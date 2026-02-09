import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Certificate } from './entities/certificate.entity';
import { CreateCertificateDto } from './dto/create-certificate.dto';
import { UpdateCertificateDto } from './dto/update-certificate.dto';

@Injectable()
export class CertificatesService {
  constructor(
    @InjectRepository(Certificate)
    private readonly certRepo: Repository<Certificate>,
  ) {}

  async findAll(
    query?: string,
    limit = 50,
    offset = 0,
  ): Promise<{
    items: Certificate[];
    total: number;
    limit: number;
    offset: number;
  }> {
    const qb = this.certRepo.createQueryBuilder('c');

    if (query) {
      const q = `%${query}%`;
      qb.where(
        '(c.certificate_type LIKE :q OR c.certificate_class LIKE :q OR c.certificate_number LIKE :q OR c.ratings LIKE :q OR c.comments LIKE :q)',
        { q },
      );
    }

    qb.orderBy('c.id', 'DESC').skip(offset).take(limit);

    const [items, total] = await qb.getManyAndCount();
    return { items, total, limit, offset };
  }

  async findOne(id: number): Promise<Certificate> {
    const cert = await this.certRepo.findOne({ where: { id } });
    if (!cert) {
      throw new NotFoundException(`Certificate #${id} not found`);
    }
    return cert;
  }

  async create(dto: CreateCertificateDto): Promise<Certificate> {
    const cert = this.certRepo.create(dto);
    return this.certRepo.save(cert);
  }

  async update(id: number, dto: UpdateCertificateDto): Promise<Certificate> {
    const cert = await this.findOne(id);
    Object.assign(cert, dto);
    return this.certRepo.save(cert);
  }

  async remove(id: number): Promise<void> {
    const cert = await this.findOne(id);
    await this.certRepo.remove(cert);
  }
}
