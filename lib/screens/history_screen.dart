import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../providers/history_provider.dart';
import '../providers/security_provider.dart';
import '../services/backup_service.dart';
import '../utils/network_detail_sheet.dart';
import '../widgets/pin_dialog.dart';
import '../widgets/native_ad_widget.dart';
import '../widgets/banner_ad_widget.dart';
import '../providers/premium_provider.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true; // Prevent widget from being disposed on tab switch

  @override
  void initState() {
    super.initState();
    // Attempt authentication after the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryAuthenticate();
    });
  }

  Future<void> _tryAuthenticate() async {
    final security = context.read<SecurityProvider>();

    if (security.isHistoryUnlocked) return;

    final result = await security.authenticateForHistory();

    switch (result) {
      case 'unlocked':
        // Auto-unlocked (no security on device and no custom PIN)
        break;
      case 'pin_required':
        if (mounted) await _showPinUnlock();
        break;
      case 'device_auth_required':
        await security.authenticateWithDeviceForHistory();
        break;
    }
  }

  Future<void> _showPinUnlock() async {
    final security = context.read<SecurityProvider>();
    final pin = await PinDialog.show(context, title: 'Unlock History');
    if (pin != null) {
      final verified = security.verifyHistoryPin(pin);
      if (!verified && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Incorrect PIN'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }


  String _searchQuery = '';
  String _selectedFilter = 'All';

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required by AutomaticKeepAliveClientMixin


    return Consumer3<SecurityProvider, HistoryProvider, PremiumProvider>(
      builder: (context, security, historyProvider, premiumProvider, child) {

    if (!security.isHistoryUnlocked) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(FluentIcons.lock_closed_24_regular, size: 80, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 24),
            const Text(
              'History is locked',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            const Text(
              'Unlock to view your saved networks.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: _tryAuthenticate,
              icon: const Icon(FluentIcons.fingerprint_24_regular),
              label: const Text('Unlock History', style: TextStyle(fontWeight: FontWeight.bold)),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            ),
          ],
        ).animate().fade().scale(),
      );
    }

    final history = historyProvider.history;


        // Apply filters
        var filteredList = history.where((network) {
          final matchesSearch = network.ssid.toLowerCase().contains(_searchQuery.toLowerCase());
          final matchesFilter = _selectedFilter == 'All' || network.category == _selectedFilter;
          return matchesSearch && matchesFilter;
        }).toList();

        return Column(
          children: [
            // Search and Filters Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          onChanged: (value) => setState(() => _searchQuery = value),
                          decoration: InputDecoration(
                            hintText: 'Search networks',
                            prefixIcon: const Icon(FluentIcons.search_24_regular),
                            filled: true,
                            fillColor: Theme.of(context).cardColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                            ),
                            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      PopupMenuButton<String>(
                        icon: const Icon(FluentIcons.more_vertical_24_regular),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        onSelected: (value) {
                          if (value == 'backup') {
                            _showBackupDialog(context, historyProvider);
                          } else if (value == 'restore') {
                            _showRestoreDialog(context, historyProvider);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'backup',
                            child: Row(
                              children: [
                                Icon(FluentIcons.arrow_upload_24_regular),
                                SizedBox(width: 8),
                                Text('Backup Networks'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'restore',
                            child: Row(
                              children: [
                                Icon(FluentIcons.arrow_download_24_regular),
                                SizedBox(width: 8),
                                Text('Restore Networks'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ).animate().fade().slideY(begin: -0.2),
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ['All', 'Home', 'Office', 'Guest'].map((filter) {
                        final isSelected = _selectedFilter == filter;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(filter, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) setState(() => _selectedFilter = filter);
                            },
                            backgroundColor: Theme.of(context).cardColor,
                            selectedColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                            labelStyle: TextStyle(
                              color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.shade700,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey.withValues(alpha: 0.2)),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ).animate().fade(delay: 100.ms),
                ],
              ),
            ),
            
            // List View
            Expanded(
              child: filteredList.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(FluentIcons.history_24_regular, size: 100, color: Colors.grey.withValues(alpha: 0.5)),
                          const SizedBox(height: 24),
                          Text(
                            history.isEmpty ? 'No Saved Networks' : 'No matches found',
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            history.isEmpty ? 'Networks you generate or scan will appear here.' : 'Try a different search term or filter.',
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
                      ).animate().fade(duration: 600.ms).slideY(begin: 0.2),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: premiumProvider.isPremium 
                          ? filteredList.length 
                          : filteredList.length + (filteredList.length ~/ 4),
                      itemBuilder: (context, index) {
                        if (!premiumProvider.isPremium && index > 0 && (index + 1) % 5 == 0) {
                          return const Padding(
                            padding: EdgeInsets.only(bottom: 12.0),
                            child: Center(child: NativeAdWidget()),
                          );
                        }
                        
                        final networkIndex = premiumProvider.isPremium ? index : index - (index ~/ 5);
                        final network = filteredList[networkIndex];
                        
                        IconData getCategoryIcon() {
                          switch (network.category) {
                            case 'Home': return FluentIcons.home_24_regular;
                            case 'Work':
                            case 'Office': return FluentIcons.building_24_regular;
                            case 'Guest': return FluentIcons.people_24_regular;
                            default: return FluentIcons.wifi_1_24_regular;
                          }
                        }

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Dismissible(
                            key: Key('${network.ssid}_${network.timestamp}'),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              decoration: BoxDecoration(
                                color: Colors.redAccent,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 24),
                              child: const Icon(FluentIcons.delete_24_regular, color: Colors.white, size: 28),
                            ),
                            onDismissed: (direction) {
                              historyProvider.removeNetwork(network);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Network removed'),
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              );
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.2 : 0.04),
                                    blurRadius: 16,
                                    spreadRadius: 0,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(20),
                                onTap: () => showNetworkDetailsSheet(context, network),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Icon(getCategoryIcon(), color: Theme.of(context).colorScheme.primary),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              network.ssid,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              '${network.securityType} ${network.category != null ? "• ${network.category}" : ""}',
                                              style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(FluentIcons.qr_code_24_regular, color: Colors.grey.shade400),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        ).animate().fade(delay: (index * 50).ms).slideX(begin: 0.1);
                      },
                    ),
            ),
            const BannerAdWidget(),
          ],
        );
      },
    );
  }

  void _showBackupDialog(BuildContext context, HistoryProvider historyProvider) {
    if (historyProvider.history.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No networks to backup')));
      return;
    }
    
    final passwordController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Backup Networks'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter a strong password to encrypt your backup. You will need this password to restore.'),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Encryption Password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (passwordController.text.length < 4) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password must be at least 4 characters')));
                return;
              }
              Navigator.pop(context);
              try {
                final path = await BackupService.createBackupFile(historyProvider.history, passwordController.text);
                // ignore: deprecated_member_use
                await Share.shareXFiles([XFile(path)], text: 'NetVault Backup');
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Backup failed: $e')));
              }
            },
            child: const Text('Create Backup'),
          ),
        ],
      ),
    );
  }

  void _showRestoreDialog(BuildContext context, HistoryProvider historyProvider) {
    final passwordController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore Networks'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Pick a backup file and enter the decryption password.'),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Decryption Password',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              if (passwordController.text.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter password')));
                return;
              }
              Navigator.pop(context);
              try {
                PlatformFile? result = await FilePicker.pickFile(
                  type: FileType.any,
                );
                if (result != null && result.path != null) {
                  final file = File(result.path!);
                  final payload = await file.readAsString();
                  final networks = BackupService.decryptBackup(payload, passwordController.text);
                  
                  int added = 0;
                  for (var net in networks) {
                    if (!historyProvider.history.any((e) => e.ssid == net.ssid && e.password == net.password)) {
                      historyProvider.addNetwork(net);
                      added++;
                    }
                  }
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Restored $added new networks')));
                }
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Restore failed: Invalid password or file')));
              }
            },
            child: const Text('Pick File & Restore'),
          ),
        ],
      ),
    );
  }
}
