import 'dart:async';
import 'dart:io';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:network_tools/network_tools.dart';

import '../models/network_device.dart';
import 'device_fingerprint_service.dart';
import 'oui_lookup_service.dart';
import 'package:path_provider/path_provider.dart';

class DeviceScannerService {
  final OuiLookupService _ouiService = OuiLookupService.instance;

  String _cleanDeviceName(String name) {
    String cleaned = name.trim();
    final suffixes = ['.lan', '.local', '.home', '.guest'];
    for (final suffix in suffixes) {
      if (cleaned.toLowerCase().endsWith(suffix)) {
        cleaned = cleaned.substring(0, cleaned.length - suffix.length);
      }
    }
    return cleaned;
  }

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

    // 0. Pre-read the ARP table for MAC addresses (works on many Android devices)
    final arpTable = await DeviceFingerprintService.readArpTable();

    // 1. Kick off a fast NetBIOS sweep in parallel to find ping-blocking Windows machines
    final netbiosSweepFuture = DeviceFingerprintService.scanSubnetNetBIOS(subnet);

    // 2. Detect gateway IP
    await DeviceFingerprintService.detectGateway();

    // 3. Start the ICMP Ping sweep
    final stream = HostScannerService.instance.getAllPingableDevicesAsync(
      subnet,
      firstHostId: 1,
      lastHostId: 254,
      timeoutInSeconds: 1,
    );

    final Set<String> yieldedIps = {};

    await for (final host in stream) {
      yieldedIps.add(host.address);
      
      // Try to get MAC from network_tools first, then fall back to ARP table
      String? macAddress = await host.getMacAddress();
      if (macAddress == null || macAddress == '00:00:00:00:00:00') {
        macAddress = arpTable[host.address];
      }

      String? manufacturer;
      String? specificDeviceName;

      // Try to get specific device name from network_tools (mDNS/DNS)
      final dName = await host.deviceName;
      if (dName != 'Generic Device' && dName.isNotEmpty) {
        specificDeviceName = dName;
      }
      
      final hName = await host.hostName;
      if (hName != null && hName.isNotEmpty && hName != host.address) {
        specificDeviceName = hName;
      }

      // Explicitly try reverse DNS if the above didn't yield a good name
      if (specificDeviceName == null || specificDeviceName.contains('Generic')) {
        try {
          final reverse = await InternetAddress(host.address).reverse().timeout(const Duration(milliseconds: 500));
          if (reverse.host != host.address && reverse.host.isNotEmpty) {
            specificDeviceName = reverse.host;
          }
        } catch (_) {}
      }

      if (specificDeviceName != null) {
        specificDeviceName = _cleanDeviceName(specificDeviceName);
      }
      
      // Try OUI lookup with MAC address for manufacturer
      if (macAddress != null && macAddress.isNotEmpty) {
        manufacturer = _ouiService.lookupManufacturer(macAddress);
      }

      // Always get the device fingerprint (type or OS guess)
      final fingerprint = await DeviceFingerprintService.fingerprintIp(host.address);
      
      if (fingerprint != null) {
        // If we don't have a specific name but the fingerprint returned a specific NetBIOS or mDNS name
        if (manufacturer == null) {
          manufacturer = fingerprint;
        } else if (specificDeviceName == null && !fingerprint.contains('Device') && !fingerprint.contains('Router') && !fingerprint.contains('Gateway') && !fingerprint.contains('PC')) {
             specificDeviceName = _cleanDeviceName(fingerprint);
        }
      }

      yield NetworkDevice(
        ipAddress: host.address,
        macAddress: macAddress,
        manufacturer: manufacturer ?? fingerprint,
        deviceName: specificDeviceName,
      );
    }
    
    // 4. Re-read ARP table after ping sweep (new entries may have been added)
    final freshArp = await DeviceFingerprintService.readArpTable();
    
    // 5. Process the NetBIOS sweep results to find devices that ignored our pings
    final netbiosResults = await netbiosSweepFuture;
    for (final entry in netbiosResults.entries) {
      final netbiosIp = entry.key;
      final name = entry.value;
      if (!yieldedIps.contains(netbiosIp)) {
        yieldedIps.add(netbiosIp);
        final mac = freshArp[netbiosIp];
        yield NetworkDevice(
          ipAddress: netbiosIp,
          macAddress: mac,
          manufacturer: 'Windows PC',
          deviceName: _cleanDeviceName(name),
        );
      }
    }

    // 6. Final fallback: Any IP that is ALIVE in the ARP table but ignored EVERYTHING else (e.g., modern Windows blocking Ping + NetBIOS)
    for (final arpIp in freshArp.keys) {
      if (!yieldedIps.contains(arpIp) && arpIp != ip && !arpIp.endsWith('.255')) {
        yieldedIps.add(arpIp);
        
        final mac = freshArp[arpIp];
        String? manufacturer;
        if (mac != null && mac.isNotEmpty) {
          manufacturer = _ouiService.lookupManufacturer(mac);
        }
        
        // Quick fingerprint fallback
        final fingerprint = await DeviceFingerprintService.fingerprintIp(arpIp);
        
        // Try reverse DNS to get the PC name
        String? specificDeviceName;
        try {
          final reverse = await InternetAddress(arpIp).reverse().timeout(const Duration(milliseconds: 500));
          if (reverse.host != arpIp && reverse.host.isNotEmpty) {
            specificDeviceName = _cleanDeviceName(reverse.host);
          }
        } catch (_) {}
        
        yield NetworkDevice(
          ipAddress: arpIp,
          macAddress: mac,
          manufacturer: manufacturer ?? fingerprint,
          deviceName: specificDeviceName,
        );
      }
    }
    progressTimer.cancel();
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
