import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class AuthService {
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userDataKey = 'user_data';
  final SharedPreferences _prefs;

  AuthService(this._prefs);

  Future<void> saveRefreshToken(String token) async {
    await _prefs.setString(_refreshTokenKey, token);
  }

  Future<String?> getRefreshToken() async {
    return _prefs.getString(_refreshTokenKey);
  }

  Future<void> clearRefreshToken() async {
    await _prefs.remove(_refreshTokenKey);
  }

  Future<void> saveUserData(Map<String, dynamic> userData) async {
    await _prefs.setString(_userDataKey, json.encode(userData));
  }

  Future<Map<String, dynamic>?> getUserData() async {
    final userDataString = _prefs.getString(_userDataKey);
    if (userDataString != null) {
      return json.decode(userDataString);
    }
    return null;
  }

  Future<void> clearUserData() async {
    await _prefs.remove(_userDataKey);
  }

  Future<void> clearAll() async {
    await clearRefreshToken();
    await clearUserData();
  }
}
