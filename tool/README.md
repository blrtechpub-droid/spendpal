# SpendPal Development Tools

This directory contains utility scripts to help maintain project continuity and workflow automation.

---

## 📋 Available Tools

### 1. `update-status.sh`

**Purpose:** Automatically updates `.claude/STATUS.md` with current project state.

**What it does:**
- Updates timestamp to current date/time
- Updates current branch name
- Updates current version from `pubspec.yaml`
- Shows project state summary
- Optionally prompts for task status updates

**Usage:**

```bash
# Run interactively (prompts for task updates)
./tool/update-status.sh

# Run in pre-commit mode (automatic, no prompts)
./tool/update-status.sh --pre-commit
```

**When to use:**
- Before ending work sessions
- After completing major tasks
- Before committing important changes
- When switching contexts
- After VS Code crashes (once recovered)

**Example output:**
```
╔════════════════════════════════════════╗
║  SpendPal Status Update Tool          ║
╚════════════════════════════════════════╝

Current Project State:
  📅 Date: 2025-10-26 at 13:15
  🌿 Branch: main
  📦 Version: 1.0.0+10
  💾 Last commit: Build release v1.0.0+10 for Play Store
  📝 Uncommitted changes: Yes
  📋 Staged files: 3

✓ Updated STATUS.md timestamp
✓ Updated branch and version info

Would you like to update task status? (y/n)
```

---

### 2. `install-hooks.sh`

**Purpose:** Installs git pre-commit hooks that automatically update STATUS.md before commits.

**What it does:**
- Creates a git pre-commit hook
- Hook runs `update-status.sh --pre-commit` before each commit
- Automatically updates timestamp, branch, and version in STATUS.md
- Adds STATUS.md to commit if it was modified
- Backs up existing hooks if present

**Usage:**

```bash
# Install the pre-commit hook
./tool/install-hooks.sh
```

**Follow prompts:**
- If pre-commit hook exists, you'll be asked to backup and replace
- Hook will be created in `.git/hooks/pre-commit`

**Once installed:**
- Every `git commit` will automatically update STATUS.md
- No manual action needed
- STATUS.md stays current with every commit

**To uninstall:**
```bash
rm .git/hooks/pre-commit
```

---

## 🚀 Quick Start

### First-Time Setup

1. **Install git hooks** (recommended):
   ```bash
   ./tool/install-hooks.sh
   ```
   This ensures STATUS.md is always updated automatically.

2. **Test the status updater**:
   ```bash
   ./tool/update-status.sh
   ```

3. **Make a test commit** to verify hooks work:
   ```bash
   git add .
   git commit -m "test: verify pre-commit hook"
   ```
   You should see "Updating STATUS.md..." before the commit.

### Daily Workflow

**With hooks installed:**
```bash
# Work on your code...
git add .
git commit -m "feat: add new feature"
# STATUS.md automatically updated! ✓
```

**Manual status updates:**
```bash
# Update status anytime
./tool/update-status.sh

# Or edit STATUS.md directly
nano .claude/STATUS.md
# Or in Claude Code:
/memory   # then select STATUS.md
```

---

## 📖 Workflow Examples

### Example 1: Before Ending Work Session

```bash
# Update status with your progress
./tool/update-status.sh

# Follow prompts to mark tasks completed
# Commit your work
git add .
git commit -m "WIP: implementing feature X - 80% complete"

# STATUS.md is already updated!
```

### Example 2: After VS Code Crash

```bash
# Check where you left off
cat .claude/STATUS.md
git log --oneline -5

# Continue work...
# When ready to commit:
git add .
git commit -m "fix: resolved crash issue"
# Hook automatically updates STATUS.md
```

### Example 3: Quick Status Check

```bash
# See current state without editing
./tool/update-status.sh
# Press 'n' when asked about task updates
# Or press 'y' and choose option 5 to skip
```

---

## 🔧 Advanced Usage

### Custom Status Updates

Edit `.claude/STATUS.md` directly for detailed updates:

```bash
# Using nano
nano .claude/STATUS.md

# Using VS Code
code .claude/STATUS.md

# Using Claude Code
/memory   # select STATUS.md
```

### Hook Customization

Edit `.git/hooks/pre-commit` to customize hook behavior:

```bash
nano .git/hooks/pre-commit
```

**Example customizations:**
- Skip hook for specific commit messages
- Add additional checks
- Update other files
- Run tests before commit

### Disable Hook Temporarily

```bash
# Commit without running hooks
git commit --no-verify -m "quick fix"

# Or temporarily disable hook
chmod -x .git/hooks/pre-commit

# Re-enable
chmod +x .git/hooks/pre-commit
```

---

## 📁 Files Modified

These scripts modify the following files:

| File | What Gets Updated |
|------|-------------------|
| `.claude/STATUS.md` | Timestamp, branch, version, task status |
| `.git/hooks/pre-commit` | Created by install-hooks.sh |

**Important:** STATUS.md is tracked in git, so updates will appear in your commits.

---

## 🐛 Troubleshooting

### Script won't run: "Permission denied"

```bash
# Make scripts executable
chmod +x tool/update-status.sh
chmod +x tool/install-hooks.sh
```

### Hook not running on commit

```bash
# Check if hook exists
ls -la .git/hooks/pre-commit

# Verify it's executable
chmod +x .git/hooks/pre-commit

# Check hook contents
cat .git/hooks/pre-commit
```

### STATUS.md not being updated

```bash
# Verify STATUS.md exists
ls -la .claude/STATUS.md

# Run manually to see errors
./tool/update-status.sh

# Check git repository
git rev-parse --git-dir
```

### sed command errors on Linux

The scripts use macOS-compatible `sed` syntax. On Linux, the scripts detect the OS and adjust automatically. If you encounter issues:

```bash
# Edit the script and ensure proper sed syntax for your OS
nano tool/update-status.sh
```

---

## 💡 Tips

### Best Practices

1. **Install hooks early** - Set up pre-commit hooks when starting work
2. **Update frequently** - Run `update-status.sh` after major milestones
3. **Descriptive commits** - Hook updates metadata; you provide context in commit messages
4. **Manual edits** - Use `/memory` in Claude Code for quick STATUS.md edits
5. **Check before push** - Review STATUS.md before pushing to remote

### Integration with Claude Code

```bash
# In Claude Code session:

# Check status
cat .claude/STATUS.md

# Update status
/memory   # select STATUS.md

# Resume after interruption
claude -c
# Then: "Check .claude/STATUS.md and continue"
```

### Recovery Workflow

```bash
# After crash/timeout:
cat .claude/STATUS.md          # Check last known state
git log --oneline -5           # See recent commits
git status                     # Check uncommitted work
./tool/update-status.sh        # Update and continue
```

---

## 📚 Related Documentation

- **`.claude/STATUS.md`** - Current project status (updated by these tools)
- **`CLAUDE.md`** - Project guidelines and session management info
- **`README.md`** - Project setup and commands
- **`.claude/BUG_WORKFLOW.md`** - Bug tracking workflow

---

## 🤝 Contributing

To improve these tools:

1. Test changes thoroughly
2. Update this README
3. Ensure compatibility with both macOS and Linux
4. Keep scripts simple and maintainable

---

## 📝 Script Details

### update-status.sh

**Dependencies:**
- `bash`
- `git`
- `sed`
- `date`
- `grep`, `awk` (standard Unix tools)

**Optional:**
- `nano` (for interactive editing)

**Exit codes:**
- `0` - Success
- `1` - Error (STATUS.md not found, etc.)

### install-hooks.sh

**Dependencies:**
- `bash`
- `git`

**Creates:**
- `.git/hooks/pre-commit`
- `.git/hooks/pre-commit.backup.<timestamp>` (if replacing existing hook)

**Exit codes:**
- `0` - Success
- `1` - Error (not a git repo, user cancelled, etc.)

---

**Last updated:** 2025-10-26
**Version:** 1.0
**Maintainer:** SpendPal Development Team
