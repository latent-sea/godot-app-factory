-- Steam accounts and the players they belong to, for the steam-signin
-- function (functions/steam-signin). One Steam account is one player; a
-- player's Steam account goes when the player does. Only the platform's
-- service role reaches it, through the two functions below.
-- Run by the factory as supabase_admin; safe to run again.

\set ON_ERROR_STOP on

create schema if not exists platform authorization supabase_admin;

create table if not exists platform.steam_accounts (
  steam_id text primary key,
  player uuid not null references auth.users (id) on delete cascade,
  linked_at timestamptz not null default now()
);
revoke all on platform.steam_accounts from public;

-- The player a Steam account belongs to, or null.
create or replace function public.platform_steam_player(steam_id text) returns uuid
language sql stable security definer set search_path = pg_catalog as $$
  select s.player from platform.steam_accounts s where s.steam_id = platform_steam_player.steam_id
$$;

-- Records a Steam account as a player's; false if it already belongs to someone.
create or replace function public.platform_link_steam(steam_id text, player uuid) returns boolean
language plpgsql security definer set search_path = pg_catalog as $$
begin
  insert into platform.steam_accounts (steam_id, player) values (steam_id, player)
  on conflict do nothing;
  return found;
end $$;

-- The data API exposes public functions to every role by default; these are the service role's alone.
revoke all on function public.platform_steam_player(text), public.platform_link_steam(text, uuid) from public, anon, authenticated;
grant execute on function public.platform_steam_player(text), public.platform_link_steam(text, uuid) to service_role;
