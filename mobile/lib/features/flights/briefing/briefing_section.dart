import 'package:flutter/material.dart';

import '../../../models/briefing.dart';

enum BriefingSection {
  // Adverse Conditions
  tfrs,
  closedUnsafe,
  convectiveSigmets,
  sigmets,
  airmetIfr,
  airmetMtnObsc,
  airmetIcing,
  airmetTurbLow,
  airmetTurbHigh,
  airmetLlws,
  airmetOther,
  urgentPireps,

  // Synopsis
  synopsis,

  // Current Weather
  metars,
  pireps,

  // Forecasts
  gfaClouds,
  gfaSurface,
  tafs,
  windsAloft,

  // NOTAMs
  notamsDeparture,
  notamsDestination,
  notamsAlternate1,
  notamsEnrouteNav,
  notamsEnrouteCom,
  notamsEnrouteSvc,
  notamsEnrouteAirspace,
  notamsEnrouteSua,
  notamsEnrouteRwyFdc,
  notamsEnrouteOther,
  notamsArtcc,
}

extension BriefingSectionExtension on BriefingSection {
  String get label {
    switch (this) {
      case BriefingSection.tfrs:
        return 'TFRs';
      case BriefingSection.closedUnsafe:
        return 'Closed/Unsafe';
      case BriefingSection.convectiveSigmets:
        return 'Convective SIGMETs';
      case BriefingSection.sigmets:
        return 'SIGMETs';
      case BriefingSection.airmetIfr:
        return 'AIRMET IFR';
      case BriefingSection.airmetMtnObsc:
        return 'AIRMET Mtn Obsc';
      case BriefingSection.airmetIcing:
        return 'AIRMET Icing';
      case BriefingSection.airmetTurbLow:
        return 'AIRMET Turb Low';
      case BriefingSection.airmetTurbHigh:
        return 'AIRMET Turb High';
      case BriefingSection.airmetLlws:
        return 'AIRMET LLWS';
      case BriefingSection.airmetOther:
        return 'AIRMET Other';
      case BriefingSection.urgentPireps:
        return 'Urgent PIREPs';
      case BriefingSection.synopsis:
        return 'Synopsis';
      case BriefingSection.metars:
        return 'METARs';
      case BriefingSection.pireps:
        return 'PIREPs';
      case BriefingSection.gfaClouds:
        return 'GFA Clouds';
      case BriefingSection.gfaSurface:
        return 'GFA Surface';
      case BriefingSection.tafs:
        return 'TAFs';
      case BriefingSection.windsAloft:
        return 'Winds Aloft';
      case BriefingSection.notamsDeparture:
        return 'Departure NOTAMs';
      case BriefingSection.notamsDestination:
        return 'Destination NOTAMs';
      case BriefingSection.notamsAlternate1:
        return 'Alternate NOTAMs';
      case BriefingSection.notamsEnrouteNav:
        return 'Enroute Navigation';
      case BriefingSection.notamsEnrouteCom:
        return 'Enroute Communication';
      case BriefingSection.notamsEnrouteSvc:
        return 'Enroute Service';
      case BriefingSection.notamsEnrouteAirspace:
        return 'Enroute Airspace';
      case BriefingSection.notamsEnrouteSua:
        return 'Enroute SUA';
      case BriefingSection.notamsEnrouteRwyFdc:
        return 'Enroute Rwy/FDC';
      case BriefingSection.notamsEnrouteOther:
        return 'Enroute Other';
      case BriefingSection.notamsArtcc:
        return 'ARTCC NOTAMs';
    }
  }

  IconData get icon {
    switch (this) {
      case BriefingSection.tfrs:
        return Icons.block;
      case BriefingSection.closedUnsafe:
        return Icons.dangerous;
      case BriefingSection.convectiveSigmets:
        return Icons.thunderstorm;
      case BriefingSection.sigmets:
        return Icons.warning_amber;
      case BriefingSection.airmetIfr:
        return Icons.visibility_off;
      case BriefingSection.airmetMtnObsc:
        return Icons.terrain;
      case BriefingSection.airmetIcing:
        return Icons.ac_unit;
      case BriefingSection.airmetTurbLow:
      case BriefingSection.airmetTurbHigh:
        return Icons.waves;
      case BriefingSection.airmetLlws:
        return Icons.air;
      case BriefingSection.airmetOther:
        return Icons.info_outline;
      case BriefingSection.urgentPireps:
        return Icons.report;
      case BriefingSection.synopsis:
        return Icons.map_outlined;
      case BriefingSection.metars:
        return Icons.cloud;
      case BriefingSection.pireps:
        return Icons.flight;
      case BriefingSection.gfaClouds:
        return Icons.cloud_queue;
      case BriefingSection.gfaSurface:
        return Icons.air;
      case BriefingSection.tafs:
        return Icons.schedule;
      case BriefingSection.windsAloft:
        return Icons.trending_up;
      case BriefingSection.notamsDeparture:
      case BriefingSection.notamsDestination:
      case BriefingSection.notamsAlternate1:
      case BriefingSection.notamsEnrouteNav:
      case BriefingSection.notamsEnrouteCom:
      case BriefingSection.notamsEnrouteSvc:
      case BriefingSection.notamsEnrouteAirspace:
      case BriefingSection.notamsEnrouteSua:
      case BriefingSection.notamsEnrouteRwyFdc:
      case BriefingSection.notamsEnrouteOther:
      case BriefingSection.notamsArtcc:
        return Icons.description;
    }
  }

