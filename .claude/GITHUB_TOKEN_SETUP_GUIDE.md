# GitHub Personal Access Token Setup Guide

**Purpose:** Create a GitHub Personal Access Token (PAT) for automatic bug report syncing to GitHub Issues.

**Time Required:** 5 minutes

**Prerequisites:** GitHub account with access to the spendpal repository

---

## Table of Contents

1. [Quick Start (TL;DR)](#quick-start-tldr)
2. [Detailed Step-by-Step Guide](#detailed-step-by-step-guide)
3. [Using the Token in Firebase](#using-the-token-in-firebase)
4. [Security Best Practices](#security-best-practices)
5. [Troubleshooting](#troubleshooting)
6. [Token Maintenance](#token-maintenance)

---

## Quick Start (TL;DR)

For experienced users:

1. **Create token:** https://github.com/settings/tokens/new
2. **Configure:**
   - Note: `SpendPal Bug Sync`
   - Expiration: `90 days`
   - Scope: ✅ `repo` (only this one!)
3. **Generate** and **copy token** (starts with `ghp_`)
4. **Set in Firebase:**
   ```bash
   firebase functions:config:set github.token="YOUR_TOKEN_HERE"
   ```
5. **Deploy:**
   ```bash
   firebase deploy --only functions:syncBugToGitHub
   ```

---

## Detailed Step-by-Step Guide

### Step 1: Navigate to Token Settings

#### Option A: Direct Link (Fastest)

Click this link to go directly to the token creation page:

**👉 https://github.com/settings/tokens/new**

---

#### Option B: Manual Navigation

If you prefer to navigate manually:

1. **Log in to GitHub**
   - Go to https://github.com
   - Sign in if you're not already logged in

2. **Open Settings**
   - Click your **profile picture** in the top-right corner
   - Select **Settings** from the dropdown menu

   ```
   ┌──────────────────┐
   │  Profile Picture │ ← Click here
   ├──────────────────┤
   │  Your profile    │
   │  Your repos      │
   │  Your stars      │
   │  ─────────────── │
   │  Settings        │ ← Then click here
   │  Sign out        │
   └──────────────────┘
   ```

3. **Navigate to Developer Settings**
   - Scroll down the **left sidebar**
   - At the very bottom, click **Developer settings**

   ```
   Left Sidebar:
   │  Profile
   │  Account
   │  Appearance
   │  ...
   │  Applications
   │  Scheduled reminders
   │  ─────────────────────
   │  Developer settings    ← At the bottom!
   ```

4. **Access Personal Access Tokens**
   - Click **Personal access tokens** (expand if collapsed)
   - Click **Tokens (classic)**
   - Click **Generate new token** button
   - Select **Generate new token (classic)**

   ```
   Personal access tokens
   ├─ Fine-grained tokens
   └─ Tokens (classic)      ← Click here
      └─ Generate new token
         ├─ Generate new token (classic)     ← Then this
         └─ Generate new token (beta)
   ```

---

### Step 2: Configure Token Settings

You'll now see the **"New personal access token"** form.

#### Field 1: Note (Token Name)

**What to enter:**
```
SpendPal - Bug Reporting Auto-Sync
```

**Purpose:** This is just a description to help you remember what this token is for.

**Tips:**
- Make it descriptive
- Include the project name
- Mention the purpose

**Example descriptions:**
- ✅ `SpendPal - Bug Reporting Auto-Sync`
- ✅ `SpendPal Firebase Functions - GitHub Integration`
- ✅ `SpendPal - Automated Issue Creation`
- ❌ `token` (too vague)
- ❌ `test` (not descriptive)

---

#### Field 2: Expiration

**Recommended:** `90 days`

**Options:**
- `7 days` - Very secure, but you'll need to rotate often
- `30 days` - More secure, monthly rotation
- `60 days` - Good balance
- **`90 days`** ⭐ **RECOMMENDED** - Best balance of security and convenience
- `Custom` - Choose your own date
- `No expiration` - ⚠️ **NOT RECOMMENDED** for security reasons

**Why 90 days?**
- Secure enough (rotated quarterly)
- Not too frequent to be annoying
- Industry standard for tokens
- GitHub recommends expiration for security

---

#### Field 3: Select Scopes (Permissions)

**IMPORTANT:** This is where you grant permissions. Only select what you need!

**What to select:**
```
✅ repo - Full control of private repositories
```

**Expanded view when you check `repo`:**
```
✅ repo
  ✅ repo:status         (Auto-checked)
  ✅ repo_deployment     (Auto-checked)
  ✅ public_repo         (Auto-checked)
  ✅ repo:invite         (Auto-checked)
  ✅ security_events     (Auto-checked)
```

**What NOT to select:**
```
❌ workflow
❌ write:packages
❌ delete:packages
❌ notifications
❌ user
❌ delete_repo
❌ write:discussion
❌ write:org
❌ admin:org
❌ admin:public_key
❌ admin:repo_hook
❌ admin:org_hook
❌ gist
❌ admin:gpg_key
```

**Why only `repo`?**
- It's the ONLY permission needed to create issues
- Following principle of least privilege
- More secure - limits what can be done if token is compromised
- Easier to audit and manage

**Visual Checklist:**
```
Scopes to grant:
┌──────────────────────────────────────┐
│ ✅ repo                              │ ← Check ONLY this!
│ ❌ workflow                          │
│ ❌ write:packages                    │
│ ❌ delete:packages                   │
│ ❌ admin:org                         │
│ ❌ admin:public_key                  │
│ ❌ admin:repo_hook                   │
│ ❌ admin:org_hook                    │
│ ❌ gist                              │
│ ❌ notifications                     │
│ ❌ user                              │
│ ❌ delete_repo                       │
│ ❌ write:discussion                  │
│ ❌ admin:gpg_key                     │
└──────────────────────────────────────┘
```

---

### Step 3: Generate the Token

1. **Review your settings:**
   - Note: `SpendPal - Bug Reporting Auto-Sync`
   - Expiration: `90 days`
   - Scope: `repo` ✅

2. **Scroll to the bottom** of the page

3. **Click the green button:**
   ```
   ┌──────────────────────────┐
   │  Generate token          │  ← Click this!
   └──────────────────────────┘
   ```

4. **Wait for confirmation**
   - GitHub will generate the token (takes 1-2 seconds)
   - You'll be redirected to a page showing your new token

---

### Step 4: Copy Your Token

**CRITICAL STEP - READ CAREFULLY!**

After generation, you'll see your token at the top of the page:

```
┌─────────────────────────────────────────────────────────────────┐
│  Make sure to copy your personal access token now.              │
│  You won't be able to see it again!                             │
│                                                                  │
│  ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx   [Copy]              │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Token Format:**
- Starts with: `ghp_`
- Length: ~40 characters
- Example: `ghp_AbCdEfGhIjKlMnOpQrStUvWxYz1234567890ABCD`

**How to Copy:**

**Option 1: Click the copy button**
- Click the **copy icon** next to the token
- You'll see a green checkmark confirming it's copied

**Option 2: Manual selection**
- Click at the start of the token (before `ghp_`)
- Hold Shift and click at the end
- Press Cmd+C (Mac) or Ctrl+C (Windows)

**Where to paste temporarily:**

While you're setting up Firebase, save it temporarily in:
- **Secure note in password manager** (1Password, LastPass, etc.) ⭐ BEST
- **Secure text file** (not in git repo!)
- **Sticky note** (delete immediately after use)

**⚠️ WARNINGS:**
- ❌ **DO NOT** close the page until you've copied the token
- ❌ **DO NOT** commit the token to git
- ❌ **DO NOT** share the token publicly
- ❌ **DO NOT** paste it in Slack/Discord/email
- ❌ **You can only see it ONCE** - if you lose it, create a new one

---

### Step 5: Verify Token Details

After copying, scroll down to see your token in the list:

```
Personal access tokens (classic)
┌────────────────────────────────────────────────────────────────┐
│  SpendPal - Bug Reporting Auto-Sync                            │
│  Created just now • Expires in 90 days                         │
│  Scopes: repo                                                  │
│  Last used: Never                                              │
│                                                                 │
│  [Regenerate token]  [Edit]  [Delete]                          │
└────────────────────────────────────────────────────────────────┘
```

**Verify:**
- ✅ Name matches what you entered
- ✅ Expiration is 90 days
- ✅ Scope is `repo` (only!)
- ✅ Status is active

---

## Using the Token in Firebase

Now that you have your token, configure Firebase Functions to use it.

### Step 1: Open Terminal

Navigate to your project directory:

```bash
cd /Users/abhaysingh/Documents/devlopment/expenseTrackingApp/spendpal
```

---

### Step 2: Set the Token in Firebase Config

Run this command, replacing `YOUR_TOKEN_HERE` with your actual token:

```bash
firebase functions:config:set github.token="ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
```

**Example:**
```bash
firebase functions:config:set github.token="ghp_AbCdEfGhIjKlMnOpQrStUvWxYz1234567890ABCD"
```

**Expected output:**
```
✔  Functions config updated.

Please deploy your functions for the change to take effect by running:
   firebase deploy --only functions
```

**What this does:**
- Stores the token securely in Firebase Functions config
- Makes it available to your Cloud Functions
- Token is encrypted and not visible in code
- Only accessible by your Firebase Functions

---

### Step 3: Verify Configuration

Check that the token was set correctly:

```bash
firebase functions:config:get
```

**Expected output:**
```json
{
  "github": {
    "token": "ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
  }
}
```

**If you see your token, you're good!**

**If you see an error:**
- Make sure you're in the correct directory
- Check you're logged into Firebase: `firebase login`
- Verify your project is selected: `firebase use`

---

### Step 4: Deploy the Function

Deploy the Cloud Function with the new configuration:

```bash
firebase deploy --only functions:syncBugToGitHub
```

**Expected output:**
```
=== Deploying to 'spendpal-app-blrtechpub'...

i  deploying functions
i  functions: ensuring required API cloudfunctions.googleapis.com is enabled...
✔  functions: required API cloudfunctions.googleapis.com is enabled
i  functions: preparing functions directory for uploading...
i  functions: packaged functions (X KB) for uploading
✔  functions: functions folder uploaded successfully
i  functions: creating Node.js 18 function syncBugToGitHub(us-central1)...
✔  functions[syncBugToGitHub(us-central1)]: Successful create operation.

✔  Deploy complete!
```

**What this does:**
- Uploads your Cloud Function to Firebase
- Configures it with the GitHub token
- Sets up the Firestore trigger
- Makes it active and ready to use

---

### Step 5: Test the Integration

**Test 1: Check Function is Deployed**

```bash
firebase functions:list
```

You should see:
```
┌────────────────────┬─────────────────┬────────┐
│ Function           │ Trigger         │ Region │
├────────────────────┼─────────────────┼────────┤
│ syncBugToGitHub    │ Firestore       │ us-... │
│ parseBill          │ HTTPS           │ us-... │
└────────────────────┴─────────────────┴────────┘
```

**Test 2: Submit a Bug Report**

1. Open SpendPal app on device/emulator
2. Navigate to: **Account** → **Report a Bug**
3. Fill out the form:
   ```
   Title: Test automated GitHub sync
   Description: Testing if bug reports automatically create GitHub issues
   Steps: 1. Open app, 2. Report bug, 3. Check GitHub
   Priority: Low
   Platform: Android
   ```
4. Click **Submit**

**Test 3: Check GitHub**

Wait 5-10 seconds, then check:
https://github.com/blrtechpub-droid/spendpal/issues

You should see a new issue:
```
[BUG] [Android] Test automated GitHub sync
Labels: bug, from-app, priority:low, android
```

**Test 4: Check Firestore**

Go to Firebase Console:
https://console.firebase.google.com/project/spendpal-app-blrtechpub/firestore/data/bugReports

The bug report document should have:
- `status`: "synced"
- `githubIssueNumber`: [number]
- `syncedAt`: [timestamp]

**Test 5: Check Logs**

```bash
firebase functions:log --only syncBugToGitHub
```

You should see:
```
New bug report created: [doc-id]
Creating GitHub issue...
GitHub issue created: #[number]
Updated Firestore document [doc-id] with issue #[number]
```

**✅ If all tests pass, you're done!**

---

## Security Best Practices

### Token Storage

**✅ DO:**
- Store in Firebase Functions config (encrypted)
- Use password manager for backup
- Keep in secure notes
- Delete from clipboard after use

**❌ DON'T:**
- Never commit to git
- Never share publicly
- Never store in plain text files in repo
- Never email or message the token

---

### Token Permissions

**Principle of Least Privilege:**
- Only grant `repo` scope (nothing more)
- Don't use tokens with `admin` permissions
- Create separate tokens for different purposes
- Revoke tokens you're not using

---

### Token Rotation

**Set a calendar reminder for 80 days from now:**

When expiration approaches:
1. Create new token (same process)
2. Update Firebase config with new token
3. Redeploy function
4. Delete old token from GitHub
5. Update any backup storage

**Rotation command:**
```bash
# Set new token
firebase functions:config:set github.token="NEW_TOKEN_HERE"

# Redeploy
firebase deploy --only functions:syncBugToGitHub

# Then delete old token on GitHub
```

---

### Access Auditing

**Regularly check token usage:**

1. Go to https://github.com/settings/tokens
2. Review each token:
   - When it was last used
   - What permissions it has
   - When it expires
3. Delete tokens you don't recognize or no longer use

---

### Compromise Response

**If you suspect your token is compromised:**

1. **Immediately revoke the token:**
   - Go to https://github.com/settings/tokens
   - Find the token
   - Click **Delete**

2. **Create a new token** (follow this guide again)

3. **Update Firebase:**
   ```bash
   firebase functions:config:set github.token="NEW_TOKEN"
   firebase deploy --only functions
   ```

4. **Review recent activity:**
   - Check GitHub for unexpected issues created
   - Review Firestore for suspicious bug reports
   - Check function logs for unusual patterns

---

## Troubleshooting

### Problem: "I closed the page and lost my token"

**Symptom:** You navigated away before copying the token.

**Solution:**
1. Go back to https://github.com/settings/tokens
2. Find the token you just created
3. Click **Delete** (you can't recover it)
4. Click **Generate new token** and start over
5. This time, copy the token before doing anything else!

**Prevention:**
- Open a text editor BEFORE generating the token
- Paste the token immediately after generation
- Don't close the browser tab until you've verified the token works

---

### Problem: "Can't find Developer settings"

**Symptom:** You don't see "Developer settings" in the sidebar.

**Solution:**
1. Make sure you're logged into GitHub
2. Click your profile picture (top right)
3. Select **Settings**
4. Scroll ALL the way down on the left sidebar
5. Developer settings is at the VERY BOTTOM (below everything else)

**Still can't find it?**
- Try the direct link: https://github.com/settings/tokens/new
- Make sure you're using the GitHub website (not the app)
- Try a different browser if needed

---

### Problem: "Token doesn't work (401 Unauthorized)"

**Symptom:** Firebase function logs show:
```
GitHub API Error: { status: 401, message: 'Bad credentials' }
```

**Possible causes and solutions:**

**1. Token not copied completely**
- Token should start with `ghp_` and be ~40 characters
- Check you copied the entire string
- No extra spaces at the beginning or end

**2. Wrong scope selected**
- Go to https://github.com/settings/tokens
- Click **Edit** on your token
- Verify `repo` scope is checked
- Save changes

**3. Token expired**
- Check expiration date on GitHub
- Create a new token if expired

**4. Token not set in Firebase**
- Run: `firebase functions:config:get`
- Verify token is there
- If not, run: `firebase functions:config:set github.token="YOUR_TOKEN"`

**5. Function not redeployed**
- Run: `firebase deploy --only functions:syncBugToGitHub`
- Config changes require redeployment

---

### Problem: "Permission denied creating issue"

**Symptom:** Function logs show:
```
GitHub API Error: { status: 403, message: 'Resource not accessible' }
```

**Cause:** Token doesn't have `repo` scope or you don't have access to the repository.

**Solution:**

**Check token permissions:**
1. Go to https://github.com/settings/tokens
2. Find your token
3. Click **Edit**
4. Verify `repo` is checked
5. Click **Update token**

**Check repository access:**
1. Go to https://github.com/blrtechpub-droid/spendpal
2. Verify you can create issues manually
3. If you can't access the repo, contact the repo owner

**Update token in Firebase:**
```bash
firebase functions:config:set github.token="UPDATED_TOKEN"
firebase deploy --only functions:syncBugToGitHub
```

---

### Problem: "Labels not found"

**Symptom:** GitHub issue created but labels are missing or function errors.

**Cause:** The labels don't exist in your GitHub repository.

**Solution:** Create the required labels:

1. Go to: https://github.com/blrtechpub-droid/spendpal/labels

2. Create these labels:

| Label | Color | Description |
|-------|-------|-------------|
| `bug` | `#d73a4a` | Something isn't working |
| `from-app` | `#0075ca` | Reported from mobile app |
| `priority:low` | `#28a745` | Low priority |
| `priority:medium` | `#ffc107` | Medium priority |
| `priority:high` | `#fd7e14` | High priority |
| `priority:critical` | `#dc3545` | Critical priority |
| `android` | `#3ddc84` | Android platform |
| `ios` | `#999999` | iOS platform |
| `web` | `#61dafb` | Web platform |

**Quick create:**
For each label, click **New label** and fill in:
- Name: (from table above)
- Color: (hex code from table)
- Description: (optional)

---

### Problem: "Function not triggering"

**Symptom:** Bug report submitted but no GitHub issue created.

**Debugging steps:**

**1. Check function is deployed:**
```bash
firebase functions:list
```
Should show `syncBugToGitHub` with trigger type `Firestore`.

**2. Check function logs:**
```bash
firebase functions:log --only syncBugToGitHub
```
Do you see any logs when you submit a bug?

**3. Check Firestore:**
- Go to Firebase Console
- Navigate to Firestore
- Check `bugReports` collection
- Does a document exist for your bug?
- What is the `status` field?

**4. Verify trigger:**
```bash
firebase functions:config:get
```
Should show the GitHub token.

**5. Redeploy:**
```bash
firebase deploy --only functions:syncBugToGitHub
```

---

### Problem: "Rate limit exceeded"

**Symptom:** Function logs show:
```
GitHub API Error: { status: 403, message: 'API rate limit exceeded' }
```

**Cause:** Too many requests to GitHub API.

**GitHub rate limits:**
- 5,000 requests per hour (with authentication)
- 60 requests per hour (without authentication)

**Solution:**

**For normal use (not rate limited):**
- The function creates 1 issue per bug report
- You'd need 5,000+ bugs/hour to hit the limit
- This is extremely unlikely

**If you're testing heavily:**
- Wait an hour for the limit to reset
- Test more slowly
- Use a different token for testing

**Check rate limit status:**
```bash
curl -H "Authorization: token YOUR_GITHUB_TOKEN" \
  https://api.github.com/rate_limit
```

---

## Token Maintenance

### Checking Token Status

**View all your tokens:**
```
https://github.com/settings/tokens
```

**For each token, check:**
- Last used date
- Expiration date
- Scopes granted
- When it was created

---

### Updating an Expired Token

**When your token expires (90 days):**

**Step 1: Create new token**
- Follow this guide again from the beginning
- Use same settings (name, expiration, scope)

**Step 2: Update Firebase**
```bash
firebase functions:config:set github.token="NEW_TOKEN_HERE"
```

**Step 3: Redeploy**
```bash
firebase deploy --only functions:syncBugToGitHub
```

**Step 4: Test**
- Submit a test bug report
- Verify GitHub issue is created
- Check function logs

**Step 5: Delete old token**
- Go to https://github.com/settings/tokens
- Find the old (expired) token
- Click **Delete**

---

### Revoking a Token

**When to revoke:**
- Token compromised or exposed
- Token no longer needed
- Creating a replacement token
- Cleaning up old tokens

**How to revoke:**
1. Go to https://github.com/settings/tokens
2. Find the token to revoke
3. Click **Delete**
4. Confirm deletion

**⚠️ Impact:**
- Any systems using this token will stop working
- Make sure you have a replacement before revoking
- Update all systems using the old token

---

### Token Inventory

**Keep track of your tokens:**

Create a secure note in your password manager:

```
SpendPal GitHub Tokens
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Current Token
  Name: SpendPal - Bug Reporting Auto-Sync
  Created: 2025-10-26
  Expires: 2026-01-24
  Scope: repo
  Used for: Firebase Cloud Function
  Location: Firebase Functions Config

Previous Tokens
  [List old tokens and when they were rotated]

Notes
  - Rotate every 90 days
  - Set calendar reminder
  - Update Firebase after rotation
```

---

## Quick Reference

### Token Creation Checklist

```
□ Navigate to GitHub Settings → Developer settings
□ Click Personal access tokens → Tokens (classic)
□ Click Generate new token (classic)
□ Set Note: "SpendPal - Bug Reporting Auto-Sync"
□ Set Expiration: 90 days
□ Check ONLY: repo scope
□ Click Generate token
□ Copy token immediately (starts with ghp_)
□ Save temporarily in secure location
□ Set in Firebase: firebase functions:config:set github.token="..."
□ Deploy: firebase deploy --only functions:syncBugToGitHub
□ Test with a bug report
□ Verify GitHub issue created
□ Delete token from temporary storage
□ Set calendar reminder for rotation (80 days)
```

---

### Essential Commands

```bash
# Set token in Firebase
firebase functions:config:set github.token="TOKEN_HERE"

# View Firebase config
firebase functions:config:get

# Deploy function
firebase deploy --only functions:syncBugToGitHub

# View function logs
firebase functions:log --only syncBugToGitHub

# List deployed functions
firebase functions:list

# Follow logs in real-time
firebase functions:log --only syncBugToGitHub --follow
```

---

### Important URLs

```
Token Management:
  Create: https://github.com/settings/tokens/new
  List:   https://github.com/settings/tokens

Repository:
  Issues: https://github.com/blrtechpub-droid/spendpal/issues
  Labels: https://github.com/blrtechpub-droid/spendpal/labels

Firebase:
  Console: https://console.firebase.google.com/project/spendpal-app-blrtechpub
  Firestore: https://console.firebase.google.com/project/spendpal-app-blrtechpub/firestore
```

---

## Summary

### What You Accomplished

✅ Created a GitHub Personal Access Token
✅ Configured token with appropriate permissions (repo only)
✅ Set expiration for security (90 days)
✅ Stored token securely in Firebase Functions Config
✅ Deployed the automatic bug sync function
✅ Tested the integration end-to-end

### What Happens Now

When a user reports a bug in the app:
1. Bug saved to Firestore
2. Cloud Function triggers automatically
3. GitHub issue created with formatted details
4. Labels applied (bug, priority, platform)
5. Firestore updated with GitHub issue number
6. You get notified on GitHub

### Next Steps

1. **Monitor the first few bugs:**
   ```bash
   firebase functions:log --only syncBugToGitHub --follow
   ```

2. **Set calendar reminder** for token rotation (80 days from now)

3. **Create GitHub labels** if they don't exist (see troubleshooting)

4. **Review security practices** periodically

5. **Document for your team** if others need to know

---

**🎉 Congratulations!** Your automated bug reporting system is now active!

---

*Last updated: 2025-10-26*
*For questions or issues, see the Troubleshooting section above.*
