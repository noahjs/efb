import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../models/briefing.dart';

class DestinationWeatherDetail extends StatelessWidget {
  final Briefing briefing;

  const DestinationWeatherDetail({super.key, required this.briefing});

  @override
  Widget build(BuildContext context) {
    final metars = briefing.currentWeather.metars;
    final tafs = briefing.forecasts.tafs;

    final destMetar = metars.where((m) => m.section == 'destination').firstOrNull;
    final destTaf = tafs.where((t) => t.section == 'destination').firstOrNull;
    final depMetar = metars.where((m) => m.section == 'departure').firstOrNull;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Destination & Alternate',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        // Departure weather summary
        if (depMetar != null)
          _StationWeatherCard(
            label: 'Departure',
            metar: depMetar,
          ),
        const SizedBox(height: 12),
        // Destination METAR
        if (destMetar != null)
          _StationWeatherCard(
            label: 'Destination',
            metar: destMetar,
          ),
        // Destination TAF
        if (destTaf != null) ...[
          const SizedBox(height: 12),
          _TafCard(
            taf: destTaf,
            eta: briefing.flight.eta,
          ),
        ],
        // No data
        if (destMetar == null && destTaf == null)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Center(
              child: Text(
                'No destination weather available',
                style: TextStyle(color: AppColors.textMuted),
              ),
            ),
          ),
      ],
    );
  }
}

class _StationWeatherCard extends StatelessWidget {
  final String label;
  final BriefingMetar metar;

  const _StationWeatherCard({required this.label, required this.metar});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '$label - ${metar.icaoId}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              if (metar.flightCategory != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _flightCatColor(metar.flightCategory),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    metar.flightCategory!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Parsed weather data
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: [
              if (metar.ceiling != null)
                _DataItem(label: 'Ceiling', value: '${metar.ceiling} ft'),
              if (metar.visib != null)
                _DataItem(
                    label: 'Visibility',
                    value: '${metar.visib!.toStringAsFixed(0)} SM'),
              if (metar.wdir != null && metar.wspd != null)
                _DataItem(
                  label: 'Wind',
                  value:
                      '${metar.wdir.toString().padLeft(3, '0')}/${metar.wspd}kt${metar.wgst != null ? 'G${metar.wgst}' : ''}',
                ),
              if (metar.temp != null && metar.dewp != null)
                _DataItem(
                  label: 'Temp/Dew',
                  value:
                      '${metar.temp!.round()}/${metar.dewp!.round()}',
                ),
              if (metar.altim != null)
                _DataItem(
                    label: 'Altimeter',
                    value: metar.altim!.toStringAsFixed(2)),
            ],
          ),
          // Clouds
          if (metar.clouds.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Clouds: ${metar.clouds.map((c) => '${c.cover}${c.base != null ? " ${c.base}" : ""}').join(', ')}',
              style:
                  const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
          // Raw METAR
          if (metar.rawOb != null && metar.rawOb!.isNotEmpty) ...[
            const Divider(color: AppColors.divider, height: 16),
            Text(
              metar.rawOb!,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TafCard extends StatelessWidget {
  final BriefingTaf taf;
  final String? eta;

  const _TafCard({required this.taf, this.eta});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TAF ${taf.icaoId}',
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          // Forecast periods
          if (taf.fcsts.isNotEmpty)
            ...taf.fcsts.map((f) {
              final isEtaPeriod = _isEtaPeriod(f, eta);
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isEtaPeriod
                      ? AppColors.primary.withAlpha(30)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: isEtaPeriod
                      ? Border.all(color: AppColors.primary, width: 1)
                      : null,
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 50,
                      child: Text(
                        f.changeType,
                        style: TextStyle(
                          color: isEtaPeriod
                              ? AppColors.primary
                              : AppColors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (f.fltCat != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: _flightCatColor(f.fltCat),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Text(
                          f.fltCat!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (f.wspd != null)
                      Text(
                        '${f.wdir ?? "VRB"}/${f.wspd}kt${f.wgst != null ? "G${f.wgst}" : ""}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    if (f.visib != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '${f.visib!.toStringAsFixed(0)}SM',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                    if (isEtaPeriod) ...[
                      const Spacer(),
                      const Text(
                        'ETA',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
          // Raw TAF
          if (taf.rawTaf != null && taf.rawTaf!.isNotEmpty) ...[
            const Divider(color: AppColors.divider, height: 16),
            Text(
              taf.rawTaf!,
              style: const TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _isEtaPeriod(TafForecastPeriod period, String? etaIso) {
    if (etaIso == null || period.timeFrom.isEmpty || period.timeTo.isEmpty) {
      return false;
    }
    final eta = DateTime.tryParse(etaIso);
    final from = DateTime.tryParse(period.timeFrom);
    final to = DateTime.tryParse(period.timeTo);
    if (eta == null || from == null || to == null) return false;
    return eta.isAfter(from) && eta.isBefore(to);
  }
}

class _DataItem extends StatelessWidget {
  final String label;
  final String value;

  const _DataItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 10),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

Color _flightCatColor(String? cat) {
  switch (cat?.toUpperCase()) {
    case 'VFR':
      return AppColors.vfr;
    case 'MVFR':
      return AppColors.mvfr;
    case 'IFR':
      return AppColors.ifr;
    case 'LIFR':
      return AppColors.lifr;
    default:
      return AppColors.textMuted;
  }
}
