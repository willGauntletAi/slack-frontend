import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../config/api_config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'websocket_provider.dart';

class User {
  final String id;
  final String username;
  final String email;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  User({
    required this.id,
    required this.username,
    required this.email,
    this.createdAt,
    this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    String? createdAtStr = json['created_at'] ?? json['createdAt'];
    String? updatedAtStr = json['updated_at'] ?? json['updatedAt'];

    return User(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      createdAt: createdAtStr != null ? DateTime.parse(createdAtStr) : null,
      updatedAt: updatedAtStr != null ? DateTime.parse(updatedAtStr) : null,
    );
  }
}

class AuthProvider with ChangeNotifier {
  final AuthService _authService;
  final WebSocketProvider _wsProvider;
  String? _accessToken;
  bool _isAuthenticated = false;
  bool _isLoading = true;
  User? _currentUser;
  bool _isInitialized = false;

  AuthProvider({
    required AuthService authService,
    required WebSocketProvider wsProvider,
  })  : _authService = authService,
        _wsProvider = wsProvider;

  String? get accessToken => _accessToken;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading || !_isInitialized;
  User? get currentUser => _currentUser;

  Future<void> initialize() async {
    if (_isInitialized) return;
    await _checkAuthStatus();
    _isInitialized = true;
  }

  Future<void> _checkAuthStatus() async {
    if (!_isLoading) {
      _isLoading = true;
      notifyListeners();
    }

    try {
      debugPrint('🔑 Auth: Checking auth status...');
      final refreshToken = await _authService.getRefreshToken();
      final userData = await _authService.getUserData();
      debugPrint(
          '🔑 Auth: Found refresh token: ${refreshToken != null}, user data: ${userData != null}');

      if (refreshToken != null && userData != null) {
        _currentUser = User.fromJson(userData);
        await _refreshAccessToken(refreshToken);
        debugPrint(
            '🔑 Auth: Refresh successful - isAuthenticated: $_isAuthenticated');
      } else {
        _isAuthenticated = false;
        _accessToken = null;
        _currentUser = null;
        debugPrint('🔑 Auth: No stored credentials found');
      }
    } catch (e) {
      debugPrint('❌ Auth: Error checking auth status - $e');
      _isAuthenticated = false;
      _accessToken = null;
      _currentUser = null;
      await _authService.clearAll();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> attemptTokenRefresh() async {
    try {
      await _checkAuthStatus();
      return _isAuthenticated && _accessToken != null;
    } catch (e) {
      return false;
    }
  }

  Future<void> setTokens({
    required String accessToken,
    required String refreshToken,
    required Map<String, dynamic> userData,
  }) async {
    debugPrint('🔑 Auth: Setting tokens and user data');

    try {
      await _authService.saveRefreshToken(refreshToken);
      await _authService.saveUserData(userData);
      _accessToken = accessToken;
      _currentUser = User.fromJson(userData);
      _isAuthenticated = true;
      await _wsProvider.connect(accessToken);
      debugPrint('✅ Auth: Successfully set tokens and user data');
    } catch (e, stackTrace) {
      debugPrint('❌ Auth: Error setting tokens - $e');
      if (e is! FormatException) {
        debugPrint('Stack trace: $stackTrace');
      }
      rethrow;
    }
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
        await _wsProvider.connect(data['accessToken']);
      } else {
        _isAuthenticated = false;
        _accessToken = null;
        _currentUser = null;
        await _authService.clearAll();
        _wsProvider.disconnect();
      }
    } catch (e) {
      _isAuthenticated = false;
      _accessToken = null;
      _currentUser = null;
      await _authService.clearAll();
      _wsProvider.disconnect();
    }
  }

  Future<void> logout() async {
    _wsProvider.disconnect();
    _accessToken = null;
    _isAuthenticated = false;
    _currentUser = null;
    await _authService.clearAll();
    notifyListeners();
  }
}
