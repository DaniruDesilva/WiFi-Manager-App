import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/wifi_network.dart';
import '../utils/widget_helper.dart';

class HistoryProvider with ChangeNotifier {
  static const String _historyKey = 'wifi_history';
  List<WifiNetwork> _history = [];

  List<WifiNetwork> get history => _history;

  HistoryProvider() {
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? historyJson = prefs.getString(_historyKey);
    if (historyJson != null) {
      final List<dynamic> decodedList = json.decode(historyJson);
      _history = decodedList.map((item) => WifiNetwork.fromJson(item)).toList();
      _history.sort((a, b) => b.timestamp.compareTo(a.timestamp)); // Newest first
      notifyListeners();
      WidgetHelper.autoSyncLatestNetworkIfEmpty(_history);
    }
  }

  Future<void> addNetwork(WifiNetwork network) async {
    // Check if network with same SSID already exists, remove it if so
    _history.removeWhere((element) => element.ssid == network.ssid);
    _history.insert(0, network); // Add to the top
    await _saveHistory();
    notifyListeners();
    WidgetHelper.autoSyncLatestNetworkIfEmpty(_history);
  }

  Future<void> removeNetwork(WifiNetwork network) async {
    _history.removeWhere((element) => element.ssid == network.ssid && element.timestamp == network.timestamp);
    await _saveHistory();
    notifyListeners();
  }
  
  Future<void> clearHistory() async {
    _history.clear();
    await _saveHistory();
    notifyListeners();
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>> jsonList = _history.map((item) => item.toJson()).toList();
    await prefs.setString(_historyKey, json.encode(jsonList));
  }
}
