# TERRA — Master Build Specification
### A Strava-grade GPS fitness app with territory-claiming gameplay
**Purpose of this document:** Feed this to Google Antigravity (or any agentic coding tool) phase by phase. It contains the full product spec, architecture, database schema, every algorithm with pseudocode, screen-by-screen UI spec, API contracts, the points/decay game design, anti-cheat rules, and a sequenced set of build prompts. Personal/experimental project — own branding, no Strava assets.

---

## 1. Product definition

**One-liner:** Record walks/runs with GPS like Strava; when the user's path forms a closed loop, the enclosed area becomes their "territory," rendered on the map and converted to points.

**Core loops:**
1. Record activity → see live stats + live loop preview → close loop → capture animation → points awarded.
2. Territory decays over time → user returns to defend it → retention loop.
3. Weekly stats, streaks, personal leaderboard (solo mode first; multiplayer optional phase).

**Non-goals (v1):** No social network, no public segments/leaderboards, no OAuth providers beyond email/anonymous, no wearable integrations. These are phase 2+.

---

## 2. Tech stack (decisions made — do not re-litigate)

| Layer | Choice | Why |
|---|---|---|
| Mobile app | **React Native (Expo, dev-client build)** | Fast iteration, one codebase, Antigravity handles JS/TS well. Expo dev-client (NOT Expo Go) because background location needs native config. |
| Language | TypeScript everywhere | |
| Maps | **Mapbox GL (via @rnmapbox/maps)** | Polygon fills, vector styling, heatmap-capable. Free tier fine for personal use. Alternative if Mapbox token is a hassle: react-native-maps + Google Maps. |
| Location | expo-location (foreground) + expo-task-manager (background tracking) | |
| Geospatial math (client) | **@turf/turf** | area, booleanPointInPolygon, kinks, intersect, difference, simplify, length |
| Local storage | **SQLite via expo-sqlite** (offline-first) | Activities must never be lost to a dead network. |
| Backend | **Node.js (Fastify) + TypeScript** | |
| Database | **PostgreSQL 16 + PostGIS 3.4** | Geometry types, ST_Area, ST_Intersection, ST_Difference, GiST spatial indexes. |
| ORM | Drizzle ORM (with raw SQL for PostGIS calls) | |
| Auth | Simple JWT (email+password or device-anonymous) — this is personal, keep it minimal | |
| Elevation | Open-Elevation API (free) or Mapbox Terrain-RGB tiles | Batch lookup post-activity |
| Charts | react-native-svg + victory-native (pace/elevation graphs) | |
| Deployment | Backend: single Docker container (fly.io/Railway/local). DB: managed Postgres or Docker postgis/postgis image. | |

---

## 3. System architecture

```
[Phone: React Native app]
  ├─ Recording engine (foreground service / background task)
  │    raw GPS → accuracy gate → Kalman filter → point buffer (SQLite)
  ├─ Live stats computer (distance, pace, duration, loop-preview)
  ├─ Map renderer (Mapbox): live trail, territories, fog layer
  └─ Sync engine: on activity finish → POST to backend (retry queue)

[Backend: Fastify API]
  ├─ /auth, /activities, /territories, /stats endpoints
  ├─ Processing pipeline (on activity upload):
  │    1. validate + anti-cheat checks
  │    2. re-smooth (server-side Kalman pass)
  │    3. simplify (Douglas-Peucker)
  │    4. loop detection → polygon construction
  │    5. self-intersection repair (ST_MakeValid / buffer(0))
  │    6. territory conflict resolution (overlap union/steal)
  │    7. area + points computation
  │    8. elevation enrichment (batch DEM lookup)
  │    9. persist activity + territory + points ledger
  └─ Decay cron job (hourly): age territories, shrink/expire, notify

[PostgreSQL + PostGIS]
  spatial storage + geometry math
```

**Principle:** the phone computes everything needed for the *live* experience (preview area, live points estimate); the server is the *source of truth* and recomputes everything on upload. Client numbers are provisional.

---

## 4. Database schema (PostGIS)

