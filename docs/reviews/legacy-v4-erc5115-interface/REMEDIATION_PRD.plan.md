> **Superseded — legacy family deleted (2026-10-15).** Retained as historical evidence only. Do not execute this plan or restore its implementation. See the [removal report](../legacy-v4-removal/EXECUTION_REPORT.md).

# Implementation plan — legacy V4 implements ERC-5115, not Pendle SY

- **Date:** 2026-10-15
- **Status:** WITHDRAWN, 2026-10-15. Do not execute. The owner is deleting `contracts/protocols/dexes/uniswap/v4`.
- **Controlling PRD:** [REMEDIATION_PRD.md](./REMEDIATION_PRD.md). Where this plan conflicts with that PRD, the PRD controls.
- **ID:** REQ-ERC5115. This plan does not split facets and does not close the 24,576-byte overrun.
- **Council:** Astra first-pass plan draft remains from `ses_ec412bcc2ffejKLo7nuoEAqbV0`. That session's plan cross-review failed an attribution check and was not resumed. Authorized Astra replacement `ses_ebdc505a9ffeLLIq4HBAh44TYi` wrote `reviewers/astra-plan-cross.md` and does not recall the old session. Grok `ses_ec4128917ffeeVds3Y2p7xrVjp`. MiniMax replacement `ses_ebdf718feffemWQNf7wuTpapqX` does not recall `ses_ec41255ceffeVhrySLQe8hwwMC`. Kimi replacement `ses_ec3d04e91ffeJa0is24e2jZv06` does not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. No Forge run. Consensus is not proof.
- **Drafts:** `reviewers/astra-plan.md`, `reviewers/grok-plan.md`, `reviewers/minimax-plan.md`, `reviewers/kimi-plan.md`, `reviewers/grok-plan-cross.md`, `reviewers/kimi-plan-cross.md`, `reviewers/minimax-plan-cross.md`, and replacement `reviewers/astra-plan-cross.md`. Those drafts are inputs. This file is the consolidation.

## Closed sentence

Rewrite both existing V4 yield targets without the Pendle bases or full `IERC5115_StandardizedYield` inheritance, implement their assigned money and read methods locally, forward both deposit flag values through the existing guarded `_exchangeIn` token-to-share branch, and locally preserve the redemption route and vault-held-share checks formerly inherited from `NativeStandardYieldMoneyTarget`, removing only obsolete overrides and replacing the vanished `super._standardRoute` fallback with its existing local semantics.

## What not to do

- Do not inherit `IERC5115_StandardizedYield` on either partial target. Import it for events, selectors, and registration only.
- Do not keep `NativeStandardYieldExecutionTarget`, `NativeStandardYieldPreviewTarget`, or `NativeStandardYieldDiscoveryTarget` as a base of either V4 target.
- Do not add the six reads to the IN facet to satisfy the compiler.
- Do not add `LocalCreditLib.requirePretransferCaller` on the deposit token path. That gate stays only on `redeem` when `burnFromInternalBalance` is true, and on the existing share-delivery path inside `_exchangeIn`.
- Do not call the custody helper directly from `deposit`. Both flag values go through `_exchangeIn`.
- Do not keep the payable four-argument `deposit` or the `UnsupportedNativePayment` check.
- Do not create a parallel execution class. Do not split a facet. Do not restore a hop, a self-call, or `via_ir`.
- Do not edit `contracts/vaults/standard/sy/`, `NativeStandardYieldSelectors.sol`, the vendored Pendle interface, or any other family's yield target.
- Do not add or drop an interface-id declaration site. Do not add `IERC5115_StandardizedYield` to the IN facet's own one-entry `facetInterfaces`.
- Do not treat a reviewer session id as an implementation precondition. Do not reset unrelated working-tree changes.
- Do not count hex characters with `wc -c`. Do not measure creation bytecode or the query facet as the size gate.

## Files a later session may edit

Production, in this order:

1. `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutMultiQueryTarget.sol`
2. `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutMultiQueryFacet.sol`
3. `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardYieldExecutionTarget.sol`
4. `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInFacet.sol`
5. `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeDFPkg.sol`

Tests, only after the size gate is recorded and is not a stop:

6. `test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangeInFacet_IFacet_Test.t.sol`
7. `test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangeOutMultiQueryFacet_IFacet_Test.t.sol`
8. `test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchange_Architecture.t.sol`
9. `test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangeVaultHeldRedeem.t.sol`
10. `test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchange_FullRangeBook.t.sol`
11. `test/foundry/spec/protocol/dexes/uniswap/v4/decimals/UniswapV4StandardExchange_FullRangeBook_Decimals.sol`
12. New file `test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchange_ERC5115.t.sol`

