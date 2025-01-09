import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import '../config/api_config.dart';
import 'websocket_provider.dart';
import 'auth_provider.dart';

class DirectMessage {
  final String id;
  final String content;
  final String userId;
  final String username;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? parentId;
  final String channelId;

  DirectMessage({
    required this.id,
    required this.content,
    required this.userId,
    required this.username,
    required this.createdAt,
    required this.updatedAt,
    required this.parentId,
    required this.channelId,
  });

  factory DirectMessage.fromJson(Map<String, dynamic> json) {
    return DirectMessage(
      id: json['id'],
      content: json['content'],
      userId: json['user_id'],
      username: json['username'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      parentId: json['parent_id'],
      channelId: json['channel_id'],
    );
  }
}

class DMChannel {
  final String id;
  final String workspaceId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> usernames;
  final DateTime? lastMessageAt;

  DMChannel({
    required this.id,
    required this.workspaceId,
    required this.createdAt,
    required this.updatedAt,
    required this.usernames,
    this.lastMessageAt,
  });

  factory DMChannel.fromJson(Map<String, dynamic> json) {
    return DMChannel(
      id: json['id'],
      workspaceId: json['workspace_id'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      usernames: List<String>.from(json['usernames']),
      lastMessageAt: json['last_message_at'] != null
          ? DateTime.parse(json['last_message_at'])
          : null,
    );
  }
}

class DMProvider with ChangeNotifier {
  final AuthProvider authProvider;
  final WebSocketProvider _wsProvider;
  StreamSubscription? _wsSubscription;

  // Map of channelId to list of messages
  final Map<String, List<DirectMessage>> _channelMessages = {};
  // Map of channelId to loading state
  final Map<String, bool> _channelLoading = {};
  // Map of channelId to error state
  final Map<String, String?> _channelErrors = {};
  // Map of channelId to last message ID
  final Map<String, String?> _channelLastMessageIds = {};
  // Map of channelId to hasMore state
  final Map<String, bool> _channelHasMore = {};
  // Currently selected DM channel
  DMChannel? _selectedChannel;

  List<DMChannel> _channels = [];

  DMProvider(this.authProvider, this._wsProvider) {
    _setupWebSocketListener();
  }

  DMChannel? get selectedChannel => _selectedChannel;
  List<DirectMessage> get messages =>
      _channelMessages[_selectedChannel?.id] ?? [];
  bool get isLoading => _channelLoading[_selectedChannel?.id] ?? false;
  String? get error => _channelErrors[_selectedChannel?.id];
  bool get hasMore => _channelHasMore[_selectedChannel?.id] ?? true;

  void selectChannel(DMChannel channel) {
    _selectedChannel = channel;
    if (!_channelMessages.containsKey(channel.id)) {
      if (authProvider.accessToken != null) {
        loadMessages(authProvider.accessToken!, channel.id);
      }
    }
    notifyListeners();
  }

  void _setupWebSocketListener() {
    _wsSubscription = _wsProvider.messageStream.listen((data) {
      switch (data['type']) {
        case 'new_direct_message':
          debugPrint('Handling new DM event');
          final messageData = data['message'] as Map<String, dynamic>;
          messageData['channel_id'] = data['channelId'];
          handleNewMessage(messageData);
          break;

        case 'dm_updated':
          handleUpdatedMessage(data['message']);
          break;

        case 'dm_deleted':
          handleDeletedMessage(
            data['messageId'],
            data['channelId'],
          );
          break;
      }
    });
  }

  void handleNewMessage(Map<String, dynamic> messageData) {
    final newMessage = DirectMessage.fromJson(messageData);
    final channelId = messageData['channel_id'];
    final channelMessages = _channelMessages[channelId] ?? [];

    if (channelMessages.any((m) => m.id == newMessage.id)) {
      return; // Skip duplicate message
    }

    int insertIndex =
        channelMessages.indexWhere((m) => m.id.compareTo(newMessage.id) < 0);
    if (insertIndex == -1) {
      channelMessages.add(newMessage);
    } else {
      channelMessages.insert(insertIndex, newMessage);
    }
    _channelMessages[channelId] = channelMessages;
    notifyListeners();
  }

  void handleUpdatedMessage(Map<String, dynamic> messageData) {
    final updatedMessage = DirectMessage.fromJson(messageData);
    final channelId = messageData['channel_id'];
    final channelMessages = _channelMessages[channelId];
    if (channelMessages != null) {
      final index =
          channelMessages.indexWhere((m) => m.id == updatedMessage.id);
      if (index != -1) {
        channelMessages[index] = updatedMessage;
        notifyListeners();
      }
    }
  }

  void handleDeletedMessage(String messageId, String channelId) {
    final channelMessages = _channelMessages[channelId];
    if (channelMessages != null) {
      channelMessages.removeWhere((m) => m.id == messageId);
      notifyListeners();
    }
  }

