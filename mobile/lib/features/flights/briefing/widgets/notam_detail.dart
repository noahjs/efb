import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../models/briefing.dart';

class NotamDetail extends StatelessWidget {
  final String title;
  final List<BriefingNotam>? notams;
  final CategorizedNotams? categorized;
  final List<CategorizedNotams>? artccNotams;

  const NotamDetail({
    super.key,
    required this.title,
    this.notams,
    this.categorized,
    this.artccNotams,
  });

  @override
  Widget build(BuildContext context) {
    // Determine which NOTAMs to show
    if (categorized != null) {
      return _buildCategorizedView(categorized!);
    }
    if (artccNotams != null) {
      return _buildArtccView();
    }
    final items = notams ?? [];
    if (items.isEmpty) {
      return Center(
        child: Text('No $title',
            style: const TextStyle(color: AppColors.textMuted)),
      );
    }
    return _buildFlatList(items);
  }

  Widget _buildFlatList(List<BriefingNotam> items) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        for (final notam in items) _NotamCard(notam: notam),
      ],
    );
  }

  Widget _buildCategorizedView(CategorizedNotams cat) {
    final allEmpty = cat.totalCount == 0;
    if (allEmpty) {
      return Center(
        child: Text('No $title',
            style: const TextStyle(color: AppColors.textMuted)),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        if (cat.navigation.isNotEmpty) ...[
          _CategoryHeader(label: 'NAVIGATION', count: cat.navigation.length),
          for (final n in cat.navigation) _NotamCard(notam: n),
        ],
        if (cat.communication.isNotEmpty) ...[
          _CategoryHeader(
              label: 'COMMUNICATION', count: cat.communication.length),
          for (final n in cat.communication) _NotamCard(notam: n),
        ],
        if (cat.svc.isNotEmpty) ...[
          _CategoryHeader(label: 'SERVICE', count: cat.svc.length),
          for (final n in cat.svc) _NotamCard(notam: n),
        ],
        if (cat.obstruction.isNotEmpty) ...[
          _CategoryHeader(
              label: 'OBSTRUCTION', count: cat.obstruction.length),
          for (final n in cat.obstruction) _NotamCard(notam: n),
        ],
      ],
    );
  }

  Widget _buildArtccView() {
    final items = artccNotams ?? [];
    final allEmpty = items.every((c) => c.totalCount == 0);
    if (allEmpty) {
      return Center(
        child: Text('No $title',
            style: const TextStyle(color: AppColors.textMuted)),
      );
    }

    final allNotams = <BriefingNotam>[];
    for (final cat in items) {
      allNotams.addAll(cat.navigation);
      allNotams.addAll(cat.communication);
      allNotams.addAll(cat.svc);
      allNotams.addAll(cat.obstruction);
    }

    return _buildFlatList(allNotams);
  }
}

class _CategoryHeader extends StatelessWidget {
  final String label;
  final int count;

  const _CategoryHeader({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotamCard extends StatelessWidget {
  final BriefingNotam notam;

  const _NotamCard({required this.notam});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                notam.icaoId,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 8),
              if (notam.id.isNotEmpty)
                Text(
                  notam.id,
                  style: const TextStyle(
                      color: AppColors.textMuted, fontSize: 11),
                ),
              const Spacer(),
              if (notam.type.isNotEmpty)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    notam.type,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 10),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            notam.text.isNotEmpty ? notam.text : notam.fullText,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
            maxLines: 6,
            overflow: TextOverflow.ellipsis,
          ),
          if (notam.effectiveStart != null || notam.effectiveEnd != null) ...[
            const SizedBox(height: 4),
            Text(
              [
                if (notam.effectiveStart != null)
                  'From: ${notam.effectiveStart}',
                if (notam.effectiveEnd != null) 'To: ${notam.effectiveEnd}',
              ].join('  '),
              style: const TextStyle(
                  color: AppColors.textMuted, fontSize: 10),
            ),
          ],
        ],
      ),
    );
  }
}
