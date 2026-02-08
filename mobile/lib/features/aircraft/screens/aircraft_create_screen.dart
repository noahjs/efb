import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/aircraft_providers.dart';

class AircraftCreateScreen extends ConsumerStatefulWidget {
  const AircraftCreateScreen({super.key});

  @override
  ConsumerState<AircraftCreateScreen> createState() =>
      _AircraftCreateScreenState();
}

class _AircraftCreateScreenState extends ConsumerState<AircraftCreateScreen> {
  final _tailController = TextEditingController();
  final _typeController = TextEditingController();
  final _icaoController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _tailController.dispose();
    _typeController.dispose();
    _icaoController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final tail = _tailController.text.trim().toUpperCase();
    final type = _typeController.text.trim();
    if (tail.isEmpty || type.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tail number and type are required')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final service = ref.read(aircraftServiceProvider);
      final aircraft = await service.createAircraft({
        'tail_number': tail,
        'aircraft_type': type,
        if (_icaoController.text.trim().isNotEmpty)
          'icao_type_code': _icaoController.text.trim().toUpperCase(),
      });
      ref.invalidate(aircraftListProvider(''));
      if (mounted) {
        context.go('/aircraft/${aircraft.id}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/aircraft'),
        ),
        title: const Text('New Aircraft'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _saving ? null : _create,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save',
                    style: TextStyle(color: AppColors.accent)),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tail Number *',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: _tailController,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(hintText: 'e.g. N12345'),
            ),
            const SizedBox(height: 20),
            const Text('Aircraft Type *',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: _typeController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(hintText: 'e.g. TBM 960'),
            ),
            const SizedBox(height: 20),
            const Text('ICAO Type Code',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            TextField(
              controller: _icaoController,
              textCapitalization: TextCapitalization.characters,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: const InputDecoration(hintText: 'e.g. TBM9'),
            ),
          ],
        ),
      ),
    );
  }
}
