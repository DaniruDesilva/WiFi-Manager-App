import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// Singleton service that loads and queries the OUI (MAC vendor) database.
class OuiLookupService {
  static OuiLookupService? _instance;
  Map<String, String> _ouiMap = {};
  bool _isLoaded = false;

  OuiLookupService._();

  static OuiLookupService get instance {
    _instance ??= OuiLookupService._();
    return _instance!;
  }

  /// Loads the OUI database from bundled assets. Safe to call multiple times.
  Future<void> loadDatabase() async {
    if (_isLoaded) return;
    try {
      final jsonString = await rootBundle.loadString('assets/oui_database.json');
      final Map<String, dynamic> raw = json.decode(jsonString);
      _ouiMap = raw.map((key, value) => MapEntry(key.toUpperCase(), value.toString()));
      _isLoaded = true;
    } catch (e) {
      // Silently fail — lookups will return null
      _ouiMap = {};
    }
  }

  /// Looks up the manufacturer for a given MAC address.
  /// [macAddress] can be in formats like "AA:BB:CC:DD:EE:FF" or "AA-BB-CC-DD-EE-FF".
  /// Returns null if the OUI prefix is not found.
  String? lookupManufacturer(String? macAddress) {
    if (macAddress == null || macAddress.isEmpty) return null;

    // Normalize separators
    final normalized = macAddress.toUpperCase().replaceAll('-', ':');

    // Extract the first 3 octets (OUI prefix)
    final parts = normalized.split(':');
    if (parts.length < 3) return null;

    final prefix = '${parts[0]}:${parts[1]}:${parts[2]}';
    return _ouiMap[prefix];
  }
}
