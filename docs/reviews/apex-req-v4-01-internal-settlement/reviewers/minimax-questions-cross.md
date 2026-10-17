# MiniMax M3 — REQ-V4-01 question cross-review

- **Date:** 2026-10-14
- **Reviewer:** MiniMax M3, one cross-review continuation. No peer original used as authority. No PRD or code was read or written this round. The three peer question passes and my own question pass were re-read. I re-grepped `contracts/` to verify peer claims about `executeNamedHolderRedemption`.
- **Question:** Agree or dissent on (1) must `executeNamedHolderRedemption` be deleted in this item, (2) must REQ-V4-02's disable check be included in this item.

## Verdict

**Dissent on point 1.** The deletion of `executeNamedHolderRedemption` is an owner decision. The recorded text does not specify whether to delete or keep it. The implementer cannot decide on security grounds. **Ask the owner in one sentence.**

**Agree on point 2.** The disable check is a separate item. The recorded text for REQ-V4-01 does not include the disable check; the recorded text for REQ-V4-02 owns it. **Closed by recorded text.**

## (1) Must `executeNamedHolderRedemption` be deleted in this item? — Owner decision

**Dissent from Grok and Kimi. Agree with Astra's framing, but disagree on whether the implementer can decide.**

The three peers disagree on whether to delete `executeNamedHolderRedemption`:
- **Astra** (line 18): "Preserve unrelated routes ... Preserve non-share dispatch and the existing public exchange wrappers; do not delete their delegate infrastructure merely because the yield hop is removed." Astra does not explicitly call out deletion of `executeNamedHolderRedemption`. Astra's framing is "preserve infrastructure."
- **Grok** (line 23): "Do not call `executeNamedHolderRedemption`. Do not delete that function, and do not change the four-argument `executeZapOutExactIn` wrapper, in this item." Grok says do NOT delete it.
- **Kimi** (line 19): "Fate of the wrapper. `executeNamedHolderRedemption` (`UniswapV4StandardExchangeInExecutionDelegate.sol:13-18`) is deleted once the hop is gone. Verified this turn: its only references are its own definition and the yield target (grep over `contracts/`). The PRD should instruct a fresh grep at implementation time and deletion if still caller-less." Kimi says it SHOULD be deleted.

I re-grepped `contracts/` to verify. The grep confirms Kimi's claim:

```
contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInExecutionDelegate.sol:13: function executeNamedHolderRedemption(address tokenOut, uint256 sharesBurned, uint256 minAmountOut, address recipient, address holder)
contracts/protocols/dexes/uniswap/v4/UniswapV4StandardYieldExecutionTarget.sol:30: abi.encodeWithSignature("executeNamedHolderRedemption(address,uint256,uint256,address,address)",
```

Two references: the definition and the call site. After REQ-V4-01's edit removes the call site at line 30, the function has zero callers. The function is dead code.

The recorded text does not explicitly say to delete this specific function. The closest recorded principle is the RC-01 plan at line 150: "Adding a holder argument to the public four-argument wrapper. MiniMax's draft did that. It is not adopted. It would change an encoded selector the PRD does not ask to change, and it would let a caller name the holder."

This principle is stated about the four-argument `executeZapOutExactIn` wrapper, not specifically about the five-argument `executeNamedHolderRedemption`. The principle is general ("a holder-naming wrapper is forbidden"), but its application to this specific function is not stated.

This is an owner decision because:
1. The recorded text does not explicitly say to delete this function.
2. The function is a holder-naming wrapper, which the RC-01 plan's general principle warns against, but the principle is stated about a different wrapper.
3. Deleting a production function (even an uncalled one) is a non-trivial change.
4. The function is a 5-argument wrapper that takes a holder parameter. The RC-01 plan's non-goal is about a holder-naming wrapper. If the owner wants to follow the principle, they should delete the function. If they want to leave it as dead code, they should keep it.

The implementer cannot decide between these two readings of the recorded principle. The owner should.

**Ask the owner in one sentence:**

> "Should `executeNamedHolderRedemption` at `UniswapV4StandardExchangeInExecutionDelegate.sol:13-18` be deleted in this item, since it has no callers after REQ-V4-01's edit and the RC-01 plan's non-goal at line 150 warns against a holder-naming wrapper?"

