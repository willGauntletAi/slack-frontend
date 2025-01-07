import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';

class Message {
  final String id;
  final String content;
  final String? parentId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String userId;
  final String username;

  Message({
    required this.id,
    required this.content,
    this.parentId,
    required this.createdAt,
    required this.updatedAt,
    required this.userId,
    required this.username,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      content: json['content'],
      parentId: json['parent_id'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      userId: json['user_id'],
      username: json['username'],
    );
  }
}

class MessageProvider extends ChangeNotifier {
  List<Message> _messages = [];
  bool _isLoading = false;
  String? _error;
  String? _lastMessageId;
  bool _hasMore = true;

  List<Message> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasMore => _hasMore;

  Future<void> loadMessages(String accessToken, String channelId, {int limit = 50}) async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      var url = '${ApiConfig.baseUrl}/message/channel/$channelId?limit=$limit';
      if (_lastMessageId != null) {
        url += '&before=$_lastMessageId';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final newMessages = data.map((json) => Message.fromJson(json)).toList();
        
        if (newMessages.isEmpty) {
          _hasMore = false;
        } else {
          _messages.addAll(newMessages);
          _lastMessageId = newMessages.last.id;
        }
        
        _error = null;
      } else {
        final error = json.decode(response.body);
        _error = error['error'] ?? 'Failed to load messages';
      }
    } catch (e) {
      _error = 'Network error occurred';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Message?> sendMessage(String accessToken, String channelId, String content, {String? parentId}) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/message/channel/$channelId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: json.encode({
          'content': content,
          if (parentId != null) 'parent_id': parentId,
        }),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        final newMessage = Message.fromJson(data);
        _messages.insert(0, newMessage);
        notifyListeners();
        return newMessage;
      } else {
        final error = json.decode(response.body);
        _error = error['error'] ?? 'Failed to send message';
        return null;
      }
    } catch (e) {
      _error = 'Network error occurred';
      return null;
    }
  }

  Future<bool> updateMessage(String accessToken, String messageId, String content) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/message/$messageId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: json.encode({
          'content': content,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final updatedMessage = Message.fromJson(data);
        final index = _messages.indexWhere((m) => m.id == messageId);
        if (index != -1) {
          _messages[index] = updatedMessage;
          notifyListeners();
        }
        return true;
      } else {
        final error = json.decode(response.body);
        _error = error['error'] ?? 'Failed to update message';
        return false;
      }
    } catch (e) {
      _error = 'Network error occurred';
      return false;
    }
  }

  Future<bool> deleteMessage(String accessToken, String messageId) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/message/$messageId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        _messages.removeWhere((m) => m.id == messageId);
        notifyListeners();
        return true;
      } else {
        final error = json.decode(response.body);
        _error = error['error'] ?? 'Failed to delete message';
        return false;
      }
    } catch (e) {
      _error = 'Network error occurred';
      return false;
    }
  }

  void clearMessages() {
    _messages = [];
    _lastMessageId = null;
    _hasMore = true;
    _error = null;
    notifyListeners();
  }
} 