-- Careerly: core tables for the dashboard.
-- Every row belongs to the signed-in user; row-level security makes each
-- table private to its owner.

-- Job applications --------------------------------------------------------

create table public.applications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  company text not null check (char_length(company) between 1 and 120),
  role text not null check (char_length(role) between 1 and 120),
  status text not null default 'saved'
    check (status in ('saved', 'applied', 'interviewing', 'offer', 'rejected')),
  location text,
  job_url text,
  salary text,
  notes text,
  applied_on date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index applications_user_id_idx on public.applications (user_id, updated_at desc);

-- Interviews, follow-ups and deadlines ------------------------------------

create table public.agenda_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  application_id uuid references public.applications (id) on delete set null,
  kind text not null default 'interview'
    check (kind in ('interview', 'follow_up', 'deadline', 'other')),
  title text not null check (char_length(title) between 1 and 160),
  starts_at timestamptz not null,
  notes text,
  is_done boolean not null default false,
  created_at timestamptz not null default now()
);

create index agenda_events_user_id_idx on public.agenda_events (user_id, starts_at);
create index agenda_events_application_id_idx on public.agenda_events (application_id);

-- Goals ---------------------------------------------------------------------

create table public.goals (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  title text not null check (char_length(title) between 1 and 120),
  target integer not null check (target between 1 and 10000),
  progress integer not null default 0 check (progress >= 0),
  period text not null default 'weekly' check (period in ('weekly', 'monthly', 'once')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index goals_user_id_idx on public.goals (user_id, created_at);

-- AI-generated resumes and cover letters ------------------------------------

create table public.documents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  application_id uuid references public.applications (id) on delete set null,
  kind text not null check (kind in ('resume', 'cover_letter')),
  title text not null check (char_length(title) between 1 and 160),
  content text not null,
  created_at timestamptz not null default now()
);

create index documents_user_id_idx on public.documents (user_id, created_at desc);
create index documents_application_id_idx on public.documents (application_id);

-- Keep updated_at current ---------------------------------------------------

create function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger applications_set_updated_at
  before update on public.applications
  for each row execute function public.set_updated_at();

create trigger goals_set_updated_at
  before update on public.goals
  for each row execute function public.set_updated_at();

-- Row-level security: owners only ---------------------------------------------

alter table public.applications enable row level security;
alter table public.agenda_events enable row level security;
alter table public.goals enable row level security;
alter table public.documents enable row level security;

create policy "Owners manage their applications" on public.applications
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "Owners manage their agenda" on public.agenda_events
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "Owners manage their goals" on public.goals
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "Owners manage their documents" on public.documents
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
