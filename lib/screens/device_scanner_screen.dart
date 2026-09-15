import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/device_scanner_provider.dart';
import 'router_admin_screen.dart';

class DeviceScannerScreen extends StatelessWidget {
  const DeviceScannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Who's on My Wi-Fi?", style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Consumer<DeviceScannerProvider>(
        builder: (context, scanner, child) {
          return Column(
            children: [
              // Scan Header
              _buildScanHeader(context, scanner),

              // Results
              Expanded(
                child: scanner.devices.isEmpty && !scanner.isScanning
                    ? _buildEmptyState(context, scanner)
                    : _buildDeviceList(context, scanner),
              ),
            ],
          );
        },
      ),
      floatingActionButton: Consumer<DeviceScannerProvider>(
        builder: (context, scanner, _) {
          if (scanner.devices.isEmpty) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const RouterAdminScreen(),
                ),
              );
            },
            icon: const Icon(FluentIcons.globe_24_filled),
            label: const Text('Manage Router', style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ).animate().scale(delay: 500.ms);
        },
      ),
    );
  }

  Widget _buildScanHeader(BuildContext context, DeviceScannerProvider scanner) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Animated radar icon
          Stack(
            alignment: Alignment.center,
            children: [
              if (scanner.isScanning)
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                  ),
                ).animate(onPlay: (c) => c.repeat())
                    .scale(begin: const Offset(0.5, 0.5), end: const Offset(1.5, 1.5), duration: 1500.ms)
                    .fadeOut(duration: 1500.ms),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Icon(
                  FluentIcons.people_team_24_filled,
                  size: 36,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Device count / status
          Text(
            scanner.isScanning
                ? 'Scanning network...'
                : scanner.devices.isNotEmpty
                    ? '${scanner.devices.length} device${scanner.devices.length != 1 ? 's' : ''} found'
                    : 'Ready to scan',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),

          // Progress bar
          if (scanner.isScanning) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: scanner.progress / 100,
                minHeight: 6,
                backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation(Theme.of(context).colorScheme.primary),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${scanner.progress}%',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
          ],

          if (scanner.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                scanner.errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ),

          const SizedBox(height: 16),
          if (!scanner.isScanning)
            FilledButton.icon(
              onPressed: () => scanner.startScan(),
              icon: const Icon(FluentIcons.wifi_1_24_regular),
              label: Text(
                scanner.devices.isEmpty ? 'Scan Network' : 'Rescan',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ).animate().fade().scale(),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, DeviceScannerProvider scanner) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(FluentIcons.wifi_1_24_regular, size: 80, color: Colors.grey.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          const Text(
            'No devices found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Make sure you are connected to Wi-Fi\nand tap "Scan Network" to start.',
            style: TextStyle(color: Colors.grey.shade500),
            textAlign: TextAlign.center,
          ),
        ],
      ).animate().fade(),
    );
  }

  Widget _buildDeviceList(BuildContext context, DeviceScannerProvider scanner) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: scanner.devices.length,
      itemBuilder: (context, index) {
        final device = scanner.devices[index];
        return Card(
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.05),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _showRenameDialog(context, scanner, device.macAddress ?? '', device.customName ?? ''),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(device.deviceIcon, color: Theme.of(context).colorScheme.primary, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device.displayName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          device.ipAddress,
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                        ),
                        if (device.macAddress != null && device.macAddress!.isNotEmpty)
                          Text(
                            device.macAddress!,
                            style: TextStyle(color: Colors.grey.shade400, fontSize: 11),
                          ),
                      ],
                    ),
                  ),
                  Icon(FluentIcons.edit_24_regular, color: Colors.grey.shade400, size: 20),
                ],
              ),
            ),
          ),
        ).animate().fade(delay: (index * 50).ms).slideX(begin: 0.1);
      },
    );
  }

  void _showRenameDialog(BuildContext context, DeviceScannerProvider scanner, String mac, String currentName) {
    if (mac.isEmpty) return;
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Rename Device', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'e.g., My iPhone',
            filled: true,
            fillColor: Theme.of(ctx).scaffoldBackgroundColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              scanner.renameDevice(mac, controller.text.trim());
              Navigator.pop(ctx);
            },
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
