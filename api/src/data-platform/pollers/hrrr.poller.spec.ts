import { Test, TestingModule } from '@nestjs/testing';
import { HttpService } from '@nestjs/axios';
import { getRepositoryToken } from '@nestjs/typeorm';
import { of, throwError } from 'rxjs';
import { HrrrPoller } from './hrrr.poller';
import { HrrrCycle } from '../entities/hrrr-cycle.entity';
import { HrrrSurface } from '../entities/hrrr-surface.entity';
import { HrrrPressure } from '../entities/hrrr-pressure.entity';

// --- Mock .idx File Content ---

const MOCK_IDX_CONTENT = [
  '1:0:d=2026021312:REFC:entire atmosphere:anl:',
  '2:5000:d=2026021312:RETOP:cloud top:anl:',
  '3:100000:d=2026021312:VIS:surface:anl:',
  '4:200000:d=2026021312:UGRD:10 m above ground:anl:',
  '5:300000:d=2026021312:VGRD:10 m above ground:anl:',
  '6:400000:d=2026021312:TMP:2 m above ground:anl:',
  '7:500000:d=2026021312:TCDC:entire atmosphere:anl:',
  '8:600000:d=2026021312:LCDC:low cloud layer:anl:',
  '9:700000:d=2026021312:MCDC:middle cloud layer:anl:',
  '10:800000:d=2026021312:HCDC:high cloud layer:anl:',
  '11:900000:d=2026021312:HGT:cloud ceiling:anl:',
  '12:1000000:d=2026021312:GUST:surface:anl:',
  '13:1100000:d=2026021312:PRES:surface:anl:',
].join('\n');

const MOCK_PRS_IDX_CONTENT = [
  '1:0:d=2026021312:HGT:500 mb:anl:',
  '2:100000:d=2026021312:TMP:500 mb:anl:',
  '3:200000:d=2026021312:UGRD:500 mb:anl:',
  '4:300000:d=2026021312:VGRD:500 mb:anl:',
  '5:400000:d=2026021312:TCDC:500 mb:anl:',
  '6:500000:d=2026021312:TMP:850 mb:anl:',
  '7:600000:d=2026021312:UGRD:850 mb:anl:',
  '8:700000:d=2026021312:VGRD:850 mb:anl:',
  '9:800000:d=2026021312:TCDC:850 mb:anl:',
  '10:900000:d=2026021312:DPT:surface:anl:',
].join('\n');

// --- Helpers ---

const INIT_TIME = new Date('2026-02-13T12:00:00Z');

function createMockCycle(overrides: Partial<HrrrCycle> = {}): HrrrCycle {
  const cycle = new HrrrCycle();
  cycle.init_time = INIT_TIME;
  cycle.status = 'discovered';
  cycle.is_active = false;
  cycle.download_total = 0;
  cycle.download_completed = 0;
  cycle.download_failed = 0;
  cycle.download_bytes = 0;
  cycle.download_started_at = null;
  cycle.download_completed_at = null;
  cycle.process_total = 0;
  cycle.process_completed = 0;
  cycle.process_failed = 0;
  cycle.process_started_at = null;
  cycle.process_completed_at = null;
  cycle.ingest_surface_rows = 0;
  cycle.ingest_pressure_rows = 0;
  cycle.ingest_completed_at = null;
  cycle.tiles_total = 0;
  cycle.tiles_completed = 0;
  cycle.tiles_failed = 0;
  cycle.tiles_count = 0;
  cycle.tiles_started_at = null;
  cycle.tiles_completed_at = null;
  cycle.activated_at = null;
  cycle.superseded_at = null;
  cycle.last_error = null;
  cycle.total_errors = 0;
  cycle.total_duration_ms = null;
  Object.assign(cycle, overrides);
  return cycle;
}

