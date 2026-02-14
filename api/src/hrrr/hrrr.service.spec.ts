import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { HrrrService } from './hrrr.service';
import { HrrrCycle } from '../data-platform/entities/hrrr-cycle.entity';
import { HrrrSurface } from '../data-platform/entities/hrrr-surface.entity';
import { HrrrPressure } from '../data-platform/entities/hrrr-pressure.entity';
import { WindGrid } from '../data-platform/entities/wind-grid.entity';

// --- Mock Data ---

const INIT_TIME = new Date('2026-02-13T12:00:00Z');
const VALID_TIME = new Date('2026-02-13T13:00:00Z');

const mockActiveCycle: Partial<HrrrCycle> = {
  init_time: INIT_TIME,
  status: 'active',
  is_active: true,
  download_total: 6,
  download_completed: 6,
  download_failed: 0,
  download_bytes: 55_000_000,
  download_started_at: new Date('2026-02-13T12:30:00Z'),
  download_completed_at: new Date('2026-02-13T12:35:00Z'),
  process_total: 6,
  process_completed: 6,
  process_failed: 0,
  process_started_at: new Date('2026-02-13T12:35:00Z'),
  process_completed_at: new Date('2026-02-13T12:40:00Z'),
  ingest_surface_rows: 9720,
  ingest_pressure_rows: 87480,
  ingest_completed_at: new Date('2026-02-13T12:42:00Z'),
  tiles_total: 0,
  tiles_completed: 0,
  tiles_failed: 0,
  tiles_count: 0,
  tiles_started_at: null,
  tiles_completed_at: null,
  activated_at: new Date('2026-02-13T12:42:00Z'),
  superseded_at: null,
  total_errors: 0,
  last_error: null,
  total_duration_ms: 720000,
};

const mockSupersededCycle: Partial<HrrrCycle> = {
  ...mockActiveCycle,
  init_time: new Date('2026-02-13T11:00:00Z'),
  status: 'superseded',
  is_active: false,
  superseded_at: new Date('2026-02-13T12:42:00Z'),
};

const mockSurface: Partial<HrrrSurface> = {
  id: 1,
  init_time: INIT_TIME,
  forecast_hour: 1,
  valid_time: VALID_TIME,
  lat: 39,
  lng: -105,
  cloud_total: 85,
  cloud_low: 60,
  cloud_mid: 40,
  cloud_high: 20,
  ceiling_ft: 3500,
  cloud_base_ft: 3200,
  cloud_top_ft: 15000,
  flight_category: 'MVFR',
  visibility_sm: 7.5,
  wind_dir: 270,
  wind_speed_kt: 12,
  wind_gust_kt: 22,
  temperature_c: 5.2,
};

const mockPressure850: Partial<HrrrPressure> = {
  id: 1,
  init_time: INIT_TIME,
  forecast_hour: 1,
  valid_time: VALID_TIME,
  lat: 39,
  lng: -105,
  pressure_level: 850,
  altitude_ft: 5000,
  relative_humidity: 65,
  wind_dir: 280,
  wind_speed_kt: 25,
  temperature_c: 2.1,
};

const mockPressure700: Partial<HrrrPressure> = {
  id: 2,
  init_time: INIT_TIME,
  forecast_hour: 1,
  valid_time: VALID_TIME,
  lat: 39,
  lng: -105,
  pressure_level: 700,
  altitude_ft: 10000,
  relative_humidity: 30,
  wind_dir: 290,
  wind_speed_kt: 40,
  temperature_c: -5.3,
};

const mockPressure500: Partial<HrrrPressure> = {
  id: 3,
  init_time: INIT_TIME,
  forecast_hour: 1,
  valid_time: VALID_TIME,
  lat: 39,
  lng: -105,
  pressure_level: 500,
  altitude_ft: 18000,
  relative_humidity: 5,
  wind_dir: 300,
  wind_speed_kt: 65,
  temperature_c: -22.0,
};

