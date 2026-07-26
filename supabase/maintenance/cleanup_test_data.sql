-- cleanup_test_data.sql — Clear the junk left behind by development testing.
--
-- REST verifications throughout the build created throwaway anonymous players,
-- turf at fake coordinates, empty crews, pickups, cosmetics, events and league
-- entries. None of it should exist when real players arrive.
--
-- OPTION A is the one you want before launch: a full reset of game data.
-- It keeps the schema, functions, views and policies — only rows are removed.
-- OPTION B is a gentler, targeted tidy if you ever want to keep real data.

-- ─────────────────────────────────────────────────────────────────────────────
-- OPTION A — FULL RESET of all game data (recommended before launch)
-- Run the whole block. Auth users are removed too, so every test account goes.
-- Order follows FKs; truncate ... cascade handles the rest.
-- ─────────────────────────────────────────────────────────────────────────────

truncate table app_events        restart identity cascade;
truncate table player_cosmetics   restart identity cascade;
truncate table pickups            restart identity cascade;
truncate table photo_flags        restart identity cascade;
truncate table ghost_runs         restart identity cascade;
truncate table player_perks        restart identity cascade;
truncate table runs               restart identity cascade;
truncate table turf               restart identity cascade;
truncate table crews              restart identity cascade;
truncate table players            restart identity cascade;

-- Remove the throwaway auth accounts those players belonged to.
delete from auth.users;

-- Keep seasons, but restart the clock so day one is launch day.
delete from seasons;
insert into seasons (name, starts_at, ends_at)
values ('Launch Season', now(), now() + interval '60 days');


-- ─────────────────────────────────────────────────────────────────────────────
-- OPTION B — TARGETED TIDY (only run this INSTEAD of Option A)
-- Comment out Option A above if you use this. Removes test artefacts while
-- keeping any genuine players and their data.
-- ─────────────────────────────────────────────────────────────────────────────

-- -- Turf at the fake coordinates used by development tests (open ocean / empty
-- -- land west of the US, and the +10..+30 lat/lng block used for league tests).
-- delete from turf
--  where (st_x(st_centroid(geom)) between -145 and -122
--         and st_y(st_centroid(geom)) between 37 and 56)
--     or (st_x(st_centroid(geom)) between 9 and 30);
--
-- -- Named test accounts created by the verification scripts.
-- delete from players
--  where display_name in ('BronzeBob','GoldGwen','GoldGrace','DiamondDan',
--                         'DiamondDot','PersistMe','Verified','TurfKing',
--                         'TestCrew','PersistMe');
--
-- -- Crews nobody belongs to.
-- delete from crews c
--  where not exists (select 1 from players p where p.crew_id = c.id);
--
-- -- Stale uncollected pickups + old analytics events.
-- delete from pickups where not collected and created_at < now() - interval '1 day';
-- delete from app_events where created_at < now() - interval '30 days';
--
-- -- Players who never actually played (no runs, no turf).
-- delete from players p
--  where not exists (select 1 from runs r where r.player_id = p.id)
--    and not exists (select 1 from turf t where t.owner_id = p.id);
