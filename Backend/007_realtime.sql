-- Lockin migration 007: live updates. Friends' status and your cheers reach the app instantly.
-- Realtime only delivers rows the signed-in user is allowed to read. Safe to re-run.

-- You may read the cheers sent to you (the app listens for new ones).
drop policy if exists "read cheers sent to me" on public.cheers;
create policy "read cheers sent to me" on public.cheers
  for select to authenticated using (to_id = auth.uid());
grant select on public.cheers to authenticated;

do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'profiles') then
    alter publication supabase_realtime add table public.profiles;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'cheers') then
    alter publication supabase_realtime add table public.cheers;
  end if;
end $$;
