import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature — Coming Soon'),
        duration: const Duration(seconds: 1),
        backgroundColor: AppColors.surfaceLight,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('More'),
      ),
      body: ListView(
        children: [
          // Downloads & Settings row
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    icon: Icons.download,
                    label: 'Downloads',
                    onTap: () => _showComingSoon(context, 'Downloads'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionButton(
                    icon: Icons.settings,
                    label: 'Settings',
                    onTap: () => _showComingSoon(context, 'Settings'),
                  ),
                ),
              ],
            ),
          ),

          // Views section
          _SectionHeader(title: 'VIEWS'),
          _MenuItem(
            icon: Icons.description_outlined,
            iconColor: const Color(0xFF5C6BC0),
            label: 'Plates',
            onTap: () => _showComingSoon(context, 'Plates'),
          ),
          _MenuItem(
            icon: Icons.folder_outlined,
            iconColor: const Color(0xFF7E57C2),
            label: 'Documents',
            onTap: () => _showComingSoon(context, 'Documents'),
          ),
          _MenuItem(
            icon: Icons.image_outlined,
            iconColor: const Color(0xFF26A69A),
            label: 'Imagery',
            onTap: () => _showComingSoon(context, 'Imagery'),
          ),
          _MenuItem(
            icon: Icons.edit_note,
            iconColor: const Color(0xFF42A5F5),
            label: 'ScratchPads',
            onTap: () => _showComingSoon(context, 'ScratchPads'),
          ),
          _MenuItem(
            icon: Icons.checklist,
            iconColor: const Color(0xFF66BB6A),
            label: 'Checklist',
            onTap: () => _showComingSoon(context, 'Checklist'),
          ),
          _MenuItem(
            icon: Icons.book_outlined,
            iconColor: const Color(0xFF5C6BC0),
            label: 'Logbook',
            onTap: () => _showComingSoon(context, 'Logbook'),
          ),
          _MenuItem(
            icon: Icons.scale_outlined,
            iconColor: const Color(0xFF26A69A),
            label: 'Weight & Balance',
            onTap: () => _showComingSoon(context, 'Weight & Balance'),
          ),
          _MenuItem(
            icon: Icons.flight_outlined,
            iconColor: const Color(0xFF42A5F5),
            label: 'Aircraft',
            onTap: () => _showComingSoon(context, 'Aircraft'),
          ),
          _MenuItem(
            icon: Icons.dashboard_customize_outlined,
            iconColor: const Color(0xFF7E57C2),
            label: 'Custom Content',
            onTap: () => _showComingSoon(context, 'Custom Content'),
          ),
          _MenuItem(
            icon: Icons.timeline,
            iconColor: const Color(0xFF26A69A),
            label: 'Track Logs',
            onTap: () => _showComingSoon(context, 'Track Logs'),
          ),

          const Divider(),

          // Additional items
          _MenuItem(
            icon: Icons.devices,
            iconColor: const Color(0xFF5C6BC0),
            label: 'Devices',
            onTap: () => _showComingSoon(context, 'Devices'),
          ),
          _MenuItem(
            icon: Icons.explore_outlined,
            iconColor: const Color(0xFF26A69A),
            label: 'Discover',
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'New',
                style: TextStyle(fontSize: 11, color: Colors.white),
              ),
            ),
            onTap: () => _showComingSoon(context, 'Discover'),
          ),
          _MenuItem(
            icon: Icons.people_outline,
            iconColor: const Color(0xFF5C6BC0),
            label: 'Passenger',
            onTap: () => _showComingSoon(context, 'Passenger'),
          ),
          _MenuItem(
            icon: Icons.person_outline,
            iconColor: const Color(0xFF42A5F5),
            label: 'Account',
            onTap: () => _showComingSoon(context, 'Account'),
          ),
          _MenuItem(
            icon: Icons.help_outline,
            iconColor: const Color(0xFF66BB6A),
            label: 'Support',
            onTap: () => _showComingSoon(context, 'Support'),
          ),
          _MenuItem(
            icon: Icons.info_outline,
            iconColor: const Color(0xFF42A5F5),
            label: 'About',
            onTap: () => _showComingSoon(context, 'About'),
          ),
          _MenuItem(
            icon: Icons.sync,
            iconColor: const Color(0xFF26A69A),
            label: 'Sync Status',
            onTap: () => _showComingSoon(context, 'Sync Status'),
          ),
          _MenuItem(
            icon: Icons.chat_bubble_outline,
            iconColor: const Color(0xFF7E57C2),
            label: 'Comments',
            onTap: () => _showComingSoon(context, 'Comments'),
          ),

          const SizedBox(height: 16),

          // Timer widget
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '00:00',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w300,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 16),
                  Text(
                    'Tap to Start',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                  SizedBox(width: 12),
                  Icon(Icons.arrow_upward, color: Colors.white, size: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
              letterSpacing: 1,
            ),
          ),
          if (title == 'VIEWS')
            TextButton(
              onPressed: () => context.push('/more/tab-order'),
              child: const Text(
                'Edit Tab Order',
                style: TextStyle(color: AppColors.primary, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  const _MenuItem({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor, size: 18),
      ),
      title: Text(label, style: const TextStyle(fontSize: 15)),
      trailing: trailing ??
          const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
      onTap: onTap,
      dense: true,
      visualDensity: const VisualDensity(vertical: -1),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceLight,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon, color: AppColors.primary, size: 28),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