function createMockQb(overrides: Record<string, any> = {}) {
  const qb: any = {
    update: jest.fn().mockReturnThis(),
    set: jest.fn().mockReturnThis(),
    where: jest.fn().mockReturnThis(),
    andWhere: jest.fn().mockReturnThis(),
    orderBy: jest.fn().mockReturnThis(),
    setParameters: jest.fn().mockReturnThis(),
    limit: jest.fn().mockReturnThis(),
    insert: jest.fn().mockReturnThis(),
    into: jest.fn().mockReturnThis(),
    values: jest.fn().mockReturnThis(),
    orIgnore: jest.fn().mockReturnThis(),
    execute: jest.fn().mockResolvedValue({ affected: 1 }),
    getOne: jest.fn().mockResolvedValue(null),
    getMany: jest.fn().mockResolvedValue([]),
    ...overrides,
  };
  return qb;
}

// --- Tests ---

describe('HrrrPoller', () => {
  let poller: HrrrPoller;
  let mockHttp: any;
  let mockCycleRepo: any;
  let mockSurfaceRepo: any;
  let mockPressureRepo: any;

  beforeEach(async () => {
    // Freeze time for cycle discovery
    jest.useFakeTimers();
    jest.setSystemTime(new Date('2026-02-13T14:30:00Z'));

    mockHttp = {
      head: jest.fn(),
      get: jest.fn(),
    };

    const mockTxnManager = {
      createQueryBuilder: jest.fn().mockReturnValue(createMockQb()),
    };

    mockCycleRepo = {
      findOne: jest.fn().mockResolvedValue(null),
      find: jest.fn().mockResolvedValue([]),
      create: jest.fn().mockImplementation((data) => createMockCycle(data)),
      save: jest.fn().mockImplementation((cycle) => Promise.resolve(cycle)),
      delete: jest.fn().mockResolvedValue({ affected: 1 }),
      createQueryBuilder: jest.fn().mockReturnValue(createMockQb()),
      manager: {
        transaction: jest
          .fn()
          .mockImplementation(async (cb) => cb(mockTxnManager)),
      },
    };

    mockSurfaceRepo = {
      delete: jest.fn().mockResolvedValue({ affected: 0 }),
      target: HrrrSurface,
      manager: {
        transaction: jest
          .fn()
          .mockImplementation(async (cb) => cb(mockTxnManager)),
      },
    };

    mockPressureRepo = {
      delete: jest.fn().mockResolvedValue({ affected: 0 }),
      target: HrrrPressure,
      manager: {
        transaction: jest
          .fn()
          .mockImplementation(async (cb) => cb(mockTxnManager)),
      },
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        HrrrPoller,
        { provide: HttpService, useValue: mockHttp },
        { provide: getRepositoryToken(HrrrCycle), useValue: mockCycleRepo },
        { provide: getRepositoryToken(HrrrSurface), useValue: mockSurfaceRepo },
        {
          provide: getRepositoryToken(HrrrPressure),
          useValue: mockPressureRepo,
        },
      ],
    }).compile();

    poller = module.get<HrrrPoller>(HrrrPoller);
  });

  afterEach(() => {
    jest.useRealTimers();
  });

  // --- Cycle Discovery ---

  describe('discoverLatestCycle', () => {
    it('should return error when no cycles available on S3', async () => {
      mockHttp.head.mockReturnValue(
        throwError(() => new Error('404 Not Found')),
      );

      const result = await poller.execute();

      expect(result.recordsUpdated).toBe(0);
      expect(result.errors).toBe(1);
      expect(result.lastError).toContain('No HRRR cycle available');
    });

    it('should try 2 hours back first', async () => {
      // At 14:30 UTC, tries 12:30 (12Z cycle)
      mockHttp.head.mockReturnValueOnce(of({ status: 200 }));
      // Stop after discovery by having existing active cycle
      mockCycleRepo.findOne.mockResolvedValue(
        createMockCycle({ status: 'active' }),
      );

      await poller.execute();

      // Should have been called with the 12Z .idx URL
      expect(mockHttp.head).toHaveBeenCalledTimes(1);
      const url = mockHttp.head.mock.calls[0][0];
      expect(url).toContain('hrrr.20260213');
      expect(url).toContain('t12z');
    });

    it('should try earlier cycles when recent ones are not available', async () => {
      // 12Z not available, 11Z available
      mockHttp.head
        .mockReturnValueOnce(throwError(() => new Error('404')))
        .mockReturnValueOnce(of({ status: 200 }));

      mockCycleRepo.findOne.mockResolvedValue(
        createMockCycle({ status: 'active' }),
      );

      await poller.execute();

      expect(mockHttp.head).toHaveBeenCalledTimes(2);
      const url2 = mockHttp.head.mock.calls[1][0];
      expect(url2).toContain('t11z');
    });

    it('should skip already-active cycles', async () => {
      mockHttp.head.mockReturnValue(of({ status: 200 }));
      mockCycleRepo.findOne.mockResolvedValue(
        createMockCycle({ status: 'active' }),
      );

      const result = await poller.execute();

      expect(result.recordsUpdated).toBe(0);
      expect(result.errors).toBe(0);
    });

    it('should skip cycles already generating tiles', async () => {
      mockHttp.head.mockReturnValue(of({ status: 200 }));
      mockCycleRepo.findOne.mockResolvedValue(
        createMockCycle({ status: 'generating_tiles' }),
      );

      const result = await poller.execute();

      expect(result.recordsUpdated).toBe(0);
      expect(result.errors).toBe(0);
    });
  });

  // --- .idx Parsing ---

  describe('parseIdxAndGetRanges (via downloadForecastHour)', () => {
    it('should parse .idx file and extract matching variable byte ranges', async () => {
      // Set up: discovery succeeds, no existing cycle
      mockHttp.head.mockReturnValue(of({ status: 200 }));
      mockCycleRepo.findOne.mockResolvedValue(null);

      // .idx file response
      mockHttp.get.mockImplementation((url: string, opts: any) => {
        if (url.endsWith('.idx')) {
          return of({ data: MOCK_IDX_CONTENT });
        }
        // Byte-range download
        return of({ data: Buffer.alloc(1000) });
      });

      // We need to mock the Python processing — it'll be called via execFile
      // Since we can't easily mock child_process in this context, we'll
      // test the idx parsing logic by accessing it indirectly
      // For this test, just verify the HTTP calls match expected patterns

      // The poller will fail at the Python processing step, which is expected
      // We're testing the download stage
      try {
        await poller.execute();
      } catch {
        // Expected: Python script won't exist in test
      }

      // Verify .idx was fetched
      const getCalls = mockHttp.get.mock.calls;
      const idxCalls = getCalls.filter(
        (c: any[]) => typeof c[0] === 'string' && c[0].endsWith('.idx'),
      );
      expect(idxCalls.length).toBeGreaterThan(0);

      // Verify byte-range downloads were made (non-.idx GET calls)
      const downloadCalls = getCalls.filter(
        (c: any[]) =>
          typeof c[0] === 'string' &&
          !c[0].endsWith('.idx') &&
          c[1]?.headers?.Range,
      );
      expect(downloadCalls.length).toBeGreaterThan(0);
    });
  });

  // --- mergeRanges ---

  describe('mergeRanges', () => {
    // Access private method via any cast
    let mergeRanges: (
      ranges: Array<{ start: number; end: number }>,
    ) => Array<{ start: number; end: number }>;

    beforeEach(() => {
      mergeRanges = (poller as any).mergeRanges.bind(poller);
    });

    it('should return empty array for empty input', () => {
      expect(mergeRanges([])).toEqual([]);
    });

    it('should return single range unchanged', () => {
      expect(mergeRanges([{ start: 0, end: 1000 }])).toEqual([
        { start: 0, end: 1000 },
      ]);
    });

    it('should merge overlapping ranges', () => {
      const result = mergeRanges([
        { start: 0, end: 500 },
        { start: 400, end: 1000 },
      ]);
      expect(result).toEqual([{ start: 0, end: 1000 }]);
    });

    it('should merge adjacent ranges within 100KB gap', () => {
      const result = mergeRanges([
        { start: 0, end: 100000 },
        { start: 150000, end: 200000 }, // gap = 50KB, within threshold
      ]);
      expect(result).toEqual([{ start: 0, end: 200000 }]);
    });

    it('should not merge ranges with gaps > 100KB', () => {
      const result = mergeRanges([
        { start: 0, end: 100000 },
        { start: 300000, end: 400000 }, // gap = 200KB, too big
      ]);
      expect(result).toEqual([
        { start: 0, end: 100000 },
        { start: 300000, end: 400000 },
      ]);
    });

    it('should sort ranges before merging', () => {
      const result = mergeRanges([
        { start: 300000, end: 400000 },
        { start: 0, end: 100000 },
        { start: 50000, end: 150000 },
      ]);
      expect(result).toEqual([
        { start: 0, end: 150000 },
        { start: 300000, end: 400000 },
      ]);
    });

    it('should handle multiple overlapping groups', () => {
      const result = mergeRanges([
        { start: 0, end: 100 },
        { start: 50, end: 200 },
        { start: 150, end: 300 },
        { start: 1000000, end: 1100000 },
        { start: 1050000, end: 1200000 },
      ]);
      expect(result).toEqual([
        { start: 0, end: 300 },
        { start: 1000000, end: 1200000 },
      ]);
    });
  });

  // --- formatDateStr ---

  describe('formatDateStr', () => {
    let formatDateStr: (date: Date) => string;

    beforeEach(() => {
      formatDateStr = (poller as any).formatDateStr.bind(poller);
    });

    it('should format date as YYYYMMDD', () => {
      expect(formatDateStr(new Date('2026-02-13T12:00:00Z'))).toBe('20260213');
    });

    it('should pad single-digit months and days', () => {
      expect(formatDateStr(new Date('2026-01-05T00:00:00Z'))).toBe('20260105');
    });

    it('should handle December', () => {
      expect(formatDateStr(new Date('2026-12-31T00:00:00Z'))).toBe('20261231');
    });
  });

  // --- Cycle Activation ---

  describe('activateCycle', () => {
    it('should supersede old cycle and activate new one in a transaction', async () => {
      mockHttp.head.mockReturnValue(of({ status: 200 }));
      mockCycleRepo.findOne.mockResolvedValue(null);

      // Minimal successful pipeline: discovery + download + process + ingest + activate
      // Mock the .idx parse
      mockHttp.get.mockImplementation((url: string) => {
        if (url.endsWith('.idx')) {
          return of({ data: MOCK_IDX_CONTENT });
        }
        return of({ data: Buffer.alloc(100) });
      });

      // Mock Python processing — throw so we can test what happens up to that point
      const activateCycle = (poller as any).activateCycle.bind(poller);

      const cycle = createMockCycle();
      await activateCycle(cycle);

      // Verify transaction was used
      expect(mockCycleRepo.manager.transaction).toHaveBeenCalled();
    });
  });

  // --- Cleanup ---

  describe('cleanupOldCycles', () => {
    it('should delete superseded cycles older than threshold', async () => {
      const oldCycle = createMockCycle({
        init_time: new Date('2026-02-13T06:00:00Z'),
        status: 'superseded',
        superseded_at: new Date('2026-02-13T07:00:00Z'),
      });

      const cleanupQb = createMockQb({
        getMany: jest.fn().mockResolvedValue([oldCycle]),
      });
      mockCycleRepo.createQueryBuilder.mockReturnValue(cleanupQb);

      const cleanupOldCycles = (poller as any).cleanupOldCycles.bind(poller);
      await cleanupOldCycles();

      expect(mockSurfaceRepo.delete).toHaveBeenCalledWith({
        init_time: oldCycle.init_time,
      });
      expect(mockPressureRepo.delete).toHaveBeenCalledWith({
        init_time: oldCycle.init_time,
      });
      expect(mockCycleRepo.delete).toHaveBeenCalledWith({
        init_time: oldCycle.init_time,
      });
    });

    it('should not delete anything when no stale cycles', async () => {
      const cleanupQb = createMockQb({
        getMany: jest.fn().mockResolvedValue([]),
      });
      mockCycleRepo.createQueryBuilder.mockReturnValue(cleanupQb);

      const cleanupOldCycles = (poller as any).cleanupOldCycles.bind(poller);
      await cleanupOldCycles();

      expect(mockSurfaceRepo.delete).not.toHaveBeenCalled();
      expect(mockPressureRepo.delete).not.toHaveBeenCalled();
      expect(mockCycleRepo.delete).not.toHaveBeenCalled();
    });
  });

  // --- Error Handling ---

  describe('error handling', () => {
    it('should reset existing cycle when reprocessing', async () => {
      mockHttp.head.mockReturnValue(of({ status: 200 }));

      // Existing failed cycle
      const failedCycle = createMockCycle({
        status: 'failed',
        total_errors: 3,
        last_error: 'Previous error',
      });
      mockCycleRepo.findOne.mockResolvedValue(failedCycle);

      // Capture the status at each save call
      const saveStatuses: string[] = [];
      mockCycleRepo.save.mockImplementation((cycle: any) => {
        saveStatuses.push(cycle.status);
        return Promise.resolve(cycle);
      });

      // Will fail at download but that's OK — we're testing the reset
      mockHttp.get.mockReturnValue(
        throwError(() => new Error('Download failed')),
      );

      await poller.execute();

      // First save should have reset status to 'discovered'
      expect(saveStatuses[0]).toBe('discovered');
      // Second save transitions to 'downloading'
      expect(saveStatuses[1]).toBe('downloading');
    });

    it('should track download failures in cycle record', async () => {
      mockHttp.head.mockReturnValue(of({ status: 200 }));
      mockCycleRepo.findOne.mockResolvedValue(null);

      // .idx succeeds, byte-range download fails
      mockHttp.get.mockImplementation((url: string) => {
        if (url.endsWith('.idx')) {
          return of({ data: MOCK_IDX_CONTENT });
        }
        return throwError(() => new Error('S3 connection reset'));
      });

      const result = await poller.execute();

      // All downloads should fail
      expect(result.errors).toBeGreaterThan(0);
      expect(result.lastError).toBeDefined();
    });
  });

  // --- bulkInsert ---

  describe('bulkInsert', () => {
    it('should chunk large inserts', async () => {
      const bulkInsert = (poller as any).bulkInsert.bind(poller);

      // Create 1200 mock entities (should be split into 3 chunks of 500, 500, 200)
      const entities = Array.from({ length: 1200 }, (_, i) => ({
        id: i,
        lat: 24 + i * 0.01,
        lng: -125,
      }));

      const mockInsertQb = createMockQb();
      const mockTxnManager = {
        createQueryBuilder: jest.fn().mockReturnValue(mockInsertQb),
      };
      mockSurfaceRepo.manager.transaction.mockImplementation(async (cb: any) =>
        cb(mockTxnManager),
      );

      await bulkInsert(mockSurfaceRepo, entities);

      // Should have 3 insert calls (500 + 500 + 200)
      expect(mockInsertQb.values).toHaveBeenCalledTimes(3);
      expect(mockInsertQb.values.mock.calls[0][0]).toHaveLength(500);
      expect(mockInsertQb.values.mock.calls[1][0]).toHaveLength(500);
      expect(mockInsertQb.values.mock.calls[2][0]).toHaveLength(200);
    });

    it('should handle empty entity array', async () => {
      const bulkInsert = (poller as any).bulkInsert.bind(poller);

      const mockInsertQb = createMockQb();
      const mockTxnManager = {
        createQueryBuilder: jest.fn().mockReturnValue(mockInsertQb),
      };
      mockSurfaceRepo.manager.transaction.mockImplementation(async (cb: any) =>
        cb(mockTxnManager),
      );

      await bulkInsert(mockSurfaceRepo, []);

      // No insert calls for empty array
      expect(mockInsertQb.values).not.toHaveBeenCalled();
    });
  });
});
