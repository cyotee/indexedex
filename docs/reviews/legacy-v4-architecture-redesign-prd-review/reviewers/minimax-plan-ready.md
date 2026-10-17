# REQ-V4-01 internal-settlement question pass

- **Date:** 2026-10-14
- **Reviewer:** MiniMax M3, independent question pass. No peer notes read. No REDESIGN_PRD.md or REMEDIATION_PRD.md was read or written this round except the cited draft and the cross-referenced current source files. No Forge run. No exploit procedure.
- **Question:** does the rewritten design still need an owner decision before a PRD?
- **Verdict:** **Ready. No owner question remains.** The plan can be written from the rewritten document alone. The owner's ruling at PRD line 9 closes every choice.

## What the owner has already ruled

The PRD at line 9 records the owner's ruling on every question the cross-review and prior question passes flagged. I read that line and confirm it closes the prior asks.

### Question 1 — Must `executeNamedHolderRedemption` be deleted in this item?

The owner ruled: "Delete `executeNamedHolderRedemption`." (PRD line 9, sentence 1.) That deletion is part of this item. Closed.

Kimi and Astra previously suggested keeping `executeNamedHolderRedemption` as a compatibility alias; the owner rejected that. The ruling is clear: the function goes. The four-argument `executeZapOutExactIn` is also deleted (sentence 2). The only remaining wrapper is `executeZapInDeposit`, which the public deposit call still uses; the implementer must not touch it.

### Question 2 — Must REQ-V4-02's disable check be included in this item?

The owner ruled: "Include the REQ-V4-02 disable check." (PRD line 9, sentence 3.) That inclusion is part of this item. Closed.

Astra and Kimi previously asked whether the check was in scope; the owner selected "include." The disable check goes on the legacy V4 direct yield path, consistent with the existing production at `RebasingAwareStandardYieldTarget.sol:57-59` and the current `UniswapV4StandardYieldExecutionTarget.sol:14-15`. No owner question on scope.

### Question 3 — Is `address(this)` safe to remove from the four-argument `executeZapOutExactIn`?

The owner ruled: "Delete the four-argument `executeZapOutExactIn` on the legacy V4 delegate." (PRD line 9, sentence 2.) The wrapper goes. The public share exit (the `UniswapV4StandardExchangeInTarget` share-exit branch) calls `_executeZapOutExactIn(..., address(this))` directly (PRD line 38). The owner rules: "Replaces the IN-target's share-exit call with a direct internal call to `_executeZapOutExactIn(..., address(this))` and removes the delegate helper invocation." The direct internal call preserves the holder as `address(this)` because the shares were already pulled onto the vault by `_secureShareDelivery` (line 37). The caller is not the holder; the vault is.

## No other owner question remains

The PRD at lines 21-23 names the new callback name (`recordNestedDeposit`). The PRD at lines 25-30 names the removed callback. The PRD at lines 36-40 names the four-argument `executeZapOutExactIn` and the direct call that replaces it. The PRD at lines 18-19 names the existing and new roles. The PRD at line 9 names the Req-V4-02 disable check inclusion.

I read the cross-referenced current source files:

- `IUniswapV4StandardExchangeDFPkg.sol:24-48` lists the 16 current facet fields, including `uniswapV4StandardExchangeCallbackFacet` (line 30) and the existing `executeNamedHolderRedemption`/four-argument `executeZapOutExactIn` delgates.
- The implementer must (a) remove the `executeNamedHolderRedemption` and `executeZapOutExactIn` fields from the delegate contract, (b) rewire the public share-exit branch in `UniswapV4StandardExchangeInTarget` to call `_executeZapOutExactIn(..., address(this))` directly, and (c) add the `recordNestedDeposit` callback to the callback facet/target.

The owner's ruling closes every choice. There is no remaining product decision for the owner.

## Mechanical closures the plan must state

The plan can be written now. It must state:

