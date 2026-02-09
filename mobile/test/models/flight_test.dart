import 'package:flutter_test/flutter_test.dart';
import 'package:efb_mobile/models/flight.dart';

Map<String, dynamic> _fullFlightJson() => {
      'id': 1,
      'aircraft_id': 10,
      'performance_profile_id': 5,
      'departure_identifier': 'APA',
      'destination_identifier': 'DEN',
      'alternate_identifier': 'BJC',
      'etd': '2025-03-15T14:00:00Z',
      'aircraft_identifier': 'N12345',
      'aircraft_type': 'TBM 960',
      'performance_profile': 'cruise',
      'true_airspeed': 300,
      'flight_rules': 'IFR',
      'route_string': 'APA V389 DEN',
      'cruise_altitude': 28000,
      'people_count': 3,
      'avg_person_weight': 185.0,
      'cargo_weight': 100.0,
      'fuel_policy': 'full_tanks',
      'start_fuel_gallons': 282.0,
      'reserve_fuel_gallons': 30.0,
      'fuel_burn_rate': 55.0,
      'fuel_at_shutdown_gallons': 10.0,
      'filing_status': 'filed',
      'filing_reference': 'FP1001',
      'filing_version_stamp': 'v123',
      'filed_at': '2025-03-15T13:00:00Z',
      'filing_format': 'icao',
      'endurance_hours': 5.1,
      'remarks': 'Test flight',
      'distance_nm': 18.5,
      'ete_minutes': 8,
      'flight_fuel_gallons': 7.3,
      'wind_component': -10.0,
      'eta': '2025-03-15T14:08:00Z',
      'calculated_at': '2025-03-15T13:30:00Z',
      'created_at': '2025-03-15T12:00:00Z',
      'updated_at': '2025-03-15T13:30:00Z',
    };

