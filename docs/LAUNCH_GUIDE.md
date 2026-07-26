# Claimr — Release & Store Submission Guide

A beginner-friendly, step-by-step guide to shipping the MVP. Do the common prep
first, then the platform you want (Android is faster to review; iOS needs a Mac,
which you have).

---

## 0. Before you build

- [ ] Replace the contact email in [PRIVACY_POLICY.md](PRIVACY_POLICY.md) and
      **host it at a public URL** (GitHub Pages, Notion public page, or your
      site). Both stores require a privacy-policy URL for location apps.
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
Then wire it into `android/app/build.gradle` (signingConfigs → release). Ask me
and I'll edit the Gradle file for you.

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

- **Justify background location**: we only request *while in use* — do not add
  "always" unless you build background runs, or review will push back.
- **Privacy policy must be reachable** and match the in-app data-delete.
- **Physical-safety**: our "eyes up" prompt + auto-pause demonstrate diligence;
  keep them.
- **No live player tracking**: never expose other users' real-time location.

---

## 4. MVP definition of done (from CLAUDE.md Part 8)

- [x] Real map, walk mode, GPS trail, loop capture, turf steal
- [x] Turf persists on the server, shared across players
- [x] Local leaderboard
- [x] Anti-cheat speed gating + privacy (turf, not people) + safety prompts
- [x] Onboarding + run summary + app icon + colorblind palette
- [ ] Builds as a release and passes store review ← **this guide**
