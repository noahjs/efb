import 'dart:math';

/// Computes sunrise and sunset times for a given location and date
/// using the NOAA solar calculator algorithm.
class SolarTimes {
  final DateTime sunrise;
  final DateTime sunset;
  final DateTime? civilDawn;
  final DateTime? civilDusk;

  SolarTimes({
    required this.sunrise,
    required this.sunset,
    this.civilDawn,
    this.civilDusk,
  });

  /// Compute sunrise/sunset and civil twilight in UTC for the given [date],
  /// [latitude], and [longitude].
  /// Returns null if the sun never rises or never sets (polar regions).
  static SolarTimes? forDate({
    required DateTime date,
    required double latitude,
    required double longitude,
  }) {
    // Julian date
    final jd = _julianDate(date.year, date.month, date.day);
    final jc = (jd - 2451545.0) / 36525.0; // Julian century

    // Solar geometry
    final geomMeanLongSun = (280.46646 + jc * (36000.76983 + 0.0003032 * jc)) % 360;
    final geomMeanAnomSun = 357.52911 + jc * (35999.05029 - 0.0001537 * jc);
    final eccentEarthOrbit = 0.016708634 - jc * (0.000042037 + 0.0000001267 * jc);

    final sunEqOfCtr = sin(_rad(geomMeanAnomSun)) *
            (1.914602 - jc * (0.004817 + 0.000014 * jc)) +
        sin(_rad(2 * geomMeanAnomSun)) * (0.019993 - 0.000101 * jc) +
        sin(_rad(3 * geomMeanAnomSun)) * 0.000289;

    final sunTrueLong = geomMeanLongSun + sunEqOfCtr;
    final sunAppLong =
        sunTrueLong - 0.00569 - 0.00478 * sin(_rad(125.04 - 1934.136 * jc));

    final meanObliqEcliptic =
        23 + (26 + (21.448 - jc * (46.815 + jc * (0.00059 - jc * 0.001813))) / 60) / 60;
    final obliqCorr =
        meanObliqEcliptic + 0.00256 * cos(_rad(125.04 - 1934.136 * jc));

    final sunDeclin = _deg(asin(sin(_rad(obliqCorr)) * sin(_rad(sunAppLong))));

    final varY = tan(_rad(obliqCorr / 2)) * tan(_rad(obliqCorr / 2));
    final eqOfTime = 4 *
        _deg(varY * sin(2 * _rad(geomMeanLongSun)) -
            2 * eccentEarthOrbit * sin(_rad(geomMeanAnomSun)) +
            4 * eccentEarthOrbit * varY * sin(_rad(geomMeanAnomSun)) * cos(2 * _rad(geomMeanLongSun)) -
            0.5 * varY * varY * sin(4 * _rad(geomMeanLongSun)) -
            1.25 * eccentEarthOrbit * eccentEarthOrbit * sin(2 * _rad(geomMeanAnomSun)));

    // Solar noon in minutes from midnight UTC
    final solarNoon = (720 - 4 * longitude - eqOfTime);

    // Hour angle for official sunrise/sunset (zenith = 90.833 degrees)
    final cosHASun = _cosHourAngle(90.833, latitude, sunDeclin);
    if (cosHASun == null) return null;
    final haSun = _deg(acos(cosHASun));

    // Hour angle for civil twilight (zenith = 96.0 degrees)
    final cosHACivil = _cosHourAngle(96.0, latitude, sunDeclin);
    DateTime? civilDawn;
    DateTime? civilDusk;
    if (cosHACivil != null) {
      final haCivil = _deg(acos(cosHACivil));
      civilDawn = _minutesToDateTime(date, solarNoon - haCivil * 4);
      civilDusk = _minutesToDateTime(date, solarNoon + haCivil * 4);
    }

    return SolarTimes(
      sunrise: _minutesToDateTime(date, solarNoon - haSun * 4),
      sunset: _minutesToDateTime(date, solarNoon + haSun * 4),
      civilDawn: civilDawn,
      civilDusk: civilDusk,
    );
  }

  /// Returns cosHA for a given zenith angle, or null if no event occurs.
  static double? _cosHourAngle(
      double zenith, double latitude, double sunDeclin) {
    final cosHA =
        (cos(_rad(zenith)) / (cos(_rad(latitude)) * cos(_rad(sunDeclin)))) -
            tan(_rad(latitude)) * tan(_rad(sunDeclin));
    if (cosHA > 1 || cosHA < -1) return null;
    return cosHA;
  }

  static double _julianDate(int year, int month, int day) {
    if (month <= 2) {
      year -= 1;
      month += 12;
    }
    final a = (year / 100).floor();
    final b = 2 - a + (a / 4).floor();
    return (365.25 * (year + 4716)).floor() +
        (30.6001 * (month + 1)).floor() +
        day +
        b -
        1524.5;
  }

  static double _rad(double deg) => deg * pi / 180;
  static double _deg(double rad) => rad * 180 / pi;

  static DateTime _minutesToDateTime(DateTime date, double minutes) {
    final totalMinutes = minutes.round();
    final h = (totalMinutes ~/ 60) % 24;
    final m = totalMinutes % 60;
    return DateTime.utc(date.year, date.month, date.day, h, m.abs());
  }
}
