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

  Workspace({
    required this.id,
    required this.name,
    required this.role,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Workspace.fromJson(Map<String, dynamic> json) {
    return Workspace(
      id: json['id'],
      name: json['name'],
      role: json['role'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
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
} 