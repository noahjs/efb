import { Injectable, Logger, NotFoundException } from '@nestjs/common';
import { FlightsService } from '../flights/flights.service';
import { WeatherService } from '../weather/weather.service';
import { ImageryService } from '../imagery/imagery.service';
import { WindyService } from '../windy/windy.service';
import { CalculateService } from '../calculate/calculate.service';
import { AirspacesService } from '../airspaces/airspaces.service';
import { AirportsService } from '../airports/airports.service';
import {
  BriefingResponse,
  BriefingWaypoint,
  BriefingMetar,
  BriefingTaf,
  BriefingNotam,
  BriefingAdvisory,
  BriefingTfr,
  BriefingPirep,
  CategorizedNotams,
  EnrouteNotams,
  WindsAloftTable,
  WindsAloftCell,
  GfaProduct,
  TafForecastPeriod,
} from './interfaces/briefing-response.interface';
import {
  computeBoundingBox,
  haversineNm,
  isPointInCorridor,
  doesPolygonIntersectCorridor,
} from './utils/route-corridor.util';
import {
  parseNotam,
  isClosureNotam,
  categorizeNotamList,
  categorizeEnrouteNotams,
} from './utils/notam-categorizer.util';
import { determineGfaRegions } from './utils/gfa-region.util';
import { contextualizeAdvisories } from './utils/advisory-context.util';
import { computeRiskSummary } from './utils/risk-assessment.util';
import { buildRouteTimeline } from './utils/route-timeline.util';
import { BRIEFING } from '../config/constants';

@Injectable()
export class BriefingService {
  private readonly logger = new Logger(BriefingService.name);

  constructor(
    private readonly flightsService: FlightsService,
    private readonly weatherService: WeatherService,
    private readonly imageryService: ImageryService,
    private readonly windyService: WindyService,
    private readonly calculateService: CalculateService,
    private readonly airspacesService: AirspacesService,
    private readonly airportsService: AirportsService,
  ) {}

  /**
   * Get briefing — returns cached version if available, otherwise generates fresh.
   */
  async getBriefing(
    flightId: number,
    userId: string,
    regenerate = false,
  ): Promise<BriefingResponse & { generatedAt: string }> {
    if (!regenerate) {
      const flight = await this.flightsService.findById(flightId, userId);
      if (!flight) throw new NotFoundException('Flight not found');

      if (flight.briefing_data && flight.briefing_generated_at) {
        return {
          ...(flight.briefing_data as BriefingResponse),
          generatedAt: flight.briefing_generated_at.toISOString(),
        };
      }
    }

    const briefing = await this.generateBriefing(flightId, userId);
    const generatedAt = new Date();

    // Save to flight record (fire-and-forget, don't block response)
    this.flightsService
      .saveBriefing(flightId, briefing as any, userId)
      .catch((e) => this.logger.warn('Failed to cache briefing', e));

    return {
      ...briefing,
      generatedAt: generatedAt.toISOString(),
    };
  }

  /**
   * Get all airports within a corridor of the flight's route.
   */
  async getRouteAirports(
    flightId: number,
    userId: string,
    corridorNm = BRIEFING.ROUTE_CORRIDOR_NM,
  ) {
    const flight = await this.flightsService.findById(flightId, userId);
    if (!flight) {
      throw new NotFoundException('Flight not found');
    }
    if (!flight.departure_identifier || !flight.destination_identifier) {
      throw new NotFoundException(
        'Flight must have departure and destination set',
      );
    }

    const calcResult = await this.calculateService.calculate({
      departure_identifier: flight.departure_identifier,
      destination_identifier: flight.destination_identifier,
      route_string: flight.route_string,
      cruise_altitude: flight.cruise_altitude,
      true_airspeed: flight.true_airspeed,
      fuel_burn_rate: flight.fuel_burn_rate,
      etd: flight.etd,
      performance_profile_id: flight.performance_profile_id,
    });

    const waypoints = this.enrichWaypoints(
      calcResult.waypoints,
      calcResult.ete_minutes,
    );

    const airports = await this.airportsService.findAirportsInCorridor(
      waypoints,
      corridorNm,
    );

    return {
      corridorNm,
      totalRoute: calcResult.distance_nm,
      count: airports.length,
      airports: airports.map((a) => ({
        identifier: a.identifier,
        icaoIdentifier: a.icao_identifier,
        name: a.name,
        city: a.city,
        state: a.state,
        latitude: a.latitude,
        longitude: a.longitude,
        elevation: a.elevation,
        facilityType: a.facility_type,
        distanceAlongRoute: a.distanceAlongRoute,
        distanceFromRoute: a.distanceFromRoute,
      })),
    };
  }

