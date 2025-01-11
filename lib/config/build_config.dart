// This file will be replaced during build time with the appropriate configuration
const String environment = 'development'; // or 'production'

class BuildConfig {
  static bool get isDevelopment => environment == 'development';
  static bool get isProduction => environment == 'production';
}
