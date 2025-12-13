# Play Store Release Guide - SpendPal

This document provides step-by-step instructions for building and uploading SpendPal to the Google Play Store for testing and production releases.

## Table of Contents
- [Prerequisites](#prerequisites)
- [Building the App Bundle](#building-the-app-bundle)
- [Upload to Play Console](#upload-to-play-console)
- [Testing Tracks](#testing-tracks)
- [First-Time Setup Requirements](#first-time-setup-requirements)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

### 1. Signing Configuration
Ensure you have the following files (these should already be set up):
- `android/key.properties` - Contains keystore credentials
- `android/app/upload-keystore.jks` - Your release keystore file

**CRITICAL:** Keep these files backed up securely. Never commit them to version control (they're in .gitignore).

### 2. App Configuration
Current app details:
- **Package Name:** `com.blrtechpub.spendpal`
- **Version:** 1.0.0
- **Build Number:** 1
- **Minimum SDK:** 21 (Android 5.0)
- **Target SDK:** Latest (defined by Flutter)

---

## Building the App Bundle

### Step 1: Clean Previous Builds
```bash
flutter clean
```

### Step 2: Build Release App Bundle
```bash
flutter build appbundle --release
```

This will:
- Compile the app in release mode
- Sign it with your release keystore
- Create an optimized app bundle (AAB)
- Generate the file at: `build/app/outputs/bundle/release/app-release.aab`

### Expected Output
- **File:** `app-release.aab`
- **Location:** `build/app/outputs/bundle/release/`
- **Size:** ~48 MB (may vary with updates)

### Build Warnings (Normal)
You may see warnings about:
- Debug symbols stripping - This is normal; symbols are included in bundle metadata
- Deprecated Java options - Can be ignored unless build fails
- Tree-shaking of Material Icons - This is a good thing (reduces app size)

---

## Upload to Play Console

### 1. Access Google Play Console
- Go to: https://play.google.com/console
- Sign in with your Google Developer account
- Select your app or create a new app if this is the first release

### 2. Choose Testing Track

For your first upload, use **Internal Testing** (recommended):

**Navigation:** Production → Testing → Internal testing

#### Testing Track Options:

| Track | Review Time | Access | Best For |
|-------|-------------|--------|----------|
| **Internal Testing** | Minutes | Up to 100 testers | Quick validation |
| **Closed Testing** | Few hours | Specific tester lists | Beta testing |
| **Open Testing** | 1-2 days | Anyone can join | Public beta |
| **Production** | 1-7 days | All users | Final release |

### 3. Create New Release

1. Click **"Create new release"** button
2. Upload the app bundle:
   - Click **"Upload"**
   - Select file: `build/app/outputs/bundle/release/app-release.aab`
   - Wait for upload to complete (may take a few minutes)

### 4. Fill in Release Details

**Release name:** (suggestion)
```
1.0.0 (Build 1) - Initial Testing Release
```

**Release notes:** (example)
```
Initial release of SpendPal - Expense tracking with social features

Features:
- Track personal and group expenses
- Split bills with friends
- Google Sign-In authentication
- Real-time expense synchronization
- Friend requests and group invitations
- Detailed expense history and categorization

This is a testing release. Please report any issues you encounter.
```

### 5. Review Warnings and Suggestions

Google Play may show:
- **App size warnings** - Normal for first release
- **API level suggestions** - Review and update if needed
- **Permission warnings** - Ensure all permissions are necessary

### 6. Start Rollout

1. Click **"Review release"**
2. Verify all information is correct
3. Click **"Start rollout to [Internal testing]"**
4. Confirm the rollout

---

## Testing Tracks

### Internal Testing

**Setup:**
1. Navigate to: Testing → Internal testing → Testers tab
2. Create a testers list or add individual email addresses
3. Copy the opt-in URL
4. Share the URL with your testers

**Tester Instructions:**
1. Open the opt-in URL on your Android device
2. Click "Become a tester"
3. Download the app from Play Store
4. Test and provide feedback

### Promoting to Production

When you're ready to release to all users:

1. Go to your testing track
2. Click on the release you want to promote
3. Click **"Promote release"**
4. Select **"Production"**
5. Review and confirm
6. Wait for Google's review (1-7 days)

---

## First-Time Setup Requirements

Before you can publish (even to testing), complete these sections in Play Console:

### 1. App Content
- Target audience and content rating
- Privacy policy URL (required)
- App access (if any restrictions)
- Ads declaration

### 2. Store Listing
Required information:
- **App name:** SpendPal (or your chosen name)
- **Short description:** (80 characters max)
- **Full description:** (4000 characters max)
- **App icon:** 512x512 PNG
- **Feature graphic:** 1024x500 PNG
- **Screenshots:** Minimum 2 screenshots (up to 8)
  - Phone: 16:9 or 9:16 ratio
  - Recommended: 1080x1920 or 1920x1080
- **App category:** Finance or Productivity
- **Contact email:** Your support email
- **Privacy policy URL:** Required for apps that access user data

### 3. Data Safety Section
Declare what data your app collects:
- User account information (email, name)
- Photos/files (if using image picker)
- Financial information (expense data)
- Location (if tracking expense locations)

For each, specify:
- Is it collected?
- Is it shared with third parties?
- Is it optional or required?
- How is it secured?

### 4. Pricing & Distribution
- Free or Paid
- Countries/regions where app is available
- Content rating questionnaire
- Government apps declaration

---

## Troubleshooting

### Build Errors

**Problem:** Google Services plugin version error
```
Solution: Update android/settings.gradle.kts:
id("com.google.gms.google-services") version "4.4.2" apply false
```

**Problem:** Keystore not found
```
Solution: Ensure android/key.properties exists and points to correct keystore file
```

**Problem:** Gradle build fails with cache errors
```
Solution:
flutter clean
rm -rf build/
flutter build appbundle --release
```

### Upload Issues

**Problem:** Package name already exists
```
Solution: Package name must be unique. Change it in:
- android/app/build.gradle.kts (applicationId)
- AndroidManifest.xml (package)
```

**Problem:** Version code conflict
```
Solution: Increment version in pubspec.yaml:
version: 1.0.1+2  (format: version+buildNumber)
```

**Problem:** Upload stuck or timing out
```
Solution:
- Check internet connection
- Try uploading from a different browser
- Compress app bundle if over 100 MB
```

### Testing Issues

**Problem:** Testers can't see the app
```
Solution:
- Ensure they've accepted the opt-in link
- Wait 15-30 minutes after rollout
- Check they're using the correct Google account
```

**Problem:** App crashes on tester devices
```
Solution:
- Check crash reports in Play Console
- Test on multiple Android versions
- Review logs: adb logcat
```

---

## Version Updates

When releasing a new version:

### 1. Update Version Number
Edit `pubspec.yaml`:
```yaml
version: 1.0.1+2  # increment either version (1.0.1) or build number (+2)
```

### 2. Rebuild App Bundle
```bash
flutter clean
flutter build appbundle --release
```

### 3. Upload to Play Console
- Create new release in same or different track
- Upload new app-release.aab
- Add release notes describing changes
- Review and rollout

### 4. Rollout Strategy
Options:
- **Staged rollout:** Release to percentage of users (10%, 25%, 50%, 100%)
- **Full rollout:** Release to all users immediately
- **Promote from testing:** Test first, then promote to production

---

## Important Security Notes

1. **Never commit these files:**
   - `android/key.properties`
   - `android/app/*.jks` (keystore files)
   - `android/app/*.keystore`

2. **Backup your keystore:**
   - Store in multiple secure locations
   - If lost, you cannot update your app on Play Store
   - Consider using a password manager for credentials

3. **Google Play App Signing:**
   - Consider enrolling in Google Play App Signing
   - Google manages your app signing key
   - You only need your upload key
   - Provides additional security and key recovery

---

## Useful Commands

```bash
# Check Flutter and Android setup
flutter doctor

# Analyze code before release
flutter analyze

# Run tests
flutter test

# Build APK for testing (not for Play Store)
flutter build apk --release

# Build App Bundle for Play Store
flutter build appbundle --release

# Check app bundle size breakdown
cd build/app/outputs/bundle/release
unzip -l app-release.aab

# Clean all build artifacts
flutter clean
rm -rf build/
```

---

## Resources

- **Play Console:** https://play.google.com/console
- **Flutter Build & Release Guide:** https://docs.flutter.dev/deployment/android
- **Play Store Requirements:** https://support.google.com/googleplay/android-developer/answer/9859152
- **App Bundle Format:** https://developer.android.com/guide/app-bundle
- **Version Code Best Practices:** https://developer.android.com/studio/publish/versioning

---

## Quick Reference

**Current Build Output:**
- File: `build/app/outputs/bundle/release/app-release.aab`
- Package: `com.blrtechpub.spendpal`
- Version: `1.0.0+1`

**Build Command:**
```bash
flutter build appbundle --release
```

**Upload Location:**
- Play Console → Production → Testing → Internal testing
- Or: Play Console → Production (for production release)

---

*Last updated: 2025-10-22*
