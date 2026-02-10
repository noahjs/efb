import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/flight.dart';
import '../../../models/aircraft.dart';
import '../../../services/aircraft_providers.dart';
import 'flight_section_header.dart';
import 'flight_field_row.dart';

class FlightAircraftSection extends ConsumerWidget {
  final Flight flight;
  final ValueChanged<Flight> onChanged;

  const FlightAircraftSection({
    super.key,
    required this.flight,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tailDisplay = flight.aircraftIdentifier ?? 'Select';
    final typeDisplay = flight.aircraftType ?? '--';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FlightSectionHeader(title: 'Aircraft'),
        FlightFieldRow(
          label: 'Aircraft',
          value: '$tailDisplay  $typeDisplay',
          showChevron: true,
          onTap: () => _showAircraftPicker(context, ref),
        ),
        FlightFieldRow(
          label: 'Performance Profile',
          value: flight.performanceProfile ?? 'None',
          showChevron: true,
          onTap: () => _showProfilePicker(context, ref),
        ),
      ],
    );
  }

  void _showAircraftPicker(BuildContext context, WidgetRef ref) {
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No aircraft found. Add one in the Aircraft tab.'),
              duration: Duration(seconds: 3),
            ),
          );
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
                      trailing: a.id == flight.aircraftId
                          ? const Icon(Icons.check,
                              color: AppColors.accent, size: 20)
                          : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        _selectAircraft(a);
                      },
                    )),
              ],
            ),
          ),
        );
      },
    );
  }

  void _selectAircraft(Aircraft a) {
    final defaultProfile = a.defaultProfile;
    // Use toFullJson + fromJson so nullable profile fields can be
    // explicitly cleared (copyWith treats null as "keep existing").
    final json = flight.toFullJson();
    json['aircraft_id'] = a.id;
    json['aircraft_identifier'] = a.tailNumber;
    json['aircraft_type'] = a.aircraftType;
    json['performance_profile_id'] = defaultProfile?.id;
    json['performance_profile'] = defaultProfile?.name;
    json['true_airspeed'] = defaultProfile?.cruiseTas?.round();
    json['fuel_burn_rate'] = defaultProfile?.cruiseFuelBurn;
    onChanged(Flight.fromJson(json));
  }

  void _showProfilePicker(BuildContext context, WidgetRef ref) {
    if (flight.aircraftId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select an aircraft first'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final detailAsync =
        ref.read(aircraftDetailProvider(flight.aircraftId!));
    detailAsync.when(
      loading: () {},
      error: (_, _) {},
      data: (aircraft) {
        if (aircraft == null) return;
        final profiles = aircraft.performanceProfiles;
        if (profiles.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'No performance profiles. Add one in the Aircraft tab.'),
              duration: Duration(seconds: 3),
            ),
          );
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
                const Text('Select Profile',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    )),
                const SizedBox(height: 12),
                ...profiles.map((p) => ListTile(
                      title: Text(p.name,
                          style: const TextStyle(
                              color: AppColors.textPrimary)),
                      subtitle: Text(
                          '${p.cruiseTas?.round() ?? '--'} kt / ${p.cruiseFuelBurn ?? '--'} GPH',
                          style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13)),
                      trailing: p.id == flight.performanceProfileId
                          ? const Icon(Icons.check,
                              color: AppColors.accent, size: 20)
                          : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        onChanged(flight.copyWith(
                          performanceProfileId: p.id,
                          performanceProfile: p.name,
                          trueAirspeed: p.cruiseTas?.round(),
                          fuelBurnRate: p.cruiseFuelBurn,
                        ));
                      },
                    )),
              ],
            ),
          ),
        );
      },
    );
  }
}
