# Kimi K3 — questions cross-review: REQ-V4-01

- **Label:** Replacement-session cross-review, not continuity. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. My question pass is `kimi-questions.md` in this directory. The three peer passes were read in full as untrusted model output. Nothing was edited; no PRD was written.
- **Date:** 2026-10-14. I did not run Forge.

## Overall: ready — no owner decision remains

All four passes agree the recorded text selects the internal call and pre-decides the size contingency (`docs/reviews/apex-remediation-application-2026-10-14/REMEDIATION_PRD.md:74-80`; `apex-rc01-explicit-holder/REMEDIATION_PRD.plan.md:140`). On the two assigned points I change my own position on one and keep the other, as follows.

## Point 1 — must `executeNamedHolderRedemption` be deleted in this item? No. Closed by recorded text.

**I withdraw my earlier closure 2 (deletion) and agree with Astra and Grok.** My questions pass argued for deleting the holder-taking wrapper once the hop is gone. The peers are right that the recorded text does not ask for that: the acceptance criterion is scoped — "It does not keep a holder-taking wrapper on the execution delegate **as the yield path**" (`REMEDIATION_PRD.md:77`). Deletion is not among the enumerated changes, the item's non-goals do not authorize expanding the edit into the shared CREATE3 delegate, and the function is inert where it stands: it reverts on direct call (`DelegateCallRequired`, `UniswapV4StandardExchangeInExecutionDelegate.sol:16`) and its selector is not exported by the facet (`UniswapV4StandardExchangeInFacet.sol:25-30`, verified in my earlier pass). Astra `:20` ("do not delete their delegate infrastructure merely because the yield hop is removed") and Grok `:23` ("Do not delete that function … in this item") read the recorded text correctly. MiniMax is silent on deletion, which is consistent.

The closed sentence for the PRD: **"This item removes the delegatecall from `_settleNamedHolder` and does not delete `executeNamedHolderRedemption`; after this item no production path calls it, and no new caller may be added to reach it. A later cleanup item may delete it separately."** The last clause keeps the recurrence concern (an unused holder-taking entrypoint) visible without expanding this item's scope.

## Point 2 — must REQ-V4-02's disable check be included in this item? No. Closed by recorded text.

**I withdraw my earlier closure 3 (one edit closing both) and agree with Grok and Astra.** Grok `:26`: "Do not add `_requireNotDisabled` in this item. REQ-V4-02 owns that sentence." Astra `:21`: keep the disable-check obligation distinct rather than letting the implementer reinterpret it inside the settlement-mechanism edit. The recorded structure already separates the two: REQ-V4-01's acceptance criteria (`:74-79`) say nothing about the disable check; REQ-V4-02 (`:82-93`) is its own numbered item with its own severity and acceptance list, including its own escape valve ("unless the owner records a scoped amendment"). Merging them would be a packaging choice the recorded text does not make.

The closed sentence for the PRD: **"This item changes only the call shape of `_settleNamedHolder`; it does not add `_requireNotDisabled`. REQ-V4-02 owns that check as a separate item. Whichever item lands second preserves the other's behavior: this item's final helper keeps the lock, the TWAP poke, and any disable check already present, and REQ-V4-02's edit applies to the internal-call body if it lands after this one."** That closes the ordering question without merging the items.

## Agreements worth recording

- The edit shape is unanimously the V3 mirror: replace only the delegatecall block (`UniswapV4StandardYieldExecutionTarget.sol:29-34`) with the internal call; keep the helper name and signature; keep `nonReentrant`; keep `_pokeBoundPoolTwap()` after the call (Grok's note that V3's immediate-return line must not be copied literally, because V4 keeps the poke, is the sharpest statement of it). MiniMax's point that the assembly revert bubble is dropped with the delegatecall is correct and consistent.
- Grok's "Do not add V3's `SYMinimumNotMet` check; the inherited function already reverts `UniswapV4ExchangeIn_SlippageExceeded`" (`:25`) is a real trap-avoidance note I had not written down; verified against `UniswapV4StandardExchangeInBase.sol:173,195`. Adopted as part of the closed set.
- All four passes: no function-name, error-name, or layout question goes to the owner; the oversize contingency is pre-decided (measure, report, stop; no delegate, no self-call, no `via_ir`).

## Unresolved dissent

None. The two assigned points are closed by recorded text; both of my withdrawn closures were expansions beyond it, and the peers' narrower reading is the faithful one. Consensus is not proof, but here the agreement is over what the recorded text does not require, and each of us re-read the same lines.

I did not run Forge.
