import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/network_info_provider.dart';
import 'speed_test_screen.dart';
import 'device_scanner_screen.dart';
import 'wifi_analyzer_screen.dart';
import 'router_admin_screen.dart';
import 'router_passwords_screen.dart';
import '../widgets/native_ad_widget.dart';
import '../widgets/banner_ad_widget.dart';

class ToolsDashboardScreen extends StatelessWidget {
  const ToolsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NetworkInfoProvider>(
      builder: (context, netInfo, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Network Tools',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ).animate().fade().slideY(begin: 0.2),
              const SizedBox(height: 8),
              Text(
                'Diagnose, analyze, and manage\nyour Wi-Fi network.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).brightness == Brightness.light
                      ? Colors.grey.shade700
                      : Colors.grey.shade400,
                  fontSize: 16,
                ),
              ).animate().fade(delay: 100.ms).slideY(begin: 0.2),
              const SizedBox(height: 32),

              // Hero Card: Speed Test
              _buildHeroCard(context).animate().fade(delay: 200.ms).scale(),
              const SizedBox(height: 16),

              // Split Row: Device Scanner + Wi-Fi Analyzer
              Row(
                children: [
                  Expanded(
                    child: _buildToolCard(
                      context,
                      icon: FluentIcons.people_team_24_filled,
                      title: "Who's on My Wi-Fi?",
                      subtitle: 'Find connected devices',
                      color: const Color(0xFF7C3AED),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const DeviceScannerScreen()),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildToolCard(
                      context,
                      icon: FluentIcons.cellular_data_1_24_filled,
                      title: 'Wi-Fi Analyzer',
                      subtitle: 'Signal & channels',
                      color: const Color(0xFF059669),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const WifiAnalyzerScreen()),
                      ),
                    ),
                  ),
                ],
              ).animate().fade(delay: 300.ms).slideY(begin: 0.2),
              const SizedBox(height: 16),

              // Network Identity Card
              _buildNetworkIdentityCard(context, netInfo)
                  .animate().fade(delay: 400.ms).slideY(begin: 0.2),
              const SizedBox(height: 16),

              // Native Ad
              const Center(child: NativeAdWidget()),
              const SizedBox(height: 16),

              // Router Tools Row
              Row(
                children: [
                  Expanded(
                    child: _buildCompactToolCard(
                      context,
                      icon: FluentIcons.globe_24_filled,
                      title: 'Router Admin',
                      color: const Color(0xFFDC2626),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RouterAdminScreen(
                            gatewayIp: netInfo.gatewayIp,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildCompactToolCard(
                      context,
                      icon: FluentIcons.key_24_filled,
                      title: 'Default Passwords',
                      color: const Color(0xFFD97706),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RouterPasswordsScreen()),
                      ),
                    ),
                  ),
                ],
              ).animate().fade(delay: 500.ms).slideY(begin: 0.2),

              const SizedBox(height: 24),
              const BannerAdWidget(),
              const SizedBox(height: 48),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeroCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtextColor = isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0x990F172A);
    final iconBgColor = isDark ? Colors.white.withValues(alpha: 0.2) : Theme.of(context).colorScheme.primary.withValues(alpha: 0.1);
    final iconColor = isDark ? Colors.white : Theme.of(context).colorScheme.primary;
    
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SpeedTestScreen()),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16.0, sigmaY: 16.0),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
                width: isDark ? 1.5 : 0.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.06),
                  blurRadius: isDark ? 24 : 16,
                  spreadRadius: 0,
                  offset: Offset(0, isDark ? 12 : 8),
                ),
              ],
            ),
            child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(FluentIcons.top_speed_24_filled, color: iconColor, size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Internet Speed Test',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Test download & upload speeds',
                    style: TextStyle(
                      color: subtextColor,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: iconBgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(FluentIcons.chevron_right_24_regular, color: iconColor),
            ),
          ],
        ),
      ),
      ),
      ),
    );
  }

  Widget _buildToolCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        height: 160,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 16,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, height: 1.2),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(color: isDark ? Colors.grey.shade400 : Colors.grey.shade600, fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactToolCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        height: 100,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 16,
              spreadRadius: 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, height: 1.2),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkIdentityCard(BuildContext context, NetworkInfoProvider netInfo) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.2 : 0.04),
            blurRadius: 16,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(FluentIcons.globe_24_filled, size: 22, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              const Text('Network Identity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Spacer(),
              // Online/offline indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (netInfo.isOnline ? Colors.green : Colors.red).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: netInfo.isOnline ? Colors.green : Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      netInfo.isOnline ? 'Online' : 'Offline',
                      style: TextStyle(
                        color: netInfo.isOnline ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (netInfo.isLoading)
            const Center(child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(strokeWidth: 2),
            ))
          else ...[
            _buildInfoRow(context, 'Wi-Fi', netInfo.wifiName ?? '—'),
            _buildInfoRow(context, 'Local IP', netInfo.localIp ?? '—'),
            _buildInfoRow(context, 'Public IP', netInfo.publicIp ?? '—'),
            _buildInfoRow(context, 'Gateway', netInfo.gatewayIp ?? '—'),
            _buildInfoRow(context, 'Subnet', netInfo.subnetMask ?? '—'),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => netInfo.refresh(isManual: true),
              icon: const Icon(FluentIcons.arrow_clockwise_24_regular, size: 18),
              label: const Text('Refresh', style: TextStyle(fontWeight: FontWeight.bold)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (value != '—')
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$label copied'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              child: Icon(FluentIcons.copy_24_regular, size: 18, color: Colors.grey.shade400),
            ),
        ],
      ),
    );
  }
}
