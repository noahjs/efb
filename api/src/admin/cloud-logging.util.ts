export type AdminLogsQuery = {
  q?: string;
  context?: string;
  /** 'error' = error+fatal, 'warning' = warn+error+fatal, undefined = all */
  minLevel?: 'warning' | 'error';
  sinceMinutes?: number;
  serviceName?: string;
};

// Cloud Logging advanced filter values are typically wrapped in double quotes.
// Escape backslashes + quotes to keep the filter valid.
export function escapeCloudLoggingFilterValue(value: string): string {
  return value.replace(/\\/g, '\\\\').replace(/"/g, '\\"');
}

export function buildCloudLoggingFilter(params: AdminLogsQuery & { sinceIso: string }): string {
  const parts: string[] = [];

  // Time window (RFC3339)
  parts.push(`timestamp >= "${params.sinceIso}"`);

  // Cloud Run revision resource (when we know the service name, scope logs to it).
  if (params.serviceName) {
    parts.push(
      `resource.type="cloud_run_revision" AND resource.labels.service_name="${escapeCloudLoggingFilterValue(
        params.serviceName,
      )}"`,
    );
  } else {
    parts.push(`resource.type="cloud_run_revision"`);
  }

  if (params.minLevel === 'error') {
    parts.push('(jsonPayload.level="error" OR jsonPayload.level="fatal")');
  } else if (params.minLevel === 'warning') {
    parts.push('(jsonPayload.level="warn" OR jsonPayload.level="error" OR jsonPayload.level="fatal")');
  }

  if (params.context) {
    const ctx = escapeCloudLoggingFilterValue(params.context);
    // Our JsonLogger writes `context` into jsonPayload.context.
    parts.push(`jsonPayload.context:"${ctx}"`);
  }

  if (params.q) {
    const q = escapeCloudLoggingFilterValue(params.q);
    parts.push(
      `(textPayload:"${q}" OR jsonPayload.message:"${q}" OR jsonPayload.event:"${q}" OR jsonPayload.context:"${q}")`,
    );
  }

  return parts.join(' AND ');
}
