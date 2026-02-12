import 'package:flutter_test/flutter_test.dart';
import 'package:efb_mobile/models/briefing.dart';

void main() {
  group('BriefingMetar.fromJson', () {
    Map<String, dynamic> _baseMetar({dynamic wdir, dynamic wspd, dynamic wgst}) {
      return {
        'station': 'APA',
        'icaoId': 'KAPA',
        'flightCategory': 'VFR',
        'rawOb': 'KAPA 112053Z VRB05KT 10SM FEW120 07/M10 A3012',
        'obsTime': '2026-02-11T20:53:00Z',
        'section': 'departure',
        'temp': 7.0,
        'dewp': -10.0,
        'wdir': wdir,
        'wspd': wspd,
        'wgst': wgst,
        'visib': 10,
        'altim': 1019.7,
        'clouds': [
          {'cover': 'FEW', 'base': 12000}
        ],
        'ceiling': null,
      };
    }

    test('parses numeric wdir correctly', () {
      final metar = BriefingMetar.fromJson(_baseMetar(wdir: 180, wspd: 10));
      expect(metar.wdir, 180);
      expect(metar.wspd, 10);
    });

    test('parses wdir as double correctly', () {
      final metar = BriefingMetar.fromJson(_baseMetar(wdir: 180.0, wspd: 10.0));
      expect(metar.wdir, 180);
      expect(metar.wspd, 10);
    });

    test('handles "VRB" string wdir without crashing', () {
      final metar = BriefingMetar.fromJson(_baseMetar(wdir: 'VRB', wspd: 5));
      expect(metar.wdir, isNull);
      expect(metar.wspd, 5);
    });

    test('handles null wdir', () {
      final metar = BriefingMetar.fromJson(_baseMetar(wdir: null, wspd: 5));
      expect(metar.wdir, isNull);
      expect(metar.wspd, 5);
    });

    test('handles null wspd and wgst', () {
      final metar = BriefingMetar.fromJson(_baseMetar(wdir: 180, wspd: null, wgst: null));
      expect(metar.wdir, 180);
      expect(metar.wspd, isNull);
      expect(metar.wgst, isNull);
    });

    test('parses wgst correctly', () {
      final metar = BriefingMetar.fromJson(_baseMetar(wdir: 270, wspd: 15, wgst: 25));
      expect(metar.wgst, 25);
    });

    test('parses visibility as string with "+" suffix', () {
      final json = _baseMetar(wdir: 180, wspd: 10);
      json['visib'] = '10+';
      final metar = BriefingMetar.fromJson(json);
      expect(metar.visib, 10.0);
    });

    test('parses clouds correctly', () {
      final metar = BriefingMetar.fromJson(_baseMetar(wdir: 180, wspd: 10));
      expect(metar.clouds.length, 1);
      expect(metar.clouds[0].cover, 'FEW');
      expect(metar.clouds[0].base, 12000);
    });
  });

  group('TafForecastPeriod.fromJson', () {
    Map<String, dynamic> _baseFcst({dynamic wdir, dynamic wspd, dynamic wgst}) {
      return {
        'timeFrom': '2026-02-11T20:00:00Z',
        'timeTo': '2026-02-12T06:00:00Z',
        'changeType': 'FM',
        'wdir': wdir,
        'wspd': wspd,
        'wgst': wgst,
        'visib': 10,
        'clouds': [],
        'fltCat': 'VFR',
      };
    }

    test('parses numeric wdir correctly', () {
      final fcst = TafForecastPeriod.fromJson(_baseFcst(wdir: 240, wspd: 12));
      expect(fcst.wdir, 240);
      expect(fcst.wspd, 12);
    });

    test('handles "VRB" string wdir without crashing', () {
      final fcst = TafForecastPeriod.fromJson(_baseFcst(wdir: 'VRB', wspd: 5));
      expect(fcst.wdir, isNull);
      expect(fcst.wspd, 5);
    });

    test('handles null wdir', () {
      final fcst = TafForecastPeriod.fromJson(_baseFcst(wdir: null, wspd: null));
      expect(fcst.wdir, isNull);
      expect(fcst.wspd, isNull);
    });

    test('parses visibility as string', () {
      final json = _baseFcst(wdir: 180, wspd: 10);
      json['visib'] = '6';
      final fcst = TafForecastPeriod.fromJson(json);
      expect(fcst.visib, 6.0);
    });
  });

  group('TimelinePoint.fromJson', () {
    Map<String, dynamic> _baseTimeline({dynamic windDir, dynamic windSpd}) {
      return {
        'waypoint': 'APA',
        'latitude': 39.57,
        'longitude': -104.85,
        'distanceFromDep': 0,
        'etaMinutes': 0,
        'etaZulu': '2026-02-11T21:00:00Z',
        'nearestStation': 'KAPA',
        'flightCategory': 'VFR',
        'ceiling': null,
        'visibility': 10,
        'windDir': windDir,
        'windSpd': windSpd,
        'headwindComponent': -5,
        'crosswindComponent': 3,
        'activeHazards': [],
      };
    }

    test('parses numeric windDir correctly', () {
      final pt = TimelinePoint.fromJson(_baseTimeline(windDir: 180, windSpd: 10));
      expect(pt.windDir, 180);
      expect(pt.windSpd, 10);
    });

    test('handles "VRB" string windDir without crashing', () {
      final pt = TimelinePoint.fromJson(_baseTimeline(windDir: 'VRB', windSpd: 5));
      expect(pt.windDir, isNull);
      expect(pt.windSpd, 5);
    });

    test('handles null windDir', () {
      final pt = TimelinePoint.fromJson(_baseTimeline(windDir: null, windSpd: null));
      expect(pt.windDir, isNull);
      expect(pt.windSpd, isNull);
    });
  });

  group('WindsAloftTable.fromJson', () {
    test('parses altitudes as int from num values', () {
      final table = WindsAloftTable.fromJson({
        'waypoints': ['APA', 'DEN'],
        'altitudes': [3000, 6000.0, 9000],
        'filedAltitude': 9000,
        'data': [],
      });
      expect(table.altitudes, [3000, 6000, 9000]);
    });
  });

  group('CloudLayer.fromJson', () {
    test('parses normal cloud layer', () {
      final cl = CloudLayer.fromJson({'cover': 'BKN', 'base': 5000});
      expect(cl.cover, 'BKN');
      expect(cl.base, 5000);
    });

    test('handles null base (e.g. CLR)', () {
      final cl = CloudLayer.fromJson({'cover': 'CLR', 'base': null});
      expect(cl.cover, 'CLR');
      expect(cl.base, isNull);
    });

    test('handles missing cover', () {
      final cl = CloudLayer.fromJson({});
      expect(cl.cover, '');
      expect(cl.base, isNull);
    });
  });

  group('Briefing.fromJson - full integration', () {
    test('parses a complete briefing with VRB winds', () {
      final json = _fullBriefingJson();
      // Should not throw
      final briefing = Briefing.fromJson(json);

      expect(briefing.currentWeather.metars.length, 1);
      final metar = briefing.currentWeather.metars[0];
      expect(metar.wdir, isNull); // "VRB" parsed as null
      expect(metar.wspd, 5);
      expect(metar.station, 'APA');
    });
  });
}

