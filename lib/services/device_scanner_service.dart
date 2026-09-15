import 'dart:async';
import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:network_tools/network_tools.dart';
import 'package:wifi_scan/wifi_scan.dart';

import '../models/network_device.dart';
import 'device_fingerprint_service.dart';
import 'oui_lookup_service.dart';
import 'package:path_provider/path_provider.dart';

class DeviceScannerService {
  final OuiLookupService _ouiService = OuiLookupService.instance;

  /// Scans the local subnet for active devices.
  /// Yields devices as they are found.
  Stream<NetworkDevice> scanSubnet({
    void Function(int)? onProgress,
  }) async* {
    await _ouiService.loadDatabase();

    final appDocDir = await getApplicationDocumentsDirectory();
    await configureNetworkTools(appDocDir.path);

    final info = NetworkInfo();
    final ip = await info.getWifiIP();

    if (ip == null || ip.isEmpty) {
      return;
    }

    final parts = ip.split('.');
    if (parts.length != 4) return;
    final subnet = '${parts[0]}.${parts[1]}.${parts[2]}';

    Timer? progressTimer;
    int currentProgress = 0;
    progressTimer = Timer.periodic(const Duration(milliseconds: 30), (timer) {
      if (currentProgress < 95) {
        currentProgress += 2;
        onProgress?.call(currentProgress);
      }
    });

    final stream = HostScannerService.instance.getAllPingableDevicesAsync(
      subnet,
      firstHostId: 1,
      lastHostId: 254,
      timeoutInSeconds: 1,
    );

    await for (final host in stream) {
      final macAddress = await host.getMacAddress();
      String? manufacturer = macAddress != null ? _ouiService.lookupManufacturer(macAddress) : null;

      if (manufacturer == null) {
        // Fallback to advanced fingerprinting (mDNS, UPnP, TTL)
        final fingerprint = await DeviceFingerprintService.fingerprintIp(host.address);
        if (fingerprint != null) {
          manufacturer = fingerprint;
        } else {
          // Last resort: network_tools mDNS parsing
          final deviceName = await host.deviceName;
          if (deviceName != 'Generic Device' && deviceName.isNotEmpty) {
            manufacturer = deviceName;
          }
        }
      }

      yield NetworkDevice(
        ipAddress: host.address,
        macAddress: macAddress,
        manufacturer: manufacturer,
      );
    }

    progressTimer?.cancel();
    // Ensure we report 100% when done
    onProgress?.call(100);
  }

  /// Gets the current device's subnet string (e.g., "192.168.1").
  Future<String?> getCurrentSubnet() async {
    final info = NetworkInfo();
    final ip = await info.getWifiIP();
    if (ip == null || ip.isEmpty) return null;
    final parts = ip.split('.');
    if (parts.length != 4) return null;
    return '${parts[0]}.${parts[1]}.${parts[2]}';
  }
}
