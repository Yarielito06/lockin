-- Lockin migration 010: your all-time focus minutes, so friends see your rank badge. Safe to re-run.

alter table public.profiles add column if not exists total_minutes int not null default 0;
grant update (total_minutes) on public.profiles to authenticated;
