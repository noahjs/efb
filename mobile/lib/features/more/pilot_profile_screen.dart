import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../services/user_providers.dart';
import '../flights/widgets/flight_section_header.dart';
import '../flights/widgets/flight_field_row.dart';
import '../flights/widgets/flight_edit_dialogs.dart';

class PilotProfileScreen extends ConsumerStatefulWidget {
  const PilotProfileScreen({super.key});

  @override
  ConsumerState<PilotProfileScreen> createState() =>
      _PilotProfileScreenState();
}

class _PilotProfileScreenState extends ConsumerState<PilotProfileScreen> {
  Map<String, dynamic> _profile = {};
  bool _loaded = false;
  bool _saving = false;

  Future<void> _saveField(Map<String, dynamic> updates) async {
    setState(() => _saving = true);
    try {
      final service = ref.read(userProfileServiceProvider);
      final updated = await service.updateProfile(updates);
      setState(() {
        _profile = updated.toJson();
        // Also carry forward read-only fields
        _profile['id'] = updated.id;
        _profile['email'] = updated.email;
      });
      ref.invalidate(userProfileProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      final profileAsync = ref.watch(userProfileProvider);
      return profileAsync.when(
        loading: () => Scaffold(
          appBar: AppBar(title: const Text('Pilot Profile')),
          body: const Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Scaffold(
          appBar: AppBar(title: const Text('Pilot Profile')),
          body: Center(child: Text('Error: $e')),
        ),
        data: (profile) {
          if (!_loaded) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              setState(() {
                _profile = {
                  'name': profile.name,
                  'pilot_name': profile.pilotName,
                  'phone_number': profile.phoneNumber,
                  'pilot_certificate_number': profile.pilotCertificateNumber,
                  'pilot_certificate_type': profile.pilotCertificateType,
                  'home_base': profile.homeBase,
                  'leidos_username': profile.leidosUsername,
                };
                _loaded = true;
              });
            });
          }
          return _buildScaffold();
        },
      );
    }
    return _buildScaffold();
  }

  Widget _buildScaffold() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pilot Profile'),
        centerTitle: true,
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        children: [
          const FlightSectionHeader(title: 'Pilot Information'),
          FlightFieldRow(
            label: 'Pilot Name (PIC)',
            value: _profile['pilot_name'] ?? '--',
            onTap: () async {
              final result = await showTextEditSheet(
                context,
                title: 'Pilot Name (PIC)',
                currentValue: _profile['pilot_name'] ?? '',
                hintText: 'Full name as on certificate',
              );
              if (result != null) _saveField({'pilot_name': result});
            },
          ),
          FlightFieldRow(
            label: 'Phone Number',
            value: _profile['phone_number'] ?? '--',
            onTap: () async {
              final result = await showTextEditSheet(
                context,
                title: 'Phone Number',
                currentValue: _profile['phone_number'] ?? '',
                hintText: 'Contact for flight service',
              );
              if (result != null) _saveField({'phone_number': result});
            },
          ),

          const FlightSectionHeader(title: 'Certificate'),
          FlightFieldRow(
            label: 'Certificate Number',
            value: _profile['pilot_certificate_number'] ?? '--',
            onTap: () async {
              final result = await showTextEditSheet(
                context,
                title: 'Certificate Number',
                currentValue: _profile['pilot_certificate_number'] ?? '',
                hintText: 'FAA certificate number',
              );
              if (result != null) {
                _saveField({'pilot_certificate_number': result});
              }
            },
          ),
          FlightFieldRow(
            label: 'Certificate Type',
            value: _formatCertType(_profile['pilot_certificate_type']),
            onTap: () async {
              final result = await showPickerSheet(
                context,
                title: 'Certificate Type',
                options: const [
                  'student',
                  'sport',
                  'recreational',
                  'private',
                  'commercial',
                  'atp',
                ],
                currentValue: _profile['pilot_certificate_type'],
              );
              if (result != null) {
                _saveField({'pilot_certificate_type': result});
              }
            },
          ),

          const FlightSectionHeader(title: 'Preferences'),
          FlightFieldRow(
            label: 'Home Base',
            value: _profile['home_base'] ?? '--',
            onTap: () async {
              final result = await showTextEditSheet(
                context,
                title: 'Home Base',
                currentValue: _profile['home_base'] ?? '',
                hintText: 'Airport identifier (e.g. APA)',
              );
              if (result != null) _saveField({'home_base': result});
            },
          ),

          const FlightSectionHeader(title: 'Flight Services'),
          FlightFieldRow(
            label: '1800wxbrief Username',
            value: _profile['leidos_username'] ?? '--',
            onTap: () async {
              final result = await showTextEditSheet(
                context,
                title: '1800wxbrief Username',
                currentValue: _profile['leidos_username'] ?? '',
                hintText: 'Leidos Flight Service account',
              );
              if (result != null) _saveField({'leidos_username': result});
            },
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            child: Text(
              'Used for electronic flight plan filing via Leidos Flight Service.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  String _formatCertType(String? type) {
    if (type == null || type.isEmpty) return '--';
    switch (type) {
      case 'atp':
        return 'ATP';
      default:
        return '${type[0].toUpperCase()}${type.substring(1)}';
    }
  }
}
