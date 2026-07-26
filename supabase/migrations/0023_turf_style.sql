-- 0023_turf_style.sql — Expose each turf owner's equipped turf style so the
-- map can render it. Run AFTER 0022. This is the cosmetic other players
-- actually see, so it's the real flex — worth wiring end to end.

drop function if exists turf_near(double precision, double precision, double precision);
create function turf_near(lng double precision, lat double precision, radius_m double precision)
returns table (
  id         uuid,
  owner_id   uuid,
  color      text,
  style      text,     -- owner's equipped turf style (turf_solid/outline/glow/hatch)
  area       numeric,
  claimed_at timestamptz,
  age_days   int,
  geojson    text
)
language sql stable security definer set search_path = public as $$
  select
    t.id, t.owner_id, p.color, p.equipped_turf,
    t.area, t.claimed_at,
    extract(day from (now() - t.last_active_at))::int as age_days,
    st_asgeojson((st_dump(t.geom)).geom) as geojson
  from turf t
  join players p on p.id = t.owner_id
  where st_dwithin(
    t.geom::geography,
    st_setsrid(st_makepoint(lng, lat), 4326)::geography,
    radius_m
  );
$$;