```sql
CREATE EXTENSION IF NOT EXISTS postgis;

CREATE TABLE users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email TEXT UNIQUE,
  display_name TEXT NOT NULL,
  total_points BIGINT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE activities (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id),
  started_at TIMESTAMPTZ NOT NULL,
  ended_at TIMESTAMPTZ NOT NULL,
  sport TEXT NOT NULL DEFAULT 'walk',        -- walk | run | ride
  raw_track GEOMETRY(LineStringZM, 4326),    -- Z=elevation M=epoch seconds
  smoothed_track GEOMETRY(LineString, 4326),
  distance_m DOUBLE PRECISION NOT NULL,
  duration_s INTEGER NOT NULL,
  moving_time_s INTEGER NOT NULL,
  avg_pace_s_per_km DOUBLE PRECISION,
  elev_gain_m DOUBLE PRECISION DEFAULT 0,
  is_flagged BOOLEAN NOT NULL DEFAULT false, -- anti-cheat
  flag_reason TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE territories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id),
  source_activity_id UUID REFERENCES activities(id),
  geom GEOMETRY(MultiPolygon, 4326) NOT NULL,
  area_m2 DOUBLE PRECISION NOT NULL,
  level SMALLINT NOT NULL DEFAULT 1,          -- re-walk to level up (max 5)
  claimed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_defended_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at TIMESTAMPTZ,                     -- decay deadline
  district_name TEXT,                         -- reverse-geocoded label
  is_active BOOLEAN NOT NULL DEFAULT true
);
CREATE INDEX territories_geom_idx ON territories USING GIST (geom);
CREATE INDEX territories_user_idx ON territories (user_id) WHERE is_active;

CREATE TABLE points_ledger (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES users(id),
  activity_id UUID REFERENCES activities(id),
  territory_id UUID REFERENCES territories(id),
  delta BIGINT NOT NULL,                      -- +capture, +defend, -decay
  reason TEXT NOT NULL,                       -- 'capture'|'defend'|'level_up'|'decay'|'bonus_new_area'
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

Notes:
- `LineStringZM` stores elevation (Z) and timestamp (M) per point — this is how Strava-style pace/elevation charts are reconstructed from one geometry column.
- Territories are **MultiPolygon** because decay/steals can split a shape into pieces.
- `points_ledger` is append-only; `users.total_points` is a cached sum (recomputable).

---

## 5. Algorithms — full detail

### 5.1 GPS accuracy gate (first filter, on-device)
Drop garbage points before they enter the pipeline.

```
accept point P if:
  P.horizontalAccuracy <= 25 meters          // reject weak fixes
  AND P.timestamp > lastAccepted.timestamp
  AND speed(lastAccepted → P) <= maxSpeed(sport)
      // walk: 4 m/s, run: 8 m/s, ride: 25 m/s
  AND dt >= 1 second                          // dedupe bursts
where speed = haversine(lastAccepted, P) / dt
```
The speed check kills "GPS teleports" (signal reflection jumps of 50–200 m).

### 5.2 Haversine distance (used everywhere)
```
R = 6371008.8 meters (mean Earth radius)
dLat = lat2 - lat1 (radians); dLon = lon2 - lon1 (radians)
a = sin²(dLat/2) + cos(lat1)·cos(lat2)·sin²(dLon/2)
d = 2R · atan2(√a, √(1−a))
```
For local math (area, loop tolerance) also implement an **equirectangular projection to meters** around the track centroid:
```
x = R · lon(rad) · cos(latOrigin)
y = R · lat(rad)
```
All polygon/area math is done in this local meter space — never in raw degrees.

### 5.3 Kalman filter for GPS smoothing (1D-per-axis constant-velocity model)
Run on-device live and again server-side. Per axis (x and y in projected meters):

State: position p, velocity v. Process noise q (m/s², tune ≈ 3 for walking).
For each new measurement z with accuracy σ (meters), time step dt:

```
// predict
p = p + v·dt
P11 += dt²·P22 + q·dt²        // covariance grow (simplified)
P22 += q

