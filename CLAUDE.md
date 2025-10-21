# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

SpendPal is a Flutter expense tracking application with social features for splitting expenses among friends and groups. The app uses Firebase for authentication (Google Sign-In) and Firestore for data persistence.

## Development Commands

### Running the App
```bash
# Run on connected device or emulator
flutter run

# Run on specific device
flutter run -d <device_id>

# Run in release mode
flutter run --release
```

### Building
```bash
# Build for iOS
flutter build ios

# Build for Android
flutter build apk
flutter build appbundle

# Build for web
flutter build web
```

### Testing & Analysis
```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/widget_test.dart

# Analyze code for issues
flutter analyze

# Check for dependency updates
flutter pub outdated
```

### Dependencies
```bash
# Get dependencies
flutter pub get

# Upgrade dependencies
flutter pub upgrade

# Clean build artifacts
flutter clean
```

## Architecture

### Core Data Models

**UserModel** (`lib/models/user_model.dart`)
- Represents user profile with uid, name, email, phone, photoURL
- Contains `friends` map (UID → Nickname) for social features
- Uses `fromFirestore()` factory for Firestore deserialization

**ExpenseModel** (`lib/models/expense_model.dart`)
- Tracks expenses with title, amount, date, notes, category
- `paidBy` field stores the user UID who paid
- `sharedWith` list contains UIDs of users splitting the expense
- `groupId` field links expense to a group (nullable for personal expenses)
- Uses Firestore Timestamp for date handling

**GroupModel** (`lib/models/group_model.dart`)
- Represents groups with groupId, name, type, members list
- `createdBy` and `createdAt` track group creation
- Optional `photo` field for group avatar
- `fromDocument()` factory for Firestore document mapping

**FriendRequestModel** (`lib/models/friend_request_model.dart`)
- Manages friend requests with requestId, fromUserId, toUserId
- Status: 'pending', 'accepted', 'rejected'
- Optional nickname field from sender
- Tracks createdAt and respondedAt timestamps

**GroupInvitationModel** (`lib/models/group_invitation_model.dart`)
- Manages group invitations with invitationId, groupId, invitedBy, invitedUserId
- Status: 'pending', 'accepted', 'rejected'
- Tracks createdAt and respondedAt timestamps

### Navigation Structure

The app uses named routes defined in `lib/main.dart`:
- `/login` - LoginScreen (initial route)
- `/home` - HomeScreen with bottom navigation
- `/add_expense` - AddExpenseScreen

**HomeScreen** (`lib/screens/home/home_screen.dart`)
- Bottom navigation with 4 tabs: Groups, Friends, Activity, Account
- FloatingButtons widget provides quick access to add expense and scan QR
- Manages tab switching via `_currentIndex` state

### Firebase Integration

**Authentication**
- `lib/services/auth_service.dart` - Currently contains placeholder methods for Google Sign-In and phone auth
- FirebaseAuth is initialized in `main.dart` before app starts

**Firestore Structure**
```
users/
  {uid}/
    - uid, name, email, phone, photoURL
    - friends: Map<String, String> (UID → Nickname)

groups/
  {groupId}/
    - groupId, name, type, createdBy, createdAt
    - members: List<String>
    - photo: String?

expenses/
  {expenseId}/
    - title, amount, date, notes, category
    - paidBy: String (uid)
    - splitWith: List<String> (uids)
    - splitDetails: Map<String, double> (uid → amount owed)
    - splitMethod: String ('equal', 'unequal', 'percentage', 'shares')
    - groupId: String?
    - createdAt, updatedAt: Timestamp

friendRequests/
  {requestId}/
    - fromUserId: String
    - toUserId: String
    - status: String ('pending', 'accepted', 'rejected')
    - nickname: String? (optional)
    - createdAt, respondedAt: Timestamp

groupInvitations/
  {invitationId}/
    - groupId: String
    - invitedBy: String (uid)
    - invitedUserId: String
    - status: String ('pending', 'accepted', 'rejected')
    - createdAt, respondedAt: Timestamp
```

### Key Screens

**GroupsScreen** (`lib/screens/groups/groups_screen.dart`)
- Streams groups from Firestore where current user is a member
- AppBar actions: search, create group, logout
- ListView displays group cards with name and photo

**AddExpenseScreen** (`lib/screens/expense/expense_screen.dart`)
- Form with title, amount, date picker, category dropdown, notes
- Friend selection using FilterChip widgets
- Saves expense to Firestore `expenses` collection
- Currently uses hardcoded friend UIDs ('uid1', 'uid2', 'uid3') - should be replaced with actual friend data

**LoginScreen** (`lib/screens/login/login_screen.dart`)
- Entry point for authentication flow
- Supports Google Sign-In and phone authentication
- Saves user profile to Firestore upon successful login

**AddFriendScreen** (`lib/screens/friends/add_friend_screen.dart`)
- Search users by email
- Send friend requests with optional nickname
- Uses FriendRequestService for request management
- Displays user info before sending request

