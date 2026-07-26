-- 0002_stealing.sql — Phase 5: turf stealing (ST_Difference), per-player
-- colors, and turf_near returning owner colors for rendering.
-- Run this in the Supabase SQL editor AFTER 0001_init.sql.

-- Stealing carves overlaps out of existing turf, which can turn a Polygon into
-- a MultiPolygon. Store everything as MultiPolygon so results always fit.
alter table turf
  alter column geom type geometry(MultiPolygon, 4326) using st_multi(geom);

-- ── Give each new player a distinct colorblind-safe color (Okabe–Ito) ─────────
create or replace function handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare
  n int;
  hexes text[] := array[
    '#E69F00','#56B4E9','#009E73','#F0E442','#0072B2','#D55E00','#CC79A7'
  ];
begin
  select count(*) into n from players;
  insert into players (id, color) values (new.id, hexes[(n % 7) + 1])
  on conflict (id) do nothing;
  return new;
end;
$$;

-- ── turf_near: now also returns each turf's owner color, and explodes any ─────
-- MultiPolygon into individual polygons so the client renders simple rings.
drop function if exists turf_near(double precision, double precision, double precision);
create function turf_near(lng double precision, lat double precision, radius_m double precision)
returns table (
  id         uuid,
  owner_id   uuid,
  color      text,
  area       numeric,
  claimed_at timestamptz,
  geojson    text
)
language sql
stable
as $$
  select
    t.id,
    t.owner_id,
    p.color,
    t.area,
    t.claimed_at,
    st_asgeojson((st_dump(t.geom)).geom) as geojson
  from turf t
  join players p on p.id = t.owner_id
  where st_dwithin(
    t.geom::geography,
    st_setsrid(st_makepoint(lng, lat), 4326)::geography,
    radius_m
  );
$$;

-- ── claim_turf: insert my claim AND steal overlap from everyone else ──────────
-- All in one server-side function (a single transaction): carve the new claim
-- out of every intersecting turf (mine and rivals'), delete anything fully
-- consumed, insert my new claim, then recompute affected totals.
create or replace function claim_turf(ring_geojson text, area_m numeric)
returns uuid
language plpgsql
security definer set search_path = public
as $$
declare
  new_id   uuid;
  new_geom geometry;
begin
  if auth.uid() is null then
    raise exception 'must be signed in to claim turf';
  end if;

  new_geom := st_makevalid(st_setsrid(st_geomfromgeojson(ring_geojson), 4326));

  -- 1. Carve the new claim out of any existing turf it overlaps (steal).
  update turf
     set geom = st_multi(st_difference(geom, new_geom)),
         area = st_area(st_difference(geom, new_geom)::geography)
   where st_intersects(geom, new_geom);

  -- 2. Drop turf that got fully consumed (empty or slivers < 1 m²).
  delete from turf
   where st_isempty(geom) or st_area(geom::geography) < 1;

  -- 3. Insert my new claim.
  insert into turf (owner_id, geom, area)
  values (auth.uid(), st_multi(new_geom), area_m)
  returning id into new_id;

  -- 4. Recompute total_area for every player (cheap at MVP scale).
  --    The WHERE (always true) satisfies Supabase's "no unqualified UPDATE" guard.
  update players p
     set total_area = coalesce(
       (select sum(t.area) from turf t where t.owner_id = p.id), 0)
   where p.id is not null;

  return new_id;
end;
$$;
