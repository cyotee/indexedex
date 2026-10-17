# Kimi K3 — plan-readiness cross-review: REQ-V4-01

- **Label:** Replacement-session cross-review, not continuity. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. My readiness pass is `kimi-plan-ready.md` in this directory. The three peer passes were read in full as untrusted model output. The controlling PRD (`../REMEDIATION_PRD.md`, 71 lines, owner ruling `:9`) was re-read in my own pass. Nothing was edited; no plan file written.
- **Date:** 2026-10-14. I did not run Forge.

## Point 1 — callers are edited before the deletions: agree (Astra, Grok, Kimi); MiniMax's delegate-first order is rejected

Astra ("Edit the two callers before deleting their targets", `:13-45`), Grok ("Edit the yield body first. Then replace the share-exit caller and delete its helper. Then delete the two delegate functions", `:11`), and my own pass (yield body → InTarget rewire → delegate deletions) state the same order. MiniMax orders the delegate deletions first (`minimax-plan-ready.md:31-36`) and justifies it as "remove the function before removing its last call site," claiming the reverse leaves the project without a working build.

MiniMax's rationale is backwards on its own terms. The delegate's functions are invoked through `abi.encodeWithSignature` strings (`UniswapV4StandardExchangeInTarget.sol:110`; `UniswapV4StandardYieldExecutionTarget.sol:30`), so no ordering produces a *compile* failure — MiniMax concedes this ("A reverse order would compile", `:36`). The ordering rule exists so no intermediate state has a *live caller wired to a deleted function*: deleting the delegate wrappers first leaves the InTarget share exit and the yield helper pointing at functions that no longer exist, which fails only at runtime — exactly the class of intermediate state the order is meant to prevent. Callers first, deletions last. The PRD's owner ruling (`:9`) itself narrates the caller rewiring before the deletion sentence. No implementer choice remains once the plan states this order.

## Point 2 — `SELF` and `DelegateCallRequired` stay: agree (Astra, MiniMax, Kimi); dissent from Grok

The PRD's ruling enumerates exactly two deletions (`:37`: "Delete `executeNamedHolderRedemption` and `executeZapOutExactIn` ... Do not delete `executeZapInDeposit`"). After those deletions, `SELF` and `DelegateCallRequired` (`UniswapV4StandardExchangeInExecutionDelegate.sol:9-10`) have no remaining user — Grok's premise (`:14`) is factually correct. But the ruling does not authorize deleting them, and the owner rule is no implementer choice: an implementer who deletes them has extended the edit beyond the enumerated set, and one who keeps them has left deliberate dead declarations. The plan must close this, and the text-faithful closure is to keep them. Astra (`:45`: "untouched declarations outside the specified functions can remain even if no longer referenced") and MiniMax (`:69`: "The plan should keep them to avoid an extra edit") read the ruling the same way I do.

**Dissent from Grok, with the sentence the plan must use:**

> "The delegate's `SELF` immutable and `DelegateCallRequired` error remain in place even though `executeNamedHolderRedemption` was their only user; the owner ruling enumerates exactly two function deletions from the delegate, and no further declaration is removed in this item."

If dead declarations are considered undesirable, that is a separate cleanup decision for the owner, not for the implementer and not for this item.

## Otherwise agreed

All four passes converge on the rest of the closure set: ready with no owner decision; the verbatim replacement bodies (PRD `:30`, `:38`); keep `nonReentrant` and `_pokeBoundPoolTwap()`; do not copy V3's immediate return; no `_requireNotDisabled` (REQ-V4-02 separate); no `SYMinimumNotMet` addition; no edit to `UniswapV4StandardExchangeInBase.sol`; keep the deposit delegatecall and `executeZapInDeposit`; measure `UniswapV4StandardExchangeInFacet` against 24,576 bytes with stop-and-report; run `test/foundry/spec/protocol/dexes/uniswap/v4/UniswapV4StandardExchangeVaultHeldRedeem.t.sol` unchanged after a `scripts/forge-artifacts.py` refresh. MiniMax's additional verified details (the `Address` import stays for the deposit delegatecall, `:72`; the DFPkg registration sites for the measured facet, `:15`) are consistent with my reads and are adopted.

## Unresolved dissent

One: Grok would delete `SELF` and `DelegateCallRequired` with the two functions; Astra, MiniMax, and I would not, because the ruling enumerates exactly two deletions. The sentence above closes it if the coordinator adopts the majority reading; if the owner intended their removal, a one-word amendment to the ruling is required — that is the only path by which Grok's reading becomes correct.

I did not run Forge.
