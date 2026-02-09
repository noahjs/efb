import 'package:flutter_test/flutter_test.dart';
import 'package:efb_mobile/models/logbook_entry.dart';

Map<String, dynamic> _fullEntryJson() => {
      'id': 1,
      'date': '2025-03-15',
      'aircraft_id': 10,
      'aircraft_identifier': 'N12345',
      'aircraft_type': 'Cessna 172',
      'from_airport': 'APA',
      'to_airport': 'DEN',
      'route': 'APA V389 DEN',
      'hobbs_start': 1234.5,
      'hobbs_end': 1236.0,
      'tach_start': 2000.1,
      'tach_end': 2001.5,
      'time_out': '14:00Z',
      'time_off': '14:05Z',
      'time_on': '14:50Z',
      'time_in': '14:55Z',
      'total_time': 1.5,
      'pic': 1.5,
      'sic': 0.0,
      'night': 0.3,
      'solo': 0.0,
      'cross_country': 1.5,
      'distance': 18.5,
      'actual_instrument': 0.5,
      'simulated_instrument': 0.0,
      'day_takeoffs': 1,
      'night_takeoffs': 0,
      'day_landings_full_stop': 1,
      'night_landings_full_stop': 0,
      'all_landings': 1,
      'holds': 2,
      'approaches': 'ILS 35L;RNAV 17R',
      'dual_given': 0.0,
      'dual_received': 0.0,
      'simulated_flight': 0.0,
      'ground_training': 0.0,
      'instructor_name': 'Jane Smith',
      'instructor_comments': 'Good approach work',
      'person1': 'Passenger 1',
      'person2': 'Passenger 2',
      'person3': null,
      'person4': null,
      'person5': null,
      'person6': null,
      'flight_review': false,
      'checkride': false,
      'ipc': true,
      'comments': 'Practice ILS approaches',
      'created_at': '2025-03-15T15:00:00Z',
      'updated_at': '2025-03-15T15:00:00Z',
    };

