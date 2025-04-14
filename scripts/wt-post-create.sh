#!/bin/bash
# Post-worktree-create hook for IndexedEx
# Properly initializes submodules in new worktrees
#
# Usage: Called automatically by git-wt or manually:
#   ./scripts/wt-post-create.sh /path/to/new/worktree

set -e

WORKTREE_PATH="${1:-$(pwd)}"
MAIN_REPO="$(git -C "$WORKTREE_PATH" rev-parse --git-common-dir)/.."
MAIN_REPO="$(cd "$MAIN_REPO" && pwd)"

echo "Initializing submodules in: $WORKTREE_PATH"
echo "Main repo: $MAIN_REPO"

cd "$WORKTREE_PATH"

# Method 1: Try normal submodule init (works if pointers are valid)
if git submodule update --init --recursive 2>/dev/null; then
    echo "✅ Submodules initialized successfully"
    exit 0
fi

echo "⚠️  Normal submodule init failed, copying from main repo..."

# Method 2: Copy submodules from main repo
copy_submodule() {
    local subpath="$1"
    local src="$MAIN_REPO/$subpath"
    local dst="$WORKTREE_PATH/$subpath"

    if [ -d "$src" ] && [ ! -z "$(ls -A "$src" 2>/dev/null)" ]; then
        echo "  Copying $subpath..."
        rm -rf "$dst"
        mkdir -p "$(dirname "$dst")"
        cp -R "$src" "$dst"
    fi
}

# Copy the submodule hierarchy
copy_submodule "lib/daosys"

# Verify
if [ -f "$WORKTREE_PATH/lib/daosys/lib/crane/CLAUDE.md" ]; then
    echo "✅ Submodules copied successfully"
else
    echo "❌ Failed to initialize submodules"
    exit 1
fi
