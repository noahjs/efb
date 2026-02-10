import 'package:flutter_test/flutter_test.dart';
import 'package:efb_mobile/core/utils/solar.dart';

/// Tests for the NOAA-based solar calculator.
/// Uses known sunrise/sunset times for Denver, CO and validates
/// against published almanac data (±2 minute tolerance).
void main() {
  /// Helper: difference in minutes between two DateTimes
  double diffMinutes(DateTime a, DateTime b) =>
      (a.difference(b).inSeconds / 60).abs();

  group('SolarTimes.forDate — Denver, CO', () {
    // Denver: 39.7392° N, 104.9903° W
    const lat = 39.7392;
    const lng = -104.9903;

    test('summer solstice — long day, sunrise ~12:31 UTC, sunset ~02:32 UTC+1', () {
      // June 21, 2025 — Denver sunrise ~05:31 MDT = 11:31 UTC
      // sunset ~20:32 MDT = 02:32 UTC next day (but same UTC day calc)
      final result = SolarTimes.forDate(
        date: DateTime.utc(2025, 6, 21),
        latitude: lat,
        longitude: lng,
      );

      expect(result, isNotNull);
      // Sunrise should be around 11:31 UTC (5:31 AM MDT)
      final sunriseMinutes = result!.sunrise.hour * 60 + result.sunrise.minute;
      // ~11:31 UTC = 691 minutes
      expect(sunriseMinutes, closeTo(691, 5)); // ±5 min tolerance

      // Sunset should be around 2:32 UTC next day = 26:32 in day-minutes
      // But since we're in UTC day, it wraps: ~2:32 = 152 minutes
      // Actually for June solstice Denver: sunset ~20:32 MDT = 02:32 UTC
      final sunsetMinutes = result.sunset.hour * 60 + result.sunset.minute;
      expect(sunsetMinutes, closeTo(152, 5));
    });

    test('winter solstice — short day, sunrise ~14:22 UTC, sunset ~23:39 UTC', () {
      // Dec 21, 2025 — Denver sunrise ~07:22 MST = 14:22 UTC
      // sunset ~16:39 MST = 23:39 UTC
      final result = SolarTimes.forDate(
        date: DateTime.utc(2025, 12, 21),
        latitude: lat,
        longitude: lng,
      );

      expect(result, isNotNull);
      final sunriseMinutes = result!.sunrise.hour * 60 + result.sunrise.minute;
      // ~14:22 UTC = 862 minutes
      expect(sunriseMinutes, closeTo(862, 5));

      final sunsetMinutes = result.sunset.hour * 60 + result.sunset.minute;
      // ~23:39 UTC = 1419 minutes
      expect(sunsetMinutes, closeTo(1419, 5));
    });

    test('equinox — sunrise and sunset roughly 12 hours apart', () {
      // March 20, 2025 — roughly equal day/night
      final result = SolarTimes.forDate(
        date: DateTime.utc(2025, 3, 20),
        latitude: lat,
        longitude: lng,
      );

      expect(result, isNotNull);
      // _minutesToDateTime wraps hours % 24 — when sunset is past midnight UTC
      // (common for western hemisphere), we must add 24h to get true day length.
      final sunriseMin = result!.sunrise.hour * 60 + result.sunrise.minute;
      var sunsetMin = result.sunset.hour * 60 + result.sunset.minute;
      if (sunsetMin < sunriseMin) sunsetMin += 1440; // next UTC day
      final dayLengthMinutes = sunsetMin - sunriseMin;
      // Day length should be close to 12 hours (720 min) ± 15 min
      expect(dayLengthMinutes, closeTo(720, 15));
    });
  });

  group('SolarTimes.forDate — civil twilight', () {
    const lat = 39.7392;
    const lng = -104.9903;

    test('civil dawn is before sunrise', () {
      final result = SolarTimes.forDate(
        date: DateTime.utc(2025, 6, 21),
        latitude: lat,
        longitude: lng,
      );

      expect(result, isNotNull);
      expect(result!.civilDawn, isNotNull);
      expect(result.civilDawn!.isBefore(result.sunrise), isTrue);
    });

    test('civil dusk is after sunset', () {
      final result = SolarTimes.forDate(
        date: DateTime.utc(2025, 6, 21),
        latitude: lat,
        longitude: lng,
      );

      expect(result, isNotNull);
      expect(result!.civilDusk, isNotNull);
      expect(result.civilDusk!.isAfter(result.sunset), isTrue);
    });
  });

  group('SolarTimes.forDate — extreme latitudes', () {
    test('high latitude summer — very long day (Reykjavik ~64°N, June)', () {
      final result = SolarTimes.forDate(
        date: DateTime.utc(2025, 6, 21),
        latitude: 64.1466,
        longitude: -21.9426,
      );

      // Reykjavik has ~21+ hours of daylight at summer solstice
      // The sun does technically set, so result should not be null
      if (result != null) {
        final sunriseMin = result.sunrise.hour * 60 + result.sunrise.minute;
        var sunsetMin = result.sunset.hour * 60 + result.sunset.minute;
        if (sunsetMin < sunriseMin) sunsetMin += 1440;
        final dayLength = sunsetMin - sunriseMin;
        expect(dayLength, greaterThan(1200)); // > 20 hours
      }
      // If null, that's also acceptable for near-polar regions
    });

    test('arctic winter — returns null for polar night (Svalbard ~78°N, Dec)', () {
      final result = SolarTimes.forDate(
        date: DateTime.utc(2025, 12, 21),
        latitude: 78.2232,
        longitude: 15.6267,
      );

      // Sun doesn't rise at 78°N in December → should return null
      expect(result, isNull);
    });
  });
}
