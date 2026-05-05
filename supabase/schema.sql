-- ============================================================
-- SignEase — Supabase Database Schema
-- Run this in your Supabase SQL Editor (Dashboard → SQL Editor)
-- ============================================================

-- ── Tier limits (reference table) ────────────────────────────
create table if not exists public.tiers (
  name        text primary key,
  sig_limit   integer not null  -- -1 = unlimited
);

insert into public.tiers (name, sig_limit) values
  ('free',      3),
  ('pro',       50),
  ('unlimited', -1)
on conflict do nothing;

-- ── Profiles (one row per auth user) ────────────────────────
create table if not exists public.profiles (
  id               uuid references auth.users(id) on delete cascade primary key,
  email            text,
  tier             text references public.tiers(name) default 'free',
  signatures_used  integer not null default 0,
  created_at       timestamptz default now()
);

alter table public.profiles enable row level security;

create policy "Users can view own profile"
  on public.profiles for select
  using (auth.uid() = id);

create policy "Users can update own profile"
  on public.profiles for update
  using (auth.uid() = id);

-- ── Auto-create profile on sign-up ──────────────────────────
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.profiles (id, email)
  values (new.id, new.email)
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ── Signed documents log ─────────────────────────────────────
create table if not exists public.signed_documents (
  id             uuid default gen_random_uuid() primary key,
  user_id        uuid references auth.users(id) on delete cascade not null,
  document_name  text not null,
  signed_at      timestamptz default now()
);

alter table public.signed_documents enable row level security;

create policy "Users can view own signed docs"
  on public.signed_documents for select
  using (auth.uid() = user_id);

create policy "Users can insert own signed docs"
  on public.signed_documents for insert
  with check (auth.uid() = user_id);

-- ── Increment usage + log document (single RPC call) ─────────
create or replace function public.record_signature(doc_name text)
returns void language plpgsql security definer as $$
declare
  v_used    integer;
  v_limit   integer;
begin
  -- Get current usage and limit
  select p.signatures_used, t.sig_limit
  into   v_used, v_limit
  from   public.profiles p
  join   public.tiers    t on t.name = p.tier
  where  p.id = auth.uid();

  -- Enforce limit (skip check if unlimited)
  if v_limit >= 0 and v_used >= v_limit then
    raise exception 'LIMIT_REACHED';
  end if;

  -- Increment counter
  update public.profiles
  set    signatures_used = signatures_used + 1
  where  id = auth.uid();

  -- Log document
  insert into public.signed_documents (user_id, document_name)
  values (auth.uid(), doc_name);
end;
$$;
