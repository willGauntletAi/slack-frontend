import 'dart:async';
import 'package:flutter/foundation.dart';
import 'websocket_provider.dart';

class TypingIndicatorProvider with ChangeNotifier {
  // Map of channelId to Map of userId to (username, timestamp) pair
  final Map<String, Map<String, (String, DateTime)>> _typingUsers = {};
  Timer? _cleanupTimer;
  StreamSubscription? _wsSubscription;
  static const _typingTimeout = Duration(seconds: 1);
  final WebSocketProvider _wsProvider;

  TypingIndicatorProvider(this._wsProvider) {
    _cleanupTimer =
        Timer.periodic(const Duration(seconds: 1), (_) => _cleanup());
    _setupWebSocketListener();
  }

  void _setupWebSocketListener() {
    _wsSubscription = _wsProvider.messageStream.listen((data) {
      debugPrint('typing message received: $data');
      if (data['type'] == 'typing') {
        userStartedTyping(
          data['channelId'],
          data['userId'],
          data['username'],
        );
      }
    });
  }

  void userStartedTyping(String channelId, String userId, String username) {
    _typingUsers.putIfAbsent(channelId, () => {});
    _typingUsers[channelId]![userId] = (username, DateTime.now());
    notifyListeners();
  }

  List<String> getTypingUsernames(String channelId, String currentUserId) {
    final typingInChannel = _typingUsers[channelId];
    if (typingInChannel == null) return [];

    final now = DateTime.now();
    final result = typingInChannel.entries
        .where((entry) =>
            entry.key != currentUserId &&
            now.difference(entry.value.$2) < _typingTimeout)
        .map((entry) => entry.value.$1)
        .toList();
    debugPrint('typingInChannel: $typingInChannel');
    debugPrint('result: $result');
    return result;
  }

  void _cleanup() {
    bool changed = false;
    final now = DateTime.now();

    for (final channelId in _typingUsers.keys.toList()) {
      final typingInChannel = _typingUsers[channelId]!;
      final staleUsers = typingInChannel.entries
          .where((entry) => now.difference(entry.value.$2) >= _typingTimeout)
          .map((entry) => entry.key)
          .toList();

      for (final userId in staleUsers) {
        typingInChannel.remove(userId);
        changed = true;
      }

      if (typingInChannel.isEmpty) {
        _typingUsers.remove(channelId);
        changed = true;
      }
    }

    if (changed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _cleanupTimer?.cancel();
    _wsSubscription?.cancel();
    _typingUsers.clear();
    super.dispose();
  }
}
