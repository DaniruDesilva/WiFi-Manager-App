import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../providers/history_provider.dart';
import '../models/wifi_network.dart';
import 'dart:convert';
import 'guest_card_screen.dart';
import 'generate_screen.dart';
import '../utils/constants.dart';
import '../utils/network_detail_sheet.dart';

class DashboardScreen extends StatelessWidget {
  final Function(int) onTabSelected;

  const DashboardScreen({super.key, required this.onTabSelected});

  @override
  Widget build(BuildContext context) {
    return Consumer<HistoryProvider>(
      builder: (context, historyProvider, child) {
        final history = historyProvider.history;
        final recentNetwork = history.isNotEmpty ? history.first : null;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Share Wi-Fi\ninstantly',
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
              ).animate().fade().slideY(begin: 0.2),
              
              const SizedBox(height: 8),
              Text(
                'Create a QR code so guests connect\nwithout typing passwords.',
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.light ? Colors.grey.shade700 : Colors.grey.shade400,
                  fontSize: 16,
                ),
              ).animate().fade(delay: 100.ms).slideY(begin: 0.2),
              
              const SizedBox(height: 32),
              
              if (recentNetwork != null) ...[
                _buildHeroCard(context, recentNetwork).animate().fade(delay: 200.ms).scale(),
                const SizedBox(height: 32),
              ] else ...[
                _buildEmptyHeroCard(context).animate().fade(delay: 200.ms).scale(),
                const SizedBox(height: 32),
              ],

              // Quick Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildQuickAction(
                    context, 
                    'Scan to\nConnect', 
                    FluentIcons.scan_24_regular, 
                    () => onTabSelected(1), // Scan tab
                    0,
                  ),
                  _buildQuickAction(
                    context, 
                    'Create\nQR Code', 
                    FluentIcons.add_circle_24_regular, 
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const GenerateScreen()),
                      );
                    },
                    1,
                  ),
                  _buildQuickAction(
                    context, 
                    'Make\nGuest Card', 
                    FluentIcons.card_ui_24_regular, 
                    () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => GuestCardScreen(network: recentNetwork)),
                      );
                    },
                    2,
                  ),
                ],
              ),
              
              const SizedBox(height: 48),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Saved networks', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  TextButton(
                    onPressed: () => onTabSelected(2),
                    child: Text('${history.length} saved', style: const TextStyle(fontWeight: FontWeight.bold)),
                  )
                ],
              ).animate().fade(delay: 400.ms),
              
              const SizedBox(height: 16),
              
              if (history.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Text('No saved networks yet.', style: TextStyle(color: Colors.grey.shade500)),
                  ),
                )
              else
                ...history.take(3).map((n) => _buildMiniNetworkTile(context, n)).toList(),
                
              const SizedBox(height: 48), // Bottom padding
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeroCard(BuildContext context, WifiNetwork network) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'YOUR WI-FI QR CODE',
                        style: TextStyle(color: Color(0x990F172A), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        network.ssid,
                        style: const TextStyle(color: Color(0xFF0F172A), fontSize: 24, fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        network.securityType,
                        style: const TextStyle(color: Color(0x990F172A), fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(FluentIcons.wifi_1_24_filled, color: Color(0xFF0F172A)),
                ),
              ],
            ),
          ),
          
          Center(
            child: Container(
              padding: const EdgeInsets.all(8),
              margin: const EdgeInsets.symmetric(horizontal: 24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: QrImageView(
                data: network.qrData,
                version: QrVersions.auto,
                size: 140.0,
                backgroundColor: Colors.white,
                dataModuleStyle: QrDataModuleStyle(
                  dataModuleShape: network.isSquareDots ? QrDataModuleShape.square : QrDataModuleShape.circle,
                  color: network.qrColorHex != null ? Color(int.parse(network.qrColorHex!, radix: 16)) : Colors.black,
                ),
                eyeStyle: QrEyeStyle(
                  eyeShape: network.isSquareEyes ? QrEyeShape.square : QrEyeShape.circle,
                  color: network.qrColorHex != null ? Color(int.parse(network.qrColorHex!, radix: 16)) : Colors.black,
                ),
                embeddedImage: MemoryImage(base64Decode(AppConstants.wifiLogoBase64)),
                embeddedImageStyle: const QrEmbeddedImageStyle(size: Size(24, 24)),
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                const Icon(FluentIcons.shield_checkmark_24_filled, color: Color(0xFF0F172A)),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Network secured', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
                      Text('Guests can connect in seconds.', style: TextStyle(color: Color(0x990F172A), fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
  
  Widget _buildEmptyHeroCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: const Color(0xFF0F172A).withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(FluentIcons.qr_code_24_regular, size: 64, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 24),
          const Text(
            'Create your first QR',
            style: TextStyle(color: Color(0xFF0F172A), fontSize: 24, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Get started by adding your home or guest Wi-Fi network.',
            style: TextStyle(color: Color(0x990F172A), fontSize: 14),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const GenerateScreen()),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            icon: const Icon(FluentIcons.add_24_regular),
            label: const Text('Create WiFi QR', style: TextStyle(fontWeight: FontWeight.bold)),
          )
        ],
      ),
    );
  }

  Widget _buildQuickAction(BuildContext context, String title, IconData icon, VoidCallback onTap, int delayMultiplier) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, spreadRadius: 1),
            ],
          ),
          child: Column(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary, size: 28),
              const SizedBox(height: 12),
              Text(
                title, 
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ],
          ),
        ),
      ).animate().fade(delay: (300 + (delayMultiplier * 100)).ms).slideY(begin: 0.2),
    );
  }

  Widget _buildMiniNetworkTile(BuildContext context, WifiNetwork network) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 5)],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(FluentIcons.wifi_1_24_regular, color: Theme.of(context).colorScheme.primary),
        ),
        title: Text(network.ssid, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(network.securityType, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
        trailing: const Icon(FluentIcons.chevron_right_24_regular, color: Colors.grey),
        onTap: () => showNetworkDetailsSheet(context, network),
      ),
    ).animate().fade(delay: 500.ms);
  }
}

