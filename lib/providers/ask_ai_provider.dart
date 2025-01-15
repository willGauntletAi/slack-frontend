import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';

class AskAiResponse {
  final String answer;
  final List<RelevantMessage> relevantMessages;

  AskAiResponse({
    required this.answer,
    required this.relevantMessages,
  });

  factory AskAiResponse.fromJson(Map<String, dynamic> json) {
    return AskAiResponse(
      answer: json['answer'],
      relevantMessages: (json['relevantMessages'] as List)
          .map((m) => RelevantMessage.fromJson(m))
          .toList(),
    );
  }
}

class RelevantMessage {
  final String id;
  final String content;
  final String userId;
  final String username;
  final String channelId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final double similarity;

  RelevantMessage({
    required this.id,
    required this.content,
    required this.userId,
    required this.username,
    required this.channelId,
    required this.createdAt,
    required this.updatedAt,
    required this.similarity,
  });

  factory RelevantMessage.fromJson(Map<String, dynamic> json) {
    return RelevantMessage(
      id: json['id'],
      content: json['content'],
      userId: json['userId'],
      username: json['username'],
      channelId: json['channelId'],
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      similarity: json['similarity'].toDouble(),
    );
  }
}

class AskAiProvider with ChangeNotifier {
  bool _isLoading = false;
  String? _error;
  AskAiResponse? _lastResponse;

  bool get isLoading => _isLoading;
  String? get error => _error;
  AskAiResponse? get lastResponse => _lastResponse;

  Future<void> askAi({
    required String accessToken,
    required String query,
    required String workspaceId,
    String? channelId,
    int? limit,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final queryParams = {
        'query': query,
        'workspaceId': workspaceId,
        if (channelId != null) 'channelId': channelId,
        if (limit != null) 'limit': limit.toString(),
      };

      final uri = Uri.parse('${ApiConfig.baseUrl}/search/ask-ai')
          .replace(queryParameters: queryParams);

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _lastResponse = AskAiResponse.fromJson(data);
      } else {
        final data = json.decode(response.body);
        _error = data['error'] ?? 'Failed to get AI response';
      }
    } catch (e) {
      _error = 'An error occurred while getting AI response: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearLastResponse() {
    _lastResponse = null;
    notifyListeners();
  }
}
