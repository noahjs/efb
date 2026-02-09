import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/flight.dart';
import '../../../services/aircraft_providers.dart';
import 'flight_section_header.dart';
import 'flight_field_row.dart';
import 'flight_edit_dialogs.dart';

class FlightDepartureSection extends ConsumerWidget {
  final Flight flight;
  final ValueChanged<Flight> onChanged;

  const FlightDepartureSection({
    super.key,
    required this.flight,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String etdDisplay = 'Set ETD';
    if (flight.etd != null) {
      try {
        final date = DateTime.parse(flight.etd!);
        etdDisplay = DateFormat('MMM d, yyyy h:mm a').format(date);
      } catch (_) {
        etdDisplay = flight.etd!;
      }
    }

    // Check if performance data is available for takeoff/landing buttons
    bool hasTakeoffData = false;
    bool hasLandingData = false;
    if (flight.id != null && flight.aircraftId != null) {
      final aircraftAsync =
          ref.watch(aircraftDetailProvider(flight.aircraftId!));
      aircraftAsync.whenData((aircraft) {
        if (aircraft != null) {
          final profile = aircraft.defaultProfile;
          if (profile != null) {
            hasTakeoffData = profile.takeoffData != null;
            hasLandingData = profile.landingData != null;
          }
        }
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FlightSectionHeader(title: 'Departure & Destination'),
        FlightFieldRow(
          label: 'ETD',
          value: etdDisplay,
          onTap: () async {
            DateTime? initial;
            if (flight.etd != null) {
              try {
                initial = DateTime.parse(flight.etd!);
              } catch (_) {}
            }
            final picked = await showDateTimePickerSheet(
              context,
              title: 'Estimated Time of Departure',
              initialDate: initial,
            );
            if (picked != null) {
              onChanged(flight.copyWith(etd: picked.toIso8601String()));
            }
          },
        ),
        _DepartureRow(
          label: 'Departure',
          airportId: flight.departureIdentifier,
          showTakeoff: hasTakeoffData,
          onTakeoff: flight.id != null
              ? () => context.push('/flights/${flight.id}/takeoff')
              : null,
          onTap: () async {
            final result = await showTextEditSheet(
              context,
              title: 'Departure Airport',
              currentValue: flight.departureIdentifier ?? '',
              hintText: 'e.g. KAPA',
            );
            if (result != null) {
              onChanged(
                  flight.copyWith(departureIdentifier: result.toUpperCase()));
            }
          },
        ),
        _DepartureRow(
          label: 'Destination',
          airportId: flight.destinationIdentifier,
          showLanding: hasLandingData,
          onLanding: flight.id != null
              ? () => context.push('/flights/${flight.id}/landing')
              : null,
          onTap: () async {
            final result = await showTextEditSheet(
              context,
              title: 'Destination Airport',
              currentValue: flight.destinationIdentifier ?? '',
              hintText: 'e.g. KBJC',
            );
            if (result != null) {
              onChanged(flight.copyWith(
                  destinationIdentifier: result.toUpperCase()));
            }
          },
        ),
        FlightFieldRow(
          label: 'Alternate',
          value: flight.alternateIdentifier ?? 'None',
          onTap: () async {
            final result = await showTextEditSheet(
              context,
              title: 'Alternate Airport',
              currentValue: flight.alternateIdentifier ?? '',
              hintText: 'e.g. KDEN',
            );
            if (result != null) {
              onChanged(
                  flight.copyWith(alternateIdentifier: result.toUpperCase()));
            }
          },
        ),
      ],
    );
  }
}

class _DepartureRow extends StatelessWidget {
  final String label;
  final String? airportId;
  final bool showTakeoff;
  final bool showLanding;
  final VoidCallback? onTakeoff;
  final VoidCallback? onLanding;
  final VoidCallback? onTap;

  const _DepartureRow({
    required this.label,
    this.airportId,
    this.showTakeoff = false,
    this.showLanding = false,
    this.onTakeoff,
    this.onLanding,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.divider, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 8),
            if (showTakeoff)
              _ActionChip(label: 'Takeoff', onTap: onTakeoff),
            if (showLanding)
              _ActionChip(label: 'Landing', onTap: onLanding),
            const Spacer(),
            Text(
              airportId ?? 'Select',
              style: TextStyle(
                fontSize: 14,
                color:
                    onTap != null ? AppColors.accent : AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right,
                size: 18, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;

  const _ActionChip({required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.accent, width: 1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.accent,
            ),
          ),
        ),
      ),
    );
  }
}