  async generateBriefing(
    flightId: number,
    userId: string,
  ): Promise<BriefingResponse> {
    // 1. Load the flight
    const flight = await this.flightsService.findById(flightId, userId);
    if (!flight) {
      throw new NotFoundException('Flight not found');
    }

    if (!flight.departure_identifier || !flight.destination_identifier) {
      throw new NotFoundException(
        'Flight must have departure and destination set',
      );
    }

    // 2. Compute route waypoints
    const calcResult = await this.calculateService.calculate({
      departure_identifier: flight.departure_identifier,
      destination_identifier: flight.destination_identifier,
      route_string: flight.route_string,
      cruise_altitude: flight.cruise_altitude,
      true_airspeed: flight.true_airspeed,
      fuel_burn_rate: flight.fuel_burn_rate,
      etd: flight.etd,
      performance_profile_id: flight.performance_profile_id,
    });

    // 3. Enrich waypoints with cumulative distance and ETA
    const waypoints = this.enrichWaypoints(
      calcResult.waypoints,
      calcResult.ete_minutes,
    );

    // 4. Compute bounding box
    const bbox = computeBoundingBox(waypoints, BRIEFING.ROUTE_CORRIDOR_NM);

    // 5. Find all airports along the route corridor
    const corridorAirports = await this.airportsService.findAirportsInCorridor(
      waypoints,
      BRIEFING.ROUTE_CORRIDOR_NM,
    );

    // Exclude departure/destination, then sample at intervals for weather queries
    const excludeIds = new Set([
      flight.departure_identifier.toUpperCase(),
      flight.destination_identifier.toUpperCase(),
    ]);
    const enrouteAirports = corridorAirports.filter(
      (a) =>
        !excludeIds.has(a.identifier.toUpperCase()) &&
        !excludeIds.has((a.icao_identifier || '').toUpperCase()),
    );

    // Sample enroute airports at ~75nm intervals for weather/NOTAM queries
    const routeStations = this.sampleAtIntervals(
      enrouteAirports,
      BRIEFING.ROUTE_STATION_INTERVAL_NM,
    );

    // 6. Build station list: departure + route + destination
    const depIcao =
      (await this.getIcaoId(flight.departure_identifier)) ||
      flight.departure_identifier;
    const destIcao =
      (await this.getIcaoId(flight.destination_identifier)) ||
      flight.destination_identifier;
    const altIcao = flight.alternate_identifier
      ? (await this.getIcaoId(flight.alternate_identifier)) ||
        flight.alternate_identifier
      : null;

    // 7. Find ARTCC IDs along route
    const artccIds = await this.findArtccsAlongRoute(bbox);

    // 8. Determine GFA regions
    const gfaRegions = determineGfaRegions(waypoints);

    // 9. Parallel fetch all data sources
    const bboxStr = `${bbox.minLat},${bbox.minLng},${bbox.maxLat},${bbox.maxLng}`;

    const [
      depNotamsResult,
      destNotamsResult,
      altNotamsResult,
      tfrsResult,
      gairmetsResult,
      sigmetsResult,
      cwasResult,
      pirepsResult,
      ...stationResults
    ] = await Promise.allSettled([
      this.weatherService.getNotams(depIcao),
      this.weatherService.getNotams(destIcao),
      altIcao ? this.weatherService.getNotams(altIcao) : Promise.resolve(null),
      this.imageryService.getTfrs(),
      this.imageryService.getAdvisories('gairmets'),
      this.imageryService.getAdvisories('sigmets'),
      this.imageryService.getAdvisories('cwas'),
      this.imageryService.getPireps(bboxStr, BRIEFING.PIREP_AGE_HOURS),
      // METARs and TAFs for all stations
      ...this.buildStationFetches(depIcao, destIcao, routeStations),
    ]);

    // Fetch enroute + ARTCC NOTAMs sequentially to avoid FAA rate limiting
    const enrouteNotamResults = await this.fetchNotamsThrottled(
      routeStations.map((s) => s.icaoId || s.identifier),
    );
    const artccNotamResults = await this.fetchNotamsThrottled(artccIds);

    // Fetch winds aloft data
    let windsTable: WindsAloftTable | null = null;
    try {
      windsTable = await this.buildWindsAloftTable(
        waypoints,
        flight.cruise_altitude || 10000,
      );
    } catch (e) {
      this.logger.warn('Failed to build winds aloft table', e);
    }

    // 10. Process results
    const depNotamsRaw = this.extractResult(depNotamsResult);
    const destNotamsRaw = this.extractResult(destNotamsResult);
    const altNotamsRaw = this.extractResult(altNotamsResult);
    const tfrsRaw = this.extractResult(tfrsResult);
    const gairmetsRaw = this.extractResult(gairmetsResult);
    const sigmetsRaw = this.extractResult(sigmetsResult);
    const cwasRaw = this.extractResult(cwasResult);
    const pirepsRaw = this.extractResult(pirepsResult);

    // Parse NOTAMs
    const depNotams = this.parseNotamResponse(depNotamsRaw, depIcao);
    const destNotams = this.parseNotamResponse(destNotamsRaw, destIcao);
    const altNotams = altIcao
      ? this.parseNotamResponse(altNotamsRaw, altIcao)
      : [];

    // Parse enroute NOTAMs
    const allEnrouteNotams: BriefingNotam[] = [];
    enrouteNotamResults.forEach((result, idx) => {
      const raw = this.extractResult(result);
      const station = routeStations[idx];
      const parsed = this.parseNotamResponse(
        raw,
        station.icaoId || station.identifier,
      );
      allEnrouteNotams.push(...parsed);
    });

    // Parse ARTCC NOTAMs
    const artccNotamSets: CategorizedNotams[] = artccIds.map((id, idx) => {
      const raw = this.extractResult(artccNotamResults[idx]);
      const parsed = this.parseNotamResponse(raw, id);
      return categorizeNotamList(parsed);
    });

    // Extract closure NOTAMs
    const closedUnsafeNotams = [
      ...depNotams.filter(
        (n) => isClosureNotam(n.text) || isClosureNotam(n.fullText),
      ),
      ...destNotams.filter(
        (n) => isClosureNotam(n.text) || isClosureNotam(n.fullText),
      ),
    ];

    // Filter TFRs by route corridor
    const filteredTfrs = this.filterTfrs(tfrsRaw, waypoints);

    // Filter and categorize advisories
    const categorizedAirmets = this.categorizeAirmets(gairmetsRaw, waypoints);
    const filteredSigmets = this.filterAdvisories(sigmetsRaw, waypoints);
    const filteredConvSigmets = this.filterAdvisories(cwasRaw, waypoints);

    // Filter PIREPs
    const allPireps = this.filterPireps(pirepsRaw, waypoints);
    const urgentPireps = allPireps.filter((p) => p.urgency === 'UUA');

    // Process METARs and TAFs from station results
    const { metars, tafs } = this.processStationResults(
      stationResults,
      depIcao,
      destIcao,
      routeStations,
    );

    // Build GFA products
    const gfaCloudProducts: GfaProduct[] = gfaRegions.map((r) => ({
      region: r.region,
      regionName: r.regionName,
      type: 'clouds',
      forecastHours: [3, 6, 9, 12, 15, 18],
    }));
    const gfaSurfaceProducts: GfaProduct[] = gfaRegions.map((r) => ({
      region: r.region,
      regionName: r.regionName,
      type: 'sfc',
      forecastHours: [3, 6, 9, 12, 15, 18],
    }));

    // 11. Contextualize advisories with route segment and altitude info
    const cruiseAlt = flight.cruise_altitude || null;
    const allAirmetArrays = [
      categorizedAirmets.ifr,
      categorizedAirmets.mountainObscuration,
      categorizedAirmets.icing,
      categorizedAirmets.turbulenceLow,
      categorizedAirmets.turbulenceHigh,
      categorizedAirmets.lowLevelWindShear,
      categorizedAirmets.other,
    ];
    for (const arr of allAirmetArrays) {
      contextualizeAdvisories(arr, waypoints, cruiseAlt);
    }
    contextualizeAdvisories(filteredSigmets, waypoints, cruiseAlt);
    contextualizeAdvisories(filteredConvSigmets, waypoints, cruiseAlt);

    // 12. Assemble response
    const briefingResponse: BriefingResponse = {
      flight: {
        id: flight.id,
        departureIdentifier: flight.departure_identifier,
        destinationIdentifier: flight.destination_identifier,
        alternateIdentifier: flight.alternate_identifier || null,
        routeString: flight.route_string || null,
        cruiseAltitude: flight.cruise_altitude || null,
        aircraftIdentifier: flight.aircraft_identifier || null,
        aircraftType: flight.aircraft_type || null,
        etd: flight.etd || null,
        eteMinutes: calcResult.ete_minutes,
        eta: calcResult.eta,
        distanceNm: calcResult.distance_nm,
        waypoints,
      },
      routeAirports: corridorAirports.map((a) => ({
        identifier: a.identifier,
        icaoIdentifier: a.icao_identifier || null,
        name: a.name,
        city: a.city || null,
        state: a.state || null,
        latitude: a.latitude,
        longitude: a.longitude,
        elevation: a.elevation || null,
        facilityType: a.facility_type || null,
        distanceAlongRoute: a.distanceAlongRoute,
        distanceFromRoute: a.distanceFromRoute,
      })),
      adverseConditions: {
        tfrs: filteredTfrs,
        closedUnsafeNotams,
        convectiveSigmets: filteredConvSigmets,
        sigmets: filteredSigmets,
        airmets: categorizedAirmets,
        urgentPireps,
      },
      synopsis: {
        surfaceAnalysisUrl: '/api/imagery/prog/sfc?forecastHour=0',
      },
      currentWeather: {
        metars,
        pireps: allPireps,
      },
      forecasts: {
        gfaCloudProducts,
        gfaSurfaceProducts,
        tafs,
        windsAloftTable: windsTable,
      },
      notams: {
        departure: categorizeNotamList(depNotams),
        destination: categorizeNotamList(destNotams),
        alternate1:
          altNotams.length > 0 ? categorizeNotamList(altNotams) : null,
        alternate2: null,
        enroute: categorizeEnrouteNotams(allEnrouteNotams),
        artcc: artccNotamSets,
      },
      // Placeholders — computed below
      riskSummary: { overallLevel: 'green', categories: [], criticalItems: [] },
      routeTimeline: [],
    };

    // 13. Compute risk summary and route timeline
    briefingResponse.riskSummary = computeRiskSummary(briefingResponse);
    briefingResponse.routeTimeline = buildRouteTimeline(
      briefingResponse,
      flight.etd || null,
    );

    return briefingResponse;
  }

