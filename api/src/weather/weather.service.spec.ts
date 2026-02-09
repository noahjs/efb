import { Test, TestingModule } from '@nestjs/testing';
import { HttpService } from '@nestjs/axios';
import { of, throwError } from 'rxjs';
import { WeatherService } from './weather.service';
import { AirportsService } from '../airports/airports.service';

describe('WeatherService', () => {
  let service: WeatherService;
  let mockHttp: any;
  let mockAirportsService: any;

  beforeEach(async () => {
    mockHttp = {
      get: jest.fn().mockReturnValue(of({ data: null })),
      post: jest.fn().mockReturnValue(of({ data: null })),
    };

    mockAirportsService = {
      findById: jest.fn().mockResolvedValue(null),
      findNearby: jest.fn().mockResolvedValue([]),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        WeatherService,
        { provide: HttpService, useValue: mockHttp },
        { provide: AirportsService, useValue: mockAirportsService },
      ],
    }).compile();

    service = module.get<WeatherService>(WeatherService);
  });

  // --- decodeWindValue (private, accessed via parseWindsAloftText) ---

  describe('winds aloft parsing (decodeWindValue)', () => {
    // To test the private decodeWindValue, we call parseWindsAloftText
    // with crafted input and check the output.

    function parseWindLine(
      windValues: string[],
      altitudes = [3000, 6000, 9000, 12000],
    ): Map<string, any[]> {
      // Build a minimal winds aloft text block
      const altHeaders = altitudes.map((a) => String(a).padStart(5));
      const headerLine = 'FT  ' + altHeaders.join(' ');

      // Build station data line with correct column positions
      const matches = [...headerLine.matchAll(/\d+/g)];
      let dataLine = 'TST ';
      for (let i = 0; i < windValues.length; i++) {
        const pos = matches[i]?.index ?? (4 + i * 6);
        while (dataLine.length < pos) dataLine += ' ';
        dataLine += windValues[i];
      }

      const text = `\n${headerLine}\n${dataLine}\n`;
      return (service as any).parseWindsAloftText(text);
    }

    it('should decode standard DDHH format at 3000ft (no temp)', () => {
      // 2520 = direction 250°, speed 20kt
      const result = parseWindLine(['2520'], [3000]);
      const station = result.get('TST');
      expect(station).toBeDefined();
      expect(station![0].altitude).toBe(3000);
      expect(station![0].direction).toBe(250);
      expect(station![0].speed).toBe(20);
      expect(station![0].temperature).toBeNull(); // no temp at 3000
      expect(station![0].lightAndVariable).toBe(false);
    });

    it('should decode DDHH+TT format (6000-24000ft with positive temp)', () => {
      // 2520+05 = direction 250°, speed 20kt, temp +5°C
      const result = parseWindLine(['', '2520+05'], [3000, 6000]);
      const station = result.get('TST');
      expect(station).toBeDefined();
      const alt6000 = station!.find((a: any) => a.altitude === 6000);
      expect(alt6000!.direction).toBe(250);
      expect(alt6000!.speed).toBe(20);
      expect(alt6000!.temperature).toBe(5);
    });

    it('should decode DDHH-TT format (negative temp)', () => {
      // 3015-12 = direction 300°, speed 15kt, temp -12°C
      const result = parseWindLine(['', '3015-12'], [3000, 6000]);
      const station = result.get('TST');
      const alt6000 = station!.find((a: any) => a.altitude === 6000);
      expect(alt6000!.direction).toBe(300);
      expect(alt6000!.speed).toBe(15);
      expect(alt6000!.temperature).toBe(-12);
    });

    it('should decode light and variable (9900 prefix)', () => {
      const result = parseWindLine(['9900'], [3000]);
      const station = result.get('TST');
      expect(station![0].lightAndVariable).toBe(true);
      expect(station![0].direction).toBeNull();
      expect(station![0].speed).toBeNull();
    });

    it('should decode light and variable with temperature', () => {
      // 9900+03 = light/variable, temp +3°C
      const result = parseWindLine(['', '9900+03'], [3000, 6000]);
      const station = result.get('TST');
      const alt6000 = station!.find((a: any) => a.altitude === 6000);
      expect(alt6000!.lightAndVariable).toBe(true);
      expect(alt6000!.temperature).toBe(3);
    });

    it('should decode speed >= 100kt (DD+50 encoding)', () => {
      // 7510 = (75-50)*10 = 250°, speed 10+100 = 110kt
      const result = parseWindLine(['7510'], [3000]);
      const station = result.get('TST');
      expect(station![0].direction).toBe(250);
      expect(station![0].speed).toBe(110);
    });

    it('should handle empty wind value', () => {
      const result = parseWindLine(['    '], [3000]);
      const station = result.get('TST');
      expect(station![0].direction).toBeNull();
      expect(station![0].speed).toBeNull();
    });

    it('should parse multiple altitudes for one station', () => {
      const result = parseWindLine(
        ['2520', '2530-05', '2745-15', '3060-25'],
        [3000, 6000, 9000, 12000],
      );
      const station = result.get('TST');
      expect(station).toHaveLength(4);
    });
  });

  // --- parseWindsAloftText header detection ---

  describe('parseWindsAloftText structure', () => {
    it('should return empty map for text without FT header', () => {
      const result = (service as any).parseWindsAloftText(
        'No wind data here\nJust some text\n',
      );
      expect(result.size).toBe(0);
    });

    it('should skip non-station lines after header', () => {
      const text = `
FT  3000    6000    9000

TST 2520    2530-05 2745-15
`;
      const result = (service as any).parseWindsAloftText(text);
      expect(result.size).toBe(1);
      expect(result.has('TST')).toBe(true);
    });

    it('should parse multiple stations', () => {
      const text = `
FT  3000    6000
APA 2520    2530-05
DEN 3015    3025+02
BJC 1810    1820-08
`;
      const result = (service as any).parseWindsAloftText(text);
      expect(result.size).toBe(3);
      expect(result.has('APA')).toBe(true);
      expect(result.has('DEN')).toBe(true);
      expect(result.has('BJC')).toBe(true);
    });
  });

  // --- parseNotamDate ---

  describe('parseNotamDate', () => {
    it('should parse MM/DD/YYYY HHMM format to ISO 8601', () => {
      const result = (service as any).parseNotamDate('03/15/2025 1400');
      expect(result).toBe('2025-03-15T14:00:00Z');
    });

    it('should parse midnight correctly', () => {
      const result = (service as any).parseNotamDate('12/31/2025 0000');
      expect(result).toBe('2025-12-31T00:00:00Z');
    });

    it('should handle EST suffix', () => {
      const result = (service as any).parseNotamDate('01/01/2025 0800EST');
      expect(result).toBe('2025-01-01T08:00:00Z');
    });

    it('should return null for null input', () => {
      expect((service as any).parseNotamDate(null)).toBeNull();
    });

    it('should return null for undefined input', () => {
      expect((service as any).parseNotamDate(undefined)).toBeNull();
    });

    it('should return null for empty string', () => {
      expect((service as any).parseNotamDate('')).toBeNull();
    });

    it('should return null for invalid date format', () => {
      expect((service as any).parseNotamDate('2025-03-15 14:00')).toBeNull();
    });

    it('should return null for nonsense string', () => {
      expect((service as any).parseNotamDate('PERMANENT')).toBeNull();
    });
  });

  // --- METAR caching ---

  describe('getMetar caching', () => {
    it('should fetch from AWC on first call', async () => {
      const mockMetar = {
        icaoId: 'KAPA',
        rawOb: 'KAPA 151453Z 23010KT 10SM FEW080 17/01 A3012',
        temp: 17,
        dewp: 1,
        wdir: 230,
        wspd: 10,
      };
      mockHttp.get.mockReturnValue(of({ data: [mockMetar] }));

      const result = await service.getMetar('KAPA');
      expect(result).toEqual(mockMetar);
      expect(mockHttp.get).toHaveBeenCalledTimes(1);
    });

    it('should return cached data on second call', async () => {
      const mockMetar = { icaoId: 'KAPA', rawOb: 'test' };
      mockHttp.get.mockReturnValue(of({ data: [mockMetar] }));

      const first = await service.getMetar('KAPA');
      const second = await service.getMetar('KAPA');

      expect(first).toEqual(second);
      expect(mockHttp.get).toHaveBeenCalledTimes(1); // Only one HTTP call
    });

    it('should return null on HTTP error', async () => {
      mockHttp.get.mockReturnValue(
        throwError(() => new Error('Network error')),
      );

      const result = await service.getMetar('KAPA');
      expect(result).toBeNull();
    });

    it('should return null for empty response', async () => {
      mockHttp.get.mockReturnValue(of({ data: [] }));

      const result = await service.getMetar('KAPA');
      expect(result).toBeNull();
    });
  });

  // --- TAF ---

  describe('getTaf', () => {
    it('should fetch TAF from AWC', async () => {
      const mockTaf = { icaoId: 'KAPA', rawTAF: 'TAF KAPA ...' };
      mockHttp.get.mockReturnValue(of({ data: [mockTaf] }));

      const result = await service.getTaf('KAPA');
      expect(result).toEqual(mockTaf);
    });

    it('should return null on error', async () => {
      mockHttp.get.mockReturnValue(
        throwError(() => new Error('Network error')),
      );

      const result = await service.getTaf('KAPA');
      expect(result).toBeNull();
    });
  });

  // --- Nearest TAF ---

  describe('getNearestTaf', () => {
    it('should return direct TAF when available', async () => {
      const mockTaf = { icaoId: 'KAPA', rawTAF: 'TAF KAPA ...' };
      mockHttp.get.mockReturnValue(of({ data: [mockTaf] }));

      const result = await service.getNearestTaf('KAPA');
      expect(result.taf).toEqual(mockTaf);
      expect(result.isNearby).toBe(false);
      expect(result.station).toBe('KAPA');
    });

    it('should search nearby when direct TAF unavailable', async () => {
      // First call (direct TAF) returns empty
      // Second call (nearby candidate) returns TAF
      const mockTaf = { icaoId: 'KDEN', rawTAF: 'TAF KDEN ...' };
      let callCount = 0;
      mockHttp.get.mockImplementation(() => {
        callCount++;
        if (callCount === 1) return of({ data: [] }); // No direct TAF
        return of({ data: [mockTaf] }); // Nearby TAF
      });

      mockAirportsService.findById.mockResolvedValue({
        identifier: 'APA',
        icao_identifier: 'KAPA',
        latitude: 39.57,
        longitude: -104.85,
      });

      mockAirportsService.findNearby.mockResolvedValue([
        {
          identifier: 'DEN',
          icao_identifier: 'KDEN',
          distance_nm: 18.5,
        },
      ]);

      const result = await service.getNearestTaf('KAPA');
      expect(result.taf).toEqual(mockTaf);
      expect(result.isNearby).toBe(true);
      expect(result.station).toBe('KDEN');
      expect(result.distanceNm).toBe(18.5);
    });

    it('should return null taf when no nearby TAF found', async () => {
      mockHttp.get.mockReturnValue(of({ data: [] }));
      mockAirportsService.findById.mockResolvedValue({
        identifier: 'APA',
        latitude: 39.57,
        longitude: -104.85,
      });
      mockAirportsService.findNearby.mockResolvedValue([]);

      const result = await service.getNearestTaf('KAPA');
      expect(result.taf).toBeNull();
      expect(result.station).toBeNull();
    });
  });

  // --- Bulk METARs ---

  describe('getBulkMetars', () => {
    it('should deduplicate METARs by station', async () => {
      const data = [
        { icaoId: 'KAPA', obsTime: 100, rawOb: 'old' },
        { icaoId: 'KAPA', obsTime: 200, rawOb: 'new' },
        { icaoId: 'KDEN', obsTime: 150, rawOb: 'den' },
      ];
      mockHttp.get.mockReturnValue(of({ data }));

      const result = await service.getBulkMetars({
        minLat: 39,
        maxLat: 40,
        minLng: -105,
        maxLng: -104,
      });

      expect(result).toHaveLength(2);
      const apa = result.find((m: any) => m.icaoId === 'KAPA');
      expect(apa.rawOb).toBe('new'); // Should keep latest
    });

    it('should return empty array on error', async () => {
      mockHttp.get.mockReturnValue(
        throwError(() => new Error('Network error')),
      );

      const result = await service.getBulkMetars({
        minLat: 39,
        maxLat: 40,
        minLng: -105,
        maxLng: -104,
      });

      expect(result).toEqual([]);
    });
  });

  // --- NOTAMs ---

  describe('getNotams', () => {
    it('should filter out cancelled/expired NOTAMs', async () => {
      const notamData = {
        notamList: [
          {
            notamNumber: '01/001',
            keyword: 'RWY',
            cancelledOrExpired: false,
            traditionalMessageFrom4thWord: 'RWY 17/35 CLSD',
            startDate: '03/15/2025 0800',
            endDate: '03/20/2025 1700',
            featureName: 'RUNWAY',
          },
          {
            notamNumber: '01/002',
            keyword: 'AD',
            cancelledOrExpired: true,
            traditionalMessageFrom4thWord: 'EXPIRED NOTAM',
          },
        ],
      };
      mockHttp.post.mockReturnValue(of({ data: notamData }));
      mockAirportsService.findById.mockResolvedValue({
        identifier: 'APA',
      });

      const result = await service.getNotams('KAPA');
      expect(result.count).toBe(1);
      expect(result.notams).toHaveLength(1);
      expect(result.notams[0].id).toBe('01/001');
    });

    it('should map NOTAM fields correctly', async () => {
      const notamData = {
        notamList: [
          {
            notamNumber: '01/001',
            keyword: 'RWY',
            cancelledOrExpired: false,
            traditionalMessageFrom4thWord: 'RWY 17/35 CLSD',
            traditionalMessage: 'FULL TEXT HERE',
            startDate: '03/15/2025 0800',
            endDate: '03/20/2025 1700',
            featureName: 'RUNWAY',
            icaoId: 'KAPA',
            facilityDesignator: 'APA',
          },
        ],
      };
      mockHttp.post.mockReturnValue(of({ data: notamData }));
      mockAirportsService.findById.mockResolvedValue({
        identifier: 'APA',
      });

      const result = await service.getNotams('KAPA');
      const notam = result.notams[0];

      expect(notam.id).toBe('01/001');
      expect(notam.type).toBe('RWY');
      expect(notam.text).toBe('RWY 17/35 CLSD');
      expect(notam.fullText).toBe('FULL TEXT HERE');
      expect(notam.effectiveStart).toBe('2025-03-15T08:00:00Z');
      expect(notam.effectiveEnd).toBe('2025-03-20T17:00:00Z');
      expect(notam.classification).toBe('RUNWAY');
    });

    it('should return error result on HTTP failure', async () => {
      mockHttp.post.mockReturnValue(
        throwError(() => new Error('timeout')),
      );
      mockAirportsService.findById.mockResolvedValue({
        identifier: 'APA',
      });

      const result = await service.getNotams('KAPA');
      expect(result.count).toBe(0);
      expect(result.notams).toEqual([]);
      expect(result.error).toBeDefined();
    });

    it('should use FAA 3-letter identifier for NOTAM search', async () => {
      mockHttp.post.mockReturnValue(of({ data: { notamList: [] } }));
      mockAirportsService.findById.mockResolvedValue({
        identifier: 'APA',
        icao_identifier: 'KAPA',
      });

      await service.getNotams('KAPA');

      const postCall = mockHttp.post.mock.calls[0];
      const body = postCall[1] as string;
      expect(body).toContain('designatorsForLocation=APA');
    });
  });

  // --- Winds aloft full flow ---

  describe('getWindsAloft', () => {
    it('should return empty forecasts when airport not found', async () => {
      mockAirportsService.findById.mockResolvedValue(null);

      const result = await service.getWindsAloft('KAPA');
      expect(result.station).toBeNull();
      expect(result.forecasts).toEqual([]);
    });

    it('should search nearby stations when direct station has no data', async () => {
      mockAirportsService.findById.mockResolvedValue({
        identifier: 'APA',
        latitude: 39.57,
        longitude: -104.85,
      });

      // Return empty winds data for all periods
      mockHttp.get.mockReturnValue(of({ data: 'FT  3000\n' }));

      mockAirportsService.findNearby.mockResolvedValue([
        { identifier: 'DEN', distance_nm: 18.5 },
      ]);

      const result = await service.getWindsAloft('KAPA');
      // Falls through to no data found
      expect(result.forecasts).toBeDefined();
    });
  });
});
