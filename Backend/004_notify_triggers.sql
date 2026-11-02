-- Lockin migration 004: call the notify Edge Function when something worth a push happens.
-- Uses pg_net (async HTTP from Postgres). Safe to re-run.
-- The anon key below is the public client key (also shipped in the app); the function
-- re-checks every event against the database, so it can't be used to forge notifications.

create extension if not exists pg_net;

create or replace function public.call_notify() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  perform net.http_post(
    url := 'https://<YOUR-PROJECT-REF>.supabase.co/functions/v1/<YOUR-NOTIFY-FUNCTION>',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer <YOUR-ANON-KEY>'
    ),
    body := jsonb_build_object(
      'type', TG_OP,
      'table', TG_TABLE_NAME,
      'record', to_jsonb(NEW),
      'old_record', case when TG_OP = 'UPDATE' then to_jsonb(OLD) end
    )
  );
  return NEW;
end $$;

drop trigger if exists notify_friend_request on public.friend_requests;
create trigger notify_friend_request after insert on public.friend_requests
  for each row execute function public.call_notify();

drop trigger if exists notify_group_invite on public.group_members;
create trigger notify_group_invite after insert on public.group_members
  for each row when (NEW.status = 'invited') execute function public.call_notify();

drop trigger if exists notify_group_session on public.groups;
create trigger notify_group_session after update of session_ends_at on public.groups
  for each row when (NEW.session_ends_at is distinct from OLD.session_ends_at) execute function public.call_notify();

revoke execute on function public.call_notify() from public, anon, authenticated;
