#!/usr/bin/env bash
# Vercel "Ignored Build Step" for multi-app frontend monorepo.
#
# Usage: bash scripts/vercel-ignore-build.sh <indexedex|pachira|dtf>
# Exit 0 → skip deploy; Exit 1 → build.
#
# Rebuild when this app, packages/protocol, or shared workspace root files change.

set -u

APP_NAME="${1:-}"
if [[ -z "$APP_NAME" ]]; then
  # Fallback: detect from Vercel project name if set
  case "${VERCEL_PROJECT_NAME:-}" in
    *pachira*) APP_NAME=pachira ;;
    *dtf*|*dtfinance*|*down-to-finance*|*downtofinance*) APP_NAME=dtf ;;
    *) APP_NAME=indexedex ;;
  esac
fi

# Paths relative to monorepo git root (when Root Directory is frontend/apps/<app>,
# git still sees the full repo if project is monorepo-linked).
SCOPES=(
  "frontend/apps/${APP_NAME}"
  "frontend/packages/protocol"
  "frontend/package.json"
  "frontend/package-lock.json"
)

# When cwd is already frontend/ (or app dir), also check relative scopes.
REL_SCOPES=(
  "apps/${APP_NAME}"
  "packages/protocol"
  "package.json"
  "package-lock.json"
  "."
)

has_commit() {
  git rev-parse -q --verify "${1}^{commit}" >/dev/null 2>&1
}

diff_touches() {
  local base="$1"
  local path
  for path in "${SCOPES[@]}" "${REL_SCOPES[@]}"; do
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
