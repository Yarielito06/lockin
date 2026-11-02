-- Lockin migration 002: friend requests, server-side groups with invites, and group sessions.
-- Run after schema.sql (Supabase → SQL Editor → Run). Safe to re-run.
--
-- Friends:  send_friend_request(code) creates a request; the other person accepts with
--           respond_friend_request(). If they had already requested you, it's accepted at once.
-- Groups:   create_group() invites friends; each invitee accepts or declines.
--           start_group_session() announces a lock-in; members' apps offer "Join".
-- All new tables have RLS on and no policies: they're only read and written through the
-- security-definer functions below, which check auth.uid() themselves.

-- Tables ---------------------------------------------------------------------

create table if not exists public.friend_requests (
  from_id    uuid not null references public.profiles(id) on delete cascade,
  to_id      uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (from_id, to_id),
  check (from_id <> to_id)
);

create table if not exists public.groups (
  id                 uuid primary key default gen_random_uuid(),
  name               text not null check (char_length(name) between 1 and 40),
  owner_id           uuid not null references public.profiles(id) on delete cascade,
  session_ends_at    timestamptz,
  session_started_by uuid references public.profiles(id) on delete set null,
  created_at         timestamptz not null default now()
);

create table if not exists public.group_members (
  group_id   uuid not null references public.groups(id) on delete cascade,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  status     text not null check (status in ('invited', 'joined')),
  invited_by uuid references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  primary key (group_id, user_id)
);

alter table public.friend_requests enable row level security;
alter table public.groups          enable row level security;
alter table public.group_members   enable row level security;
revoke all on public.friend_requests, public.groups, public.group_members from anon, authenticated;

-- Friend requests ------------------------------------------------------------

drop function if exists public.add_friend(text);

create or replace function public.send_friend_request(code text) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  me     uuid := auth.uid();
  target public.profiles;
begin
  if me is null then raise exception 'Not signed in'; end if;
  select * into target from public.profiles where invite_code = upper(trim(code));
  if target.id is null then raise exception 'No one has that code'; end if;
  if target.id = me then raise exception 'That''s your own code'; end if;

  if exists (select 1 from public.friendships where user_id = me and friend_id = target.id) then
    return jsonb_build_object('name', target.display_name, 'status', 'already');
  end if;

  -- They already asked you: accept straight away.
  if exists (select 1 from public.friend_requests where from_id = target.id and to_id = me) then
    insert into public.friendships (user_id, friend_id) values (me, target.id), (target.id, me) on conflict do nothing;
    delete from public.friend_requests where from_id = target.id and to_id = me;
    return jsonb_build_object('name', target.display_name, 'status', 'accepted');
  end if;

  insert into public.friend_requests (from_id, to_id) values (me, target.id) on conflict do nothing;
  return jsonb_build_object('name', target.display_name, 'status', 'requested');
end $$;

create or replace function public.respond_friend_request(requester uuid, accept boolean) returns void
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid();
begin
  if not exists (select 1 from public.friend_requests where from_id = requester and to_id = me) then
    raise exception 'That request no longer exists';
  end if;
  if accept then
    insert into public.friendships (user_id, friend_id) values (me, requester), (requester, me) on conflict do nothing;
  end if;
  delete from public.friend_requests where from_id = requester and to_id = me;
end $$;

create or replace function public.cancel_friend_request(target uuid) returns void
language sql security definer set search_path = public as $$
  delete from public.friend_requests where from_id = auth.uid() and to_id = target;
$$;

-- Groups ---------------------------------------------------------------------

create or replace function public.create_group(group_name text, member_ids uuid[]) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  me  uuid := auth.uid();
  gid uuid;
begin
  if me is null then raise exception 'Not signed in'; end if;
  insert into public.groups (name, owner_id) values (trim(group_name), me) returning id into gid;
  insert into public.group_members (group_id, user_id, status) values (gid, me, 'joined');
  -- Only friends can be invited.
  insert into public.group_members (group_id, user_id, status, invited_by)
  select gid, f.friend_id, 'invited', me
  from public.friendships f
  where f.user_id = me and f.friend_id = any(member_ids)
  on conflict do nothing;
  return gid;
