-- Lockin migration 005: Moments — photos shared with friends, reactions and reports. Safe to re-run.
--
-- Photos live in a private Storage bucket at moments/<user id>/<moment id>.jpg.
-- Only you and your friends can read them; only you can upload or delete your own.
-- The feed keeps the last 7 days.

-- Tables ---------------------------------------------------------------------

create table if not exists public.moments (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null references public.profiles(id) on delete cascade,
  image_path text not null,
  caption    text check (char_length(caption) <= 140),
  tag        text check (char_length(tag) <= 40),  -- e.g. "🔒 Locked in 50 min"
  created_at timestamptz not null default now()
);
create index if not exists moments_user_created_idx on public.moments (user_id, created_at desc);

create table if not exists public.moment_reactions (
  moment_id  uuid not null references public.moments(id) on delete cascade,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  emoji      text not null check (emoji in ('🔥', '💪', '👏', '❤️')),
  created_at timestamptz not null default now(),
  primary key (moment_id, user_id)
);

create table if not exists public.moment_reports (
  moment_id   uuid not null references public.moments(id) on delete cascade,
  reporter_id uuid not null references public.profiles(id) on delete cascade,
  reason      text,
  created_at  timestamptz not null default now(),
  primary key (moment_id, reporter_id)
);

alter table public.moments          enable row level security;
alter table public.moment_reactions enable row level security;
alter table public.moment_reports   enable row level security;
revoke all on public.moments, public.moment_reactions, public.moment_reports from anon, authenticated;

-- Can the signed-in user see this person's moments? (themselves or a friend)
create or replace function public.can_see(owner uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select owner = auth.uid()
      or exists (select 1 from public.friendships where user_id = auth.uid() and friend_id = owner);
$$;

-- Storage --------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('moments', 'moments', false, 3145728, array['image/jpeg'])
on conflict (id) do update set public = false, file_size_limit = 3145728, allowed_mime_types = array['image/jpeg'];

drop policy if exists "moments: read own and friends'" on storage.objects;
create policy "moments: read own and friends'" on storage.objects
  for select to authenticated
  using (bucket_id = 'moments' and public.can_see(((storage.foldername(name))[1])::uuid));

drop policy if exists "moments: upload to own folder" on storage.objects;
create policy "moments: upload to own folder" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'moments' and (storage.foldername(name))[1] = auth.uid()::text);

drop policy if exists "moments: delete own" on storage.objects;
create policy "moments: delete own" on storage.objects
  for delete to authenticated
  using (bucket_id = 'moments' and (storage.foldername(name))[1] = auth.uid()::text);

-- Functions ------------------------------------------------------------------

-- Creates a moment for a photo already uploaded to your folder.
create or replace function public.post_moment(image_path text, caption text, tag text) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  me  uuid := auth.uid();
  mid uuid;
begin
  if me is null then raise exception 'Not signed in'; end if;
  if split_part(image_path, '/', 1) <> me::text then raise exception 'That photo isn''t yours'; end if;
  insert into public.moments (user_id, image_path, caption, tag)
  values (me, image_path, nullif(trim(caption), ''), nullif(trim(tag), ''))
  returning id into mid;
  return mid;
end $$;

-- Your feed: your own and your friends' moments from the last 7 days, newest first,
-- with reactions. Reported moments are hidden from the person who reported them.
create or replace function public.moments_feed() returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', m.id,
    'user_id', m.user_id,
    'name', p.display_name,
    'image_path', m.image_path,
    'caption', m.caption,
    'tag', m.tag,
    'created_at', m.created_at,
    'reactions', coalesce((
      select jsonb_agg(jsonb_build_object('user_id', r.user_id, 'name', rp.display_name, 'emoji', r.emoji)
                       order by r.created_at)
      from public.moment_reactions r join public.profiles rp on rp.id = r.user_id
      where r.moment_id = m.id), '[]'::jsonb)
  ) order by m.created_at desc), '[]'::jsonb)
  from public.moments m
  join public.profiles p on p.id = m.user_id
  where public.can_see(m.user_id)
    and m.created_at > now() - interval '7 days'
    and not exists (select 1 from public.moment_reports x where x.moment_id = m.id and x.reporter_id = auth.uid());
$$;

-- Sets your reaction (one per moment); the same emoji again removes it.
create or replace function public.react_to_moment(mid uuid, emoji text) returns void
language plpgsql security definer set search_path = public as $$
declare
  me    uuid := auth.uid();
  owner uuid;
begin
  select user_id into owner from public.moments where id = mid;
  if owner is null or not public.can_see(owner) then raise exception 'Moment not found'; end if;
  if exists (select 1 from public.moment_reactions r where r.moment_id = mid and r.user_id = me and r.emoji = react_to_moment.emoji) then
    delete from public.moment_reactions where moment_id = mid and user_id = me;
  else
    insert into public.moment_reactions (moment_id, user_id, emoji) values (mid, me, react_to_moment.emoji)
    on conflict (moment_id, user_id) do update set emoji = excluded.emoji, created_at = now();
  end if;
end $$;

-- Deletes your own moment (the app removes the photo file too).
create or replace function public.delete_moment(mid uuid) returns text
language sql security definer set search_path = public as $$
  delete from public.moments where id = mid and user_id = auth.uid() returning image_path;
$$;

-- Hides a friend's moment for you and records it for review.
create or replace function public.report_moment(mid uuid, reason text) returns void
language plpgsql security definer set search_path = public as $$
declare owner uuid;
begin
  select user_id into owner from public.moments where id = mid;
  if owner is null or not public.can_see(owner) then raise exception 'Moment not found'; end if;
  insert into public.moment_reports (moment_id, reporter_id, reason)
  values (mid, auth.uid(), left(reason, 200)) on conflict do nothing;
end $$;

revoke execute on function public.can_see(uuid), public.post_moment(text, text, text), public.moments_feed(),
  public.react_to_moment(uuid, text), public.delete_moment(uuid), public.report_moment(uuid, text) from public, anon;
grant execute on function public.can_see(uuid), public.post_moment(text, text, text), public.moments_feed(),
  public.react_to_moment(uuid, text), public.delete_moment(uuid), public.report_moment(uuid, text) to authenticated;

-- Push: tell friends when someone shares a moment (handled by the notify function).
drop trigger if exists notify_moment on public.moments;
create trigger notify_moment after insert on public.moments
  for each row execute function public.call_notify();
