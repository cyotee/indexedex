# Rebasing-aware ERC4626 SY/SE validation

**Date:** 2026-09-11  
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
| F-10/18, ADV-04/11 | `RebasingAwareERC4626_StakedDETF.t.sol` (rebasing claim-token stand-in + no `synchronizeRewards` in wrapper bytecode) |
| F-11 | dropped (TokenStaking) |
| API-16–18, F-16/17, §8.3 CP | `RebasingAwareERC4626_Buffers.t.sol` + `UniswapV4SeBufferHookLegLib.t.sol` |
| §8.3 Weighted | `RebasingAwareERC4626_Buffers_Weighted.t.sol` |
| §8.3 Orbital | `RebasingAwareERC4626_Buffers_Orbital.t.sol` |
| §8.3 Curve quad | `RebasingAwareERC4626_Buffers_Curve.t.sol` |
| §8.3 Balancer quad V4 hook | `RebasingAwareERC4626_Buffers_Balancer.t.sol` |
| §8.3 Dual CP (standalone) | `RebasingAwareERC4626_Buffers_Dual.t.sol` |
| §8.3 Legacy single | existing `test/foundry/spec/hooks/uniswap/v4/standardExchange/single/` regression |
| D60/D66 | out of functional scope |
| PKG-04–06, F-12 | `RebasingAwareERC4626_LaunchCompatibility.t.sol` |

Independent oracle: `RebasingAwareOracle.sol` (direct integer math) and `oracle/generate_vectors.py` / `oracle/vectors.json`.

## Focused hermetic result

`forge build` then `forge test --match-path 'test/foundry/spec/protocols/staking/rebasingVault/*.t.sol'`: **105 passed, 0 failed**.

Captured under the implementer scratch directory:

- `forge-build.log`
- `forge-test-focused.log`
- `rebasing-wrapper-tests.log`
- `rebasing-quote-tests.log`
- `rebasing-packaging-tests.log`
- `rebasing-integration-tests.log`

## Campaign evidence

`forge config --json` under overrides: `fuzz.runs=10000`, `fuzz.seed=0x1`, `invariant.runs=1000`, `invariant.depth=100`, `invariant.fail_on_revert=true`. Captured in `forge-config.json`.

Seeds `0x…01`, `0x…11`, `0x…0101` each: 12 fuzz properties × 10,000 runs passed; 5 invariants × 1,000 runs at depth 100 passed with `fail_on_revert=true` and 0 unexpected handler reverts. Handler coverage per 100k-call campaign includes deposit, redeem, share transfer, donate, asset-pretransfer reject, SY internal redeem, second-vault deposit, and zero-deposit revert. Logs: `rebasing-fuzz.log`, `rebasing-invariant.log`.

## Buffer amendment

Owner-approved companion: `contracts/hooks/uniswap/v4/standardExchange/REBASING_WRAPPER_SHARE_INVENTORY_AMENDMENT.md`. Static wrapper-share inventory: `pairToken == standardExchange` and `IERC4626.asset()` is a different non-zero address. CP identity buffer/unwrap; 19–36 share decimals; PairSeOverlap exception. Dual CP standalone only. Legacy single compile/regression. D60/D66 unchanged.

Composed evidence:

| Family | Test file | Coverage |
|---|---|---|
| CP single | `RebasingAwareERC4626_Buffers.t.sol` | processArgs 19–36, join/exit, quote/rebase, raw-asset pretransfer reject, zero wrapper fees |
| Weighted | `RebasingAwareERC4626_Buffers_Weighted.t.sol` | mixed wrapper/raw legs, processArgs, join/exit, rebase |
| Orbital | `RebasingAwareERC4626_Buffers_Orbital.t.sol` | wrapper SE leg, processArgs, add/remove liquidity, rebase |
| Curve quad | `RebasingAwareERC4626_Buffers_Curve.t.sol` | wrapper-eligible leg, processArgs, join/exit, rebase |
| Balancer quad V4 hook | `RebasingAwareERC4626_Buffers_Balancer.t.sol` | V4 hook only (not Balancer-hosted DETF), processArgs, join/exit, rebase |
| Dual CP | `RebasingAwareERC4626_Buffers_Dual.t.sol` | mixed wrapper leg, both-wrapper processArgs, join/exit; standalone, no DETF factory claim |
| Legacy single | existing family suite | compile/regression only |

Family identity buffering: `_buffer` / `_unwrap` / claim / dust skip when `pair == se`. Ordinary `pair == se` still reverts `InvalidSE` / `TokenNotInVaultTokens`. Ordinary 19-decimal inventory still reverts `InvalidDecimals`.

## Unresolved

- TokenStaking consumer suites: dropped by owner.
- Full default `forge test` (entire hermetic suite) was not run; focused rebasingVault suites and campaigns were.
- Dual CP is standalone (no DETF factory claim). D60 Balancer-hosted DETFs and D66 unfinished Slipstream remain out of functional scope.
