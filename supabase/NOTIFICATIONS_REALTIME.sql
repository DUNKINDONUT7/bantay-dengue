-- ============================================================================
-- BantayDengue — enable Realtime for the notifications table
-- Run this ONCE in Supabase Studio -> SQL Editor -> New query.
--
-- WHY THIS EXISTS: the global notification bell (now shown on every page,
-- every viewport — see main_shell.dart's NotificationBellButton) shows an
-- unread count. Without this, the badge only updates on the next full
-- shell rebuild; with it, a new notification updates the badge live, the
-- same "no manual refresh needed" behavior COMMUNITY_REALTIME.sql gave the
-- Community feed. Same reasoning applies: confirmed live via
-- `pg_publication_tables` that `notifications` was not yet in the
-- `supabase_realtime` publication.
-- ============================================================================

do $$
begin
  if exists (select 1 from public.schema_migrations where filename = 'NOTIFICATIONS_REALTIME.sql') then
    raise exception 'NOTIFICATIONS_REALTIME.sql has already been applied — see supabase/README.md before re-running.';
  end if;
end $$;

begin;

alter table public.notifications replica identity full;
alter publication supabase_realtime add table public.notifications;

insert into public.schema_migrations (filename) values ('NOTIFICATIONS_REALTIME.sql')
on conflict (filename) do nothing;

commit;

-- ============================================================================
-- Done. Verify with:
--   select tablename from pg_publication_tables where pubname = 'supabase_realtime' order by 1;
--   -- should now also list notifications
-- Update supabase/README.md's run-order table in the same PR.
-- ============================================================================
