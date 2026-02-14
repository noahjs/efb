import {
  Injectable,
  Logger,
  BadRequestException,
  NotFoundException,
  ConflictException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, Repository, Not, In } from 'typeorm';
import {
  DataCycle,
  CycleDataGroup,
  CycleStatus,
} from './entities/data-cycle.entity';
import { CycleQueryHelper } from './cycle-query.helper';

/** Max archived cycles to keep per group before auto-cleanup. */
const MAX_ARCHIVED_CYCLES = 2;

/** Maps data groups to the tables whose rows carry cycle_id. */
const GROUP_TABLES: Record<CycleDataGroup, string[]> = {
  [CycleDataGroup.NASR]: [
    'a_runway_ends',
    'a_runways',
    'a_frequencies',
    'a_airports',
    'a_navaids',
    'a_fixes',
    'a_airspaces',
    'a_airway_segments',
    'a_artcc_boundaries',
    'a_preferred_route_segments',
    'a_preferred_routes',
  ],
  [CycleDataGroup.CIFP]: [
    'a_cifp_legs',
    'a_cifp_approaches',
    'a_cifp_ils',
    'a_cifp_msa',
    'a_cifp_runways',
  ],
  [CycleDataGroup.DTPP]: ['a_procedures', 'a_dtpp_cycles'],
  [CycleDataGroup.CHARTS]: [], // Filesystem only
};

@Injectable()
export class DataCycleService {
  private readonly logger = new Logger(DataCycleService.name);

  constructor(
    @InjectRepository(DataCycle)
    private cycleRepo: Repository<DataCycle>,
    private readonly cycleHelper: CycleQueryHelper,
    private readonly dataSource: DataSource,
  ) {}

  /** List all cycles, optionally filtered by group. */
  async list(group?: CycleDataGroup): Promise<DataCycle[]> {
    const where = group ? { data_group: group } : {};
    return this.cycleRepo.find({
      where,
      order: { data_group: 'ASC', effective_date: 'DESC' },
    });
  }

  /** Get a cycle by ID. */
  async findById(id: string): Promise<DataCycle> {
    const cycle = await this.cycleRepo.findOne({ where: { id } });
    if (!cycle) throw new NotFoundException(`Data cycle ${id} not found`);
    return cycle;
  }

  /** Create a new cycle in SEEDING status. */
  async create(data: {
    data_group: CycleDataGroup;
    cycle_code: string;
    effective_date: string;
    expiration_date: string;
    source_url?: string;
  }): Promise<DataCycle> {
    const existing = await this.cycleRepo.findOne({
      where: {
        data_group: data.data_group,
        cycle_code: data.cycle_code,
      },
    });
    if (existing) {
      throw new ConflictException(
        `Cycle ${data.cycle_code} already exists for ${data.data_group}`,
      );
    }

    const cycle = this.cycleRepo.create({
      ...data,
      status: CycleStatus.SEEDING,
    });
    return this.cycleRepo.save(cycle);
  }

  /** Get the active cycle for each data group. */
  async getActive(): Promise<DataCycle[]> {
    return this.cycleRepo.find({
      where: { status: CycleStatus.ACTIVE },
      order: { data_group: 'ASC' },
    });
  }

  /** Get cycles ready for activation (STAGED with effective_date <= today). */
  async getPending(): Promise<DataCycle[]> {
    return this.cycleRepo
      .createQueryBuilder('c')
      .where('c.status IN (:...statuses)', {
        statuses: [CycleStatus.STAGED, CycleStatus.PENDING_ACTIVATION],
      })
      .andWhere('c.effective_date <= CURRENT_DATE')
      .orderBy('c.data_group', 'ASC')
      .addOrderBy('c.effective_date', 'ASC')
      .getMany();
  }

  /** Transition SEEDING → STAGED. */
  async stage(id: string): Promise<DataCycle> {
    const cycle = await this.findById(id);
    if (cycle.status !== CycleStatus.SEEDING) {
      throw new BadRequestException(
        `Cannot stage cycle in ${cycle.status} status (expected SEEDING)`,
      );
    }
    cycle.status = CycleStatus.STAGED;
    return this.cycleRepo.save(cycle);
  }

