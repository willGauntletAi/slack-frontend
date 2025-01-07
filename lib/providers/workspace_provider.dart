import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';

class Workspace {
  final String id;
  final String name;
  final String role;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isInvited;

  Workspace({
    required this.id,
    required this.name,
    required this.role,
    required this.createdAt,
    required this.updatedAt,
    this.isInvited = false,
  });

  factory Workspace.fromJson(Map<String, dynamic> json) {
    return Workspace(
      id: json['id'],
      name: json['name'],
      role: json['role'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      isInvited: json['role'] == 'invited',
    );
  }
}

class WorkspaceProvider with ChangeNotifier {
  List<Workspace> _workspaces = [];
  Workspace? _selectedWorkspace;
  bool _isLoading = false;
  String? _error;

  List<Workspace> get workspaces => _workspaces;
  Workspace? get selectedWorkspace => _selectedWorkspace;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchWorkspaces(String accessToken) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/workspace'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _workspaces = data.map((json) => Workspace.fromJson(json)).toList();
        
        // Select the first workspace if none is selected
        if (_selectedWorkspace == null && _workspaces.isNotEmpty) {
          _selectedWorkspace = _workspaces.first;
        }
      } else {
        _error = 'Failed to load workspaces';
      }
    } catch (e) {
      _error = 'Network error occurred';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createWorkspace(String accessToken, String name) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/workspace'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: json.encode({'name': name}),
      );

      if (response.statusCode == 201) {
        // Refresh the workspace list
        await fetchWorkspaces(accessToken);
      } else {
        _error = 'Failed to create workspace';
      }
    } catch (e) {
      _error = 'Network error occurred';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectWorkspace(Workspace workspace) {
    _selectedWorkspace = workspace;
    notifyListeners();
  }

  Future<bool> inviteUser(String token, String workspaceId, String email) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/workspace/$workspaceId/invite'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'email': email,
        }),
      );

      if (response.statusCode == 200) {
        _error = null;
        return true;
      } else {
        final error = json.decode(response.body);
        _error = error['error'] ?? 'Failed to send invitation';
        notifyListeners();
        _error = null;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Network error occurred';
      notifyListeners();
      _error = null;
      notifyListeners();
      return false;
    }
  }

  Future<bool> acceptInvite(String token, String workspaceId) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/workspace/$workspaceId/accept'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        // Refresh the workspace list to update the workspace's status
        await fetchWorkspaces(token);
        _error = null;
        _selectedWorkspace = _workspaces.firstWhere((workspace) => workspace.id == workspaceId);
        return true;
      } else {
        final error = json.decode(response.body);
        _error = error['error'] ?? 'Failed to accept invitation';
        notifyListeners();
        _error = null;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Network error occurred';
      notifyListeners();
      _error = null;
      notifyListeners();
      return false;
    }
  }

  Future<bool> rejectInvite(String token, String workspaceId) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/workspace/$workspaceId/member/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        // Refresh the workspace list to update available workspaces
        _selectedWorkspace = null;
        await fetchWorkspaces(token);
        _error = null;
        return true;
      } else {
        final error = json.decode(response.body);
        _error = error['error'] ?? 'Failed to reject invitation';
        notifyListeners();
        _error = null;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Network error occurred';
      notifyListeners();
      _error = null;
      notifyListeners();
      return false;
    }
  }

  Future<bool> leaveWorkspace(String token, String workspaceId, String userId) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/workspace/$workspaceId/member/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        // Refresh the workspace list to update available workspaces
        await fetchWorkspaces(token);
        _error = null;
        // Clear selected workspace if we just left it
        if (_selectedWorkspace?.id == workspaceId) {
          _selectedWorkspace = _workspaces.isNotEmpty ? _workspaces.first : null;
        }
        return true;
      } else {
        final error = json.decode(response.body);
        _error = error['error'] ?? 'Failed to leave workspace';
        notifyListeners();
        _error = null;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Network error occurred';
      notifyListeners();
      _error = null;
      notifyListeners();
      return false;
    }
  }
} 