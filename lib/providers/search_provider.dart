import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';

class SearchResult {
  final String id;
  final String content;
  final String channelId;
  final String userId;
  final String username;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String matchContext;
  final List<SearchAttachment> attachments;
  final bool isAvatar;

  SearchResult({
    required this.id,
    required this.content,
    required this.channelId,
    required this.userId,
    required this.username,
    required this.createdAt,
    required this.updatedAt,
    required this.matchContext,
    required this.attachments,
    required this.isAvatar,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      id: json['id'],
      content: json['content'],
      channelId: json['channelId'],
      userId: json['userId'],
      username: json['username'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      matchContext: json['matchContext'],
      attachments: (json['attachments'] as List)
          .map((a) => SearchAttachment.fromJson(a))
          .toList(),
      isAvatar: json['is_avatar'],
    );
  }
}

class SearchAttachment {
  final String id;
  final String filename;
  final String fileKey;
  final String mimeType;
  final String size;
  final DateTime createdAt;

  SearchAttachment({
    required this.id,
    required this.filename,
    required this.fileKey,
    required this.mimeType,
    required this.size,
    required this.createdAt,
  });

  factory SearchAttachment.fromJson(Map<String, dynamic> json) {
    return SearchAttachment(
      id: json['id'],
      filename: json['filename'],
      fileKey: json['fileKey'],
      mimeType: json['mimeType'],
      size: json['size'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}

class SearchProvider with ChangeNotifier {
  List<SearchResult> _results = [];
  bool _isLoading = false;
  String? _error;
  String? _nextId;
  int _totalCount = 0;
  String? _lastQuery;
  String? _lastWorkspaceId;
  String? _lastChannelId;

  List<SearchResult> get results => _results;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasMore => _nextId != null;
  int get totalCount => _totalCount;

  Future<void> search(
    String accessToken,
    String query,
    String workspaceId, {
    String? channelId,
    bool reset = true,
  }) async {
    if (query.isEmpty) {
      _results = [];
      _nextId = null;
      _totalCount = 0;
      _error = null;
      notifyListeners();
      return;
    }

    // If it's a new search, reset the state
    if (reset ||
        query != _lastQuery ||
        workspaceId != _lastWorkspaceId ||
        channelId != _lastChannelId) {
      _results = [];
      _nextId = null;
      _totalCount = 0;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      var url =
          '${ApiConfig.baseUrl}/search?query=${Uri.encodeComponent(query)}'
          '&workspaceId=$workspaceId';

      if (channelId != null) {
        url += '&channelId=$channelId';
      }
      if (_nextId != null) {
        url += '&beforeId=$_nextId';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final newResults = (data['messages'] as List)
            .map((m) => SearchResult.fromJson(m))
            .toList();

        if (reset ||
            query != _lastQuery ||
            workspaceId != _lastWorkspaceId ||
            channelId != _lastChannelId) {
          _results = newResults;
        } else {
          _results.addAll(newResults);
        }

        _nextId = data['nextId'];
        _totalCount = data['totalCount'];
        _lastQuery = query;
        _lastWorkspaceId = workspaceId;
        _lastChannelId = channelId;
        _error = null;
      } else {
        final error = json.decode(response.body);
        _error = error['error'] ?? 'Failed to perform search';
      }
    } catch (e) {
      _error = 'Network error occurred';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearResults() {
    _results = [];
    _nextId = null;
    _totalCount = 0;
    _error = null;
    _lastQuery = null;
    _lastWorkspaceId = null;
    _lastChannelId = null;
    notifyListeners();
  }
}
