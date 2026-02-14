export function serviceRole(): string {
  return (process.env.SERVICE_ROLE || 'api').toLowerCase();
}

export function isProduction(): boolean {
  return (process.env.NODE_ENV || 'development').toLowerCase() === 'production';
}

/**
 * In development and other non-production environments, run scheduler/worker
 * in-process for local convenience. In production, only worker role runs them.
 */
export function isWorkerRuntimeEnabled(): boolean {
  if (!isProduction()) {
    return true;
  }
  return serviceRole() === 'worker';
}
