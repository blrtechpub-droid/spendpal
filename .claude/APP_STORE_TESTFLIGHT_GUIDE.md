# App Store Connect & TestFlight Setup Guide

Complete guide to set up TestFlight beta testing for SpendPal on iOS.

---

## Current Configuration

- **App Name:** Spendpal
- **Bundle Identifier:** (Needs to be set in Xcode)
- **Version:** 1.0.0 (Build 1)
- **Minimum iOS Version:** Check in Xcode project settings
- **Features:** Google Sign-In, Camera, Photo Library

---

## Prerequisites

### 1. Apple Developer Account
- Enroll in Apple Developer Program ($99/year)
- URL: https://developer.apple.com/programs/
- Sign in with your Apple ID

### 2. Development Tools
- Xcode (latest version)
- macOS with latest updates
- Valid development certificate

---

## Step 1: Create App in App Store Connect

### 1.1 Access App Store Connect
```
1. Go to https://appstoreconnect.apple.com/
2. Sign in with your Apple ID
3. Click "My Apps"
```

### 1.2 Create New App
```
1. Click the "+" button → "New App"
2. Fill in the details:
   - Platform: iOS
   - Name: SpendPal
   - Primary Language: English (U.S.)
   - Bundle ID: Select or create (e.g., com.blrtechpub.spendpal)
   - SKU: spendpal-ios (unique identifier)
   - User Access: Full Access
3. Click "Create"
```

**Important:** The Bundle ID must match what you set in Xcode.

---

## Step 2: Configure Xcode Project

### 2.1 Open Project in Xcode
```bash
cd ios
open Runner.xcworkspace  # Open workspace, NOT .xcodeproj
```

### 2.2 Configure Bundle Identifier
```
1. Select "Runner" project in left sidebar
2. Select "Runner" target
3. General tab:
   - Display Name: SpendPal
   - Bundle Identifier: com.blrtechpub.spendpal (match App Store Connect)
   - Version: 1.0.0
   - Build: 1
```

### 2.3 Set Deployment Target
```
1. In General tab:
   - Deployment Info → iOS: 13.0 or higher
2. Check "iPhone" and "iPad" if supporting both
```

### 2.4 Configure Signing
```
1. Go to "Signing & Capabilities" tab
2. Check "Automatically manage signing"
3. Select your Team from dropdown
4. Xcode will create provisioning profiles automatically
```

**For Release:**
```
1. Ensure both "Debug" and "Release" have:
   - Automatically manage signing: ✓
   - Team: Your Apple Developer Team
   - Provisioning Profile: Xcode Managed Profile
```

### 2.5 Add App Icon
```
1. Open Assets.xcassets in Xcode
2. Click "AppIcon"
3. Drag your app icons to appropriate slots:
   - 1024x1024 (App Store)
   - Various sizes for different devices
```

**Icon Requirements:**
- PNG format
- No transparency
- Square images
- Sizes: 20, 29, 40, 58, 60, 76, 80, 87, 120, 152, 167, 180, 1024px

---

## Step 3: Build Archive

### 3.1 Clean Build
```bash
cd /path/to/spendpal
flutter clean
flutter pub get
cd ios
pod install  # If using CocoaPods
```

### 3.2 Build iOS Release
```bash
flutter build ios --release
```

### 3.3 Create Archive in Xcode
```
1. Open Runner.xcworkspace in Xcode
2. Select "Any iOS Device (arm64)" as build destination
3. Product menu → Archive
4. Wait for archive to complete
5. Organizer window opens automatically
```

**Alternative: Command Line Archive**
```bash
xcodebuild -workspace ios/Runner.xcworkspace \
  -scheme Runner \
  -configuration Release \
  -archivePath build/Runner.xcarchive \
  archive
```

---

## Step 4: Upload to App Store Connect

### 4.1 Validate Archive
```
1. In Organizer window:
   - Select your archive
   - Click "Validate App"
   - Select your distribution certificate
   - Click "Validate"
   - Fix any errors or warnings
```

### 4.2 Distribute Archive
```
1. Click "Distribute App"
2. Select "App Store Connect"
3. Click "Upload"
4. Select options:
   - ✓ Upload your app's symbols
   - ✓ Manage Version and Build Number (optional)
5. Select distribution certificate
6. Review and click "Upload"
```

