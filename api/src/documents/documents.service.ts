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

  async findFolders(aircraftId?: number): Promise<DocumentFolder[]> {
    return this.folderRepo.find({
      where: aircraftId ? { aircraft_id: aircraftId } : {},
      order: { name: 'ASC' },
    });
  }

  async createFolder(dto: CreateDocumentFolderDto): Promise<DocumentFolder> {
    const folder = this.folderRepo.create(dto);
    return this.folderRepo.save(folder);
  }

  async updateFolder(
    id: number,
    dto: UpdateDocumentFolderDto,
  ): Promise<DocumentFolder> {
    const folder = await this.folderRepo.findOne({ where: { id } });
    if (!folder) throw new NotFoundException(`Folder #${id} not found`);
    Object.assign(folder, dto);
    return this.folderRepo.save(folder);
  }

  async removeFolder(id: number): Promise<void> {
    const folder = await this.folderRepo.findOne({ where: { id } });
    if (!folder) throw new NotFoundException(`Folder #${id} not found`);
    await this.folderRepo.remove(folder);
  }

  // ── Documents ──

  async findDocuments(filters: {
    folder_id?: number;
    aircraft_id?: number;
  }): Promise<Document[]> {
    const where: Record<string, number> = {};
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

  async getDocument(id: number): Promise<Document> {
    const doc = await this.documentRepo.findOne({
      where: { id },
      relations: ['folder'],
    });
    if (!doc) throw new NotFoundException(`Document #${id} not found`);
    return doc;
  }

  async getDownloadUrl(id: number): Promise<{ url: string }> {
    const doc = await this.getDocument(id);
    const url = await this.storageService.getPresignedUrl(doc.s3_key);
    return { url };
  }

  async downloadFile(
    id: number,
  ): Promise<{ buffer: Buffer; mimeType: string; filename: string }> {
    const doc = await this.getDocument(id);
    const buffer = await this.storageService.download(doc.s3_key);
    return {
      buffer,
      mimeType: doc.mime_type,
      filename: doc.original_name,
    };
  }

  async updateDocument(id: number, dto: UpdateDocumentDto): Promise<Document> {
    await this.getDocument(id); // throws NotFoundException if missing
    const updates: Record<string, any> = {};
    for (const [key, value] of Object.entries(dto)) {
      if (value !== undefined) updates[key] = value;
    }
    if (Object.keys(updates).length > 0) {
      await this.documentRepo.update(id, updates);
    }
    return this.getDocument(id);
  }

  async removeDocument(id: number): Promise<void> {
    const doc = await this.getDocument(id);
    await this.storageService.delete(doc.s3_key);
    await this.documentRepo.remove(doc);
  }
}
