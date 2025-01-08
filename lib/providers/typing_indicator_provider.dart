import 'dart:async';
import 'package:flutter/foundation.dart';

class TypingIndicatorProvider with ChangeNotifier {
  // Map of channelId to Map of userId to (username, timestamp) pair
  final Map<String, Map<String, (String, DateTime)>> _typingUsers = {};
  Timer? _cleanupTimer;
  static const _typingTimeout = Duration(seconds: 6);

  TypingIndicatorProvider() {
    _cleanupTimer =
        Timer.periodic(const Duration(seconds: 1), (_) => _cleanup());
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
    return typingInChannel.entries
        .where((entry) =>
            entry.key != currentUserId &&
            now.difference(entry.value.$2) < _typingTimeout)
        .map((entry) => entry.value.$1)
        .toList();
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
    _typingUsers.clear();
    super.dispose();
  }
}
