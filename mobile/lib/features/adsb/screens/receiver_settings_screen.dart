import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../models/connection_state.dart';
import '../models/receiver_config.dart';
import '../providers/adsb_providers.dart';

/// Full-screen settings for ADS-B receiver connection management.
///
/// Sections:
/// 1. Active Connection — status, receiver info, disconnect
/// 2. Discovered Devices — auto-discovered via ForeFlight broadcast
/// 3. Manual Connection — IP address entry
/// 4. Saved Receivers — previously connected receivers
/// 5. GPS Source — toggle external vs device GPS
/// 6. Diagnostics — message counts, errors
class ReceiverSettingsScreen extends ConsumerStatefulWidget {
  const ReceiverSettingsScreen({super.key});

  @override
  ConsumerState<ReceiverSettingsScreen> createState() =>
      _ReceiverSettingsScreenState();
}

class _ReceiverSettingsScreenState
    extends ConsumerState<ReceiverSettingsScreen> {
  final _ipController = TextEditingController();
  final _portController = TextEditingController(text: '4000');

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(receiverStatusProvider);
    final savedReceivers = ref.watch(savedReceiversProvider);
    final gpsSource = ref.watch(gpsSourceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ADS-B Receiver'),
        backgroundColor: AppColors.toolbarBackground,
      ),
      backgroundColor: AppColors.background,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Active Connection ──
          _buildSectionHeader('Active Connection'),
          _buildConnectionCard(status),
          const SizedBox(height: 24),

          // ── Manual Connection ──
          _buildSectionHeader('Manual Connection'),
          _buildManualConnectionCard(),
          const SizedBox(height: 24),

          // ── Saved Receivers ──
          _buildSectionHeader('Saved Receivers'),
          savedReceivers.when(
            data: (receivers) => receivers.isEmpty
                ? _buildEmptyCard('No saved receivers')
                : Column(
                    children: receivers
                        .map((r) => _buildReceiverTile(r))
                        .toList(),
                  ),
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (_, _) => _buildEmptyCard('Error loading receivers'),
          ),
          const SizedBox(height: 24),

          // ── GPS Source ──
          _buildSectionHeader('GPS Source'),
          Card(
            color: AppColors.surface,
            child: SwitchListTile(
              title: const Text(
                'Prefer External GPS',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
              ),
              subtitle: Text(
                gpsSource == GpsSource.external
                    ? 'Using GPS from ADS-B receiver (higher accuracy)'
                    : 'Using device GPS only',
                style:
                    const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
              value: gpsSource == GpsSource.external,
              onChanged: (value) {
                ref.read(gpsSourceProvider.notifier).set(
                    value ? GpsSource.external : GpsSource.device);
              },
              activeTrackColor: AppColors.accent,
            ),
          ),
          const SizedBox(height: 24),

          // ── Diagnostics ──
          _buildSectionHeader('Diagnostics'),
          _buildDiagnosticsCard(status),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildConnectionCard(AdsbStatus status) {
    final isActive = status.status == AdsbConnectionStatus.connected ||
        status.status == AdsbConnectionStatus.stale;

    return Card(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isActive ? Icons.sensors : Icons.sensors_off,
                  color: isActive ? AppColors.success : AppColors.textMuted,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _statusText(status.status),
                  style: TextStyle(
                    color: isActive
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (status.receiverName != null) ...[
              const SizedBox(height: 8),
              Text(
                'Receiver: ${status.receiverName}',
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 13),
              ),
            ],
            if (status.receiverIp != null) ...[
              const SizedBox(height: 4),
              Text(
                'IP: ${status.receiverIp}',
                style:
                    const TextStyle(color: AppColors.textMuted, fontSize: 12),
              ),
            ],
            if (isActive) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _disconnect,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                  ),
                  child: const Text('Disconnect'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildManualConnectionCard() {
    return Card(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _ipController,
              style:
                  const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: const InputDecoration(
                labelText: 'IP Address',
                labelStyle: TextStyle(color: AppColors.textMuted),
                hintText: '192.168.10.1',
                hintStyle: TextStyle(color: AppColors.textMuted),
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _portController,
              style:
                  const TextStyle(color: AppColors.textPrimary, fontSize: 14),
              decoration: const InputDecoration(
                labelText: 'Port',
                labelStyle: TextStyle(color: AppColors.textMuted),
                hintText: '4000',
                hintStyle: TextStyle(color: AppColors.textMuted),
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _connectManual,
                icon: const Icon(Icons.link, size: 18),
                label: const Text('Connect'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReceiverTile(ReceiverConfig receiver) {
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 4),
      child: ListTile(
        leading: Icon(
          Icons.sensors,
          color: receiver.isPreferred
              ? AppColors.accent
              : AppColors.textMuted,
        ),
        title: Text(
          receiver.name,
          style:
              const TextStyle(color: AppColors.textPrimary, fontSize: 14),
        ),
        subtitle: Text(
          [
            receiver.deviceType,
            if (receiver.ipAddress != null) receiver.ipAddress,
            if (receiver.lastConnected != null)
              'Last: ${_formatDate(receiver.lastConnected!)}',
          ].join(' \u2022 '),
          style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                receiver.isPreferred ? Icons.star : Icons.star_border,
                color: receiver.isPreferred
                    ? AppColors.warning
                    : AppColors.textMuted,
                size: 20,
              ),
              onPressed: () => _togglePreferred(receiver),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: AppColors.textMuted, size: 20),
              onPressed: () =>
                  removeReceiver(ref, receiver.name),
            ),
          ],
        ),
        onTap: () => _connectToReceiver(receiver),
      ),
    );
  }

  Widget _buildDiagnosticsCard(AdsbStatus status) {
    return Card(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _diagRow('Messages received', '${status.messageCount}'),
            _diagRow('Parse errors', '${status.errorCount}'),
            _diagRow('Traffic targets', '${status.trafficCount}'),
            _diagRow('GPS valid', status.gpsPositionValid ? 'Yes' : 'No'),
            _diagRow(
              'Last heartbeat',
              status.lastHeartbeat != null
                  ? '${DateTime.now().difference(status.lastHeartbeat!).inSeconds}s ago'
                  : 'Never',
            ),
          ],
        ),
      ),
    );
  }

  Widget _diagRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
          Text(value,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildEmptyCard(String message) {
    return Card(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            message,
            style:
                const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ),
      ),
    );
  }

  String _statusText(AdsbConnectionStatus status) {
    switch (status) {
      case AdsbConnectionStatus.connected:
        return 'Connected';
      case AdsbConnectionStatus.stale:
        return 'Signal Lost';
      case AdsbConnectionStatus.scanning:
        return 'Scanning...';
      case AdsbConnectionStatus.connecting:
        return 'Connecting...';
      case AdsbConnectionStatus.disconnected:
        return 'Not Connected';
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void _connectManual() {
    final ip = _ipController.text.trim();
    if (ip.isEmpty) return;
    final port = int.tryParse(_portController.text.trim()) ?? 4000;

    final cm = ref.read(connectionManagerProvider);
    cm.setReceiverName('Manual ($ip)');
    cm.connect(ipAddress: ip, port: port);

    // Save for future use
    saveReceiver(
      ref,
      ReceiverConfig(
        name: 'Manual ($ip)',
        ipAddress: ip,
        port: port,
        lastConnected: DateTime.now(),
      ),
    );
  }

  void _connectToReceiver(ReceiverConfig receiver) {
    final cm = ref.read(connectionManagerProvider);
    cm.setReceiverName(receiver.name);
    cm.connect(
      ipAddress: receiver.ipAddress,
      port: receiver.port,
    );
  }

  void _disconnect() {
    ref.read(connectionManagerProvider).disconnect();
  }

  void _togglePreferred(ReceiverConfig receiver) {
    saveReceiver(
      ref,
      receiver.copyWith(isPreferred: !receiver.isPreferred),
    );
  }
}
