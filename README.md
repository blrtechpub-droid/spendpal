# SpendPal

A Flutter expense tracking application with social features for splitting expenses among friends and groups.

## Features

- 👥 **Friend Management**: Send and accept friend requests with custom nicknames
- 👨‍👩‍👧‍👦 **Group Expenses**: Create groups and split expenses with multiple people
- 📊 **Balance Tracking**: Track who owes whom across all expenses
- 📱 **Real-time Updates**: Live updates using Firebase Firestore
- 🔐 **Secure**: Firebase authentication with Google Sign-In
- 🎨 **Modern UI**: Clean, intuitive interface

## Architecture

### Tech Stack
- **Framework**: Flutter
- **Backend**: Firebase (Auth, Firestore)
- **State Management**: StatefulWidget with StreamBuilder
- **Authentication**: Firebase Auth (Google Sign-In)

### Key Features Implementation

#### Friend Request System
- Send friend requests with optional nicknames
- Accept/reject requests with two-sided consent
- Each user maintains their own local nicknames for friends
- Real-time notifications for pending requests

#### Group Management
- Create and manage expense groups
- Invite friends to groups via invitations
- Transfer group ownership when leaving
- Track group-specific balances

#### Expense Tracking
- Split expenses equally or custom amounts
- Track expenses for individuals or groups
- Calculate balances automatically
- View transaction history

## Getting Started - Complete Setup Guide

Follow these steps to set up the development environment on a new computer.

### Prerequisites

**Install the following before starting:**

1. **Flutter SDK** (v3.35.4 or higher)
   - Download: https://docs.flutter.dev/get-started/install
   - Verify: `flutter --version`
   - Run: `flutter doctor` and resolve any issues

2. **Git**
   - macOS: Pre-installed or `brew install git`
   - Verify: `git --version`

3. **Node.js** (v18 or higher - for Firebase Functions)
   - Download: https://nodejs.org/
   - Verify: `node --version` and `npm --version`

4. **Firebase CLI**
   ```bash
   npm install -g firebase-tools
   firebase --version
   ```

5. **IDE** (Choose one)
   - VS Code: https://code.visualstudio.com/
   - Android Studio: https://developer.android.com/studio

6. **Platform-specific tools:**
   - **iOS Development (macOS only):**
     - Xcode from Mac App Store
     - CocoaPods: `sudo gem install cocoapods`
   - **Android Development:**
     - Android Studio with SDK
     - Accept licenses: `flutter doctor --android-licenses`

### Step-by-Step Installation

#### 1. Clone the Repository

```bash
git clone https://github.com/blrtechpub-droid/spendpal.git
cd spendpal
```

#### 2. Download Firebase Configuration Files

**These files are NOT in the repository (gitignored for security).**

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project (or create a new one)
3. Go to **Project Settings** (⚙️ icon)

**For Android:**
- Click **Add app** → **Android** (or select existing Android app)
- Download `google-services.json`
- Place it in: `android/app/google-services.json`

**For iOS:**
- Click **Add app** → **iOS** (or select existing iOS app)
- Download `GoogleService-Info.plist`
- Place it in: `ios/Runner/GoogleService-Info.plist`

**For macOS (if building for macOS):**
- Download `GoogleService-Info.plist` for macOS
- Place it in: `macos/Runner/GoogleService-Info.plist`

#### 3. Install Flutter Dependencies

```bash
flutter pub get
```

#### 4. Set Up Firebase

**Login to Firebase:**
```bash
firebase login
```

**Select your Firebase project:**
```bash
firebase use --add
# Select your project from the list
# Give it an alias (e.g., "default" or "dev")
```

#### 5. Set Up Firebase Functions

```bash
cd functions
npm install
cd ..
```

#### 6. Deploy Firestore Security Rules

```bash
firebase deploy --only firestore:rules
```

**Optional:** Deploy Storage rules if you're using Firebase Storage:
```bash
firebase deploy --only storage:rules
```

#### 7. iOS-Specific Setup (macOS only)

```bash
cd ios
pod install
cd ..
```

#### 8. Run the Application

**List available devices:**
```bash
flutter devices
```

**Run on a specific device:**
```bash
# iOS Simulator (macOS only)
flutter run -d "iPhone 15 Pro"

# Android Emulator
flutter run -d emulator-5554

# Physical device
flutter run -d <device-id>
```

**Or simply:**
```bash
flutter run
# Select device from the list
```

### Troubleshooting

#### "google-services.json not found"
- Make sure you downloaded the file from Firebase Console
- Check it's in `android/app/google-services.json`

#### "GoogleService-Info.plist not found"
- Download from Firebase Console
- Place in `ios/Runner/GoogleService-Info.plist`