No sixth production file is authorized. Do not edit `UniswapV4StandardExchange_LocalLiquidBuffer_H2.t.sol` or its decimals copy. Their `single.deposit` calls are not this vault's SY deposit.

## Step 1 — query target

In `UniswapV4StandardExchangeOutMultiQueryTarget.sol`, stop inheriting `NativeStandardYieldTarget`. Delete the Pendle and shared-SY imports. Keep `IStandardExchangeOut`, `IERC20`, `ERC20Repo`, `FixedPointMathLib`, `Math`, `Config`, and `Accounting`.

Delete `assetInfo`, both public `isValidToken*` overrides, and `_previewExchangeIn`. Keep `previewExchangeOutOneToMany` unchanged.

Implement these six reads on this contract, with no `override` and no interface inheritance:

- `getTokensIn` keeps the current two-token body.
- `getTokensOut` returns `getTokensIn()`.
- `yieldToken` returns `address(0)`.
- `exchangeRate` keeps the current supply, reserve, and `mulSqrt` body, including the empty-supply `1e18` return.
- `previewDeposit` returns `0` when `Config._isValidToken(tokenIn_)` is false. Otherwise it returns `Accounting._previewExchangeIn(IERC20(tokenIn_), amount_, IERC20(address(this)))`.
- `previewRedeem` returns `0` when `Config._isValidToken(tokenOut_)` is false. Otherwise it returns `Accounting._previewExchangeIn(IERC20(address(this)), shares_, IERC20(tokenOut_))`.

Invalid tokens return zero. They do not revert.

## Step 2 — query facet

In `UniswapV4StandardExchangeOutMultiQueryFacet.sol`, replace the Pendle import with `IERC5115_StandardizedYield`. Stop calling `NativeStandardYieldSelectors._appendQuery`.

`facetInterfaces` stays length 2. Index 0 stays `IStandardExchangeOutMulti`. Index 1 becomes `type(IERC5115_StandardizedYield).interfaceId`.

`facetFuncs` is this exact length-7 literal:

1. `IStandardExchangeOutMulti.previewExchangeOutOneToMany.selector`
2. `IERC5115_StandardizedYield.exchangeRate.selector`
3. `IERC5115_StandardizedYield.getTokensIn.selector`
4. `IERC5115_StandardizedYield.getTokensOut.selector`
5. `IERC5115_StandardizedYield.yieldToken.selector`
6. `IERC5115_StandardizedYield.previewDeposit.selector`
7. `IERC5115_StandardizedYield.previewRedeem.selector`

## Step 3 — money target

In `UniswapV4StandardYieldExecutionTarget.sol`, stop inheriting `NativeStandardYieldExecutionTarget`. Keep inheriting `UniswapV4StandardExchangeInTarget`. Import `IERC5115_StandardizedYield` but do not inherit it. Import `NativeStandardYieldErrors`, `LocalCreditLib`, `ISecurePullErrors`, and `ERC20Repo`. Remove the Pendle money-target import.

Delete the payable four-argument `deposit` and both public `isValidToken*` functions.

Replace them with this non-payable deposit. Do not add a caller gate:

```solidity
function deposit(
    address receiver_,
    address tokenIn_,
    uint256 amount_,
    uint256 minimum_,
    bool depositFromInternalBalance_
) public returns (uint256 shares_) {
    Config._requireNotDisabled();
    if (receiver_ == address(0)) revert NativeStandardYieldErrors.InvalidSYReceiver();
    if (amount_ == 0) revert NativeStandardYieldErrors.ZeroSYAmount();
    if (!Config._isValidToken(tokenIn_)) revert NativeStandardYieldErrors.InvalidSYToken(tokenIn_);
    shares_ = _exchangeIn(
        IERC20(tokenIn_),
        amount_,
        IERC20(address(this)),
        minimum_,
        receiver_,
        depositFromInternalBalance_,
        block.timestamp
    );
    if (shares_ < minimum_) revert NativeStandardYieldErrors.SYMinimumNotMet(minimum_, shares_);
    if (shares_ == 0) revert NativeStandardYieldErrors.ZeroSYAmount();
    emit IERC5115_StandardizedYield.Deposit(msg.sender, receiver_, tokenIn_, amount_, shares_);
}
```

