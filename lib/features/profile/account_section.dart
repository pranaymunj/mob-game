// account_section.dart — Turn an anonymous install into a real account.
//
// Until a player links an email their entire game (turf, level, perks) exists
// only on this device and is lost on reinstall. Linking preserves the user id,
// so nothing is migrated — the same account simply gains a login.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../core/ui_kit.dart';
import 'profile_screen.dart';

class AccountSection extends ConsumerStatefulWidget {
  const AccountSection({super.key});

  @override
  ConsumerState<AccountSection> createState() => _AccountSectionState();
}

class _AccountSectionState extends ConsumerState<AccountSection> {
  bool _busy = false;

  Future<void> _promptCredentials({
    required String title,
    required String actionLabel,
    required Future<void> Function(String email, String password) action,
    required String successMessage,
  }) async {
    final emailC = TextEditingController();
    final passC = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailC,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: passC,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                helperText: 'At least 6 characters',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(actionLabel)),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await action(emailC.text.trim(), passC.text);
      ref.invalidate(myPlayerProvider);
      messenger.showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final backend = ref.read(backendServiceProvider);
    final isGuest = backend.isAnonymousAccount;
    final email = backend.accountEmail;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('Account', icon: Icons.shield_outlined),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(isGuest ? Icons.warning_amber : Icons.verified_user,
                        color: isGuest ? Colors.orangeAccent : Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isGuest ? 'Guest account' : 'Signed in',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  isGuest
                      ? 'Your turf, level and perks exist only on this phone. '
                          'If you delete the app or switch phones, they are gone '
                          'for good. Add an email to keep them safe.'
                      : 'Signed in as $email. Your progress is saved to your '
                          'account and will follow you to a new phone.',
                  style: const TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 12),
                if (isGuest) ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _promptCredentials(
                                title: 'Secure your account',
                                actionLabel: 'Save',
                                successMessage:
                                    'Account secured — your progress is safe.',
                                action: (e, p) => ref
                                    .read(backendServiceProvider)
                                    .linkEmail(email: e, password: p),
                              ),
                      icon: const Icon(Icons.lock),
                      label: const Text('Secure my account'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _promptCredentials(
                              title: 'Sign in',
                              actionLabel: 'Sign in',
                              successMessage: 'Signed in — welcome back.',
                              action: (e, p) => ref
                                  .read(backendServiceProvider)
                                  .signInWithEmail(email: e, password: p),
                            ),
                    icon: const Icon(Icons.login),
                    label: const Text('I already have an account'),
                  ),
                ] else
                  OutlinedButton.icon(
                    onPressed: _busy
                        ? null
                        : () async {
                            await ref.read(backendServiceProvider).signOut();
                            ref.invalidate(myPlayerProvider);
                            if (context.mounted) setState(() {});
                          },
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign out'),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