#### Pod install fails (iOS)
```bash
cd ios
rm -rf Pods Podfile.lock
pod repo update
pod install
cd ..
```

#### Firebase login issues
```bash
firebase logout
firebase login --reauth
```

#### Flutter doctor shows issues
```bash
flutter doctor -v
# Follow the instructions for each issue
```

#### Build fails on first run
```bash
flutter clean
flutter pub get
flutter run
```

### Firebase Functions Deployment (Optional)

To deploy Firebase Functions:

```bash
firebase deploy --only functions
```

### Environment Setup Verification

Run these commands to verify everything is set up correctly:

```bash
# 1. Flutter is working
flutter doctor -v

# 2. Firebase is configured
firebase projects:list

# 3. Dependencies are installed
flutter pub get
cd functions && npm list && cd ..

# 4. Firebase config files exist
ls -la android/app/google-services.json
ls -la ios/Runner/GoogleService-Info.plist

# 5. Git is tracking correctly
git status
```

### IDE Setup Recommendations

**VS Code Extensions:**
- Flutter
- Dart
- Firebase Explorer
- GitLens

**Android Studio Plugins:**
- Flutter
- Dart
- Firebase

### First Run Checklist

- [ ] Flutter SDK installed and working (`flutter doctor`)
- [ ] Repository cloned
- [ ] Firebase config files downloaded and placed correctly
- [ ] `flutter pub get` completed successfully
- [ ] Firebase CLI logged in (`firebase login`)
- [ ] Firebase project selected (`firebase use`)
- [ ] Firebase Functions dependencies installed
- [ ] Firestore rules deployed
- [ ] iOS pods installed (macOS only)
- [ ] App runs successfully (`flutter run`)

### Quick Start Summary

```bash
# For experienced developers - quick setup:
git clone https://github.com/blrtechpub-droid/spendpal.git
cd spendpal
# Download Firebase config files from Console
flutter pub get
cd functions && npm install && cd ..
firebase login
firebase use --add
firebase deploy --only firestore:rules
cd ios && pod install && cd ..  # macOS only
flutter run
```

## Project Structure

```
lib/
├── models/               # Data models
│   ├── user_model.dart
│   ├── expense_model.dart
│   ├── group_model.dart
│   ├── friend_request_model.dart
│   └── group_invitation_model.dart
├── services/            # Business logic
│   ├── auth_service.dart
│   ├── friend_request_service.dart
│   ├── group_invitation_service.dart
│   └── balance_service.dart
├── screens/             # UI screens
│   ├── login/
│   ├── home/
│   ├── friends/
│   ├── groups/
│   ├── expense/
│   └── requests/
├── widgets/             # Reusable widgets
└── theme/              # App theme
```

## Firestore Structure

```
users/
  {uid}/
    - name, email, phone, photoURL
    - friends: Map<String, String> (uid -> nickname)

groups/
  {groupId}/
    - name, type, members, createdBy

expenses/
  {expenseId}/
    - title, amount, paidBy, splitWith, splitDetails

friendRequests/
  {requestId}/
    - fromUserId, toUserId, status, nickname

groupInvitations/
  {invitationId}/
    - groupId, invitedBy, invitedUserId, status
```

## Development

### Running Tests
```bash
flutter test
```

### Code Analysis
```bash
flutter analyze
```

### Clean Build
```bash
flutter clean
flutter pub get
```

## Useful Commands Reference

### Claude Code Commands

**Custom Bug Management Commands:**
```bash
/list-bugs          # List all open bugs from GitHub issues
/fix-bug <number>   # Automatically fix a GitHub issue by number
/report-bug         # Create a new GitHub issue for a bug
/sync-bugs          # Sync bug reports from Firestore to GitHub Issues
```

**Built-in Commands:**
- `/help` - Get help with using Claude Code
- `/clear` - Clear conversation history
- Type `@` - Reference files, folders, or URLs

### Flutter Development Commands

**Running the App:**
```bash
flutter run                          # Run on default device
flutter run -d <device_id>           # Run on specific device
flutter run --release                # Run in release mode
flutter devices                      # List available devices
```

**Building:**
```bash
flutter build apk                    # Build APK for testing
flutter build apk --release          # Build release APK
flutter build appbundle              # Build app bundle for Play Store
flutter build appbundle --release    # Build release app bundle
flutter build ios                    # Build for iOS
flutter build ios --release          # Build release iOS
```

**Testing & Analysis:**
```bash
flutter test                         # Run all tests
flutter test test/widget_test.dart   # Run specific test file
flutter analyze                      # Analyze code for issues
flutter pub outdated                 # Check for dependency updates
flutter doctor                       # Check Flutter setup
flutter doctor -v                    # Verbose Flutter setup check
```

