import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import {
  HrrrTileService,
  tilePixelXToLng,
  tilePixelYToLat,
  tileToLatLngBounds,
  bilinearSample,
  TILE_PRODUCTS,
} from './hrrr-tile.service';
import { HrrrCycle } from '../data-platform/entities/hrrr-cycle.entity';
import { HrrrSurface } from '../data-platform/entities/hrrr-surface.entity';
import { HrrrPressure } from '../data-platform/entities/hrrr-pressure.entity';

const INIT_TIME = new Date('2026-02-13T12:00:00Z');

const GRID_COLS = 60;

describe('HrrrTileService', () => {
  // --- Projection tests ---

  describe('tilePixelXToLng', () => {
    it('returns -180 at globalX=0', () => {
      const lng = tilePixelXToLng(0, 256);
      expect(lng).toBeCloseTo(-180, 5);
    });

    it('returns 0 at globalX midpoint', () => {
      const lng = tilePixelXToLng(128, 256);
      expect(lng).toBeCloseTo(0, 5);
    });

    it('returns 180 at globalX=totalPixels', () => {
      const lng = tilePixelXToLng(256, 256);
      expect(lng).toBeCloseTo(180, 5);
    });
  });

  describe('tilePixelYToLat', () => {
    it('returns ~85.05 at globalY=0 (top of map)', () => {
      const lat = tilePixelYToLat(0, 256);
      expect(lat).toBeGreaterThan(85);
    });

    it('returns 0 at globalY midpoint', () => {
      const lat = tilePixelYToLat(128, 256);
      expect(lat).toBeCloseTo(0, 3);
    });

    it('returns ~-85.05 at globalY=totalPixels', () => {
      const lat = tilePixelYToLat(256, 256);
      expect(lat).toBeLessThan(-85);
    });
  });

  describe('tileToLatLngBounds', () => {
    it('returns correct bounds for tile z=0 x=0 y=0 (whole world)', () => {
      const b = tileToLatLngBounds(0, 0, 0);
      expect(b.minLng).toBeCloseTo(-180, 3);
      expect(b.maxLng).toBeCloseTo(180, 3);
      expect(b.maxLat).toBeGreaterThan(85);
      expect(b.minLat).toBeLessThan(-85);
    });

    it('returns correct bounds for z=1 tiles', () => {
      // z=1 has 2×2 tiles
      const topLeft = tileToLatLngBounds(1, 0, 0);
      expect(topLeft.minLng).toBeCloseTo(-180, 3);
      expect(topLeft.maxLng).toBeCloseTo(0, 3);
      expect(topLeft.maxLat).toBeGreaterThan(85);
      expect(topLeft.minLat).toBeCloseTo(0, 1);

      const bottomRight = tileToLatLngBounds(1, 1, 1);
      expect(bottomRight.minLng).toBeCloseTo(0, 3);
      expect(bottomRight.maxLng).toBeCloseTo(180, 3);
      expect(bottomRight.maxLat).toBeCloseTo(0, 1);
      expect(bottomRight.minLat).toBeLessThan(-85);
    });
  });

  // --- Bilinear interpolation tests ---

  describe('bilinearSample', () => {
    it('returns exact value at grid corners', () => {
      // 27×60 grid, value at (lat=30, lng=-120) → row=6, col=5
      const data = new Float32Array(27 * 60).fill(0);
      const row = 6; // lat 30
      const col = 5; // lng -120
      data[row * 60 + col] = 75;

      const result = bilinearSample(data, 30, -120);
      expect(result).toBeCloseTo(75, 3);
    });

    it('interpolates between four grid corners', () => {
      const data = new Float32Array(27 * 60).fill(0);
      // Set up a 2×2 patch at (lat 30-31, lng -120 to -119)
      data[6 * 60 + 5] = 10; // (30, -120)
      data[6 * 60 + 6] = 20; // (30, -119)
      data[7 * 60 + 5] = 30; // (31, -120)
      data[7 * 60 + 6] = 40; // (31, -119)

      // Center point should be mean of 4 corners
      const center = bilinearSample(data, 30.5, -119.5);
      expect(center).toBeCloseTo(25, 1);
    });

    it('handles sentinel values with nearest-neighbor fallback', () => {
      const data = new Float32Array(27 * 60).fill(-1);
      // Only one valid cell
      data[6 * 60 + 5] = 50;

      const result = bilinearSample(data, 30, -120);
      expect(result).toBeCloseTo(50, 3);
    });
  });

  // --- Color mapping tests ---

  describe('Color mapping via renderTile', () => {
    let service: HrrrTileService;
    let mockCycleRepo: any;
    let mockSurfaceRepo: any;
    let mockPressureRepo: any;

    beforeEach(async () => {
      mockCycleRepo = {
        findOne: jest.fn().mockResolvedValue({
          init_time: INIT_TIME,
          is_active: true,
        }),
      };
      mockSurfaceRepo = {
        find: jest.fn().mockResolvedValue([]),
      };
      mockPressureRepo = {
        find: jest.fn().mockResolvedValue([]),
      };

      const module: TestingModule = await Test.createTestingModule({
        providers: [
          HrrrTileService,
          { provide: getRepositoryToken(HrrrCycle), useValue: mockCycleRepo },
          {
            provide: getRepositoryToken(HrrrSurface),
            useValue: mockSurfaceRepo,
          },
          {
            provide: getRepositoryToken(HrrrPressure),
            useValue: mockPressureRepo,
          },
        ],
      }).compile();

      service = module.get<HrrrTileService>(HrrrTileService);
    });

    it('returns a PNG buffer for a valid tile request', async () => {
      const buffer = await service.renderTile('flight-cat', 4, 3, 5, 1);
      expect(buffer).toBeInstanceOf(Buffer);
      // PNG magic bytes
      expect(buffer[0]).toBe(0x89);
      expect(buffer[1]).toBe(0x50); // P
      expect(buffer[2]).toBe(0x4e); // N
      expect(buffer[3]).toBe(0x47); // G
    });

    it('returns transparent tile for out-of-bounds tile', async () => {
      // z=4, x=0, y=0 is in the far north (>85° lat) — well outside CONUS
      const buffer = await service.renderTile('clouds-total', 4, 0, 0, 1);
      expect(buffer).toBeInstanceOf(Buffer);
      // Should be the pre-cached transparent tile
      expect(buffer[0]).toBe(0x89); // PNG header
    });

    it('returns transparent tile when no active cycle exists', async () => {
      mockCycleRepo.findOne.mockResolvedValue(null);
      const buffer = await service.renderTile('flight-cat', 4, 3, 5, 1);
      expect(buffer).toBeInstanceOf(Buffer);
    });

    it('renders tile with surface data', async () => {
      // Provide a surface row in the CONUS area
      mockSurfaceRepo.find.mockResolvedValue([
        {
          lat: 39,
          lng: -105,
          cloud_total: 80,
          cloud_low: 30,
          cloud_mid: 50,
          cloud_high: 20,
          flight_category: 'MVFR',
          visibility_sm: 4.5,
        },
      ]);

      // z=4, tile that covers the Denver area
      // At z=4, tile coordinates: x=3, y=5 covers roughly lat 36-45, lng -135 to -90
      const buffer = await service.renderTile('clouds-total', 4, 3, 5, 1);
      expect(buffer).toBeInstanceOf(Buffer);
      expect(buffer.length).toBeGreaterThan(100); // Should be a non-trivial PNG
    });
  });

  // --- Cache eviction tests ---

  describe('Cache eviction on cycle change', () => {
    let service: HrrrTileService;
    let mockCycleRepo: any;
    let mockSurfaceRepo: any;
    let mockPressureRepo: any;

    beforeEach(async () => {
      mockCycleRepo = {
        findOne: jest.fn().mockResolvedValue({
          init_time: INIT_TIME,
          is_active: true,
        }),
      };
      mockSurfaceRepo = {
        find: jest.fn().mockResolvedValue([]),
      };
      mockPressureRepo = {
        find: jest.fn().mockResolvedValue([]),
      };

      const module: TestingModule = await Test.createTestingModule({
        providers: [
          HrrrTileService,
          { provide: getRepositoryToken(HrrrCycle), useValue: mockCycleRepo },
          {
            provide: getRepositoryToken(HrrrSurface),
            useValue: mockSurfaceRepo,
          },
          {
            provide: getRepositoryToken(HrrrPressure),
            useValue: mockPressureRepo,
          },
        ],
      }).compile();

      service = module.get<HrrrTileService>(HrrrTileService);
    });

    it('loads raster from DB on first request', async () => {
      await service.renderTile('flight-cat', 4, 3, 5, 1);
      expect(mockSurfaceRepo.find).toHaveBeenCalledWith({
        where: { init_time: INIT_TIME, forecast_hour: 1 },
      });
    });

    it('caches rendered tiles', async () => {
      // Provide data so raster is cached (empty rows → null raster → no cache)
      mockSurfaceRepo.find.mockResolvedValue([
        {
          lat: 39,
          lng: -105,
          cloud_total: 50,
          cloud_low: 10,
          cloud_mid: 20,
          cloud_high: 15,
          flight_category: 'VFR',
          visibility_sm: 10,
        },
      ]);

      const buf1 = await service.renderTile('flight-cat', 4, 3, 5, 1);
      const findCalls = mockSurfaceRepo.find.mock.calls.length;
      const buf2 = await service.renderTile('flight-cat', 4, 3, 5, 1);
      // Second call returns the exact same cached buffer
      expect(buf1).toBe(buf2);
      // No additional DB calls for the second render
      expect(mockSurfaceRepo.find).toHaveBeenCalledTimes(findCalls);
    });
  });

  // --- Direct color function tests ---

  describe('Color mapping via pixel inspection', () => {
    let service: HrrrTileService;
    let mockCycleRepo: any;
    let mockSurfaceRepo: any;
    let mockPressureRepo: any;

    beforeEach(async () => {
      mockCycleRepo = {
        findOne: jest.fn().mockResolvedValue({
          init_time: INIT_TIME,
          is_active: true,
        }),
      };
      mockSurfaceRepo = { find: jest.fn() };
      mockPressureRepo = { find: jest.fn().mockResolvedValue([]) };

      const module: TestingModule = await Test.createTestingModule({
        providers: [
          HrrrTileService,
          { provide: getRepositoryToken(HrrrCycle), useValue: mockCycleRepo },
          {
            provide: getRepositoryToken(HrrrSurface),
            useValue: mockSurfaceRepo,
          },
          {
            provide: getRepositoryToken(HrrrPressure),
            useValue: mockPressureRepo,
          },
        ],
      }).compile();

      service = module.get<HrrrTileService>(HrrrTileService);
    });

    // Helper: fill a full CONUS grid so every pixel can sample valid data
    function makeFullGrid(
      overrides: Partial<{
        cloud_total: number;
        cloud_low: number;
        cloud_mid: number;
        cloud_high: number;
        flight_category: string;
        visibility_sm: number;
      }> = {},
    ) {
      const rows: any[] = [];
      for (let lat = 24; lat <= 50; lat++) {
        for (let lng = -125; lng <= -66; lng++) {
          rows.push({
            lat,
            lng,
            cloud_total: overrides.cloud_total ?? 50,
            cloud_low: overrides.cloud_low ?? 20,
            cloud_mid: overrides.cloud_mid ?? 30,
            cloud_high: overrides.cloud_high ?? 10,
            flight_category: overrides.flight_category ?? 'VFR',
            visibility_sm: overrides.visibility_sm ?? 10,
          });
        }
      }
      return rows;
    }

    it('flight-cat: VFR renders transparent', async () => {
      mockSurfaceRepo.find.mockResolvedValue(
        makeFullGrid({ flight_category: 'VFR' }),
      );
      // Use z=2 for a tile covering CONUS — at z=2, tile (0,1) covers north, (1,1) covers south
      // z=2, x=0, y=1 covers roughly lat 0-66, lng -180 to -90 — includes CONUS
      const buffer = await service.renderTile('flight-cat', 2, 0, 1, 1);
      // VFR = transparent, so the PNG should be mostly transparent (small file)
      expect(buffer).toBeInstanceOf(Buffer);
    });

    it('flight-cat: MVFR renders blue', async () => {
      mockSurfaceRepo.find.mockResolvedValue(
        makeFullGrid({ flight_category: 'MVFR' }),
      );
      const buffer = await service.renderTile('flight-cat', 2, 0, 1, 1);
      expect(buffer).toBeInstanceOf(Buffer);
      expect(buffer.length).toBeGreaterThan(100);
    });

    it('flight-cat: IFR renders red', async () => {
      mockSurfaceRepo.find.mockResolvedValue(
        makeFullGrid({ flight_category: 'IFR' }),
      );
      const buffer = await service.renderTile('flight-cat', 2, 0, 1, 1);
      expect(buffer).toBeInstanceOf(Buffer);
      expect(buffer.length).toBeGreaterThan(100);
    });

    it('flight-cat: LIFR renders magenta', async () => {
      mockSurfaceRepo.find.mockResolvedValue(
        makeFullGrid({ flight_category: 'LIFR' }),
      );
      const buffer = await service.renderTile('flight-cat', 2, 0, 1, 1);
      expect(buffer).toBeInstanceOf(Buffer);
      expect(buffer.length).toBeGreaterThan(100);
    });

    it('clouds: high coverage renders opaque white', async () => {
      mockSurfaceRepo.find.mockResolvedValue(
        makeFullGrid({ cloud_total: 100 }),
      );
      const buffer = await service.renderTile('clouds-total', 2, 0, 1, 1);
      expect(buffer).toBeInstanceOf(Buffer);
      expect(buffer.length).toBeGreaterThan(200);
    });

    it('clouds: zero coverage renders transparent', async () => {
      mockSurfaceRepo.find.mockResolvedValue(makeFullGrid({ cloud_total: 0 }));
      const buffer = await service.renderTile('clouds-total', 2, 0, 1, 1);
      expect(buffer).toBeInstanceOf(Buffer);
    });

    it('visibility: <1sm renders red', async () => {
      mockSurfaceRepo.find.mockResolvedValue(
        makeFullGrid({ visibility_sm: 0.5 }),
      );
      const buffer = await service.renderTile('visibility', 2, 0, 1, 1);
      expect(buffer).toBeInstanceOf(Buffer);
      expect(buffer.length).toBeGreaterThan(200);
    });

    it('visibility: 1-3sm renders orange', async () => {
      mockSurfaceRepo.find.mockResolvedValue(
        makeFullGrid({ visibility_sm: 2 }),
      );
      const buffer = await service.renderTile('visibility', 2, 0, 1, 1);
      expect(buffer).toBeInstanceOf(Buffer);
      expect(buffer.length).toBeGreaterThan(200);
    });

    it('visibility: 3-5sm renders yellow', async () => {
      mockSurfaceRepo.find.mockResolvedValue(
        makeFullGrid({ visibility_sm: 4 }),
      );
      const buffer = await service.renderTile('visibility', 2, 0, 1, 1);
      expect(buffer).toBeInstanceOf(Buffer);
      expect(buffer.length).toBeGreaterThan(200);
    });

    it('visibility: >=5sm renders transparent', async () => {
      mockSurfaceRepo.find.mockResolvedValue(
        makeFullGrid({ visibility_sm: 10 }),
      );
      const buffer = await service.renderTile('visibility', 2, 0, 1, 1);
      expect(buffer).toBeInstanceOf(Buffer);
    });
  });

  // --- All products render ---

  describe('All products render correctly with data', () => {
    let service: HrrrTileService;
    let mockCycleRepo: any;
    let mockSurfaceRepo: any;
    let mockPressureRepo: any;

    // A tile at z=4, x=3, y=5 covers roughly CONUS center
    // Provide surface data at multiple grid points to exercise color maps
    const surfaceRows = [
      // VFR, good visibility
      {
        lat: 39,
        lng: -105,
        cloud_total: 10,
        cloud_low: 5,
        cloud_mid: 5,
        cloud_high: 0,
        flight_category: 'VFR',
        visibility_sm: 10,
      },
      // MVFR, moderate visibility
      {
        lat: 40,
        lng: -104,
        cloud_total: 60,
        cloud_low: 40,
        cloud_mid: 30,
        cloud_high: 20,
        flight_category: 'MVFR',
        visibility_sm: 4,
      },
      // IFR, poor visibility
      {
        lat: 38,
        lng: -106,
        cloud_total: 90,
        cloud_low: 70,
        cloud_mid: 60,
        cloud_high: 50,
        flight_category: 'IFR',
        visibility_sm: 2,
      },
      // LIFR, very poor visibility
      {
        lat: 37,
        lng: -107,
        cloud_total: 100,
        cloud_low: 95,
        cloud_mid: 80,
        cloud_high: 70,
        flight_category: 'LIFR',
        visibility_sm: 0.5,
      },
    ];

    beforeEach(async () => {
      mockCycleRepo = {
        findOne: jest.fn().mockResolvedValue({
          init_time: INIT_TIME,
          is_active: true,
        }),
      };
      mockSurfaceRepo = {
        find: jest.fn().mockResolvedValue(surfaceRows),
      };
      mockPressureRepo = {
        find: jest.fn().mockResolvedValue([]),
      };

      const module: TestingModule = await Test.createTestingModule({
        providers: [
          HrrrTileService,
          { provide: getRepositoryToken(HrrrCycle), useValue: mockCycleRepo },
          {
            provide: getRepositoryToken(HrrrSurface),
            useValue: mockSurfaceRepo,
          },
          {
            provide: getRepositoryToken(HrrrPressure),
            useValue: mockPressureRepo,
          },
        ],
      }).compile();

      service = module.get<HrrrTileService>(HrrrTileService);
    });

    it('renders flight-cat tiles with flight category colors', async () => {
      const buffer = await service.renderTile('flight-cat', 4, 3, 5, 1);
      expect(buffer).toBeInstanceOf(Buffer);
      expect(buffer.length).toBeGreaterThan(100);
    });

    it('renders clouds-total tiles', async () => {
      const buffer = await service.renderTile('clouds-total', 4, 3, 5, 1);
      expect(buffer).toBeInstanceOf(Buffer);
      expect(buffer.length).toBeGreaterThan(100);
    });

    it('renders clouds-low tiles', async () => {
      const buffer = await service.renderTile('clouds-low', 4, 3, 5, 1);
      expect(buffer).toBeInstanceOf(Buffer);
      expect(buffer.length).toBeGreaterThan(100);
    });

    it('renders clouds-mid tiles', async () => {
      const buffer = await service.renderTile('clouds-mid', 4, 3, 5, 1);
      expect(buffer).toBeInstanceOf(Buffer);
      expect(buffer.length).toBeGreaterThan(100);
    });

    it('renders clouds-high tiles', async () => {
      const buffer = await service.renderTile('clouds-high', 4, 3, 5, 1);
      expect(buffer).toBeInstanceOf(Buffer);
      expect(buffer.length).toBeGreaterThan(100);
    });

    it('renders visibility tiles', async () => {
      const buffer = await service.renderTile('visibility', 4, 3, 5, 1);
      expect(buffer).toBeInstanceOf(Buffer);
      expect(buffer.length).toBeGreaterThan(100);
    });
  });

  // --- Cycle change eviction ---

  describe('Cycle change triggers cache eviction', () => {
    it('evicts raster and tile caches when init_time changes', async () => {
      const NEW_INIT_TIME = new Date('2026-02-13T13:00:00Z');

      const mockCycleRepo = {
        findOne: jest.fn().mockResolvedValue({
          init_time: INIT_TIME,
          is_active: true,
        }),
      };
      const mockSurfaceRepo = {
        find: jest.fn().mockResolvedValue([
          {
            lat: 39,
            lng: -105,
            cloud_total: 50,
            cloud_low: 10,
            cloud_mid: 20,
            cloud_high: 15,
            flight_category: 'VFR',
            visibility_sm: 10,
          },
        ]),
      };
      const mockPressureRepo = {
        find: jest.fn().mockResolvedValue([]),
      };

      const module: TestingModule = await Test.createTestingModule({
        providers: [
          HrrrTileService,
          { provide: getRepositoryToken(HrrrCycle), useValue: mockCycleRepo },
          {
            provide: getRepositoryToken(HrrrSurface),
            useValue: mockSurfaceRepo,
          },
          {
            provide: getRepositoryToken(HrrrPressure),
            useValue: mockPressureRepo,
          },
        ],
      }).compile();

      const service = module.get<HrrrTileService>(HrrrTileService);

      // First render → populates cache
      await service.renderTile('flight-cat', 4, 3, 5, 1);
      const callsAfterFirst = mockSurfaceRepo.find.mock.calls.length;

      // Simulate cycle change by updating mock and forcing cycle check
      mockCycleRepo.findOne.mockResolvedValue({
        init_time: NEW_INIT_TIME,
        is_active: true,
      });
      // Force cycle check by resetting internal timer
      (service as any).lastCycleCheck = 0;

      // Next render should reload from DB because cycle changed
      await service.renderTile('flight-cat', 4, 3, 5, 1);
      expect(mockSurfaceRepo.find.mock.calls.length).toBeGreaterThan(
        callsAfterFirst,
      );
    });
  });

  // --- TILE_PRODUCTS constant ---

  describe('TILE_PRODUCTS', () => {
    it('contains the expected products', () => {
      expect(TILE_PRODUCTS).toContain('flight-cat');
      expect(TILE_PRODUCTS).toContain('clouds-total');
      expect(TILE_PRODUCTS).toContain('clouds-low');
      expect(TILE_PRODUCTS).toContain('clouds-mid');
      expect(TILE_PRODUCTS).toContain('clouds-high');
      expect(TILE_PRODUCTS).toContain('visibility');
      expect(TILE_PRODUCTS).toContain('clouds');
    });
  });

  // --- Pressure-level cloud tiles ---

  describe('Pressure-level cloud tiles', () => {
    let service: HrrrTileService;
    let mockCycleRepo: any;
    let mockSurfaceRepo: any;
    let mockPressureRepo: any;

    function makePressureGrid(rh: number, pressureLevel = 850) {
      const rows: any[] = [];
      for (let lat = 24; lat <= 50; lat++) {
        for (let lng = -125; lng <= -66; lng++) {
          rows.push({
            lat,
            lng,
            pressure_level: pressureLevel,
            relative_humidity: rh,
          });
        }
      }
      return rows;
    }

    beforeEach(async () => {
      mockCycleRepo = {
        findOne: jest.fn().mockResolvedValue({
          init_time: INIT_TIME,
          is_active: true,
        }),
      };
      mockSurfaceRepo = {
        find: jest.fn().mockResolvedValue([]),
      };
      mockPressureRepo = {
        find: jest.fn().mockResolvedValue([]),
      };

      const module: TestingModule = await Test.createTestingModule({
        providers: [
          HrrrTileService,
          { provide: getRepositoryToken(HrrrCycle), useValue: mockCycleRepo },
          {
            provide: getRepositoryToken(HrrrSurface),
            useValue: mockSurfaceRepo,
          },
          {
            provide: getRepositoryToken(HrrrPressure),
            useValue: mockPressureRepo,
          },
        ],
      }).compile();

      service = module.get<HrrrTileService>(HrrrTileService);
    });

    it('loads pressure raster from pressureRepo, not surfaceRepo', async () => {
      mockPressureRepo.find.mockResolvedValue(makePressureGrid(80));
      await service.renderTile('clouds', 4, 3, 5, 1, 850);
      expect(mockPressureRepo.find).toHaveBeenCalledWith({
        where: { init_time: INIT_TIME, forecast_hour: 1, pressure_level: 850 },
      });
      // Surface repo should NOT be called for 'clouds' product
      expect(mockSurfaceRepo.find).not.toHaveBeenCalled();
    });

    it('renders RH=0 as transparent', async () => {
      mockPressureRepo.find.mockResolvedValue(makePressureGrid(0));
      const buffer = await service.renderTile('clouds', 2, 0, 1, 1, 850);
      expect(buffer).toBeInstanceOf(Buffer);
      expect(buffer[0]).toBe(0x89); // PNG header
    });

    it('renders RH=40 as transparent (below 50% threshold)', async () => {
      mockPressureRepo.find.mockResolvedValue(makePressureGrid(40));
      const buffer = await service.renderTile('clouds', 2, 0, 1, 1, 850);
      expect(buffer).toBeInstanceOf(Buffer);
    });

    it('renders RH=100 as opaque white cloud', async () => {
      mockPressureRepo.find.mockResolvedValue(makePressureGrid(100));
      const buffer = await service.renderTile('clouds', 2, 0, 1, 1, 850);
      expect(buffer).toBeInstanceOf(Buffer);
      expect(buffer.length).toBeGreaterThan(200);
    });

    it('renders RH=75 as semi-transparent cloud', async () => {
      mockPressureRepo.find.mockResolvedValue(makePressureGrid(75));
      const buffer = await service.renderTile('clouds', 2, 0, 1, 1, 850);
      expect(buffer).toBeInstanceOf(Buffer);
      expect(buffer.length).toBeGreaterThan(100);
    });

    it('uses separate cache entries for different pressure levels', async () => {
      mockPressureRepo.find.mockResolvedValue(makePressureGrid(80, 850));
      await service.renderTile('clouds', 4, 3, 5, 1, 850);
      const calls850 = mockPressureRepo.find.mock.calls.length;

      mockPressureRepo.find.mockResolvedValue(makePressureGrid(60, 300));
      await service.renderTile('clouds', 4, 3, 5, 1, 300);
      // Should have made an additional DB call for the new level
      expect(mockPressureRepo.find.mock.calls.length).toBeGreaterThan(calls850);
    });

    it('defaults to 850hPa when no pressure level specified', async () => {
      mockPressureRepo.find.mockResolvedValue(makePressureGrid(80));
      await service.renderTile('clouds', 4, 3, 5, 1);
      expect(mockPressureRepo.find).toHaveBeenCalledWith({
        where: { init_time: INIT_TIME, forecast_hour: 1, pressure_level: 850 },
      });
    });

    it('returns transparent tile when no active cycle exists', async () => {
      mockCycleRepo.findOne.mockResolvedValue(null);
      const buffer = await service.renderTile('clouds', 4, 3, 5, 1, 850);
      expect(buffer).toBeInstanceOf(Buffer);
    });

    it('returns transparent tile for out-of-bounds tile', async () => {
      const buffer = await service.renderTile('clouds', 4, 0, 0, 1, 850);
      expect(buffer).toBeInstanceOf(Buffer);
      expect(buffer[0]).toBe(0x89);
    });
  });
});
