import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Document } from './entities/document.entity';
import { DocumentFolder } from './entities/document-folder.entity';
import { StorageService } from './storage.service';
import { CreateDocumentFolderDto } from './dto/create-document-folder.dto';
import { UpdateDocumentFolderDto } from './dto/update-document-folder.dto';
import { UpdateDocumentDto } from './dto/update-document.dto';
import * as path from 'path';
import * as crypto from 'crypto';

@Injectable()
export class DocumentsService {
  constructor(
    @InjectRepository(Document)
    private readonly documentRepo: Repository<Document>,
    @InjectRepository(DocumentFolder)
    private readonly folderRepo: Repository<DocumentFolder>,
    private readonly storageService: StorageService,
  ) {}

  // ── Folders ──

  async findFolders(
    userId: string,
    aircraftId?: number,
  ): Promise<DocumentFolder[]> {
    const where: Record<string, any> = { user_id: userId };
    if (aircraftId) where.aircraft_id = aircraftId;
    return this.folderRepo.find({
      where,
      order: { name: 'ASC' },
    });
  }

  async createFolder(
    dto: CreateDocumentFolderDto,
    userId: string,
  ): Promise<DocumentFolder> {
    const folder = this.folderRepo.create({ ...dto, user_id: userId });
    return this.folderRepo.save(folder);
  }

  async updateFolder(
    id: number,
    dto: UpdateDocumentFolderDto,
    userId: string,
  ): Promise<DocumentFolder> {
    const folder = await this.folderRepo.findOne({
      where: { id, user_id: userId },
    });
    if (!folder) throw new NotFoundException(`Folder #${id} not found`);
    Object.assign(folder, dto);
    return this.folderRepo.save(folder);
  }

  async removeFolder(id: number, userId: string): Promise<void> {
    const folder = await this.folderRepo.findOne({
      where: { id, user_id: userId },
    });
    if (!folder) throw new NotFoundException(`Folder #${id} not found`);
    await this.folderRepo.remove(folder);
  }

  // ── Documents ──

  async findDocuments(
    userId: string,
    filters: {
      folder_id?: number;
      aircraft_id?: number;
    },
  ): Promise<Document[]> {
    const where: Record<string, any> = { user_id: userId };
    if (filters.folder_id) where.folder_id = filters.folder_id;
    if (filters.aircraft_id) where.aircraft_id = filters.aircraft_id;
    return this.documentRepo.find({
      where,
      relations: ['folder'],
      order: { created_at: 'DESC' },
    });
  }

  async uploadDocument(
    file: Express.Multer.File,
    userId: string,
    aircraftId?: number,
    folderId?: number,
  ): Promise<Document> {
    const ext = path.extname(file.originalname).toLowerCase();
    const timestamp = Date.now();
    const random = crypto.randomBytes(8).toString('hex');
    const filename = `${timestamp}-${random}${ext}`;
    const gcsKey = `${userId}/${filename}`;

    await this.storageService.upload(gcsKey, file.buffer, file.mimetype);

    const doc = this.documentRepo.create();
    doc.user_id = userId;
    doc.original_name = file.originalname;
    doc.filename = filename;
    doc.mime_type = file.mimetype;
    doc.size_bytes = file.size;
    doc.s3_key = gcsKey;
    doc.aircraft_id = aircraftId ?? null;
    doc.folder_id = folderId ?? null;

    return this.documentRepo.save(doc);
  }

  async getDocument(id: number, userId?: string): Promise<Document> {
    const where: Record<string, any> = { id };
    if (userId) where.user_id = userId;
    const doc = await this.documentRepo.findOne({
      where,
      relations: ['folder'],
    });
    if (!doc) throw new NotFoundException(`Document #${id} not found`);
    return doc;
  }

  async getDownloadUrl(id: number, userId?: string): Promise<{ url: string }> {
    const doc = await this.getDocument(id, userId);
    const url = await this.storageService.getPresignedUrl(doc.s3_key);
    return { url };
  }

  async downloadFile(
    id: number,
    userId?: string,
  ): Promise<{ buffer: Buffer; mimeType: string; filename: string }> {
    const doc = await this.getDocument(id, userId);
    const buffer = await this.storageService.download(doc.s3_key);
    return {
      buffer,
      mimeType: doc.mime_type,
      filename: doc.original_name,
    };
  }

  async updateDocument(
    id: number,
    dto: UpdateDocumentDto,
    userId?: string,
  ): Promise<Document> {
    await this.getDocument(id, userId); // throws NotFoundException if missing
    const updates: Record<string, any> = {};
    for (const [key, value] of Object.entries(dto)) {
      if (value !== undefined) updates[key] = value;
    }
    if (Object.keys(updates).length > 0) {
      await this.documentRepo.update(id, updates);
    }
    return this.getDocument(id, userId);
  }

  async removeDocument(id: number, userId?: string): Promise<void> {
    const doc = await this.getDocument(id, userId);
    await this.storageService.delete(doc.s3_key);
    await this.documentRepo.remove(doc);
  }
}
