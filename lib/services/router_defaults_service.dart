import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/router_credential.dart';

/// Service that loads and queries the bundled default router password database.
class RouterDefaultsService {
  static RouterDefaultsService? _instance;
  List<RouterCredential> _credentials = [];
  bool _isLoaded = false;

  RouterDefaultsService._();

  static RouterDefaultsService get instance {
    _instance ??= RouterDefaultsService._();
    return _instance!;
  }

  /// Loads the router defaults database from bundled assets.
  Future<void> loadDatabase() async {
    if (_isLoaded) return;
    try {
      final jsonString = await rootBundle.loadString('assets/router_defaults.json');
      final List<dynamic> raw = json.decode(jsonString);
      _credentials = raw.map((e) => RouterCredential.fromJson(e)).toList();
      _isLoaded = true;
    } catch (e) {
      _credentials = [];
    }
  }

  /// Returns all router credentials.
  List<RouterCredential> getAll() => List.unmodifiable(_credentials);

  /// Searches credentials by brand or model name (case-insensitive).
  List<RouterCredential> search(String query) {
    if (query.trim().isEmpty) return getAll();
    final q = query.toLowerCase();
    return _credentials.where((cred) {
      return cred.brand.toLowerCase().contains(q) ||
          cred.models.any((m) => m.toLowerCase().contains(q));
    }).toList();
  }
}
