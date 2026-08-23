-- ============================================================================
-- BantayDengue — enable Realtime for Community Stories
-- Run this ONCE in Supabase Studio -> SQL Editor -> New query, after
-- COMMUNITY_STORIES.sql. Safe to re-run (guarded by the ledger below).
--
-- WHY THIS EXISTS: the resident asked for the community feed to behave like
-- Facebook/Instagram — new posts/comments/reactions should appear on other
-- residents' screens without them having to pull-to-refresh. Supabase
-- Realtime does this via Postgres logical replication, but a table only
-- streams changes once it's added to the `supabase_realtime` publication —
-- confirmed live via `select * from pg_publication_tables where
-- pubname='supabase_realtime'` that NO tables were in it yet, so this was
-- silently never going to work without this file, regardless of what the
-- Flutter side subscribes to.
--
-- REPLICA IDENTITY FULL is set on all three tables because Realtime (and
-- the RLS check it runs per change) needs the OLD row values on
-- UPDATE/DELETE to know whether a change is still visible to a given
-- subscriber — e.g. a soft-delete (UPDATE ... SET deleted_at = now()) needs
-- the pre-update row to correctly notify "this post disappeared" rather
-- than silently doing nothing. Default replica identity (primary key only)
-- doesn't carry that.
-- ============================================================================

do $$
begin
  if exists (select 1 from public.schema_migrations where filename = 'COMMUNITY_REALTIME.sql') then
    raise exception 'COMMUNITY_REALTIME.sql has already been applied — see supabase/README.md before re-running.';
  end if;
end $$;

begin;

alter table public.community_posts replica identity full;
alter table public.community_comments replica identity full;
alter table public.community_reactions replica identity full;

alter publication supabase_realtime add table public.community_posts;
alter publication supabase_realtime add table public.community_comments;
alter publication supabase_realtime add table public.community_reactions;

insert into public.schema_migrations (filename) values ('COMMUNITY_REALTIME.sql')
on conflict (filename) do nothing;

commit;

-- ============================================================================
-- Done. Verify with:
--   select tablename from pg_publication_tables where pubname = 'supabase_realtime' order by 1;
--   -- should list community_posts, community_comments, community_reactions
-- Update supabase/README.md's run-order table in the same PR.
-- ============================================================================
