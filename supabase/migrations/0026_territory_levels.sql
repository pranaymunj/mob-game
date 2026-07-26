-- 0026_territory_levels.sql — Territory levels (re-walk to level up). Run AFTER 0025.
--
-- Re-walking a loop over your OWN turf levels it up (1→5) instead of just
-- stacking area. Higher level = brighter render, a coin bonus, and a longer
-- decay window, so defending/upgrading your empire becomes its own loop.

alter table turf add column if not exists level smallint not null default 1;

-- ── claim_turf: now handles re-walk level-ups + level-scaled decay ───────────
create or replace function claim_turf(
  ring_geojson text, area_m numeric,
  mode text default 'walk', distance_m numeric default 0, duration_s numeric default 0
)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  new_id uuid; new_geom geometry; cap_mps numeric; tol numeric := 1.25;
  earned int; own_union geometry; overlap_m numeric; leveled boolean := false;
  new_part geometry; new_area numeric;
begin
  if auth.uid() is null then raise exception 'must be signed in to claim turf'; end if;

  -- Decay: abandoned turf frees up. Higher-level turf survives longer
  -- (base 30 days + 15 per level above 1).
  delete from turf
   where last_active_at < now() - (interval '30 days' + (level - 1) * interval '15 days');

  cap_mps := case mode when 'run' then 6.5 when 'cycle' then 12.0 else 2.5 end;
  if duration_s > 0 and (distance_m / duration_s) > cap_mps * tol then
    raise exception 'capture rejected: implied speed % m/s exceeds % cap',
      round(distance_m / duration_s, 1), mode;
  end if;

  new_geom := st_makevalid(st_setsrid(st_geomfromgeojson(ring_geojson), 4326));

  -- Steal overlap from OTHER players (shield-aware), as before.
  update turf set geom = st_multi(st_difference(geom, new_geom)),
                  area = st_area(st_difference(geom, new_geom)::geography)
   where owner_id <> auth.uid()
     and st_intersects(geom, new_geom)
     and (shielded_until is null or shielded_until < now());
  delete from turf where st_isempty(geom) or st_area(geom::geography) < 1;

  -- Re-walk detection: how much of this loop lies over my OWN existing turf.
  select st_union(geom) into own_union
    from turf where owner_id = auth.uid() and st_intersects(geom, new_geom);
  overlap_m := case when own_union is null then 0
                    else st_area(st_intersection(own_union, new_geom)::geography) end;

  -- If I substantially re-walked my own turf, level it up (cap 5).
  if overlap_m >= area_m * 0.4 then
    update turf set level = least(level + 1, 5), last_active_at = now()
     where owner_id = auth.uid() and st_intersects(geom, new_geom);
    leveled := true;
  end if;

  -- Only bank the genuinely-new area (the part not already mine).
  new_part := case when own_union is null then new_geom
                   else st_difference(new_geom, own_union) end;
  new_part := st_makevalid(new_part);
  new_area := case when st_isempty(new_part) then 0
                   else st_area(new_part::geography) end;

  if new_area >= 1 then
    insert into turf (owner_id, geom, area, level)
    values (auth.uid(), st_multi(new_part), new_area, 1)
    returning id into new_id;
  end if;

  update turf set last_active_at = now() where owner_id = auth.uid();

  update players p set total_area = coalesce(
    (select sum(t.area) from turf t where t.owner_id = p.id), 0) where p.id is not null;

  -- Coins: 1 per 100m² of NEW area, plus a bonus for a level-up.
  earned := greatest(0, floor(new_area / 100)::int) + (case when leveled then 50 else 0 end);
  update players set coins = coins + earned where id = auth.uid();

  insert into runs (player_id, distance, area_gained, duration, mode)
  values (auth.uid(), 0, area_m, floor(duration_s)::int, mode);

  return new_id;
end;
$$;

-- ── turf_near: expose level so the client can render it ──────────────────────
drop function if exists turf_near(double precision, double precision, double precision);
create function turf_near(lng double precision, lat double precision, radius_m double precision)
returns table (id uuid, owner_id uuid, color text, style text, level int,
               area numeric, claimed_at timestamptz, age_days int, geojson text)
language sql stable security definer set search_path = public as $$
  select t.id, t.owner_id, p.color, p.equipped_turf, t.level, t.area, t.claimed_at,
    extract(day from (now() - t.last_active_at))::int as age_days,
    st_asgeojson((st_dump(t.geom)).geom) as geojson
  from turf t join players p on p.id = t.owner_id
  where st_dwithin(t.geom::geography,
    st_setsrid(st_makepoint(lng, lat), 4326)::geography, radius_m);
$$;
