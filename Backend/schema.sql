-- Lockin backend schema. Run once in Supabase → SQL Editor → New query → Run.
-- Safe to re-run: everything is "create or replace" / "if not exists".
--
-- Model: every user (anonymous sign-in) has one profile with a shareable invite code.
-- Friendships are stored in both directions and only created via add_friend(code).
-- Row Level Security: you can read your own profile and your friends' profiles, nothing else.

-- Invite codes ---------------------------------------------------------------

create or replace function public.generate_invite_code() returns text
language plpgsql as $$
declare
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; -- no 0/O/1/I
  code text;
begin
  loop
    code := 'LOCK-';
    for i in 1..5 loop
      code := code || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
    end loop;
    exit when not exists (select 1 from public.profiles where invite_code = code);
  end loop;
  return code;
end $$;

-- Tables ---------------------------------------------------------------------

create table if not exists public.profiles (
  id             uuid primary key references auth.users on delete cascade,
  display_name   text not null check (char_length(display_name) between 1 and 40),
  invite_code    text not null unique default public.generate_invite_code(),
  focusing_until timestamptz,          -- set while locked in; in the past = not focusing
  focus_group    text,                 -- group name for group sessions
  week_minutes   int  not null default 0,
  week_start     text,                 -- ISO week start (yyyy-MM-dd) that week_minutes belongs to
  streak         int  not null default 0,
  updated_at     timestamptz not null default now()
);

create table if not exists public.friendships (
  user_id    uuid not null references public.profiles(id) on delete cascade,
  friend_id  uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, friend_id),
  check (user_id <> friend_id)
);

-- Row Level Security ---------------------------------------------------------

alter table public.profiles    enable row level security;
alter table public.friendships enable row level security;

drop policy if exists "read own and friends' profiles" on public.profiles;
create policy "read own and friends' profiles" on public.profiles
  for select to authenticated
  using (
    id = auth.uid()
    or exists (select 1 from public.friendships f where f.user_id = auth.uid() and f.friend_id = profiles.id)
  );

drop policy if exists "create own profile" on public.profiles;
create policy "create own profile" on public.profiles
  for insert to authenticated with check (id = auth.uid());

drop policy if exists "update own profile" on public.profiles;
create policy "update own profile" on public.profiles
  for update to authenticated using (id = auth.uid()) with check (id = auth.uid());

drop policy if exists "read own friendships" on public.friendships;
create policy "read own friendships" on public.friendships
  for select to authenticated using (user_id = auth.uid());

-- Signed-in users may read (filtered by RLS above) and create their own profile...
grant usage on schema public to authenticated;
grant select, insert on public.profiles to authenticated;
grant select on public.friendships to authenticated;
-- ...and change their status and name, but never their id or invite code.
revoke update on public.profiles from authenticated;
grant update (display_name, focusing_until, focus_group, week_minutes, week_start, streak, updated_at)
  on public.profiles to authenticated;
-- Friendships change only through the functions below.
revoke insert, update, delete on public.friendships from authenticated;

-- Functions ------------------------------------------------------------------

-- Adds the owner of `code` as a friend (both directions) and returns their profile.
create or replace function public.add_friend(code text) returns public.profiles
language plpgsql security definer set search_path = public as $$
declare
  me     uuid := auth.uid();
  friend public.profiles;
begin
  if me is null then
    raise exception 'Not signed in';
  end if;
  select * into friend from public.profiles where invite_code = upper(trim(code));
  if friend.id is null then
    raise exception 'No one has that code';
  end if;
  if friend.id = me then
    raise exception 'That''s your own code';
  end if;
  insert into public.friendships (user_id, friend_id)
  values (me, friend.id), (friend.id, me)
  on conflict do nothing;
  return friend;
end $$;

-- Removes a friendship in both directions.
create or replace function public.remove_friend(friend uuid) returns void
language sql security definer set search_path = public as $$
  delete from public.friendships
  where (user_id = auth.uid() and friend_id = friend)
     or (user_id = friend and friend_id = auth.uid());
$$;

-- Your friends' profiles (runs with your permissions, so RLS applies).
create or replace function public.my_friends() returns setof public.profiles
language sql stable set search_path = public as $$
  select p.* from public.profiles p
  join public.friendships f on f.friend_id = p.id
  where f.user_id = auth.uid()
  order by p.display_name;
$$;

revoke execute on function public.add_friend(text), public.remove_friend(uuid), public.my_friends() from public, anon;
grant  execute on function public.add_friend(text), public.remove_friend(uuid), public.my_friends() to authenticated;
