import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/fbo.dart';

class FboDetailScreen extends StatelessWidget {
  final Fbo fbo;

  const FboDetailScreen({super.key, required this.fbo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(fbo.name),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        children: [
          _HeaderSection(fbo: fbo),
          if (_hasContactInfo) _ContactSection(fbo: fbo),
          if (fbo.fuelPrices.isNotEmpty) _FuelPricesSection(fbo: fbo),
          if (fbo.description != null && fbo.description!.isNotEmpty)
            _AboutSection(description: fbo.description!),
          if (fbo.badges.isNotEmpty) _BadgesSection(badges: fbo.badges),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  bool get _hasContactInfo =>
      fbo.phone != null ||
      fbo.tollFreePhone != null ||
      fbo.email != null ||
      fbo.website != null ||
      fbo.asriFrequency != null;
}

class _HeaderSection extends StatelessWidget {
  final Fbo fbo;

  const _HeaderSection({required this.fbo});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fbo.name,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          if (fbo.fuelBrand != null)
            Text(
              fbo.fuelBrand!,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          if (fbo.rating != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                ...List.generate(5, (i) {
                  final starValue = i + 1;
                  if (fbo.rating! >= starValue) {
                    return const Icon(Icons.star,
                        size: 18, color: Colors.amber);
                  } else if (fbo.rating! >= starValue - 0.5) {
                    return const Icon(Icons.star_half,
                        size: 18, color: Colors.amber);
                  }
                  return Icon(Icons.star_border,
                      size: 18, color: Colors.amber.withValues(alpha: 0.4));
                }),
                const SizedBox(width: 8),
                Text(
                  fbo.rating!.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ContactSection extends StatelessWidget {
  final Fbo fbo;

  const _ContactSection({required this.fbo});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Contact'),
        if (fbo.phone != null)
          _ContactRow(
            icon: Icons.phone,
            label: 'Phone',
            value: fbo.phone!,
            onTap: () => launchUrl(Uri.parse('tel:${fbo.phone}')),
          ),
        if (fbo.tollFreePhone != null)
          _ContactRow(
            icon: Icons.phone,
            label: 'Toll-Free',
            value: fbo.tollFreePhone!,
            onTap: () => launchUrl(Uri.parse('tel:${fbo.tollFreePhone}')),
          ),
        if (fbo.email != null)
          _ContactRow(
            icon: Icons.email_outlined,
            label: 'Email',
            value: fbo.email!,
            onTap: () => launchUrl(Uri.parse('mailto:${fbo.email}')),
          ),
        if (fbo.website != null)
          _ContactRow(
            icon: Icons.language,
            label: 'Website',
            value: fbo.website!,
            onTap: () {
              final url = fbo.website!.startsWith('http')
                  ? fbo.website!
                  : 'https://${fbo.website}';
              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
            },
          ),
        if (fbo.asriFrequency != null)
          _ContactRow(
            icon: Icons.radio,
            label: 'ASRI',
            value: fbo.asriFrequency!,
          ),
      ],
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.divider, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.textMuted),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textSecondary),
            ),
            const Spacer(),
            Flexible(
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  color: onTap != null ? AppColors.accent : AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onTap != null)
              const Padding(
                padding: EdgeInsets.only(left: 4),
                child: Icon(Icons.chevron_right,
                    size: 18, color: AppColors.textMuted),
              ),
          ],
        ),
      ),
    );
  }
}

class _FuelPricesSection extends StatelessWidget {
  final Fbo fbo;

  const _FuelPricesSection({required this.fbo});

  @override
  Widget build(BuildContext context) {
    // Group prices by fuel type
    final grouped = <String, List<FuelPrice>>{};
    for (final fp in fbo.fuelPrices) {
      grouped.putIfAbsent(fp.fuelType, () => []).add(fp);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Fuel Prices'),
        // Table header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: AppColors.surfaceLight,
          child: const Row(
            children: [
              Expanded(flex: 3, child: Text('Fuel', style: _headerStyle)),
              Expanded(
                  flex: 2,
                  child: Text('Self-Serve',
                      style: _headerStyle, textAlign: TextAlign.right)),
              Expanded(
                  flex: 2,
                  child: Text('Full-Service',
                      style: _headerStyle, textAlign: TextAlign.right)),
            ],
          ),
        ),
        ...grouped.entries.map((entry) {
          final ss = entry.value
              .where((fp) => fp.serviceLevel == 'SS')
              .toList();
          final fs = entry.value
              .where((fp) => fp.serviceLevel == 'FS')
              .toList();

          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.divider, width: 0.5),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    entry.key,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: ss.isNotEmpty
                      ? _PriceCell(price: ss.first)
                      : const Text('—',
                          textAlign: TextAlign.right,
                          style: TextStyle(color: AppColors.textMuted)),
                ),
                Expanded(
                  flex: 2,
                  child: fs.isNotEmpty
                      ? _PriceCell(price: fs.first)
                      : const Text('—',
                          textAlign: TextAlign.right,
                          style: TextStyle(color: AppColors.textMuted)),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  static const _headerStyle = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textMuted,
    letterSpacing: 0.5,
  );
}

class _PriceCell extends StatelessWidget {
  final FuelPrice price;

  const _PriceCell({required this.price});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '\$${price.price.toStringAsFixed(2)}',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        if (price.isGuaranteed) ...[
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(3),
            ),
            child: const Text(
              'G',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: AppColors.success,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _AboutSection extends StatelessWidget {
  final String description;

  const _AboutSection({required this.description});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('About'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            description,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _BadgesSection extends StatelessWidget {
  final List<String> badges;

  const _BadgesSection({required this.badges});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Badges'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: badges
                .map((badge) => Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: AppColors.divider, width: 0.5),
                      ),
                      child: Text(
                        badge,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}

Widget _sectionTitle(String title) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
    margin: const EdgeInsets.only(top: 4),
    decoration: const BoxDecoration(
      color: AppColors.surface,
      border: Border(
        top: BorderSide(color: AppColors.divider, width: 0.5),
      ),
    ),
    child: Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
        color: AppColors.textMuted,
      ),
    ),
  );
}
