import {
  CallHandler,
  ExecutionContext,
  HttpException,
  Injectable,
  Logger,
  NestInterceptor,
} from '@nestjs/common';
import { Observable, tap } from 'rxjs';

type RequestWithMeta = {
  method: string;
  originalUrl?: string;
  url: string;
  ip?: string;
  requestId?: string;
  user?: { id?: string };
};

@Injectable()
export class RequestLoggingInterceptor implements NestInterceptor {
  private readonly logger = new Logger(RequestLoggingInterceptor.name);

  intercept(context: ExecutionContext, next: CallHandler): Observable<unknown> {
    if (context.getType() !== 'http') {
      return next.handle();
    }

    const req = context.switchToHttp().getRequest<RequestWithMeta>();
    const res = context.switchToHttp().getResponse<{ statusCode: number }>();
    const started = Date.now();
    const path = req.originalUrl || req.url;

    return next.handle().pipe(
      tap({
        next: () => {
          this.logger.log({
            event: 'http_request',
            requestId: req.requestId,
            method: req.method,
            path,
            statusCode: res.statusCode,
            durationMs: Date.now() - started,
            userId: req.user?.id,
            ip: req.ip,
          });
        },
        error: (err: unknown) => {
          const statusCode = this.inferStatusCode(err);
          this.logger.warn({
            event: 'http_request_error',
            requestId: req.requestId,
            method: req.method,
            path,
            statusCode,
            durationMs: Date.now() - started,
            userId: req.user?.id,
            ip: req.ip,
          });
        },
      }),
    );
  }

  private inferStatusCode(err: unknown): number {
    if (err instanceof HttpException) {
      return err.getStatus();
    }
    return 500;
  }
}
