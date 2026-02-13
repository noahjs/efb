import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { NotFoundException } from '@nestjs/common';
import { FlightsService } from './flights.service';
import { Flight } from './entities/flight.entity';
import {
  CalculateService,
  CalculateResult,
} from '../calculate/calculate.service';

describe('FlightsService', () => {
  let service: FlightsService;
  let mockFlightRepo: any;
  let mockCalculateService: any;

  const mockCalculateResult: CalculateResult = {
    distance_nm: 120.5,
    ete_minutes: 60,
    flight_fuel_gallons: 10.2,
    eta: '2025-03-15T15:00:00.000Z',
    wind_component: -8.5,
    calculation_method: 'single_phase',
    phases: null,
    waypoints: [
      {
        identifier: 'APA',
        latitude: 39.57,
        longitude: -104.85,
        type: 'airport',
      },
      {
        identifier: 'DEN',
        latitude: 39.86,
        longitude: -104.67,
        type: 'airport',
      },
    ],
    calculated_at: '2025-03-15T14:00:00.000Z',
  };

  const mockFlight: Partial<Flight> = {
    id: 1,
    departure_identifier: 'APA',
    destination_identifier: 'DEN',
    alternate_identifier: 'BJC',
    etd: '2025-03-15T14:00:00Z',
    aircraft_identifier: 'N12345',
    aircraft_type: 'TBM 960',
    true_airspeed: 120,
    flight_rules: 'IFR',
    route_string: 'APA V389 DEN',
    cruise_altitude: 10000,
    people_count: 2,
    avg_person_weight: 170,
    cargo_weight: 50,
    fuel_burn_rate: 10,
    start_fuel_gallons: 48,
    reserve_fuel_gallons: 5,
    filing_status: 'not_filed',
    performance_profile_id: 1,
  };

  beforeEach(async () => {
    const mockQb = {
      where: jest.fn().mockReturnThis(),
      andWhere: jest.fn().mockReturnThis(),
      orderBy: jest.fn().mockReturnThis(),
      addOrderBy: jest.fn().mockReturnThis(),
      skip: jest.fn().mockReturnThis(),
      take: jest.fn().mockReturnThis(),
      getManyAndCount: jest.fn().mockResolvedValue([[{ ...mockFlight }], 1]),
    };

    mockFlightRepo = {
      findOne: jest.fn().mockResolvedValue({ ...mockFlight }),
      create: jest.fn().mockImplementation((dto) => ({ ...dto })),
      save: jest
        .fn()
        .mockImplementation((flight) =>
          Promise.resolve({ ...flight, id: flight.id ?? 2 }),
        ),
      remove: jest.fn().mockImplementation((flight) => Promise.resolve(flight)),
      createQueryBuilder: jest.fn().mockReturnValue(mockQb),
    };

    mockCalculateService = {
      calculate: jest.fn().mockResolvedValue({ ...mockCalculateResult }),
      calculateDebug: jest.fn().mockResolvedValue({
        ...mockCalculateResult,
        steps: [{ label: 'Test', value: 'test' }],
      }),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        FlightsService,
        { provide: getRepositoryToken(Flight), useValue: mockFlightRepo },
        { provide: CalculateService, useValue: mockCalculateService },
      ],
    }).compile();

    service = module.get<FlightsService>(FlightsService);
  });

  // --- findAll ---

  describe('findAll', () => {
    it('should return paginated results', async () => {
      const result = await service.findAll('test-user');
      expect(result.items).toHaveLength(1);
      expect(result.total).toBe(1);
      expect(result.limit).toBe(50);
      expect(result.offset).toBe(0);
    });

    it('should apply query filter when provided', async () => {
      const mockQb = mockFlightRepo.createQueryBuilder();
      await service.findAll('test-user', 'KAPA');
      expect(mockQb.where).toHaveBeenCalled();
    });

    it('should respect custom limit and offset', async () => {
      const mockQb = mockFlightRepo.createQueryBuilder();
      await service.findAll('test-user', undefined, 10, 20);
      expect(mockQb.skip).toHaveBeenCalledWith(20);
      expect(mockQb.take).toHaveBeenCalledWith(10);
    });
  });

  // --- findById ---

  describe('findById', () => {
    it('should return flight when found', async () => {
      const result = await service.findById(1);
      expect(result.id).toBe(1);
      expect(result.departure_identifier).toBe('APA');
    });

    it('should throw NotFoundException when not found', async () => {
      mockFlightRepo.findOne.mockResolvedValue(null);
      await expect(service.findById(999)).rejects.toThrow(NotFoundException);
    });
  });

  // --- create ---

  describe('create', () => {
    it('should create a flight and run calculation', async () => {
      const dto = {
        departure_identifier: 'APA',
        destination_identifier: 'DEN',
        true_airspeed: 120,
      };

      const result = await service.create(dto as any);

      expect(mockFlightRepo.create).toHaveBeenCalledWith(dto);
      expect(mockCalculateService.calculate).toHaveBeenCalledTimes(1);
      expect(mockFlightRepo.save).toHaveBeenCalledTimes(1);
    });

    it('should populate computed fields from calculation', async () => {
      const dto = {
        departure_identifier: 'APA',
        destination_identifier: 'DEN',
        true_airspeed: 120,
      };

      await service.create(dto as any);

      const savedFlight = mockFlightRepo.save.mock.calls[0][0];
      expect(savedFlight.distance_nm).toBe(120.5);
      expect(savedFlight.ete_minutes).toBe(60);
      expect(savedFlight.flight_fuel_gallons).toBe(10.2);
      expect(savedFlight.eta).toBe('2025-03-15T15:00:00.000Z');
      expect(savedFlight.wind_component).toBe(-8.5);
    });

    it('should pass correct fields to calculate service', async () => {
      const dto = {
        departure_identifier: 'APA',
        destination_identifier: 'DEN',
        route_string: 'V389',
        cruise_altitude: 10000,
        true_airspeed: 120,
        fuel_burn_rate: 10,
        etd: '2025-03-15T14:00:00Z',
        performance_profile_id: 1,
      };

      await service.create(dto as any);

      expect(mockCalculateService.calculate).toHaveBeenCalledWith({
        departure_identifier: 'APA',
        destination_identifier: 'DEN',
        route_string: 'V389',
        cruise_altitude: 10000,
        true_airspeed: 120,
        fuel_burn_rate: 10,
        etd: '2025-03-15T14:00:00Z',
        performance_profile_id: 1,
      });
    });
  });

  // --- update ---

  describe('update', () => {
    it('should update an existing flight and recalculate', async () => {
      const dto = { true_airspeed: 150 };
      await service.update(1, dto as any);

      expect(mockFlightRepo.findOne).toHaveBeenCalledWith({ where: { id: 1 } });
      expect(mockCalculateService.calculate).toHaveBeenCalledTimes(1);
      expect(mockFlightRepo.save).toHaveBeenCalledTimes(1);
    });

    it('should throw NotFoundException when updating non-existent flight', async () => {
      mockFlightRepo.findOne.mockResolvedValue(null);
      await expect(
        service.update(999, { true_airspeed: 150 } as any),
      ).rejects.toThrow(NotFoundException);
    });

    it('should merge updated fields into existing flight', async () => {
      const dto = { true_airspeed: 150, cruise_altitude: 12000 };
      await service.update(1, dto as any);

      const savedFlight = mockFlightRepo.save.mock.calls[0][0];
      expect(savedFlight.true_airspeed).toBe(150);
      expect(savedFlight.cruise_altitude).toBe(12000);
      // Original fields preserved
      expect(savedFlight.departure_identifier).toBe('APA');
    });
  });

  // --- remove ---

  describe('remove', () => {
    it('should remove an existing flight', async () => {
      await service.remove(1);
      expect(mockFlightRepo.remove).toHaveBeenCalledTimes(1);
    });

    it('should throw NotFoundException when removing non-existent flight', async () => {
      mockFlightRepo.findOne.mockResolvedValue(null);
      await expect(service.remove(999)).rejects.toThrow(NotFoundException);
    });
  });

  // --- copy ---

  describe('copy', () => {
    it('should create a copy with filing_status reset to not_filed', async () => {
      // Source flight is "filed"
      mockFlightRepo.findOne.mockResolvedValue({
        ...mockFlight,
        filing_status: 'filed',
        filing_reference: 'FP1001',
      });

      await service.copy(1);

      const createdFlight = mockFlightRepo.create.mock.calls[0][0];
      expect(createdFlight.filing_status).toBe('not_filed');
    });

    it('should copy route and aircraft fields', async () => {
      await service.copy(1);

      const createdFlight = mockFlightRepo.create.mock.calls[0][0];
      expect(createdFlight.departure_identifier).toBe('APA');
      expect(createdFlight.destination_identifier).toBe('DEN');
      expect(createdFlight.route_string).toBe('APA V389 DEN');
      expect(createdFlight.aircraft_identifier).toBe('N12345');
      expect(createdFlight.cruise_altitude).toBe(10000);
    });

    it('should copy weight and fuel fields', async () => {
      await service.copy(1);

      const createdFlight = mockFlightRepo.create.mock.calls[0][0];
      expect(createdFlight.people_count).toBe(2);
      expect(createdFlight.avg_person_weight).toBe(170);
      expect(createdFlight.cargo_weight).toBe(50);
      expect(createdFlight.start_fuel_gallons).toBe(48);
      expect(createdFlight.fuel_burn_rate).toBe(10);
    });

    it('should not copy the source flight id', async () => {
      await service.copy(1);

      const createdFlight = mockFlightRepo.create.mock.calls[0][0];
      expect(createdFlight.id).toBeUndefined();
    });

    it('should run calculation on copied flight', async () => {
      await service.copy(1);
      expect(mockCalculateService.calculate).toHaveBeenCalledTimes(1);
    });

    it('should throw NotFoundException when copying non-existent flight', async () => {
      mockFlightRepo.findOne.mockResolvedValue(null);
      await expect(service.copy(999)).rejects.toThrow(NotFoundException);
    });
  });

  // --- calculateDebug ---

  describe('calculateDebug', () => {
    it('should return debug result with steps', async () => {
      const result = await service.calculateDebug(1);
      expect(result.steps).toBeDefined();
      expect(result.steps.length).toBeGreaterThan(0);
    });

    it('should throw NotFoundException for non-existent flight', async () => {
      mockFlightRepo.findOne.mockResolvedValue(null);
      await expect(service.calculateDebug(999)).rejects.toThrow(
        NotFoundException,
      );
    });
  });
});
