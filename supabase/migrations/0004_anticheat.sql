-- 0004_anticheat.sql — Phase 6: server-side speed gating + run logging, and a
-- GDPR data-delete. Run AFTER 0003. The server is the source of truth for
-- fairness (CLAUDE.md Part 5) — never trust the client.

-- ── claim_turf: now validates implied speed and logs a run ───────────────────
-- The client sends the loop's mode, perimeter (distance_m) and duration_s.
-- If distance/duration exceeds the mode's cap (with a small tolerance), the
-- capture is rejected. On success we also insert a runs row for stats.
create or replace function claim_turf(
  ring_geojson text,
  area_m       numeric,
  mode         text default 'walk',
  distance_m   numeric default 0,
  duration_s   numeric default 0
)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  new_id     uuid;
  new_geom   geometry;
  cap_mps    numeric;
  tol        numeric := 1.25; -- 25% headroom for GPS noise
begin
  if auth.uid() is null then
    raise exception 'must be signed in to claim turf';
  end if;

  -- Speed cap per mode (meters/second).
  cap_mps := case mode
    when 'run'   then 6.5
    when 'cycle' then 12.0
    else 2.5 -- walk
  end;

  -- Reject implausibly fast captures (spoofing / driving).
  if duration_s > 0 and (distance_m / duration_s) > cap_mps * tol then
    raise exception 'capture rejected: implied speed % m/s exceeds % cap',
      round(distance_m / duration_s, 1), mode;
  end if;

  new_geom := st_makevalid(st_setsrid(st_geomfromgeojson(ring_geojson), 4326));

  -- Steal: carve the new claim out of any overlapping turf.
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

  insert into runs (player_id, distance, area_gained, duration, mode)
  values (auth.uid(), distance_m, area_m, floor(duration_s)::int, mode);

  return new_id;
end;
$$;

-- ── delete_my_data: GDPR/CCPA — erase everything tied to this account ─────────
-- Removes the player's turf, runs, and profile row (turf/runs also cascade
-- from the players delete). The client then signs out.
create or replace function delete_my_data()
returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then
    raise exception 'must be signed in';
  end if;
  delete from turf   where owner_id  = auth.uid();
  delete from runs   where player_id = auth.uid();
  delete from players where id        = auth.uid();
end;
$$;
