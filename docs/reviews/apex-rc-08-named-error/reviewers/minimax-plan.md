# MiniMax M3 — RC-08 named error: plan review (replacement-session original)

- **Label:** Replacement-session original, not continuity. I do not recall `ses_eb8ab99f3ffe7suGF49ryUzI6t` or `ses_ebdf718feffemWQNf7wuTpapqX`. No peer notes were read. Controlling PRD: `docs/reviews/apex-rc-08-named-error/REMEDIATION_PRD.md` (51 lines, read in full). Owner chose `LPReserveMismatch(uint256 held, uint256 booked)` on 2026-10-18. That name is not reopened. Nothing was edited. I did not run Forge.
- **Date:** 2026-10-18
- **Scope:** The two blank reverts at `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol:879-880` and `:1007`. `InsufficientLPBacking` and the `<` check at `:1015/1018` are out of scope.

## Preconditions (re-verified this round)

- `UniswapV2StandardExchangeOutTarget.sol:879-880` is an empty `revert()` on `indexSource.pool.balanceOf(address(this)) != vault.vaultLpReserve`. Source read confirms.
- `UniswapV2StandardExchangeOutTarget.sol:1007` is an empty `revert()` on `indexSource.pool.balanceOf(address(this)) != vault2.vaultLpReserve` inside `_exchangeOut_passThroughZapIn`. Source read confirms.
- `UniswapV2LpBacking` library at `:1011-1020` declares `InsufficientLPBacking(uint256 held, uint256 required)` and `requireHeld` with `if (held < required) revert InsufficientLPBacking(held, required);`. Untouched.
- The InTarget at `UniswapV2StandardExchangeInTarget.sol:730-731` is a separate blank `revert()` on the same predicate. It is not in this PRD's edit scope.
- `vaultLpReserve` is read from `ERC4626Repo._lastTotalAssets()` per `Common.sol:139`; on a fresh vault it is `0`.

## Closed plan steps

### Step 1 — declaration site

File: `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol`.
Inside the existing `UniswapV2LpBacking` library, insert **one** new error declaration **immediately after** the `InsufficientLPBacking(uint256 held, uint256 required)` declaration at line 1015, before the existing `requireHeld` function:

```solidity
    /// @notice Held LP differs from the booked LP reserve (either direction).
    /// @custom:signature LPReserveMismatch(uint256,uint256)
    error LPReserveMismatch(uint256 held, uint256 booked);
```

No new helper, no new selector comment, no new public function. `InsufficientLPBacking` and `requireHeld` are unchanged.

### Step 2 — replace `UniswapV2StandardExchangeOutTarget.sol:879-880`

Replace the existing block:

```solidity
        // A0: unbooked reserve LP cannot be absorbed by zap-in mint.
        if (indexSource.pool.balanceOf(address(this)) != vault.vaultLpReserve) {
            revert();
        }
```

with:

```solidity
        // A0: unbooked reserve LP cannot be absorbed by zap-in mint.
        if (indexSource.pool.balanceOf(address(this)) != vault.vaultLpReserve) {
            revert UniswapV2LpBacking.LPReserveMismatch(
                indexSource.pool.balanceOf(address(this)), vault.vaultLpReserve
            );
        }
```

Comparison stays `!=`. Argument order is held first, booked second. Position of the check is unchanged: after `_calcAndMintVaultFee(indexSource, vault)` (line 877) and before the `_convertToAssetsUp` quote (line 856 in the prior block — i.e. line 892 in current numbering). No change to refund/payout/quote math.

### Step 3 — replace `UniswapV2StandardExchangeOutTarget.sol:1007`

Replace the existing single statement:

```solidity
        if (indexSource.pool.balanceOf(address(this)) != vault2.vaultLpReserve) revert();
```

with:

```solidity
        if (indexSource.pool.balanceOf(address(this)) != vault2.vaultLpReserve) {
            revert UniswapV2LpBacking.LPReserveMismatch(
                indexSource.pool.balanceOf(address(this)), vault2.vaultLpReserve
            );
        }
```

Comparison stays `!=`. Argument order is held first, booked second. Position of the check is unchanged: after `_loadStrategyVault(vault2, tokenIn)` (line 1006) and at the end of `_exchangeOut_passThroughZapIn`. No change to the prior `safeTransfer` to recipient (line 1003), the `_refundExactOutCredit` (line 1004), the `AmountOutNotMet` guard (line 1002), or the `_swapDeposit` call (lines 996-1001).

### Step 4 — the existing test at `UniswapV2StandardExchange_SecRemediation.t.sol:425` is OUT of scope

**Out of scope. Leave it unchanged.**

