#!/usr/bin/env bash
# Vercel "Ignored Build Step" for the indexedex monorepo frontend.
#
# Exit codes (Vercel contract):
#   0 → skip this deployment (no frontend changes)
#   1 → proceed with build/deploy
#
# Prefer VERCEL_GIT_PREVIOUS_SHA so multi-commit pushes that touch frontend
# still build even when the tip commit is unrelated.

set -u

scope="frontend"
if [[ ! -d "$scope" ]]; then
  # Root Directory checkout or cwd already inside frontend/
  if [[ -f package.json && ( -f next.config.js || -f next.config.mjs || -f next.config.ts ) ]]; then
    scope="."
  else
    exit 1
  fi
fi

has_commit() {
  git rev-parse -q --verify "${1}^{commit}" >/dev/null 2>&1
}

if [[ -n "${VERCEL_GIT_PREVIOUS_SHA:-}" ]] && has_commit "$VERCEL_GIT_PREVIOUS_SHA"; then
  if git diff --quiet "$VERCEL_GIT_PREVIOUS_SHA" HEAD -- "$scope"; then
    echo "vercel-ignore-frontend: no changes under ${scope}/ since ${VERCEL_GIT_PREVIOUS_SHA:0:7} — skip"
    exit 0
  fi
  echo "vercel-ignore-frontend: changes under ${scope}/ since ${VERCEL_GIT_PREVIOUS_SHA:0:7} — build"
  exit 1
fi

if has_commit "HEAD^"; then
  if git diff --quiet HEAD^ HEAD -- "$scope"; then
    echo "vercel-ignore-frontend: no changes under ${scope}/ in HEAD — skip"
    exit 0
  fi
  echo "vercel-ignore-frontend: changes under ${scope}/ in HEAD — build"
  exit 1
fi

echo "vercel-ignore-frontend: cannot compare commits — build"
exit 1
