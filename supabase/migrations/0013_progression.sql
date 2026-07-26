-- 0013_progression.sql — Player progression: lifetime "territory made" + runs.
-- Run AFTER 0012. Lifetime area is the sum of every claim ever (from the
-- append-only runs log), so it only grows even when your turf is stolen.
-- The client turns these into level / XP / achievements.

create or replace function player_stats()
returns table (lifetime_area numeric, run_count int, current_area numeric,
               longest_streak int, current_streak int)
language sql stable security definer set search_path = public as $$
  select
    coalesce((select sum(area_gained) from runs where player_id = auth.uid()), 0) as lifetime_area,
    coalesce((select count(*) from runs where player_id = auth.uid()), 0)::int   as run_count,
    coalesce((select total_area from players where id = auth.uid()), 0)           as current_area,
    coalesce((select longest_streak from players where id = auth.uid()), 0)       as longest_streak,
    coalesce((select current_streak from players where id = auth.uid()), 0)       as current_streak;
$$;
