-- verify_claim_integrity.sql — Prove that 0028 actually closed the hole.
--
-- Run this in the Supabase SQL editor AFTER applying 0028, while signed in as
-- a real player (the SQL editor runs as the service role, where auth.uid() is
-- null, so run it from an authenticated session — e.g. the app's Supabase
-- client, or the SQL editor with "Run as: authenticated" if available).
--
-- Every block below is an attack that MUST fail. If any of them returns a uuid
-- instead of raising, that attack still works and 0028 did not take.

-- ── 1. The original exploit ────────────────────────────────────────────────
-- A huge ring plus an absurd duration. Before 0028 the implied speed was near
-- zero and this claimed a whole city. Expected: rejected on the area limit.
select claim_turf(
  '{"type":"Polygon","coordinates":[[[-118.50,33.90],[-118.10,33.90],
    [-118.10,34.20],[-118.50,34.20],[-118.50,33.90]]]}',
  1,                 -- lying about area
  'walk',
  1,                 -- lying about distance
  9999999            -- lying about duration
);

-- ── 2. The skipped gate ────────────────────────────────────────────────────
-- duration_s = 0 used to bypass the speed check entirely.
-- Expected: rejected for missing duration.
select claim_turf(
  '{"type":"Polygon","coordinates":[[[-118.30,34.00],[-118.29,34.00],
    [-118.29,34.01],[-118.30,34.01],[-118.30,34.00]]]}',
  1000, 'walk', 100, 0
);

-- ── 3. Teleporting round a real-sized block ────────────────────────────────
-- A ~1km perimeter walked in 10 seconds. Expected: rejected on implied speed.
select claim_turf(
  '{"type":"Polygon","coordinates":[[[-118.30,34.00],[-118.2973,34.00],
    [-118.2973,34.0023],[-118.30,34.0023],[-118.30,34.00]]]}',
  1000, 'walk', 10, 10
);

-- ── 4. A legitimate claim ──────────────────────────────────────────────────
-- Same block, walked in 15 minutes. Expected: SUCCEEDS, returning a turf uuid.
-- If this one fails, the gate is too tight and real players are being blocked —
-- which is worse than the bug, so check it every time you touch the caps.
select claim_turf(
  '{"type":"Polygon","coordinates":[[[-118.30,34.00],[-118.2973,34.00],
    [-118.2973,34.0023],[-118.30,34.0023],[-118.30,34.00]]]}',
  1000, 'walk', 1000, 900
);

-- ── 5. Payout is measured, not reported ────────────────────────────────────
-- After a successful claim, the run row's area_gained should match the real
-- polygon area (~62,000 m² for the block above), NOT the 1000 sent by the
-- client.
select area_gained, distance, duration, mode, started_at
  from runs
 where player_id = auth.uid()
 order by started_at desc
 limit 3;

-- ── 6. Decay no longer runs on the capture path ────────────────────────────
-- Should list decay_turf as its own function, and it should be callable only
-- by the service role / cron (not by anon or authenticated).
select p.proname, pg_get_function_identity_arguments(p.oid) as args
  from pg_proc p
  join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.proname in ('decay_turf', 'claim_turf');

-- Clean up anything block 4 created, so running this twice is safe.
-- delete from turf where owner_id = auth.uid()
--   and st_intersects(geom, st_setsrid(st_makepoint(-118.2985, 34.0011), 4326));
