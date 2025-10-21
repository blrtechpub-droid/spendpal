---
description: Create a new GitHub issue for a bug
---

Help the user create a well-formatted bug report as a GitHub issue.

## Instructions

1. **Gather information** from the user's description:
   - Bug title (short, descriptive)
   - Steps to reproduce
   - Expected behavior
   - Actual behavior
   - Affected files/components (if known)
   - Error messages or logs (if any)
   - Device/platform information (if relevant: iOS, Android, Web)

2. **Check for duplicates**:
   - Search existing issues to avoid duplicates
   - If similar issue exists, suggest commenting there instead

3. **Create the issue** with proper formatting:
   ```markdown
   ## Description
   [Clear description of the bug]

   ## Steps to Reproduce
   1. [First step]
   2. [Second step]
   3. [...]

   ## Expected Behavior
   [What should happen]

   ## Actual Behavior
   [What actually happens]

   ## Environment
   - Platform: [iOS/Android/Web]
   - Flutter version: [if known]
   - Device: [if relevant]

   ## Additional Context
   [Error logs, screenshots, related issues]

   ## Affected Files
   - `file/path.dart`
   ```

4. **Add appropriate labels**:
   - `bug` for bugs
   - `critical` for severe issues
   - `enhancement` for feature requests
   - Platform-specific labels: `ios`, `android`, `firebase`, etc.

5. **Submit the issue**:
   ```bash
   gh issue create --title "Bug title" --body "issue body" --label "bug,critical"
   ```

6. **Offer immediate action**:
   - After creating, ask if the user wants you to fix it immediately using `/fix-bug <number>`

Extract the bug details from the user's message and create a comprehensive GitHub issue.