Map<String, dynamic> _fullBriefingJson() {
  return {
    'flight': {
      'id': 1,
      'departureIdentifier': 'APA',
      'destinationIdentifier': 'DEN',
      'waypoints': [],
    },
    'routeAirports': [],
    'adverseConditions': {
      'tfrs': [],
      'closedUnsafeNotams': [],
      'convectiveSigmets': [],
      'sigmets': [],
      'airmets': {
        'ifr': [],
        'mountainObscuration': [],
        'icing': [],
        'turbulenceLow': [],
        'turbulenceHigh': [],
        'lowLevelWindShear': [],
        'other': [],
      },
      'urgentPireps': [],
    },
    'synopsis': {
      'surfaceAnalysisUrl': 'https://example.com/surface.png',
    },
    'currentWeather': {
      'metars': [
        {
          'station': 'APA',
          'icaoId': 'KAPA',
          'flightCategory': 'VFR',
          'rawOb': 'KAPA 112053Z VRB05KT 10SM FEW120 07/M10 A3012',
          'obsTime': '2026-02-11T20:53:00Z',
          'section': 'departure',
          'temp': 7.0,
          'dewp': -10.0,
          'wdir': 'VRB',
          'wspd': 5,
          'wgst': null,
          'visib': '10+',
          'altim': 1019.7,
          'clouds': [
            {'cover': 'FEW', 'base': 12000}
          ],
          'ceiling': null,
        }
      ],
      'pireps': [],
    },
    'forecasts': {
      'gfaCloudProducts': [],
      'gfaSurfaceProducts': [],
      'tafs': [
        {
          'station': 'APA',
          'icaoId': 'KAPA',
          'rawTaf': 'TAF KAPA ...',
          'section': 'departure',
          'fcsts': [
            {
              'timeFrom': '2026-02-11T20:00:00Z',
              'timeTo': '2026-02-12T06:00:00Z',
              'changeType': 'FM',
              'wdir': 'VRB',
              'wspd': 3,
              'wgst': null,
              'visib': 10,
              'clouds': [],
              'fltCat': 'VFR',
            }
          ],
        }
      ],
      'windsAloftTable': null,
    },
    'notams': {
      'departure': null,
      'destination': null,
      'enroute': {
        'navigation': [],
        'communication': [],
        'svc': [],
        'airspace': [],
        'specialUseAirspace': [],
        'rwyTwyApronAdFdc': [],
        'otherUnverified': [],
      },
      'artcc': [],
    },
    'routeTimeline': [
      {
        'waypoint': 'APA',
        'latitude': 39.57,
        'longitude': -104.85,
        'distanceFromDep': 0,
        'etaMinutes': 0,
        'windDir': 'VRB',
        'windSpd': 5,
        'activeHazards': [],
      }
    ],
  };
}
