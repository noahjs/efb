import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, Like, ILike } from 'typeorm';
import { Airport, Runway, Frequency } from './entities';
import { Fbo } from '../fbos/entities/fbo.entity';
import { AIRPORTS } from '../config/constants';
import {
  computeBoundingBox,
  getPositionAlongRoute,
} from '../briefing/utils/route-corridor.util';

@Injectable()
export class AirportsService {
  constructor(
    @InjectRepository(Airport)
    private airportRepo: Repository<Airport>,
    @InjectRepository(Runway)
    private runwayRepo: Repository<Runway>,
    @InjectRepository(Frequency)
    private frequencyRepo: Repository<Frequency>,
    @InjectRepository(Fbo)
    private fboRepo: Repository<Fbo>,
  ) {}

  async search(
    query?: string,
    state?: string,
    limit = AIRPORTS.SEARCH_DEFAULT_LIMIT,
    offset = 0,
  ) {
    const qb = this.airportRepo.createQueryBuilder('airport');

    if (query) {
      const q = `%${query}%`;
      qb.where(
        '(airport.identifier LIKE :q OR airport.icao_identifier LIKE :q OR airport.name LIKE :q OR airport.city LIKE :q)',
        { q },
      );
    }

    if (state) {
      qb.andWhere('airport.state = :state', { state });
    }

    qb.orderBy('airport.identifier', 'ASC').skip(offset).take(limit);

    const [items, total] = await qb.getManyAndCount();
    return { items, total, limit, offset };
  }

  async findById(identifier: string) {
    return this.airportRepo.findOne({
      where: [{ identifier }, { icao_identifier: identifier }],
      relations: ['runways', 'runways.ends', 'frequencies'],
    });
  }

  /** Lightweight lookup — returns the airport row without relations. */
  async findByIdLean(identifier: string) {
    return this.airportRepo.findOne({
      where: [{ identifier }, { icao_identifier: identifier }],
    });
  }

  async findNearby(
    lat: number,
    lng: number,
    radiusNm = AIRPORTS.NEARBY_DEFAULT_RADIUS_NM,
    limit = AIRPORTS.NEARBY_DEFAULT_LIMIT,
  ) {
    // Simple bounding-box approximation: 1 degree ~= 60nm
    const degRange = radiusNm / 60;

    const airports = await this.airportRepo
      .createQueryBuilder('airport')
      .where('airport.latitude BETWEEN :minLat AND :maxLat', {
        minLat: lat - degRange,
        maxLat: lat + degRange,
      })
      .andWhere('airport.longitude BETWEEN :minLng AND :maxLng', {
        minLng: lng - degRange,
        maxLng: lng + degRange,
      })
      .orderBy('airport.identifier', 'ASC')
      .take(limit)
      .getMany();

    // Compute distance and sort
    return airports
      .map((a) => ({
        ...a,
        distance_nm: this.haversineNm(
          lat,
          lng,
          a.latitude ?? 0,
          a.longitude ?? 0,
        ),
      }))
      .sort((a, b) => a.distance_nm - b.distance_nm);
  }

  async getRunways(identifier: string) {
    const faaId = await this.resolveFaaIdentifier(identifier);
    return this.runwayRepo.find({
      where: { airport_identifier: faaId },
      relations: ['ends'],
    });
  }

  async getFrequencies(identifier: string) {
    const faaId = await this.resolveFaaIdentifier(identifier);
    return this.frequencyRepo.find({
      where: { airport_identifier: faaId },
      order: { type: 'ASC' },
    });
  }

  async getFbos(identifier: string) {
    const faaId = await this.resolveFaaIdentifier(identifier);
    return this.fboRepo.find({
      where: { airport_identifier: faaId },
      relations: ['fuel_prices'],
      order: { name: 'ASC' },
    });
  }

  /**
   * Resolve an identifier (FAA or ICAO) to the FAA 3-letter code.
   * If the identifier matches an airport's icao_identifier, returns the
   * FAA identifier. Otherwise returns the input unchanged.
   */
  private async resolveFaaIdentifier(identifier: string): Promise<string> {
    const airport = await this.airportRepo.findOne({
      where: [{ identifier }, { icao_identifier: identifier }],
      select: ['identifier'],
    });
    return airport?.identifier ?? identifier;
  }

