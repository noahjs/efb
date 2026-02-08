import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/map_flight_provider.dart';

class MapBottomBar extends ConsumerWidget {
  const MapBottomBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final flight = ref.watch(activeFlightProvider);

    return Container(
      color: AppColors.surface.withValues(alpha: 0.95),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SafeArea(
        top: false,
        child: flight == null
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.info_outline,
                      size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    'No active flight plan',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  Flexible(
                    child: _RouteLabel(
                        route: flight.routeString ?? ''),
                  ),
                  const Spacer(),
                  if (flight.distanceNm != null)
                    _BarStat(
                        label: 'DIST',
                        value: '${flight.distanceNm!.toStringAsFixed(0)}nm'),
                  if (flight.eteMinutes != null)
                    _BarStat(
                        label: 'ETE',
                        value:
                            '${flight.eteMinutes! ~/ 60}h${(flight.eteMinutes! % 60).toString().padLeft(2, '0')}m'),
                  if (flight.flightFuelGallons != null)
                    _BarStat(
                        label: 'FUEL',
                        value:
                            '${flight.flightFuelGallons!.toStringAsFixed(1)}g'),
                ],
              ),
      ),
    );
  }
}

class _RouteLabel extends StatelessWidget {
  final String route;

  const _RouteLabel({required this.route});

  @override
  Widget build(BuildContext context) {
    final wps = route.trim().isEmpty
        ? <String>[]
        : route.trim().split(RegExp(r'\s+'));
    if (wps.isEmpty) {
      return Text('----',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ));
    }
    final children = <Widget>[];
    for (var i = 0; i < wps.length; i++) {
      if (i > 0) {
        children.add(const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child:
              Icon(Icons.arrow_forward, size: 12, color: AppColors.textMuted),
        ));
      }
      children.add(Text(
        wps[i],
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ));
    }
    return Row(mainAxisSize: MainAxisSize.min, children: children);
  }
}

class _BarStat extends StatelessWidget {
  final String label;
  final String value;

  const _BarStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12),
      child: Row(
        children: [
          Text(
            '$label ',
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
