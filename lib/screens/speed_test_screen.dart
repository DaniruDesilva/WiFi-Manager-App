import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

class SpeedTestScreen extends StatefulWidget {
  const SpeedTestScreen({super.key});

  @override
  State<SpeedTestScreen> createState() => _SpeedTestScreenState();
}

class _SpeedTestScreenState extends State<SpeedTestScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  double downloadRate = 0;
  double uploadRate = 0;
  bool isTesting = false;
  String currentStatus = 'Ready to test';

  Future<void> _runSpeedTest() async {
    setState(() {
      isTesting = true;
      downloadRate = 0;
      uploadRate = 0;
      currentStatus = 'Testing download...';
    });

    try {
      final client = http.Client();
      
      final request = http.Request('GET', Uri.parse('https://speed.cloudflare.com/__down?bytes=10000000'));
      
      final stopwatch = Stopwatch()..start();
      final response = await client.send(request);
      
      int downloadedBytes = 0;
      await for (final chunk in response.stream) {
        downloadedBytes += chunk.length;
        final elapsedSeconds = stopwatch.elapsedMilliseconds / 1000.0;
        if (elapsedSeconds > 0) {
          final mbps = (downloadedBytes * 8 / 1000000.0) / elapsedSeconds;
          setState(() {
            downloadRate = mbps;
            currentStatus = 'Testing download... (${(downloadedBytes / 100000).toStringAsFixed(0)}%)';
          });
        }
      }
      stopwatch.stop();

      setState(() {
        currentStatus = 'Testing upload...';
      });

      final uploadBytes = Uint8List(5000000); 
      final uploadStopwatch = Stopwatch()..start();
      
      await client.post(Uri.parse('https://speed.cloudflare.com/__up'), body: uploadBytes);
      uploadStopwatch.stop();
      
      final uploadSeconds = uploadStopwatch.elapsedMilliseconds / 1000.0;
      final uploadMbps = (uploadBytes.length * 8 / 1000000.0) / uploadSeconds;
      
      setState(() {
        uploadRate = uploadMbps;
        currentStatus = 'Test completed';
        isTesting = false;
      });

      client.close();
    } catch (e) {
      setState(() {
        currentStatus = 'Error: Check internet connection';
        isTesting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated Radar/Pulse Icon
            Stack(
              alignment: Alignment.center,
              children: [
                if (isTesting)
                  Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                    ),
                  ).animate(onPlay: (controller) => controller.repeat())
                   .scale(begin: const Offset(0.5, 0.5), end: const Offset(1.5, 1.5), duration: 1500.ms)
                   .fadeOut(duration: 1500.ms),
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3), blurRadius: 30, spreadRadius: 5),
                    ],
                  ),
                  child: Icon(FluentIcons.top_speed_24_filled, size: 50, color: Theme.of(context).colorScheme.primary),
                ),
              ],
            ).animate().scale(curve: Curves.easeOutBack, duration: 500.ms),
            
            const SizedBox(height: 32),
            
            Text(
              'Wi-Fi Speed Test',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
            ).animate().fade().slideY(begin: 0.5),
            
            const SizedBox(height: 8),
            Text(currentStatus, style: const TextStyle(color: Colors.grey, fontSize: 16, fontWeight: FontWeight.w500))
                .animate(target: isTesting ? 1 : 0).shimmer(duration: 1.seconds, color: Theme.of(context).colorScheme.primary),
            
            const SizedBox(height: 48),
            
            // Speed Metrics
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildSpeedIndicator('Download', downloadRate, FluentIcons.arrow_download_24_filled, isTesting ? null : Colors.green),
                _buildSpeedIndicator('Upload', uploadRate, FluentIcons.arrow_upload_24_filled, isTesting ? null : Colors.blue),
              ],
            ).animate().fade(delay: 200.ms).slideY(begin: 0.2),
            
            const SizedBox(height: 32),
            
            if (downloadRate > 0 && !isTesting)
              _buildBandwidthRecommendation().animate().fade(delay: 300.ms).slideY(begin: 0.2),

            const SizedBox(height: 32),
            
            // Start Button
            FilledButton.icon(
              onPressed: isTesting ? null : _runSpeedTest,
              icon: isTesting 
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                  : const Icon(FluentIcons.play_24_filled),
              label: Text(
                isTesting ? 'Testing...' : 'Start Speed Test',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size(250, 64),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                elevation: 8,
                shadowColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
              ),
            ).animate().fade(delay: 400.ms).scale(),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeedIndicator(String label, double rate, IconData icon, Color? finalColor) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
          ),
          child: Icon(icon, size: 28, color: rate > 0 ? (finalColor ?? Theme.of(context).colorScheme.primary) : Colors.grey.shade400),
        ),
        const SizedBox(height: 16),
        Text(
          rate.toStringAsFixed(1),
          style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, height: 1.0),
        ),
        const Text(
          'Mbps',
          style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }

  Widget _buildBandwidthRecommendation() {
    String message = '';
    IconData icon = FluentIcons.info_24_regular;
    Color color = Colors.grey;

    if (downloadRate >= 100) {
      message = 'Excellent for 4K streaming & heavy gaming';
      icon = FluentIcons.rocket_24_regular;
      color = Colors.green;
    } else if (downloadRate >= 25) {
      message = 'Good for HD streaming & working from home';
      icon = FluentIcons.checkmark_24_regular;
      color = Colors.blue;
    } else if (downloadRate >= 10) {
      message = 'Okay for basic web browsing & emails';
      icon = FluentIcons.warning_24_regular;
      color = Colors.orange;
    } else {
      message = 'Slow connection. Text and basic browsing only';
      icon = FluentIcons.error_circle_24_regular;
      color = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              message,
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}


