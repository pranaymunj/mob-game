// backend_service.dart — Supabase auth + turf read/write (Phase 4-5).
// Anonymous auth; claims saved via the claim_turf RPC (server stamps owner,
// builds geometry, and steals overlap from rivals). Reads use turf_near
// (ST_DWithin) so we only fetch turf around the viewport (CLAUDE.md Part 4/5).

import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/challenge.dart';
import '../models/crew.dart';
import '../models/photo_flag.dart';
import '../models/pickup.dart';
import '../models/player.dart';
import '../models/player_stats.dart';
import '../models/run.dart';
import '../models/turf.dart';
import '../models/zone.dart';

abstract class BackendService {
  Future<void> signIn();
  String? get currentUserId;

  Future<String?> saveClaim({
    required List<List<double>> ring,
    required double area,
    String mode,
    double distanceM,
    double durationS,
  });

  // GDPR/CCPA: erase all data tied to this account, then sign out.
  Future<void> deleteMyData();

  Future<List<Turf>> turfNear({
    required double lng,
    required double lat,
    required double radiusMeters,
  });

  Future<List<Player>> leaderboard({int limit});

  // Profile — name, colour and avatar.
  Future<void> updateProfile({
    required String name,
    required String colorHex,
    String? avatar,
  });

  // Account — an anonymous install can be upgraded to a real account so turf
  // survives a reinstall or a new phone.
  bool get isAnonymousAccount;
  String? get accountEmail;
  Future<void> linkEmail({required String email, required String password});
  Future<void> signInWithEmail({required String email, required String password});
  Future<void> signOut();

  // Phase 8 — Home Base + streaks.
  Future<Player?> myPlayer();
  Future<void> setHomeBase({required double lng, required double lat});
  Future<void> recordActivity();

  // Phase 8 — today's shared daily challenge + this player's progress.
  Future<Challenge?> challengeStatus();

  // Shop — spend coins on a perk; returns the remaining balance.
  Future<int> buyPerk(String perk);

  // Cosmetics — owned item keys + currently equipped trail/turf.
  Future<({List<String> owned, String trail, String turf})?> myCosmetics();
  Future<int> buyCosmetic(String itemKey); // returns remaining balance
  Future<void> equipCosmetic(String itemKey);

  // Called when a run ends (capture or not) so walking always earns something.
  // Returns the coins awarded for the distance.
  Future<int> finishRun({
    required double distanceM,
    required double durationS,
    String mode,
  });

  // Run history — this player's past runs, newest first.
  Future<List<Run>> myRuns({int limit});

  // Daily login ladder — (day, claimable, nextCoins).
  Future<({int day, bool claimable, int nextCoins})?> dailyLoginStatus();
  Future<({int day, int coins, String? perk})> claimLoginReward();

  // Phase 8 — perks (inventory, earn from the daily challenge, activate).
  Future<Map<String, int>> perks();
  Future<String> claimDailyReward(); // returns the perk granted
  Future<void> activatePerk(String perk);

  // Phase 8 — crews (teams).
  Future<String?> myCrewName();
  Future<void> createCrew(String name);
  Future<void> joinCrew(String name);
  Future<void> leaveCrew();
  Future<List<Crew>> crewLeaderboard({int limit});

  // Phase 8 — seasons (time-boxed leaderboard).
  Future<String?> currentSeasonName();
  Future<List<Player>> seasonLeaderboard({int limit});

  // Phase 8 — ghost runs (save/replay your best route).
  Future<void> saveGhostRun({required List<List<double>> path, required double distanceM});
  Future<List<List<double>>> ghostRunPath();

  // Phase 8 — photo flags (leave a photo on the map).
  Future<void> addPhotoFlag({
    required double lng,
    required double lat,
    required Uint8List bytes,
    String? caption,
  });
  Future<List<PhotoFlag>> flagsNear({
    required double lng,
    required double lat,
    required double radiusMeters,
  });

