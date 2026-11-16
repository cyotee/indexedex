#!/bin/bash
# Reproduce the two handoff section 6 scopes without changing Foundry paths.
set -u
set -o pipefail
cd /Users/cyotee/Projects/indexedex-wt/dtf-migration-phase-03 || exit 1
export PATH="/Users/cyotee/.foundry/bin:$PATH"
export TMPDIR="/var/folders/8f/582y7l_125s9pbmjpdydnk_r0000gn/T/tmp.enuGXu0sUI/preparation-runtime"
export XDG_CACHE_HOME="$TMPDIR/xdg-cache"
export BUN_INSTALL_CACHE_DIR="$TMPDIR/bun-cache"
export npm_config_cache="$TMPDIR/npm-cache"
export PYTHONDONTWRITEBYTECODE=1
evidence="docs/incidents/2026-09-16-dtf-recovery/migration/package/evidence/preparation"
mkdir -p "$TMPDIR" "$XDG_CACHE_HOME" "$BUN_INSTALL_CACHE_DIR" "$npm_config_cache"
sources=(
  contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfInitializationLib.sol
  contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfDFPkg.sol
  contracts/vaults/detf/common/bondNft/DETFFundedBondTarget.sol
  contracts/vaults/detf/common/claimToken/StakedDETFTarget.sol
)
case "${1:-}" in
  focused)
    tests=(
      test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Deploy.t.sol
      test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Weighted.t.sol
      test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Weighted_Univ3Se.t.sol
      test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_BondNftPackaging.t.sol
      test/foundry/spec/vaults/detf/common/bondNft/DETFNFTVault_Surface.t.sol
      test/foundry/spec/vaults/detf/common/claimToken/RebasingClaimToken_Accounting.t.sol
      test/foundry/spec/vaults/detf/common/claimToken/FundedStakingSequence.t.sol
    )
    ;;
  broad)
    tests=(
      test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf
      test/foundry/spec/vaults/detf/common
    )
    ;;
  *) printf 'Expected focused or broad\n' >&2; exit 2 ;;
esac
command=(python3 scripts/forge-artifacts.py test "${sources[@]}")
for test in "${tests[@]}"; do command+=(--test-root "$test"); done
command+=(-- -vv)
{
  date -u '+START %Y-%m-%dT%H:%M:%SZ'
  printf 'TMPDIR=%s\nXDG_CACHE_HOME=%s\nBUN_INSTALL_CACHE_DIR=%s\nnpm_config_cache=%s\n' \
    "$TMPDIR" "$XDG_CACHE_HOME" "$BUN_INSTALL_CACHE_DIR" "$npm_config_cache"
  printf 'COMMAND '; printf '%q ' "${command[@]}"; printf '\n'
  forge --version
  "${command[@]}"
  rc=$?
  printf 'COMMAND_EXIT=%s\n' "$rc"
  date -u '+END %Y-%m-%dT%H:%M:%SZ'
  exit "$rc"
} 2>&1 | tee "$evidence/$1.log"
exit "${PIPESTATUS[0]}"
