# In-App Bug Reporting → GitHub Integration

This document describes the in-app bug reporting feature and how it integrates with GitHub Issues.

## Overview

Users can report bugs directly from the SpendPal mobile app through the Account tab. Bug reports are stored in Firestore and can be synced to GitHub Issues using a slash command.

---

## User Flow

### 1. Reporting a Bug (User Side)

1. User opens **Account tab** in the app
2. Taps **"Report a Bug"** under Help & Support section
3. Fills out the bug report form:
   - **Title** (required): Brief description
   - **Description** (required): What happened vs expected
   - **Steps to Reproduce** (optional): Detailed steps
   - **Priority**: Low, Medium, High, Critical
   - **Platform**: Android, iOS, Web, All
4. Taps **"Submit Bug Report"**
5. Bug is saved to Firestore with status `'pending'`
6. User sees success message

### 2. Syncing to GitHub (Developer Side)

Use the slash command to sync pending bug reports:

```
/sync-bugs
```

This will:
- Fetch all bug reports with status `'pending'` from Firestore
- Create GitHub issues for each bug
- Update Firestore records with GitHub issue number and status `'synced'`

---

## Architecture

### Firestore Collection: `bugReports`

Each bug report document contains:

```javascript
{
  title: "App crashes when adding expense",
  description: "The app crashes immediately...",
  stepsToReproduce: "1. Go to Add Expense\n2. Click Save\n3. See crash",
  priority: "High", // Low, Medium, High, Critical
  platform: "Android", // Android, iOS, Web, All
  status: "pending", // pending, synced, closed
  reportedBy: "uid123",
  reportedByName: "John Doe",
  reportedByEmail: "john@example.com",
  createdAt: Timestamp,
  githubIssueNumber: 42, // null until synced
  syncedAt: Timestamp // null until synced
}
```

### Firestore Security Rules

```javascript
match /bugReports/{reportId} {
  // Users can read their own bug reports
  allow read: if isAuthenticated() &&
    resource.data.reportedBy == request.auth.uid;

  // Users can create bug reports
  allow create: if isAuthenticated() &&
    request.resource.data.reportedBy == request.auth.uid &&
    request.resource.data.status == 'pending';

  // No updates or deletes by users
  allow update, delete: if false;
}
```

**Note:** Updates are blocked for users. System/admin updates to sync status need to be done via Firebase Admin SDK or server-side operations.

---

## Implementation Details

### Screen: `ReportBugScreen`

**Location:** `lib/screens/account/report_bug_screen.dart`

**Features:**
- Form validation (title and description required)
- Priority selector with color coding
- Platform selector with icons
- Loading state during submission
- Success/error feedback

**Navigation:**
From `account_screen.dart` → Tap "Report a Bug" → Opens `ReportBugScreen`

---

## Syncing to GitHub

### Manual Sync (Current Implementation)

Use the `/sync-bugs` slash command:

```
/sync-bugs
```

**What it does:**
1. Queries Firestore for bug reports with `status: 'pending'`
2. For each bug report:
   - Formats as GitHub issue with all details
   - Adds labels: `bug`, `from-app`, `priority:X`, `platform`
   - Creates issue using `gh issue create`
   - Updates Firestore document with issue number and status

**GitHub Issue Format:**
```markdown
## Description
[User's description]

## Steps to Reproduce
[User's steps or "Not provided"]

## Platform
[Android/iOS/Web/All]

## Priority
[Low/Medium/High/Critical]

## Reported By
- Name: John Doe
- Email: john@example.com
- Date: 2024-01-15 10:30 AM

---
*This issue was automatically created from an in-app bug report*
```

**Labels Applied:**
- `bug` - Always added
- `from-app` - Identifies in-app reports
- `priority:low`, `priority:medium`, `priority:high`, `priority:critical`
- `android`, `ios`, `web` - Platform-specific

---

### Automated Sync (Future Enhancement)

You can create a Firebase Cloud Function to automatically sync bug reports:

**`functions/index.js`:**
```javascript
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const { Octokit } = require('@octokit/rest');

admin.initializeApp();

exports.syncBugToGitHub = functions.firestore
  .document('bugReports/{reportId}')
  .onCreate(async (snap, context) => {
    const bugData = snap.data();

    // Create GitHub issue
    const octokit = new Octokit({ auth: functions.config().github.token });

    const issue = await octokit.issues.create({
      owner: 'blrtechpub-droid',
      repo: 'spendpal',
      title: `[BUG] [${bugData.platform}] ${bugData.title}`,
      body: formatIssueBody(bugData),
      labels: [
        'bug',
        'from-app',
        `priority:${bugData.priority.toLowerCase()}`,
        bugData.platform.toLowerCase()
      ]
    });

    // Update Firestore
    await snap.ref.update({
      status: 'synced',
      githubIssueNumber: issue.data.number,
      syncedAt: admin.firestore.FieldValue.serverTimestamp()
    });
  });
```

**Setup:**
```bash
# Install dependencies
cd functions
npm install @octokit/rest

# Set GitHub token
firebase functions:config:set github.token="YOUR_GITHUB_PAT"

# Deploy function
firebase deploy --only functions
```

---

## Usage Examples

### Example 1: User Reports a Bug

