export const authConfig = {
  jwtSecret: process.env.JWT_SECRET || 'dev-jwt-secret-change-in-production',
  jwtAccessExpiry: '15m',
  jwtRefreshExpiry: '30d',
  bcryptRounds: 12,
  googleClientId: process.env.GOOGLE_CLIENT_ID || '',
  appleBundleId: process.env.APPLE_BUNDLE_ID || 'com.efb.app',
};
