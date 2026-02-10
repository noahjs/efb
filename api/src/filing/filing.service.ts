import {
  Injectable,
  Inject,
  BadRequestException,
  Logger,
} from '@nestjs/common';
import { FlightsService } from '../flights/flights.service';
import { AircraftService } from '../aircraft/aircraft.service';
import { UsersService } from '../users/users.service';
import { AirportsService } from '../airports/airports.service';
import { Aircraft } from '../aircraft/entities/aircraft.entity';
import { Flight } from '../flights/entities/flight.entity';
import {
  ValidationCheck,
  FilingValidationResult,
} from './dto/filing-validation.dto';
import { FilingResponse } from './dto/filing-response.dto';
import type { IcaoFlightPlan } from './interfaces/icao-flight-plan';
import type { LeidosClient } from './interfaces/leidos-types';
import { LeidosFlightPlanPayload } from './interfaces/leidos-types';

@Injectable()
export class FilingService {
  private readonly logger = new Logger(FilingService.name);

  constructor(
    private readonly flightsService: FlightsService,
    private readonly aircraftService: AircraftService,
    private readonly usersService: UsersService,
    private readonly airportsService: AirportsService,
    @Inject('LEIDOS_CLIENT') private readonly leidosClient: LeidosClient,
  ) {}

  // --- Validation ---

  async validateForFiling(
    flightId: number,
    userId: string,
  ): Promise<FilingValidationResult> {
    const flight = await this.flightsService.findById(flightId, userId);
    const user = await this.usersService.findById(userId);

    let aircraft: Aircraft | null = null;
    if (flight.aircraft_id) {
      try {
        aircraft = await this.aircraftService.findOne(flight.aircraft_id);
      } catch {
        // aircraft not found
      }
    }

    const checks: ValidationCheck[] = [];

    // Aircraft identifier
    checks.push({
      field: 'aircraft_identifier',
      label: 'Aircraft identifier',
      passed:
        !!flight.aircraft_identifier && flight.aircraft_identifier.length <= 7,
      value: flight.aircraft_identifier || undefined,
      severity: 'error',
    });

    // ICAO type code
    const icaoType = aircraft?.icao_type_code;
    checks.push({
      field: 'icao_type_code',
      label: 'ICAO type code',
      passed: !!icaoType,
      value: icaoType || undefined,
      severity: 'error',
    });

    // Equipment codes
    const equipmentCodes = aircraft?.equipment?.equipment_codes;
    checks.push({
      field: 'equipment_codes',
      label: 'Equipment codes',
      passed: !!equipmentCodes,
      value: equipmentCodes || undefined,
      severity: 'error',
    });

    // Departure
    checks.push({
      field: 'departure_identifier',
      label: 'Departure airport',
      passed: !!flight.departure_identifier,
      value: flight.departure_identifier || undefined,
      severity: 'error',
    });

    // Destination
    checks.push({
      field: 'destination_identifier',
      label: 'Destination airport',
      passed: !!flight.destination_identifier,
      value: flight.destination_identifier || undefined,
      severity: 'error',
    });

    // Route string (required for IFR)
    checks.push({
      field: 'route_string',
      label: 'Route',
      passed: !!flight.route_string,
      value: flight.route_string || undefined,
      severity: flight.flight_rules === 'IFR' ? 'error' : 'warning',
    });

    // Cruise altitude
    checks.push({
      field: 'cruise_altitude',
      label: 'Cruise altitude',
      passed: !!flight.cruise_altitude,
      value: flight.cruise_altitude
        ? `${flight.cruise_altitude} ft`
        : undefined,
      severity: 'error',
    });

    // True airspeed
    checks.push({
      field: 'true_airspeed',
      label: 'True airspeed',
      passed: !!flight.true_airspeed,
      value: flight.true_airspeed ? `${flight.true_airspeed} kt` : undefined,
      severity: 'error',
    });

    // ETD
    checks.push({
      field: 'etd',
      label: 'Departure time',
      passed: !!flight.etd,
      value: flight.etd || undefined,
      severity: 'error',
    });

    // ETE (flight must be calculated)
    checks.push({
      field: 'ete_minutes',
      label: 'Estimated time en route',
      passed: !!flight.ete_minutes && flight.ete_minutes > 0,
      value: flight.ete_minutes
        ? `${Math.floor(flight.ete_minutes / 60)}h ${flight.ete_minutes % 60}m`
        : undefined,
      severity: 'error',
    });

    // Pilot name
    checks.push({
      field: 'pilot_name',
      label: 'Pilot name',
      passed: !!user?.pilot_name,
      value: user?.pilot_name || undefined,
      severity: 'error',
    });

    // Phone
    checks.push({
      field: 'phone_number',
      label: 'Pilot phone',
      passed: !!user?.phone_number,
      value: user?.phone_number || undefined,
      severity: 'error',
    });

    // People on board
    checks.push({
      field: 'people_count',
      label: 'Persons on board',
      passed: flight.people_count > 0,
      value: `${flight.people_count}`,
      severity: 'error',
    });

    // Alternate (warning only)
    checks.push({
      field: 'alternate_identifier',
      label: 'Alternate airport',
      passed: !!flight.alternate_identifier,
      value: flight.alternate_identifier || undefined,
      severity: 'warning',
    });

    const ready = checks
      .filter((c) => c.severity === 'error')
      .every((c) => c.passed);

    return { ready, checks };
  }

