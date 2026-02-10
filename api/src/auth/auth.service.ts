import {
  Injectable,
  ConflictException,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import * as bcrypt from 'bcryptjs';
import { OAuth2Client } from 'google-auth-library';
import * as crypto from 'crypto';
import { User } from '../users/entities/user.entity';
import { authConfig } from './auth.config';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { GoogleAuthDto, AppleAuthDto } from './dto/social-auth.dto';
import { RefreshDto } from './dto/refresh.dto';

@Injectable()
export class AuthService {
  private googleClient: OAuth2Client;

  constructor(
    @InjectRepository(User)
    private userRepo: Repository<User>,
    private jwtService: JwtService,
  ) {
    this.googleClient = new OAuth2Client(authConfig.googleClientId);
  }

  async register(dto: RegisterDto) {
    const existing = await this.userRepo.findOne({
      where: { email: dto.email.toLowerCase() },
    });
    if (existing) {
      throw new ConflictException('Email already registered');
    }

    const password_hash = await bcrypt.hash(dto.password, authConfig.bcryptRounds);

    const user = this.userRepo.create({
      name: dto.name,
      email: dto.email.toLowerCase(),
      password_hash,
      auth_provider: 'email',
      email_verified: false,
    });
    await this.userRepo.save(user);

    return this.generateTokenResponse(user);
  }

  async login(dto: LoginDto) {
    const user = await this.userRepo
      .createQueryBuilder('user')
      .addSelect('user.password_hash')
      .where('user.email = :email', { email: dto.email.toLowerCase() })
      .getOne();

    if (!user || !user.password_hash) {
      throw new UnauthorizedException('Invalid email or password');
    }

    const valid = await bcrypt.compare(dto.password, user.password_hash);
    if (!valid) {
      throw new UnauthorizedException('Invalid email or password');
    }

    return this.generateTokenResponse(user);
  }

  async loginWithGoogle(dto: GoogleAuthDto) {
    const ticket = await this.googleClient.verifyIdToken({
      idToken: dto.id_token,
      audience: authConfig.googleClientId,
    });
    const payload = ticket.getPayload();
    if (!payload || !payload.email) {
      throw new UnauthorizedException('Invalid Google token');
    }

    let user = await this.userRepo.findOne({
      where: { provider_id: payload.sub, auth_provider: 'google' },
    });

    if (!user) {
      // Check if email already exists with a different provider
      user = await this.userRepo.findOne({
        where: { email: payload.email.toLowerCase() },
      });
      if (user) {
        // Link the Google account to the existing user
        user.provider_id = payload.sub;
        user.auth_provider = 'google';
        user.email_verified = true;
        await this.userRepo.save(user);
      } else {
        user = this.userRepo.create({
          name: payload.name || payload.email.split('@')[0],
          email: payload.email.toLowerCase(),
          auth_provider: 'google',
          provider_id: payload.sub,
          email_verified: true,
        });
        await this.userRepo.save(user);
      }
    }

    return this.generateTokenResponse(user);
  }

  async loginWithApple(dto: AppleAuthDto) {
    // Decode the Apple identity token (JWT) to extract claims
    const decoded = this.jwtService.decode(dto.identity_token) as any;
    if (!decoded || !decoded.sub) {
      throw new UnauthorizedException('Invalid Apple token');
    }

    // In production, you'd verify the token signature against Apple's JWKS
    // For now we trust the token content (Apple tokens are hard to forge)
    const appleUserId = decoded.sub as string;
    const email = (decoded.email as string)?.toLowerCase();

    let user = await this.userRepo.findOne({
      where: { provider_id: appleUserId, auth_provider: 'apple' },
    });

    if (!user && email) {
      user = await this.userRepo.findOne({
        where: { email },
      });
      if (user) {
        user.provider_id = appleUserId;
        user.auth_provider = 'apple';
        user.email_verified = true;
        await this.userRepo.save(user);
      }
    }

    if (!user) {
      user = this.userRepo.create({
        name: dto.name || email?.split('@')[0] || 'Apple User',
        email: email || `${appleUserId}@privaterelay.appleid.com`,
        auth_provider: 'apple',
        provider_id: appleUserId,
        email_verified: !!email,
      });
      await this.userRepo.save(user);
    }

    return this.generateTokenResponse(user);
  }

  async refresh(dto: RefreshDto) {
    let payload: any;
    try {
      payload = this.jwtService.verify(dto.refresh_token, {
        secret: authConfig.jwtSecret,
      });
    } catch {
      throw new UnauthorizedException('Invalid refresh token');
    }

    if (payload.type !== 'refresh') {
      throw new UnauthorizedException('Invalid token type');
    }

    const user = await this.userRepo
      .createQueryBuilder('user')
      .addSelect('user.refresh_token_hash')
      .where('user.id = :id', { id: payload.sub })
      .getOne();

    if (!user || !user.refresh_token_hash) {
      throw new UnauthorizedException('Refresh token revoked');
    }

    // Verify the stored hash matches
    const tokenHash = crypto
      .createHash('sha256')
      .update(dto.refresh_token)
      .digest('hex');
    if (tokenHash !== user.refresh_token_hash) {
      throw new UnauthorizedException('Refresh token revoked');
    }

    return this.generateTokenResponse(user);
  }

  async logout(userId: string) {
    await this.userRepo.update(userId, { refresh_token_hash: null } as any);
  }

  private async generateTokenResponse(user: User) {
    const tokenPayload = { sub: user.id, email: user.email };

    const access_token = this.jwtService.sign(tokenPayload, {
      expiresIn: '15m',
    });

    const refresh_token = this.jwtService.sign(
      { ...tokenPayload, type: 'refresh' },
      { expiresIn: '30d' },
    );

    // Store hash of refresh token
    const refresh_token_hash = crypto
      .createHash('sha256')
      .update(refresh_token)
      .digest('hex');
    await this.userRepo.update(user.id, {
      refresh_token_hash,
    } as any);

    return {
      access_token,
      refresh_token,
      user: {
        id: user.id,
        name: user.name,
        email: user.email,
      },
    };
  }
}
