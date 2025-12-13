#!/bin/bash

# install-hooks.sh
# Installs git hooks for automatic status updates

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOKS_DIR="$PROJECT_ROOT/.git/hooks"
PRE_COMMIT_HOOK="$HOOKS_DIR/pre-commit"

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Git Hooks Installation                ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# Check if .git exists
if [ ! -d "$PROJECT_ROOT/.git" ]; then
    echo -e "${RED}Error: Not a git repository${NC}"
    exit 1
fi

# Create hooks directory if it doesn't exist
mkdir -p "$HOOKS_DIR"

# Check if pre-commit hook already exists
if [ -f "$PRE_COMMIT_HOOK" ]; then
    echo -e "${YELLOW}⚠ Pre-commit hook already exists${NC}"
    echo -e "${YELLOW}Would you like to backup and replace it? (y/n)${NC}"
    read -r RESPONSE

    if [[ "$RESPONSE" =~ ^[Yy]$ ]]; then
        BACKUP_FILE="$PRE_COMMIT_HOOK.backup.$(date +%s)"
        mv "$PRE_COMMIT_HOOK" "$BACKUP_FILE"
        echo -e "${GREEN}✓ Backed up existing hook to: $(basename $BACKUP_FILE)${NC}"
    else
        echo -e "${RED}Installation cancelled${NC}"
        exit 1
    fi
fi

# Create pre-commit hook
cat > "$PRE_COMMIT_HOOK" << 'EOF'
#!/bin/bash

# Pre-commit hook: Update STATUS.md before each commit

PROJECT_ROOT="$(git rev-parse --show-toplevel)"
UPDATE_SCRIPT="$PROJECT_ROOT/tool/update-status.sh"

# Check if update script exists
if [ -f "$UPDATE_SCRIPT" ]; then
    echo "Updating STATUS.md..."
    "$UPDATE_SCRIPT" --pre-commit
else
    echo "Warning: update-status.sh not found, skipping status update"
fi

# Continue with commit
exit 0
EOF

# Make hook executable
chmod +x "$PRE_COMMIT_HOOK"

echo -e "${GREEN}✓ Pre-commit hook installed successfully!${NC}"
echo ""
echo -e "${BLUE}What happens now:${NC}"
echo "  • Before each commit, STATUS.md will be automatically updated"
echo "  • Timestamp, branch, and version info will be refreshed"
echo "  • STATUS.md will be added to the commit if changed"
echo ""
echo -e "${BLUE}To update status manually:${NC}"
echo "  ${YELLOW}./tool/update-status.sh${NC}"
echo ""
echo -e "${BLUE}To uninstall:${NC}"
echo "  ${YELLOW}rm $PRE_COMMIT_HOOK${NC}"
echo ""
echo -e "${GREEN}Installation complete!${NC}"
