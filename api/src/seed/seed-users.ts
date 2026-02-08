/**
 * Seed Demo User
 *
 * Creates a demo user for development. The user auto-logins in the app.
 *
 * Usage: npx ts-node -r tsconfig-paths/register src/seed/seed-users.ts
 */

import { DataSource } from 'typeorm';
import { User } from '../users/entities/user.entity';
import { StarredAirport } from '../users/entities/starred-airport.entity';
import { dbConfig } from '../db.config';

const DEMO_USER_ID = '00000000-0000-0000-0000-000000000001';

async function seed() {
  const ds = new DataSource({
    ...dbConfig,
    entities: [User, StarredAirport],
  });

  await ds.initialize();
  console.log('Database connected.');

  const userRepo = ds.getRepository(User);

  const existing = await userRepo.findOne({ where: { id: DEMO_USER_ID } });
  if (existing) {
    console.log('Demo user already exists, skipping.');
  } else {
    await userRepo.save({
      id: DEMO_USER_ID,
      name: 'Demo Pilot',
      email: 'demo@efb.app',
    });
    console.log('Demo user created.');
  }

  await ds.destroy();
  console.log('Done.');
}

seed().catch((err) => {
  console.error('Seed failed:', err);
  process.exit(1);
});