`redeem` keeps the current disable check and the current parent body, with the Pendle event replaced and `isValidTokenOut` replaced by `Config._isValidToken`. The internal-balance branch still calls `LocalCreditLib.requirePretransferCaller(msg.sender)` before `_requireVaultHeldShares` and `_redeemVaultHeld`. The external-balance branch still calls `_standardRoute` with the last argument `false`. The outer `amount_ < minimum_` check and the `IERC5115_StandardizedYield.Redeem` event stay. Remove `override`.

Copy these helpers onto this target and remove `override` from the two that had it:

- `_requireVaultHeldShares` reverts `ISecurePullErrors.TransferDeltaInsufficient(shares_, held_)` when `ERC20Repo._balanceOf(address(this))` is below `shares_`.
- `_vaultHeldShares` returns `ERC20Repo._balanceOf(address(this))`.
- `_redeemVaultHeld` still returns `_settleNamedHolder(tokenOut_, shares_, minimum_, receiver_, address(this))`.
- `_settleNamedHolder` stays the current private `nonReentrant` zap-out plus TWAP poke. Do not paste the zap body here.

`_standardRoute` becomes local and has no `super` call:

- If `address(in_) == address(this) && !internal_`, return `_settleNamedHolder(address(out_), amount_, minimum_, receiver_, msg.sender)`.
- Else if `internal_`, run the copied vault-held check, call `_redeemVaultHeld`, revert `SYMinimumNotMet` when the result is below `minimum_`, and return that result.
- Else call `_exchangeIn(in_, amount_, out_, minimum_, receiver_, false, block.timestamp)`, apply the same minimum check, and return that result.

## Step 4 — IN facet

In `UniswapV4StandardExchangeInFacet.sol`, remove `NativeStandardYieldSelectors`. Import `IERC5115_StandardizedYield` for selectors only.

`facetInterfaces` stays the one-entry `IStandardExchangeIn` array. Do not add a second slot.

`facetFuncs` is this exact length-3 literal:

1. `IStandardExchangeIn.exchangeIn.selector`
2. `IERC5115_StandardizedYield.deposit.selector`
3. `IERC5115_StandardizedYield.redeem.selector`

## Step 5 — package registration

In `UniswapV4StandardExchangeDFPkg.sol`, replace the `IStandardizedYield` import with `IERC5115_StandardizedYield`. `facetInterfaces` stays length 15. Change only index 13 to `type(IERC5115_StandardizedYield).interfaceId`. Leave indexes 0 through 12 and index 14 unchanged.

## Step 6 — compile, then measure, then stop if oversized

Record `git status`. Preserve unrelated changes. Do not delete `out/` or `cache_forge/`. Default Foundry profile. Do not set `FOUNDRY_PROFILE=fork`. Do not enable `via_ir`.

From the repository root:

```bash
python3 scripts/forge-artifacts.py build \
  contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutMultiQueryTarget.sol \
  contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutMultiQueryFacet.sol \
  contracts/protocols/dexes/uniswap/v4/UniswapV4StandardYieldExecutionTarget.sol \
  contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInFacet.sol \
  contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeDFPkg.sol
```

If that command fails, stop and report the compiler error. Do not edit tests yet.

Then measure decoded deployed-bytecode length, not hex character count:

```bash
python3 - <<'PY'
import subprocess, sys
names = ("UniswapV4StandardExchangeInFacet", "UniswapV4StandardExchangeOutFacet")
over = False
for name in names:
    raw = subprocess.check_output(["forge", "inspect", name, "deployedBytecode"], text=True).strip().strip('"')
    hex_ = raw[2:] if raw.startswith("0x") else raw
    if len(hex_) % 2:
        sys.exit(f"{name}: odd hex length")
    nbytes = len(hex_) // 2
    print(f"{name} {nbytes}")
    over = over or nbytes > 24576
sys.exit(2 if over else 0)
PY
```

Record both numbers in the execution log before any behavioral test. If the command exits 2, stop and report both numbers. Do not split a facet, restore a hop, add a self-call, enable `via_ir`, or raise an existing `24_576` assertion. A later item may split only after that recorded measurement.

## Step 7 — retarget the named legacy V4 tests

Only if step 6 exits 0. Change `IStandardizedYield` casts and imports to `IERC5115_StandardizedYield` in the six existing test files listed above. Do not retarget another family.

Exact assertion edits:

