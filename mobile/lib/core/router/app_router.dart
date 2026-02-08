import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/maps/maps_screen.dart';
import '../../features/airports/screens/airports_screen.dart';
import '../../features/airports/screens/airport_detail_screen.dart';
import '../../features/flights/flights_screen.dart';
import '../../features/aircraft/aircraft_screen.dart';
import '../../features/more/more_screen.dart';
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
        ),
        GoRoute(
          path: '/aircraft',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: AircraftScreen(),
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
  ],
);
