import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/router/navigation_helpers.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../models/certificate.dart';
import '../../services/certificates_providers.dart';
import '../flights/widgets/flight_section_header.dart';
import '../flights/widgets/flight_field_row.dart';
import '../flights/widgets/flight_edit_dialogs.dart';

class CertificateDetailScreen extends ConsumerStatefulWidget {
  final int? certificateId;

  const CertificateDetailScreen({super.key, required this.certificateId});

  @override
  ConsumerState<CertificateDetailScreen> createState() =>
      _CertificateDetailScreenState();
}

class _CertificateDetailScreenState
    extends ConsumerState<CertificateDetailScreen> {
  Certificate _certificate = const Certificate();
  bool _loaded = false;
  bool _saving = false;

  bool get _isNew =>
      widget.certificateId == null && _certificate.id == null;

  static const _typeOptions = [
    'pilot',
    'medical',
    'type_rating',
    'instructor',
  ];

  static const _pilotClassOptions = [
    'student',
    'sport',
    'recreational',
    'private',
    'commercial',
    'atp',
  ];

  static const _medicalClassOptions = [
    'first_class',
    'second_class',
    'third_class',
    'basicmed',
  ];

  static const _instructorClassOptions = [
    'cfi',
    'cfii',
    'mei',
  ];

  List<String> get _classOptions {
    switch (_certificate.certificateType) {
      case 'pilot':
        return _pilotClassOptions;
      case 'medical':
        return _medicalClassOptions;
      case 'instructor':
        return _instructorClassOptions;
      default:
        return [..._pilotClassOptions, ..._medicalClassOptions, ..._instructorClassOptions];
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.certificateId == null) {
      _loaded = true;
    }
  }

  void _goBackToList() {
    ref.invalidate(certificatesListProvider(''));
    context.goBack('/credentials');
  }

  Future<void> _saveField(Certificate updated) async {
    setState(() {
      _certificate = updated;
      _saving = true;
    });

    try {
      final service = ref.read(certificatesServiceProvider);
      if (_isNew) {
        final created =
            await service.createCertificate(updated.toJson());
        setState(() => _certificate = created);
      } else {
        final saved = await service.updateCertificate(
            _certificate.id!, updated.toJson());
        setState(() => _certificate = saved);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteCertificate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Certificate',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
            'Are you sure you want to delete this certificate?',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true && _certificate.id != null) {
      try {
        final service = ref.read(certificatesServiceProvider);
        await service.deleteCertificate(_certificate.id!);
        if (mounted) _goBackToList();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.certificateId != null && !_loaded) {
      final certAsync =
          ref.watch(certificateDetailProvider(widget.certificateId!));
      return certAsync.when(
        loading: () => Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => _goBackToList(),
            ),
            title: const Text('Loading...'),
          ),
          body: const Center(child: CircularProgressIndicator()),
        ),
        error: (error, _) => Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => _goBackToList(),
            ),
            title: const Text('Error'),
          ),
          body: Center(child: Text('Failed to load certificate: $error')),
        ),
        data: (certificate) {
          if (certificate != null && !_loaded) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() {
                _certificate = certificate;
                _loaded = true;
              });
            });
          }
          return _buildScaffold();
        },
      );
    }

    return _buildScaffold();
  }

  Widget _buildScaffold() {
    final title =
        _isNew ? 'New Certificate' : (_formatType(_certificate.certificateType) ?? 'Certificate');

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => _goBackToList(),
        ),
        title: Text(title, style: const TextStyle(fontSize: 16)),
        centerTitle: true,
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 80),
        children: [
          _buildGeneralSection(),
          _buildDatesSection(),
          _buildRatingsSection(),
          _buildLimitationsSection(),
          _buildCommentsSection(),
          if (!_isNew) _buildActionsSection(),
        ],
      ),
    );
  }

  // --- GENERAL ---
  Widget _buildGeneralSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FlightSectionHeader(title: 'General'),
        FlightFieldRow(
          label: 'Type',
          value: _formatType(_certificate.certificateType) ?? 'Select',
          valueColor: AppColors.accent,
          onTap: () async {
            final result = await _showPickerSheet(
              'Certificate Type',
              _typeOptions,
              _certificate.certificateType,
              _formatType,
            );
            if (result != null) {
              _saveField(_certificate.copyWith(
                certificateType: result,
                certificateClass: null,
              ));
            }
          },
        ),
        FlightFieldRow(
          label: 'Class',
          value: _formatClass(_certificate.certificateClass) ?? 'Select',
          valueColor: AppColors.accent,
          onTap: () async {
            final result = await _showPickerSheet(
              'Certificate Class',
              _classOptions,
              _certificate.certificateClass,
              _formatClass,
            );
            if (result != null) {
              _saveField(_certificate.copyWith(certificateClass: result));
            }
          },
        ),
        FlightFieldRow(
          label: 'Certificate #',
          value: _certificate.certificateNumber ?? 'None',
          valueColor: AppColors.accent,
          onTap: () async {
            final result = await showTextEditSheet(
              context,
              title: 'Certificate Number',
              currentValue: _certificate.certificateNumber ?? '',
              hintText: 'e.g. 1234567',
            );
            if (result != null) {
              _saveField(_certificate.copyWith(certificateNumber: result));
            }
          },
        ),
      ],
    );
  }

  // --- DATES ---
  Widget _buildDatesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FlightSectionHeader(title: 'Dates'),
        FlightFieldRow(
          label: 'Issue Date',
          value: _certificate.issueDate != null
              ? _formatDate(_certificate.issueDate!)
              : 'None',
          valueColor: AppColors.accent,
          onTap: () => _pickDate(
            _certificate.issueDate,
            (picked) => _saveField(_certificate.copyWith(
                issueDate: DateFormat('yyyy-MM-dd').format(picked))),
          ),
        ),
        _buildExpirationRow(),
      ],
    );
  }

  Widget _buildExpirationRow() {
    String display = 'None';
    Color color = AppColors.accent;

    if (_certificate.expirationDate != null) {
      try {
        final expDate = DateTime.parse(_certificate.expirationDate!);
        final now = DateTime.now();
        final daysUntil = expDate.difference(now).inDays;
        display = DateFormat('MMM d, yyyy').format(expDate);

        if (daysUntil < 0) {
          color = AppColors.error;
        } else if (daysUntil <= 30) {
          color = Colors.orange;
        } else {
          color = Colors.green;
        }
      } catch (_) {
        display = _certificate.expirationDate!;
      }
    }

    return FlightFieldRow(
      label: 'Expiration Date',
      value: display,
      valueColor: color,
      onTap: () => _pickDate(
        _certificate.expirationDate,
        (picked) => _saveField(_certificate.copyWith(
            expirationDate: DateFormat('yyyy-MM-dd').format(picked))),
      ),
    );
  }

  // --- RATINGS ---
  Widget _buildRatingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FlightSectionHeader(title: 'Ratings'),
        InkWell(
          onTap: () async {
            final result = await showTextEditSheet(
              context,
              title: 'Ratings',
              currentValue: _certificate.ratings ?? '',
              hintText: 'e.g. ASEL, AMEL, Instrument',
            );
            if (result != null) {
              _saveField(_certificate.copyWith(ratings: result));
            }
          },
          child: Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.divider, width: 0.5),
              ),
            ),
            child: Text(
              _certificate.ratings != null &&
                      _certificate.ratings!.isNotEmpty
                  ? _certificate.ratings!
                  : 'Add ratings...',
              style: TextStyle(
                fontSize: 14,
                color: _certificate.ratings != null &&
                        _certificate.ratings!.isNotEmpty
                    ? AppColors.accent
                    : AppColors.textMuted,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- LIMITATIONS ---
  Widget _buildLimitationsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FlightSectionHeader(title: 'Limitations'),
        InkWell(
          onTap: () async {
            final result = await showTextEditSheet(
              context,
              title: 'Limitations',
              currentValue: _certificate.limitations ?? '',
              hintText: 'Add limitations...',
            );
            if (result != null) {
              _saveField(_certificate.copyWith(limitations: result));
            }
          },
          child: Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.divider, width: 0.5),
              ),
            ),
            child: Text(
              _certificate.limitations != null &&
                      _certificate.limitations!.isNotEmpty
                  ? _certificate.limitations!
                  : 'Add limitations...',
              style: TextStyle(
                fontSize: 14,
                color: _certificate.limitations != null &&
                        _certificate.limitations!.isNotEmpty
                    ? AppColors.accent
                    : AppColors.textMuted,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- COMMENTS ---
  Widget _buildCommentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FlightSectionHeader(title: 'Comments'),
        InkWell(
          onTap: () async {
            final result = await showTextEditSheet(
              context,
              title: 'Comments',
              currentValue: _certificate.comments ?? '',
              hintText: 'Add comments...',
            );
            if (result != null) {
              _saveField(_certificate.copyWith(comments: result));
            }
          },
          child: Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.divider, width: 0.5),
              ),
            ),
            child: Text(
              _certificate.comments != null &&
                      _certificate.comments!.isNotEmpty
                  ? _certificate.comments!
                  : 'Add comments...',
              style: TextStyle(
                fontSize: 14,
                color: _certificate.comments != null &&
                        _certificate.comments!.isNotEmpty
                    ? AppColors.accent
                    : AppColors.textMuted,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // --- ACTIONS ---
  Widget _buildActionsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: TextButton(
          onPressed: _deleteCertificate,
          child: const Text('Delete',
              style: TextStyle(color: AppColors.error, fontSize: 16)),
        ),
      ),
    );
  }

  // --- HELPERS ---

  Future<void> _pickDate(
    String? currentDate,
    void Function(DateTime) onPicked,
  ) async {
    DateTime? initial;
    if (currentDate != null) {
      try {
        initial = DateTime.parse(currentDate);
      } catch (_) {}
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(1970),
      lastDate: DateTime(2040),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.accent,
            surface: AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      onPicked(picked);
    }
  }

  Future<String?> _showPickerSheet(
    String title,
    List<String> options,
    String? currentValue,
    String? Function(String?) formatter,
  ) async {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  )),
            ),
            ...options.map((option) => ListTile(
                  title: Text(
                    formatter(option) ?? option,
                    style: TextStyle(
                      color: option == currentValue
                          ? AppColors.accent
                          : AppColors.textPrimary,
                    ),
                  ),
                  trailing: option == currentValue
                      ? const Icon(Icons.check, color: AppColors.accent)
                      : null,
                  onTap: () => Navigator.pop(ctx, option),
                )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('MMM d, yyyy').format(date);
    } catch (_) {
      return dateStr;
    }
  }

  String? _formatType(String? type) {
    switch (type) {
      case 'pilot':
        return 'Pilot Certificate';
      case 'medical':
        return 'Medical Certificate';
      case 'type_rating':
        return 'Type Rating';
      case 'instructor':
        return 'Instructor Certificate';
      default:
        return type;
    }
  }

  String? _formatClass(String? cls) {
    switch (cls) {
      case 'student':
        return 'Student';
      case 'sport':
        return 'Sport';
      case 'recreational':
        return 'Recreational';
      case 'private':
        return 'Private';
      case 'commercial':
        return 'Commercial';
      case 'atp':
        return 'ATP';
      case 'first_class':
        return 'First Class';
      case 'second_class':
        return 'Second Class';
      case 'third_class':
        return 'Third Class';
      case 'basicmed':
        return 'BasicMed';
      case 'cfi':
        return 'CFI';
      case 'cfii':
        return 'CFII';
      case 'mei':
        return 'MEI';
      default:
        return cls;
    }
  }
}
