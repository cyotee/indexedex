#!/bin/bash
# Commit and push all dirty submodules, then commit ALL changes in parent repo.
# Pushes submodules but does NOT push the parent repo.
#
# Usage: ./scripts/submodule-commit.sh [-m "message"]
#
# Options:
#   -m "message"   Commit message for submodule commits (default: "chore: sync submodule changes")
#   -n             Dry run - show what would be done without doing it
#   -h             Show this help
#
# The script walks the submodule tree bottom-up (deepest submodules first)
# so that parent submodules pick up child pointer changes before committing.

set -e

# --- Parse arguments ---

MSG="chore: sync submodule changes"
DRY_RUN=false

while getopts "m:nh" opt; do
    case $opt in
        m) MSG="$OPTARG" ;;
        n) DRY_RUN=true ;;
        h)
            sed -n '2,/^$/s/^# //p' "$0"
            exit 0
            ;;
        *)
            echo "Usage: $0 [-m \"message\"] [-n] [-h]"
            exit 1
            ;;
    esac
done

MAIN_REPO="$(git rev-parse --show-toplevel)"
COMMITTED_SOMETHING=false

# --- Helpers ---

log()  { echo "  $*"; }
info() { echo ""; echo "==> $*"; }

run() {
    if $DRY_RUN; then
        echo "  [dry-run] $*"
    else
        "$@"
    fi
}

# Commit and push a single repo if it has changes.
# Returns 0 if a commit was made, 1 if clean.
commit_and_push() {
    local repo_path="$1"
    local label="$2"

    cd "$repo_path"

    # Check for any changes (staged, unstaged, untracked, or submodule pointer changes).
    # --ignore-submodules=none overrides any diff.ignoreSubmodules config.
    if git diff --ignore-submodules=none --quiet && git diff --cached --ignore-submodules=none --quiet && [ -z "$(git ls-files --others --exclude-standard)" ]; then
        log "$label: clean, skipping"
        return 1
    fi

    info "$label: has changes"
    git status --short

    run git add -A
    run git commit -m "$MSG"

    # Push to remote (the submodule's own remote)
    local branch
    branch="$(git rev-parse --abbrev-ref HEAD)"
    if [ "$branch" = "HEAD" ]; then
        log "WARNING: $label is in detached HEAD state, skipping push"
        log "  You may need to checkout a branch first"
        COMMITTED_SOMETHING=true
        return 0
    fi

    log "Pushing $label ($branch)..."
    run git push origin "$branch"

    COMMITTED_SOMETHING=true
    return 0
}

# --- Walk submodule tree bottom-up ---

info "Scanning submodule tree from $MAIN_REPO"

# Collect all submodule absolute paths (recursive), deepest first.
# git submodule foreach --recursive visits top-down, so we reverse.
# We use $toplevel/$sm_path to get the correct absolute path since
# $sm_path is relative to its immediate parent, not the root repo.
SUBMODULE_PATHS=()
while IFS= read -r abs_path; do
    SUBMODULE_PATHS+=("$abs_path")
done < <(git submodule foreach --recursive --quiet 'echo "$toplevel/$sm_path"' 2>/dev/null)

# Reverse the array so we process deepest submodules first
REVERSED=()
for (( i=${#SUBMODULE_PATHS[@]}-1; i>=0; i-- )); do
    REVERSED+=("${SUBMODULE_PATHS[$i]}")
done

if [ ${#REVERSED[@]} -eq 0 ]; then
    echo "No submodules found."
    exit 0
fi

info "Found ${#REVERSED[@]} submodule(s), processing bottom-up:"
for p in "${REVERSED[@]}"; do
    log "  ${p#$MAIN_REPO/}"
done

# Process each submodule
for sub_path in "${REVERSED[@]}"; do
    label="${sub_path#$MAIN_REPO/}"
    commit_and_push "$sub_path" "$label" || true
done

# --- Commit all changes in parent repo (including submodule refs) ---

cd "$MAIN_REPO"

info "Checking parent repo for changes..."

# Stage everything in the parent repo: submodule pointer updates, modified files,
# new files, etc. --ignore-submodules=none is critical: this repo has
# diff.ignoreSubmodules=all which would silently hide submodule pointer changes.
if git diff --ignore-submodules=none --quiet && git diff --cached --ignore-submodules=none --quiet && [ -z "$(git ls-files --others --exclude-standard)" ]; then
    log "Parent repo: clean, skipping"
else
    info "Parent repo: has changes"
    git status --short --ignore-submodules=none
    run git add -A
    run git commit -m "$MSG"
    COMMITTED_SOMETHING=true
fi

# --- Summary ---

echo ""
if $COMMITTED_SOMETHING; then
    echo "Done. Submodules committed and pushed. Parent repo committed with all changes (NOT pushed)."
else
    echo "Nothing to do - all submodules and parent repo are clean."
fi
