import 'dart:typed_data';
import 'dart:io';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:provider/provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/nfc_manager_android.dart';
import 'package:nfc_manager/ndef_record.dart';
import 'dart:convert';
import '../providers/history_provider.dart';
import '../models/wifi_network.dart';
import '../utils/constants.dart';
import '../utils/pdf_generator.dart';

class GenerateScreen extends StatefulWidget {
  const GenerateScreen({super.key});

  @override
  State<GenerateScreen> createState() => _GenerateScreenState();
}

class _GenerateScreenState extends State<GenerateScreen> {
  final TextEditingController _ssidController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final ScreenshotController _screenshotController = ScreenshotController();

  String _securityType = 'WPA';
  String? _category;
  bool _isHidden = false;
  bool _obscurePassword = true;
  WifiNetwork? _generatedNetwork;

  // Customization state
  Color _qrColor = Colors.black;
  bool _isSquareDots = true;
  bool _isSquareEyes = true;

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _generateQrCode() {
    final ssid = _ssidController.text.trim();
    final password = _passwordController.text;

    if (ssid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a Network Name (SSID)')),
      );
      return;
    }

    final network = WifiNetwork(
      ssid: ssid,
      password: password,
      securityType: _securityType,
      isHidden: _isHidden,
      category: _category,
      qrColorHex: _qrColor.value.toRadixString(16).padLeft(8, '0'),
      isSquareDots: _isSquareDots,
      isSquareEyes: _isSquareEyes,
    );

    setState(() {
      _generatedNetwork = network;
    });

