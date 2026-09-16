import 'package:flutter/material.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

class NetworkDevice {
  final String ipAddress;
  final String? macAddress;
  final String? manufacturer;
  final String? deviceName; // The specific host name (e.g., HONOR-X9c-Smart)
  String? customName;
  final DateTime discoveredAt;

  NetworkDevice({
    required this.ipAddress,
    this.macAddress,
    this.manufacturer,
    this.deviceName,
    this.customName,
    DateTime? discoveredAt,
  }) : discoveredAt = discoveredAt ?? DateTime.now();

  /// Returns an appropriate icon based on the manufacturer name.
  IconData get deviceIcon {
    final mfr = (manufacturer ?? '').toLowerCase();
    if (mfr.contains('apple')) return FluentIcons.phone_24_regular;
    if (mfr.contains('samsung')) return FluentIcons.phone_24_regular;
    if (mfr.contains('xiaomi')) return FluentIcons.phone_24_regular;
    if (mfr.contains('oneplus')) return FluentIcons.phone_24_regular;
    if (mfr.contains('oppo')) return FluentIcons.phone_24_regular;
    if (mfr.contains('vivo')) return FluentIcons.phone_24_regular;
    if (mfr.contains('google')) return FluentIcons.home_24_regular;
    if (mfr.contains('amazon')) return FluentIcons.speaker_2_24_regular;
    if (mfr.contains('sonos')) return FluentIcons.speaker_2_24_regular;
    if (mfr.contains('nest')) return FluentIcons.home_24_regular;
    if (mfr.contains('philips')) return FluentIcons.lightbulb_24_regular;
    if (mfr.contains('sony')) return FluentIcons.tv_24_regular;
    if (mfr.contains('lg')) return FluentIcons.tv_24_regular;
    if (mfr.contains('roku')) return FluentIcons.tv_24_regular;
    if (mfr.contains('raspberry')) return FluentIcons.developer_board_24_regular;
    if (mfr.contains('espressif') || mfr.contains('esp')) return FluentIcons.developer_board_24_regular;
    if (mfr.contains('tuya')) return FluentIcons.home_24_regular;
    if (mfr.contains('dell') || mfr.contains('hp') || mfr.contains('hewlett') || mfr.contains('lenovo')) return FluentIcons.laptop_24_regular;
    if (mfr.contains('intel')) return FluentIcons.laptop_24_regular;
    if (mfr.contains('microsoft')) return FluentIcons.laptop_24_regular;
    if (mfr.contains('vmware')) return FluentIcons.server_24_regular;
    if (mfr.contains('cisco')) return FluentIcons.router_24_regular;
    if (mfr.contains('netgear')) return FluentIcons.router_24_regular;
    if (mfr.contains('tp-link')) return FluentIcons.router_24_regular;
    if (mfr.contains('asus')) return FluentIcons.router_24_regular;
    if (mfr.contains('d-link')) return FluentIcons.router_24_regular;
    if (mfr.contains('ubiquiti')) return FluentIcons.router_24_regular;
    if (mfr.contains('linksys') || mfr.contains('belkin')) return FluentIcons.router_24_regular;
    if (mfr.contains('huawei')) return FluentIcons.router_24_regular;
    if (mfr.contains('zte')) return FluentIcons.router_24_regular;
    if (mfr.contains('nvidia')) return FluentIcons.desktop_24_regular;
    if (mfr.contains('western digital')) return FluentIcons.hard_drive_24_regular;
    return FluentIcons.device_eq_24_regular;
  }

  /// Returns a display name: custom name > device name > manufacturer > "Unknown Device"
  String get displayName => customName ?? deviceName ?? manufacturer ?? 'Unknown Device';

  Map<String, dynamic> toJson() => {
    'ipAddress': ipAddress,
    'macAddress': macAddress,
    'manufacturer': manufacturer,
    'deviceName': deviceName,
    'customName': customName,
    'discoveredAt': discoveredAt.toIso8601String(),
  };

  factory NetworkDevice.fromJson(Map<String, dynamic> json) {
    return NetworkDevice(
      ipAddress: json['ipAddress'] ?? '',
      macAddress: json['macAddress'],
      manufacturer: json['manufacturer'],
      deviceName: json['deviceName'],
      customName: json['customName'],
      discoveredAt: json['discoveredAt'] != null ? DateTime.parse(json['discoveredAt']) : null,
    );
  }
}
