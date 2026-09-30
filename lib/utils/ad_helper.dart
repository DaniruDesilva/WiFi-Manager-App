import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import '../providers/premium_provider.dart';

class AdHelper {
  static InterstitialAd? _interstitialAd;
  static bool _isAdLoaded = false;
  
  static final String _adUnitId = Platform.isAndroid
      ? 'ca-app-pub-5105772344719492/2673277632' // Production Interstitial ID
      : 'ca-app-pub-3940256099942544/4411468910'; // Test iOS ID

  /// Pre-loads an interstitial ad so it's ready when needed
  static void loadInterstitialAd(BuildContext context) {
    final isPremium = context.read<PremiumProvider>().isPremium;
    if (isPremium) return; // Don't load if premium

    InterstitialAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isAdLoaded = true;
          
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              _isAdLoaded = false;
              loadInterstitialAd(context); // Load the next one
            },
            onAdFailedToShowFullScreenContent: (ad, err) {
              ad.dispose();
              _isAdLoaded = false;
            },
          );
        },
        onAdFailedToLoad: (err) {
          debugPrint('Failed to load interstitial ad: $err');
          _isAdLoaded = false;
        },
      ),
    );
  }

  /// Shows the pre-loaded interstitial ad.
  /// Call this at a natural transition point, e.g., after saving a PDF.
  static void showInterstitialAd(BuildContext context) {
    final isPremium = context.read<PremiumProvider>().isPremium;
    if (isPremium) return;

    if (_isAdLoaded && _interstitialAd != null) {
      _interstitialAd!.show();
      _interstitialAd = null;
      _isAdLoaded = false;
    }
  }
}
