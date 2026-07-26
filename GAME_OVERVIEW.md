# Claimr — What the Game Is (plain English)

## The one-line idea
**paper.io, but played on the real world with your phone's GPS.** You walk
around outside; your path draws a trail on a real map; when you loop back to
where you started, the enclosed patch of the real world becomes *your*
territory. It stays on the map and everyone can see it.

## The core loop (what a player actually does)
1. Open the app, tap **START RUN**.
2. Walk outside — your GPS trail follows you on the map.
3. Walk a loop (around a block, a park, a parking lot) and head back toward your
   start.
4. When you get close, either it **auto-closes** or you tap the **CLAIM** button.
5. The middle of your loop **fills with your colour** — you've claimed that land.
   Confetti, a sound, a buzz, and it tells you the neighbourhood: *"You claimed
   turf in Bandra!"*
6. You earn **coins**, and your territory is saved forever and shared with all
   players.

That's the whole game. Everything else is a layer on top of that one moment.

---

## Every feature, grouped

### 🗺️ Core gameplay
- **Real GPS map** centred on you, with everyone's claimed turf shown in owner
  colours.
- **Trail + loop capture** — the walk-and-close-a-loop mechanic above.
- **Manual CLAIM button** — if GPS is imperfect and the loop won't auto-close,
  a button force-closes it when you're near your start. (This is what makes it
  actually work outdoors.)
- **Live loop preview** — as you near your start, it shows the exact m² and
  coins you'd get, with a dashed line back to your start.
- **Smart GPS** — a smoothing filter (Kalman) cleans up jittery GPS so the trail
  is accurate and distance isn't inflated by drift.
- **Background tracking** — put the phone in your pocket and it keeps recording.

### 🏆 Territory
- **Stealing** — walk over a rival's turf and you take the overlap from them.
- **Territory levels** — re-walk your OWN turf to level it up (1→5). Higher
  levels look richer/brighter on the map, give bonus coins, and resist decay
  longer.
- **Decay** — turf you never revisit slowly fades and eventually frees up, so
  you have to defend your empire.
- **Neighborhood Wars** — the map is split into ~1 km zones; whoever holds the
  most turf in a zone "controls" it.

### 💰 Economy
- **Coins** — earned by walking (1 per 50 m) AND by claiming turf (1 per 100 m²).
  So walking always pays, even if you don't close a loop.
- **Shop** — spend coins on:
  - **Perks:** Sprint, Recon, Wide Brush, Shield (protects your turf from theft
    for 24h).
  - **Trail skins** (5): change your trail's colour/glow.
  - **Turf styles** (4): change how your claimed land looks on everyone's map —
    the flex other players actually see.
- **Power-up pickups** — 🎁 boxes spawn on the map; walk over one to grab a perk.

### 📈 Progression & daily habits
- **Levels + XP** — level up from total territory ever claimed.
- **Achievements** — badges like "First Claim", "Landowner", "Empire".
- **Daily challenge** — a rotating goal (claim X m² / close X loops / walk X km).
- **Daily login reward** — a 7-day escalating coin ladder (day 7 = big + a perk).
- **Streaks** — play consecutive days to build a streak.

### 🥇 Competition & social
- **Leaderboards** — Players / Crews / Season / **League** tabs.
- **Leagues** — divisions from Bronze → Diamond (set by lifetime territory),
  competing on this week's area, with medal-ringed top-3 ranks.
- **Crews** — team up; members pool their turf on the leaderboard.
- **Friends + referrals** — share your code; when a friend uses it you both get
  coins, and you see each other on a friends board.
- **Seasons** — time-boxed competition that resets.
- **Photo flags** — plant a photo at a real spot on the map for others to find.

### ✨ Feel & safety
- **Bold "Clash-Royale" style UI** — chunky panels, 3D buttons that sink when
  pressed, gold/green/blue colour system.
- **Capture celebration** — the big confetti + count-up moment when you claim.
- **Onboarding** — a short first-run explainer, plus a *guided first capture*
  (it draws a suggested square for you to walk so your first claim can't fail).
- **Anti-cheat** — the server rejects impossible speeds (you can't drive and
  claim). All validation is server-side, so it can't be faked.
- **Privacy** — the game shows *turf, never people*. Your live location is never
  shown to others. Home base is stored only at approximate block level.
- **Safety** — "eyes up, watch your surroundings" prompts; auto-pauses if you
  move at car speed.
- **Accessibility** — colourblind-safe colours, sound/vibration toggles,
  metric/imperial units.

---

## How it's built (one paragraph for your friend)
Flutter app (one codebase for iPhone + Android). The **phone** handles the live
experience (GPS, trail, preview). The **Supabase** database is the source of
truth: all the important rules (who owns what, coins, anti-cheat) are SQL
functions on the server, so the app can't cheat them. Maps are Mapbox. See
`HANDOVER.md` for how to run it.

---

## The one thing still to prove
The whole game works and is tested, but the *real-world block walk* — going
outside and actually claiming a real loop — is the final field test. Everything
is built to make it succeed (guided square, manual claim button, smooth GPS).
That's the fun "does it really work in your hand" moment to try first.