  // Phase 8 — Neighborhood Wars: which owner controls each ~1km zone.
  Future<List<Zone>> zonesNear({
    required double lng,
    required double lat,
    required double radiusMeters,
  });

  // Progression — lifetime stats for levels + achievements.
  Future<PlayerStats?> playerStats();

  // Leagues — your tier + weekly standing, and your division's ranking.
  Future<({int tier, String label, double weekly, int rank, int size})?>
      leagueStatus();
  Future<List<Player>> leagueStandings({int limit});

  // Friends + referrals.
  Future<String> myReferralCode();
  Future<int> redeemReferral(String code); // returns new balance
  Future<void> addFriend(String code);
  Future<List<Player>> friendsBoard();

  // Power-up pickups — collectibles on the map.
  Future<List<Pickup>> pickupsNear({
    required double lng,
    required double lat,
    required double radiusMeters,
  });
  Future<void> spawnPickupsNear({required double lng, required double lat});
  Future<String> collectPickup(String id); // returns the perk granted

  // Fire `onChange` whenever turf changes anywhere (Phase 5 realtime).
  RealtimeChannel subscribeTurf(void Function() onChange);
}

class SupabaseBackendService implements BackendService {
  SupabaseClient get _db => Supabase.instance.client;

  @override
  String? get currentUserId => _db.auth.currentUser?.id;

  @override
  Future<void> signIn() async {
    if (_db.auth.currentUser != null) return;
    await _db.auth.signInAnonymously();
  }

  @override
  Future<String?> saveClaim({
    required List<List<double>> ring,
    required double area,
    String mode = 'walk',
    double distanceM = 0,
    double durationS = 0,
  }) async {
    final geojson = jsonEncode({
      'type': 'Polygon',
      'coordinates': [ring],
    });
    final id = await _db.rpc('claim_turf', params: {
      'ring_geojson': geojson,
      'area_m': area,
      'mode': mode,
      'distance_m': distanceM,
      'duration_s': durationS,
    });
    return id as String?;
  }

  @override
  Future<void> deleteMyData() async {
    await _db.rpc('delete_my_data');
    await _db.auth.signOut();
  }

  @override
  bool get isAnonymousAccount => _db.auth.currentUser?.isAnonymous ?? true;

  @override
  String? get accountEmail => _db.auth.currentUser?.email;

  // Upgrade the current anonymous user in place: the user id is preserved, so
  // all existing turf, perks and progress carry over.
  @override
  Future<void> linkEmail({
    required String email,
    required String password,
  }) async {
    await _db.auth.updateUser(
      UserAttributes(email: email, password: password),
    );
  }

  @override
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    await _db.auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<void> signOut() async {
    await _db.auth.signOut();
  }

  @override
  Future<void> updateProfile({
    required String name,
    required String colorHex,
    String? avatar,
  }) async {
    await _db.rpc('update_profile', params: {
      'new_name': name,
      'new_color': colorHex,
      'new_avatar': avatar,
    });
  }

