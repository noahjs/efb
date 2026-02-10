import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:efb_mobile/features/adsb/protocol/traffic_report_decoder.dart';

/// Encode a latitude into 3-byte signed representation (180/2^23 per LSB).
List<int> encodeLat(double lat) {
  int raw = (lat / (180.0 / (1 << 23))).round();
  if (raw < 0) raw += 0x1000000;
  return [(raw >> 16) & 0xFF, (raw >> 8) & 0xFF, raw & 0xFF];
}

/// Encode a longitude into 3-byte signed representation (180/2^23 per LSB).
List<int> encodeLon(double lon) {
  int raw = (lon / (180.0 / (1 << 23))).round();
  if (raw < 0) raw += 0x1000000;
  return [(raw >> 16) & 0xFF, (raw >> 8) & 0xFF, raw & 0xFF];
}

/// Build a 28-byte traffic report payload.
Uint8List buildReport({
  int addressType = 0,
  int icaoAddress = 0xABCDEF,
  double latitude = 39.8561,
  double longitude = -104.6737,
  int? altitude = 5000,
  bool isAirborne = true,
  int nic = 8,
  int nacp = 9,
  int? groundspeed = 120,
  int? verticalRate = 500,
  int track = 270,
  int emitterCategory = 1,
  String callsign = 'N12345',
  int emergencyCode = 0,
}) {
  final bytes = List<int>.filled(28, 0);

  // Byte 0: status
  bytes[0] = ((addressType & 0x0F) << 4);

  // Bytes 1-3: ICAO address
  bytes[1] = (icaoAddress >> 16) & 0xFF;
  bytes[2] = (icaoAddress >> 8) & 0xFF;
  bytes[3] = icaoAddress & 0xFF;

  // Bytes 4-6: latitude
  final latBytes = encodeLat(latitude);
  bytes[4] = latBytes[0];
  bytes[5] = latBytes[1];
  bytes[6] = latBytes[2];

  // Bytes 7-9: longitude
  final lonBytes = encodeLon(longitude);
  bytes[7] = lonBytes[0];
  bytes[8] = lonBytes[1];
  bytes[9] = lonBytes[2];

  // Bytes 10-11: altitude + misc
  final altRaw = altitude != null ? ((altitude + 1000) ~/ 25) : 0xFFF;
  bytes[10] = (altRaw >> 4) & 0xFF;
  final miscBits = isAirborne ? 0x08 : 0x00;
  bytes[11] = ((altRaw & 0x0F) << 4) | (miscBits & 0x0F);

  // Byte 12: NIC + NACp
  bytes[12] = ((nic & 0x0F) << 4) | (nacp & 0x0F);

  // Bytes 13-14: horizontal velocity + vertical velocity (upper nibble)
  final hvelRaw = groundspeed ?? 0xFFF;
  bytes[13] = (hvelRaw >> 4) & 0xFF;

  // Bytes 14-15: vertical velocity
  int vvelRaw;
  if (verticalRate == null) {
    vvelRaw = 0x800;
  } else {
    vvelRaw = verticalRate ~/ 64;
    if (vvelRaw < 0) vvelRaw += 0x1000;
  }
  bytes[14] = ((hvelRaw & 0x0F) << 4) | ((vvelRaw >> 8) & 0x0F);
  bytes[15] = vvelRaw & 0xFF;

  // Byte 16: track
  bytes[16] = ((track * 256) ~/ 360) & 0xFF;

  // Byte 17: emitter category
  bytes[17] = emitterCategory;

  // Bytes 18-25: callsign (8 bytes, space-padded)
  final csBytes = callsign.padRight(8).codeUnits.take(8).toList();
  for (int i = 0; i < 8; i++) {
    bytes[18 + i] = csBytes[i];
  }

  // Byte 26: emergency code
  bytes[26] = ((emergencyCode & 0x0F) << 4);

  return Uint8List.fromList(bytes);
}

