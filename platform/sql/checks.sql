-- The platform's own table, for its live check (services/backend/tests/online.gd):
-- a player's lines, each seen only by its owner, published live. It follows
-- the rules every app's table follows (platform/README.md, "Apps' tables"). Run by bin/apply-sql; safe to run again.

\set ON_ERROR_STOP on

create table if not exists public.platform_check (
  id bigint generated always as identity primary key,
  owner uuid not null default auth.uid() references auth.users (id) on delete cascade,
  body text not null default '',
  created_at timestamptz not null default now()
);
alter table public.platform_check enable row level security;
drop policy if exists "own rows" on public.platform_check;
create policy "own rows" on public.platform_check for all to authenticated
  using (owner = auth.uid()) with check (owner = auth.uid());
grant select, insert, update, delete on public.platform_check to authenticated;

do $$
begin
  if not exists (select 1 from pg_publication_tables
                 where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'platform_check') then
    alter publication supabase_realtime add table public.platform_check;
  end if;
end $$;
