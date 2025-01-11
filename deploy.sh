#!/bin/bash

# Exit on error
set -e

# Configuration
BUCKET_NAME="slack-frontend-1736548898"

echo "🚀 Starting deployment process..."

# Backup development config
echo "📝 Backing up development configuration..."
cp lib/config/build_config.dart lib/config/build_config.dev.bak

# Set production configuration
echo "⚙️ Setting production configuration..."
echo "const String environment = 'production';

class BuildConfig {
  static bool get isDevelopment => environment == 'development';
  static bool get isProduction => environment == 'production';
}" > lib/config/build_config.dart

# Build Flutter web app
echo "📦 Building Flutter web application..."
flutter build web --release

# Restore development config
echo "🔄 Restoring development configuration..."
mv lib/config/build_config.dev.bak lib/config/build_config.dart

# Upload to S3
echo "☁️ Uploading to S3..."
aws s3 sync build/web s3://$BUCKET_NAME

# Ensure bucket policy is set correctly
echo "🔒 Setting bucket permissions..."
aws s3api put-bucket-policy \
  --bucket $BUCKET_NAME \
  --policy "{\"Version\":\"2012-10-17\",\"Statement\":[{\"Sid\":\"PublicReadGetObject\",\"Effect\":\"Allow\",\"Principal\":\"*\",\"Action\":\"s3:GetObject\",\"Resource\":\"arn:aws:s3:::$BUCKET_NAME/*\"}]}"

# Configure website
echo "🌐 Configuring static website hosting..."
aws s3 website s3://$BUCKET_NAME \
  --index-document index.html \
  --error-document index.html

echo "✅ Deployment complete!"
echo "🌎 Your website is available at: http://$BUCKET_NAME.s3-website-us-east-1.amazonaws.com"