  /**
   * Enrich waypoints with cumulative distance and ETA minutes.
   */
  private enrichWaypoints(
    rawWaypoints: {
      identifier: string;
      latitude: number;
      longitude: number;
      type: string;
    }[],
    totalEteMinutes: number | null,
  ): BriefingWaypoint[] {
    if (rawWaypoints.length === 0) return [];

    // Compute cumulative distances
    let cumDistance = 0;
    const distances: number[] = [0];
    for (let i = 1; i < rawWaypoints.length; i++) {
      const d = haversineNm(
        rawWaypoints[i - 1].latitude,
        rawWaypoints[i - 1].longitude,
        rawWaypoints[i].latitude,
        rawWaypoints[i].longitude,
      );
      cumDistance += d;
      distances.push(cumDistance);
    }

    const totalDist = cumDistance || 1;

    return rawWaypoints.map((wp, i) => ({
      identifier: wp.identifier,
      latitude: wp.latitude,
      longitude: wp.longitude,
      type: wp.type,
      distanceFromDep: Math.round(distances[i]),
      etaMinutes:
        totalEteMinutes != null
          ? Math.round((distances[i] / totalDist) * totalEteMinutes)
          : 0,
    }));
  }

  /**
   * Get ICAO identifier for an airport (4-letter).
   */
  private async getIcaoId(identifier: string): Promise<string | null> {
    try {
      const airport = await this.airportsService.findById(identifier);
      return airport?.icao_identifier || null;
    } catch {
      return null;
    }
  }

