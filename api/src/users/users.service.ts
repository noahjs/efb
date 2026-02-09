import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from './entities/user.entity';
import { StarredAirport } from './entities/starred-airport.entity';
import { AirportsService } from '../airports/airports.service';
import { UpdateUserDto } from './dto/update-user.dto';

const DEMO_USER_ID = '00000000-0000-0000-0000-000000000001';

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User)
    private userRepo: Repository<User>,
    @InjectRepository(StarredAirport)
    private starredRepo: Repository<StarredAirport>,
    private airportsService: AirportsService,
  ) {}

  async getDemoUser() {
    return this.userRepo.findOne({ where: { id: DEMO_USER_ID } });
  }

  async getStarredAirports() {
    const starred = await this.starredRepo.find({
      where: { user_id: DEMO_USER_ID },
      order: { created_at: 'DESC' },
    });

    const airports = await Promise.all(
      starred.map((s) => this.airportsService.findById(s.airport_identifier)),
    );

    return airports.filter((a) => a !== null);
  }

  async starAirport(airportIdentifier: string) {
    // Resolve the airport to ensure it exists and normalize the identifier
    const airport = await this.airportsService.findById(airportIdentifier);
    if (!airport) {
      return null;
    }

    const existing = await this.starredRepo.findOne({
      where: {
        user_id: DEMO_USER_ID,
        airport_identifier: airport.identifier,
      },
    });

    if (existing) {
      return airport;
    }

    await this.starredRepo.save({
      user_id: DEMO_USER_ID,
      airport_identifier: airport.identifier,
    });

    return airport;
  }

  async updateProfile(dto: UpdateUserDto) {
    const user = await this.getDemoUser();
    if (!user) {
      throw new NotFoundException('Demo user not found. Run the seed script.');
    }
    const filtered = Object.fromEntries(
      Object.entries(dto).filter(([, v]) => v !== undefined),
    );
    Object.assign(user, filtered);
    return this.userRepo.save(user);
  }

  async unstarAirport(airportIdentifier: string) {
    // Try both the raw identifier and resolved one
    const airport = await this.airportsService.findById(airportIdentifier);
    const identifier = airport?.identifier ?? airportIdentifier;

    await this.starredRepo.delete({
      user_id: DEMO_USER_ID,
      airport_identifier: identifier,
    });
  }
}
