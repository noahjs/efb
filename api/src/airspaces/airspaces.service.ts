import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Airspace } from './entities/airspace.entity';
import { AirwaySegment } from './entities/airway-segment.entity';
import { ArtccBoundary } from './entities/artcc-boundary.entity';
import { CycleQueryHelper } from '../data-cycle/cycle-query.helper';
import { CycleDataGroup } from '../data-cycle/entities/data-cycle.entity';

@Injectable()
export class AirspacesService {
  constructor(
    @InjectRepository(Airspace)
    private airspaceRepo: Repository<Airspace>,
    @InjectRepository(AirwaySegment)
    private airwayRepo: Repository<AirwaySegment>,
    @InjectRepository(ArtccBoundary)
    private artccRepo: Repository<ArtccBoundary>,
    private readonly cycleHelper: CycleQueryHelper,
  ) {}

  async getAirspacesInBounds(
    minLat: number,
    maxLat: number,
    minLng: number,
    maxLng: number,
    types?: string[],
    classes?: string[],
    limit = 500,
  ) {
    const qb = this.airspaceRepo
      .createQueryBuilder('a')
      .where('a.max_lat >= :minLat AND a.min_lat <= :maxLat', {
        minLat,
        maxLat,
      })
      .andWhere('a.max_lng >= :minLng AND a.min_lng <= :maxLng', {
        minLng,
        maxLng,
      });

    await this.cycleHelper.applyCycleFilter(qb, 'a', CycleDataGroup.NASR);

    if (types && types.length > 0) {
      qb.andWhere('a.type IN (:...types)', { types });
    }

    if (classes && classes.length > 0) {
      qb.andWhere('a.airspace_class IN (:...classes)', { classes });
    }

    qb.take(limit);

    const airspaces = await qb.getMany();
    return this.toFeatureCollection(
      airspaces.map((a) => ({
        type: 'Feature' as const,
        geometry: JSON.parse(a.geometry_json),
        properties: {
          id: a.id,
          identifier: a.identifier,
          name: a.name,
          airspace_class: a.airspace_class,
          type: a.type,
          lower_alt: a.lower_alt,
          upper_alt: a.upper_alt,
          lower_code: a.lower_code,
          upper_code: a.upper_code,
          military: a.military,
        },
      })),
    );
  }

  async getAirwaysInBounds(
    minLat: number,
    maxLat: number,
    minLng: number,
    maxLng: number,
    types?: string[],
    limit = 1000,
  ) {
    const qb = this.airwayRepo
      .createQueryBuilder('s')
      .where(
        '((s.from_lat BETWEEN :minLat AND :maxLat AND s.from_lng BETWEEN :minLng AND :maxLng) OR ' +
          '(s.to_lat BETWEEN :minLat AND :maxLat AND s.to_lng BETWEEN :minLng AND :maxLng))',
        { minLat, maxLat, minLng, maxLng },
      );

    await this.cycleHelper.applyCycleFilter(qb, 's', CycleDataGroup.NASR);

    if (types && types.length > 0) {
      qb.andWhere('s.airway_type IN (:...types)', { types });
    }

    qb.orderBy('s.airway_id', 'ASC')
      .addOrderBy('s.sequence', 'ASC')
      .take(limit);

    const segments = await qb.getMany();

    const features = segments.map((s) => ({
      type: 'Feature' as const,
      geometry: {
        type: 'LineString' as const,
        coordinates: [
          [s.from_lng, s.from_lat],
          [s.to_lng, s.to_lat],
        ],
      },
      properties: {
        airway_id: s.airway_id,
        sequence: s.sequence,
        from_fix: s.from_fix,
        to_fix: s.to_fix,
        min_enroute_alt: s.min_enroute_alt,
        airway_type: s.airway_type,
        distance_nm: s.distance_nm,
      },
    }));

    return this.toFeatureCollection(features);
  }

  async getArtccInBounds(
    minLat: number,
    maxLat: number,
    minLng: number,
    maxLng: number,
    limit = 100,
  ) {
    const qb = this.artccRepo
      .createQueryBuilder('b')
      .where('b.max_lat >= :minLat AND b.min_lat <= :maxLat', {
        minLat,
        maxLat,
      })
      .andWhere('b.max_lng >= :minLng AND b.min_lng <= :maxLng', {
        minLng,
        maxLng,
      });

    await this.cycleHelper.applyCycleFilter(qb, 'b', CycleDataGroup.NASR);

    const boundaries = await qb.take(limit).getMany();

    return this.toFeatureCollection(
      boundaries.map((b) => ({
        type: 'Feature' as const,
        geometry: JSON.parse(b.geometry_json),
        properties: {
          artcc_id: b.artcc_id,
          name: b.name,
          altitude: b.altitude,
        },
      })),
    );
  }

  private toFeatureCollection(features: any[]) {
    return {
      type: 'FeatureCollection',
      features,
    };
  }
}
