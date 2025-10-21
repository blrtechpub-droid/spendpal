#!/bin/bash
# Build Android app bundle for Google Play Console
# Usage: ./scripts/build-android-release.sh

set -e  # Exit on error

echo "🚀 Building SpendPal for Android (Google Play)..."
echo ""

# Check Flutter
if ! command -v flutter &> /dev/null; then
    echo "❌ Error: Flutter not found. Please install Flutter SDK"
    exit 1
fi

# Check for key.properties
if [ ! -f "android/key.properties" ]; then
    echo "⚠️  Warning: android/key.properties not found!"
    echo "   This file is required for release builds."
    echo ""
    echo "📋 To create signing configuration:"
    echo "   1. Generate keystore (see GOOGLE_PLAY_CONSOLE_GUIDE.md)"
    echo "   2. Create android/key.properties with:"
    echo "      storePassword=YOUR_PASSWORD"
    echo "      keyPassword=YOUR_PASSWORD"
    echo "      keyAlias=upload"
    echo "      storeFile=/path/to/keystore.jks"
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean

# Get dependencies
echo "📦 Getting Flutter dependencies..."
flutter pub get

# Build app bundle
echo "🔨 Building Android App Bundle (AAB)..."
flutter build appbundle --release

# Build APK (for testing)
echo "🔨 Building Android APK..."
flutter build apk --release

echo ""
echo "✅ Build complete!"
echo ""
echo "📦 Output files:"
echo "   AAB: build/app/outputs/bundle/release/app-release.aab"
echo "   APK: build/app/outputs/apk/release/app-release.apk"
echo ""
echo "📋 Next steps:"
echo "1. Go to https://play.google.com/console/"
echo "2. Select your app → Testing → Internal testing"
echo "3. Create new release → Upload AAB"
echo "4. Add release notes → Roll out"
echo ""
echo "📖 For detailed instructions, see:"
echo "   .claude/GOOGLE_PLAY_CONSOLE_GUIDE.md"
