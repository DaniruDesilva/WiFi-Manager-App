import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/wifi_network.dart';

class WidgetHelper {
  static const String _providerName = 'WifiWidgetProvider';

  /// Pins a specific network to the Android Home Screen Widget.
  /// Generates the QR image to permanent app documents storage,
  /// saves widget data, and immediately notifies the widget provider to redraw.
  static Future<bool> pinNetwork(
    WifiNetwork network, {
    bool requestPin = true,
  }) async {
    try {
      // 1. Generate QR code painter
      final qrValidationResult = QrValidator.validate(
        data: network.qrData,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
      );

      if (qrValidationResult.status != QrValidationStatus.valid ||
          qrValidationResult.qrCode == null) {
        return false;
      }

      final qrCode = qrValidationResult.qrCode!;
      final painter = QrPainter.withQr(
        qr: qrCode,
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Colors.black,
        ),
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: Colors.black,
        ),
        gapless: true,
      );

      // 2. Save image to permanent documents directory
      final docsDir = await getApplicationDocumentsDirectory();
      final file = File('${docsDir.path}/pinned_widget_qr.png');

      final picData = await painter.toImageData(600, format: ui.ImageByteFormat.png);
      if (picData == null) return false;

      await file.writeAsBytes(picData.buffer.asUint8List(), flush: true);

      // 3. Save widget data to HomeWidget storage
      await HomeWidget.saveWidgetData<String>('wifi_ssid', network.ssid);
      await HomeWidget.saveWidgetData<String>('wifi_password', network.password);
      await HomeWidget.saveWidgetData<String>('wifi_qr_data', network.qrData);
      await HomeWidget.saveWidgetData<String>('wifi_qr_image_path', file.path);

      // 4. Force immediate update of any active widget on the home screen
      await HomeWidget.updateWidget(
        name: _providerName,
        androidName: _providerName,
      );

      // 5. If requested, ask launcher to pin new widget
      if (requestPin) {
        try {
          await HomeWidget.requestPinWidget(
            name: _providerName,
            androidName: _providerName,
          );
        } catch (_) {
          // Some launchers don't support requestPinWidget; updateWidget already handled active widgets
        }
      }

      return true;
    } catch (e) {
      debugPrint('Error pinning network to widget: $e');
      return false;
    }
  }

  /// Automatically updates the widget with the user's primary/latest saved network
  /// if no network is pinned yet or if the pinned network needs refreshing.
  static Future<void> autoSyncLatestNetworkIfEmpty(List<WifiNetwork> history) async {
    if (history.isEmpty) return;
    try {
      final currentSsid = await HomeWidget.getWidgetData<String>('wifi_ssid');
      if (currentSsid == null || currentSsid.isEmpty) {
        await pinNetwork(history.first, requestPin: false);
      }
    } catch (e) {
      debugPrint('Error auto-syncing widget: $e');
    }
  }
}
