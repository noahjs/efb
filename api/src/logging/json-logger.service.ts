import { LoggerService, LogLevel } from '@nestjs/common';

type ContextualMessage = {
  context?: string;
  event?: string;
  message?: string;
  [key: string]: unknown;
};

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

    const line = `${this.safeStringify(entry)}\n`;
    if (level === 'error' || level === 'fatal') {
      process.stderr.write(line);
      return;
    }
    process.stdout.write(line);
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
