-- 0007_perks.sql — Phase 8 layer 3: perks (Sprint / Shield / Wide Brush / Recon).
-- Run AFTER 0006. Shield is enforced server-side: shielded turf cannot be
-- stolen. Perks are earned by completing the daily challenge (one/day).

-- Inventory: how many of each perk a player holds.
create table if not exists player_perks (
  player_id uuid not null references players (id) on delete cascade,
  perk      text not null,               -- sprint | shield | wide_brush | recon
  qty       int  not null default 0,
  primary key (player_id, perk)
);

alter table player_perks enable row level security;
create policy "perks readable by owner" on player_perks for select using (auth.uid() = player_id);

-- Turf can be shielded until a timestamp (protects it from being stolen).
alter table turf add column if not exists shielded_until timestamptz;

-- Track the last day a challenge reward was claimed (one reward/day).
alter table players add column if not exists last_reward_at date;

-- ── claim_daily_reward: if today's challenge is complete, grant a random perk ─
create or replace function claim_daily_reward()
returns text language plpgsql security definer set search_path = public as $$
declare
  done  boolean;
  last  date;
  perks text[] := array['sprint','shield','wide_brush','recon'];
  pick  text;
begin
  if auth.uid() is null then raise exception 'must be signed in'; end if;

  select completed into done from challenge_status();
  if not done then raise exception 'challenge not complete yet'; end if;

  select last_reward_at into last from players where id = auth.uid();
  if last = current_date then raise exception 'reward already claimed today'; end if;

  pick := perks[1 + floor(random() * array_length(perks, 1))::int];

  insert into player_perks (player_id, perk, qty) values (auth.uid(), pick, 1)
  on conflict (player_id, perk) do update set qty = player_perks.qty + 1;

  update players set last_reward_at = current_date where id = auth.uid();
  return pick;
end;
$$;

-- ── activate_perk: consume one perk and apply its effect ──────────────────────
-- Shield is applied server-side (shields all your current turf for 24h). The
-- others (sprint/wide_brush/recon) are consumed here and applied client-side.
create or replace function activate_perk(perk_key text)
returns void language plpgsql security definer set search_path = public as $$
declare
  have int;
begin
  if auth.uid() is null then raise exception 'must be signed in'; end if;

  select qty into have from player_perks where player_id = auth.uid() and perk = perk_key;
  if coalesce(have, 0) < 1 then raise exception 'you have no % perk', perk_key; end if;

  update player_perks set qty = qty - 1
   where player_id = auth.uid() and perk = perk_key;

  if perk_key = 'shield' then
    update turf set shielded_until = now() + interval '24 hours'
     where owner_id = auth.uid();
  end if;
end;
$$;

-- ── claim_turf: don't steal turf that is currently shielded ───────────────────
create or replace function claim_turf(
  ring_geojson text, area_m numeric,
  mode text default 'walk', distance_m numeric default 0, duration_s numeric default 0
)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  new_id uuid; new_geom geometry; cap_mps numeric; tol numeric := 1.25;
begin
  if auth.uid() is null then raise exception 'must be signed in to claim turf'; end if;

  cap_mps := case mode when 'run' then 6.5 when 'cycle' then 12.0 else 2.5 end;
  if duration_s > 0 and (distance_m / duration_s) > cap_mps * tol then
    raise exception 'capture rejected: implied speed % m/s exceeds % cap',
      round(distance_m / duration_s, 1), mode;
  end if;

  new_geom := st_makevalid(st_setsrid(st_geomfromgeojson(ring_geojson), 4326));

  -- Steal overlap, EXCEPT turf that is currently shielded.
  update turf
     set geom = st_multi(st_difference(geom, new_geom)),
         area = st_area(st_difference(geom, new_geom)::geography)
   where st_intersects(geom, new_geom)
     and (shielded_until is null or shielded_until < now());

  delete from turf where st_isempty(geom) or st_area(geom::geography) < 1;

  insert into turf (owner_id, geom, area)
  values (auth.uid(), st_multi(new_geom), area_m)
  returning id into new_id;

  update players p
     set total_area = coalesce((select sum(t.area) from turf t where t.owner_id = p.id), 0)
   where p.id is not null;

  insert into runs (player_id, distance, area_gained, duration, mode)
  values (auth.uid(), distance_m, area_m, floor(duration_s)::int, mode);

  return new_id;
end;
$$;