  /**
   * Bulk fetch airports within a geographic bounding box.
   * Used by the map to render airport markers.
   */
  async getInBounds(
    minLat: number,
    maxLat: number,
    minLng: number,
    maxLng: number,
    limit = AIRPORTS.BOUNDS_QUERY_LIMIT,
  ) {
    const airports = await this.airportRepo
      .createQueryBuilder('airport')
      .where('airport.latitude BETWEEN :minLat AND :maxLat', { minLat, maxLat })
      .andWhere('airport.longitude BETWEEN :minLng AND :maxLng', {
        minLng,
        maxLng,
      })
      .take(limit)
      .getMany();

    if (airports.length === 0) return airports;

    const ids = airports.map((a) => a.identifier);

    // Determine which airports have at least one hard-surface runway
    const hardRows: { airport_identifier: string }[] = await this.runwayRepo
      .createQueryBuilder('r')
      .select('DISTINCT r.airport_identifier', 'airport_identifier')
      .where('r.airport_identifier IN (:...ids)', { ids })
      .andWhere(
        "(r.surface LIKE 'ASPH%' OR r.surface LIKE 'CONC%' OR r.surface IN ('PFC', 'BRICK', 'METAL', 'STEEL', 'ALUMINUM', 'ALUM'))",
      )
      .getRawMany();
    const hardSet = new Set(hardRows.map((r) => r.airport_identifier));

    // Determine which airports have a control tower (TWR frequency)
    const towerRows: { airport_identifier: string }[] =
      await this.frequencyRepo
        .createQueryBuilder('f')
        .select('DISTINCT f.airport_identifier', 'airport_identifier')
        .where('f.airport_identifier IN (:...ids)', { ids })
        .andWhere("f.type = 'TWR'")
        .getRawMany();
    const towerSet = new Set(towerRows.map((r) => r.airport_identifier));

    return airports.map((a) => ({
      ...a,
      has_hard_surface: hardSet.has(a.identifier),
      has_tower: towerSet.has(a.identifier),
    }));
  }

  /**
   * Find all airports within a corridor of the given route.
   * Returns airports sorted by their position along the route,
   * with distanceAlongRoute (nm from departure) and distanceFromRoute (nm off-track).
   */
  async findAirportsInCorridor(
    waypoints: { latitude: number; longitude: number }[],
    corridorNm: number,
  ): Promise<
    (Airport & { distanceAlongRoute: number; distanceFromRoute: number })[]
  > {
    if (waypoints.length < 2) return [];

    const bbox = computeBoundingBox(waypoints, corridorNm);

    const candidates = await this.airportRepo
      .createQueryBuilder('airport')
      .where('airport.latitude BETWEEN :minLat AND :maxLat', {
        minLat: bbox.minLat,
        maxLat: bbox.maxLat,
      })
      .andWhere('airport.longitude BETWEEN :minLng AND :maxLng', {
        minLng: bbox.minLng,
        maxLng: bbox.maxLng,
      })
      .getMany();

    const results: (Airport & {
      distanceAlongRoute: number;
      distanceFromRoute: number;
    })[] = [];

    for (const airport of candidates) {
      if (airport.latitude == null || airport.longitude == null) continue;

      const pos = getPositionAlongRoute(
        airport.latitude,
        airport.longitude,
        waypoints,
        corridorNm,
      );

      if (pos.inCorridor) {
        results.push(
          Object.assign(airport, {
            distanceAlongRoute: Math.round(pos.alongTrackNm),
            distanceFromRoute: Math.round(pos.crossTrackNm * 10) / 10,
          }),
        );
      }
    }

    return results.sort((a, b) => a.distanceAlongRoute - b.distanceAlongRoute);
  }

  private haversineNm(
    lat1: number,
    lon1: number,
    lat2: number,
    lon2: number,
  ): number {
    const R = AIRPORTS.EARTH_RADIUS_NM;
    const dLat = this.toRad(lat2 - lat1);
    const dLon = this.toRad(lon2 - lon1);
    const a =
      Math.sin(dLat / 2) ** 2 +
      Math.cos(this.toRad(lat1)) *
        Math.cos(this.toRad(lat2)) *
        Math.sin(dLon / 2) ** 2;
    return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  }

  private toRad(deg: number): number {
    return (deg * Math.PI) / 180;
  }
}