    Provider.of<HistoryProvider>(context, listen: false).addNetwork(network);
    FocusScope.of(context).unfocus();
  }

  Future<void> _autoDetectWifi() async {
    final status = await Permission.locationWhenInUse.request();
    if (status.isGranted) {
      final info = NetworkInfo();
      String? wifiName = await info.getWifiName();
      if (wifiName != null && wifiName != '<unknown ssid>') {
        // Remove quotes around SSID if present
        if (wifiName.startsWith('"') && wifiName.endsWith('"')) {
          wifiName = wifiName.substring(1, wifiName.length - 1);
        }
        setState(() {
          _ssidController.text = wifiName!;
        });
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not detect Wi-Fi. Ensure Location is turned ON and you are connected to a network.')),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission is required to detect Wi-Fi name.')),
        );
      }
    }
  }

  void _pickColor() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Pick QR Color'),
          content: SingleChildScrollView(
            child: BlockPicker(
              pickerColor: _qrColor,
              onColorChanged: (color) {
                setState(() {
                  _qrColor = color;
                });
              },
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Done'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  Future<void> _shareQrCode() async {
    if (_generatedNetwork == null) return;
    try {
      final Uint8List? image = await _screenshotController.capture();
      if (image != null) {
        final directory = await getTemporaryDirectory();
        final path = '${directory.path}/wifi_qr.png';
        final file = File(path);
        await file.writeAsBytes(image);
        final xFile = XFile(path);
        await Share.shareXFiles([xFile], text: 'Connect to my Wi-Fi: ${_generatedNetwork!.ssid}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing QR Code: $e')),
        );
      }
    }
  }

  Future<void> _saveQrCode() async {
    if (_generatedNetwork == null) return;
    try {
      final Uint8List? image = await _screenshotController.capture();
      if (image != null) {
        final hasAccess = await Gal.hasAccess();
        if (!hasAccess) {
          await Gal.requestAccess();
        }
        
        final directory = await getTemporaryDirectory();
        final path = '${directory.path}/wifi_qr_${DateTime.now().millisecondsSinceEpoch}.png';
        final file = File(path);
        await file.writeAsBytes(image);

        await Gal.putImage(path);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('QR Code saved to gallery')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving QR Code: $e')),
        );
      }
    }
  }

  Future<void> _printPoster() async {
    if (_generatedNetwork == null) return;
    try {
      await PdfGenerator.printWifiPoster(_generatedNetwork!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error printing poster: $e')),
        );
      }
    }
  }

  Future<void> _writeToNFC() async {
    if (_generatedNetwork == null) return;
    
    // Check if NFC is available
    final availability = await NfcManager.instance.checkAvailability();
    if (availability != NfcAvailability.enabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('NFC is not available on this device.')),
        );
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Approach an NFC tag to write the Wi-Fi credentials...'),
          duration: Duration(seconds: 5),
        ),
      );
    }

    NfcManager.instance.startSession(
      pollingOptions: {NfcPollingOption.iso14443, NfcPollingOption.iso15693},
      onDiscovered: (NfcTag tag) async {
        var ndef = NdefAndroid.from(tag);
        if (ndef == null || !ndef.isWritable) {
          await NfcManager.instance.stopSession();
          return;
        }

        // Write Wi-Fi data as a text NDEF record
        final wifiData = _generatedNetwork!.qrData;
        final languageCode = 'en';
        final textBytes = utf8.encode(wifiData);
        final languageCodeBytes = utf8.encode(languageCode);
        final payloadBytes = <int>[
          languageCodeBytes.length,
          ...languageCodeBytes,
          ...textBytes,
        ];

        final message = NdefMessage(
          records: [
            NdefRecord(
              typeNameFormat: TypeNameFormat.wellKnown,
              type: Uint8List.fromList(utf8.encode('T')),
              identifier: Uint8List(0),
              payload: Uint8List.fromList(payloadBytes),
            ),
          ],
        );

        try {
          await ndef.writeNdefMessage(message);
          await NfcManager.instance.stopSession();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Wi-Fi written to NFC tag successfully!')),
            );
          }
        } catch (e) {
          await NfcManager.instance.stopSession();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('NFC write failed: $e')),
            );
          }
        }
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData prefixIcon,
    Widget? suffixIcon,
    bool obscureText = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.normal),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
        ),
        filled: true,
        fillColor: Theme.of(context).cardColor,
        prefixIcon: Icon(prefixIcon, color: Theme.of(context).colorScheme.primary),
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      ),
    );
  }

  Widget _buildDropdown<T>({
    required T value,
    required String label,
    required IconData prefixIcon,
    required List<DropdownMenuItem<T>> items,
    required void Function(T?) onChanged,
  }) {
    return DropdownButtonFormField<T>(
      value: value,
      icon: const Icon(FluentIcons.chevron_down_20_regular),
      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Theme.of(context).textTheme.bodyLarge?.color),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.normal),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
        ),
        filled: true,
        fillColor: Theme.of(context).cardColor,
        prefixIcon: Icon(prefixIcon, color: Theme.of(context).colorScheme.primary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      ),
      items: items,
      onChanged: onChanged,
      dropdownColor: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(16),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create QR Code', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Network Details Card
                Card(
                  elevation: 8,
                  shadowColor: Colors.black.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(FluentIcons.wifi_1_24_filled, size: 28, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(width: 12),
                            Text('Network Details', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _buildTextField(
                          controller: _ssidController,
                          label: 'Network Name (SSID)',
                          prefixIcon: FluentIcons.text_field_24_regular,
                          suffixIcon: IconButton(
                            icon: const Icon(FluentIcons.location_24_regular),
                            tooltip: 'Auto-detect current Wi-Fi',
                            onPressed: _autoDetectWifi,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildDropdown<String?>(
                          value: _category,
                          label: 'Category (Optional)',
                          prefixIcon: FluentIcons.tag_24_regular,
                          items: const [
                            DropdownMenuItem(value: null, child: Text('None')),
                            DropdownMenuItem(value: 'Home', child: Text('Home')),
                            DropdownMenuItem(value: 'Work', child: Text('Work')),
                            DropdownMenuItem(value: 'Guest', child: Text('Guest')),
                            DropdownMenuItem(value: 'Other', child: Text('Other')),
                          ],
                          onChanged: (value) => setState(() => _category = value),
                        ),
                        const SizedBox(height: 16),
                        _buildDropdown<String>(
                          value: _securityType,
                          label: 'Security Type',
                          prefixIcon: FluentIcons.lock_shield_24_regular,
                          items: const [
                            DropdownMenuItem(value: 'WPA', child: Text('WPA / WPA2 / WPA3')),
                            DropdownMenuItem(value: 'WEP', child: Text('WEP')),
                            DropdownMenuItem(value: 'nopass', child: Text('None')),
                          ],
                          onChanged: (value) {
                            if (value != null) setState(() => _securityType = value);
                          },
                        ),
                        if (_securityType != 'nopass') ...[
                          const SizedBox(height: 16),
                          _buildTextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            label: 'Password',
                            prefixIcon: FluentIcons.password_24_regular,
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? FluentIcons.eye_24_regular : FluentIcons.eye_off_24_regular),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        SwitchListTile(
                          title: const Text('Hidden Network', style: TextStyle(fontWeight: FontWeight.w500)),
                          value: _isHidden,
                          onChanged: (value) => setState(() => _isHidden = value),
                          activeColor: Theme.of(context).colorScheme.primary,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                ).animate().fade(duration: 400.ms).slideY(begin: 0.2),

                const SizedBox(height: 24),

                // Customization Card
                Card(
                  elevation: 8,
                  shadowColor: Colors.black.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  child: Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      title: const Text('QR Customization', style: TextStyle(fontWeight: FontWeight.bold)),
                      leading: Icon(FluentIcons.paint_brush_24_filled, color: Theme.of(context).colorScheme.primary),
                      childrenPadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
                      children: [
                        ListTile(
                          title: const Text('QR Color', style: TextStyle(fontWeight: FontWeight.w500)),
                          contentPadding: EdgeInsets.zero,
                          trailing: GestureDetector(
                            onTap: _pickColor,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: _qrColor,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.grey.shade300, width: 2),
                                boxShadow: [
                                  BoxShadow(color: _qrColor.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 4)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SwitchListTile(
                          title: const Text('Square Dots', style: TextStyle(fontWeight: FontWeight.w500)),
                          value: _isSquareDots,
                          onChanged: (val) => setState(() => _isSquareDots = val),
                          activeColor: Theme.of(context).colorScheme.primary,
                          contentPadding: EdgeInsets.zero,
                        ),
                        SwitchListTile(
                          title: const Text('Square Corner Eyes', style: TextStyle(fontWeight: FontWeight.w500)),
                          value: _isSquareEyes,
                          onChanged: (val) => setState(() => _isSquareEyes = val),
                          activeColor: Theme.of(context).colorScheme.primary,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                  ),
                ).animate().fade(delay: 100.ms).slideY(begin: 0.2),

                const SizedBox(height: 32),
                
                // Massive Generate Button
                FilledButton.icon(
                  onPressed: _generateQrCode,
                  icon: const Icon(FluentIcons.qr_code_24_filled),
                  label: const Text('Generate QR Code', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(64),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    elevation: 8,
                    shadowColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                  ),
                ).animate().fade(delay: 200.ms).scale(begin: const Offset(0.9, 0.9)),

                if (_generatedNetwork != null) ...[
                  const SizedBox(height: 48),
                  Screenshot(
                    controller: _screenshotController,
                    child: Card(
                      elevation: 12,
                      shadowColor: Colors.black.withValues(alpha: 0.2),
                      color: Theme.of(context).colorScheme.surface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          children: [
                            Text(
                              _generatedNetwork!.ssid,
                              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Scan to connect',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                            ),
                            const SizedBox(height: 32),
                            Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, spreadRadius: 5),
                                ]
                              ),
                              child: QrImageView(
                                data: _generatedNetwork!.qrData,
                                version: QrVersions.auto,
                                size: 200.0,
                                backgroundColor: Colors.white,
                                dataModuleStyle: QrDataModuleStyle(
                                  dataModuleShape: _generatedNetwork!.isSquareDots ? QrDataModuleShape.square : QrDataModuleShape.circle,
                                  color: _generatedNetwork!.qrColorHex != null ? Color(int.parse(_generatedNetwork!.qrColorHex!, radix: 16)) : Colors.black,
                                ),
                                eyeStyle: QrEyeStyle(
                                  eyeShape: _generatedNetwork!.isSquareEyes ? QrEyeShape.square : QrEyeShape.circle,
                                  color: _generatedNetwork!.qrColorHex != null ? Color(int.parse(_generatedNetwork!.qrColorHex!, radix: 16)) : Colors.black,
                                ),
                                embeddedImage: MemoryImage(base64Decode(AppConstants.wifiLogoBase64)),
                                embeddedImageStyle: const QrEmbeddedImageStyle(size: Size(32, 32)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ).animate().fade().scale(curve: Curves.easeOutBack, duration: 500.ms),
                  const SizedBox(height: 24),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _saveQrCode,
                        icon: const Icon(FluentIcons.save_24_regular),
                        label: const Text('Save'),
                        style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      ),
                      OutlinedButton.icon(
                        onPressed: _shareQrCode,
                        icon: const Icon(FluentIcons.share_24_regular),
                        label: const Text('Share'),
                        style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      ),
                      FilledButton.icon(
                        onPressed: _printPoster,
                        icon: const Icon(FluentIcons.print_24_regular),
                        label: const Text('Print'),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          backgroundColor: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: _writeToNFC,
                        icon: const Icon(FluentIcons.contact_card_24_regular),
                        label: const Text('Write NFC'),
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          backgroundColor: Colors.teal,
                        ),
                      ),
                    ],
                  ).animate().fade(delay: 300.ms).slideY(),
                  const SizedBox(height: 24),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

