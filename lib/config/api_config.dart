import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;
import 'build_config.dart';

class ApiConfig {
  static String get baseUrl {
    if (BuildConfig.isProduction) {
      return 'http://ec2-3-139-67-107.us-east-2.compute.amazonaws.com:80';
    }

    // Development URLs
    if (kIsWeb) {
      return 'http://localhost:3000';
    }

    // For iOS Simulator and macOS, we need to use localhost
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
    return wsUrl;
  }

  static String get loginUrl => '$baseUrl/auth/login';
  static String get registerUrl => '$baseUrl/auth/register';
  static String get refreshTokenUrl => '$baseUrl/auth/refresh';
  static String get logoutUrl => '$baseUrl/auth/logout';
}
