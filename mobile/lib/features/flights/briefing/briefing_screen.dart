import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/briefing.dart';
import '../../../services/briefing_providers.dart';
import 'briefing_section.dart';
import 'widgets/briefing_sidebar.dart';
import 'widgets/briefing_detail_panel.dart';

class BriefingScreen extends ConsumerStatefulWidget {
  final int flightId;

  const BriefingScreen({super.key, required this.flightId});

  @override
  ConsumerState<BriefingScreen> createState() => _BriefingScreenState();
}

class _BriefingScreenState extends ConsumerState<BriefingScreen> {
  BriefingSection? _selectedSection;
  final Set<BriefingSection> _readSections = {};

  int _unreadCount(Briefing briefing) {
    int total = 0;
    for (final section in allBriefingSections) {
      if (section.getItemCount(briefing) > 0 &&
          !_readSections.contains(section)) {
        total++;
      }
    }
    return total;
  }

  void _selectSection(BriefingSection section) {
    setState(() {
      _selectedSection = section;
      _readSections.add(section);
    });
  }

  void _goToNextSection(Briefing briefing) {
    if (_selectedSection == null) return;
    final idx = allBriefingSections.indexOf(_selectedSection!);
    // Find next section with items
    for (int i = idx + 1; i < allBriefingSections.length; i++) {
      if (allBriefingSections[i].getItemCount(briefing) > 0) {
        _selectSection(allBriefingSections[i]);
        return;
      }
    }
    // Wrap to first
    for (int i = 0; i < idx; i++) {
      if (allBriefingSections[i].getItemCount(briefing) > 0) {
        _selectSection(allBriefingSections[i]);
        return;
      }
    }
  }

  void _goToPrevSection(Briefing briefing) {
    if (_selectedSection == null) return;
    final idx = allBriefingSections.indexOf(_selectedSection!);
    for (int i = idx - 1; i >= 0; i--) {
      if (allBriefingSections[i].getItemCount(briefing) > 0) {
        _selectSection(allBriefingSections[i]);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final briefingAsync = ref.watch(briefingProvider(widget.flightId));
    final isWide = MediaQuery.of(context).size.width >= 600;

    return briefingAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Briefing')),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Generating briefing...',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              SizedBox(height: 4),
              Text(
                'Fetching weather, NOTAMs, TFRs, and advisories',
                style: TextStyle(
                    color: AppColors.textMuted, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Briefing')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline,
                    color: AppColors.error, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Failed to generate briefing',
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () =>
                      ref.invalidate(briefingProvider(widget.flightId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (briefing) {
        if (isWide) {
          return _buildWideLayout(briefing);
        }
        return _buildNarrowLayout(briefing);
      },
    );
  }

  Widget _buildWideLayout(Briefing briefing) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${briefing.flight.departureIdentifier} - ${briefing.flight.destinationIdentifier}  Briefing',
        ),
        centerTitle: true,
      ),
      body: Row(
        children: [
          SizedBox(
            width: 280,
            child: BriefingSidebar(
              briefing: briefing,
              selectedSection: _selectedSection,
              readSections: _readSections,
              unreadCount: _unreadCount(briefing),
              onSectionSelected: _selectSection,
            ),
          ),
          const VerticalDivider(width: 1, color: AppColors.divider),
          Expanded(
            child: BriefingDetailPanel(
              briefing: briefing,
              selectedSection: _selectedSection,
              onNext: () => _goToNextSection(briefing),
              onPrev: () => _goToPrevSection(briefing),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNarrowLayout(Briefing briefing) {
    if (_selectedSection != null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => setState(() => _selectedSection = null),
          ),
          title: Text(_selectedSection!.label),
        ),
        body: BriefingDetailPanel(
          briefing: briefing,
          selectedSection: _selectedSection,
          onNext: () => _goToNextSection(briefing),
          onPrev: () => _goToPrevSection(briefing),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${briefing.flight.departureIdentifier} - ${briefing.flight.destinationIdentifier}',
        ),
        centerTitle: true,
      ),
      body: BriefingSidebar(
        briefing: briefing,
        selectedSection: _selectedSection,
        readSections: _readSections,
        unreadCount: _unreadCount(briefing),
        onSectionSelected: _selectSection,
      ),
    );
  }
}
