import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { NotFoundException } from '@nestjs/common';
import { EndorsementsService } from './endorsements.service';
import { Endorsement } from './entities/endorsement.entity';

describe('EndorsementsService', () => {
  let service: EndorsementsService;
  let mockEndorsementRepo: any;

  const mockEndorsement: Partial<Endorsement> = {
    id: 1,
    date: '2025-01-15',
    endorsement_type: 'High Performance',
    far_reference: '61.31(f)',
    endorsement_text:
      'I certify that the pilot has received the required training in a high performance airplane.',
    cfi_name: 'Jane Smith',
    cfi_certificate_number: 'CFI123456',
    cfi_expiration_date: '2026-01-15',
    expiration_date: null,
    comments: 'Completed in PA-32R',
  };

  const mockEndorsement2: Partial<Endorsement> = {
    id: 2,
    date: '2025-02-20',
    endorsement_type: 'Complex',
    far_reference: '61.31(e)',
    endorsement_text:
      'I certify that the pilot has received the required training in a complex airplane.',
    cfi_name: 'Bob Jones',
    cfi_certificate_number: 'CFI789012',
    cfi_expiration_date: '2026-06-01',
  };

  beforeEach(async () => {
    const mockQb = {
      where: jest.fn().mockReturnThis(),
      orderBy: jest.fn().mockReturnThis(),
      addOrderBy: jest.fn().mockReturnThis(),
      skip: jest.fn().mockReturnThis(),
      take: jest.fn().mockReturnThis(),
      getManyAndCount: jest
        .fn()
        .mockResolvedValue([[{ ...mockEndorsement }], 1]),
    };

    mockEndorsementRepo = {
      findOne: jest.fn().mockResolvedValue({ ...mockEndorsement }),
      create: jest.fn().mockImplementation((dto) => ({ ...dto })),
      save: jest
        .fn()
        .mockImplementation((endorsement) =>
          Promise.resolve({ ...endorsement, id: endorsement.id ?? 3 }),
        ),
      remove: jest
        .fn()
        .mockImplementation((endorsement) => Promise.resolve(endorsement)),
      createQueryBuilder: jest.fn().mockReturnValue(mockQb),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        EndorsementsService,
        {
          provide: getRepositoryToken(Endorsement),
          useValue: mockEndorsementRepo,
        },
      ],
    }).compile();

    service = module.get<EndorsementsService>(EndorsementsService);
  });

  // --- findAll ---

  describe('findAll', () => {
    it('should return paginated results', async () => {
      const result = await service.findAll();
      expect(result.items).toHaveLength(1);
      expect(result.total).toBe(1);
      expect(result.limit).toBe(50);
      expect(result.offset).toBe(0);
    });

    it('should apply query filter when provided', async () => {
      const mockQb = mockEndorsementRepo.createQueryBuilder();
      await service.findAll('High Performance');
      expect(mockQb.where).toHaveBeenCalled();
    });

    it('should respect custom limit and offset', async () => {
      const mockQb = mockEndorsementRepo.createQueryBuilder();
      await service.findAll(undefined, 5, 10);
      expect(mockQb.skip).toHaveBeenCalledWith(10);
      expect(mockQb.take).toHaveBeenCalledWith(5);
    });

    it('should order by date DESC then id DESC', async () => {
      const mockQb = mockEndorsementRepo.createQueryBuilder();
      await service.findAll();
      expect(mockQb.orderBy).toHaveBeenCalledWith('e.date', 'DESC');
      expect(mockQb.addOrderBy).toHaveBeenCalledWith('e.id', 'DESC');
    });
  });

  // --- findOne ---

  describe('findOne', () => {
    it('should return endorsement when found', async () => {
      const result = await service.findOne(1);
      expect(result.id).toBe(1);
      expect(result.endorsement_type).toBe('High Performance');
      expect(result.far_reference).toBe('61.31(f)');
    });

    it('should throw NotFoundException when not found', async () => {
      mockEndorsementRepo.findOne.mockResolvedValue(null);
      await expect(service.findOne(999)).rejects.toThrow(NotFoundException);
    });
  });

  // --- create ---

  describe('create', () => {
    it('should create an endorsement', async () => {
      const dto = {
        date: '2025-03-01',
        endorsement_type: 'Tailwheel',
        far_reference: '61.31(i)',
        cfi_name: 'Jane Smith',
        cfi_certificate_number: 'CFI123456',
      };

      const result = await service.create(dto as any);

      expect(mockEndorsementRepo.create).toHaveBeenCalledWith(dto);
      expect(mockEndorsementRepo.save).toHaveBeenCalledTimes(1);
      expect(result.id).toBeDefined();
    });
  });

  // --- update ---

  describe('update', () => {
    it('should update an existing endorsement', async () => {
      const dto = { comments: 'Updated comments' };
      await service.update(1, dto as any);

      expect(mockEndorsementRepo.findOne).toHaveBeenCalledWith({
        where: { id: 1 },
      });
      expect(mockEndorsementRepo.save).toHaveBeenCalledTimes(1);
    });

    it('should merge updated fields into existing endorsement', async () => {
      const dto = { comments: 'Updated', cfi_name: 'New CFI' };
      await service.update(1, dto as any);

      const saved = mockEndorsementRepo.save.mock.calls[0][0];
      expect(saved.comments).toBe('Updated');
      expect(saved.cfi_name).toBe('New CFI');
      // Original fields preserved
      expect(saved.endorsement_type).toBe('High Performance');
    });

    it('should throw NotFoundException when updating non-existent endorsement', async () => {
      mockEndorsementRepo.findOne.mockResolvedValue(null);
      await expect(
        service.update(999, { comments: 'Test' } as any),
      ).rejects.toThrow(NotFoundException);
    });
  });

  // --- remove ---

  describe('remove', () => {
    it('should remove an existing endorsement', async () => {
      await service.remove(1);
      expect(mockEndorsementRepo.remove).toHaveBeenCalledTimes(1);
    });

    it('should throw NotFoundException when removing non-existent endorsement', async () => {
      mockEndorsementRepo.findOne.mockResolvedValue(null);
      await expect(service.remove(999)).rejects.toThrow(NotFoundException);
    });
  });
});