end $$;

create or replace function public.respond_group_invite(gid uuid, accept boolean) returns void
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid();
begin
  if accept then
    update public.group_members set status = 'joined' where group_id = gid and user_id = me and status = 'invited';
  else
    delete from public.group_members where group_id = gid and user_id = me and status = 'invited';
  end if;
end $$;

-- Leaving removes you; a group with no joined members left is deleted.
create or replace function public.leave_group(gid uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  delete from public.group_members where group_id = gid and user_id = auth.uid();
  delete from public.groups g
  where g.id = gid and not exists (select 1 from public.group_members m where m.group_id = gid and m.status = 'joined');
end $$;

-- Announces a group lock-in until ends_at (unless one is already running).
create or replace function public.start_group_session(gid uuid, ends_at timestamptz) returns void
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid();
begin
  if not exists (select 1 from public.group_members where group_id = gid and user_id = me and status = 'joined') then
    raise exception 'You''re not in that group';
  end if;
  update public.groups
  set session_ends_at = ends_at, session_started_by = me
  where id = gid and (session_ends_at is null or session_ends_at < now());
end $$;

-- One group as JSON, with its members (invited and joined). Internal helper.
create or replace function public.group_json(gid uuid) returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'id', g.id,
    'name', g.name,
    'owner_id', g.owner_id,
    'session_ends_at', g.session_ends_at,
    'session_started_by', g.session_started_by,
    'session_started_by_name', sp.display_name,
    'members', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', p.id, 'name', p.display_name, 'status', m.status, 'focusing_until', p.focusing_until
      ) order by m.created_at)
      from public.group_members m join public.profiles p on p.id = m.user_id
      where m.group_id = g.id
    ), '[]'::jsonb)
  )
  from public.groups g
  left join public.profiles sp on sp.id = g.session_started_by
  where g.id = gid;
$$;

-- Everything social that isn't the friends list itself, in one call.
create or replace function public.my_social() returns jsonb
language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'incoming', coalesce((
      select jsonb_agg(jsonb_build_object('id', p.id, 'name', p.display_name) order by r.created_at)
      from public.friend_requests r join public.profiles p on p.id = r.from_id
      where r.to_id = auth.uid()), '[]'::jsonb),
    'outgoing', coalesce((
      select jsonb_agg(jsonb_build_object('id', p.id, 'name', p.display_name) order by r.created_at)
      from public.friend_requests r join public.profiles p on p.id = r.to_id
      where r.from_id = auth.uid()), '[]'::jsonb),
    'groups', coalesce((
      select jsonb_agg(public.group_json(m.group_id) order by m.created_at)
      from public.group_members m
      where m.user_id = auth.uid() and m.status = 'joined'), '[]'::jsonb),
    'invites', coalesce((
      select jsonb_agg(public.group_json(m.group_id) || jsonb_build_object('invited_by', ip.display_name) order by m.created_at)
      from public.group_members m left join public.profiles ip on ip.id = m.invited_by
      where m.user_id = auth.uid() and m.status = 'invited'), '[]'::jsonb)
  );
$$;

-- Permissions ----------------------------------------------------------------

revoke execute on function
  public.send_friend_request(text), public.respond_friend_request(uuid, boolean), public.cancel_friend_request(uuid),
  public.create_group(text, uuid[]), public.respond_group_invite(uuid, boolean), public.leave_group(uuid),
  public.start_group_session(uuid, timestamptz), public.group_json(uuid), public.my_social()
from public, anon;

grant execute on function
  public.send_friend_request(text), public.respond_friend_request(uuid, boolean), public.cancel_friend_request(uuid),
  public.create_group(text, uuid[]), public.respond_group_invite(uuid, boolean), public.leave_group(uuid),
  public.start_group_session(uuid, timestamptz), public.my_social()
to authenticated;