  // --- ICAO Transformation ---

  async buildIcaoFlightPlan(
    flight: Flight,
    userId: string,
  ): Promise<IcaoFlightPlan> {
    const user = await this.usersService.findById(userId);
    let aircraft: Aircraft | null = null;
    if (flight.aircraft_id) {
      aircraft = await this.aircraftService.findOne(flight.aircraft_id);
    }

    // Resolve ICAO identifiers for airports
    const depIcao = await this.resolveIcao(flight.departure_identifier);
    const destIcao = await this.resolveIcao(flight.destination_identifier);
    const altIcao = flight.alternate_identifier
      ? await this.resolveIcao(flight.alternate_identifier)
      : undefined;

    // Format speed: TAS 150 → N0150
    const speed = this.formatSpeed(flight.true_airspeed || 0);

    // Format altitude: 18000+ → F180, below → A045
    const level = this.formatLevel(flight.cruise_altitude || 0);

    // Format ETE: 90 min → 0130
    const ete = this.formatMinutesToHHMM(flight.ete_minutes || 0);

    // Departure time from ETD
    const depTime = this.formatDepartureTime(flight.etd || '');

    // Endurance
    const enduranceHours =
      flight.endurance_hours || this.computeEndurance(flight);
    const endurance = this.formatHoursToHHMM(enduranceHours);

    return {
      aircraftId: (flight.aircraft_identifier || '').substring(0, 7),
      flightRules: flight.flight_rules === 'IFR' ? 'I' : 'V',
      flightType: 'G',
      aircraftType: aircraft?.icao_type_code || 'ZZZZ',
      wakeTurbulence: 'L',
      equipmentCodes: aircraft?.equipment?.equipment_codes || 'S/C',
      departureIcao: depIcao,
      departureTime: depTime,
      cruisingSpeed: speed,
      cruisingLevel: level,
      route: flight.route_string || 'DCT',
      destinationIcao: destIcao,
      totalEet: ete,
      alternateIcao: altIcao,
      otherInfo: flight.remarks || undefined,
      endurance,
      personsOnBoard: flight.people_count || 1,
      pilotInCommand: user?.pilot_name || 'UNKNOWN',
      aircraftColor: aircraft?.color || undefined,
      contactPhone: user?.phone_number || undefined,
    };
  }

  // --- File ---