// update
K = P11 / (P11 + σ²)          // Kalman gain
p = p + K·(z − p)
v = v + (K/dt)·(z − p_pre)    // velocity correction
P11 = (1 − K)·P11
```
A simpler, battle-tested variant (good enough, ship this first):
```
variance += dt · q²
K = variance / (variance + accuracy²)
lat += K · (measLat − lat)
lon += K · (measLon − lon)
variance = (1 − K) · variance
```
Effect: jitter collapses, corners stay. Tune q: 3 (walk), 5 (run), 9 (ride).

### 5.4 Track simplification — Douglas-Peucker (server, before storage/render)
Reduces 3,000 raw points to ~200 without changing shape.
```
function dp(points, ε):
  find point Pmax with max perpendicular distance dmax to line(first,last)
  if dmax > ε:
     return dp(points[..Pmax]) + dp(points[Pmax..])  // recurse, merge
  else:
     return [first, last]
ε = 5 meters (walk/run), 10 m (ride)
```
Use turf.simplify (which implements DP) — do not hand-roll unless asked.

### 5.5 Loop-closure detection (the territory trigger)
Runs live on-device every accepted point, and authoritatively on server.

```
CLOSE_TOLERANCE = 30 m          // how near "back to start" must be
MIN_LOOP_DISTANCE = 300 m       // total path length before a loop can count
MIN_LOOP_AREA = 500 m²          // ignore micro-loops (walking around a car)

on new point P (projected meters):
  if pathLength < MIN_LOOP_DISTANCE: return
  // check against EARLY portion of path, not just start point:
  for each point Q in path[0 .. 20% of path]:
      if dist(P, Q) <= CLOSE_TOLERANCE:
          candidateLoop = path[indexOf(Q) .. current]
          if shoelaceArea(candidateLoop) >= MIN_LOOP_AREA:
              → LOOP DETECTED (loop = candidateLoop, snap last point to Q)
```
Why check the early *segment* instead of only point[0]: users rarely stop exactly where they pressed start. Also support **manual close**: a "Claim" button that closes the polygon with a straight line from current position to start if the gap ≤ 100 m.

### 5.6 Live loop preview (the engagement feature)
Every few seconds while recording:
```
previewPolygon = currentPath + straightLine(currentPos → startPos)
previewArea    = |shoelace(previewPolygon)|   // only if gap ≤ 250 m
show: dotted line + "Close loop now: X m² · Y pts"
```

### 5.7 Polygon area — Shoelace formula (in projected meters)
```
A = ½ |Σ (xᵢ·yᵢ₊₁ − xᵢ₊₁·yᵢ)|   for i = 0..n-1, indices mod n
```
In production call turf.area(polygon) (geodesic, more accurate for big loops); shoelace on the local projection is fine for the live preview.

### 5.8 Self-intersection repair (figure-8 walks)
Real paths self-cross. A self-intersecting ring is an invalid polygon.
- Client quick-check: turf.kinks(line) → if kinks exist, split at intersections and keep the largest simple ring for preview.
- Server authoritative: `ST_MakeValid(ST_MakePolygon(line))` then `ST_CollectionExtract(geom, 3)` to keep polygonal parts; alternatively `ST_Buffer(geom, 0)`. Result may be MultiPolygon — that's why the column is MultiPolygon.

### 5.9 Territory conflict resolution (server, inside one SQL transaction)
```sql
-- new claimed polygon :new_geom for user :uid
-- 1) merge with the user's own adjacent/overlapping territory:
--    if ST_Intersects with own territory → ST_Union, keep older claimed_at,
--    level = max(levels), re-walked overlap ≥60% → level += 1 (cap 5)
-- 2) steal from others (multiplayer mode only):
--    others_geom = ST_Intersection(new_geom, other.geom)
--    other.geom  = ST_Difference(other.geom, new_geom)  → may split/empty
--    stolen_m2   = ST_Area(others_geom::geography)
-- 3) truly-new area = ST_Area(ST_Difference(new_geom, union(all prior))::geography)
```
Always compute areas with `::geography` casts so results are in real m².

### 5.10 Points formula (tunable constants at top of one config file)
```
BASE_DIVISOR   = 50        // 1 pt per 50 m²
NEW_AREA_MULT  = 1.5
STEAL_MULT     = 2.0
DEFEND_POINTS  = area_m2 / 500     // re-walk own territory
LEVEL_UP_BONUS = 100 · newLevel
MIN_AREA       = 500 m²

capture_pts = floor(new_area_m2 / BASE_DIVISOR · NEW_AREA_MULT)
            + floor(stolen_m2   / BASE_DIVISOR · STEAL_MULT)
            + (leveledUp ? LEVEL_UP_BONUS : 0)
