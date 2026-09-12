#!/usr/bin/env bash
# Vercel "Ignored Build Step" for the IndexedEx and DTF frontend apps.
#
# Usage: bash scripts/vercel-ignore-build.sh [indexedex|dtf]
# Exit 0 → skip deploy; Exit 1 → build.
#
# Rebuild when this app, packages/protocol, or shared workspace root files change.
# Both deployments share the main app; DTF adds a landing announcement.

set -u

APP_NAME="${1:-indexedex}"
if [[ "$APP_NAME" != "dtf" && "$APP_NAME" != "indexedex" ]]; then
  echo "vercel-ignore: unknown app '${APP_NAME}' — build"
  exit 1
fi

# Anchor scopes to the git root even when Vercel runs this inside an app.
REPO_ROOT="$(git rev-parse --show-toplevel)" || exit 1
cd "$REPO_ROOT" || exit 1

# Paths relative to monorepo git root (when Root Directory is frontend/apps/<app>,
# git still sees the full repo if project is monorepo-linked).
SCOPES=(
  "frontend/apps/${APP_NAME}"
  "frontend/package.json"
  "frontend/package-lock.json"
  "frontend/patches"
  "frontend/scripts/vercel-ignore-build.sh"
  "scripts/shell/vercel-ignore-frontend.sh"
)
SCOPES+=("frontend/apps/indexedex" "frontend/packages/protocol")

has_commit() {
  git rev-parse -q --verify "${1}^{commit}" >/dev/null 2>&1
}

diff_touches() {
  local base="$1"
  local path
  for path in "${SCOPES[@]}"; do
    if [[ -e "$path" ]] || git cat-file -e "${base}:${path}" 2>/dev/null; then
      if ! git diff --quiet "$base" HEAD -- "$path" 2>/dev/null; then
        return 0
      fi
    fi
  done
  return 1
}

if [[ -n "${VERCEL_GIT_PREVIOUS_SHA:-}" ]] && has_commit "$VERCEL_GIT_PREVIOUS_SHA"; then
  if diff_touches "$VERCEL_GIT_PREVIOUS_SHA"; then
    echo "vercel-ignore: changes affecting ${APP_NAME} since ${VERCEL_GIT_PREVIOUS_SHA:0:7} — build"
    exit 1
  fi
  echo "vercel-ignore: no relevant changes for ${APP_NAME} since ${VERCEL_GIT_PREVIOUS_SHA:0:7} — skip"
  exit 0
fi

if has_commit "HEAD^"; then
  if diff_touches "HEAD^"; then
    echo "vercel-ignore: changes affecting ${APP_NAME} in HEAD — build"
    exit 1
  fi
  echo "vercel-ignore: no relevant changes for ${APP_NAME} in HEAD — skip"
  exit 0
fi

echo "vercel-ignore: cannot compare commits — build"
exit 1
