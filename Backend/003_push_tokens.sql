-- Lockin migration 003: device tokens for push notifications. Safe to re-run.
-- The `notify` Edge Function reads these (with the service role) to send APNs pushes.

create table if not exists public.push_tokens (
  token      text primary key,
  user_id    uuid not null references public.profiles(id) on delete cascade,
  sandbox    boolean not null default false,  -- true for development builds (APNs sandbox)
  updated_at timestamptz not null default now()
);

create index if not exists push_tokens_user_idx on public.push_tokens (user_id);

alter table public.push_tokens enable row level security;
revoke all on public.push_tokens from anon, authenticated;

-- Saves this device's token for the signed-in user. A token moves with the device:
-- if someone else signs in on the same phone, it's reassigned to them.
create or replace function public.save_push_token(token text, sandbox boolean) returns void
language sql security definer set search_path = public as $$
  insert into public.push_tokens (token, user_id, sandbox, updated_at)
  values (token, auth.uid(), sandbox, now())
  on conflict (token) do update set user_id = excluded.user_id, sandbox = excluded.sandbox, updated_at = now();
$$;

revoke execute on function public.save_push_token(text, boolean) from public, anon;
grant  execute on function public.save_push_token(text, boolean) to authenticated;

-- One row per event already notified, so each request / invite / session pushes exactly once
-- even if the function is called again (retries, or someone calling it directly).
create table if not exists public.push_log (
  key        text primary key,
  created_at timestamptz not null default now()
);
alter table public.push_log enable row level security;
revoke all on public.push_log from anon, authenticated;
