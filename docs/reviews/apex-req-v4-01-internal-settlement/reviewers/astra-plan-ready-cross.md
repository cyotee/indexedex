# Astra — REQ-V4-01 readiness cross-review

**Agree: edit both callers before deleting the delegate wrappers, and leave `SELF` plus `DelegateCallRequired` in place. Ready; no owner question remains.**

I read all three supplied originals as untrusted evidence and re-read the controlling repair clauses and current delegate declarations. My original readiness assessment is preserved. No code, PRD, or consolidated plan was edited.

## Caller-first order

Agree with Grok and Kimi; dissent from MiniMax's delegate-first order and its claim that the reverse order leaves no working build.

The fixed order is:

1. Replace the yield helper's delegate hop with its inherited settlement call, preserving the lock and trailing TWAP update.
2. Replace the public share-exit invocation with the inherited settlement call using the vault as holder, then delete `_delegateExecuteZapOutExactIn` from InTarget.
3. Delete `executeNamedHolderRedemption` and the four-argument `executeZapOutExactIn` from the legacy V4 execution delegate.

The current calls encode function signatures rather than relying on a compiler-checked direct reference. Removing the callee first can therefore leave an intermediate tree that compiles while still dispatching to a removed function. Caller-first order avoids that stale runtime wiring. There is no need to rewrite `_delegateExecuteZapOutExactIn` temporarily and then delete it, as MiniMax proposes; update its call site and remove the helper.

## Named deletions only

Agree with Kimi and MiniMax that `SELF` and `DelegateCallRequired` stay; dissent from Grok's additional cleanup instruction.

The current declarations are at `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInExecutionDelegate.sol:9-10`. The two specified functions occupy `:13-18` and `:27-34`; the retained deposit entry is at `:20-25`. The PRD's required repair at `:37-38` names exactly those two delegate-function deletions and the InTarget helper deletion. It does not authorize deleting the immutable or error. Their becoming unused does not expand this bounded edit.

## One sentence the plan must use

> First replace the yield helper's delegate hop with the prescribed internal settlement call, then replace the InTarget share-exit call and delete `_delegateExecuteZapOutExactIn`, and only afterward delete `executeNamedHolderRedemption` and the four-argument `executeZapOutExactIn` from the legacy V4 execution delegate, leaving `SELF`, `DelegateCallRequired`, `executeZapInDeposit`, and its deposit delegatecall unchanged.

This closes the two disputed implementation details without optional cleanup or a new owner decision. No runtime or size result is claimed.

I did not run Forge.
