import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Storage } from '@google-cloud/storage';
import * as path from 'path';
import { LIVEATC_ATIS } from '../config/constants';
import { LIVEATC_MOUNTS } from './liveatc-mounts';
import { AtisRecording } from './entities/atis-recording.entity';

@Injectable()
export class AtisTranscriptionService {
  private readonly logger = new Logger(AtisTranscriptionService.name);

  // Cache: icao -> { data, expiresAt }
  private cache = new Map<string, { data: any; expiresAt: number }>();

  // Dedup concurrent requests for the same ICAO
  private inProgress = new Map<string, Promise<any>>();

  // GCS for ATIS audio storage
  private readonly gcsStorage: Storage | null;
  private readonly gcsBucket: string;

  constructor(
    @InjectRepository(AtisRecording)
    private readonly atisRecordingRepo: Repository<AtisRecording>,
  ) {
    this.gcsBucket = process.env.GCS_ATIS_BUCKET || 'efb-atis-dev';
    const keyFilePath =
      process.env.GCS_KEY_FILE ||
      path.resolve(process.cwd(), '..', 'gcs-key.json');

    try {
      this.gcsStorage = new Storage({ keyFilename: keyFilePath });
    } catch {
      this.logger.warn('GCS storage not available for ATIS audio');
      this.gcsStorage = null;
    }
  }

  /**
   * Public entry point. Returns D-ATIS-shaped array or null.
   * Format: [{ datis: "...", type: "combined" }]
   */
  async getTranscribedAtis(icao: string): Promise<any[] | null> {
    const cached = this.getFromCache(icao);
    if (cached !== undefined) return cached;

    const mount = LIVEATC_MOUNTS.get(icao.toUpperCase());
    if (!mount) return null;

    // Dedup: if already fetching for this ICAO, await the same promise
    const existing = this.inProgress.get(icao);
    if (existing) return existing;

    const promise = this.fetchAndTranscribe(icao, mount.mount, mount.dedicated);
    this.inProgress.set(icao, promise);

    try {
      return await promise;
    } finally {
      this.inProgress.delete(icao);
    }
  }

  private async fetchAndTranscribe(
    icao: string,
    mount: string,
    dedicated: boolean,
  ): Promise<any[] | null> {
    try {
      this.logger.log(`Capturing LiveATC stream for ${icao} (mount: ${mount})`);
      const audio = await this.captureStream(mount);

      this.logger.log(`Transcribing ${audio.byteLength} bytes for ${icao}...`);
      const raw = await this.transcribeAudio(audio, icao);

      if (!raw || raw.trim().length === 0) {
        this.logger.warn(`Empty transcription for ${icao}`);
        this.setCache(icao, null, LIVEATC_ATIS.CACHE_TTL_FAILURE_MS);
        return null;
      }

      this.logger.debug(`Raw transcription for ${icao}: ${raw}`);
      const extracted = this.extractAtisFromTranscription(raw, icao, dedicated);

      if (!extracted) {
        this.logger.warn(
          `Could not extract ATIS loop from transcription for ${icao}`,
        );
        this.setCache(icao, null, LIVEATC_ATIS.CACHE_TTL_FAILURE_MS);
        return null;
      }

      const result = [
        {
          datis: extracted,
          type: 'combined',
          source: 'liveatc',
          audioUrl: `/api/weather/atis/${icao}/audio`,
        },
      ];
      this.setCache(icao, result, LIVEATC_ATIS.CACHE_TTL_MS);

      // Upload audio to GCS and save recording (fire-and-forget)
      this.uploadAndSaveRecording(icao, audio).catch((err) =>
        this.logger.error(
          `Failed to save ATIS audio for ${icao}: ${err.message}`,
        ),
      );

      return result;
    } catch (error: unknown) {
      const msg = error instanceof Error ? error.message : String(error);
      this.logger.error(`ATIS transcription failed for ${icao}: ${msg}`);
      this.setCache(icao, null, LIVEATC_ATIS.CACHE_TTL_FAILURE_MS);
      return null;
    }
  }

