import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/user_guide_screen.dart';

class OnboardingSheet extends StatefulWidget {
  final Function(int)? onTabSelected;

  const OnboardingSheet({super.key, this.onTabSelected});

  static const String _prefKey = 'netvault_has_seen_onboarding';

  /// Automatically checks if the user is launching NetVault for the first time
  /// and shows the interactive welcome walkthrough.
  static Future<void> checkAndShow(BuildContext context, {Function(int)? onTabSelected}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasSeen = prefs.getBool(_prefKey) ?? false;
      if (!hasSeen && context.mounted) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (ctx) => OnboardingSheet(onTabSelected: onTabSelected),
        );
      }
    } catch (e) {
      debugPrint('Onboarding check error: $e');
    }
  }

  /// Manually shows the welcome tour (e.g. from Help or Settings).
  static void showTour(BuildContext context, {Function(int)? onTabSelected}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => OnboardingSheet(onTabSelected: onTabSelected),
    );
  }

  @override
  State<OnboardingSheet> createState() => _OnboardingSheetState();
}

class _OnboardingSheetState extends State<OnboardingSheet> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingItem> _pages = const [
    _OnboardingItem(
      title: 'Instant Wi-Fi Sharing',
      subtitle: 'Create Wi-Fi QR Codes & Cards',
      description:
          'Generate instant QR codes and printable guest cards for home, cafes, or Airbnbs. Guests scan with their phone camera to connect in seconds—no typing passwords!',
      icon: FluentIcons.qr_code_24_filled,
      gradient: [Color(0xFF007AFF), Color(0xFF0EA5E9)],
    ),
    _OnboardingItem(
      title: 'Smart Scanner & Vault',
      subtitle: 'Scan & Encrypt Safely',
      description:
          'Scan Wi-Fi QR codes with your camera or photos to connect instantly. All your passwords are stored 100% offline, protected by biometric fingerprint and PIN.',
      icon: FluentIcons.lock_shield_24_filled,
      gradient: [Color(0xFF10B981), Color(0xFF059669)],
    ),
    _OnboardingItem(
      title: 'Network Toolkit & Widget',
      subtitle: 'Diagnostics & 1-Tap Widget',
      description:
          'Analyze signal strength (dBm), test real internet speeds, scan connected devices, and pin your Wi-Fi QR code directly to your Android Home Screen widget!',
      icon: FluentIcons.toolbox_24_filled,
      gradient: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
    ),
  ];

  Future<void> _markAsSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(OnboardingSheet._prefKey, true);
    } catch (_) {}
  }

  void _onComplete() async {
    await _markAsSeen();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _openFullGuide() async {
    await _markAsSeen();
    if (mounted) {
      Navigator.pop(context);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => UserGuideScreen(onTabSelected: widget.onTabSelected),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = Theme.of(context).cardColor;

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 25, offset: Offset(0, -5))
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Drag handle
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            // Top action row (Skip & Guide)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: _openFullGuide,
                    icon: const Icon(FluentIcons.book_question_mark_24_regular, size: 18),
                    label: const Text('Detailed Guide', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.primary),
                  ),
                  TextButton(
                    onPressed: _onComplete,
                    child: Text('Skip', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                  ),
                ],
              ),
            ),

            // PageView content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (idx) {
                  setState(() {
                    _currentPage = idx;
                  });
                },
                itemBuilder: (ctx, idx) {
                  final page = _pages[idx];
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Animated Hero Graphic
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: page.gradient,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [
                              BoxShadow(
                                color: page.gradient.first.withValues(alpha: 0.35),
                                blurRadius: 22,
                                offset: const Offset(0, 10),
                              )
                            ],
                          ),
                          child: Icon(page.icon, color: Colors.white, size: 54),
                        ).animate(key: ValueKey(idx)).scale(duration: 350.ms, curve: Curves.easeOutBack),

                        const SizedBox(height: 28),

                        Text(
                          page.title,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                          textAlign: TextAlign.center,
                        ).animate(key: ValueKey('title_$idx')).fade().slideY(begin: 0.2),

                        const SizedBox(height: 6),

                        Text(
                          page.subtitle,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: page.gradient.first,
                          ),
                          textAlign: TextAlign.center,
                        ),

                        const SizedBox(height: 14),

                        Text(
                          page.description,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                            height: 1.45,
                          ),
                          textAlign: TextAlign.center,
                        ).animate(key: ValueKey('desc_$idx')).fade(delay: 100.ms),
                      ],
                    ),
                  );
                },
              ),
            ),

            // Dot indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (idx) {
                final isSelected = idx == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: isSelected ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                );
              }),
            ),

            const SizedBox(height: 20),

            // Bottom action button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: () {
                    if (_currentPage < _pages.length - 1) {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    } else {
                      _onComplete();
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  child: Text(
                    _currentPage < _pages.length - 1 ? 'Next' : 'Get Started with NetVault',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _OnboardingItem {
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final List<Color> gradient;

  const _OnboardingItem({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.gradient,
  });
}
