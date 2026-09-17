import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/security_provider.dart';
import '../widgets/pin_dialog.dart';

class SecuritySettingsScreen extends StatelessWidget {
  const SecuritySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Security Settings', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: Consumer<SecurityProvider>(
        builder: (context, security, _) {
          if (!security.isLoaded) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Text(
                  'App Security',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ).animate().fade().slideY(begin: 0.2),
                const SizedBox(height: 8),
                Text(
                  'Protect your saved networks and app access with a custom PIN or device biometrics.',
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.light
                        ? Colors.grey.shade700
                        : Colors.grey.shade400,
                    fontSize: 15,
                  ),
                ).animate().fade(delay: 100.ms),
                const SizedBox(height: 32),

                // ─── History Lock Section ───
                _buildSectionHeader(context, 'History / Vault Lock', FluentIcons.lock_closed_24_filled),
                const SizedBox(height: 12),

                // Device biometrics info
                _buildInfoCard(
                  context,
                  icon: FluentIcons.fingerprint_24_regular,
                  title: 'Device Security',
                  subtitle: security.deviceHasSecurity
                      ? 'Your device has a screen lock. History is automatically protected.'
                      : 'Your device has no screen lock set. Please set a custom PIN.',
                  color: security.deviceHasSecurity ? Colors.green : Colors.orange,
                ),
                const SizedBox(height: 12),

                // Custom History PIN
                _buildToggleCard(
                  context,
                  icon: FluentIcons.number_symbol_24_regular,
                  title: 'Custom History PIN',
                  subtitle: security.historyPinEnabled
                      ? 'A 4-digit PIN is required to view History'
                      : 'Set a custom PIN to protect History',
                  isEnabled: security.historyPinEnabled,
                  onToggle: (enabled) async {
                    if (enabled) {
                      final pin = await PinDialog.show(context, isSetMode: true, title: 'Set History PIN');
                      if (pin != null) {
                        await security.setHistoryPin(pin);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('History PIN set successfully'), backgroundColor: Colors.green),
                          );
                        }
                      }
                    } else {
                      // Verify current PIN before removing
                      final pin = await PinDialog.show(context, title: 'Enter Current PIN');
                      if (pin != null && security.verifyHistoryPin(pin)) {
                        await security.removeHistoryPin();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('History PIN removed'), backgroundColor: Colors.orange),
                          );
                        }
                      } else if (pin != null && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Incorrect PIN'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                ),
                if (security.historyPinEnabled) ...[
                  const SizedBox(height: 8),
                  _buildActionButton(
                    context,
                    icon: FluentIcons.key_24_regular,
                    label: 'Change History PIN',
                    onTap: () => _changePin(context, security, isApp: false),
                  ),
                ],

                const SizedBox(height: 32),

                // ─── App Lock Section ───
                _buildSectionHeader(context, 'Entire App Lock', FluentIcons.shield_24_filled),
                const SizedBox(height: 12),

                _buildToggleCard(
                  context,
                  icon: FluentIcons.lock_shield_24_regular,
                  title: 'App Lock PIN',
                  subtitle: security.appPinEnabled
                      ? 'A 4-digit PIN is required to open the app'
                      : 'Set a PIN to lock the entire app on launch',
                  isEnabled: security.appPinEnabled,
                  onToggle: (enabled) async {
                    if (enabled) {
                      final pin = await PinDialog.show(context, isSetMode: true, title: 'Set App PIN');
                      if (pin != null) {
                        await security.setAppPin(pin);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('App Lock PIN set successfully'), backgroundColor: Colors.green),
                          );
                        }
                      }
                    } else {
                      // Verify current PIN before removing
                      final pin = await PinDialog.show(context, title: 'Enter Current App PIN');
                      if (pin != null && security.verifyAppPin(pin)) {
                        await security.removeAppPin();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('App Lock PIN removed'), backgroundColor: Colors.orange),
                          );
                        }
                      } else if (pin != null && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Incorrect PIN'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                ),
                if (security.appPinEnabled) ...[
                  const SizedBox(height: 8),
                  _buildActionButton(
                    context,
                    icon: FluentIcons.key_24_regular,
                    label: 'Change App PIN',
                    onTap: () => _changePin(context, security, isApp: true),
                  ),
                ],
                const SizedBox(height: 48),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _changePin(BuildContext context, SecurityProvider security, {required bool isApp}) async {
    // Verify old PIN first
    final oldPin = await PinDialog.show(context, title: 'Enter Current PIN');
    if (oldPin == null) return;

    final isValid = isApp ? security.verifyAppPin(oldPin) : security.verifyHistoryPin(oldPin);
    if (!isValid) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Incorrect PIN'), backgroundColor: Colors.red),
        );
      }
      return;
    }

    if (!context.mounted) return;
    
    // Set new PIN
    final newPin = await PinDialog.show(context, isSetMode: true, title: 'Set New PIN');
    if (newPin != null) {
      if (isApp) {
        await security.setAppPin(newPin);
      } else {
        await security.setHistoryPin(newPin);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PIN changed successfully'), backgroundColor: Colors.green),
        );
      }
    }
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ],
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isEnabled,
    required Future<void> Function(bool) onToggle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              ],
            ),
          ),
          Switch(
            value: isEnabled,
            onChanged: onToggle,
            activeColor: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}
