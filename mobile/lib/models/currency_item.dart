import 'package:flutter/material.dart';

class CurrencyItem {
  final String name;
  final String rule;
  final String status;
  final String? expirationDate;
  final String details;
  final String? actionRequired;

  const CurrencyItem({
    required this.name,
    required this.rule,
    required this.status,
    this.expirationDate,
    required this.details,
    this.actionRequired,
  });

  factory CurrencyItem.fromJson(Map<String, dynamic> json) {
    return CurrencyItem(
      name: json['name'] as String? ?? '',
      rule: json['rule'] as String? ?? '',
      status: json['status'] as String? ?? 'expired',
      expirationDate: json['expiration_date'] as String?,
      details: json['details'] as String? ?? '',
      actionRequired: json['action_required'] as String?,
    );
  }

  Color get statusColor {
    switch (status) {
      case 'current':
        return Colors.green;
      case 'expiring_soon':
        return Colors.orange;
      case 'expired':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String get statusLabel {
    switch (status) {
      case 'current':
        return 'Current';
      case 'expiring_soon':
        return 'Expiring Soon';
      case 'expired':
        return 'Expired';
      default:
        return status;
    }
  }
}