if total polygon area < MIN_AREA → 0 points, no territory
Write every award to points_ledger; update users.total_points.
```

### 5.11 Territory decay (retention mechanic)
Hourly cron:
```
DECAY_START = 7 days after last_defended_at
DECAY_RATE  = 10% of area per day after DECAY_START (shrink via negative buffer:
              geom = ST_Buffer(geom::geography, -r)::geometry, r sized so area drops ~10%)
EXPIRE      = when area < MIN_AREA → is_active = false
points penalty: ledger entry −(lost_m2 / BASE_DIVISOR) reason 'decay'
expires_at kept updated so the client can render "decaying · 2d left" badges.
```

### 5.12 Moving time, pace, splits (Strava-style stats)
```
moving if instantaneous speed > 0.5 m/s (walk) / 0.7 (run)
pace = duration over rolling 30 s window ÷ distance in window (s per km)
splits: emit cumulative distance crossings at each 1,000 m → per-km split times
```

### 5.13 Elevation gain (server enrichment)
1. Sample the smoothed track every ~50 m.
2. Batch-query DEM (Open-Elevation POST /api/v1/lookup, up to ~100 points/call).
3. Smooth elevations with a 5-point moving average.
4. `elev_gain = Σ max(0, eᵢ₊₁ − eᵢ)` only counting rises > 1 m (hysteresis threshold kills DEM noise).

### 5.14 Anti-cheat (flag, don't block — it's personal, but build it right)
Flag activity if ANY:
```
- p95 speed > 1.5× sport max
- any single jump > 200 m between consecutive accepted points
- straight-line ratio: distance / ST_Length(track) < 0.15 with distance > 2 km
  (suspiciously perfect polygon = drawn, not walked)
- duration < 60 s with area > 5,000 m²
Flagged → activity saves, territory + points withheld, is_flagged = true.
```

---

## 6. Screens (UI spec)

1. **Home / Map (empire view)** — full-screen Mapbox map. Layers bottom→top: basemap → fog overlay (dark 55% opacity polygon with holes punched for explored area — maintain an "explored" MultiPolygon = union of buffered tracks, buffer 60 m) → other users' territories (gray) → own territories (fill color by level: level1 #AFA9EC → level5 #3C3489, teal for healthy, fading opacity for decaying) → live trail. Header: total points + total km². Territory tap → bottom sheet (name, area, level, decay countdown, "history").
2. **Record screen** — big start button; while recording: live trail (coral), dotted preview line to start, floating chip "Close loop now: X m² · +Y pts", stats bar (time, distance, pace), Claim button (enabled when gap ≤ 100 m), pause/finish.
3. **Capture moment** — on loop close: polygon fill animates inward from the path (Mapbox fill-opacity animation 0→0.5 over 600 ms), haptic burst, floating "+340 pts · 2.1 km² claimed", confetti 1 s, then reverse-geocode district name toast: "You now control 60% of <district>". Over-invest here.
4. **Activity summary** — map snapshot with territory highlighted, stat grid (distance, time, pace, elev gain, area claimed, points), pace-per-km bar chart, elevation profile line chart.
5. **Profile / stats** — points total, ledger history, weekly distance chart, streak counter, territory list sorted by decay urgency ("defend soon").
6. **Settings** — sport type, units, decay on/off, map style, export GPX.

---

## 7. API contract (Fastify, JSON, JWT bearer)

```
POST /auth/register {email,password,displayName} → {token}
POST /auth/login → {token}

POST /activities            // upload finished recording
  body: { startedAt, endedAt, sport,
          points: [{lat,lon,ele?,t,acc}] }     // raw accepted points
  → 201 { activity, territory?, pointsAwarded, breakdown[] }