void main() {
  group('Flight', () {
    group('fromJson', () {
      test('should deserialize all fields from full JSON', () {
        final fullJson = _fullFlightJson();
        final flight = Flight.fromJson(fullJson);

        expect(flight.id, 1);
        expect(flight.aircraftId, 10);
        expect(flight.performanceProfileId, 5);
        expect(flight.departureIdentifier, 'APA');
        expect(flight.destinationIdentifier, 'DEN');
        expect(flight.alternateIdentifier, 'BJC');
        expect(flight.etd, '2025-03-15T14:00:00Z');
        expect(flight.aircraftIdentifier, 'N12345');
        expect(flight.aircraftType, 'TBM 960');
        expect(flight.trueAirspeed, 300);
        expect(flight.flightRules, 'IFR');
        expect(flight.routeString, 'APA V389 DEN');
        expect(flight.cruiseAltitude, 28000);
        expect(flight.peopleCount, 3);
        expect(flight.avgPersonWeight, 185.0);
        expect(flight.cargoWeight, 100.0);
        expect(flight.startFuelGallons, 282.0);
        expect(flight.reserveFuelGallons, 30.0);
        expect(flight.fuelBurnRate, 55.0);
        expect(flight.fuelAtShutdownGallons, 10.0);
        expect(flight.filingStatus, 'filed');
        expect(flight.filingReference, 'FP1001');
        expect(flight.filingVersionStamp, 'v123');
        expect(flight.filedAt, '2025-03-15T13:00:00Z');
        expect(flight.filingFormat, 'icao');
        expect(flight.enduranceHours, 5.1);
        expect(flight.remarks, 'Test flight');
        expect(flight.distanceNm, 18.5);
        expect(flight.eteMinutes, 8);
        expect(flight.flightFuelGallons, 7.3);
        expect(flight.windComponent, -10.0);
        expect(flight.eta, '2025-03-15T14:08:00Z');
        expect(flight.calculatedAt, '2025-03-15T13:30:00Z');
      });

      test('should use defaults for missing fields', () {
        final flight = Flight.fromJson({});

        expect(flight.id, isNull);
        expect(flight.departureIdentifier, isNull);
        expect(flight.flightRules, 'IFR');
        expect(flight.peopleCount, 1);
        expect(flight.avgPersonWeight, 170.0);
        expect(flight.cargoWeight, 0.0);
        expect(flight.fuelAtShutdownGallons, 0.0);
        expect(flight.filingStatus, 'not_filed');
      });

      test('should handle numeric values passed as int or double', () {
        final flight = Flight.fromJson({
          'start_fuel_gallons': 48,
          'fuel_burn_rate': 10.5,
          'distance_nm': 120,
        });

        expect(flight.startFuelGallons, 48.0);
        expect(flight.fuelBurnRate, 10.5);
        expect(flight.distanceNm, 120.0);
      });
    });

    group('toJson', () {
      test('should serialize editable fields', () {
        final flight = Flight.fromJson(_fullFlightJson());
        final json = flight.toJson();

        expect(json['id'], 1);
        expect(json['departure_identifier'], 'APA');
        expect(json['destination_identifier'], 'DEN');
        expect(json['aircraft_identifier'], 'N12345');
        expect(json['flight_rules'], 'IFR');
        expect(json['cruise_altitude'], 28000);
        expect(json['people_count'], 3);
        expect(json['start_fuel_gallons'], 282.0);
        expect(json['filing_status'], 'filed');
        expect(json['remarks'], 'Test flight');
      });

      test('should NOT include computed/read-only fields', () {
        final flight = Flight.fromJson(_fullFlightJson());
        final json = flight.toJson();

        expect(json.containsKey('distance_nm'), false);
        expect(json.containsKey('ete_minutes'), false);
        expect(json.containsKey('flight_fuel_gallons'), false);
        expect(json.containsKey('eta'), false);
        expect(json.containsKey('calculated_at'), false);
        expect(json.containsKey('filing_reference'), false);
        expect(json.containsKey('filing_version_stamp'), false);
        expect(json.containsKey('filed_at'), false);
        expect(json.containsKey('created_at'), false);
        expect(json.containsKey('updated_at'), false);
      });

      test('should omit id when null', () {
        final flight = Flight.fromJson({});
        final json = flight.toJson();
        expect(json.containsKey('id'), false);
      });
    });

    group('toFullJson', () {
      test('should include computed fields', () {
        final flight = Flight.fromJson(_fullFlightJson());
        final json = flight.toFullJson();

        expect(json['distance_nm'], 18.5);
        expect(json['ete_minutes'], 8);
        expect(json['flight_fuel_gallons'], 7.3);
        expect(json['eta'], '2025-03-15T14:08:00Z');
        expect(json['calculated_at'], '2025-03-15T13:30:00Z');
        expect(json['filing_reference'], 'FP1001');
        expect(json['filing_version_stamp'], 'v123');
        expect(json['filed_at'], '2025-03-15T13:00:00Z');
        expect(json['filing_format'], 'icao');
        expect(json['created_at'], '2025-03-15T12:00:00Z');
        expect(json['updated_at'], '2025-03-15T13:30:00Z');
      });

      test('should be a superset of toJson', () {
        final flight = Flight.fromJson(_fullFlightJson());
        final json = flight.toJson();
        final fullJsonResult = flight.toFullJson();

        for (final key in json.keys) {
          expect(fullJsonResult.containsKey(key), true,
              reason: 'toFullJson missing key: $key');
          expect(fullJsonResult[key], json[key],
              reason: 'toFullJson value mismatch for key: $key');
        }
      });
    });

    group('copyWith', () {
      test('should create a copy with updated fields', () {
        final original = Flight.fromJson(_fullFlightJson());
        final copy = original.copyWith(
          departureIdentifier: 'BJC',
          cruiseAltitude: 10000,
        );

        expect(copy.departureIdentifier, 'BJC');
        expect(copy.cruiseAltitude, 10000);
        expect(copy.destinationIdentifier, 'DEN');
        expect(copy.aircraftIdentifier, 'N12345');
        expect(copy.id, 1);
      });

      test('should preserve all fields when no arguments given', () {
        final original = Flight.fromJson(_fullFlightJson());
        final copy = original.copyWith();

        expect(copy.id, original.id);
        expect(copy.departureIdentifier, original.departureIdentifier);
        expect(copy.destinationIdentifier, original.destinationIdentifier);
        expect(copy.flightRules, original.flightRules);
        expect(copy.filingStatus, original.filingStatus);
        expect(copy.distanceNm, original.distanceNm);
      });

      test('should allow updating filing status', () {
        final original = Flight.fromJson(_fullFlightJson());
        final copy = original.copyWith(filingStatus: 'not_filed');

        expect(copy.filingStatus, 'not_filed');
        expect(original.filingStatus, 'filed');
      });
    });

    group('defaults', () {
      test('should have sensible default values', () {
        const flight = Flight();

        expect(flight.flightRules, 'IFR');
        expect(flight.peopleCount, 1);
        expect(flight.avgPersonWeight, 170);
        expect(flight.cargoWeight, 0);
        expect(flight.fuelAtShutdownGallons, 0);
        expect(flight.filingStatus, 'not_filed');
      });
    });

    group('roundtrip', () {
      test('toJson -> fromJson should preserve editable fields', () {
        final original = Flight.fromJson(_fullFlightJson());
        final json = original.toJson();
        final restored = Flight.fromJson(json);

        expect(restored.departureIdentifier, original.departureIdentifier);
        expect(restored.destinationIdentifier, original.destinationIdentifier);
        expect(restored.flightRules, original.flightRules);
        expect(restored.cruiseAltitude, original.cruiseAltitude);
        expect(restored.trueAirspeed, original.trueAirspeed);
        expect(restored.peopleCount, original.peopleCount);
        expect(restored.startFuelGallons, original.startFuelGallons);
      });

      test('toFullJson -> fromJson should preserve all fields', () {
        final original = Flight.fromJson(_fullFlightJson());
        final json = original.toFullJson();
        final restored = Flight.fromJson(json);

        expect(restored.distanceNm, original.distanceNm);
        expect(restored.eteMinutes, original.eteMinutes);
        expect(restored.eta, original.eta);
        expect(restored.filingReference, original.filingReference);
        expect(restored.calculatedAt, original.calculatedAt);
      });
    });
  });
}