  /**
   * Capture MP3 audio from a LiveATC Icecast stream.
   * Reads for RECORD_DURATION_MS or until MAX_AUDIO_BYTES, whichever comes first.
   */
  private async captureStream(mount: string): Promise<Buffer> {
    const url = `${LIVEATC_ATIS.BASE_URL}/${mount}`;
    const controller = new AbortController();
    const chunks: Uint8Array[] = [];
    let totalBytes = 0;
    let connected = false;

    // Abort after record duration
    const timeout = setTimeout(
      () => controller.abort(),
      LIVEATC_ATIS.RECORD_DURATION_MS,
    );

    // Connection timeout — abort if no response within CONNECTION_TIMEOUT_MS
    const connTimeout = setTimeout(() => {
      if (!connected) controller.abort();
    }, LIVEATC_ATIS.CONNECTION_TIMEOUT_MS);

    try {
      const response = await fetch(url, {
        signal: controller.signal,
        headers: {
          'User-Agent': 'EFB/1.0 (Flight Planning App)',
          Accept: '*/*',
        },
      });

      connected = true;
      clearTimeout(connTimeout);

      if (!response.ok) {
        throw new Error(
          `LiveATC returned ${response.status} for mount ${mount}`,
        );
      }

      if (!response.body) {
        throw new Error(`No response body from LiveATC for mount ${mount}`);
      }

      const reader = response.body.getReader();

      while (true) {
        const { done, value } = await reader.read();
        if (done) break;

        chunks.push(value);
        totalBytes += value.byteLength;

        if (totalBytes >= LIVEATC_ATIS.MAX_AUDIO_BYTES) {
          controller.abort();
          break;
        }
      }

      return Buffer.concat(chunks);
    } catch (error) {
      // AbortError is expected when the recording timer fires
      if (
        error instanceof Error &&
        error.name === 'AbortError' &&
        totalBytes > 0
      ) {
        return Buffer.concat(chunks);
      }
      throw error;
    } finally {
      clearTimeout(timeout);
      clearTimeout(connTimeout);
    }
  }

