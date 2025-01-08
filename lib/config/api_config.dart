import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show debugPrint;

class ApiConfig {
  static String get baseUrl {
    // For web, always use localhost
    if (kIsWeb) {
      return 'http://localhost:3000';
    }

    // For iOS Simulator and macOS, we need to use localhost.
    if (Platform.isIOS || Platform.isMacOS) {
      return 'http://127.0.0.1:3000';
    }
    // For Android emulator, we need to use 10.0.2.2
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:3000';
    }
    // Default fallback
    return 'http://localhost:3000';
  }

  static String get wsUrl {
    final httpUrl = baseUrl;
    final wsUrl = '${httpUrl.replaceFirst('http', 'ws')}/ws';
    debugPrint('Constructed WebSocket URL: $wsUrl');
    return wsUrl;
  }

  static String get loginUrl => '$baseUrl/auth/login';
  static String get registerUrl => '$baseUrl/auth/register';
  static String get refreshTokenUrl => '$baseUrl/auth/refresh';
  static String get logoutUrl => '$baseUrl/auth/logout';
}
