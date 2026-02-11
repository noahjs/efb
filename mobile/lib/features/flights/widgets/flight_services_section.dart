import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/flight.dart';
import '../../../models/fbo.dart';
import '../../../services/airport_providers.dart';
import 'flight_section_header.dart';
import 'flight_field_row.dart';

class FlightServicesSection extends ConsumerWidget {
  final Flight flight;
  final ValueChanged<Flight> onChanged;

  const FlightServicesSection({
    super.key,
    required this.flight,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasDestination = flight.destinationIdentifier != null &&
        flight.destinationIdentifier!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FlightSectionHeader(title: 'Services'),
        FlightFieldRow(
          label: 'Arrival FBO',
          value: flight.arrivalFboName ?? (hasDestination ? 'Select FBO' : 'Set Destination First'),
          valueColor: flight.arrivalFboName != null
              ? AppColors.textPrimary
              : AppColors.textMuted,
          showChevron: hasDestination,
          onTap: hasDestination
              ? () => _showFboPicker(context, ref)
              : null,
        ),
        const FlightFieldRow(
          label: 'Fuel Order',
          value: 'Coming Soon',
          valueColor: AppColors.textMuted,
        ),
      ],
    );
  }

  void _showFboPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _FboPickerSheet(
        destinationIdentifier: flight.destinationIdentifier!,
        selectedFboId: flight.arrivalFboId,
        onSelected: (fbo) {
          Navigator.of(ctx).pop();
          onChanged(flight.copyWith(
            arrivalFboId: fbo.id,
            arrivalFboName: fbo.name,
          ));
        },
        onClear: () {
          Navigator.of(ctx).pop();
          // Use a special copyWith — set to 0/empty to clear
          onChanged(Flight(
            id: flight.id,
            aircraftId: flight.aircraftId,
            performanceProfileId: flight.performanceProfileId,
            departureIdentifier: flight.departureIdentifier,
            destinationIdentifier: flight.destinationIdentifier,
            alternateIdentifier: flight.alternateIdentifier,
            etd: flight.etd,
            aircraftIdentifier: flight.aircraftIdentifier,
            aircraftType: flight.aircraftType,
            performanceProfile: flight.performanceProfile,
            trueAirspeed: flight.trueAirspeed,
            flightRules: flight.flightRules,
            routeString: flight.routeString,
            cruiseAltitude: flight.cruiseAltitude,
            peopleCount: flight.peopleCount,
            avgPersonWeight: flight.avgPersonWeight,
            cargoWeight: flight.cargoWeight,
            fuelPolicy: flight.fuelPolicy,
            startFuelGallons: flight.startFuelGallons,
            reserveFuelGallons: flight.reserveFuelGallons,
            fuelBurnRate: flight.fuelBurnRate,
            fuelAtShutdownGallons: flight.fuelAtShutdownGallons,
            filingStatus: flight.filingStatus,
            filingReference: flight.filingReference,
            filingVersionStamp: flight.filingVersionStamp,
            filedAt: flight.filedAt,
            filingFormat: flight.filingFormat,
            enduranceHours: flight.enduranceHours,
            remarks: flight.remarks,
            distanceNm: flight.distanceNm,
            eteMinutes: flight.eteMinutes,
            flightFuelGallons: flight.flightFuelGallons,
            windComponent: flight.windComponent,
            eta: flight.eta,
            calculatedAt: flight.calculatedAt,
            arrivalFboId: null,
            arrivalFboName: null,
            createdAt: flight.createdAt,
            updatedAt: flight.updatedAt,
          ));
        },
      ),
    );
  }
}

class _FboPickerSheet extends ConsumerWidget {
  final String destinationIdentifier;
  final int? selectedFboId;
  final ValueChanged<Fbo> onSelected;
  final VoidCallback onClear;

  const _FboPickerSheet({
    required this.destinationIdentifier,
    required this.selectedFboId,
    required this.onSelected,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fbosAsync = ref.watch(airportFbosProvider(destinationIdentifier));

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Text(
                'Select Arrival FBO',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              if (selectedFboId != null)
                TextButton(
                  onPressed: onClear,
                  child: const Text('Clear'),
                ),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.divider),
        fbosAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => const Padding(
            padding: EdgeInsets.all(32),
            child: Center(
              child: Text('Failed to load FBOs',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
          ),
          data: (fbos) {
            if (fbos.isEmpty) {
              return const Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Text('No FBOs at this airport',
                      style: TextStyle(color: AppColors.textMuted)),
                ),
              );
            }
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.5,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: fbos.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, color: AppColors.divider),
                itemBuilder: (context, index) {
                  final fbo = fbos[index];
                  final isSelected = fbo.id == selectedFboId;
                  return ListTile(
                    title: Text(
                      fbo.name,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    subtitle: fbo.cheapest100LL != null
                        ? Text(
                            '100LL: \$${fbo.cheapest100LL!.toStringAsFixed(2)}',
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 13),
                          )
                        : null,
                    trailing: isSelected
                        ? const Icon(Icons.check, color: AppColors.accent)
                        : null,
                    onTap: () => onSelected(fbo),
                  );
                },
              ),
            );
          },
        ),
        SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
      ],
    );
  }
}
