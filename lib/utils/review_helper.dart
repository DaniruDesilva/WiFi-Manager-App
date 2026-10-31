import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class ReviewHelper {
  static final InAppReview _inAppReview = InAppReview.instance;
  static const MethodChannel _securityChannel =
      MethodChannel('com.example.wifi_qr_generator/security');
  static const String _appPackage = 'com.netvault.app';
  static const String _playStoreUrl =
      'https://play.google.com/store/apps/details?id=$_appPackage';
  static const String _prefActionCountKey = 'netvault_positive_action_count';
  static const String _prefHasRequestedSmartReviewKey =
      'netvault_smart_review_requested';

  /// Called when the user taps "Rate Us" in Settings.
  /// Shows an instant, responsive in-app rating dialog.
  static Future<void> requestManualReview(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const _RatingDialog(),
    );
  }

  /// Triggers the native Google Play In-App Review prompt.
  /// If the API is unavailable on this device (e.g. Huawei device without GMS,
  /// or when quota is exceeded), smoothly falls back to Google Play Store.
  static Future<void> triggerInAppReviewOrStore({bool forceStore = false}) async {
    if (!forceStore) {
      try {
        final isAvailable = await _inAppReview.isAvailable();
        if (isAvailable) {
          await _inAppReview.requestReview();
          return;
        }
      } catch (e) {
        debugPrint('In-app review direct request failed: $e');
      }
    }

    // Fallback: Open Google Play Store directly
    await openGooglePlayStore();
  }

  /// Gently prompts for review after positive milestones (e.g. generating or sharing 2 QR codes).
  /// Uses the native Google Play In-App Review sheet in the background if eligible.
  static Future<void> checkAndTriggerSmartReview() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasRequested =
          prefs.getBool(_prefHasRequestedSmartReviewKey) ?? false;
      if (hasRequested) return;

      int count = (prefs.getInt(_prefActionCountKey) ?? 0) + 1;
      await prefs.setInt(_prefActionCountKey, count);

      if (count >= 2) {
        if (await _inAppReview.isAvailable()) {
          await prefs.setBool(_prefHasRequestedSmartReviewKey, true);
          await _inAppReview.requestReview();
        }
      }
    } catch (e) {
      debugPrint('Smart review check error: $e');
    }
  }

  /// Directly launches Google Play Store to NetVault's page.
  /// Uses a native Android intent targeted at com.android.vending to GUARANTEE
  /// it opens Google Play Store and NEVER Huawei AppGallery, Xiaomi GetApps, or Samsung Galaxy Store.
  static Future<void> openGooglePlayStore() async {
    if (Platform.isAndroid) {
      try {
        final bool? opened = await _securityChannel.invokeMethod<bool>(
          'openGooglePlayStore',
          {'packageName': _appPackage},
        );
        if (opened == true) return;
      } catch (e) {
        debugPrint('Platform channel openGooglePlayStore error: $e');
      }
    }

    // Fallback for iOS or non-standard Android:
    // Open HTTPS Play Store web URL in external browser
    try {
      final webUri = Uri.parse(_playStoreUrl);
      if (await canLaunchUrl(webUri)) {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('Fallback launchUrl failed: $e');
    }
  }

  /// Kept for backwards-compatibility
  static Future<void> openStoreReview() async {
    await openGooglePlayStore();
  }
}

class _RatingDialog extends StatefulWidget {
  const _RatingDialog();

  @override
  State<_RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<_RatingDialog> {
  int _selectedRating = 5;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPositive = _selectedRating >= 4;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Glowing star badge
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                FluentIcons.star_24_filled,
                color: Colors.amber,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),

            Text(
              isPositive ? 'Enjoying NetVault?' : 'How Can We Improve?',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            Text(
              isPositive
                  ? 'Your 5-star review helps us keep NetVault secure, fast, and 100% ad-light!'
                  : 'We value your experience! Tell us what we can improve to make NetVault better.',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // Interactive Star Row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                final starNum = index + 1;
                return GestureDetector(
                  onTap: () async {
                    setState(() {
                      _selectedRating = starNum;
                    });
                    if (starNum >= 4) {
                      // Brief delay for visual feedback of the selected star
                      await Future.delayed(const Duration(milliseconds: 220));
                      if (context.mounted) {
                        Navigator.pop(context);
                        // Trigger Google Play in-app review prompt or store
                        await ReviewHelper.triggerInAppReviewOrStore(forceStore: false);
                      }
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      starNum <= _selectedRating
                          ? FluentIcons.star_24_filled
                          : FluentIcons.star_24_regular,
                      color: Colors.amber,
                      size: 38,
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 24),

            // Action button:
            // If 4-5 stars: "Rate on Google Play"
            // If 1-3 stars: "Send Feedback" (with direct email launcher)
            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  if (isPositive) {
                    await ReviewHelper.openGooglePlayStore();
                  } else {
                    // Send Feedback via email
                    final emailUri = Uri(
                      scheme: 'mailto',
                      path: 'daniru@creatorboxstudios.com',
                      queryParameters: {
                        'subject': 'NetVault Feedback ($_selectedRating Stars)',
                        'body': 'Hi NetVault team,\n\nHere is how you can improve the app:\n',
                      },
                    );
                    try {
                      if (await canLaunchUrl(emailUri)) {
                        await launchUrl(emailUri);
                      }
                    } catch (_) {}
                  }
                },
                icon: Icon(
                  isPositive
                      ? FluentIcons.open_24_regular
                      : FluentIcons.mail_24_regular,
                  size: 18,
                ),
                label: Text(
                  isPositive ? 'Rate on Google Play' : 'Send Feedback',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Fallback store link if user rated low but still wants Google Play
            if (!isPositive)
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);
                  await ReviewHelper.openGooglePlayStore();
                },
                child: Text(
                  'Rate on Google Play anyway',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 13,
                  ),
                ),
              ),

            // Dismiss button
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Maybe Later',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
