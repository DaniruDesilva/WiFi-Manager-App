import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:wifi_scan/wifi_scan.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/wifi_access_point.dart';
import '../services/network_info_service.dart';

/// Lifecycle-aware provider for the Wi-Fi Analyzer feature.
/// Scans nearby Wi-Fi access points for signal strength and channel analysis.
class WifiAnalyzerProvider with ChangeNotifier, WidgetsBindingObserver {
  List<WifiAccessPointModel> _accessPoints = [];
  WifiAccessPointModel? _connectedNetwork;
  bool _isScanning = false;
  bool _isSupported = true;
  String? _errorMessage;
  Timer? _scanTimer;
  final NetworkInfoService _networkInfoService = NetworkInfoService();

  List<WifiAccessPointModel> get accessPoints => _accessPoints;
  WifiAccessPointModel? get connectedNetwork => _connectedNetwork;
  bool get isScanning => _isScanning;
  bool get isSupported => _isSupported;
  String? get errorMessage => _errorMessage;

  /// Access points filtered by band.
  List<WifiAccessPointModel> getByBand(String band) {
    return _accessPoints.where((ap) => ap.band == band).toList();
  }

  StreamSubscription? _resultsSubscription;

  WifiAnalyzerProvider() {
    WidgetsBinding.instance.addObserver(this);
    _checkPlatformSupport();
    _resultsSubscription = WiFiScan.instance.onScannedResultsAvailable.listen((_) {
      _fetchResults();
    });
  }

  void _checkPlatformSupport() {
    if (!Platform.isAndroid) {
      _isSupported = false;
      _errorMessage = 'Wi-Fi scanning is only available on Android.';
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      stopScanning();
    }
  }

  /// Starts periodic Wi-Fi scanning (every 5 seconds).
  Future<void> startScanning() async {
    if (!_isSupported || _isScanning) return;

    // Run initial scan immediately
    await _performScan();

    // Then scan every 30 seconds to avoid Android throttling (max 4 per 2 mins)
    _scanTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _performScan();
    });
  }

  /// Forces an immediate scan (for pull-to-refresh).
  /// Returns an error message if the scan is throttled, null otherwise.
  Future<String?> forceScan() async {
    if (!_isSupported) return null;

    final canScan = await WiFiScan.instance.canStartScan();
    if (canScan == CanStartScan.failed) {
      return 'Android restricts Wi-Fi scans to 4 per 2 minutes. Please wait a moment.';
    }

    await _performScan();
    // Wait for a bit so the RefreshIndicator spins, and the scan actually completes
    await Future.delayed(const Duration(seconds: 2));
    await _fetchResults();
    
    // Restart timer to avoid immediate double-scan
    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _performScan();
    });
    
    return null;
  }

  Future<void> _performScan() async {
    try {
      _isScanning = true;
      _errorMessage = null;
      notifyListeners();

      // Check location service status
      final serviceStatus = await Permission.locationWhenInUse.serviceStatus;
      if (!serviceStatus.isEnabled) {
        _errorMessage = 'Location Services are disabled. Please turn on Location/GPS to scan Wi-Fi.';
        return;
      }

      // Request location permission
      final locationStatus = await Permission.locationWhenInUse.request();
      if (!locationStatus.isGranted) {
        _errorMessage = 'Location permission is required to scan Wi-Fi networks.';
        return;
      }

      // Check if we can start a scan
      final canScan = await WiFiScan.instance.canStartScan();
      if (canScan != CanStartScan.yes) {
        if (canScan == CanStartScan.failed) {
          _errorMessage = 'Scan throttled by Android. Please wait a moment.';
        } else {
          _errorMessage = 'Cannot scan Wi-Fi. (Status: ${canScan.name}).';
        }
        return;
      }

      await WiFiScan.instance.startScan();
      // Notice: we do not immediately fetch results here anymore.
      // We rely on the stream _resultsSubscription or forceScan delay.
    } catch (e) {
      _errorMessage = 'Scan error: $e';
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  Future<void> _fetchResults() async {
    try {
      final canGetResults = await WiFiScan.instance.canGetScannedResults();
      if (canGetResults != CanGetScannedResults.yes) {
        return;
      }

      final results = await WiFiScan.instance.getScannedResults();

      _accessPoints = results.map((ap) {
        return WifiAccessPointModel(
          ssid: ap.ssid.isNotEmpty ? ap.ssid : '(Hidden Network)',
          bssid: ap.bssid,
          rssi: ap.level,
          frequency: ap.frequency,
        );
      }).toList();

      // Sort by signal strength (strongest first)
      _accessPoints.sort((a, b) => b.rssi.compareTo(a.rssi));

      // Accurately determine connected network
      final connectedBssid = await _networkInfoService.getWifiBSSID();
      final connectedSsid = await _networkInfoService.getWifiName();

      _connectedNetwork = null;
      if (_accessPoints.isNotEmpty) {
        if (connectedBssid != null && connectedBssid.isNotEmpty) {
          try {
            _connectedNetwork = _accessPoints.firstWhere((ap) => ap.bssid.toLowerCase() == connectedBssid.toLowerCase());
          } catch (_) {}
        }
        
        if (_connectedNetwork == null && connectedSsid != null && connectedSsid.isNotEmpty) {
           try {
            _connectedNetwork = _accessPoints.firstWhere((ap) => ap.ssid == connectedSsid);
          } catch (_) {}
        }
        
        // Fallback to strongest if we still don't know, though less accurate.
        if (_connectedNetwork == null) {
          _connectedNetwork = _accessPoints.first;
        }
      }
      notifyListeners();
    } catch (e) {
      _errorMessage = 'Failed to fetch results: $e';
      notifyListeners();
    }
  }

  /// Stops periodic scanning.
  void stopScanning() {
    _scanTimer?.cancel();
    _scanTimer = null;
    if (_isScanning) {
      _isScanning = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    stopScanning();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
