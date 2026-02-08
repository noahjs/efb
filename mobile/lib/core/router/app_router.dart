import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/maps/maps_screen.dart';
import '../../features/airports/screens/airports_screen.dart';
import '../../features/airports/screens/airport_detail_screen.dart';
import '../../features/flights/flights_screen.dart';
import '../../features/flights/flight_detail_screen.dart';
import '../../features/scratchpads/scratchpads_screen.dart';
import '../../features/scratchpads/scratchpad_editor_screen.dart';
import '../../features/aircraft/aircraft_screen.dart';
import '../../features/aircraft/screens/aircraft_detail_screen.dart';
import '../../features/aircraft/screens/aircraft_create_screen.dart';
import '../../features/aircraft/screens/performance_profiles_screen.dart';
import '../../features/aircraft/screens/performance_profile_edit_screen.dart';
import '../../features/aircraft/screens/fuel_tanks_screen.dart';
import '../../features/aircraft/screens/equipment_screen.dart';
import '../../features/more/more_screen.dart';
import '../../features/more/tab_order_screen.dart';
import '../widgets/app_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/maps',
  routes: [
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/airports',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: AirportsScreen(),
          ),
          routes: [
            GoRoute(
              path: ':id',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (context, state) {
                final airportId = state.pathParameters['id']!;
                return AirportDetailScreen(airportId: airportId);
              },
            ),
          ],
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
          routes: [
            GoRoute(
              path: 'new',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (context, state) =>
                  const FlightDetailScreen(flightId: null),
            ),
            GoRoute(
              path: ':id',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (context, state) {
                final id = int.parse(state.pathParameters['id']!);
                return FlightDetailScreen(flightId: id);
              },
            ),
          ],
        ),
        GoRoute(
          path: '/scratchpads',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: ScratchPadsScreen(),
          ),
          routes: [
            GoRoute(
              path: ':id',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (context, state) {
                final padId = state.pathParameters['id']!;
                return ScratchPadEditorScreen(padId: padId);
              },
            ),
          ],
        ),
        GoRoute(
          path: '/aircraft',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: AircraftScreen(),
          ),
          routes: [
            GoRoute(
              path: 'new',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (context, state) => const AircraftCreateScreen(),
            ),
            GoRoute(
              path: ':id',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (context, state) {
                final id = int.parse(state.pathParameters['id']!);
                return AircraftDetailScreen(aircraftId: id);
              },
              routes: [
                GoRoute(
                  path: 'profiles',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) {
                    final id = int.parse(state.pathParameters['id']!);
                    return PerformanceProfilesScreen(aircraftId: id);
                  },
                  routes: [
                    GoRoute(
                      path: ':pid',
                      parentNavigatorKey: _rootNavigatorKey,
                      builder: (context, state) {
                        final id = int.parse(state.pathParameters['id']!);
                        final pid = int.parse(state.pathParameters['pid']!);
                        return PerformanceProfileEditScreen(
                          aircraftId: id,
                          profileId: pid,
                        );
                      },
                    ),
                  ],
                ),
                GoRoute(
                  path: 'fuel-tanks',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) {
                    final id = int.parse(state.pathParameters['id']!);
                    return FuelTanksScreen(aircraftId: id);
                  },
                ),
                GoRoute(
                  path: 'equipment',
                  parentNavigatorKey: _rootNavigatorKey,
                  builder: (context, state) {
                    final id = int.parse(state.pathParameters['id']!);
                    return EquipmentScreen(aircraftId: id);
                  },
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/more',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: MoreScreen(),
          ),
          routes: [
            GoRoute(
              path: 'tab-order',
              parentNavigatorKey: _rootNavigatorKey,
              builder: (context, state) => const TabOrderScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);
