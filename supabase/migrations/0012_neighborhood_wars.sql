-- 0012_neighborhood_wars.sql — Phase 8 layer 8: Neighborhood Wars (zone control).
-- Run AFTER 0011. The world is a grid of ~1km cells; whoever holds the most
-- turf area in a cell "controls" that neighborhood. Returns the controlling
-- owner (+ color) per cell near the viewport.

create or replace function zones_near(p_lng double precision, p_lat double precision, radius_m double precision)
returns table (cx int, cy int, owner_id uuid, color text, area numeric)
language sql stable security definer set search_path = public as $$
  with cells as (
    -- Snap each turf polygon to the grid cell of its centroid (0.01° ≈ 1 km).
    select floor(st_x(st_centroid(t.geom)) / 0.01)::int as cx,
           floor(st_y(st_centroid(t.geom)) / 0.01)::int as cy,
           t.owner_id,
           t.area
    from turf t
    where st_dwithin(
      t.geom::geography,
      st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography,
      radius_m
    )
  ),
  agg as (
    select cx, cy, owner_id, sum(area) as area,
           row_number() over (partition by cx, cy order by sum(area) desc) as rn
    from cells
    group by cx, cy, owner_id
  )
  select a.cx, a.cy, a.owner_id, p.color, a.area
  from agg a
  join players p on p.id = a.owner_id
  where a.rn = 1; -- the dominant owner in each cell
$$;
