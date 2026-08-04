-- ============================================================
-- RAMS Cloud Sync Schema for Supabase
-- ============================================================
-- Run this in your Supabase project's SQL Editor:
--   Dashboard -> SQL Editor -> New Query -> paste this whole file -> Run
--
-- Safe to re-run: it drops and recreates these specific tables first,
-- so a previous partial/failed run (or an older version of this
-- script) can never leave things in a broken half-created state like
-- "column does not exist". Since this is the initial cloud setup
-- (before any real syncing has happened), there is no data to lose
-- here — this only affects the six tables listed below, nothing else
-- in your Supabase project.
-- ============================================================

create extension if not exists "uuid-ossp";

drop table if exists attendance cascade;
drop table if exists leave_requests cascade;
drop table if exists notifications cascade;
drop table if exists manpower_rules cascade;
drop table if exists app_users cascade;
drop table if exists employees cascade;

-- ------------------------------------------------------------
-- employees
-- ------------------------------------------------------------
create table employees (
  id uuid primary key default uuid_generate_v4(),
  local_id integer,                 -- the row's original SQLite id, for mapping
  employee_code text not null,
  name text not null,
  father_name text default '',
  cnic text default '',
  mobile_number text default '',
  designation text not null,
  department text default '',
  unit_number text default '',
  shift text not null,
  weekly_rest_day text not null,
  joining_date text not null,
  status text not null default 'Active',
  remarks text default '',
  updated_at timestamptz not null default now()
);
create unique index employees_code_unique on employees (employee_code);

-- ------------------------------------------------------------
-- attendance
-- ------------------------------------------------------------
create table attendance (
  id uuid primary key default uuid_generate_v4(),
  employee_code text not null,      -- linked by code, not local numeric id
  date text not null,
  status text not null,
  updated_at timestamptz not null default now()
);
create unique index attendance_emp_date_unique on attendance (employee_code, date);

-- ------------------------------------------------------------
-- leave_requests
-- ------------------------------------------------------------
create table leave_requests (
  id uuid primary key default uuid_generate_v4(),
  employee_code text not null,
  leave_type text not null,
  from_date text not null,
  to_date text not null,
  reason text default '',
  status text not null default 'Pending',
  applied_by text default '',
  applied_at timestamptz not null,
  decided_by text,
  decided_at timestamptz,
  remarks text default '',
  updated_at timestamptz not null default now()
);

-- ------------------------------------------------------------
-- notifications
-- ------------------------------------------------------------
create table notifications (
  id uuid primary key default uuid_generate_v4(),
  message text not null,
  type text not null default 'info',
  related_id text,
  is_read boolean not null default false,
  created_at timestamptz not null,
  updated_at timestamptz not null default now()
);

-- ------------------------------------------------------------
-- manpower_rules
-- ------------------------------------------------------------
create table manpower_rules (
  id uuid primary key default uuid_generate_v4(),
  designation text not null,
  min_required integer not null default 0,
  max_required integer not null default 0,
  updated_at timestamptz not null default now()
);
create unique index manpower_rules_designation_unique on manpower_rules (designation);

-- ------------------------------------------------------------
-- app_users
-- ------------------------------------------------------------
create table app_users (
  id uuid primary key default uuid_generate_v4(),
  username text not null,
  password_hash text not null,
  role text not null,
  updated_at timestamptz not null default now()
);
create unique index app_users_username_unique on app_users (username);

-- ============================================================
-- Row Level Security
-- ============================================================
-- These tables are reachable using the app's "anon" public key
-- (the same key embedded in the Android app). That key is meant to
-- be public-facing, so access here is intentionally permissive —
-- the app's own Admin/Supervisor/Viewer permission system is what
-- actually restricts what a person can do inside the app itself.
-- ============================================================

alter table employees enable row level security;
alter table attendance enable row level security;
alter table leave_requests enable row level security;
alter table notifications enable row level security;
alter table manpower_rules enable row level security;
alter table app_users enable row level security;

create policy "Allow all with anon key" on employees for all using (true) with check (true);
create policy "Allow all with anon key" on attendance for all using (true) with check (true);
create policy "Allow all with anon key" on leave_requests for all using (true) with check (true);
create policy "Allow all with anon key" on notifications for all using (true) with check (true);
create policy "Allow all with anon key" on manpower_rules for all using (true) with check (true);
create policy "Allow all with anon key" on app_users for all using (true) with check (true);

-- ============================================================
-- Done! You should see a "Success. No rows returned" message.
-- Verify by going to Table Editor in the left sidebar — you should
-- see all 6 tables listed: employees, attendance, leave_requests,
-- notifications, manpower_rules, app_users.
-- ============================================================
