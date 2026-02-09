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
      expect(
        result.checks.every((c) => (c.severity === 'error' ? c.passed : true)),
      ).toBe(true);
    });

    it('should fail when aircraft_identifier is missing', async () => {
      (mockFlightsService.findById as jest.Mock).mockResolvedValue({
        ...mockFlight,
        aircraft_identifier: null,
      });

      const result = await service.validateForFiling(1);
      expect(result.ready).toBe(false);
      const check = result.checks.find(
        (c) => c.field === 'aircraft_identifier',
      );
      expect(check?.passed).toBe(false);
    });

    it('should fail when aircraft_identifier is too long', async () => {
      (mockFlightsService.findById as jest.Mock).mockResolvedValue({
        ...mockFlight,
        aircraft_identifier: 'N1234567890',
      });

      const result = await service.validateForFiling(1);
      expect(result.ready).toBe(false);
      const check = result.checks.find(
        (c) => c.field === 'aircraft_identifier',
      );
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

    it('should fail when phone_number is missing', async () => {
      (mockUsersService.getDemoUser as jest.Mock).mockResolvedValue({
        ...mockUser,
        phone_number: null,
      });

      const result = await service.validateForFiling(1);
      expect(result.ready).toBe(false);
      const check = result.checks.find((c) => c.field === 'phone_number');
      expect(check?.passed).toBe(false);
    });

    it('should warn (not fail) when alternate is missing', async () => {
      (mockFlightsService.findById as jest.Mock).mockResolvedValue({
        ...mockFlight,
        alternate_identifier: null,
      });

      const result = await service.validateForFiling(1);
      expect(result.ready).toBe(true);
      const check = result.checks.find(
        (c) => c.field === 'alternate_identifier',
      );
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

    it('should fail when departure is missing', async () => {
      (mockFlightsService.findById as jest.Mock).mockResolvedValue({
        ...mockFlight,
        departure_identifier: null,
      });

      const result = await service.validateForFiling(1);
      expect(result.ready).toBe(false);
      const check = result.checks.find(
        (c) => c.field === 'departure_identifier',
      );
      expect(check?.passed).toBe(false);
    });

    it('should fail when destination is missing', async () => {
      (mockFlightsService.findById as jest.Mock).mockResolvedValue({
        ...mockFlight,
        destination_identifier: null,
      });

      const result = await service.validateForFiling(1);
      expect(result.ready).toBe(false);
      const check = result.checks.find(
        (c) => c.field === 'destination_identifier',
      );
      expect(check?.passed).toBe(false);
    });

    it('should fail when cruise_altitude is missing', async () => {
      (mockFlightsService.findById as jest.Mock).mockResolvedValue({
        ...mockFlight,
        cruise_altitude: null,
      });

      const result = await service.validateForFiling(1);
      expect(result.ready).toBe(false);
    });

    it('should fail when true_airspeed is missing', async () => {
      (mockFlightsService.findById as jest.Mock).mockResolvedValue({
        ...mockFlight,
        true_airspeed: null,
      });

      const result = await service.validateForFiling(1);
      expect(result.ready).toBe(false);
    });

    it('should fail when ETD is missing', async () => {
      (mockFlightsService.findById as jest.Mock).mockResolvedValue({
        ...mockFlight,
        etd: null,
      });

      const result = await service.validateForFiling(1);
      expect(result.ready).toBe(false);
    });

    it('should fail when people_count is 0', async () => {
      (mockFlightsService.findById as jest.Mock).mockResolvedValue({
        ...mockFlight,
        people_count: 0,
      });

      const result = await service.validateForFiling(1);
      expect(result.ready).toBe(false);
    });

    it('should treat route as error for IFR but warning for VFR', async () => {
      // IFR missing route = error
      (mockFlightsService.findById as jest.Mock).mockResolvedValue({
        ...mockFlight,
        route_string: null,
        flight_rules: 'IFR',
      });

      let result = await service.validateForFiling(1);
      let routeCheck = result.checks.find((c) => c.field === 'route_string');
      expect(routeCheck?.severity).toBe('error');
      expect(result.ready).toBe(false);

      // VFR missing route = warning
      (mockFlightsService.findById as jest.Mock).mockResolvedValue({
        ...mockFlight,
        route_string: null,
        flight_rules: 'VFR',
      });

      result = await service.validateForFiling(1);
      routeCheck = result.checks.find((c) => c.field === 'route_string');
      expect(routeCheck?.severity).toBe('warning');
      expect(result.ready).toBe(true);
    });

    it('should fail when aircraft has no ICAO type code', async () => {
      (mockAircraftService.findOne as jest.Mock).mockResolvedValue({
        ...mockAircraft,
        icao_type_code: null,
      });

      const result = await service.validateForFiling(1);
      expect(result.ready).toBe(false);
      const check = result.checks.find((c) => c.field === 'icao_type_code');
      expect(check?.passed).toBe(false);
    });

    it('should fail when aircraft has no equipment codes', async () => {
      (mockAircraftService.findOne as jest.Mock).mockResolvedValue({
        ...mockAircraft,
        equipment: { equipment_codes: null },
      });

      const result = await service.validateForFiling(1);
      expect(result.ready).toBe(false);
      const check = result.checks.find((c) => c.field === 'equipment_codes');
      expect(check?.passed).toBe(false);
    });

    it('should handle aircraft_id being null gracefully', async () => {
      (mockFlightsService.findById as jest.Mock).mockResolvedValue({
        ...mockFlight,
        aircraft_id: null,
      });

      const result = await service.validateForFiling(1);
      expect(result.ready).toBe(false);
      const icaoCheck = result.checks.find(
        (c) => c.field === 'icao_type_code',
      );
      expect(icaoCheck?.passed).toBe(false);
    });

    it('should include value fields in check results', async () => {
      const result = await service.validateForFiling(1);
      const depCheck = result.checks.find(
        (c) => c.field === 'departure_identifier',
      );
      expect(depCheck?.value).toBe('APA');

      const altCheck = result.checks.find(
        (c) => c.field === 'cruise_altitude',
      );
      expect(altCheck?.value).toBe('10000 ft');

      const tasCheck = result.checks.find(
        (c) => c.field === 'true_airspeed',
      );
      expect(tasCheck?.value).toBe('120 kt');
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

    it('should map VFR flight_rules to V', async () => {
      const plan = await service.buildIcaoFlightPlan({
        ...mockFlight,
        flight_rules: 'VFR',
      } as any);
      expect(plan.flightRules).toBe('V');
    });

    it('should use ZZZZ for unknown aircraft type when no aircraft found', async () => {
      (mockAircraftService.findOne as jest.Mock).mockRejectedValue(
        new Error('Not found'),
      );

      const plan = await service.buildIcaoFlightPlan({
        ...mockFlight,
        aircraft_id: null,
      } as any);
      expect(plan.aircraftType).toBe('ZZZZ');
    });

    it('should use DCT when route_string is empty', async () => {
      const plan = await service.buildIcaoFlightPlan({
        ...mockFlight,
        route_string: null,
      } as any);
      expect(plan.route).toBe('DCT');
    });

    it('should not include alternate when not set', async () => {
      const plan = await service.buildIcaoFlightPlan({
        ...mockFlight,
        alternate_identifier: null,
      } as any);
      expect(plan.alternateIcao).toBeUndefined();
    });

    it('should compute endurance from fuel data', async () => {
      const plan = await service.buildIcaoFlightPlan(mockFlight as any);
      // 48 gal / 8.5 GPH ≈ 5.647 hours → 5h 39m → 0539
      expect(plan.endurance).toBe('0539');
    });

    it('should fall back to ETE + 1hr when no fuel data', async () => {
      const plan = await service.buildIcaoFlightPlan({
        ...mockFlight,
        fuel_burn_rate: null,
        start_fuel_gallons: null,
        ete_minutes: 90,
      } as any);
      // 1.5h + 1h = 2.5h → 0230
      expect(plan.endurance).toBe('0230');
    });

    it('should truncate aircraft identifier to 7 chars', async () => {
      const plan = await service.buildIcaoFlightPlan({
        ...mockFlight,
        aircraft_identifier: 'N1234567890',
      } as any);
      expect(plan.aircraftId).toBe('N123456');
    });

    it('should prepend K for unknown US airports', async () => {
      (mockAirportsService.findById as jest.Mock).mockResolvedValue(null);

      const plan = await service.buildIcaoFlightPlan({
        ...mockFlight,
        departure_identifier: 'XYZ',
      } as any);
      expect(plan.departureIcao).toBe('KXYZ');
    });

    it('should format departure time from ETD', async () => {
      const plan = await service.buildIcaoFlightPlan(mockFlight as any);
      expect(plan.departureTime).toBe('1400');
    });

    it('should return 0000 for invalid ETD', async () => {
      const plan = await service.buildIcaoFlightPlan({
        ...mockFlight,
        etd: '',
      } as any);
      expect(plan.departureTime).toBe('0000');
    });

    it('should include remarks when present', async () => {
      const plan = await service.buildIcaoFlightPlan({
        ...mockFlight,
        remarks: '/v/ VFR ON TOP',
      } as any);
      expect(plan.otherInfo).toBe('/v/ VFR ON TOP');
    });

    it('should default personsOnBoard to 1 when people_count is 0', async () => {
      const plan = await service.buildIcaoFlightPlan({
        ...mockFlight,
        people_count: 0,
      } as any);
      expect(plan.personsOnBoard).toBe(1);
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
      expect(mockFlightsService.update).toHaveBeenCalledWith(
        1,
        expect.objectContaining({
          filing_status: 'filed',
          filing_reference: 'FP1001',
        }),
      );
    });

    it('should reject filing if already filed', async () => {
      (mockFlightsService.findById as jest.Mock).mockResolvedValue({
        ...mockFlight,
        filing_status: 'filed',
      });

      await expect(service.fileFlight(1)).rejects.toThrow('Cannot file');
    });

    it('should reject filing if status is accepted', async () => {
      (mockFlightsService.findById as jest.Mock).mockResolvedValue({
        ...mockFlight,
        filing_status: 'accepted',
      });

      await expect(service.fileFlight(1)).rejects.toThrow('Cannot file');
    });

    it('should reject filing if status is closed', async () => {
      (mockFlightsService.findById as jest.Mock).mockResolvedValue({
        ...mockFlight,
        filing_status: 'closed',
      });

      await expect(service.fileFlight(1)).rejects.toThrow('Cannot file');
    });

    it('should reject filing when validation fails', async () => {
      (mockFlightsService.findById as jest.Mock).mockResolvedValue({
        ...mockFlight,
        departure_identifier: null,
      });

      await expect(service.fileFlight(1)).rejects.toThrow(
        'Flight plan is not ready',
      );
    });

    it('should return failure when Leidos API fails', async () => {
      mockLeidosClient.fileFlightPlan.mockResolvedValue({
        success: false,
        flightIdentifier: '',
        versionStamp: '',
        errors: ['Server unavailable'],
      });

      const result = await service.fileFlight(1);

      expect(result.success).toBe(false);
      expect(result.filingStatus).toBe('not_filed');
      expect(result.errors).toContain('Server unavailable');
      // Should NOT update flight record on failure
      expect(mockFlightsService.update).not.toHaveBeenCalled();
    });

    it('should store filing_format as icao', async () => {
      await service.fileFlight(1);

      expect(mockFlightsService.update).toHaveBeenCalledWith(
        1,
        expect.objectContaining({
          filing_format: 'icao',
        }),
      );
    });

    it('should store filed_at timestamp', async () => {
      const result = await service.fileFlight(1);

      expect(result.filedAt).toBeDefined();
      expect(mockFlightsService.update).toHaveBeenCalledWith(
        1,
        expect.objectContaining({
          filed_at: expect.any(String),
        }),
      );
    });

    it('should pass correct payload to Leidos', async () => {
      await service.fileFlight(1);

      expect(mockLeidosClient.fileFlightPlan).toHaveBeenCalledWith({
        webUserName: 'jdoe',
        flightPlan: expect.objectContaining({
          aircraftIdentifier: 'N12345',
          aircraftType: 'C172',
          departurePoint: 'KAPA',
          destinationPoint: 'KDEN',
          flightType: 'IFR',
          cruiseSpeed: 'N0120',
          cruiseAltitude: 'A100',
          route: 'APA V389 DEN',
          personsOnBoard: 2,
          pilotName: 'John Doe',
        }),
      });
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

    it('should amend an accepted flight', async () => {
      (mockFlightsService.findById as jest.Mock).mockResolvedValue({
        ...mockFlight,
        filing_status: 'accepted',
        filing_reference: 'FP1001',
        filing_version_stamp: 'v123',
      });

      const result = await service.amendFlight(1);
      expect(result.success).toBe(true);
    });

    it('should reject amend if not filed', async () => {
      await expect(service.amendFlight(1)).rejects.toThrow('Cannot amend');
    });

    it('should reject amend if no filing reference', async () => {
      (mockFlightsService.findById as jest.Mock).mockResolvedValue({
        ...mockFlight,
        filing_status: 'filed',
        filing_reference: null,
      });

      await expect(service.amendFlight(1)).rejects.toThrow(
        'No filing reference',
      );
    });

    it('should pass version stamp to Leidos for amend', async () => {
      (mockFlightsService.findById as jest.Mock).mockResolvedValue({
        ...mockFlight,
        filing_status: 'filed',
        filing_reference: 'FP1001',
        filing_version_stamp: 'v123',
      });

      await service.amendFlight(1);

      expect(mockLeidosClient.amendFlightPlan).toHaveBeenCalledWith(
        expect.objectContaining({
          flightIdentifier: 'FP1001',
          versionStamp: 'v123',
        }),
      );
    });

    it('should update version stamp after successful amend', async () => {
      (mockFlightsService.findById as jest.Mock).mockResolvedValue({
        ...mockFlight,
        filing_status: 'filed',
        filing_reference: 'FP1001',
        filing_version_stamp: 'v123',
      });

      await service.amendFlight(1);

      expect(mockFlightsService.update).toHaveBeenCalledWith(
        1,
        expect.objectContaining({
          filing_version_stamp: 'v124',
        }),
      );
    });

    it('should return failure when Leidos amend fails', async () => {
      (mockFlightsService.findById as jest.Mock).mockResolvedValue({
        ...mockFlight,
        filing_status: 'filed',
        filing_reference: 'FP1001',
        filing_version_stamp: 'v123',
      });

      mockLeidosClient.amendFlightPlan.mockResolvedValue({
        success: false,
        errors: ['Version conflict'],
      });

      const result = await service.amendFlight(1);

      expect(result.success).toBe(false);
      expect(result.message).toBe('Amendment failed');
      expect(mockFlightsService.update).not.toHaveBeenCalled();
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

    it('should cancel an accepted flight', async () => {
      (mockFlightsService.findById as jest.Mock).mockResolvedValue({
        ...mockFlight,
        filing_status: 'accepted',
        filing_reference: 'FP1001',
      });

      const result = await service.cancelFiling(1);
      expect(result.success).toBe(true);
      expect(result.filingStatus).toBe('not_filed');
    });

    it('should reject cancel if not filed', async () => {
      await expect(service.cancelFiling(1)).rejects.toThrow('Cannot cancel');
    });

    it('should reject cancel if no filing reference', async () => {
      (mockFlightsService.findById as jest.Mock).mockResolvedValue({
        ...mockFlight,
        filing_status: 'filed',
        filing_reference: null,
      });

      await expect(service.cancelFiling(1)).rejects.toThrow(
        'No filing reference',
      );
    });

    it('should clear filing fields on successful cancel', async () => {
      (mockFlightsService.findById as jest.Mock).mockResolvedValue({
        ...mockFlight,
        filing_status: 'filed',
        filing_reference: 'FP1001',
      });

      await service.cancelFiling(1);

      expect(mockFlightsService.update).toHaveBeenCalledWith(
        1,
        expect.objectContaining({
          filing_status: 'not_filed',
          filing_reference: null,
          filing_version_stamp: null,
          filed_at: null,
        }),
      );
    });

    it('should return failure when Leidos cancel fails', async () => {
      (mockFlightsService.findById as jest.Mock).mockResolvedValue({
        ...mockFlight,
        filing_status: 'filed',
        filing_reference: 'FP1001',
      });

      mockLeidosClient.cancelFlightPlan.mockResolvedValue({
        success: false,
        errors: ['Flight not found in system'],
      });

      const result = await service.cancelFiling(1);

      expect(result.success).toBe(false);
      expect(result.message).toBe('Cancellation failed');
      expect(mockFlightsService.update).not.toHaveBeenCalled();
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

    it('should close an accepted flight', async () => {
      (mockFlightsService.findById as jest.Mock).mockResolvedValue({
        ...mockFlight,
        filing_status: 'accepted',
        filing_reference: 'FP1001',
      });

      const result = await service.closeFiling(1);
      expect(result.success).toBe(true);
      expect(result.filingStatus).toBe('closed');
    });

    it('should reject close if not filed', async () => {
      await expect(service.closeFiling(1)).rejects.toThrow('Cannot close');
    });

    it('should reject close if no filing reference', async () => {
      (mockFlightsService.findById as jest.Mock).mockResolvedValue({
        ...mockFlight,
        filing_status: 'filed',
        filing_reference: null,
      });

      await expect(service.closeFiling(1)).rejects.toThrow(
        'No filing reference',
      );
    });

    it('should return failure when Leidos close fails', async () => {
      (mockFlightsService.findById as jest.Mock).mockResolvedValue({
        ...mockFlight,
        filing_status: 'filed',
        filing_reference: 'FP1001',
      });

      mockLeidosClient.closeFlightPlan.mockResolvedValue({
        success: false,
        errors: ['Already closed'],
      });

      const result = await service.closeFiling(1);

      expect(result.success).toBe(false);
      expect(result.message).toBe('Close failed');
      expect(mockFlightsService.update).not.toHaveBeenCalled();
    });
  });

  // --- getFilingStatus ---

  describe('getFilingStatus', () => {
    it('should return status for filed flight', async () => {
      (mockFlightsService.findById as jest.Mock).mockResolvedValue({
        ...mockFlight,
        filing_status: 'filed',
        filing_reference: 'FP1001',
      });

      const result = await service.getFilingStatus(1);

      expect(result.success).toBe(true);
      expect(result.filingReference).toBe('FP1001');
      expect(mockLeidosClient.getFlightPlanStatus).toHaveBeenCalledWith(
        'jdoe',
        'FP1001',
      );
    });

    it('should return status without Leidos call for unfiled flight', async () => {
      const result = await service.getFilingStatus(1);

      expect(result.success).toBe(true);
      expect(result.filingStatus).toBe('not_filed');
      expect(result.message).toContain('not been filed');
      expect(mockLeidosClient.getFlightPlanStatus).not.toHaveBeenCalled();
    });
  });

  // --- Full lifecycle ---

  describe('filing lifecycle', () => {
    it('should support file → amend → cancel flow', async () => {
      // File
      const fileResult = await service.fileFlight(1);
      expect(fileResult.success).toBe(true);

      // Amend
      (mockFlightsService.findById as jest.Mock).mockResolvedValue({
        ...mockFlight,
        filing_status: 'filed',
        filing_reference: 'FP1001',
        filing_version_stamp: 'v123',
      });
      const amendResult = await service.amendFlight(1);
      expect(amendResult.success).toBe(true);

      // Cancel
      const cancelResult = await service.cancelFiling(1);
      expect(cancelResult.success).toBe(true);
      expect(cancelResult.filingStatus).toBe('not_filed');
    });

    it('should support file → close flow', async () => {
      // File
      const fileResult = await service.fileFlight(1);
      expect(fileResult.success).toBe(true);

      // Close
      (mockFlightsService.findById as jest.Mock).mockResolvedValue({
        ...mockFlight,
        filing_status: 'filed',
        filing_reference: 'FP1001',
      });
      const closeResult = await service.closeFiling(1);
      expect(closeResult.success).toBe(true);
      expect(closeResult.filingStatus).toBe('closed');
    });
  });
});
