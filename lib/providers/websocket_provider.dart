import 'package:flutter/foundation.dart';
import '../services/websocket_service.dart';

class WebSocketProvider with ChangeNotifier {
  final WebSocketService _webSocketService = WebSocketService();
  bool get isConnected => _webSocketService.isConnected;

  Stream<Map<String, dynamic>> get messageStream =>
      _webSocketService.messageStream;

  Future<void> connect(String token) async {
    await _webSocketService.connect(token);
  }

  void sendMessage(String channelId, String content) {
    _webSocketService.sendMessage(channelId, content);
  }

  @override
  void dispose() {
    _webSocketService.dispose();
    super.dispose();
  }
}
