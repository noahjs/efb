import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { NotFoundException } from '@nestjs/common';
import { LogbookService } from './logbook.service';
import { LogbookEntry } from './entities/logbook-entry.entity';

describe('LogbookService', () => {
  let service: LogbookService;
  let mockEntryRepo: any;

  const mockEntry: Partial<LogbookEntry> = {
    id: 1,
    date: '2025-03-15',
    aircraft_id: 10,
    aircraft_identifier: 'N12345',
    aircraft_type: 'Cessna 172',
    from_airport: 'APA',
    to_airport: 'DEN',
    route: 'APA DEN',
    total_time: 1.5,
    pic: 1.5,
    sic: 0,
    night: 0,
    solo: 0,
    cross_country: 1.5,
    actual_instrument: 0.5,
    simulated_instrument: 0,
    day_takeoffs: 1,
    night_takeoffs: 0,
    day_landings_full_stop: 1,
    night_landings_full_stop: 0,
    all_landings: 1,
    holds: 1,
    approaches: 'ILS 35L',
    dual_given: 0,
    dual_received: 0,
    simulated_flight: 0,
    ground_training: 0,
    flight_review: false,
    checkride: false,
    ipc: false,
    comments: 'Practice flight',
  };

  const mockEntry2: Partial<LogbookEntry> = {
    id: 2,
    date: '2025-03-10',
    aircraft_identifier: 'N67890',
    aircraft_type: 'Piper PA-28',
    from_airport: 'BJC',
    to_airport: 'APA',
    total_time: 2.0,
    pic: 2.0,
    sic: 0,
    night: 0.5,
    solo: 0,
    cross_country: 2.0,
    actual_instrument: 0,
    simulated_instrument: 0,
    day_takeoffs: 1,
    night_takeoffs: 1,
    day_landings_full_stop: 0,
    night_landings_full_stop: 1,
    all_landings: 1,
    holds: 0,
    dual_given: 0,
    dual_received: 0,
    simulated_flight: 0,
    ground_training: 0,
  };

  beforeEach(async () => {
    const mockQb = {
      where: jest.fn().mockReturnThis(),
      orderBy: jest.fn().mockReturnThis(),
      addOrderBy: jest.fn().mockReturnThis(),
      skip: jest.fn().mockReturnThis(),
      take: jest.fn().mockReturnThis(),
      getManyAndCount: jest.fn().mockResolvedValue([[{ ...mockEntry }], 1]),
    };

    mockEntryRepo = {
      findOne: jest.fn().mockResolvedValue({ ...mockEntry }),
      find: jest.fn().mockResolvedValue([{ ...mockEntry }, { ...mockEntry2 }]),
      create: jest.fn().mockImplementation((dto) => ({ ...dto })),
      save: jest
        .fn()
        .mockImplementation((entry) =>
          Promise.resolve({ ...entry, id: entry.id ?? 3 }),
        ),
      remove: jest.fn().mockImplementation((entry) => Promise.resolve(entry)),
      createQueryBuilder: jest.fn().mockReturnValue(mockQb),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        LogbookService,
        { provide: getRepositoryToken(LogbookEntry), useValue: mockEntryRepo },
      ],
    }).compile();

    service = module.get<LogbookService>(LogbookService);
  });

  // --- findAll ---

  describe('findAll', () => {
    it('should return paginated results', async () => {
      const result = await service.findAll();
      expect(result.items).toHaveLength(1);
      expect(result.total).toBe(1);
      expect(result.limit).toBe(50);
      expect(result.offset).toBe(0);
    });

    it('should apply query filter when provided', async () => {
      const mockQb = mockEntryRepo.createQueryBuilder();
      await service.findAll('APA');
      expect(mockQb.where).toHaveBeenCalled();
    });

    it('should respect custom limit and offset', async () => {
      const mockQb = mockEntryRepo.createQueryBuilder();
      await service.findAll(undefined, 10, 20);
      expect(mockQb.skip).toHaveBeenCalledWith(20);
      expect(mockQb.take).toHaveBeenCalledWith(10);
    });

    it('should order by date DESC then id DESC', async () => {
      const mockQb = mockEntryRepo.createQueryBuilder();
      await service.findAll();
      expect(mockQb.orderBy).toHaveBeenCalledWith('entry.date', 'DESC');
      expect(mockQb.addOrderBy).toHaveBeenCalledWith('entry.id', 'DESC');
    });
  });

  // --- findOne ---

  describe('findOne', () => {
    it('should return entry when found', async () => {
      const result = await service.findOne(1);
      expect(result.id).toBe(1);
      expect(result.from_airport).toBe('APA');
    });

    it('should throw NotFoundException when not found', async () => {
      mockEntryRepo.findOne.mockResolvedValue(null);
      await expect(service.findOne(999)).rejects.toThrow(NotFoundException);
    });
  });

  // --- create ---

  describe('create', () => {
    it('should create a logbook entry', async () => {
      const dto = {
        date: '2025-03-20',
        aircraft_identifier: 'N12345',
        from_airport: 'APA',
        to_airport: 'BJC',
        total_time: 0.8,
        pic: 0.8,
        day_landings_full_stop: 1,
        all_landings: 1,
      };

      const result = await service.create(dto as any);

      expect(mockEntryRepo.create).toHaveBeenCalledWith(dto);
      expect(mockEntryRepo.save).toHaveBeenCalledTimes(1);
      expect(result.id).toBeDefined();
    });
  });

  // --- update ---

  describe('update', () => {
    it('should update an existing entry', async () => {
      const dto = { total_time: 2.5, comments: 'Updated' };
      await service.update(1, dto as any);

      expect(mockEntryRepo.findOne).toHaveBeenCalledWith({ where: { id: 1 } });
      expect(mockEntryRepo.save).toHaveBeenCalledTimes(1);
    });

    it('should merge updated fields into existing entry', async () => {
      const dto = { total_time: 2.5, comments: 'Updated' };
      await service.update(1, dto as any);

      const savedEntry = mockEntryRepo.save.mock.calls[0][0];
      expect(savedEntry.total_time).toBe(2.5);
      expect(savedEntry.comments).toBe('Updated');
      // Original fields preserved
      expect(savedEntry.from_airport).toBe('APA');
    });

    it('should throw NotFoundException when updating non-existent entry', async () => {
      mockEntryRepo.findOne.mockResolvedValue(null);
      await expect(
        service.update(999, { total_time: 1.0 } as any),
      ).rejects.toThrow(NotFoundException);
    });
  });

  // --- remove ---

  describe('remove', () => {
    it('should remove an existing entry', async () => {
      await service.remove(1);
      expect(mockEntryRepo.remove).toHaveBeenCalledTimes(1);
    });

    it('should throw NotFoundException when removing non-existent entry', async () => {
      mockEntryRepo.findOne.mockResolvedValue(null);
      await expect(service.remove(999)).rejects.toThrow(NotFoundException);
    });
  });

  // --- getSummary ---

  describe('getSummary', () => {
    it('should return total entries and total time', async () => {
      const result = await service.getSummary();
      expect(result.totalEntries).toBe(2);
      expect(result.totalTime).toBe(3.5); // 1.5 + 2.0
    });

    it('should return time for each period bucket', async () => {
      const result = await service.getSummary();
      expect(result).toHaveProperty('last7Days');
      expect(result).toHaveProperty('last30Days');
      expect(result).toHaveProperty('last90Days');
      expect(result).toHaveProperty('last6Months');
      expect(result).toHaveProperty('last12Months');
    });

    it('should handle empty logbook', async () => {
      mockEntryRepo.find.mockResolvedValue([]);

      const result = await service.getSummary();
      expect(result.totalEntries).toBe(0);
      expect(result.totalTime).toBe(0);
      expect(result.last7Days).toBe(0);
    });

    it('should filter entries by date for period buckets', async () => {
      const today = new Date().toISOString().slice(0, 10);
      const oldDate = '2020-01-01';

      mockEntryRepo.find.mockResolvedValue([
        { ...mockEntry, date: today, total_time: 1.5 },
        { ...mockEntry2, date: oldDate, total_time: 2.0 },
      ]);

      const result = await service.getSummary();
      expect(result.totalTime).toBe(3.5);
      // Recent flight should appear in 7-day bucket
      expect(result.last7Days).toBe(1.5);
      // Old flight should not appear in 7-day bucket
      expect(result.last12Months).toBe(1.5);
    });
  });

  // --- getExperienceReport ---

  describe('getExperienceReport', () => {
    it('should group entries by aircraft type', async () => {
      const result = await service.getExperienceReport();

      expect(result.rows.length).toBe(2);
      const c172Row = result.rows.find((r) => r.aircraftType === 'Cessna 172');
      const pa28Row = result.rows.find((r) => r.aircraftType === 'Piper PA-28');
      expect(c172Row).toBeDefined();
      expect(pa28Row).toBeDefined();
      expect(c172Row!.totalTime).toBe(1.5);
      expect(pa28Row!.totalTime).toBe(2.0);
    });

    it('should compute totals across all entries', async () => {
      const result = await service.getExperienceReport();

      expect(result.totals.totalTime).toBe(3.5);
      expect(result.totals.flightCount).toBe(2);
      expect(result.totals.pic).toBe(3.5);
      expect(result.totals.dayTakeoffs).toBe(2);
    });

    it('should sort rows by totalTime descending', async () => {
      const result = await service.getExperienceReport();

      // PA-28 has 2.0h, C172 has 1.5h
      expect(result.rows[0].aircraftType).toBe('Piper PA-28');
      expect(result.rows[1].aircraftType).toBe('Cessna 172');
    });

    it('should filter by period when specified', async () => {
      const today = new Date().toISOString().slice(0, 10);
      const oldDate = '2020-01-01';

      mockEntryRepo.find.mockResolvedValue([
        { ...mockEntry, date: today, aircraft_type: 'Cessna 172' },
        { ...mockEntry2, date: oldDate, aircraft_type: 'Piper PA-28' },
      ]);

      const result = await service.getExperienceReport('7d');
      // Only recent entry should be included
      expect(result.rows.length).toBe(1);
      expect(result.rows[0].aircraftType).toBe('Cessna 172');
    });

    it('should return all entries when period is "all"', async () => {
      const result = await service.getExperienceReport('all');
      expect(result.rows.length).toBe(2);
    });

    it('should handle entries with null aircraft_type as Unknown', async () => {
      mockEntryRepo.find.mockResolvedValue([
        { ...mockEntry, aircraft_type: null },
      ]);

      const result = await service.getExperienceReport();
      expect(result.rows[0].aircraftType).toBe('Unknown');
    });

    it('should aggregate landing counts correctly', async () => {
      const result = await service.getExperienceReport();

      expect(result.totals.dayLandings).toBe(1); // only mockEntry has day landing
      expect(result.totals.nightLandings).toBe(1); // only mockEntry2 has night landing
      expect(result.totals.allLandings).toBe(2);
    });
  });
});
