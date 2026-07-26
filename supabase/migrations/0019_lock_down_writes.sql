-- 0019_lock_down_writes.sql — SECURITY FIX. Run AFTER 0018.
--
-- Found by testing: a client could PATCH players.coins directly and the server
-- accepted it (set 999,999 coins in one request). The same class of hole let a
-- client insert turf and runs directly, bypassing EVERY server-side rule:
--
--   players.update  -> forge coins, total_area (leaderboard), streaks, level
--   runs.insert     -> forge lifetime area, XP, daily-challenge and season
--                      progress (season_leaderboard is computed from runs)
--   turf.insert     -> claim turf without going through claim_turf(), skipping
--                      the anti-cheat speed gate and shield protection entirely
--   turf.update     -> resize your own turf to any size
--
-- Every legitimate write already goes through a SECURITY DEFINER function
-- (claim_turf, buy_perk, update_profile, set_home_base, record_activity,
-- claim_login_reward, crew functions, delete_my_data), which run with elevated
-- rights and are unaffected by these policies. The only direct table write the
-- client performs is photo_flags, which stays.

-- Players: profile changes go through update_profile(); everything else
-- (coins, total_area, streaks) is server-owned.
drop policy if exists "players update own" on players;

-- Runs: written only by claim_turf(). A forged run would inflate lifetime
-- "territory made", level, challenge progress and the season leaderboard.
drop policy if exists "runs insert by owner" on runs;

-- Turf: written only by claim_turf() / delete_my_data(), so the speed gate and
-- shields can't be side-stepped.
drop policy if exists "turf insert by owner" on turf;
drop policy if exists "turf update/delete by owner" on turf;
drop policy if exists "turf delete by owner" on turf;

-- Reads stay open (the map shows everyone's turf) and photo_flags keeps its
-- owner-scoped insert/delete, which the client genuinely uses.
