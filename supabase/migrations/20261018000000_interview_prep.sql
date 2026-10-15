-- Careerly: AI interview prep, one kit per application.
-- Safe to run more than once.

create table if not exists public.interview_preps (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  application_id uuid not null references public.applications (id) on delete cascade,
  -- Company brief, focus areas, questions with suggested answers, tips.
  content jsonb not null,
  -- AI provider that wrote it, e.g. "Gemini".
  provider text not null default 'AI',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, application_id)
);

create index if not exists interview_preps_application_idx
  on public.interview_preps (application_id);

alter table public.interview_preps enable row level security;

drop policy if exists "Owners manage their interview preps" on public.interview_preps;
create policy "Owners manage their interview preps" on public.interview_preps
  for all to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
