-- ============================================================================
-- BantayDengue — Community Stories (resident peer-support feed)
-- Run this ONCE in Supabase Studio -> SQL Editor -> New query.
-- Safe to re-run (idempotent): CREATE TABLE IF NOT EXISTS, DROP POLICY IF
-- EXISTS / CREATE POLICY, CREATE OR REPLACE FUNCTION throughout.
--
-- WHAT THIS ADDS: a resident-only space to share a dengue recovery journey
-- (posts), comment on each other's posts, and react with a single "send
-- love" reaction — a peer-support feed, not a clinical record. Kept
-- deliberately separate from `reports`/`health_advisories`: this is
-- resident-authored and informal, not meant to inform official case data
-- the way a verified report does.
--
-- SCOPE DECISIONS (documented here — there was no time for a full product
-- discussion before this shipped, so these are the calls made and why):
--   - Resident-only, both posting AND reading. Admin retains moderation
--     visibility (can see + soft-delete any post/comment), matching their
--     existing oversight role elsewhere (Users, Verify, Waste). Health
--     workers and waste personnel do NOT get access — meant to be a peer
--     space, not something staff monitor day to day.
--   - One reaction type ("love"), not a reaction picker — matches exactly
--     what was asked for, not scope-crept into a multi-emoji system.
--   - Soft delete for posts/comments (deleted_at), matching every other
--     table in this schema. Reactions use a real delete instead — a
--     reaction has no content to preserve, it's purely present/absent
--     (un-loving a post removes the row, same as toggling a like off).
--   - Photos are public within the app (new `community-photos` bucket),
--     not signed-URL private like report/waste evidence — a community
--     photo is meant to be seen by the community it's posted to, unlike
--     sensitive report evidence. Same pattern as AVATAR_STORAGE.sql.
--   - Rate-limited the same way reports/appointments/waste_requests
--     already are (RATE_LIMIT_ADDITIONS.sql) — an open posting feature
--     needs this at least as much as the operational forms do.
--   - Engagement notifications (comment/reaction on your post) mirror
--     capture_status_change's shape (BantayDengue_FINAL.sql), skipping
--     self-notifications.
-- ============================================================================

do $$
begin
  if exists (select 1 from public.schema_migrations where filename = 'COMMUNITY_STORIES.sql') then
    raise exception 'COMMUNITY_STORIES.sql has already been applied — see supabase/README.md before re-running.';
  end if;
end $$;

begin;

-- ── Tables ───────────────────────────────────────────────────────────────

create table if not exists public.community_posts (
  id uuid primary key default uuid_generate_v4(),
  author_id uuid not null references public.profiles(id),
  content text not null,
  photo_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz,
  deleted_at timestamptz
);
create index if not exists idx_community_posts_active
  on public.community_posts(created_at desc) where deleted_at is null;

