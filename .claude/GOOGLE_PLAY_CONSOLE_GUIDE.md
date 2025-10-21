# Google Play Console Setup Guide

Complete guide to set up beta testing for SpendPal on Android using Google Play Console.

---

## Current Configuration

- **App Name:** spendpal
- **Package Name:** com.example.spendpal (⚠️ Change for production!)
- **Version:** 1.0.0 (Code: 1)
- **Minimum SDK:** Set by Flutter
- **Target SDK:** Set by Flutter

**⚠️ IMPORTANT:** You must change the package name from `com.example.spendpal` to your own unique identifier before publishing.

---

## Prerequisites

### 1. Google Play Console Account
- One-time registration fee: $25
- URL: https://play.google.com/console/signup
- Sign in with Google account

### 2. Development Tools
- Android Studio (optional but recommended)
- Java JDK 11 or higher
- Flutter SDK

---

## Step 1: Create Signing Key

### 1.1 Generate Upload Keystore
```bash
# Navigate to android/app directory
cd android/app

# Generate keystore
keytool -genkey -v \
  -keystore ~/upload-keystore.jks \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -alias upload \
  -storetype JKS
```

**Answer the prompts:**
```
Enter keystore password: [CHOOSE STRONG PASSWORD]
Re-enter password: [REPEAT PASSWORD]
What is your first and last name? SpendPal Development
What is the name of your organizational unit? Development
What is the name of your organization? BLRTECH Pub
What is the name of your City or Locality? [Your City]
What is the name of your State or Province? [Your State]
What is the two-letter country code? IN
Is CN=..., correct? yes

Enter key password for <upload>: [PRESS ENTER to use same password]
```

**Save the keystore:**
```bash
# Move keystore to safe location (NOT in git repo!)
mv ~/upload-keystore.jks ~/keystores/spendpal-upload-keystore.jks
```

### 1.2 Create key.properties File
```bash
# Create key.properties in android/ directory
cat > android/key.properties <<EOF
storePassword=[YOUR KEYSTORE PASSWORD]
keyPassword=[YOUR KEY PASSWORD]
keyAlias=upload
storeFile=[FULL PATH TO .jks FILE]
EOF
```

**Example:**
```properties
storePassword=MySecurePassword123!
keyPassword=MySecurePassword123!
keyAlias=upload
storeFile=/Users/abhaysingh/keystores/spendpal-upload-keystore.jks
```

**⚠️ SECURITY:**
- Add `key.properties` to `.gitignore`
- NEVER commit passwords to git
- Keep keystore file secure (backup in safe location)

### 1.3 Update .gitignore
```bash
# Add to .gitignore
echo "android/key.properties" >> .gitignore
echo "**/*.jks" >> .gitignore
echo "**/*.keystore" >> .gitignore
```

---

## Step 2: Configure Build for Signing

### 2.1 Update android/app/build.gradle.kts

**Add BEFORE android {} block:**
```kotlin
// Load keystore properties
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = java.util.Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(java.io.FileInputStream(keystorePropertiesFile))
}
```

**Update android {} block:**
```kotlin
android {
    namespace = "com.blrtechpub.spendpal"  // ⚠️ Change from com.example.spendpal
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.blrtechpub.spendpal"  // ⚠️ Change from com.example.spendpal
        minSdk = 21  // Minimum for Firebase
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Add signing configurations
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            storeFile = file(keystoreProperties.getProperty("storeFile"))
            storePassword = keystoreProperties.getProperty("storePassword")
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            // Enable minification and resource shrinking for smaller APK
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}
```

### 2.2 Create ProGuard Rules (Optional but Recommended)

```bash
# Create android/app/proguard-rules.pro
cat > android/app/proguard-rules.pro <<EOF
# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**

# Google Sign-In
-keep class com.google.android.gms.auth.** { *; }
-dontwarn com.google.android.gms.auth.**
EOF
```

---

## Step 3: Update Package Name

### 3.1 Update Build Files
```
Already done in Step 2.1:
- android/app/build.gradle.kts → applicationId and namespace
```

### 3.2 Update Android Manifest
```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    package="com.blrtechpub.spendpal">  <!-- Change this -->
```

### 3.3 Update MainActivity Kotlin File

**Rename directory:**
```bash
cd android/app/src/main/kotlin
mv com/example/spendpal com/blrtechpub/spendpal
```

