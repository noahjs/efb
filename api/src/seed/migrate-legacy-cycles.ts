/**
 * Legacy Data Migration — Assign cycle_id to existing rows.
 *
 * Existing data seeded before the cycle-aware system was introduced has
 * NULL cycle_id values.  Once a CycleQueryHelper filter is active for a
 * data group, those rows become invisible.
 *
 * This script:
 *  1. Checks each data group (NASR, CIFP, DTPP) for NULL cycle_id rows.
 *  2. Creates (or reuses) an ACTIVE DataCycle per group.
 *  3. Updates all NULL rows to the cycle's ID.
 *  4. Populates record_counts on the cycle.
 *
 * Idempotent — safe to run multiple times.  Skips groups that have no
 * NULL-cycle rows.
 *
 * Usage:
 *   npx ts-node -r tsconfig-paths/register src/seed/migrate-legacy-cycles.ts
 */

import { DataSource } from 'typeorm';
import {
  DataCycle,
  CycleDataGroup,
  CycleStatus,
} from '../data-cycle/entities/data-cycle.entity';
import { dbConfig } from '../db.config';

/** Tables per data group — child tables listed before parents (for delete order).
 *  For UPDATE order doesn't matter, but we keep the same canonical list. */
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
  [CycleDataGroup.CHARTS]: [],
};

const LEGACY_CYCLE_CODE = 'legacy';

async function main() {
  console.log('=== Legacy Cycle Migration ===\n');

  const ds = new DataSource({
    ...dbConfig,
    entities: [DataCycle],
  });
  await ds.initialize();

  const repo = ds.getRepository(DataCycle);

  for (const group of [
    CycleDataGroup.NASR,
    CycleDataGroup.CIFP,
    CycleDataGroup.DTPP,
  ]) {
    const tables = GROUP_TABLES[group];
    if (!tables.length) continue;

    // Count rows with NULL cycle_id across all tables in this group
    let totalNull = 0;
    const tableCounts: Record<string, number> = {};

    for (const table of tables) {
      const hasColumn = await ds.query(
        `SELECT 1 FROM information_schema.columns
         WHERE table_name = $1 AND column_name = 'cycle_id' LIMIT 1`,
        [table],
      );
      if (!hasColumn.length) {
        console.log(`  [${group}] Skipping ${table} — no cycle_id column`);
        continue;
      }

      const [{ count }] = await ds.query(
        `SELECT COUNT(*)::int AS count FROM ${table} WHERE cycle_id IS NULL`,
      );
      tableCounts[table] = count;
      totalNull += count;
    }

    if (totalNull === 0) {
      console.log(`[${group}] No legacy rows (all rows already have cycle_id). Skipping.\n`);
      continue;
    }

    console.log(`[${group}] Found ${totalNull} rows with NULL cycle_id`);

    // Check if there's already an active cycle for this group
    let cycle = await repo.findOne({
      where: { data_group: group, status: CycleStatus.ACTIVE },
    });

    if (cycle) {
      console.log(
        `  Using existing active cycle: ${cycle.id} (${cycle.cycle_code})`,
      );
    } else {
      // Check if a legacy cycle already exists (maybe from a previous partial run)
      cycle = await repo.findOne({
        where: { data_group: group, cycle_code: LEGACY_CYCLE_CODE },
      });

      if (cycle) {
        console.log(
          `  Found existing legacy cycle: ${cycle.id} (status: ${cycle.status})`,
        );
        // Ensure it's active
        if (cycle.status !== CycleStatus.ACTIVE) {
          cycle.status = CycleStatus.ACTIVE;
          cycle.activated_at = new Date();
          cycle = await repo.save(cycle);
          console.log(`  Activated legacy cycle`);
        }
      } else {
        // Create a new active cycle for legacy data
        const today = new Date().toISOString().slice(0, 10);
        const expiry = new Date(Date.now() + 28 * 86400000)
          .toISOString()
          .slice(0, 10);

        cycle = repo.create({
          data_group: group,
          cycle_code: LEGACY_CYCLE_CODE,
          effective_date: today,
          expiration_date: expiry,
          status: CycleStatus.ACTIVE,
          activated_at: new Date(),
          record_counts: {},
        });
        cycle = await repo.save(cycle);
        console.log(`  Created legacy cycle: ${cycle.id}`);
      }
    }

    // Update all NULL cycle_id rows to point to this cycle
    const recordCounts: Record<string, number> = {};
    for (const table of tables) {
      const nullCount = tableCounts[table] ?? 0;
      if (nullCount === 0) continue;

      await ds.query(
        `UPDATE ${table} SET cycle_id = $1 WHERE cycle_id IS NULL`,
        [cycle.id],
      );
      console.log(`  Updated ${nullCount} rows in ${table}`);
      recordCounts[table] = nullCount;
    }

    // Update record_counts on the cycle
    cycle.record_counts = {
      ...(cycle.record_counts || {}),
      ...recordCounts,
    };
    await repo.save(cycle);
    console.log(`  Record counts saved\n`);
  }

  await ds.destroy();
  console.log('=== Migration Complete ===');
}

main().catch((err) => {
  console.error('Migration failed:', err);
  process.exit(1);
});
