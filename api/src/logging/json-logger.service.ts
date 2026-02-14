import { LoggerService, LogLevel } from '@nestjs/common';

type ContextualMessage = {
  context?: string;
  event?: string;
  message?: string;
  [key: string]: unknown;
};

const isDev =
  !process.env.NODE_ENV || process.env.NODE_ENV === 'development';

const levelColors: Record<string, string> = {
  log: '\x1b[32m',     // green
  error: '\x1b[31m',   // red
  warn: '\x1b[33m',    // yellow
  debug: '\x1b[35m',   // magenta
  verbose: '\x1b[36m', // cyan
  fatal: '\x1b[41m',   // red background
};
const reset = '\x1b[0m';
const dim = '\x1b[2m';
const yellow = '\x1b[33m';

export class JsonLogger implements LoggerService {
  private readonly defaultContext?: string;

  constructor(context?: string) {
    this.defaultContext = context;
  }

  log(message: unknown, context?: string): void {
    this.write('log', message, context);
  }

  error(message: unknown, trace?: string, context?: string): void {
    this.write('error', message, context, trace);
  }

  warn(message: unknown, context?: string): void {
    this.write('warn', message, context);
  }

  debug(message: unknown, context?: string): void {
    this.write('debug', message, context);
  }

  verbose(message: unknown, context?: string): void {
    this.write('verbose', message, context);
  }

  fatal(message: unknown, context?: string): void {
    this.write('fatal', message, context);
  }

  private write(
    level: LogLevel | 'fatal',
    message: unknown,
    context?: string,
    trace?: string,
  ): void {
    const entry: Record<string, unknown> = {
      timestamp: new Date().toISOString(),
      level,
      pid: process.pid,
      context: context || this.defaultContext || 'Application',
    };

    if (typeof message === 'string') {
      entry.message = message;
    } else if (message instanceof Error) {
      entry.message = message.message;
      entry.error_name = message.name;
      entry.stack = message.stack;
    } else if (message && typeof message === 'object') {
      Object.assign(entry, message as ContextualMessage);
      if (!entry.message) {
        entry.message = 'log';
      }
    } else {
      entry.message = String(message);
    }

    if (trace) {
      entry.trace = trace;
    }

    const line = isDev ? this.formatDev(entry, level) : `${this.safeStringify(entry)}\n`;
    if (level === 'error' || level === 'fatal') {
      process.stderr.write(line);
      return;
    }
    process.stdout.write(line);
  }

  private formatDev(
    entry: Record<string, unknown>,
    level: LogLevel | 'fatal',
  ): string {
    const color = levelColors[level] || '';
    const tag = level.toUpperCase().padEnd(7);
    const ctx = entry.context ? `${yellow}[${entry.context}]${reset} ` : '';
    const msg = entry.message || '';

    // Collect extra fields (skip the ones already shown)
    const skip = new Set([
      'timestamp',
      'level',
      'pid',
      'context',
      'message',
      'stack',
      'trace',
    ]);
    const extras = Object.entries(entry)
      .filter(([k]) => !skip.has(k))
      .map(([k, v]) => `${dim}${k}=${typeof v === 'object' ? JSON.stringify(v) : v}${reset}`)
      .join(' ');

    let line = `${color}${tag}${reset} ${ctx}${msg}`;
    if (extras) line += ` ${extras}`;
    line += '\n';

    if (entry.stack) line += `${dim}${entry.stack}${reset}\n`;
    if (entry.trace) line += `${dim}${entry.trace}${reset}\n`;

    return line;
  }

  private safeStringify(value: unknown): string {
    const seen = new WeakSet();
    return JSON.stringify(value, (_key, current) => {
      if (typeof current === 'bigint') {
        return current.toString();
      }
      if (current && typeof current === 'object') {
        if (seen.has(current)) {
          return '[Circular]';
        }
        seen.add(current);
      }
      return current;
    });
  }
}
