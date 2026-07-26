-- 0021_finish_run.sql — Walking always pays. Run AFTER 0020.
--
-- Two problems this fixes:
--   1. Runs were only written inside claim_turf(), so a walk that never closed
--      a loop recorded nothing at all — no distance, no coins, no history.
--      Since loop capture is the hard part, players could walk for ages and
--      earn literally nothing.
--   2. The client sends the WHOLE session distance on every capture, so two
--      captures in one run double-counted the distance.
--
-- Now: captures log area only (distance 0), and finish_run() logs the session's
-- distance once, at the end, awarding coins for it.

-- ── finish_run: called when a run stops, capture or not ─────────────────────
create or replace function finish_run(
  distance_m numeric,
  duration_s numeric default 0,
  mode text default 'walk'
)
returns int language plpgsql security definer set search_path = public as $$
declare cap_mps numeric; tol numeric := 1.25; earned int;
begin
  if auth.uid() is null then raise exception 'must be signed in'; end if;
  if distance_m <= 0 then return 0; end if;

  -- Same anti-cheat gate as claiming: no coins for impossible speeds.
  cap_mps := case mode when 'run' then 6.5 when 'cycle' then 12.0 else 2.5 end;
  if duration_s > 0 and (distance_m / duration_s) > cap_mps * tol then
    raise exception 'run rejected: implied speed % m/s exceeds % cap',
      round(distance_m / duration_s, 1), mode;
  end if;

  -- 1 coin per 50m walked. Deliberately less lucrative than capturing
  -- (1 per 100m²) so claiming turf stays the better play.
  earned := floor(distance_m / 50)::int;
  update players set coins = coins + earned where id = auth.uid();

  insert into runs (player_id, distance, area_gained, duration, mode)
  values (auth.uid(), distance_m, 0, floor(duration_s)::int, mode);

  return earned;
end;
$$;

-- ── claim_turf: log area only; distance is credited by finish_run ───────────
create or replace function claim_turf(
  ring_geojson text, area_m numeric,
  mode text default 'walk', distance_m numeric default 0, duration_s numeric default 0
)
returns uuid language plpgsql security definer set search_path = public as $$
declare new_id uuid; new_geom geometry; cap_mps numeric; tol numeric := 1.25; earned int;
begin
  if auth.uid() is null then raise exception 'must be signed in to claim turf'; end if;

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
  values (auth.uid(), st_multi(new_geom), area_m) returning id into new_id;

  update turf set last_active_at = now() where owner_id = auth.uid();

  update players p set total_area = coalesce(
    (select sum(t.area) from turf t where t.owner_id = p.id), 0) where p.id is not null;

  earned := greatest(0, floor(area_m / 100)::int);
  update players set coins = coins + earned where id = auth.uid();

  -- distance 0: finish_run() credits the session's distance once, at the end.
  insert into runs (player_id, distance, area_gained, duration, mode)
  values (auth.uid(), 0, area_m, floor(duration_s)::int, mode);

  return new_id;
end;
$$;

-- ── challenge_status: "loops" must count captures, not finish_run rows ──────
create or replace function challenge_status()
returns table (metric text, target numeric, label text, progress numeric, completed boolean)
language plpgsql stable security definer set search_path = public as $$
declare
  d int := (extract(epoch from current_date) / 86400)::int % 3;
  m text; tg numeric; lb text; pg numeric;
begin
  if auth.uid() is null then raise exception 'must be signed in'; end if;

  if d = 0 then m := 'area';     tg := 3000; lb := 'Claim 3,000 m² of turf today';
  elsif d = 1 then m := 'loops'; tg := 3;    lb := 'Close 3 loops today';
  else m := 'distance';          tg := 2000; lb := 'Walk 2 km during runs today';
  end if;

  if m = 'area' then
    select coalesce(sum(area_gained), 0) into pg
      from runs where player_id = auth.uid() and started_at::date = current_date;
  elsif m = 'loops' then
    -- only rows with area are actual captures
    select count(*) into pg
      from runs where player_id = auth.uid() and started_at::date = current_date
        and area_gained > 0;
  else
    select coalesce(sum(distance), 0) into pg
      from runs where player_id = auth.uid() and started_at::date = current_date;
  end if;

  return query select m, tg, lb, pg, pg >= tg;
end;
$$;
