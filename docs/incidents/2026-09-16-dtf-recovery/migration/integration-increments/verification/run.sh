#!/bin/bash
set -u
set -o pipefail
cd '/Users/cyotee/Projects/indexedex-wt/dtf-migration-integration' || exit 1
export PATH="/Users/cyotee/.foundry/bin:$PATH"
export TMPDIR='/Users/cyotee/Projects/indexedex-wt/dtf-migration-integration/.integration-verification-runtime-st01a1c6fd'
export XDG_CACHE_HOME="$TMPDIR/xdg-cache"
export NODE_COMPILE_CACHE="$TMPDIR/node-cache"
export BUN_RUNTIME_TRANSPILER_CACHE_PATH="$TMPDIR/bun-transpile"
export BUN_INSTALL_CACHE_DIR="$TMPDIR/bun-cache"
export npm_config_cache="$TMPDIR/npm-cache"
export PYTHONDONTWRITEBYTECODE=1
export FOUNDRY_PROFILE=default
unset FOUNDRY_TEST FOUNDRY_SRC FOUNDRY_OUT FOUNDRY_CACHE_PATH FOUNDRY_SOLC FOUNDRY_VIA_IR FOUNDRY_MATCH_TEST FOUNDRY_MATCH_CONTRACT FOUNDRY_MATCH_PATH FOUNDRY_NO_MATCH_TEST FOUNDRY_NO_MATCH_CONTRACT FOUNDRY_NO_MATCH_PATH FOUNDRY_FORK_URL
mkdir -p "$XDG_CACHE_HOME" "$NODE_COMPILE_CACHE" "$BUN_RUNTIME_TRANSPILER_CACHE_PATH" "$BUN_INSTALL_CACHE_DIR" "$npm_config_cache"
{
  date -u '+START %Y-%m-%dT%H:%M:%SZ'
  printf 'RECORDER_PID=%s
' "$$"
  printf 'CWD=%s
PATH=%s
TMPDIR=%s
XDG_CACHE_HOME=%s
NODE_COMPILE_CACHE=%s
BUN_RUNTIME_TRANSPILER_CACHE_PATH=%s
BUN_INSTALL_CACHE_DIR=%s
npm_config_cache=%s
FOUNDRY_PROFILE=%s
' "$PWD" "$PATH" "$TMPDIR" "$XDG_CACHE_HOME" "$NODE_COMPILE_CACHE" "$BUN_RUNTIME_TRANSPILER_CACHE_PATH" "$BUN_INSTALL_CACHE_DIR" "$npm_config_cache" "$FOUNDRY_PROFILE"
  forge --version
  printf '%s
' ''\''python3'\'' '\''scripts/forge-artifacts.py'\'' '\''test'\'' '\''contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationSnapshotLib.sol'\'' '\''contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationSnapshot.sol'\'' '\''contracts/interfaces/IStandardExchangeFrozenQuoteInputs.sol'\'' '\''contracts/utils/StandardExchangeFrozenQuoteLib.sol'\'' '\''contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHookCapture.sol'\'' '\''contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookTarget.sol'\'' '\''contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookHooksTarget.sol'\'' '\''contracts/hooks/uniswap/v4/standardExchange/weighted/facets/UniswapV4StandardExchangeWeightedBufferHookHooksFacet.sol'\'' '\''contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookDFPkg.sol'\'' '\''contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookClaimLib.sol'\'' '\''contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultInQueryTarget.sol'\'' '\''contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultInQueryFacet.sol'\'' '\''contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultDFPkg.sol'\'' '\''contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/TestBase_UniswapV4DetfMigrationSnapshot.sol'\'' '\''contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfInitializationLib.sol'\'' '\''contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfDFPkg.sol'\'' '\''contracts/vaults/detf/common/bondNft/DETFFundedBondTarget.sol'\'' '\''contracts/vaults/detf/common/claimToken/StakedDETFTarget.sol'\'' '\''--test-root'\'' '\''test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf'\'' '\''--test-root'\'' '\''test/foundry/spec/vaults/detf/common'\'' '\''--test-root'\'' '\''test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration'\'' '\''--test-root'\'' '\''test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v3/UniswapV3FullSpreadStandardExchangeVaultInQueryFacet_IFacet_Test.t.sol'\'' '\''--test-root'\'' '\''test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_Swap.t.sol'\'' '\''--test-root'\'' '\''test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_Scale.t.sol'\'' '\''--test-root'\'' '\''test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_Fees.t.sol'\'' '\''--test-root'\'' '\''test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_RefundCallback.t.sol'\'' '\''--test-root'\'' '\''test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_OwnerDuringLock.t.sol'\'' '\''--test-root'\'' '\''test/foundry/spec/vaults/standard/erc4626/ERC4626StandardExchange_TransitionQuote.t.sol'\'' '\''--test-root'\'' '\''test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v3/UniswapV3FullSpreadStandardExchangeVault_FullRangeBook.t.sol'\'' '\''--test-root'\'' '\''test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v3/UniswapV3FullSpreadStandardExchangeVault_Previews.t.sol'\'' '\''--test-root'\'' '\''test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeBufferAbi.t.sol'\'' '\''--'\'' '\''-vv'\'''
  'python3' 'scripts/forge-artifacts.py' 'test' 'contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/UniswapV4DetfMigrationSnapshotLib.sol' 'contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/interfaces/IUniswapV4DetfMigrationSnapshot.sol' 'contracts/interfaces/IStandardExchangeFrozenQuoteInputs.sol' 'contracts/utils/StandardExchangeFrozenQuoteLib.sol' 'contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHookCapture.sol' 'contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookTarget.sol' 'contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookHooksTarget.sol' 'contracts/hooks/uniswap/v4/standardExchange/weighted/facets/UniswapV4StandardExchangeWeightedBufferHookHooksFacet.sol' 'contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookDFPkg.sol' 'contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookClaimLib.sol' 'contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultInQueryTarget.sol' 'contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultInQueryFacet.sol' 'contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultDFPkg.sol' 'contracts/vaults/detf/protocols/dexes/uniswap/v4/migration/TestBase_UniswapV4DetfMigrationSnapshot.sol' 'contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfInitializationLib.sol' 'contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfDFPkg.sol' 'contracts/vaults/detf/common/bondNft/DETFFundedBondTarget.sol' 'contracts/vaults/detf/common/claimToken/StakedDETFTarget.sol' '--test-root' 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf' '--test-root' 'test/foundry/spec/vaults/detf/common' '--test-root' 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/migration' '--test-root' 'test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v3/UniswapV3FullSpreadStandardExchangeVaultInQueryFacet_IFacet_Test.t.sol' '--test-root' 'test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_Swap.t.sol' '--test-root' 'test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_Scale.t.sol' '--test-root' 'test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_Fees.t.sol' '--test-root' 'test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_RefundCallback.t.sol' '--test-root' 'test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_OwnerDuringLock.t.sol' '--test-root' 'test/foundry/spec/vaults/standard/erc4626/ERC4626StandardExchange_TransitionQuote.t.sol' '--test-root' 'test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v3/UniswapV3FullSpreadStandardExchangeVault_FullRangeBook.t.sol' '--test-root' 'test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v3/UniswapV3FullSpreadStandardExchangeVault_Previews.t.sol' '--test-root' 'test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeBufferAbi.t.sol' '--' '-vv'
  rc=$?
  printf 'COMMAND_EXIT=%s
' "$rc"
  date -u '+END %Y-%m-%dT%H:%M:%SZ'
  exit "$rc"
} 2>&1 | tee "$TMPDIR/combined.log"
statuses=("${PIPESTATUS[@]}")
printf 'PIPE_COMMAND_EXIT=%s TEE_EXIT=%s
' "${statuses[0]}" "${statuses[1]}"
exit "${statuses[0]}"

