import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class AircraftScreen extends StatelessWidget {
  const AircraftScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Aircraft'),
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.flight, size: 64, color: AppColors.textMuted),
            SizedBox(height: 16),
            Text(
              'Aircraft Profiles',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Coming in Phase 2',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