  /**
   * Transcribe audio buffer via OpenAI Whisper API.
   * Uses native fetch + manual multipart form to avoid extra dependencies.
   */
  private async transcribeAudio(
    audio: Buffer,
    icao: string,
  ): Promise<string | null> {
    const apiKey = process.env.OPENAI_API_KEY;
    if (!apiKey) {
      this.logger.warn('OPENAI_API_KEY not set — cannot transcribe ATIS');
      return null;
    }

    const boundary = `----EFBBoundary${Date.now()}`;
    const prompt = [
      `Aviation ATIS broadcast for ${icao}.`,
      'Terms: RNAV, ILS, LOC, VOR, NDB, GPS, NOTAM, PIREP, SIGMET, AIRMET,',
      'altimeter, ceiling, visibility, wind, runway, taxiway, FBO,',
      'alpha, bravo, charlie, delta, echo, foxtrot, golf, hotel, india,',
      'juliet, kilo, lima, mike, november, oscar, papa, quebec, romeo,',
      'sierra, tango, uniform, victor, whiskey, x-ray, yankee, zulu.',
      'Information alpha through zulu.',
      'Advise on initial contact you have information.',
    ].join(' ');

    // Build multipart body manually
    const parts: Buffer[] = [];

    // file field
    parts.push(
      Buffer.from(
        `--${boundary}\r\nContent-Disposition: form-data; name="file"; filename="atis.mp3"\r\nContent-Type: audio/mpeg\r\n\r\n`,
      ),
    );
    parts.push(audio);
    parts.push(Buffer.from('\r\n'));

    // model field
    parts.push(
      Buffer.from(
        `--${boundary}\r\nContent-Disposition: form-data; name="model"\r\n\r\n${LIVEATC_ATIS.WHISPER_MODEL}\r\n`,
      ),
    );

    // prompt field
    parts.push(
      Buffer.from(
        `--${boundary}\r\nContent-Disposition: form-data; name="prompt"\r\n\r\n${prompt}\r\n`,
      ),
    );

    // language field
    parts.push(
      Buffer.from(
        `--${boundary}\r\nContent-Disposition: form-data; name="language"\r\n\r\nen\r\n`,
      ),
    );

    // closing boundary
    parts.push(Buffer.from(`--${boundary}--\r\n`));

    const body = Buffer.concat(parts);

    const controller = new AbortController();
    const timeout = setTimeout(
      () => controller.abort(),
      LIVEATC_ATIS.WHISPER_TIMEOUT_MS,
    );

    try {
      const response = await fetch(
        'https://api.openai.com/v1/audio/transcriptions',
        {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${apiKey}`,
            'Content-Type': `multipart/form-data; boundary=${boundary}`,
          },
          body,
          signal: controller.signal,
        },
      );

      if (!response.ok) {
        const errorBody = await response.text();
        throw new Error(
          `Whisper API returned ${response.status}: ${errorBody}`,
        );
      }

      const data = (await response.json()) as { text?: string };
      return data.text ?? null;
    } finally {
      clearTimeout(timeout);
    }
  }

  /**
   * Extract one complete ATIS loop from the raw transcription.
   *
   * For dedicated ATIS feeds: the entire transcript is typically one or two loops.
   * For mixed feeds: we look for "INFORMATION [letter]" markers and extract between them.
   */
  extractAtisFromTranscription(
    raw: string,
    icao: string,
    dedicated: boolean,
  ): string | null {
    if (!raw || raw.trim().length === 0) return null;

    const text = raw.trim();

    if (dedicated) {
      return this.extractFromDedicatedFeed(text);
    }

    return this.extractFromMixedFeed(text);
  }

  private extractFromDedicatedFeed(text: string): string | null {
    // For dedicated feeds, try to find a complete ATIS loop
    // Pattern: "INFORMATION [letter]" ... "ADVISE ON INITIAL CONTACT YOU HAVE INFORMATION [letter]"
    const infoPattern =
      /INFORMATION\s+([A-Z](?:LPHA|RAVO|HARLIE|ELTA|CHO|OXTROT|OLF|OTEL|NDIA|ULIET|ILO|IMA|IKE|OVEMBER|SCAR|APA|UEBEC|OMEO|IERRA|ANGO|NIFORM|ICTOR|HISKEY|.?RAY|ANKEE|ULU)?)\b/gi;

    const matches = [...text.matchAll(infoPattern)];

    if (matches.length >= 2) {
      // Extract from first "INFORMATION X" to the next "INFORMATION X" or end marker
      const firstMatch = matches[0];
      const secondMatch = matches[1];

      // Check if first and second match have the same letter — that's the loop boundary
      const firstLetter = this.normalizePhoneticLetter(firstMatch[1]);
      const secondLetter = this.normalizePhoneticLetter(secondMatch[1]);

      if (firstLetter === secondLetter) {
        // Same letter = second occurrence is the start of the repeat
        return text.substring(firstMatch.index, secondMatch.index).trim();
      }

      // Different letters — could be old ATIS rolling into new. Take the second one
      // (it's the most current)
      if (matches.length >= 3) {
        const thirdLetter = this.normalizePhoneticLetter(matches[2][1]);
        if (secondLetter === thirdLetter) {
          return text.substring(secondMatch.index, matches[2].index).trim();
        }
      }
    }

    // Fallback: check for "ADVISE" ending marker
    const advisePattern =
      /ADVISE\s+(?:ON\s+INITIAL\s+CONTACT\s+)?YOU\s+HAVE\s+(?:INFORMATION\s+)?([A-Z])/i;
    const adviseMatch = text.match(advisePattern);

    if (adviseMatch && matches.length >= 1) {
      // Take from first INFORMATION to end of ADVISE sentence
      const endIdx = adviseMatch.index! + adviseMatch[0].length;
      return text.substring(matches[0].index, endIdx).trim();
    }

    // Last resort for dedicated feed: return the whole transcription
    // (it's likely just one ATIS loop with maybe partial repeats)
    if (text.length > 50) {
      return text;
    }

    return null;
  }

  private extractFromMixedFeed(text: string): string | null {
    // For mixed feeds (tower/ground + ATIS), look for ATIS markers
    const infoPattern =
      /INFORMATION\s+([A-Z](?:LPHA|RAVO|HARLIE|ELTA|CHO|OXTROT|OLF|OTEL|NDIA|ULIET|ILO|IMA|IKE|OVEMBER|SCAR|APA|UEBEC|OMEO|IERRA|ANGO|NIFORM|ICTOR|HISKEY|.?RAY|ANKEE|ULU)?)\b/gi;

    const matches = [...text.matchAll(infoPattern)];

    if (matches.length < 2) {
      // Can't reliably extract ATIS from mixed feed without clear markers
      return null;
    }

    // Find two matches with the same letter — that's our loop
    for (let i = 0; i < matches.length - 1; i++) {
      const letterA = this.normalizePhoneticLetter(matches[i][1]);

      for (let j = i + 1; j < matches.length; j++) {
        const letterB = this.normalizePhoneticLetter(matches[j][1]);

        if (letterA === letterB) {
          return text.substring(matches[i].index, matches[j].index).trim();
        }
      }
    }

    // No duplicate letters found — take the last INFORMATION block to end
    const lastMatch = matches[matches.length - 1];
    const advisePattern =
      /ADVISE\s+(?:ON\s+INITIAL\s+CONTACT\s+)?YOU\s+HAVE\s+(?:INFORMATION\s+)?([A-Z])/i;
    const remaining = text.substring(lastMatch.index);
    const adviseMatch = remaining.match(advisePattern);

    if (adviseMatch) {
      return remaining
        .substring(0, adviseMatch.index! + adviseMatch[0].length)
        .trim();
    }

    return null;
  }

  /**
   * Normalize a phonetic letter word (e.g., "ALPHA", "BRAVO") to its single letter.
   */
  private normalizePhoneticLetter(word: string): string {
    const w = word.toUpperCase().trim();
    const phonetics: Record<string, string> = {
      ALPHA: 'A',
      BRAVO: 'B',
      CHARLIE: 'C',
      DELTA: 'D',
      ECHO: 'E',
      FOXTROT: 'F',
      GOLF: 'G',
      HOTEL: 'H',
      INDIA: 'I',
      JULIET: 'J',
      KILO: 'K',
      LIMA: 'L',
      MIKE: 'M',
      NOVEMBER: 'N',
      OSCAR: 'O',
      PAPA: 'P',
      QUEBEC: 'Q',
      ROMEO: 'R',
      SIERRA: 'S',
      TANGO: 'T',
      UNIFORM: 'U',
      VICTOR: 'V',
      WHISKEY: 'W',
      XRAY: 'X',
      'X-RAY': 'X',
      YANKEE: 'Y',
      ZULU: 'Z',
    };

    return phonetics[w] ?? w.charAt(0);
  }

  private async uploadAndSaveRecording(
    icao: string,
    audio: Buffer,
  ): Promise<void> {
    if (!this.gcsStorage) return;

    const timestamp = Date.now();
    const gcsKey = `${icao}/${timestamp}.mp3`;

    const file = this.gcsStorage.bucket(this.gcsBucket).file(gcsKey);
    await file.save(audio, {
      contentType: 'audio/mpeg',
      resumable: false,
    });
    this.logger.log(`Uploaded ${gcsKey} (${audio.length} bytes)`);

    // Upsert: update existing row for this ICAO or insert new one
    const existing = await this.atisRecordingRepo.findOne({
      where: { icao },
    });

    if (existing) {
      existing.gcs_key = gcsKey;
      existing.recorded_at = new Date(timestamp);
      existing.size_bytes = audio.length;
      await this.atisRecordingRepo.save(existing);
    } else {
      await this.atisRecordingRepo.save(
        this.atisRecordingRepo.create({
          icao,
          gcs_key: gcsKey,
          recorded_at: new Date(timestamp),
          size_bytes: audio.length,
        }),
      );
    }
  }

  private getFromCache(icao: string): any {
    const entry = this.cache.get(icao);
    if (entry && entry.expiresAt > Date.now()) {
      return entry.data;
    }
    if (entry) {
      this.cache.delete(icao);
    }
    return undefined;
  }

  private setCache(icao: string, data: any, ttlMs: number): void {
    this.cache.set(icao, {
      data,
      expiresAt: Date.now() + ttlMs,
    });
  }
}
