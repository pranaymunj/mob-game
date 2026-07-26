-- 0020_cosmetics.sql — Cosmetics: trail skins + turf styles bought with coins.
-- Run AFTER 0019.
--
-- Two equip slots: 'trail' (what you look like while running) and 'turf' (how
-- your claimed land renders on everyone's map). Prices and ownership live on
-- the server; the client only holds display metadata.

create table if not exists player_cosmetics (
  player_id  uuid not null references players (id) on delete cascade,
  item_key   text not null,
  acquired_at timestamptz not null default now(),
  primary key (player_id, item_key)
);

alter table player_cosmetics enable row level security;
create policy "cosmetics readable by owner" on player_cosmetics
  for select using (auth.uid() = player_id);

-- Equipped slots. The defaults are free and always owned.
alter table players add column if not exists equipped_trail text not null default 'trail_classic';
alter table players add column if not exists equipped_turf  text not null default 'turf_solid';

-- ── catalogue (server is the authority on price + slot) ─────────────────────
create or replace function cosmetic_price(item_key text)
returns int language sql immutable as $$
  select case item_key
    -- trails
    when 'trail_classic' then 0
    when 'trail_neon'    then 200
    when 'trail_flame'   then 350
    when 'trail_ice'     then 350
    when 'trail_void'    then 600
    -- turf styles
    when 'turf_solid'    then 0
    when 'turf_outline'  then 250
    when 'turf_glow'     then 400
    when 'turf_hatch'    then 500
    else null
  end;
$$;

create or replace function cosmetic_slot(item_key text)
returns text language sql immutable as $$
  select case
    when item_key like 'trail_%' then 'trail'
    when item_key like 'turf_%'  then 'turf'
    else null
  end;
$$;

-- ── buy_cosmetic: spend coins, grant ownership ──────────────────────────────
create or replace function buy_cosmetic(item_key text)
returns int language plpgsql security definer set search_path = public as $$
declare price int; have int;
begin
  if auth.uid() is null then raise exception 'must be signed in'; end if;

  price := cosmetic_price(item_key);
  if price is null then raise exception 'unknown item %', item_key; end if;

  if exists (select 1 from player_cosmetics
              where player_id = auth.uid() and player_cosmetics.item_key = buy_cosmetic.item_key) then
    raise exception 'you already own this';
  end if;

  select coins into have from players where id = auth.uid();
  if coalesce(have, 0) < price then
    raise exception 'not enough coins: need %, you have %', price, coalesce(have, 0);
  end if;

  update players set coins = coins - price where id = auth.uid();
  insert into player_cosmetics (player_id, item_key) values (auth.uid(), item_key);

  return have - price;
end;
$$;

-- ── equip_cosmetic: you must own it (defaults are free) ─────────────────────
create or replace function equip_cosmetic(item_key text)
returns void language plpgsql security definer set search_path = public as $$
declare slot text;
begin
  if auth.uid() is null then raise exception 'must be signed in'; end if;

  slot := cosmetic_slot(item_key);
  if slot is null or cosmetic_price(item_key) is null then
    raise exception 'unknown item %', item_key;
  end if;

  -- Free defaults need no purchase; everything else must be owned.
  if cosmetic_price(item_key) > 0
     and not exists (select 1 from player_cosmetics
                      where player_id = auth.uid()
                        and player_cosmetics.item_key = equip_cosmetic.item_key) then
    raise exception 'you do not own this item';
  end if;

  if slot = 'trail' then
    update players set equipped_trail = item_key where id = auth.uid();
  else
    update players set equipped_turf = item_key where id = auth.uid();
  end if;
end;
$$;

-- ── my_cosmetics: owned items + what's equipped ─────────────────────────────
create or replace function my_cosmetics()
returns table (owned text[], trail text, turf text)
language sql stable security definer set search_path = public as $$
  select
    coalesce((select array_agg(item_key) from player_cosmetics where player_id = auth.uid()), '{}'),
    (select equipped_trail from players where id = auth.uid()),
    (select equipped_turf  from players where id = auth.uid());
$$;