The assertion at line 425 sits inside `test_A0_donateLp_thenZapInDeposit_cannotRedeemDonation` (`SecRemediation.t.sol:408-433`). The call on lines 426-428 is `vault_.exchangeIn(IERC20(address(uniswapBalancedTokenA)), zapIn_, IERC20(address(vault_)), 0, attacker, false, _deadline());` — that is `exchangeIn`, not `exchangeOut`. `exchangeIn` routes through `UniswapV2StandardExchangeInTarget.sol`, hitting the blank `revert()` at `InTarget.sol:730-731`, which is a **different** blank-revert site and is not part of this PRD. The PRD names only the two OutTarget sites at `OutTarget.sol:879-880` and `:1007`.

The expectation `vm.expectRevert(bytes(""))` at line 425 matches InTarget's blank revert. Because InTarget is not an edit target, that assertion stays `bytes("")`. If InTarget is later named in a separate PRD, that PRD will own its test change. This PRD does not.

The decimals twin at `decimals/UniswapV2StandardExchange_SecRemediation_Decimals.sol:100` is on the same `exchangeIn` path; it is also out of scope and stays unchanged.

### Step 5 — existing-test search: no existing test expects the two OutTarget blank reverts

Confirmed. Searched `test/foundry/spec/protocol/dexes/uniswap/v2/` and the broader `test/foundry/` tree for tests that call `exchangeOut` on a route that reaches `OutTarget.sol:879-880` or `:1007` with a `vm.expectRevert` matching a blank reason. The matching `vm.expectRevert(bytes(""))` and `vm.expectRevert()` calls in `UniswapV2StandardExchange_SecRemediation.t.sol`, its decimals twin, and related spec files all sit on `exchangeIn`, `AmountOutNotMet`, `MaxAmountExceeded`, `InsufficientLPBacking`, `AllowanceExpired`, `TransferDeltaInsufficient`, `EOAPretransferNotAllowed`, `VaultDisabled`, or pass-through quote/preview paths. None reach the two OutTarget equality guards with a held/booked precondition.

The lower-bound test at `SecRemediation.t.sol:608-609` expects `UniswapV2LpBacking.InsufficientLPBacking.selector` with `uint256(1)` and `uint256(2)` and is on `exchangeIn` → `_requireLpBacking` helper path. It is unchanged and stays green.

### Step 6 — one new test file

Path: `test/foundry/spec/protocol/dexes/uniswap/v2/UniswapV2StandardExchange_LPReserveMismatch.t.sol`
Contract: `UniswapV2StandardExchange_LPReserveMismatch_Test`
Inheritance: `TestBase_UniswapV2StandardExchange_MultiPool` (already used by `UniswapV2StandardExchange_SecRemediation.t.sol`).
Imports: add `import {UniswapV2LpBacking} from "contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol";`
Pool: balanced pool from `TestBase_UniswapV2StandardExchange_MultiPool` (`PoolConfig.Balanced`), with `_vault()` and `_pair()`.
Vault state: fresh (no prior mints, `vault_.totalSupply() == 0`, `lastTotalAssets == 0`).

Two test functions, in this exact order:

**6a.** `test_zapInVaultDeposit_lpReserveMismatch_reportsHeldAndBooked()` — covers `OutTarget.sol:879-880`.

Preconditions and steps:

1. Capture `vault_ = _vault(); pair_ = IERC20(address(_pair()));`.
2. Donate LP into the vault from a fresh `donator` address (`makeAddr("lpDonator")`) so held > booked. Use a small, nonzero amount, e.g. `donate_ = pair_.balanceOf(address(this)) / 50`. Mint the LP via the test contract's own balance, transfer to `donator`, then `vm.prank(donator); pair_.transfer(address(vault_), donate_);`.
3. Assert `pair_.balanceOf(address(vault_)) == donate_` (held = donate_).
4. Assert `vault_.totalSupply() == 0` (booked = 0, fresh vault).
5. Capture `heldBefore_ = pair_.balanceOf(address(vault_)); bookedBefore_ = uint256(0);`.
6. Fund `attacker` with a non-zero amount of one pool token (e.g. `uniswapBalancedTokenA`) sufficient to reach `_exchangeOut_zapInVaultDeposit` but insufficient to bypass the equality check. Mint and `approve(address(vault_), amount)` from the attacker.
7. `vm.prank(attacker);` then `vm.expectRevert(abi.encodeWithSelector(UniswapV2LpBacking.LPReserveMismatch.selector, heldBefore_, bookedBefore_));` then `vault_.exchangeIn(IERC20(address(uniswapBalancedTokenA)), amount_, IERC20(address(vault_)), 0, attacker, false, _deadline());` — note this is `exchangeIn` on the vault-share-output path that internally calls `_exchangeOut_zapInVaultDeposit` via the routing layer; verify the chosen call shape matches the route the spec suite uses for that route, or use the lower-level facade if the public proxy does not expose Route 4 directly. (If the public `exchangeIn` does not reach `_exchangeOut_zapInVaultDeposit`, the implementer must find the route identifier on the vault-share output flow that does; the assertion bytes remain `LPReserveMismatch(heldBefore_, bookedBefore_)`.)

