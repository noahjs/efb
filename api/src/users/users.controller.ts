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
import { CurrentUser } from '../auth/decorators/current-user.decorator';

@Controller('users')
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Get('me')
  async getMe(@CurrentUser() user: { id: string; email: string }) {
    const found = await this.usersService.findById(user.id);
    if (!found) {
      throw new NotFoundException('User not found');
    }
    return found;
  }

  @Put('me')
  async updateProfile(
    @CurrentUser() user: { id: string; email: string },
    @Body() dto: UpdateUserDto,
  ) {
    return this.usersService.updateProfile(user.id, dto);
  }

  @Get('me/starred-airports')
  async getStarredAirports(@CurrentUser() user: { id: string; email: string }) {
    return this.usersService.getStarredAirports(user.id);
  }

  @Put('me/starred-airports/:airportId')
  async starAirport(
    @CurrentUser() user: { id: string; email: string },
    @Param('airportId') airportId: string,
  ) {
    const airport = await this.usersService.starAirport(user.id, airportId);
    if (!airport) {
      throw new NotFoundException(`Airport ${airportId} not found`);
    }
    return airport;
  }

  @Delete('me/starred-airports/:airportId')
  async unstarAirport(
    @CurrentUser() user: { id: string; email: string },
    @Param('airportId') airportId: string,
  ) {
    await this.usersService.unstarAirport(user.id, airportId);
    return { success: true };
  }
}
