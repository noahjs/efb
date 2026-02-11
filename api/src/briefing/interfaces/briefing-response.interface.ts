export interface BriefingWaypoint {
  identifier: string;
  latitude: number;
  longitude: number;
  type: string;
  distanceFromDep: number;
  etaMinutes: number;
}

export interface BriefingMetar {
  station: string;
  icaoId: string;
  flightCategory: string | null;
  rawOb: string | null;
  obsTime: string | null;
  section: 'departure' | 'route' | 'destination';
}

export interface BriefingTaf {
  station: string;
  icaoId: string;
  rawTaf: string | null;
  section: 'departure' | 'route' | 'destination';
}

export interface BriefingNotam {
  id: string;
  type: string;
  icaoId: string;
  text: string;
  fullText: string;
  effectiveStart: string | null;
  effectiveEnd: string | null;
  category: string;
}

export interface CategorizedNotams {
  navigation: BriefingNotam[];
  communication: BriefingNotam[];
  svc: BriefingNotam[];
  obstruction: BriefingNotam[];
}

export interface EnrouteNotams {
  navigation: BriefingNotam[];
  communication: BriefingNotam[];
  svc: BriefingNotam[];
  airspace: BriefingNotam[];
  specialUseAirspace: BriefingNotam[];
  rwyTwyApronAdFdc: BriefingNotam[];
  otherUnverified: BriefingNotam[];
}

export interface BriefingAdvisory {
  hazardType: string;
  rawText: string;
  validStart: string | null;
  validEnd: string | null;
  severity: string | null;
  top: string | null;
  base: string | null;
  dueTo: string | null;
  geometry: any | null;
}

export interface BriefingTfr {
  notamNumber: string;
  description: string;
  effectiveStart: string | null;
  effectiveEnd: string | null;
  notamText: string | null;
  geometry: any | null;
}

export interface BriefingPirep {
  raw: string;
  location: string | null;
  time: string | null;
  altitude: string | null;
  aircraftType: string | null;
  turbulence: string | null;
  icing: string | null;
  urgency: string;
  latitude: number | null;
  longitude: number | null;
}

export interface WindsAloftCell {
  direction: number | null;
  speed: number | null;
  temperature: number | null;
}

export interface WindsAloftTable {
  waypoints: string[];
  altitudes: number[];
  filedAltitude: number;
  data: WindsAloftCell[][];
}

export interface GfaProduct {
  region: string;
  regionName: string;
  type: string;
  forecastHours: number[];
}

export interface RouteAirport {
  identifier: string;
  icaoIdentifier: string | null;
  name: string;
  city: string | null;
  state: string | null;
  latitude: number;
  longitude: number;
  elevation: number | null;
  facilityType: string | null;
  distanceAlongRoute: number;
  distanceFromRoute: number;
}

export interface BriefingFlightSummary {
  id: number;
  departureIdentifier: string;
  destinationIdentifier: string;
  alternateIdentifier: string | null;
  routeString: string | null;
  cruiseAltitude: number | null;
  aircraftIdentifier: string | null;
  aircraftType: string | null;
  etd: string | null;
  eteMinutes: number | null;
  eta: string | null;
  distanceNm: number | null;
  waypoints: BriefingWaypoint[];
}

export interface AdverseConditions {
  tfrs: BriefingTfr[];
  closedUnsafeNotams: BriefingNotam[];
  convectiveSigmets: BriefingAdvisory[];
  sigmets: BriefingAdvisory[];
  airmets: {
    ifr: BriefingAdvisory[];
    mountainObscuration: BriefingAdvisory[];
    icing: BriefingAdvisory[];
    turbulenceLow: BriefingAdvisory[];
    turbulenceHigh: BriefingAdvisory[];
    lowLevelWindShear: BriefingAdvisory[];
    other: BriefingAdvisory[];
  };
  urgentPireps: BriefingPirep[];
}

export interface Synopsis {
  surfaceAnalysisUrl: string;
}

export interface CurrentWeather {
  metars: BriefingMetar[];
  pireps: BriefingPirep[];
}

export interface Forecasts {
  gfaCloudProducts: GfaProduct[];
  gfaSurfaceProducts: GfaProduct[];
  tafs: BriefingTaf[];
  windsAloftTable: WindsAloftTable | null;
}

export interface BriefingNotams {
  departure: CategorizedNotams | null;
  destination: CategorizedNotams | null;
  alternate1: CategorizedNotams | null;
  alternate2: CategorizedNotams | null;
  enroute: EnrouteNotams;
  artcc: CategorizedNotams[];
}

export interface BriefingResponse {
  flight: BriefingFlightSummary;
  routeAirports: RouteAirport[];
  adverseConditions: AdverseConditions;
  synopsis: Synopsis;
  currentWeather: CurrentWeather;
  forecasts: Forecasts;
  notams: BriefingNotams;
}
