import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, ILike } from 'typeorm';
import { Navaid } from './entities/navaid.entity';
import { Fix } from './entities/fix.entity';
import { Airport } from '../airports/entities/airport.entity';
import { CycleQueryHelper } from '../data-cycle/cycle-query.helper';
import { CycleDataGroup } from '../data-cycle/entities/data-cycle.entity';

@Injectable()
export class NavaidsService {
  constructor(
    @InjectRepository(Navaid)
    private navaidRepo: Repository<Navaid>,
    @InjectRepository(Fix)
    private fixRepo: Repository<Fix>,
    @InjectRepository(Airport)
    private airportRepo: Repository<Airport>,
    private readonly cycleHelper: CycleQueryHelper,
  ) {}

  async searchNavaids(query?: string, type?: string, limit = 50) {
    const qb = this.navaidRepo.createQueryBuilder('navaid');
    await this.cycleHelper.applyCycleFilter(qb, 'navaid', CycleDataGroup.NASR);

    if (query) {
      const q = `%${query}%`;
      qb.andWhere('(navaid.identifier ILIKE :q OR navaid.name ILIKE :q)', { q });
    }

    if (type) {
      qb.andWhere('navaid.type = :type', { type });
    }

    qb.orderBy('navaid.identifier', 'ASC').take(limit);

    return qb.getMany();
  }

  async findNavaidById(identifier: string) {
    const cycleWhere = await this.cycleHelper.getCycleWhere(CycleDataGroup.NASR);
    return this.navaidRepo.findOne({ where: { identifier, ...cycleWhere } });
  }

  async getNavaidsInBounds(
    minLat: number,
    maxLat: number,
    minLng: number,
    maxLng: number,
    limit = 200,
  ) {
    const qb = this.navaidRepo
      .createQueryBuilder('navaid')
      .where('navaid.latitude BETWEEN :minLat AND :maxLat', { minLat, maxLat })
      .andWhere('navaid.longitude BETWEEN :minLng AND :maxLng', {
        minLng,
        maxLng,
      });

    await this.cycleHelper.applyCycleFilter(qb, 'navaid', CycleDataGroup.NASR);

    return qb.take(limit).getMany();
  }

  async searchFixes(query?: string, limit = 50) {
    const qb = this.fixRepo.createQueryBuilder('fix');
    await this.cycleHelper.applyCycleFilter(qb, 'fix', CycleDataGroup.NASR);

    if (query) {
      const q = `%${query}%`;
      qb.andWhere('fix.identifier ILIKE :q', { q });
    }

    qb.orderBy('fix.identifier', 'ASC').take(limit);

    return qb.getMany();
  }

  async getFixesInBounds(
    minLat: number,
    maxLat: number,
    minLng: number,
    maxLng: number,
    limit = 200,
  ) {
    const qb = this.fixRepo
      .createQueryBuilder('fix')
      .where('fix.latitude BETWEEN :minLat AND :maxLat', { minLat, maxLat })
      .andWhere('fix.longitude BETWEEN :minLng AND :maxLng', { minLng, maxLng });

    await this.cycleHelper.applyCycleFilter(qb, 'fix', CycleDataGroup.NASR);

    return qb.take(limit).getMany();
  }

  /**
   * Resolve a waypoint identifier to coordinates.
   * Searches airports (by identifier and icao_identifier), then navaids, then fixes.
   */
  async resolveWaypoint(identifier: string): Promise<{
    identifier: string;
    latitude: number;
    longitude: number;
    type: string;
  } | null> {
    const id = identifier.trim();
    const cycleWhere = await this.cycleHelper.getCycleWhere(CycleDataGroup.NASR);

    // Try airport (FAA id or ICAO id) — case-insensitive
    const airport = await this.airportRepo.findOne({
      where: [
        { identifier: ILike(id), ...cycleWhere },
        { icao_identifier: ILike(id), ...cycleWhere },
      ],
    });
    if (airport?.latitude != null && airport?.longitude != null) {
      return {
        identifier: airport.identifier,
        latitude: airport.latitude,
        longitude: airport.longitude,
        type: 'airport',
      };
    }

    // ICAO fallback: if 4-char code starting with K, try the 3-letter FAA code
    const upper = id.toUpperCase();
    if (upper.length === 4 && upper.startsWith('K')) {
      const faaId = upper.substring(1);
      const faaAirport = await this.airportRepo.findOne({
        where: { identifier: ILike(faaId), ...cycleWhere },
      });
      if (faaAirport?.latitude != null && faaAirport?.longitude != null) {
        return {
          identifier: faaAirport.identifier,
          latitude: faaAirport.latitude,
          longitude: faaAirport.longitude,
          type: 'airport',
        };
      }
    }

    // Try navaid — case-insensitive
    const navaid = await this.navaidRepo.findOne({
      where: { identifier: ILike(id), ...cycleWhere },
    });
    if (navaid) {
      return {
        identifier: navaid.identifier,
        latitude: navaid.latitude,
        longitude: navaid.longitude,
        type: 'navaid',
      };
    }

    // Try fix — case-insensitive
    const fix = await this.fixRepo.findOne({
      where: { identifier: ILike(id), ...cycleWhere },
    });
    if (fix) {
      return {
        identifier: fix.identifier,
        latitude: fix.latitude,
        longitude: fix.longitude,
        type: 'fix',
      };
    }

    return null;
  }

  /**
   * Resolve multiple waypoint identifiers in order.
   */
  async resolveRoute(
    identifiers: string[],
  ): Promise<
    { identifier: string; latitude: number; longitude: number; type: string }[]
  > {
    const results: {
      identifier: string;
      latitude: number;
      longitude: number;
      type: string;
    }[] = [];
    for (const id of identifiers) {
      const resolved = await this.resolveWaypoint(id);
      if (resolved) {
        results.push(resolved);
      }
    }
    return results;
  }
}
