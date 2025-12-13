# Automatic Bug Sync to GitHub - Setup Guide

This guide explains how to set up and deploy the automatic bug reporting system that syncs bug reports from the app to GitHub Issues.

---

## Overview

When a user reports a bug in the app (Account → Report a Bug), a Cloud Function automatically:
1. Creates a GitHub Issue with all bug details
2. Applies appropriate labels (priority, platform)
3. Updates the Firestore document with the GitHub issue number
4. Logs the sync status

---

## Prerequisites

✅ You need:
- Firebase project set up (already done)
- GitHub repository access (blrtechpub-droid/spendpal)
- GitHub Personal Access Token with repo permissions

---

## Step 1: Create GitHub Personal Access Token

### 1.1 Go to GitHub Settings

1. Visit: https://github.com/settings/tokens
2. Click **"Generate new token"** → **"Generate new token (classic)"**

### 1.2 Configure Token

**Token name:** `SpendPal Firebase Function - Bug Sync`

**Expiration:** Choose your preference (90 days recommended)

**Select scopes:**
- ✅ `repo` - Full control of private repositories
  - This includes: repo:status, repo_deployment, public_repo, repo:invite

**Note:** The `repo` scope is needed to create issues in your repository.

### 1.3 Generate and Copy Token

1. Click **"Generate token"**
2. **IMPORTANT:** Copy the token immediately (starts with `ghp_`)
3. Store it securely (you won't be able to see it again)

Example token format: `ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`

---

## Step 2: Configure Firebase Functions

### 2.1 Set GitHub Token in Firebase Config

```bash
# Navigate to project root
cd /Users/abhaysingh/Documents/devlopment/expenseTrackingApp/spendpal

# Set the GitHub token
firebase functions:config:set github.token="YOUR_GITHUB_TOKEN_HERE"
```

Replace `YOUR_GITHUB_TOKEN_HERE` with your actual token.

### 2.2 Verify Configuration

```bash
# View current config
firebase functions:config:get
```

You should see:
```json
{
  "github": {
    "token": "ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
  }
}
```

---

## Step 3: Deploy the Cloud Function

### 3.1 Build Functions

```bash
# Build TypeScript
cd functions
npm run build
cd ..
```

### 3.2 Deploy

```bash
# Deploy only the new function
firebase deploy --only functions:syncBugToGitHub
```

OR deploy all functions:

```bash
# Deploy all functions
firebase deploy --only functions
```

### 3.3 Verify Deployment

After deployment, you should see:
```
✔  functions[syncBugToGitHub(us-central1)] Successful create operation.
Function URL: https://us-central1-spendpal-app-blrtechpub.cloudfunctions.net/syncBugToGitHub
```

---

## Step 4: Test the Integration

### 4.1 Submit a Test Bug Report

1. Open SpendPal app on device/emulator
2. Go to **Account** tab
3. Tap **"Report a Bug"**
4. Fill out the form:
   - **Title:** Test bug report from automated sync
   - **Description:** Testing the automatic GitHub integration
   - **Steps:** 1. Open app\n2. Go to Account\n3. Report bug
   - **Priority:** Medium
   - **Platform:** Android
5. Submit

### 4.2 Check Cloud Function Logs

```bash
# View function logs
firebase functions:log --only syncBugToGitHub
```

You should see:
```
New bug report created: [documentId]
Bug details: { title: '...', priority: 'Medium', ... }
Creating GitHub issue...
GitHub issue created: #[number]
Issue URL: https://github.com/blrtechpub-droid/spendpal/issues/[number]
Updated Firestore document
```

### 4.3 Verify GitHub Issue Created

1. Go to: https://github.com/blrtechpub-droid/spendpal/issues
2. You should see a new issue with:
   - Title: `[BUG] [Android] Test bug report from automated sync`
   - Labels: `bug`, `from-app`, `priority:medium`, `android`
   - Body: Formatted with all bug details

### 4.4 Check Firestore Update

1. Go to Firebase Console: https://console.firebase.google.com/project/spendpal-app-blrtechpub/firestore
2. Navigate to `bugReports` collection
3. Find your test bug report
4. Verify it has:
   - `status`: "synced"
   - `githubIssueNumber`: [number]
   - `syncedAt`: [timestamp]

---

## How It Works

### Trigger

The function triggers automatically when a new document is created in the `bugReports` collection:

```typescript
export const syncBugToGitHub = functions.firestore
  .document('bugReports/{reportId}')
  .onCreate(async (snap, context) => {
    // Sync logic here
  });
```

### Process Flow

1. **User submits bug** → Firestore document created with `status: 'pending'`
2. **Cloud Function triggers** → Detects new document
3. **GitHub API call** → Creates issue with formatted body and labels
4. **Firestore update** → Sets `status: 'synced'`, adds `githubIssueNumber`
5. **Logs** → Function logs success or error

### Labels Applied

Based on bug report data:
- **Always:** `bug`, `from-app`
- **Priority:** `priority:low`, `priority:medium`, `priority:high`, `priority:critical`
- **Platform:** `android`, `ios`, `web` (or all three if "All" selected)

Example: A High priority Android bug gets labels: `bug`, `from-app`, `priority:high`, `android`

---

## Monitoring & Maintenance

### View Function Logs

```bash
# Real-time logs
firebase functions:log --only syncBugToGitHub

# Last 10 entries
firebase functions:log --only syncBugToGitHub -n 10

# Follow mode (live)
firebase functions:log --only syncBugToGitHub --follow
```

### Common Log Patterns

**Success:**
```
New bug report created: abc123
Creating GitHub issue...
GitHub issue created: #42
Updated Firestore document abc123 with issue #42
```

**Token Not Configured:**
```
GitHub token not configured!
Set it with: firebase functions:config:set github.token="YOUR_GITHUB_PAT"
```

**GitHub API Error:**
```
GitHub API Error: { status: 401, message: 'Bad credentials' }
```

### Troubleshooting

#### Issue: Function not triggering

**Check:**
1. Is function deployed? `firebase functions:list`
2. Are Firestore triggers enabled in Firebase Console?
3. Check function logs for errors

**Fix:**
```bash
firebase deploy --only functions:syncBugToGitHub
```

#### Issue: GitHub token error (401 Unauthorized)

**Cause:** Invalid or expired token

**Fix:**
1. Generate new token on GitHub
2. Update Firebase config:
   ```bash
   firebase functions:config:set github.token="NEW_TOKEN"
   firebase deploy --only functions:syncBugToGitHub
   ```

#### Issue: Permission denied creating issue

**Cause:** Token doesn't have `repo` scope

**Fix:**
1. Go to GitHub → Settings → Tokens
2. Edit the token
3. Ensure `repo` scope is checked
4. Save and update Firebase config with new token

#### Issue: Labels not found

**Cause:** Labels don't exist in GitHub repository

**Fix:**
Create the labels in GitHub:
1. Go to: https://github.com/blrtechpub-droid/spendpal/labels
2. Create these labels:
   - `bug` (color: #d73a4a)
   - `from-app` (color: #0075ca)
   - `priority:low` (color: #28a745)
   - `priority:medium` (color: #ffc107)
   - `priority:high` (color: #fd7e14)
   - `priority:critical` (color: #dc3545)
   - `android` (color: #3ddc84)
   - `ios` (color: #999999)
   - `web` (color: #61dafb)

---

## Security Best Practices

### Token Security

1. **Never commit the token** to version control
2. **Use Firebase config** (not environment variables in code)
3. **Rotate tokens periodically** (every 90 days recommended)
4. **Revoke old tokens** after rotation

### Access Control

1. **Firestore rules** already restrict bug report creation to authenticated users
2. **Function permissions** - only Cloud Functions can update `status` field
3. **GitHub token** has minimal required permissions (repo only)

---

## Costs & Quotas

### Firebase Functions

**Free tier includes:**
- 2M invocations/month
- 400K GB-seconds compute time
- 200K CPU-seconds

**This function uses:**
- ~1 invocation per bug report
- ~1 second compute time per invocation

**Estimate:** Even with 1000 bug reports/month, well within free tier.

### GitHub API

**Rate limits:**
- 5000 requests/hour with authenticated token
- This function makes 1 request per bug report

**Estimate:** No issues unless you receive 5000+ bugs/hour.

---

## Updating the Function

### To modify the function logic:

1. Edit `functions/src/index.ts`
2. Build: `cd functions && npm run build`
3. Deploy: `firebase deploy --only functions:syncBugToGitHub`

### Common modifications:

**Change repository:**
```typescript
const issue = await octokit.issues.create({
  owner: 'YOUR_ORG',
  repo: 'YOUR_REPO',
  // ...
});
```

**Add custom labels:**
```typescript
function getLabelsForBug(bug: BugReport): string[] {
  const labels = ['bug', 'from-app', 'needs-triage']; // Add 'needs-triage'
  // ...
}
```

**Modify issue format:**
```typescript
function formatGitHubIssueBody(bug: BugReport): string {
  let body = `## Description\n\n${bug.description}\n\n`;
  // Add custom sections here
  return body;
}
```

---

## Alternative: Manual Sync Script

If you prefer manual control instead of automatic sync, use the script:

```bash
node tool/sync-bugs-manually.js
```

This would:
1. Query all `pending` bug reports
2. Create GitHub issues for each
3. Update Firestore with issue numbers

**Pros:** Control when sync happens, review before creating issues
**Cons:** Manual work, delay in issue creation

---

## Quick Reference

### Commands

```bash
# Set GitHub token
firebase functions:config:set github.token="TOKEN"

# Deploy function
firebase deploy --only functions:syncBugToGitHub

# View logs
firebase functions:log --only syncBugToGitHub

# Check config
firebase functions:config:get

# Test locally (emulator)
firebase emulators:start --only functions,firestore
```

### Important URLs

- **Firebase Console:** https://console.firebase.google.com/project/spendpal-app-blrtechpub
- **GitHub Issues:** https://github.com/blrtechpub-droid/spendpal/issues
- **GitHub Tokens:** https://github.com/settings/tokens
- **Firestore Data:** https://console.firebase.google.com/project/spendpal-app-blrtechpub/firestore

---

## Next Steps

After setup is complete:

1. ✅ Test with a real bug report from the app
2. ✅ Monitor logs for first week
3. ✅ Create GitHub labels if they don't exist
4. ✅ Set up GitHub notifications for `from-app` label
5. ✅ Document the workflow for your team

---

**Setup Complete!**

Bug reports from the app will now automatically create GitHub issues. 🎉

---

*Last updated: 2025-10-26*
*Function: `syncBugToGitHub`*
*Location: `functions/src/index.ts:551-634`*
