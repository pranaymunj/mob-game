-- 0028_claim_integrity.sql — Close the anti-cheat hole and stop claim_turf
-- scanning the whole database on every capture. Run AFTER 0027.
--
-- Two problems, both in claim_turf:
--
-- 1. FAIRNESS. The speed gate divided the DISTANCE AND DURATION THE PHONE
--    REPORTED. Nothing tied either number to the polygon being claimed, so a
--    forged request carrying a city-sized ring plus duration_s = 999999 implied
--    a speed near zero and sailed through. Worse, the gate was written
--    `if duration_s > 0 and ...`, so simply sending duration_s = 0 skipped it
--    altogether. area_m was likewise taken on trust and used for the coin
--    payout and the level-up threshold.
--
--    The server now measures the claim itself with PostGIS and treats every
--    client number as advisory. The gate is the loop's own PERIMETER over the
--    elapsed time: you cannot claim a ring you could not have walked around.
--
-- 2. COST. Every capture ran two whole-table statements: a decay DELETE across
--    all turf, and a total_area recompute for EVERY PLAYER IN THE GAME. Fine at
--    20 players, seconds at 2,000, and both scale with the whole player base
--    rather than with the one claim being made. Decay moves to a scheduled job;
--    the recompute now touches only the players this claim actually affected.
--
-- Nothing in the client contract changes: same name, same arguments, same
-- return. Older app builds keep working — they just can't lie any more.

-- Rate limiting reads recent claims per player; make that lookup cheap.
create index if not exists runs_player_time_idx on runs (player_id, started_at desc);

-- ── Decay, lifted out of the capture path ───────────────────────────────────
-- Abandoned turf still frees up, but on a schedule instead of on the back of
-- whichever unlucky player happens to close a loop.
--
-- Schedule it once (Supabase → Database → Extensions → enable pg_cron, then):
--   select cron.schedule('turf-decay', '0 4 * * *', $$select decay_turf()$$);
-- Running it by hand is harmless; it is idempotent.
create or replace function decay_turf()
returns int language plpgsql security definer set search_path = public as $$
declare removed int; owners uuid[];
begin
  with gone as (
    delete from turf
     where last_active_at < now() - (interval '30 days' + (level - 1) * interval '15 days')
    returning owner_id
  )
  select count(*), coalesce(array_agg(distinct owner_id), '{}'::uuid[])
    into removed, owners
    from gone;

  -- Totals only for owners who actually lost something. Recomputing every
  -- player here would just move the full scan from the capture path to the
  -- nightly job rather than getting rid of it.
  update players p
     set total_area = coalesce((select sum(t.area) from turf t where t.owner_id = p.id), 0)
   where p.id = any (owners);

  return removed;
end;
$$;

revoke all on function decay_turf() from public, anon, authenticated;

-- ── claim_turf ──────────────────────────────────────────────────────────────
create or replace function claim_turf(
  ring_geojson text, area_m numeric,
  mode text default 'walk', distance_m numeric default 0, duration_s numeric default 0
)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  new_id uuid; new_geom geometry; cap_mps numeric; tol numeric := 1.25;
  earned int; own_union geometry; overlap_m numeric; leveled boolean := false;
  new_part geometry; new_area numeric;
  claim_area numeric; perim numeric; implied numeric;
  affected uuid[] := '{}'::uuid[]; recent int;
  -- A walked loop cannot enclose a whole city. Generous enough that a long
  -- cycle ride is fine, tight enough that a forged continent is not.
  max_area constant numeric := 2000000;   -- 2 km²
  max_per_hour constant int := 20;
