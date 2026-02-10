import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, IsNull } from 'typeorm';
import { Endorsement } from './entities/endorsement.entity';
import { CreateEndorsementDto } from './dto/create-endorsement.dto';
import { UpdateEndorsementDto } from './dto/update-endorsement.dto';

@Injectable()
export class EndorsementsService {
  constructor(
    @InjectRepository(Endorsement)
    private readonly endorsementRepo: Repository<Endorsement>,
  ) {}

  async findAll(
    userId: string,
    query?: string,
    limit = 50,
    offset = 0,
  ): Promise<{
    items: Endorsement[];
    total: number;
    limit: number;
    offset: number;
  }> {
    const qb = this.endorsementRepo.createQueryBuilder('e');

    if (query) {
      const q = `%${query}%`;
      qb.where(
        '(e.endorsement_type LIKE :q OR e.cfi_name LIKE :q OR e.far_reference LIKE :q OR e.comments LIKE :q)',
        { q },
      );
    }

    qb.andWhere('(e.user_id = :userId OR e.user_id IS NULL)', { userId });

    qb.orderBy('e.date', 'DESC')
      .addOrderBy('e.id', 'DESC')
      .skip(offset)
      .take(limit);

    const [items, total] = await qb.getManyAndCount();
    return { items, total, limit, offset };
  }

  async findOne(userId: string, id: number): Promise<Endorsement> {
    const endorsement = await this.endorsementRepo.findOne({
      where: [
        { id, user_id: userId },
        { id, user_id: IsNull() },
      ],
    });
    if (!endorsement) {
      throw new NotFoundException(`Endorsement #${id} not found`);
    }
    return endorsement;
  }

  async create(
    userId: string,
    dto: CreateEndorsementDto,
  ): Promise<Endorsement> {
    const endorsement = this.endorsementRepo.create({
      ...dto,
      user_id: userId,
    });
    return this.endorsementRepo.save(endorsement);
  }

  async update(
    userId: string,
    id: number,
    dto: UpdateEndorsementDto,
  ): Promise<Endorsement> {
    const endorsement = await this.findOne(userId, id);
    Object.assign(endorsement, dto);
    return this.endorsementRepo.save(endorsement);
  }

  async remove(userId: string, id: number): Promise<void> {
    const endorsement = await this.findOne(userId, id);
    await this.endorsementRepo.remove(endorsement);
  }
}
