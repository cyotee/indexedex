#!/bin/bash
# Task setup script for IndexedEx worktrees
# Copies task files from tasks/ directory to worktree root for subagent access
#
# Usage: cd <worktree-path> && ./scripts/task-setup.sh <task-directory-name>
# Example: cd ../indexedex-wt/feature/IDXEX-013 && ./scripts/task-setup.sh IDXEX-013-implement-uniswap-v4-vault

set -e

TASK_DIR_NAME="${1:?Usage: task-setup.sh <task-directory-name>}"
WORKTREE_PATH="$(pwd)"
MAIN_REPO="$(git rev-parse --show-toplevel 2>/dev/null || echo "$WORKTREE_PATH")"
TASKS_BASE="$MAIN_REPO/tasks"
TASK_PATH="$TASKS_BASE/$TASK_DIR_NAME"

echo "Setting up task: $TASK_DIR_NAME"
echo "Worktree: $WORKTREE_PATH"
echo "Task source: $TASK_PATH"

# Verify task directory exists
if [ ! -d "$TASK_PATH" ]; then
    echo "❌ Task directory not found: $TASK_PATH"
    echo "   Make sure you're in the worktree and the task directory exists."
    exit 1
fi

# Copy TASK.md to PROMPT.md
echo ""
echo "Copying TASK.md → PROMPT.md..."
if [ -f "$TASK_PATH/TASK.md" ]; then
    cp "$TASK_PATH/TASK.md" "$WORKTREE_PATH/PROMPT.md"
    echo "  ✅ PROMPT.md created"
else
    echo "  ❌ TASK.md not found in $TASK_PATH"
    exit 1
fi

# Copy or create PROGRESS.md
echo ""
echo "Setting up PROGRESS.md..."
if [ -f "$TASK_PATH/PROGRESS.md" ]; then
    cp "$TASK_PATH/PROGRESS.md" "$WORKTREE_PATH/PROGRESS.md"
    echo "  ✅ PROGRESS.md copied from task directory"
else
    # Create template PROGRESS.md
    cat > "$WORKTREE_PATH/PROGRESS.md" << EOF
# Task Progress: $TASK_DIR_NAME

**Started:** $(date -u +"%Y-%m-%d %H:%M UTC")

## Current Status

In Progress

## Completed Work

- [ ] Task setup complete

## Blockers

None

## Notes

Subagent initialized in worktree.
EOF
    echo "  ✅ PROGRESS.md created (template)"
fi

# Copy or create REVIEW.md
echo ""
echo "Setting up REVIEW.md..."
if [ -f "$TASK_PATH/REVIEW.md" ]; then
    cp "$TASK_PATH/REVIEW.md" "$WORKTREE_PATH/REVIEW.md"
    echo "  ✅ REVIEW.md copied from task directory"
else
    # Create template REVIEW.md
    cat > "$WORKTREE_PATH/REVIEW.md" << EOF
# Review Notes: $TASK_DIR_NAME

**Task:** $TASK_DIR_NAME
**Started:** $(date -u +"%Y-%m-%d %H:%M UTC")

## Review Findings

(No findings yet)

## Questions/Clarifications

(None yet)

## Sign-off

- [ ] Implementation complete
- [ ] Tests passing
- [ ] Code review passed
EOF
    echo "  ✅ REVIEW.md created (template)"
fi

# Verify files exist
echo ""
echo "Verifying setup..."
for file in PROMPT.md PROGRESS.md REVIEW.md; do
    if [ -f "$WORKTREE_PATH/$file" ]; then
        echo "  ✅ $file"
    else
        echo "  ❌ $file missing"
    fi
done

echo ""
echo "✅ Task setup complete!"
echo ""
echo "Subagent instructions:"
echo "  1. Read PROMPT.md for task requirements"
echo "  2. Update PROGRESS.md as you work"
echo "  3. Add findings to REVIEW.md as needed"
echo "  4. Output <promise>TASK_COMPLETE</promise> when done"
echo ""
echo "To teardown when complete:"
echo "  ./scripts/task-teardown.sh $TASK_DIR_NAME"
