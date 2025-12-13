# Session Management Quick Start Guide

**Created:** 2025-10-26
**Purpose:** Maintain continuity across work sessions, especially after crashes or timeouts

---

## ✨ What's New

Your project now has a comprehensive session management system:

### 📁 New Files

1. **`.claude/STATUS.md`** - Live project status tracker
2. **`tool/update-status.sh`** - Automatic status updater script
3. **`tool/install-hooks.sh`** - Git hook installer
4. **`tool/README.md`** - Detailed tool documentation

### 📝 Updated Files

1. **`CLAUDE.md`** - Added "Session Management and Recovery" section
2. **`README.md`** - Added "Useful Commands Reference" section

---

## 🚀 Quick Start (3 Steps)

### Step 1: Install Git Hooks (Recommended)

```bash
./tool/install-hooks.sh
```

**What this does:**
- Creates a pre-commit hook
- Auto-updates STATUS.md before every commit
- Keeps timestamp, branch, and version current

### Step 2: Test the Status Updater

```bash
./tool/update-status.sh
```

**What this does:**
- Updates STATUS.md with current state
- Shows project summary
- Prompts for task updates

### Step 3: Make a Test Commit

```bash
# Make a small change
echo "# Test" >> test.txt
git add test.txt
git commit -m "test: verify auto-update works"
# You should see "Updating STATUS.md..." before commit
git reset HEAD~1  # Undo test commit
rm test.txt
```

---

## 📖 How It Works

### During Normal Work

```bash
# Work on your code...
git add .
git commit -m "feat: add new feature"
# ✓ STATUS.md automatically updated!
```

### Manual Status Updates

```bash
# Update status anytime
./tool/update-status.sh

# Or use Claude Code
/memory   # then select STATUS.md
```

### After VS Code Crash

```bash
# 1. Check where you left off
cat .claude/STATUS.md

# 2. Check recent commits
git log --oneline -5

# 3. Resume in Claude Code
claude -c

# 4. Ask Claude
"Check .claude/STATUS.md and continue where we left off"
```

---

## 🎯 Key Files to Know

### `.claude/STATUS.md`
**Purpose:** Current project status
**Updated:** Automatically by git hook, or manually
**Read by:** You and Claude Code
**When to check:** After crashes, context switches, resuming work

**Contains:**
- Active tasks
- Recently completed work
- Current build information
- Environment state
- Next steps
- Recovery instructions

### `CLAUDE.md`
**Purpose:** Project context and guidelines
**Updated:** Manually using `/memory`
**Read by:** Claude Code (automatically)
**When to update:** New patterns, decisions, conventions

**Contains:**
- Architecture overview
- Data models and services
- Development commands
- Session management guidelines
- Recovery protocols

### `tool/update-status.sh`
**Purpose:** Automate STATUS.md updates
**Usage:** `./tool/update-status.sh`

**Features:**
- Updates timestamp, branch, version
- Shows project summary
- Interactive task updates
- Pre-commit mode for git hooks

---

## 💡 Best Practices

### Daily Workflow

1. **Morning:** Check STATUS.md to see where you left off
2. **During work:** Let git hooks update STATUS.md automatically
3. **Major milestones:** Run `./tool/update-status.sh` manually
4. **Evening:** Update STATUS.md with current progress

### Session Recovery

1. **Read STATUS.md first** - It's your safety net
2. **Check git log** - See what you last committed
3. **Use `claude -c`** - Resume last conversation
4. **Ask Claude to check STATUS.md** - Let AI help you resume

### Updating Memory

**Update STATUS.md when:**
- Completing tasks
- Encountering blockers
- Before ending work sessions
- After crashes (once recovered)
- Before/after major builds

**Update CLAUDE.md when:**
- Learning new patterns
- Making architectural decisions
- Changing conventions
- Adding new workflows

---

## 🔧 Commands Reference

### Status Management

```bash
# Update status (interactive)
./tool/update-status.sh

# Update status (auto mode for hooks)
./tool/update-status.sh --pre-commit

# View current status
cat .claude/STATUS.md

# Edit status manually
nano .claude/STATUS.md
# or in Claude Code:
/memory
```

### Git Hooks

```bash
# Install hooks
./tool/install-hooks.sh

# Uninstall hook
rm .git/hooks/pre-commit

# Commit without running hook (emergency)
git commit --no-verify -m "quick fix"
```

### Recovery

```bash
# Full status check
cat .claude/STATUS.md
git log --oneline -5
git status
flutter doctor

# Resume Claude session
claude -c

# Check build status
ls -lh build/app/outputs/bundle/release/
```

---

## 📚 Documentation

### Detailed Guides

- **`tool/README.md`** - Complete tool documentation
- **`CLAUDE.md`** - Session Management section (lines 323-523)
- **`README.md`** - Useful Commands section (lines 364-515)
- **`.claude/STATUS.md`** - Session Recovery Guide section

### Quick References

**Session recovery:**
```bash
cat .claude/STATUS.md                    # Check status
git log --oneline -5                     # Recent commits
claude -c                                # Resume session
```

**Update status:**
```bash
./tool/update-status.sh                  # Interactive
/memory                                  # In Claude Code
```

**Emergency recovery:**
```bash
cat .claude/STATUS.md
git log --oneline -10
git diff HEAD~5..HEAD
flutter doctor -v
```

---

## 🎉 You're All Set!

Your project now has:

✅ Automatic status tracking
✅ Git hooks for seamless updates
✅ Crash recovery procedures
✅ Session continuity system
✅ Comprehensive documentation

### Next Steps

1. **Install git hooks:** `./tool/install-hooks.sh`
2. **Update STATUS.md** with your current work
3. **Continue working** - hooks handle the rest!

### Getting Help

- **Tool usage:** See `tool/README.md`
- **Session management:** See `CLAUDE.md` (lines 323-523)
- **Commands:** See `README.md` (lines 364-515)
- **Current status:** See `.claude/STATUS.md`

---

## 💬 Tips for Claude Code Users

### Starting a New Session

```bash
claude -c
# Then:
"Check .claude/STATUS.md - what was I working on?"
```

### After a Crash

```bash
# 1. Check status file
cat .claude/STATUS.md

# 2. Resume
claude -c
"VS Code crashed. Check STATUS.md and git log. Continue from where we were."
```

### Updating Memory

```bash
# In Claude Code:
/memory
# Select STATUS.md to update current work
# Select CLAUDE.md to update project guidelines
```

### Regular Updates

```bash
# Let Claude update STATUS.md for you:
"Update .claude/STATUS.md with today's progress:
- Completed: [your tasks]
- In progress: [current work]
- Next: [upcoming tasks]"
```

---

**Happy coding! Your work is now protected from interruptions.** 🎊

---

*For questions or issues, see `tool/README.md` troubleshooting section.*