  async fileFlight(
    flightId: number,
    userId: string,
  ): Promise<FilingResponse> {
    const flight = await this.flightsService.findById(flightId, userId);

    // Validate state
    if (flight.filing_status !== 'not_filed') {
      throw new BadRequestException(
        `Cannot file: current status is '${flight.filing_status}'. Cancel first to re-file.`,
      );
    }

    // Validate completeness
    const validation = await this.validateForFiling(flightId, userId);
    if (!validation.ready) {
      const missing = validation.checks
        .filter((c) => !c.passed && c.severity === 'error')
        .map((c) => c.label);
      throw new BadRequestException(
        `Flight plan is not ready: missing ${missing.join(', ')}`,
      );
    }

    const user = await this.usersService.findById(userId);
    const icao = await this.buildIcaoFlightPlan(flight, userId);

    const payload: LeidosFlightPlanPayload = {
      aircraftIdentifier: icao.aircraftId,
      aircraftType: icao.aircraftType,
      specialEquipment: icao.equipmentCodes,
      flightType: icao.flightRules === 'I' ? 'IFR' : 'VFR',
      numAircraft: 1,
      wakeTurbulence: icao.wakeTurbulence,
      departurePoint: icao.departureIcao,
      departureTime: icao.departureTime,
      route: icao.route,
      cruiseSpeed: icao.cruisingSpeed,
      cruiseAltitude: icao.cruisingLevel,
      destinationPoint: icao.destinationIcao,
      estimatedElapsedTime: icao.totalEet,
      alternateAirport: icao.alternateIcao,
      fuelOnBoard: icao.endurance,
      personsOnBoard: icao.personsOnBoard,
      pilotName: icao.pilotInCommand,
      pilotPhone: icao.contactPhone,
      aircraftColor: icao.aircraftColor,
      remarks: icao.otherInfo,
    };

    const result = await this.leidosClient.fileFlightPlan({
      webUserName: user?.leidos_username || 'demo',
      flightPlan: payload,
    });

    if (!result.success) {
      return {
        success: false,
        filingStatus: flight.filing_status,
        errors: result.errors,
        message: 'Filing failed',
      };
    }

    // Update flight record
    await this.flightsService.update(flightId, {
      filing_status: 'filed',
      filing_reference: result.flightIdentifier,
      filing_version_stamp: result.versionStamp,
      filed_at: new Date().toISOString(),
      filing_format: 'icao',
    }, userId);

    return {
      success: true,
      filingStatus: 'filed',
      filingReference: result.flightIdentifier,
      filingVersionStamp: result.versionStamp,
      filedAt: new Date().toISOString(),
      message: result.message,
    };
  }

  // --- Amend ---

  async amendFlight(
    flightId: number,
    userId: string,
  ): Promise<FilingResponse> {
    const flight = await this.flightsService.findById(flightId, userId);

    if (!['filed', 'accepted'].includes(flight.filing_status)) {
      throw new BadRequestException(
        `Cannot amend: current status is '${flight.filing_status}'`,
      );
    }

    if (!flight.filing_reference) {
      throw new BadRequestException('No filing reference found');
    }

    const user = await this.usersService.findById(userId);
    const icao = await this.buildIcaoFlightPlan(flight, userId);

    const payload: LeidosFlightPlanPayload = {
      aircraftIdentifier: icao.aircraftId,
      aircraftType: icao.aircraftType,
      specialEquipment: icao.equipmentCodes,
      flightType: icao.flightRules === 'I' ? 'IFR' : 'VFR',
      numAircraft: 1,
      wakeTurbulence: icao.wakeTurbulence,
      departurePoint: icao.departureIcao,
      departureTime: icao.departureTime,
      route: icao.route,
      cruiseSpeed: icao.cruisingSpeed,
      cruiseAltitude: icao.cruisingLevel,
      destinationPoint: icao.destinationIcao,
      estimatedElapsedTime: icao.totalEet,
      alternateAirport: icao.alternateIcao,
      fuelOnBoard: icao.endurance,
      personsOnBoard: icao.personsOnBoard,
      pilotName: icao.pilotInCommand,
      pilotPhone: icao.contactPhone,
      aircraftColor: icao.aircraftColor,
      remarks: icao.otherInfo,
    };

    const result = await this.leidosClient.amendFlightPlan({
      webUserName: user?.leidos_username || 'demo',
      flightPlan: payload,
      flightIdentifier: flight.filing_reference,
      versionStamp: flight.filing_version_stamp || '',
    });

    if (!result.success) {
      return {
        success: false,
        filingStatus: flight.filing_status,
        errors: result.errors,
        message: 'Amendment failed',
      };
    }

    await this.flightsService.update(flightId, {
      filing_status: 'filed',
      filing_version_stamp: result.versionStamp,
      filed_at: new Date().toISOString(),
    }, userId);

    return {
      success: true,
      filingStatus: 'filed',
      filingReference: flight.filing_reference,
      filingVersionStamp: result.versionStamp,
      filedAt: new Date().toISOString(),
      message: result.message,
    };
  }

  // --- Cancel ---

