// settings_format_test.dart — Distance/area formatting must respect the
// player's unit choice; conversion errors are the kind of bug nobody notices
// until a user in the US says "why does it say 1.6 km when I walked a mile".

import 'package:claimr/services/settings_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const metric = AppSettings();
  const imperial = AppSettings(useMiles: true);

  group('metric', () {
    test('short distances stay in metres', () {
      expect(metric.formatDistance(250), '250 m');
    });

    test('a kilometre or more switches to km', () {
      expect(metric.formatDistance(1000), '1.00 km');
      expect(metric.formatDistance(2500), '2.50 km');
    });

    test('area is square metres', () {
      expect(metric.formatArea(1234), '1234 m²');
    });
  });

  group('imperial', () {
    test('short distances are feet', () {
      // 100m ≈ 328ft
      expect(imperial.formatDistance(100), '328 ft');
    });

    test('a mile converts correctly', () {
      // 1609.344m is exactly 1 mile
      expect(imperial.formatDistance(1609.344), '1.00 mi');
    });

    test('area converts to square feet', () {
      // 100 m² ≈ 1076 ft²
      expect(imperial.formatArea(100), '1076 ft²');
    });
  });
}