create table if not exists public.community_comments (
  id uuid primary key default uuid_generate_v4(),
  post_id uuid not null references public.community_posts(id),
  author_id uuid not null references public.profiles(id),
  content text not null,
  created_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index if not exists idx_community_comments_post
  on public.community_comments(post_id, created_at) where deleted_at is null;

create table if not exists public.community_reactions (
  id uuid primary key default uuid_generate_v4(),
  post_id uuid not null references public.community_posts(id),
  user_id uuid not null references public.profiles(id),
  created_at timestamptz not null default now(),
  unique (post_id, user_id)
);
create index if not exists idx_community_reactions_post
  on public.community_reactions(post_id);

alter table public.community_posts enable row level security;
alter table public.community_comments enable row level security;
alter table public.community_reactions enable row level security;

-- ── RLS: posts ───────────────────────────────────────────────────────────

drop policy if exists "community_posts_select" on public.community_posts;
create policy "community_posts_select" on public.community_posts
  for select using (
    public.current_account_active()
    and deleted_at is null
    and public.current_role() in ('resident', 'admin')
  );

drop policy if exists "community_posts_insert" on public.community_posts;
create policy "community_posts_insert" on public.community_posts
  for insert with check (
    author_id = auth.uid()
    and public.current_account_active()
    and public.current_role() = 'resident'
  );

-- Author can edit/soft-delete their own post.
drop policy if exists "community_posts_update_own" on public.community_posts;
create policy "community_posts_update_own" on public.community_posts
  for update using (
    author_id = auth.uid() and public.current_account_active()
  )
  with check (author_id = auth.uid());

-- Admin can soft-delete (moderate) any post.
drop policy if exists "community_posts_moderate" on public.community_posts;
create policy "community_posts_moderate" on public.community_posts
  for update using (public.current_role() = 'admin')
  with check (public.current_role() = 'admin');

-- ── RLS: comments ────────────────────────────────────────────────────────

-- Also requires the parent post to still be visible (not soft-deleted) —
-- otherwise a moderated post's comments would stay independently queryable
-- even though the post itself is hidden from the feed.
drop policy if exists "community_comments_select" on public.community_comments;
create policy "community_comments_select" on public.community_comments
  for select using (
    public.current_account_active()
    and deleted_at is null
    and public.current_role() in ('resident', 'admin')
    and exists (
      select 1 from public.community_posts p
      where p.id = community_comments.post_id and p.deleted_at is null
    )
  );

drop policy if exists "community_comments_insert" on public.community_comments;
create policy "community_comments_insert" on public.community_comments
  for insert with check (
    author_id = auth.uid()
    and public.current_account_active()
    and public.current_role() = 'resident'
  );

drop policy if exists "community_comments_update_own" on public.community_comments;
create policy "community_comments_update_own" on public.community_comments
  for update using (
    author_id = auth.uid() and public.current_account_active()
  )
  with check (author_id = auth.uid());

drop policy if exists "community_comments_moderate" on public.community_comments;
create policy "community_comments_moderate" on public.community_comments
  for update using (public.current_role() = 'admin')
  with check (public.current_role() = 'admin');

-- ── RLS: reactions ───────────────────────────────────────────────────────

drop policy if exists "community_reactions_select" on public.community_reactions;
create policy "community_reactions_select" on public.community_reactions
  for select using (
    public.current_account_active()
    and public.current_role() in ('resident', 'admin')
  );

drop policy if exists "community_reactions_insert" on public.community_reactions;
create policy "community_reactions_insert" on public.community_reactions
  for insert with check (
    user_id = auth.uid()
    and public.current_account_active()
    and public.current_role() = 'resident'
  );

drop policy if exists "community_reactions_delete_own" on public.community_reactions;
create policy "community_reactions_delete_own" on public.community_reactions
  for delete using (user_id = auth.uid());

-- ── Rate limits — same shape as RATE_LIMIT_ADDITIONS.sql ────────────────

create or replace function public.enforce_community_post_rate_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  recent_count integer;
begin
  select count(*) into recent_count
  from public.community_posts
  where author_id = new.author_id
    and created_at > now() - interval '24 hours';

  if recent_count >= 10 then
    raise exception
      'Too many posts in the last 24 hours. Please wait before posting again.'
      using errcode = 'P0001';
  end if;

  return new;
end;
$$;

drop trigger if exists community_posts_rate_limit on public.community_posts;
create trigger community_posts_rate_limit
  before insert on public.community_posts
  for each row
  execute function public.enforce_community_post_rate_limit();

create or replace function public.enforce_community_comment_rate_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  recent_count integer;
begin
  select count(*) into recent_count
  from public.community_comments
  where author_id = new.author_id
    and created_at > now() - interval '24 hours';

  if recent_count >= 60 then
    raise exception
      'Too many comments in the last 24 hours. Please wait before commenting again.'
      using errcode = 'P0001';
  end if;

  return new;
end;
$$;

drop trigger if exists community_comments_rate_limit on public.community_comments;
create trigger community_comments_rate_limit
  before insert on public.community_comments
  for each row
  execute function public.enforce_community_comment_rate_limit();

-- ── Engagement notifications ─────────────────────────────────────────────

create or replace function public.notify_community_comment()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  post_author uuid;
begin
  select author_id into post_author
  from public.community_posts
  where id = new.post_id;

  if post_author is not null and post_author <> new.author_id then
    insert into public.notifications(user_id, title, body, type)
    values (
      post_author,
      'New comment on your story',
      'Someone commented on your community post.',
      'community_comment'
    );
  end if;
  return new;
end;
$$;

drop trigger if exists community_comments_notify on public.community_comments;
create trigger community_comments_notify
  after insert on public.community_comments
  for each row
  execute function public.notify_community_comment();

create or replace function public.notify_community_reaction()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  post_author uuid;
begin
  select author_id into post_author
  from public.community_posts
  where id = new.post_id;

  if post_author is not null and post_author <> new.user_id then
    insert into public.notifications(user_id, title, body, type)
    values (
      post_author,
      'Someone sent love',
      'Someone reacted to your community post.',
      'community_reaction'
    );
  end if;
  return new;
end;
$$;

drop trigger if exists community_reactions_notify on public.community_reactions;
create trigger community_reactions_notify
  after insert on public.community_reactions
  for each row
  execute function public.notify_community_reaction();

-- ── Public photo bucket — same pattern as AVATAR_STORAGE.sql ────────────

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('community-photos', 'community-photos', true, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set
  public = true,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "community_photos_public_read" on storage.objects;
create policy "community_photos_public_read" on storage.objects
  for select
  using (bucket_id = 'community-photos');

drop policy if exists "community_photos_owner_write" on storage.objects;
create policy "community_photos_owner_write" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'community-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
    and public.current_account_active()
  );

drop policy if exists "community_photos_owner_delete" on storage.objects;
create policy "community_photos_owner_delete" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'community-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

insert into public.schema_migrations (filename) values ('COMMUNITY_STORIES.sql')
on conflict (filename) do nothing;

commit;

-- ============================================================================
-- Done. Verify with:
--   select filename from public.schema_migrations where filename = 'COMMUNITY_STORIES.sql';
--   select count(*) from public.community_posts;  -- should succeed, return 0
-- Update supabase/README.md's run-order table in the same PR.
-- ============================================================================
