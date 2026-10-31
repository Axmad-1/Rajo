-- RAJO foundation: demo-only workspace schema
create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  created_at timestamptz not null default now()
);

create table if not exists public.demo_accounts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null default 'Demo Account',
  starting_balance numeric(14,2) not null default 10000 check (starting_balance >= 0),
  currency text not null default 'USD',
  created_at timestamptz not null default now()
);

create table if not exists public.journal_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  instrument text not null,
  direction text not null check (direction in ('BUY','SELL','OBSERVE')),
  entry_price numeric(18,8),
  exit_price numeric(18,8),
  notes text not null default '',
  outcome text not null default 'PLANNED' check (outcome in ('PLANNED','WIN','LOSS','BREAKEVEN')),
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;
alter table public.demo_accounts enable row level security;
alter table public.journal_entries enable row level security;

create policy "profile owner read" on public.profiles for select using (auth.uid() = id);
create policy "profile owner insert" on public.profiles for insert with check (auth.uid() = id);
create policy "profile owner update" on public.profiles for update using (auth.uid() = id) with check (auth.uid() = id);

create policy "demo account owner all" on public.demo_accounts
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "journal owner all" on public.journal_entries
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

create or replace function public.create_profile_for_new_user()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'display_name',''));
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_profile on auth.users;
create trigger on_auth_user_created_profile
after insert on auth.users
for each row execute procedure public.create_profile_for_new_user();
