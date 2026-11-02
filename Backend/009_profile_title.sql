-- Lockin migration 009: a title you write yourself, shown on your card instead of your weekly rank.
-- Safe to re-run.

alter table public.profiles add column if not exists profile_title text;
alter table public.profiles drop constraint if exists profile_title_length;
alter table public.profiles add constraint profile_title_length check (profile_title is null or char_length(profile_title) <= 24);
grant update (profile_title) on public.profiles to authenticated;
