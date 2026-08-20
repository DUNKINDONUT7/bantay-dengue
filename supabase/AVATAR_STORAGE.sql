-- ============================================================================
-- BantayDengue — profile avatar storage
-- Run this ONCE in Supabase Studio → SQL Editor → New query, after
-- BantayDengue_FINAL.sql. Safe to re-run (idempotent).
--
-- WHY THIS EXISTS: public.profiles.photo_url has existed in the schema
-- since schema.sql, but nothing in the app has ever written to it or given
-- residents a way to upload a photo — this adds the storage bucket + RLS
-- policies for that. Unlike report-evidence/waste-evidence (private, signed
-- URLs, staff-visible), avatars are public within the app the same way a
-- person's name already is — so this uses a public bucket (simpler,
-- no signed-URL expiry to manage) with the same folder-based ownership
-- check used by the private evidence buckets.
-- ============================================================================

begin;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('avatars', 'avatars', true, 3145728, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set
  public = true,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "avatars_public_read" on storage.objects;
create policy "avatars_public_read" on storage.objects
  for select
  using (bucket_id = 'avatars');

drop policy if exists "avatars_owner_write" on storage.objects;
create policy "avatars_owner_write" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
    and public.current_account_active()
  );

drop policy if exists "avatars_owner_update" on storage.objects;
create policy "avatars_owner_update" on storage.objects
  for update to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "avatars_owner_delete" on storage.objects;
create policy "avatars_owner_delete" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

commit;
