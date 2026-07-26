# CLAUDE.md — Claimr Build Brief (End to End)

> **How to use this file:** Save it as `CLAUDE.md` in the root of your Flutter project. Claude Code automatically reads it and treats it as the project's source of truth. Then work through **Part 7 (Build Plan)** one phase at a time, pasting each phase's prompt to Claude Code. Do NOT ask Claude Code to "build the whole game" at once — go phase by phase, run the app after each, and only move on when it works.

---

## Part 1 — What we're building

**Claimr** is a real-world territory-capture mobile game. Think **paper.io played on the player's actual city map using their real GPS.** The player walks/runs through real streets leaving a trail; closing a loop claims the enclosed real-world area; the claimed turf is persistent and shared with all players on a live map. Players steal each other's turf and compete on local leaderboards.

**Core loop:** open app → see live map with owned turf → start run → GPS draws a trail → close the loop → enclosed area becomes yours → banked to server → visible to everyone.

**The golden rule for all development:** everything is a layer on top of ONE working thing — a run that closes a loop, fills in the player's color, and saves. Build that first. Add nothing until it works.

---

## Part 2 — Tech stack (use exactly this unless told otherwise)

- **Framework:** Flutter (Dart). One codebase for iOS + Android.
- **State management:** Riverpod (simple, testable). Keep it lightweight.
- **Map SDK:** Mapbox Maps Flutter SDK to start (50k free loads/month, fastest to ship). Keep map logic isolated behind a `MapService` interface so we can swap to MapLibre later without rewriting the app.
- **Location:** `geolocator` package for GPS position + speed streams.
- **Geometry (capture math):** `turf` Dart port or a spatial library for polygon union / difference / intersection and point-in-polygon. **Never hand-roll computational geometry** — use library functions.
- **Backend:** Supabase (Postgres + PostGIS for spatial data, Auth, Realtime). Turf is stored as geo-polygons; spatial queries done in PostGIS.
- **Local storage:** `shared_preferences` for small settings; buffer runs locally if offline and reconcile on reconnect.
- **HTTP/realtime:** Supabase Flutter client handles this.

Prefer well-maintained, popular packages. When choosing a package, pick the one with the most pub.dev likes and recent updates, and tell me why.

---

## Part 3 — Architecture & folder structure

Keep a clean, feature-first structure. Create files as needed following this shape:

```
lib/
  main.dart
  app.dart                      # root widget, theme, routing
  core/
    theme.dart                  # colors, palette (colorblind-safe)
    constants.dart
    result.dart                 # simple success/error type
  services/
    map_service.dart            # abstract interface (swap Mapbox/MapLibre)
    mapbox_map_service.dart     # concrete Mapbox impl
    location_service.dart       # GPS position + speed stream (geolocator)
    geometry_service.dart       # loop detection, polygon math
    backend_service.dart        # Supabase auth + turf read/write
    anticheat_service.dart      # speed gating, plausibility checks
  features/
    run/                        # the active gameplay run
      run_controller.dart
      run_state.dart
      run_screen.dart
    map_world/                  # the persistent world map view
      world_controller.dart
      world_screen.dart
    profile/
      profile_screen.dart
    leaderboard/
      leaderboard_screen.dart
    onboarding/
      onboarding_screen.dart
  models/
    turf.dart                   # a claimed polygon + owner + color + timestamp
    player.dart
    run.dart
```

**Principles:**
- UI never talks to Supabase or Mapbox directly — always go through a `services/` class. This keeps things swappable and testable.
- One feature = one folder with its controller (logic), state, and screen (UI).
- Keep functions small. Comment the *why*, not the *what*.

---

## Part 4 — Data model (Supabase / PostGIS)

Tables to create (Claude Code: generate the SQL migration when we reach Phase 4):

- **players**: `id (uuid, from auth)`, `display_name`, `color` (hex), `total_area` (numeric), `created_at`.
- **turf**: `id`, `owner_id (fk players)`, `geom` (PostGIS `geometry(Polygon, 4326)`), `area` (numeric), `claimed_at`, `last_active_at` (for turf-fade later).
- **runs**: `id`, `player_id`, `distance`, `area_gained`, `duration`, `started_at`, `mode` (walk/run/cycle) — for stats and anti-cheat.

Use spatial indexes (`GIST`) on `turf.geom`. Turf steal = `ST_Difference`; new claim = insert polygon, subtract overlap from other owners' turf in a transaction. Only query turf near the player's viewport (`ST_DWithin`) to keep it cheap.

---

## Part 5 — Non-negotiable rules (safety, fairness, cost)

Bake these in from the start; do not defer them to "later":

1. **Anti-cheat / speed gating:** reject captures where implied speed exceeds the mode cap (walk/run/cycle). Flag altitude and road-network mismatches. Combine signals. Validate server-side, never trust the client.
2. **Privacy:** never expose a player's exact live location to other players — show *turf*, not people. Home base is block-level approximate, never an address. Be GDPR/CCPA-ready: let users delete their data.
3. **Physical safety:** show "eyes up, watch your surroundings" prompts; auto-pause a run if speed implies a car.
4. **Cost discipline:** batch GPS updates (every ~2–3 seconds, not every frame); cache map tiles; only stream/query turf genuinely near the player. Map loads and realtime volume are the two costs that spiral.
5. **Accessibility:** colorblind-safe ownership (use pattern/icon + color, never color alone).

