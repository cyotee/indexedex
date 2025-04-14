#!/bin/bash
# Task teardown script for IndexedEx worktrees
# Syncs PROGRESS.md and REVIEW.md back to tasks/, rebases onto main
#
# Usage: cd <worktree-path> && ./scripts/task-teardown.sh <task-directory-name>
# Example: cd ../indexedex-wt/feature/IDXEX-013 && ./scripts/task-teardown.sh IDXEX-013-implement-uniswap-v4-vault

set -e

TASK_DIR_NAME="${1:?Usage: task-teardown.sh <task-directory-name>}"
WORKTREE_PATH="$(pwd)"
MAIN_REPO="$(git rev-parse --show-toplevel 2>/dev/null)"

# If we're in a worktree, main repo is the common git dir
if [ -z "$MAIN_REPO" ]; then
    # Try to find main repo from git common dir
    GIT_COMMON="$(git rev-parse --git-common-dir 2>/dev/null)"
    if [ -n "$GIT_COMMON" ] && [ "$GIT_COMMON" != ".git" ]; then
        MAIN_REPO="$(cd "$GIT_COMMON/.." && pwd)"
    else
        echo "❌ Cannot determine main repository path"
        echo "   Make sure you're in a git worktree"
        exit 1
    fi
fi

TASKS_BASE="$MAIN_REPO/tasks"
TASK_PATH="$TASKS_BASE/$TASK_DIR_NAME"

echo "Tearing down task: $TASK_DIR_NAME"
echo "Worktree: $WORKTREE_PATH"
echo "Task destination: $TASK_PATH"

# Verify task directory exists
if [ ! -d "$TASK_PATH" ]; then
    echo "❌ Task directory not found: $TASK_PATH"
    exit 1
fi

# Copy PROGRESS.md back
echo ""
echo "Syncing PROGRESS.md to task directory..."
if [ -f "$WORKTREE_PATH/PROGRESS.md" ]; then
    cp "$WORKTREE_PATH/PROGRESS.md" "$TASK_PATH/PROGRESS.md"
    echo "  ✅ PROGRESS.md synced"
else
    echo "  ⚠️  PROGRESS.md not found in worktree"
fi

# Copy REVIEW.md back
echo ""
echo "Syncing REVIEW.md to task directory..."
if [ -f "$WORKTREE_PATH/REVIEW.md" ]; then
    cp "$WORKTREE_PATH/REVIEW.md" "$TASK_PATH/REVIEW.md"
    echo "  ✅ REVIEW.md synced"
else
    echo "  ⚠️  REVIEW.md not found in worktree"
fi

# Sync PROMPT.md back to TASK.md (required)
echo ""
echo "Syncing PROMPT.md to TASK.md..."
if [ -f "$WORKTREE_PATH/PROMPT.md" ]; then
    cp "$WORKTREE_PATH/PROMPT.md" "$TASK_PATH/TASK.md"
    echo "  ✅ TASK.md updated from PROMPT.md"
else
    echo "  ⚠️  PROMPT.md not found in worktree"
fi

# Commit all changes (required) - AFTER copying task files
echo ""
echo "Checking worktree status..."
cd "$WORKTREE_PATH"
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
    echo "  Changes detected - committing..."
    git add -A
    git commit -m "Task $TASK_DIR_NAME: Implementation complete"
    echo "  ✅ Changes committed"
else
    echo "  ✅ Worktree is clean"
fi

# Rebase onto main
echo ""
echo "Rebasing worktree onto main..."
cd "$WORKTREE_PATH"
CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"

# Fetch latest main
git fetch origin main 2>/dev/null || echo "  ⚠️  Could not fetch from origin"

# Attempt rebase
echo "  Rebasing $CURRENT_BRANCH onto main..."
if git rebase main; then
    echo "  ✅ Rebase successful"
else
    echo ""
    echo "  ❌ Rebase has conflicts!"
    echo "  Resolve conflicts manually, then run:"
    echo "    git rebase --continue"
    echo "    ./scripts/task-teardown.sh $TASK_DIR_NAME"
    exit 1
fi

echo ""
echo "✅ Task teardown complete!"
echo ""
echo "Actions completed:"
echo "  ✅ All changes committed"
echo "  ✅ PROGRESS.md synced to task directory"
echo "  ✅ REVIEW.md synced to task directory"
echo "  ✅ TASK.md updated from PROMPT.md"
echo "  ✅ Branch rebased onto main"
echo ""
echo "Next steps:"
echo "  1. Update INDEX.md to mark task as Complete"
echo "  2. Remove worktree when ready:"
echo "     ./scripts/wt-remove.sh $CURRENT_BRANCH"
echo ""
echo "Or push changes:"
echo "  git push origin $CURRENT_BRANCH"
