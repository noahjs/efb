import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../models/briefing.dart';
import '../briefing_section.dart';

class BriefingSidebar extends StatelessWidget {
  final Briefing briefing;
  final BriefingSection? selectedSection;
  final Set<BriefingSection> readSections;
  final int unreadCount;
  final ValueChanged<BriefingSection> onSectionSelected;

  const BriefingSidebar({
    super.key,
    required this.briefing,
    required this.selectedSection,
    required this.readSections,
    required this.unreadCount,
    required this.onSectionSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SummaryHeader(briefing: briefing, unreadCount: unreadCount),
        const Divider(height: 1, color: AppColors.divider),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: _buildSectionList(),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildSectionList() {
    final widgets = <Widget>[];
    String? lastGroup;

    for (final section in allBriefingSections) {
      final group = section.groupLabel;
      if (group != lastGroup) {
        lastGroup = group;
        widgets.add(Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            group,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ));
      }

      final count = section.getItemCount(briefing);
      final isSelected = section == selectedSection;
      final isRead = readSections.contains(section);
      final isEmpty = count == 0;

      widgets.add(_SectionRow(
        section: section,
        count: count,
        isSelected: isSelected,
        isRead: isRead,
        isEmpty: isEmpty,
        onTap: () => onSectionSelected(section),
      ));
    }

    return widgets;
  }
}

class _SummaryHeader extends StatelessWidget {
  final Briefing briefing;
  final int unreadCount;

  const _SummaryHeader({required this.briefing, required this.unreadCount});

  @override
  Widget build(BuildContext context) {
    final flight = briefing.flight;
    final altStr = flight.cruiseAltitude != null
        ? "${flight.cruiseAltitude!.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}' MSL"
        : '';
    final acStr = flight.aircraftIdentifier ?? '';

    String eteStr = '';
    if (flight.eteMinutes != null) {
      final h = flight.eteMinutes! ~/ 60;
      final m = flight.eteMinutes! % 60;
      eteStr = '${h}h${m}m';
    }

    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'STANDARD BRIEFING',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              const Spacer(),
              if (unreadCount > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$unreadCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${flight.departureIdentifier} to ${flight.destinationIdentifier}',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          if (altStr.isNotEmpty || acStr.isNotEmpty)
            Text(
              [altStr, if (acStr.isNotEmpty) 'in $acStr']
                  .where((s) => s.isNotEmpty)
                  .join(' '),
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13),
            ),
          if (eteStr.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'ETE $eteStr${flight.eta != null ? ', ETA ${flight.eta}' : ''}',
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionRow extends StatelessWidget {
  final BriefingSection section;
  final int count;
  final bool isSelected;
  final bool isRead;
  final bool isEmpty;
  final VoidCallback onTap;

  const _SectionRow({
    required this.section,
    required this.count,
    required this.isSelected,
    required this.isRead,
    required this.isEmpty,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isEmpty
        ? AppColors.textMuted
        : isSelected
            ? AppColors.textPrimary
            : AppColors.textSecondary;

    return Material(
      color: isSelected
          ? AppColors.primary.withAlpha(40)
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(section.icon, size: 16, color: textColor),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  section.label,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 13,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
              if (!isRead && !isEmpty && count > 0)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: const BoxDecoration(
                    color: Colors.orange,
                    shape: BoxShape.circle,
                  ),
                ),
              if (count > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: isEmpty ? AppColors.textMuted : AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
