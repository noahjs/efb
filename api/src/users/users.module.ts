import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { UsersController } from './users.controller';
import { UsersService } from './users.service';
import { User } from './entities/user.entity';
import { StarredAirport } from './entities/starred-airport.entity';
import { AirportsModule } from '../airports/airports.module';

@Module({
  imports: [TypeOrmModule.forFeature([User, StarredAirport]), AirportsModule],
  controllers: [UsersController],
  providers: [UsersService],
  exports: [UsersService],
})
export class UsersModule {}
