import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from './entities/user.entity';
import { StarredAirport } from './entities/starred-airport.entity';
import { AirportsService } from '../airports/airports.service';
import { UpdateUserDto } from './dto/update-user.dto';

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User)
    private userRepo: Repository<User>,
    @InjectRepository(StarredAirport)
    private starredRepo: Repository<StarredAirport>,
    private airportsService: AirportsService,
  ) {}

  async findById(userId: string) {
    return this.userRepo.findOne({ where: { id: userId } });
  }

  async getStarredAirports(userId: string) {
    const starred = await this.starredRepo.find({
      where: { user_id: userId },
      order: { created_at: 'DESC' },
    });

    const airports = await Promise.all(
      starred.map((s) => this.airportsService.findById(s.airport_identifier)),
    );

    return airports.filter((a) => a !== null);
  }

  async starAirport(userId: string, airportIdentifier: string) {
    const airport = await this.airportsService.findById(airportIdentifier);
    if (!airport) {
      return null;
    }

    const existing = await this.starredRepo.findOne({
      where: {
        user_id: userId,
        airport_identifier: airport.identifier,
      },
    });

    if (existing) {
      return airport;
    }

    await this.starredRepo.save({
      user_id: userId,
      airport_identifier: airport.identifier,
    });

    return airport;
  }

  async updateProfile(userId: string, dto: UpdateUserDto) {
    const user = await this.findById(userId);
    if (!user) {
      throw new NotFoundException('User not found');
    }
    const filtered = Object.fromEntries(
      Object.entries(dto).filter(([, v]) => v !== undefined),
    );
    Object.assign(user, filtered);
    return this.userRepo.save(user);
  }

  async unstarAirport(userId: string, airportIdentifier: string) {
    const airport = await this.airportsService.findById(airportIdentifier);
    const identifier = airport?.identifier ?? airportIdentifier;

    await this.starredRepo.delete({
      user_id: userId,
      airport_identifier: identifier,
    });
  }
}
