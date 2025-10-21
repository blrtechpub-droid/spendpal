# App Store Testing - Quick Start Guide

Fast-track guide to set up beta testing on both iOS (TestFlight) and Android (Google Play).

---

## 📋 Prerequisites Checklist

### Required Accounts
- [ ] Apple Developer Account ($99/year) - https://developer.apple.com/programs/
- [ ] Google Play Console Account ($25 one-time) - https://play.google.com/console/signup

### Required Tools
- [ ] Flutter SDK installed
- [ ] Xcode installed (for iOS, macOS only)
- [ ] Android Studio or Android SDK (for Android)
- [ ] Git repository set up

---

## ⚡ Quick Setup (30 Minutes)

### iOS TestFlight (15 minutes)

```bash
# 1. Build iOS app
./scripts/build-ios-testflight.sh

# 2. Open in Xcode
open ios/Runner.xcworkspace

# 3. In Xcode:
#    - Select team in Signing & Capabilities
#    - Product → Archive
#    - Distribute → App Store Connect → Upload

# 4. In App Store Connect (web):
#    - Create app with Bundle ID
#    - TestFlight → Add build
#    - Add internal testers
#    - Send invites
```

**Time: 15 minutes (plus 10-30 min processing)**

### Android Google Play (15 minutes)

```bash
# 1. Generate signing key (first time only)
keytool -genkey -v \
  -keystore ~/keystores/spendpal-upload-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload

# 2. Create android/key.properties
# See GOOGLE_PLAY_CONSOLE_GUIDE.md Step 1.2

# 3. Build Android app
./scripts/build-android-release.sh

# 4. In Google Play Console (web):
#    - Create app
#    - Complete store listing
#    - Testing → Internal testing → Upload AAB
#    - Add testers
#    - Share opt-in link
```

**Time: 15 minutes (plus 1-2 hours processing)**

---

## 🎯 Essential Setup Steps

### iOS (TestFlight)

**1. Create App in App Store Connect**
```
URL: https://appstoreconnect.apple.com
→ My Apps → + New App
→ Fill details: Name, Bundle ID, SKU
```

**2. Configure Xcode**
```
- Open: ios/Runner.xcworkspace
- Set Bundle ID (must match App Store Connect)
- Enable Automatic Signing
- Select your Team
```

**3. Build & Upload**
```bash
# Use our script
./scripts/build-ios-testflight.sh

# Then in Xcode:
# Product → Archive → Distribute
```

**4. Add Testers**
```
App Store Connect → TestFlight → Internal Testing
→ Add testers by email
→ Testers get invite email
→ Install via TestFlight app
```

### Android (Google Play)

**1. Setup Signing (One-time)**
```bash
# Generate keystore
keytool -genkey -v \
  -keystore ~/keystores/spendpal-upload-keystore.jks \
  -alias upload -keyalg RSA -keysize 2048 -validity 10000

# Create android/key.properties
cat > android/key.properties <<EOF
storePassword=YOUR_PASSWORD
keyPassword=YOUR_PASSWORD
keyAlias=upload
storeFile=/Users/YOUR_NAME/keystores/spendpal-upload-keystore.jks
EOF

# Add to .gitignore
echo "android/key.properties" >> .gitignore
```

**2. Update Package Name**
```
Change in:
- android/app/build.gradle.kts: applicationId
- AndroidManifest.xml: package
- MainActivity.kt: package declaration
- Rename folder structure

From: com.example.spendpal
To: com.blrtechpub.spendpal (or your domain)
```

**3. Build & Upload**
```bash
# Use our script
./scripts/build-android-release.sh

# Upload to Play Console:
# Testing → Internal testing → Create release
# Upload: build/app/outputs/bundle/release/app-release.aab
```

**4. Add Testers**
```
Play Console → Testing → Internal testing → Testers
→ Create email list
→ Add testers (Google accounts)
→ Share opt-in URL
```

---

## 🚀 Release Workflow

### Version Increment
```bash
# Increment build number (1.0.0+1 → 1.0.0+2)
./scripts/increment-version.sh build

# Increment patch (1.0.0+2 → 1.0.1+1)
./scripts/increment-version.sh patch

# Increment minor (1.0.1 → 1.1.0)
./scripts/increment-version.sh minor

# Increment major (1.1.0 → 2.0.0)
./scripts/increment-version.sh major
```

### Build Both Platforms
```bash
# iOS
./scripts/build-ios-testflight.sh
# Then archive in Xcode

# Android
./scripts/build-android-release.sh
# Then upload AAB to Play Console
```

### Git Workflow
```bash
# Commit version bump
git add pubspec.yaml
git commit -m "Bump version to 1.0.1"

# Tag release
git tag v1.0.1
git push origin main --tags
```

---

## 📊 Testing Phases

### Phase 1: Internal Testing (1-2 weeks)
**iOS:**
- TestFlight → Internal Testing
- Up to 100 testers
- No review required
- Instant distribution

**Android:**
- Play Console → Internal Testing
- Up to 100 testers
- No review required
- Available within hours

**Goal:** Fix critical bugs, ensure core functionality works

### Phase 2: Closed Testing (2-4 weeks)
**iOS:**
- TestFlight → External Testing
- Up to 10,000 testers
- Beta App Review required (1-2 days)
- Can share public link

**Android:**
- Play Console → Closed Testing
- Unlimited testers across 100 lists
- No review required
- Share opt-in link

**Goal:** Gather feedback, test with larger audience

### Phase 3: Open Testing (Optional, 1-2 weeks)
**iOS:**
- Same as external testing
- Make public link more visible

**Android:**
- Play Console → Open Testing
- Unlimited testers
- Visible on Play Store with "Early Access" badge
- Anyone can join

