const String environment = 'production';

class BuildConfig {
  static bool get isDevelopment => environment == 'development';
  static bool get isProduction => environment == 'production';
}
