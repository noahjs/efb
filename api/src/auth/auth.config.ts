function resolveJwtSecret(): string {
  if (process.env.JWT_SECRET) {
    return process.env.JWT_SECRET;
  }
  if (process.env.NODE_ENV === 'production') {
    throw new Error(
      'JWT_SECRET environment variable is required in production',
    );
  }
  return 'dev-jwt-secret-change-in-production';
}

export const authConfig = {
  jwtSecret: resolveJwtSecret(),
  jwtAccessExpiry: '15m',
  jwtRefreshExpiry: '30d',
  bcryptRounds: 12,
  googleClientId: process.env.GOOGLE_CLIENT_ID || '',
  appleBundleId: process.env.APPLE_BUNDLE_ID || 'com.efb.app',
};
