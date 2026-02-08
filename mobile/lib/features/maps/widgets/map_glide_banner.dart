import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class MapGlideBanner extends StatelessWidget {
  const MapGlideBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 40),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'Glide: 120kts, 13.8:1 (N980EK)',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