const mockWindGrid: Partial<WindGrid> = {
  lat: 39,
  lng: -105,
  updated_at: new Date('2026-02-13T12:00:00Z'),
  levels: [
    {
      level: 'surface',
      winds: [{ direction: 270, speed: 10, temperature: 8 }],
    },
    {
      level: '850hPa',
      winds: [{ direction: 275, speed: 22, temperature: 3 }],
    },
    {
      level: '700hPa',
      winds: [{ direction: 285, speed: 38, temperature: -6 }],
    },
    {
      level: '500hPa',
      winds: [{ direction: 295, speed: 60, temperature: -21 }],
    },
  ] as any,
};

// --- Helpers for QueryBuilder Mocking ---

function createMockQb(returnValue: any, isMany = false) {
  const qb: any = {
    select: jest.fn().mockReturnThis(),
    where: jest.fn().mockReturnThis(),
    andWhere: jest.fn().mockReturnThis(),
    orderBy: jest.fn().mockReturnThis(),
    setParameters: jest.fn().mockReturnThis(),
    limit: jest.fn().mockReturnThis(),
    getOne: jest.fn().mockResolvedValue(isMany ? undefined : returnValue),
    getMany: jest.fn().mockResolvedValue(isMany ? returnValue : []),
    getRawMany: jest.fn().mockResolvedValue(isMany ? returnValue : []),
  };
  return qb;
}

// --- Tests ---