**Update MainActivity.kt:**
```kotlin
package com.blrtechpub.spendpal  // Change this

import io.flutter.embedding.android.FlutterActivity

class MainActivity: FlutterActivity() {
}
```

### 3.4 Update google-services.json
```
1. Go to Firebase Console
2. Project Settings → Your apps → Android app
3. Update package name to com.blrtechpub.spendpal
4. Download new google-services.json
5. Replace android/app/google-services.json
```

---

## Step 4: Build App Bundle

### 4.1 Clean Build
```bash
flutter clean
flutter pub get
```

### 4.2 Build App Bundle (AAB)
```bash
flutter build appbundle --release
```

**Output:**
```
✓ Built build/app/outputs/bundle/release/app-release.aab (XX.X MB)
```

**Alternative: Build APK (for testing)**
```bash
flutter build apk --release
```

---

## Step 5: Create App in Google Play Console

### 5.1 Access Play Console
```
1. Go to https://play.google.com/console/
2. Sign in with Google account
3. Create account if first time ($25 fee)
4. Accept developer agreement
```

### 5.2 Create New App
```
1. Click "Create app"
2. Fill in details:
   - App name: SpendPal
   - Default language: English (United States)
   - App or game: App
   - Free or paid: Free
3. Read and accept declarations
4. Click "Create app"
```

---

## Step 6: Complete App Store Listing

### 6.1 Store Listing
```
Dashboard → Store presence → Main store listing

Fill in:
- App name: SpendPal
- Short description (80 chars):
  "Track and split expenses with friends. Simple, social expense management."

- Full description (4000 chars):
  "SpendPal makes expense tracking and splitting easy!

  FEATURES:
  • Track personal expenses
  • Split bills with friends
  • Create expense groups
  • Real-time balance calculations
  • Scan bills (coming soon)
  • Multiple split methods
  • Beautiful dark mode interface

  Perfect for roommates, trips, and shared expenses!"

- App icon (512x512 PNG)
- Feature graphic (1024x500 PNG)
- Phone screenshots (2-8 required)
- Tablet screenshots (optional)

- Category: Finance
- Tags: expense, tracker, split, bills
- Email: your-email@example.com
- Phone: Optional
- Website: Optional
```

### 6.2 Create Graphics

**App Icon (512x512):**
```bash
# Export from your design tool or use existing icon
# Must be PNG, 512x512px, 32-bit
```

**Feature Graphic (1024x500):**
```
Design a banner showcasing your app
Tools: Canva, Figma, Photoshop
```

**Screenshots:**
```
Minimum 2, maximum 8 screenshots required
- Phone: 1080x1920 or 1080x2340
- Tablet (optional): 1600x2560

Capture from:
1. Groups screen
2. Add expense screen
3. Expense details
4. Account screen

Use Android emulator or physical device
```

---

## Step 7: Set Up Internal Testing

### 7.1 Create Internal Testing Release
```
1. Dashboard → Testing → Internal testing
2. Click "Create new release"
```

### 7.2 Upload App Bundle
```
1. Click "Upload" in App bundles section
2. Select: build/app/outputs/bundle/release/app-release.aab
3. Wait for upload to complete
4. Google Play validates the bundle
```

### 7.3 Add Release Notes
```
Release name: 1.0.0 (Beta 1)

What's new in this release:
- Initial beta release
- Track expenses
- Split with friends
- Create groups
- Real-time balances

Known issues:
- None
```

### 7.4 Review and Save
```
1. Review release details
2. Click "Save"
3. Click "Review release"
4. Fix any warnings/errors
5. Click "Start rollout to Internal testing"
```

---

## Step 8: Add Test Users

### 8.1 Create Tester List
```
1. Testing → Internal testing → Testers tab
2. Create email list:
   - Click "Create email list"
   - Name: "Internal Testers"
   - Add email addresses (Google accounts)
   - Save
```

### 8.2 Share Testing Link
```
1. Copy the opt-in URL
2. Share with testers via email
3. Testers must:
   - Be signed in to Google Play with listed email
   - Open opt-in link on Android device
   - Accept invitation
   - Download app
```

**Limits:** Up to 100 internal testers

---

## Step 9: Set Up Closed Testing (Optional)

### 9.1 Create Closed Testing Track
```
1. Testing → Closed testing → Create new release
2. Upload same AAB or create new release
3. Add release notes
```

### 9.2 Add More Testers
```
1. Closed testing → Testers tab
2. Create new email list
3. Add up to 100 lists
4. Each list: unlimited testers
```

