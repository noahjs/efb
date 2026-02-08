import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, Like, ILike } from 'typeorm';
import { Airport, Runway, Frequency } from './entities';

@Injectable()
export class AirportsService {
  constructor(
    @InjectRepository(Airport)
    private airportRepo: Repository<Airport>,
    @InjectRepository(Runway)
    private runwayRepo: Repository<Runway>,
    @InjectRepository(Frequency)
    private frequencyRepo: Repository<Frequency>,
  ) {}

  async search(query?: string, state?: string, limit = 50, offset = 0) {
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

    qb.orderBy('airport.identifier', 'ASC')
      .skip(offset)
      .take(limit);

    const [items, total] = await qb.getManyAndCount();
    return { items, total, limit, offset };
  }

  async findById(identifier: string) {
    return this.airportRepo.findOne({
      where: [
        { identifier },
        { icao_identifier: identifier },
      ],
      relations: ['runways', 'runways.ends', 'frequencies'],
    });
  }

  async findNearby(lat: number, lng: number, radiusNm = 30, limit = 20) {
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
        distance_nm: this.haversineNm(lat, lng, a.latitude ?? 0, a.longitude ?? 0),
      }))
      .sort((a, b) => a.distance_nm - b.distance_nm);
  }

  async getRunways(identifier: string) {
    return this.runwayRepo.find({
      where: { airport_identifier: identifier },
      relations: ['ends'],
    });
  }

  async getFrequencies(identifier: string) {
    return this.frequencyRepo.find({
      where: { airport_identifier: identifier },
      order: { type: 'ASC' },
    });
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
    limit = 200,
  ) {
    return this.airportRepo
      .createQueryBuilder('airport')
      .where('airport.latitude BETWEEN :minLat AND :maxLat', { minLat, maxLat })
      .andWhere('airport.longitude BETWEEN :minLng AND :maxLng', { minLng, maxLng })
      .take(limit)
      .getMany();
  }

  private haversineNm(
    lat1: number,
    lon1: number,
    lat2: number,
    lon2: number,
  ): number {
    const R = 3440.065; // Earth radius in nautical miles
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
