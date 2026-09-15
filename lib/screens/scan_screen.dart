import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import '../providers/history_provider.dart';
import '../models/wifi_network.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> with AutomaticKeepAliveClientMixin {
  MobileScannerController? _scannerController;
  bool _isScanning = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  void _initCamera() {
    _scannerController = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      autoStart: true,
    );
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (!_isScanning) return;
    
    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue != null && rawValue.startsWith('WIFI:')) {
        setState(() {
          _isScanning = false;
        });
        _processWifiQr(rawValue);
        break;
      }
    }
  }

  void _processWifiQr(String rawData) {
    String ssid = '';
    String password = '';
    String securityType = 'nopass';
    bool isHidden = false;

    String data = rawData.substring(5);
    if (data.endsWith(';;')) {
      data = data.substring(0, data.length - 2);
    } else if (data.endsWith(';')) {
      data = data.substring(0, data.length - 1);
    }

    final parts = data.split(';');
    for (final part in parts) {
      if (part.startsWith('S:')) {
        ssid = part.substring(2);
      } else if (part.startsWith('P:')) {
        password = part.substring(2);
      } else if (part.startsWith('T:')) {
        securityType = part.substring(2);
      } else if (part.startsWith('H:')) {
        isHidden = part.substring(2).toLowerCase() == 'true';
      }
    }

    if (ssid.isNotEmpty) {
      final network = WifiNetwork(
        ssid: ssid,
        password: password,
        securityType: securityType,
        isHidden: isHidden,
      );

      _showScannedNetworkDialog(network);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid Wi-Fi QR Code')),
      );
      setState(() {
        _isScanning = true;
      });
    }
  }

  void _showScannedNetworkDialog(WifiNetwork network) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(FluentIcons.wifi_1_24_filled, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            const Text('Network Found', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SSID: ${network.ssid}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text('Security: ${network.securityType}'),
                  if (network.password.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('Password: ${network.password}'),
                  ],
                  if (network.isHidden) ...[
                    const SizedBox(height: 4),
                    const Text('Hidden Network', style: TextStyle(fontStyle: FontStyle.italic)),
                  ],
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _isScanning = true;
              });
            },
            child: const Text('Discard'),
          ),
          FilledButton(
            onPressed: () {
              Provider.of<HistoryProvider>(context, listen: false).addNetwork(network);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Saved to History')),
              );
              setState(() {
                _isScanning = true;
              });
            },
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Save to History'),
          ),
        ],
      ).animate().fade().scale(),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final scanWindowSize = MediaQuery.of(context).size.width * 0.7;

    return Stack(
      children: [
        // Camera view
        if (_scannerController != null)
          MobileScanner(
            controller: _scannerController!,
            onDetect: _onDetect,
            errorBuilder: (context, error) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(FluentIcons.camera_off_24_regular, size: 64, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'Camera unavailable',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please check camera permissions',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _initCamera,
                      icon: const Icon(FluentIcons.arrow_clockwise_24_regular),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              );
            },
          ),

        // Dark Overlay with Cutout
        ColorFiltered(
          colorFilter: ColorFilter.mode(Colors.black.withValues(alpha: 0.7), BlendMode.srcOut),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: const BoxDecoration(
                  color: Colors.black,
                  backgroundBlendMode: BlendMode.dstOut,
                ),
              ),
              Center(
                child: Container(
                  width: scanWindowSize,
                  height: scanWindowSize,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Animated Corners and Scanner Line
        Center(
          child: SizedBox(
            width: scanWindowSize,
            height: scanWindowSize,
            child: Stack(
              children: [
                _buildCorner(Alignment.topLeft),
                _buildCorner(Alignment.topRight),
                _buildCorner(Alignment.bottomLeft),
                _buildCorner(Alignment.bottomRight),
                
                // Animated Scan Line
                if (_isScanning)
                  Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      width: scanWindowSize * 0.9,
                      height: 3,
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.6),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ).animate(onPlay: (controller) => controller.repeat(reverse: true))
                     .slideY(begin: 0, end: scanWindowSize / 3 - 1, duration: 1500.ms, curve: Curves.easeInOut),
                  ),
              ],
            ),
          ),
        ),
        // Bottom instruction panel
        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            margin: const EdgeInsets.only(bottom: 40),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(FluentIcons.scan_object_24_regular, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  _isScanning ? 'Point at a Wi-Fi QR Code' : 'Processing...',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ).animate(onPlay: (controller) => controller.repeat(reverse: true)).shimmer(duration: 2000.ms, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)),
        ),
        if (!_isScanning)
          Container(
            color: Colors.black54,
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }

  Widget _buildCorner(Alignment alignment) {
    const double length = 40;
    const double strokeWidth = 4;
    final color = Theme.of(context).colorScheme.primary;

    return Align(
      alignment: alignment,
      child: Container(
        width: length,
        height: length,
        decoration: BoxDecoration(
          border: Border(
            top: (alignment == Alignment.topLeft || alignment == Alignment.topRight)
                ? BorderSide(color: color, width: strokeWidth)
                : BorderSide.none,
            bottom: (alignment == Alignment.bottomLeft || alignment == Alignment.bottomRight)
                ? BorderSide(color: color, width: strokeWidth)
                : BorderSide.none,
            left: (alignment == Alignment.topLeft || alignment == Alignment.bottomLeft)
                ? BorderSide(color: color, width: strokeWidth)
                : BorderSide.none,
            right: (alignment == Alignment.topRight || alignment == Alignment.bottomRight)
                ? BorderSide(color: color, width: strokeWidth)
                : BorderSide.none,
          ),
        ),
      ),
    );
  }
}
