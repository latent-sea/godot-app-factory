-- Shivonne Dubarry's bookings on the platform (platform/README.md, "Apps'
-- tables"). Run on every deploy, so safe to run again.
--
-- - When she works: a weekly pattern (week), in her own time zone
--   (settings), less the times she blocks out (blocked). Only she reads or
--   changes them.
-- - Visitors see only the free times (shivonne_dubarry_openings()): never
--   who asked for the others, nor why they are not free.
-- - A request holds its time at once, until she declines it. It asks only
--   for what she needs to reply: the session, the time, a name, an email
--   and, if they like, a phone number. A visitor sees only their own; only
--   she sees them all, and only she can accept or decline. One open request
--   per visitor at a time.
-- - She is staff: her account's id goes in shivonne_dubarry_staff once she
--   has signed in.

\set ON_ERROR_STOP on

create table if not exists public.shivonne_dubarry_staff (
  user_id uuid primary key references auth.users (id) on delete cascade
);
alter table public.shivonne_dubarry_staff enable row level security;
drop policy if exists "sees themself" on public.shivonne_dubarry_staff;
create policy "sees themself" on public.shivonne_dubarry_staff for select to authenticated
  using (user_id = auth.uid());
grant select on public.shivonne_dubarry_staff to authenticated;

create or replace function public.shivonne_dubarry_is_staff() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.shivonne_dubarry_staff where user_id = auth.uid())
$$;

-- one row: how her week is read
create table if not exists public.shivonne_dubarry_settings (  -- no player data
  id boolean primary key default true check (id),
  time_zone text not null default 'Pacific/Auckland',
  slot_minutes int not null default 60 check (slot_minutes between 15 and 240),
  notice_hours int not null default 24 check (notice_hours between 0 and 336),
  horizon_days int not null default 28 check (horizon_days between 1 and 120)
);

-- when she works, week by week: weekday 0 is Sunday, times in her time zone
create table if not exists public.shivonne_dubarry_week (  -- no player data
  id bigint generated always as identity primary key,
  weekday smallint not null check (weekday between 0 and 6),
  starts time not null,
  ends time not null check (ends > starts)
);

-- times she isn't working, whatever the week says
create table if not exists public.shivonne_dubarry_blocked (  -- no player data
  id bigint generated always as identity primary key,
  starts timestamptz not null,
  ends timestamptz not null check (ends > starts)
);

do $$
begin
  -- the first time only: a placeholder week she changes (weekdays, 9 to 12 and 1 to 5)
  if not exists (select 1 from public.shivonne_dubarry_settings) then
    insert into public.shivonne_dubarry_settings default values;
    insert into public.shivonne_dubarry_week (weekday, starts, ends)
      select day, hours.starts, hours.ends
      from generate_series(1, 5) as day,
           (values (time '09:00', time '12:00'), (time '13:00', time '17:00')) as hours (starts, ends);
  end if;
end $$;

alter table public.shivonne_dubarry_settings enable row level security;
alter table public.shivonne_dubarry_week enable row level security;
alter table public.shivonne_dubarry_blocked enable row level security;
drop policy if exists "hers" on public.shivonne_dubarry_settings;
create policy "hers" on public.shivonne_dubarry_settings for all to authenticated
  using (public.shivonne_dubarry_is_staff()) with check (public.shivonne_dubarry_is_staff());
drop policy if exists "hers" on public.shivonne_dubarry_week;
create policy "hers" on public.shivonne_dubarry_week for all to authenticated
  using (public.shivonne_dubarry_is_staff()) with check (public.shivonne_dubarry_is_staff());
drop policy if exists "hers" on public.shivonne_dubarry_blocked;
create policy "hers" on public.shivonne_dubarry_blocked for all to authenticated
  using (public.shivonne_dubarry_is_staff()) with check (public.shivonne_dubarry_is_staff());
grant select, update on public.shivonne_dubarry_settings to authenticated;
grant select, insert, update, delete on public.shivonne_dubarry_week, public.shivonne_dubarry_blocked to authenticated;

