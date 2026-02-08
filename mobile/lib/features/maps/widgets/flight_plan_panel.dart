import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/flight.dart';
import '../../../services/api_client.dart';
import '../../../services/flight_providers.dart';
import '../../../services/aircraft_providers.dart';
import '../../../services/map_flight_provider.dart';
import '../../../models/aircraft.dart';
import '../../flights/widgets/altitude_picker_sheet.dart';
import '../../flights/widgets/flight_edit_dialogs.dart';
import '../../flights/widgets/preferred_route_sheet.dart';

class FlightPlanPanel extends ConsumerStatefulWidget {
  const FlightPlanPanel({super.key});

  @override
  ConsumerState<FlightPlanPanel> createState() => _FlightPlanPanelState();
}

class _FlightPlanPanelState extends ConsumerState<FlightPlanPanel> {
  bool _saving = false;

  Flight? get _flight => ref.read(activeFlightProvider);

  Future<void> _saveField(Flight updated) async {
    ref.read(activeFlightProvider.notifier).set(updated);
    setState(() => _saving = true);

    try {
      if (updated.id != null) {
        // Saved flight — update on server
        final service = ref.read(flightServiceProvider);
        final saved =
            await service.updateFlight(updated.id!, updated.toJson());
        ref.read(activeFlightProvider.notifier).set(saved);
      } else {
        // Unsaved flight — compute stats without persisting
        final api = ref.read(apiClientProvider);
        final result = await api.calculateFlight(
          departureIdentifier: updated.departureIdentifier,
          destinationIdentifier: updated.destinationIdentifier,
          routeString: updated.routeString,
          cruiseAltitude: updated.cruiseAltitude,
          trueAirspeed: updated.trueAirspeed,
          fuelBurnRate: updated.fuelBurnRate,
          etd: updated.etd,
          performanceProfileId: updated.performanceProfileId,
        );
        // Build a new Flight so null results properly clear stale values
        // (copyWith's ?? operator can't set fields back to null).
        ref.read(activeFlightProvider.notifier).set(Flight(
              id: updated.id,
              aircraftId: updated.aircraftId,
              performanceProfileId: updated.performanceProfileId,
              departureIdentifier: updated.departureIdentifier,
              destinationIdentifier: updated.destinationIdentifier,
              alternateIdentifier: updated.alternateIdentifier,
              etd: updated.etd,
              aircraftIdentifier: updated.aircraftIdentifier,
              aircraftType: updated.aircraftType,
              performanceProfile: updated.performanceProfile,
              trueAirspeed: updated.trueAirspeed,
              flightRules: updated.flightRules,
              routeString: updated.routeString,
              cruiseAltitude: updated.cruiseAltitude,
              peopleCount: updated.peopleCount,
              avgPersonWeight: updated.avgPersonWeight,
              cargoWeight: updated.cargoWeight,
              fuelPolicy: updated.fuelPolicy,
              startFuelGallons: updated.startFuelGallons,
              reserveFuelGallons: updated.reserveFuelGallons,
              fuelBurnRate: updated.fuelBurnRate,
              fuelAtShutdownGallons: updated.fuelAtShutdownGallons,
              filingStatus: updated.filingStatus,
              // Computed fields from API (may be null)
              distanceNm: (result['distance_nm'] as num?)?.toDouble(),
              eteMinutes: result['ete_minutes'] as int?,
              flightFuelGallons:
                  (result['flight_fuel_gallons'] as num?)?.toDouble(),
              eta: result['eta'] as String?,
              calculatedAt: result['calculated_at'] as String?,
            ));
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

  Future<void> _editTextField({
    required String title,
    required String? currentValue,
    required Flight Function(String) updater,
    String? hint,
  }) async {
    final result = await showTextEditSheet(
      context,
      title: title,
      currentValue: currentValue ?? '',
      hintText: hint,
    );
    if (result != null && result != currentValue) {
      _saveField(updater(result));
    }
  }

  /// Parse waypoints from routeString (space-separated identifiers).
  List<String> _parseWaypoints(Flight? flight) {
    final route = flight?.routeString;
    if (route == null || route.trim().isEmpty) return [];
    return route.trim().split(RegExp(r'\s+'));
  }

  /// Build routeString from waypoints list, and sync dep/dest fields.
  Flight _buildRouteUpdate(Flight flight, List<String> waypoints) {
    final routeStr = waypoints.join(' ');
    return flight.copyWith(
      routeString: routeStr.isEmpty ? '' : routeStr,
      departureIdentifier: waypoints.isNotEmpty ? waypoints.first : '',
      destinationIdentifier:
          waypoints.length > 1 ? waypoints.last : (waypoints.isNotEmpty ? waypoints.first : ''),
    );
  }

  Future<void> _addWaypoint(Flight? flight) async {
    final result = await showTextEditSheet(
      context,
      title: 'Add Waypoint',
      currentValue: '',
      hintText: 'Airport or waypoint identifier',
    );
    if (result != null && result.trim().isNotEmpty) {
      final f = flight ?? const Flight();
      final wps = _parseWaypoints(f);
      wps.add(result.trim().toUpperCase());
      _saveField(_buildRouteUpdate(f, wps));
    }
  }

  Future<void> _editWaypoint(Flight flight, int index) async {
    final wps = _parseWaypoints(flight);
    if (index >= wps.length) return;

    final action = await showModalBottomSheet<String>(
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
            Text(wps[index],
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                )),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.edit, color: AppColors.textSecondary),
              title: const Text('Edit',
                  style: TextStyle(color: AppColors.textPrimary)),
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.error),
              title: const Text('Remove',
                  style: TextStyle(color: AppColors.error)),
              onTap: () => Navigator.pop(ctx, 'remove'),
            ),
          ],
        ),
      ),
    );

    if (!mounted) return;
    if (action == 'edit') {
      final result = await showTextEditSheet(
        context,
        title: 'Edit Waypoint',
        currentValue: wps[index],
        hintText: 'Airport or waypoint identifier',
      );
      if (result != null && result.trim().isNotEmpty) {
        wps[index] = result.trim().toUpperCase();
        _saveField(_buildRouteUpdate(flight, wps));
      }
    } else if (action == 'remove') {
      wps.removeAt(index);
      _saveField(_buildRouteUpdate(flight, wps));
    }
  }

  void _swapRoute() {
    final flight = _flight;
    if (flight == null) return;
    final wps = _parseWaypoints(flight);
    if (wps.length < 2) return;
    _saveField(_buildRouteUpdate(flight, wps.reversed.toList()));
  }

  void _clearFlight() {
    ref.read(activeFlightProvider.notifier).clear();
  }

  Future<void> _openRouteFinder(Flight? flight, List<String> waypoints) async {
    if (waypoints.length < 2) return;
    final origin = waypoints.first;
    final destination = waypoints.last;
    final result = await showPreferredRouteSheet(
      context,
      origin: origin,
      destination: destination,
    );
    if (result != null && flight != null) {
      _saveField(flight.copyWith(routeString: result.routeString));
    }
  }

  /// Estimate the pixel width of a waypoint chip + arrow.
  static double _chipWidth(String label) {
    // ~8.5px per character at fontSize 14 w700, plus 24px horizontal padding, plus 6px gap
    return label.length * 8.5 + 24 + 6;
  }

  static const _arrowWidth = 22.0; // " → " text width + spacing

  /// Build a collapsed list of waypoint chips that fits within [maxWidth].
  /// Always shows first and last. Fills intermediate from the start, then
  /// collapses remaining into a "..." chip.
  List<Widget> _buildCollapsedWaypoints(
      List<String> waypoints, double maxWidth, Flight? flight) {
    if (waypoints.isEmpty) return [];
    if (waypoints.length == 1) {
      return [_waypointChip(waypoints[0], 0, flight)];
    }

    final firstW = _chipWidth(waypoints.first);
    final lastW = _chipWidth(waypoints.last);
    const ellipsisW = 40.0; // "..." chip width
    // Reserve space for first, last, and arrows between them
    final reserved = firstW + _arrowWidth + lastW;

    if (waypoints.length == 2 || reserved > maxWidth) {
      // Only room for first → last
      return [
        _waypointChip(waypoints.first, 0, flight),
        _arrowSeparator(),
        _waypointChip(waypoints.last, waypoints.length - 1, flight),
      ];
    }

    // Try to fit intermediate waypoints from the start
    var used = reserved;
    var fitCount = 0;
    for (var i = 1; i < waypoints.length - 1; i++) {
      final w = _arrowWidth + _chipWidth(waypoints[i]);
      // If not all intermediates fit, we need room for the ellipsis chip too
      final needEllipsis = i + 1 < waypoints.length - 1;
      final extra = needEllipsis ? _arrowWidth + ellipsisW : 0;
      if (used + w + extra > maxWidth) break;
      used += w;
      fitCount++;
    }

    final intermediateCount = waypoints.length - 2;
    if (fitCount >= intermediateCount) {
      // All fit — show everything
      final chips = <Widget>[_waypointChip(waypoints.first, 0, flight)];
      for (var i = 1; i < waypoints.length - 1; i++) {
        chips.add(_arrowSeparator());
        chips.add(_waypointChip(waypoints[i], i, flight));
      }
      chips.add(_arrowSeparator());
      chips.add(_waypointChip(waypoints.last, waypoints.length - 1, flight));
      return chips;
    }

    // Show first, fitCount intermediates, ellipsis, last
    final chips = <Widget>[_waypointChip(waypoints.first, 0, flight)];
    for (var i = 1; i <= fitCount; i++) {
      chips.add(_arrowSeparator());
      chips.add(_waypointChip(waypoints[i], i, flight));
    }
    chips.add(_arrowSeparator());
    chips.add(_ellipsisChip(waypoints, flight));
    chips.add(_arrowSeparator());
    chips.add(_waypointChip(waypoints.last, waypoints.length - 1, flight));
    return chips;
  }

  Widget _waypointChip(String label, int index, Flight? flight) {
    return GestureDetector(
      onTap: flight != null ? () => _editWaypoint(flight, index) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _ellipsisChip(List<String> waypoints, Flight? flight) {
    final hidden = waypoints.length - 2;
    return GestureDetector(
      onTap: () {
        // Show full route editor
        if (flight?.id != null) {
          context.push('/flights/${flight!.id}');
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '+$hidden',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _arrowSeparator() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 2),
      child: Icon(Icons.arrow_forward, size: 14, color: AppColors.textMuted),
    );
  }

  String _formatEte(int? minutes) {
    if (minutes == null) return '--';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h}h${m.toString().padLeft(2, '0')}m';
  }

  String _formatEta(String? eta) {
    if (eta == null) return '--';
    try {
      final dt = DateTime.parse(eta).toLocal();
      final h = dt.hour;
      final m = dt.minute.toString().padLeft(2, '0');
      final period = h >= 12 ? 'pm' : 'am';
      final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
      return '$hour12:$m$period';
    } catch (_) {
      return eta;
    }
  }

  void _showAircraftPicker(Flight? flight) {
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
                          style: const TextStyle(color: AppColors.textPrimary)),
                      subtitle: Text(a.aircraftType,
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 13)),
                      trailing: a.id == flight?.aircraftId
                          ? const Icon(Icons.check,
                              color: AppColors.accent, size: 20)
                          : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        final defaultProfile = a.defaultProfile;
                        _saveField((flight ?? const Flight()).copyWith(
                          aircraftId: a.id,
                          aircraftIdentifier: a.tailNumber,
                          aircraftType: a.aircraftType,
                          performanceProfileId: defaultProfile?.id,
                          performanceProfile: defaultProfile?.name,
                          trueAirspeed: defaultProfile?.cruiseTas?.round(),
                          fuelBurnRate: defaultProfile?.cruiseFuelBurn,
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

  void _showProfilePicker(Flight? flight) {
    if (flight?.aircraftId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select an aircraft first'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    final detailAsync = ref.read(aircraftDetailProvider(flight!.aircraftId!));
    detailAsync.when(
      loading: () {},
      error: (_, _) {},
      data: (aircraft) {
        if (aircraft == null) return;
        final profiles = aircraft.performanceProfiles;
        if (profiles.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('No profiles. Add one in the Aircraft tab.'),
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
                          style:
                              const TextStyle(color: AppColors.textPrimary)),
                      subtitle: Text(
                          '${p.cruiseTas?.round() ?? '--'} kt / ${p.cruiseFuelBurn ?? '--'} GPH',
                          style: const TextStyle(
                              color: AppColors.textSecondary, fontSize: 13)),
                      trailing: p.id == flight.performanceProfileId
                          ? const Icon(Icons.check,
                              color: AppColors.accent, size: 20)
                          : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        _saveField(flight.copyWith(
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

  String _formatAltitudeChip(int ft) {
    if (ft >= 18000) return 'FL${ft ~/ 100}';
    final s = ft.toString();
    if (s.length <= 3) return "$s'";
    return "${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}'";
  }

  Future<void> _showAltitudePicker(Flight? flight) async {
    final api = ref.read(apiClientProvider);
    final result = await showAltitudePickerSheet(
      context,
      apiClient: api,
      currentAltitude: flight?.cruiseAltitude,
      departureIdentifier: flight?.departureIdentifier,
      destinationIdentifier: flight?.destinationIdentifier,
      routeString: flight?.routeString,
      trueAirspeed: flight?.trueAirspeed,
      fuelBurnRate: flight?.fuelBurnRate,
      performanceProfileId: flight?.performanceProfileId,
    );
    if (result != null) {
      _saveField(
          (flight ?? const Flight()).copyWith(cruiseAltitude: result));
    }
  }

  /// Build a Flight pre-populated with the given aircraft & its default profile.
  static Flight _flightFromAircraft(Aircraft aircraft) {
    final dp = aircraft.defaultProfile;
    return Flight(
      etd: DateTime.now().toIso8601String(),
      aircraftId: aircraft.id,
      aircraftIdentifier: aircraft.tailNumber,
      aircraftType: aircraft.aircraftType,
      performanceProfileId: dp?.id,
      performanceProfile: dp?.name,
      trueAirspeed: dp?.cruiseTas?.round(),
      fuelBurnRate: dp?.cruiseFuelBurn,
    );
  }

  @override
  Widget build(BuildContext context) {
    var flight = ref.watch(activeFlightProvider);

    // When no active flight, seed from the default aircraft
    if (flight == null) {
      final defaultAircraft = ref.watch(defaultAircraftProvider).value;
      if (defaultAircraft != null) {
        flight = _flightFromAircraft(defaultAircraft);
        // Push into provider so subsequent interactions use this flight
        Future.microtask(() {
          ref.read(activeFlightProvider.notifier).set(flight);
        });
      }
    }

    final waypoints = _parseWaypoints(flight);

    return Container(
      color: AppColors.surface.withValues(alpha: 0.98),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Metadata chips row 1
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            child: Row(
              children: [
                Expanded(
                  child: _MetadataChip(
                    label: flight?.aircraftIdentifier ?? 'Tail #',
                    onTap: () => _showAircraftPicker(flight),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _MetadataChip(
                    label: flight?.performanceProfile ?? 'Performance',
                    onTap: () => _showProfilePicker(flight),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _MetadataChip(
                    label: flight?.cruiseAltitude != null
                        ? _formatAltitudeChip(flight!.cruiseAltitude!)
                        : 'Altitude',
                    onTap: () => _showAltitudePicker(flight),
                  ),
                ),
              ],
            ),
          ),

          // Metadata chips row 2
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            child: Row(
              children: [
                Expanded(
                  child: _MetadataChip(
                    label: 'Procedure',
                    onTap: () => _editTextField(
                      title: 'Procedure',
                      currentValue: '',
                      updater: (val) => flight ?? const Flight(),
                      hint: 'Procedure type',
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _MetadataChip(
                    label: flight?.routeString != null
                        ? 'Routes'
                        : 'Routes',
                    onTap: () => _editTextField(
                      title: 'Route String',
                      currentValue: flight?.routeString,
                      updater: (val) =>
                          (flight ?? const Flight()).copyWith(
                            routeString: val.toUpperCase(),
                          ),
                      hint: 'e.g. DCT ABB V16 ETX',
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _MetadataChip(
                    label: flight?.etd != null ? 'ETD' : 'ETD',
                    onTap: () async {
                      final dt = await showDateTimePickerSheet(
                        context,
                        title: 'Estimated Time of Departure',
                        initialDate: flight?.etd != null
                            ? DateTime.tryParse(flight!.etd!)
                            : null,
                      );
                      if (dt != null) {
                        _saveField(
                          (flight ?? const Flight()).copyWith(
                            etd: dt.toIso8601String(),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.divider),

          // Route waypoint chips (collapsed when too many)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
            child: SizedBox(
              height: 34,
              child: Row(
                children: [
                  Expanded(
                    child: waypoints.isEmpty
                        ? const SizedBox.shrink()
                        : LayoutBuilder(
                            builder: (context, constraints) {
                              final chips = _buildCollapsedWaypoints(
                                waypoints,
                                constraints.maxWidth,
                                flight,
                              );
                              return Row(children: chips);
                            },
                          ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => _addWaypoint(flight),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.add,
                          size: 16, color: AppColors.textMuted),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Swap / Clear / Find Route row
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
            child: Row(
              children: [
                // Find Route button
                GestureDetector(
                  onTap: waypoints.length >= 2
                      ? () => _openRouteFinder(flight, waypoints)
                      : null,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.alt_route,
                            size: 14,
                            color: waypoints.length >= 2
                                ? AppColors.accent
                                : AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text(
                          'Find Route',
                          style: TextStyle(
                            color: waypoints.length >= 2
                                ? AppColors.accent
                                : AppColors.textMuted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                if (_saving)
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ),
                GestureDetector(
                  onTap: _swapRoute,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.swap_horiz,
                        size: 18, color: AppColors.textSecondary),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _clearFlight,
                  child: Text(
                    'Clear',
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.divider),

          // Stats bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                _StatItem(
                  label: 'DIST',
                  value: flight?.distanceNm != null
                      ? '${flight!.distanceNm!.toStringAsFixed(0)} nm'
                      : '--',
                ),
                _StatItem(
                  label: 'ETE',
                  value: _formatEte(flight?.eteMinutes),
                ),
                _StatItem(
                  label: 'ETA',
                  value: _formatEta(flight?.eta),
                ),
                _StatItem(
                  label: 'FUEL',
                  value: flight?.flightFuelGallons != null
                      ? '${flight!.flightFuelGallons!.toStringAsFixed(1)}g'
                      : '--',
                ),
                _StatItem(
                  label: 'WIND',
                  value: flight?.windComponent != null
                      ? '${flight!.windComponent!.toStringAsFixed(0)}kts'
                      : '--',
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: AppColors.divider),

          // Bottom action bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                _ActionIcon(icon: Icons.settings, onTap: () {}),
                _ActionIcon(icon: Icons.flag, onTap: () {}),
                _ActionIcon(icon: Icons.star_border, onTap: () {}),
                _ActionIcon(icon: Icons.share, onTap: () {}),
                const Spacer(),
                _TabButton(
                  label: 'Edit',
                  onTap: () {
                    if (flight?.id != null) {
                      context.push('/flights/${flight!.id}');
                    } else {
                      context.push('/flights/new');
                    }
                  },
                ),
                const SizedBox(width: 4),
                _TabButton(
                  label: 'NavLog',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('NavLog coming soon')),
                    );
                  },
                ),
                const SizedBox(width: 4),
                _TabButton(
                  label: 'Profile',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Profile coming soon')),
                    );
                  },
                ),
              ],
            ),
          ),

          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: AppColors.textMuted,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetadataChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _MetadataChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ActionIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 20, color: AppColors.textSecondary),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TabButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
