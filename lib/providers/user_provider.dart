import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';

class User {
  final String id;
  final String username;
  final String email;
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.createdAt,
    required this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}

class UserProvider extends ChangeNotifier {
  User? _currentUser;
  bool _isLoading = false;
  String? _error;

  User? get currentUser => _currentUser;
  String? get userId => _currentUser?.id;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchCurrentUser(String accessToken) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/users/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _currentUser = User.fromJson(data);
      } else {
        final error = json.decode(response.body);
        _error = error['error'] ?? 'Failed to fetch user profile';
      }
    } catch (e) {
      _error = 'Network error occurred';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setCurrentUser(Map<String, dynamic> userData) {
    _currentUser = User.fromJson(userData);
    notifyListeners();
  }

  void clearCurrentUser() {
    _currentUser = null;
    _error = null;
    notifyListeners();
  }
} 