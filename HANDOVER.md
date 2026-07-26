# Claimr — Handover Guide

Everything a new developer needs to run, continue, and ship this project.

Claimr is a **Flutter** (Dart) mobile game — walk in the real world, close a GPS
loop, claim the enclosed land as territory. Backend is **Supabase** (Postgres +
PostGIS). Maps are **Mapbox**.

---

## 1. What you need installed

- **Flutter SDK** (3.12+) — https://docs.flutter.dev/get-started/install
- **Xcode** (for iPhone) and/or **Android Studio + Android SDK** (for Android)
- A code editor (VS Code or Android Studio)
- Accounts: a **Mapbox** account (free) and access to the **Supabase** project

Check your setup: `flutter doctor` (fix anything it flags).

---

## 2. Get the code running (5 minutes)

```bash
git clone https://github.com/pranaymunj/mob-game.git
cd mob-game
flutter pub get
cp .env.example .env      # then edit .env with real keys (see below)
```

### The `.env` file (secrets — never committed)
Open `.env` and fill in three values:

```
MAPBOX_PUBLIC_TOKEN=pk....        # from account.mapbox.com/access-tokens
SUPABASE_URL=https://xxxx.supabase.co
SUPABASE_PUBLISHABLE_KEY=sb_publishable_...   # Supabase → Project Settings → API
```

Ask Pranay for the current keys **OR** create your own projects (section 4).

### Run it
```bash
flutter run                       # pick a device when prompted
```

---

## 3. Mapbox — two tokens

Mapbox needs **two** tokens (a known gotcha):

1. **Public token** (`pk.…`) → goes in `.env` as `MAPBOX_PUBLIC_TOKEN` (used at runtime).
2. **Secret/download token** (`sk.…`, scope: `DOWNLOADS:READ`) → needed to
   download the Mapbox native SDK at build time:
   - **iOS:** put it in `~/.netrc`:
     ```
     machine api.mapbox.com
       login mapbox
       password sk.your_secret_token
     ```
   - **Android:** put it in `~/.gradle/gradle.properties`:
     ```
     MAPBOX_DOWNLOADS_TOKEN=sk.your_secret_token
     ```

Without the secret token, the app won't build (it can't fetch the map SDK).

---

## 4. Supabase — the backend

All the game logic (claiming, coins, leagues, anti-cheat) lives in the database
as SQL functions. There are **26 migration files** in `supabase/migrations/`
(`0001_…` through `0026_…`), applied in order.

### Option A — reuse Pranay's existing project (fastest)
Just use the `SUPABASE_URL` + `SUPABASE_PUBLISHABLE_KEY` he gives you. The
database is already set up. You share the same backend. Good for continuing dev.

### Option B — your own fresh Supabase project
1. Create a project at supabase.com (free tier is fine).
2. **Enable PostGIS:** SQL Editor → run `create extension if not exists postgis;`
3. Run each file in `supabase/migrations/` **in numeric order** (0001, 0002, …
   0026) by pasting its contents into the SQL Editor and clicking Run.
4. **Turn off email confirmation:** Authentication → Providers → Email →
   uncheck "Confirm email" (needed for the in-app account linking to work).
5. Put your project's URL + publishable key in `.env`.

### Important Supabase notes
- **Anonymous auth must be ON:** Authentication → Providers → enable Anonymous.
  The game signs players in anonymously on first launch.
- **Security:** clients can only *read* game tables; all writes go through
  `SECURITY DEFINER` functions (this is deliberate — see migration
  `0019_lock_down_writes.sql`). Do not add table write policies.
- **Test data cleanup:** development left throwaway accounts/turf in the DB. Run
  `supabase/maintenance/cleanup_test_data.sql` (Option A = full reset) before
  any real launch.

---

## 5. Project layout

```
lib/
  main.dart            app entry (loads .env, inits Mapbox + Supabase)
  app.dart             splash → onboarding → home routing + theme
  core/                theme.dart (design system), ui_kit.dart, constants.dart
  services/            map, location, geometry, Kalman, backend (Supabase),
                       anti-cheat, analytics, notifications, geocoding
  features/            one folder per screen:
    home/ run/ map_world/ shop/ profile/ leaderboard/ friends/ history/
    settings/ help/ onboarding/ splash/ progression/ perks/
  models/              plain data classes (player, turf, run, etc.)
supabase/migrations/   the 26 SQL migrations (the whole backend)
test/                  33 automated tests (flutter test)
```

**Golden rule:** the UI never talks to Supabase/Mapbox directly — always through
a class in `services/`. Keeps things swappable and testable.

---

## 6. Common commands

```bash
flutter run                 # run on a connected device/simulator
flutter analyze             # static analysis (keep it clean)
flutter test                # run the 33 tests
flutter build apk --release # Android release APK (see section 7)
flutter build ios --release # iOS release build (needs a Mac + Xcode)
```

---

## 7. Putting it on an Android phone

1. One-time: enable **Developer Options** on the phone (tap Build Number 7×),
   then turn on **USB debugging**.
2. Make sure the Mapbox **secret** token is in `~/.gradle/gradle.properties`
   (section 3).
3. Plug the phone in via USB, then:
   ```bash
   flutter run --release        # installs + launches on the phone
   ```
   OR build a shareable file and sideload it:
   ```bash
   flutter build apk --release
   # output: build/app/outputs/flutter-apk/app-release.apk
   ```
   Send that `.apk` to the phone, tap it, allow "install from unknown sources".

Android permissions (location, notifications) are already configured in
`android/app/src/main/AndroidManifest.xml`.

---

## 8. Where to start reading the code

1. `lib/features/run/run_controller.dart` — the heart: GPS → trail → loop
   detection → claim. This is the core game logic.
2. `lib/services/backend_service.dart` — every call to the server.
3. `supabase/migrations/` — read `0001` (schema) then skim later files to see
   how each feature's backend works.

See `GAME_OVERVIEW.md` for a plain-English tour of all the features.
