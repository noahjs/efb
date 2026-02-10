import { Injectable, Logger } from '@nestjs/common';
import { Storage } from '@google-cloud/storage';
import * as path from 'path';

@Injectable()
export class StorageService {
  private readonly storage: Storage;
  private readonly bucket: string;
  private readonly logger = new Logger(StorageService.name);

  constructor() {
    this.bucket = process.env.GCS_BUCKET || 'mobile-efb-dev';

    const keyFilePath =
      process.env.GCS_KEY_FILE ||
      path.resolve(process.cwd(), '..', 'gcs-key.json');

    this.storage = new Storage({ keyFilename: keyFilePath });
  }

  async upload(
    key: string,
    buffer: Buffer,
    contentType: string,
  ): Promise<void> {
    const file = this.storage.bucket(this.bucket).file(key);
    await file.save(buffer, {
      contentType,
      resumable: false,
    });
    this.logger.log(`Uploaded ${key} (${buffer.length} bytes)`);
  }

  async getPresignedUrl(key: string, expiresIn = 3600): Promise<string> {
    const file = this.storage.bucket(this.bucket).file(key);
    const [url] = await file.getSignedUrl({
      action: 'read',
      expires: Date.now() + expiresIn * 1000,
    });
    return url;
  }

  async download(key: string): Promise<Buffer> {
    const file = this.storage.bucket(this.bucket).file(key);
    const [contents] = await file.download();
    return contents;
  }

  async delete(key: string): Promise<void> {
    const file = this.storage.bucket(this.bucket).file(key);
    await file.delete({ ignoreNotFound: true });
    this.logger.log(`Deleted ${key}`);
  }
}
