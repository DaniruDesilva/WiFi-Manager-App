import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import '../providers/premium_provider.dart';

class NativeAdWidget extends StatefulWidget {
  const NativeAdWidget({super.key});

  @override
  State<NativeAdWidget> createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends State<NativeAdWidget> {
  NativeAd? _nativeAd;
  bool _nativeAdIsLoaded = false;

  final String _adUnitId = Platform.isAndroid
      ? 'ca-app-pub-5105772344719492/3785022635' // Production Native ID
      : 'ca-app-pub-3940256099942544/3986624511'; // Test iOS Native ID

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    final isPremium = context.read<PremiumProvider>().isPremium;
    if (isPremium) return;

    _nativeAd = NativeAd(
      adUnitId: _adUnitId,
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          debugPrint('$NativeAd loaded.');
          setState(() {
            _nativeAdIsLoaded = true;
          });
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('$NativeAd failed to load: $error');
          ad.dispose();
        },
      ),
      request: const AdRequest(),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
        mainBackgroundColor: Colors.transparent,
        cornerRadius: 12.0,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          backgroundColor: const Color(0xFF0EA5E9),
          style: NativeTemplateFontStyle.bold,
          size: 16.0,
        ),
      ),
    )..load();
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<PremiumProvider>(
      builder: (context, premiumProvider, child) {
        if (premiumProvider.isPremium) {
          return const SizedBox.shrink();
        }
        
        if (_nativeAdIsLoaded && _nativeAd != null) {
          return ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: 320,
              minHeight: 320,
              maxWidth: 400,
              maxHeight: 400,
            ),
            child: AdWidget(ad: _nativeAd!),
          );
        }
        
        // Show a small placeholder or nothing while loading to prevent UI jumps
        return const SizedBox(height: 10);
      },
    );
  }
}
