#!/bin/bash
# Build and prepare iOS app for TestFlight
# Usage: ./scripts/build-ios-testflight.sh

set -e  # Exit on error

echo "🚀 Building SpendPal for iOS TestFlight..."
echo ""

# Check if on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "❌ Error: iOS builds require macOS"
    exit 1
fi

# Check for Xcode
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Error: Xcode not found. Please install Xcode from App Store"
    exit 1
fi

# Check Flutter
if ! command -v flutter &> /dev/null; then
    echo "❌ Error: Flutter not found. Please install Flutter SDK"
    exit 1
fi

# Clean previous builds
echo "🧹 Cleaning previous builds..."
flutter clean
rm -rf ios/Pods
rm -rf ios/.symlinks

# Get dependencies
echo "📦 Getting Flutter dependencies..."
flutter pub get

# Install CocoaPods dependencies
echo "📦 Installing iOS dependencies..."
cd ios
pod install
cd ..

# Run Flutter doctor
echo "🔍 Checking Flutter configuration..."
flutter doctor

# Build iOS release
echo "🔨 Building iOS release..."
flutter build ios --release --no-codesign

echo ""
echo "✅ Build complete!"
echo ""
echo "📋 Next steps:"
echo "1. Open Xcode: open ios/Runner.xcworkspace"
echo "2. Select 'Any iOS Device (arm64)' as build destination"
echo "3. Product → Archive"
echo "4. Distribute to App Store Connect"
echo ""
echo "📖 For detailed instructions, see:"
echo "   .claude/APP_STORE_TESTFLIGHT_GUIDE.md"