  /**
   * Fetch NOTAMs in small sequential batches to avoid FAA rate limiting.
   * Processes 2 at a time with a short delay between batches.
   */
  private async fetchNotamsThrottled(
    identifiers: string[],
  ): Promise<PromiseSettledResult<any>[]> {
    const results: PromiseSettledResult<any>[] = [];
    const batchSize = 2;

    for (let i = 0; i < identifiers.length; i += batchSize) {
      const batch = identifiers.slice(i, i + batchSize);
      const batchResults = await Promise.allSettled(
        batch.map((id) => this.weatherService.getNotams(id)),
      );
      results.push(...batchResults);

      // Small delay between batches to avoid triggering WAF
      if (i + batchSize < identifiers.length) {
        await new Promise((r) => setTimeout(r, 200));
      }
    }

    return results;
  }

  /**
   * Sample airports at roughly even intervals along the route.
   * Picks the airport closest to the route at each interval.
   */
  private sampleAtIntervals(
    airports: {
      identifier: string;
      icao_identifier: string;
      latitude: number;
      longitude: number;
      distanceAlongRoute: number;
      distanceFromRoute: number;
    }[],
    intervalNm: number,
  ): {
    identifier: string;
    icaoId: string;
    lat: number;
    lng: number;
    distanceAlongRoute: number;
    distanceFromRoute: number;
  }[] {
    if (airports.length === 0) return [];

    const sampled: typeof airports = [];
    let lastDist = -intervalNm; // allow first airport

    for (const a of airports) {
      if (a.distanceAlongRoute - lastDist >= intervalNm) {
        sampled.push(a);
        lastDist = a.distanceAlongRoute;
      } else if (
        sampled.length > 0 &&
        a.distanceFromRoute < sampled[sampled.length - 1].distanceFromRoute
      ) {
        // Replace last sample if this airport is closer to the route
        // (within the same interval window)
        if (
          a.distanceAlongRoute - lastDist < intervalNm &&
          a.distanceAlongRoute >= sampled[sampled.length - 1].distanceAlongRoute
        ) {
          sampled[sampled.length - 1] = a;
        }
      }
    }

    return sampled.map((a) => ({
      identifier: a.identifier,
      icaoId: a.icao_identifier || a.identifier,
      lat: a.latitude,
      lng: a.longitude,
      distanceAlongRoute: a.distanceAlongRoute,
      distanceFromRoute: a.distanceFromRoute,
    }));
  }

