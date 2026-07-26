// help_screen.dart — In-app help & support: how to play, perks, safety,
// privacy, FAQ, and how to reach support.

import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _Section(
            icon: Icons.directions_walk,
            title: 'How to play',
            body:
                '1. Tap Start Run and allow location.\n'
                '2. Walk a loop through real streets — your trail follows you.\n'
                '3. Return near where you started to close the loop.\n'
                '4. The enclosed area fills in your color and is claimed.\n'
                'Walk loops bigger than ~30 m across for the best results.',
          ),
          _Section(
            icon: Icons.groups_outlined,
            title: 'Stealing & crews',
            body:
                'Overlap a rival’s turf with a new claim to take the overlap. '
                'Join or create a Crew from your Profile to pool your turf on the '
                'leaderboard, and compete for zone control in Neighborhood Wars.',
          ),
          _Section(
            icon: Icons.bolt,
            title: 'Perks',
            body:
                'Complete the daily challenge to earn a perk:\n'
                '• Sprint — move faster without tripping anti-cheat\n'
                '• Shield — protect your turf from theft for 24h\n'
                '• Wide Brush — claim a little extra around your loop\n'
                '• Recon — see rival turf farther out',
          ),
          _Section(
            icon: Icons.health_and_safety_outlined,
            title: 'Stay safe',
            body:
                'Keep your eyes up and watch your surroundings — don’t stare at '
                'your phone while walking. You can lock it and put it in your '
                'pocket; your trail keeps recording, and a blue indicator shows '
                'whenever we’re tracking. Runs auto-pause if you move at car '
                'speed. Only play where it’s safe and legal to walk.',
          ),
          _Section(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy',
            body:
                'We show turf, never people. Others see the land you claim — '
                'never your live location. Home base is stored only at '
                'approximate, block-level precision. Delete all your data '
                'anytime from Profile → Delete my data.',
          ),
          _FaqTile(
            q: 'My trail looks jumpy or won’t close a loop.',
            a: 'GPS is weak indoors and near tall buildings. Play outside with a '
                'clear view of the sky, and walk a loop at least ~30 m across.',
          ),
          _FaqTile(
            q: 'My turf disappeared.',
            a: 'Another player may have claimed over it. Use a Shield perk to '
                'protect your turf for 24 hours.',
          ),
          _FaqTile(
            q: 'Does it use a lot of battery / data?',
            a: 'Location updates are batched and turf is only loaded near you, to '
                'keep battery and data use low.',
          ),
          SizedBox(height: 8),
          _Contact(),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _Section({required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
            ]),
            const SizedBox(height: 8),
            Text(body),
          ],
        ),
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  final String q;
  final String a;
  const _FaqTile({required this.q, required this.a});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        title: Text(q, style: const TextStyle(fontWeight: FontWeight.w600)),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [Align(alignment: Alignment.centerLeft, child: Text(a))],
      ),
    );
  }
}

class _Contact extends StatelessWidget {
  const _Contact();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Row(children: [
              Icon(Icons.support_agent, size: 20),
              SizedBox(width: 8),
              Text('Contact support',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ]),
            SizedBox(height: 8),
            Text('Need help or found a bug? Email us:'),
            SizedBox(height: 4),
            SelectableText('support@claimr.app',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
