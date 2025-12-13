# Automatic Bug Sync - Quick Start

## What Was Implemented

✅ **Cloud Function:** `syncBugToGitHub`
- Automatically creates GitHub issues when users report bugs in the app
- Applies labels based on priority and platform
- Updates Firestore with GitHub issue number

## Setup (3 Steps)

### 1. Create GitHub Token

1. Go to: https://github.com/settings/tokens/new
2. Name: `SpendPal Bug Sync`
3. Expiration: 90 days
4. Scope: ✅ `repo` (full control)
5. Generate and copy token

### 2. Configure Firebase

```bash
# Set the GitHub token
firebase functions:config:set github.token="YOUR_TOKEN_HERE"
```

### 3. Deploy

```bash
# Build and deploy
cd functions && npm run build && cd ..
firebase deploy --only functions:syncBugToGitHub
```

## Test

1. Open app → Account → Report a Bug
2. Submit a test bug report
3. Check: https://github.com/blrtechpub-droid/spendpal/issues

## Monitor

```bash
# View logs
firebase functions:log --only syncBugToGitHub
```

---

**Full Documentation:** `.claude/BUG_SYNC_SETUP.md`

**Files Modified:**
- `functions/src/index.ts` - Added syncBugToGitHub function (lines 526-691)
- `functions/package.json` - Added @octokit/rest dependency

**Function Location:** functions/src/index.ts:551-634