void main() {
  group('LogbookEntry', () {
    group('fromJson', () {
      test('should deserialize all fields', () {
        final entry = LogbookEntry.fromJson(_fullEntryJson());

        expect(entry.id, 1);
        expect(entry.date, '2025-03-15');
        expect(entry.aircraftId, 10);
        expect(entry.aircraftIdentifier, 'N12345');
        expect(entry.aircraftType, 'Cessna 172');
        expect(entry.fromAirport, 'APA');
        expect(entry.toAirport, 'DEN');
        expect(entry.route, 'APA V389 DEN');
        expect(entry.hobbsStart, 1234.5);
        expect(entry.hobbsEnd, 1236.0);
        expect(entry.tachStart, 2000.1);
        expect(entry.tachEnd, 2001.5);
        expect(entry.totalTime, 1.5);
        expect(entry.pic, 1.5);
        expect(entry.night, 0.3);
        expect(entry.crossCountry, 1.5);
        expect(entry.actualInstrument, 0.5);
        expect(entry.dayTakeoffs, 1);
        expect(entry.dayLandingsFullStop, 1);
        expect(entry.allLandings, 1);
        expect(entry.holds, 2);
        expect(entry.approaches, 'ILS 35L;RNAV 17R');
        expect(entry.ipc, true);
        expect(entry.flightReview, false);
        expect(entry.comments, 'Practice ILS approaches');
        expect(entry.instructorName, 'Jane Smith');
        expect(entry.person1, 'Passenger 1');
      });

      test('should use defaults for missing fields', () {
        final entry = LogbookEntry.fromJson({});

        expect(entry.id, isNull);
        expect(entry.date, isNull);
        expect(entry.totalTime, 0.0);
        expect(entry.pic, 0.0);
        expect(entry.sic, 0.0);
        expect(entry.night, 0.0);
        expect(entry.solo, 0.0);
        expect(entry.crossCountry, 0.0);
        expect(entry.actualInstrument, 0.0);
        expect(entry.simulatedInstrument, 0.0);
        expect(entry.dayTakeoffs, 0);
        expect(entry.nightTakeoffs, 0);
        expect(entry.dayLandingsFullStop, 0);
        expect(entry.nightLandingsFullStop, 0);
        expect(entry.allLandings, 0);
        expect(entry.holds, 0);
        expect(entry.dualGiven, 0.0);
        expect(entry.dualReceived, 0.0);
        expect(entry.simulatedFlight, 0.0);
        expect(entry.groundTraining, 0.0);
        expect(entry.flightReview, false);
        expect(entry.checkride, false);
        expect(entry.ipc, false);
      });

      test('should handle int values for double fields', () {
        final entry = LogbookEntry.fromJson({
          'total_time': 2,
          'pic': 2,
          'hobbs_start': 1000,
        });

        expect(entry.totalTime, 2.0);
        expect(entry.pic, 2.0);
        expect(entry.hobbsStart, 1000.0);
      });
    });

    group('toJson', () {
      test('should serialize all fields', () {
        final entry = LogbookEntry.fromJson(_fullEntryJson());
        final json = entry.toJson();

        expect(json['id'], 1);
        expect(json['date'], '2025-03-15');
        expect(json['aircraft_identifier'], 'N12345');
        expect(json['from_airport'], 'APA');
        expect(json['to_airport'], 'DEN');
        expect(json['total_time'], 1.5);
        expect(json['pic'], 1.5);
        expect(json['day_landings_full_stop'], 1);
        expect(json['holds'], 2);
        expect(json['approaches'], 'ILS 35L;RNAV 17R');
        expect(json['ipc'], true);
        expect(json['flight_review'], false);
        expect(json['comments'], 'Practice ILS approaches');
      });

      test('should omit id when null', () {
        final entry = LogbookEntry.fromJson({});
        final json = entry.toJson();
        expect(json.containsKey('id'), false);
      });

      test('should not include metadata fields', () {
        final entry = LogbookEntry.fromJson(_fullEntryJson());
        final json = entry.toJson();

        expect(json.containsKey('created_at'), false);
        expect(json.containsKey('updated_at'), false);
      });
    });

    group('copyWith', () {
      test('should create a copy with updated fields', () {
        final original = LogbookEntry.fromJson(_fullEntryJson());
        final copy = original.copyWith(
          fromAirport: 'BJC',
          totalTime: 2.0,
          nightLandingsFullStop: 1,
        );

        expect(copy.fromAirport, 'BJC');
        expect(copy.totalTime, 2.0);
        expect(copy.nightLandingsFullStop, 1);
        expect(copy.toAirport, 'DEN');
        expect(copy.aircraftIdentifier, 'N12345');
        expect(copy.id, 1);
      });

      test('should preserve all fields when no arguments given', () {
        final original = LogbookEntry.fromJson(_fullEntryJson());
        final copy = original.copyWith();

        expect(copy.id, original.id);
        expect(copy.date, original.date);
        expect(copy.totalTime, original.totalTime);
        expect(copy.pic, original.pic);
        expect(copy.holds, original.holds);
        expect(copy.ipc, original.ipc);
        expect(copy.comments, original.comments);
      });

      test('should allow toggling boolean fields', () {
        final original = LogbookEntry.fromJson(_fullEntryJson());
        final copy = original.copyWith(
          flightReview: true,
          checkride: true,
          ipc: false,
        );

        expect(copy.flightReview, true);
        expect(copy.checkride, true);
        expect(copy.ipc, false);
      });
    });

    group('roundtrip', () {
      test('toJson -> fromJson should preserve data', () {
        final original = LogbookEntry.fromJson(_fullEntryJson());
        final json = original.toJson();
        final restored = LogbookEntry.fromJson(json);

        expect(restored.date, original.date);
        expect(restored.fromAirport, original.fromAirport);
        expect(restored.toAirport, original.toAirport);
        expect(restored.totalTime, original.totalTime);
        expect(restored.pic, original.pic);
        expect(restored.dayLandingsFullStop, original.dayLandingsFullStop);
        expect(restored.holds, original.holds);
        expect(restored.approaches, original.approaches);
        expect(restored.ipc, original.ipc);
        expect(restored.comments, original.comments);
      });
    });

    group('training entry', () {
      test('should handle dual received entry', () {
        final entry = LogbookEntry.fromJson({
          'date': '2025-03-15',
          'total_time': 1.5,
          'dual_received': 1.5,
          'instructor_name': 'Jane CFI',
          'instructor_comments': 'Practiced stalls',
          'day_takeoffs': 3,
          'day_landings_full_stop': 3,
          'all_landings': 3,
        });

        expect(entry.dualReceived, 1.5);
        expect(entry.instructorName, 'Jane CFI');
        expect(entry.dayTakeoffs, 3);
        expect(entry.pic, 0.0);
      });

      test('should handle sim entry', () {
        final entry = LogbookEntry.fromJson({
          'date': '2025-03-15',
          'total_time': 0.0,
          'simulated_flight': 2.0,
          'ground_training': 1.0,
          'actual_instrument': 0.0,
          'simulated_instrument': 1.5,
          'holds': 4,
          'approaches': 'ILS;VOR;RNAV;LOC',
        });

        expect(entry.simulatedFlight, 2.0);
        expect(entry.groundTraining, 1.0);
        expect(entry.simulatedInstrument, 1.5);
        expect(entry.holds, 4);
      });
    });
  });
}
