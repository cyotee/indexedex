#!/usr/bin/env bash
# Verify stack-too-deep fix (Coordinator batch adapters + default profile).
# Run from repo root, or: bash scripts/foundry/verify-stack-too-deep-fix.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"
echo "cwd: $ROOT"
echo

echo "=== 1) Default profile: forge build ==="
forge build
echo

echo "=== 2) Coordinator profile: forge build ==="
FOUNDRY_PROFILE=coordinator forge build
echo

echo "=== 3) Coordinator SE suite ==="
FOUNDRY_PROFILE=coordinator forge test \
  --match-path 'test/foundry/routers/spec/balancerV3-uniswapV4/*SE*' -vv
echo

echo "=== 4) Coordinator Stock suite ==="
FOUNDRY_PROFILE=coordinator forge test \
  --match-path 'test/foundry/routers/spec/balancerV3-uniswapV4/*Stock*' -vv
echo

echo "=== 5) Optional: default forge test (full suite; long) ==="
echo "# Uncomment or run manually:"
echo "# forge test"
echo

echo "All requested steps finished."
