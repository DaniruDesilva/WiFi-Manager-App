import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/wifi_network.dart';
import '../utils/pdf_generator.dart';
import '../utils/ad_helper.dart';
import '../providers/premium_provider.dart';
import 'package:provider/provider.dart';
import 'paywall_screen.dart';

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
  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  String _securityType = 'WPA';
  bool _isHidden = false;

  @override
  void initState() {
    super.initState();
    _titleController.text = _title;
    if (widget.network != null) {
      _ssidController.text = widget.network!.ssid;
      _passwordController.text = widget.network!.password;
      _securityType = widget.network!.securityType;
      _isHidden = widget.network!.isHidden;
    } else {
      _ssidController.text = 'Guest Network';
      _passwordController.text = '';
      _securityType = 'WPA';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  WifiNetwork get _currentNetwork {
    return WifiNetwork(
      ssid: _ssidController.text,
      password: _passwordController.text,
      securityType: _securityType,
      isHidden: _isHidden,
    );
  }

  Future<void> _shareGuestCard() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a Card Title before exporting.')),
      );
      return;
    }
    
    if (_ssidController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a Wi-Fi Name (SSID) before exporting.')),
      );
      return;
    }

    if (_securityType != 'nopass' && _passwordController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a Password for this security type.')),
      );
      return;
    }

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
              leading: const Icon(FluentIcons.save_24_regular),
              title: const Text('Save to Gallery'),
              subtitle: const Text('Save the card image to your device'),
              onTap: () {
                Navigator.pop(context);
                _executeSaveImage();
              },
            ),
            ListTile(
              leading: const Icon(FluentIcons.share_24_regular),
              title: const Text('Share Image'),
              subtitle: const Text('Share the card as a PNG image'),
              onTap: () {
                Navigator.pop(context);
                _executeShareImage();
              },
            ),
            ListTile(
              leading: const Icon(FluentIcons.print_24_regular),
              title: const Text('Print Card'),
              subtitle: const Text('Print the exact card design'),
              onTap: () {
                Navigator.pop(context);
                _executePrintCard();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _executeSaveImage() async {
    setState(() => _isExporting = true);
    await Future.delayed(const Duration(milliseconds: 100));
    try {
      final Uint8List image = await _screenshotController.captureFromWidget(
        Material(
          color: Colors.transparent,
          child: _buildSelectedTemplate(_currentNetwork, isForExport: true),
        ),
        delay: const Duration(milliseconds: 50),
        pixelRatio: 3.0,
        context: context,
      );
      if (image.isNotEmpty) {
        final directory = await getTemporaryDirectory();
        final path = '${directory.path}/guest_wifi_card.png';
        final file = File(path);
        await file.writeAsBytes(image);
        await Gal.putImage(path);
        if (mounted) {
          showDialog(
            context: context,
            barrierColor: Colors.transparent,
            builder: (ctx) {
              Future.delayed(const Duration(milliseconds: 1500), () {
                if (ctx.mounted) Navigator.of(ctx).pop();
              });
              return Dialog(
                backgroundColor: Colors.black87,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(FluentIcons.checkmark_circle_24_regular, color: Colors.greenAccent),
                      const SizedBox(width: 12),
                      const Text('Saved to Gallery', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              );
            },
          );
        }
        if (mounted) AdHelper.showInterstitialAd(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _executePrintCard() async {
    setState(() => _isExporting = true);
    await Future.delayed(const Duration(milliseconds: 100));
    try {
      final Uint8List imageBytes = await _screenshotController.captureFromWidget(
        Material(
          color: Colors.transparent,
          child: _buildSelectedTemplate(_currentNetwork, isForExport: true),
        ),
        delay: const Duration(milliseconds: 50),
        pixelRatio: 3.0,
        context: context,
      );
      if (imageBytes.isNotEmpty) {
        await Printing.layoutPdf(
          onLayout: (PdfPageFormat format) async {
            final doc = pw.Document();
            final image = pw.MemoryImage(imageBytes);
            doc.addPage(
              pw.Page(
                pageFormat: format,
                margin: pw.EdgeInsets.zero,
                build: (pw.Context context) {
                  return pw.Center(
                    child: pw.Image(image, fit: pw.BoxFit.cover),
                  );
                },
              ),
            );
            return doc.save();
          },
          name: 'Guest_WiFi_Card',
        );
        if (mounted) AdHelper.showInterstitialAd(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to print: $e')));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _executeShareImage() async {
    setState(() => _isExporting = true);
    
    await Future.delayed(const Duration(milliseconds: 100));
    
    try {
      final Uint8List image = await _screenshotController.captureFromWidget(
        Material(
          color: Colors.transparent,
          child: _buildSelectedTemplate(_currentNetwork, isForExport: true),
        ),
        delay: const Duration(milliseconds: 50),
        pixelRatio: 3.0,
        context: context,
      );
      
      if (image.isNotEmpty) {
        final xfile = XFile.fromData(image, mimeType: 'image/png', name: 'guest_wifi_card.png');
        await Share.shareXFiles([xfile], text: 'Here is the Wi-Fi connection card!');
        if (mounted) AdHelper.showInterstitialAd(context);
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
    final network = _currentNetwork;

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
                            const SizedBox(height: 16),
                            const Text('Wi-Fi Name (SSID)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _ssidController,
                              onChanged: (val) => setState(() {}),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Theme.of(context).scaffoldBackgroundColor,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text('Password', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _passwordController,
                              onChanged: (val) => setState(() {}),
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Theme.of(context).scaffoldBackgroundColor,
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text('Security Type', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: Theme.of(context).scaffoldBackgroundColor,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _securityType,
                                  isExpanded: true,
                                  items: const [
                                    DropdownMenuItem(value: 'WPA', child: Text('WPA/WPA2/WPA3')),
                                    DropdownMenuItem(value: 'WEP', child: Text('WEP')),
                                    DropdownMenuItem(value: 'nopass', child: Text('None')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) setState(() => _securityType = val);
                                  },
                                ),
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
                                itemCount: 10,
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

  Widget _buildSelectedTemplate(WifiNetwork network, {bool isForExport = false}) {
    return _getTemplateByIndex(_selectedTemplateIndex, network, isForExport: isForExport);
  }

  Widget _getTemplateByIndex(int index, WifiNetwork network, {bool isForExport = false}) {
    switch (index) {
      case 0: return _buildModernGradientTemplate(network, isForExport: isForExport);
      case 1: return _buildCleanMinimalTemplate(network, isForExport: isForExport);
      case 2: return _buildDarkPremiumTemplate(network, isForExport: isForExport);
      case 3: return _buildBoldTypographicTemplate(network, isForExport: isForExport);
      case 4: return _buildCafeTemplate(network, isForExport: isForExport);
      case 5: return _buildRestaurantTemplate(network, isForExport: isForExport);
      case 6: return _buildTravelTemplate(network, isForExport: isForExport);
      case 7: return _buildSchoolTemplate(network, isForExport: isForExport);
      case 8: return _buildVehicleTemplate(network, isForExport: isForExport);
      case 9: return _buildEventTemplate(network, isForExport: isForExport);
      default: return _buildModernGradientTemplate(network);
    }
  }

  Widget _buildTemplateThumbnail(int index, WifiNetwork network) {
    final isSelected = _selectedTemplateIndex == index;
    final labels = [
      'Tech Modern', 'Minimalist', 'Stealth', 'Boutique',
      'Cafe', 'Restaurant', 'Travel', 'School', 'Vehicle', 'Event'
    ];
    // Templates 2 (Stealth) and 3 (Boutique) and 6 (Travel) are premium
    final isPremiumTemplate = index == 2 || index == 3 || index == 6; 
    
    return GestureDetector(
      onTap: () {
        if (isPremiumTemplate && !context.read<PremiumProvider>().isPremium) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const PaywallScreen()));
          return;
        }
        setState(() => _selectedTemplateIndex = index);
      },
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
                          return _getTemplateByIndex(index, network);
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isPremiumTemplate) 
                      Padding(
                        padding: const EdgeInsets.only(right: 2.0),
                        child: Icon(FluentIcons.premium_24_filled, color: isSelected ? Colors.white : Colors.amber, size: 10),
                      ),
                    Text(
                      labels[index],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────── TEMPLATE 1: Tech Modern ─────────────────────────

  Widget _buildModernGradientTemplate(WifiNetwork network, {bool isForExport = false}) {
    return Container(
      width: 300,
      height: isForExport ? 424.2 : 450,
      decoration: BoxDecoration(
        borderRadius: isForExport ? BorderRadius.zero : BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF007AFF), Color(0xFF0B3B60)], // Apple-like Tech Blue to Deep Blue
        ),
      ),
      child: Stack(
        children: [
          // Background abstract shapes (subtle)
          Positioned(
            top: -50, right: -50,
            child: Container(
              width: 150, height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Positioned(
            bottom: -80, left: -40,
            child: Container(
              width: 200, height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              children: [
                const SizedBox(height: 12),
                // Title
                Text(
                  _title,
                  style: const TextStyle(
                    color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 24),

                // Glassmorphism Card for QR & Details
                Expanded(
                  child: ClipRRect(
                    borderRadius: isForExport ? BorderRadius.zero : BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: isForExport ? BorderRadius.zero : BorderRadius.circular(24),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: isForExport ? BorderRadius.zero : BorderRadius.circular(20),
                                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10)],
                              ),
                              child: QrImageView(
                                data: network.qrData,
                                version: QrVersions.auto,
                                size: 140,
                                backgroundColor: Colors.white,
                                dataModuleStyle: const QrDataModuleStyle(color: Color(0xFF007AFF), dataModuleShape: QrDataModuleShape.square),
                                eyeStyle: const QrEyeStyle(color: Color(0xFF007AFF), eyeShape: QrEyeShape.square),
                                embeddedImageStyle: const QrEmbeddedImageStyle(size: Size(28, 28)),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              network.ssid,
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (network.password.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: isForExport ? BorderRadius.zero : BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(FluentIcons.lock_closed_24_regular, color: Colors.white, size: 14),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        network.password,
                                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 1),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── TEMPLATE 2: Pure Minimalist ─────────────────────────

  Widget _buildCleanMinimalTemplate(WifiNetwork network, {bool isForExport = false}) {
    return Container(
      width: 300,
      height: isForExport ? 424.2 : 450,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: isForExport ? BorderRadius.zero : BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, spreadRadius: 0)
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          children: [
            const Spacer(flex: 1),
            Text(
              _title,
              style: const TextStyle(
                color: Color(0xFF0F172A), fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              'Scan to connect automatically',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w500),
            ),
            const Spacer(flex: 2),

            // QR Code (No background box, just clean on white)
            QrImageView(
              data: network.qrData,
              version: QrVersions.auto,
              size: 160,
              backgroundColor: Colors.white,
              dataModuleStyle: const QrDataModuleStyle(color: Color(0xFF0F172A), dataModuleShape: QrDataModuleShape.square),
              eyeStyle: const QrEyeStyle(color: Color(0xFF0F172A), eyeShape: QrEyeShape.square),
              embeddedImageStyle: const QrEmbeddedImageStyle(size: Size(30, 30)),
            ),
            
            const Spacer(flex: 2),
            
            // Network Details Grid
            Divider(color: Colors.grey.shade200, height: 1),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('NETWORK', style: TextStyle(color: Colors.grey.shade400, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      const SizedBox(height: 4),
                      Text(network.ssid, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                if (network.password.isNotEmpty)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('PASSWORD', style: TextStyle(color: Colors.grey.shade400, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        const SizedBox(height: 4),
                        Text(network.password, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
              ],
            ),
            const Spacer(flex: 1),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── TEMPLATE 3: Stealth Premium ─────────────────────────

  Widget _buildDarkPremiumTemplate(WifiNetwork network, {bool isForExport = false}) {
    return Container(
      width: 300,
      height: isForExport ? 424.2 : 450,
      decoration: BoxDecoration(
        borderRadius: isForExport ? BorderRadius.zero : BorderRadius.circular(24),
        color: const Color(0xFF0F172A), // Deep Slate/Matte Black
        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3), width: 1),
        boxShadow: [
          BoxShadow(color: Colors.blueAccent.withValues(alpha: 0.1), blurRadius: 20, spreadRadius: 0),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Top Accent
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.blueAccent, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(
                  'SECURE NETWORK',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              _title,
              style: const TextStyle(
                color: Colors.white, fontSize: 26, fontWeight: FontWeight.w300, letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),

            // Inverted QR Code
            Center(
              child: QrImageView(
                data: network.qrData,
                version: QrVersions.auto,
                size: 160,
                backgroundColor: Colors.transparent, // Transparent background
                dataModuleStyle: const QrDataModuleStyle(color: Colors.white, dataModuleShape: QrDataModuleShape.circle), // White dots
                eyeStyle: const QrEyeStyle(color: Colors.white, eyeShape: QrEyeShape.circle),
                embeddedImageStyle: const QrEmbeddedImageStyle(size: Size(30, 30)),
              ),
            ),
            const Spacer(),

            // Info blocks
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: isForExport ? BorderRadius.zero : BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text('WIFI NAME', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                  const SizedBox(height: 4),
                  Text(network.ssid, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                  if (network.password.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('PASSWORD', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                    const SizedBox(height: 4),
                    Text(network.password, style: const TextStyle(color: Colors.blueAccent, fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 1), overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── TEMPLATE 4: Boutique Hotel ─────────────────────────

  Widget _buildBoldTypographicTemplate(WifiNetwork network, {bool isForExport = false}) {
    return Container(
      width: 300,
      height: isForExport ? 424.2 : 450,
      decoration: BoxDecoration(
        color: const Color(0xFFF7F5F0), // Beautiful warm off-white (cream)
        borderRadius: isForExport ? BorderRadius.zero : BorderRadius.circular(24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Top heavy line
            Container(width: 80, height: 4, color: const Color(0xFF111111)),
            const SizedBox(height: 16),
            
            // Title
            Text(
              _title.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF111111), fontSize: 32, fontWeight: FontWeight.w900, height: 1.0, letterSpacing: -1,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              'COMPLIMENTARY WI-FI',
              style: TextStyle(color: const Color(0xFF111111).withValues(alpha: 0.6), fontWeight: FontWeight.w700, fontSize: 10, letterSpacing: 2),
              textAlign: TextAlign.center,
            ),
            
            const Spacer(),

            // QR Code centered
            Center(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFF111111), width: 2),
                ),
                child: QrImageView(
                  data: network.qrData,
                  version: QrVersions.auto,
                  size: 110,
                  backgroundColor: const Color(0xFFF7F5F0),
                  dataModuleStyle: const QrDataModuleStyle(color: Color(0xFF111111), dataModuleShape: QrDataModuleShape.square),
                  eyeStyle: const QrEyeStyle(color: Color(0xFF111111), eyeShape: QrEyeShape.square),
                  embeddedImageStyle: const QrEmbeddedImageStyle(size: Size(24, 24)),
                ),
              ),
            ),
            
            const Spacer(),

            // Bottom info section
            Container(width: 120, height: 1.5, color: const Color(0xFF111111)),
            const SizedBox(height: 16),
            
            Text('NETWORK', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: Color(0xFF111111), letterSpacing: 1)),
            const SizedBox(height: 4),
            Text(
              network.ssid,
              style: const TextStyle(fontSize: 16, color: Color(0xFF111111), fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
            
            if (network.password.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('PASSCODE', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 10, color: Color(0xFF111111), letterSpacing: 1)),
              const SizedBox(height: 4),
              Text(
                network.password,
                style: const TextStyle(fontSize: 16, color: Color(0xFF111111), fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            
            const SizedBox(height: 16),
            Container(width: 80, height: 4, color: const Color(0xFF111111)),
          ],
        ),
      ),
    );
  }
  // ───────────────────────── TEMPLATE 5: Cafe / Coffee Shop ─────────────────────────

  Widget _buildCafeTemplate(WifiNetwork network, {bool isForExport = false}) {
    return Container(
      width: 300,
      height: isForExport ? 424.2 : 450,
      decoration: BoxDecoration(
        color: const Color(0xFFF4EBE1), // Latte Cream
        borderRadius: isForExport ? BorderRadius.zero : BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          // Decorative background circles
          Positioned(
            top: -60, left: -60,
            child: Container(width: 150, height: 150, decoration: const BoxDecoration(color: Color(0xFFE8D5C4), shape: BoxShape.circle)),
          ),
          Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              children: [
                const Icon(FluentIcons.drink_coffee_24_regular, color: Color(0xFF6D4C41), size: 32),
                const SizedBox(height: 12),
                Text(
                  _title,
                  style: const TextStyle(color: Color(0xFF5D4037), fontSize: 22, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Grab a Coffee & Connect',
                  style: TextStyle(color: const Color(0xFF795548).withValues(alpha: 0.8), fontSize: 12, fontStyle: FontStyle.italic),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: isForExport ? BorderRadius.zero : BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: const Color(0xFF8D6E63).withValues(alpha: 0.1), blurRadius: 15)],
                  ),
                  child: QrImageView(
                    data: network.qrData,
                    version: QrVersions.auto,
                    size: 130,
                    backgroundColor: Colors.white,
                    dataModuleStyle: const QrDataModuleStyle(color: Color(0xFF5D4037), dataModuleShape: QrDataModuleShape.circle),
                    eyeStyle: const QrEyeStyle(color: Color(0xFF5D4037), eyeShape: QrEyeShape.circle),
                    embeddedImageStyle: const QrEmbeddedImageStyle(size: Size(24, 24)),
                  ),
                ),
                const Spacer(),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8D6E63).withValues(alpha: 0.1),
                    borderRadius: isForExport ? BorderRadius.zero : BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Text('NETWORK', style: const TextStyle(color: Color(0xFF795548), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
                      Text(network.ssid, style: const TextStyle(color: Color(0xFF4E342E), fontSize: 15, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                      if (network.password.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('PASSWORD', style: const TextStyle(color: Color(0xFF795548), fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1)),
                        Text(network.password, style: const TextStyle(color: Color(0xFF4E342E), fontSize: 15, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── TEMPLATE 6: Restaurant / Dining ─────────────────────────

  Widget _buildRestaurantTemplate(WifiNetwork network, {bool isForExport = false}) {
    return Container(
      width: 300,
      height: isForExport ? 424.2 : 450,
      decoration: BoxDecoration(
        color: const Color(0xFF2C0E14), // Deep Burgundy
        borderRadius: isForExport ? BorderRadius.zero : BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFD4AF37), width: 2), // Gold Border
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Icon(FluentIcons.food_24_regular, color: Color(0xFFD4AF37), size: 28),
            const SizedBox(height: 12),
            Text(
              _title,
              style: const TextStyle(color: Color(0xFFD4AF37), fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: 1),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              'BON APPÉTIT & WI-FI',
              style: TextStyle(color: const Color(0xFFD4AF37).withValues(alpha: 0.7), fontSize: 10, letterSpacing: 2),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFD4AF37), width: 1),
              ),
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(8),
                child: QrImageView(
                  data: network.qrData,
                  version: QrVersions.auto,
                  size: 130,
                  backgroundColor: Colors.white,
                  dataModuleStyle: const QrDataModuleStyle(color: Color(0xFF2C0E14), dataModuleShape: QrDataModuleShape.square),
                  eyeStyle: const QrEyeStyle(color: Color(0xFF2C0E14), eyeShape: QrEyeShape.square),
                  embeddedImageStyle: const QrEmbeddedImageStyle(size: Size(24, 24)),
                ),
              ),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('NETWORK', style: TextStyle(color: Color(0xFFD4AF37), fontSize: 9, letterSpacing: 1)),
                      Text(network.ssid, style: const TextStyle(color: Colors.white, fontSize: 14), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                if (network.password.isNotEmpty)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('PASSWORD', style: TextStyle(color: Color(0xFFD4AF37), fontSize: 9, letterSpacing: 1)),
                        Text(network.password, style: const TextStyle(color: Colors.white, fontSize: 14), overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── TEMPLATE 7: Tourist / Travel ─────────────────────────

  Widget _buildTravelTemplate(WifiNetwork network, {bool isForExport = false}) {
    return Container(
      width: 300,
      height: isForExport ? 424.2 : 450,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [Color(0xFFFF9900), Color(0xFFFF5E62)],
        ),
        borderRadius: isForExport ? BorderRadius.zero : BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20, top: 100,
            child: Icon(FluentIcons.airplane_24_filled, color: Colors.white.withValues(alpha: 0.1), size: 120),
          ),
          Padding(
            padding: const EdgeInsets.all(28.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                    child: const Text('EXPLORE & CONNECT', style: TextStyle(color: Color(0xFFFF5E62), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _title,
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900, height: 1.1),
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: isForExport ? BorderRadius.zero : BorderRadius.circular(32),
                      boxShadow: [BoxShadow(color: const Color(0xFFFF5E62).withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 10))],
                    ),
                    child: QrImageView(
                      data: network.qrData,
                      version: QrVersions.auto,
                      size: 140,
                      backgroundColor: Colors.white,
                      dataModuleStyle: const QrDataModuleStyle(color: Color(0xFFFF5E62), dataModuleShape: QrDataModuleShape.circle),
                      eyeStyle: const QrEyeStyle(color: Color(0xFFFF5E62), eyeShape: QrEyeShape.circle),
                      embeddedImageStyle: const QrEmbeddedImageStyle(size: Size(28, 28)),
                    ),
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    const Icon(FluentIcons.location_24_filled, color: Colors.white, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(network.ssid, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                          if (network.password.isNotEmpty)
                            Text('Pass: ${network.password}', style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14), overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── TEMPLATE 8: School / University ─────────────────────────

  Widget _buildSchoolTemplate(WifiNetwork network, {bool isForExport = false}) {
    return Container(
      width: 300,
      height: isForExport ? 424.2 : 450,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: isForExport ? BorderRadius.zero : BorderRadius.circular(16), // Less rounded for ID card look
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: const BoxDecoration(
              color: Color(0xFF003366),
              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Column(
              children: [
                const Icon(FluentIcons.library_24_filled, color: Colors.white, size: 28),
                const SizedBox(height: 8),
                Text(
                  _title,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const Text('CAMPUS NETWORK', style: TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 1.5)),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  QrImageView(
                    data: network.qrData,
                    version: QrVersions.auto,
                    size: 150,
                    backgroundColor: Colors.white,
                    dataModuleStyle: const QrDataModuleStyle(color: Color(0xFF003366), dataModuleShape: QrDataModuleShape.square),
                    eyeStyle: const QrEyeStyle(color: Color(0xFF003366), eyeShape: QrEyeShape.square),
                    embeddedImageStyle: const QrEmbeddedImageStyle(size: Size(30, 30)),
                  ),
                  const Spacer(),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: isForExport ? BorderRadius.zero : BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      children: [
                        Text('NETWORK ID', style: TextStyle(color: Colors.grey.shade600, fontSize: 9, fontWeight: FontWeight.bold)),
                        Text(network.ssid, style: const TextStyle(color: Color(0xFF003366), fontSize: 14, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                        if (network.password.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text('ACCESS KEY', style: TextStyle(color: Colors.grey.shade600, fontSize: 9, fontWeight: FontWeight.bold)),
                          Text(network.password, style: const TextStyle(color: Color(0xFF003366), fontSize: 14, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── TEMPLATE 9: Vehicle / Rideshare ─────────────────────────

  Widget _buildVehicleTemplate(WifiNetwork network, {bool isForExport = false}) {
    return Container(
      width: 300,
      height: isForExport ? 424.2 : 450,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: isForExport ? BorderRadius.zero : BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF39FF14).withValues(alpha: 0.3), width: 1), // Neon Green border
      ),
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(FluentIcons.vehicle_car_24_filled, color: Color(0xFF39FF14), size: 28),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    _title,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text('ENJOY THE RIDE & SURF', style: TextStyle(color: Colors.white54, fontSize: 10, letterSpacing: 1)),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: isForExport ? BorderRadius.zero : BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: const Color(0xFF39FF14).withValues(alpha: 0.2), blurRadius: 20, spreadRadius: 5)],
              ),
              child: QrImageView(
                data: network.qrData,
                version: QrVersions.auto,
                size: 150,
                backgroundColor: Colors.white,
                dataModuleStyle: const QrDataModuleStyle(color: Colors.black, dataModuleShape: QrDataModuleShape.square),
                eyeStyle: const QrEyeStyle(color: Colors.black, eyeShape: QrEyeShape.square),
                embeddedImageStyle: const QrEmbeddedImageStyle(size: Size(30, 30)),
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: isForExport ? BorderRadius.zero : BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF222222)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('WIFI', style: TextStyle(color: Color(0xFF39FF14), fontSize: 10, fontWeight: FontWeight.bold)),
                  Text(network.ssid, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (network.password.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text('PASS', style: TextStyle(color: Color(0xFF39FF14), fontSize: 10, fontWeight: FontWeight.bold)),
                    Text(network.password, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── TEMPLATE 10: Event / Conference ─────────────────────────

  Widget _buildEventTemplate(WifiNetwork network, {bool isForExport = false}) {
    return Container(
      width: 300,
      height: isForExport ? 424.2 : 450,
      decoration: BoxDecoration(
        borderRadius: isForExport ? BorderRadius.zero : BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
          colors: [Color(0xFF4A00E0), Color(0xFF8E2DE2)], // Deep Purple to Magenta
        ),
      ),
      child: Column(
        children: [
          // "Lanyard" hole styling
          const SizedBox(height: 20),
          Container(
            width: 60,
            height: 12,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.2),
              borderRadius: isForExport ? BorderRadius.zero : BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: isForExport ? BorderRadius.zero : BorderRadius.circular(20),
                  ),
                  child: const Text('GUEST ACCESS', style: TextStyle(color: Color(0xFF8E2DE2), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1)),
                ),
                const SizedBox(height: 16),
                Text(
                  _title,
                  style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: isForExport ? BorderRadius.zero : BorderRadius.circular(24),
                  ),
                  child: QrImageView(
                    data: network.qrData,
                    version: QrVersions.auto,
                    size: 140,
                    backgroundColor: Colors.white,
                    dataModuleStyle: const QrDataModuleStyle(color: Color(0xFF4A00E0), dataModuleShape: QrDataModuleShape.circle),
                    eyeStyle: const QrEyeStyle(color: Color(0xFF4A00E0), eyeShape: QrEyeShape.circle),
                    embeddedImageStyle: const QrEmbeddedImageStyle(size: Size(28, 28)),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: isForExport ? BorderRadius.zero : BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      Text(network.ssid, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                      if (network.password.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(network.password, style: const TextStyle(color: Colors.white70, fontSize: 14), overflow: TextOverflow.ellipsis),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
