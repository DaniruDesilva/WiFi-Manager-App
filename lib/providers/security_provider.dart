import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Centralized provider for all authentication and app lock logic.
/// Manages custom PINs, biometric auth, and session unlock state.
class SecurityProvider with ChangeNotifier {
  static const String _historyPinKey = 'security_history_pin_hash';
  static const String _appPinKey = 'security_app_pin_hash';
  static const String _historyPinEnabledKey = 'security_history_pin_enabled';
  static const String _appPinEnabledKey = 'security_app_pin_enabled';

  final LocalAuthentication _localAuth = LocalAuthentication();
  static const MethodChannel _securityChannel = MethodChannel('com.example.wifi_qr_generator/security');

  // Session state — resets when app is killed
  bool _isHistoryUnlocked = false;
  bool _isAppUnlocked = false;

  // Settings state
  bool _historyPinEnabled = false;
  bool _appPinEnabled = false;
  String? _historyPinHash;
  String? _appPinHash;

  // Device capabilities
  bool _deviceHasSecurity = false;
  bool _deviceCapabilityChecked = false;
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;
  bool get isHistoryUnlocked => _isHistoryUnlocked;
  bool get isAppUnlocked => _isAppUnlocked;
  bool get historyPinEnabled => _historyPinEnabled;
  bool get appPinEnabled => _appPinEnabled;
  bool get deviceHasSecurity => _deviceHasSecurity;

  /// True if the user has enabled the App Lock PIN
  bool get appNeedsAuth => _appPinEnabled && _appPinHash != null;

  SecurityProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _historyPinEnabled = prefs.getBool(_historyPinEnabledKey) ?? false;
    _appPinEnabled = prefs.getBool(_appPinEnabledKey) ?? false;
    _historyPinHash = prefs.getString(_historyPinKey);
    _appPinHash = prefs.getString(_appPinKey);

    // Check device capabilities once
    await _checkDeviceSecurity();

    _isLoaded = true;
    notifyListeners();
  }

  Future<void> _checkDeviceSecurity() async {
    if (_deviceCapabilityChecked) return;
    try {
      final bool isSecure = await _securityChannel.invokeMethod('isDeviceSecure');
      _deviceHasSecurity = isSecure;
    } on PlatformException catch (e) {
      debugPrint("Failed to check device security: '${e.message}'. Falling back to local_auth.");
      try {
        final canCheckBiometrics = await _localAuth.canCheckBiometrics;
        final isDeviceSupported = await _localAuth.isDeviceSupported();
        _deviceHasSecurity = canCheckBiometrics || isDeviceSupported;
      } catch (e) {
        _deviceHasSecurity = false;
      }
    }
    _deviceCapabilityChecked = true;
  }

  // ---------------------------------------------------------------------------
  // Hash helpers
  // ---------------------------------------------------------------------------

  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    return sha256.convert(bytes).toString();
  }

  bool _verifyPin(String pin, String? storedHash) {
    if (storedHash == null) return false;
    return _hashPin(pin) == storedHash;
  }

  // ---------------------------------------------------------------------------
  // History Authentication
  // ---------------------------------------------------------------------------

  /// Smart authentication flow for the History tab.
  /// Returns 'unlocked', 'pin_required', or 'device_auth_required'.
  Future<String> authenticateForHistory() async {
    await _checkDeviceSecurity();

    // 1. Custom PIN is set → caller must show PIN dialog
    if (_historyPinEnabled && _historyPinHash != null) {
      return 'pin_required';
    }

    // 2. Device has biometrics/screen lock → use it
    if (_deviceHasSecurity) {
      return 'device_auth_required';
    }

    // 3. No security at all → auto-unlock
    _isHistoryUnlocked = true;
    notifyListeners();
    return 'unlocked';
  }

  /// Verify a PIN entered for History unlock.
  bool verifyHistoryPin(String pin) {
    if (_verifyPin(pin, _historyPinHash)) {
      _isHistoryUnlocked = true;
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Mark history as unlocked (after successful device auth).
  void unlockHistory() {
    _isHistoryUnlocked = true;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // App Authentication
  // ---------------------------------------------------------------------------

  /// Smart authentication flow for the App lock.
  /// Returns true if unlocked successfully (no PIN needed), false if PIN needed.
  Future<bool> authenticateForApp() async {
    if (!_appPinEnabled) {
      _isAppUnlocked = true;
      notifyListeners();
      return true;
    }

    // App PIN is set → caller must show PIN dialog
    return false;
  }

  /// Verify a PIN entered for App unlock.
  bool verifyAppPin(String pin) {
    if (_verifyPin(pin, _appPinHash)) {
      _isAppUnlocked = true;
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Mark app as unlocked.
  void unlockApp() {
    _isAppUnlocked = true;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Device Biometric/PIN Auth
  // ---------------------------------------------------------------------------

  /// Authenticate using device biometrics for History tab.
  Future<bool> authenticateWithDeviceForHistory() async {
    try {
      final stopwatch = Stopwatch()..start();
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Authenticate to view saved networks',
        biometricOnly: false,
      );
      stopwatch.stop();

      if (didAuthenticate) {
        _isHistoryUnlocked = true;
        notifyListeners();
        return true;
      } else {
        // Workaround for some Android devices (like MIUI) that return false instantly
        // instead of throwing a NotEnrolled exception when no screen lock is set.
        if (stopwatch.elapsedMilliseconds < 500) {
          debugPrint('Auth returned false instantly. Assuming no device security.');
          _deviceHasSecurity = false;
          _isHistoryUnlocked = true;
          notifyListeners();
          return true;
        }
        return false;
      }
    } on PlatformException catch (e) {
      debugPrint('Device auth error: $e');
      // If auth is broken/unavailable/not-enrolled, allow access
      _deviceHasSecurity = false;
      _isHistoryUnlocked = true;
      notifyListeners();
      return true;
    }
  }

  // ---------------------------------------------------------------------------
  // PIN Management
  // ---------------------------------------------------------------------------

  Future<void> setHistoryPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    _historyPinHash = _hashPin(pin);
    _historyPinEnabled = true;
    await prefs.setString(_historyPinKey, _historyPinHash!);
    await prefs.setBool(_historyPinEnabledKey, true);
    notifyListeners();
  }

  Future<void> removeHistoryPin() async {
    final prefs = await SharedPreferences.getInstance();
    _historyPinHash = null;
    _historyPinEnabled = false;
    await prefs.remove(_historyPinKey);
    await prefs.setBool(_historyPinEnabledKey, false);
    notifyListeners();
  }

  Future<void> setAppPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    _appPinHash = _hashPin(pin);
    _appPinEnabled = true;
    await prefs.setString(_appPinKey, _appPinHash!);
    await prefs.setBool(_appPinEnabledKey, true);
    notifyListeners();
  }

  Future<void> removeAppPin() async {
    final prefs = await SharedPreferences.getInstance();
    _appPinHash = null;
    _appPinEnabled = false;
    _isAppUnlocked = true; // No lock anymore
    await prefs.remove(_appPinKey);
    await prefs.setBool(_appPinEnabledKey, false);
    notifyListeners();
  }
}