**Limits:** Unlimited closed testers across 100 lists

---

## Step 10: Set Up Open Testing (Optional)

### 10.1 Create Open Testing Track
```
1. Testing → Open testing → Create new release
2. Upload AAB
3. Add release notes
```

### 10.2 Configure Open Testing
```
- Anyone can join
- No approval needed
- Visible on Play Store with "Early access" badge
- Share opt-in link or list on Play Store
```

**Limits:** Unlimited open testers

---

## Step 11: Monitor Testing

### 11.1 Track Crashes
```
Dashboard → Quality → Android vitals → Crashes

View:
- Crash rate
- ANR (App Not Responding) rate
- Stack traces
- Device models affected
```

### 11.2 Review Feedback
```
Dashboard → Testing → [Track] → Feedback tab

Testers can provide:
- Star ratings
- Written feedback
- Screenshots
```

### 11.3 Check Pre-Launch Report
```
Dashboard → Quality → Pre-launch report

Google automatically tests on:
- Multiple devices
- Different Android versions
- Various screen sizes

Review:
- Crashes
- Security vulnerabilities
- Performance issues
```

---

## Updating Beta Builds

### Update Process
```
1. Increment version in pubspec.yaml:
   version: 1.0.0+2  # Increment build number

2. Build new AAB:
   flutter build appbundle --release

3. Upload to testing track:
   - Testing → [Track] → Create new release
   - Upload new AAB
   - Add release notes
   - Roll out

4. Testers auto-notified via Play Store
```

---

## Production Release Process

When ready for production:

### 1. Complete Store Listing
```
All required fields in:
- Main store listing
- Store settings
- App content (privacy policy, target audience, etc.)
```

### 2. Set Up Countries
```
Dashboard → Production → Countries/regions
- Select available countries
- Can start with limited release
```

### 3. Create Production Release
```
1. Dashboard → Production → Create new release
2. Upload final AAB
3. Add release notes
4. Set rollout percentage (start at 5-10%)
5. Review and roll out
```

### 4. Submit for Review
```
Google reviews app (1-7 days)
Check for:
- Policy violations
- Malware
- Content rating accuracy
```

---

## Troubleshooting

### Issue: Build Fails with Signing Error
**Solutions:**
```
1. Verify key.properties exists and has correct values
2. Check keystore file path is absolute
3. Ensure passwords are correct
4. Check keystore file permissions
```

### Issue: Upload Rejected - Version Code Exists
**Solutions:**
```
1. Increment build number in pubspec.yaml
2. Clean and rebuild:
   flutter clean && flutter build appbundle --release
3. Upload new AAB
```

### Issue: Google Play Services Error
**Solutions:**
```
1. Verify google-services.json is in android/app/
2. Check package name matches in:
   - build.gradle.kts
   - AndroidManifest.xml
   - Firebase Console
3. Rebuild project
```

### Issue: App Not Compatible with Any Devices
**Solutions:**
```
1. Check minSdk in build.gradle.kts (should be >= 21)
2. Review AndroidManifest.xml for restrictive permissions
3. Check for hardware requirements (e.g., camera="required")
```

---

## Best Practices

### 1. Version Management
```yaml
# pubspec.yaml
version: MAJOR.MINOR.PATCH+BUILD

Examples:
- First beta: 1.0.0+1
- Bug fix: 1.0.0+2
- New feature: 1.0.1+1
- Breaking change: 1.1.0+1
```

### 2. Testing Phases
```
1. Internal testing (1-2 weeks)
   - Core team, 10-20 testers
   - Fix critical bugs

2. Closed testing (2-4 weeks)
   - Larger group, 100-500 testers
   - Gather feedback, fix issues

3. Open testing (optional, 1-2 weeks)
   - Public beta
   - Final polish

4. Production (gradual rollout)
   - Start at 5%, increase to 100%
```

### 3. Release Notes
```
Always include:
- New features
- Bug fixes
- Performance improvements
- Known issues
- Breaking changes (if any)
```

### 4. Monitoring
```
- Check crashes daily
- Respond to feedback
- Monitor ANR rate
- Track install/uninstall rate
- Review Play Console warnings
```

---

## Automation with Fastlane (Advanced)

### Install Fastlane
```bash
sudo gem install fastlane
cd android
fastlane init
```

