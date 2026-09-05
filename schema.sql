-- Hintvite Growth Engine — Supabase schema
-- Run this in Supabase SQL Editor.

create extension if not exists pgcrypto;

create table if not exists public.app_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null default 'admin' check (role in ('admin','sales')),
  created_at timestamptz not null default now()
);

create or replace function public.is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists(select 1 from public.app_admins a where a.user_id = auth.uid());
$$;

create table if not exists public.questionnaire_responses (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  full_name text,
  first_name text,
  last_name text,
  email text,
  phone text,
  company text,
  city text,
  profession text,
  source text not null default 'hintvite_questionnaire',
  payload jsonb not null,
  reviewed boolean not null default false
);

create table if not exists public.prospects (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  company text not null,
  contact_name text,
  first_name text,
  last_name text,
  email text,
  phone text,
  website text,
  linkedin_url text,
  instagram_url text,
  city text,
  specialties text[] default '{}',
  company_size text,
  project_signals text,
  brands_detected text[] default '{}',
  source text,
  score integer check (score between 0 and 100),
  score_reason text,
  ai_summary text,
  status text not null default 'new' check (status in ('new','qualified','contacted','replied','meeting','pilot','active','nurture','lost','do_not_contact')),
  last_contact_at timestamptz,
  next_action_at timestamptz,
  owner_id uuid references auth.users(id),
  unique(email)
);

create table if not exists public.prospect_activities (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  prospect_id uuid not null references public.prospects(id) on delete cascade,
  activity_type text not null,
  channel text,
  subject text,
  body text,
  metadata jsonb default '{}',
  created_by uuid references auth.users(id)
);

create table if not exists public.brands (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  name text not null unique,
  category text,
  website text,
  contact_name text,
  contact_email text,
  status text not null default 'identified',
  demand_count integer not null default 0,
  potential_value numeric,
  notes text
);

create table if not exists public.campaigns (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  name text not null,
  channel text not null default 'email',
  status text not null default 'draft',
  prompt text,
  settings jsonb default '{}'
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  prospect_id uuid references public.prospects(id) on delete cascade,
  campaign_id uuid references public.campaigns(id) on delete set null,
  direction text not null check (direction in ('outbound','inbound')),
  channel text not null default 'email',
  subject text,
  body text,
  status text not null default 'draft',
  provider_id text,
  sent_at timestamptz,
  ai_classification jsonb
);

create table if not exists public.ai_tasks (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  task_type text not null,
  entity_type text not null,
  entity_id uuid,
  status text not null default 'queued',
  input jsonb not null default '{}',
  output jsonb,
  error text,
  completed_at timestamptz
);

-- RLS
alter table public.app_admins enable row level security;
alter table public.questionnaire_responses enable row level security;
alter table public.prospects enable row level security;
alter table public.prospect_activities enable row level security;
alter table public.brands enable row level security;
alter table public.campaigns enable row level security;
alter table public.messages enable row level security;
alter table public.ai_tasks enable row level security;

-- Public questionnaire: anyone can INSERT, nobody anonymous can READ.
drop policy if exists questionnaire_public_insert on public.questionnaire_responses;
create policy questionnaire_public_insert on public.questionnaire_responses for insert to anon, authenticated with check (true);
drop policy if exists questionnaire_admin_select on public.questionnaire_responses;
create policy questionnaire_admin_select on public.questionnaire_responses for select to authenticated using (public.is_admin());
drop policy if exists questionnaire_admin_update on public.questionnaire_responses;
create policy questionnaire_admin_update on public.questionnaire_responses for update to authenticated using (public.is_admin()) with check (public.is_admin());
drop policy if exists questionnaire_admin_delete on public.questionnaire_responses;
create policy questionnaire_admin_delete on public.questionnaire_responses for delete to authenticated using (public.is_admin());

-- Admin-only CRM tables.
create policy admin_all_prospects on public.prospects for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy admin_all_activities on public.prospect_activities for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy admin_all_brands on public.brands for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy admin_all_campaigns on public.campaigns for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy admin_all_messages on public.messages for all to authenticated using (public.is_admin()) with check (public.is_admin());
create policy admin_all_ai_tasks on public.ai_tasks for all to authenticated using (public.is_admin()) with check (public.is_admin());

-- Useful indexes
create index if not exists idx_responses_created on public.questionnaire_responses(created_at desc);
create index if not exists idx_prospects_score on public.prospects(score desc);
create index if not exists idx_prospects_status on public.prospects(status);
create index if not exists idx_activities_prospect on public.prospect_activities(prospect_id, created_at desc);
create index if not exists idx_messages_prospect on public.messages(prospect_id, created_at desc);

-- After creating your first Auth user, run:
-- insert into public.app_admins(user_id, role) values ('YOUR-AUTH-USER-UUID', 'admin');
