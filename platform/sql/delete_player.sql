-- Deleting a player everywhere. Each tenant provides one function in its
-- schema,
--   <schema>.forget_player(player uuid) returns void
-- which removes or anonymises everything it holds for that player, and may
-- queue anything outside the database (files on disk) for its own service.
-- The platform calls every tenant's function, then removes the player's
-- sign-in, all in one transaction: if any tenant's function raises an error,
-- or a tenant hasn't provided one yet, nothing is deleted and the request is
-- tried again later. So a tenant's function must be quick (well under the
-- 30 s statement limit), safe to run twice, and succeed for a player it has
-- never seen.
-- Run by the factory as supabase_admin; safe to run again.

\set ON_ERROR_STOP on

create schema if not exists platform authorization supabase_admin;

-- The tenants: each one's schema holds its forget_player.
create table if not exists platform.tenants (
  schema_name name primary key
);
revoke all on platform.tenants from public;

create or replace function platform.delete_player(player uuid) returns void
language plpgsql security definer set search_path = pg_catalog as $$
declare
  tenant record;
begin
  for tenant in select schema_name from platform.tenants order by schema_name loop
    if to_regprocedure(format('%I.forget_player(uuid)', tenant.schema_name)) is null then
      raise exception 'tenant % has not provided %.forget_player(uuid); nothing was deleted', tenant.schema_name, tenant.schema_name;
    end if;
    execute format('select %I.forget_player($1)', tenant.schema_name) using player;
  end loop;
  delete from auth.users where id = player;
end $$;

-- Called by the platform's own server code with the service key, never by a client.
revoke all on function platform.delete_player(uuid) from public;
grant usage on schema platform to service_role;
grant execute on function platform.delete_player(uuid) to service_role;
