import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { IsNull, Repository } from 'typeorm';
import { CifpApproach } from './entities/cifp-approach.entity';
import { CifpIls } from './entities/cifp-ils.entity';
import { CifpMsa } from './entities/cifp-msa.entity';
import { CifpRunway } from './entities/cifp-runway.entity';

@Injectable()
export class CifpService {
  constructor(
    @InjectRepository(CifpApproach)
    private approachRepo: Repository<CifpApproach>,
    @InjectRepository(CifpIls)
    private ilsRepo: Repository<CifpIls>,
    @InjectRepository(CifpMsa)
    private msaRepo: Repository<CifpMsa>,
    @InjectRepository(CifpRunway)
    private runwayRepo: Repository<CifpRunway>,
  ) {}

  /**
   * Normalize airport identifier: accept both FAA (DEN) and ICAO (KDEN).
   */
  private normalizeId(id: string): { faa: string; icao: string } {
    const upper = id.toUpperCase().trim();
    if (upper.length === 4 && upper.startsWith('K')) {
      return { faa: upper.substring(1), icao: upper };
    }
    if (upper.length === 4 && (upper.startsWith('PH') || upper.startsWith('PA'))) {
      return { faa: upper, icao: upper };
    }
    return { faa: upper, icao: `K${upper}` };
  }

  /**
   * List all approaches for an airport.
   */
  async getApproaches(airportId: string) {
    const { faa, icao } = this.normalizeId(airportId);

    return this.approachRepo
      .createQueryBuilder('a')
      .select([
        'a.id',
        'a.airport_identifier',
        'a.icao_identifier',
        'a.procedure_identifier',
        'a.route_type',
        'a.transition_identifier',
        'a.procedure_name',
        'a.runway_identifier',
        'a.cycle',
      ])
      .loadRelationCountAndMap('a.leg_count', 'a.legs')
      .where(
        'a.airport_identifier = :faa OR a.icao_identifier = :icao',
        { faa, icao },
      )
      .orderBy('a.procedure_name', 'ASC')
      .addOrderBy('a.transition_identifier', 'ASC')
      .getMany();
  }

  /**
   * Get a single approach with all legs.
   */
  async getApproach(approachId: number) {
    return this.approachRepo.findOne({
      where: { id: approachId },
      relations: ['legs'],
      order: { legs: { sequence_number: 'ASC' } },
    });
  }

  /**
   * Get ILS/LOC data for an airport.
   */
  async getIls(airportId: string) {
    const { faa, icao } = this.normalizeId(airportId);
    return this.ilsRepo.find({
      where: [
        { airport_identifier: faa },
        { icao_identifier: icao },
      ],
    });
  }

  /**
   * Get MSA data for an airport.
   */
  async getMsa(airportId: string) {
    const { faa, icao } = this.normalizeId(airportId);
    return this.msaRepo.find({
      where: [
        { airport_identifier: faa },
        { icao_identifier: icao },
      ],
    });
  }

  /**
   * Get CIFP runway data for an airport.
   */
  async getRunways(airportId: string) {
    const { faa, icao } = this.normalizeId(airportId);
    return this.runwayRepo.find({
      where: [
        { airport_identifier: faa },
        { icao_identifier: icao },
      ],
    });
  }

  /**
   * Build merged legs for an approach. For ILS approaches (route_type 'I'),
   * merge in step-down fixes from the matching LOC approach on the same runway.
   */
  private async buildMergedLegs(approach: CifpApproach) {
    const mapLeg = (leg: any) => ({
      sequence_number: leg.sequence_number,
      fix_identifier: leg.fix_identifier,
      path_termination: leg.path_termination,
      turn_direction: leg.turn_direction,
      magnetic_course: leg.magnetic_course,
      route_distance_or_time: leg.route_distance_or_time,
      altitude_description: leg.altitude_description,
      altitude1: leg.altitude1,
      altitude2: leg.altitude2,
      vertical_angle: leg.vertical_angle,
      speed_limit: leg.speed_limit,
      recomm_navaid: leg.recomm_navaid,
      theta: leg.theta,
      rho: leg.rho,
      arc_radius: leg.arc_radius,
      center_fix: leg.center_fix,
      fix_latitude: leg.fix_latitude,
      fix_longitude: leg.fix_longitude,
      is_iaf: leg.is_iaf,
      is_if: leg.is_if,
      is_faf: leg.is_faf,
      is_map: leg.is_map,
      is_missed_approach: leg.is_missed_approach,
    });

    let legs = approach.legs.map(mapLeg);

    // For ILS approaches, merge LOC step-down fixes
    if (approach.route_type === 'I' && approach.runway_identifier) {
      const locWhere: any = {
        airport_identifier: approach.airport_identifier,
        route_type: 'L',
        runway_identifier: approach.runway_identifier,
      };
      if (approach.transition_identifier) {
        locWhere.transition_identifier = approach.transition_identifier;
      } else {
        locWhere.transition_identifier = IsNull();
      }
      const locApproach = await this.approachRepo.findOne({
        where: locWhere,
        relations: ['legs'],
        order: { legs: { sequence_number: 'ASC' } },
      });

      if (locApproach) {
        const ilsLegs = [...legs];
        const locLegs = locApproach.legs.map(mapLeg);

        // Find MAP index in both
        const ilsMapIdx = ilsLegs.findIndex((l) => l.is_map);
        const locMapIdx = locLegs.findIndex((l) => l.is_map);

        // Get approach-only legs (before MAP)
        const ilsBefore = ilsMapIdx >= 0 ? ilsLegs.slice(0, ilsMapIdx) : ilsLegs;
        const locBefore = locMapIdx >= 0 ? locLegs.slice(0, locMapIdx) : locLegs;
        const afterMap = ilsMapIdx >= 0 ? ilsLegs.slice(ilsMapIdx) : [];

        // Find LOC fixes not already in ILS
        const ilsFixIds = new Set(
          ilsBefore
            .filter((l) => l.fix_identifier)
            .map((l) => l.fix_identifier),
        );

        const newFixes = locBefore.filter(
          (l) =>
            l.fix_identifier &&
            !l.fix_identifier.startsWith('RW') &&
            !ilsFixIds.has(l.fix_identifier),
        );

        if (newFixes.length > 0) {
          // Merge: all ILS before + new LOC fixes, sorted by sequence
          const combined = [...ilsBefore, ...newFixes].sort(
            (a, b) => a.sequence_number - b.sequence_number,
          );

          // Update MAP leg's distance from LOC version
          if (afterMap.length > 0 && locMapIdx >= 0) {
            const locMapLeg = locLegs[locMapIdx];
            afterMap[0] = {
              ...afterMap[0],
              route_distance_or_time: locMapLeg.route_distance_or_time,
            };
          }

          legs = [...combined, ...afterMap];
        }
      }
    }

    return legs;
  }

