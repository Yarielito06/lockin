-- Lockin migration 008: profile photos. The photo file lives in the private `moments` bucket
-- under your own folder (friends can read it, nobody else); the profile stores its path.
-- Safe to re-run.

alter table public.profiles add column if not exists avatar_path text;
grant update (avatar_path) on public.profiles to authenticated;