  /**
   * Find ARTCC IDs along the route.
   */
  private async findArtccsAlongRoute(bbox: {
    minLat: number;
    maxLat: number;
    minLng: number;
    maxLng: number;
  }): Promise<string[]> {
    try {
      const result = await this.airspacesService.getArtccInBounds(
        bbox.minLat,
        bbox.maxLat,
        bbox.minLng,
        bbox.maxLng,
      );
      const features = result?.features || [];
      const ids = new Set<string>();
      for (const f of features) {
        const artccId = f.properties?.artcc_id;
        if (artccId) ids.add(artccId);
      }
      return Array.from(ids);
    } catch {
      return [];
    }
  }

  /**
   * Build parallel METAR/TAF fetch promises for all stations.
   */
  private buildStationFetches(
    depIcao: string,
    destIcao: string,
    routeStations: { identifier: string; icaoId: string }[],
  ): Promise<any>[] {
    const allStations = [
      depIcao,
      ...routeStations.map((s) => s.icaoId || s.identifier),
      destIcao,
    ];

    const fetches: Promise<any>[] = [];
    for (const station of allStations) {
      fetches.push(this.weatherService.getMetar(station));
      fetches.push(this.weatherService.getTaf(station));
    }
    return fetches;
  }

  /**
   * Process station METAR/TAF results into typed arrays.
   */
  private processStationResults(
    results: PromiseSettledResult<any>[],
    depIcao: string,
    destIcao: string,
    routeStations: { identifier: string; icaoId: string }[],
  ): { metars: BriefingMetar[]; tafs: BriefingTaf[] } {
    const allStations = [
      depIcao,
      ...routeStations.map((s) => s.icaoId || s.identifier),
      destIcao,
    ];

    const metars: BriefingMetar[] = [];
    const tafs: BriefingTaf[] = [];

    for (let i = 0; i < allStations.length; i++) {
      const station = allStations[i];
      const metarIdx = i * 2;
      const tafIdx = i * 2 + 1;

      let section: 'departure' | 'route' | 'destination' = 'route';
      if (i === 0) section = 'departure';
      else if (i === allStations.length - 1) section = 'destination';

      const metarData = this.extractResult(results[metarIdx]);
      if (metarData) {
        const clouds = this.parseClouds(metarData.clouds);
        metars.push({
          station,
          icaoId: metarData.icaoId || station,
          flightCategory: metarData.fltCat || null,
          rawOb: metarData.rawOb || null,
          obsTime:
            (metarData.reportTime ?? metarData.obsTime)?.toString() || null,
          section,
          temp: metarData.temp ?? null,
          dewp: metarData.dewp ?? null,
          wdir: metarData.wdir ?? null,
          wspd: metarData.wspd ?? null,
          wgst: metarData.wgst ?? null,
          visib: metarData.visib ?? null,
          altim: metarData.altim ?? null,
          clouds,
          ceiling: this.computeCeiling(clouds),
        });
      }

      const tafData = this.extractResult(results[tafIdx]);
      if (tafData) {
        tafs.push({
          station,
          icaoId: tafData.icaoId || station,
          rawTaf: tafData.rawTAF || tafData.rawOb || null,
          section,
          fcsts: this.parseTafForecasts(tafData.fcsts),
        });
      }
    }

    return { metars, tafs };
  }