---

## Part 6 — Coding conventions for Claude Code

- Explain your plan in 2–3 lines before writing code, then write it.
- After each feature, tell me exactly how to run/test it and what I should see.
- Prefer small, working increments over large dumps of code.
- When something needs a secret (Mapbox token, Supabase keys), put it in a `.env` file and add `.env` to `.gitignore` — never hardcode keys.
- Write a short comment at the top of each new file saying what it does.
- If a request is ambiguous, ask me one clarifying question rather than guessing.
- Assume I'm a beginner: explain new concepts briefly and in plain language.

---

## Part 7 — The Build Plan (do these in order)

Work one phase at a time. Run the app after each. **Copy the prompt block to Claude Code to start each phase.**

### Phase 0 — Project skeleton
> "Set up the folder structure from Part 3 of CLAUDE.md. Create empty service classes with clear TODOs, a basic theme with a colorblind-safe palette, Riverpod wired up, and a home screen with placeholder buttons for Start Run, Map, Profile, Leaderboard. Make it run on a simulator. Tell me how to run it."

**Done when:** app launches and shows a home screen.

### Phase 1 — Map on screen + my GPS dot
> "Integrate the Mapbox Flutter SDK behind the MapService interface. Show the real map centered on my current GPS location, with a dot that moves as I move. Use geolocator for location. Walk me through getting a Mapbox token and adding it via .env. Tell me how to test by walking."

**Done when:** you walk outside and your dot follows you on a real map.

### Phase 2 — Draw the trail
> "As my GPS position updates during an active run, draw a colored polyline trail behind my dot on the map. Add a Start Run / Stop Run button. Batch location updates to every ~2–3 seconds for cost. Show the trail clearly in my player color."

**Done when:** walking during a run leaves a visible trail line.

### Phase 3 — Capture the loop (the crucial one)
> "In geometry_service.dart, detect when my trail closes a loop (returns near its start or crosses itself). When it closes, build the enclosed polygon and fill it on the map in my color as claimed turf. Use a spatial/turf library for the polygon math — do not hand-roll geometry. Keep it all local for now (no server yet). Explain the loop-detection approach simply."

**Done when:** you walk a loop, close it, and the enclosed area fills with your color. **This is the moment you have a game — go walk your block and confirm it's fun.**

### Phase 4 — Persistence + accounts (backend)
> "Add Supabase. Generate the SQL migration for the players, turf, and runs tables from Part 4 with PostGIS and GIST indexes. Add anonymous or email auth. Save claimed turf polygons to the server and reload my turf when the app opens. Walk me through creating the Supabase project and adding keys to .env. Only query turf near my map viewport with ST_DWithin."

**Done when:** you claim turf, close the app, reopen, and your turf is still there.

### Phase 5 — Other players + stealing
> "Show other players' turf on the map in their colors (read from Supabase). When my new claim overlaps a rival's turf, subtract the overlap from them and add it to me using ST_Difference in a server-side transaction. Add a simple local leaderboard by total area. Add turf near-viewport realtime updates."

**Done when:** two accounts can see and take each other's turf.

### Phase 6 — Safety, anti-cheat, fairness
> "Implement anticheat_service.dart: reject captures implying speed above the walk/run/cycle cap, validated server-side. Auto-pause runs at car-like speeds. Add 'watch your surroundings' safety prompts. Ensure we never show another player's live position — only turf. Add a data-delete option for GDPR."

**Done when:** fake-fast movement is rejected and no live positions leak.

### Phase 7 — Polish + MVP launch prep
> "Add the 60-second onboarding first-run, an app icon, a run-summary screen (area gained, distance, time), and finalize the colorblind-safe palette. Prepare release builds and walk me through submitting to Google Play (and App Store if I'm on a Mac), including the privacy policy requirements for a location app."

**Done when:** a stranger could install it and understand it in one run.

### Phase 8 — Layers (only after MVP works)
Add these ONE at a time, each as its own prompt, from the feature spec: Home Base + streaks, Ghost Runs, daily challenges, perks (Sprint/Shield/Wide Brush/Recon), Neighborhood Wars, crews, seasons, photo flags.

---

## Part 8 — Definition of "MVP done"

The MVP is finished when all of this is true:
- Real map, walk mode, GPS trail, loop capture, turf steal, trail vulnerability.
- Turf persists on the server and is shared across players.
- Local leaderboard works.
- Anti-cheat speed gating + privacy (turf not people) + safety prompts are live.
- 60-second onboarding + run summary + app icon + colorblind palette.
- It builds as a release and passes store review.

Everything beyond that list is a V2/V3 layer. **Ship the MVP first.**

---

## Part 9 — Reminders for every session

- Build phase by phase; run and test after each.
- Never trust the client for anything that affects fairness — validate on the server.
- Keep secrets in `.env`, never in git.
- When stuck, paste the exact error and ask for a beginner-friendly fix.
- Test GPS features by physically walking with a real phone — not from a chair.