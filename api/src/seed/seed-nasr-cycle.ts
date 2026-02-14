/**
 * NASR Cycle Orchestrator
 *
 * Creates a single DataCycle for NASR data and runs all four NASR seed scripts
 * (airports, navaids, airspaces, routes) under that cycle.
 *
 * Usage: npx ts-node -r tsconfig-paths/register src/seed/seed-nasr-cycle.ts
 *
 * Options:
 *   --fast          Skip contacts, tower hours, AWOS, D-ATIS in airport seed
 *   --cycle-code=X  Override cycle code (default: today's date)
 */

import { DataSource } from 'typeorm';
import * as path from 'path';
import { execSync } from 'child_process';
import {
  DataCycle,
  CycleDataGroup,
  CycleStatus,
} from '../data-cycle/entities/data-cycle.entity';
import { dbConfig } from '../db.config';

const APP_ROOT = path.join(__dirname, '..', '..');

function getArg(name: string): string | undefined {
  for (const arg of process.argv.slice(2)) {
    const match = arg.match(new RegExp(`^--${name}=(.+)$`));
    if (match) return match[1];
  }
  return undefined;
}

function hasFlag(name: string): boolean {
  return process.argv.slice(2).includes(`--${name}`);
}

async function main() {
  console.log('=== NASR Cycle Orchestrator ===\n');

  const cycleCode =
    getArg('cycle-code') || new Date().toISOString().slice(0, 10);
  const fast = hasFlag('fast');

  // Create DataCycle
  const ds = new DataSource({
    ...dbConfig,
    entities: [DataCycle],
  });
  await ds.initialize();

  const repo = ds.getRepository(DataCycle);

  // Check for existing cycle with same code
  const existing = await repo.findOne({
    where: {
      data_group: CycleDataGroup.NASR,
      cycle_code: cycleCode,
    },
  });

  let cycle: DataCycle;
  if (existing) {
    console.log(
      `  Found existing NASR cycle: ${existing.id} (${existing.cycle_code}, status: ${existing.status})`,
    );
    if (
      existing.status !== CycleStatus.SEEDING &&
      existing.status !== CycleStatus.STAGED
    ) {
      console.error(
        `  Cannot re-seed cycle with status ${existing.status}. Use a different cycle code.`,
      );
      await ds.destroy();
      process.exit(1);
    }
    cycle = existing;
  } else {
    cycle = repo.create({
      data_group: CycleDataGroup.NASR,
      cycle_code: cycleCode,
      effective_date: new Date().toISOString().slice(0, 10),
      expiration_date: new Date(Date.now() + 28 * 86400000)
        .toISOString()
        .slice(0, 10),
      status: CycleStatus.SEEDING,
      record_counts: {},
    });
    cycle = await repo.save(cycle);
    console.log(`  Created NASR cycle: ${cycle.id} (${cycle.cycle_code})`);
  }

  await ds.destroy();

  const cycleId = cycle.id;
  const cycleArg = `--cycle-id=${cycleId}`;
  const tsNode = 'npx ts-node -r tsconfig-paths/register';

  // Run each seed script with the shared cycle ID
  const scripts = [
    {
      name: 'Airports',
      cmd: `${tsNode} src/seed/seed.ts ${cycleArg}${fast ? ' --fast' : ''}`,
    },
    {
      name: 'Navaids & Fixes',
      cmd: `${tsNode} src/seed/seed-navaids.ts ${cycleArg}`,
    },
    {
      name: 'Airspaces & Airways',
      cmd: `${tsNode} src/seed/seed-airspaces.ts ${cycleArg}`,
    },
    {
      name: 'Preferred Routes',
      cmd: `${tsNode} src/seed/seed-routes.ts ${cycleArg}`,
    },
  ];

  for (const script of scripts) {
    console.log(`\n--- ${script.name} ---\n`);
    try {
      execSync(script.cmd, {
        cwd: APP_ROOT,
        stdio: 'inherit',
        env: { ...process.env },
      });
    } catch (err: any) {
      console.error(`\n  FAILED: ${script.name} (exit code ${err.status})`);
      console.error('  Aborting orchestrator. Cycle remains in SEEDING state.');
      process.exit(1);
    }
  }

  // Mark cycle as STAGED
  const ds2 = new DataSource({ ...dbConfig, entities: [DataCycle] });
  await ds2.initialize();
  const repo2 = ds2.getRepository(DataCycle);
  const finalCycle = await repo2.findOneBy({ id: cycleId });
  if (finalCycle && finalCycle.status === CycleStatus.SEEDING) {
    finalCycle.status = CycleStatus.STAGED;
    await repo2.save(finalCycle);
    console.log(`\n  Cycle ${cycleId} marked as STAGED`);
  }
  await ds2.destroy();

  console.log('\n=== NASR Cycle Complete ===');
  console.log(`  Cycle ID: ${cycleId}`);
  console.log(`  Cycle Code: ${cycleCode}`);
  console.log('  Status: STAGED');
  console.log(
    '\n  Activate with: POST /api/admin/data-cycles/:id/activate\n',
  );
}

main().catch((err) => {
  console.error('Orchestrator failed:', err);
  process.exit(1);
});