  Future<DMChannel?> createDMChannel(
      String accessToken, String workspaceId, List<String> userIds) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/dm/workspace/$workspaceId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: json.encode({
          'user_ids': userIds,
        }),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        debugPrint('DM channel data: ${response.body.toString()}');
        debugPrint('DM channel created successfully');
        return DMChannel.fromJson(data);
      } else {
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Failed to create DM channel');
      }
    } catch (e) {
      debugPrint('Error creating DM channel: $e');
      return null;
    }
  }

  Future<void> loadMessages(String accessToken, String channelId,
      {int limit = 50}) async {
    if (_channelLoading[channelId] == true) {
      return;
    }

    _channelLoading[channelId] = true;
    _channelErrors[channelId] = null;
    notifyListeners();

    try {
      var url = '${ApiConfig.baseUrl}/dm/$channelId/messages?limit=$limit';
      final lastMessageId = _channelLastMessageIds[channelId];
      if (lastMessageId != null) {
        url += '&before=$lastMessageId';
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
        final newMessages =
            data.map((json) => DirectMessage.fromJson(json)).toList();

        if (newMessages.isEmpty) {
          _channelHasMore[channelId] = false;
        } else {
          final channelMessages = _channelMessages[channelId] ?? [];
          channelMessages.addAll(newMessages);
          _channelMessages[channelId] = channelMessages;
          _channelLastMessageIds[channelId] = newMessages.last.id;
        }

        _channelErrors[channelId] = null;
      } else {
        final error = json.decode(response.body);
        _channelErrors[channelId] = error['error'] ?? 'Failed to load messages';
      }
    } catch (e) {
      _channelErrors[channelId] = 'Network error occurred';
    } finally {
      _channelLoading[channelId] = false;
      notifyListeners();
    }
  }

  Future<DirectMessage?> sendMessage(
      String accessToken, String channelId, String content,
      {String? parentId}) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/dm/$channelId/messages'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: json.encode({
          'content': content,
          'parent_id': parentId,
        }),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        return DirectMessage.fromJson(data);
      } else {
        final error = json.decode(response.body);
        _channelErrors[channelId] = error['error'] ?? 'Failed to send message';
        return null;
      }
    } catch (e) {
      _channelErrors[channelId] = 'Network error occurred';
      return null;
    }
  }

  Future<bool> updateMessage(
      String accessToken, String messageId, String content) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/dm/$messageId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: json.encode({
          'content': content,
        }),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        final error = json.decode(response.body);
        if (_selectedChannel != null) {
          _channelErrors[_selectedChannel!.id] =
              error['error'] ?? 'Failed to update message';
        }
        return false;
      }
    } catch (e) {
      if (_selectedChannel != null) {
        _channelErrors[_selectedChannel!.id] = 'Network error occurred';
      }
      return false;
    }
  }

  Future<bool> deleteMessage(String accessToken, String messageId) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/dm/$messageId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        final error = json.decode(response.body);
        if (_selectedChannel != null) {
          _channelErrors[_selectedChannel!.id] =
              error['error'] ?? 'Failed to delete message';
        }
        return false;
      }
    } catch (e) {
      if (_selectedChannel != null) {
        _channelErrors[_selectedChannel!.id] = 'Network error occurred';
      }
      return false;
    }
  }

  void clearChannel(String channelId) {
    _channelMessages.remove(channelId);
    _channelLoading.remove(channelId);
    _channelErrors.remove(channelId);
    _channelLastMessageIds.remove(channelId);
    _channelHasMore.remove(channelId);
    if (_selectedChannel?.id == channelId) {
      _selectedChannel = null;
    }
    notifyListeners();
  }

  void clearAllChannels() {
    _channelMessages.clear();
    _channelLoading.clear();
    _channelErrors.clear();
    _channelLastMessageIds.clear();
    _channelHasMore.clear();
    _selectedChannel = null;
    notifyListeners();
  }

  List<DMChannel> get channels => _channels;

  Future<void> fetchDMChannels(String accessToken, String workspaceId) async {
    try {
      debugPrint('Fetching DM channels for workspace $workspaceId');
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/dm/workspace/$workspaceId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        debugPrint('DM channels fetched successfully');
        debugPrint('DM channels: ${response.body}');
        final List<dynamic> data = json.decode(response.body);
        _channels = data.map((json) => DMChannel.fromJson(json)).toList();

        // Select the first channel by default if none is selected
        if (_channels.isNotEmpty && _selectedChannel == null) {
          selectChannel(_channels.first);
        }
        notifyListeners();
      } else {
        debugPrint('Failed to fetch DM channels');
        final error = json.decode(response.body);
        throw Exception(error['error'] ?? 'Failed to fetch DM channels');
      }
    } catch (e) {
      debugPrint('Error fetching DM channels: $e');
      _channels = [];
      notifyListeners();
    }
  }

  void clearChannels() {
    _channels = [];
    _selectedChannel = null;
    _channelMessages.clear();
    _channelLoading.clear();
    _channelErrors.clear();
    _channelLastMessageIds.clear();
    _channelHasMore.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    super.dispose();
  }
}
