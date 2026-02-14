import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/solar.dart';
import '../../../services/airport_providers.dart';

class AirportInfoTab extends ConsumerWidget {
  final String airportId;
  const AirportInfoTab({super.key, required this.airportId});

  /// Map backend frequency type codes to display section titles
  static const _typeSections = {
    'ATIS': 'WEATHER AND ADVISORY',
    'AWOS': 'WEATHER AND ADVISORY',
    'ASOS': 'WEATHER AND ADVISORY',
    'CD': 'CLEARANCE',
    'GND': 'GROUND',
    'TWR': 'TOWER',
    'APP': 'APPROACH / DEPARTURE',
    'DEP': 'APPROACH / DEPARTURE',
    'CTAF': 'UNICOM / CTAF',
    'UNIC': 'UNICOM / CTAF',
  };

  /// Ordering for frequency sections
  static const _sectionOrder = [
    'WEATHER AND ADVISORY',
    'CLEARANCE',
    'GROUND',
    'TOWER',
    'APPROACH / DEPARTURE',
    'UNICOM / CTAF',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final airportAsync = ref.watch(airportDetailProvider(airportId));

    return airportAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const Center(
        child: Text(
          'Failed to load airport data',
          style: TextStyle(color: AppColors.textMuted),
        ),
      ),
      data: (airport) {
        if (airport == null) {
          return const Center(
            child: Text(
              'Airport not found',
              style: TextStyle(color: AppColors.textMuted),
            ),
          );
        }

        return ListView(
          children: [
            _buildFrequencies(airport),
            _buildTrafficPatterns(airport),
            _buildFeatures(airport),
            _buildSolarInfo(airport),
            _buildManager(airport),
            _buildOwner(airport),
            _buildNearbyAirports(context, ref, airport),
            _buildCycle(airport),
            const SizedBox(height: 32),
          ],
        );
      },
    );
  }

  // --- FREQUENCIES ---

  Widget _buildFrequencies(Map<String, dynamic> airport) {
    final frequencies = airport['frequencies'] as List<dynamic>? ?? [];
    if (frequencies.isEmpty) return const SizedBox.shrink();

    // Group frequencies by section title
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final freq in frequencies) {
      final map = freq as Map<String, dynamic>;
      final type = map['type'] as String? ?? '';
      final section = _typeSections[type] ?? 'OTHER';
      grouped.putIfAbsent(section, () => []).add(map);
    }

    // Build ordered section list
    final sections = <String>[];
    for (final s in _sectionOrder) {
      if (grouped.containsKey(s)) sections.add(s);
    }
    for (final s in grouped.keys) {
      if (!sections.contains(s)) sections.add(s);
    }

    return Column(
      children: [
        for (final section in sections)
          _FrequencySection(
            title: section,
            items: grouped[section]!
                .map((f) => _FrequencyItem(
                      name: f['name'] as String? ?? '',
                      phone: f['phone'] as String?,
                      frequency: f['frequency'] as String?,
                    ))
                .toList(),
          ),
      ],
    );
  }

  // --- TRAFFIC PATTERNS ---

  Widget _buildTrafficPatterns(Map<String, dynamic> airport) {
    final tpa = airport['tpa'];
    final runways = airport['runways'] as List<dynamic>? ?? [];

    // Collect per-runway-end pattern info
    final patternRows = <Widget>[];
    for (final rwy in runways) {
      final rwyMap = rwy as Map<String, dynamic>;
      final ends = rwyMap['ends'] as List<dynamic>? ?? [];
      for (final end in ends) {
        final endMap = end as Map<String, dynamic>;
        final endId = endMap['identifier'] as String? ?? '';
        final pattern = endMap['traffic_pattern'] as String? ?? 'Left';
        if (endId.isNotEmpty) {
          patternRows.add(_InfoRow(
            label: 'Runway $endId',
            value: '$pattern Traffic',
          ));
        }
      }
    }

    if (tpa == null && patternRows.isEmpty) return const SizedBox.shrink();

    return _InfoSection(
      title: 'TRAFFIC PATTERNS',
      children: [
        if (tpa != null)
          _InfoRow(
            label: 'Traffic Pattern Altitude',
            value: "${NumberFormat('#,##0').format(tpa)}' MSL",
          ),
        ...patternRows,
      ],
    );
  }

  // --- FEATURES ---

  Widget _buildFeatures(Map<String, dynamic> airport) {
    final rows = <Widget>[];

    // Elevation
    final elevation = airport['elevation'];
    if (elevation != null) {
      rows.add(_InfoRow(
        label: 'Elevation (MSL)',
        value: "${NumberFormat('#,##0').format((elevation as num).round())}'",
      ));
    }

    // Type
    final facilityType = airport['facility_type'] as String?;
    if (facilityType != null && facilityType.isNotEmpty) {
      rows.add(_InfoRow(label: 'Type', value: _mapFacilityType(facilityType)));
    }

    // Access
    final facilityUse = airport['facility_use'] as String?;
    if (facilityUse != null && facilityUse.isNotEmpty) {
      rows.add(_InfoRow(label: 'Access', value: _mapFacilityUse(facilityUse)));
    }

    // ARTCC
    final artccId = airport['artcc_id'] as String?;
    final artccName = airport['artcc_name'] as String?;
    if (artccId != null && artccId.isNotEmpty) {
      final display = artccName != null && artccName.isNotEmpty
          ? '$artccName ($artccId)'
          : artccId;
      rows.add(_InfoRow(label: 'FIR/ARTCC', value: display));
    }

    // FSS
    final fssId = airport['fss_id'] as String?;
    final fssName = airport['fss_name'] as String?;
    if (fssId != null && fssId.isNotEmpty) {
      final display = fssName != null && fssName.isNotEmpty
          ? '$fssName ($fssId)'
          : fssId;
      rows.add(_InfoRow(label: 'Flight Service', value: display));
    }

    // Sectional
    final sectional = airport['sectional_chart'] as String?;
    if (sectional != null && sectional.isNotEmpty) {
      rows.add(_InfoRow(label: 'Sectional', value: sectional));
    }

    // Customs
    final customs = airport['customs_flag'] as String?;
    if (customs != null && customs.isNotEmpty) {
      rows.add(_InfoRow(
        label: 'Customs Available',
        value: customs == 'Y' ? 'Yes' : 'No',
      ));
    }

    // Landing Rights
    final landingRights = airport['landing_rights_flag'] as String?;
    if (landingRights != null && landingRights.isNotEmpty) {
      rows.add(_InfoRow(
        label: 'Landing Rights',
        value: landingRights == 'Y' ? 'Yes' : 'No',
      ));
    }

    // Magnetic Variation
    final magVar = airport['magnetic_variation'] as String?;
    if (magVar != null && magVar.isNotEmpty) {
      rows.add(_InfoRow(label: 'Magnetic Variation', value: magVar));
    }

    // Time Zone
    final tz = airport['timezone'] as String?;
    if (tz != null && tz.isNotEmpty) {
      rows.add(_InfoRow(label: 'Time Zone', value: tz));
    }

    // Location
    final lat = airport['latitude'];
    final lng = airport['longitude'];
    if (lat != null && lng != null) {
      rows.add(_InfoRow(
        label: 'Location',
        value: '${(lat as num).toStringAsFixed(4)}, ${(lng as num).toStringAsFixed(4)}',
      ));
    }

    // Transition Altitude (hardcoded for US)
    rows.add(const _InfoRow(
      label: 'Transition Altitude',
      value: "18,000' MSL",
    ));

    // Fuel
    final fuel = airport['fuel_types'] as String?;
    if (fuel != null && fuel.isNotEmpty) {
      rows.add(_InfoRow(label: 'Fuel', value: fuel));
    }

    // Lighting
    final lighting = airport['lighting_schedule'] as String?;
    if (lighting != null && lighting.isNotEmpty) {
      rows.add(_InfoRow(label: 'Lighting', value: lighting));
    }

    // Tower Hours
    final towerHours = airport['tower_hours'] as String?;
    rows.add(_InfoRow(
      label: 'Tower Hours',
      value: towerHours != null && towerHours.isNotEmpty
          ? towerHours
          : 'Untowered',
    ));

    if (rows.isEmpty) return const SizedBox.shrink();

    return _InfoSection(title: 'FEATURES', children: rows);
  }

  // --- SOLAR INFORMATION ---

  Widget _buildSolarInfo(Map<String, dynamic> airport) {
    final lat = airport['latitude'] as num?;
    final lng = airport['longitude'] as num?;
    if (lat == null || lng == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final solar = SolarTimes.forDate(
      date: now,
      latitude: lat.toDouble(),
      longitude: lng.toDouble(),
    );
    if (solar == null) return const SizedBox.shrink();

    final timeFmt = DateFormat('h:mm a');

    final rows = <Widget>[];

    if (solar.civilDawn != null) {
      rows.add(_InfoRow(
        label: 'Morning Civil Twilight',
        value: timeFmt.format(solar.civilDawn!.toLocal()),
      ));
    }
    rows.add(_InfoRow(
      label: 'Sunrise',
      value: timeFmt.format(solar.sunrise.toLocal()),
    ));
    rows.add(_InfoRow(
      label: 'Sunset',
      value: timeFmt.format(solar.sunset.toLocal()),
    ));
    if (solar.civilDusk != null) {
      rows.add(_InfoRow(
        label: 'Evening Civil Twilight',
        value: timeFmt.format(solar.civilDusk!.toLocal()),
      ));
    }

    return _InfoSection(title: 'SOLAR INFORMATION', children: rows);
  }

  // --- MANAGER ---

  Widget _buildManager(Map<String, dynamic> airport) {
    final name = airport['manager_name'] as String?;
    final phone = airport['manager_phone'] as String?;
    final address = airport['manager_address'] as String?;

    if ((name == null || name.isEmpty) &&
        (phone == null || phone.isEmpty) &&
        (address == null || address.isEmpty)) {
      return const SizedBox.shrink();
    }

    return _InfoSection(
      title: 'MANAGER',
      children: [
        if (name != null && name.isNotEmpty) _InfoRow(label: 'Name', value: name),
        if (phone != null && phone.isNotEmpty)
          _InfoRow(label: 'Phone', value: phone, isPhone: true),
        if (address != null && address.isNotEmpty)
          _InfoRow(label: 'Address', value: address),
      ],
    );
  }

  // --- OWNER ---

  Widget _buildOwner(Map<String, dynamic> airport) {
    final name = airport['owner_name'] as String?;
    final phone = airport['owner_phone'] as String?;
    final address = airport['owner_address'] as String?;

    if ((name == null || name.isEmpty) &&
        (phone == null || phone.isEmpty) &&
        (address == null || address.isEmpty)) {
      return const SizedBox.shrink();
    }

    return _InfoSection(
      title: 'OWNER',
      children: [
        if (name != null && name.isNotEmpty) _InfoRow(label: 'Name', value: name),
        if (phone != null && phone.isNotEmpty)
          _InfoRow(label: 'Phone', value: phone, isPhone: true),
        if (address != null && address.isNotEmpty)
          _InfoRow(label: 'Address', value: address),
      ],
    );
  }

  // --- NEARBY AIRPORTS ---

  Widget _buildNearbyAirports(
      BuildContext context, WidgetRef ref, Map<String, dynamic> airport) {
    final lat = airport['latitude'] as num?;
    final lng = airport['longitude'] as num?;
    if (lat == null || lng == null) return const SizedBox.shrink();

    final nearbyAsync = ref.watch(
      nearbyAirportsProvider((lat: lat.toDouble(), lng: lng.toDouble())),
    );

    return nearbyAsync.when(
      loading: () => _InfoSection(
        title: 'NEARBY AIRPORTS',
        children: const [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
                child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )),
          ),
        ],
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (nearby) {
        // Filter out the current airport
        final currentId = airport['identifier'] as String? ?? '';
        final filtered = nearby
            .where((a) {
              final map = a as Map<String, dynamic>;
              return (map['identifier'] as String? ?? '') != currentId;
            })
            .take(8)
            .toList();

        if (filtered.isEmpty) return const SizedBox.shrink();

        return _InfoSection(
          title: 'NEARBY AIRPORTS',
          children: [
            for (final a in filtered)
              _NearbyAirportRow(airport: a as Map<String, dynamic>),
          ],
        );
      },
    );
  }

  // --- CYCLE ---

  Widget _buildCycle(Map<String, dynamic> airport) {
    final effDate = airport['nasr_effective_date'] as String?;
    if (effDate == null || effDate.isEmpty) return const SizedBox.shrink();

    DateTime? effective;
    // Try parsing YYYY/MM/DD or MM/DD/YYYY formats
    try {
      if (effDate.contains('/') && effDate.length >= 10) {
        final parts = effDate.split('/');
        if (parts[0].length == 4) {
          // YYYY/MM/DD
          effective = DateTime(
            int.parse(parts[0]),
            int.parse(parts[1]),
            int.parse(parts[2]),
          );
        } else {
          // MM/DD/YYYY
          effective = DateTime(
            int.parse(parts[2]),
            int.parse(parts[0]),
            int.parse(parts[1]),
          );
        }
      }
    } catch (_) {
      return const SizedBox.shrink();
    }

    if (effective == null) return const SizedBox.shrink();

    final expires = effective.add(const Duration(days: 28));
    final now = DateTime.now();
    final isCurrent = now.isBefore(expires);
    final dateFmt = DateFormat('MMM d, y');

    return _InfoSection(
      title: 'CYCLE',
      children: [
        _InfoRow(label: 'Effective', value: dateFmt.format(effective)),
        _InfoRow(label: 'Expires', value: dateFmt.format(expires)),
        _InfoRow(
          label: 'Status',
          value: isCurrent ? 'Current' : 'Expired',
          valueColor: isCurrent ? Colors.green : Colors.red,
        ),
      ],
    );
  }

  // --- HELPERS ---

  String _mapFacilityType(String code) {
    switch (code) {
      case 'AIRPORT':
        return 'Airport';
      case 'HELIPORT':
        return 'Heliport';
      case 'SEAPLANE BASE':
        return 'Seaplane Base';
      case 'ULTRALIGHT':
        return 'Ultralight';
      case 'GLIDERPORT':
        return 'Gliderport';
      case 'BALLOONPORT':
        return 'Balloonport';
      default:
        return code;
    }
  }

  String _mapFacilityUse(String code) {
    switch (code) {
      case 'PU':
        return 'Public';
      case 'PR':
        return 'Private';
      case 'MR':
        return 'Military/Civil Joint Use';
      default:
        return code;
    }
  }
}