  /**
   * Parse NOTAM API response into BriefingNotam[].
   */
  private parseNotamResponse(raw: any, icaoId: string): BriefingNotam[] {
    if (!raw) return [];
    const notamList = raw.notamList || raw.notams || [];
    if (!Array.isArray(notamList)) return [];

    return notamList
      .filter((n: any) => !n.cancelledOrExpired)
      .map((n: any) => parseNotam(n, icaoId));
  }

  /**
   * Filter TFRs by route corridor.
   */
  private filterTfrs(
    tfrsData: any,
    waypoints: BriefingWaypoint[],
  ): BriefingTfr[] {
    if (!tfrsData?.features) return [];

    return tfrsData.features
      .filter((feature: any) =>
        doesPolygonIntersectCorridor(
          feature.geometry,
          waypoints,
          BRIEFING.ROUTE_CORRIDOR_NM,
        ),
      )
      .map((feature: any) => ({
        notamNumber:
          feature.properties?.NOTAM_KEY || feature.properties?.notam_id || '',
        description:
          feature.properties?.TITLE || feature.properties?.description || '',
        effectiveStart: feature.properties?.effective_start || null,
        effectiveEnd: feature.properties?.effective_end || null,
        notamText: feature.properties?.notam_text || null,
        geometry: feature.geometry || null,
      }));
  }

  /**
   * Filter and categorize G-AIRMETs into subtypes.
   */
  private categorizeAirmets(
    data: any,
    waypoints: BriefingWaypoint[],
  ): {
    ifr: BriefingAdvisory[];
    mountainObscuration: BriefingAdvisory[];
    icing: BriefingAdvisory[];
    turbulenceLow: BriefingAdvisory[];
    turbulenceHigh: BriefingAdvisory[];
    lowLevelWindShear: BriefingAdvisory[];
    other: BriefingAdvisory[];
  } {
    const result = {
      ifr: [] as BriefingAdvisory[],
      mountainObscuration: [] as BriefingAdvisory[],
      icing: [] as BriefingAdvisory[],
      turbulenceLow: [] as BriefingAdvisory[],
      turbulenceHigh: [] as BriefingAdvisory[],
      lowLevelWindShear: [] as BriefingAdvisory[],
      other: [] as BriefingAdvisory[],
    };

    if (!data?.features) return result;

    for (const feature of data.features) {
      if (
        !doesPolygonIntersectCorridor(
          feature.geometry,
          waypoints,
          BRIEFING.ROUTE_CORRIDOR_NM,
        )
      ) {
        continue;
      }

      const advisory = this.parseAdvisory(feature);
      const hazard = (
        feature.properties?.hazard ||
        feature.properties?.hazardType ||
        ''
      )
        .toLowerCase()
        .trim();

      if (hazard.includes('ifr')) result.ifr.push(advisory);
      else if (hazard.includes('mtn') || hazard.includes('mountain'))
        result.mountainObscuration.push(advisory);
      else if (hazard.includes('ice') || hazard.includes('icing'))
        result.icing.push(advisory);
      else if (hazard.includes('turb') && hazard.includes('lo'))
        result.turbulenceLow.push(advisory);
      else if (hazard.includes('turb')) result.turbulenceHigh.push(advisory);
      else if (hazard.includes('llws') || hazard.includes('wind shear'))
        result.lowLevelWindShear.push(advisory);
      else result.other.push(advisory);
    }

    return result;
  }

