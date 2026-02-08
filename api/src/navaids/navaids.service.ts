import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Navaid } from './entities/navaid.entity';
import { Fix } from './entities/fix.entity';

@Injectable()
export class NavaidsService {
  constructor(
    @InjectRepository(Navaid)
    private navaidRepo: Repository<Navaid>,
    @InjectRepository(Fix)
    private fixRepo: Repository<Fix>,
  ) {}

  async searchNavaids(query?: string, type?: string, limit = 50) {
    const qb = this.navaidRepo.createQueryBuilder('navaid');

    if (query) {
      const q = `%${query}%`;
      qb.where(
        '(navaid.identifier LIKE :q OR navaid.name LIKE :q)',
        { q },
      );
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
      .andWhere('navaid.longitude BETWEEN :minLng AND :maxLng', { minLng, maxLng })
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
}
