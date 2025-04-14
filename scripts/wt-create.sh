#!/bin/bash
# Safe worktree creation for IndexedEx (handles submodules)
#
# Usage: ./scripts/wt-create.sh <branch-name>
# Example: ./scripts/wt-create.sh feature/new-vault

set -e

BRANCH="${1:?Usage: wt-create.sh <branch-name>}"
MAIN_REPO="$(git rev-parse --show-toplevel)"
WT_BASE="${MAIN_REPO}-wt"
WORKTREE_PATH="$WT_BASE/$BRANCH"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Creating worktree: $BRANCH"
echo "Path: $WORKTREE_PATH"

# Check if worktree already exists
if git worktree list | grep -q "$WORKTREE_PATH"; then
    echo "⚠️  Worktree already exists at $WORKTREE_PATH"
    echo "    Use: cd $WORKTREE_PATH"
    exit 0
fi

# Check if branch exists
if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
    echo "  Branch exists, creating worktree for existing branch..."
    git worktree add "$WORKTREE_PATH" "$BRANCH"
else
    echo "  Creating new branch from main..."
    git worktree add -b "$BRANCH" "$WORKTREE_PATH" main
fi

# Initialize submodules
echo ""
echo "Initializing submodules..."
"$SCRIPT_DIR/wt-post-create.sh" "$WORKTREE_PATH"

# Verify build environment
echo ""
echo "Verifying build environment..."
cd "$WORKTREE_PATH"
if forge build --help >/dev/null 2>&1; then
    echo "  Forge available ✅"
else
    echo "  ⚠️  Forge not found in PATH"
fi

echo ""
echo "✅ Worktree ready: $WORKTREE_PATH"
echo ""
echo "Next steps:"
echo "  cd $WORKTREE_PATH"
echo "  forge build"
