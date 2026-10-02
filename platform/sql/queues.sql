-- Queues for tenants. pgmq (Supabase Queues) keeps every queue's tables in
-- its own schema and only the extension's owner may create one, so a tenant
-- asks this function, which creates the queue and hands its tables over:
--   select platform.create_queue('lizarding_moves');
-- A tenant's queues are named after its login role (lizarding_*), and only it
-- is granted their tables, so no other tenant can read, write or drop them.
-- Sending, reading and archiving are pgmq's own functions, called as the
-- tenant. (Supabase gives whatever its admin creates to the postgres role, so
-- the tables stay postgres's; the tenant has the rights to use them.)
-- Run by the factory as supabase_admin; safe to run again.

\set ON_ERROR_STOP on

create extension if not exists pgmq;
create schema if not exists platform authorization supabase_admin;

create or replace function platform.create_queue(queue_name text) returns void
language plpgsql security definer set search_path = pg_catalog as $$
declare
  tenant text := session_user;
begin
  if queue_name !~ ('^' || tenant || '_[a-z0-9_]{1,40}$') then
    raise exception 'a queue of % must be named %_<lower-case letters, digits, _>', tenant, tenant;
  end if;
  perform pgmq.create(queue_name);
  execute format('grant select, insert, update, delete on pgmq.%I, pgmq.%I to %I', 'q_' || queue_name, 'a_' || queue_name, tenant);
  execute format('grant usage, select, update on sequence pgmq.%I to %I', 'q_' || queue_name || '_msg_id_seq', tenant);
end $$;

create or replace function platform.drop_queue(queue_name text) returns boolean
language plpgsql security definer set search_path = pg_catalog as $$
begin
  if queue_name !~ ('^' || session_user || '_') then
    raise exception 'only a queue named %_* can be dropped by %', session_user, session_user;
  end if;
  return pgmq.drop_queue(queue_name);
end $$;

revoke all on function platform.create_queue(text), platform.drop_queue(text) from public;
