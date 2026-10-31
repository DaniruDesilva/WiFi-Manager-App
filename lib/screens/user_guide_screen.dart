import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'generate_screen.dart';
import 'guest_card_screen.dart';
import 'security_settings_screen.dart';

class UserGuideScreen extends StatelessWidget {
  final Function(int)? onTabSelected;

  const UserGuideScreen({super.key, this.onTabSelected});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Guide & Help', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Header Banner
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF0F2B66), const Color(0xFF001B8C)]
                    : [const Color(0xFF007AFF), const Color(0xFF0EA5E9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: primary.withValues(alpha: 0.3),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(FluentIcons.book_question_mark_24_filled, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text(
                        'Welcome to NetVault',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Your all-in-one secure Wi-Fi toolkit. Follow this quick guide to get the most out of NetVault.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ).animate().fade().slideY(begin: 0.1),

          const SizedBox(height: 24),

          // ── Guide Items ──
          _buildGuideCard(
            context,
            icon: FluentIcons.qr_code_24_filled,
            color: const Color(0xFF007AFF),
            title: '1. Share Wi-Fi with QR Code',
            description:
                'Never read or spell complex Wi-Fi passwords to guests again! Generate a fast, clean QR code.',
            steps: [
              'Tap the "+ Create QR" button on the Home or Vault screen.',
              'Type your Wi-Fi SSID (network name) and password.',
              'Tap "Generate QR Code" to show the code or save it as an image.',
              'Guests simply scan the code with their camera to connect instantly without typing anything.',
            ],
            actionLabel: 'Create a Wi-Fi QR Code',
            onAction: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const GenerateScreen()),
              );
            },
          ).animate().fade(delay: 50.ms).slideY(begin: 0.1),

          const SizedBox(height: 18),

          _buildGuideCard(
            context,
            icon: FluentIcons.card_ui_24_filled,
            color: const Color(0xFF8B5CF6),
            title: '2. Design Printable Guest Cards',
            description:
                'Perfect for home living rooms, Airbnb rentals, offices, and cafes.',
            steps: [
              'Tap "Make Guest Card" on the Home screen or inside any saved network.',
              'Choose from stylish templates: Glassmorphic, Minimal, Neon, or Wooden Cafe.',
              'Customize guest instructions, welcome message, and styling.',
              'Export directly as high-resolution Image or printable PDF to frame on your desk.',
            ],
            actionLabel: 'Design a Guest Card',
            onAction: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const GuestCardScreen()),
              );
            },
          ).animate().fade(delay: 100.ms).slideY(begin: 0.1),

          const SizedBox(height: 18),

          _buildGuideCard(
            context,
            icon: FluentIcons.scan_24_filled,
            color: const Color(0xFF10B981),
            title: '3. Scan to Connect Instantly',
            description:
                'Connect to any Wi-Fi network instantly using your camera or gallery screenshots.',
            steps: [
              'Switch to the "Scan" tab at the bottom.',
              'Aim your phone at any Wi-Fi QR code (on routers, cafe menus, or cards).',
              'You can also tap the Gallery icon to scan a saved screenshot from your photos.',
              'NetVault parses the security type and lets you view the password or connect directly.',
            ],
            actionLabel: 'Open Camera Scanner',
            onAction: () {
              if (onTabSelected != null) {
                onTabSelected!(1);
                Navigator.pop(context);
              }
            },
          ).animate().fade(delay: 150.ms).slideY(begin: 0.1),

          const SizedBox(height: 18),

          _buildGuideCard(
            context,
            icon: FluentIcons.lock_shield_24_filled,
            color: const Color(0xFFF59E0B),
            title: '4. Encrypted Biometric Vault & PIN',
            description:
                'All your passwords are stored 100% offline on your device, protected by military-grade AES encryption.',
            steps: [
              'Open Security Settings by tapping the Shield icon on the top right.',
              'Enable "Custom History PIN" to require a 4-digit code before viewing passwords.',
              'Enable "App Lock PIN" to lock the entire app whenever it opens.',
              'Supports biometric fingerprint and Face Unlock on supported devices.',
            ],
            actionLabel: 'Configure App Security',
            onAction: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SecuritySettingsScreen()),
              );
            },
          ).animate().fade(delay: 200.ms).slideY(begin: 0.1),

          const SizedBox(height: 18),

          _buildGuideCard(
            context,
            icon: FluentIcons.toolbox_24_filled,
            color: const Color(0xFF06B6D4),
            title: '5. Network Tools & Diagnostics',
            description:
                'Professional diagnostic tools to optimize and secure your internet connection.',
            steps: [
              'WiFi Analyzer: View real-time signal strength (dBm) and find the least crowded channel.',
              'Speed Test: Measure download, upload, and latency ping accurately.',
              'Device Scanner: Scan your local subnet to detect intruders or smart devices connected to your Wi-Fi.',
              'Router Setup: Access router admin settings and default password lookups easily.',
            ],
            actionLabel: 'Open Network Tools',
            onAction: () {
              if (onTabSelected != null) {
                onTabSelected!(3);
                Navigator.pop(context);
              }
            },
          ).animate().fade(delay: 250.ms).slideY(begin: 0.1),

          const SizedBox(height: 18),

          _buildGuideCard(
            context,
            icon: FluentIcons.apps_24_filled,
            color: const Color(0xFFEC4899),
            title: '6. Home Screen Widget (Quick Sharing)',
            description:
                'Display your guest Wi-Fi QR code right on your Android home screen without even launching the app.',
            steps: [
              'Long-press on any empty space on your phone\'s Home Screen.',
              'Select "Widgets" and find "NetVault".',
              'Drag the "Wi-Fi QR Code" widget onto your home screen.',
              'In NetVault, tap the "Pin" icon on any network in your Vault to display it on the widget!',
            ],
          ).animate().fade(delay: 300.ms).slideY(begin: 0.1),

          const SizedBox(height: 36),
        ],
      ),
    );
  }

  Widget _buildGuideCard(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String description,
    required List<String> steps,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.04),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          ...steps.asMap().entries.map((entry) {
            final idx = entry.key + 1;
            final stepText = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    margin: const EdgeInsets.only(top: 2, right: 10),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '$idx',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      stepText,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onAction,
                icon: Text(actionLabel, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                label: Icon(FluentIcons.arrow_right_24_regular, size: 16, color: color),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
