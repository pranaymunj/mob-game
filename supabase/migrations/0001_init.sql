-- 0001_init.sql — Claimr initial schema (players, turf, runs) with PostGIS.
-- Run this in the Supabase SQL editor (or via the CLI) for your project.
-- Turf is stored as geo-polygons; spatial queries use PostGIS (CLAUDE.md Part 4).

-- PostGIS gives us geometry types + spatial indexes/queries.
create extension if not exists postgis;

-- ── players ────────────────────────────────────────────────────────────────
-- One row per account. id matches the Supabase auth user id.
create table if not exists players (
  id           uuid primary key references auth.users (id) on delete cascade,
  display_name text        not null default 'Player',
  color        text        not null default '#56B4E9', -- hex, colorblind-safe default
  total_area   numeric     not null default 0,          -- sq meters held
  created_at   timestamptz not null default now()
);

-- ── turf ───────────────────────────────────────────────────────────────────
-- A claimed polygon owned by a player. geom is a WGS84 polygon (lng/lat).
create table if not exists turf (
  id             uuid primary key default gen_random_uuid(),
  owner_id       uuid not null references players (id) on delete cascade,
  geom           geometry(Polygon, 4326) not null,
  area           numeric not null default 0,          -- sq meters
  claimed_at     timestamptz not null default now(),
  last_active_at timestamptz not null default now()   -- for turf-fade later
);

-- Spatial index so "turf near me" queries stay cheap.
create index if not exists turf_geom_gist on turf using gist (geom);
create index if not exists turf_owner_idx on turf (owner_id);

-- ── runs ───────────────────────────────────────────────────────────────────
-- One row per gameplay run — for stats and anti-cheat (Phase 6).
create table if not exists runs (
  id          uuid primary key default gen_random_uuid(),
  player_id   uuid not null references players (id) on delete cascade,
  distance    numeric not null default 0,   -- meters
  area_gained numeric not null default 0,   -- sq meters
  duration    integer not null default 0,   -- seconds
  started_at  timestamptz not null default now(),
  mode        text not null default 'walk'  -- walk | run | cycle
);

-- ── Auto-create a players row when a new auth user signs up ──────────────────
create or replace function handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into players (id) values (new.id)
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- ── turf_near: only return turf within `radius_m` meters of a point ──────────
-- Keeps reads cheap by querying just the player's viewport (ST_DWithin).
-- Returns geometry as GeoJSON so the Flutter client can parse it directly.
create or replace function turf_near(lng double precision, lat double precision, radius_m double precision)
returns table (
  id         uuid,
  owner_id   uuid,
  area       numeric,
  claimed_at timestamptz,
  geojson    text
)
language sql
stable
as $$
  select t.id, t.owner_id, t.area, t.claimed_at, st_asgeojson(t.geom) as geojson
  from turf t
  where st_dwithin(
    t.geom::geography,
    st_setsrid(st_makepoint(lng, lat), 4326)::geography,
    radius_m
  );
$$;

-- ── claim_turf: insert a new claim from a GeoJSON polygon ────────────────────
-- The client sends the ring as GeoJSON; the server builds the geometry and
-- stamps the owner from the auth token (never trust a client-supplied owner).
create or replace function claim_turf(ring_geojson text, area_m numeric)
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  new_id uuid;
begin
  if auth.uid() is null then
    raise exception 'must be signed in to claim turf';
  end if;

  insert into turf (owner_id, geom, area)
  values (
    auth.uid(),
    st_setsrid(st_geomfromgeojson(ring_geojson), 4326),
    area_m
  )
  returning id into new_id;

  update players set total_area = total_area + area_m where id = auth.uid();
  return new_id;
end;
$$;

-- ── Row Level Security ───────────────────────────────────────────────────────
alter table players enable row level security;
alter table turf    enable row level security;
alter table runs    enable row level security;

-- Turf is public to read (it's a shared world map) but only the owner writes.
create policy "turf readable by all"        on turf for select using (true);
create policy "turf insert by owner"        on turf for insert with check (auth.uid() = owner_id);
create policy "turf update/delete by owner" on turf for update using (auth.uid() = owner_id);
create policy "turf delete by owner"        on turf for delete using (auth.uid() = owner_id);

-- Players readable by all (leaderboard); each user manages only their own row.
create policy "players readable by all" on players for select using (true);
create policy "players update own"      on players for update using (auth.uid() = id);

-- Runs are private to their owner.
create policy "runs readable by owner" on runs for select using (auth.uid() = player_id);
create policy "runs insert by owner"   on runs for insert with check (auth.uid() = player_id);
