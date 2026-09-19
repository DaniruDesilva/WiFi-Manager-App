import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/premium_provider.dart';

class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(FluentIcons.dismiss_24_regular, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0F172A), Color(0xFF001B8C)],
              ),
            ),
          ),
          
          SafeArea(
            child: Consumer<PremiumProvider>(
              builder: (context, premiumProvider, child) {
                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 24),
                    
                    // Crown Icon
                    const Icon(
                      FluentIcons.premium_24_filled,
                      color: Colors.amber,
                      size: 80,
                    ).animate().scale(duration: 500.ms, curve: Curves.easeOutBack),
                    const SizedBox(height: 24),
                    
                    // Title
                    const Text(
                      'NetVault Premium',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ).animate().fade().slideY(begin: 0.3),
                    const SizedBox(height: 8),
                    
                    // Subtitle
                    Text(
                      'Unlock the full potential of your network.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 16,
                      ),
                    ).animate().fade(delay: 100.ms).slideY(begin: 0.3),
                    const SizedBox(height: 48),
                    
                    // Features List
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32.0),
                      child: Column(
                        children: [
                          _buildFeatureItem('Ad-Free Experience', 'Remove all banners and pop-ups.'),
                          _buildFeatureItem('Premium Guest Cards', 'Unlock all premium PDF templates.'),
                          _buildFeatureItem('Advanced Analytics', 'Unlimited Wi-Fi speed and signal tests.'),
                          _buildFeatureItem('Support Development', 'Help us build more cool features!'),
                        ],
                      ),
                    ).animate().fade(delay: 200.ms),
                    
                    const Spacer(),
                    
                    // Pricing / Purchase Button
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: premiumProvider.isLoading
                          ? const Center(child: CircularProgressIndicator(color: Colors.white))
                          : premiumProvider.isPremium
                              ? _buildSuccessView(context)
                              : _buildPurchaseView(context, premiumProvider),
                    ),
                    const SizedBox(height: 16),
                    
                    // Restore Purchases
                    if (!premiumProvider.isPremium && !premiumProvider.isLoading)
                      TextButton(
                        onPressed: () async {
                          final success = await premiumProvider.restorePurchases();
                          if (success && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Purchases Restored!')));
                            Navigator.pop(context);
                          } else if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No previous purchases found.')));
                          }
                        },
                        child: const Text(
                          'Restore Purchases',
                          style: TextStyle(color: Colors.white54, decoration: TextDecoration.underline),
                        ),
                      ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(FluentIcons.checkmark_24_regular, color: Colors.greenAccent, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseView(BuildContext context, PremiumProvider premiumProvider) {
    return Column(
      children: [
        const Text(
          'One-Time Purchase',
          style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.5),
        ),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: () async {
            final success = await premiumProvider.purchasePremium();
            if (success && context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Welcome to Premium!')));
              Navigator.pop(context);
            }
          },
          style: FilledButton.styleFrom(
            backgroundColor: Colors.amber,
            foregroundColor: Colors.black,
            minimumSize: const Size(double.infinity, 60),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 8,
          ),
          child: const Text(
            'Unlock for \$2.99',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
        ).animate().shake(delay: 1.seconds),
      ],
    );
  }

  Widget _buildSuccessView(BuildContext context) {
    return Column(
      children: [
        const Icon(FluentIcons.checkmark_circle_24_filled, color: Colors.greenAccent, size: 48),
        const SizedBox(height: 16),
        const Text(
          'You are a Premium user!',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => Navigator.pop(context),
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white24,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 60),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          child: const Text('Return to App'),
        ),
      ],
    );
  }
}
