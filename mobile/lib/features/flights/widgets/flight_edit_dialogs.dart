import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

Future<String?> showTextEditSheet(
  BuildContext context, {
  required String title,
  required String currentValue,
  String? hintText,
}) async {
  final controller = TextEditingController(text: currentValue);
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  )),
              TextButton(
                onPressed: () => Navigator.pop(ctx, controller.text),
                child:
                    const Text('Done', style: TextStyle(color: AppColors.accent)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            autofocus: true,
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(hintText: hintText),
            onSubmitted: (val) => Navigator.pop(ctx, val),
          ),
        ],
      ),
    ),
  );
}

Future<double?> showNumberEditSheet(
  BuildContext context, {
  required String title,
  required double? currentValue,
  String? hintText,
  String? suffix,
}) async {
  final controller =
      TextEditingController(text: currentValue?.toString() ?? '');
  return showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  )),
              TextButton(
                onPressed: () {
                  final val = double.tryParse(controller.text);
                  Navigator.pop(ctx, val);
                },
                child:
                    const Text('Done', style: TextStyle(color: AppColors.accent)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: hintText,
              suffixText: suffix,
            ),
            onSubmitted: (val) {
              final parsed = double.tryParse(val);
              Navigator.pop(ctx, parsed);
            },
          ),
        ],
      ),
    ),
  );
}

Future<String?> showPickerSheet(
  BuildContext context, {
  required String title,
  required List<String> options,
  required String? currentValue,
}) async {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: AppColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
    ),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              )),
          const SizedBox(height: 12),
          ...options.map((option) => ListTile(
                title: Text(option,
                    style: const TextStyle(color: AppColors.textPrimary)),
                trailing: option == currentValue
                    ? const Icon(Icons.check, color: AppColors.accent, size: 20)
                    : null,
                onTap: () => Navigator.pop(ctx, option),
              )),
        ],
      ),
    ),
  );
}

Future<DateTime?> showDateTimePickerSheet(
  BuildContext context, {
  required String title,
  DateTime? initialDate,
}) async {
  final date = await showDatePicker(
    context: context,
    initialDate: initialDate ?? DateTime.now(),
    firstDate: DateTime(2020),
    lastDate: DateTime(2030),
    builder: (context, child) => Theme(
      data: Theme.of(context).copyWith(
        colorScheme: const ColorScheme.dark(
          primary: AppColors.accent,
          surface: AppColors.surface,
        ),
      ),
      child: child!,
    ),
  );
  if (date == null || !context.mounted) return null;

  final time = await showTimePicker(
    context: context,
    initialTime: initialDate != null
        ? TimeOfDay.fromDateTime(initialDate)
        : TimeOfDay.now(),
    builder: (context, child) => Theme(
      data: Theme.of(context).copyWith(
        colorScheme: const ColorScheme.dark(
          primary: AppColors.accent,
          surface: AppColors.surface,
        ),
      ),
      child: child!,
    ),
  );
  if (time == null) return null;

  return DateTime(date.year, date.month, date.day, time.hour, time.minute);
}
