// edit_profile_screen.dart — Set your display name, turf colour and avatar.
// Colours come from the colourblind-safe ownership palette, and the server
// re-validates every field (CLAUDE.md: never trust the client).

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';
import '../../core/ui_kit.dart';
import '../../models/player.dart';
import 'profile_screen.dart';

// The palette the server accepts, as hex.
const _paletteHex = [
  '#E69F00',
  '#56B4E9',
  '#009E73',
  '#F0E442',
  '#0072B2',
  '#D55E00',
  '#CC79A7',
];

const _avatars = [
  '🚩', '🏃', '🦊', '🐺', '🦅', '🐉',
  '⚡', '🔥', '👑', '🎯', '🌟', '💀',
];

class EditProfileScreen extends ConsumerStatefulWidget {
  final Player player;
  const EditProfileScreen({super.key, required this.player});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _name =
      TextEditingController(text: widget.player.displayName);
  late String _color = _paletteHex.contains(widget.player.colorHex)
      ? widget.player.colorHex
      : _paletteHex[1];
  late String? _avatar = widget.player.avatar;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  static int _hexToArgb(String hex) =>
      int.parse('FF${hex.replaceFirst('#', '')}', radix: 16);

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    try {
      await ref.read(backendServiceProvider).updateProfile(
            name: _name.text.trim(),
            colorHex: _color,
            avatar: _avatar,
          );
      ref.invalidate(myPlayerProvider);
      messenger.showSnackBar(const SnackBar(content: Text('Profile saved.')));
      navigator.pop();
    } catch (e) {
      // Surface the server's own validation message — it's the source of truth.
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Live preview of how you'll appear to others.
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundColor: Color(_hexToArgb(_color)),
                  child: _avatar == null
                      ? const Icon(Icons.person, size: 44, color: Colors.black)
                      : Text(_avatar!, style: const TextStyle(fontSize: 40)),
                ),
                const SizedBox(height: 10),
                Text(
                  _name.text.trim().isEmpty ? 'Your name' : _name.text.trim(),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Text('This is how rivals see you',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 28),

          const SectionLabel('Display name'),
          const SizedBox(height: 8),
          TextField(
            controller: _name,
            maxLength: 20,
            onChanged: (_) => setState(() {}), // keep the preview in sync
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: '2-20 characters',
            ),
          ),
          const SizedBox(height: 12),

          const SectionLabel('Your turf colour'),
          const Text(
            'Every colour here stays distinguishable for colourblind players.',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final hex in _paletteHex)
                GestureDetector(
                  onTap: () => setState(() => _color = hex),
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Color(_hexToArgb(hex)),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _color == hex ? Colors.white : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: _color == hex
                        ? const Icon(Icons.check, color: Colors.black)
                        : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),

          const SectionLabel('Avatar'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final emoji in _avatars)
                GestureDetector(
                  onTap: () => setState(
                      () => _avatar = _avatar == emoji ? null : emoji),
                  child: Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: _avatar == emoji
                            ? AppColors.accent
                            : Colors.white12,
                        width: 2,
                      ),
                    ),
                    child: Text(emoji, style: const TextStyle(fontSize: 24)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 32),

          _saving
              ? const Center(child: CircularProgressIndicator())
              : GameButton(
                  label: 'SAVE PROFILE',
                  icon: Icons.check,
                  onPressed: _save,
                ),
        ],
      ),
    );
  }
}
