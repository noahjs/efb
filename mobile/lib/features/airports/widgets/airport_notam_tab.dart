import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class AirportNotamTab extends StatelessWidget {
  final String airportId;
  const AirportNotamTab({super.key, required this.airportId});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _NotamCard(
          id: '2/4567',
          type: 'AIRSPACE',
          effective: '01 Feb 2026 - 28 Feb 2026',
          text:
              'TEMPORARY FLIGHT RESTRICTION. PURSUANT TO 14 CFR SECTION 91.141, AIRCRAFT OPERATIONS ARE PROHIBITED WITHIN A 3 NM RADIUS OF $airportId.',
        ),
        const SizedBox(height: 8),
        _NotamCard(
          id: '1/2345',
          type: 'RUNWAY',
          effective: '05 Feb 2026 - 15 Feb 2026',
          text:
              'RWY 03/21 CLSD FOR MAINT 0700-1500 LOCAL DAILY.',
        ),
        const SizedBox(height: 8),
        _NotamCard(
          id: '0/9876',
          type: 'LIGHTING',
          effective: '01 Jan 2026 - PERM',
          text:
              'PAPI RWY 30R U/S.',
        ),
        const SizedBox(height: 8),
        _NotamCard(
          id: '3/1111',
          type: 'OBSTRUCTION',
          effective: '01 Feb 2026 - 01 Mar 2026',
          text:
              'CRANE ERECTED 3975FT MSL (100FT AGL) 1.2NM NE OF ARPT.',
        ),
      ],
    );
  }
}

class _NotamCard extends StatelessWidget {
  final String id;
  final String type;
  final String effective;
  final String text;

  const _NotamCard({
    required this.id,
    required this.type,
    required this.effective,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.divider, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  type,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: AppColors.warning,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'NOTAM $id',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            effective,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
