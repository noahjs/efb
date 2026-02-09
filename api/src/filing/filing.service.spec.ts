import { Test, TestingModule } from '@nestjs/testing';
import { FilingService } from './filing.service';
import { FlightsService } from '../flights/flights.service';
import { AircraftService } from '../aircraft/aircraft.service';
import { UsersService } from '../users/users.service';
import { AirportsService } from '../airports/airports.service';

describe('FilingService', () => {
  let service: FilingService;
  let mockFlightsService: Partial<FlightsService>;
  let mockAircraftService: Partial<AircraftService>;
  let mockUsersService: Partial<UsersService>;
  let mockAirportsService: Partial<AirportsService>;
  let mockLeidosClient: any;

  const mockFlight = {
    id: 1,
    aircraft_id: 10,
    aircraft_identifier: 'N12345',
    aircraft_type: 'Cessna 172',
    departure_identifier: 'APA',
    destination_identifier: 'DEN',
    alternate_identifier: 'BJC',
    etd: '2025-03-15T14:00:00Z',
    flight_rules: 'IFR',
    route_string: 'APA V389 DEN',
    cruise_altitude: 10000,
    true_airspeed: 120,
    people_count: 2,
    ete_minutes: 45,
    filing_status: 'not_filed',
    filing_reference: null,
    filing_version_stamp: null,
    fuel_burn_rate: 8.5,
    start_fuel_gallons: 48,
  };

  const mockAircraft = {
    id: 10,
    icao_type_code: 'C172',
    color: 'White/Blue',
    equipment: { equipment_codes: 'SG/C' },
  };

  const mockUser = {
    id: '00000000-0000-0000-0000-000000000001',
    name: 'Test Pilot',
    pilot_name: 'John Doe',
    phone_number: '555-1234',
    leidos_username: 'jdoe',
  };

  beforeEach(async () => {
    mockFlightsService = {
      findById: jest.fn().mockResolvedValue({ ...mockFlight }),
      update: jest.fn().mockResolvedValue({ ...mockFlight }),
    };

    mockAircraftService = {
      findOne: jest.fn().mockResolvedValue({ ...mockAircraft }),
    };

    mockUsersService = {
      getDemoUser: jest.fn().mockResolvedValue({ ...mockUser }),
    };

    mockAirportsService = {
      findById: jest.fn().mockImplementation(async (id: string) => {
        const airports: Record<string, any> = {
          APA: { identifier: 'APA', icao_identifier: 'KAPA' },
          DEN: { identifier: 'DEN', icao_identifier: 'KDEN' },
          BJC: { identifier: 'BJC', icao_identifier: 'KBJC' },
        };
        return airports[id] || null;
      }),
    };

    mockLeidosClient = {
      fileFlightPlan: jest.fn().mockResolvedValue({
        success: true,
        flightIdentifier: 'FP1001',
        versionStamp: 'v123',
        message: 'Filed successfully',
      }),
      amendFlightPlan: jest.fn().mockResolvedValue({
        success: true,
        flightIdentifier: 'FP1001',
        versionStamp: 'v124',
        message: 'Amended successfully',
      }),
      cancelFlightPlan: jest.fn().mockResolvedValue({
        success: true,
        flightIdentifier: 'FP1001',
        versionStamp: '',
        message: 'Cancelled',
      }),
      closeFlightPlan: jest.fn().mockResolvedValue({
        success: true,
        flightIdentifier: 'FP1001',
        versionStamp: '',
        message: 'Closed',
      }),
      getFlightPlanStatus: jest.fn().mockResolvedValue({
        flightIdentifier: 'FP1001',
        status: 'filed',
        versionStamp: 'v123',
      }),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        FilingService,
        { provide: FlightsService, useValue: mockFlightsService },
        { provide: AircraftService, useValue: mockAircraftService },
        { provide: UsersService, useValue: mockUsersService },
        { provide: AirportsService, useValue: mockAirportsService },
        { provide: 'LEIDOS_CLIENT', useValue: mockLeidosClient },
      ],
    }).compile();

    service = module.get<FilingService>(FilingService);
  });

  // --- Validation ---

  describe('validateForFiling', () => {
    it('should return ready=true when all required fields are present', async () => {
      const result = await service.validateForFiling(1);
      expect(result.ready).toBe(true);
      expect(result.checks.every((c) => c.severity === 'error' ? c.passed : true)).toBe(true);
    });

    it('should fail when aircraft_identifier is missing', async () => {
      (mockFlightsService.findById as jest.Mock).mockResolvedValue({
        ...mockFlight,
        aircraft_identifier: null,
      });

      const result = await service.validateForFiling(1);
      expect(result.ready).toBe(false);
      const check = result.checks.find((c) => c.field === 'aircraft_identifier');
      expect(check?.passed).toBe(false);
    });

    it('should fail when pilot_name is missing', async () => {
      (mockUsersService.getDemoUser as jest.Mock).mockResolvedValue({
        ...mockUser,
        pilot_name: null,
      });

      const result = await service.validateForFiling(1);
      expect(result.ready).toBe(false);
      const check = result.checks.find((c) => c.field === 'pilot_name');
      expect(check?.passed).toBe(false);
    });

    it('should warn (not fail) when alternate is missing', async () => {
      (mockFlightsService.findById as jest.Mock).mockResolvedValue({
        ...mockFlight,
        alternate_identifier: null,
      });

      const result = await service.validateForFiling(1);
      expect(result.ready).toBe(true);
      const check = result.checks.find((c) => c.field === 'alternate_identifier');
      expect(check?.passed).toBe(false);
      expect(check?.severity).toBe('warning');
    });

    it('should fail when ETE is not computed', async () => {
      (mockFlightsService.findById as jest.Mock).mockResolvedValue({
        ...mockFlight,
        ete_minutes: null,
      });

      const result = await service.validateForFiling(1);
      expect(result.ready).toBe(false);
      const check = result.checks.find((c) => c.field === 'ete_minutes');
      expect(check?.passed).toBe(false);
    });
  });

  // --- ICAO Transformation ---

  describe('formatSpeed', () => {
    it('should format 120kt as N0120', () => {
      expect(service.formatSpeed(120)).toBe('N0120');
    });

    it('should format 85kt as N0085', () => {
      expect(service.formatSpeed(85)).toBe('N0085');
    });
  });

  describe('formatLevel', () => {
    it('should format 18000 as F180', () => {
      expect(service.formatLevel(18000)).toBe('F180');
    });

    it('should format 35000 as F350', () => {
      expect(service.formatLevel(35000)).toBe('F350');
    });

    it('should format 10000 as A100', () => {
      expect(service.formatLevel(10000)).toBe('A100');
    });

    it('should format 4500 as A045', () => {
      expect(service.formatLevel(4500)).toBe('A045');
    });
  });

  describe('formatMinutesToHHMM', () => {
    it('should format 90 minutes as 0130', () => {
      expect(service.formatMinutesToHHMM(90)).toBe('0130');
    });

    it('should format 45 minutes as 0045', () => {
      expect(service.formatMinutesToHHMM(45)).toBe('0045');
    });

    it('should format 125 minutes as 0205', () => {
      expect(service.formatMinutesToHHMM(125)).toBe('0205');
    });
  });

  describe('formatHoursToHHMM', () => {
    it('should format 5.5 hours as 0530', () => {
      expect(service.formatHoursToHHMM(5.5)).toBe('0530');
    });

    it('should format 2.75 hours as 0245', () => {
      expect(service.formatHoursToHHMM(2.75)).toBe('0245');
    });
  });

  describe('buildIcaoFlightPlan', () => {
    it('should map flight data to ICAO fields', async () => {
      const plan = await service.buildIcaoFlightPlan(mockFlight as any);

      expect(plan.aircraftId).toBe('N12345');
      expect(plan.flightRules).toBe('I');
      expect(plan.flightType).toBe('G');
      expect(plan.aircraftType).toBe('C172');
      expect(plan.equipmentCodes).toBe('SG/C');
      expect(plan.departureIcao).toBe('KAPA');
      expect(plan.destinationIcao).toBe('KDEN');
      expect(plan.alternateIcao).toBe('KBJC');
      expect(plan.cruisingSpeed).toBe('N0120');
      expect(plan.cruisingLevel).toBe('A100');
      expect(plan.route).toBe('APA V389 DEN');
      expect(plan.totalEet).toBe('0045');
      expect(plan.pilotInCommand).toBe('John Doe');
      expect(plan.personsOnBoard).toBe(2);
      expect(plan.aircraftColor).toBe('White/Blue');
    });
  });

  // --- State Machine ---

  describe('fileFlight', () => {
    it('should file a valid not_filed flight', async () => {
      const result = await service.fileFlight(1);

      expect(result.success).toBe(true);
      expect(result.filingStatus).toBe('filed');
      expect(result.filingReference).toBe('FP1001');
      expect(mockLeidosClient.fileFlightPlan).toHaveBeenCalledTimes(1);
      expect(mockFlightsService.update).toHaveBeenCalledWith(1, expect.objectContaining({
        filing_status: 'filed',
        filing_reference: 'FP1001',
      }));
    });

    it('should reject filing if already filed', async () => {
      (mockFlightsService.findById as jest.Mock).mockResolvedValue({
        ...mockFlight,
        filing_status: 'filed',
      });

      await expect(service.fileFlight(1)).rejects.toThrow('Cannot file');
    });
  });

  describe('amendFlight', () => {
    it('should amend a filed flight', async () => {
      (mockFlightsService.findById as jest.Mock).mockResolvedValue({
        ...mockFlight,
        filing_status: 'filed',
        filing_reference: 'FP1001',
        filing_version_stamp: 'v123',
      });

      const result = await service.amendFlight(1);

      expect(result.success).toBe(true);
      expect(result.filingStatus).toBe('filed');
      expect(mockLeidosClient.amendFlightPlan).toHaveBeenCalledTimes(1);
    });

    it('should reject amend if not filed', async () => {
      await expect(service.amendFlight(1)).rejects.toThrow('Cannot amend');
    });
  });

  describe('cancelFiling', () => {
    it('should cancel a filed flight', async () => {
      (mockFlightsService.findById as jest.Mock).mockResolvedValue({
        ...mockFlight,
        filing_status: 'filed',
        filing_reference: 'FP1001',
      });

      const result = await service.cancelFiling(1);

      expect(result.success).toBe(true);
      expect(result.filingStatus).toBe('not_filed');
      expect(mockLeidosClient.cancelFlightPlan).toHaveBeenCalledTimes(1);
    });

    it('should reject cancel if not filed', async () => {
      await expect(service.cancelFiling(1)).rejects.toThrow('Cannot cancel');
    });
  });

  describe('closeFiling', () => {
    it('should close a filed flight', async () => {
      (mockFlightsService.findById as jest.Mock).mockResolvedValue({
        ...mockFlight,
        filing_status: 'filed',
        filing_reference: 'FP1001',
      });

      const result = await service.closeFiling(1);

      expect(result.success).toBe(true);
      expect(result.filingStatus).toBe('closed');
      expect(mockLeidosClient.closeFlightPlan).toHaveBeenCalledTimes(1);
    });

    it('should reject close if not filed', async () => {
      await expect(service.closeFiling(1)).rejects.toThrow('Cannot close');
    });
  });
});