**Goal:** Final polish, public beta

### Phase 4: Production
**iOS:**
- App Store Connect → App Store
- Full app review (1-7 days)
- Public release

**Android:**
- Play Console → Production
- Review (1-7 days)
- Gradual rollout recommended (5% → 100%)

---

## 🛠️ Helpful Scripts

### Build Scripts
```bash
# iOS TestFlight build
./scripts/build-ios-testflight.sh

# Android release build
./scripts/build-android-release.sh

# Increment version
./scripts/increment-version.sh build
```

### Manual Commands
```bash
# Clean everything
flutter clean
cd ios && pod install && cd ..
flutter pub get

# Build iOS
flutter build ios --release --no-codesign

# Build Android AAB
flutter build appbundle --release

# Build Android APK
flutter build apk --release

# Check version
grep version pubspec.yaml
```

---

## 📱 Tester Instructions

### iOS (TestFlight)

**For Testers:**
```
1. Install TestFlight app from App Store
2. Check email for invitation
3. Tap "View in TestFlight" in email
4. Accept invitation
5. Install SpendPal
6. Provide feedback via TestFlight
```

**Share this link:** https://testflight.apple.com/join/YOUR_CODE

### Android (Google Play)

**For Testers:**
```
1. Ensure Google Play account matches invited email
2. Open opt-in link on Android device
3. Accept invitation to join beta
4. Download SpendPal from Play Store
5. Provide feedback via Play Store
```

**Share this link:** (Get from Play Console → Testing → Testers → Opt-in URL)

---

## 🐛 Troubleshooting

### iOS Build Issues

**Problem: "Code signing failed"**
```
Solution:
1. Xcode → Preferences → Accounts → Download Manual Profiles
2. Clean build folder: Product → Clean Build Folder
3. Verify team is selected in Signing & Capabilities
```

**Problem: "Archive failed"**
```
Solution:
1. flutter clean && cd ios && pod install
2. Open Runner.xcworkspace (NOT .xcodeproj)
3. Select "Any iOS Device (arm64)"
4. Try archiving again
```

### Android Build Issues

**Problem: "Signing config not found"**
```
Solution:
1. Verify android/key.properties exists
2. Check file paths are absolute
3. Verify passwords are correct
4. See GOOGLE_PLAY_CONSOLE_GUIDE.md Step 2
```

**Problem: "Version code already exists"**
```
Solution:
1. Increment build number:
   ./scripts/increment-version.sh build
2. Rebuild:
   flutter build appbundle --release
```

### Common Issues

**Problem: "App not compatible with any devices"**
```
Solution:
- Check minSdk in Android (should be >= 21)
- Check iOS deployment target (should be >= 12.0)
- Review permissions in manifests
```

---

## 📚 Full Documentation

- **iOS TestFlight:** `.claude/APP_STORE_TESTFLIGHT_GUIDE.md`
- **Android Play Console:** `.claude/GOOGLE_PLAY_CONSOLE_GUIDE.md`
- **Bug Workflow:** `.claude/BUG_WORKFLOW.md`
- **In-App Bug Reporting:** `.claude/IN_APP_BUG_REPORTING.md`

---

## ✅ Pre-Launch Checklist

### iOS
- [ ] Apple Developer account active
- [ ] App created in App Store Connect
- [ ] Bundle ID matches in Xcode and App Store Connect
- [ ] Signing configured in Xcode
- [ ] App icon added (1024x1024)
- [ ] Build archives successfully
- [ ] TestFlight internal group created
- [ ] Testers added and invited

### Android
- [ ] Google Play Console account active
- [ ] Upload keystore generated and backed up
- [ ] key.properties created and in .gitignore
- [ ] Package name changed from com.example.spendpal
- [ ] google-services.json updated
- [ ] App listing completed
- [ ] Screenshots and graphics added
- [ ] AAB builds successfully
- [ ] Internal testing track created
- [ ] Testers added and link shared

---

## 🎯 Success Metrics

Track these in dashboards:

**iOS (App Store Connect):**
- Crash-free rate (target: >99%)
- Installs/invitations sent
- Sessions per user
- Feedback count

**Android (Play Console):**
- Crash-free rate (target: >99%)
- ANR rate (target: <0.5%)
- Install/uninstall rate
- Pre-launch report issues

---

## 🔄 Update Cycle

**Recommended Cadence:**
```
Weekly for beta:
- Monday: Increment version
- Tuesday: Build & upload both platforms
- Wednesday-Friday: Monitor feedback/crashes
- Weekend: Fix critical bugs

Every 2 weeks for production:
- After 2 beta cycles, promote to production
- Gradual rollout over 1 week
```

---

## 🆘 Getting Help

**iOS Issues:**
- Apple Developer Forums: https://developer.apple.com/forums/
- App Store Connect Help: https://developer.apple.com/support/app-store-connect/
- Flutter iOS Docs: https://docs.flutter.dev/deployment/ios

**Android Issues:**
- Android Developers: https://developer.android.com/distribute
- Play Console Help: https://support.google.com/googleplay/android-developer/
- Flutter Android Docs: https://docs.flutter.dev/deployment/android

**General:**
- Flutter GitHub: https://github.com/flutter/flutter/issues
- Stack Overflow: Tag [flutter], [testflight], [google-play]

---

## 🎉 You're Ready!

Follow this guide to get your app to testers quickly. For detailed instructions and advanced topics, refer to the full platform-specific guides.

**Remember:**
- Start with internal testing
- Increment versions properly
- Monitor crashes and feedback
- Respond to testers
- Keep documentation updated

Good luck with your beta launch! 🚀
