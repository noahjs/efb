import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/navigation_helpers.dart';
import '../../../models/aircraft.dart';
import '../../../services/aircraft_providers.dart';
import '../../flights/widgets/flight_section_header.dart';
import '../../flights/widgets/flight_field_row.dart';
import '../../flights/widgets/flight_edit_dialogs.dart';

class EquipmentScreen extends ConsumerStatefulWidget {
  final int aircraftId;

  const EquipmentScreen({super.key, required this.aircraftId});

  @override
  ConsumerState<EquipmentScreen> createState() => _EquipmentScreenState();
}

class _EquipmentScreenState extends ConsumerState<EquipmentScreen> {
  AircraftEquipment? _equipment;
  bool _loaded = false;
  bool _saving = false;

  Future<void> _saveField(Map<String, dynamic> updates) async {
    setState(() => _saving = true);
    try {
      final service = ref.read(aircraftServiceProvider);
      final updated =
          await service.upsertEquipment(widget.aircraftId, updates);
      setState(() => _equipment = updated);
      ref.invalidate(aircraftDetailProvider(widget.aircraftId));
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

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      final detailAsync =
          ref.watch(aircraftDetailProvider(widget.aircraftId));
      return detailAsync.when(
        loading: () => Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () =>
                  context.goBack('/aircraft/${widget.aircraftId}'),
            ),
          ),
          body: const Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () =>
                  context.goBack('/aircraft/${widget.aircraftId}'),
            ),
          ),
          body: Center(child: Text('Error: $e')),
        ),
        data: (aircraft) {
          if (aircraft != null && !_loaded) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() {
                _equipment = aircraft.equipment;
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
    final e = _equipment ?? const AircraftEquipment();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.goBack('/aircraft/${widget.aircraftId}'),
        ),
        title: const Text('Equipment'),
        centerTitle: true,
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        children: [
          const FlightSectionHeader(title: 'Navigation'),
          FlightFieldRow(
            label: 'GPS Type',
            value: e.gpsType ?? '--',
            onTap: () async {
              final result = await showTextEditSheet(context,
                  title: 'GPS Type',
                  currentValue: e.gpsType ?? '',
                  hintText: 'e.g. WAAS GPS');
              if (result != null) {
                _saveField({'gps_type': result});
              }
            },
          ),

          const FlightSectionHeader(title: 'Surveillance'),
          FlightFieldRow(
            label: 'Transponder',
            value: e.transponderType ?? '--',
            onTap: () async {
              final result = await showPickerSheet(context,
                  title: 'Transponder Type',
                  options: [
                    'Mode A/C',
                    'Mode S',
                    'Mode S (Extended Squitter)',
                  ],
                  currentValue: e.transponderType);
              if (result != null) {
                _saveField({'transponder_type': result});
              }
            },
          ),
          FlightFieldRow(
            label: 'ADS-B Compliance',
            value: e.adsbCompliance ?? '--',
            onTap: () async {
              final result = await showPickerSheet(context,
                  title: 'ADS-B Compliance',
                  options: [
                    'ADS-B Out',
                    'ADS-B In/Out',
                    'None',
                  ],
                  currentValue: e.adsbCompliance);
              if (result != null) {
                _saveField({'adsb_compliance': result});
              }
            },
          ),

          const FlightSectionHeader(title: 'Equipment Codes'),
          FlightFieldRow(
            label: 'Equipment Codes',
            value: e.equipmentCodes ?? '--',
            onTap: () async {
              final result = await showTextEditSheet(context,
                  title: 'Equipment Codes',
                  currentValue: e.equipmentCodes ?? '',
                  hintText: 'e.g. G/S');
              if (result != null) {
                _saveField({'equipment_codes': result});
              }
            },
          ),

          const FlightSectionHeader(title: 'Avionics'),
          FlightFieldRow(
            label: 'Installed Avionics',
            value: e.installedAvionics ?? '--',
            onTap: () async {
              final result = await showTextEditSheet(context,
                  title: 'Installed Avionics',
                  currentValue: e.installedAvionics ?? '',
                  hintText: 'e.g. Garmin G3000');
              if (result != null) {
                _saveField({'installed_avionics': result});
              }
            },
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