  /**
   * Debug: get full raw data for an approach by ID — all columns, no filtering.
   */
  async getDebugData(approachId: number) {
    const approach = await this.approachRepo.findOne({
      where: { id: approachId },
      relations: ['legs'],
      order: { legs: { sequence_number: 'ASC' } },
    });
    if (!approach) return null;

    const { faa, icao } = this.normalizeId(approach.airport_identifier);

    const [ils, msa, runways, relatedApproaches] = await Promise.all([
      this.ilsRepo.find({ where: [{ airport_identifier: faa }, { icao_identifier: icao }] }),
      this.msaRepo.find({ where: [{ airport_identifier: faa }, { icao_identifier: icao }] }),
      this.runwayRepo.find({ where: [{ airport_identifier: faa }, { icao_identifier: icao }] }),
      this.approachRepo
        .createQueryBuilder('a')
        .select(['a.id', 'a.procedure_identifier', 'a.route_type', 'a.transition_identifier', 'a.procedure_name', 'a.runway_identifier'])
        .loadRelationCountAndMap('a.leg_count', 'a.legs')
        .where('a.airport_identifier = :faa OR a.icao_identifier = :icao', { faa, icao })
        .orderBy('a.procedure_name', 'ASC')
        .getMany(),
    ]);

    return {
      approach,
      all_ils: ils,
      all_msa: msa,
      all_runways: runways,
      all_approaches: relatedApproaches,
    };
  }

  /**
   * Get composite chart data for a specific approach.
   * Returns approach + legs + matching ILS + MSA + runway in one response.
   */
  async getChartData(approachId: number) {
    const approach = await this.getApproach(approachId);
    if (!approach) return null;

    const airportId = approach.airport_identifier;
    const runwayId = approach.runway_identifier;

    // Find matching ILS by runway
    const allIls = await this.ilsRepo.find({
      where: { airport_identifier: airportId },
    });
    const matchingIls = runwayId
      ? allIls.find((ils) => ils.runway_identifier === runwayId)
      : null;

    // Find matching MSA
    const allMsa = await this.msaRepo.find({
      where: { airport_identifier: airportId },
    });
    // Try to match MSA by runway, then fall back to first available
    const matchingMsa = allMsa.find((msa) => {
      const centerKey = `${runwayId}`;
      return msa.msa_center === centerKey;
    }) || allMsa[0] || null;

    // Find matching runway
    const matchingRunway = runwayId
      ? await this.runwayRepo.findOne({
          where: {
            airport_identifier: airportId,
            runway_identifier: runwayId,
          },
        })
      : null;

    return {
      approach: {
        id: approach.id,
        airport_identifier: approach.airport_identifier,
        icao_identifier: approach.icao_identifier,
        procedure_identifier: approach.procedure_identifier,
        route_type: approach.route_type,
        transition_identifier: approach.transition_identifier,
        procedure_name: approach.procedure_name,
        runway_identifier: approach.runway_identifier,
        cycle: approach.cycle,
      },
      legs: await this.buildMergedLegs(approach),
      ils: matchingIls
        ? {
            localizer_identifier: matchingIls.localizer_identifier,
            frequency: matchingIls.frequency,
            localizer_bearing: matchingIls.localizer_bearing,
            localizer_latitude: matchingIls.localizer_latitude,
            localizer_longitude: matchingIls.localizer_longitude,
            gs_latitude: matchingIls.gs_latitude,
            gs_longitude: matchingIls.gs_longitude,
            gs_angle: matchingIls.gs_angle,
            gs_elevation: matchingIls.gs_elevation,
            threshold_crossing_height: matchingIls.threshold_crossing_height,
          }
        : null,
      msa: matchingMsa
        ? {
            msa_center: matchingMsa.msa_center,
            sectors: matchingMsa.sectors,
          }
        : null,
      runway: matchingRunway
        ? {
            runway_identifier: matchingRunway.runway_identifier,
            runway_length: matchingRunway.runway_length,
            runway_bearing: matchingRunway.runway_bearing,
            threshold_latitude: matchingRunway.threshold_latitude,
            threshold_longitude: matchingRunway.threshold_longitude,
            threshold_elevation: matchingRunway.threshold_elevation,
            threshold_crossing_height: matchingRunway.threshold_crossing_height,
            runway_width: matchingRunway.runway_width,
          }
        : null,
    };
  }
}