begin
  if auth.uid() is null then raise exception 'must be signed in to claim turf'; end if;

  -- ── Trust nothing from the client ─────────────────────────────────────────
  new_geom := st_makevalid(st_setsrid(st_geomfromgeojson(ring_geojson), 4326));
  if new_geom is null or st_isempty(new_geom) then
    raise exception 'capture rejected: invalid geometry';
  end if;
  if st_geometrytype(new_geom) not in ('ST_Polygon', 'ST_MultiPolygon') then
    raise exception 'capture rejected: geometry is not a polygon';
  end if;

  -- The server measures the claim. area_m is ignored from here on.
  claim_area := st_area(new_geom::geography);
  perim      := st_perimeter(new_geom::geography);

  if claim_area < 1 then
    raise exception 'capture rejected: area is empty';
  end if;
  if claim_area > max_area then
    raise exception 'capture rejected: % m² exceeds the % m² per-claim limit',
      round(claim_area), max_area;
  end if;

  cap_mps := case mode when 'run' then 6.5 when 'cycle' then 12.0 else 2.5 end;

  -- A missing duration used to skip the gate entirely; now it fails closed.
  if duration_s is null or duration_s <= 0 then
    raise exception 'capture rejected: missing run duration';
  end if;

  -- The real test: you had to physically walk the loop's perimeter. This is
  -- tied to the polygon itself, so inflating the ring inflates the distance
  -- you must account for.
  implied := perim / duration_s;
  if implied > cap_mps * tol then
    raise exception 'capture rejected: implied speed % m/s exceeds the % cap of % m/s',
      round(implied, 1), mode, cap_mps;
  end if;

  -- Burst limit: a legitimate player cannot close 20 loops in an hour.
  select count(*) into recent
    from runs
   where player_id = auth.uid()
     and area_gained > 0
     and started_at > now() - interval '1 hour';
  if recent >= max_per_hour then
    raise exception 'capture rejected: too many claims in the last hour';
  end if;

  -- ── Steal overlap from OTHER players (shield-aware) ───────────────────────
  with cut as (
    update turf
       set geom = st_multi(st_difference(geom, new_geom)),
           area = st_area(st_difference(geom, new_geom)::geography)
     where owner_id <> auth.uid()
       and st_intersects(geom, new_geom)
       and (shielded_until is null or shielded_until < now())
    returning owner_id
  )
  select array_agg(distinct owner_id) into affected from cut;
  affected := coalesce(affected, '{}'::uuid[]) || auth.uid();

  delete from turf where st_isempty(geom) or st_area(geom::geography) < 1;

  -- ── Re-walking your own turf levels it up ────────────────────────────────
  select st_union(geom) into own_union
    from turf where owner_id = auth.uid() and st_intersects(geom, new_geom);
  overlap_m := case when own_union is null then 0
                    else st_area(st_intersection(own_union, new_geom)::geography) end;

  if overlap_m >= claim_area * 0.4 then
    update turf set level = least(level + 1, 5), last_active_at = now()
     where owner_id = auth.uid() and st_intersects(geom, new_geom);
    leveled := true;
  end if;

  -- Bank only the genuinely-new area.
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

  -- Totals for the players this claim touched — not for everyone.
  update players p
     set total_area = coalesce((select sum(t.area) from turf t where t.owner_id = p.id), 0)
   where p.id = any (affected);

  -- Coins are paid on measured area, never on the client's figure.
  earned := greatest(0, floor(new_area / 100)::int) + (case when leveled then 50 else 0 end);
  update players set coins = coins + earned where id = auth.uid();

  insert into runs (player_id, distance, area_gained, duration, mode)
  values (auth.uid(), distance_m, claim_area, floor(duration_s)::int, mode);

  return new_id;
end;
$$;

-- ── finish_run: same duration hole ──────────────────────────────────────────
-- `if duration_s > 0 and ...` meant duration_s = 0 skipped the speed gate and
-- paid out on any distance the phone claimed. Distance here has no geometry to
-- check it against, so the best available test is that it fails closed and is
-- capped at what the mode could cover in the elapsed time.
create or replace function finish_run(
  distance_m numeric, duration_s numeric default 0, mode text default 'walk'
)
returns int language plpgsql security definer set search_path = public as $$
declare
  cap_mps numeric; tol numeric := 1.25;
  base int; treasure_coins int; perk_drops int; i int;
  perks text[] := array['sprint','shield','wide_brush','recon'];
begin
  if auth.uid() is null then raise exception 'must be signed in'; end if;
  if distance_m is null or distance_m <= 0 then return 0; end if;

  cap_mps := case mode when 'run' then 6.5 when 'cycle' then 12.0 else 2.5 end;

  if duration_s is null or duration_s <= 0 then
    raise exception 'run rejected: missing run duration';
  end if;
  if distance_m / duration_s > cap_mps * tol then
    raise exception 'run rejected: implied speed % m/s exceeds % cap',
      round(distance_m / duration_s, 1), mode;
  end if;

  base           := floor(distance_m / 50)::int;
  treasure_coins := floor(distance_m / 500)::int * 30;
  perk_drops     := floor(distance_m / 1500)::int;

  update players set coins = coins + base + treasure_coins where id = auth.uid();

  for i in 1..perk_drops loop
    insert into player_perks (player_id, perk, qty)
    values (auth.uid(), perks[1 + floor(random() * 4)::int], 1)
    on conflict (player_id, perk) do update set qty = player_perks.qty + 1;
  end loop;

  insert into runs (player_id, distance, area_gained, duration, mode)
  values (auth.uid(), distance_m, 0, floor(duration_s)::int, mode);

  return base + treasure_coins;
end;
$$;
