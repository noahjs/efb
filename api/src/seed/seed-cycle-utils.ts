/**
 * Shared utilities for cycle-aware seed scripts.
 *
 * Each seed script can accept `--cycle-id=<uuid>` to attach data to an
 * existing DataCycle, or omit it to create a new one.
 */

import { DataSource, Repository } from 'typeorm';
import {
  DataCycle,
  CycleDataGroup,
  CycleStatus,
} from '../data-cycle/entities/data-cycle.entity';

export interface CycleSetupResult {
  cycle: DataCycle;
  isNew: boolean;
}

/**
 * Parse `--cycle-id=<uuid>` from CLI args.
 */
export function parseCycleIdArg(): string | undefined {
  for (const arg of process.argv.slice(2)) {
    const match = arg.match(/^--cycle-id=(.+)$/);
    if (match) return match[1];
  }
  return undefined;
}

/**
 * Resolve or create a DataCycle for seeding.
 *
 * If `cycleId` is provided, looks up the existing cycle.
 * Otherwise creates a new one with status=SEEDING.
 */
export async function resolveOrCreateCycle(
  ds: DataSource,
  cycleId: string | undefined,
  group: CycleDataGroup,
  defaults: {
    cycle_code: string;
    effective_date: string;
    expiration_date: string;
    source_url?: string;
  },
): Promise<CycleSetupResult> {
  const repo = ds.getRepository(DataCycle);

  if (cycleId) {
    const existing = await repo.findOne({ where: { id: cycleId } });
    if (!existing) {
      throw new Error(`DataCycle not found: ${cycleId}`);
    }
    if (
      existing.status !== CycleStatus.SEEDING &&
      existing.status !== CycleStatus.STAGED
    ) {
      throw new Error(
        `DataCycle ${cycleId} has status ${existing.status} — expected SEEDING or STAGED`,
      );
    }
    console.log(
      `  Using existing cycle: ${existing.id} (${existing.data_group} ${existing.cycle_code})`,
    );
    return { cycle: existing, isNew: false };
  }

  // Create a new cycle
  const cycle = repo.create({
    data_group: group,
    cycle_code: defaults.cycle_code,
    effective_date: defaults.effective_date,
    expiration_date: defaults.expiration_date,
    source_url: defaults.source_url,
    status: CycleStatus.SEEDING,
    record_counts: {},
  });

  const saved = await repo.save(cycle);
  console.log(
    `  Created new cycle: ${saved.id} (${saved.data_group} ${saved.cycle_code})`,
  );
  return { cycle: saved, isNew: true };
}

/**
 * Delete all data for a specific cycle from the given tables (child-first order).
 */
export async function deleteCycleData(
  ds: DataSource,
  cycleId: string,
  tables: string[],
): Promise<void> {
  for (const table of tables) {
    const result = await ds.query(`DELETE FROM ${table} WHERE cycle_id = $1`, [
      cycleId,
    ]);
    const count = result[1] ?? 0;
    if (count > 0) {
      console.log(`  Deleted ${count} rows from ${table}`);
    }
  }
}

/**
 * Update record_counts on a DataCycle.
 * Merges new counts into existing ones.
 */
export async function updateRecordCounts(
  ds: DataSource,
  cycleId: string,
  counts: Record<string, number>,
): Promise<void> {
  const repo = ds.getRepository(DataCycle);
  const cycle = await repo.findOneBy({ id: cycleId });
  if (!cycle) return;

  cycle.record_counts = { ...(cycle.record_counts || {}), ...counts };
  await repo.save(cycle);
}

/**
 * Transition a cycle from SEEDING to STAGED.
 */
export async function markCycleStaged(
  ds: DataSource,
  cycleId: string,
): Promise<void> {
  const repo = ds.getRepository(DataCycle);
  const cycle = await repo.findOneBy({ id: cycleId });
  if (!cycle) return;

  if (cycle.status === CycleStatus.SEEDING) {
    cycle.status = CycleStatus.STAGED;
    await repo.save(cycle);
    console.log(`  Cycle ${cycleId} marked as STAGED`);
  }
}