1. **Edit order** — first add the `recordNestedDeposit` callback (the new shape), then rewire the In-target share-exit branch to call `_executeZapOutExactIn(..., address(this))` directly, then remove `executeNamedHolderRedemption` from the delegate contract, then remove the four-argument `executeZapOutExactIn` from the delegate contract. The order matters: callers are rewired before deletions. (This matches the owner's ruling on Question 1.)

2. **Exact calls** — the new `recordNestedDeposit` callback is added in the callback facet at `UniswapV4StandardExchangeCallbackFacet.sol`. It decodes the same operation format as the prior `observeNestedDeposit` (or the replacement callback) and dispatches to the new `recordNestedDeposit` path. The public share-exit branch in `UniswapV4StandardExchangeInTarget.sol` is rewired from `_delegateExecuteZapOutWithdrawal(...)` to `_executeZapOutExactIn(tokenOut, actualIn, minAmountOut, recipient, address(this))`. The dispatch field on `UniswapV4StandardYieldExecutionTarget` updates to call the new callback.

3. **What is deleted** — `executeNamedHolderRedemption` (line 13-18) and `executeZapOutExactIn` (line 27-34) from `UniswapV4StandardExchangeInExecutionDelegate.sol`. The `delegatecall`-from-target path to the deleted wrappers is removed. No other wrapper is deleted; `executeZapInDeposit` (line 12-17) is the surviving wrapper. The deployed `executeZapInDeposit` factory wiring is preserved.

4. **Which deployed unit is measured** — `UniswapV4StandardExchangeInFacet`. The 24,576-byte hard limit and 23,000-byte advisory target apply. The new callback is added to `UniswapV4StandardExchangeCallbackFacet`, which is currently well under the limit; the In-facet is the larger one that historically exceeded the limit. The plan must report the post-edit runtime of `UniswapV4StandardExchangeInFacet` and stop if it exceeds the hard limit, without restoring the delegate hop or using `via_ir`.

5. **Test file to run** — `test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangeVaultHeldRedeem.t.sol`. The plan must refresh artifacts with `python3 scripts/forge-artifacts.py` passing the edited production sources, then run the named test, and report the test result alongside the measured runtime. The plan must not add new tests in this item; the existing test is the acceptance gate for the new callback shape.

## Mechanical closures the plan must state that I observed but the PRD does not explicitly state

These are not open owner questions. They are implementations of the PRD's existing rules. The plan states them; the plan does not invent a new choice.

- **File 1: `UniswapV4StandardExchangeInExecutionDelegate.sol`** — remove the two named functions; the contract is otherwise unchanged.
- **File 2: `UniswapV4StandardExchangeOutExecutionDelegate.sol`** — keep as-is. (No deletion specified.)
- **File 3: `UniswapV4StandardExchangeInTarget.sol`** — rewire the share-exit branch (line 79-84 area) from `_delegateExecuteZapOutWithdrawal(...)` to the direct internal call. The `_settleNamedHolder` / `_redeemVaultHeld` / `_standardRoute` overrides on the legacy V4 SY hook layer are the dispatch surfaces; they call the new callback or the direct settlement, not the deleted delegate. The two-arg `executeZapOutExactIn` and the five-arg `executeZapOutExactIn(..., holder)` are both available; the four-arg one goes.
- **File 4: `UniswapV4StandardExchangeCallbackFacet.sol`** — add `recordNestedDeposit` to `facetFuncs`. (Already has the slot from the earlier rewiring pass.)
- **File 5: `UniswapV4StandardExchangeCallbackTarget.sol`** — replace `observeNestedDeposit` body with the recording and returning implementation.
- **File 6: `IUniswapV4StandardExchangeDFPkg.sol`** — no `PkgInit` change is named in the owner ruling. The 16 `PkgInit` fields stay as listed. The plan does not invent a new field.

These are mechanical implementations of the PRD's existing rules. The plan states the file list and the edit order; the plan does not choose a new interface, a new function, a new storage layout, or a new facet split.

## Why I do not ask the owner one question

The two prior question passes each asked one question and received an answer. This pass is the third in the series. The prior answers closed both questions:

- "Must `executeNamedHolderRedemption` be deleted in this item?" — yes, per the owner at PRD line 9 sentence 1.
- "Must REQ-V4-02's disable check be included in this item?" — yes, per the owner at PRD line 9 sentence 3.

Both are answered. The "address this question, give the one sentence the plan must use" rule is satisfied by the existing PRD text. The plan quotes the owner's ruling. No further owner question is needed.

I did not run Forge.