create table if not exists public.shivonne_dubarry_requests (
  id uuid primary key default gen_random_uuid(),
  visitor uuid not null default auth.uid() references auth.users (id) on delete cascade,
  session text not null check (session in ('consultation', 'individual')),
  starts timestamptz not null,
  ends timestamptz not null,
  name text not null check (length(btrim(name)) between 1 and 200),
  email text not null check (length(email) <= 320 and email ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'),
  phone text not null default '' check (length(phone) <= 40),
  status text not null default 'pending' check (status in ('pending', 'accepted', 'declined')),
  created_at timestamptz not null default now(),
  -- a time is held by one request, until it's declined
  constraint shivonne_dubarry_requests_hold exclude using gist (tstzrange(starts, ends) with &&) where (status <> 'declined')
);
alter table public.shivonne_dubarry_requests enable row level security;
drop policy if exists "a visitor asks" on public.shivonne_dubarry_requests;
create policy "a visitor asks" on public.shivonne_dubarry_requests for insert to authenticated
  with check (visitor = auth.uid());
drop policy if exists "a visitor sees theirs; she sees all" on public.shivonne_dubarry_requests;
create policy "a visitor sees theirs; she sees all" on public.shivonne_dubarry_requests for select to authenticated
  using (visitor = auth.uid() or public.shivonne_dubarry_is_staff());
drop policy if exists "she answers" on public.shivonne_dubarry_requests;
create policy "she answers" on public.shivonne_dubarry_requests for update to authenticated
  using (public.shivonne_dubarry_is_staff()) with check (public.shivonne_dubarry_is_staff());
grant select, insert, update on public.shivonne_dubarry_requests to authenticated;

-- The times a visitor may ask for, from now on: each slot of her week within
-- the horizon, at least the notice ahead, not blocked and not held.
create or replace function public.shivonne_dubarry_openings() returns table (starts timestamptz, ends timestamptz)
language sql stable security definer set search_path = '' as $$
  select slot.starts, slot.ends
  from public.shivonne_dubarry_settings s
  cross join generate_series(0, s.horizon_days) as ahead
  cross join lateral (select (now() at time zone s.time_zone)::date + ahead as day) d
  join public.shivonne_dubarry_week w on w.weekday = extract(dow from d.day)
  cross join generate_series(0, floor(extract(epoch from w.ends - w.starts) / 60 / s.slot_minutes)::int - 1) as n
  cross join lateral (
    select (d.day + w.starts + make_interval(mins => n * s.slot_minutes)) at time zone s.time_zone as starts,
           (d.day + w.starts + make_interval(mins => (n + 1) * s.slot_minutes)) at time zone s.time_zone as ends
  ) slot
  where s.id
    and slot.starts >= now() + make_interval(hours => s.notice_hours)
    and not exists (select 1 from public.shivonne_dubarry_blocked b
                    where tstzrange(b.starts, b.ends) && tstzrange(slot.starts, slot.ends))
    and not exists (select 1 from public.shivonne_dubarry_requests r
                    where r.status <> 'declined' and tstzrange(r.starts, r.ends) && tstzrange(slot.starts, slot.ends))
  order by slot.starts
$$;
grant execute on function public.shivonne_dubarry_openings() to anon, authenticated;

-- A request is the visitor's, pending, and for a free time: the server says
-- so, whatever the page sent.
create or replace function public.shivonne_dubarry_request_made() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  new.visitor := auth.uid();
  new.status := 'pending';
  new.created_at := now();
  new.name := btrim(new.name);
  new.email := btrim(new.email);
  new.phone := btrim(new.phone);
  select o.ends into new.ends from public.shivonne_dubarry_openings() o where o.starts = new.starts;
  if new.ends is null then
    raise exception 'That time is no longer free' using errcode = 'P0001';
  end if;
  if exists (select 1 from public.shivonne_dubarry_requests
             where visitor = new.visitor and status = 'pending' and starts > now()) then
    raise exception 'You already have a request waiting for a reply' using errcode = 'P0001';
  end if;
  return new;
end $$;
drop trigger if exists shivonne_dubarry_request_made on public.shivonne_dubarry_requests;
create trigger shivonne_dubarry_request_made before insert on public.shivonne_dubarry_requests
  for each row execute function public.shivonne_dubarry_request_made();

-- Answering a request changes its status and nothing else.
create or replace function public.shivonne_dubarry_request_answered() returns trigger
language plpgsql set search_path = '' as $$
declare
  answer text := new.status;
begin
  new := old;
  new.status := answer;
  return new;
end $$;
drop trigger if exists shivonne_dubarry_request_answered on public.shivonne_dubarry_requests;
create trigger shivonne_dubarry_request_answered before update on public.shivonne_dubarry_requests
  for each row execute function public.shivonne_dubarry_request_answered();

-- Live, for her page: each subscriber is sent only the rows they may read.
do $$
begin
  if not exists (select 1 from pg_publication_tables
                 where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'shivonne_dubarry_requests') then
    alter publication supabase_realtime add table public.shivonne_dubarry_requests;
  end if;
end $$;
