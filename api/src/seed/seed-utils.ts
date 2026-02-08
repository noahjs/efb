/**
 * Shared utility functions for seed scripts.
 */

import * as fs from 'fs';
import * as https from 'https';
import * as http from 'http';
import * as path from 'path';
import { createReadStream } from 'fs';
import { parse } from 'csv-parse';
import { execSync } from 'child_process';

export function downloadFile(url: string, dest: string): Promise<void> {
  return new Promise((resolve, reject) => {
    const file = fs.createWriteStream(dest);
    const protocol = url.startsWith('https') ? https : http;

    (protocol as typeof https)
      .get(url, (response) => {
        // Handle redirects
        if (
          response.statusCode &&
          response.statusCode >= 300 &&
          response.statusCode < 400 &&
          response.headers.location
        ) {
          file.close();
          fs.unlinkSync(dest);
          return downloadFile(response.headers.location, dest).then(
            resolve,
            reject,
          );
        }

        // Handle HTTP errors
        if (response.statusCode && response.statusCode >= 400) {
          file.close();
          fs.unlinkSync(dest);
          reject(
            new Error(
              `HTTP ${response.statusCode} downloading ${url}`,
            ),
          );
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

export function parsePipeDelimited(
  filePath: string,
): Promise<Record<string, string>[]> {
  return new Promise((resolve, reject) => {
    const records: Record<string, string>[] = [];

    createReadStream(filePath)
      .pipe(
        parse({
          delimiter: ',',
          columns: true,
          skip_empty_lines: true,
          trim: true,
          relax_column_count: true,
        }),
      )
      .on('data', (record: Record<string, string>) => records.push(record))
      .on('end', () => resolve(records))
      .on('error', reject);
  });
}

export function parseCoordinate(dms: string): number | null {
  if (!dms) return null;

  // Handle decimal format
  const decimal = parseFloat(dms);
  if (!isNaN(decimal) && Math.abs(decimal) <= 180) return decimal;

  // Handle DMS format: e.g. "39-54-32.6800N" or "104-50-56.1100W"
  const match = dms.match(/(\d+)-(\d+)-([\d.]+)([NSEW])/);
  if (!match) return null;

  const deg = parseInt(match[1]);
  const min = parseInt(match[2]);
  const sec = parseFloat(match[3]);
  const dir = match[4];

  let result = deg + min / 60 + sec / 3600;
  if (dir === 'S' || dir === 'W') result = -result;
  return result;
}

export function findFile(dir: string, ...names: string[]): string | null {
  if (!fs.existsSync(dir)) return null;

  for (const name of names) {
    const filePath = `${dir}/${name}`;
    if (fs.existsSync(filePath)) return filePath;
  }

  // Search subdirectories
  try {
    const entries = fs.readdirSync(dir, { withFileTypes: true });
    for (const entry of entries) {
      if (entry.isDirectory()) {
        const result = findFile(`${dir}/${entry.name}`, ...names);
        if (result) return result;
      }
    }
  } catch {
    // ignore
  }

  return null;
}

// NASR download URL - 28-day subscription
const NASR_CSV_URL =
  'https://nfdc.faa.gov/webContent/28DaySub/28DaySubscription_Effective_2026-01-22.zip';

/**
 * Downloads and extracts the FAA NASR 28-day subscription data if CSV files
 * are not already present. The NASR ZIP contains a nested CSV ZIP that also
 * needs extraction.
 */
export async function ensureNasrData(nasrDir: string): Promise<void> {
  // Check if CSVs are already extracted
  if (findFile(nasrDir, 'APT_BASE.csv')) {
    console.log('NASR CSV data already present, skipping download.\n');
    return;
  }

  fs.mkdirSync(nasrDir, { recursive: true });

  const zipPath = path.join(nasrDir, 'nasr.zip');

  // Download the outer ZIP
  console.log('Downloading FAA NASR 28-day subscription...');
  console.log(`  URL: ${NASR_CSV_URL}`);
  await downloadFile(NASR_CSV_URL, zipPath);
  const zipSize = fs.statSync(zipPath).size;
  console.log(`  Downloaded: ${(zipSize / 1024 / 1024).toFixed(1)} MB`);

  // Extract outer ZIP
  console.log('Extracting NASR archive...');
  execSync(`unzip -o "${zipPath}" -d "${nasrDir}"`, { stdio: 'pipe' });

  // Extract nested CSV ZIP (e.g. CSV_Data/22_Jan_2026_CSV.zip)
  const csvDataDir = path.join(nasrDir, 'CSV_Data');
  if (fs.existsSync(csvDataDir)) {
    const nestedZips = fs.readdirSync(csvDataDir).filter(f => f.endsWith('.zip'));
    for (const z of nestedZips) {
      const nestedPath = path.join(csvDataDir, z);
      console.log(`Extracting ${z}...`);
      execSync(`unzip -o "${nestedPath}" -d "${csvDataDir}"`, { stdio: 'pipe' });
    }
  }

  console.log('NASR data ready.\n');
}
