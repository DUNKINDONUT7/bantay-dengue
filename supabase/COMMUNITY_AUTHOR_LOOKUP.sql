-- ============================================================================
-- BantayDengue — narrow author-info lookup for Community Stories
-- Run this ONCE in Supabase Studio -> SQL Editor -> New query, after
-- COMMUNITY_STORIES.sql. Safe to re-run (idempotent).
--
-- WHY THIS EXISTS: community_posts/community_comments were designed
-- assuming a Postgrest embed (`profiles!community_posts_author_id_fkey(...)`)
-- would resolve each author's name/photo — but `profiles`' own RLS
-- (`profiles_select_own_or_staff`) only lets a user read THEIR OWN row,
-- plus staff (health_worker/waste_personnel/admin) can read everyone's.
-- A resident is not staff, so a resident viewing another resident's post
-- would have silently gotten a null author on every embed — the exact kind
-- of thing that's easy to miss because it fails quiet, not loud, and this
-- session has already been burned once by exactly that failure mode (see
-- the incident note in supabase/README.md).
--
-- Loosening `profiles_select_own_or_staff` itself to let any resident read
-- any other resident's row was rejected on purpose: that table also holds
-- email, phone, and barangay — a community "send love" feature has no
-- business exposing all of that to every other resident. Instead, this is
-- a narrow SECURITY DEFINER function that returns only id/full_name/
-- photo_url for a requested set of ids — the same "narrow safe signal, not
-- broad table access" shape as `nearby_report_exists` in
-- BantayDengue_FINAL.sql.
-- ============================================================================

do $$
begin
  if exists (select 1 from public.schema_migrations where filename = 'COMMUNITY_AUTHOR_LOOKUP.sql') then
    raise exception 'COMMUNITY_AUTHOR_LOOKUP.sql has already been applied — see supabase/README.md before re-running.';
  end if;
end $$;

begin;

create or replace function public.community_author_info(p_ids uuid[])
returns table(id uuid, full_name text, photo_url text)
language sql
stable
security definer
set search_path = public
as $$
  select p.id, p.full_name, p.photo_url
  from public.profiles p
  where p.id = any(p_ids);
$$;

grant execute on function public.community_author_info(uuid[]) to authenticated;

insert into public.schema_migrations (filename) values ('COMMUNITY_AUTHOR_LOOKUP.sql')
on conflict (filename) do nothing;

commit;

-- ============================================================================
-- Done. Verify with:
--   select * from public.community_author_info(array[]::uuid[]);  -- should succeed, return 0 rows
-- ============================================================================
