-- 0003_fix_claim_where.sql — Fix: Supabase blocks UPDATE without a WHERE clause
-- (error 21000). The players total_area recompute in claim_turf needed a WHERE.
-- Run AFTER 0002. (0002 in the repo is already corrected; this is the delta for
-- databases that ran the earlier version.)

create or replace function claim_turf(ring_geojson text, area_m numeric)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  new_id uuid;
  new_geom geometry;
begin
  if auth.uid() is null then
    raise exception 'must be signed in to claim turf';
  end if;
  new_geom := st_makevalid(st_setsrid(st_geomfromgeojson(ring_geojson), 4326));

  update turf
     set geom = st_multi(st_difference(geom, new_geom)),
         area = st_area(st_difference(geom, new_geom)::geography)
   where st_intersects(geom, new_geom);

  delete from turf where st_isempty(geom) or st_area(geom::geography) < 1;

  insert into turf (owner_id, geom, area)
  values (auth.uid(), st_multi(new_geom), area_m)
  returning id into new_id;

  update players p
     set total_area = coalesce(
       (select sum(t.area) from turf t where t.owner_id = p.id), 0)
   where p.id is not null;

  return new_id;
end;
$$;