  /** Activate a cycle: STAGED/PENDING_ACTIVATION → ACTIVE. Archives previous active. */
  async activate(id: string): Promise<DataCycle> {
    const cycle = await this.findById(id);
    if (
      cycle.status !== CycleStatus.STAGED &&
      cycle.status !== CycleStatus.PENDING_ACTIVATION
    ) {
      throw new BadRequestException(
        `Cannot activate cycle in ${cycle.status} status (expected STAGED or PENDING_ACTIVATION)`,
      );
    }

    // Archive the currently active cycle for this group
    const currentActive = await this.cycleRepo.findOne({
      where: {
        data_group: cycle.data_group,
        status: CycleStatus.ACTIVE,
      },
    });

    if (currentActive) {
      currentActive.status = CycleStatus.ARCHIVED;
      await this.cycleRepo.save(currentActive);
      this.logger.log(
        `Archived cycle ${currentActive.cycle_code} (${currentActive.data_group})`,
      );
    }

    // Activate the new cycle
    cycle.status = CycleStatus.ACTIVE;
    cycle.activated_at = new Date();
    const saved = await this.cycleRepo.save(cycle);

    // Invalidate cached active cycle
    this.cycleHelper.invalidateCache(cycle.data_group);

    // Auto-clean old archived cycles
    await this.cleanupArchivedCycles(cycle.data_group);

    this.logger.log(
      `Activated cycle ${cycle.cycle_code} (${cycle.data_group})`,
    );
    return saved;
  }

  /** Rollback: re-activate an ARCHIVED cycle. */
  async rollback(id: string): Promise<DataCycle> {
    const cycle = await this.findById(id);
    if (cycle.status !== CycleStatus.ARCHIVED) {
      throw new BadRequestException(
        `Cannot rollback cycle in ${cycle.status} status (expected ARCHIVED)`,
      );
    }

    // Archive the currently active cycle
    const currentActive = await this.cycleRepo.findOne({
      where: {
        data_group: cycle.data_group,
        status: CycleStatus.ACTIVE,
      },
    });

    if (currentActive) {
      currentActive.status = CycleStatus.ARCHIVED;
      await this.cycleRepo.save(currentActive);
    }

    // Re-activate the archived cycle
    cycle.status = CycleStatus.ACTIVE;
    cycle.activated_at = new Date();
    const saved = await this.cycleRepo.save(cycle);

    this.cycleHelper.invalidateCache(cycle.data_group);

    this.logger.log(
      `Rolled back to cycle ${cycle.cycle_code} (${cycle.data_group})`,
    );
    return saved;
  }

  /** Delete a cycle and all its data rows. */
  async remove(id: string): Promise<void> {
    const cycle = await this.findById(id);
    if (cycle.status === CycleStatus.ACTIVE) {
      throw new BadRequestException(
        'Cannot delete the active cycle. Activate another cycle first.',
      );
    }

    await this.deleteCycleData(cycle);
    await this.cycleRepo.remove(cycle);

    this.logger.log(
      `Deleted cycle ${cycle.cycle_code} (${cycle.data_group}) and all its data`,
    );
  }

  /** Update record_counts on a cycle. */
  async updateRecordCounts(
    id: string,
    counts: Record<string, number>,
  ): Promise<DataCycle> {
    const cycle = await this.findById(id);
    cycle.record_counts = { ...(cycle.record_counts || {}), ...counts };
    return this.cycleRepo.save(cycle);
  }

  // --- Internal helpers ---

  /** Delete all data rows belonging to a cycle. */
  private async deleteCycleData(cycle: DataCycle): Promise<void> {
    const tables = GROUP_TABLES[cycle.data_group];
    if (!tables || tables.length === 0) return;

    // Delete in order (child tables first) to respect FK constraints
    for (const table of tables) {
      const result = await this.dataSource.query(
        `DELETE FROM ${table} WHERE cycle_id = $1`,
        [cycle.id],
      );
      const count = result?.[1] ?? 0;
      if (count > 0) {
        this.logger.log(`  Deleted ${count} rows from ${table}`);
      }
    }
  }

  /** Keep only MAX_ARCHIVED_CYCLES archived cycles per group. */
  private async cleanupArchivedCycles(
    group: CycleDataGroup,
  ): Promise<void> {
    const archived = await this.cycleRepo.find({
      where: { data_group: group, status: CycleStatus.ARCHIVED },
      order: { activated_at: 'DESC' },
    });

    if (archived.length <= MAX_ARCHIVED_CYCLES) return;

    const toDelete = archived.slice(MAX_ARCHIVED_CYCLES);
    for (const cycle of toDelete) {
      this.logger.log(
        `Auto-cleaning archived cycle ${cycle.cycle_code} (${group})`,
      );
      await this.deleteCycleData(cycle);
      await this.cycleRepo.remove(cycle);
    }
  }
}
