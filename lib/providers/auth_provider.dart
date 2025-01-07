import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../services/auth_service.dart';
import '../config/api_config.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService;
  String? _accessToken;
  bool _isAuthenticated = false;
  bool _isLoading = true;

  AuthProvider(this._authService) {
    _initializeAuth();
  }

  bool get isAuthenticated => _isAuthenticated;
  String? get accessToken => _accessToken;
  bool get isLoading => _isLoading;

  Future<void> _initializeAuth() async {
    final refreshToken = await _authService.getRefreshToken();
    if (refreshToken != null) {
      try {
        final response = await http.post(
          Uri.parse(ApiConfig.refreshTokenUrl),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'refreshToken': refreshToken}),
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          await setTokens(
            accessToken: data['accessToken'],
            refreshToken: data['refreshToken'],
          );
        } else {
          await logout();
        }
      } catch (e) {
        await logout();
      }
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> setTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _accessToken = accessToken;
    await _authService.saveRefreshToken(refreshToken);
    _isAuthenticated = true;
    notifyListeners();
  }

  Future<void> logout() async {
    _accessToken = null;
    await _authService.clearRefreshToken();
    _isAuthenticated = false;
    notifyListeners();
  }
} 