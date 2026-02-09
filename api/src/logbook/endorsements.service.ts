import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
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

    qb.orderBy('e.date', 'DESC')
      .addOrderBy('e.id', 'DESC')
      .skip(offset)
      .take(limit);

    const [items, total] = await qb.getManyAndCount();
    return { items, total, limit, offset };
  }

  async findOne(id: number): Promise<Endorsement> {
    const endorsement = await this.endorsementRepo.findOne({ where: { id } });
    if (!endorsement) {
      throw new NotFoundException(`Endorsement #${id} not found`);
    }
    return endorsement;
  }

  async create(dto: CreateEndorsementDto): Promise<Endorsement> {
    const endorsement = this.endorsementRepo.create(dto);
    return this.endorsementRepo.save(endorsement);
  }

  async update(id: number, dto: UpdateEndorsementDto): Promise<Endorsement> {
    const endorsement = await this.findOne(id);
    Object.assign(endorsement, dto);
    return this.endorsementRepo.save(endorsement);
  }

  async remove(id: number): Promise<void> {
    const endorsement = await this.findOne(id);
    await this.endorsementRepo.remove(endorsement);
  }
}