**PendingRequestsScreen** (`lib/screens/requests/pending_requests_screen.dart`)
- Tabbed interface for friend requests and group invitations
- Accept/reject friend requests
- Accept/reject group invitations
- Real-time updates using StreamBuilder

**AddGroupMembersScreen** (`lib/screens/groups/add_group_members_screen.dart`)
- Select friends to invite to group
- Sends group invitations instead of directly adding members
- Excludes users who are already members
- Uses GroupInvitationService

### Services

**BalanceService** (`lib/services/balance_service.dart`)
- Calculates overall balance across all expenses
- Calculates group-specific balances
- Calculates non-group (friend-to-friend) balances
- Determines per-user balances within groups

**FriendRequestService** (`lib/services/friend_request_service.dart`)
- sendFriendRequest() - Send a friend request
- acceptFriendRequest() - Accept and add to both users' friends lists
- rejectFriendRequest() - Decline a friend request
- cancelFriendRequest() - Cancel a sent request
- getPendingReceivedRequests() - Stream of incoming requests
- getPendingSentRequests() - Stream of sent requests
- Prevents duplicate requests and validates status changes

**GroupInvitationService** (`lib/services/group_invitation_service.dart`)
- sendGroupInvitation() - Send invitation to user
- acceptGroupInvitation() - Accept and add to group members
- rejectGroupInvitation() - Decline invitation
- cancelGroupInvitation() - Cancel sent invitation
- getPendingInvitations() - Stream of user's pending invitations
- getGroupPendingInvitations() - Stream of group's pending invitations
- leaveGroup() - Remove user from group (with ownership transfer logic)

### Reusable Widgets

- `lib/widgets/custom_button.dart` - Standardized button component
- `lib/widgets/custom_card.dart` - Card layout component
- `lib/widgets/FloatingButtons.dart` - Dual floating action buttons for add expense and scan QR

## Key Development Notes

### Missing Implementations
1. AuthService methods (signInWithGoogle, signInWithPhone) are placeholders
2. FirestoreService methods are not implemented yet
3. Friend selection in AddExpenseScreen uses hardcoded UIDs
4. Account tab in HomeScreen is a Placeholder widget
5. QR code scanning route '/scan_qr' is referenced but not implemented
6. Group details route '/group_home' is referenced but not fully set up
7. Search functionality in GroupsScreen is not implemented

### Firebase Configuration
- Firebase is configured via `lib/firebase_options.dart` (generated by FlutterFire CLI)
- `firebase.json` exists in project root
- iOS and Android Firebase configurations are present

### Code Quality
- Uses `analysis_options.yaml` with `flutter_lints` package
- Currently using Flutter 3.35.4 with Dart 3.9.2

### Important Patterns
- Firestore queries use `arrayContains` for group membership
- StreamBuilder pattern for real-time data updates
- Timestamp conversion using `Timestamp.fromDate()` and `.toDate()`
- Navigator with named routes and arguments for data passing

## Friend Request and Group Invitation System

### Security & Privacy Model

SpendPal implements a Splitwise-style consent-based invitation system for adding friends and group members. This ensures users have full control over who they interact with.

### Friend Request Flow

1. **Sending Request**
   - User searches for friend by email
   - Option to add a nickname
   - Friend request created in `friendRequests` collection with status 'pending'
   - Sender cannot add friend directly

2. **Receiving Request**
   - Recipient sees request in PendingRequestsScreen
   - Can view sender's profile and proposed nickname
   - Options: Accept or Reject

3. **Accepting Request**
   - Both users added to each other's friends list
   - Request status updated to 'accepted'
   - Mutual friendship established

4. **Rejecting Request**
   - Request status updated to 'rejected'
   - No friendship established

### Group Invitation Flow

1. **Sending Invitation**
   - Group member selects friends to invite
   - Invitations created in `groupInvitations` collection
   - Status set to 'pending'
   - Cannot directly add members

2. **Receiving Invitation**
   - Invited user sees invitation in PendingRequestsScreen
   - Can view group name, inviter, and member count
   - Options: Accept or Decline

3. **Accepting Invitation**
   - User added to group's members list
   - Invitation status updated to 'accepted'
   - User can now see group and its expenses

4. **Declining Invitation**
   - Invitation status updated to 'rejected'
   - User not added to group

### Security Rules

Firestore security rules enforce the invitation system:

**friendRequests collection**:
- Users can only create requests where they are the sender
- Only sender and receiver can read the request
- Only receiver can accept/reject
- Only sender can cancel pending requests

**groupInvitations collection**:
- Only group members can send invitations
- Only invited user can accept/reject
- Only sender can cancel pending invitations
- Validates group membership before allowing invitation creation

### Key Benefits

1. **Consent-based**: All interactions require explicit consent
2. **Privacy**: Users control who sees their expense data
3. **Audit Trail**: All requests/invitations tracked with timestamps
4. **Reversible**: Users can reject/leave at any time
5. **Spam Protection**: Prevents unauthorized adds
6. **Clear Communication**: Users know who invited them and when
