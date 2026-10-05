# Provenance: Hookless analytic swap (D1)

This memo records the no-source-reuse decision for Stage 1 of
[UNISWAP_V4_HOOKLESS_APERTURE_OPTIMAL_SWAP_REFACTOR_PRD.plan.md](../UNISWAP_V4_HOOKLESS_APERTURE_OPTIMAL_SWAP_REFACTOR_PRD.plan.md).
It names decision D1. It does not grant legal clearance beyond the selected non-reuse.
It does not say the implementation is clean-room.

## IndexedEx revision

- Git revision at Stage 1 start: `92cdf89a6fefd9c2ff4f04f74bdade1a7d379f5b`
- Compiler from `foundry.toml` profile `default`: `solc = 0.8.35`, `optimizer_runs = 1`, `via_ir = false`
- `foundry.toml` is not changed by this refactor
- Working tree already contained unrelated modifications when this memo was written. Those files are not part of Stage 1. Stage 1 must not edit them.

## Crane primitives reused

Crane submodule revision observed at the same moment: `b35609951b4951a3c107e267e22844a50c4dc043`.

Reused paths, not copied third-party solver source:

- `lib/crane/contracts/utils/Math.sol` (`Math.mul512`, `Math.mulDiv`)
- `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/SwapMath.sol`
- `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol`
- `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/ProtocolFeeLibrary.sol`
- `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol`
- `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/TickBitmap.sol` (`compress`, `position` only)
- `lib/crane/contracts/protocols/dexes/uniswap/libraries/BitMath.sol`

Unchanged Hookless libraries reused by the isolated planner:

- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultQuoteService.sol`
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultInventoryMath.sol`
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultProtectionMath.sol`
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultRouteTypes.sol`

## Sources not reused

- Aperture repository commit `c40aaa98cf49baf454fbb7a8ee6709862e27038e`
- Aperture license at that commit: BUSL document, change date `2026-07-01`, change license `GPL-2.0-or-later`
- `@aperture_finance/uni-v3-lib` tag `v3.0.3`
- Aperture `OptimalSwap.sol` and Aperture `SwapRouter.sol` are not vendored, copied, or transliterated
- This tree's Hookless sources remain BSL-1.1

## Locked choice

Independent implementation under BSL-1.1. No source copy. No clean-room claim.
Research read the Aperture and `uni-v3-lib` sources on 2026-10-03. That access remains recorded.
This memo does not authorize Stage 2, deployment, or a license opinion beyond non-reuse.
