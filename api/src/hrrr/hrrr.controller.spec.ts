import { Test, TestingModule } from '@nestjs/testing';
import { BadRequestException } from '@nestjs/common';
import { HrrrController } from './hrrr.controller';
import { HrrrService } from './hrrr.service';
import { HrrrTileService } from './hrrr-tile.service';

describe('HrrrController', () => {
  let controller: HrrrController;
  let mockService: any;
  let mockTileService: any;

  beforeEach(async () => {
    mockService = {
      getCycles: jest.fn().mockResolvedValue({
        active_cycle: new Date('2026-02-13T12:00:00Z'),
        cycles: [],
      }),
      getMeta: jest.fn().mockResolvedValue({
        model: 'hrrr',
        latest_init: new Date('2026-02-13T12:00:00Z'),
        products: {},
      }),
      getRouteWeather: jest.fn().mockResolvedValue({
        model: 'hrrr',
        init_time: new Date('2026-02-13T12:00:00Z'),
        waypoints: [],
      }),
      getRouteProfile: jest.fn().mockResolvedValue({
        model: 'hrrr',
        init_time: new Date('2026-02-13T12:00:00Z'),
        waypoints: [],
      }),
      compareWinds: jest.fn().mockResolvedValue({
        lat: 39,
        lng: -105,
        hrrr: null,
        open_meteo: null,
      }),
    };

    const pngBuf = Buffer.from([0x89, 0x50, 0x4e, 0x47]); // fake PNG header
    mockTileService = {
      renderTile: jest.fn().mockResolvedValue(pngBuf),
    };

    const module: TestingModule = await Test.createTestingModule({
      controllers: [HrrrController],
      providers: [
        { provide: HrrrService, useValue: mockService },
        { provide: HrrrTileService, useValue: mockTileService },
      ],
    }).compile();

    controller = module.get<HrrrController>(HrrrController);
  });

  // --- getCycles ---

  describe('getCycles', () => {
    it('should call service with default limit', async () => {
      await controller.getCycles(10);
      expect(mockService.getCycles).toHaveBeenCalledWith(10);
    });

    it('should pass custom limit to service', async () => {
      await controller.getCycles(5);
      expect(mockService.getCycles).toHaveBeenCalledWith(5);
    });

    it('should return the service response', async () => {
      const result = await controller.getCycles(10);
      expect(result.active_cycle).toBeDefined();
    });
  });

  // --- getMeta ---

  describe('getMeta', () => {
    it('should call service getMeta', async () => {
      const result = await controller.getMeta();

      expect(mockService.getMeta).toHaveBeenCalled();
      expect(result.model).toBe('hrrr');
    });
  });

  // --- getRouteWeather ---

  describe('getRouteWeather', () => {
    it('should parse valid waypoints JSON and call service', async () => {
      const waypointsJson = '[{"lat":39,"lng":-105},{"lat":38,"lng":-104}]';

      await controller.getRouteWeather(waypointsJson, 8000);

      expect(mockService.getRouteWeather).toHaveBeenCalledWith(
        [
          { lat: 39, lng: -105 },
          { lat: 38, lng: -104 },
        ],
        8000,
      );
    });

    it('should throw BadRequestException for missing waypoints', () => {
      expect(() => controller.getRouteWeather(undefined as any, 8000)).toThrow(
        BadRequestException,
      );
    });

    it('should throw BadRequestException for empty string waypoints', () => {
      expect(() => controller.getRouteWeather('', 8000)).toThrow(
        BadRequestException,
      );
    });

    it('should throw BadRequestException for invalid JSON', () => {
      expect(() => controller.getRouteWeather('not-json', 8000)).toThrow(
        BadRequestException,
      );
    });

    it('should throw BadRequestException for non-array JSON', () => {
      expect(() => controller.getRouteWeather('{"lat":39}', 8000)).toThrow(
        BadRequestException,
      );
    });

    it('should throw BadRequestException for empty array', () => {
      expect(() => controller.getRouteWeather('[]', 8000)).toThrow(
        BadRequestException,
      );
    });

    it('should throw BadRequestException for waypoints without lat/lng', () => {
      expect(() =>
        controller.getRouteWeather('[{"x":39,"y":-105}]', 8000),
      ).toThrow(BadRequestException);
    });

    it('should throw BadRequestException for non-numeric lat/lng', () => {
      expect(() =>
        controller.getRouteWeather('[{"lat":"abc","lng":-105}]', 8000),
      ).toThrow(BadRequestException);
    });

    it('should handle string numbers in waypoints', async () => {
      // JSON might have string values that are actually numbers
      const waypointsJson = '[{"lat":"39.5","lng":"-104.8"}]';

      await controller.getRouteWeather(waypointsJson, 8000);

      expect(mockService.getRouteWeather).toHaveBeenCalledWith(
        [{ lat: 39.5, lng: -104.8 }],
        8000,
      );
    });

    it('should handle decimal lat/lng', async () => {
      const waypointsJson = '[{"lat":39.8617,"lng":-104.6731}]';

      await controller.getRouteWeather(waypointsJson, 5000);

      expect(mockService.getRouteWeather).toHaveBeenCalledWith(
        [{ lat: 39.8617, lng: -104.6731 }],
        5000,
      );
    });
  });

  // --- getRouteProfile ---

  describe('getRouteProfile', () => {
    it('should parse waypoints and call service', async () => {
      const waypointsJson = '[{"lat":39,"lng":-105}]';

      await controller.getRouteProfile(waypointsJson);

      expect(mockService.getRouteProfile).toHaveBeenCalledWith([
        { lat: 39, lng: -105 },
      ]);
    });

    it('should throw BadRequestException for invalid waypoints', () => {
      expect(() => controller.getRouteProfile('invalid')).toThrow(
        BadRequestException,
      );
    });

    it('should throw BadRequestException for missing waypoints', () => {
      expect(() => controller.getRouteProfile(undefined as any)).toThrow(
        BadRequestException,
      );
    });
  });

  // --- compareWinds ---

  describe('compareWinds', () => {
    it('should pass lat/lng to service', async () => {
      await controller.compareWinds(39.5, -104.8);

      expect(mockService.compareWinds).toHaveBeenCalledWith(39.5, -104.8);
    });

    it('should return service response', async () => {
      const result = await controller.compareWinds(39, -105);

      expect(result.lat).toBe(39);
      expect(result.lng).toBe(-105);
    });
  });

  // --- getTile ---

  describe('getTile', () => {
    const mockRes = () => {
      const res: any = {};
      res.set = jest.fn().mockReturnValue(res);
      res.send = jest.fn().mockReturnValue(res);
      return res;
    };

    it('should return PNG for valid tile request', async () => {
      const res = mockRes();
      await controller.getTile('flight-cat', '4', '3', '5.png', 1, 850, res);

      expect(mockTileService.renderTile).toHaveBeenCalledWith(
        'flight-cat',
        4,
        3,
        5,
        1,
        undefined,
      );
      expect(res.set).toHaveBeenCalledWith(
        expect.objectContaining({ 'Content-Type': 'image/png' }),
      );
      expect(res.send).toHaveBeenCalled();
    });

    it('should throw BadRequestException for invalid product', async () => {
      const res = mockRes();
      await expect(
        controller.getTile('invalid-product', '4', '3', '5.png', 1, 850, res),
      ).rejects.toThrow(BadRequestException);
    });

    it('should throw BadRequestException for zoom out of range', async () => {
      const res = mockRes();
      await expect(
        controller.getTile('flight-cat', '1', '0', '0.png', 1, 850, res),
      ).rejects.toThrow(BadRequestException);

      await expect(
        controller.getTile('flight-cat', '10', '0', '0.png', 1, 850, res),
      ).rejects.toThrow(BadRequestException);
    });

    it('should throw BadRequestException for invalid y.png format', async () => {
      const res = mockRes();
      await expect(
        controller.getTile('flight-cat', '4', '3', '5.jpg', 1, 850, res),
      ).rejects.toThrow(BadRequestException);
    });

    it('should throw BadRequestException for invalid forecast hour', async () => {
      const res = mockRes();
      await expect(
        controller.getTile('flight-cat', '4', '3', '5.png', -1, 850, res),
      ).rejects.toThrow(BadRequestException);

      await expect(
        controller.getTile('flight-cat', '4', '3', '5.png', 19, 850, res),
      ).rejects.toThrow(BadRequestException);
    });

    it('should default forecast hour to 1', async () => {
      const res = mockRes();
      await controller.getTile('flight-cat', '4', '3', '5.png', 1, 850, res);

      expect(mockTileService.renderTile).toHaveBeenCalledWith(
        'flight-cat',
        4,
        3,
        5,
        1,
        undefined,
      );
    });

    it('should pass level to renderTile for clouds product', async () => {
      const res = mockRes();
      await controller.getTile('clouds', '4', '3', '5.png', 1, 700, res);

      expect(mockTileService.renderTile).toHaveBeenCalledWith(
        'clouds',
        4,
        3,
        5,
        1,
        700,
      );
    });

    it('should default level to 850 for clouds product', async () => {
      const res = mockRes();
      await controller.getTile('clouds', '4', '3', '5.png', 1, 850, res);

      expect(mockTileService.renderTile).toHaveBeenCalledWith(
        'clouds',
        4,
        3,
        5,
        1,
        850,
      );
    });

    it('should throw BadRequestException for invalid pressure level on clouds', async () => {
      const res = mockRes();
      await expect(
        controller.getTile('clouds', '4', '3', '5.png', 1, 999, res),
      ).rejects.toThrow(BadRequestException);
    });

    it('should not validate level for non-clouds products', async () => {
      const res = mockRes();
      // 999 is invalid pressure level, but should be ignored for non-clouds products
      await controller.getTile('flight-cat', '4', '3', '5.png', 1, 999, res);
      expect(res.send).toHaveBeenCalled();
    });
  });
});
