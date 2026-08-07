# Claimr — Release & Store Submission Guide

A beginner-friendly, step-by-step guide to shipping the MVP. Do the common prep
first, then the platform you want (Android is faster to review; iOS needs a Mac,
which you have).

---

## 0. Before you build

- [ ] **Host the privacy policy.** It lives at [PRIVACY.md](PRIVACY.md). Both
      stores require a reachable URL for location apps, and reviewers follow the
      link. Fastest free route — GitHub Pages, about two minutes:

      1. GitHub → your repo → **Settings** → **Pages**
      2. Source: **Deploy from a branch**; Branch: `main`, folder: `/docs`
      3. Save, wait ~1 minute, then open
         <https://pranaymunj.github.io/mob-game/PRIVACY.html> and confirm it
         loads in a private window (a page only you can see fails review).

      That exact URL is already in the app as `AppConstants.privacyPolicyUrl`
      and is linked from Settings → Privacy policy. If you host it elsewhere,
      change the constant to match — a dead link there is a rejection.
- [ ] Confirm `.env` is filled and **never committed** (it's gitignored).
- [ ] Pick a final app name / bundle id. Current id: `com.claimr.claimr`.
- [ ] Bump the version in `pubspec.yaml` (`version: 1.0.0+1` → build number `+1`).
- [ ] Test on a **real phone** by walking a loop (simulators fake GPS).

Regenerate the app icon anytime with:
```bash
dart run tool/generate_icon.dart && dart run flutter_launcher_icons
```

---

## 1. Android → Google Play

### One-time setup
1. Create a **Google Play Console** account ($25 once) at play.google.com/console.
2. In the Console: **Create app** → name "Claimr", type **Game**, free.

### Signing (so you can upload a release)
Create an upload keystore (keep it safe — losing it means you can't update the app):
```bash
keytool -genkey -v -keystore ~/claimr-upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
Create `android/key.properties` (gitignore it):
```
storePassword=YOUR_PASSWORD
keyPassword=YOUR_PASSWORD
keyAlias=upload
storeFile=/Users/YOU/claimr-upload.jks
```
**No Gradle edit needed** — `android/app/build.gradle.kts` already reads
`key.properties` and uses the release key when the file exists, falling back to
the debug key when it doesn't. Create the file and the next release build is
signed.

Two things worth knowing, because both are unrecoverable:
- **Back up the `.jks` file and its passwords.** Lose them and you can never
  update this app on Play again — you'd have to ship a new listing and abandon
  your installs.
- **Never commit either.** `key.properties` is gitignored; keep the keystore
  outside the repo entirely.

### Build the release
```bash
flutter build appbundle --release
# output: build/app/outputs/bundle/release/app-release.aab
```

### Store listing & submission
1. **App content** section — fill out:
   - **Privacy policy URL** (from step 0).
   - **Data safety form**: declare you collect **Location (precise)**, **App
     activity**, and a user id; used for **app functionality**; not sold; users
     can request deletion. (Matches our privacy policy.)
   - **Permissions**: location is used **while in use** only.
2. **Store listing**: short + full description, app icon (auto from the build),
   at least 2 phone screenshots, a feature graphic (1024×500).
3. Upload the `.aab` to **Internal testing** first → add your email as a tester →
   install via the opt-in link and verify.
4. Promote to **Production** when happy. First review usually takes a few days.

---

## 2. iOS → App Store (you're on a Mac ✅)

### One-time setup
1. Enroll in the **Apple Developer Program** ($99/year) at developer.apple.com.
2. In **App Store Connect** (appstoreconnect.apple.com): **My Apps → +** →
   new app, pick the bundle id `com.claimr.claimr` (register it under
   Certificates, Identifiers & Profiles first if needed).

### Build & upload
1. Open the iOS workspace in Xcode:
   ```bash
   open ios/Runner.xcworkspace
   ```
2. Select **Runner** target → **Signing & Capabilities** → choose your Team
   (Xcode manages signing automatically).
3. Set **Product → Destination → Any iOS Device**, then **Product → Archive**.
4. In the Organizer window: **Distribute App → App Store Connect → Upload**.

Or from the CLI:
```bash
flutter build ipa --release
# then open build/ios/archive/*.xcarchive in Xcode Organizer to upload
```

### Store listing & review
1. In App Store Connect: add **screenshots** (6.7" and 6.1" iPhone),
   description, keywords, support URL, and the **privacy policy URL**.
2. **App Privacy** section: declare **Location (precise)** used for **App
   Functionality**, linked to the user, not used for tracking.
3. **Location usage string** is already set in `Info.plist`
   (`NSLocationWhenInUseUsageDescription`). Apple reviewers test this — make sure
   the string clearly explains the game use (it does).
4. Submit for review. Location apps sometimes get extra scrutiny; the honest
   "turf, not people" privacy design helps.

---

## 3. Common review gotchas for location games

- **Background location — we DO use it, so be ready to justify it.** An earlier
  version of this guide said we only request "while in use". That is no longer
  true: the app sets `allowBackgroundLocationUpdates` on iOS and declares
  `ACCESS_BACKGROUND_LOCATION` on Android, because tracking has to survive a
  locked screen or the game would force players to walk staring at the phone.

  Declare it honestly and lead with the safety argument. What helps: tracking
  runs **only during an active run**, iOS shows the blue status-bar indicator
  throughout, Android shows a persistent notification, and the app auto-pauses
  at vehicle speed. Answer Play's Location Permissions declaration and Apple's
  privacy questions to match — a mismatch between what you declare and what the
  binary does is the most common rejection for location games.
- **Privacy policy must be reachable** and match the in-app data-delete.
- **Physical-safety**: our "eyes up" prompt + auto-pause demonstrate diligence;
  keep them.
- **No live player tracking**: never expose other users' real-time location.

---

## 4. MVP definition of done (from CLAUDE.md Part 8)

- [x] Real map, walk mode, GPS trail, loop capture, turf steal
- [x] **Trail vulnerability** — an open trail expires after 12 minutes
- [x] Turf persists on the server, shared across players
- [x] Local leaderboard
- [x] Privacy (turf, not people) + safety prompts + data delete
- [ ] **Anti-cheat speed gating LIVE** — the code is written, but
      `supabase/migrations/0028_claim_integrity.sql` has not been applied, so
      the server is not yet enforcing it. Run it, then run
      `supabase/maintenance/verify_claim_integrity.sql` to prove it took.
- [x] Onboarding + run summary + app icon + colorblind palette
- [ ] Privacy policy hosted at a public URL (§0)
- [ ] Android upload keystore created (§1)
- [ ] Tested on a real phone by walking a loop
- [ ] Builds as a release and passes store review ← **this guide**
