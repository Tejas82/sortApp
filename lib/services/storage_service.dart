import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/action_item.dart';
import '../models/settings.dart';

/// On-device storage. Only extracted actions and message ids are kept,
/// never full email bodies (PRD: data minimisation).
class StorageService {
  static const _kActions = 'actions_v1';
  static const _kProcessed = 'processed_ids_v1';
  static const _kSettings = 'settings_v1';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  AppSettings loadSettings() {
    final raw = _prefs.getString(_kSettings);
    if (raw == null) return AppSettings();
    try {
      return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return AppSettings();
    }
  }

  Future<void> saveSettings(AppSettings s) =>
      _prefs.setString(_kSettings, jsonEncode(s.toJson()));

  List<ActionItem> loadActions() {
    final raw = _prefs.getString(_kActions);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => ActionItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveActions(List<ActionItem> items) =>
      _prefs.setString(_kActions, jsonEncode(items.map((e) => e.toJson()).toList()));

  Set<String> loadProcessedIds() =>
      (_prefs.getStringList(_kProcessed) ?? const []).toSet();

  Future<void> saveProcessedIds(Set<String> ids) =>
      _prefs.setStringList(_kProcessed, ids.toList());

  Future<void> clearAll() async {
    await _prefs.remove(_kActions);
    await _prefs.remove(_kProcessed);
    await _prefs.remove(_kSettings);
  }
}
