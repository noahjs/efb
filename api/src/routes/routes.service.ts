import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { PreferredRoute } from './entities/preferred-route.entity';
import { CycleQueryHelper } from '../data-cycle/cycle-query.helper';
import { CycleDataGroup } from '../data-cycle/entities/data-cycle.entity';

@Injectable()
export class RoutesService {
  constructor(
    @InjectRepository(PreferredRoute)
    private routeRepo: Repository<PreferredRoute>,
    private readonly cycleHelper: CycleQueryHelper,
  ) {}

  async search(origin: string, destination: string, type?: string) {
    const qb = this.routeRepo
      .createQueryBuilder('route')
      .leftJoinAndSelect('route.segments', 'seg')
      .where('route.origin_id = :origin', { origin: origin.toUpperCase() })
      .andWhere('route.destination_id = :destination', {
        destination: destination.toUpperCase(),
      });

    await this.cycleHelper.applyCycleFilter(qb, 'route', CycleDataGroup.NASR);

    if (type) {
      qb.andWhere('route.route_type = :type', { type: type.toUpperCase() });
    }

    qb.orderBy('route.route_type', 'ASC')
      .addOrderBy('route.route_number', 'ASC')
      .addOrderBy('seg.sequence', 'ASC');

    return qb.getMany();
  }

  async findByOrigin(origin: string, type?: string) {
    const qb = this.routeRepo
      .createQueryBuilder('route')
      .leftJoinAndSelect('route.segments', 'seg')
      .where('route.origin_id = :origin', { origin: origin.toUpperCase() });

    await this.cycleHelper.applyCycleFilter(qb, 'route', CycleDataGroup.NASR);

    if (type) {
      qb.andWhere('route.route_type = :type', { type: type.toUpperCase() });
    }

    qb.orderBy('route.destination_id', 'ASC')
      .addOrderBy('route.route_type', 'ASC')
      .addOrderBy('route.route_number', 'ASC')
      .addOrderBy('seg.sequence', 'ASC');

    return qb.getMany();
  }

  async getRouteTypes(): Promise<string[]> {
    const qb = this.routeRepo
      .createQueryBuilder('route')
      .select('DISTINCT route.route_type', 'route_type');

    await this.cycleHelper.applyCycleFilter(qb, 'route', CycleDataGroup.NASR);

    const result: { route_type: string }[] = await qb
      .orderBy('route.route_type', 'ASC')
      .getRawMany();

    return result.map((r) => r.route_type);
  }
}
