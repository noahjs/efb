import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class AirportInfoTab extends StatelessWidget {
  final String airportId;
  const AirportInfoTab({super.key, required this.airportId});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        // Cameras section
        _FrequencySection(
          title: 'CAMERAS',
          items: [
            _FrequencyItem(name: 'Airport Cameras', trailing: '>'),
          ],
        ),

        // Weather and Advisory
        _FrequencySection(
          title: 'WEATHER AND ADVISORY',
          items: [
            _FrequencyItem(
              name: 'ATIS',
              phone: '(303) 466-8744',
              frequency: '126.25',
            ),
            _FrequencyItem(
              name: 'AWOS-3',
              phone: '(720) 887-8067',
            ),
          ],
        ),

        // Clearance
        _FrequencySection(
          title: 'CLEARANCE',
          items: [
            _FrequencyItem(
              name: 'Metro Clearance Delivery',
              frequency: '132.6',
            ),
          ],
        ),

        // Ground
        _FrequencySection(
          title: 'GROUND',
          items: [
            _FrequencyItem(
              name: 'Metro Ground',
              frequency: '121.7',
            ),
          ],
        ),

        // Tower
        _FrequencySection(
          title: 'TOWER',
          items: [
            _FrequencyItem(
              name: 'Metro Tower',
              subtitle: '0600-2200',
              frequency: '118.6',
            ),
          ],
        ),

        // Approach / Departure
        _FrequencySection(
          title: 'APPROACH / DEPARTURE',
          items: [
            _FrequencyItem(
              name: 'Denver Approach',
              frequency: '120.3',
            ),
            _FrequencyItem(
              name: 'Denver Departure',
              frequency: '128.3',
            ),
          ],
        ),

        // UNICOM
        _FrequencySection(
          title: 'UNICOM / CTAF',
          items: [
            _FrequencyItem(
              name: 'UNICOM',
              frequency: '122.95',
            ),
          ],
        ),
        const SizedBox(height: 32),
      ],
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
  final String? subtitle;
  final String? phone;
  final String? frequency;
  final String? trailing;

  const _FrequencyItem({
    required this.name,
    this.subtitle,
    this.phone,
    this.frequency,
    this.trailing,
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
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                if (phone != null)
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
          if (frequency != null)
            Text(
              frequency!,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
          if (trailing != null)
            const Icon(Icons.chevron_right,
                color: AppColors.textMuted, size: 20),
        ],
      ),
    );
  }
}
