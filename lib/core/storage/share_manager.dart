import 'package:shared_preferences/shared_preferences.dart';

const String kSelectedRoleKey = 'selected_role';
const String kPendingDeepLinkUriKey = 'pending_deep_link_uri';

class ShareManager {
  ShareManager._internal();
  static final ShareManager _instance = ShareManager._internal();
  factory ShareManager() => _instance;

  SharedPreferences? _prefs;

  Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  Future<void> saveString(String key, String value) async {
    final prefs = await _getPrefs();
    await prefs.setString(key, value);
  }

  Future<String?> getString(String key) async {
    final prefs = await _getPrefs();
    return prefs.getString(key);
  }

  Future<void> saveJson(String key, String value) async {
    final prefs = await _getPrefs();
    await prefs.setString(key, value);
  }

  Future<String?> getJson(String key) async {
    final prefs = await _getPrefs();
    return prefs.getString(key);
  }

  Future<void> saveBool(String key, bool value) async {
    final prefs = await _getPrefs();
    await prefs.setBool(key, value);
  }

  Future<bool?> getBool(String key) async {
    final prefs = await _getPrefs();
    return prefs.getBool(key);
  }

  Future<void> remove(String key) async {
    final prefs = await _getPrefs();
    await prefs.remove(key);
  }

  Future<void> clear() async {
    final prefs = await _getPrefs();
    await prefs.clear();
  }
}
