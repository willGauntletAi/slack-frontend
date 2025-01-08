import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';

class WorkspaceUser {
  final String id;
  final String username;
  final String email;
  final DateTime joinedAt;

  WorkspaceUser({
    required this.id,
    required this.username,
    required this.email,
    required this.joinedAt,
  });

  factory WorkspaceUser.fromJson(Map<String, dynamic> json) {
    return WorkspaceUser(
      id: json['id'],
      username: json['username'],
      email: json['email'],
      joinedAt: DateTime.parse(json['joined_at']),
    );
  }
}

class WorkspaceUsersProvider with ChangeNotifier {
  final Map<String, List<WorkspaceUser>> _workspaceUsers = {};
  final Map<String, bool> _isLoading = {};
  final Map<String, String?> _errors = {};

  List<WorkspaceUser> getWorkspaceUsers(String workspaceId) =>
      _workspaceUsers[workspaceId] ?? [];
  bool isLoading(String workspaceId) => _isLoading[workspaceId] ?? false;
  String? getError(String workspaceId) => _errors[workspaceId];

  Future<List<WorkspaceUser>> fetchWorkspaceUsers(
      String accessToken, String workspaceId) async {
    if (_isLoading[workspaceId] == true) {
      return _workspaceUsers[workspaceId] ?? [];
    }

    _isLoading[workspaceId] = true;
    _errors[workspaceId] = null;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/user/workspace/$workspaceId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final users = data.map((json) => WorkspaceUser.fromJson(json)).toList();
        _workspaceUsers[workspaceId] = users;
        _errors[workspaceId] = null;
        notifyListeners();
        return users;
      } else {
        final error = json.decode(response.body);
        _errors[workspaceId] =
            error['error'] ?? 'Failed to fetch workspace users';
        notifyListeners();
        return [];
      }
    } catch (e) {
      _errors[workspaceId] = 'Network error occurred';
      notifyListeners();
      return [];
    } finally {
      _isLoading[workspaceId] = false;
      notifyListeners();
    }
  }

  void clearWorkspace(String workspaceId) {
    _workspaceUsers.remove(workspaceId);
    _isLoading.remove(workspaceId);
    _errors.remove(workspaceId);
    notifyListeners();
  }

  void clearAll() {
    _workspaceUsers.clear();
    _isLoading.clear();
    _errors.clear();
    notifyListeners();
  }
}
