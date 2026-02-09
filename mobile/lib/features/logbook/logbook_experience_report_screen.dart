import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../services/logbook_providers.dart';

class _PeriodOption {
  final String label;
  final String value;
  const _PeriodOption(this.label, this.value);
}

const _periodOptions = [
  _PeriodOption('All Time', 'all'),
  _PeriodOption('Last 12 Months', '12mo'),
  _PeriodOption('Last 6 Months', '6mo'),
  _PeriodOption('Last 90 Days', '90d'),
  _PeriodOption('Last 30 Days', '30d'),
  _PeriodOption('Last 7 Days', '7d'),
];

class _ColumnDef {
  final String label;
  final String key;
  final bool isFloat;
  final double width;
  const _ColumnDef(this.label, this.key,
      {this.isFloat = true, this.width = 72});
}

const _columns = [
  _ColumnDef('Flights', 'flightCount', isFloat: false, width: 60),
  _ColumnDef('Total\nTime', 'totalTime', width: 62),
  _ColumnDef('Day\nLdgs', 'dayLandings', isFloat: false, width: 56),
  _ColumnDef('Night\nLdgs', 'nightLandings', isFloat: false, width: 56),
  _ColumnDef('All\nLdgs', 'allLandings', isFloat: false, width: 52),
  _ColumnDef('PIC', 'pic', width: 52),
  _ColumnDef('SIC', 'sic', width: 52),
  _ColumnDef('XC', 'crossCountry', width: 52),
  _ColumnDef('Actl\nInst', 'actualInstrument', width: 56),
  _ColumnDef('Sim\nInst', 'simulatedInstrument', width: 56),
  _ColumnDef('Night', 'night', width: 52),
  _ColumnDef('Solo', 'solo', width: 52),
  _ColumnDef('Dual\nGiven', 'dualGiven', width: 56),
  _ColumnDef('Dual\nRcvd', 'dualReceived', width: 56),
  _ColumnDef('Holds', 'holds', isFloat: false, width: 52),
  _ColumnDef('Day\nT/O', 'dayTakeoffs', isFloat: false, width: 52),
  _ColumnDef('Night\nT/O', 'nightTakeoffs', isFloat: false, width: 56),
];

// Document colors — light paper theme for printability
class _DocColors {
  static const Color paper = Color(0xFFFFFFFF);
  static const Color headerBg = Color(0xFF2C3E50);
  static const Color headerText = Color(0xFFFFFFFF);
  static const Color sectionBg = Color(0xFF34495E);
  static const Color sectionText = Color(0xFFFFFFFF);
  static const Color cellText = Color(0xFF2C3E50);
  static const Color cellTextMuted = Color(0xFF7F8C8D);
  static const Color totalsBg = Color(0xFFF0F3F5);
  static const Color totalsText = Color(0xFF2C3E50);
  static const Color border = Color(0xFFD5D8DC);
  static const Color altRow = Color(0xFFF8F9FA);
}

class LogbookExperienceReportScreen extends ConsumerStatefulWidget {
  const LogbookExperienceReportScreen({super.key});

  @override
  ConsumerState<LogbookExperienceReportScreen> createState() =>
      _LogbookExperienceReportScreenState();
}

