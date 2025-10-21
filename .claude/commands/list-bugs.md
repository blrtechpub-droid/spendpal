---
description: List all open bugs from GitHub issues
---

List all open issues from the GitHub repository and present them in a clear, organized format.

## Instructions

1. **Fetch open issues** using GitHub CLI:
   ```bash
   gh issue list --state open --json number,title,labels,author,createdAt,url
   ```

2. **Organize and display** the issues:
   - Show issue number, title, and labels
   - Group by labels if there are "bug", "enhancement", or custom labels
   - Include creation date and author
   - Provide the GitHub URL for easy access

3. **Highlight priority**:
   - Issues labeled "bug" should be highlighted
   - Show issues labeled "critical" or "urgent" first
   - Note any issues assigned to specific users

4. **Provide recommendations**:
   - Suggest which bugs should be fixed first based on:
     - Severity/priority labels
     - Age of the issue
     - Number of comments (indicates impact)
   - Offer to fix any issue by number using `/fix-bug <number>`

5. **Summary statistics**:
   - Total number of open issues
   - Number of bugs vs enhancements
   - Number of issues without labels

Present the information in a clean, scannable format that makes it easy to identify and prioritize issues.
