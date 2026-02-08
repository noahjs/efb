import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, ILike } from 'typeorm';
import { Navaid } from './entities/navaid.entity';
import { Fix } from './entities/fix.entity';
import { Airport } from '../airports/entities/airport.entity';

@Injectable()
export class NavaidsService {
  constructor(
    @InjectRepository(Navaid)
    private navaidRepo: Repository<Navaid>,
    @InjectRepository(Fix)
    private fixRepo: Repository<Fix>,
    @InjectRepository(Airport)
    private airportRepo: Repository<Airport>,
  ) {}

  async searchNavaids(query?: string, type?: string, limit = 50) {
    const qb = this.navaidRepo.createQueryBuilder('navaid');

    if (query) {
      const q = `%${query}%`;
      qb.where('(navaid.identifier LIKE :q OR navaid.name LIKE :q)', { q });
    }

    if (type) {
      qb.andWhere('navaid.type = :type', { type });
    }

    qb.orderBy('navaid.identifier', 'ASC').take(limit);

    return qb.getMany();
  }

  async findNavaidById(identifier: string) {
    return this.navaidRepo.findOne({ where: { identifier } });
  }

  async getNavaidsInBounds(
    minLat: number,
    maxLat: number,
    minLng: number,
    maxLng: number,
    limit = 200,
  ) {
    return this.navaidRepo
      .createQueryBuilder('navaid')
      .where('navaid.latitude BETWEEN :minLat AND :maxLat', { minLat, maxLat })
      .andWhere('navaid.longitude BETWEEN :minLng AND :maxLng', {
        minLng,
        maxLng,
      })
      .take(limit)
      .getMany();
  }

  async searchFixes(query?: string, limit = 50) {
    const qb = this.fixRepo.createQueryBuilder('fix');

    if (query) {
      const q = `%${query}%`;
      qb.where('fix.identifier LIKE :q', { q });
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
    return this.fixRepo
      .createQueryBuilder('fix')
      .where('fix.latitude BETWEEN :minLat AND :maxLat', { minLat, maxLat })
      .andWhere('fix.longitude BETWEEN :minLng AND :maxLng', { minLng, maxLng })
      .take(limit)
      .getMany();
  }

  /**
   * Resolve a waypoint identifier to coordinates.
   * Searches airports (by identifier and icao_identifier), then navaids, then fixes.
   */
  async resolveWaypoint(
    identifier: string,
  ): Promise<{ identifier: string; latitude: number; longitude: number; type: string } | null> {
    const id = identifier.trim();

    // Try airport (FAA id or ICAO id) — case-insensitive
    const airport = await this.airportRepo.findOne({
      where: [{ identifier: ILike(id) }, { icao_identifier: ILike(id) }],
    });
    if (airport?.latitude != null && airport?.longitude != null) {
      return {
        identifier: airport.identifier,
        latitude: airport.latitude,
        longitude: airport.longitude,
        type: 'airport',
      };
    }

    // Try navaid — case-insensitive
    const navaid = await this.navaidRepo.findOne({
      where: { identifier: ILike(id) },
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
      where: { identifier: ILike(id) },
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
