import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/aircraft.dart';

class AttachAircraftSheet extends StatelessWidget {
  final List<Aircraft> aircraftList;
  final int? currentAircraftId;

  const AttachAircraftSheet({
    super.key,
    required this.aircraftList,
    this.currentAircraftId,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      child: SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Attach to Aircraft',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.divider),
            ListTile(
              leading: const Icon(Icons.close, color: AppColors.textMuted),
              title: const Text('No Aircraft'),
              selected: currentAircraftId == null,
              onTap: () => Navigator.pop(context, -1),
            ),
            ...aircraftList.map(
              (a) => ListTile(
                leading: const Icon(Icons.flight, color: AppColors.accent),
                title: Text(a.tailNumber),
                subtitle: Text(a.aircraftType,
                    style: const TextStyle(color: AppColors.textMuted)),
                selected: currentAircraftId == a.id,
                onTap: () => Navigator.pop(context, a.id),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
