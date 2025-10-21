# Automated Bug-Fixing Workflow

This document describes the automated bug-fixing workflow integrated with GitHub Issues.

## Available Commands

### `/list-bugs`
Lists all open issues from your GitHub repository.

**Usage:**
```
/list-bugs
```

**What it does:**
- Fetches all open issues from GitHub
- Groups them by type (bugs, enhancements, etc.)
- Highlights critical/urgent issues
- Provides recommendations on priority
- Shows issue numbers for easy fixing

---

### `/fix-bug <issue-number>`
Automatically analyzes and fixes a specific GitHub issue.

**Usage:**
```
/fix-bug 42
```

**What it does:**
1. Fetches issue details from GitHub
2. Analyzes the bug description and error messages
3. Investigates the codebase to find the root cause
4. Creates a fix plan with TodoWrite
5. Implements the fix automatically
6. Tests the changes (when applicable)
7. Commits with a proper message referencing the issue
8. Comments on the GitHub issue with the fix details

**Automation Level:** Fully automatic
- No approval needed at each step
- Works autonomously from analysis to commit
- Only asks for clarification if issue is unclear

---

### `/report-bug`
Creates a new GitHub issue with proper formatting.

**Usage:**
```
/report-bug User can't accept group invitations on iOS
```

**What it does:**
- Guides you through creating a well-formatted bug report
- Checks for duplicate issues
- Creates the GitHub issue with proper labels
- Offers to fix it immediately

---

## Workflow Examples

### Example 1: List and Fix a Bug
```
You: /list-bugs

Claude: [Shows list of 5 open issues]
#42 - Group invitations not working on iOS
#43 - Balance calculation incorrect for split expenses
...

You: /fix-bug 42

Claude: [Automatically fixes the bug and commits]
```

### Example 2: Report and Immediately Fix
```
You: /report-bug App crashes when adding expense without selecting friends

Claude: [Creates GitHub issue #44]
Would you like me to fix this immediately?

You: /fix-bug 44

Claude: [Analyzes, fixes, tests, and commits]
```

### Example 3: Manual Bug Report
```
You: I found a bug where the floating button doesn't appear on GroupHomeScreen

Claude: Let me create a GitHub issue for this.
/report-bug

[Creates properly formatted issue #45 with labels]
```

---

## How It Works

### 1. Issue Creation
- Bugs can be reported via GitHub web interface
- Or use `/report-bug` command in Claude
- Issues are automatically labeled and categorized

### 2. Automatic Analysis
When `/fix-bug <number>` is called:
- Fetches issue from GitHub API
- Parses description, error logs, and reproduction steps
- Uses codebase exploration to locate affected files
- Identifies root cause through code analysis

### 3. Automatic Fix
- Creates structured fix plan with TodoWrite
- Modifies necessary files following project patterns
- Adheres to architecture guidelines in CLAUDE.md
- Maintains coding style consistency

### 4. Testing & Verification
- Runs relevant tests if they exist
- Checks for compilation errors
- Verifies no new issues introduced

### 5. Commit & Documentation
- Creates commit with clear message
- References issue number (e.g., "Fix: Resolve group invitation bug #42")
- Comments on GitHub issue with commit hash
- Suggests if issue can be closed

---

## Configuration

### GitHub CLI Setup
Ensure `gh` CLI is authenticated:
```bash
gh auth login
```

### Repository Connection
The workflow uses:
- **Repository:** https://github.com/blrtechpub-droid/spendpal.git
- **GitHub CLI:** v2.82.0
- **Auto-commit:** Enabled

---

## Best Practices

### For Bug Reporting
1. Be specific about the issue
2. Include reproduction steps
3. Add error messages/logs if available
4. Mention affected platform (iOS/Android/Web)
5. Reference related files if known

### For Bug Fixing
1. Use `/list-bugs` to see all issues
2. Prioritize critical/urgent issues first
3. Let Claude work autonomously - trust the process
4. Review commits after automatic fixes
5. Test on actual devices when possible

### Issue Management
- Label issues appropriately (bug, enhancement, critical)
- Close issues after verifying fixes
- Keep issue descriptions updated
- Use milestones for release planning

---

## Integration with Firebase

The workflow can also pull errors from Firebase logs:

```bash
# View recent function errors
firebase functions:log -n 20

# Filter for specific function
firebase functions:log --only parseBill -n 10
```

This can help identify issues before users report them.

---

## Troubleshooting

### If `/fix-bug` fails:
1. Check if issue number exists
2. Verify GitHub CLI authentication
3. Ensure issue has enough detail
4. Check for conflicting changes in working directory

### If issues aren't fetched:
1. Verify repository connection: `gh repo view`
2. Check authentication: `gh auth status`
3. Ensure issues exist: Visit GitHub web interface

---

## Future Enhancements

Potential improvements to the workflow:
- Automatic deployment after fix
- Integration with CI/CD pipeline
- Slack/Discord notifications for new issues
- Automated regression testing
- Pull request creation instead of direct commits
- Multi-issue batch fixing

---

## Notes

- The workflow follows security best practices
- All fixes maintain project architecture patterns
- Commits are properly attributed
- Firebase rules and Flutter conventions are respected
- No destructive operations without explicit confirmation
