import { Injectable, NotFoundException, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Procedure } from './entities/procedure.entity';
import { DtppCycle } from './entities/dtpp-cycle.entity';
import * as fs from 'fs';
import * as path from 'path';
import * as https from 'https';
import * as http from 'http';

const PDF_CACHE_DIR = path.join(__dirname, '..', '..', 'data', 'procedures', 'pdfs');

@Injectable()
export class ProceduresService {
  private readonly logger = new Logger(ProceduresService.name);

  constructor(
    @InjectRepository(Procedure) private procedureRepo: Repository<Procedure>,
    @InjectRepository(DtppCycle) private cycleRepo: Repository<DtppCycle>,
  ) {}

  async getByAirport(airportId: string): Promise<Record<string, Procedure[]>> {
    // FAA d-TPP uses FAA identifiers (e.g. "APA"), not ICAO (e.g. "KAPA").
    // Try the provided ID first, then strip leading K for US ICAO codes.
    let id = airportId.toUpperCase();
    let procedures = await this.procedureRepo.find({
      where: { airport_identifier: id },
      order: { chart_code: 'ASC', chart_seq: 'ASC' },
    });

    if (procedures.length === 0 && id.length === 4 && id.startsWith('K')) {
      id = id.substring(1);
      procedures = await this.procedureRepo.find({
        where: { airport_identifier: id },
        order: { chart_code: 'ASC', chart_seq: 'ASC' },
      });
    }

    const grouped: Record<string, Procedure[]> = {};
    for (const proc of procedures) {
      if (!grouped[proc.chart_code]) {
        grouped[proc.chart_code] = [];
      }
      grouped[proc.chart_code].push(proc);
    }

    return grouped;
  }

  async getPdf(
    airportId: string,
    procedureId: number,
  ): Promise<{ filePath: string; fileName: string }> {
    let id = airportId.toUpperCase();
    let procedure = await this.procedureRepo.findOne({
      where: { id: procedureId, airport_identifier: id },
    });

    if (!procedure && id.length === 4 && id.startsWith('K')) {
      id = id.substring(1);
      procedure = await this.procedureRepo.findOne({
        where: { id: procedureId, airport_identifier: id },
      });
    }

    if (!procedure) {
      throw new NotFoundException('Procedure not found');
    }

    const cycleDir = path.join(PDF_CACHE_DIR, procedure.cycle);
    const filePath = path.join(cycleDir, procedure.pdf_name);

    // If cached, return immediately
    if (fs.existsSync(filePath)) {
      return { filePath, fileName: procedure.pdf_name };
    }

    // Download on-demand from FAA
    fs.mkdirSync(cycleDir, { recursive: true });
    const url = `https://aeronav.faa.gov/d-tpp/${procedure.cycle}/${procedure.pdf_name}`;
    this.logger.log(`Downloading PDF: ${url}`);

    await this.downloadFile(url, filePath);
    return { filePath, fileName: procedure.pdf_name };
  }

  async getCurrentCycle(): Promise<DtppCycle | null> {
    const cycles = await this.cycleRepo.find({
      order: { seeded_at: 'DESC' },
      take: 1,
    });
    return cycles[0] || null;
  }

  private downloadFile(url: string, dest: string): Promise<void> {
    return new Promise((resolve, reject) => {
      const file = fs.createWriteStream(dest);
      const protocol = url.startsWith('https') ? https : http;

      (protocol as typeof https)
        .get(url, (response) => {
          if (
            response.statusCode &&
            response.statusCode >= 300 &&
            response.statusCode < 400 &&
            response.headers.location
          ) {
            file.close();
            fs.unlinkSync(dest);
            return this.downloadFile(response.headers.location, dest).then(
              resolve,
              reject,
            );
          }

          if (response.statusCode && response.statusCode >= 400) {
            file.close();
            fs.unlinkSync(dest);
            reject(new Error(`HTTP ${response.statusCode} downloading ${url}`));
            return;
          }

          response.pipe(file);
          file.on('finish', () => {
            file.close();
            resolve();
          });
        })
        .on('error', (err) => {
          if (fs.existsSync(dest)) fs.unlinkSync(dest);
          reject(err);
        });
    });
  }
}
