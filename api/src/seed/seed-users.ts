/**
 * Seed Demo User
 *
 * Creates a demo user for development. The user auto-logins in the app.
 *
 * Usage: npx ts-node -r tsconfig-paths/register src/seed/seed-users.ts
 */

import { DataSource } from 'typeorm';
import * as bcrypt from 'bcryptjs';
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
    // Update existing demo user with auth fields
    const password_hash = await bcrypt.hash('demo1234', 12);
    existing.password_hash = password_hash;
    existing.auth_provider = 'email';
    existing.email_verified = true;
    if (!existing.email) existing.email = 'demo@efb.app';
    await userRepo.save(existing);
    console.log('Demo user updated with auth fields.');
  } else {
    const password_hash = await bcrypt.hash('demo1234', 12);
    await userRepo.save({
      id: DEMO_USER_ID,
      name: 'Demo Pilot',
      email: 'demo@efb.app',
      password_hash,
      auth_provider: 'email',
      email_verified: true,
      role: 'user',
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
