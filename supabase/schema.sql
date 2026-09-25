-- Healthy Mind Living: database schema with row-level security.
-- Run this whole file once in Supabase: SQL Editor > New query > paste > Run.
-- Change the doctor email below if the clinician will sign up with a different address.

create extension if not exists pgcrypto;

-- ---------- tables ----------
create table if not exists public.app_settings (
  key text primary key,
  value text not null
);
insert into public.app_settings (key, value) values ('doctor_email', 'maduwantha31@gmail.com')
  on conflict (key) do update set value = excluded.value;

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  email text not null,
  role text not null check (role in ('doctor', 'client')),
  created_at timestamptz not null default now()
);

create table if not exists public.invites (
  email text primary key check (email = lower(email)),
  name text,
  created_at timestamptz not null default now()
);

create table if not exists public.patients (
  id text primary key,
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create table if not exists public.entries (
  id uuid primary key default gen_random_uuid(),
  patient_id text not null,
  type text not null,
  created_at bigint not null,
  data jsonb not null default '{}'::jsonb
);
create index if not exists entries_patient_idx on public.entries (patient_id, created_at desc);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  patient_id text not null,
  created_at bigint not null,
  data jsonb not null default '{}'::jsonb
);
create index if not exists messages_patient_idx on public.messages (patient_id, created_at);

create table if not exists public.config (
  id int primary key check (id = 1),
  data jsonb not null default '{}'::jsonb
);

-- ---------- helpers ----------
create or replace function public.is_doctor() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid() and role = 'doctor');
$$;

-- Sign-up gate: only the doctor's email or an invited email can create an account.
create or replace function public.handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
declare
  dr text;
  inv public.invites%rowtype;
begin
  select value into dr from public.app_settings where key = 'doctor_email';
  if lower(new.email) = lower(dr) then
    insert into public.profiles (id, email, role) values (new.id, lower(new.email), 'doctor');
    return new;
  end if;
  select * into inv from public.invites where email = lower(new.email);
  if not found then
    raise exception 'NOT_INVITED';
  end if;
  insert into public.profiles (id, email, role) values (new.id, lower(new.email), 'client');
  insert into public.patients (id, data) values (
    new.id::text,
    jsonb_strip_nulls(jsonb_build_object(
      'name', nullif(inv.name, ''),
      'email', lower(new.email),
      'joinedAt', (extract(epoch from now()) * 1000)::bigint
    ))
  );
  delete from public.invites where email = inv.email;
  return new;
end $$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users
  for each row execute function public.handle_new_user();

-- Create/merge a patient summary. Doctors: any patient. Clients: only their own.
create or replace function public.upsert_patient(pid text, patch jsonb) returns void
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null or not (public.is_doctor() or pid = auth.uid()::text) then
    raise exception 'not allowed';
  end if;
  insert into public.patients (id, data)
    values (pid, jsonb_build_object('joinedAt', (extract(epoch from now()) * 1000)::bigint) || patch)
  on conflict (id) do update
    set data = public.patients.data || excluded.data, updated_at = now();
end $$;

-- Update only the done/read flags of a message.
create or replace function public.update_message(mid uuid, patch jsonb) returns void
language plpgsql security definer set search_path = public as $$
declare
  m public.messages%rowtype;
  p jsonb;
begin
  select * into m from public.messages where id = mid;
  if not found then raise exception 'not found'; end if;
  if auth.uid() is null or not (public.is_doctor() or m.patient_id = auth.uid()::text) then
    raise exception 'not allowed';
  end if;
  select coalesce(jsonb_object_agg(k, v), '{}'::jsonb) into p
    from jsonb_each(patch) as t(k, v) where k in ('done', 'read');
  update public.messages set data = data || p where id = mid;
end $$;

-- Doctor only: permanently delete a client and all their data.
create or replace function public.delete_patient(pid text) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not public.is_doctor() then raise exception 'not allowed'; end if;
  delete from public.entries where patient_id = pid;
  delete from public.messages where patient_id = pid;
  delete from public.patients where id = pid;
  if pid like 'inv-%' then
    delete from public.invites where email = substr(pid, 5);
  else
    begin
      delete from auth.users where id = pid::uuid and id <> auth.uid();
    exception when invalid_text_representation then null;
    end;
  end if;
end $$;

revoke execute on function public.upsert_patient(text, jsonb) from public, anon;
revoke execute on function public.update_message(uuid, jsonb) from public, anon;
revoke execute on function public.delete_patient(text) from public, anon;
revoke execute on function public.handle_new_user() from public, anon, authenticated;
grant execute on function public.upsert_patient(text, jsonb) to authenticated;
grant execute on function public.update_message(uuid, jsonb) to authenticated;
grant execute on function public.delete_patient(text) to authenticated;
grant execute on function public.is_doctor() to authenticated;

-- ---------- row-level security ----------
alter table public.app_settings enable row level security;   -- no policies: unreadable by clients
alter table public.profiles enable row level security;
alter table public.invites enable row level security;
alter table public.patients enable row level security;
alter table public.entries enable row level security;
alter table public.messages enable row level security;
alter table public.config enable row level security;

drop policy if exists profiles_select on public.profiles;
create policy profiles_select on public.profiles for select to authenticated
  using (id = auth.uid() or public.is_doctor());

drop policy if exists invites_all on public.invites;
create policy invites_all on public.invites for all to authenticated
  using (public.is_doctor()) with check (public.is_doctor());

drop policy if exists patients_select on public.patients;
create policy patients_select on public.patients for select to authenticated
  using (public.is_doctor() or id = auth.uid()::text);

drop policy if exists entries_select on public.entries;
create policy entries_select on public.entries for select to authenticated
  using (public.is_doctor() or patient_id = auth.uid()::text);
drop policy if exists entries_insert on public.entries;
create policy entries_insert on public.entries for insert to authenticated
  with check (public.is_doctor() or patient_id = auth.uid()::text);

drop policy if exists messages_select on public.messages;
create policy messages_select on public.messages for select to authenticated
  using (public.is_doctor() or patient_id = auth.uid()::text);
drop policy if exists messages_insert on public.messages;
create policy messages_insert on public.messages for insert to authenticated
  with check (
    (public.is_doctor() and (data->>'from' = 'doctor' or patient_id = auth.uid()::text))
    or (patient_id = auth.uid()::text and data->>'from' = 'client')
  );

drop policy if exists config_select on public.config;
create policy config_select on public.config for select to authenticated using (true);
drop policy if exists config_write on public.config;
create policy config_write on public.config for all to authenticated
  using (public.is_doctor()) with check (public.is_doctor());

-- ---------- realtime ----------
do $$
declare t text;
begin
  foreach t in array array['patients', 'entries', 'messages', 'invites', 'config'] loop
    begin
      execute format('alter publication supabase_realtime add table public.%I', t);
    exception when duplicate_object then null;
    end;
  end loop;
end $$;
