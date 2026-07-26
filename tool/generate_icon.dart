// generate_icon.dart — Generates the app icon PNG (1024x1024) into assets/.
// Run with: dart run tool/generate_icon.dart
// A dark board, a claimed-territory blob in the brand sky-blue, and a flag.

import 'dart:io';
import 'package:image/image.dart';

void main() {
  const size = 1024;
  final img = Image(width: size, height: size, numChannels: 4);

  // Board background (brand dark).
  fill(img, color: ColorRgb8(0x10, 0x13, 0x1A));

  // Claimed territory blob (Okabe–Ito sky blue), big and centered.
  final blue = ColorRgb8(0x56, 0xB4, 0xE9);
  fillPolygon(
    img,
    vertices: [
      Point(512, 250),
      Point(760, 360),
      Point(810, 600),
      Point(650, 800),
      Point(380, 800),
      Point(215, 590),
      Point(275, 360),
    ],
    color: blue,
  );

  // Flag pole (dark) + pennant (bluish green) planted inside the turf.
  final dark = ColorRgb8(0x10, 0x13, 0x1A);
  final green = ColorRgb8(0x00, 0x9E, 0x73);
  fillRect(img, x1: 500, y1: 300, x2: 524, y2: 640, color: dark);
  fillPolygon(
    img,
    vertices: [Point(524, 318), Point(700, 372), Point(524, 426)],
    color: green,
  );

  final dir = Directory('assets');
  if (!dir.existsSync()) dir.createSync(recursive: true);
  File('assets/app_icon.png').writeAsBytesSync(encodePng(img));
  stdout.writeln('Wrote assets/app_icon.png (${size}x$size)');
}
