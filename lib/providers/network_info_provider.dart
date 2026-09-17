import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/network_info_service.dart';

/// Provider for the Network Information Dashboard.
class NetworkInfoProvider with ChangeNotifier {
  final NetworkInfoService _service = NetworkInfoService();

  String? _localIp;
  String? _publicIp;
  String? _gatewayIp;
  String? _subnetMask;
  String? _broadcast;
  String? _wifiName;
  bool _isOnline = false;
  bool _isLoading = false;

  String? get localIp => _localIp;
  String? get publicIp => _publicIp;
  String? get gatewayIp => _gatewayIp;
  String? get subnetMask => _subnetMask;
  String? get broadcast => _broadcast;
  String? get wifiName => _wifiName;
  bool get isOnline => _isOnline;
  bool get isLoading => _isLoading;

  NetworkInfoProvider() {
    refresh();
  }

  /// Refreshes all network information.
  /// If [isManual] is true, it will request location permissions if needed.
  Future<void> refresh({bool isManual = false}) async {
    _isLoading = true;
    notifyListeners();

    try {
      // For Wi-Fi name (SSID), Android requires Location permission.
      if (isManual) {
        final status = await Permission.locationWhenInUse.status;
        if (!status.isGranted) {
          await Permission.locationWhenInUse.request();
        }
      }

      // Fetch fast local info first
      _localIp = await _service.getLocalIp();
      _gatewayIp = await _service.getGatewayIp();
      _subnetMask = await _service.getSubnetMask();
      _broadcast = await _service.getBroadcast();
      
      String? name = await _service.getWifiName();
      if (name == '<unknown ssid>') name = null;
      _wifiName = name;
      
      // Update UI immediately for fast local addresses
      notifyListeners();

      // Fetch slower external info in parallel
      final externalResults = await Future.wait([
        _service.getPublicIp(),
        _service.checkInternetConnectivity(),
      ]);

      _publicIp = externalResults[0] as String?;
      _isOnline = externalResults[1] as bool;
    } catch (_) {
      // Keep whatever we have
    }

    _isLoading = false;
    notifyListeners();
  }
}
