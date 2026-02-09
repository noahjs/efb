import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../models/logbook_entry.dart';
import '../../models/aircraft.dart';
import '../../services/logbook_providers.dart';
import '../../services/aircraft_providers.dart';
import '../flights/widgets/flight_section_header.dart';
import '../flights/widgets/flight_field_row.dart';
import '../flights/widgets/flight_edit_dialogs.dart';

class LogbookEntryScreen extends ConsumerStatefulWidget {
  final int? entryId;

  const LogbookEntryScreen({super.key, required this.entryId});

  @override
  ConsumerState<LogbookEntryScreen> createState() =>
      _LogbookEntryScreenState();
}

class _LogbookEntryScreenState extends ConsumerState<LogbookEntryScreen> {
  LogbookEntry _entry = const LogbookEntry();
  bool _loaded = false;
  bool _saving = false;

  bool get _isNew => widget.entryId == null && _entry.id == null;

  @override
  void initState() {
    super.initState();
    if (widget.entryId == null) {
      _entry = LogbookEntry(
        date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
      );
      _loaded = true;
    }
  }

  void _goBackToList() {
    ref.invalidate(logbookListProvider(''));
    ref.invalidate(logbookSummaryProvider);
    context.go('/logbook');
  }

  Future<void> _saveField(LogbookEntry updated) async {
    setState(() {
      _entry = updated;
      _saving = true;
    });

    try {
      final service = ref.read(logbookServiceProvider);
      if (_isNew) {
        final created = await service.createEntry(updated.toJson());
        setState(() => _entry = created);
      } else {
        final saved =
            await service.updateEntry(_entry.id!, updated.toJson());
        setState(() => _entry = saved);
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

  Future<void> _deleteEntry() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Entry',
            style: TextStyle(color: AppColors.textPrimary)),
        content: const Text('Are you sure you want to delete this logbook entry?',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child:
                const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true && _entry.id != null) {
      try {
        final service = ref.read(logbookServiceProvider);
        await service.deleteEntry(_entry.id!);
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
    if (widget.entryId != null && !_loaded) {
      final entryAsync = ref.watch(logbookDetailProvider(widget.entryId!));
      return entryAsync.when(
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
          body: Center(child: Text('Failed to load entry: $error')),
        ),
        data: (entry) {
          if (entry != null && !_loaded) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() {
                _entry = entry;
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
    final from = _entry.fromAirport ?? '----';
    final to = _entry.toAirport ?? '----';
    final title = _isNew ? 'New Entry' : '$from - $to';

    String? subtitle;
    if (!_isNew && _entry.date != null) {
      try {
        final date = DateTime.parse(_entry.date!);
        subtitle = DateFormat('M/d/yy').format(date);
      } catch (_) {}
    }

    return Scaffold(
      appBar: AppBar(
        leading: TextButton(
          onPressed: () => _goBackToList(),
          child: const Text('Entries',
              style: TextStyle(color: AppColors.accent, fontSize: 14)),
        ),
        title: Column(
          children: [
            Text(title, style: const TextStyle(fontSize: 16)),
            if (subtitle != null)
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
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
          _buildStartEndSection(),
          _buildTimesSection(),
          _buildCrossCountrySection(),
          _buildTakeoffsSection(),
          _buildLandingsSection(),
          _buildInstrumentSection(),
          _buildTrainingSection(),
          _buildCommentsSection(),
          if (!_isNew) _buildActionsSection(),
        ],
      ),
    );
  }

  // --- GENERAL ---
  Widget _buildGeneralSection() {
    String dateDisplay = 'Set Date';
    if (_entry.date != null) {
      try {
        final date = DateTime.parse(_entry.date!);
        dateDisplay = DateFormat('MMM d, yyyy').format(date);
      } catch (_) {
        dateDisplay = _entry.date!;
      }
    }

    final aircraftDisplay = _entry.aircraftIdentifier != null
        ? '${_entry.aircraftIdentifier}${_entry.aircraftType != null ? " (${_entry.aircraftType})" : ""}'
        : 'Select';

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
            if (_entry.date != null) {
              try {
                initial = DateTime.parse(_entry.date!);
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
              _saveField(_entry.copyWith(
                  date: DateFormat('yyyy-MM-dd').format(picked)));
            }
          },
        ),
        FlightFieldRow(
          label: 'Aircraft',
          value: aircraftDisplay,
          valueColor: AppColors.accent,
          showChevron: true,
          onTap: () => _showAircraftPicker(),
        ),
        FlightFieldRow(
          label: 'From',
          value: _entry.fromAirport ?? 'Select',
          valueColor: AppColors.accent,
          onTap: () async {
            final result = await showTextEditSheet(
              context,
              title: 'Departure Airport',
              currentValue: _entry.fromAirport ?? '',
              hintText: 'e.g. KBJC',
            );
            if (result != null) {
              _saveField(
                  _entry.copyWith(fromAirport: result.toUpperCase()));
            }
          },
        ),
        FlightFieldRow(
          label: 'To',
          value: _entry.toAirport ?? 'Select',
          valueColor: AppColors.accent,
          onTap: () async {
            final result = await showTextEditSheet(
              context,
              title: 'Destination Airport',
              currentValue: _entry.toAirport ?? '',
              hintText: 'e.g. KAPA',
            );
            if (result != null) {
              _saveField(
                  _entry.copyWith(toAirport: result.toUpperCase()));
            }
          },
        ),
        FlightFieldRow(
          label: 'Route',
          value: _entry.route ?? 'None',
          valueColor: AppColors.accent,
          onTap: () async {
            final result = await showTextEditSheet(
              context,
              title: 'Route',
              currentValue: _entry.route ?? '',
              hintText: 'e.g. CYS GLL',
            );
            if (result != null) {
              _saveField(
                  _entry.copyWith(route: result.toUpperCase()));
            }
          },
        ),
      ],
    );
  }

  // --- START & END ---
  Widget _buildStartEndSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FlightSectionHeader(title: 'Start & End'),
        _buildDecimalRow('Hobbs Start', _entry.hobbsStart, (v) =>
            _saveField(_entry.copyWith(hobbsStart: v))),
        _buildDecimalRow('Hobbs End', _entry.hobbsEnd, (v) =>
            _saveField(_entry.copyWith(hobbsEnd: v))),
        _buildDecimalRow('Tach Start', _entry.tachStart, (v) =>
            _saveField(_entry.copyWith(tachStart: v))),
        _buildDecimalRow('Tach End', _entry.tachEnd, (v) =>
            _saveField(_entry.copyWith(tachEnd: v))),
        _buildTimeRow('Time Out', _entry.timeOut, (v) =>
            _saveField(_entry.copyWith(timeOut: v))),
        _buildTimeRow('Time Off', _entry.timeOff, (v) =>
            _saveField(_entry.copyWith(timeOff: v))),
        _buildTimeRow('Time On', _entry.timeOn, (v) =>
            _saveField(_entry.copyWith(timeOn: v))),
        _buildTimeRow('Time In', _entry.timeIn, (v) =>
            _saveField(_entry.copyWith(timeIn: v))),
      ],
    );
  }

  // --- TIMES ---
  Widget _buildTimesSection() {
    final tt = _entry.totalTime;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FlightSectionHeader(title: 'Times'),
        _buildDecimalRow('Total Time', _entry.totalTime, (v) =>
            _saveField(_entry.copyWith(totalTime: v ?? 0))),
        _buildDecimalRow('PIC', _entry.pic, (v) =>
            _saveField(_entry.copyWith(pic: v ?? 0)),
            suggestValue: tt),
        _buildDecimalRow('SIC', _entry.sic, (v) =>
            _saveField(_entry.copyWith(sic: v ?? 0)),
            suggestValue: tt),
        _buildDecimalRow('Night', _entry.night, (v) =>
            _saveField(_entry.copyWith(night: v ?? 0)),
            suggestValue: tt),
        _buildDecimalRow('Solo', _entry.solo, (v) =>
            _saveField(_entry.copyWith(solo: v ?? 0)),
            suggestValue: tt),
      ],
    );
  }

  // --- CROSS COUNTRY ---
  Widget _buildCrossCountrySection() {
    final tt = _entry.totalTime;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FlightSectionHeader(title: 'Cross Country'),
        _buildDecimalRow('Cross Country', _entry.crossCountry, (v) =>
            _saveField(_entry.copyWith(crossCountry: v ?? 0)),
            suggestValue: tt),
        _buildDecimalRow('Distance', _entry.distance, (v) =>
            _saveField(_entry.copyWith(distance: v))),
      ],
    );
  }

  // --- TAKEOFFS ---
  Widget _buildTakeoffsSection() {
    final total = _entry.dayTakeoffs + _entry.nightTakeoffs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FlightSectionHeader(title: 'Total Takeoffs ($total)'),
        _buildCounterRow('Day Takeoff', _entry.dayTakeoffs,
            icon: Icons.wb_sunny, iconColor: const Color(0xFFFFC107),
            onChanged: (v) =>
                _saveField(_entry.copyWith(dayTakeoffs: v))),
        _buildCounterRow('Night Takeoff', _entry.nightTakeoffs,
            icon: Icons.nightlight_round, iconColor: AppColors.textMuted,
            onChanged: (v) =>
                _saveField(_entry.copyWith(nightTakeoffs: v))),
      ],
    );
  }

  // --- LANDINGS ---
  Widget _buildLandingsSection() {
    final total = _entry.dayLandingsFullStop + _entry.nightLandingsFullStop;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FlightSectionHeader(title: 'Total Landings ($total)'),
        _buildCounterRow('Day Full Stop', _entry.dayLandingsFullStop,
            icon: Icons.wb_sunny, iconColor: const Color(0xFFFFC107),
            onChanged: (v) =>
                _saveField(_entry.copyWith(dayLandingsFullStop: v))),
        _buildCounterRow('Night Full Stop', _entry.nightLandingsFullStop,
            icon: Icons.nightlight_round, iconColor: AppColors.textMuted,
            onChanged: (v) =>
                _saveField(_entry.copyWith(nightLandingsFullStop: v))),
      ],
    );
  }

  // --- INSTRUMENT ---
  Widget _buildInstrumentSection() {
    final tt = _entry.totalTime;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FlightSectionHeader(title: 'Instrument'),
        _buildDecimalRow('Actual Instrument', _entry.actualInstrument, (v) =>
            _saveField(_entry.copyWith(actualInstrument: v ?? 0)),
            suggestValue: tt),
        _buildDecimalRow(
            'Simulated Instrument', _entry.simulatedInstrument, (v) =>
                _saveField(_entry.copyWith(simulatedInstrument: v ?? 0)),
            suggestValue: tt),
        _buildCounterRow('Holds', _entry.holds,
            onChanged: (v) => _saveField(_entry.copyWith(holds: v))),
      ],
    );
  }

  // --- TRAINING ---
  Widget _buildTrainingSection() {
    final tt = _entry.totalTime;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FlightSectionHeader(title: 'Training'),
        _buildDecimalRow('Dual Given', _entry.dualGiven, (v) =>
            _saveField(_entry.copyWith(dualGiven: v ?? 0)),
            suggestValue: tt),
        _buildDecimalRow('Dual Received', _entry.dualReceived, (v) =>
            _saveField(_entry.copyWith(dualReceived: v ?? 0)),
            suggestValue: tt),
        _buildDecimalRow('Simulated Flight', _entry.simulatedFlight, (v) =>
            _saveField(_entry.copyWith(simulatedFlight: v ?? 0)),
            suggestValue: tt),
        _buildDecimalRow('Ground Training', _entry.groundTraining, (v) =>
            _saveField(_entry.copyWith(groundTraining: v ?? 0)),
            suggestValue: tt),
      ],
    );
  }

  // --- COMMENTS ---
  Widget _buildCommentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FlightSectionHeader(title: 'My Comments'),
        InkWell(
          onTap: () async {
            final result = await showTextEditSheet(
              context,
              title: 'Comments',
              currentValue: _entry.comments ?? '',
              hintText: 'Add remarks...',
            );
            if (result != null) {
              _saveField(_entry.copyWith(comments: result));
            }
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.divider, width: 0.5),
              ),
            ),
            child: Text(
              _entry.comments != null && _entry.comments!.isNotEmpty
                  ? _entry.comments!
                  : 'Add comments...',
              style: TextStyle(
                fontSize: 14,
                color: _entry.comments != null && _entry.comments!.isNotEmpty
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
          onPressed: _deleteEntry,
          child: const Text('Delete',
              style: TextStyle(color: AppColors.error, fontSize: 16)),
        ),
      ),
    );
  }

  // --- AIRCRAFT PICKER ---

  void _showAircraftPicker() {
    final aircraftAsync = ref.read(aircraftListProvider(''));

    aircraftAsync.when(
      loading: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Loading aircraft...')),
        );
      },
      error: (_, _) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load aircraft')),
        );
      },
      data: (aircraftList) {
        if (aircraftList.isEmpty) {
          _enterAircraftManually();
          return;
        }

        showModalBottomSheet(
          context: context,
          backgroundColor: AppColors.surface,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
          ),
          builder: (ctx) => Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select Aircraft',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    )),
                const SizedBox(height: 12),
                ...aircraftList.map((a) => ListTile(
                      title: Text(a.tailNumber,
                          style: const TextStyle(
                              color: AppColors.textPrimary)),
                      subtitle: Text(a.aircraftType,
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13)),
                      trailing: a.id == _entry.aircraftId
                          ? const Icon(Icons.check,
                              color: AppColors.accent, size: 20)
                          : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        _selectAircraft(a);
                      },
                    )),
                const Divider(color: AppColors.divider),
                ListTile(
                  leading: const Icon(Icons.edit,
                      color: AppColors.accent, size: 20),
                  title: const Text('Enter Manually',
                      style: TextStyle(color: AppColors.accent)),
                  onTap: () {
                    Navigator.pop(ctx);
                    _enterAircraftManually();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _enterAircraftManually() async {
    final tail = await showTextEditSheet(
      context,
      title: 'Aircraft Tail Number',
      currentValue: _entry.aircraftIdentifier ?? '',
      hintText: 'e.g. N977CA',
    );
    if (tail != null && tail.isNotEmpty && mounted) {
      final type = await showTextEditSheet(
        context,
        title: 'Aircraft Type',
        currentValue: _entry.aircraftType ?? '',
        hintText: 'e.g. TBM9',
      );
      _saveField(_entry.copyWith(
        aircraftId: null,
        aircraftIdentifier: tail.toUpperCase(),
        aircraftType: type?.toUpperCase() ?? _entry.aircraftType,
      ));
    }
  }

  void _selectAircraft(Aircraft a) {
    _saveField(_entry.copyWith(
      aircraftId: a.id,
      aircraftIdentifier: a.tailNumber,
      aircraftType: a.aircraftType,
    ));
  }

  // --- HELPERS ---

  Widget _buildDecimalRow(
      String label, double? value, ValueChanged<double?> onChanged,
      {double? suggestValue}) {
    final display = value != null ? value.toStringAsFixed(1) : '0.0';
    final showSuggest = suggestValue != null &&
        suggestValue > 0 &&
        (value == null || value != suggestValue);

    return InkWell(
      onTap: () async {
        final result = await showNumberEditSheet(
          context,
          title: label,
          currentValue: value,
        );
        if (result != null) {
          onChanged(result);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.divider, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            if (showSuggest)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: InkWell(
                  onTap: () => onChanged(suggestValue),
                  borderRadius: BorderRadius.circular(4),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.accent, width: 1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'USE ${suggestValue.toStringAsFixed(1)}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accent,
                      ),
                    ),
                  ),
                ),
              ),
            Text(
              display,
              style: TextStyle(
                fontSize: 14,
                color: value != null && value > 0
                    ? AppColors.accent
                    : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeRow(
      String label, String? value, ValueChanged<String?> onChanged) {
    return FlightFieldRow(
      label: label,
      value: value ?? '0000',
      valueColor:
          value != null && value != '0000' ? AppColors.accent : AppColors.textPrimary,
      onTap: () async {
        final result = await showTextEditSheet(
          context,
          title: '$label (HHMM Zulu)',
          currentValue: value ?? '',
          hintText: 'e.g. 2357',
        );
        if (result != null) {
          onChanged(result);
        }
      },
    );
  }

  Widget _buildCounterRow(String label, int value,
      {IconData? icon,
      Color? iconColor,
      required ValueChanged<int> onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20, color: iconColor ?? AppColors.textMuted),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(label,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                )),
          ),
          // Minus button
          _counterButton(Icons.remove, () {
            if (value > 0) onChanged(value - 1);
          }),
          const SizedBox(width: 8),
          // Plus button
          _counterButton(Icons.add, () {
            onChanged(value + 1);
          }),
          const SizedBox(width: 12),
          SizedBox(
            width: 30,
            child: Text(
              '$value',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                color: value > 0 ? AppColors.accent : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _counterButton(IconData icon, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.accent, width: 1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, size: 18, color: AppColors.accent),
      ),
    );
  }
}
