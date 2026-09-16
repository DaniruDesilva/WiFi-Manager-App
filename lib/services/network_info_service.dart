import 'package:network_info_plus/network_info_plus.dart';
import 'package:http/http.dart' as http;

/// Centralizes all network information gathering.
class NetworkInfoService {
  final NetworkInfo _networkInfo = NetworkInfo();

  /// Returns the local (internal) IP address.
  Future<String?> getLocalIp() async {
    return await _networkInfo.getWifiIP();
  }

  /// Returns the gateway (router) IP address.
  Future<String?> getGatewayIp() async {
    return await _networkInfo.getWifiGatewayIP();
  }

  /// Returns the subnet mask.
  Future<String?> getSubnetMask() async {
    return await _networkInfo.getWifiSubmask();
  }

  /// Returns the broadcast address.
  Future<String?> getBroadcast() async {
    return await _networkInfo.getWifiBroadcast();
  }

  /// Returns the current Wi-Fi name (SSID).
  Future<String?> getWifiName() async {
    String? name = await _networkInfo.getWifiName();
    if (name != null && name.startsWith('"') && name.endsWith('"')) {
      name = name.substring(1, name.length - 1);
    }
    return name;
  }

  /// Returns the current Wi-Fi BSSID (MAC address).
  Future<String?> getWifiBSSID() async {
    return await _networkInfo.getWifiBSSID();
  }

  /// Fetches the public (external) IP address via ipify.org.
  Future<String?> getPublicIp() async {
    try {
      final response = await http
          .get(Uri.parse('https://api.ipify.org'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return response.body.trim();
      }
    } catch (_) {
      // No internet or timeout
    }
    return null;
  }

  /// Checks if the device can reach the internet.
  Future<bool> checkInternetConnectivity() async {
    try {
      final response = await http
          .get(Uri.parse('https://www.google.com'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
