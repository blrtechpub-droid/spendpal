# Session Workflow Instructions

## For Claude Code Assistant

### BEFORE ENDING ANY SESSION:
When the user says any of these phrases, create/update the session summary:
- "end session"
- "wrap up"
- "save progress"
- "create summary"
- "session summary"

### Session Summary Checklist:
1. **Update or create** `.claude/session_summary.md` with:
   - Date and session focus
   - All completed tasks with ✅
   - Files modified with line numbers
   - Code snippets for key changes
   - Build status
   - Next steps or pending work

2. **Format**: Use the template below

3. **Archive**: If summary gets long (>500 lines), create dated archive:
   - `.claude/archives/session_YYYY-MM-DD.md`

---

## Session Summary Template

```markdown
# Session Summary - [Topic]

**Date**: YYYY-MM-DD
**Focus**: [Main task description]

---

## Completed Tasks

### Task 1: [Name] ✅
**Files Modified**:
- `path/to/file.dart` (lines X-Y)

**Changes**:
- Description of change
- Code snippet if relevant

**Impact**: What this improves

### Task 2: [Name] ✅
...

---

## Files Modified Summary
1. **path/to/file1** - Description
2. **path/to/file2** - Description

---

## Build Status
- ✅/❌ Build result
- Any errors or warnings

---

## Pending/Next Steps
- [ ] Task to continue
- [ ] Ideas for future sessions

---

## Notes
- Important context
- Decisions made
- Issues encountered
```

---

## For Users

### To End a Session:
Simply say: **"end session"** or **"wrap up"**

I'll automatically:
1. Create/update session summary
2. List all files modified
3. Note any pending tasks
4. Provide continuity notes for next session

### To Start a New Session:
Say: **"What did we work on last time?"**

I'll read `.claude/session_summary.md` and brief you on:
- Previous session's work
- Files that were modified
- Where we left off
- Next logical steps
