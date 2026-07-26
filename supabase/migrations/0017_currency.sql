-- 0017_currency.sql — Coins: the game's soft currency. Run AFTER 0016.
--
-- Earned by claiming turf (1 coin per 100 m²) and spent in the shop on perks.
-- Both the award and the spend happen server-side so the client can never
-- mint or discount anything.

alter table players add column if not exists coins int not null default 0;

-- ── claim_turf: now also awards coins for the area claimed ───────────────────
-- Otherwise identical to 0014 (decay purge, shield-aware steal, speed gate).
create or replace function claim_turf(
  ring_geojson text, area_m numeric,
  mode text default 'walk', distance_m numeric default 0, duration_s numeric default 0
)
returns uuid language plpgsql security definer set search_path = public as $$
declare new_id uuid; new_geom geometry; cap_mps numeric; tol numeric := 1.25; earned int;
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

  update turf set last_active_at = now() where owner_id = auth.uid();

  update players p set total_area = coalesce(
    (select sum(t.area) from turf t where t.owner_id = p.id), 0) where p.id is not null;

  -- Coins: 1 per 100 m² claimed, computed from the server-validated area.
  earned := greatest(0, floor(area_m / 100)::int);
  update players set coins = coins + earned where id = auth.uid();

  insert into runs (player_id, distance, area_gained, duration, mode)
  values (auth.uid(), distance_m, area_m, floor(duration_s)::int, mode);

  return new_id;
end;
$$;

-- ── buy_perk: spend coins on a perk ──────────────────────────────────────────
-- Prices live here, not on the client, so they can't be tampered with.
create or replace function buy_perk(perk_key text)
returns int language plpgsql security definer set search_path = public as $$
declare price int; have int;
begin
  if auth.uid() is null then raise exception 'must be signed in'; end if;

  price := case perk_key
             when 'sprint'     then 50
             when 'recon'      then 75
             when 'wide_brush' then 100
             when 'shield'     then 150
             else null
           end;
  if price is null then raise exception 'unknown perk %', perk_key; end if;

  select coins into have from players where id = auth.uid();
  if coalesce(have, 0) < price then
    raise exception 'not enough coins: need %, you have %', price, coalesce(have, 0);
  end if;

  update players set coins = coins - price where id = auth.uid();

  insert into player_perks (player_id, perk, qty) values (auth.uid(), perk_key, 1)
    on conflict (player_id, perk) do update set qty = player_perks.qty + 1;

  return have - price; -- remaining balance
end;
$$;