  int getItemCount(Briefing briefing) {
    switch (this) {
      case BriefingSection.tfrs:
        return briefing.adverseConditions.tfrs.length;
      case BriefingSection.closedUnsafe:
        return briefing.adverseConditions.closedUnsafeNotams.length;
      case BriefingSection.convectiveSigmets:
        return briefing.adverseConditions.convectiveSigmets.length;
      case BriefingSection.sigmets:
        return briefing.adverseConditions.sigmets.length;
      case BriefingSection.airmetIfr:
        return briefing.adverseConditions.airmets.ifr.length;
      case BriefingSection.airmetMtnObsc:
        return briefing.adverseConditions.airmets.mountainObscuration.length;
      case BriefingSection.airmetIcing:
        return briefing.adverseConditions.airmets.icing.length;
      case BriefingSection.airmetTurbLow:
        return briefing.adverseConditions.airmets.turbulenceLow.length;
      case BriefingSection.airmetTurbHigh:
        return briefing.adverseConditions.airmets.turbulenceHigh.length;
      case BriefingSection.airmetLlws:
        return briefing.adverseConditions.airmets.lowLevelWindShear.length;
      case BriefingSection.airmetOther:
        return briefing.adverseConditions.airmets.other.length;
      case BriefingSection.urgentPireps:
        return briefing.adverseConditions.urgentPireps.length;
      case BriefingSection.synopsis:
        return 1;
      case BriefingSection.metars:
        return briefing.currentWeather.metars.length;
      case BriefingSection.pireps:
        return briefing.currentWeather.pireps.length;
      case BriefingSection.gfaClouds:
        return briefing.forecasts.gfaCloudProducts.length;
      case BriefingSection.gfaSurface:
        return briefing.forecasts.gfaSurfaceProducts.length;
      case BriefingSection.tafs:
        return briefing.forecasts.tafs.length;
      case BriefingSection.windsAloft:
        return briefing.forecasts.windsAloftTable != null ? 1 : 0;
      case BriefingSection.notamsDeparture:
        return briefing.notams.departure?.totalCount ?? 0;
      case BriefingSection.notamsDestination:
        return briefing.notams.destination?.totalCount ?? 0;
      case BriefingSection.notamsAlternate1:
        return briefing.notams.alternate1?.totalCount ?? 0;
      case BriefingSection.notamsEnrouteNav:
        return briefing.notams.enroute.navigation.length;
      case BriefingSection.notamsEnrouteCom:
        return briefing.notams.enroute.communication.length;
      case BriefingSection.notamsEnrouteSvc:
        return briefing.notams.enroute.svc.length;
      case BriefingSection.notamsEnrouteAirspace:
        return briefing.notams.enroute.airspace.length;
      case BriefingSection.notamsEnrouteSua:
        return briefing.notams.enroute.specialUseAirspace.length;
      case BriefingSection.notamsEnrouteRwyFdc:
        return briefing.notams.enroute.rwyTwyApronAdFdc.length;
      case BriefingSection.notamsEnrouteOther:
        return briefing.notams.enroute.otherUnverified.length;
      case BriefingSection.notamsArtcc:
        return briefing.notams.artcc.fold<int>(
            0, (sum, a) => sum + a.totalCount);
    }
  }

  String get groupLabel {
    if (index <= BriefingSection.urgentPireps.index) {
      return 'ADVERSE CONDITIONS';
    }
    if (this == BriefingSection.synopsis) return 'SYNOPSIS';
    if (index <= BriefingSection.pireps.index) return 'CURRENT WEATHER';
    if (index <= BriefingSection.windsAloft.index) return 'FORECASTS';
    return 'NOTAMS';
  }
}

/// All sections in briefing order, used for sequential navigation.
const allBriefingSections = BriefingSection.values;
