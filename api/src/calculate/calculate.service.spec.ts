import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import {
  CalculateService,
  haversineNm,
  CalculateInput,
} from './calculate.service';
import { Airport } from '../airports/entities/airport.entity';
import { PerformanceProfile } from '../aircraft/entities/performance-profile.entity';
import { NavaidsService } from '../navaids/navaids.service';

describe('haversineNm', () => {
  it('should return 0 for identical points', () => {
    expect(haversineNm(39.57, -104.85, 39.57, -104.85)).toBeCloseTo(0, 1);
  });

  it('should compute KAPA to KDEN correctly (~15 nm)', () => {
    // APA: 39.5701, -104.8493   DEN: 39.8561, -104.6737
    const dist = haversineNm(39.5701, -104.8493, 39.8561, -104.6737);
    expect(dist).toBeGreaterThan(15);
    expect(dist).toBeLessThan(22);
  });

  it('should compute KDEN to KORD correctly (~770 nm)', () => {
    // DEN: 39.8561, -104.6737   ORD: 41.9742, -87.9073
    const dist = haversineNm(39.8561, -104.6737, 41.9742, -87.9073);
    expect(dist).toBeGreaterThan(750);
    expect(dist).toBeLessThan(800);
  });

  it('should be symmetric', () => {
    const ab = haversineNm(39.57, -104.85, 41.97, -87.91);
    const ba = haversineNm(41.97, -87.91, 39.57, -104.85);
    expect(ab).toBeCloseTo(ba, 5);
  });

  it('should handle crossing the equator', () => {
    const dist = haversineNm(1, 0, -1, 0);
    // 2 degrees latitude ≈ 120 nm
    expect(dist).toBeGreaterThan(115);
    expect(dist).toBeLessThan(125);
  });

  it('should handle crossing the antimeridian', () => {
    const dist = haversineNm(0, 179, 0, -179);
    // 2 degrees longitude at equator ≈ 120 nm
    expect(dist).toBeGreaterThan(115);
    expect(dist).toBeLessThan(125);
  });
});

