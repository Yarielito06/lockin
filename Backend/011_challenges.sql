-- Lockin migration 011: group challenges. A group sets a shared focus goal for a week,
-- e.g. "Study marathon: 20 hours together". Progress is the sum of each member's weekly minutes
-- (the same numbers friends already see). Safe to re-run.

create table if not exists public.group_challenges (
  group_id       uuid primary key references public.groups(id) on delete cascade,
  title          text not null check (char_length(title) between 1 and 40),
  target_minutes int  not null check (target_minutes between 60 and 60000),
  week_start     text not null,
  created_by     uuid references public.profiles(id) on delete set null,
  created_at     timestamptz not null default now()
);

alter table public.group_challenges enable row level security;
revoke all on public.group_challenges from anon, authenticated;

-- Start (or replace) your group's challenge for the week the app names.
create or replace function public.set_group_challenge(gid uuid, challenge_title text, minutes int, week text) returns void
language plpgsql security definer set search_path = public as $$
declare me uuid := auth.uid();
begin
  if me is null then raise exception 'Not signed in'; end if;
  if not exists (select 1 from public.group_members where group_id = gid and user_id = me and status = 'joined') then
    raise exception 'You''re not in that group';
  end if;
  insert into public.group_challenges (group_id, title, target_minutes, week_start, created_by)
  values (gid, trim(challenge_title), minutes, week, me)
  on conflict (group_id) do update
    set title = excluded.title, target_minutes = excluded.target_minutes,
        week_start = excluded.week_start, created_by = excluded.created_by, created_at = now();
end $$;

create or replace function public.clear_group_challenge(gid uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from public.group_members where group_id = gid and user_id = auth.uid() and status = 'joined') then
    raise exception 'You''re not in that group';
  end if;
  delete from public.group_challenges where group_id = gid;
end $$;

-- The challenges of your groups, with each joined member's minutes for the challenge's week.
create or replace function public.my_challenges() returns jsonb
language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'group_id', c.group_id,
    'group_name', g.name,
    'title', c.title,
    'target_minutes', c.target_minutes,
    'week_start', c.week_start,
    'created_by', c.created_by,
    'created_by_name', cp.display_name,
    'members', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', p.id, 'name', p.display_name,
        'minutes', case when p.week_start = c.week_start then p.week_minutes else 0 end
      ) order by case when p.week_start = c.week_start then p.week_minutes else 0 end desc)
      from public.group_members m join public.profiles p on p.id = m.user_id
      where m.group_id = c.group_id and m.status = 'joined'
    ), '[]'::jsonb)
  ) order by c.created_at desc), '[]'::jsonb)
  from public.group_challenges c
  join public.groups g on g.id = c.group_id
  left join public.profiles cp on cp.id = c.created_by
  where exists (select 1 from public.group_members m where m.group_id = c.group_id and m.user_id = auth.uid() and m.status = 'joined');
$$;

revoke execute on function public.set_group_challenge(uuid, text, int, text), public.clear_group_challenge(uuid), public.my_challenges() from public, anon;
grant execute on function public.set_group_challenge(uuid, text, int, text), public.clear_group_challenge(uuid), public.my_challenges() to authenticated;