### 4.3 Monitor Upload
```
- Upload progress shown in Xcode
- Can take 5-30 minutes
- Check email for confirmation
```

---

## Step 5: Configure TestFlight

### 5.1 Wait for Processing
```
1. Go to App Store Connect → My Apps → SpendPal
2. TestFlight tab
3. Wait for "Processing" to complete (10-30 minutes)
4. You'll receive email when ready
```

### 5.2 Add Test Information
```
1. In TestFlight tab:
   - Click on your build
   - Add "What to Test" notes
   - Add beta app description
   - Add feedback email
   - Add marketing URL (optional)
```

### 5.3 Export Compliance
```
If prompted about encryption:
- Does your app use encryption?
  - If only HTTPS: Select "No"
  - If using additional encryption: Select "Yes" and provide details
```

---

## Step 6: Add Beta Testers

### 6.1 Internal Testing (Apple ID Required)
```
1. TestFlight → Internal Testing → "+" button
2. Create a group (e.g., "Internal Team")
3. Add testers:
   - Click "Add Testers to Group"
   - Enter email addresses (must have Apple ID)
   - Testers get email invitation
```

**Limits:** Up to 100 internal testers

### 6.2 External Testing (Beta App Review Required)
```
1. TestFlight → External Testing → "+" button
2. Create a group (e.g., "Beta Testers")
3. Add build to test
4. Fill in test information
5. Submit for Beta App Review
6. Wait for approval (1-2 days)
7. Add testers via email or public link
```

**Limits:** Up to 10,000 external testers

### 6.3 Public Link (Optional)
```
1. In External Testing group
2. Enable "Public Link"
3. Share link with beta testers
4. Anyone with link can join (up to limit)
```

---

## Step 7: Distribute to Testers

### 7.1 Send Invitations
```
Testers receive email with:
- Download link for TestFlight app
- Invitation code
- Instructions to install
```

### 7.2 Tester Instructions
```
1. Install TestFlight app from App Store
2. Open invitation email on iOS device
3. Tap "View in TestFlight"
4. Accept invitation
5. Install SpendPal beta
```

---

## Step 8: Manage Feedback

### 8.1 Monitor Crashes
```
1. App Store Connect → My Apps → SpendPal
2. TestFlight → iOS Builds → Select build
3. Crashes tab shows crash reports
4. Download crash logs for debugging
```

### 8.2 Collect Feedback
```
Testers can send feedback via:
- Screenshot → Share → TestFlight
- Shake device → Send Beta Feedback
```

**View feedback:**
```
TestFlight → Feedback
- Read tester comments
- View screenshots
- See device/OS info
```

---

## Updating Beta Builds

### Update Process
```
1. Update version or build number in pubspec.yaml:
   version: 1.0.0+2  # Increment build number

2. Build new release:
   flutter build ios --release

3. Archive in Xcode (Step 3.3)

4. Upload to App Store Connect (Step 4)

5. Add to TestFlight groups:
   - TestFlight → Select build
   - Add to existing groups
   - Testers auto-notified of update
```

---

## Troubleshooting

### Issue: Archive Fails
**Solutions:**
```
1. Clean build folder:
   - Xcode → Product → Clean Build Folder
   - flutter clean && cd ios && pod install

2. Check signing:
   - Verify team selected
   - Ensure valid certificates

3. Update pods:
   - cd ios && pod update && pod install
```

### Issue: Upload Fails
**Solutions:**
```
1. Check application loader logs
2. Verify Bundle ID matches
3. Check Info.plist for errors
4. Ensure version/build incremented
```

### Issue: Processing Stuck
**Solutions:**
```
1. Wait 1-2 hours
2. Check email for rejection notice
3. Contact Apple Developer Support if stuck >24 hours
```

### Issue: Beta App Review Rejected
**Solutions:**
```
1. Read rejection email carefully
2. Fix issues mentioned
3. Update build and resubmit
4. Common issues:
   - Missing test account
   - Incomplete features
   - Crashes on launch
```

---

