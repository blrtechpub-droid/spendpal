---
description: Sync bug reports from Firestore to GitHub Issues
---

Sync pending bug reports from the Firestore `bugReports` collection to GitHub Issues.

## Instructions

1. **Fetch pending bug reports** from Firestore:
   - Query the `bugReports` collection for documents with `status: 'pending'`
   - Sort by `createdAt` (oldest first)

2. **For each pending bug report**:
   - Extract the bug details:
     - title
     - description
     - stepsToReproduce
     - priority (Low, Medium, High, Critical)
     - platform (Android, iOS, Web, All)
     - reportedByName and reportedByEmail
     - createdAt timestamp

3. **Create GitHub issue** with formatted content:
   ```markdown
   ## Description
   [description]

   ## Steps to Reproduce
   [stepsToReproduce or "Not provided"]

   ## Platform
   [platform]

   ## Priority
   [priority]

   ## Reported By
   - Name: [reportedByName]
   - Email: [reportedByEmail]
   - Date: [createdAt formatted]

   ---
   *This issue was automatically created from an in-app bug report*
   ```

4. **Add appropriate labels** based on priority and platform:
   - Priority labels: `priority:low`, `priority:medium`, `priority:high`, `priority:critical`
   - Platform labels: `android`, `ios`, `web`
   - Always add: `bug`, `from-app`

5. **Create the GitHub issue**:
   ```bash
   gh issue create \
     --title "[BUG] [Platform] Title" \
     --body "issue body" \
     --label "bug,from-app,priority:X,platform"
   ```

6. **Update Firestore** after successful creation:
   - Set `status` to `'synced'`
   - Set `githubIssueNumber` to the created issue number
   - Set `syncedAt` to current timestamp

7. **Report summary**:
   - Show how many bugs were synced
   - List the created GitHub issue numbers with titles
   - Note any failures or errors

8. **Error handling**:
   - If GitHub issue creation fails, keep status as `'pending'`
   - Log the error for review
   - Continue with other bug reports

## Firestore Query Example

To fetch bug reports, you'll need to use Firebase CLI or Admin SDK. For manual sync:

```bash
# Install firebase-tools if not already installed
npm install -g firebase-tools

# Login to Firebase
firebase login

# Use Firestore export/query to get pending bugs
firebase firestore:export gs://your-bucket/bugs --collections bugReports
```

**Note:** This command requires you to implement the Firestore query logic. You can use the Firebase Admin SDK or direct Firestore access through the Firebase CLI.

## Automation Recommendation

This command can be:
1. Run manually when you want to sync bug reports
2. Scheduled to run periodically (e.g., daily via cron)
3. Triggered automatically via Firebase Cloud Function when a new bug report is created

## Important Notes

- Only sync bugs with status 'pending'
- Always update Firestore after creating GitHub issue
- Preserve all bug report metadata
- Handle rate limiting gracefully (GitHub API has limits)
- Validate all fields before creating issues
