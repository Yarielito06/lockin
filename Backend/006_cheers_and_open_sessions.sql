-- Lockin migration 006: cheers for friends who are locked in, and open-ended ("free time") sessions.
-- Safe to re-run.

-- Open-ended sessions: when it started, and whether it has no fixed end.
alter table public.profiles add column if not exists focus_since timestamptz;
alter table public.profiles add column if not exists focus_open  boolean not null default false;
grant update (focus_since, focus_open) on public.profiles to authenticated;

-- Cheers ---------------------------------------------------------------------

create table if not exists public.cheers (
  id         uuid primary key default gen_random_uuid(),
  from_id    uuid not null references public.profiles(id) on delete cascade,
  to_id      uuid not null references public.profiles(id) on delete cascade,
  emoji      text not null check (emoji in ('🔥', '💪', '👏', '❤️', '🙏')),
  created_at timestamptz not null default now(),
  check (from_id <> to_id)
);
create index if not exists cheers_to_created_idx on public.cheers (to_id, created_at desc);

alter table public.cheers enable row level security;
revoke all on public.cheers from anon, authenticated;

-- Cheer a friend (once every 20 seconds per friend, so it can't be used to spam).
create or replace function public.send_cheer(target uuid, emoji text) returns void
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid();
begin
  if me is null then raise exception 'Not signed in'; end if;
  if not exists (select 1 from public.friendships where user_id = me and friend_id = target) then
    raise exception 'You can only cheer friends';
  end if;
  if exists (select 1 from public.cheers c where c.from_id = me and c.to_id = target and c.created_at > now() - interval '20 seconds') then
    raise exception 'Easy — you just cheered them';
  end if;
  insert into public.cheers (from_id, to_id, emoji) values (me, target, send_cheer.emoji);
end $$;

-- Cheers you've received since a time (the app asks for your current session's start).
create or replace function public.my_cheers(since timestamptz) returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'id', c.id, 'from_id', c.from_id, 'name', p.display_name, 'emoji', c.emoji, 'created_at', c.created_at
  ) order by c.created_at desc), '[]'::jsonb)
  from public.cheers c join public.profiles p on p.id = c.from_id
  where c.to_id = auth.uid() and c.created_at > since;
$$;

revoke execute on function public.send_cheer(uuid, text), public.my_cheers(timestamptz) from public, anon;
grant execute on function public.send_cheer(uuid, text), public.my_cheers(timestamptz) to authenticated;

-- Push: tell them when a friend cheers (handled by the notify function).
drop trigger if exists notify_cheer on public.cheers;
create trigger notify_cheer after insert on public.cheers
  for each row execute function public.call_notify();
