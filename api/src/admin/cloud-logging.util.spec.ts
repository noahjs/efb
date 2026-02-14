import { buildCloudLoggingFilter, escapeCloudLoggingFilterValue } from './cloud-logging.util';

describe('cloud-logging.util', () => {
  it('escapes backslashes and quotes', () => {
    expect(escapeCloudLoggingFilterValue('a"b\\c')).toBe('a\\"b\\\\c');
  });

  it('builds a filter with optional fields', () => {
    const filter = buildCloudLoggingFilter({
      sinceIso: '2026-02-14T00:00:00.000Z',
      serviceName: 'efb-api',
      minLevel: 'error',
      context: 'AdminService',
      q: 'failed "bad"',
      sinceMinutes: 60,
    });

    expect(filter).toContain('timestamp >= "2026-02-14T00:00:00.000Z"');
    expect(filter).toContain('resource.type="cloud_run_revision"');
    expect(filter).toContain('resource.labels.service_name="efb-api"');
    expect(filter).toContain('(jsonPayload.level="error" OR jsonPayload.level="fatal")');
    expect(filter).toContain('jsonPayload.context:"AdminService"');
    expect(filter).toContain('jsonPayload.message:"failed \\"bad\\""');
  });

  it('queries all Cloud Run services when no serviceName is provided', () => {
    const filter = buildCloudLoggingFilter({
      sinceIso: '2026-02-14T00:00:00.000Z',
      sinceMinutes: 60,
    });

    expect(filter).toContain('resource.type="cloud_run_revision"');
    expect(filter).not.toContain('resource.labels.service_name');
  });

  it('filters warnings + errors + fatals with minLevel=warning', () => {
    const filter = buildCloudLoggingFilter({
      sinceIso: '2026-02-14T00:00:00.000Z',
      minLevel: 'warning',
      sinceMinutes: 60,
    });

    expect(filter).toContain('jsonPayload.level="warn"');
    expect(filter).toContain('jsonPayload.level="error"');
    expect(filter).toContain('jsonPayload.level="fatal"');
  });

  it('does not filter by level when minLevel is omitted', () => {
    const filter = buildCloudLoggingFilter({
      sinceIso: '2026-02-14T00:00:00.000Z',
      sinceMinutes: 60,
    });

    expect(filter).not.toContain('jsonPayload.level');
  });
});
