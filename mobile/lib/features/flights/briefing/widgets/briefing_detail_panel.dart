import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../models/briefing.dart';
import '../briefing_section.dart';
import 'metar_detail.dart';
import 'taf_detail.dart';
import 'notam_detail.dart';
import 'tfr_detail.dart';
import 'advisory_detail.dart';
import 'pirep_detail.dart';
import 'synopsis_detail.dart';
import 'gfa_detail.dart';
import 'winds_table_detail.dart';
import 'next_section_footer.dart';

class BriefingDetailPanel extends StatelessWidget {
  final Briefing briefing;
  final BriefingSection? selectedSection;
  final VoidCallback onNext;
  final VoidCallback onPrev;

  const BriefingDetailPanel({
    super.key,
    required this.briefing,
    required this.selectedSection,
    required this.onNext,
    required this.onPrev,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedSection == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.description_outlined,
                size: 48, color: AppColors.textMuted),
            SizedBox(height: 12),
            Text(
              'Select a section to view details',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    // Find next section label for footer
    String? nextLabel;
    final idx = allBriefingSections.indexOf(selectedSection!);
    for (int i = idx + 1; i < allBriefingSections.length; i++) {
      if (allBriefingSections[i].getItemCount(briefing) > 0) {
        nextLabel = allBriefingSections[i].label;
        break;
      }
    }

    return Column(
      children: [
        Expanded(child: _buildContent()),
        NextSectionFooter(
          nextLabel: nextLabel,
          onNext: onNext,
          onPrev: onPrev,
        ),
      ],
    );
  }

  Widget _buildContent() {
    switch (selectedSection!) {
      case BriefingSection.tfrs:
        return TfrDetail(
          tfrs: briefing.adverseConditions.tfrs,
          waypoints: briefing.flight.waypoints,
        );
      case BriefingSection.closedUnsafe:
        return NotamDetail(
          title: 'Closed/Unsafe NOTAMs',
          notams: briefing.adverseConditions.closedUnsafeNotams,
        );
      case BriefingSection.convectiveSigmets:
        return AdvisoryDetail(
          title: 'Convective SIGMETs',
          advisories: briefing.adverseConditions.convectiveSigmets,
          waypoints: briefing.flight.waypoints,
        );
      case BriefingSection.sigmets:
        return AdvisoryDetail(
          title: 'SIGMETs',
          advisories: briefing.adverseConditions.sigmets,
          waypoints: briefing.flight.waypoints,
        );
      case BriefingSection.airmetIfr:
        return AdvisoryDetail(
          title: 'AIRMET IFR',
          advisories: briefing.adverseConditions.airmets.ifr,
          waypoints: briefing.flight.waypoints,
        );
      case BriefingSection.airmetMtnObsc:
        return AdvisoryDetail(
          title: 'AIRMET Mountain Obscuration',
          advisories:
              briefing.adverseConditions.airmets.mountainObscuration,
          waypoints: briefing.flight.waypoints,
        );
      case BriefingSection.airmetIcing:
        return AdvisoryDetail(
          title: 'AIRMET Icing',
          advisories: briefing.adverseConditions.airmets.icing,
          waypoints: briefing.flight.waypoints,
        );
      case BriefingSection.airmetTurbLow:
        return AdvisoryDetail(
          title: 'AIRMET Turbulence Low',
          advisories: briefing.adverseConditions.airmets.turbulenceLow,
          waypoints: briefing.flight.waypoints,
        );
      case BriefingSection.airmetTurbHigh:
        return AdvisoryDetail(
          title: 'AIRMET Turbulence High',
          advisories: briefing.adverseConditions.airmets.turbulenceHigh,
          waypoints: briefing.flight.waypoints,
        );
      case BriefingSection.airmetLlws:
        return AdvisoryDetail(
          title: 'AIRMET Low Level Wind Shear',
          advisories:
              briefing.adverseConditions.airmets.lowLevelWindShear,
          waypoints: briefing.flight.waypoints,
        );
      case BriefingSection.airmetOther:
        return AdvisoryDetail(
          title: 'AIRMET Other',
          advisories: briefing.adverseConditions.airmets.other,
          waypoints: briefing.flight.waypoints,
        );
      case BriefingSection.urgentPireps:
        return PirepDetail(
          title: 'Urgent PIREPs',
          pireps: briefing.adverseConditions.urgentPireps,
          waypoints: briefing.flight.waypoints,
        );
      case BriefingSection.synopsis:
        return const SynopsisDetail();
      case BriefingSection.metars:
        return MetarDetail(
          metars: briefing.currentWeather.metars,
          waypoints: briefing.flight.waypoints,
        );
      case BriefingSection.pireps:
        return PirepDetail(
          title: 'PIREPs',
          pireps: briefing.currentWeather.pireps,
          waypoints: briefing.flight.waypoints,
        );
      case BriefingSection.gfaClouds:
        return GfaDetail(
          title: 'GFA Cloud Coverage',
          products: briefing.forecasts.gfaCloudProducts,
        );
      case BriefingSection.gfaSurface:
        return GfaDetail(
          title: 'GFA Surface',
          products: briefing.forecasts.gfaSurfaceProducts,
        );
      case BriefingSection.tafs:
        return TafDetail(
          tafs: briefing.forecasts.tafs,
          waypoints: briefing.flight.waypoints,
        );
      case BriefingSection.windsAloft:
        return WindsTableDetail(
          table: briefing.forecasts.windsAloftTable,
        );
      case BriefingSection.notamsDeparture:
        return NotamDetail(
          title:
              'Departure NOTAMs - ${briefing.flight.departureIdentifier}',
          categorized: briefing.notams.departure,
        );
      case BriefingSection.notamsDestination:
        return NotamDetail(
          title:
              'Destination NOTAMs - ${briefing.flight.destinationIdentifier}',
          categorized: briefing.notams.destination,
        );
      case BriefingSection.notamsAlternate1:
        return NotamDetail(
          title:
              'Alternate NOTAMs - ${briefing.flight.alternateIdentifier ?? ''}',
          categorized: briefing.notams.alternate1,
        );
      case BriefingSection.notamsEnrouteNav:
        return NotamDetail(
          title: 'Enroute Navigation NOTAMs',
          notams: briefing.notams.enroute.navigation,
        );
      case BriefingSection.notamsEnrouteCom:
        return NotamDetail(
          title: 'Enroute Communication NOTAMs',
          notams: briefing.notams.enroute.communication,
        );
      case BriefingSection.notamsEnrouteSvc:
        return NotamDetail(
          title: 'Enroute Service NOTAMs',
          notams: briefing.notams.enroute.svc,
        );
      case BriefingSection.notamsEnrouteAirspace:
        return NotamDetail(
          title: 'Enroute Airspace NOTAMs',
          notams: briefing.notams.enroute.airspace,
        );
      case BriefingSection.notamsEnrouteSua:
        return NotamDetail(
          title: 'Enroute Special Use Airspace NOTAMs',
          notams: briefing.notams.enroute.specialUseAirspace,
        );
      case BriefingSection.notamsEnrouteRwyFdc:
        return NotamDetail(
          title: 'Enroute Rwy/Twy/FDC NOTAMs',
          notams: briefing.notams.enroute.rwyTwyApronAdFdc,
        );
      case BriefingSection.notamsEnrouteOther:
        return NotamDetail(
          title: 'Enroute Other NOTAMs',
          notams: briefing.notams.enroute.otherUnverified,
        );
      case BriefingSection.notamsArtcc:
        return NotamDetail(
          title: 'ARTCC NOTAMs',
          artccNotams: briefing.notams.artcc,
        );
    }
  }
}
