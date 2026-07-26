-- 0024_leagues.sql — Weekly leagues (Bronze → Diamond). Run AFTER 0023.
--
-- Your DIVISION is set by lifetime territory (a durable rank that only grows),
-- and within it you compete on THIS WEEK's area claimed. No weekly reset job is
-- needed: "this week" is derived live from the runs log, and tiers are computed
-- on read. Promotion is organic — claim more lifetime territory, move up.

create or replace function player_tier(lifetime numeric)
returns int language sql immutable as $$
  select case
    when lifetime >= 100000 then 4  -- Diamond
    when lifetime >=  50000 then 3  -- Platinum
    when lifetime >=  20000 then 2  -- Gold
    when lifetime >=   5000 then 1  -- Silver
    else 0                          -- Bronze
  end;
$$;

create or replace function tier_name(t int)
returns text language sql immutable as $$
  select case t
    when 4 then 'Diamond' when 3 then 'Platinum' when 2 then 'Gold'
    when 1 then 'Silver' else 'Bronze' end;
$$;

-- Per-player weekly + lifetime area from the runs log.
create or replace view player_league_stats as
  select r.player_id,
    coalesce(sum(r.area_gained) filter (
      where r.started_at >= date_trunc('week', now())), 0) as weekly_area,
    coalesce(sum(r.area_gained), 0) as lifetime_area
  from runs r
  group by r.player_id;

-- ── league_status: your tier, this week's area, and your rank in-tier ────────
-- NB: CTE column aliased `wa` and output cols kept distinct to avoid the
-- "column reference is ambiguous" trap (output cols shadow source cols).
create or replace function league_status()
returns table (tier int, tier_label text, weekly_area numeric, rank int, division_size int)
language plpgsql stable security definer set search_path = public as $$
declare my_tier int; my_weekly numeric;
begin
  if auth.uid() is null then raise exception 'must be signed in'; end if;

  select player_tier(s.lifetime_area), s.weekly_area into my_tier, my_weekly
    from player_league_stats s where s.player_id = auth.uid();
  my_tier := coalesce(my_tier, 0);
  my_weekly := coalesce(my_weekly, 0);

  return query
    with peers as (
      select s.weekly_area as wa from player_league_stats s
      where player_tier(s.lifetime_area) = my_tier
    )
    select my_tier, tier_name(my_tier), my_weekly,
      (select count(*)::int + 1 from peers where peers.wa > my_weekly),
      (select count(*)::int from peers);
end;
$$;

-- ── league_standings: the current player's division, ranked by weekly area ──
-- Output columns prefixed p*/w to avoid colliding with source column names.
drop function if exists league_standings(int);
create function league_standings(lim int default 25)
returns table (pid uuid, pname text, pcolor text, pavatar text, warea numeric)
language plpgsql stable security definer set search_path = public as $$
declare my_tier int;
begin
  if auth.uid() is null then raise exception 'must be signed in'; end if;
  select player_tier(s.lifetime_area) into my_tier
    from player_league_stats s where s.player_id = auth.uid();
  my_tier := coalesce(my_tier, 0);

  return query
    select p.id, p.display_name, p.color, p.avatar, s.weekly_area
    from player_league_stats s
    join players p on p.id = s.player_id
    where player_tier(s.lifetime_area) = my_tier
    order by s.weekly_area desc
    limit lim;
end;
$$;
