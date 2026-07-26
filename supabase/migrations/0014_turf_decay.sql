-- 0014_turf_decay.sql — Turf decay/fade. Run AFTER 0013.
-- turf_near now returns each turf's age (days since last active) so the client
-- can fade older turf. Abandoned turf (30+ days) is purged whenever anyone
-- claims, freeing it up to be reclaimed (no cron needed).

-- turf_near: add age_days (must DROP first — return signature changes).
drop function if exists turf_near(double precision, double precision, double precision);
create function turf_near(lng double precision, lat double precision, radius_m double precision)
returns table (
  id         uuid,
  owner_id   uuid,
  color      text,
  area       numeric,
  claimed_at timestamptz,
  age_days   int,
  geojson    text
)
language sql stable security definer set search_path = public as $$
  select
    t.id, t.owner_id, p.color, t.area, t.claimed_at,
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

-- claim_turf: purge abandoned turf (decay) + refresh your own turf's activity,
-- otherwise unchanged from 0007.
create or replace function claim_turf(
  ring_geojson text, area_m numeric,
  mode text default 'walk', distance_m numeric default 0, duration_s numeric default 0
)
returns uuid language plpgsql security definer set search_path = public as $$
declare new_id uuid; new_geom geometry; cap_mps numeric; tol numeric := 1.25;
begin
  if auth.uid() is null then raise exception 'must be signed in to claim turf'; end if;

  -- Decay: abandoned turf frees up for everyone.
  delete from turf where last_active_at < now() - interval '30 days';

  cap_mps := case mode when 'run' then 6.5 when 'cycle' then 12.0 else 2.5 end;
  if duration_s > 0 and (distance_m / duration_s) > cap_mps * tol then
    raise exception 'capture rejected: implied speed % m/s exceeds % cap',
      round(distance_m / duration_s, 1), mode;
  end if;

  new_geom := st_makevalid(st_setsrid(st_geomfromgeojson(ring_geojson), 4326));

  update turf set geom = st_multi(st_difference(geom, new_geom)),
                  area = st_area(st_difference(geom, new_geom)::geography)
   where st_intersects(geom, new_geom)
     and (shielded_until is null or shielded_until < now());
  delete from turf where st_isempty(geom) or st_area(geom::geography) < 1;

  insert into turf (owner_id, geom, area)
  values (auth.uid(), st_multi(new_geom), area_m)
  returning id into new_id;

  -- Refresh activity on all of this owner's turf so playing keeps it alive.
  update turf set last_active_at = now() where owner_id = auth.uid();

  update players p set total_area = coalesce(
    (select sum(t.area) from turf t where t.owner_id = p.id), 0) where p.id is not null;

  insert into runs (player_id, distance, area_gained, duration, mode)
  values (auth.uid(), distance_m, area_m, floor(duration_s)::int, mode);

  return new_id;
end;
$$;
