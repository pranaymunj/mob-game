// cosmetics_catalog.dart — Display metadata for cosmetics. Prices and ownership
// are the server's authority (0020_cosmetics.sql); this only describes how each
// item looks so the shop and the map can render it.

import 'package:flutter/material.dart';

enum CosmeticSlot { trail, turf }

class CosmeticInfo {
  final String key;
  final String name;
  final int price; // for display; server re-checks on purchase
  final CosmeticSlot slot;
  final Color color; // the colour this skin paints in
  final String blurb;

  const CosmeticInfo({
    required this.key,
    required this.name,
    required this.price,
    required this.slot,
    required this.color,
    required this.blurb,
  });
}

// Trail skins — the colour + glow of your trail while you run. Only you see it.
const trailCatalog = <CosmeticInfo>[
  CosmeticInfo(
      key: 'trail_classic',
      name: 'Classic',
      price: 0,
      slot: CosmeticSlot.trail,
      color: Color(0xFF56B4E9),
      blurb: 'The original blue trail.'),
  CosmeticInfo(
      key: 'trail_neon',
      name: 'Neon',
      price: 200,
      slot: CosmeticSlot.trail,
      color: Color(0xFF00E676),
      blurb: 'Electric green glow.'),
  CosmeticInfo(
      key: 'trail_flame',
      name: 'Flame',
      price: 350,
      slot: CosmeticSlot.trail,
      color: Color(0xFFFF6D00),
      blurb: 'A blazing orange streak.'),
  CosmeticInfo(
      key: 'trail_ice',
      name: 'Ice',
      price: 350,
      slot: CosmeticSlot.trail,
      color: Color(0xFF80D8FF),
      blurb: 'Cool frosted cyan.'),
  CosmeticInfo(
      key: 'trail_void',
      name: 'Void',
      price: 600,
      slot: CosmeticSlot.trail,
      color: Color(0xFFB388FF),
      blurb: 'Deep violet, for the elite.'),
];

// Turf styles — how your claimed land renders on everyone's shared map. This
// is the one rivals actually see, so it's the real flex.
const turfCatalog = <CosmeticInfo>[
  CosmeticInfo(
      key: 'turf_solid',
      name: 'Solid',
      price: 0,
      slot: CosmeticSlot.turf,
      color: Color(0xFF56B4E9),
      blurb: 'A clean colour fill.'),
  CosmeticInfo(
      key: 'turf_outline',
      name: 'Outline',
      price: 250,
      slot: CosmeticSlot.turf,
      color: Color(0xFFE69F00),
      blurb: 'Bold border, light fill.'),
  CosmeticInfo(
      key: 'turf_glow',
      name: 'Glow',
      price: 400,
      slot: CosmeticSlot.turf,
      color: Color(0xFF009E73),
      blurb: 'A radiant, brighter fill.'),
  CosmeticInfo(
      key: 'turf_hatch',
      name: 'Hatch',
      price: 500,
      slot: CosmeticSlot.turf,
      color: Color(0xFFCC79A7),
      blurb: 'Densely marked territory.'),
];

final _byKey = {
  for (final c in [...trailCatalog, ...turfCatalog]) c.key: c,
};

CosmeticInfo? cosmeticInfo(String key) => _byKey[key];
