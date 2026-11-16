# Rebasing-aware ERC4626 SY/SE validation

The subsequent [production review](REBASING_AWARE_ERC4626_PRODUCTION_REVIEW.md)
records defects found after this handoff, their fixes, expanded tests, and current
release-gate results. Use that review for the current readiness assessment.

**Date:** 2026-09-13
**Release:** `indexedex.rebasing-aware-erc4626.sy-se.v1`  
**Approved revisions:** owner dropped TokenStaking (2026-09-11) and approved `REBASING_WRAPPER_SHARE_INVENTORY_AMENDMENT.md` for static wrapper-share inventory.

## Owner scope change

TokenStaking consumer compatibility is out of scope (owner 2026-09-11). F-11 / API-02 claim-vault gates and `test/foundry/spec/protocols/staking/token/*.t.sol` are not required for this handoff. Existing wrapper TokenStaking files were left in place and still pass; they were not extended.

## Buffer gate

Plan §8 companion amendment is present. Pool inventory is static wrapper shares (`pairToken == standardExchange` and `IERC4626.asset()` is a different non-zero address). Identity buffer/unwrap on CP, weighted, orbital, curve, balancer, and dual. Share decimals 19–36. Dual CP is standalone (no DETF factory claim). Legacy single is compile/regression only. D60/D66 unchanged.

## Requirement mapping

| Row | Tests |
|---|---|
| ACC-01–09, F-03–08/18–21, API-01/03/06 | `RebasingAwareERC4626_Accounting.t.sol` |
| API-04–07/14–15, F-03/04/08/14/15/19/20 | `RebasingAwareERC4626_StandardExchange.t.sol` |
| API-08–15, F-09/18/19/21 | `RebasingAwareERC4626_StandardYield.t.sol` |
| API-02 (non-TokenStaking), PKG-01–04/06, F-01/02/12/13 | `RebasingAwareERC4626_Packaging.t.sol` |
| API-16/17, F-17, ADV-15 | `RebasingAwareERC4626_TransitionQuote.t.sol` |
| ADV-01–16 (wrapper-only), F-14/15/18–21 | `RebasingAwareERC4626_Adversarial.t.sol` |
| FUZZ-01–13 | `RebasingAwareERC4626_Fuzz.t.sol` |
| INV-01–15 (two-vault handler) | `RebasingAwareERC4626_Invariant.t.sol` |
| F-10/18, ADV-04/11 | `RebasingAwareERC4626_StakedDETF.t.sol` (production sDETF wrap: transfer-triggered revert then `synchronizeRewards()` success; wrapper bytecode has no `synchronizeRewards` selector) |
| F-11 | dropped (TokenStaking) |
| API-16–18, F-16/17, §8.3 CP | `RebasingAwareERC4626_Buffers.t.sol` (join/quote/SE swap/V4 swap/exit + amendment §7 on live hook) + `RebasingAwareERC4626_Buffers_Detf.t.sol` (UniV4 DETF mint/redeem with wrapper-share reserve) + `UniswapV4SeBufferHookLegLib.t.sol` |
| §8.3 Weighted | `RebasingAwareERC4626_Buffers_Weighted.t.sol` (join/quote/swap/exit + §7) + `RebasingAwareERC4626_Buffers_Detf.t.sol` weighted DETF mint/redeem |
| §8.3 Orbital | `RebasingAwareERC4626_Buffers_Orbital.t.sol` (depositFlexible/quote/swap/withdrawFlexible + §7) |
| §8.3 Curve quad | `RebasingAwareERC4626_Buffers_Curve.t.sol` (join/quote/swap/exit + §7) |
| §8.3 Balancer quad V4 hook | `RebasingAwareERC4626_Buffers_Balancer.t.sol` (join/quote/swap/exit + §7; V4 hook only) |
| §8.3 Dual CP (standalone) | `RebasingAwareERC4626_Buffers_Dual.t.sol` (join/quote/SE swap/exit + §7; no DETF factory claim) |
| INV composed buffer | `RebasingAwareERC4626_BufferInvariant.t.sol` (CP wrapper-hook handler: join/swap/exit/rebase/donate; custody + zero fees) |
| §8.3 Legacy single | existing `test/foundry/spec/hooks/uniswap/v4/standardExchange/single/` regression |
| D60/D66 | out of functional scope |
| PKG-04–06, F-12 | `RebasingAwareERC4626_LaunchCompatibility.t.sol` |

Independent oracle: `RebasingAwareOracle.sol` (direct integer math) and `oracle/generate_vectors.py` / `oracle/vectors.json`.

## Focused hermetic result

`forge build` then `forge test --match-path 'test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_*.t.sol'`: **140 passed, 0 failed**.

