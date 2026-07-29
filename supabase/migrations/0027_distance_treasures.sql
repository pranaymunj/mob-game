-- 0027_distance_treasures.sql — Reward distance walked with "treasures".
-- Run AFTER 0026.
--
-- Every 500m walked in a run is a treasure: +30 bonus coins on top of the base
-- walking coins, and every 1500m also drops a random perk. This rewards free
-- roaming (no loop required) — replacing the hand-holding first-run tutorial
-- with "just walk and you'll be rewarded".
--
-- Kept server-side (in finish_run) so the rewards can't be forged. Return type
-- is unchanged (total coins), so no client contract change.

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
  if distance_m <= 0 then return 0; end if;

  -- Same anti-cheat gate as claiming: no rewards for impossible speeds.
  cap_mps := case mode when 'run' then 6.5 when 'cycle' then 12.0 else 2.5 end;
  if duration_s > 0 and (distance_m / duration_s) > cap_mps * tol then
    raise exception 'run rejected: implied speed % m/s exceeds % cap',
      round(distance_m / duration_s, 1), mode;
  end if;

  base           := floor(distance_m / 50)::int;          -- 1 coin / 50m
  treasure_coins := floor(distance_m / 500)::int * 30;    -- +30 per 500m
  perk_drops     := floor(distance_m / 1500)::int;        -- a perk per 1500m

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