  /**
   * Filter advisories (SIGMETs, Convective) by route corridor.
   */
  private filterAdvisories(
    data: any,
    waypoints: BriefingWaypoint[],
  ): BriefingAdvisory[] {
    if (!data?.features) return [];

    return data.features
      .filter((feature: any) =>
        doesPolygonIntersectCorridor(
          feature.geometry,
          waypoints,
          BRIEFING.ROUTE_CORRIDOR_NM,
        ),
      )
      .map((feature: any) => this.parseAdvisory(feature));
  }

  /**
   * Parse a GeoJSON advisory feature into BriefingAdvisory.
   */
  private parseAdvisory(feature: any): BriefingAdvisory {
    const props = feature.properties || {};
    return {
      hazardType: props.hazard || props.hazardType || props.type || 'Unknown',
      rawText: props.rawAirSigmet || props.rawText || props.text || '',
      validStart: props.validTimeFrom || props.validStart || null,
      validEnd: props.validTimeTo || props.validEnd || null,
      severity: props.severity || props.sev || null,
      top: props.top != null ? String(props.top) : null,
      base: props.base != null ? String(props.base) : null,
      dueTo: props.dueTo || props.cause || null,
      geometry: feature.geometry || null,
      topFt: null,
      baseFt: null,
      altitudeRelation: null,
      affectedSegment: null,
      plainEnglish: null,
    };
  }

  /**
   * Filter PIREPs by route corridor.
   */
  private filterPireps(
    data: any,
    waypoints: BriefingWaypoint[],
  ): BriefingPirep[] {
    if (!data?.features) return [];

    return data.features
      .filter((feature: any) => {
        const coords = feature.geometry?.coordinates;
        if (!coords || coords.length < 2) return false;
        return isPointInCorridor(
          coords[1],
          coords[0],
          waypoints,
          BRIEFING.ROUTE_CORRIDOR_NM,
        );
      })
      .map((feature: any) => {
        const props = feature.properties || {};
        const coords = feature.geometry?.coordinates || [];
        return {
          raw: props.rawOb || props.raw || '',
          location: props.icaoId || props.location || null,
          time: (props.obsTime ?? props.time)?.toString() || null,
          altitude: props.fltlvl != null ? String(props.fltlvl) : null,
          aircraftType: props.acType || props.aircraftType || null,
          turbulence: props.tbInt1
            ? `${props.tbInt1 || ''} ${props.tbType1 || ''} ${props.tbFreq1 || ''}`.trim()
            : null,
          icing: props.icgInt1
            ? `${props.icgInt1 || ''} ${props.icgType1 || ''}`.trim()
            : null,
          urgency: props.airepType === 'URGENT PIREP' ? 'UUA' : 'UA',
          latitude: coords[1] ?? null,
          longitude: coords[0] ?? null,
        };
      });
  }

  /**
   * Build winds aloft table from wind point forecasts.
   */
  private async buildWindsAloftTable(
    waypoints: BriefingWaypoint[],
    filedAltitude: number,
  ): Promise<WindsAloftTable> {
    const step = BRIEFING.WINDS_TABLE_ALTITUDE_STEP;
    const range = BRIEFING.WINDS_TABLE_ALTITUDE_RANGE;
    const minAlt = Math.max(0, filedAltitude - range);
    const maxAlt = filedAltitude + range;

    // Build altitude columns
    const altitudes: number[] = [];
    for (let alt = minAlt; alt <= maxAlt; alt += step) {
      altitudes.push(alt);
    }
    // Ensure filed altitude is included
    if (!altitudes.includes(filedAltitude)) {
      altitudes.push(filedAltitude);
      altitudes.sort((a, b) => a - b);
    }

    // Sample waypoints (max ~8 for table readability)
    const sampleWaypoints = this.sampleWaypointsForTable(waypoints, 8);

    // Fetch wind data for each waypoint
    const points = sampleWaypoints.map((wp) => ({
      lat: wp.latitude,
      lng: wp.longitude,
    }));

    let forecasts: any[] = [];
    try {
      forecasts = await this.windyService.getBatchForecasts(points);
    } catch (e) {
      this.logger.warn('Failed to fetch batch forecasts for winds table', e);
    }

    // Build data matrix
    const data: WindsAloftCell[][] = [];
    for (let wpIdx = 0; wpIdx < sampleWaypoints.length; wpIdx++) {
      const row: WindsAloftCell[] = [];
      const forecast = forecasts[wpIdx];

      for (const alt of altitudes) {
        const cell = this.extractWindAtAltitude(forecast, alt);
        row.push(cell);
      }
      data.push(row);
    }

    return {
      waypoints: sampleWaypoints.map((wp) => wp.identifier),
      altitudes,
      filedAltitude,
      data,
    };
  }

