import { Test, TestingModule } from '@nestjs/testing';
import { HttpService } from '@nestjs/axios';
import { getRepositoryToken } from '@nestjs/typeorm';
import { WeatherService } from './weather.service';
import { AirportsService } from '../airports/airports.service';
import { WeatherStation } from './entities/weather-station.entity';
import { AtisRecording } from './entities/atis-recording.entity';
import { AtisTranscriptionService } from './atis-transcription.service';
import { Metar } from '../data-platform/entities/metar.entity';
import { Taf } from '../data-platform/entities/taf.entity';
import { WindsAloft } from '../data-platform/entities/winds-aloft.entity';
import { Notam } from '../data-platform/entities/notam.entity';
import { NwsForecast } from '../data-platform/entities/nws-forecast.entity';
import { Atis } from '../data-platform/entities/atis.entity';

describe('WeatherService', () => {
  let service: WeatherService;
  let airportsService: any;
  let metarRepo: any;
  let windsAloftRepo: any;

  beforeEach(async () => {
    airportsService = {
      findById: jest.fn(),
      findNearby: jest.fn(),
    };
    metarRepo = { findOne: jest.fn() };
    windsAloftRepo = { find: jest.fn() };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        WeatherService,
        { provide: HttpService, useValue: {} },
        { provide: AirportsService, useValue: airportsService },
        { provide: getRepositoryToken(WeatherStation), useValue: {} },
        { provide: getRepositoryToken(AtisRecording), useValue: {} },
        { provide: AtisTranscriptionService, useValue: {} },
        { provide: getRepositoryToken(Metar), useValue: metarRepo },
        { provide: getRepositoryToken(Taf), useValue: { findOne: jest.fn() } },
        { provide: getRepositoryToken(WindsAloft), useValue: windsAloftRepo },
        { provide: getRepositoryToken(Notam), useValue: {} },
        { provide: getRepositoryToken(NwsForecast), useValue: {} },
        { provide: getRepositoryToken(Atis), useValue: {} },
      ],
    }).compile();

    service = module.get<WeatherService>(WeatherService);
  });

  describe('getMetar', () => {
    it('should return null when no row exists', async () => {
      metarRepo.findOne.mockResolvedValue(null);
      await expect(service.getMetar('KAPA')).resolves.toBeNull();
    });

    it('should return raw data with _meta when row exists', async () => {
      metarRepo.findOne.mockResolvedValue({
        icao_id: 'KAPA',
        updated_at: new Date('2026-02-14T00:00:00.000Z'),
        raw_data: { raw: 'METAR KAPA ...', icao_id: 'KAPA' },
      });

      const result = await service.getMetar('KAPA');
      expect(result.icao_id).toBe('KAPA');
      expect(result._meta).toBeDefined();
      expect(result._meta.updatedAt).toBe('2026-02-14T00:00:00.000Z');
    });
  });

  describe('getWindsAloft', () => {
    it('should return empty response when airport lookup fails', async () => {
      airportsService.findById.mockResolvedValue(null);
      const result = await service.getWindsAloft('KAPA');
      expect(result.station).toBeNull();
      expect(result.forecasts).toEqual([]);
    });

    it('should use direct station if present', async () => {
      airportsService.findById.mockResolvedValue({
        identifier: 'APA',
        latitude: 39.57,
        longitude: -104.85,
      });
      windsAloftRepo.find.mockResolvedValue([
        {
          station_code: 'APA',
          forecast_period: '06',
          altitudes: [{ altitude: 3000, direction: 250, speed: 20 }],
          updated_at: new Date('2026-02-14T00:00:00.000Z'),
        },
      ]);

      const result = await service.getWindsAloft('KAPA');
      expect(result.station).toBe('APA');
      expect(result.isNearby).toBe(false);
      const fcst06 = result.forecasts.find((f: any) => f.period === '06');
      expect(fcst06.altitudes.length).toBe(1);
    });

    it('should fall back to nearby station when direct is missing', async () => {
      airportsService.findById.mockResolvedValue({
        identifier: 'APA',
        latitude: 39.57,
        longitude: -104.85,
      });

      windsAloftRepo.find.mockImplementation(async ({ where }: any) => {
        if (where.station_code === 'APA') return [];
        if (where.station_code === 'DEN') {
          return [
            {
              station_code: 'DEN',
              forecast_period: '12',
              altitudes: [{ altitude: 6000, direction: 270, speed: 35 }],
              updated_at: new Date('2026-02-14T00:00:00.000Z'),
            },
          ];
        }
        return [];
      });

      airportsService.findNearby.mockResolvedValue([
        { identifier: 'DEN', distance_nm: 18.2 },
      ]);

      const result = await service.getWindsAloft('KAPA');
      expect(result.station).toBe('DEN');
      expect(result.isNearby).toBe(true);
      expect(result.distanceNm).toBe(18.2);
      const fcst12 = result.forecasts.find((f: any) => f.period === '12');
      expect(fcst12.altitudes.length).toBe(1);
    });
  });
});