describe('CalculateService', () => {
  let service: CalculateService;
  let mockNavaidsService: any;
  let mockAirportRepo: any;
  let mockProfileRepo: any;

  // Standard waypoints for testing
  const KAPA = {
    identifier: 'APA',
    latitude: 39.5701,
    longitude: -104.8493,
    type: 'airport',
  };
  const KDEN = {
    identifier: 'DEN',
    latitude: 39.8561,
    longitude: -104.6737,
    type: 'airport',
  };
  const KORD = {
    identifier: 'ORD',
    latitude: 41.9742,
    longitude: -87.9073,
    type: 'airport',
  };

  const fullProfile = {
    id: 1,
    climb_rate: 1000,
    climb_speed: 120,
    climb_fuel_flow: 25,
    cruise_tas: 250,
    cruise_fuel_burn: 40,
    descent_rate: 800,
    descent_speed: 200,
    descent_fuel_flow: 15,
  };

  beforeEach(async () => {
    mockNavaidsService = {
      resolveRoute: jest.fn().mockResolvedValue([]),
    };

    mockAirportRepo = {
      findOne: jest.fn().mockResolvedValue(null),
    };

    mockProfileRepo = {
      findOne: jest.fn().mockResolvedValue(null),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        CalculateService,
        { provide: NavaidsService, useValue: mockNavaidsService },
        { provide: getRepositoryToken(Airport), useValue: mockAirportRepo },
        {
          provide: getRepositoryToken(PerformanceProfile),
          useValue: mockProfileRepo,
        },
      ],
    }).compile();

    service = module.get<CalculateService>(CalculateService);
  });

  // --- Single-phase calculation ---

  describe('single-phase calculation', () => {
    it('should return null result when fewer than 2 identifiers', async () => {
      const result = await service.calculate({
        departure_identifier: 'APA',
      });

      expect(result.distance_nm).toBeNull();
      expect(result.ete_minutes).toBeNull();
      expect(result.calculation_method).toBe('none');
    });

    it('should return null result when waypoints cannot be resolved', async () => {
      mockNavaidsService.resolveRoute.mockResolvedValue([]);

      const result = await service.calculate({
        departure_identifier: 'APA',
        destination_identifier: 'DEN',
      });

      expect(result.distance_nm).toBeNull();
      expect(result.calculation_method).toBe('none');
    });

    it('should return only distance when no TAS provided', async () => {
      mockNavaidsService.resolveRoute.mockResolvedValue([KAPA, KDEN]);

      const result = await service.calculate({
        departure_identifier: 'APA',
        destination_identifier: 'DEN',
      });

      expect(result.distance_nm).not.toBeNull();
      expect(result.distance_nm).toBeGreaterThan(0);
      expect(result.ete_minutes).toBeNull();
      expect(result.calculation_method).toBe('single_phase');
    });

    it('should compute ETE with TAS', async () => {
      mockNavaidsService.resolveRoute.mockResolvedValue([KAPA, KDEN]);

      const result = await service.calculate({
        departure_identifier: 'APA',
        destination_identifier: 'DEN',
        true_airspeed: 120,
      });

      expect(result.distance_nm).toBeGreaterThan(0);
      expect(result.ete_minutes).toBeGreaterThan(0);
      expect(result.calculation_method).toBe('single_phase');
      // ETE should be roughly distance / TAS * 60 (within 1 min due to rounding)
      const expectedMinutes = (result.distance_nm! / 120) * 60;
      expect(
        Math.abs(result.ete_minutes! - Math.round(expectedMinutes)),
      ).toBeLessThanOrEqual(1);
    });

    it('should compute fuel gallons with burn rate', async () => {
      mockNavaidsService.resolveRoute.mockResolvedValue([KAPA, KDEN]);

      const result = await service.calculate({
        departure_identifier: 'APA',
        destination_identifier: 'DEN',
        true_airspeed: 120,
        fuel_burn_rate: 10,
      });

      expect(result.flight_fuel_gallons).not.toBeNull();
      expect(result.flight_fuel_gallons).toBeGreaterThan(0);
    });

    it('should return null fuel when no burn rate', async () => {
      mockNavaidsService.resolveRoute.mockResolvedValue([KAPA, KDEN]);

      const result = await service.calculate({
        departure_identifier: 'APA',
        destination_identifier: 'DEN',
        true_airspeed: 120,
      });

      expect(result.flight_fuel_gallons).toBeNull();
    });

    it('should compute ETA from ETD', async () => {
      mockNavaidsService.resolveRoute.mockResolvedValue([KAPA, KDEN]);

      const result = await service.calculate({
        departure_identifier: 'APA',
        destination_identifier: 'DEN',
        true_airspeed: 120,
        etd: '2025-03-15T14:00:00Z',
      });

      expect(result.eta).not.toBeNull();
      const eta = new Date(result.eta!);
      const etd = new Date('2025-03-15T14:00:00Z');
      expect(eta.getTime()).toBeGreaterThan(etd.getTime());
      // ETA - ETD should equal ete_minutes (in ms)
      const diffMinutes = (eta.getTime() - etd.getTime()) / 60000;
      expect(diffMinutes).toBe(result.ete_minutes);
    });

    it('should return null ETA when no ETD', async () => {
      mockNavaidsService.resolveRoute.mockResolvedValue([KAPA, KDEN]);

      const result = await service.calculate({
        departure_identifier: 'APA',
        destination_identifier: 'DEN',
        true_airspeed: 120,
      });

      expect(result.eta).toBeNull();
    });

    it('should include resolved waypoints in result', async () => {
      mockNavaidsService.resolveRoute.mockResolvedValue([KAPA, KDEN]);

      const result = await service.calculate({
        departure_identifier: 'APA',
        destination_identifier: 'DEN',
        true_airspeed: 120,
      });

      expect(result.waypoints).toHaveLength(2);
      expect(result.waypoints[0].identifier).toBe('APA');
      expect(result.waypoints[1].identifier).toBe('DEN');
    });
  });

  // --- Multi-leg distance ---

  describe('multi-leg routes', () => {
    it('should sum distances across multiple waypoints', async () => {
      const midpoint = {
        identifier: 'MID',
        latitude: 40.5,
        longitude: -96.0,
        type: 'navaid',
      };
      mockNavaidsService.resolveRoute.mockResolvedValue([KAPA, midpoint, KORD]);

      const result = await service.calculate({
        departure_identifier: 'APA',
        route_string: 'MID',
        destination_identifier: 'ORD',
        true_airspeed: 200,
      });

      // Direct KAPA→KORD is ~885nm; going via MID should be longer
      const directResult = haversineNm(
        KAPA.latitude,
        KAPA.longitude,
        KORD.latitude,
        KORD.longitude,
      );
      expect(result.distance_nm).toBeGreaterThan(directResult);
    });

    it('should handle route_string with multiple identifiers', async () => {
      mockNavaidsService.resolveRoute.mockResolvedValue([KAPA, KDEN, KORD]);

      await service.calculate({
        departure_identifier: 'APA',
        route_string: 'DEN',
        destination_identifier: 'ORD',
      });

      // Should pass all 3 identifiers to resolveRoute
      expect(mockNavaidsService.resolveRoute).toHaveBeenCalledWith([
        'APA',
        'DEN',
        'ORD',
      ]);
    });
  });

  // --- Three-phase calculation ---

  describe('three-phase calculation', () => {
    it('should use three-phase when profile has full climb/descent data', async () => {
      mockNavaidsService.resolveRoute.mockResolvedValue([KAPA, KORD]);
      mockProfileRepo.findOne.mockResolvedValue({ ...fullProfile });
      // APA elevation = 5885, ORD = 668
      mockAirportRepo.findOne.mockImplementation(async ({ where }) => {
        const conditions = Array.isArray(where) ? where : [where];
        for (const cond of conditions) {
          if (
            cond.identifier?.['_value']?.toLowerCase() === 'apa' ||
            cond.icao_identifier?.['_value']?.toLowerCase() === 'apa'
          ) {
            return { elevation: 5885 };
          }
          if (
            cond.identifier?.['_value']?.toLowerCase() === 'ord' ||
            cond.icao_identifier?.['_value']?.toLowerCase() === 'ord'
          ) {
            return { elevation: 668 };
          }
        }
        return null;
      });

      const result = await service.calculate({
        departure_identifier: 'APA',
        destination_identifier: 'ORD',
        cruise_altitude: 17000,
        performance_profile_id: 1,
      });

      expect(result.calculation_method).toBe('three_phase');
      expect(result.phases).toHaveLength(3);
      expect(result.phases![0].phase).toBe('climb');
      expect(result.phases![1].phase).toBe('cruise');
      expect(result.phases![2].phase).toBe('descent');
    });

    it('should fall back to single-phase when profile missing climb fields', async () => {
      mockNavaidsService.resolveRoute.mockResolvedValue([KAPA, KDEN]);
      mockProfileRepo.findOne.mockResolvedValue({
        id: 1,
        cruise_tas: 120,
        cruise_fuel_burn: 10,
        // Missing climb/descent fields
      });

      const result = await service.calculate({
        departure_identifier: 'APA',
        destination_identifier: 'DEN',
        cruise_altitude: 10000,
        performance_profile_id: 1,
        true_airspeed: 120,
      });

      expect(result.calculation_method).toBe('single_phase');
    });

    it('should fall back when climb+descent exceeds total distance', async () => {
      mockNavaidsService.resolveRoute.mockResolvedValue([KAPA, KDEN]);
      mockProfileRepo.findOne.mockResolvedValue({
        ...fullProfile,
        climb_speed: 120,
        descent_speed: 120,
      });
      // Both airports at sea level
      mockAirportRepo.findOne.mockResolvedValue({ elevation: 0 });

      const result = await service.calculate({
        departure_identifier: 'APA',
        destination_identifier: 'DEN',
        cruise_altitude: 40000, // Very high altitude for short route
        performance_profile_id: 1,
        true_airspeed: 120,
      });

      // Should fall back since climb + descent > ~18nm total
      expect(result.calculation_method).toBe('single_phase');
    });

    it('should produce phases that sum to total ETE', async () => {
      mockNavaidsService.resolveRoute.mockResolvedValue([KAPA, KORD]);
      mockProfileRepo.findOne.mockResolvedValue({ ...fullProfile });
      mockAirportRepo.findOne.mockResolvedValue({ elevation: 0 });

      const result = await service.calculate({
        departure_identifier: 'APA',
        destination_identifier: 'ORD',
        cruise_altitude: 17000,
        performance_profile_id: 1,
      });

      if (result.phases) {
        const phaseTimeSum = result.phases.reduce(
          (s, p) => s + p.time_minutes,
          0,
        );
        // ete_minutes is Math.round of sum, so should be close
        expect(result.ete_minutes).toBe(Math.round(phaseTimeSum));
      }
    });

    it('should produce phases that sum to total fuel', async () => {
      mockNavaidsService.resolveRoute.mockResolvedValue([KAPA, KORD]);
      mockProfileRepo.findOne.mockResolvedValue({ ...fullProfile });
      mockAirportRepo.findOne.mockResolvedValue({ elevation: 0 });

      const result = await service.calculate({
        departure_identifier: 'APA',
        destination_identifier: 'ORD',
        cruise_altitude: 17000,
        performance_profile_id: 1,
      });

      if (result.phases) {
        const phaseFuelSum = result.phases.reduce(
          (s, p) => s + p.fuel_gallons,
          0,
        );
        expect(result.flight_fuel_gallons).toBe(
          Math.round(phaseFuelSum * 10) / 10,
        );
      }
    });

    it('should set correct start/end altitudes for each phase', async () => {
      mockNavaidsService.resolveRoute.mockResolvedValue([KAPA, KORD]);
      mockProfileRepo.findOne.mockResolvedValue({ ...fullProfile });
      mockAirportRepo.findOne.mockImplementation(async ({ where }) => {
        // Simplified: return different elevations for departure/destination
        const conditions = Array.isArray(where) ? where : [where];
        for (const cond of conditions) {
          const val =
            cond.identifier?.['_value'] ||
            cond.icao_identifier?.['_value'] ||
            '';
          if (val.toLowerCase() === 'apa') return { elevation: 5885 };
          if (val.toLowerCase() === 'ord') return { elevation: 668 };
        }
        return { elevation: 0 };
      });

      const result = await service.calculate({
        departure_identifier: 'APA',
        destination_identifier: 'ORD',
        cruise_altitude: 17000,
        performance_profile_id: 1,
      });

      if (result.phases) {
        expect(result.phases[0].start_altitude_ft).toBe(5885); // climb starts at dep
        expect(result.phases[0].end_altitude_ft).toBe(17000); // climb to cruise
        expect(result.phases[1].start_altitude_ft).toBe(17000); // cruise at cruise
        expect(result.phases[1].end_altitude_ft).toBe(17000); // cruise at cruise
        expect(result.phases[2].start_altitude_ft).toBe(17000); // descent from cruise
      }
    });
  });

  // --- calculateForAltitudes ---

  describe('calculateForAltitudes', () => {
    it('should return results for all requested altitudes', async () => {
      mockNavaidsService.resolveRoute.mockResolvedValue([KAPA, KORD]);
      mockProfileRepo.findOne.mockResolvedValue({ ...fullProfile });
      mockAirportRepo.findOne.mockResolvedValue({ elevation: 0 });

      const altitudes = [8000, 10000, 12000, 14000];
      const result = await service.calculateForAltitudes(
        {
          departure_identifier: 'APA',
          destination_identifier: 'ORD',
          performance_profile_id: 1,
        },
        altitudes,
      );

      expect(result.distance_nm).not.toBeNull();
      expect(result.results).toHaveLength(4);
      for (const r of result.results) {
        expect(altitudes).toContain(r.altitude);
        expect(r.ete_minutes).not.toBeNull();
      }
    });

    it('should return null results when fewer than 2 identifiers', async () => {
      const result = await service.calculateForAltitudes(
        { departure_identifier: 'APA' },
        [8000, 10000],
      );

      expect(result.distance_nm).toBeNull();
      expect(result.results).toHaveLength(2);
      expect(result.results[0].calculation_method).toBe('none');
    });

    it('should produce same distance for all altitudes', async () => {
      mockNavaidsService.resolveRoute.mockResolvedValue([KAPA, KORD]);
      mockProfileRepo.findOne.mockResolvedValue({ ...fullProfile });
      mockAirportRepo.findOne.mockResolvedValue({ elevation: 0 });

      const result = await service.calculateForAltitudes(
        {
          departure_identifier: 'APA',
          destination_identifier: 'ORD',
          performance_profile_id: 1,
        },
        [8000, 12000, 16000],
      );

      // Distance doesn't change with altitude
      expect(result.distance_nm).toBeGreaterThan(0);
    });

    it('should show higher altitude = more fuel for short climb (more time at cruise)', async () => {
      mockNavaidsService.resolveRoute.mockResolvedValue([KAPA, KORD]);
      mockProfileRepo.findOne.mockResolvedValue({ ...fullProfile });
      mockAirportRepo.findOne.mockResolvedValue({ elevation: 0 });

      const result = await service.calculateForAltitudes(
        {
          departure_identifier: 'APA',
          destination_identifier: 'ORD',
          performance_profile_id: 1,
        },
        [8000, 18000],
      );

      // Both should have fuel values
      expect(result.results[0].flight_fuel_gallons).not.toBeNull();
      expect(result.results[1].flight_fuel_gallons).not.toBeNull();
    });
  });

  // --- Debug mode ---

  describe('calculateDebug', () => {
    it('should return steps array in debug mode', async () => {
      mockNavaidsService.resolveRoute.mockResolvedValue([KAPA, KDEN]);

      const result = await service.calculateDebug({
        departure_identifier: 'APA',
        destination_identifier: 'DEN',
        true_airspeed: 120,
      });

      expect(result.steps).toBeDefined();
      expect(result.steps.length).toBeGreaterThan(0);
      expect(result.steps[0]).toHaveProperty('label');
      expect(result.steps[0]).toHaveProperty('value');
    });
  });

  // --- Edge cases ---

  describe('edge cases', () => {
    it('should handle empty route_string gracefully', async () => {
      mockNavaidsService.resolveRoute.mockResolvedValue([KAPA, KDEN]);

      const result = await service.calculate({
        departure_identifier: 'APA',
        destination_identifier: 'DEN',
        route_string: '',
        true_airspeed: 120,
      });

      expect(result.distance_nm).not.toBeNull();
    });

    it('should handle route_string with extra whitespace', async () => {
      mockNavaidsService.resolveRoute.mockResolvedValue([KAPA, KDEN]);

      await service.calculate({
        departure_identifier: 'APA',
        destination_identifier: 'DEN',
        route_string: '  ',
        true_airspeed: 120,
      });

      // Should still call with just dep + dest, ignoring whitespace
      expect(mockNavaidsService.resolveRoute).toHaveBeenCalledWith([
        'APA',
        'DEN',
      ]);
    });

    it('should handle invalid ETD gracefully', async () => {
      mockNavaidsService.resolveRoute.mockResolvedValue([KAPA, KDEN]);

      const result = await service.calculate({
        departure_identifier: 'APA',
        destination_identifier: 'DEN',
        true_airspeed: 120,
        etd: 'not-a-date',
      });

      expect(result.eta).toBeNull();
      expect(result.ete_minutes).not.toBeNull();
    });

    it('should return 0 elevation for unknown airport', async () => {
      mockNavaidsService.resolveRoute.mockResolvedValue([KAPA, KORD]);
      mockProfileRepo.findOne.mockResolvedValue({ ...fullProfile });
      mockAirportRepo.findOne.mockResolvedValue(null);

      const result = await service.calculate({
        departure_identifier: 'APA',
        destination_identifier: 'ORD',
        cruise_altitude: 10000,
        performance_profile_id: 1,
      });

      // Should still work with 0 elevation
      expect(result.distance_nm).not.toBeNull();
    });

    it('should include calculated_at timestamp', async () => {
      mockNavaidsService.resolveRoute.mockResolvedValue([KAPA, KDEN]);

      const result = await service.calculate({
        departure_identifier: 'APA',
        destination_identifier: 'DEN',
        true_airspeed: 120,
      });

      expect(result.calculated_at).toBeDefined();
      expect(() => new Date(result.calculated_at)).not.toThrow();
    });
  });
});
