import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../services/api_client.dart';

enum _ImportStep { source, file, preview, importing, result }

class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  _ImportStep _step = _ImportStep.source;
  String? _source;
  String? _fileName;
  Uint8List? _fileBytes;
  Map<String, dynamic>? _previewResult;
  Map<String, dynamic>? _importResult;
  String? _error;
  bool _loading = false;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      setState(() {
        _fileName = file.name;
        _fileBytes = file.bytes;
        _error = null;
      });

      if (_fileBytes != null) {
        await _runPreview();
      }
    }
  }

  Future<void> _runPreview() async {
    if (_fileBytes == null || _source == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final result = await api.importLogbook(
        fileBytes: _fileBytes!,
        fileName: _fileName ?? 'logbook.csv',
        source: _source!,
        preview: true,
      );

      setState(() {
        _previewResult = result;
        _step = _ImportStep.preview;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to preview: $e';
        _loading = false;
      });
    }
  }

  Future<void> _runImport() async {
    if (_fileBytes == null || _source == null) return;

    setState(() {
      _step = _ImportStep.importing;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      final result = await api.importLogbook(
        fileBytes: _fileBytes!,
        fileName: _fileName ?? 'logbook.csv',
        source: _source!,
        preview: false,
      );

      setState(() {
        _importResult = result;
        _step = _ImportStep.result;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to import: $e';
        _step = _ImportStep.preview;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/logbook'),
        ),
        title: const Text('Import Logbook'),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  color: AppColors.error, size: 48),
              const SizedBox(height: 16),
              Text(_error!,
                  style: const TextStyle(color: AppColors.error),
                  textAlign: TextAlign.center),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => setState(() => _error = null),
                child: const Text('Dismiss'),
              ),
            ],
          ),
        ),
      );
    }

    switch (_step) {
      case _ImportStep.source:
        return _buildSourceStep();
      case _ImportStep.file:
        return _buildFileStep();
      case _ImportStep.preview:
        return _buildPreviewStep();
      case _ImportStep.importing:
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Importing entries...',
                  style: TextStyle(color: AppColors.textSecondary)),
            ],
          ),
        );
      case _ImportStep.result:
        return _buildResultStep();
    }
  }

  Widget _buildSourceStep() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Source',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose the app you exported your logbook from.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          _buildSourceCard(
            'ForeFlight',
            'Export from ForeFlight: More > Logbook > Share > CSV',
            'foreflight',
            Icons.flight,
          ),
          const SizedBox(height: 12),
          _buildSourceCard(
            'Garmin Pilot',
            'Export from Garmin Pilot: Logbook > Menu > Export CSV',
            'garmin',
            Icons.gps_fixed,
          ),
        ],
      ),
    );
  }

  Widget _buildSourceCard(
    String title,
    String subtitle,
    String source,
    IconData icon,
  ) {
    return InkWell(
      onTap: () {
        setState(() {
          _source = source;
          _step = _ImportStep.file;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.accent, size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildFileStep() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Import from ${_source == 'foreflight' ? 'ForeFlight' : 'Garmin Pilot'}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select the CSV file exported from your logbook.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          Center(
            child: Column(
              children: [
                ElevatedButton.icon(
                  onPressed: _loading ? null : _pickFile,
                  icon: const Icon(Icons.upload_file),
                  label: Text(_fileName ?? 'Select CSV File'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                  ),
                ),
                if (_loading) ...[
                  const SizedBox(height: 16),
                  const CircularProgressIndicator(),
                  const SizedBox(height: 8),
                  const Text('Analyzing file...',
                      style: TextStyle(color: AppColors.textSecondary)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewStep() {
    if (_previewResult == null) return const SizedBox.shrink();

    final totalEntries = _previewResult!['totalEntries'] ?? 0;
    final totalTime = _previewResult!['totalTime'] ?? 0.0;
    final duplicates = (_previewResult!['duplicates'] as List?)?.length ?? 0;
    final warnings = (_previewResult!['warnings'] as List?)?.length ?? 0;
    final errors = (_previewResult!['errors'] as List?)?.length ?? 0;
    final entries = _previewResult!['entries'] as List? ?? [];
    final duplicateSet =
        Set<int>.from((_previewResult!['duplicates'] as List?) ?? []);
    final importCount = totalEntries - duplicates;

    // Get date range
    String dateRange = '';
    final dates = entries
        .map((e) => e['date'] as String?)
        .where((d) => d != null && d.isNotEmpty)
        .toList()
      ..sort();
    if (dates.isNotEmpty) {
      dateRange = '${dates.first} to ${dates.last}';
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Summary card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Preview',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  )),
              const SizedBox(height: 12),
              _buildStatRow('Total Entries', '$totalEntries'),
              _buildStatRow('Total Time', '${totalTime}h'),
              if (dateRange.isNotEmpty)
                _buildStatRow('Date Range', dateRange),
              _buildStatRow('Duplicates', '$duplicates',
                  color: duplicates > 0 ? Colors.orange : null),
              if (warnings > 0)
                _buildStatRow('Warnings', '$warnings',
                    color: Colors.orange),
              if (errors > 0)
                _buildStatRow('Errors', '$errors',
                    color: AppColors.error),
              const SizedBox(height: 8),
              _buildStatRow('Will Import', '$importCount',
                  color: Colors.green),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Entries list
        if (entries.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text('ENTRIES',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2,
                  color: AppColors.accent,
                )),
          ),
          ...entries.asMap().entries.map((mapEntry) {
            final i = mapEntry.key;
            final e = mapEntry.value;
            final isDuplicate = duplicateSet.contains(i);
            return _buildEntryPreviewRow(e, isDuplicate);
          }),
        ],

        const SizedBox(height: 24),

        // Import button
        if (importCount > 0)
          Center(
            child: ElevatedButton(
              onPressed: _runImport,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 14),
              ),
              child: Text('Import $importCount Entries',
                  style: const TextStyle(fontSize: 16)),
            ),
          )
        else
          const Center(
            child: Text('All entries are duplicates — nothing to import.',
                style: TextStyle(color: AppColors.textSecondary)),
          ),

        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildStatRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              )),
          Text(value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: color ?? AppColors.textPrimary,
              )),
        ],
      ),
    );
  }

  Widget _buildEntryPreviewRow(dynamic entry, bool isDuplicate) {
    final date = entry['date'] ?? '';
    final from = entry['from_airport'] ?? '';
    final to = entry['to_airport'] ?? '';
    final tail = entry['aircraft_identifier'] ?? '';
    final totalTime = entry['total_time'] ?? 0.0;

    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 0.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      child: Opacity(
        opacity: isDuplicate ? 0.4 : 1.0,
        child: Row(
          children: [
            if (isDuplicate)
              const Padding(
                padding: EdgeInsets.only(right: 6),
                child: Icon(Icons.copy, size: 14, color: Colors.orange),
              ),
            SizedBox(
              width: 80,
              child: Text(date,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ),
            Expanded(
              child: Text(
                from.isNotEmpty || to.isNotEmpty
                    ? '$from - $to'
                    : 'No Route',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            SizedBox(
              width: 50,
              child: Text(tail,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ),
            SizedBox(
              width: 40,
              child: Text('${totalTime is num ? totalTime.toStringAsFixed(1) : totalTime}',
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultStep() {
    if (_importResult == null) return const SizedBox.shrink();

    final importedCount = _importResult!['importedCount'] ?? 0;
    final totalTime = _importResult!['totalTime'] ?? 0.0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle,
                color: Colors.green, size: 64),
            const SizedBox(height: 16),
            Text(
              'Imported $importedCount Entries',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$totalTime total hours',
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => context.go('/logbook'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 14),
              ),
              child: const Text('Done', style: TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}