## Best Practices

### 1. Version Numbering
```yaml
# pubspec.yaml
version: MAJOR.MINOR.PATCH+BUILD

Examples:
- First beta: 1.0.0+1
- Bug fix: 1.0.0+2
- New feature: 1.0.1+1
- Breaking change: 1.1.0+1
```

### 2. Release Notes
```
Always include in "What to Test":
- New features added
- Bugs fixed
- Known issues
- Specific test scenarios
```

### 3. Tester Management
```
- Create multiple groups for different test phases
- Remove inactive testers
- Track feedback and respond
- Keep testers updated via email
```

### 4. Crash Reporting
```
- Enable symbolication (upload symbols)
- Check crashes daily
- Prioritize fixing crash bugs
- Test on multiple iOS versions
```

---

## Automation with Fastlane (Advanced)

### Install Fastlane
```bash
sudo gem install fastlane
cd ios
fastlane init
```

### Configure Fastfile
```ruby
# ios/fastlane/Fastfile
default_platform(:ios)

platform :ios do
  desc "Push a new beta build to TestFlight"
  lane :beta do
    # Build
    build_app(
      workspace: "Runner.xcworkspace",
      scheme: "Runner",
      export_method: "app-store"
    )

    # Upload to TestFlight
    upload_to_testflight(
      skip_waiting_for_build_processing: true
    )
  end
end
```

### Run Fastlane
```bash
cd ios
fastlane beta
```

---

## CI/CD Integration

### GitHub Actions Example
```yaml
# .github/workflows/ios-testflight.yml
name: iOS TestFlight Deploy

on:
  push:
    tags:
      - 'v*'

jobs:
  deploy:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3

      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.35.4'

      - name: Install dependencies
        run: flutter pub get

      - name: Build iOS
        run: flutter build ios --release --no-codesign

      - name: Deploy to TestFlight
        run: |
          cd ios
          fastlane beta
        env:
          FASTLANE_USER: ${{ secrets.APPLE_ID }}
          FASTLANE_PASSWORD: ${{ secrets.APPLE_PASSWORD }}
```

---

## Checklist

### Before First Upload
- [ ] Apple Developer account enrolled
- [ ] App created in App Store Connect
- [ ] Bundle ID configured in Xcode
- [ ] Signing certificates configured
- [ ] App icon added (1024x1024 required)
- [ ] Version set in pubspec.yaml
- [ ] Info.plist permissions configured
- [ ] Build succeeds in release mode

### Before Each Upload
- [ ] Version/build number incremented
- [ ] App tested on physical device
- [ ] No critical bugs
- [ ] Release notes prepared
- [ ] Archive validates successfully

### After Upload
- [ ] Processing completes
- [ ] Export compliance submitted
- [ ] Testers added to groups
- [ ] "What to Test" filled out
- [ ] Email notifications sent

---

## Useful Commands

```bash
# Check Flutter/iOS setup
flutter doctor

# Clean build
flutter clean && cd ios && pod install

# Build release
flutter build ios --release

# Check current version
grep version pubspec.yaml

# Open Xcode workspace
open ios/Runner.xcworkspace

# List archives
xcodebuild -list -project ios/Runner.xcodeproj

# Export archive (if already created)
xcodebuild -exportArchive \
  -archivePath build/Runner.xcarchive \
  -exportPath build/ios \
  -exportOptionsPlist ios/ExportOptions.plist
```

---

## Resources

- **App Store Connect:** https://appstoreconnect.apple.com/
- **TestFlight Documentation:** https://developer.apple.com/testflight/
- **Human Interface Guidelines:** https://developer.apple.com/design/human-interface-guidelines/
- **App Review Guidelines:** https://developer.apple.com/app-store/review/guidelines/
- **Fastlane Docs:** https://docs.fastlane.tools/
- **Flutter iOS Deployment:** https://docs.flutter.dev/deployment/ios

---

## Support

If you encounter issues:
1. Check Apple Developer Forums
2. Review App Store Connect Help
3. Contact Apple Developer Support
4. Check Flutter GitHub issues

---

**Next Steps:**
After TestFlight is set up, proceed with Google Play Console setup for Android testing.