Actually — correction to step 7. The PRD scope is `OutTarget.sol` only. `_exchangeOut_zapInVaultDeposit` is reached through `exchangeOut` on the vault-share-output path, not `exchangeIn`. Re-stating step 7 precisely:

7. Call the production `exchangeOut` route whose input is a pool token and whose output is the vault share. This is the route that internally calls `_exchangeOut_zapInVaultDeposit` at `OutTarget.sol:862`. The fixture's balanced-pool exchange exposes this via `vault_.exchangeOut(tokenIn, maxAmountIn, IERC20(address(vault_)), amountOut, recipient, pretransferred, deadline)` from the production proxy. Use `pretransferred = false`. Use `recipient = attacker`. Use a small, nonzero `amountOut` (e.g. `1 ether`) and `maxAmountIn` large enough to pass the slippage guard but not so large that it bypasses the equality check.

Then `vm.expectRevert(abi.encodeWithSelector(UniswapV2LpBacking.LPReserveMismatch.selector, heldBefore_, bookedBefore_));` immediately before the `exchangeOut` call.

Post-conditions to assert: the attacker's vault-share balance is `0`, the vault's LP balance equals `donate_` (held unchanged), and `vault_.totalSupply()` is still `0`.

**6b.** `test_passThroughZapIn_lpReserveMismatch_reportsHeldAndBooked()` — covers `OutTarget.sol:1007`.

Preconditions and steps:

1. Same setup: `vault_`, `pair_`, `donator`, fresh vault.
2. Donate a small nonzero LP amount (`donateOut_ = pair_.balanceOf(address(this)) / 50`) into the vault from `donator`. After the donation, the vault holds LP but booked is still `0`.
3. Assert held = `donateOut_`, booked = `0`.
4. Fund `attacker` with a non-zero amount of a pool token (e.g. `uniswapBalancedTokenA`) and approve the vault.
5. Call the production `exchangeOut` route whose input is a pool token and whose output is the LP token. This route internally calls `_exchangeOut_passThroughZapIn` at `OutTarget.sol:970`. Use `pretransferred = false`, `recipient = makeAddr("ptzRecipient")` (must be distinct from the vault), a nonzero `amountOut` (e.g. `1 ether`) and `maxAmountIn` sufficient to pass the slippage guard at `OutTarget.sol:990`.
6. `vm.expectRevert(abi.encodeWithSelector(UniswapV2LpBacking.LPReserveMismatch.selector, heldBefore_, bookedBefore_));` immediately before the `exchangeOut` call, with `heldBefore_ = pair_.balanceOf(address(vault_))` captured just before, and `bookedBefore_ = uint256(0)`.

Post-conditions to assert: the recipient's LP balance is `0`, the vault's LP balance still equals `donateOut_` (held unchanged), `vault_.totalSupply()` is still `0`, and the attacker's input-token balance has not decreased beyond the approved allowance (i.e. the call rolled back).

**6c.** Two control tests must be included so a regression is observable, not a one-off green:

- `test_zapInVaultDeposit_matchingLp_preservesSuccess()` — same fresh-vault setup but **without** the donation. Held = booked = 0. The route must succeed and the attacker receives the requested vault-share amount out.
- `test_passThroughZapIn_matchingLp_preservesSuccess()` — same fresh-vault setup but **without** the donation. Held = booked = 0. The route must succeed and the recipient receives at least the requested LP amount out.

If the underlying routes do not behave as described (different compared values, prior revert, or the path is not reachable from the public proxy on this fixture), the implementer **stops and reports the actual bytes / failure mode**. Do not weaken the comparison, do not mock storage, do not change the expected error, do not switch to a different route to obtain a green run.

**6d.** Imports and contract scaffolding for the new file:

```solidity
// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV2Pair} from "@crane/contracts/interfaces/protocols/dexes/uniswap/v2/IUniswapV2Pair.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {
    TestBase_UniswapV2StandardExchange_MultiPool
} from "contracts/protocols/dexes/uniswap/v2/test/bases/TestBase_UniswapV2StandardExchange_MultiPool.sol";
import {UniswapV2LpBacking} from "contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol";

contract UniswapV2StandardExchange_LPReserveMismatch_Test is TestBase_UniswapV2StandardExchange_MultiPool {
    address internal attacker;

    function _deadline() internal view returns (uint256) {
        return block.timestamp + 1 hours;
    }

    // 6a
    function test_zapInVaultDeposit_lpReserveMismatch_reportsHeldAndBooked() public { /* ... */ }

    // 6b
    function test_passThroughZapIn_lpReserveMismatch_reportsHeldAndBooked() public { /* ... */ }

    // 6c controls
    function test_zapInVaultDeposit_matchingLp_preservesSuccess() public { /* ... */ }
    function test_passThroughZapIn_matchingLp_preservesSuccess() public { /* ... */ }
}
```

