import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../models/wifi_network.dart';
import '../utils/constants.dart';
import '../utils/pdf_generator.dart';

class GuestCardScreen extends StatefulWidget {
  final WifiNetwork? network;

  const GuestCardScreen({super.key, this.network});

  @override
  State<GuestCardScreen> createState() => _GuestCardScreenState();
}

class _GuestCardScreenState extends State<GuestCardScreen> {
  final ScreenshotController _screenshotController = ScreenshotController();
  String _title = 'Welcome Guest';
  int _selectedTemplateIndex = 0;
  bool _isExporting = false;

  final TextEditingController _titleController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _titleController.text = _title;
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _shareGuestCard() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 6, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(3))),
            const SizedBox(height: 24),
            const Text('Export Options', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(FluentIcons.image_24_regular),
              title: const Text('Share Image'),
              subtitle: const Text('Share as a PNG image for messaging'),
              onTap: () {
                Navigator.pop(context);
                _executeShareImage();
              },
            ),
            ListTile(
              leading: const Icon(FluentIcons.document_pdf_24_regular),
              title: const Text('Print Poster (A4)'),
              subtitle: const Text('Print a full-page Wi-Fi poster'),
              onTap: () {
                Navigator.pop(context);
                PdfGenerator.printWifiPoster(widget.network!);
              },
            ),
            ListTile(
              leading: const Icon(FluentIcons.table_24_regular),
              title: const Text('Print Table Tent (Foldable)'),
              subtitle: const Text('Print a 2-sided foldable card for tables'),
              onTap: () {
                Navigator.pop(context);
                PdfGenerator.printTableTent(widget.network!);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _executeShareImage() async {
    setState(() => _isExporting = true);
    
    await Future.delayed(const Duration(milliseconds: 100));
    
    try {
      final Uint8List? image = await _screenshotController.capture(
        delay: const Duration(milliseconds: 10),
        pixelRatio: 3.0,
      );
      
      if (image != null) {
        final xfile = XFile.fromData(image, mimeType: 'image/png', name: 'guest_wifi_card.png');
        await Share.shareXFiles([xfile], text: 'Here is the Wi-Fi connection card!');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.network == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Make a Guest Card')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(FluentIcons.wifi_off_24_regular, size: 80, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              const Text('No Network Selected', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Please generate or save a network first.', style: TextStyle(color: Colors.grey)),
            ],
          ).animate().fade().scale(),
        ),
      );
    }

    final network = widget.network!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Make a Guest Card', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                icon: const Icon(FluentIcons.share_ios_24_regular, size: 20),
                onPressed: _isExporting ? null : _shareGuestCard,
                tooltip: 'Share Card',
              ),
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    // Preview Area
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        color: Theme.of(context).scaffoldBackgroundColor,
                        child: Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(24),
                            child: Hero(
                              tag: 'guest_card_preview',
                              child: Material(
                                elevation: 12,
                                shadowColor: Colors.black.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(24),
                                child: Screenshot(
                                  controller: _screenshotController,
                                  child: _buildSelectedTemplate(network),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    // Editor Bottom Sheet Area
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, spreadRadius: 2, offset: const Offset(0, -5))
                        ],
                      ),
                      child: SafeArea(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('Card Title', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _titleController,
                              onChanged: (val) => setState(() => _title = val),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Theme.of(context).scaffoldBackgroundColor,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Templates', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                TextButton(onPressed: () {}, child: const Text('See all')),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 120,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: 4,
                                itemBuilder: (context, index) {
                                  return _buildTemplateThumbnail(index, network);
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ).animate().slideY(begin: 1, curve: Curves.easeOutBack, duration: 500.ms),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSelectedTemplate(WifiNetwork network) {
    switch (_selectedTemplateIndex) {
      case 0:
        return _buildModernGradientTemplate(network);
      case 1:
        return _buildCleanMinimalTemplate(network);
      case 2:
        return _buildDarkPremiumTemplate(network);
      case 3:
        return _buildBoldTypographicTemplate(network);
      default:
        return _buildModernGradientTemplate(network);
    }
  }

  Widget _buildTemplateThumbnail(int index, WifiNetwork network) {
    final isSelected = _selectedTemplateIndex == index;
    final labels = ['Gradient', 'Minimal', 'Premium', 'Bold'];
    return GestureDetector(
      onTap: () => setState(() => _selectedTemplateIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 12),
        width: 80,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Theme.of(context).colorScheme.primary : Colors.transparent,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Column(
            children: [
              Expanded(
                child: IgnorePointer(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: 300,
                      height: 450,
                      child: Builder(
                        builder: (context) {
                          switch (index) {
                            case 0: return _buildModernGradientTemplate(network);
                            case 1: return _buildCleanMinimalTemplate(network);
                            case 2: return _buildDarkPremiumTemplate(network);
                            case 3: return _buildBoldTypographicTemplate(network);
                            default: return _buildModernGradientTemplate(network);
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4),
                color: isSelected 
                    ? Theme.of(context).colorScheme.primary 
                    : Theme.of(context).cardColor,
                child: Text(
                  labels[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : null,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────── TEMPLATE 1: Modern Gradient ─────────────────────────

  Widget _buildModernGradientTemplate(WifiNetwork network) {
    return Container(
      width: 300,
      height: 450,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          children: [
            // WiFi icon badge
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(FluentIcons.wifi_1_24_filled, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 16),
            
            // Title
            Text(
              _title,
              style: const TextStyle(
                color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, height: 1.2,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              network.ssid,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 20),

            // QR Code
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20)],
              ),
              child: QrImageView(
                data: network.qrData,
                version: QrVersions.auto,
                size: 140,
                backgroundColor: Colors.white,
                embeddedImage: MemoryImage(base64Decode(AppConstants.wifiLogoBase64)),
                embeddedImageStyle: const QrEmbeddedImageStyle(size: Size(28, 28)),
              ),
            ),
            const SizedBox(height: 16),

            // Scan instruction
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.scan_24_regular, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text('Scan to connect', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              ),
            ),
            const Spacer(),

            // Password info
            if (network.password.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(FluentIcons.lock_closed_24_regular, color: Colors.white, size: 14),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        network.password,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── TEMPLATE 2: Clean Minimal ─────────────────────────

  Widget _buildCleanMinimalTemplate(WifiNetwork network) {
    return Container(
      width: 300,
      height: 450,
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAF8),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Thin line accent
            Container(width: 40, height: 3, color: const Color(0xFF2D2D2D)),
            const SizedBox(height: 20),
            
            Text(
              _title.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF2D2D2D), fontSize: 18, letterSpacing: 3, fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 28),

            // QR Code
            QrImageView(
              data: network.qrData,
              version: QrVersions.auto,
              size: 170,
              backgroundColor: const Color(0xFFFAFAF8),
              dataModuleStyle: const QrDataModuleStyle(color: Color(0xFF2D2D2D)),
              eyeStyle: const QrEyeStyle(color: Color(0xFF2D2D2D)),
              embeddedImage: MemoryImage(base64Decode(AppConstants.wifiLogoBase64)),
              embeddedImageStyle: const QrEmbeddedImageStyle(size: Size(30, 30)),
            ),
            const SizedBox(height: 28),

            // Network info
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(FluentIcons.wifi_1_24_regular, color: Color(0xFF666666), size: 18),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    network.ssid,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Color(0xFF2D2D2D)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (network.password.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(FluentIcons.lock_closed_24_regular, color: Color(0xFF666666), size: 18),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      network.password,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: Color(0xFF2D2D2D)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
            Container(width: 40, height: 3, color: const Color(0xFF2D2D2D)),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── TEMPLATE 3: Dark Premium ─────────────────────────

  Widget _buildDarkPremiumTemplate(WifiNetwork network) {
    return Container(
      width: 300,
      height: 450,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
        ),
        border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.5), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          children: [
            // Gold star
            const Icon(FluentIcons.star_24_filled, color: Color(0xFFD4AF37), size: 28),
            const SizedBox(height: 12),

            // Title
            Text(
              _title,
              style: const TextStyle(
                color: Color(0xFFD4AF37), fontSize: 22, fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            
            // Thin gold divider
            Container(
              width: 60,
              height: 1,
              margin: const EdgeInsets.symmetric(vertical: 8),
              color: const Color(0xFFD4AF37).withValues(alpha: 0.4),
            ),
            
            Text(
              'Guest Wi-Fi',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13, letterSpacing: 1.5),
            ),
            const SizedBox(height: 20),

            // QR Code
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: QrImageView(
                data: network.qrData,
                version: QrVersions.auto,
                size: 140,
                backgroundColor: Colors.white,
                embeddedImage: MemoryImage(base64Decode(AppConstants.wifiLogoBase64)),
                embeddedImageStyle: const QrEmbeddedImageStyle(size: Size(26, 26)),
              ),
            ),
            const Spacer(),

            // Network details
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('NETWORK', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      Flexible(
                        child: Text(
                          network.ssid,
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (network.password.isNotEmpty) ...[
                    Divider(color: Colors.white.withValues(alpha: 0.1), height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('PASSWORD', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        Flexible(
                          child: Text(
                            network.password,
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── TEMPLATE 4: Bold Typographic ─────────────────────────

  Widget _buildBoldTypographicTemplate(WifiNetwork network) {
    return Container(
      width: 300,
      height: 450,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF1A1A1A), width: 3),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              _title,
              style: const TextStyle(
                color: Color(0xFF1A1A1A), fontSize: 28, fontWeight: FontWeight.w900, height: 1.1,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            const Text(
              'SCAN • CONNECT • ENJOY',
              style: TextStyle(color: Color(0xFF888888), fontWeight: FontWeight.w700, fontSize: 10, letterSpacing: 2),
            ),
            const SizedBox(height: 20),

            // QR Code centered
            Center(
              child: QrImageView(
                data: network.qrData,
                version: QrVersions.auto,
                size: 160,
                backgroundColor: Colors.white,
                embeddedImage: MemoryImage(base64Decode(AppConstants.wifiLogoBase64)),
                embeddedImageStyle: const QrEmbeddedImageStyle(size: Size(28, 28)),
              ),
            ),
            const Spacer(),

            // Bottom info section
            Container(
              width: double.infinity,
              height: 2,
              color: const Color(0xFF1A1A1A),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('SSID', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Color(0xFF1A1A1A))),
                const Spacer(),
                Flexible(
                  child: Text(
                    network.ssid,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF444444)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (network.password.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Text('PASS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Color(0xFF1A1A1A))),
                  const Spacer(),
                  Flexible(
                    child: Text(
                      network.password,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF444444)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
