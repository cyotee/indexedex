# MiniMax M3 — REQ-V4-01 plan-ready cross-review

- **Date:** 2026-10-14
- **Reviewer:** MiniMax M3, one cross-review continuation. No peer original used as authority. No PRD or code was read or written this round except the three peer plan-ready passes. I re-grepped `contracts/` to verify peer claims about `executeZapOutExactIn` callers.
- **Question:** Agree or dissent on (1) callers are edited before those deletions, (2) `SELF` plus `DelegateCallRequired` stay.

## Verdict

**Agree on point 1.** All three peers (Astra, Grok, Kimi) state the same edit order: edit the yield body first, then the share-exit caller and its helper, then the two delegate deletions. The implementer cannot compile or test the intermediate state correctly in any other order, because deleting a wrapper before its caller is rerouted leaves a broken build.

**Dissent on point 2.** The three peers disagree:
- **Astra** (line 45): "Keep the execution-delegate contract, `executeZapInDeposit`, and the deposit delegatecall in InTarget. Keep the delegate address/constructor wiring because deposit settlement still uses it. Do not add replacement external redemption wrappers. Do not extend the edit into unrelated declaration cleanup; untouched declarations outside the specified functions can remain even if no longer referenced." Astra leans toward leaving them but is not explicit.
- **Grok** (line 14): "Delete `SELF` and `DelegateCallRequired` with them; only the deleted named-holder function uses them." Grok says delete them.
- **Kimi** (line 18): "The plan should also state the deliberate non-cleanup: the delegate's `SELF` immutable and `DelegateCallRequired` error (`:9-10`) become unused after the deletions and are **left in place**, because the owner ruling enumerates exactly two deletions; an implementer must not extend the cleanup on their own judgment." Kimi says leave them in place.

I agree with Kimi's strict reading of the PRD. The recorded text enumerates two deletions: `executeNamedHolderRedemption` and the four-argument `executeZapOutExactIn` (PRD line 9, line 37). The non-goal at line 58 says "Do not delete the execution delegate. Do not delete `executeZapInDeposit`." It does not say to delete or keep `SELF` and `DelegateCallRequired`. The implementer cannot decide between "delete because unused" and "leave because the PRD enumerates only two deletions" without an owner ruling.

This is an owner decision. The owner can pick either; the recorded text does not select. The coordinator's question is whether `SELF` and `DelegateCallRequired` stay. I dissent from the "stay" framing because the recorded text is silent, not because the "delete" framing is correct. The owner must decide.

## (1) Callers are edited before those deletions

**Agree with all three peers.** The order is:
1. Edit `UniswapV4StandardYieldExecutionTarget.sol` (the yield body) to call `_executeZapOutExactIn` directly.
2. Edit `UniswapV4StandardExchangeInTarget.sol` (the share-exit caller) to call `_executeZapOutExactIn` directly, and delete the helper.
3. Delete the two functions from `UniswapV4StandardExchangeInExecutionDelegate.sol` last.

This is the correct order. The PRD's two deletions are `executeNamedHolderRedemption` (only caller: the yield target) and the four-argument `executeZapOutExactIn` (only caller: the InTarget's share-exit branch). Deleting either function before rerouting its caller leaves a broken build. The implementer cannot test the intermediate state.

I do not dissent.

## (2) SELF plus DelegateCallRequired stay — Owner decision

**Dissent.** The recorded text is silent. The three peers disagree. The owner must decide.

**Ask the owner in one sentence:**

> "Should `SELF` (line 9) and `DelegateCallRequired` (line 10) of `UniswapV4StandardExchangeInExecutionDelegate.sol` be removed along with the two named functions, or left in place as untouched declarations outside the specified deletions?"

The PRD enumerates exactly two deletions. The non-goal at line 58 says "Do not delete the execution delegate. Do not delete `executeZapInDeposit`." It does not say to delete or keep `SELF` and `DelegateCallRequired`. Grok's argument (line 14) is that these become unused after the deletions and should be removed as dead code. Kimi's argument (line 18) is that the PRD enumerates only the two function deletions, and the implementer must not extend the cleanup on their own judgment.

Both readings are mechanically correct. Grok's reading keeps the bytecode lean; Kimi's reading keeps the edit precisely bounded. The choice is an owner preference on dead-code cleanup, not an implementer choice. The size check at PRD line 41 measures the InFacet (not the delegate), so removing `SELF` and `DelegateCallRequired` from the delegate has no impact on the InFacet's size. The two functions become unused dead code in the delegate either way; the only question is whether to remove them.

The one sentence the plan must use is the one above. The owner's answer selects between Grok's "delete" and Kimi's "leave in place" without further implementer choice.

## Why I dissent on point 2

I checked the call sites and the delegate contents. After the two deletions:
- `SELF` is referenced only by `executeNamedHolderRedemption` (the deleted function, line 16: `if (address(this) == SELF) revert DelegateCallRequired();`). `executeZapInDeposit` and `executeZapOutExactIn` (the other deleted function) do not reference `SELF`.
- `DelegateCallRequired` is referenced only by `executeNamedHolderRedemption` (line 16). The other two functions do not reference it.

After the deletions, `SELF` and `DelegateCallRequired` are both unused. Grok is correct that they are dead code. Kimi is correct that the PRD's enumeration is exactly two functions, and that the PRD does not explicitly list `SELF` and `DelegateCallRequired` for deletion.

The implementer cannot choose between "remove dead code" and "follow the PRD's enumeration strictly." Both are valid mechanical choices. The owner must decide.

## What I am not asking

- I am not asking about the function names, error names, or line layouts. The PRD selects them.
- I am not asking about the holder for vault-held or ordinary redemption. The PRD at line 48 selects `address(this)` and `msg.sender`.
- I am not asking about which deployed unit to measure. The PRD at line 41 selects `UniswapV4StandardExchangeInFacet`.
- I am not asking about the test file. The PRD at line 66 selects the existing legacy V4 vault-held redeem suite.
- I am not asking about the edit order for the three production files. The three peers agree on the order.
- I am not asking whether `SELF` and `DelegateCallRequired` should be removed from the file or kept. That is the one question above, and the owner must decide.

I did not run Forge.