**Dependencies:**
```bash
flutter pub get                      # Install dependencies
flutter pub upgrade                  # Upgrade dependencies
flutter pub outdated                 # Check for outdated packages
```

**Maintenance:**
```bash
flutter clean                        # Clean build artifacts
flutter clean && flutter pub get     # Clean and reinstall
rm -rf build/                        # Remove build directory
```

### Firebase Commands

**Authentication & Setup:**
```bash
firebase login                       # Login to Firebase
firebase logout                      # Logout from Firebase
firebase use --add                   # Select Firebase project
firebase projects:list               # List all Firebase projects
```

**Deployment:**
```bash
firebase deploy                      # Deploy everything
firebase deploy --only firestore:rules    # Deploy Firestore rules
firebase deploy --only storage:rules      # Deploy Storage rules
firebase deploy --only functions          # Deploy Functions only
```

**Monitoring:**
```bash
firebase functions:log -n 10         # View last 10 function logs
firebase functions:log -n 20         # View last 20 function logs
firebase functions:log --only parseBill -n 10   # View specific function logs
```

**Functions (in functions/ directory):**
```bash
cd functions
npm install                          # Install function dependencies
npm run lint                         # Lint functions code
npm run build                        # Build functions
cd ..
```

### iOS Development (macOS only)

```bash
cd ios
pod install                          # Install CocoaPods dependencies
pod update                           # Update pods
pod repo update                      # Update pod repository
rm -rf Pods Podfile.lock && pod install   # Clean reinstall
cd ..
```

### Android Development

```bash
flutter doctor --android-licenses    # Accept Android licenses
cd android
./gradlew clean                      # Clean Android build
./gradlew assembleRelease            # Build release APK
cd ..
```

### Git Commands

```bash
git status                           # Check repository status
git add .                            # Stage all changes
git commit -m "message"              # Commit changes
git push                             # Push to remote
git pull                             # Pull latest changes
git log --oneline -10                # View last 10 commits
```

### Debugging

```bash
flutter logs                         # View app logs
flutter logs -d <device_id>          # View logs for specific device
adb logcat                           # Android device logs
adb devices                          # List Android devices
```

### App Icon Generation

```bash
flutter pub run flutter_launcher_icons:main   # Generate app icons
```

### Project Verification

```bash
# Run these to verify project setup
flutter doctor -v
firebase projects:list
ls -la android/app/google-services.json
ls -la ios/Runner/GoogleService-Info.plist
git status
```

## Recent Development Work

### Automatic Bug Reporting to GitHub

SpendPal now automatically syncs bug reports from the mobile app to GitHub Issues using Firebase Cloud Functions.

#### How It Works

When a user submits a bug report through the app (Account → Report a Bug):
1. Bug report is saved to Firestore `bugReports` collection
2. Cloud Function `syncBugToGitHub` triggers automatically
3. GitHub Issue is created with formatted details and labels
4. Firestore document is updated with issue number and sync status

#### Implementation Details

**Cloud Function Location:** `functions/src/index.ts` (lines 526-749)

**Key Features:**
- Automatic GitHub issue creation on bug submission
- Smart labeling based on priority (low/medium/high/critical) and platform (Android/iOS/Web)
- Direct HTTPS API implementation (no external dependencies)
- Firestore status tracking (pending → synced)
- Comprehensive error handling and logging

**Labels Applied:**
- `bug` - All bug reports
- `from-app` - Indicates report came from mobile app
- `priority:low|medium|high|critical` - Based on user selection
- `android|ios|web` - Platform labels

#### Setup and Configuration

**1. Create GitHub Personal Access Token:**
- Visit: https://github.com/settings/tokens/new
- Name: `SpendPal Bug Sync`
- Expiration: 90 days (recommended)
- Scope: ✅ `repo` (full control)
- See detailed guide: `.claude/GITHUB_TOKEN_SETUP_GUIDE.md`

**2. Configure Firebase:**
```bash
firebase functions:config:set github.token="YOUR_GITHUB_TOKEN"
```

**3. Deploy Cloud Function:**
```bash
cd functions
npm run build
cd ..
firebase deploy --only functions:syncBugToGitHub
```

**4. Verify Deployment:**
```bash
firebase functions:log --only syncBugToGitHub
```

#### Testing

1. Open SpendPal app
2. Navigate to Account → Report a Bug
3. Submit a test bug report
4. Check GitHub Issues: https://github.com/blrtechpub-droid/spendpal/issues
5. Verify issue was created with correct labels

