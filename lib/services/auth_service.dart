import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _refreshTokenKey = 'refresh_token';
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
} 