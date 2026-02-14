import { Injectable, NotFoundException, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Procedure } from './entities/procedure.entity';
import { DtppCycle } from './entities/dtpp-cycle.entity';
import { parseGeoref, GeorefData } from './georef-parser';
import { CycleQueryHelper } from '../data-cycle/cycle-query.helper';
import { CycleDataGroup } from '../data-cycle/entities/data-cycle.entity';
import * as fs from 'fs';
import * as path from 'path';
import * as https from 'https';
import * as http from 'http';
import { execFile } from 'child_process';

const PDF_CACHE_DIR = path.join(
  __dirname,
  '..',
  '..',
  'data',
  'procedures',
  'pdfs',
);

const IMAGE_CACHE_DIR = path.join(
  __dirname,
  '..',
  '..',
  'data',
  'procedures',
  'images',
);

@Injectable()
export class ProceduresService {
  private readonly logger = new Logger(ProceduresService.name);

  constructor(
    @InjectRepository(Procedure) private procedureRepo: Repository<Procedure>,
    @InjectRepository(DtppCycle) private cycleRepo: Repository<DtppCycle>,
    private readonly cycleHelper: CycleQueryHelper,
  ) {}

  async getByAirport(airportId: string): Promise<Record<string, Procedure[]>> {
    // FAA d-TPP uses FAA identifiers (e.g. "APA"), not ICAO (e.g. "KAPA").
    // Try the provided ID first, then strip leading K for US ICAO codes.
    const cycleWhere = await this.cycleHelper.getCycleWhere(CycleDataGroup.DTPP);
    let id = airportId.toUpperCase();
    let procedures = await this.procedureRepo.find({
      where: { airport_identifier: id, ...cycleWhere },
      order: { chart_code: 'ASC', chart_seq: 'ASC' },
    });

    if (procedures.length === 0 && id.length === 4 && id.startsWith('K')) {
      id = id.substring(1);
      procedures = await this.procedureRepo.find({
        where: { airport_identifier: id, ...cycleWhere },
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
    const procedure = await this.findProcedure(airportId, procedureId);

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
    const cycleWhere = await this.cycleHelper.getCycleWhere(CycleDataGroup.DTPP);
    const cycles = await this.cycleRepo.find({
      where: { ...cycleWhere },
      order: { seeded_at: 'DESC' },
      take: 1,
    });
    return cycles[0] || null;
  }

  /**
   * Find a procedure by airport ID and procedure ID, handling ICAO→FAA fallback.
   */
  private async findProcedure(
    airportId: string,
    procedureId: number,
  ): Promise<Procedure> {
    const cycleWhere = await this.cycleHelper.getCycleWhere(CycleDataGroup.DTPP);
    let id = airportId.toUpperCase();
    let procedure = await this.procedureRepo.findOne({
      where: { id: procedureId, airport_identifier: id, ...cycleWhere },
    });

    if (!procedure && id.length === 4 && id.startsWith('K')) {
      id = id.substring(1);
      procedure = await this.procedureRepo.findOne({
        where: { id: procedureId, airport_identifier: id, ...cycleWhere },
      });
    }

    if (!procedure) {
      throw new NotFoundException('Procedure not found');
    }

    return procedure;
  }

  /**
   * Get georef data for an IAP procedure. Parses from the PDF on first
   * access and caches the result in the database.
   */
  async getGeoref(
    airportId: string,
    procedureId: number,
  ): Promise<GeorefData | null> {
    const procedure = await this.findProcedure(airportId, procedureId);

    if (procedure.chart_code !== 'IAP') {
      return null;
    }

    // Return cached georef if available
    if (procedure.georef_data) {
      return procedure.georef_data as GeorefData;
    }

    // Download/locate the PDF
    const { filePath } = await this.getPdf(airportId, procedureId);
    const pdfBytes = fs.readFileSync(filePath);

    // Parse georef from PDF
    const georef = await parseGeoref(new Uint8Array(pdfBytes));

    // Cache result (even null → store as null so we don't re-parse)
    await this.procedureRepo.update(procedureId, {
      georef_data: georef as object | null,
    });

    return georef;
  }

  /**
   * Render a procedure PDF page to PNG. Caches the image on disk.
   * Uses pdftoppm (poppler-utils) for rendering.
   */
  async getProcedureImage(
    airportId: string,
    procedureId: number,
  ): Promise<{ filePath: string; fileName: string }> {
    const procedure = await this.findProcedure(airportId, procedureId);

    const imageDir = path.join(IMAGE_CACHE_DIR, procedure.cycle);
    const imageName = procedure.pdf_name.replace(/\.pdf$/i, '.png');
    const imagePath = path.join(imageDir, imageName);

    // Return cached image if it exists
    if (fs.existsSync(imagePath)) {
      return { filePath: imagePath, fileName: imageName };
    }

    // Ensure the PDF exists
    const { filePath: pdfPath } = await this.getPdf(airportId, procedureId);

    // Render PDF page 1 to PNG using pdftoppm
    fs.mkdirSync(imageDir, { recursive: true });
    const outputPrefix = imagePath.replace(/\.png$/, '');

    await new Promise<void>((resolve, reject) => {
      execFile(
        'pdftoppm',
        [
          '-png',
          '-r',
          '200', // 200 DPI
          '-f',
          '1', // first page
          '-l',
          '1', // last page (same = single page)
          '-singlefile',
          pdfPath,
          outputPrefix,
        ],
        (error) => {
          if (error) {
            reject(new Error(`pdftoppm failed: ${error.message}`));
          } else {
            resolve();
          }
        },
      );
    });

    if (!fs.existsSync(imagePath)) {
      throw new Error('Image rendering failed — output file not created');
    }

    return { filePath: imagePath, fileName: imageName };
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
