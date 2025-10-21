# 📱 SpendPal - App Store & Play Store Testing Release Guide

Complete guide to releasing SpendPal for **TestFlight (iOS)** and **Google Play Internal Testing (Android)**.

---

## 🎯 Overview

| Platform | Service | Max Testers | Duration | Review Required | Cost |
|----------|---------|-------------|----------|-----------------|------|
| **iOS** | TestFlight | 10,000 | 90 days | No (internal) | $99/year |
| **Android** | Internal Testing | 100 | Unlimited | No | $25 one-time |

---

## 📋 Prerequisites

### For Both Platforms
- [ ] Completed app with all features working
- [ ] Firebase configuration set up
- [ ] App tested locally on physical devices
- [ ] App icons and splash screens ready
- [ ] Privacy policy URL (required for stores)

### For iOS (TestFlight)
- [ ] Mac with Xcode installed
- [ ] Apple Developer Account ($99/year)
- [ ] Apple Developer Program enrollment completed

### For Android (Play Store)
- [ ] Google Play Console account ($25 one-time)
- [ ] Keystore for signing (we'll create this)

---

## 🍎 PART 1: iOS TestFlight Deployment

### Step 1: Enroll in Apple Developer Program

1. Go to https://developer.apple.com/programs/
2. Click **"Enroll"**
3. Complete enrollment ($99/year)
4. Wait for approval (1-2 days)

### Step 2: Create App ID in Apple Developer Portal

1. Go to https://developer.apple.com/account/
2. Navigate to **Certificates, Identifiers & Profiles**
3. Click **Identifiers** → **+** button
4. Select **App IDs** → **App**
5. Fill in:
   - **Description**: SpendPal
   - **Bundle ID**: `com.example.spendpal` (or your custom domain)
   - **Capabilities**: Enable **Sign in with Apple**, **Push Notifications**
6. Click **Continue** → **Register**

### Step 3: Create App in App Store Connect

1. Go to https://appstoreconnect.apple.com/
2. Click **My Apps** → **+** → **New App**
3. Fill in:
   - **Platform**: iOS
   - **Name**: SpendPal
   - **Primary Language**: English
   - **Bundle ID**: Select the one you created
   - **SKU**: `spendpal-001` (unique identifier)
   - **User Access**: Full Access
4. Click **Create**

### Step 4: Prepare iOS Build

```bash
# Navigate to project root
cd /Users/abhaysingh/Documents/devlopment/expenseTrackingApp/spendpal

# Update pubspec.yaml version (if needed)
# version: 1.0.0+1
#          ^^^^^^ ^^^
#          |      build number
#          version name

# Clean and get dependencies
flutter clean
flutter pub get

# Update pods
cd ios
pod install
pod update
cd ..
```

### Step 5: Update iOS Configuration

**Edit `ios/Runner/Info.plist`:**

```xml
<!-- Add these keys if not present -->
<key>CFBundleDisplayName</key>
<string>SpendPal</string>

<key>NSCameraUsageDescription</key>
<string>We need camera access to scan bills and receipts</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>We need photo library access to upload bill images</string>

<key>NSMicrophoneUsageDescription</key>
<string>Microphone access is required for video features</string>
```

**Edit `ios/Runner.xcodeproj/project.pbxproj` (via Xcode):**

1. Open project in Xcode:
   ```bash
   open ios/Runner.xcworkspace
   ```

2. Select **Runner** in left panel
3. Go to **Signing & Capabilities** tab
4. Select your **Team** from dropdown
5. Ensure **Automatically manage signing** is checked
6. Bundle Identifier should match your App ID

### Step 6: Build and Archive

```bash
# Build iOS release
flutter build ios --release

# Or build with specific configuration
flutter build ipa --release
```

**Or via Xcode:**

1. In Xcode: **Product** → **Archive**
2. Wait for build to complete
3. **Organizer** window will open

### Step 7: Upload to TestFlight

**Via Xcode:**

1. In **Organizer** window, select your archive
2. Click **Distribute App**
3. Select **App Store Connect**
4. Click **Upload**
5. Select **Upload** (not Export)
6. Click **Next** through the options
7. Click **Upload**

**Or via Command Line:**

```bash
flutter build ipa --release

# Upload using fastlane (if installed)
# Or manually via Application Loader
```

### Step 8: Configure TestFlight

1. Go to **App Store Connect** → **TestFlight** tab
2. Wait for processing (10-30 minutes)
3. Once processed, click on your build
4. Fill in **What to Test**:
   ```
   SpendPal v1.0.0 - Beta Testing

   Features to test:
   - Friend request system
   - Group expense splitting
   - Bill upload and parsing
   - Balance calculations
   - Real-time updates

   Known issues:
   - None at this time

   Please report any bugs or feedback!
   ```

### Step 9: Add Testers

**Internal Testing (No Review):**
1. Go to **TestFlight** → **Internal Testing**
2. Click **+** next to testers
3. Add testers by email (must have Apple IDs)
4. They'll receive invitation emails instantly

**External Testing (Requires Review):**
1. Go to **TestFlight** → **External Testing**
2. Create a new group
3. Add testers (up to 10,000)
4. Submit for review (1-2 days)

### Step 10: Testers Install App

Testers receive an email with:
1. Link to install **TestFlight app** from App Store
2. Invitation code
3. Instructions to install SpendPal

---

## 🤖 PART 2: Android Play Store Internal Testing

### Step 1: Create Google Play Console Account

1. Go to https://play.google.com/console/
2. Sign up with Google account
3. Pay $25 one-time registration fee
4. Complete account setup

### Step 2: Create Android Keystore (Signing Key)

```bash
# Navigate to android directory
cd android

# Create keystore
keytool -genkey -v -keystore ~/spendpal-release-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias spendpal

# You'll be prompted for:
# - Keystore password (SAVE THIS!)
# - Alias password (SAVE THIS!)
# - Your name, organization, etc.
```

**IMPORTANT:** Save these passwords in a secure password manager!

### Step 3: Configure Signing

**Create `android/key.properties`:**

```properties
storePassword=YOUR_KEYSTORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=spendpal
storeFile=/Users/abhaysingh/spendpal-release-key.jks
```

**Edit `android/app/build.gradle.kts`:**

Find and update the signing configuration:

```kotlin
// Add at the top, before android block
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    // ... existing config ...

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}
```

### Step 4: Update App Configuration

**Edit `android/app/src/main/AndroidManifest.xml`:**

```xml
<!-- Update application label -->
<application
    android:label="SpendPal"
    android:icon="@mipmap/ic_launcher">
```

**Edit `android/app/build.gradle.kts`:**

```kotlin
defaultConfig {
    applicationId = "com.example.spendpal"  // Same as iOS bundle ID
    minSdk = 21
    targetSdk = 34
    versionCode = 1      // Increment for each release
    versionName = "1.0.0"
}
```

### Step 5: Build Android App Bundle (AAB)

```bash
# Navigate to project root
cd /Users/abhaysingh/Documents/devlopment/expenseTrackingApp/spendpal

# Clean build
flutter clean
flutter pub get

# Build App Bundle (recommended for Play Store)
flutter build appbundle --release

# Output will be at:
# build/app/outputs/bundle/release/app-release.aab
```

**Alternative: Build APK (for direct distribution):**

```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Step 6: Create App in Play Console

1. Go to **Play Console** → **All apps** → **Create app**
2. Fill in:
   - **App name**: SpendPal
   - **Default language**: English (United States)
   - **App or game**: App
   - **Free or paid**: Free
3. Accept declarations
4. Click **Create app**

### Step 7: Set Up App Content

**Complete these sections in Play Console:**

1. **App access**
   - Select: All functionality is available without restrictions

2. **Ads**
   - Select: No, my app does not contain ads

3. **Content rating**
   - Click **Start questionnaire**
   - Answer questions about app content
   - Submit for rating

4. **Target audience**
   - Select age groups: 18+
   - Complete questionnaire

5. **Data safety**
   - Fill in data collection practices
   - Add privacy policy URL (required)

### Step 8: Upload to Internal Testing

1. Go to **Testing** → **Internal testing**
2. Click **Create new release**
3. Click **Upload** and select `app-release.aab`
4. Fill in **Release notes**:
   ```
   SpendPal v1.0.0 - Internal Testing

   What's new:
   - Friend request and group invitation system
   - Split expenses with friends and groups
   - Real-time balance tracking
   - Bill upload and automatic parsing
   - Secure Firebase authentication

   Please test all features and report any issues.
   ```
5. Click **Save** → **Review release** → **Start rollout to Internal testing**

### Step 9: Add Testers

1. Go to **Testing** → **Internal testing** → **Testers** tab
2. Create an email list:
   - Click **Create email list**
   - Add tester emails (Gmail accounts)
   - Save list
3. Copy the **opt-in URL** for testers

### Step 10: Testers Install App

Send testers the opt-in URL. They will:
1. Click the URL
2. Accept the invitation
3. Install from Play Store

---

## 📝 Important Files to Add to `.gitignore`

```bash
# Add to .gitignore:
android/key.properties
*.jks
*.keystore
```

---

## 🔄 Updating the Test Build

### For iOS:

1. Update version in `pubspec.yaml`:
   ```yaml
   version: 1.0.1+2  # Increment version/build number
   ```

2. Build and upload:
   ```bash
   flutter build ipa --release
   # Upload via Xcode or Transporter app
   ```

### For Android:

1. Update version in `android/app/build.gradle.kts`:
   ```kotlin
   versionCode = 2        // Increment
   versionName = "1.0.1"  // Update
   ```

2. Build and upload:
   ```bash
   flutter build appbundle --release
   # Upload to Play Console → Create new release
   ```

---

## 🎨 App Store Assets Needed

### iOS (App Store Connect)

- **App Icon**: 1024×1024px (no transparency)
- **Screenshots**:
  - 6.7" iPhone: 1290×2796px (at least 2)
  - 6.5" iPhone: 1284×2778px
  - 5.5" iPhone: 1242×2208px
- **App Description**: Up to 4,000 characters
- **Keywords**: 100 characters
- **Support URL**: Required
- **Privacy Policy URL**: Required

### Android (Play Console)

- **App Icon**: 512×512px
- **Feature Graphic**: 1024×500px
- **Screenshots**:
  - Phone: 1080×1920px to 7680×4320px (at least 2)
  - 7" Tablet: Optional
  - 10" Tablet: Optional
- **Short description**: 80 characters
- **Full description**: 4,000 characters
- **Privacy Policy URL**: Required

---

## ✅ Testing Release Checklist

### Before Release
- [ ] All features tested and working
- [ ] Firebase configuration verified
- [ ] App icons and splash screens finalized
- [ ] Privacy policy created and hosted
- [ ] Support email/website set up

### iOS
- [ ] Apple Developer account active
- [ ] App ID created
- [ ] App created in App Store Connect
- [ ] Build uploaded to TestFlight
- [ ] Testers added and invited
- [ ] Test notes written

### Android
- [ ] Play Console account created
- [ ] Keystore created and backed up
- [ ] key.properties configured
- [ ] App Bundle built successfully
- [ ] Content rating completed
- [ ] Data safety form completed
- [ ] Internal testing release created
- [ ] Testers added and invited

---

## 🐛 Troubleshooting

### iOS Issues

**"No profiles for 'com.example.spendpal' were found"**
- Open Xcode
- Go to Signing & Capabilities
- Select your team
- Let Xcode create profiles automatically

**"Archive upload failed"**
- Check Bundle ID matches App Store Connect
- Verify signing certificates are valid
- Try uploading via Transporter app

**"Build processing stuck"**
- Wait up to 1 hour
- Check for email from Apple about issues
- Verify Info.plist has all required keys

### Android Issues

**"keystore not found"**
- Verify path in `key.properties`
- Use absolute path, not relative

**"Failed to sign APK"**
- Check passwords in `key.properties`
- Verify keystore file exists
- Try creating new keystore

**"Upload rejected"**
- Ensure versionCode is higher than previous
- Check AndroidManifest.xml for issues
- Verify AAB is signed correctly

---

## 💡 Pro Tips

1. **Use Firebase App Distribution** for quick testing before stores:
   ```bash
   firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk \
     --app FIREBASE_APP_ID \
     --groups "testers"
   ```

2. **Keep keystore safe**: Store in password manager + cloud backup

3. **Version naming**: Use semantic versioning (1.0.0, 1.0.1, 1.1.0, etc.)

4. **Test on multiple devices**: Different screen sizes and OS versions

5. **Collect feedback**: Use TestFlight feedback or Google Form

---

## 📊 After Testing

Once testing is complete and you're ready for public release:

### iOS
1. Go to App Store Connect
2. Submit for **App Review**
3. Wait 1-3 days for approval
4. Release to App Store

### Android
1. Promote from Internal → Closed → Open Testing
2. Finally, promote to Production
3. Submit for review
4. Release to Play Store

---

## 🎉 You're Ready!

Your SpendPal app will now be available to testers through:
- **iOS**: TestFlight app
- **Android**: Google Play Store (Internal Testing)

**Average time to first tester:**
- iOS: 30-60 minutes after upload
- Android: 10-20 minutes after upload

---

## 📞 Need Help?

- **iOS**: https://developer.apple.com/support/
- **Android**: https://support.google.com/googleplay/android-developer/

---

**Happy Testing! 🚀**
