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

## Getting Started

### Prerequisites
- Flutter SDK (3.35.4 or higher)
- Firebase project setup
- iOS/Android development environment

### Installation

1. Clone the repository:
```bash
git clone <your-repo-url>
cd spendpal
```

2. Install dependencies:
```bash
flutter pub get
```

3. Configure Firebase:
   - Add your `google-services.json` to `android/app/`
   - Add your `GoogleService-Info.plist` to `ios/Runner/`
   - Update `lib/firebase_options.dart` with your Firebase config

4. Deploy Firestore security rules:
```bash
firebase deploy --only firestore:rules
```

5. Run the app:
```bash
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
