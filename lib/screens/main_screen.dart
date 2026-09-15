import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/theme_provider.dart';
import 'dashboard_screen.dart';
import 'scan_screen.dart';
import 'history_screen.dart';
import 'speed_test_screen.dart';
import 'generate_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
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
      const SpeedTestScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wi-Fi QR Generator', style: TextStyle(fontWeight: FontWeight.w600)),
        actions: [
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
      body: PageView(
        controller: _pageController,
        physics: const NeverScrollableScrollPhysics(),
        children: screens,
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
              return IconThemeData(color: Theme.of(context).colorScheme.onSurface);
            }
            return IconThemeData(
              color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade400 : Colors.grey.shade600,
            );
          }),
          labelTextStyle: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold, fontSize: 12);
            }
            return TextStyle(
              color: Theme.of(context).brightness == Brightness.dark ? Colors.grey.shade400 : Colors.grey.shade600,
              fontSize: 12,
            );
          }),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          elevation: 10,
          backgroundColor: Theme.of(context).cardColor,
          indicatorColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
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
              icon: Icon(FluentIcons.bookmark_24_regular),
              selectedIcon: Icon(FluentIcons.bookmark_24_filled),
              label: 'Saved',
            ),
            NavigationDestination(
              icon: Icon(FluentIcons.top_speed_24_regular),
              selectedIcon: Icon(FluentIcons.top_speed_24_filled),
              label: 'Speed',
            ),
          ],
        ),
      ).animate().slideY(begin: 1, duration: 400.ms, curve: Curves.easeOutBack),
    );
  }
}

