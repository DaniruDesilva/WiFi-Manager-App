import 'dart:async';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:network_tools/network_tools.dart';
import '../models/network_device.dart';
import 'oui_lookup_service.dart';

/// Service that wraps network_tools to perform subnet device discovery.
class DeviceScannerService {
  final OuiLookupService _ouiService = OuiLookupService.instance;

  /// Scans the local subnet for connected devices.
  /// Returns a stream of discovered [NetworkDevice] objects.
  /// [onProgress] callback reports progress from 0 to 100.
  Stream<NetworkDevice> scanSubnet({
    void Function(int progress)? onProgress,
  }) async* {
    await _ouiService.loadDatabase();

    final info = NetworkInfo();
    final ip = await info.getWifiIP();

    if (ip == null || ip.isEmpty) {
      return;
    }

    // Extract subnet base (e.g., "192.168.1" from "192.168.1.15")
    final parts = ip.split('.');
    if (parts.length != 4) return;
    final subnet = '${parts[0]}.${parts[1]}.${parts[2]}';

    int scannedCount = 0;

    final stream = HostScannerService.instance.getAllPingableDevices(
      subnet,
      firstHostId: 1,
      lastHostId: 254,
      timeoutInSeconds: 1,
    );

    await for (final host in stream) {
      scannedCount++;
      onProgress?.call(((scannedCount / 254) * 100).round().clamp(0, 100));

      final macAddress = host.hostId;
      final manufacturer = _ouiService.lookupManufacturer(macAddress);

      yield NetworkDevice(
        ipAddress: host.address,
        macAddress: macAddress,
        manufacturer: manufacturer,
      );
    }

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
