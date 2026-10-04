-- backend.sql's promises, in a real PostgreSQL (platform/checks/test_sql.sh).
-- Each block fails with what isn't true.

\set ON_ERROR_STOP on

-- a known week: every day 9 to 5 in UTC, a day's notice
update public.shivonne_dubarry_settings set time_zone = 'UTC', slot_minutes = 60, notice_hours = 24, horizon_days = 28;
delete from public.shivonne_dubarry_week;
insert into public.shivonne_dubarry_week (weekday, starts, ends) select day, '09:00', '17:00' from generate_series(0, 6) as day;
insert into auth.users values ('5d000000-0000-0000-0000-000000000001'), ('5d000000-0000-0000-0000-000000000002'), ('5d000000-0000-0000-0000-000000000003');
insert into public.shivonne_dubarry_staff values ('5d000000-0000-0000-0000-000000000003');
create temporary table first_two as select starts from public.shivonne_dubarry_openings() limit 2;
grant select on first_two to anon, authenticated;

set role anon;
do $$ begin
  assert (select count(*) from public.shivonne_dubarry_openings()) between 27 * 8 and 28 * 8,
    'NOT TRUE: anyone sees the openings: eight a day for four weeks';
  assert (select min(starts) from public.shivonne_dubarry_openings()) >= now() + interval '24 hours', 'NOT TRUE: none sooner than the notice';
  assert (select bool_and(extract(minute from starts) = 0 and extract(hour from starts) between 9 and 16) from public.shivonne_dubarry_openings()),
    'NOT TRUE: each on the hour, within the week''s hours';
end $$;
do $$ begin
  begin perform 1 from public.shivonne_dubarry_week; exception when insufficient_privilege then return; end;
  raise exception 'NOT TRUE: a visitor can''t read her week';
end $$;

-- a visitor asks
set role authenticated;
set request.jwt.claim.sub = '5d000000-0000-0000-0000-000000000001';
insert into public.shivonne_dubarry_requests (session, starts, name, email, status, visitor)
  select 'consultation', (select min(starts) from first_two), '  Ana  ', 'ana@example.com', 'accepted', '5d000000-0000-0000-0000-000000000002';
do $$
declare made public.shivonne_dubarry_requests;
begin
  select * into made from public.shivonne_dubarry_requests;
  assert made.visitor = '5d000000-0000-0000-0000-000000000001', 'NOT TRUE: a request is the visitor''s, whoever it names';
  assert made.status = 'pending', 'NOT TRUE: and pending, whatever it says';
  assert made.ends = made.starts + interval '1 hour', 'NOT TRUE: and holds the whole slot';
  assert made.name = 'Ana', 'NOT TRUE: names are trimmed';
  assert not exists (select 1 from public.shivonne_dubarry_openings() where starts = made.starts), 'NOT TRUE: the time is held at once';
end $$;
do $$ begin
  begin
    insert into public.shivonne_dubarry_requests (session, starts, name, email) select 'individual', max(starts), 'Ana', 'ana@example.com' from first_two;
  exception when raise_exception then return; end;
  raise exception 'NOT TRUE: one waiting request per visitor';
end $$;
do $$ begin
  update public.shivonne_dubarry_requests set status = 'accepted';
  assert (select status from public.shivonne_dubarry_requests) = 'pending', 'NOT TRUE: a visitor can''t accept their own request';
end $$;

-- another visitor
set request.jwt.claim.sub = '5d000000-0000-0000-0000-000000000002';
do $$ begin
  assert not exists (select 1 from public.shivonne_dubarry_requests), 'NOT TRUE: another visitor can''t see it';
  begin
    insert into public.shivonne_dubarry_requests (session, starts, name, email) select 'individual', min(starts), 'Ben', 'ben@example.com' from first_two;
  exception when raise_exception then
    begin
      insert into public.shivonne_dubarry_requests (session, starts, name, email) values ('individual', date_trunc('hour', now()) + interval '24 hours 30 minutes', 'Ben', 'ben@example.com');
    exception when raise_exception then return; end;
    raise exception 'NOT TRUE: nor ask for a time that isn''t a slot';
  end;
  raise exception 'NOT TRUE: nor ask for the held time';
end $$;
do $$ begin
  begin
    insert into public.shivonne_dubarry_requests (session, starts, name, email) select 'individual', max(starts), 'Ben', 'not an email' from first_two;
  exception when check_violation then return; end;
  raise exception 'NOT TRUE: an email must look like one';
end $$;

-- she answers
set request.jwt.claim.sub = '5d000000-0000-0000-0000-000000000003';
do $$ begin
  assert (select count(*) from public.shivonne_dubarry_requests) = 1, 'NOT TRUE: she sees every request';
  assert (select count(*) from public.shivonne_dubarry_week) = 7, 'NOT TRUE: she reads her week';
  update public.shivonne_dubarry_requests set status = 'declined', name = 'changed';
  assert (select name from public.shivonne_dubarry_requests) = 'Ana', 'NOT TRUE: answering changes nothing but the status';
  assert exists (select 1 from public.shivonne_dubarry_openings() o join first_two f on f.starts = o.starts having count(*) = 2),
    'NOT TRUE: declining frees the time';
  insert into public.shivonne_dubarry_blocked (starts, ends) select min(starts), max(starts) + interval '1 hour' from first_two;
  assert not exists (select 1 from public.shivonne_dubarry_openings() o join first_two f on f.starts = o.starts), 'NOT TRUE: blocked times aren''t offered';
end $$;

reset role;
reset request.jwt.claim.sub;
do $$ begin
  delete from auth.users where id = '5d000000-0000-0000-0000-000000000001';
  assert not exists (select 1 from public.shivonne_dubarry_requests), 'NOT TRUE: deleting a visitor deletes their requests';
end $$;
