-- The experiment's one table: a player's notes, each visible only to its owner,
-- and published to realtime so a second device sees changes live.
create table public.notes (
  id bigint generated always as identity primary key,
  owner uuid not null default auth.uid() references auth.users (id) on delete cascade,
  body text not null default '',
  created_at timestamptz not null default now()
);
alter table public.notes enable row level security;
create policy "own notes: read" on public.notes for select to authenticated using (owner = auth.uid());
create policy "own notes: write" on public.notes for insert to authenticated with check (owner = auth.uid());
grant select, insert on public.notes to authenticated;
alter publication supabase_realtime add table public.notes;
