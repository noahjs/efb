import 'dotenv/config';
import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import helmet from 'helmet';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  // Security headers
  app.use(
    helmet({
      // Disable HSTS in development — it causes Chrome to cache an HSTS policy
      // for localhost and silently upgrade HTTP→HTTPS, breaking connections.
      hsts: false,
      // Allow cross-origin resource loading (Flutter web loads from a different port)
      crossOriginResourcePolicy: { policy: 'cross-origin' },
      // Disable X-Frame-Options so CSP frame-ancestors takes precedence
      frameguard: false,
      // Allow inline scripts for admin page; allow framing from any localhost port
      contentSecurityPolicy: {
        directives: {
          defaultSrc: ["'self'"],
          scriptSrc: ["'self'", "'unsafe-inline'"],
          scriptSrcAttr: ["'unsafe-inline'"],
          styleSrc: ["'self'", "'unsafe-inline'"],
          frameAncestors: ["'self'", 'http://localhost:*', 'https://localhost:*'],
        },
      },
    }),
  );

  // Global prefix for all routes
  app.setGlobalPrefix('api');

  // CORS for Flutter web dev and admin page
  const corsOrigins = process.env.CORS_ORIGINS;
  app.enableCors({
    origin: (origin, callback) => {
      if (!origin) {
        callback(null, true);
        return;
      }
      if (corsOrigins) {
        // Explicit allowlist from env var (comma-separated)
        const allowed = corsOrigins.split(',').map((s) => s.trim());
        if (allowed.includes(origin)) {
          callback(null, true);
        } else {
          callback(new Error('Not allowed by CORS'));
        }
      } else {
        // Default: allow all localhost origins in development
        if (/^https?:\/\/localhost(:\d+)?$/.test(origin)) {
          callback(null, true);
        } else {
          callback(new Error('Not allowed by CORS'));
        }
      }
    },
    methods: 'GET,HEAD,PUT,PATCH,POST,DELETE',
  });

  // Validation
  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
    }),
  );

  const port = process.env.PORT || 3001;
  await app.listen(port);
  console.log(`EFB API running on http://localhost:${port}`);
}
bootstrap();
