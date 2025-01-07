import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../config/api_config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'user_provider.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  String? _accessToken;
  bool _isAuthenticated = false;
  bool _isLoading = true;
  User? _currentUser;

  AuthProvider(this._authService) {
    _checkAuthStatus();
  }

  String? get accessToken => _accessToken;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  User? get currentUser => _currentUser;

  Future<void> _checkAuthStatus() async {
    _isLoading = true;
    notifyListeners();

    try {
      final refreshToken = await _authService.getRefreshToken();
      final userData = await _authService.getUserData();
      
      if (refreshToken != null && userData != null) {
        _currentUser = User.fromJson(userData);
        await _refreshAccessToken(refreshToken);
      }
    } catch (e) {
      print('Error checking auth status: $e');
      _isAuthenticated = false;
      _accessToken = null;
      _currentUser = null;
      await _authService.clearAll();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> setTokens({
    required String accessToken,
    required String refreshToken,
    required Map<String, dynamic> userData,
  }) async {
    await _authService.saveRefreshToken(refreshToken);
    await _authService.saveUserData(userData);
    _accessToken = accessToken;
    _currentUser = User.fromJson(userData);
    _isAuthenticated = true;
    notifyListeners();
  }

  Future<void> _refreshAccessToken(String refreshToken) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'refreshToken': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _accessToken = data['accessToken'];
        await _authService.saveRefreshToken(data['refreshToken']);
        _isAuthenticated = true;
      } else {
        _isAuthenticated = false;
        _accessToken = null;
        _currentUser = null;
        await _authService.clearAll();
      }
    } catch (e) {
      _isAuthenticated = false;
      _accessToken = null;
      _currentUser = null;
      await _authService.clearAll();
    }
  }

  Future<void> logout() async {
    _accessToken = null;
    _isAuthenticated = false;
    _currentUser = null;
    await _authService.clearAll();
    notifyListeners();
  }
} 