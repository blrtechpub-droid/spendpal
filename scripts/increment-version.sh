#!/bin/bash
# Increment app version number
# Usage:
#   ./scripts/increment-version.sh patch  # 1.0.0+1 → 1.0.1+1
#   ./scripts/increment-version.sh minor  # 1.0.1+1 → 1.1.0+1
#   ./scripts/increment-version.sh major  # 1.1.0+1 → 2.0.0+1
#   ./scripts/increment-version.sh build  # 1.0.0+1 → 1.0.0+2

set -e

PUBSPEC_FILE="pubspec.yaml"
INCREMENT_TYPE="${1:-build}"

# Read current version
CURRENT_VERSION=$(grep "^version:" $PUBSPEC_FILE | sed 's/version: //')
VERSION_NAME=$(echo $CURRENT_VERSION | cut -d'+' -f1)
BUILD_NUMBER=$(echo $CURRENT_VERSION | cut -d'+' -f2)

# Split version name
MAJOR=$(echo $VERSION_NAME | cut -d'.' -f1)
MINOR=$(echo $VERSION_NAME | cut -d'.' -f2)
PATCH=$(echo $VERSION_NAME | cut -d'.' -f3)

echo "Current version: $CURRENT_VERSION"
echo "  Version name: $VERSION_NAME"
echo "  Build number: $BUILD_NUMBER"
echo ""

# Increment based on type
case $INCREMENT_TYPE in
    major)
        MAJOR=$((MAJOR + 1))
        MINOR=0
        PATCH=0
        BUILD_NUMBER=1
        ;;
    minor)
        MINOR=$((MINOR + 1))
        PATCH=0
        BUILD_NUMBER=1
        ;;
    patch)
        PATCH=$((PATCH + 1))
        BUILD_NUMBER=1
        ;;
    build)
        BUILD_NUMBER=$((BUILD_NUMBER + 1))
        ;;
    *)
        echo "❌ Error: Invalid increment type: $INCREMENT_TYPE"
        echo "   Usage: $0 [major|minor|patch|build]"
        exit 1
        ;;
esac

# Create new version string
NEW_VERSION_NAME="$MAJOR.$MINOR.$PATCH"
NEW_VERSION="$NEW_VERSION_NAME+$BUILD_NUMBER"

echo "New version: $NEW_VERSION"
echo "  Version name: $NEW_VERSION_NAME"
echo "  Build number: $BUILD_NUMBER"
echo ""

# Update pubspec.yaml
sed -i.bak "s/^version: .*/version: $NEW_VERSION/" $PUBSPEC_FILE
rm "$PUBSPEC_FILE.bak"

echo "✅ Updated $PUBSPEC_FILE"
echo ""
echo "📋 Don't forget to:"
echo "   1. Commit the version change"
echo "   2. Tag the release: git tag v$NEW_VERSION_NAME"
echo "   3. Push tags: git push --tags"
