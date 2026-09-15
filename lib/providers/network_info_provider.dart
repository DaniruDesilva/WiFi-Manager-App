import 'package:flutter/material.dart';
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
  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Run all queries in parallel
      final results = await Future.wait([
        _service.getLocalIp(),
        _service.getGatewayIp(),
        _service.getSubnetMask(),
        _service.getBroadcast(),
        _service.getWifiName(),
        _service.getPublicIp(),
        _service.checkInternetConnectivity(),
      ]);

      _localIp = results[0] as String?;
      _gatewayIp = results[1] as String?;
      _subnetMask = results[2] as String?;
      _broadcast = results[3] as String?;
      _wifiName = results[4] as String?;
      _publicIp = results[5] as String?;
      _isOnline = results[6] as bool;
    } catch (_) {
      // Keep whatever we have
    }

    _isLoading = false;
    notifyListeners();
  }
}
