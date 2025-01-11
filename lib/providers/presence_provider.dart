import 'dart:async';
import 'package:flutter/foundation.dart';
import 'websocket_provider.dart';

class PresenceProvider with ChangeNotifier {
  final WebSocketProvider _wsProvider;
  final Map<String, String> _userPresence = {}; // userId -> status
  final Map<String, int> _userTrackingCount =
      {}; // userId -> number of trackers
  StreamSubscription? _wsSubscription;

  PresenceProvider(this._wsProvider) {
    _setupWebSocketListener();
  }

  void _setupWebSocketListener() {
    _wsSubscription = _wsProvider.messageStream.listen((data) {
      if (data['type'] == 'presence') {
        final userId = data['userId'] as String;
        final status = data['status'] as String;
        _userPresence[userId] = status;
        notifyListeners();
      }
    });
  }

  String? getUserPresence(String userId) => _userPresence[userId];

  void startTrackingUser(String userId) {
    final currentCount = _userTrackingCount[userId] ?? 0;
    _userTrackingCount[userId] = currentCount + 1;

    // Only send subscribe message if this is the first tracker
    if (currentCount == 0) {
      _wsProvider.sendPresenceSubscribe(userId);
    }
  }

  void stopTrackingUser(String userId) {
    final currentCount = _userTrackingCount[userId] ?? 0;
    if (currentCount <= 0) return;

    final newCount = currentCount - 1;
    if (newCount == 0) {
      _userTrackingCount.remove(userId);
      _userPresence.remove(userId);
      _wsProvider.sendPresenceUnsubscribe(userId);
    } else {
      _userTrackingCount[userId] = newCount;
    }
  }

  @override
  void dispose() {
    _wsSubscription?.cancel();
    _userPresence.clear();
    _userTrackingCount.clear();
    super.dispose();
  }
}