  /**
   * Sample waypoints evenly for the winds table.
   */
  private sampleWaypointsForTable(
    waypoints: BriefingWaypoint[],
    maxCount: number,
  ): BriefingWaypoint[] {
    if (waypoints.length <= maxCount) return waypoints;

    const result: BriefingWaypoint[] = [waypoints[0]];
    const step = (waypoints.length - 1) / (maxCount - 1);
    for (let i = 1; i < maxCount - 1; i++) {
      result.push(waypoints[Math.round(i * step)]);
    }
    result.push(waypoints[waypoints.length - 1]);
    return result;
  }

  /**
   * Extract wind data at a specific altitude from a point forecast.
   */
  private extractWindAtAltitude(
    forecast: any,
    altitudeFt: number,
  ): WindsAloftCell {
    if (!forecast?.levels) {
      return { direction: null, speed: null, temperature: null };
    }

    // Find the closest level by altitude
    let bestLevel: any = null;
    let bestDiff = Infinity;
    for (const level of forecast.levels) {
      const diff = Math.abs(level.altitudeFt - altitudeFt);
      if (diff < bestDiff) {
        bestDiff = diff;
        bestLevel = level;
      }
    }

    if (!bestLevel?.winds?.length) {
      return { direction: null, speed: null, temperature: null };
    }

    // Take the first (most recent) wind entry
    const wind = bestLevel.winds[0];
    return {
      direction: wind.direction ?? null,
      speed: wind.speed ?? null,
      temperature: wind.temperature ?? null,
    };
  }

  /**
   * Safely extract result from Promise.allSettled.
   */
  private extractResult(result: PromiseSettledResult<any>): any {
    if (result.status === 'fulfilled') return result.value;
    this.logger.warn('Promise rejected in briefing fetch', result.reason);
    return null;
  }

  /**
   * Parse clouds array from AWC METAR response.
   */
  private parseClouds(
    raw: any,
  ): Array<{ cover: string; base: number | null }> {
    if (!Array.isArray(raw)) return [];
    return raw.map((c: any) => ({
      cover: c.cover || c.type || '',
      base: c.base != null ? Number(c.base) : null,
    }));
  }

  /**
   * Compute ceiling from clouds array (lowest BKN or OVC base).
   */
  private computeCeiling(
    clouds: Array<{ cover: string; base: number | null }>,
  ): number | null {
    let ceiling: number | null = null;
    for (const c of clouds) {
      const cover = (c.cover || '').toUpperCase();
      if ((cover === 'BKN' || cover === 'OVC') && c.base != null) {
        if (ceiling == null || c.base < ceiling) {
          ceiling = c.base;
        }
      }
    }
    return ceiling;
  }

  /**
   * Parse TAF forecast periods from AWC response.
   */
  private parseTafForecasts(raw: any): TafForecastPeriod[] {
    if (!Array.isArray(raw)) return [];
    return raw.map((f: any) => ({
      timeFrom: (f.timeFrom ?? f.fcstTimeFrom ?? '')?.toString(),
      timeTo: (f.timeTo ?? f.fcstTimeTo ?? '')?.toString(),
      changeType: f.changeType || f.change || f.type || 'initial',
      wdir: f.wdir ?? null,
      wspd: f.wspd ?? null,
      wgst: f.wgst ?? null,
      visib: f.visib ?? null,
      clouds: this.parseClouds(f.clouds),
      fltCat: f.fltCat || null,
    }));
  }
}
