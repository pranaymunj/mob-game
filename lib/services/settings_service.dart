// settings_service.dart — Player preferences, persisted with shared_preferences.
// Kept deliberately small: anything that changes how the game feels or reports
// itself (sound, haptics, units, reminders) belongs here so the UI can respect
// the player's choices everywhere.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppSettings {
  final bool sound;
  final bool haptics;
  final bool useMiles; // false = metric (m / km)
  final bool dailyReminder;

  const AppSettings({
    this.sound = true,
    this.haptics = true,
    this.useMiles = false,
    this.dailyReminder = true,
  });

  AppSettings copyWith({
    bool? sound,
    bool? haptics,
    bool? useMiles,
    bool? dailyReminder,
  }) =>
      AppSettings(
        sound: sound ?? this.sound,
        haptics: haptics ?? this.haptics,
        useMiles: useMiles ?? this.useMiles,
        dailyReminder: dailyReminder ?? this.dailyReminder,
      );

  // Format a distance in metres according to the player's unit choice.
  String formatDistance(double metres) {
    if (useMiles) {
      final feet = metres * 3.28084;
      if (feet < 1000) return '${feet.toStringAsFixed(0)} ft';
      return '${(metres / 1609.344).toStringAsFixed(2)} mi';
    }
    if (metres < 1000) return '${metres.toStringAsFixed(0)} m';
    return '${(metres / 1000).toStringAsFixed(2)} km';
  }

  // Areas stay metric-ish but switch to feet² for imperial players.
  String formatArea(double squareMetres) {
    if (useMiles) {
      return '${(squareMetres * 10.7639).toStringAsFixed(0)} ft²';
    }
    return '${squareMetres.toStringAsFixed(0)} m²';
  }
}

class SettingsNotifier extends Notifier<AppSettings> {
  static const _kSound = 'settings_sound';
  static const _kHaptics = 'settings_haptics';
  static const _kMiles = 'settings_miles';
  static const _kReminder = 'settings_reminder';

  @override
  AppSettings build() {
    _load(); // async hydrate; defaults apply until it completes
    return const AppSettings();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    state = AppSettings(
      sound: p.getBool(_kSound) ?? true,
      haptics: p.getBool(_kHaptics) ?? true,
      useMiles: p.getBool(_kMiles) ?? false,
      dailyReminder: p.getBool(_kReminder) ?? true,
    );
  }

  Future<void> _persist(AppSettings s) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kSound, s.sound);
    await p.setBool(_kHaptics, s.haptics);
    await p.setBool(_kMiles, s.useMiles);
    await p.setBool(_kReminder, s.dailyReminder);
  }

  void setSound(bool v) => _update(state.copyWith(sound: v));
  void setHaptics(bool v) => _update(state.copyWith(haptics: v));
  void setUseMiles(bool v) => _update(state.copyWith(useMiles: v));
  void setDailyReminder(bool v) => _update(state.copyWith(dailyReminder: v));

  void _update(AppSettings s) {
    state = s;
    _persist(s);
  }
}

final settingsProvider =
    NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);
