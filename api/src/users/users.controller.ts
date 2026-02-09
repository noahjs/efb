import {
  Controller,
  Get,
  Put,
  Delete,
  Param,
  Body,
  NotFoundException,
} from '@nestjs/common';
import { UsersService } from './users.service';
import { UpdateUserDto } from './dto/update-user.dto';

@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get('me')
  async getMe() {
    const user = await this.usersService.getDemoUser();
    if (!user) {
      throw new NotFoundException('Demo user not found. Run the seed script.');
    }
    return user;
  }

  @Put('me')
  async updateProfile(@Body() dto: UpdateUserDto) {
    return this.usersService.updateProfile(dto);
  }

  @Get('me/starred-airports')
  async getStarredAirports() {
    return this.usersService.getStarredAirports();
  }

  @Put('me/starred-airports/:airportId')
  async starAirport(@Param('airportId') airportId: string) {
    const airport = await this.usersService.starAirport(airportId);
    if (!airport) {
      throw new NotFoundException(`Airport ${airportId} not found`);
    }
    return airport;
  }

  @Delete('me/starred-airports/:airportId')
  async unstarAirport(@Param('airportId') airportId: string) {
    await this.usersService.unstarAirport(airportId);
    return { success: true };
  }
}
