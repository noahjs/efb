import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../models/certificate.dart';
import '../../services/certificates_providers.dart';

class CertificatesScreen extends ConsumerStatefulWidget {
  const CertificatesScreen({super.key});

  @override
  ConsumerState<CertificatesScreen> createState() => _CertificatesScreenState();
}

class _CertificatesScreenState extends ConsumerState<CertificatesScreen> {
  @override
  Widget build(BuildContext context) {
    final certificatesAsync = ref.watch(certificatesListProvider(''));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/logbook'),
        ),
        title: const Text('Certificates & Ratings'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            color: AppColors.accent,
            onPressed: () => context.go('/certificates/new'),
          ),
        ],
      ),
      body: certificatesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  color: AppColors.error, size: 48),
              const SizedBox(height: 16),
              Text('Failed to load certificates',
                  style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () =>
                    ref.invalidate(certificatesListProvider('')),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (certificates) {
          if (certificates.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.card_membership_outlined,
                      size: 64, color: AppColors.textMuted),
                  const SizedBox(height: 16),
                  const Text('No Certificates',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      )),
                  const SizedBox(height: 8),
                  const Text('Tap + to add a certificate or rating',
                      style: TextStyle(color: AppColors.textSecondary)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: certificates.length,
            itemBuilder: (context, index) =>
                _buildCertificateCard(certificates[index]),
          );
        },
      ),
    );
  }

  Widget _buildCertificateCard(Certificate cert) {
    final type = cert.certificateType ?? 'Untitled';
    final cls = cert.certificateClass ?? '';
    final number = cert.certificateNumber ?? '';

    // Expiration color coding
    Color? expirationColor;
    String expirationDisplay = '';
    if (cert.expirationDate != null) {
      try {
        final expDate = DateTime.parse(cert.expirationDate!);
        final now = DateTime.now();
        final daysUntil = expDate.difference(now).inDays;

        expirationDisplay = DateFormat('MMM d, yyyy').format(expDate);

        if (daysUntil < 0) {
          expirationColor = AppColors.error;
        } else if (daysUntil <= 30) {
          expirationColor = Colors.orange;
        } else {
          expirationColor = Colors.green;
        }
      } catch (_) {
        expirationDisplay = cert.expirationDate!;
      }
    }

    return InkWell(
      onTap: () {
        if (cert.id != null) {
          context.go('/certificates/${cert.id}');
        }
      },
      child: Container(
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.divider, width: 0.5),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _formatType(type),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (cls.isNotEmpty)
                        Text(
                          _formatClass(cls),
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      if (cls.isNotEmpty && number.isNotEmpty)
                        const Text(
                          '  \u2022  ',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                        ),
                      if (number.isNotEmpty)
                        Text(
                          '#$number',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (expirationDisplay.isNotEmpty)
              Row(
                children: [
                  if (expirationColor != null)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: expirationColor,
                      ),
                    ),
                  Text(
                    expirationDisplay,
                    style: TextStyle(
                      fontSize: 13,
                      color: expirationColor ?? AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right,
                color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }

  String _formatType(String type) {
    switch (type) {
      case 'pilot':
        return 'Pilot Certificate';
      case 'medical':
        return 'Medical Certificate';
      case 'type_rating':
        return 'Type Rating';
      case 'instructor':
        return 'Instructor Certificate';
      default:
        return type;
    }
  }

  String _formatClass(String cls) {
    switch (cls) {
      case 'student':
        return 'Student';
      case 'sport':
        return 'Sport';
      case 'recreational':
        return 'Recreational';
      case 'private':
        return 'Private';
      case 'commercial':
        return 'Commercial';
      case 'atp':
        return 'ATP';
      case 'first_class':
        return 'First Class';
      case 'second_class':
        return 'Second Class';
      case 'third_class':
        return 'Third Class';
      case 'basicmed':
        return 'BasicMed';
      case 'cfi':
        return 'CFI';
      case 'cfii':
        return 'CFII';
      case 'mei':
        return 'MEI';
      default:
        return cls;
    }
  }
}