## (2) Must REQ-V4-02's disable check be included in this item? — Closed by recorded text

**Agree with all three peers that the recorded text separates the two items.** The disagreement among the peers is about whether the REQ-V4-01 PRD should *state* the separation explicitly, not about whether the disable check is part of REQ-V4-01.

- **Astra** (line 21): "Keep the separately tracked disable-check obligation distinct rather than asking the implementer to reinterpret it as part of choosing a settlement mechanism."
- **Grok** (line 26): "Do not add `_requireNotDisabled` in this item. REQ-V4-02 owns that sentence."
- **Kimi** (line 20): "The PRD should state that the replacement body keeps `nonReentrant` and the post-settlement `_pokeBoundPoolTwap()` and adds `_requireNotDisabled()` per REQ-V4-02's acceptance — one edit closing both, or an explicit sequence — so the implementer does not choose whether REQ-V4-02 is in scope of this edit."

The recorded REQ-V4-01 acceptance criteria at `apex-remediation-application-2026-10-14/REMEDIATION_PRD.md:74-79` say:

- "Legacy V4 yield redemption calls the inherited `_executeZapOutExactIn` and passes `address(this)` or the original caller."
- "It does not `delegatecall` or externally call `address(this)`."
- "It does not keep a holder-taking wrapper on the execution delegate as the yield path."
- "If a deployed unit no longer fits the runtime limit, that fact is reported. The delegate hop is not the silent substitute."
- "V3 FullSpread's internal call is left as the matching shape, not rewritten to copy the V4 hop."

The recorded REQ-V4-01 acceptance criteria do not mention the disable check. The recorded REQ-V4-02 acceptance criteria at `apex-remediation-application-2026-10-14/REMEDIATION_PRD.md:88-91` say:

- "The legacy V4 direct yield path rejects a disabled vault before burn, using the existing disable check, unless the owner records a scoped amendment that this family may redeem while disabled."
- "The reentrancy lock and the post-settlement TWAP update remain."
- "The path does not re-enter `exchangeIn` to obtain the check."
- "V3 FullSpread is not edited to add a disable rejection. Its public share route already skips that check, and the plan did not impose this sentence on V3."

The disable check is a separate recorded item. The natural reading is that REQ-V4-02 owns the disable check, and REQ-V4-01 owns the function-call shape. Both items target the same function, but the recorded text separates them by acceptance criteria.

**Closed by recorded text:** the REQ-V4-01 PRD should not include the disable check. The implementer follows the recorded text. If the owner later wants the disable check added to this item, that is a separate decision the owner can record; until then, the recorded text closes point 2.

The disagreement among peers is whether the REQ-V4-01 PRD should *state* the separation explicitly. I agree with Grok and Kimi on the direction: the PRD should state the separation, but the separation is not an owner decision — it's a scope statement already implied by the recorded text. The PRD can restate the recorded separation: "This PRD addresses REQ-V4-01 (internal call). REQ-V4-02 (disable check) is a separate item and is not in scope of this edit."

## What I am not asking

- I am not asking whether the recorded text is internally consistent. The two items have separate acceptance criteria; the implementer can implement them independently.
- I am not asking whether V3 FullSpread needs a disable check. The recorded REQ-V4-02 non-goal at line 92 says: "V3 FullSpread is not edited to add a disable rejection. Its public share route already skips that check, and the plan did not impose this sentence on V3."

## Summary

**Point 1 (delete `executeNamedHolderRedemption`?) is an owner decision.** The recorded text does not specify. The function has no callers after REQ-V4-01's edit, but it is a holder-naming wrapper that the RC-01 plan's general principle warns against. The implementer cannot decide on security grounds. **One sentence to ask the owner:**

> "Should `executeNamedHolderRedemption` at `UniswapV4StandardExchangeInExecutionDelegate.sol:13-18` be deleted in this item, since it has no callers after REQ-V4-01's edit and the RC-01 plan's non-goal at line 150 warns against a holder-naming wrapper?"

**Point 2 (include REQ-V4-02's disable check?) is closed by recorded text.** The REQ-V4-01 acceptance criteria do not include the disable check. The REQ-V4-02 acceptance criteria own the disable check. The PRD for REQ-V4-01 should not include the disable check; it can restate the separation.

I did not run Forge.