class _LogbookExperienceReportScreenState
    extends ConsumerState<LogbookExperienceReportScreen> {
  String _period = 'all';

  @override
  Widget build(BuildContext context) {
    final reportAsync = ref.watch(logbookExperienceReportProvider(_period));

    return Scaffold(
      appBar: AppBar(
        title: DropdownButton<String>(
          value: _period,
          dropdownColor: AppColors.surface,
          underline: const SizedBox.shrink(),
          icon: const Icon(Icons.arrow_drop_down,
              color: AppColors.textSecondary, size: 20),
          items: _periodOptions
              .map((o) => DropdownMenuItem(
                    value: o.value,
                    child: Text(o.label,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        )),
                  ))
              .toList(),
          onChanged: (value) {
            if (value != null) setState(() => _period = value);
          },
        ),
        centerTitle: true,
      ),
      body: reportAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  color: AppColors.error, size: 48),
              const SizedBox(height: 16),
              Text('Failed to load report',
                  style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref
                    .invalidate(logbookExperienceReportProvider(_period)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (data) {
          final rows = (data['rows'] as List<dynamic>?) ?? [];
          final totals =
              (data['totals'] as Map<String, dynamic>?) ?? {};

          if (rows.isEmpty) {
            return const Center(
              child: Text('No logbook entries found',
                  style: TextStyle(color: AppColors.textSecondary)),
            );
          }

          return _buildReport(rows, totals);
        },
      ),
    );
  }

  Widget _buildReport(List<dynamic> rows, Map<String, dynamic> totals) {
    final periodLabel = _periodOptions
        .firstWhere((o) => o.value == _period)
        .label;
    final dateStr = DateFormat('MMMM d, yyyy').format(DateTime.now());

    return Container(
      color: const Color(0xFFE8EAED),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Container(
            decoration: BoxDecoration(
              color: _DocColors.paper,
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Document header
                _buildDocumentHeader(periodLabel, dateStr),
                const SizedBox(height: 20),
                // Summary boxes
                _buildSummaryBoxes(totals),
                const SizedBox(height: 20),
                // Experience table
                _buildExperienceTable(rows, totals),
                const SizedBox(height: 16),
                // Footer
                Text(
                  'Generated $dateStr',
                  style: const TextStyle(
                    fontSize: 10,
                    color: _DocColors.cellTextMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDocumentHeader(String periodLabel, String dateStr) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Flight Experience Report',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: _DocColors.cellText,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Period: $periodLabel',
          style: const TextStyle(
            fontSize: 13,
            color: _DocColors.cellTextMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryBoxes(Map<String, dynamic> totals) {
    num val(String key) => (totals[key] as num?) ?? 0;
    String fmtFloat(String key) => val(key).toStringAsFixed(1);
    String fmtInt(String key) => val(key).toInt().toString();

    final items = [
      ('Total Time', fmtFloat('totalTime')),
      ('Flights', fmtInt('flightCount')),
      ('PIC', fmtFloat('pic')),
      ('SIC', fmtFloat('sic')),
      ('Cross Country', fmtFloat('crossCountry')),
      ('Night', fmtFloat('night')),
      ('Solo', fmtFloat('solo')),
      ('Actual Instrument', fmtFloat('actualInstrument')),
      ('Sim Instrument', fmtFloat('simulatedInstrument')),
      ('Dual Given', fmtFloat('dualGiven')),
      ('Dual Received', fmtFloat('dualReceived')),
      ('Landings', fmtInt('allLandings')),
    ];

    const boxWidth = 130.0;
    const boxHeight = 64.0;
    const spacing = 8.0;

    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: items.map((item) {
        final (label, value) = item;
        return Container(
          width: boxWidth,
          height: boxHeight,
          decoration: BoxDecoration(
            border: Border.all(color: _DocColors.border, width: 0.5),
            borderRadius: BorderRadius.circular(4),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _DocColors.cellText,
                  fontFeatures: [FontFeature.tabularFigures()],
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: _DocColors.cellTextMuted,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildExperienceTable(
      List<dynamic> rows, Map<String, dynamic> totals) {
    const typeColWidth = 110.0;
    final totalWidth =
        typeColWidth + _columns.fold<double>(0, (s, c) => s + c.width);

    return SizedBox(
      width: totalWidth,
      child: Table(
        columnWidths: {
          0: const FixedColumnWidth(typeColWidth),
          for (int i = 0; i < _columns.length; i++)
            i + 1: FixedColumnWidth(_columns[i].width),
        },
        border: TableBorder.all(
          color: _DocColors.border,
          width: 0.5,
        ),
        children: [
          // Section header row
          TableRow(
            decoration: const BoxDecoration(color: _DocColors.sectionBg),
            children: [
              _sectionCell('EXPERIENCE'),
              ...List.generate(
                  _columns.length, (_) => const SizedBox(height: 28)),
            ],
          ),
          // Column header row
          TableRow(
            decoration: const BoxDecoration(color: _DocColors.headerBg),
            children: [
              _headerCell('Aircraft Type', align: TextAlign.left),
              ..._columns.map((c) => _headerCell(c.label)),
            ],
          ),
          // Data rows
          for (int i = 0; i < rows.length; i++)
            TableRow(
              decoration: BoxDecoration(
                color: i.isOdd ? _DocColors.altRow : _DocColors.paper,
              ),
              children: [
                _typeCell(
                    (rows[i] as Map<String, dynamic>)['aircraftType'] ??
                        'Unknown'),
                ..._columns.map((c) =>
                    _dataCell(rows[i] as Map<String, dynamic>, c)),
              ],
            ),
          // Totals row
          TableRow(
            decoration: const BoxDecoration(color: _DocColors.totalsBg),
            children: [
              _totalsTypeCell('Totals'),
              ..._columns.map((c) => _totalsCell(totals, c)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionCell(String text) {
    return TableCell(
      child: Container(
        height: 28,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
            color: _DocColors.sectionText,
          ),
        ),
      ),
    );
  }

  Widget _headerCell(String text, {TextAlign align = TextAlign.center}) {
    return TableCell(
      child: Container(
        height: 40,
        alignment: align == TextAlign.left
            ? Alignment.centerLeft
            : Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text(
          text,
          textAlign: align,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: _DocColors.headerText,
            height: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _typeCell(String text) {
    return TableCell(
      child: Container(
        height: 32,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          text,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: _DocColors.cellText,
          ),
        ),
      ),
    );
  }

  String _formatValue(Map<String, dynamic> data, _ColumnDef col) {
    final value = data[col.key];
    if (value == null) return col.isFloat ? '0.0' : '0';
    if (col.isFloat && value is num) return value.toStringAsFixed(1);
    return '$value';
  }

  Widget _dataCell(Map<String, dynamic> data, _ColumnDef col) {
    final text = _formatValue(data, col);
    final isZero = text == '0' || text == '0.0';
    return TableCell(
      child: Container(
        height: 32,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: isZero ? _DocColors.cellTextMuted : _DocColors.cellText,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }

  Widget _totalsTypeCell(String text) {
    return TableCell(
      child: Container(
        height: 34,
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _DocColors.totalsText,
          ),
        ),
      ),
    );
  }

  Widget _totalsCell(Map<String, dynamic> data, _ColumnDef col) {
    final text = _formatValue(data, col);
    return TableCell(
      child: Container(
        height: 34,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _DocColors.totalsText,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}
