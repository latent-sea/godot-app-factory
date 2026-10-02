-- Run as Lizarding after setup, to see its walls hold:
--   psql "$DATABASE_URL" -f lizarding_walls.sql      (DATABASE_URL from ~/.platform/db.env)
-- The first part must work; every statement after "MUST FAIL" must fail.
\set ON_ERROR_STOP off
\echo == works: its own schema and queues
create table if not exists lizarding.walls_check (id int);
insert into lizarding.walls_check values (1);
select count(*) as own_rows from lizarding.walls_check;
select platform.create_queue('lizarding_walls_check');
select pgmq.send('lizarding_walls_check', '{"ok": true}');
select message from pgmq.read('lizarding_walls_check', 30, 1);
select platform.drop_queue('lizarding_walls_check');
drop table lizarding.walls_check;
\echo == MUST FAIL: everything below
select count(*) from auth.users;
create table public.walls_check (x int);
select platform.create_queue('factory_walls_check');
select platform.delete_player(gen_random_uuid());
create role walls_check;
set role postgres;