  async cancelFiling(
    flightId: number,
    userId: string,
  ): Promise<FilingResponse> {
    const flight = await this.flightsService.findById(flightId, userId);

    if (!['filed', 'accepted'].includes(flight.filing_status)) {
      throw new BadRequestException(
        `Cannot cancel: current status is '${flight.filing_status}'`,
      );
    }

    if (!flight.filing_reference) {
      throw new BadRequestException('No filing reference found');
    }

    const user = await this.usersService.findById(userId);

    const result = await this.leidosClient.cancelFlightPlan({
      webUserName: user?.leidos_username || 'demo',
      flightIdentifier: flight.filing_reference,
    });

    if (!result.success) {
      return {
        success: false,
        filingStatus: flight.filing_status,
        errors: result.errors,
        message: 'Cancellation failed',
      };
    }

    // Clear filing fields — use 'as any' because we need to set null
    // to clear the DB columns, but the DTO types are string | undefined
    await this.flightsService.update(flightId, {
      filing_status: 'not_filed',
      filing_reference: null as any,
      filing_version_stamp: null as any,
      filed_at: null as any,
    }, userId);

    return {
      success: true,
      filingStatus: 'not_filed',
      message: result.message,
    };
  }

  // --- Close ---

  async closeFiling(
    flightId: number,
    userId: string,
  ): Promise<FilingResponse> {
    const flight = await this.flightsService.findById(flightId, userId);

    if (!['filed', 'accepted'].includes(flight.filing_status)) {
      throw new BadRequestException(
        `Cannot close: current status is '${flight.filing_status}'`,
      );
    }

    if (!flight.filing_reference) {
      throw new BadRequestException('No filing reference found');
    }

    const user = await this.usersService.findById(userId);

    const result = await this.leidosClient.closeFlightPlan({
      webUserName: user?.leidos_username || 'demo',
      flightIdentifier: flight.filing_reference,
    });

    if (!result.success) {
      return {
        success: false,
        filingStatus: flight.filing_status,
        errors: result.errors,
        message: 'Close failed',
      };
    }

    await this.flightsService.update(flightId, {
      filing_status: 'closed',
    }, userId);

    return {
      success: true,
      filingStatus: 'closed',
      filingReference: flight.filing_reference,
      message: result.message,
    };
  }

  // --- Status ---

  async getFilingStatus(
    flightId: number,
    userId: string,
  ): Promise<FilingResponse> {
    const flight = await this.flightsService.findById(flightId, userId);

    if (!flight.filing_reference) {
      return {
        success: true,
        filingStatus: flight.filing_status,
        message: 'No filing reference — flight has not been filed',
      };
    }

    const user = await this.usersService.findById(userId);

    const result = await this.leidosClient.getFlightPlanStatus(
      user?.leidos_username || 'demo',
      flight.filing_reference,
    );

    return {
      success: true,
      filingStatus: flight.filing_status,
      filingReference: flight.filing_reference,
      filingVersionStamp: result.versionStamp,
      message: result.message,
    };
  }

  // --- Helpers ---

  private async resolveIcao(identifier: string): Promise<string> {
    if (!identifier) return 'ZZZZ';
    const airport = await this.airportsService.findById(identifier);
    if (airport?.icao_identifier) return airport.icao_identifier;
    // If already 4-char ICAO, return as-is
    if (identifier.length === 4) return identifier.toUpperCase();
    // Prepend K for US airports
    return `K${identifier.toUpperCase()}`;
  }

  formatSpeed(tas: number): string {
    return `N${String(tas).padStart(4, '0')}`;
  }

  formatLevel(altitude: number): string {
    if (altitude >= 18000) {
      const fl = Math.round(altitude / 100);
      return `F${String(fl).padStart(3, '0')}`;
    }
    const hundreds = Math.round(altitude / 100);
    return `A${String(hundreds).padStart(3, '0')}`;
  }

  formatMinutesToHHMM(minutes: number): string {
    const h = Math.floor(minutes / 60);
    const m = minutes % 60;
    return `${String(h).padStart(2, '0')}${String(m).padStart(2, '0')}`;
  }

  formatHoursToHHMM(hours: number): string {
    const h = Math.floor(hours);
    const m = Math.round((hours - h) * 60);
    return `${String(h).padStart(2, '0')}${String(m).padStart(2, '0')}`;
  }

  private formatDepartureTime(etd: string): string {
    if (!etd) return '0000';
    try {
      const d = new Date(etd);
      const h = String(d.getUTCHours()).padStart(2, '0');
      const m = String(d.getUTCMinutes()).padStart(2, '0');
      return `${h}${m}`;
    } catch {
      return '0000';
    }
  }

  private computeEndurance(flight: Flight): number {
    if (flight.fuel_burn_rate && flight.start_fuel_gallons) {
      return flight.start_fuel_gallons / flight.fuel_burn_rate;
    }
    // Default: ETE + 1 hour reserve
    const eteHours = (flight.ete_minutes || 0) / 60;
    return eteHours + 1;
  }
}
