import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/network_device.dart';
import '../services/device_scanner_service.dart';

/// Lifecycle-aware provider for the "Who's on My Wi-Fi?" device scanner.
/// Pauses scanning when app is backgrounded, resumes when foregrounded.
class DeviceScannerProvider with ChangeNotifier, WidgetsBindingObserver {
  static const String _customNamesKey = 'device_custom_names';

  final DeviceScannerService _scannerService = DeviceScannerService();
  List<NetworkDevice> _devices = [];
  bool _isScanning = false;
  int _progress = 0;
  String? _errorMessage;
  StreamSubscription? _scanSubscription;
  Timer? _pollingTimer;
  Map<String, String> _customNames = {};

  List<NetworkDevice> get devices => _devices;
  bool get isScanning => _isScanning;
  int get progress => _progress;
  String? get errorMessage => _errorMessage;

  DeviceScannerProvider() {
    WidgetsBinding.instance.addObserver(this);
    _loadCustomNames();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _cancelScan();
      _pollingTimer?.cancel();
    }
  }

  /// Loads user-assigned custom device names from SharedPreferences.
  Future<void> _loadCustomNames() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_customNamesKey);
      if (raw != null) {
        final Map<String, dynamic> decoded = json.decode(raw);
        _customNames = decoded.map((k, v) => MapEntry(k, v.toString()));
      }
    } catch (_) {}
  }

  /// Saves custom device names.
  Future<void> _saveCustomNames() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_customNamesKey, json.encode(_customNames));
  }

  /// Assigns a custom name to a device by MAC address.
  Future<void> renameDevice(String macAddress, String name) async {
    _customNames[macAddress] = name;
    // Update existing device in the list
    for (final device in _devices) {
      if (device.macAddress == macAddress) {
        device.customName = name;
      }
    }
    await _saveCustomNames();
    notifyListeners();
  }

  /// Starts a full subnet scan.
  Future<void> startScan() async {
    if (_isScanning) return;

    _isScanning = true;
    _progress = 0;
    _errorMessage = null;
    _devices = [];
    notifyListeners();

    try {
      final stream = _scannerService.scanSubnet(
        onProgress: (p) {
          _progress = p;
          notifyListeners();
        },
      );

      _scanSubscription = stream.listen(
        (device) {
          // Apply any saved custom name
          if (device.macAddress != null && _customNames.containsKey(device.macAddress)) {
            device.customName = _customNames[device.macAddress!];
          }
          _devices.add(device);
          notifyListeners();
        },
        onDone: () {
          _isScanning = false;
          _progress = 100;
          notifyListeners();
        },
        onError: (error) {
          _errorMessage = 'Scan failed: $error';
          _isScanning = false;
          notifyListeners();
        },
      );
    } catch (e) {
      _errorMessage = 'Could not start scan. Make sure you are connected to Wi-Fi.';
      _isScanning = false;
      notifyListeners();
    }
  }

  void _cancelScan() {
    _scanSubscription?.cancel();
    _scanSubscription = null;
    if (_isScanning) {
      _isScanning = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _cancelScan();
    _pollingTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
