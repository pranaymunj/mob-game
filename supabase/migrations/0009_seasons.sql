-- 0009_seasons.sql — Phase 8 layer 5: seasons (time-boxed leaderboards).
-- Run AFTER 0008. A season leaderboard ranks players by area gained during the
-- active season window (from the append-only runs log — no extra bookkeeping).

create table if not exists seasons (
  id        uuid primary key default gen_random_uuid(),
  name      text not null,
  starts_at timestamptz not null,
  ends_at   timestamptz not null
);

alter table seasons enable row level security;
create policy "seasons readable by all" on seasons for select using (true);

-- Seed a current season only if none is active right now.
insert into seasons (name, starts_at, ends_at)
select 'Launch Season', now() - interval '1 day', now() + interval '60 days'
where not exists (select 1 from seasons where now() between starts_at and ends_at);

-- ── current_season: the season active right now ──────────────────────────────
create or replace function current_season()
returns table (name text, ends_at timestamptz)
language sql stable security definer set search_path = public as $$
  select s.name, s.ends_at from seasons s
  where now() between s.starts_at and s.ends_at
  order by s.starts_at desc limit 1;
$$;

-- ── season_leaderboard: players by area gained during the active season ──────
create or replace function season_leaderboard(lim int default 20)
returns table (player_id uuid, color text, area numeric)
language sql stable security definer set search_path = public as $$
  select r.player_id, pl.color, sum(r.area_gained) as area
  from runs r
  join players pl on pl.id = r.player_id
  join seasons s on now() between s.starts_at and s.ends_at
  where r.started_at between s.starts_at and s.ends_at
  group by r.player_id, pl.color
  order by area desc
  limit lim;
$$;