**User action:**
1. Opens Account → Report a Bug
2. Fills form:
   - Title: "Group invitations not showing"
   - Description: "When I'm invited to a group, no notification appears"
   - Steps: "1. Have friend invite you\n2. Check notifications\n3. Nothing shows"
   - Priority: High
   - Platform: Android
3. Submits

**Result:**
- Bug saved in Firestore with status `'pending'`
- User sees "Bug report submitted successfully!"

### Example 2: Developer Syncs Bugs

**Developer action:**
```
/sync-bugs
```

**Claude's response:**
```
Syncing pending bug reports to GitHub...

Found 3 pending bug reports:
1. "Group invitations not showing" (High, Android)
2. "Balance calculation wrong" (Medium, All)
3. "App slow on iOS 14" (Low, iOS)

Creating GitHub issues...
✓ Created issue #45: Group invitations not showing
✓ Created issue #46: Balance calculation wrong
✓ Created issue #47: App slow on iOS 14

Successfully synced 3 bug reports to GitHub.
Updated Firestore records with issue numbers.
```

---

## Monitoring & Management

### View All Bug Reports

Use Firestore console or Firebase CLI:

```bash
firebase firestore:export gs://your-bucket/bugs
```

### Check Sync Status

Query Firestore for pending bugs:
```javascript
db.collection('bugReports')
  .where('status', '==', 'pending')
  .get()
```

### Close Synced Bugs

After fixing and deploying:

```bash
# Close GitHub issue
gh issue close 45 --comment "Fixed in v1.2.0"

# Optionally update Firestore
# (manually or via script)
```

---

## Best Practices

### For Users
1. **Be specific** - Provide clear titles and descriptions
2. **Include steps** - Help developers reproduce the bug
3. **Choose correct platform** - Specify where you saw the issue
4. **Set appropriate priority** - Be honest about severity

### For Developers
1. **Sync regularly** - Run `/sync-bugs` daily or after releases
2. **Triage quickly** - Review new issues promptly
3. **Respond to users** - Consider adding user notification when bug is fixed
4. **Keep Firestore clean** - Archive old/closed bug reports periodically

---

## Security Considerations

### Firestore Rules
- Users can only read their own bug reports
- Users cannot update or delete bug reports
- All updates done server-side

### GitHub Token
- Store GitHub Personal Access Token securely
- Use Firebase Functions config or environment variables
- Never commit tokens to code

### User Data
- Bug reports include user email/name
- Ensure GDPR/privacy compliance
- Allow users to request data deletion

---

## Troubleshooting

### Issue: Bug report not submitting
**Solution:**
- Check Firestore rules are deployed
- Verify user is authenticated
- Check network connection
- Review browser/app console for errors

### Issue: Sync command not creating GitHub issues
**Solution:**
- Verify GitHub CLI is authenticated: `gh auth status`
- Check repository access permissions
- Ensure bug reports exist with status 'pending'
- Review GitHub API rate limits

### Issue: Firestore update fails during sync
**Solution:**
- Use Firebase Admin SDK for server-side updates
- Security rules block client-side updates to prevent tampering

---

## Future Enhancements

1. **Auto-sync with Cloud Function**
   - Instant GitHub issue creation
   - No manual `/sync-bugs` needed

2. **User Notifications**
   - Notify user when bug is fixed
   - Show GitHub issue link in app

3. **Bug Report History**
   - Let users view their submitted bugs
   - Show fix status and progress

4. **Attachments**
   - Allow screenshot uploads
   - Store in Firebase Storage
   - Attach to GitHub issues

5. **Duplicate Detection**
   - Check for similar issues before creating
   - Suggest existing issues to user

6. **Analytics**
   - Track most common bugs
   - Monitor bug submission trends
   - Identify problematic features

---

## Related Files

- `lib/screens/account/report_bug_screen.dart` - Bug report UI
- `lib/screens/account/account_screen.dart` - Account tab with link to bug reporting
- `firestore.rules` - Security rules for bugReports collection
- `.claude/commands/sync-bugs.md` - Slash command to sync bugs
- `.claude/BUG_WORKFLOW.md` - Complete bug workflow documentation

---

## API Reference

### Firestore Collection

**Path:** `/bugReports/{reportId}`

**Create Bug Report:**
```dart
await FirebaseFirestore.instance.collection('bugReports').add({
  'title': 'Bug title',
  'description': 'Bug description',
  'stepsToReproduce': 'Steps...',
  'priority': 'High',
  'platform': 'Android',
  'status': 'pending',
  'reportedBy': currentUser.uid,
  'reportedByName': userName,
  'reportedByEmail': userEmail,
  'createdAt': FieldValue.serverTimestamp(),
  'githubIssueNumber': null,
});
```

### GitHub CLI

**Create Issue:**
```bash
gh issue create \
  --title "[BUG] [Android] Title" \
  --body "Issue description" \
  --label "bug,from-app,priority:high,android"
```

**List Issues:**
```bash
gh issue list --label "from-app" --state open
```

---

## Conclusion

The in-app bug reporting feature provides a seamless way for users to report issues directly from SpendPal. Combined with the GitHub integration, it creates an efficient bug tracking workflow that keeps development organized and responsive to user feedback.