- IN IFacet control array becomes length 3, in the step 4 order, using `IERC5115_StandardizedYield` selectors. Its interface array stays the one `IStandardExchangeIn` entry.
- Query IFacet control array becomes length 7, in the step 2 order. Its interface index 1 becomes `type(IERC5115_StandardizedYield).interfaceId`.
- Architecture test: `cuts[6].functionSelectors.length` becomes 3. `cuts[15].functionSelectors.length` becomes 7. Loupe assertions for `deposit`, `redeem`, and `previewRedeem` use `IERC5115_StandardizedYield`. Both `deposit` calls gain a final `false`. Redeem calls keep their arguments.
- Full-range book: delete the `assetInfo()` call and the `getRewardTokens().length` assertion. `supportsInterface` expects `type(IERC5115_StandardizedYield).interfaceId`. The two `deposit` calls at the current lines 870 and 912 gain a final `false`. Redeem calls keep their arguments. The import-position `previewRedeem` and `redeem` casts change interface only.
- Decimals full-range book: change the import and the cast. It has no four-argument `deposit` to extend.
- Vault-held redeem: change the import and the casts. Redeem arguments stay.

Do not use a bare `vm.expectRevert()` in the new test. Do not change `single.deposit` calls.

## Step 8 — new proxy behavior test

Add `UniswapV4StandardExchange_ERC5115.t.sol` beside the architecture test, using that test's existing production vault setup. It must assert all of the following on the deployed proxy:

- Loupe address is `address(0)` for `deposit(address,address,uint256,uint256)`, `claimRewards(address)`, `rewardIndexesCurrent()`, `assetInfo()`, `isValidTokenIn(address)`, `isValidTokenOut(address)`, `getRewardTokens()`, `accruedRewards(address)`, and `rewardIndexesStored()`.
- `deposit` and `redeem` resolve to the IN facet. The six reads resolve to the OUT multi-query facet.
- `supportsInterface(type(IERC5115_StandardizedYield).interfaceId)` is true. `supportsInterface(type(IStandardizedYield).interfaceId)` is false.
- `depositFromInternalBalance == false`: an approved caller loses the deposited tokens and the receiver gains the returned shares. Expect the `Deposit` event fields `msg.sender`, receiver, token, amount, and shares.
- `depositFromInternalBalance == true`: transfer the tokens to the vault first, then call from an EOA with no code. The call succeeds, does not pull a second time from that EOA, and mints the returned shares. This is the positive control that no new token-path caller gate was added. Do not expect that EOA to revert.
- A value-bearing call to the five-argument `deposit` is a failed low-level call. Do not use `vm.expectRevert()`.
- `redeem` with `burnFromInternalBalance == true` still emits `Redeem` with the caller, receiver, token, shares, and token-out amount.

## Step 9 — run the named tests

From the repository root, default profile, `via_ir` false:

```bash
python3 scripts/forge-artifacts.py test \
  --test-root test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchange_ERC5115.t.sol \
  --test-root test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangeInFacet_IFacet_Test.t.sol \
  --test-root test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangeOutMultiQueryFacet_IFacet_Test.t.sol \
  --test-root test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchange_Architecture.t.sol \
  --test-root test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangeVaultHeldRedeem.t.sol \
  --test-root test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchange_FullRangeBook.t.sol \
  --test-root test/foundry/spec/protocol/dexes/uniswap/v4/decimals/UniswapV4StandardExchange_FullRangeBook_Decimals.sol \
  -- -vv
python3 scripts/forge-artifacts.py test \
  --test-root test/foundry/spec/vaults/standard/sy/V3FullRangeNativeSY.t.sol \
  -- -vv
```

The second command is the untouched Pendle control. If it fails, stop and report. Do not edit that file or the shared SY bases to make it pass.

Record the commands, toolchain, both facet sizes, and every result. A present assertion is not a pass until that run is reported.

## Done when

- The five production files match the closed sentence and the selector lists above.
- The legacy V4 proxy no longer exposes the nine removed selectors and does expose the eight ERC-5115 methods on their assigned facets.
- Both interface-id sites use `IERC5115_StandardizedYield`. No site was added or dropped.
- False deposit pulls tokens. True deposit uses the existing pretransfer token path and does not add the share-delivery caller gate.
- `V3FullRangeNativeSY.t.sol` still passes without edits.
- Both measured runtime sizes are recorded. Neither hop was restored. If either size exceeds 24,576, the item stops at that report and is not marked done.

## Dissent carried forward

Astra and Kimi wanted `LocalCreditLib.requirePretransferCaller` before a true-flag deposit. The controlling PRD does not. This plan follows the PRD. The new test's code-less true-flag success is the witness for that ruling, not a reversal of it.
