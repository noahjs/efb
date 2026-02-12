import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../models/briefing.dart';
import '../briefing_section.dart';

class RiskSummaryDetail extends StatelessWidget {
  final RiskSummary? riskSummary;
  final ValueChanged<BriefingSection>? onNavigateToSection;

  const RiskSummaryDetail({
    super.key,
    required this.riskSummary,
    this.onNavigateToSection,
  });

  @override
  Widget build(BuildContext context) {
    if (riskSummary == null) {
      return const Center(
        child: Text('No risk summary available',
            style: TextStyle(color: AppColors.textMuted)),
      );
    }

    final summary = riskSummary!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Risk Summary',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        // Overall level chip
        _OverallChip(level: summary.overallLevel),
        const SizedBox(height: 20),
        // Category bars
        ...summary.categories.map((cat) => _CategoryRow(
              category: cat,
              onTap: () => _navigateToCategory(cat.category),
            )),
        // Critical items
        if (summary.criticalItems.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Divider(color: AppColors.divider),
          const SizedBox(height: 12),
          ...summary.criticalItems.map((item) => _AlertRow(
                text: item,
                level: _inferLevelForItem(item, summary),
              )),
        ],
      ],
    );
  }

  String _inferLevelForItem(String item, RiskSummary summary) {
    for (final cat in summary.categories) {
      if (cat.level == 'red' && cat.alerts.contains(item)) return 'red';
    }
    return 'yellow';
  }

  void _navigateToCategory(String category) {
    if (onNavigateToSection == null) return;
    final section = _categoryToSection(category);
    if (section != null) onNavigateToSection!(section);
  }

  static BriefingSection? _categoryToSection(String category) {
    switch (category) {
      case 'weather':
        return BriefingSection.metars;
      case 'icing':
        return BriefingSection.airmetIcing;
      case 'turbulence':
        return BriefingSection.airmetTurbulence;
      case 'thunderstorms':
        return BriefingSection.convectiveSigmets;
      case 'tfrs':
        return BriefingSection.tfrs;
      case 'notams':
        return BriefingSection.notamsDeparture;
      default:
        return null;
    }
  }
}

class _OverallChip extends StatelessWidget {
  final String level;

  const _OverallChip({required this.level});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text(
          'Overall: ',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: _levelColor(level),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            level.toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final RiskCategory category;
  final VoidCallback? onTap;

  const _CategoryRow({required this.category, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(
              width: 110,
              child: Text(
                _categoryLabel(category.category),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ),
            Expanded(
              child: Container(
                height: 20,
                decoration: BoxDecoration(
                  color: _levelColor(category.level).withAlpha(80),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: 1.0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: _levelColor(category.level),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 56,
              child: Text(
                category.level.toUpperCase(),
                style: TextStyle(
                  color: _levelColor(category.level),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (category.level != 'green')
              Icon(
                Icons.warning_amber_rounded,
                size: 16,
                color: _levelColor(category.level),
              ),
          ],
        ),
      ),
    );
  }

  static String _categoryLabel(String category) {
    switch (category) {
      case 'weather':
        return 'Weather';
      case 'icing':
        return 'Icing';
      case 'turbulence':
        return 'Turbulence';
      case 'thunderstorms':
        return 'Thunderstorms';
      case 'tfrs':
        return 'TFRs';
      case 'notams':
        return 'NOTAMs';
      default:
        return category;
    }
  }
}

class _AlertRow extends StatelessWidget {
  final String text;
  final String level;

  const _AlertRow({required this.text, required this.level});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 16,
            color: _levelColor(level),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Color _levelColor(String level) {
  switch (level) {
    case 'red':
      return AppColors.error;
    case 'yellow':
      return AppColors.warning;
    case 'green':
      return AppColors.success;
    default:
      return AppColors.textMuted;
  }
}
