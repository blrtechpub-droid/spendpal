#!/bin/bash

# update-status.sh
# Automatically updates .claude/STATUS.md with current project state
# Can be used manually or as a git pre-commit hook

set -e

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Project root detection
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
STATUS_FILE="$PROJECT_ROOT/.claude/STATUS.md"

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  SpendPal Status Update Tool          ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# Check if STATUS.md exists
if [ ! -f "$STATUS_FILE" ]; then
    echo -e "${RED}Error: STATUS.md not found at $STATUS_FILE${NC}"
    exit 1
fi

# Get current timestamp
CURRENT_DATE=$(date "+%Y-%m-%d")
CURRENT_TIME=$(date "+%H:%M")
TIMESTAMP="$CURRENT_DATE $CURRENT_TIME"

# Get current branch
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")

# Get current version from pubspec.yaml
CURRENT_VERSION=$(grep "^version:" "$PROJECT_ROOT/pubspec.yaml" | awk '{print $2}' || echo "unknown")

# Get last commit message
LAST_COMMIT=$(git log -1 --pretty=format:"%s" 2>/dev/null || echo "No commits yet")

# Check if there are uncommitted changes
if git diff-index --quiet HEAD -- 2>/dev/null; then
    HAS_CHANGES="No"
else
    HAS_CHANGES="Yes"
fi

# Count staged files
STAGED_FILES=$(git diff --cached --name-only 2>/dev/null | wc -l | tr -d ' ')

echo -e "${GREEN}Current Project State:${NC}"
echo "  📅 Date: $CURRENT_DATE at $CURRENT_TIME"
echo "  🌿 Branch: $CURRENT_BRANCH"
echo "  📦 Version: $CURRENT_VERSION"
echo "  💾 Last commit: $LAST_COMMIT"
echo "  📝 Uncommitted changes: $HAS_CHANGES"
echo "  📋 Staged files: $STAGED_FILES"
echo ""

# Update timestamp in STATUS.md
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s/^\*\*Last Updated:\*\* .*/**Last Updated:** $TIMESTAMP/" "$STATUS_FILE"
else
    # Linux
    sed -i "s/^\*\*Last Updated:\*\* .*/**Last Updated:** $TIMESTAMP/" "$STATUS_FILE"
fi

# Update current branch
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s/^\*\*Current Branch:\*\* .*/**Current Branch:** \`$CURRENT_BRANCH\`/" "$STATUS_FILE"
else
    sed -i "s/^\*\*Current Branch:\*\* .*/**Current Branch:** \`$CURRENT_BRANCH\`/" "$STATUS_FILE"
fi

# Update current version
if [[ "$OSTYPE" == "darwin"* ]]; then
    sed -i '' "s/^\*\*Current Version:\*\* .*/**Current Version:** $CURRENT_VERSION/" "$STATUS_FILE"
else
    sed -i "s/^\*\*Current Version:\*\* .*/**Current Version:** $CURRENT_VERSION/" "$STATUS_FILE"
fi

echo -e "${GREEN}✓ Updated STATUS.md timestamp${NC}"
echo -e "${GREEN}✓ Updated branch and version info${NC}"
echo ""

# Check if running as pre-commit hook
if [ "$1" = "--pre-commit" ]; then
    echo -e "${YELLOW}Running in pre-commit mode...${NC}"

    # Add STATUS.md to the commit if it was modified
    if git diff --name-only "$STATUS_FILE" | grep -q "STATUS.md"; then
        git add "$STATUS_FILE"
        echo -e "${GREEN}✓ Added STATUS.md to commit${NC}"
    fi

    echo -e "${GREEN}✓ Pre-commit update complete${NC}"
    exit 0
fi

# Interactive mode - ask if user wants to update task status
echo -e "${YELLOW}Would you like to update task status? (y/n)${NC}"
read -r RESPONSE

if [[ "$RESPONSE" =~ ^[Yy]$ ]]; then
    echo ""
    echo -e "${BLUE}Task Status Update:${NC}"
    echo "What would you like to update?"
    echo "  1) Mark a task as completed"
    echo "  2) Add a new active task"
    echo "  3) Update current work section"
    echo "  4) Add to recently completed"
    echo "  5) Skip - just update timestamp"
    echo ""
    echo -n "Enter choice (1-5): "
    read -r CHOICE

    case $CHOICE in
        1)
            echo -n "Enter task description to mark complete: "
            read -r TASK_DESC
            echo -e "${GREEN}✓ Task noted: $TASK_DESC${NC}"
            echo "  (Please manually update STATUS.md to move this to completed section)"
            ;;
        2)
            echo -n "Enter new active task: "
            read -r NEW_TASK
            echo -e "${GREEN}✓ New task noted: $NEW_TASK${NC}"
            echo "  (Please manually add this to STATUS.md active tasks section)"
            ;;
        3)
            echo -n "What are you currently working on? "
            read -r CURRENT_WORK
            echo -e "${GREEN}✓ Current work noted: $CURRENT_WORK${NC}"
            echo "  (Please update STATUS.md 'Recently Completed' section)"
            ;;
        4)
            echo -n "What did you just complete? "
            read -r COMPLETED
            echo -e "${GREEN}✓ Completed work noted: $COMPLETED${NC}"
            echo "  (Please update STATUS.md 'Recently Completed' section)"
            ;;
        5)
            echo -e "${BLUE}Skipping task updates${NC}"
            ;;
        *)
            echo -e "${RED}Invalid choice${NC}"
            ;;
    esac
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════${NC}"
echo -e "${GREEN}Status update complete!${NC}"
echo ""
echo "Next steps:"
echo "  1. Review changes: ${YELLOW}git diff .claude/STATUS.md${NC}"
echo "  2. Edit STATUS.md if needed: ${YELLOW}/memory${NC} (in Claude Code)"
echo "  3. Or edit manually: ${YELLOW}nano .claude/STATUS.md${NC}"
echo ""

# Offer to open STATUS.md in editor
if command -v nano &> /dev/null; then
    echo -e "${YELLOW}Open STATUS.md in nano? (y/n)${NC}"
    read -r OPEN_RESPONSE
    if [[ "$OPEN_RESPONSE" =~ ^[Yy]$ ]]; then
        nano "$STATUS_FILE"
    fi
fi

echo -e "${GREEN}Done!${NC}"
