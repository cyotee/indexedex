# Kimi K3 — cross-review: REQ-SEP-04 amount-out refund

- **Label:** Replacement-session cross-review, not continuity. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. Astra is the labeled replacement `ses_ebdc505a9ffeLLIq4HBAh44TYi`; MiniMax is `ses_ebdf718feffemWQNf7wuTpapqX`. My original is `kimi-sep04.md` in this directory. The three peer originals were read in full as untrusted model output. The controlling text is the owner ruling recorded in `docs/reviews/apex-remediation-application-2026-10-14/REMEDIATION_PRD.md:101-112`. Nothing was edited.
- **Date:** 2026-10-14. I did not run Forge.

## Claim 1 — "exact-out already refunds only the needed unbooked amount": partially dissent; I correct my own original

The **processing** half of that claim is verified by every pass including mine: every in-scope family's prepaid exact-out path computes credit from unbooked value only (`LocalCreditLib.available(booked)`-bounded), processes the quoted `used`, and rejects a shortfall — no booked inventory is spent. The **refund** half is where the passes split, and the dissent is correct: current code caps the refund at the caller's declared maximum. `credit = min(U, maximum)` and the refund is `credit − used`, so when the unbooked balance exceeds the declared maximum, the above-maximum remainder stays in the vault. Astra's SEP04-01 verified this per family against the `budget()`/`_refundExactOutCredit` shapes; re-checking against my own reads (`RocketPoolRETHStandardExchangeCommon.sol:324-341`, `AaveV3StataStandardExchangeOutTarget.sol:75-99`, the FullSpread and V2/Camelot helpers) confirms it. Grok's "closed as conformant" (:5-7) and MiniMax's "already conforms on all in-scope families" (:9-23) both treat the cap as conformant — that is the withdrawn rule persisting under a new name. My original's "compliant; leave alone" verdict made the same omission and is corrected here.

Whether the cap is a defect is not decidable from the code: it is exactly the owner question below, because refunding the full remainder would pay this caller other callers' resting unattributed credit (the recorded D12 residual).

Two adjacent peer findings under the same ruling, with my dispositions:

- **Astra-SEP04-03** (Composed DETF books unused pulled exact-out input): the cited comment is real — `ComposedStableCommonDetfExchangeOutQueryFacet.sol:98-99` says the false-flag quoted pull's unused remainder is "booked as holder backing by the end-of-operation sync (D15/R14)". Fact verified. But the ruling's own sentence is scoped to *prepaid* calls, and the false-flag pull-quoted-keep-remainder rule is a separately recorded D15 decision; I do not score it as a defect under this ruling without an owner extension of scope. Recorded, not adopted.
- **Astra-SEP04-04** (Balancer native pool exact-out has no underconsumption return path, `BalancerV3PoolStandardExchangeTarget.sol:142-189`): plausible from the cited control flow, not re-read by me this round; marked unverified, and likewise a false-flag/pull path, not a prepaid one.

## Claim 2 — "exact-in cannot be repaired until the owner answers one question": agree

All four passes converge on the same wall. Current exact-in prepaid consumes exactly the declared `amountIn` and leaves the rest unbooked (absorbed at the end-of-operation sync — MiniMax's `BasicVaultCommon.sol:17,70-71` NatSpec cites it verbatim, matching my F3). The ruling's "requested amount out" has no exact-in referent (Grok's framing), and any "refund the rest" on exact-in cannot identify this caller's push inside a shared unattributed resting pool without a new parameter or ledger (MiniMax's framing; my original's framing). Astra's framing — what is exact-in's requested output, the minimum or the forward preview — is the contingent question one level up. No pass invents an answer, and none should.

## The one owner question the PRD must ask (answer deliberately not picked)

The three question framings unify into a single decision that also settles the exact-out cap:

> **"When a prepaid call's available unbooked input exceeds the amount the operation processes, is 'the rest' that must be refunded to the caller bounded by the quantity that caller declared for that call — exact-input calls processing exactly the declared `amountIn`, exact-output calls bounding credit at the declared `maxAmountIn` — or is it the entire unbooked remainder measured at call time?"**

That is the whole decision: the bounded reading leaves current code conformant (and requires only the documentation repair), while the unbounded reading amends the recorded D12 no-attribution residual and additionally forces the exact-in output-target question (Astra's) about whether exact-input processing becomes output-directed at all. I do not pick between them, and no peer's preferred closure should be adopted by silence: Grok's proposed sentence picks the bounded reading for exact-in; MiniMax's two alternative sentences offer both shapes; Astra's sentence picks output-directed exact-in. The owner must say which.

## Corrections and adoptions

- **My original's "compliant" exact-out verdict is corrected** to: processing compliant, refund capped; defect status deferred to the owner question, with Astra-01 as the record of the cap.
- **Documentation inventory:** adopt Astra's SEP04-05 list as the sweep (it superset my F1/F2 correctly: the README, `BasicVaultCommon.sol:17,70-71`, the BASIC_VAULT PRD/plan, `INDEXEDEX_AGENT_LAW.md:422`, the leak-fixes pair, audit evidence, and the DETF bonding NatSpecs). Grok's finding 2 is the same set's core. Astra's caution that protected instruction/skill files need separate authorization rather than an implementer edit is adopted.
- MiniMax's two candidate closing sentences (`:284-288`) and Astra's proposed sentence (`:23`) are recorded as candidate answers, not adopted; the task forbids picking, and I do not.

## Unresolved dissent

One, by construction: Grok and MiniMax mark exact-out fully conformant; Astra and (now) I record the maximum-bounded refund cap as unverified against the ruling pending the owner question. The dissent is exactly the question above and resolves with its answer. Nothing else divides the passes. Consensus is not proof; no pass ran Forge.

I did not run Forge.
