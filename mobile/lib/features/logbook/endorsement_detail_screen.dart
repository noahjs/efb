import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../models/endorsement.dart';
import '../../services/endorsements_providers.dart';
import '../flights/widgets/flight_section_header.dart';
import '../flights/widgets/flight_field_row.dart';
import '../flights/widgets/flight_edit_dialogs.dart';

class EndorsementDetailScreen extends ConsumerStatefulWidget {
  final int? endorsementId;

  const EndorsementDetailScreen({super.key, required this.endorsementId});

  @override
  ConsumerState<EndorsementDetailScreen> createState() =>
      _EndorsementDetailScreenState();
}

class _EndorsementDetailScreenState
    extends ConsumerState<EndorsementDetailScreen> {
  Endorsement _endorsement = const Endorsement();
  bool _loaded = false;
  bool _saving = false;

  bool get _isNew =>
      widget.endorsementId == null && _endorsement.id == null;

  @override
  void initState() {
    super.initState();
    if (widget.endorsementId == null) {
      _endorsement = Endorsement(
        date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
      );
      _loaded = true;
    }
  }

  void _goBackToList() {
    ref.invalidate(endorsementsListProvider(''));
    context.go('/endorsements');
  }

  Future<void> _saveField(Endorsement updated) async {
    setState(() {
      _endorsement = updated;
      _saving = true;
    });

    try {
      final service = ref.read(endorsementsServiceProvider);
      if (_isNew) {
        final created =
            await service.createEndorsement(updated.toJson());
        setState(() => _endorsement = created);
      } else {
        final saved = await service.updateEndorsement(
            _endorsement.id!, updated.toJson());
        setState(() => _endorsement = saved);
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

  Future<void> _deleteEndorsement() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Endorsement',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text(
            'Are you sure you want to delete this endorsement?',
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

    if (confirmed == true && _endorsement.id != null) {
      try {
        final service = ref.read(endorsementsServiceProvider);
        await service.deleteEndorsement(_endorsement.id!);
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
    if (widget.endorsementId != null && !_loaded) {
      final endorsementAsync =
          ref.watch(endorsementDetailProvider(widget.endorsementId!));
      return endorsementAsync.when(
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
          body: Center(child: Text('Failed to load endorsement: $error')),
        ),
        data: (endorsement) {
          if (endorsement != null && !_loaded) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() {
                _endorsement = endorsement;
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
        _isNew ? 'New Endorsement' : (_endorsement.endorsementType ?? 'Endorsement');

    return Scaffold(
      appBar: AppBar(
        leading: TextButton(
          onPressed: () => _goBackToList(),
          child: const Text('Back',
              style: TextStyle(color: AppColors.accent, fontSize: 14)),
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
          _buildCfiSection(),
          _buildEndorsementTextSection(),
          _buildExpirationSection(),
          _buildCommentsSection(),
          if (!_isNew) _buildActionsSection(),
        ],
      ),
    );
  }

  // --- GENERAL ---
  Widget _buildGeneralSection() {
    String dateDisplay = 'Set Date';
    if (_endorsement.date != null) {
      try {
        final date = DateTime.parse(_endorsement.date!);
        dateDisplay = DateFormat('MMM d, yyyy').format(date);
      } catch (_) {
        dateDisplay = _endorsement.date!;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FlightSectionHeader(title: 'General'),
        FlightFieldRow(
          label: 'Date',
          value: dateDisplay,
          valueColor: AppColors.accent,
          onTap: () async {
            DateTime? initial;
            if (_endorsement.date != null) {
              try {
                initial = DateTime.parse(_endorsement.date!);
              } catch (_) {}
            }
            final picked = await showDatePicker(
              context: context,
              initialDate: initial ?? DateTime.now(),
              firstDate: DateTime(1970),
              lastDate: DateTime(2030),
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
              _saveField(_endorsement.copyWith(
                  date: DateFormat('yyyy-MM-dd').format(picked)));
            }
          },
        ),
        FlightFieldRow(
          label: 'Type',
          value: _endorsement.endorsementType ?? 'Select',
          valueColor: AppColors.accent,
          onTap: () async {
            final result = await showTextEditSheet(
              context,
              title: 'Endorsement Type',
              currentValue: _endorsement.endorsementType ?? '',
              hintText: 'e.g. Flight Review, Solo Flight',
            );
            if (result != null) {
              _saveField(_endorsement.copyWith(endorsementType: result));
            }
          },
        ),
        FlightFieldRow(
          label: 'FAR Reference',
          value: _endorsement.farReference ?? 'None',
          valueColor: AppColors.accent,
          onTap: () async {
            final result = await showTextEditSheet(
              context,
              title: 'FAR Reference',
              currentValue: _endorsement.farReference ?? '',
              hintText: 'e.g. 61.56, 61.87(n)',
            );
            if (result != null) {
              _saveField(_endorsement.copyWith(farReference: result));
            }
          },
        ),
      ],
    );
  }

  // --- CFI INFO ---
  Widget _buildCfiSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FlightSectionHeader(title: 'CFI Information'),
        FlightFieldRow(
          label: 'CFI Name',
          value: _endorsement.cfiName ?? 'None',
          valueColor: AppColors.accent,
          onTap: () async {
            final result = await showTextEditSheet(
              context,
              title: 'CFI Name',
              currentValue: _endorsement.cfiName ?? '',
              hintText: 'Instructor name',
            );
            if (result != null) {
              _saveField(_endorsement.copyWith(cfiName: result));
            }
          },
        ),
        FlightFieldRow(
          label: 'Certificate #',
          value: _endorsement.cfiCertificateNumber ?? 'None',
          valueColor: AppColors.accent,
          onTap: () async {
            final result = await showTextEditSheet(
              context,
              title: 'CFI Certificate Number',
              currentValue: _endorsement.cfiCertificateNumber ?? '',
              hintText: 'e.g. 1234567',
            );
            if (result != null) {
              _saveField(
                  _endorsement.copyWith(cfiCertificateNumber: result));
            }
          },
        ),
        FlightFieldRow(
          label: 'CFI Exp. Date',
          value: _endorsement.cfiExpirationDate != null
              ? _formatDate(_endorsement.cfiExpirationDate!)
              : 'None',
          valueColor: AppColors.accent,
          onTap: () async {
            DateTime? initial;
            if (_endorsement.cfiExpirationDate != null) {
              try {
                initial = DateTime.parse(_endorsement.cfiExpirationDate!);
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
              _saveField(_endorsement.copyWith(
                  cfiExpirationDate:
                      DateFormat('yyyy-MM-dd').format(picked)));
            }
          },
        ),
      ],
    );
  }

  // --- ENDORSEMENT TEXT ---
  Widget _buildEndorsementTextSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FlightSectionHeader(title: 'Endorsement Text'),
        InkWell(
          onTap: () async {
            final result = await showTextEditSheet(
              context,
              title: 'Endorsement Text',
              currentValue: _endorsement.endorsementText ?? '',
              hintText: 'Full regulatory endorsement language...',
            );
            if (result != null) {
              _saveField(
                  _endorsement.copyWith(endorsementText: result));
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
              _endorsement.endorsementText != null &&
                      _endorsement.endorsementText!.isNotEmpty
                  ? _endorsement.endorsementText!
                  : 'Add endorsement text...',
              style: TextStyle(
                fontSize: 14,
                color: _endorsement.endorsementText != null &&
                        _endorsement.endorsementText!.isNotEmpty
                    ? AppColors.accent
                    : AppColors.textMuted,
              ),
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  // --- EXPIRATION ---
  Widget _buildExpirationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FlightSectionHeader(title: 'Expiration'),
        FlightFieldRow(
          label: 'Expiration Date',
          value: _endorsement.expirationDate != null
              ? _formatDate(_endorsement.expirationDate!)
              : 'None',
          valueColor: AppColors.accent,
          onTap: () async {
            DateTime? initial;
            if (_endorsement.expirationDate != null) {
              try {
                initial = DateTime.parse(_endorsement.expirationDate!);
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
              _saveField(_endorsement.copyWith(
                  expirationDate:
                      DateFormat('yyyy-MM-dd').format(picked)));
            }
          },
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
              currentValue: _endorsement.comments ?? '',
              hintText: 'Add comments...',
            );
            if (result != null) {
              _saveField(_endorsement.copyWith(comments: result));
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
              _endorsement.comments != null &&
                      _endorsement.comments!.isNotEmpty
                  ? _endorsement.comments!
                  : 'Add comments...',
              style: TextStyle(
                fontSize: 14,
                color: _endorsement.comments != null &&
                        _endorsement.comments!.isNotEmpty
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
          onPressed: _deleteEndorsement,
          child: const Text('Delete',
              style: TextStyle(color: AppColors.error, fontSize: 16)),
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
}
