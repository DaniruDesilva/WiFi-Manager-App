import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:home_widget/home_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';
import 'package:screenshot/screenshot.dart';
import '../models/wifi_network.dart';
import 'pdf_generator.dart';

/// Shared bottom sheet for displaying network details.
/// Used by both DashboardScreen and HistoryScreen.
void showNetworkDetailsSheet(BuildContext context, WifiNetwork network) {
  final screenshotController = ScreenshotController();
  
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.5,
      maxChildSize: 0.92,
      builder: (_, scrollController) => Container(
        decoration: BoxDecoration(
          color: Theme.of(sheetContext).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20, spreadRadius: 5),
          ],
        ),
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(32, 16, 32, 32),
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Network Name
            Text(
              network.ssid,
              style: Theme.of(sheetContext).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Security: ${network.securityType}',
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),

            // Category Badge
            if (network.category != null) ...[
              const SizedBox(height: 12),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Theme.of(sheetContext).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    network.category!,
                    style: TextStyle(
                      color: Theme.of(sheetContext).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],

            // Password Row
            if (network.password.isNotEmpty) ...[
              const SizedBox(height: 24),
              _PasswordRow(network: network),
            ],

            const SizedBox(height: 32),

            // QR Code
            Center(
              child: Screenshot(
                controller: screenshotController,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, spreadRadius: 5),
                    ],
                  ),
                  child: QrImageView(
                    data: network.qrData,
                    version: QrVersions.auto,
                    size: 200.0,
                    backgroundColor: Colors.white,
                    dataModuleStyle: QrDataModuleStyle(
                      dataModuleShape: network.isSquareDots ? QrDataModuleShape.square : QrDataModuleShape.circle,
                      color: network.qrColorHex != null ? Color(int.parse(network.qrColorHex!, radix: 16)) : Colors.black,
                    ),
                    eyeStyle: QrEyeStyle(
                      eyeShape: network.isSquareEyes ? QrEyeShape.square : QrEyeShape.circle,
                      color: network.qrColorHex != null ? Color(int.parse(network.qrColorHex!, radix: 16)) : Colors.black,
                    ),
                    embeddedImageStyle: const QrEmbeddedImageStyle(size: Size(36, 36)),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Action Buttons
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _saveQrCode(sheetContext, network, screenshotController),
                  icon: const Icon(FluentIcons.save_24_regular),
                  label: const Text('Save'),
                  style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
                OutlinedButton.icon(
                  onPressed: () => _shareQrCode(sheetContext, network, screenshotController),
                  icon: const Icon(FluentIcons.share_24_regular),
                  label: const Text('Share'),
                  style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
                FilledButton.icon(
                  onPressed: () => _printQrCode(sheetContext, network),
                  icon: const Icon(FluentIcons.print_24_regular),
                  label: const Text('Print'),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    backgroundColor: Theme.of(sheetContext).colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Pin to Home Screen Button
            FilledButton.icon(
              onPressed: () => _pinToHomeScreen(sheetContext, network),
              icon: const Icon(FluentIcons.pin_24_regular),
              label: const Text('Pin to Home Screen', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                backgroundColor: Theme.of(sheetContext).colorScheme.secondary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),

            const SizedBox(height: 16),

            // Close Button
            TextButton(
              onPressed: () => Navigator.pop(sheetContext),
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    ),
  );
}

Future<void> _pinToHomeScreen(BuildContext context, WifiNetwork network) async {
  try {
    // Generate QR Image for the widget
    final qrValidationResult = QrValidator.validate(
      data: network.qrData,
      version: QrVersions.auto,
      errorCorrectionLevel: QrErrorCorrectLevel.L,
    );
    
    if (qrValidationResult.status == QrValidationStatus.valid) {
      final qrCode = qrValidationResult.qrCode;
      final painter = QrPainter.withQr(
        qr: qrCode!,
        dataModuleStyle: QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: network.qrColorHex != null ? Color(int.parse(network.qrColorHex!, radix: 16)) : Colors.black,
        ),
        eyeStyle: QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: network.qrColorHex != null ? Color(int.parse(network.qrColorHex!, radix: 16)) : Colors.black,
        ),
        gapless: true,
      );
      
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/widget_qr_${DateTime.now().millisecondsSinceEpoch}.png');
      
      final picData = await painter.toImageData(600, format: ui.ImageByteFormat.png);
      if (picData != null) {
        await file.writeAsBytes(picData.buffer.asUint8List());
        await HomeWidget.saveWidgetData<String>('wifi_qr_image_path', file.path);
      }
    }

    await HomeWidget.saveWidgetData<String>('wifi_ssid', network.ssid);
    await HomeWidget.saveWidgetData<String>('wifi_password', network.password);
    await HomeWidget.saveWidgetData<String>('wifi_qr_data', network.qrData);

    // Use requestPinWidget to actually pin the widget to the home screen
    await HomeWidget.requestPinWidget(
      name: 'WifiWidgetProvider',
      androidName: 'WifiWidgetProvider',
    );

    if (!context.mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Widget pin requested! Check your home screen.'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  } catch (e) {
    if (!context.mounted) return;
    // Fallback: try updateWidget for devices that don't support pinning
    try {
      await HomeWidget.updateWidget(
        name: 'WifiWidgetProvider',
        androidName: 'WifiWidgetProvider',
      );
      if (!context.mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Widget data updated. Add the widget manually from your home screen widget picker.'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e2) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not pin widget: $e2'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }
}

Future<void> _saveQrCode(BuildContext context, WifiNetwork network, ScreenshotController screenshotController) async {
  try {
    final image = await screenshotController.capture();
    if (image != null) {
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) await Gal.requestAccess();
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/wifi_qr_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(path);
      await file.writeAsBytes(image);
      await Gal.putImage(path);
      if (context.mounted) {
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
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(FluentIcons.checkmark_circle_24_regular, color: Colors.greenAccent),
                    SizedBox(width: 12),
                    Text('Saved to Gallery', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            );
          },
        );
      }
    }
  } catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving QR Code: $e')));
  }
}

Future<void> _shareQrCode(BuildContext context, WifiNetwork network, ScreenshotController screenshotController) async {
  try {
    final image = await screenshotController.capture();
    if (image != null) {
      final directory = await getTemporaryDirectory();
      final path = '${directory.path}/wifi_qr_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(path);
      await file.writeAsBytes(image);
      final xFile = XFile(path);
      await Share.shareXFiles([xFile], text: 'Connect to my Wi-Fi: ${network.ssid}');
    }
  } catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error sharing QR Code: $e')));
  }
}

Future<void> _printQrCode(BuildContext context, WifiNetwork network) async {
  try {
    await PdfGenerator.printWifiPoster(network);
  } catch (e) {
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error printing poster: $e')));
  }
}

/// Stateful password row widget for the bottom sheet
class _PasswordRow extends StatefulWidget {
  final WifiNetwork network;
  const _PasswordRow({required this.network});

  @override
  State<_PasswordRow> createState() => _PasswordRowState();
}

class _PasswordRowState extends State<_PasswordRow> {
  bool _isVisible = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(FluentIcons.password_24_regular),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _isVisible ? widget.network.password : '••••••••',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 2),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: Icon(_isVisible ? FluentIcons.eye_off_24_regular : FluentIcons.eye_24_regular),
            onPressed: () {
              HapticFeedback.lightImpact();
              setState(() => _isVisible = !_isVisible);
            },
          ),
          IconButton(
            icon: const Icon(FluentIcons.copy_24_regular),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: widget.network.password));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Password copied to clipboard'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
