# Confirms what's actually live on the linked Supabase project -- never
# trust a file's claimed status (see supabase/README.md and the incident
# that prompted MIGRATION_LEDGER.sql: a file marked "not confirmed live"
# turned out to already be applied, and a file marked "Applied" had
# silently been reverted by a later re-run of a different file).
#
# Usage:
#   supabase/check_live_schema.ps1 columns <table>   # column shape of a table
#   supabase/check_live_schema.ps1 policies <table>  # RLS policies on a table
#   supabase/check_live_schema.ps1 ledger            # what MIGRATION_LEDGER.sql thinks is applied
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

$mode = $args[0]
$table = $args[1]

switch ($mode) {
  "columns" {
    if (-not $table) { Write-Error "Usage: check_live_schema.ps1 columns <table>"; exit 1 }
    supabase db query --linked "select column_name, data_type, is_nullable from information_schema.columns where table_schema='public' and table_name='$table' order by ordinal_position;"
  }
  "policies" {
    if (-not $table) { Write-Error "Usage: check_live_schema.ps1 policies <table>"; exit 1 }
    supabase db query --linked "select policyname, cmd, qual, with_check from pg_policies where schemaname='public' and tablename='$table' order by policyname;"
  }
  "ledger" {
    supabase db query --linked "select filename, applied_at from public.schema_migrations order by filename;"
  }
  default {
    Write-Error "Usage: check_live_schema.ps1 {columns <table>|policies <table>|ledger}"
    exit 1
  }
}
