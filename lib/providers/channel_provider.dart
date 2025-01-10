import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';

class Channel {
  final String id;
  final String? name;
  final bool isPrivate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> usernames;
  final int unreadCount;
  final String? lastReadMessage;

  Channel({
    required this.id,
    this.name,
    required this.isPrivate,
    required this.createdAt,
    required this.updatedAt,
    required this.usernames,
    required this.unreadCount,
    this.lastReadMessage,
  });

  factory Channel.fromJson(Map<String, dynamic> json) {
    return Channel(
      id: json['id'],
      name: json['name'],
      isPrivate: json['is_private'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      usernames: (json['usernames'] as List<dynamic>)
          .map((e) => e.toString())
          .toList(),
      unreadCount: json['unread_count'] ?? 0,
      lastReadMessage: json['last_read_message'],
    );
  }
}

class ChannelProvider extends ChangeNotifier {
  List<Channel> _channels = [];
  Channel? _selectedChannel;
  bool _isLoading = false;
  String? _error;

  List<Channel> get channels => _channels;
  Channel? get selectedChannel => _selectedChannel;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void selectChannel(Channel? channel) {
    if (_selectedChannel?.id != channel?.id) {
      if (channel != null) {
        // Reset unread count when selecting a channel
        final updatedChannel = Channel(
          id: channel.id,
          name: channel.name,
          isPrivate: channel.isPrivate,
          createdAt: channel.createdAt,
          updatedAt: channel.updatedAt,
          usernames: channel.usernames,
          unreadCount: 0,
          lastReadMessage: channel.lastReadMessage,
        );
        updateChannel(updatedChannel);
      }
      _selectedChannel = channel;
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

        // Select the first channel by default if none is selected
        if (_channels.isNotEmpty) {
          // Always select first channel to ensure proper initialization
          selectChannel(_channels.first);
        } else {
          _selectedChannel = null;
          notifyListeners();
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
        debugPrint('Response body: ${response.body}');
        final data = json.decode(response.body);
        final newChannel = Channel.fromJson(data);

        _channels.add(newChannel);
        notifyListeners();

        return newChannel;
      } else {
        debugPrint('Response body: ${response.body}');
        final error = json.decode(response.body);
        _error = error['error'] ?? 'Failed to create channel';
        return null;
      }
    } catch (e) {
      debugPrint('Error creating channel: $e');
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
      notifyListeners();
    }
  }
}
