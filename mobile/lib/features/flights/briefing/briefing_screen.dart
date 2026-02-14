import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
  bool _regenerating = false;

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
    final request = BriefingRequest(
      widget.flightId,
      regenerate: _regenerating,
    );
    final briefingAsync = ref.watch(briefingProvider(request));
    final isWide = MediaQuery.of(context).size.width >= 600;

    return briefingAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: const Text('Briefing'),
        ),
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
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          title: const Text('Briefing'),
        ),
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
                  onPressed: () => ref.invalidate(
                      briefingProvider(request)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
      data: (briefing) {
        // Reset regenerating flag once fresh data arrives
        if (_regenerating) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) setState(() => _regenerating = false);
          });
        }
        // Auto-select risk summary on first load
        if (_selectedSection == null && briefing.riskSummary != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _selectSection(BriefingSection.riskSummary);
          });
        }
        if (isWide) {
          return _buildWideLayout(briefing);
        }
        return _buildNarrowLayout(briefing);
      },
    );
  }

  void _regenerate() {
    setState(() {
      _regenerating = true;
      _readSections.clear();
    });
    // Invalidate any cached provider state so it re-fetches
    ref.invalidate(briefingProvider(
        BriefingRequest(widget.flightId, regenerate: true)));
  }

  String _formatGeneratedAt(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final local = dt.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${local.month}/${local.day} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildWideLayout(Briefing briefing) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(
          '${briefing.flight.departureIdentifier} - ${briefing.flight.destinationIdentifier}  Briefing',
        ),
        centerTitle: true,
        actions: [
          if (briefing.generatedAt != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Text(
                  _formatGeneratedAt(briefing.generatedAt),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Regenerate briefing',
            onPressed: _regenerate,
          ),
        ],
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
              onNavigateToSection: _selectSection,
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
          onNavigateToSection: _selectSection,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(
          '${briefing.flight.departureIdentifier} - ${briefing.flight.destinationIdentifier}',
        ),
        centerTitle: true,
        actions: [
          if (briefing.generatedAt != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Text(
                  _formatGeneratedAt(briefing.generatedAt),
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Regenerate briefing',
            onPressed: _regenerate,
          ),
        ],
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
