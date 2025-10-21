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
