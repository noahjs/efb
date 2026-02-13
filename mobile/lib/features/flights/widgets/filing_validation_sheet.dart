import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

class ValidationCheck {
  final String field;
  final String label;
  final bool passed;
  final String? value;
  final String severity; // 'error' or 'warning'

  const ValidationCheck({
    required this.field,
    required this.label,
    required this.passed,
    this.value,
    required this.severity,
  });

  factory ValidationCheck.fromJson(Map<String, dynamic> json) {
    return ValidationCheck(
      field: json['field'] as String,
      label: json['label'] as String,
      passed: json['passed'] as bool,
      value: json['value'] as String?,
      severity: json['severity'] as String? ?? 'error',
    );
  }
}

class FilingValidationSheet extends StatelessWidget {
  final List<ValidationCheck> checks;
  final bool ready;
  final VoidCallback onFile;
  final bool filing;

  const FilingValidationSheet({
    super.key,
    required this.checks,
    required this.ready,
    required this.onFile,
    this.filing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text(
                  'Filing Checklist',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                if (ready)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'READY',
                      style: TextStyle(
                        color: AppColors.success,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'NOT READY',
                      style: TextStyle(
                        color: AppColors.error,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Checks list
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: checks.length,
              itemBuilder: (context, index) {
                final check = checks[index];
                return _CheckRow(check: check);
              },
            ),
          ),

          // File button
          const Divider(height: 1),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: ready && !filing ? onFile : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    disabledBackgroundColor:
                        AppColors.accent.withValues(alpha: 0.3),
                    disabledForegroundColor:
                        Colors.white.withValues(alpha: 0.5),
                  ),
                  child: filing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'File Flight Plan',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  final ValidationCheck check;

  const _CheckRow({required this.check});

  @override
  Widget build(BuildContext context) {
    final isWarning = check.severity == 'warning';
    final icon = check.passed
        ? Icons.check_circle
        : isWarning
            ? Icons.warning_amber_rounded
            : Icons.cancel;
    final color = check.passed
        ? AppColors.success
        : isWarning
            ? AppColors.warning
            : AppColors.error;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  check.label,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (check.value != null)
                  Text(
                    check.value!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