GET  /activities?cursor=    → paginated list (summary fields)
GET  /activities/:id        → full detail incl. smoothed GeoJSON, splits
GET  /territories           → GeoJSON FeatureCollection (own, active)
GET  /territories/:id       → detail + capture history
GET  /stats/summary         → totals, weekly aggregates, streak
GET  /explored              → explored-area MultiPolygon for fog layer
```
Upload is idempotent: client sends a UUID it generated; server upserts.

---

## 8. Offline-first sync rules
- Recording writes points to SQLite every 5 s (never lose a walk to a crash).
- Finish → enqueue upload job (table `sync_queue`), retry w/ exponential backoff.
- Territories/points shown from server responses; while offline show provisional client-computed values tagged "pending sync".

---

## 9. Build phases — feed these to Antigravity ONE AT A TIME
Each phase = one agent task. Tell the agent to verify each phase (run app / run tests) before moving on. Paste the relevant spec sections with each prompt.

**Phase 0 — Monorepo scaffold.**
"Create a monorepo `terra/` with `apps/mobile` (Expo React Native TS, dev-client, @rnmapbox/maps, expo-location, expo-task-manager, expo-sqlite, @turf/turf, victory-native) and `apps/api` (Fastify TS, Drizzle, pg). Add `docker-compose.yml` running postgis/postgis:16-3.4. Add the schema from §4 as a Drizzle migration plus raw SQL for indexes. Verify: API boots, migration applies, mobile app renders a Mapbox map centered on user location."

**Phase 1 — Recording engine.**
"Implement the recording pipeline from §5.1–5.3: foreground+background location task, accuracy gate, Kalman filter (simple variant), SQLite point buffer, live stats (§5.12), record screen UI (§6.2 minus loop features). Verify with the included mock-GPS harness: feed the sample noisy track (write a fixture generator that adds gaussian noise σ=8 m to a rectangle route) and assert smoothed distance within 5% of truth."

**Phase 2 — Loop detection + live preview (client).**
"Implement §5.5–5.7 on-device: loop detection against early-path segment, manual Claim button, live dotted preview line + area chip. Unit-test loop detection with 5 fixture tracks: clean rectangle, open C-shape (no loop), figure-8, loop closing at 25 m gap (detect), 40 m gap (no auto-detect, manual claim allowed at ≤100 m)."

**Phase 3 — Server processing pipeline.**
"Implement POST /activities executing §5 steps 1–9 exactly: anti-cheat (§5.14), server Kalman re-pass, turf/DP simplification (§5.4), polygon construction with ST_MakeValid (§5.8), conflict resolution SQL (§5.9), points (§5.10), ledger writes. Integration tests against dockerized PostGIS using the same fixtures; assert m² within 2% of analytically known areas."

**Phase 4 — Territory rendering + capture moment.**
"Home map with territory layers, level colors, decay badges (§6.1); capture animation + haptics + district reverse-geocode toast (§6.3); activity summary screen with charts (§6.4)."

**Phase 5 — Decay cron + defend + fog of war.**
"Hourly decay job (§5.11) with negative-buffer shrink; defend detection (re-walk overlap ≥60% of own territory → defend points + level-up per §5.9/5.10); explored-area union maintenance and fog overlay (§6.1). Test decay math by injecting old last_defended_at values."

**Phase 6 — Polish.**
"Profile/stats screens, streaks, GPX export, settings, offline sync queue (§8), empty states, error handling audit."

---

## 10. Verification checklist for the agent (per phase)
- Type-checks clean, lints clean, all tests green.
- Launch app (simulator ok) and screenshot the affected screen.
- For geo math: every algorithm gets unit tests with known-answer fixtures (rectangle 100×200 m must yield 20,000 m² ± 2%).
- No secrets committed; Mapbox token via .env.

## 11. Tuning table (single config file: packages/shared/gameConfig.ts)
All constants from §5 live here: CLOSE_TOLERANCE, MIN_LOOP_AREA, BASE_DIVISOR, NEW_AREA_MULT, STEAL_MULT, DECAY_*, sport speed caps, Kalman q per sport. Change numbers → whole system follows.

## 12. Known hard edges (tell the agent explicitly)
- Background location on iOS needs `UIBackgroundModes: location` + "Always" permission flow; Android needs a foreground service notification. Expo dev-client, not Expo Go.
- Never do area math in degrees. Always geography casts (server) or local meter projection (client).
- MultiPolygon everywhere; a decayed/stolen territory can split.
- Mapbox fill layers need polygon rings in correct winding order; GeoJSON from PostGIS ST_AsGeoJSON is already correct — don't "fix" it.
- Battery: request Balanced accuracy at 1 Hz walk / 0.5 Hz ride; pause GPS when stationary > 2 min.
