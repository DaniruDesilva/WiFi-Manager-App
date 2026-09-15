/// Data model wrapping a nearby Wi-Fi access point from wifi_scan results.
class WifiAccessPointModel {
  final String ssid;
  final String bssid;
  final int rssi;
  final int frequency; // MHz

  WifiAccessPointModel({
    required this.ssid,
    required this.bssid,
    required this.rssi,
    required this.frequency,
  });

  /// Returns '2.4 GHz', '5 GHz', or '6 GHz' based on frequency.
  String get band {
    if (frequency < 3000) return '2.4 GHz';
    if (frequency < 5900) return '5 GHz';
    return '6 GHz';
  }

  /// Calculates the Wi-Fi channel from the frequency in MHz.
  int get channel {
    // 2.4 GHz band
    if (frequency >= 2412 && frequency <= 2484) {
      if (frequency == 2484) return 14;
      return ((frequency - 2412) ~/ 5) + 1;
    }
    // 5 GHz band
    if (frequency >= 5170 && frequency <= 5825) {
      return ((frequency - 5170) ~/ 5) + 34;
    }
    // 6 GHz band (Wi-Fi 6E)
    if (frequency >= 5955 && frequency <= 7115) {
      return ((frequency - 5955) ~/ 5) + 1;
    }
    return 0;
  }

  /// Normalized signal percentage (0-100) from RSSI dBm.
  /// -30 dBm = 100%, -90 dBm = 0%
  double get signalPercent {
    if (rssi >= -30) return 100.0;
    if (rssi <= -90) return 0.0;
    return ((rssi + 90) / 60.0) * 100.0;
  }

  /// Human-readable signal quality label.
  String get signalQuality {
    if (rssi >= -50) return 'Excellent';
    if (rssi >= -60) return 'Good';
    if (rssi >= -70) return 'Fair';
    return 'Weak';
  }
}
