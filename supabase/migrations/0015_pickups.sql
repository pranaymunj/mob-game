-- 0015_pickups.sql — Power-up pickups: collectibles on the map that grant a
-- perk when you walk over them. Run AFTER 0014.

create table if not exists pickups (
  id           uuid primary key default gen_random_uuid(),
  lng          double precision not null,
  lat          double precision not null,
  perk         text not null,
  collected    boolean not null default false,
  collected_by uuid references players (id) on delete set null,
  created_at   timestamptz not null default now()
);

create index if not exists pickups_open_idx on pickups (collected) where not collected;

alter table pickups enable row level security;
create policy "pickups readable by all" on pickups for select using (true);

-- ── pickups_near: uncollected pickups within radius ──────────────────────────
create or replace function pickups_near(p_lng double precision, p_lat double precision, radius_m double precision)
returns table (id uuid, lng double precision, lat double precision, perk text)
language sql stable security definer set search_path = public as $$
  select p.id, p.lng, p.lat, p.perk
  from pickups p
  where not p.collected
    and st_dwithin(
      st_setsrid(st_makepoint(p.lng, p.lat), 4326)::geography,
      st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography,
      radius_m);
$$;

-- ── spawn_pickups_near: ensure a few pickups exist near a point ──────────────
-- Keeps ~4 uncollected pickups within ~500m, scattering new ones up to ~400m.
create or replace function spawn_pickups_near(p_lng double precision, p_lat double precision)
returns void language plpgsql security definer set search_path = public as $$
declare
  have  int;
  need  int;
  perks text[] := array['sprint','shield','wide_brush','recon'];
begin
  select count(*) into have from pickups p
  where not p.collected
    and st_dwithin(
      st_setsrid(st_makepoint(p.lng, p.lat), 4326)::geography,
      st_setsrid(st_makepoint(p_lng, p_lat), 4326)::geography, 500);

  need := 4 - have;
  while need > 0 loop
    insert into pickups (lng, lat, perk) values (
      p_lng + (random() - 0.5) * 0.008,  -- ~±400m lng
      p_lat + (random() - 0.5) * 0.007,  -- ~±400m lat
      perks[1 + floor(random() * 4)::int]
    );
    need := need - 1;
  end loop;
end;
$$;

-- ── collect_pickup: grab a pickup and receive its perk ───────────────────────
create or replace function collect_pickup(pickup_id uuid)
returns text language plpgsql security definer set search_path = public as $$
declare got text;
begin
  if auth.uid() is null then raise exception 'must be signed in'; end if;

  update pickups set collected = true, collected_by = auth.uid()
   where id = pickup_id and not collected
   returning perk into got;

  if got is null then raise exception 'pickup already taken'; end if;

  insert into player_perks (player_id, perk, qty) values (auth.uid(), got, 1)
    on conflict (player_id, perk) do update set qty = player_perks.qty + 1;

  return got;
end;
$$;
