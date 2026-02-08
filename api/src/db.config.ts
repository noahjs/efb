export const dbConfig = {
  type: 'postgres' as const,
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT || '5433', 10),
  username: process.env.DB_USER || 'efb',
  password: process.env.DB_PASS || 'efb',
  database: process.env.DB_NAME || 'efb',
  synchronize: true,
};