describe('HrrrService', () => {
  let service: HrrrService;
  let mockCycleRepo: any;
  let mockSurfaceRepo: any;
  let mockPressureRepo: any;
  let mockWindGridRepo: any;

  beforeEach(async () => {
    mockCycleRepo = {
      find: jest.fn(),
      findOne: jest.fn(),
      createQueryBuilder: jest.fn(),
    };

    mockSurfaceRepo = {
      createQueryBuilder: jest.fn(),
    };

    mockPressureRepo = {
      createQueryBuilder: jest.fn(),
    };

    mockWindGridRepo = {
      createQueryBuilder: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        HrrrService,
        { provide: getRepositoryToken(HrrrCycle), useValue: mockCycleRepo },
        {
          provide: getRepositoryToken(HrrrSurface),
          useValue: mockSurfaceRepo,
        },
        {
          provide: getRepositoryToken(HrrrPressure),
          useValue: mockPressureRepo,
        },
        { provide: getRepositoryToken(WindGrid), useValue: mockWindGridRepo },
      ],
    }).compile();

    service = module.get<HrrrService>(HrrrService);
  });

  // --- getCycles ---

  describe('getCycles', () => {
    it('should return cycles with formatted response shape', async () => {
      mockCycleRepo.find.mockResolvedValue([
        mockActiveCycle,
        mockSupersededCycle,
      ]);

      const result = await service.getCycles(10);

      expect(result.active_cycle).toEqual(INIT_TIME);
      expect(result.cycles).toHaveLength(2);
      expect(mockCycleRepo.find).toHaveBeenCalledWith({
        order: { init_time: 'DESC' },
        take: 10,
      });
    });

    it('should structure download/processing/ingest/tiles/timing/errors', async () => {
      mockCycleRepo.find.mockResolvedValue([mockActiveCycle]);

      const result = await service.getCycles();
      const cycle = result.cycles[0];

      expect(cycle.download).toEqual({
        completed: 6,
        failed: 0,
        total: 6,
        bytes: 55_000_000,
      });
      expect(cycle.processing).toEqual({
        completed: 6,
        failed: 0,
        total: 6,
      });
      expect(cycle.ingest).toEqual({
        surface_rows: 9720,
        pressure_rows: 87480,
      });
      expect(cycle.tiles).toEqual({
        completed: 0,
        failed: 0,
        total: 0,
        count: 0,
      });
      expect(cycle.timing.activated_at).toEqual(mockActiveCycle.activated_at);
      expect(cycle.timing.total_duration_ms).toBe(720000);
      expect(cycle.errors).toEqual({ total: 0, last_error: null });
    });

    it('should return null active_cycle when no cycle is active', async () => {
      mockCycleRepo.find.mockResolvedValue([mockSupersededCycle]);

      const result = await service.getCycles();

      expect(result.active_cycle).toBeNull();
    });

    it('should return empty cycles array when none exist', async () => {
      mockCycleRepo.find.mockResolvedValue([]);

      const result = await service.getCycles();

      expect(result.active_cycle).toBeNull();
      expect(result.cycles).toEqual([]);
    });

    it('should respect limit parameter', async () => {
      mockCycleRepo.find.mockResolvedValue([]);

      await service.getCycles(5);

      expect(mockCycleRepo.find).toHaveBeenCalledWith({
        order: { init_time: 'DESC' },
        take: 5,
      });
    });
  });

  // --- getMeta ---

  describe('getMeta', () => {
    it('should return empty products when no active cycle', async () => {
      mockCycleRepo.findOne.mockResolvedValue(null);

      const result = await service.getMeta();

      expect(result).toEqual({
        model: 'hrrr',
        latest_init: null,
        products: {},
      });
    });

    it('should return metadata with forecast hours and products', async () => {
      mockCycleRepo.findOne.mockResolvedValue(mockActiveCycle);

      const mockQb = createMockQb([{ fh: 1 }, { fh: 2 }, { fh: 3 }], true);
      mockSurfaceRepo.createQueryBuilder.mockReturnValue(mockQb);

      const result = await service.getMeta();

      expect(result.model).toBe('hrrr');
      expect(result.latest_init).toEqual(INIT_TIME);
      expect(result.products.clouds.forecast_hours).toEqual([1, 2, 3]);
      expect(result.products.clouds.levels).toContain('low');
      expect(result.products.clouds.levels).toContain('mid');
      expect(result.products.clouds.levels).toContain('high');
      expect(result.products.clouds.levels).toContain('total');
      expect(result.products.clouds.levels).toContain('850');
      expect(result.products['flight-cat'].forecast_hours).toEqual([1, 2, 3]);
      expect(result.level_altitudes).toBeDefined();
      expect(result.level_altitudes[850]).toBe(5000);
    });

    it('should query only for active cycle', async () => {
      mockCycleRepo.findOne.mockResolvedValue(null);

      await service.getMeta();

      expect(mockCycleRepo.findOne).toHaveBeenCalledWith({
        where: { is_active: true },
      });
    });
  });

  // --- getRouteWeather ---

  describe('getRouteWeather', () => {
    it('should return empty waypoints when no active cycle', async () => {
      mockCycleRepo.findOne.mockResolvedValue(null);

      const result = await service.getRouteWeather(
        [{ lat: 39, lng: -105 }],
        8000,
      );

      expect(result).toEqual({
        model: 'hrrr',
        init_time: null,
        waypoints: [],
      });
    });

    it('should return route weather for a single waypoint', async () => {
      mockCycleRepo.findOne.mockResolvedValue(mockActiveCycle);

      const surfaceQb = createMockQb(mockSurface);
      const pressureQb = createMockQb(mockPressure850);
      mockSurfaceRepo.createQueryBuilder.mockReturnValueOnce(surfaceQb);
      mockPressureRepo.createQueryBuilder.mockReturnValueOnce(pressureQb);

      const result = await service.getRouteWeather(
        [{ lat: 39, lng: -105 }],
        5000,
      );

      expect(result.model).toBe('hrrr');
      expect(result.init_time).toEqual(INIT_TIME);
      expect(result.altitude_ft).toBe(5000);
      expect(result.pressure_level).toBe(850);
      expect(result.waypoints).toHaveLength(1);

      const wp = result.waypoints[0];
      expect(wp.lat).toBe(39);
      expect(wp.lng).toBe(-105);
      expect(wp.forecast_hour).toBe(1);
      expect(wp.clouds.at_altitude_rh).toBe(65);
      expect(wp.clouds.at_altitude_coverage).toBe('FEW');
      expect(wp.clouds.total).toBe(85);
      expect(wp.clouds.flight_category).toBe('MVFR');
      expect(wp.wind.direction).toBe(280);
      expect(wp.wind.speed_kt).toBe(25);
      expect(wp.surface.wind_gust_kt).toBe(22);
    });

    it('should handle multiple waypoints', async () => {
      mockCycleRepo.findOne.mockResolvedValue(mockActiveCycle);

      const surface2: Partial<HrrrSurface> = {
        ...mockSurface,
        lat: 38,
        lng: -104,
        cloud_total: 10,
        flight_category: 'VFR',
      };

      // First waypoint
      mockSurfaceRepo.createQueryBuilder
        .mockReturnValueOnce(createMockQb(mockSurface))
        .mockReturnValueOnce(createMockQb(surface2));
      mockPressureRepo.createQueryBuilder
        .mockReturnValueOnce(createMockQb(mockPressure850))
        .mockReturnValueOnce(createMockQb(mockPressure850));

      const result = await service.getRouteWeather(
        [
          { lat: 39, lng: -105 },
          { lat: 38, lng: -104 },
        ],
        5000,
      );

      expect(result.waypoints).toHaveLength(2);
      expect(result.waypoints[0].clouds.total).toBe(85);
      expect(result.waypoints[1].clouds.total).toBe(10);
    });

    it('should handle null surface and pressure data gracefully', async () => {
      mockCycleRepo.findOne.mockResolvedValue(mockActiveCycle);

      mockSurfaceRepo.createQueryBuilder.mockReturnValue(createMockQb(null));
      mockPressureRepo.createQueryBuilder.mockReturnValue(createMockQb(null));

      const result = await service.getRouteWeather(
        [{ lat: 39, lng: -105 }],
        5000,
      );

      const wp = result.waypoints[0];
      expect(wp.forecast_hour).toBeNull();
      expect(wp.valid_time).toBeNull();
      expect(wp.clouds.at_altitude_rh).toBeNull();
      expect(wp.clouds.at_altitude_coverage).toBe('N/A');
      expect(wp.clouds.total).toBeNull();
      expect(wp.wind.direction).toBeNull();
      expect(wp.surface.wind_dir).toBeNull();
    });

    it('should map altitude to correct pressure level', async () => {
      mockCycleRepo.findOne.mockResolvedValue(mockActiveCycle);
      mockSurfaceRepo.createQueryBuilder.mockReturnValue(
        createMockQb(mockSurface),
      );
      mockPressureRepo.createQueryBuilder.mockReturnValue(
        createMockQb(mockPressure700),
      );

      // 8000ft → nearest is 800hPa (6200ft), not 700hPa (10000ft)
      const result = await service.getRouteWeather(
        [{ lat: 39, lng: -105 }],
        8000,
      );

      expect(result.pressure_level).toBe(800);

      // Verify the query builder was called with 800
      const qb = mockPressureRepo.createQueryBuilder.mock.results[0].value;
      expect(qb.andWhere).toHaveBeenCalledWith('p.pressure_level = :level', {
        level: 800,
      });
    });

    it('should map high altitude to correct pressure level', async () => {
      mockCycleRepo.findOne.mockResolvedValue(mockActiveCycle);
      mockSurfaceRepo.createQueryBuilder.mockReturnValue(
        createMockQb(mockSurface),
      );
      mockPressureRepo.createQueryBuilder.mockReturnValue(
        createMockQb(mockPressure500),
      );

      // 17000ft → nearest is 500hPa (18000ft)
      const result = await service.getRouteWeather(
        [{ lat: 39, lng: -105 }],
        17000,
      );

      expect(result.pressure_level).toBe(500);
    });

    it('should map low altitude to 1000hPa', async () => {
      mockCycleRepo.findOne.mockResolvedValue(mockActiveCycle);
      mockSurfaceRepo.createQueryBuilder.mockReturnValue(
        createMockQb(mockSurface),
      );
      mockPressureRepo.createQueryBuilder.mockReturnValue(createMockQb(null));

      const result = await service.getRouteWeather(
        [{ lat: 39, lng: -105 }],
        500,
      );

      expect(result.pressure_level).toBe(1000);
    });
  });

  // --- getRouteProfile ---

  describe('getRouteProfile', () => {
    it('should return empty waypoints when no active cycle', async () => {
      mockCycleRepo.findOne.mockResolvedValue(null);

      const result = await service.getRouteProfile([{ lat: 39, lng: -105 }]);

      expect(result).toEqual({
        model: 'hrrr',
        init_time: null,
        waypoints: [],
      });
    });

    it('should return full profile with all pressure levels', async () => {
      mockCycleRepo.findOne.mockResolvedValue(mockActiveCycle);

      const surfaceQb = createMockQb(mockSurface);
      mockSurfaceRepo.createQueryBuilder.mockReturnValue(surfaceQb);

      const pressureLevels = [
        mockPressure850,
        mockPressure700,
        mockPressure500,
      ];
      const pressureQb = createMockQb(pressureLevels, true);
      mockPressureRepo.createQueryBuilder.mockReturnValue(pressureQb);

      const result = await service.getRouteProfile([{ lat: 39, lng: -105 }]);

      expect(result.model).toBe('hrrr');
      expect(result.init_time).toEqual(INIT_TIME);
      expect(result.waypoints).toHaveLength(1);

      const wp = result.waypoints[0];
      expect(wp.ceiling_ft).toBe(3500);
      expect(wp.visibility_sm).toBe(7.5);
      expect(wp.flight_category).toBe('MVFR');
      expect(wp.levels).toHaveLength(3);

      expect(wp.levels[0].pressure).toBe(850);
      expect(wp.levels[0].altitude_ft).toBe(5000);
      expect(wp.levels[0].relative_humidity).toBe(65);
      expect(wp.levels[0].wind_dir).toBe(280);
      expect(wp.levels[0].wind_speed_kt).toBe(25);
      expect(wp.levels[0].temp_c).toBe(2.1);

      expect(wp.levels[1].pressure).toBe(700);
      expect(wp.levels[2].pressure).toBe(500);
    });

    it('should skip waypoints with no surface data', async () => {
      mockCycleRepo.findOne.mockResolvedValue(mockActiveCycle);

      // First waypoint: has surface data
      // Second waypoint: no surface data
      mockSurfaceRepo.createQueryBuilder
        .mockReturnValueOnce(createMockQb(mockSurface))
        .mockReturnValueOnce(createMockQb(null));

      const pressureQb = createMockQb([mockPressure850], true);
      mockPressureRepo.createQueryBuilder.mockReturnValue(pressureQb);

      const result = await service.getRouteProfile([
        { lat: 39, lng: -105 },
        { lat: 50, lng: -130 }, // outside CONUS, no data
      ]);

      expect(result.waypoints).toHaveLength(1);
      expect(result.waypoints[0].lat).toBe(39);
    });

    it('should use surface lat/lng for pressure level query', async () => {
      mockCycleRepo.findOne.mockResolvedValue(mockActiveCycle);

      const surfaceQb = createMockQb(mockSurface);
      mockSurfaceRepo.createQueryBuilder.mockReturnValue(surfaceQb);

      const pressureQb = createMockQb([], true);
      mockPressureRepo.createQueryBuilder.mockReturnValue(pressureQb);

      await service.getRouteProfile([{ lat: 39.5, lng: -104.8 }]);

      // Pressure query should use the surface's snapped lat/lng
      expect(pressureQb.andWhere).toHaveBeenCalledWith(
        'p.lat = :lat AND p.lng = :lng',
        { lat: mockSurface.lat, lng: mockSurface.lng },
      );
    });
  });

  // --- compareWinds ---

  describe('compareWinds', () => {
    it('should return both HRRR and Open-Meteo data', async () => {
      mockCycleRepo.findOne.mockResolvedValue(mockActiveCycle);

      const pressureQb = createMockQb(
        [mockPressure850, mockPressure700, mockPressure500],
        true,
      );
      mockPressureRepo.createQueryBuilder.mockReturnValue(pressureQb);

      const windGridQb = createMockQb(mockWindGrid);
      mockWindGridRepo.createQueryBuilder.mockReturnValue(windGridQb);

      const result = await service.compareWinds(39, -105);

      expect(result.lat).toBe(39);
      expect(result.lng).toBe(-105);

      // HRRR data
      expect(result.hrrr).not.toBeNull();
      expect(result.hrrr.init_time).toEqual(INIT_TIME);
      expect(result.hrrr.levels['850']).toEqual({
        dir: 280,
        speed: 25,
        temp: 2.1,
      });
      expect(result.hrrr.levels['700']).toEqual({
        dir: 290,
        speed: 40,
        temp: -5.3,
      });
      expect(result.hrrr.levels['500']).toEqual({
        dir: 300,
        speed: 65,
        temp: -22.0,
      });

      // Open-Meteo data
      expect(result.open_meteo).not.toBeNull();
      expect(result.open_meteo.levels['850']).toEqual({
        dir: 275,
        speed: 22,
        temp: 3,
      });
      expect(result.open_meteo.levels['700']).toEqual({
        dir: 285,
        speed: 38,
        temp: -6,
      });
    });

    it('should return null HRRR data when no active cycle', async () => {
      mockCycleRepo.findOne.mockResolvedValue(null);

      const windGridQb = createMockQb(mockWindGrid);
      mockWindGridRepo.createQueryBuilder.mockReturnValue(windGridQb);

      const result = await service.compareWinds(39, -105);

      expect(result.hrrr).toBeNull();
      expect(result.open_meteo).not.toBeNull();
    });

    it('should return null Open-Meteo data when no wind grid', async () => {
      mockCycleRepo.findOne.mockResolvedValue(mockActiveCycle);

      const pressureQb = createMockQb([mockPressure850], true);
      mockPressureRepo.createQueryBuilder.mockReturnValue(pressureQb);

      const windGridQb = createMockQb(null);
      mockWindGridRepo.createQueryBuilder.mockReturnValue(windGridQb);

      const result = await service.compareWinds(39, -105);

      expect(result.hrrr).not.toBeNull();
      expect(result.open_meteo).toBeNull();
    });

    it('should skip surface level in Open-Meteo data', async () => {
      mockCycleRepo.findOne.mockResolvedValue(null);

      const windGridQb = createMockQb(mockWindGrid);
      mockWindGridRepo.createQueryBuilder.mockReturnValue(windGridQb);

      const result = await service.compareWinds(39, -105);

      expect(result.open_meteo.levels).not.toHaveProperty('surface');
    });

    it('should return both null when no data at all', async () => {
      mockCycleRepo.findOne.mockResolvedValue(null);

      const windGridQb = createMockQb(null);
      mockWindGridRepo.createQueryBuilder.mockReturnValue(windGridQb);

      const result = await service.compareWinds(39, -105);

      expect(result.hrrr).toBeNull();
      expect(result.open_meteo).toBeNull();
    });
  });

  // --- rhToCloudCategory (tested via getRouteWeather) ---

  describe('RH to cloud categorization', () => {
    beforeEach(() => {
      mockCycleRepo.findOne.mockResolvedValue(mockActiveCycle);
      mockSurfaceRepo.createQueryBuilder.mockReturnValue(
        createMockQb(mockSurface),
      );
    });

    const testCategory = async (rh: number | null) => {
      const pressure = { ...mockPressure850, relative_humidity: rh };
      mockPressureRepo.createQueryBuilder.mockReturnValue(
        createMockQb(pressure),
      );

      const result = await service.getRouteWeather(
        [{ lat: 39, lng: -105 }],
        5000,
      );
      return result.waypoints[0].clouds.at_altitude_coverage;
    };

    it('should return CLR for 0% RH', async () => {
      expect(await testCategory(0)).toBe('CLR');
    });

    it('should return CLR for 49% RH', async () => {
      expect(await testCategory(49)).toBe('CLR');
    });

    it('should return FEW for 50% RH', async () => {
      expect(await testCategory(50)).toBe('FEW');
    });

    it('should return FEW for 69% RH', async () => {
      expect(await testCategory(69)).toBe('FEW');
    });

    it('should return SCT for 70% RH', async () => {
      expect(await testCategory(70)).toBe('SCT');
    });

    it('should return SCT for 79% RH', async () => {
      expect(await testCategory(79)).toBe('SCT');
    });

    it('should return BKN for 80% RH', async () => {
      expect(await testCategory(80)).toBe('BKN');
    });

    it('should return BKN for 89% RH', async () => {
      expect(await testCategory(89)).toBe('BKN');
    });

    it('should return OVC for 90% RH', async () => {
      expect(await testCategory(90)).toBe('OVC');
    });

    it('should return OVC for 100% RH', async () => {
      expect(await testCategory(100)).toBe('OVC');
    });

    it('should return N/A for null', async () => {
      expect(await testCategory(null)).toBe('N/A');
    });
  });

  // --- altitudeToPressureLevel (tested via getRouteWeather) ---

  describe('altitude to pressure level mapping', () => {
    beforeEach(() => {
      mockCycleRepo.findOne.mockResolvedValue(mockActiveCycle);
      mockSurfaceRepo.createQueryBuilder.mockReturnValue(
        createMockQb(mockSurface),
      );
      mockPressureRepo.createQueryBuilder.mockReturnValue(createMockQb(null));
    });

    const testMapping = async (altFt: number) => {
      const result = await service.getRouteWeather(
        [{ lat: 39, lng: -105 }],
        altFt,
      );
      return result.pressure_level;
    };

    it('should map 300ft to 1000hPa (360ft)', async () => {
      expect(await testMapping(300)).toBe(1000);
    });

    it('should map 2500ft to 925hPa (2500ft)', async () => {
      expect(await testMapping(2500)).toBe(925);
    });

    it('should map 4000ft to 900hPa (3200ft)', async () => {
      expect(await testMapping(4000)).toBe(900);
    });

    it('should map 7500ft to 800hPa (6200ft)', async () => {
      // 7500 is 1300 from 800(6200) and 2500 from 700(10000)
      expect(await testMapping(7500)).toBe(800);
    });

    it('should map 10000ft to 700hPa (10000ft)', async () => {
      expect(await testMapping(10000)).toBe(700);
    });

    it('should map 18000ft to 500hPa (18000ft)', async () => {
      expect(await testMapping(18000)).toBe(500);
    });

    it('should map 24000ft to 400hPa (24000ft)', async () => {
      expect(await testMapping(24000)).toBe(400);
    });

    it('should map 30000ft to 300hPa (30000ft)', async () => {
      expect(await testMapping(30000)).toBe(300);
    });

    it('should map 39000ft to 200hPa (39000ft)', async () => {
      expect(await testMapping(39000)).toBe(200);
    });

    it('should map 45000ft to 150hPa (44000ft)', async () => {
      expect(await testMapping(45000)).toBe(150);
    });
  });
});