// --- REUSABLE WIDGETS ---

class _InfoSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _InfoSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 0.8,
            ),
          ),
        ),
        ...children,
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isPhone;
  final Color? valueColor;

  const _InfoRow({
    required this.label,
    required this.value,
    this.isPhone = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: GestureDetector(
              onTap: isPhone
                  ? () => launchUrl(Uri.parse('tel:$value'))
                  : null,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  color: valueColor ??
                      (isPhone ? AppColors.accent : AppColors.textSecondary),
                ),
                textAlign: TextAlign.end,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FrequencySection extends StatelessWidget {
  final String title;
  final List<_FrequencyItem> items;

  const _FrequencySection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 0.8,
            ),
          ),
        ),
        ...items,
      ],
    );
  }
}

class _FrequencyItem extends StatelessWidget {
  final String name;
  final String? phone;
  final String? frequency;

  const _FrequencyItem({
    required this.name,
    this.phone,
    this.frequency,
  });

  @override
  Widget build(BuildContext context) {
    // Split frequency at semicolon: number on the right, remarks below name
    String? freqNumber = frequency;
    String? freqRemarks;
    if (frequency != null && frequency!.contains(';')) {
      final parts = frequency!.split(';');
      freqNumber = parts[0].trim();
      freqRemarks = parts.sublist(1).join(';').trim();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.divider, width: 0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (freqRemarks != null && freqRemarks.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      freqRemarks,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                if (phone != null && phone!.isNotEmpty)
                  Text(
                    phone!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (freqNumber != null && freqNumber.isNotEmpty)
            Text(
              freqNumber,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
        ],
      ),
    );
  }
}

class _NearbyAirportRow extends StatelessWidget {
  final Map<String, dynamic> airport;

  const _NearbyAirportRow({required this.airport});

  @override
  Widget build(BuildContext context) {
    final identifier = airport['identifier'] as String? ?? '';
    final icao = airport['icao_identifier'] as String? ?? '';
    final displayId = icao.isNotEmpty ? icao : identifier;
    final name = airport['name'] as String? ?? '';
    final distance = airport['distance_nm'] as num?;

    return GestureDetector(
      onTap: () => context.push('/airports/$displayId'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.divider, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Text(
              displayId,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (distance != null)
              Text(
                '${distance.toStringAsFixed(1)} nm',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textMuted,
                ),
              ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right,
                size: 16, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}
