import { Injectable, Inject, Optional } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, SelectQueryBuilder, ObjectLiteral } from 'typeorm';
import { REQUEST } from '@nestjs/core';
import type { Request } from 'express';
import {
  DataCycle,
  CycleDataGroup,
  CycleStatus,
} from './entities/data-cycle.entity';

/**
 * Resolves the active cycle_id per data_group and applies WHERE cycle_id = ?
 * filters to query builders. Caches active cycle IDs in memory.
 *
 * Supports X-Cycle-Id header override for admin preview of staged data.
 */
@Injectable()
export class CycleQueryHelper {
  private activeCycleCache = new Map<CycleDataGroup, string | null>();

  constructor(
    @InjectRepository(DataCycle)
    private cycleRepo: Repository<DataCycle>,
    @Optional() @Inject(REQUEST) private request?: any,
  ) {}

  /**
   * Invalidate the cached active cycle for a group (call after activation/rollback).
   */
  invalidateCache(group?: CycleDataGroup) {
    if (group) {
      this.activeCycleCache.delete(group);
    } else {
      this.activeCycleCache.clear();
    }
  }

  /**
   * Get the active cycle_id for a data group.
   * Returns null if no active cycle exists (legacy/no-cycle mode).
   */
  async getActiveCycleId(group: CycleDataGroup): Promise<string | null> {
    // Check for admin override header
    const overrideId = this.request?.headers?.['x-cycle-id'] as
      | string
      | undefined;
    if (overrideId) {
      return overrideId;
    }

    if (this.activeCycleCache.has(group)) {
      return this.activeCycleCache.get(group)!;
    }

    const active = await this.cycleRepo.findOne({
      where: { data_group: group, status: CycleStatus.ACTIVE },
      select: ['id'],
    });

    const cycleId = active?.id ?? null;
    this.activeCycleCache.set(group, cycleId);
    return cycleId;
  }

  /**
   * Apply cycle filter to a query builder.
   * If no active cycle exists, no filter is applied (backward compatible).
   */
  async applyCycleFilter<T extends ObjectLiteral>(
    qb: SelectQueryBuilder<T>,
    alias: string,
    group: CycleDataGroup,
  ): Promise<SelectQueryBuilder<T>> {
    const cycleId = await this.getActiveCycleId(group);
    if (cycleId) {
      qb.andWhere(`${alias}.cycle_id = :cycleId`, { cycleId });
    }
    return qb;
  }

  /**
   * Get the active cycle_id as a where condition object for find() calls.
   * Returns empty object if no active cycle (backward compatible).
   */
  async getCycleWhere(
    group: CycleDataGroup,
  ): Promise<{ cycle_id?: string }> {
    const cycleId = await this.getActiveCycleId(group);
    return cycleId ? { cycle_id: cycleId } : {};
  }
}
