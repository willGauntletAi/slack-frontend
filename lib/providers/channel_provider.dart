import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../config/api_config.dart';
import 'websocket_provider.dart';

class Channel {
  final String id;
  final String? name;
  final bool isPrivate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> usernames;
  final int unreadCount;
  final String? lastReadMessage;
  final DateTime lastUpdated;

  Channel({
    required this.id,
    this.name,
    required this.isPrivate,
    required this.createdAt,
    required this.updatedAt,
    required this.usernames,
    required this.unreadCount,
    this.lastReadMessage,
    required this.lastUpdated,
  });

  factory Channel.fromJson(Map<String, dynamic> json) {
    return Channel(
      id: json['id'],
      name: json['name'],
      isPrivate: json['is_private'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      usernames: (json['usernames'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          (json['members'] as List<dynamic>?)
              ?.map((e) => (e as Map<String, dynamic>)['username'] as String)
              .toList() ??
          [],
      unreadCount: json['unread_count'] ?? 0,
      lastReadMessage: json['last_read_message'],
      lastUpdated: DateTime.parse(json['lastUpdated'] ?? json['updated_at']),
    );
  }

  factory Channel.fromWebSocket(Map<String, dynamic> json) {
    return Channel(
      id: json['id'],
      name: json['name'],
      isPrivate: json['is_private'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      usernames: (json['members'] as List<dynamic>)
          .map((e) => (e as Map<String, dynamic>)['username'] as String)
          .toList(),
      unreadCount: 0, // New channels from websocket start with 0 unread
      lastReadMessage: null,
      lastUpdated: DateTime.parse(json['lastUpdated'] ?? json['updated_at']),
    );
  }
}

class ChannelProvider extends ChangeNotifier {
  List<Channel> _channels = [];
  Channel? _selectedChannel;
  String? _selectedMessageId;
  bool _isLoading = false;
  String? _error;
  String? _operationError;
  final WebSocketProvider _wsProvider;
  StreamSubscription? _wsSubscription;

  ChannelProvider(this._wsProvider) {
    _setupWebSocketListener();
  }

  void _sortChannels() {
    _channels.sort((a, b) {
      // First sort by unread count
      if (a.unreadCount > 0 && b.unreadCount == 0) return -1;
      if (a.unreadCount == 0 && b.unreadCount > 0) return 1;

      // Then by last updated time
      return b.lastUpdated.compareTo(a.lastUpdated);
    });
  }

  void _setupWebSocketListener() {
    Set<String> processedMessageIds = {};
    _wsSubscription = _wsProvider.messageStream.listen((data) {
      if (data['type'] == 'channel_join') {
        try {
          final channelData = data['channel'] as Map<String, dynamic>;
          final newChannel = Channel.fromWebSocket(channelData);

          // Check if channel already exists
          final existingIndex =
              _channels.indexWhere((c) => c.id == newChannel.id);
          if (existingIndex != -1) {
            _channels[existingIndex] = newChannel;
          } else {
            _channels.add(newChannel);
          }
          _sortChannels();
          notifyListeners();
        } catch (e) {
          // Error handling preserved without debug print
        }
      } else if (data['type'] == 'new_message') {
        try {
          final messageData = data['message'] as Map<String, dynamic>;
          final messageId = messageData['id'].toString();
          final channelId = data['channelId'] as String;

          if (processedMessageIds.contains(messageId)) {
            return;
          }
          processedMessageIds.add(messageId);

          final channelIndex = _channels.indexWhere((c) => c.id == channelId);

          if (channelIndex != -1) {
            final channel = _channels[channelIndex];
            final isSelected = _selectedChannel?.id == channelId;

            final updatedChannel = Channel(
              id: channel.id,
              name: channel.name,
              isPrivate: channel.isPrivate,
              createdAt: channel.createdAt,
              updatedAt: channel.updatedAt,
              usernames: channel.usernames,
              unreadCount:
                  isSelected ? channel.unreadCount : channel.unreadCount + 1,
              lastReadMessage: channel.lastReadMessage,
              lastUpdated: DateTime.now(),
            );

            _channels[channelIndex] = updatedChannel;
            _sortChannels();
            notifyListeners();
          }
        } catch (e) {
          debugPrint('Error processing new_message: $e'); // Debug log
        }
      }
    });
  }

  List<Channel> get channels => _channels;
  Channel? get selectedChannel => _selectedChannel;
  String? get selectedMessageId => _selectedMessageId;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get operationError => _operationError;

  void _clearOperationError() {
    _operationError = null;
    notifyListeners();
  }

  void selectChannel(Channel? channel, {String? messageId}) {
    if (_selectedChannel?.id != channel?.id ||
        _selectedMessageId != messageId) {
      _selectedChannel = channel;
      _selectedMessageId = messageId;
      notifyListeners();
    }
  }

  Future<void> fetchChannels(String accessToken, String workspaceId) async {
    _isLoading = true;
    _error = null;
    _selectedChannel = null;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/channel/me?workspace_id=$workspaceId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _channels = data.map((json) => Channel.fromJson(json)).toList();

        // Remove any duplicate channels by ID
        final uniqueChannels = <String, Channel>{};
        for (var channel in _channels) {
          uniqueChannels[channel.id] = channel;
        }
        _channels = uniqueChannels.values.toList();

        _sortChannels();

        // Select the first channel by default if none is selected
        if (_channels.isNotEmpty && _selectedChannel == null) {
          selectChannel(_channels.first);
        }
      } else {
        final error = json.decode(response.body);
        _error = error['error'] ?? 'Failed to fetch channels';
      }
    } catch (e) {
      _error = 'Network error occurred';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Channel?> createChannel(
      String accessToken, String workspaceId, String? name,
      {List<String> userIds = const [], bool isPrivate = false}) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/channel/workspace/$workspaceId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
        body: json.encode({
          'name': name,
          'is_private': isPrivate,
          'member_ids': userIds,
        }),
      );

      if (response.statusCode == 201) {
        final data = json.decode(response.body);
        final newChannel = Channel.fromJson(data);

        // Add new channel to the list
        _channels.add(newChannel);
        _sortChannels();
        notifyListeners();

        return newChannel;
      } else {
        final error = json.decode(response.body);
        _error = error['error'] ?? 'Failed to create channel';
        return null;
      }
    } catch (e) {
      _error = 'Network error occurred';
      return null;
    }
  }

  Future<bool> leaveChannel(
      String accessToken, String channelId, String userId) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/channel/$channelId/member/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        _channels.removeWhere((channel) => channel.id == channelId);
        if (_selectedChannel?.id == channelId) {
          _selectedChannel = _channels.isNotEmpty ? _channels.first : null;
        }
        notifyListeners();
        return true;
      } else {
        final error = json.decode(response.body);
        _error = error['error'] ?? 'Failed to leave channel';
        return false;
      }
    } catch (e) {
      _error = 'Network error occurred';
      return false;
    }
  }

  Future<List<Channel>> fetchPublicChannels(
      String accessToken, String workspaceId,
      {String? search}) async {
    try {
      var queryParams = 'exclude_mine=true';
      if (search != null && search.isNotEmpty) {
        queryParams += '&search=$search';
      }

      final response = await http.get(
        Uri.parse(
            '${ApiConfig.baseUrl}/channel/workspace/$workspaceId?$queryParams'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Channel.fromJson(json)).toList();
      } else {
        final error = json.decode(response.body);
        _error = error['error'] ?? 'Failed to fetch public channels';
        return [];
      }
    } catch (e) {
      _error = 'Network error occurred';
      return [];
    }
  }

  Future<bool> joinChannel(String accessToken, String channelId, String userId,
      String workspaceId) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/channel/$channelId/member/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      if (response.statusCode == 200) {
        // Refresh the channels list
        await fetchChannels(accessToken, workspaceId);
        return true;
      } else {
        final error = json.decode(response.body);
        _error = error['error'] ?? 'Failed to join channel';
        return false;
      }
    } catch (e) {
      _error = 'Network error occurred: $e';
      return false;
    }
  }

  void clearChannels() {
    _channels = [];
    _selectedChannel = null;
    _error = null;
    notifyListeners();
  }

  void updateChannel(Channel updatedChannel) {
    final index = _channels.indexWhere((c) => c.id == updatedChannel.id);
    if (index != -1) {
      _channels[index] = updatedChannel;
      if (_selectedChannel?.id == updatedChannel.id) {
        _selectedChannel = updatedChannel;
      }
      _sortChannels();
      notifyListeners();
    }
  }

  void handleMessageRead(String channelId, String messageId) {
    final channel = _channels.firstWhere((c) => c.id == channelId);
    final updatedChannel = Channel(
      id: channel.id,
      name: channel.name,
      isPrivate: channel.isPrivate,
      createdAt: channel.createdAt,
      updatedAt: channel.updatedAt,
      usernames: channel.usernames,
      //TODO: fix this. This only works if there is a single unread message. Otherwise, we might be marking several messages as read, but only decrementing the count by 1.
      unreadCount: channel.unreadCount > 0 ? channel.unreadCount - 1 : 0,
      lastReadMessage: messageId,
      lastUpdated: channel.lastUpdated,
    );
    updateChannel(updatedChannel);
  }

  Future<bool> addChannelMembers(
    String token,
    String channelId,
    List<String> userIds,
  ) async {
    _clearOperationError();
    try {
      // Add each user to the channel individually
      for (final userId in userIds) {
        final response = await http.post(
          Uri.parse('${ApiConfig.baseUrl}/channel/$channelId/member/$userId'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );

        if (response.statusCode != 200) {
          _operationError = 'Failed to add member to channel';
          notifyListeners();
          return false;
        }
      }

      // Refresh the channels list after adding all members
      final channel = _channels.firstWhere((c) => c.id == channelId);
      final selectedChannel = Channel(
        id: channel.id,
        name: channel.name,
        isPrivate: channel.isPrivate,
        createdAt: channel.createdAt,
        updatedAt: channel.updatedAt,
        usernames: [...channel.usernames],
        unreadCount: channel.unreadCount,
        lastReadMessage: channel.lastReadMessage,
        lastUpdated: channel.lastUpdated,
      );
      updateChannel(selectedChannel);
      return true;
    } catch (e) {
      _operationError = 'Failed to add members to channel';
      notifyListeners();
      return false;
    }
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    super.dispose();
  }
}
