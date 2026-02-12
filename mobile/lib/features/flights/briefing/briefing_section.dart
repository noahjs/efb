import 'package:flutter/material.dart';

import '../../../models/briefing.dart';

enum BriefingSection {
  // Overview
  riskSummary,
  routeTimeline,

  // Destination
  destinationWeather,

  // Hazards
  tfrs,
  convectiveSigmets,
  sigmets,
  airmetIcing,
  airmetTurbulence,
  airmetIfr,
  airmetMtnObsc,
  urgentPireps,

  // NOTAMs
  notamsDeparture,
  notamsDestination,
  notamsEnroute,
  notamsArtcc,

  // Details (raw data)
  metars,
  tafs,
  pireps,
  windsAloft,
  gfaClouds,
  gfaSurface,
  synopsis,
}

extension BriefingSectionExtension on BriefingSection {
  String get label {
    switch (this) {
      case BriefingSection.riskSummary:
        return 'Risk Summary';
      case BriefingSection.routeTimeline:
        return 'Route Timeline';
      case BriefingSection.destinationWeather:
        return 'Destination & Alternate';
      case BriefingSection.tfrs:
        return 'TFRs';
      case BriefingSection.convectiveSigmets:
        return 'Convective SIGMETs';
      case BriefingSection.sigmets:
        return 'SIGMETs';
      case BriefingSection.airmetIcing:
        return 'AIRMET Icing';
      case BriefingSection.airmetTurbulence:
        return 'AIRMET Turbulence';
      case BriefingSection.airmetIfr:
        return 'AIRMET IFR';
      case BriefingSection.airmetMtnObsc:
        return 'AIRMET Mtn Obsc';
      case BriefingSection.urgentPireps:
        return 'Urgent PIREPs';
      case BriefingSection.notamsDeparture:
        return 'Departure NOTAMs';
      case BriefingSection.notamsDestination:
        return 'Destination NOTAMs';
      case BriefingSection.notamsEnroute:
        return 'Enroute NOTAMs';
      case BriefingSection.notamsArtcc:
        return 'ARTCC NOTAMs';
      case BriefingSection.metars:
        return 'METARs';
      case BriefingSection.tafs:
        return 'TAFs';
      case BriefingSection.pireps:
        return 'PIREPs';
      case BriefingSection.windsAloft:
        return 'Winds Aloft';
      case BriefingSection.gfaClouds:
        return 'GFA Clouds';
      case BriefingSection.gfaSurface:
        return 'GFA Surface';
      case BriefingSection.synopsis:
        return 'Synopsis';
    }
  }

  IconData get icon {
    switch (this) {
      case BriefingSection.riskSummary:
        return Icons.shield_outlined;
      case BriefingSection.routeTimeline:
        return Icons.timeline;
      case BriefingSection.destinationWeather:
        return Icons.flight_land;
      case BriefingSection.tfrs:
        return Icons.block;
      case BriefingSection.convectiveSigmets:
        return Icons.thunderstorm;
      case BriefingSection.sigmets:
        return Icons.warning_amber;
      case BriefingSection.airmetIcing:
        return Icons.ac_unit;
      case BriefingSection.airmetTurbulence:
        return Icons.waves;
      case BriefingSection.airmetIfr:
        return Icons.visibility_off;
      case BriefingSection.airmetMtnObsc:
        return Icons.terrain;
      case BriefingSection.urgentPireps:
        return Icons.report;
      case BriefingSection.notamsDeparture:
      case BriefingSection.notamsDestination:
      case BriefingSection.notamsEnroute:
      case BriefingSection.notamsArtcc:
        return Icons.description;
      case BriefingSection.metars:
        return Icons.cloud;
      case BriefingSection.tafs:
        return Icons.schedule;
      case BriefingSection.pireps:
        return Icons.flight;
      case BriefingSection.windsAloft:
        return Icons.trending_up;
      case BriefingSection.gfaClouds:
        return Icons.cloud_queue;
      case BriefingSection.gfaSurface:
        return Icons.air;
      case BriefingSection.synopsis:
        return Icons.map_outlined;
    }
  }

