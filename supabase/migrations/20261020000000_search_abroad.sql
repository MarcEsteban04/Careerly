-- Careerly: saved searches can target one country abroad ("country:sg").
-- Safe to run more than once.

alter table public.saved_searches
  drop constraint if exists saved_searches_scope_check;

alter table public.saved_searches
  add constraint saved_searches_scope_check
  check (scope ~ '^(philippines|remote|anywhere|country:[a-z]{2})$');
