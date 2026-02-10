import 'package:flutter_test/flutter_test.dart';
import 'package:efb_mobile/core/utils/notam_matcher.dart';

/// Tests for NotamProcedureMatcher — matches NOTAMs to procedure plates
/// by analyzing NOTAM type, runway references, navaid/lighting mentions.
void main() {
  /// Helper: create a NOTAM map
  Map<String, dynamic> notam({
    String text = '',
    String fullText = '',
    String type = '',
    String classification = '',
  }) =>
      {
        'text': text,
        'fullText': fullText,
        'type': type,
        'classification': classification,
      };

  group('Runway matching', () {
    test('runway NOTAM matches approach on same runway', () {
      final results = NotamProcedureMatcher.match(
        chartName: 'ILS OR LOC RWY 35R',
        chartCode: 'IAP',
        notams: [
          notam(text: 'RWY 35R CLOSED', type: 'RWY'),
        ],
      );
      expect(results, hasLength(1));
    });

    test('runway NOTAM does NOT match approach on different runway', () {
      final results = NotamProcedureMatcher.match(
        chartName: 'ILS OR LOC RWY 35R',
        chartCode: 'IAP',
        notams: [
          notam(text: 'RWY 17L CLOSED', type: 'RWY'),
        ],
      );
      expect(results, isEmpty);
    });
  });

  group('Navaid NOTAM matching', () {
    test('ILS NOTAM matches ILS approach on same runway', () {
      final results = NotamProcedureMatcher.match(
        chartName: 'ILS OR LOC RWY 35R',
        chartCode: 'IAP',
        notams: [
          notam(text: 'ILS RWY 35R GLIDESLOPE U/S', type: ''),
        ],
      );
      expect(results, hasLength(1));
    });

    test('VOR NOTAM matches VOR approach on same runway', () {
      final results = NotamProcedureMatcher.match(
        chartName: 'VOR RWY 17',
        chartCode: 'IAP',
        notams: [
          notam(text: 'VOR RWY 17 OUT OF SERVICE', type: ''),
        ],
      );
      expect(results, hasLength(1));
    });

    test('GPS NOTAM matches RNAV approach on same runway', () {
      final results = NotamProcedureMatcher.match(
        chartName: 'RNAV (GPS) RWY 28',
        chartCode: 'IAP',
        notams: [
          notam(text: 'WAAS RWY 28 UNRELIABLE', type: ''),
        ],
      );
      expect(results, hasLength(1));
    });
  });

  group('Lighting NOTAM matching', () {
    test('PAPI NOTAM matches approach on same runway', () {
      final results = NotamProcedureMatcher.match(
        chartName: 'ILS OR LOC RWY 35R',
        chartCode: 'IAP',
        notams: [
          notam(text: 'PAPI RWY 35R U/S', type: ''),
        ],
      );
      expect(results, hasLength(1));
    });

    test('REIL NOTAM matches approach on same runway', () {
      final results = NotamProcedureMatcher.match(
        chartName: 'RNAV (GPS) RWY 10',
        chartCode: 'IAP',
        notams: [
          notam(text: 'REIL RWY 10 OUT OF SERVICE', type: ''),
        ],
      );
      expect(results, hasLength(1));
    });

    test('lighting NOTAM on different runway does not match', () {
      final results = NotamProcedureMatcher.match(
        chartName: 'ILS OR LOC RWY 35R',
        chartCode: 'IAP',
        notams: [
          notam(text: 'PAPI RWY 17L U/S', type: ''),
        ],
      );
      expect(results, isEmpty);
    });
  });

  group('Airport-wide NOTAMs', () {
    test('IAP-typed NOTAM with no runway matches all IAP procedures', () {
      final results = NotamProcedureMatcher.match(
        chartName: 'ILS OR LOC RWY 35R',
        chartCode: 'IAP',
        notams: [
          notam(text: 'ALL INSTRUMENT APPROACHES NA', type: 'IAP'),
        ],
      );
      expect(results, hasLength(1));
    });

    test('airport diagram matches surface NOTAMs', () {
      final results = NotamProcedureMatcher.match(
        chartName: 'AIRPORT DIAGRAM',
        chartCode: 'APD',
        notams: [
          notam(text: 'TWY A CLOSED', type: 'TWY'),
          notam(text: 'RWY 17/35 CLOSED', type: 'RWY'),
          notam(text: 'APRON CONSTRUCTION', type: 'CONSTRUCTION'),
        ],
      );
      expect(results, hasLength(3));
    });
  });

  group('Unrelated NOTAMs', () {
    test('taxiway NOTAM does not match approach plate', () {
      final results = NotamProcedureMatcher.match(
        chartName: 'ILS OR LOC RWY 35R',
        chartCode: 'IAP',
        notams: [
          notam(text: 'TWY B CLOSED', type: 'TWY'),
        ],
      );
      expect(results, isEmpty);
    });

    test('SID NOTAM does not match IAP chart', () {
      final results = NotamProcedureMatcher.match(
        chartName: 'ILS OR LOC RWY 35R',
        chartCode: 'IAP',
        notams: [
          notam(text: 'DENVER TWO DEPARTURE RWY 35R', type: 'SID'),
        ],
      );
      // SID-typed NOTAM should not bleed into IAP category
      // unless the chart name is mentioned in the text
      expect(results, isEmpty);
    });
  });

  group('Edge cases', () {
    test('empty notams list returns empty results', () {
      final results = NotamProcedureMatcher.match(
        chartName: 'ILS OR LOC RWY 35R',
        chartCode: 'IAP',
        notams: [],
      );
      expect(results, isEmpty);
    });

    test('NOTAM with empty text does not match', () {
      final results = NotamProcedureMatcher.match(
        chartName: 'ILS OR LOC RWY 35R',
        chartCode: 'IAP',
        notams: [
          notam(text: '', fullText: '', type: '', classification: ''),
        ],
      );
      expect(results, isEmpty);
    });

    test('direct procedure name mention in NOTAM text matches', () {
      final results = NotamProcedureMatcher.match(
        chartName: 'ILS OR LOC RWY 35R',
        chartCode: 'IAP',
        notams: [
          notam(text: 'ILS OR LOC RWY 35R AMDT 5'),
        ],
      );
      expect(results, hasLength(1));
    });

    test('OBSTACLE NOTAM matches departure plate on same runway', () {
      final results = NotamProcedureMatcher.match(
        chartName: 'DENVER TWO DEPARTURE RWY 35R',
        chartCode: 'DP',
        notams: [
          notam(text: 'CRANE RWY 35R 200FT AGL', type: 'OBST'),
        ],
      );
      expect(results, hasLength(1));
    });
  });
}
