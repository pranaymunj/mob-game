// perk_info.dart — Display metadata for the four perks (name, icon, blurb).

import 'package:flutter/material.dart';

class PerkInfo {
  final String key;
  final String name;
  final IconData icon;
  final String blurb;
  const PerkInfo(this.key, this.name, this.icon, this.blurb);
}

const perkInfos = <String, PerkInfo>{
  'sprint': PerkInfo('sprint', 'Sprint', Icons.bolt,
      'Move faster this run without tripping anti-cheat.'),
  'shield': PerkInfo('shield', 'Shield', Icons.shield,
      'Protects all your turf from being stolen for 24 hours.'),
  'wide_brush': PerkInfo('wide_brush', 'Wide Brush', Icons.brush,
      'Your next loop claims a little extra around the edges.'),
  'recon': PerkInfo('recon', 'Recon', Icons.visibility,
      'See rival turf farther beyond your viewport.'),
};

String perkName(String key) => perkInfos[key]?.name ?? key;
IconData perkIcon(String key) => perkInfos[key]?.icon ?? Icons.star;
