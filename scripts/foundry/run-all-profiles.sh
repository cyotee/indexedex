#!/usr/bin/env bash
# One command per Foundry profile (including default).
# Run from repo root: lib/indexedex
# Usage: bash scripts/foundry/run-all-profiles.sh
# Or copy/paste individual lines below.

set -euo pipefail
cd "$(dirname "$0")/../.."

# --- default (no FOUNDRY_PROFILE) ---
forge test -vv

# --- hermetic / package profiles ---
FOUNDRY_PROFILE=research forge test -vv
FOUNDRY_PROFILE=universal_router forge test -vv
FOUNDRY_PROFILE=coordinator forge test -vv
FOUNDRY_PROFILE=orbital forge test -vv
FOUNDRY_PROFILE=quad_stable forge test -vv
FOUNDRY_PROFILE=single_se_buffer_cp_hook forge test -vv
FOUNDRY_PROFILE=dual_se_buffer_cp_hook forge test -vv
FOUNDRY_PROFILE=single_se_buffer_hook forge test -vv
FOUNDRY_PROFILE=hook_factory forge test -vv
FOUNDRY_PROFILE=uv4_single_se_cp_detf forge test -vv

# --- fork profiles (require RPC) ---
FOUNDRY_PROFILE=fork forge test -vv
FOUNDRY_PROFILE=coordinator_fork forge test -vv
FOUNDRY_PROFILE=se_erc4626 forge test -vv
