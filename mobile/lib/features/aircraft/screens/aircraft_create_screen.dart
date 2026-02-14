import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/navigation_helpers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/aircraft_providers.dart';
import '../../../services/api_client.dart';
import '../../flights/widgets/flight_section_header.dart';
import '../../flights/widgets/flight_field_row.dart';
import '../../flights/widgets/flight_edit_dialogs.dart';

class AircraftCreateScreen extends ConsumerStatefulWidget {
  const AircraftCreateScreen({super.key});

  @override
  ConsumerState<AircraftCreateScreen> createState() =>
      _AircraftCreateScreenState();
}

class _AircraftCreateScreenState extends ConsumerState<AircraftCreateScreen> {
  bool _saving = false;

  // Form state
  String _tailNumber = '';
  String _aircraftType = '';
  String _icaoTypeCode = '';
  String _category = 'landplane';
  String _callSign = '';
  String _serialNumber = '';
  String _homeAirport = '';
  String _color = '';
  String _fuelType = '100ll';
  double? _totalUsableFuel;
  double? _bestGlideSpeed;
  double? _glideRatio;

  // Registry lookup state
  bool _lookingUp = false;
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onTailChanged(String value) {
    _debounceTimer?.cancel();
    final text = value.trim().toUpperCase();

    if (text.length < 2) {
      if (_lookingUp) setState(() => _lookingUp = false);
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _lookupRegistry(text);
    });
  }

  Future<void> _lookupRegistry(String nNumber) async {
    setState(() => _lookingUp = true);
    try {
      final api = ref.read(apiClientProvider);
      final result = await api.lookupRegistry(nNumber);
      if (!mounted) return;
      setState(() => _lookingUp = false);

      if (result != null) {
        _showAutoFillDialog(result);
      }
    } catch (_) {
      if (mounted) setState(() => _lookingUp = false);
    }
  }

  void _showAutoFillDialog(Map<String, dynamic> data) {
    final aircraftType = data['aircraft_type'] ?? 'Unknown';
    final year = data['year_mfr'];
    final engine = data['engine_manufacturer'] != null
        ? '${data['engine_manufacturer']} ${data['engine_model'] ?? ''}'.trim()
        : null;
    final subtitle = [
      if (year != null && year.toString().isNotEmpty) year.toString(),
      ?engine,
    ].join(' — ');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Aircraft Found'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(aircraftType,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.accent,
                )),
            if (subtitle.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    )),
              ),
            const SizedBox(height: 12),
            const Text('Auto-fill aircraft details?',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _applyRegistryData(data);
            },
            child: const Text('Yes',
                style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
    );
  }

  void _applyRegistryData(Map<String, dynamic> data) {
    setState(() {
      if (data['model'] != null) {
        _aircraftType = data['model'];
      } else if (data['aircraft_type'] != null) {
        _aircraftType = data['aircraft_type'];
      }
      if (data['serial_number'] != null) {
        _serialNumber = data['serial_number'];
      }
      if (data['category'] != null) {
        _category = data['category'];
      }
      if (data['fuel_type'] != null) {
        _fuelType = data['fuel_type'];
      }
    });
  }

  Future<void> _create() async {
    if (_tailNumber.isEmpty || _aircraftType.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tail number and type are required')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final service = ref.read(aircraftServiceProvider);
      final createData = <String, dynamic>{
        'tail_number': _tailNumber,
        'aircraft_type': _aircraftType,
        'category': _category,
        'fuel_type': _fuelType,
        if (_icaoTypeCode.isNotEmpty) 'icao_type_code': _icaoTypeCode,
        if (_callSign.isNotEmpty) 'call_sign': _callSign,
        if (_serialNumber.isNotEmpty) 'serial_number': _serialNumber,
        if (_homeAirport.isNotEmpty) 'home_airport': _homeAirport,
        if (_color.isNotEmpty) 'color': _color,
        if (_totalUsableFuel != null) 'total_usable_fuel': _totalUsableFuel,
        if (_bestGlideSpeed != null) 'best_glide_speed': _bestGlideSpeed,
        if (_glideRatio != null) 'glide_ratio': _glideRatio,
      };

      final aircraft = await service.createAircraft(createData);
      ref.invalidate(aircraftListProvider(''));
      if (mounted) {
        context.go('/aircraft/${aircraft.id}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.goBack('/aircraft'),
        ),
        title: const Text('New Aircraft'),
        centerTitle: true,
        actions: [
          if (_lookingUp)
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          TextButton(
            onPressed: _saving ? null : _create,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save',
                    style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
      body: ListView(
        children: [
          // General section
          const FlightSectionHeader(title: 'General'),
          FlightFieldRow(
            label: 'Tail Number *',
            value: _tailNumber.isEmpty ? '--' : _tailNumber,
            onTap: () async {
              final result = await showTextEditSheet(context,
                  title: 'Tail Number',
                  currentValue: _tailNumber,
                  hintText: 'e.g. N12345');
              if (result != null) {
                final upper = result.toUpperCase();
                setState(() => _tailNumber = upper);
                _onTailChanged(upper);
              }
            },
          ),
          FlightFieldRow(
            label: 'Aircraft Type *',
            value: _aircraftType.isEmpty ? '--' : _aircraftType,
            onTap: () async {
              final result = await showTextEditSheet(context,
                  title: 'Aircraft Type',
                  currentValue: _aircraftType,
                  hintText: 'e.g. TBM 960');
              if (result != null) {
                setState(() => _aircraftType = result);
              }
            },
          ),
          FlightFieldRow(
            label: 'ICAO Type',
            value: _icaoTypeCode.isEmpty ? '--' : _icaoTypeCode,
            onTap: () async {
              final result = await showTextEditSheet(context,
                  title: 'ICAO Type Code',
                  currentValue: _icaoTypeCode,
                  hintText: 'e.g. TBM9');
              if (result != null) {
                setState(() => _icaoTypeCode = result.toUpperCase());
              }
            },
          ),
          FlightFieldRow(
            label: 'Category',
            value: _category,
            onTap: () async {
              final result = await showPickerSheet(context,
                  title: 'Category',
                  options: [
                    'landplane',
                    'seaplane',
                    'amphibian',
                    'helicopter',
                  ],
                  currentValue: _category);
              if (result != null) {
                setState(() => _category = result);
              }
            },
          ),
          FlightFieldRow(
            label: 'Call Sign',
            value: _callSign.isEmpty ? '--' : _callSign,
            onTap: () async {
              final result = await showTextEditSheet(context,
                  title: 'Call Sign',
                  currentValue: _callSign,
                  hintText: 'Optional');
              if (result != null) {
                setState(() => _callSign = result);
              }
            },
          ),
          FlightFieldRow(
            label: 'Serial Number',
            value: _serialNumber.isEmpty ? '--' : _serialNumber,
            onTap: () async {
              final result = await showTextEditSheet(context,
                  title: 'Serial Number',
                  currentValue: _serialNumber,
                  hintText: 'Optional');
              if (result != null) {
                setState(() => _serialNumber = result);
              }
            },
          ),
          FlightFieldRow(
            label: 'Home Airport',
            value: _homeAirport.isEmpty ? '--' : _homeAirport,
            onTap: () async {
              final result = await showTextEditSheet(context,
                  title: 'Home Airport',
                  currentValue: _homeAirport,
                  hintText: 'e.g. BJC');
              if (result != null) {
                setState(() => _homeAirport = result.toUpperCase());
              }
            },
          ),
          FlightFieldRow(
            label: 'Color',
            value: _color.isEmpty ? '--' : _color,
            onTap: () async {
              final result = await showTextEditSheet(context,
                  title: 'Color',
                  currentValue: _color,
                  hintText: 'e.g. White/Blue');
              if (result != null) {
                setState(() => _color = result);
              }
            },
          ),

          // Fuel section
          const FlightSectionHeader(title: 'Fuel'),
          FlightFieldRow(
            label: 'Fuel Type',
            value: _fuelTypeDisplay(_fuelType),
            onTap: () async {
              final result = await showPickerSheet(context,
                  title: 'Fuel Type',
                  options: ['100ll', 'jet_a', 'mogas', 'diesel'],
                  currentValue: _fuelType);
              if (result != null) {
                setState(() => _fuelType = result);
              }
            },
          ),
          FlightFieldRow(
            label: 'Total Usable Fuel',
            value: _totalUsableFuel != null
                ? '$_totalUsableFuel gal'
                : '--',
            onTap: () async {
              final result = await showNumberEditSheet(context,
                  title: 'Total Usable Fuel',
                  currentValue: _totalUsableFuel,
                  hintText: 'Gallons',
                  suffix: 'gal');
              if (result != null) {
                setState(() => _totalUsableFuel = result);
              }
            },
          ),

          // Glide section
          const FlightSectionHeader(title: 'Glide'),
          FlightFieldRow(
            label: 'Best Glide Speed',
            value: _bestGlideSpeed != null
                ? '${_bestGlideSpeed!.round()} KIAS'
                : '--',
            onTap: () async {
              final result = await showNumberEditSheet(context,
                  title: 'Best Glide Speed',
                  currentValue: _bestGlideSpeed,
                  hintText: 'KIAS',
                  suffix: 'KIAS');
              if (result != null) {
                setState(() => _bestGlideSpeed = result);
              }
            },
          ),
          FlightFieldRow(
            label: 'Glide Ratio',
            value: _glideRatio != null ? '$_glideRatio:1' : '--',
            onTap: () async {
              final result = await showNumberEditSheet(context,
                  title: 'Glide Ratio',
                  currentValue: _glideRatio,
                  hintText: 'e.g. 13.8',
                  suffix: ':1');
              if (result != null) {
                setState(() => _glideRatio = result);
              }
            },
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  String _fuelTypeDisplay(String fuelType) {
    switch (fuelType) {
      case '100ll':
        return '100LL';
      case 'jet_a':
        return 'Jet-A';
      case 'mogas':
        return 'MoGas';
      case 'diesel':
        return 'Diesel';
      default:
        return fuelType;
    }
  }
}
