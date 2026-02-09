export interface LeidosFileRequest {
  webUserName: string;
  flightPlan: LeidosFlightPlanPayload;
}

export interface LeidosFlightPlanPayload {
  // Aircraft
  aircraftIdentifier: string;
  aircraftType: string;
  specialEquipment: string;

  // Flight
  flightType: string; // IFR, VFR
  numAircraft: number;
  wakeTurbulence: string;

  // Departure
  departurePoint: string;
  departureTime: string; // HHMM
  departureDate?: string; // YYYYMMDD

  // Route
  route: string;
  cruiseSpeed: string;
  cruiseAltitude: string;

  // Destination
  destinationPoint: string;
  estimatedElapsedTime: string; // HHMM
  alternateAirport?: string;
  alternate2Airport?: string;

  // Supplementary
  fuelOnBoard: string; // HHMM
  personsOnBoard: number;
  pilotName: string;
  pilotPhone?: string;
  aircraftColor?: string;
  remarks?: string;
}

export interface LeidosFileResponse {
  success: boolean;
  flightIdentifier: string;
  versionStamp: string;
  message?: string;
  errors?: string[];
}

export interface LeidosAmendRequest extends LeidosFileRequest {
  flightIdentifier: string;
  versionStamp: string;
}

export interface LeidosCancelRequest {
  webUserName: string;
  flightIdentifier: string;
}

export interface LeidosCloseRequest {
  webUserName: string;
  flightIdentifier: string;
}

export interface LeidosStatusResponse {
  flightIdentifier: string;
  status: string;
  versionStamp?: string;
  message?: string;
}

export interface LeidosClient {
  fileFlightPlan(request: LeidosFileRequest): Promise<LeidosFileResponse>;
  amendFlightPlan(request: LeidosAmendRequest): Promise<LeidosFileResponse>;
  cancelFlightPlan(request: LeidosCancelRequest): Promise<LeidosFileResponse>;
  closeFlightPlan(request: LeidosCloseRequest): Promise<LeidosFileResponse>;
  getFlightPlanStatus(
    webUserName: string,
    flightIdentifier: string,
  ): Promise<LeidosStatusResponse>;
}
