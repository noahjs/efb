import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/maps/maps_screen.dart';
import '../../features/airports/screens/airports_screen.dart';
import '../../features/airports/screens/airport_detail_screen.dart';
import '../../features/flights/flights_screen.dart';
import '../../features/flights/flight_detail_screen.dart';
import '../../features/flights/told_screen.dart';
import '../../features/flights/told_card_screen.dart';
import '../../services/told_providers.dart';
import '../../features/scratchpads/scratchpads_screen.dart';
import '../../features/scratchpads/scratchpad_editor_screen.dart';
import '../../features/aircraft/aircraft_screen.dart';
import '../../features/aircraft/screens/aircraft_detail_screen.dart';
import '../../features/aircraft/screens/aircraft_create_screen.dart';
import '../../features/aircraft/screens/performance_profiles_screen.dart';
import '../../features/aircraft/screens/performance_profile_edit_screen.dart';
import '../../features/aircraft/screens/fuel_tanks_screen.dart';
import '../../features/aircraft/screens/equipment_screen.dart';
import '../../features/imagery/imagery_screen.dart';
import '../../features/imagery/widgets/gfa_viewer.dart';
import '../../features/imagery/widgets/advisory_viewer.dart';
import '../../features/imagery/widgets/pirep_viewer.dart';
import '../../features/imagery/widgets/convective_viewer.dart';
import '../../features/imagery/widgets/icing_viewer.dart';
import '../../features/imagery/widgets/prog_viewer.dart';
import '../../features/imagery/widgets/tfr_viewer.dart';
import '../../features/imagery/widgets/winds_aloft_viewer.dart';
import '../../features/logbook/logbook_screen.dart';
import '../../features/logbook/logbook_entry_screen.dart';
import '../../features/logbook/logbook_experience_report_screen.dart';
import '../../features/logbook/endorsement_detail_screen.dart';
import '../../features/logbook/certificate_detail_screen.dart';
import '../../features/logbook/credentials_screen.dart';
import '../../features/logbook/currency_screen.dart';
import '../../features/logbook/import_screen.dart';
import '../../features/weight_balance/wb_screen.dart';
import '../../features/weight_balance/screens/wb_profile_editor_screen.dart';
import '../../features/weight_balance/screens/flight_wb_screen.dart';
import '../../features/approach_charts/screens/approach_list_screen.dart';
import '../../features/approach_charts/screens/approach_chart_screen.dart';
import '../../features/more/more_screen.dart';
import '../../features/more/pilot_profile_screen.dart';
import '../../features/adsb/screens/receiver_settings_screen.dart';
import '../widgets/app_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/maps',
  routes: [
    // ── Shell route (bottom nav tabs) ──
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/airports',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: AirportsScreen(),
          ),
        ),
        GoRoute(
          path: '/maps',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: MapsScreen(),
          ),
        ),
        GoRoute(
          path: '/flights',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: FlightsScreen(),
          ),
        ),
        GoRoute(
          path: '/scratchpads',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: ScratchPadsScreen(),
          ),
        ),
        GoRoute(
          path: '/aircraft',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: AircraftScreen(),
          ),
        ),
        GoRoute(
          path: '/plates',
          pageBuilder: (context, state) => NoTransitionPage(
            child: Scaffold(
              appBar: AppBar(title: const Text('Plates')),
              body: const Center(child: Text('Coming Soon')),
            ),
          ),
        ),
        GoRoute(
          path: '/documents',
          pageBuilder: (context, state) => NoTransitionPage(
            child: Scaffold(
              appBar: AppBar(title: const Text('Documents')),
              body: const Center(child: Text('Coming Soon')),
            ),
          ),
        ),
        GoRoute(
          path: '/imagery',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: ImageryScreen(),
          ),
        ),
        GoRoute(
          path: '/logbook',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: LogbookScreen(),
          ),
        ),
        GoRoute(
          path: '/credentials',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: CredentialsScreen(),
          ),
        ),
        GoRoute(
          path: '/endorsements',
          redirect: (context, state) => '/credentials',
        ),
        GoRoute(
          path: '/certificates',
          redirect: (context, state) => '/credentials',
        ),
        GoRoute(
          path: '/weight-balance',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: WBScreen(),
          ),
        ),
        GoRoute(
          path: '/track-logs',
          pageBuilder: (context, state) => NoTransitionPage(
            child: Scaffold(
              appBar: AppBar(title: const Text('Track Logs')),
              body: const Center(child: Text('Coming Soon')),
            ),
          ),
        ),
        GoRoute(
          path: '/more',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: MoreScreen(),
          ),
        ),
      ],
    ),

    // ── Full-screen detail routes (root navigator) ──

    // Airports
    GoRoute(
      path: '/airports/:id',
      builder: (context, state) {
        final airportId = state.pathParameters['id']!;
        return AirportDetailScreen(airportId: airportId);
      },
    ),

    // Approach Charts
    GoRoute(
      path: '/airports/:id/approaches',
      builder: (context, state) {
        final airportId = state.pathParameters['id']!;
        return ApproachListScreen(airportId: airportId);
      },
    ),
    GoRoute(
      path: '/airports/:id/approaches/:approachId',
      builder: (context, state) {
        final airportId = state.pathParameters['id']!;
        final approachId = int.parse(state.pathParameters['approachId']!);
        return ApproachChartScreen(
          airportId: airportId,
          approachId: approachId,
        );
      },
    ),

    // Flights
    GoRoute(
      path: '/flights/new',
      builder: (context, state) =>
          const FlightDetailScreen(flightId: null),
    ),
    GoRoute(
      path: '/flights/:id/takeoff',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return ToldScreen(flightId: id, mode: ToldMode.takeoff);
      },
    ),
    GoRoute(
      path: '/flights/:id/landing',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return ToldScreen(flightId: id, mode: ToldMode.landing);
      },
    ),
    GoRoute(
      path: '/flights/:id/told',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        final modeStr =
            state.uri.queryParameters['mode'] ?? 'takeoff';
        final mode = modeStr == 'landing'
            ? ToldMode.landing
            : ToldMode.takeoff;
        return ToldCardScreen(flightId: id, mode: mode);
      },
    ),
    GoRoute(
      path: '/flights/:id/wb',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return FlightWBScreen(flightId: id);
      },
    ),
    GoRoute(
      path: '/flights/:id',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return FlightDetailScreen(flightId: id);
      },
    ),

    // Scratchpads
    GoRoute(
      path: '/scratchpads/:id',
      builder: (context, state) {
        final padId = state.pathParameters['id']!;
        return ScratchPadEditorScreen(padId: padId);
      },
    ),

    // Aircraft
    GoRoute(
      path: '/aircraft/new',
      builder: (context, state) => const AircraftCreateScreen(),
    ),
    // W&B
    GoRoute(
      path: '/aircraft/:id/wb',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return WBScreen(aircraftId: id);
      },
    ),
    GoRoute(
      path: '/aircraft/:id/wb/profiles/:pid/edit',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        final pid = int.parse(state.pathParameters['pid']!);
        return WBProfileEditorScreen(aircraftId: id, profileId: pid);
      },
    ),

    GoRoute(
      path: '/aircraft/:id/profiles/:pid',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        final pid = int.parse(state.pathParameters['pid']!);
        return PerformanceProfileEditScreen(
          aircraftId: id,
          profileId: pid,
        );
      },
    ),
    GoRoute(
      path: '/aircraft/:id/profiles',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return PerformanceProfilesScreen(aircraftId: id);
      },
    ),
    GoRoute(
      path: '/aircraft/:id/fuel-tanks',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return FuelTanksScreen(aircraftId: id);
      },
    ),
    GoRoute(
      path: '/aircraft/:id/equipment',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return EquipmentScreen(aircraftId: id);
      },
    ),
    GoRoute(
      path: '/aircraft/:id',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return AircraftDetailScreen(aircraftId: id);
      },
    ),

    // Imagery
    GoRoute(
      path: '/imagery/gfa',
      builder: (context, state) {
        final type =
            state.uri.queryParameters['type'] ?? 'clouds';
        final region =
            state.uri.queryParameters['region'] ?? 'us';
        final name =
            state.uri.queryParameters['name'] ?? 'GFA';
        return GfaViewer(
          gfaType: type,
          region: region,
          name: name,
        );
      },
    ),
    GoRoute(
      path: '/imagery/advisory',
      builder: (context, state) {
        final type =
            state.uri.queryParameters['type'] ?? 'gairmets';
        final name =
            state.uri.queryParameters['name'] ?? 'Advisories';
        return AdvisoryViewer(
          advisoryType: type,
          name: name,
        );
      },
    ),
    GoRoute(
      path: '/imagery/prog',
      builder: (context, state) {
        final type =
            state.uri.queryParameters['type'] ?? 'low';
        final name =
            state.uri.queryParameters['name'] ?? 'Prog Chart';
        return ProgViewer(progType: type, name: name);
      },
    ),
    GoRoute(
      path: '/imagery/convective',
      builder: (context, state) => const ConvectiveViewer(),
    ),
    GoRoute(
      path: '/imagery/icing',
      builder: (context, state) {
        final param =
            state.uri.queryParameters['param'] ?? 'prob';
        final name =
            state.uri.queryParameters['name'] ?? 'Icing';
        return IcingViewer(icingParam: param, name: name);
      },
    ),
    GoRoute(
      path: '/imagery/winds',
      builder: (context, state) => const WindsAloftViewer(),
    ),
    GoRoute(
      path: '/imagery/pireps',
      builder: (context, state) => const PirepViewer(),
    ),
    GoRoute(
      path: '/imagery/tfrs',
      builder: (context, state) => const TfrViewer(),
    ),

    // Logbook
    GoRoute(
      path: '/logbook/experience',
      builder: (context, state) =>
          const LogbookExperienceReportScreen(),
    ),
    GoRoute(
      path: '/logbook/currency',
      builder: (context, state) => const CurrencyScreen(),
    ),
    GoRoute(
      path: '/logbook/import',
      builder: (context, state) => const ImportScreen(),
    ),
    GoRoute(
      path: '/logbook/new',
      builder: (context, state) =>
          const LogbookEntryScreen(entryId: null),
    ),
    GoRoute(
      path: '/logbook/:id',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return LogbookEntryScreen(entryId: id);
      },
    ),

    // Endorsements & Certificates
    GoRoute(
      path: '/endorsements/new',
      builder: (context, state) =>
          const EndorsementDetailScreen(endorsementId: null),
    ),
    GoRoute(
      path: '/endorsements/:id',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return EndorsementDetailScreen(endorsementId: id);
      },
    ),
    GoRoute(
      path: '/certificates/new',
      builder: (context, state) =>
          const CertificateDetailScreen(certificateId: null),
    ),
    GoRoute(
      path: '/certificates/:id',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return CertificateDetailScreen(certificateId: id);
      },
    ),

    // ADS-B Receiver Settings
    GoRoute(
      path: '/settings/receiver',
      builder: (context, state) => const ReceiverSettingsScreen(),
    ),

    // More
    GoRoute(
      path: '/more/profile',
      builder: (context, state) => const PilotProfileScreen(),
    ),
  ],
);
