-- Careerly: job tracking, job finding and the apply flow.
-- Safe to run more than once.

-- Applications: where a job came from, its posting, and what was sent -------

alter table public.applications
  add column if not exists source text,
  add column if not exists external_id text,
  add column if not exists job_description text,
  add column if not exists follow_up_on date,
  add column if not exists resume_document_id uuid
    references public.documents (id) on delete set null,
  add column if not exists cover_letter_document_id uuid
    references public.documents (id) on delete set null;

create index if not exists applications_external_id_idx
  on public.applications (user_id, external_id);
create index if not exists applications_resume_document_id_idx
  on public.applications (resume_document_id);
create index if not exists applications_cover_letter_document_id_idx
  on public.applications (cover_letter_document_id);

-- Timeline: every status change, logged by the database --------------------

create table if not exists public.application_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  application_id uuid not null references public.applications (id) on delete cascade,
  kind text not null check (kind in ('created', 'status_changed', 'note')),
  from_status text,
  to_status text,
  note text,
  created_at timestamptz not null default now()
);

create index if not exists application_events_application_idx
  on public.application_events (application_id, created_at desc);
create index if not exists application_events_user_idx
  on public.application_events (user_id);

alter table public.application_events enable row level security;

drop policy if exists "Owners manage their application events" on public.application_events;
create policy "Owners manage their application events" on public.application_events
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create or replace function public.log_application_event()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    insert into public.application_events (user_id, application_id, kind, to_status)
    values (new.user_id, new.id, 'created', new.status);
  elsif new.status is distinct from old.status then
    insert into public.application_events
      (user_id, application_id, kind, from_status, to_status)
    values (new.user_id, new.id, 'status_changed', old.status, new.status);
  end if;
  return new;
end;
$$;

drop trigger if exists applications_log_event on public.applications;
create trigger applications_log_event
  after insert or update of status on public.applications
  for each row execute function public.log_application_event();

-- Give existing applications a starting point on their timeline.
insert into public.application_events (user_id, application_id, kind, to_status, created_at)
select a.user_id, a.id, 'created', a.status, a.created_at
from public.applications a
where not exists (
  select 1 from public.application_events e where e.application_id = a.id
);

-- Saved searches ---------------------------------------------------------------

create table if not exists public.saved_searches (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  keywords text not null check (char_length(keywords) between 1 and 120),
  scope text not null default 'philippines'
    check (scope in ('philippines', 'remote', 'anywhere')),
  posted_within text not null default 'month'
    check (posted_within in ('today', 'week', 'month', 'any')),
  created_at timestamptz not null default now(),
  unique (user_id, keywords, scope, posted_within)
);

create index if not exists saved_searches_user_idx
  on public.saved_searches (user_id, created_at desc);

alter table public.saved_searches enable row level security;

drop policy if exists "Owners manage their saved searches" on public.saved_searches;
create policy "Owners manage their saved searches" on public.saved_searches
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- Jobs marked "Not interested" ---------------------------------------------------

create table if not exists public.dismissed_jobs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  -- Normalized "title|company", stable across job boards.
  job_key text not null check (char_length(job_key) between 1 and 300),
  title text not null,
  company text not null,
  created_at timestamptz not null default now(),
  unique (user_id, job_key)
);

alter table public.dismissed_jobs enable row level security;

drop policy if exists "Owners manage their dismissed jobs" on public.dismissed_jobs;
create policy "Owners manage their dismissed jobs" on public.dismissed_jobs
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