### Configure Fastfile
```ruby
# android/fastlane/Fastfile
default_platform(:android)

platform :android do
  desc "Upload to Internal Testing"
  lane :internal do
    # Build
    gradle(
      task: "bundle",
      build_type: "Release"
    )

    # Upload to Play Console
    upload_to_play_store(
      track: 'internal',
      aab: '../build/app/outputs/bundle/release/app-release.aab',
      skip_upload_screenshots: true,
      skip_upload_images: true
    )
  end

  desc "Promote Internal to Closed Testing"
  lane :promote_to_closed do
    upload_to_play_store(
      track: 'internal',
      track_promote_to: 'beta',
      skip_upload_apk: true,
      skip_upload_aab: true
    )
  end
end
```

### Run Fastlane
```bash
cd android
fastlane internal
```

---

## CI/CD with GitHub Actions

```yaml
# .github/workflows/android-internal.yml
name: Android Internal Testing

on:
  push:
    tags:
      - 'v*'

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - uses: actions/setup-java@v3
        with:
          distribution: 'zulu'
          java-version: '11'

      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.35.4'

      - name: Decode keystore
        run: |
          echo "${{ secrets.KEYSTORE_BASE64 }}" | base64 -d > android/app/upload-keystore.jks

      - name: Create key.properties
        run: |
          echo "storePassword=${{ secrets.KEYSTORE_PASSWORD }}" > android/key.properties
          echo "keyPassword=${{ secrets.KEY_PASSWORD }}" >> android/key.properties
          echo "keyAlias=upload" >> android/key.properties
          echo "storeFile=upload-keystore.jks" >> android/key.properties

      - name: Build AAB
        run: flutter build appbundle --release

      - name: Deploy to Play Console
        uses: r0adkll/upload-google-play@v1
        with:
          serviceAccountJsonPlainText: ${{ secrets.PLAY_STORE_JSON }}
          packageName: com.blrtechpub.spendpal
          releaseFiles: build/app/outputs/bundle/release/app-release.aab
          track: internal
```

---

## Checklist

### Before First Upload
- [ ] Google Play Console account created ($25 paid)
- [ ] Upload keystore generated and secured
- [ ] key.properties created and in .gitignore
- [ ] Package name changed from com.example.spendpal
- [ ] google-services.json updated with new package name
- [ ] build.gradle.kts configured for signing
- [ ] App store listing completed
- [ ] App icon and graphics created
- [ ] Screenshots captured

### Before Each Upload
- [ ] Version/build number incremented
- [ ] App tested on physical device
- [ ] No critical bugs
- [ ] Release notes prepared
- [ ] AAB builds successfully

### After Upload
- [ ] Release rolled out to track
- [ ] Testers added and invited
- [ ] Opt-in link shared
- [ ] Pre-launch report reviewed
- [ ] No critical issues in report

---

## Useful Commands

```bash
# Build signed AAB
flutter build appbundle --release

# Build signed APK
flutter build apk --release

# Build APK for specific ABI
flutter build apk --split-per-abi --release

# Check current version
grep version pubspec.yaml

# Check keystore info
keytool -list -v -keystore ~/keystores/spendpal-upload-keystore.jks

# Verify APK signing
jarsigner -verify -verbose -certs build/app/outputs/apk/release/app-release.apk

# Analyze bundle size
bundletool build-apks \
  --bundle=build/app/outputs/bundle/release/app-release.aab \
  --output=app.apks

# Install APK on device
flutter install --release
```

---

## Resources

- **Play Console:** https://play.google.com/console/
- **Google Play Documentation:** https://developer.android.com/distribute/console
- **Android App Bundle:** https://developer.android.com/guide/app-bundle
- **Flutter Android Deployment:** https://docs.flutter.dev/deployment/android
- **Fastlane Android:** https://docs.fastlane.tools/getting-started/android/setup/

---

## Important Security Notes

### Keystore Security
```
✓ DO:
- Store keystore in secure location outside repo
- Keep backup in multiple secure places
- Use strong passwords (16+ characters)
- Document keystore details securely

✗ DON'T:
- Commit keystore to git
- Share keystore file publicly
- Use simple passwords
- Lose keystore (can't update app!)
```

### Credentials Management
```
For CI/CD, use:
- GitHub Secrets for passwords
- Base64 encode keystore for storage
- Service account for Play Console API
- Environment variables for sensitive data
```

---

**Next Steps:**
1. Complete iOS TestFlight setup
2. Test on both platforms
3. Gather user feedback
4. Prepare for production release
