-- Lizarding, a tenant of the shared platform: one login role that owns one
-- schema and nothing else. Run once by tenants/add-tenant.sh, as the
-- platform's admin (supabase_admin), after sql/queues.sql and
-- sql/delete_player.sql. Everything inside the schema is Lizarding's; the
-- factory never edits it.

\set ON_ERROR_STOP on

-- The role: logs in, owns its schema, can't create roles or databases, and
-- holds at most 20 connections at once.
create role lizarding login password :'tenant_password'
  nosuperuser nocreatedb nocreaterole noinherit noreplication nobypassrls
  connection limit 20;

-- Its schema, owned by it: tables, rules (row-level security), functions.
create schema lizarding authorization lizarding;

-- Where unqualified names resolve, and the limits on any one statement or a
-- transaction left idle, so a stuck query can't hold locks for long.
alter role lizarding set search_path = lizarding, extensions;
alter role lizarding set statement_timeout = '30s';
alter role lizarding set idle_in_transaction_session_timeout = '60s';
alter role lizarding set lock_timeout = '10s';

-- Nothing of the platform's: no use of the auth, storage or realtime schemas,
-- and no rights on the apps' tables (Supabase grants those to its own roles,
-- never to PUBLIC, so a new role starts with none).
revoke all on schema auth, storage, realtime from lizarding;
revoke create on schema public from lizarding;

-- Queues (Supabase Queues): created and dropped through the platform's
-- functions (sql/queues.sql), named lizarding_*, used only by Lizarding;
-- sending, reading and archiving with pgmq's own functions.
grant usage on schema platform, pgmq to lizarding;
grant execute on function platform.create_queue(text), platform.drop_queue(text) to lizarding;
grant execute on all functions in schema pgmq to lizarding;

-- Deleting a player: the platform calls lizarding.forget_player(uuid), which
-- Lizarding writes as a security definer function it owns
-- (sql/delete_player.sql says what it must do).
insert into platform.tenants values ('lizarding') on conflict do nothing;
