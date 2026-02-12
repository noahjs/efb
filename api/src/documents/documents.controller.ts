import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Body,
  Param,
  Query,
  Res,
  ParseIntPipe,
  UseInterceptors,
  UploadedFile,
  BadRequestException,
} from '@nestjs/common';
import type { Response } from 'express';
import { FileInterceptor } from '@nestjs/platform-express';
import { DocumentsService } from './documents.service';
import { CreateDocumentFolderDto } from './dto/create-document-folder.dto';
import { UpdateDocumentFolderDto } from './dto/update-document-folder.dto';
import { UpdateDocumentDto } from './dto/update-document.dto';
import { CurrentUser } from '../auth/decorators/current-user.decorator';

const ALLOWED_MIMES = ['application/pdf', 'image/jpeg', 'image/png'];

@Controller('documents')
export class DocumentsController {
  constructor(private readonly documentsService: DocumentsService) {}

  // ── Folders (defined BEFORE /:id to avoid param collision) ──

  @Get('folders')
  findFolders(
    @CurrentUser() user: { id: string },
    @Query('aircraft_id') aircraftId?: string,
  ) {
    return this.documentsService.findFolders(
      user.id,
      aircraftId ? parseInt(aircraftId, 10) : undefined,
    );
  }

  @Post('folders')
  createFolder(
    @CurrentUser() user: { id: string },
    @Body() dto: CreateDocumentFolderDto,
  ) {
    return this.documentsService.createFolder(dto, user.id);
  }

  @Patch('folders/:id')
  updateFolder(
    @CurrentUser() user: { id: string },
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateDocumentFolderDto,
  ) {
    return this.documentsService.updateFolder(id, dto, user.id);
  }

  @Delete('folders/:id')
  removeFolder(
    @CurrentUser() user: { id: string },
    @Param('id', ParseIntPipe) id: number,
  ) {
    return this.documentsService.removeFolder(id, user.id);
  }

  // ── Documents ──

  @Post('upload')
  @UseInterceptors(
    FileInterceptor('file', { limits: { fileSize: 50 * 1024 * 1024 } }),
  )
  uploadDocument(
    @CurrentUser() user: { id: string; email: string },
    @UploadedFile() file: Express.Multer.File,
    @Body('aircraft_id') aircraftId?: string,
    @Body('folder_id') folderId?: string,
  ) {
    if (!file) {
      throw new BadRequestException('No file uploaded');
    }
    if (!ALLOWED_MIMES.includes(file.mimetype)) {
      throw new BadRequestException(
        'File type not allowed. Accepted: PDF, JPEG, PNG',
      );
    }
    return this.documentsService.uploadDocument(
      file,
      user.id,
      aircraftId ? parseInt(aircraftId, 10) : undefined,
      folderId ? parseInt(folderId, 10) : undefined,
    );
  }

  @Get()
  findDocuments(
    @CurrentUser() user: { id: string },
    @Query('folder_id') folderId?: string,
    @Query('aircraft_id') aircraftId?: string,
  ) {
    return this.documentsService.findDocuments(user.id, {
      folder_id: folderId ? parseInt(folderId, 10) : undefined,
      aircraft_id: aircraftId ? parseInt(aircraftId, 10) : undefined,
    });
  }

  @Get(':id')
  getDocument(
    @CurrentUser() user: { id: string },
    @Param('id', ParseIntPipe) id: number,
  ) {
    return this.documentsService.getDocument(id, user.id);
  }

  @Get(':id/download')
  async downloadFile(
    @CurrentUser() user: { id: string },
    @Param('id', ParseIntPipe) id: number,
    @Res() res: Response,
  ) {
    const { buffer, mimeType, filename } =
      await this.documentsService.downloadFile(id, user.id);
    res.set({
      'Content-Type': mimeType,
      'Content-Disposition': `inline; filename="${filename}"`,
      'Content-Length': buffer.length,
    });
    res.send(buffer);
  }

  @Patch(':id')
  updateDocument(
    @CurrentUser() user: { id: string },
    @Param('id', ParseIntPipe) id: number,
    @Body() dto: UpdateDocumentDto,
  ) {
    return this.documentsService.updateDocument(id, dto, user.id);
  }

  @Delete(':id')
  removeDocument(
    @CurrentUser() user: { id: string },
    @Param('id', ParseIntPipe) id: number,
  ) {
    return this.documentsService.removeDocument(id, user.id);
  }
}
