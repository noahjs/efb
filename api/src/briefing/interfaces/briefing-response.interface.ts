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
  temp: number | null;
  dewp: number | null;
  wdir: number | null;
  wspd: number | null;
  wgst: number | null;
  visib: number | null;
  altim: number | null;
  clouds: Array<{ cover: string; base: number | null }>;
  ceiling: number | null;
}

export interface TafForecastPeriod {
  timeFrom: string;
  timeTo: string;
  changeType: string;
  wdir: number | null;
  wspd: number | null;
  wgst: number | null;
  visib: number | null;
  clouds: Array<{ cover: string; base: number | null }>;
  fltCat: string | null;
}

export interface BriefingTaf {
  station: string;
  icaoId: string;
  rawTaf: string | null;
  section: 'departure' | 'route' | 'destination';
  fcsts: TafForecastPeriod[];
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

export interface AffectedSegment {
  fromWaypoint: string;
  toWaypoint: string;
  fromDistNm: number;
  toDistNm: number;
  fromEtaMin: number;
  toEtaMin: number;
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
  topFt: number | null;
  baseFt: number | null;
  altitudeRelation: 'within' | 'above' | 'below' | null;
  affectedSegment: AffectedSegment | null;
  plainEnglish: string | null;
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
  phaseProfile: FlightPhaseProfile | null;
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

// Risk Assessment types
export type RiskLevel = 'green' | 'yellow' | 'red';

export interface RiskCategory {
  category: string;
  level: RiskLevel;
  alerts: string[];
}

export interface RiskSummary {
  overallLevel: RiskLevel;
  categories: RiskCategory[];
  criticalItems: string[];
}

// Flight Phase Profile
export interface FlightPhaseProfile {
  departureElevationFt: number;
  destinationElevationFt: number;
  cruiseAltitudeFt: number;
  tocDistanceNm: number;
  todDistanceNm: number;
  totalDistanceNm: number;
}

// Route Timeline types
export interface TimelineHazard {
  type: string;
  description: string;
  altitudeRelation: string | null;
  alertLevel: 'red' | 'yellow' | 'green';
}

export interface TimelinePoint {
  waypoint: string;
  latitude: number;
  longitude: number;
  distanceFromDep: number;
  etaMinutes: number;
  etaZulu: string | null;
  flightPhase: 'climb' | 'cruise' | 'descent' | null;
  estimatedAltitudeFt: number | null;
  nearestStation: string | null;
  flightCategory: string | null;
  ceiling: number | null;
  visibility: number | null;
  windDir: number | null;
  windSpd: number | null;
  forecastAtEta: TafForecastPeriod | null;
  headwindComponent: number | null;
  crosswindComponent: number | null;
  activeHazards: TimelineHazard[];
}

export interface BriefingResponse {
  flight: BriefingFlightSummary;
  routeAirports: RouteAirport[];
  adverseConditions: AdverseConditions;
  synopsis: Synopsis;
  currentWeather: CurrentWeather;
  forecasts: Forecasts;
  notams: BriefingNotams;
  riskSummary: RiskSummary;
  routeTimeline: TimelinePoint[];
}