void main() {
  group('TrafficReportDecoder', () {
    test('decodes Denver area position correctly', () {
      final payload = buildReport(
        latitude: 39.8561,
        longitude: -104.6737,
        altitude: 5000,
      );
      final report = TrafficReportDecoder.decode(payload);

      expect(report, isNotNull);
      expect(report!.latitude, closeTo(39.8561, 0.01));
      expect(report.longitude, closeTo(-104.6737, 0.01));
      expect(report.altitude, isNotNull);
      // Altitude encoding: (5000+1000)/25 = 240, decode: 240*25-1000 = 5000
      expect(report.altitude, 5000);
    });

    test('decodes ICAO address correctly', () {
      final payload = buildReport(icaoAddress: 0xABCDEF);
      final report = TrafficReportDecoder.decode(payload)!;
      expect(report.icaoAddress, 0xABCDEF);
    });

    test('decodes callsign correctly', () {
      final payload = buildReport(callsign: 'N977CA');
      final report = TrafficReportDecoder.decode(payload)!;
      expect(report.callsign, 'N977CA');
    });

    test('decodes empty callsign as empty string', () {
      final payload = buildReport(callsign: '');
      final report = TrafficReportDecoder.decode(payload)!;
      expect(report.callsign, isEmpty);
    });

    test('decodes airborne flag', () {
      final airborne = buildReport(isAirborne: true);
      final ground = buildReport(isAirborne: false);

      expect(TrafficReportDecoder.decode(airborne)!.isAirborne, true);
      expect(TrafficReportDecoder.decode(ground)!.isAirborne, false);
    });

    test('decodes groundspeed', () {
      final payload = buildReport(groundspeed: 120);
      final report = TrafficReportDecoder.decode(payload)!;
      expect(report.groundspeed, 120);
    });

    test('handles invalid groundspeed (0xFFF)', () {
      final payload = buildReport(groundspeed: null);
      final report = TrafficReportDecoder.decode(payload)!;
      expect(report.groundspeed, isNull);
    });

    test('decodes positive vertical rate', () {
      final payload = buildReport(verticalRate: 500);
      final report = TrafficReportDecoder.decode(payload)!;
      // 500/64 = 7 (truncated), decoded = 7*64 = 448
      // Due to 64 fpm quantization, expect within 64 fpm
      expect(report.verticalRate, isNotNull);
      expect((report.verticalRate! - 500).abs(), lessThanOrEqualTo(64));
    });

    test('decodes negative vertical rate', () {
      final payload = buildReport(verticalRate: -500);
      final report = TrafficReportDecoder.decode(payload)!;
      expect(report.verticalRate, isNotNull);
      expect(report.verticalRate!, lessThan(0));
      expect((report.verticalRate! + 500).abs(), lessThanOrEqualTo(64));
    });

    test('handles invalid vertical rate (0x800)', () {
      final payload = buildReport(verticalRate: null);
      final report = TrafficReportDecoder.decode(payload)!;
      expect(report.verticalRate, isNull);
    });

    test('handles invalid altitude (0xFFF)', () {
      final payload = buildReport(altitude: null);
      final report = TrafficReportDecoder.decode(payload)!;
      expect(report.altitude, isNull);
    });

    test('decodes NIC and NACp', () {
      final payload = buildReport(nic: 8, nacp: 9);
      final report = TrafficReportDecoder.decode(payload)!;
      expect(report.nic, 8);
      expect(report.nacp, 9);
    });

    test('decodes track angle', () {
      final payload = buildReport(track: 270);
      final report = TrafficReportDecoder.decode(payload)!;
      // 270 * 256 / 360 = 192, decoded = 192 * 360 / 256 = 270
      expect(report.track, closeTo(270, 2));
    });

    test('decodes emitter category', () {
      final payload = buildReport(emitterCategory: 3);
      final report = TrafficReportDecoder.decode(payload)!;
      expect(report.emitterCategory, 3);
    });

    test('returns null for wrong payload length', () {
      expect(TrafficReportDecoder.decode(Uint8List(27)), isNull);
      expect(TrafficReportDecoder.decode(Uint8List(29)), isNull);
      expect(TrafficReportDecoder.decode(Uint8List(0)), isNull);
    });

    test('decodes southern hemisphere latitude', () {
      final payload = buildReport(latitude: -33.8688); // Sydney
      final report = TrafficReportDecoder.decode(payload)!;
      expect(report.latitude, closeTo(-33.8688, 0.01));
    });

    test('decodes eastern hemisphere longitude', () {
      final payload = buildReport(longitude: 151.2093); // Sydney
      final report = TrafficReportDecoder.decode(payload)!;
      expect(report.longitude, closeTo(151.2093, 0.01));
    });

    test('decodes zero position', () {
      final payload = buildReport(latitude: 0.0, longitude: 0.0);
      final report = TrafficReportDecoder.decode(payload)!;
      expect(report.latitude, closeTo(0.0, 0.01));
      expect(report.longitude, closeTo(0.0, 0.01));
    });

    test('decodes high altitude', () {
      final payload = buildReport(altitude: 45000);
      final report = TrafficReportDecoder.decode(payload)!;
      expect(report.altitude, 45000);
    });

    test('decodes negative altitude', () {
      // -1000 is the minimum: (0 * 25) - 1000 = -1000
      final payload = buildReport(altitude: -1000);
      final report = TrafficReportDecoder.decode(payload)!;
      expect(report.altitude, -1000);
    });
  });
}
