#!/bin/bash
# Safe worktree removal for IndexedEx (handles submodules)
#
# Usage: ./scripts/wt-remove.sh <branch-name>
# Example: ./scripts/wt-remove.sh feature/camelot-deploy-with-pool

set -e

BRANCH="${1:?Usage: wt-remove.sh <branch-name>}"
MAIN_REPO="$(git rev-parse --show-toplevel)"
WT_BASE="${MAIN_REPO}-wt"
WORKTREE_PATH="$WT_BASE/$BRANCH"

echo "Removing worktree: $BRANCH"
echo "Path: $WORKTREE_PATH"

# Check if worktree exists
if ! git worktree list | grep -q "$WORKTREE_PATH"; then
    echo "⚠️  Worktree not found in git worktree list"

    # Check if directory exists anyway
    if [ -d "$WORKTREE_PATH" ]; then
        echo "  Directory exists, removing manually..."
        rm -rf "$WORKTREE_PATH"
    fi
else
    # Remove worktree (force required for submodules)
    echo "  Removing worktree..."
    git worktree remove --force "$WORKTREE_PATH" 2>/dev/null || {
        echo "  Force remove failed, cleaning manually..."
        rm -rf "$WORKTREE_PATH"
        git worktree prune
    }
fi

# Remove branch if it exists and is not checked out elsewhere
if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
    echo "  Deleting branch $BRANCH..."
    git branch -D "$BRANCH" 2>/dev/null || echo "  Branch deletion skipped (may be current branch elsewhere)"
fi

# Clean up any stale lock files
find "$MAIN_REPO/.git/modules" -name "*.lock" -delete 2>/dev/null || true

# Prune worktree references
git worktree prune

echo "✅ Worktree $BRANCH removed"
echo ""
echo "Remaining worktrees:"
git worktree list
