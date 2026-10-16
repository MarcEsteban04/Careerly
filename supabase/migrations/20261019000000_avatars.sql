-- Careerly: profile photos in Supabase Storage.
-- Safe to run more than once.

-- Public bucket: photos are shown by URL. File names are random per upload.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', true, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- Each user manages only their own folder: avatars/<user id>/...
drop policy if exists "Users read their own avatar folder" on storage.objects;
create policy "Users read their own avatar folder" on storage.objects
  for select to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid()::text));

drop policy if exists "Users upload to their own avatar folder" on storage.objects;
create policy "Users upload to their own avatar folder" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid()::text));

drop policy if exists "Users update their own avatar folder" on storage.objects;
create policy "Users update their own avatar folder" on storage.objects
  for update to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid()::text));

drop policy if exists "Users delete from their own avatar folder" on storage.objects;
create policy "Users delete from their own avatar folder" on storage.objects
  for delete to authenticated
  using (bucket_id = 'avatars' and (storage.foldername(name))[1] = (select auth.uid()::text));