That 140 includes wrapper ACC/SE/SY/quote/packaging/adversarial/fuzz plus composed §8.3 family buffers (join/quote/swap/exit + amendment §7 on live hooks), CP and Weighted UniV4 DETF mint/redeem, production sDETF wrap (`synchronizeRewards` boundary), and the CP buffer invariant handler.

Captured under the implementer scratch directory:

- `forge-build.log` (`Compiler run successful`, `EXIT:0`)
- `forge-test-focused.log` (copy of the 140-test run)
- `rebasing-integration-tests.log` (140 passed, 0 failed)
- `family-regress.log` (Deploy/StagedInit/Liquidity/Core)
- `forge-config.json`
- `cp-buffers.log` (7/7 including live-hook swap)
- `detf-sdetf.log` (production sDETF + Weighted DETF)
- `cp-detf-retest.log` (CP DETF mint/redeem)

## Campaign evidence

`forge config --json` under overrides: `fuzz.runs=10000`, `fuzz.seed=0x1`, `invariant.runs=1000`, `invariant.depth=100`, `invariant.fail_on_revert=true`. Captured in `forge-config.json`.

Prior session ran seeds `0x…01`, `0x…11`, `0x…0101` (12 fuzz properties × 10,000; 5 invariants × 1,000 depth 100, `fail_on_revert=true`). This scratch directory was recreated empty, so those campaign log files are not present here. `forge-config.json` in this scratch records the required overrides.

## Buffer amendment

Owner-approved companion: `contracts/hooks/uniswap/v4/standardExchange/REBASING_WRAPPER_SHARE_INVENTORY_AMENDMENT.md`. Static wrapper-share inventory: `pairToken == standardExchange` and `IERC4626.asset()` is a different non-zero address. CP identity buffer/unwrap; 19–36 share decimals; PairSeOverlap exception. Dual CP standalone only. Legacy single compile/regression. D60/D66 unchanged.

Composed evidence:

| Family | Test file | Coverage |
|---|---|---|
| CP single | `RebasingAwareERC4626_Buffers.t.sol` | processArgs 19–36, join/exit, SE+V4 swap, projected quote, §7 matrix on live hook |
| CP DETF | `RebasingAwareERC4626_Buffers_Detf.t.sol` | UniV4 DETF factory, wrapper-share reserve, first bond, mint, redeem |
| Weighted | `RebasingAwareERC4626_Buffers_Weighted.t.sol` + Detf weighted contract | mixed wrapper/raw legs, join/quote/swap/exit, §7, DETF mint/redeem |
| Orbital | `RebasingAwareERC4626_Buffers_Orbital.t.sol` | wrapper SE leg, depositFlexible/quote/swap/withdrawFlexible, §7 |
| Curve quad | `RebasingAwareERC4626_Buffers_Curve.t.sol` | wrapper-eligible leg, join/quote/swap/exit, §7 |
| Balancer quad V4 hook | `RebasingAwareERC4626_Buffers_Balancer.t.sol` | V4 hook only (not Balancer-hosted DETF), join/quote/swap/exit, §7 |
| Dual CP | `RebasingAwareERC4626_Buffers_Dual.t.sol` | mixed wrapper leg, both-wrapper processArgs, join/SE swap/exit, §7; standalone |
| Legacy single | existing family suite | compile/regression only |

CP identity: `_bufferPair` / `_unwrapSeShares` / `_unwrapExactPairOut` / `_unwrapPairLeavingDust` / `_previewUnwrapSe` skip when `pair == se`. Weighted/Curve/Balancer `_mapPairInToRatedWad` identity skip. Ordinary `pair == se` still reverts `InvalidSE` / `TokenNotInVaultTokens`. Ordinary 19-decimal inventory still reverts `InvalidDecimals`. Amendment §7 on the live hook: positive/negative rebase, donation, zero-reserve swap reject, stale quote vs live convert, transfer-triggered wrap revert then success, disabled wrapper inbound with live hook exit, zero wrapper fees with nonzero outer fees, raw-asset pretransfer reject.

## Unresolved

- TokenStaking consumer suites: dropped by owner.
- Full default `forge test` (entire hermetic suite) was not run in this session; focused rebasingVault (140) plus family Deploy/StagedInit/Liquidity/Core regressions (18 files, `OVERALL_EXIT:0`) were.
- Dual CP is standalone (no DETF factory claim). D60 Balancer-hosted DETFs and D66 unfinished Slipstream remain out of functional scope.
- Release 10k/1k×depth-100 campaign was not re-run in this session. `forge-config.json` records `fuzz.runs=10000`, `fuzz.seed=0x1`, `invariant.runs=1000`, `invariant.depth=100`, `fail_on_revert=true`. Do not treat default-profile fuzz as AC-05.