  @override
  Future<Player?> myPlayer() async {
    final id = currentUserId;
    if (id == null) return null;
    final row = await _db
        .from('players')
        .select(
            'id, display_name, color, avatar, coins, total_area, home_lng, home_lat, current_streak, longest_streak')
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return Player(
      id: row['id'] as String,
      displayName: (row['display_name'] as String?) ?? 'Player',
      colorValue: _hexToArgb((row['color'] as String?) ?? '#56B4E9'),
      colorHex: (row['color'] as String?) ?? '#56B4E9',
      avatar: row['avatar'] as String?,
      coins: (row['coins'] as num?)?.toInt() ?? 0,
      totalArea: (row['total_area'] as num?)?.toDouble() ?? 0,
      homeLng: (row['home_lng'] as num?)?.toDouble(),
      homeLat: (row['home_lat'] as num?)?.toDouble(),
      currentStreak: (row['current_streak'] as num?)?.toInt() ?? 0,
      longestStreak: (row['longest_streak'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<void> setHomeBase({required double lng, required double lat}) async {
    await _db.rpc('set_home_base', params: {'lng': lng, 'lat': lat});
  }

  @override
  Future<void> recordActivity() async {
    await _db.rpc('record_activity');
  }

  @override
  Future<List<Pickup>> pickupsNear({
    required double lng,
    required double lat,
    required double radiusMeters,
  }) async {
    final rows = await _db.rpc('pickups_near', params: {
      'p_lng': lng,
      'p_lat': lat,
      'radius_m': radiusMeters,
    }) as List<dynamic>;
    return rows.map((r) {
      final row = r as Map<String, dynamic>;
      return Pickup(
        id: row['id'] as String,
        lng: (row['lng'] as num).toDouble(),
        lat: (row['lat'] as num).toDouble(),
        perk: row['perk'] as String,
      );
    }).toList();
  }

  @override
  Future<void> spawnPickupsNear({
    required double lng,
    required double lat,
  }) async {
    await _db.rpc('spawn_pickups_near', params: {'p_lng': lng, 'p_lat': lat});
  }

  @override
  Future<String> collectPickup(String id) async {
    final perk = await _db.rpc('collect_pickup', params: {'pickup_id': id});
    return perk as String;
  }

  @override
  Future<String> myReferralCode() async {
    final code = await _db.rpc('my_referral_code');
    return code as String;
  }

  @override
  Future<int> redeemReferral(String code) async {
    final balance = await _db.rpc('redeem_referral', params: {'friend_code': code});
    return (balance as num).toInt();
  }

  @override
  Future<void> addFriend(String code) async {
    await _db.rpc('add_friend', params: {'friend_code': code});
  }

  @override
  Future<List<Player>> friendsBoard() async {
    final rows = await _db.rpc('friends_board') as List<dynamic>;
    return rows.map((r) {
      final row = r as Map<String, dynamic>;
      return Player(
        id: row['fid'] as String,
        displayName: (row['fname'] as String?) ?? 'Player',
        colorValue: _hexToArgb((row['fcolor'] as String?) ?? '#56B4E9'),
        avatar: row['favatar'] as String?,
        totalArea: (row['warea'] as num?)?.toDouble() ?? 0, // weekly
      );
    }).toList();
  }

  @override
  Future<({int tier, String label, double weekly, int rank, int size})?>
      leagueStatus() async {
    final rows = await _db.rpc('league_status') as List<dynamic>;
    if (rows.isEmpty) return null;
    final row = rows.first as Map<String, dynamic>;
    return (
      tier: (row['tier'] as num).toInt(),
      label: row['tier_label'] as String,
      weekly: (row['weekly_area'] as num?)?.toDouble() ?? 0,
      rank: (row['rank'] as num?)?.toInt() ?? 0,
      size: (row['division_size'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<List<Player>> leagueStandings({int limit = 25}) async {
    final rows = await _db
        .rpc('league_standings', params: {'lim': limit}) as List<dynamic>;
    return rows.map((r) {
      final row = r as Map<String, dynamic>;
      return Player(
        id: row['pid'] as String,
        displayName: (row['pname'] as String?) ?? 'Player',
        colorValue: _hexToArgb((row['pcolor'] as String?) ?? '#56B4E9'),
        avatar: row['pavatar'] as String?,
        totalArea: (row['warea'] as num?)?.toDouble() ?? 0, // weekly here
      );
    }).toList();
  }

  @override
  Future<PlayerStats?> playerStats() async {
    final rows = await _db.rpc('player_stats') as List<dynamic>;
    if (rows.isEmpty) return null;
    final row = rows.first as Map<String, dynamic>;
    return PlayerStats(
      lifetimeArea: (row['lifetime_area'] as num?)?.toDouble() ?? 0,
      runCount: (row['run_count'] as num?)?.toInt() ?? 0,
      currentArea: (row['current_area'] as num?)?.toDouble() ?? 0,
      longestStreak: (row['longest_streak'] as num?)?.toInt() ?? 0,
      currentStreak: (row['current_streak'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  Future<List<Zone>> zonesNear({
    required double lng,
    required double lat,
    required double radiusMeters,
  }) async {
    final rows = await _db.rpc('zones_near', params: {
      'p_lng': lng,
      'p_lat': lat,
      'radius_m': radiusMeters,
    }) as List<dynamic>;
    return rows.map((r) {
      final row = r as Map<String, dynamic>;
      return Zone(
        cx: (row['cx'] as num).toInt(),
        cy: (row['cy'] as num).toInt(),
        ownerId: row['owner_id'] as String,
        colorHex: (row['color'] as String?) ?? '#56B4E9',
        area: (row['area'] as num?)?.toDouble() ?? 0,
      );
    }).toList();
  }

  @override
  Future<void> addPhotoFlag({
    required double lng,
    required double lat,
    required Uint8List bytes,
    String? caption,
  }) async {
    final id = currentUserId;
    if (id == null) return;
    // Upload the image to the public 'flags' bucket, then record the flag.
    final path = '$id/${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _db.storage.from('flags').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
    final url = _db.storage.from('flags').getPublicUrl(path);
    await _db.from('photo_flags').insert({
      'owner_id': id,
      'lng': lng,
      'lat': lat,
      'url': url,
      'caption': caption,
    });
  }

  @override
  Future<List<PhotoFlag>> flagsNear({
    required double lng,
    required double lat,
    required double radiusMeters,
  }) async {
    final rows = await _db.rpc('flags_near', params: {
      'p_lng': lng,
      'p_lat': lat,
      'radius_m': radiusMeters,
    }) as List<dynamic>;
    return rows.map((r) {
      final row = r as Map<String, dynamic>;
      return PhotoFlag(
        id: row['id'] as String,
        ownerId: row['owner_id'] as String,
        lng: (row['lng'] as num).toDouble(),
        lat: (row['lat'] as num).toDouble(),
        url: row['url'] as String,
        caption: row['caption'] as String?,
      );
    }).toList();
  }

  @override
  Future<void> saveGhostRun({
    required List<List<double>> path,
    required double distanceM,
  }) async {
    if (path.length < 2) return;
    await _db.rpc('save_ghost_run', params: {
      'run_path': path,
      'dist': distanceM,
    });
  }

  @override
  Future<List<List<double>>> ghostRunPath() async {
    final id = currentUserId;
    if (id == null) return const [];
    final row = await _db
        .from('ghost_runs')
        .select('path')
        .eq('player_id', id)
        .maybeSingle();
    final path = row?['path'];
    if (path is! List) return const [];
    return path
        .map<List<double>>(
            (p) => [(p[0] as num).toDouble(), (p[1] as num).toDouble()])
        .toList();
  }

  @override
  Future<String?> currentSeasonName() async {
    final rows = await _db.rpc('current_season') as List<dynamic>;
    if (rows.isEmpty) return null;
    return (rows.first as Map<String, dynamic>)['name'] as String?;
  }

  @override
  Future<List<Player>> seasonLeaderboard({int limit = 20}) async {
    final rows = await _db
        .rpc('season_leaderboard', params: {'lim': limit}) as List<dynamic>;
    return rows.map((r) {
      final row = r as Map<String, dynamic>;
      return Player(
        id: row['player_id'] as String,
        displayName: 'Player',
        colorValue: _hexToArgb((row['color'] as String?) ?? '#56B4E9'),
        totalArea: (row['area'] as num?)?.toDouble() ?? 0,
      );
    }).toList();
  }

  @override
  Future<String?> myCrewName() async {
    final id = currentUserId;
    if (id == null) return null;
    final row = await _db
        .from('players')
        .select('crews(name)')
        .eq('id', id)
        .maybeSingle();
    final crew = row?['crews'];
    if (crew is Map && crew['name'] != null) return crew['name'] as String;
    return null;
  }

  @override
  Future<void> createCrew(String name) async {
    await _db.rpc('create_crew', params: {'crew_name': name});
  }

  @override
  Future<void> joinCrew(String name) async {
    await _db.rpc('join_crew', params: {'crew_name': name});
  }

  @override
  Future<void> leaveCrew() async {
    await _db.rpc('leave_crew');
  }

  @override
  Future<List<Crew>> crewLeaderboard({int limit = 20}) async {
    final rows =
        await _db.rpc('crew_leaderboard', params: {'lim': limit}) as List<dynamic>;
    return rows.map((r) {
      final row = r as Map<String, dynamic>;
      return Crew(
        id: row['id'] as String,
        name: row['name'] as String,
        colorHex: (row['color'] as String?) ?? '#0072B2',
        members: (row['members'] as num?)?.toInt() ?? 0,
        totalArea: (row['total_area'] as num?)?.toDouble() ?? 0,
      );
    }).toList();
  }

  @override
  Future<int> finishRun({
    required double distanceM,
    required double durationS,
    String mode = 'walk',
  }) async {
    final earned = await _db.rpc('finish_run', params: {
      'distance_m': distanceM,
      'duration_s': durationS,
      'mode': mode,
    });
    return (earned as num?)?.toInt() ?? 0;
  }

  @override
  Future<List<Run>> myRuns({int limit = 50}) async {
    final id = currentUserId;
    if (id == null) return const [];
    final rows = await _db
        .from('runs')
        .select('id, player_id, distance, area_gained, duration, started_at, mode')
        .eq('player_id', id)
        .order('started_at', ascending: false)
        .limit(limit) as List<dynamic>;
    return rows.map((r) {
      final row = r as Map<String, dynamic>;
      return Run(
        id: row['id'].toString(),
        playerId: row['player_id'] as String,
        distance: (row['distance'] as num?)?.toDouble() ?? 0,
        areaGained: (row['area_gained'] as num?)?.toDouble() ?? 0,
        duration: Duration(seconds: (row['duration'] as num?)?.toInt() ?? 0),
        startedAt: DateTime.parse(row['started_at'] as String),
        mode: RunMode.values.firstWhere(
          (m) => m.name == (row['mode'] as String?),
          orElse: () => RunMode.walk,
        ),
      );
    }).toList();
  }

  @override
  Future<({int day, bool claimable, int nextCoins})?> dailyLoginStatus() async {
    final rows = await _db.rpc('daily_login_status') as List<dynamic>;
    if (rows.isEmpty) return null;
    final row = rows.first as Map<String, dynamic>;
    return (
      day: (row['day'] as num).toInt(),
      claimable: row['claimable'] as bool,
      nextCoins: (row['next_coins'] as num).toInt(),
    );
  }

  @override
  Future<({int day, int coins, String? perk})> claimLoginReward() async {
    final rows = await _db.rpc('claim_login_reward') as List<dynamic>;
    final row = rows.first as Map<String, dynamic>;
    return (
      day: (row['day'] as num).toInt(),
      coins: (row['coins_awarded'] as num).toInt(),
      perk: row['perk'] as String?,
    );
  }

  @override
  Future<int> buyPerk(String perk) async {
    final remaining = await _db.rpc('buy_perk', params: {'perk_key': perk});
    return (remaining as num).toInt();
  }

  @override
  Future<({List<String> owned, String trail, String turf})?>
      myCosmetics() async {
    final rows = await _db.rpc('my_cosmetics') as List<dynamic>;
    if (rows.isEmpty) return null;
    final row = rows.first as Map<String, dynamic>;
    final ownedRaw = (row['owned'] as List<dynamic>? ?? const []);
    return (
      owned: ownedRaw.map((e) => e.toString()).toList(),
      trail: (row['trail'] as String?) ?? 'trail_classic',
      turf: (row['turf'] as String?) ?? 'turf_solid',
    );
  }

  @override
  Future<int> buyCosmetic(String itemKey) async {
    final remaining =
        await _db.rpc('buy_cosmetic', params: {'item_key': itemKey});
    return (remaining as num).toInt();
  }

  @override
  Future<void> equipCosmetic(String itemKey) async {
    await _db.rpc('equip_cosmetic', params: {'item_key': itemKey});
  }

  @override
  Future<Map<String, int>> perks() async {
    final id = currentUserId;
    if (id == null) return {};
    final rows = await _db
        .from('player_perks')
        .select('perk, qty')
        .eq('player_id', id) as List<dynamic>;
    return {
      for (final r in rows)
        (r as Map<String, dynamic>)['perk'] as String: (r['qty'] as num).toInt(),
    };
  }

  @override
  Future<String> claimDailyReward() async {
    final perk = await _db.rpc('claim_daily_reward');
    return perk as String;
  }

  @override
  Future<void> activatePerk(String perk) async {
    await _db.rpc('activate_perk', params: {'perk_key': perk});
  }

  @override
  Future<Challenge?> challengeStatus() async {
    final rows = await _db.rpc('challenge_status') as List<dynamic>;
    if (rows.isEmpty) return null;
    final row = rows.first as Map<String, dynamic>;
    return Challenge(
      metric: row['metric'] as String,
      target: (row['target'] as num).toDouble(),
      label: row['label'] as String,
      progress: (row['progress'] as num).toDouble(),
      completed: row['completed'] as bool,
    );
  }

  @override
  Future<List<Turf>> turfNear({
    required double lng,
    required double lat,
    required double radiusMeters,
  }) async {
    final rows = await _db.rpc('turf_near', params: {
      'lng': lng,
      'lat': lat,
      'radius_m': radiusMeters,
    }) as List<dynamic>;

    return rows.map((r) {
      final row = r as Map<String, dynamic>;
      final geo = jsonDecode(row['geojson'] as String) as Map<String, dynamic>;
      final coords = (geo['coordinates'] as List).first as List; // outer ring
      final ring = coords
          .map<List<double>>(
              (p) => [(p[0] as num).toDouble(), (p[1] as num).toDouble()])
          .toList();
      return Turf(
        id: row['id'] as String,
        ownerId: row['owner_id'] as String,
        polygon: ring,
        area: (row['area'] as num).toDouble(),
        claimedAt: DateTime.parse(row['claimed_at'] as String),
        colorHex: (row['color'] as String?) ?? '#56B4E9',
        ageDays: (row['age_days'] as num?)?.toInt() ?? 0,
        style: (row['style'] as String?) ?? 'turf_solid',
        level: (row['level'] as num?)?.toInt() ?? 1,
      );
    }).toList();
  }

  @override
  Future<List<Player>> leaderboard({int limit = 20}) async {
    final rows = await _db
        .from('players')
        .select('id, display_name, color, total_area')
        .order('total_area', ascending: false)
        .limit(limit) as List<dynamic>;

    return rows.map((r) {
      final row = r as Map<String, dynamic>;
      return Player(
        id: row['id'] as String,
        displayName: (row['display_name'] as String?) ?? 'Player',
        colorValue: _hexToArgb((row['color'] as String?) ?? '#56B4E9'),
        totalArea: (row['total_area'] as num?)?.toDouble() ?? 0,
      );
    }).toList();
  }

  @override
  RealtimeChannel subscribeTurf(void Function() onChange) {
    return _db
        .channel('public:turf')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'turf',
          callback: (_) => onChange(),
        )
        .subscribe();
  }

  static int _hexToArgb(String hex) {
    final h = hex.replaceFirst('#', '');
    return int.parse('FF$h', radix: 16);
  }
}