  int getItemCount(Briefing briefing) {
    switch (this) {
      case BriefingSection.riskSummary:
        return briefing.riskSummary != null ? 1 : 0;
      case BriefingSection.routeTimeline:
        return briefing.routeTimeline.isNotEmpty ? 1 : 0;
      case BriefingSection.destinationWeather:
        return briefing.currentWeather.metars
                .any((m) => m.section == 'destination')
            ? 1
            : 0;
      case BriefingSection.tfrs:
        return briefing.adverseConditions.tfrs.length;
      case BriefingSection.convectiveSigmets:
        return briefing.adverseConditions.convectiveSigmets.length;
      case BriefingSection.sigmets:
        return briefing.adverseConditions.sigmets.length;
      case BriefingSection.airmetIcing:
        return briefing.adverseConditions.airmets.icing.length;
      case BriefingSection.airmetTurbulence:
        return briefing.adverseConditions.airmets.turbulenceLow.length +
            briefing.adverseConditions.airmets.turbulenceHigh.length;
      case BriefingSection.airmetIfr:
        return briefing.adverseConditions.airmets.ifr.length;
      case BriefingSection.airmetMtnObsc:
        return briefing.adverseConditions.airmets.mountainObscuration.length;
      case BriefingSection.urgentPireps:
        return briefing.adverseConditions.urgentPireps.length;
      case BriefingSection.notamsDeparture:
        return briefing.notams.departure?.totalCount ?? 0;
      case BriefingSection.notamsDestination:
        return briefing.notams.destination?.totalCount ?? 0;
      case BriefingSection.notamsEnroute:
        return briefing.notams.enroute.totalCount;
      case BriefingSection.notamsArtcc:
        return briefing.notams.artcc.fold<int>(
            0, (sum, a) => sum + a.totalCount);
      case BriefingSection.metars:
        return briefing.currentWeather.metars.length;
      case BriefingSection.tafs:
        return briefing.forecasts.tafs.length;
      case BriefingSection.pireps:
        return briefing.currentWeather.pireps.length;
      case BriefingSection.windsAloft:
        return briefing.forecasts.windsAloftTable != null ? 1 : 0;
      case BriefingSection.gfaClouds:
        return briefing.forecasts.gfaCloudProducts.length;
      case BriefingSection.gfaSurface:
        return briefing.forecasts.gfaSurfaceProducts.length;
      case BriefingSection.synopsis:
        return 1;
    }
  }

  String get groupLabel {
    switch (this) {
      case BriefingSection.riskSummary:
      case BriefingSection.routeTimeline:
        return 'OVERVIEW';
      case BriefingSection.destinationWeather:
        return 'DESTINATION';
      case BriefingSection.tfrs:
      case BriefingSection.convectiveSigmets:
      case BriefingSection.sigmets:
      case BriefingSection.airmetIcing:
      case BriefingSection.airmetTurbulence:
      case BriefingSection.airmetIfr:
      case BriefingSection.airmetMtnObsc:
      case BriefingSection.urgentPireps:
        return 'HAZARDS';
      case BriefingSection.notamsDeparture:
      case BriefingSection.notamsDestination:
      case BriefingSection.notamsEnroute:
      case BriefingSection.notamsArtcc:
        return 'NOTAMS';
      case BriefingSection.metars:
      case BriefingSection.tafs:
      case BriefingSection.pireps:
      case BriefingSection.windsAloft:
      case BriefingSection.gfaClouds:
      case BriefingSection.gfaSurface:
      case BriefingSection.synopsis:
        return 'DETAILS';
    }
  }
}

/// All sections in briefing order, used for sequential navigation.
const allBriefingSections = BriefingSection.values;
