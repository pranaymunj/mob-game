// settings_screen.dart — Sound, haptics, units, reminders, and app info.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants.dart';
import '../../services/notification_service.dart';
import '../../services/settings_service.dart';
import '../help/help_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('Game'),
          SwitchListTile(
            value: s.sound,
            onChanged: notifier.setSound,
            secondary: const Icon(Icons.volume_up),
            title: const Text('Sound effects'),
            subtitle: const Text('Plays when you claim turf'),
          ),
          SwitchListTile(
            value: s.haptics,
            onChanged: notifier.setHaptics,
            secondary: const Icon(Icons.vibration),
            title: const Text('Vibration'),
            subtitle: const Text('Feel it when a loop closes'),
          ),

          const _SectionHeader('Units'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Metric')),
                ButtonSegment(value: true, label: Text('Imperial')),
              ],
              selected: {s.useMiles},
              onSelectionChanged: (v) => notifier.setUseMiles(v.first),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(
              s.useMiles ? 'feet, miles, ft²' : 'metres, kilometres, m²',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ),

          const _SectionHeader('Notifications'),
          SwitchListTile(
            value: s.dailyReminder,
            onChanged: (v) async {
              notifier.setDailyReminder(v);
              final n = NotificationService();
              if (v) {
                await n.enableReminders();
              } else {
                await n.cancelReminders();
              }
            },
            secondary: const Icon(Icons.notifications_active),
            title: const Text('Daily streak reminder'),
            subtitle: const Text('A nudge so you don\'t lose your streak'),
          ),

          const _SectionHeader('About'),
          ListTile(
            leading: const Icon(Icons.help_outline),
            title: const Text('Help & Support'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const HelpScreen()),
            ),
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Version'),
            subtitle: Text('${AppConstants.appName} 1.0.0'),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy policy'),
            subtitle: const Text(
              'Claimr shows turf, never people. Your live location is never '
              'shared. Delete your data anytime from Profile.',
            ),
            trailing: const Icon(Icons.open_in_new, size: 18),
            onTap: () async {
              final uri = Uri.parse(AppConstants.privacyPolicyUrl);
              // Fall back to a copyable address rather than failing silently —
              // a dead privacy link is a store-review rejection.
              if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(AppConstants.privacyPolicyUrl),
                  ));
                }
              }
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          letterSpacing: 1.5,
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
