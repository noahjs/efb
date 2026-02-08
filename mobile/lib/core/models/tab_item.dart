import 'package:flutter/material.dart';

/// A view that can appear in the bottom navigation bar.
class TabItem {
  final String key;
  final String label;
  final String route;
  final IconData icon;
  final IconData activeIcon;
  final Color iconColor;

  const TabItem({
    required this.key,
    required this.label,
    required this.route,
    required this.icon,
    required this.activeIcon,
    required this.iconColor,
  });
}

/// Every view that can be placed in the tab bar.
/// The first 4 in the user's saved order become bottom nav tabs;
/// the rest remain accessible from the More screen.
const allAvailableTabs = <TabItem>[
  TabItem(
    key: 'airports',
    label: 'Airports',
    route: '/airports',
    icon: Icons.navigation_outlined,
    activeIcon: Icons.navigation,
    iconColor: Color(0xFF42A5F5),
  ),
  TabItem(
    key: 'maps',
    label: 'Maps',
    route: '/maps',
    icon: Icons.map_outlined,
    activeIcon: Icons.map,
    iconColor: Color(0xFF66BB6A),
  ),
  TabItem(
    key: 'flights',
    label: 'Flights',
    route: '/flights',
    icon: Icons.route_outlined,
    activeIcon: Icons.route,
    iconColor: Color(0xFF5C6BC0),
  ),
  TabItem(
    key: 'scratchpads',
    label: 'ScratchPads',
    route: '/scratchpads',
    icon: Icons.edit_note,
    activeIcon: Icons.edit_note,
    iconColor: Color(0xFF26A69A),
  ),
  TabItem(
    key: 'aircraft',
    label: 'Aircraft',
    route: '/aircraft',
    icon: Icons.flight_outlined,
    activeIcon: Icons.flight,
    iconColor: Color(0xFF7E57C2),
  ),
  TabItem(
    key: 'plates',
    label: 'Plates',
    route: '/plates',
    icon: Icons.description_outlined,
    activeIcon: Icons.description,
    iconColor: Color(0xFF5C6BC0),
  ),
  TabItem(
    key: 'documents',
    label: 'Documents',
    route: '/documents',
    icon: Icons.folder_outlined,
    activeIcon: Icons.folder,
    iconColor: Color(0xFF7E57C2),
  ),
  TabItem(
    key: 'imagery',
    label: 'Imagery',
    route: '/imagery',
    icon: Icons.image_outlined,
    activeIcon: Icons.image,
    iconColor: Color(0xFF26A69A),
  ),
  TabItem(
    key: 'logbook',
    label: 'Logbook',
    route: '/logbook',
    icon: Icons.book_outlined,
    activeIcon: Icons.book,
    iconColor: Color(0xFF5C6BC0),
  ),
  TabItem(
    key: 'weight_balance',
    label: 'Weight & Balance',
    route: '/weight-balance',
    icon: Icons.scale_outlined,
    activeIcon: Icons.scale,
    iconColor: Color(0xFF26A69A),
  ),
  TabItem(
    key: 'track_logs',
    label: 'Track Logs',
    route: '/track-logs',
    icon: Icons.timeline,
    activeIcon: Icons.timeline,
    iconColor: Color(0xFF66BB6A),
  ),
];

/// Default tab keys — first 4 become bottom nav, rest overflow to More.
const defaultTabKeys = [
  'airports', 'maps', 'flights', 'scratchpads',
  'aircraft', 'plates', 'documents', 'imagery',
  'logbook', 'weight_balance', 'track_logs',
];

/// Number of slots in the bottom nav (excluding More).
const tabBarSlotCount = 4;

/// Look up a TabItem by key, returns null if not found.
TabItem? tabItemByKey(String key) {
  for (final t in allAvailableTabs) {
    if (t.key == key) return t;
  }
  return null;
}