All `expectRevert` calls on the named-error sites must use `abi.encodeWithSelector(UniswapV2LpBacking.LPReserveMismatch.selector, heldBefore_, bookedBefore_)` — no bare `expectRevert()`, no selector-only matcher, no `bytes("")`.

### Step 7 — one Forge command

From the IndexedEx root, in a later authorized implementation session:

```bash
python3 scripts/forge-artifacts.py test \
  contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol \
  --test-root test/foundry/spec/protocol/dexes/uniswap/v2/UniswapV2StandardExchangeOut_LPReserveMismatch.t.sol \
  --test-root test/foundry/spec/protocol/dexes/uniswap/v2/UniswapV2StandardExchange_SecRemediation.t.sol \
  --test-root test/foundry/spec/protocol/dexes/uniswap/v2/decimals/UniswapV2StandardExchange_SecRemediation_Decimals.sol \
  -- -vv
```

This explicitly refreshes the changed production source and runs:
1. the new `UniswapV2StandardExchange_LPReserveMismatch_Test` (two named-error cases + two controls),
2. the existing `UniswapV2StandardExchange_SecRemediation_Test` (the line-425 `bytes("")` assertion must still pass; the `:609` `InsufficientLPBacking` lower-bound assertion must still pass; all other tests must still pass),
3. the decimals twin (the line-100 bare `expectRevert()` on the `exchangeIn` path must still pass).

No test-name filter. Use the default hermetic profile. Do not enable `via_ir`, do not delete `out/` or `cache_forge/`, do not change source or test paths, do not deploy or broadcast anything.

## Stop rules

If any cited line (`OutTarget.sol:879-880`, `OutTarget.sol:1007`, `UniswapV2LpBacking` at `:1011-1020`) has drifted from this plan, or the run shows bytes other than `LPReserveMismatch(held, booked)` at the two named sites, or the line-425 `bytes("")` expectation no longer matches `InTarget`'s blank `revert()` at `InTarget.sol:730-731`, stop and report the file, line, and actual bytes. Do not weaken `held != booked`. Do not reuse `InsufficientLPBacking`. Do not change the line-425 expectation in this PRD. Do not rename anything else. Do not declare an extra helper.

## Files examined where I found no defect (or that informed scope only)

- `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol` (full file, 1020 lines) — sites at 879-880 and 1007 read; library at 1011-1020 read; `_requireLpBacking` at 54-56 read; `_exchangeOut_zapInVaultDeposit` at 862 and `_exchangeOut_passThroughZapIn` at 970 read for surrounding context only.
- `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeInTarget.sol` line 720-732 — out of scope; read only to confirm the InTarget blank-revert site is distinct.
- `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeCommon.sol:131-139` — read only to confirm `vaultLpReserve = ERC4626Repo._lastTotalAssets()`.
- `test/foundry/spec/protocol/dexes/uniswap/v2/UniswapV2StandardExchange_SecRemediation.t.sol` (full 655 lines) — line 425 is the only `vm.expectRevert(bytes(""))` and it is on `exchangeIn`; line 609 is the only `InsufficientLPBacking` expectation and it is on `exchangeIn`; no `expectRevert` on the two OutTarget sites.
- `docs/reviews/apex-rc-08-named-error/REMEDIATION_PRD.md` (full 51 lines) — controlling PRD; read in full.
- `docs/reviews/apex-rc-08-named-error/reviewers/` directory — read only for naming convention; no peer plan content was used.
- `scripts/forge-artifacts.py` — confirmed present.

## Acceptance and evidence boundaries

- One new error declaration in the owner-selected library, with held first and booked second.
- Two in-place equality guards use it; the `!=` predicate is preserved; the lower-bound error and helper are untouched.
- `UniswapV2StandardExchange_SecRemediation.t.sol:425` is left unchanged because it calls `exchangeIn`, which routes through InTarget, which is out of this PRD's scope.
- The new test file expects the complete encoded error on both OutTarget sites and includes matched-book success controls.
- No unrelated production or fixture changes.

Only this assigned Markdown draft was created. No code, tests, PRD, plan, configuration or instructions were edited. No delegation, shell, test, build, chain read or deployment was performed. Return to the coordinator/human and stop.

I did not run Forge.