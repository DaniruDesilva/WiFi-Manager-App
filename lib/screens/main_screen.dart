import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/theme_provider.dart';
import '../providers/security_provider.dart';
import 'dashboard_screen.dart';
import 'scan_screen.dart';
import 'history_screen.dart';
import 'generate_screen.dart';
import 'tools_dashboard_screen.dart';
import 'security_settings_screen.dart';
import '../widgets/pin_dialog.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  late PageController _pageController;
  bool _hasAttemptedAppUnlock = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryUnlockApp();
    });
  }

  Future<void> _tryUnlockApp() async {
    final security = context.read<SecurityProvider>();
    if (!security.isLoaded) return; // Wait for load
    
    if (security.appNeedsAuth && !security.isAppUnlocked && !_hasAttemptedAppUnlock) {
      _hasAttemptedAppUnlock = true;
      final result = await security.authenticateForApp();
      if (!result && mounted) {
        // App pin is set, we need to show pin dialog
        _showAppPinDialog();
      }
    }
  }

  Future<void> _showAppPinDialog() async {
    final security = context.read<SecurityProvider>();
    final pin = await PinDialog.show(context, title: 'Unlock App');
    if (pin != null) {
      final verified = security.verifyAppPin(pin);
      if (!verified && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Incorrect PIN'), backgroundColor: Colors.redAccent),
        );
      }
    } else {
      // User cancelled, reset attempt so they can click unlock again
      _hasAttemptedAppUnlock = false;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
    _pageController.jumpToPage(index);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    final List<Widget> screens = [
      DashboardScreen(onTabSelected: _onTabSelected),
      const ScanScreen(),
      const HistoryScreen(),
      const ToolsDashboardScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('NetVault', style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: const Icon(FluentIcons.shield_24_regular),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SecuritySettingsScreen()),
              );
            },
          ).animate().fade().scale(),
          IconButton(
            icon: Icon(
              themeProvider.isDarkMode ? FluentIcons.weather_sunny_24_regular : FluentIcons.weather_moon_24_regular,
            ),
            onPressed: () {
              themeProvider.toggleTheme();
            },
          ).animate().fade().scale(),
        ],
      ),
      body: Consumer<SecurityProvider>(
        builder: (context, security, child) {
          if (!security.isLoaded) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (security.appNeedsAuth && !security.isAppUnlocked) {
            // Check if we haven't attempted unlock yet, trigger it
            if (!_hasAttemptedAppUnlock) {
               WidgetsBinding.instance.addPostFrameCallback((_) {
                 if (mounted) _tryUnlockApp();
               });
            }
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(FluentIcons.lock_shield_24_filled, size: 80, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(height: 24),
                  const Text(
                    'App is locked',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Unlock to use the app.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 32),
                  FilledButton.icon(
                    onPressed: _showAppPinDialog,
                    icon: const Icon(FluentIcons.key_24_regular),
                    label: const Text('Enter PIN', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                  ),
                ],
              ).animate().fade().scale(),
            );
          }

          return PageView(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            children: screens,
          );
        },
      ),
      floatingActionButton: (_currentIndex == 2 && !isKeyboardOpen) ? FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const GenerateScreen()),
          );
        },
        icon: const Icon(FluentIcons.qr_code_24_filled),
        label: const Text('Create QR', style: TextStyle(fontWeight: FontWeight.bold)),
      ).animate().scale() : null,
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          iconTheme: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return IconThemeData(
                color: Theme.of(context).colorScheme.primary, // Always primary color when selected
              );
            }
            return IconThemeData(
              color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade400 : Colors.grey.shade500,
            );
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 12);
            }
            return TextStyle(
              color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade400 : Colors.grey.shade500,
              fontSize: 12,
            );
          }),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          elevation: 10,
          backgroundColor: Theme.of(context).cardColor,
          indicatorColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
          onDestinationSelected: _onTabSelected,
          destinations: const [
            NavigationDestination(
              icon: Icon(FluentIcons.home_24_regular),
              selectedIcon: Icon(FluentIcons.home_24_filled),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(FluentIcons.scan_24_regular),
              selectedIcon: Icon(FluentIcons.scan_24_filled),
              label: 'Scan',
            ),
            NavigationDestination(
              icon: Icon(FluentIcons.lock_closed_24_regular),
              selectedIcon: Icon(FluentIcons.lock_closed_24_filled),
              label: 'Vault',
            ),
            NavigationDestination(
              icon: Icon(FluentIcons.toolbox_24_regular),
              selectedIcon: Icon(FluentIcons.toolbox_24_filled),
              label: 'Tools',
            ),
          ],
        ),
      ).animate().slideY(begin: 1, duration: 400.ms, curve: Curves.easeOutBack),
    );
  }
}
