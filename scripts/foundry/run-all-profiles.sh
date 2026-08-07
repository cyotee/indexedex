#!/usr/bin/env bash
# Two Foundry gates only (see docs/ci.md Profile law).
# Run from repo root: lib/indexedex
# Usage: bash scripts/foundry/run-all-profiles.sh
#
# Focus a subtree without inventing profiles:
#   forge test --match-path 'test/foundry/spec/hooks/.../**' -vv
#   FOUNDRY_PROFILE=fork forge test --match-path 'test/foundry/fork/base_main/.../**' -vv

set -euo pipefail
cd "$(dirname "$0")/../.."

echo "=== hermetic (default profile → test/foundry/spec) ==="
forge test -vv

echo "=== fork (FOUNDRY_PROFILE=fork → test/foundry/fork; requires ALCHEMY_KEY) ==="
if [[ -z "${ALCHEMY_KEY:-}" ]]; then
  echo "ALCHEMY_KEY not set; skipping fork suite."
  exit 0
fi
FOUNDRY_PROFILE=fork forge test -vv