#### Monitoring Commands

```bash
# View function logs
firebase functions:log --only syncBugToGitHub

# View last 20 log entries
firebase functions:log --only syncBugToGitHub -n 20

# List all deployed functions
firebase functions:list

# Check Firebase configuration
firebase functions:config:get
```

#### Documentation

- **Quick Start:** `BUG_SYNC_QUICKSTART.md`
- **Full Setup Guide:** `.claude/BUG_SYNC_SETUP.md`
- **Token Setup Guide:** `.claude/GITHUB_TOKEN_SETUP_GUIDE.md`
- **Deployment Success Log:** `DEPLOYMENT_SUCCESS.md`

#### Technical Implementation

The function uses Node.js built-in `https` module for direct GitHub API calls:

```typescript
export const syncBugToGitHub = functions.firestore
    .document('bugReports/{reportId}')
    .onCreate(async (snap, context) => {
      // Get bug data from Firestore
      const bugData = snap.data() as BugReport;

      // Create GitHub issue via HTTPS API
      const issue = await createGitHubIssue({
        token: githubToken,
        owner: 'blrtechpub-droid',
        repo: 'spendpal',
        title: `[BUG] [${platform}] ${title}`,
        body: formattedBody,
        labels: ['bug', 'from-app', 'priority:medium', 'android'],
      });

      // Update Firestore with issue number
      await snap.ref.update({
        status: 'synced',
        githubIssueNumber: issue.number,
      });
    });
```

#### Security Notes

- GitHub token stored in Firebase Functions config (not in code)
- Token has minimal permissions (repo scope only)
- Rotate token every 90 days for security
- Never commit tokens to version control

---

### Session Management System

To prevent work loss from crashes or session timeouts, the project includes a comprehensive session management system.

#### Status Tracking

**`.claude/STATUS.md`** - Live project status file that contains:
- Current active tasks
- Recently completed work
- Current build version and status
- Environment state
- Recovery instructions

This file is automatically updated and serves as Claude Code's memory across sessions.

#### Automation Tools

**`tool/update-status.sh`** - Bash script to auto-update STATUS.md
- Updates timestamp
- Captures current git branch
- Records Flutter version
- Can run manually or as git hook

**`tool/install-hooks.sh`** - Installs git pre-commit hook
- Auto-runs update-status.sh on commits
- Keeps STATUS.md always current
- Zero manual intervention needed

**Usage:**
```bash
# Install git hooks
./tool/install-hooks.sh

# Manually update status
./tool/update-status.sh

# View current status
cat .claude/STATUS.md
```

#### Session Recovery

If VS Code crashes or session times out:

1. Open `.claude/STATUS.md` to see last state
2. Resume from "Active Tasks" section
3. Check "Recent Completions" for context
4. Review "Environment" for build info

#### Documentation

**`CLAUDE.md`** - Project memory file for Claude Code
- Contains architecture overview
- Development patterns and practices
- Session management section
- Recovery protocols

**`.claude/SESSION_MANAGEMENT_QUICKSTART.md`** - Quick reference guide

---

### Play Store Release Build

**Latest Release:** v1.0.0+10

**Build Output:**
- `build/app/outputs/bundle/release/app-release.aab` (49MB)
- Production-ready Android App Bundle
- Signed and ready for Play Store upload

**Build Commands:**
```bash
# Clean previous builds
flutter clean

# Build release app bundle
flutter build appbundle --release

# Verify build
ls -lh build/app/outputs/bundle/release/
```

**Upload to Play Store:**
1. Go to Google Play Console
2. Navigate to Release → Production
3. Create new release
4. Upload `app-release.aab`
5. Complete release notes and submit

---

### Development Workflow Improvements

#### Commands Documentation
- Added comprehensive "Useful Commands Reference" section
- Includes Claude Code, Flutter, Firebase, Git commands
- Quick reference for common development tasks

#### Bug Management Slash Commands
```bash
/list-bugs        # List all open bugs from GitHub
/fix-bug <number> # Auto-fix a specific bug
/report-bug       # Create new GitHub issue
/sync-bugs        # Manual sync Firestore bugs to GitHub
```

#### iOS Simulator Quick Start
```bash
# List available iOS simulators
xcrun simctl list devices

# Launch specific simulator
open -a Simulator

# Run Flutter app on simulator
cd /Users/abhaysingh/Documents/devlopment/expenseTrackingApp/spendpal
flutter run -d <SIMULATOR_ID>
```

---

## Firebase Tools

### Clear Database (for testing)
```bash
./clear_firestore.sh
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License.

## Support

For issues and questions, please create an issue in the GitHub repository.
