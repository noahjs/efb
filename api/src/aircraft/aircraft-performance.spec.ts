import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { NotFoundException } from '@nestjs/common';
import { AircraftService } from './aircraft.service';
import { Aircraft } from './entities/aircraft.entity';
import { PerformanceProfile } from './entities/performance-profile.entity';
import { FuelTank } from './entities/fuel-tank.entity';
import { Equipment } from './entities/equipment.entity';
import {
  TBM960_TAKEOFF_DATA,
  TBM960_LANDING_DATA,
} from './seed/tbm960-performance';

describe('Aircraft Performance', () => {
  // --- Seed data structure tests ---

  describe('TBM960 Seed Data', () => {
    it('should have correct top-level structure for takeoff data', () => {
      expect(TBM960_TAKEOFF_DATA.version).toBe(1);
      expect(TBM960_TAKEOFF_DATA.source).toContain('TBM 960');
      expect(TBM960_TAKEOFF_DATA.flap_settings).toHaveLength(2);
    });

    it('should have correct top-level structure for landing data', () => {
      expect(TBM960_LANDING_DATA.version).toBe(1);
      expect(TBM960_LANDING_DATA.source).toContain('TBM 960');
      expect(TBM960_LANDING_DATA.flap_settings).toHaveLength(2);
    });

    it('should have TO flap as default takeoff setting', () => {
      const toFlap = TBM960_TAKEOFF_DATA.flap_settings[0];
      expect(toFlap.name).toBe('TO');
      expect(toFlap.code).toBe('to');
      expect(toFlap.is_default).toBe(true);
    });

    it('should have FULL flap as default landing setting', () => {
      const fullFlap = TBM960_LANDING_DATA.flap_settings[0];
      expect(fullFlap.name).toBe('FULL');
      expect(fullFlap.code).toBe('full');
      expect(fullFlap.is_default).toBe(true);
    });

    it('should generate 140 table entries per flap setting (5 altitudes × 4 temps × 7 weights)', () => {
      for (const fs of TBM960_TAKEOFF_DATA.flap_settings) {
        expect(fs.table).toHaveLength(140);
      }
      for (const fs of TBM960_LANDING_DATA.flap_settings) {
        expect(fs.table).toHaveLength(140);
      }
    });

    it('should have valid wind correction factors', () => {
      for (const fs of TBM960_TAKEOFF_DATA.flap_settings) {
        expect(fs.wind_correction.headwind_factor_per_kt).toBe(-0.015);
        expect(fs.wind_correction.tailwind_factor_per_kt).toBe(0.035);
      }
    });

    it('should have all 4 surface factors', () => {
      for (const fs of TBM960_TAKEOFF_DATA.flap_settings) {
        expect(fs.surface_factors.paved_dry).toBe(1.0);
        expect(fs.surface_factors.paved_wet).toBe(1.15);
        expect(fs.surface_factors.grass_dry).toBe(1.2);
        expect(fs.surface_factors.grass_wet).toBe(1.3);
      }
    });

    it('should have correct altitude breakpoints in table', () => {
      const altitudes = new Set(
        TBM960_TAKEOFF_DATA.flap_settings[0].table.map(
          (p) => p.pressure_altitude,
        ),
      );
      expect([...altitudes].sort((a, b) => a - b)).toEqual([
        0, 2000, 4000, 6000, 8000,
      ]);
    });

    it('should have correct temperature breakpoints in table', () => {
      const temps = new Set(
        TBM960_TAKEOFF_DATA.flap_settings[0].table.map((p) => p.temperature_c),
      );
      expect([...temps].sort((a, b) => a - b)).toEqual([-20, 0, 20, 40]);
    });

    it('should have correct weight breakpoints in table', () => {
      const weights = new Set(
        TBM960_TAKEOFF_DATA.flap_settings[0].table.map((p) => p.weight_lbs),
      );
      expect([...weights].sort((a, b) => a - b)).toEqual([
        4500, 5000, 5500, 6000, 6500, 7000, 7615,
      ]);
    });

    it('should have all positive values in every table entry', () => {
      for (const fs of TBM960_TAKEOFF_DATA.flap_settings) {
        for (const pt of fs.table) {
          expect(pt.ground_roll_ft).toBeGreaterThan(0);
          expect(pt.total_distance_ft).toBeGreaterThan(0);
          expect(pt.vr_kias).toBeGreaterThan(0);
          expect(pt.v50_kias).toBeGreaterThan(0);
        }
      }
    });

    it('should have total distance >= ground roll for every entry', () => {
      for (const fs of TBM960_TAKEOFF_DATA.flap_settings) {
        for (const pt of fs.table) {
          expect(pt.total_distance_ft).toBeGreaterThanOrEqual(
            pt.ground_roll_ft,
          );
        }
      }
    });

    it('should produce longer distances at higher altitudes (same temp/weight)', () => {
      const toFlap = TBM960_TAKEOFF_DATA.flap_settings[0];
      const slPt = toFlap.table.find(
        (p) =>
          p.pressure_altitude === 0 &&
          p.temperature_c === 20 &&
          p.weight_lbs === 5000,
      );
      const highPt = toFlap.table.find(
        (p) =>
          p.pressure_altitude === 8000 &&
          p.temperature_c === 20 &&
          p.weight_lbs === 5000,
      );
      expect(highPt!.ground_roll_ft).toBeGreaterThan(slPt!.ground_roll_ft);
      expect(highPt!.total_distance_ft).toBeGreaterThan(
        slPt!.total_distance_ft,
      );
    });

    it('should produce longer distances at higher weights (same alt/temp)', () => {
      const toFlap = TBM960_TAKEOFF_DATA.flap_settings[0];
      const lightPt = toFlap.table.find(
        (p) =>
          p.pressure_altitude === 0 &&
          p.temperature_c === 0 &&
          p.weight_lbs === 4500,
      );
      const heavyPt = toFlap.table.find(
        (p) =>
          p.pressure_altitude === 0 &&
          p.temperature_c === 0 &&
          p.weight_lbs === 7615,
      );
      expect(heavyPt!.ground_roll_ft).toBeGreaterThan(lightPt!.ground_roll_ft);
      expect(heavyPt!.vr_kias).toBeGreaterThan(lightPt!.vr_kias);
    });

    it('should produce higher V-speeds at higher weights', () => {
      const toFlap = TBM960_TAKEOFF_DATA.flap_settings[0];
      const lightPt = toFlap.table.find(
        (p) =>
          p.pressure_altitude === 0 &&
          p.temperature_c === 0 &&
          p.weight_lbs === 4500,
      );
      const heavyPt = toFlap.table.find(
        (p) =>
          p.pressure_altitude === 0 &&
          p.temperature_c === 0 &&
          p.weight_lbs === 7615,
      );
      expect(heavyPt!.vr_kias).toBeGreaterThan(lightPt!.vr_kias);
      expect(heavyPt!.v50_kias).toBeGreaterThan(lightPt!.v50_kias);
    });

    it('should have landing slope correction negative (downhill helps landing)', () => {
      for (const fs of TBM960_LANDING_DATA.flap_settings) {
        expect(fs.slope_correction_per_percent).toBe(-0.05);
      }
    });

    it('should have takeoff slope correction positive (uphill hurts takeoff)', () => {
      for (const fs of TBM960_TAKEOFF_DATA.flap_settings) {
        expect(fs.slope_correction_per_percent).toBe(0.05);
      }
    });
  });

  // --- applyTemplate service method tests ---

  describe('AircraftService.applyTemplate', () => {
    let service: AircraftService;
    let mockProfileRepo: any;

    const mockProfile = {
      id: 1,
      aircraft_id: 1,
      name: 'Test Profile',
      is_default: true,
      takeoff_data: null as string | null,
      landing_data: null as string | null,
    };

    beforeEach(async () => {
      mockProfileRepo = {
        findOne: jest.fn().mockResolvedValue({ ...mockProfile }),
        save: jest
          .fn()
          .mockImplementation((profile) => Promise.resolve({ ...profile })),
      };

      const module: TestingModule = await Test.createTestingModule({
        providers: [
          AircraftService,
          {
            provide: getRepositoryToken(Aircraft),
            useValue: {
              findOne: jest.fn().mockResolvedValue({ id: 1 }),
              findAndCount: jest.fn(),
            },
          },
          {
            provide: getRepositoryToken(PerformanceProfile),
            useValue: mockProfileRepo,
          },
          {
            provide: getRepositoryToken(FuelTank),
            useValue: {},
          },
          {
            provide: getRepositoryToken(Equipment),
            useValue: {},
          },
        ],
      }).compile();

      service = module.get<AircraftService>(AircraftService);
    });

    it('should populate takeoff_data and landing_data for tbm960 template', async () => {
      const result = await service.applyTemplate(1, 1, 'tbm960');

      expect(result.takeoff_data).toBeDefined();
      expect(result.landing_data).toBeDefined();

      const takeoff = JSON.parse(result.takeoff_data);
      const landing = JSON.parse(result.landing_data);

      expect(takeoff.version).toBe(1);
      expect(takeoff.flap_settings).toHaveLength(2);
      expect(landing.version).toBe(1);
      expect(landing.flap_settings).toHaveLength(2);
    });

    it('should save the profile with serialized JSON strings', async () => {
      await service.applyTemplate(1, 1, 'tbm960');

      expect(mockProfileRepo.save).toHaveBeenCalledTimes(1);
      const savedProfile = mockProfileRepo.save.mock.calls[0][0];
      expect(typeof savedProfile.takeoff_data).toBe('string');
      expect(typeof savedProfile.landing_data).toBe('string');

      // Verify it's valid JSON
      expect(() => JSON.parse(savedProfile.takeoff_data)).not.toThrow();
      expect(() => JSON.parse(savedProfile.landing_data)).not.toThrow();
    });

    it('should throw NotFoundException for unknown template type', async () => {
      await expect(service.applyTemplate(1, 1, 'cessna172')).rejects.toThrow(
        NotFoundException,
      );
    });

    it('should throw NotFoundException for non-existent profile', async () => {
      mockProfileRepo.findOne.mockResolvedValue(null);

      await expect(service.applyTemplate(1, 999, 'tbm960')).rejects.toThrow(
        NotFoundException,
      );
    });

    it('should look up profile by both aircraftId and profileId', async () => {
      await service.applyTemplate(5, 10, 'tbm960');

      expect(mockProfileRepo.findOne).toHaveBeenCalledWith({
        where: { id: 10, aircraft_id: 5 },
      });
    });
  });
});
