import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class FlightFilingBar extends StatelessWidget {
  final String filingStatus;

  const FlightFilingBar({
    super.key,
    required this.filingStatus,
  });

  String get _statusLabel {
    switch (filingStatus) {
      case 'filed':
        return 'Filed';
      case 'accepted':
        return 'Accepted';
      case 'closed':
        return 'Closed';
      default:
        return 'Not Filed';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _statusLabel,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Flight filing coming in a future update'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Proceed to File',
                  style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}
