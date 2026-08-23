#!/usr/bin/env bash
# Confirms what's actually live on the linked Supabase project — never trust
# a file's claimed status (see supabase/README.md and the incident that
# prompted MIGRATION_LEDGER.sql: a file marked "not confirmed live" turned
# out to already be applied, and a file marked "Applied" had silently been
# reverted by a later re-run of a different file).
#
# Usage:
#   supabase/check_live_schema.sh columns <table>   # column shape of a table
#   supabase/check_live_schema.sh policies <table>   # RLS policies on a table
#   supabase/check_live_schema.sh ledger             # what MIGRATION_LEDGER.sql thinks is applied
set -euo pipefail
cd "$(dirname "$0")/.."

mode="${1:-}"
table="${2:-}"

case "$mode" in
  columns)
    if [[ -z "$table" ]]; then echo "Usage: $0 columns <table>"; exit 1; fi
    supabase db query --linked "select column_name, data_type, is_nullable from information_schema.columns where table_schema='public' and table_name='${table}' order by ordinal_position;"
    ;;
  policies)
    if [[ -z "$table" ]]; then echo "Usage: $0 policies <table>"; exit 1; fi
    supabase db query --linked "select policyname, cmd, qual, with_check from pg_policies where schemaname='public' and tablename='${table}' order by policyname;"
    ;;
  ledger)
    supabase db query --linked "select filename, applied_at from public.schema_migrations order by filename;"
    ;;
  *)
    echo "Usage: $0 {columns <table>|policies <table>|ledger}"
    exit 1
    ;;
esac
