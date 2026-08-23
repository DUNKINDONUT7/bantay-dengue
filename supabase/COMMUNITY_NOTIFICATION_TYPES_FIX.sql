-- ============================================================================
-- BantayDengue — fix notifications_type_check to allow community types
-- Run this ONCE in Supabase Studio -> SQL Editor -> New query.
--
-- BUG FOUND (2026-08-23), while seeding demo data for the Community Stories
-- feature: `notifications.notifications_type_check` only allows
-- ['general','outbreak_alert','advisory','appointment','report_status',
-- 'waste'] — it was never updated when COMMUNITY_STORIES.sql added
-- `notify_community_comment()`/`notify_community_reaction()`, both of which
-- insert type = 'community_comment' / 'community_reaction'.
--
-- IMPACT: every comment and every reaction on a community post has been
-- failing outright since COMMUNITY_STORIES.sql was applied — the trigger
-- fires AFTER INSERT, its own insert into notifications violates the check
-- constraint, and that aborts the entire transaction. The comment/reaction
-- row itself never actually committed either, not just the notification.
-- Confirmed by reproducing it live via the demo-data seed script
-- (COMMUNITY_SEED_DEMO_DATA.sql), not assumed from reading the trigger.
-- ============================================================================

do $$
begin
  if exists (select 1 from public.schema_migrations where filename = 'COMMUNITY_NOTIFICATION_TYPES_FIX.sql') then
    raise exception 'COMMUNITY_NOTIFICATION_TYPES_FIX.sql has already been applied — see supabase/README.md before re-running.';
  end if;
end $$;

begin;

alter table public.notifications drop constraint if exists notifications_type_check;
alter table public.notifications add constraint notifications_type_check
  check (type = any (array[
    'general', 'outbreak_alert', 'advisory', 'appointment', 'report_status',
    'waste', 'community_comment', 'community_reaction'
  ]));

insert into public.schema_migrations (filename) values ('COMMUNITY_NOTIFICATION_TYPES_FIX.sql')
on conflict (filename) do nothing;

commit;

-- ============================================================================
-- Done. Verify with:
--   select pg_get_constraintdef(oid) from pg_constraint
--     where conrelid = 'public.notifications'::regclass and contype = 'c';
--   -- must include 'community_comment' and 'community_reaction'
-- Update supabase/README.md's run-order table in the same PR.
-- ============================================================================
