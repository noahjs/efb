export interface IcaoFlightPlan {
  // Field 7 — Aircraft identification
  aircraftId: string;

  // Field 8 — Flight rules and type
  flightRules: string; // I, V, Y, Z
  flightType: string; // G (general aviation)

  // Field 9 — Number and type of aircraft, wake turbulence
  aircraftType: string; // ICAO type designator
  wakeTurbulence: string; // L, M, H, J

  // Field 10 — Equipment and capabilities
  equipmentCodes: string;

  // Field 13 — Departure aerodrome and time
  departureIcao: string;
  departureTime: string; // HHMM UTC

  // Field 15 — Cruising speed, level, and route
  cruisingSpeed: string; // N0XXX (knots) or M0XX (mach)
  cruisingLevel: string; // FXXX or A0XX
  route: string;

  // Field 16 — Destination, ETE, alternates
  destinationIcao: string;
  totalEet: string; // HHMM
  alternateIcao?: string;
  alternate2Icao?: string;

  // Field 18 — Other information (remarks)
  otherInfo?: string;

  // Field 19 — Supplementary information
  endurance: string; // HHMM
  personsOnBoard: number;
  pilotInCommand: string;
  aircraftColor?: string;
  remarks?: string;
  contactPhone?: string;
}
