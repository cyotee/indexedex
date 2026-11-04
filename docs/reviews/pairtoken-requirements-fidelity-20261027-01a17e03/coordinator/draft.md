# PairToken requirements fidelity - coordinator draft

Draft identity: pairtoken-fidelity-draft-r1.
Status: all four independent originals settled; proposed synthesis for one advisory pass. This draft is not the final report and has not yet received advisory feedback.
Coordinator: invoking gpt-6.1-sol; not an independent council vote.
Date: October 27, 2026.

## Answer

**Yes: the document is a faithful, technically usable baseline for independently implementing PairToken-local behavior. Make two small wording/order clarifications before treating it as a frozen, exact-parity handoff. No material accounting, mint/burn, callback, or integration-rule mismatch was demonstrated.**

This is a source-to-requirements assessment, not proof that a future implementation is equivalent and not certification of a legally cleared clean-room process. Use the requirements as the implementer's input, not the source-exposed council report or its evidence tree. Whole-system parity still needs the compatible PoolManager and concrete factory/fee-manager/hook/token dependencies identified in Part III.

## Participation and independent dispositions

| Member | Requested route; Native resolved route | Initial verdict | Substantive original |
| --- | --- | --- | --- |
| Astra | chatgpt-subscription/gpt-6-astra:high; same provider/model, high | Yes; no demonstrated defect or blocking omission | members/astra/response.md |
| Grok | xai/grok-4.7:xhigh; same provider/model, xhigh | Yes with corrections; two Low clarifications | members/grok/response.md |
| MiniMax | minimax/MiniMax-M3; same provider/model | Yes with corrections; uncapped-fee consequence plus precision/coverage suggestions, all Low | members/minimax/response.md |
| Kimi | kimi-coding/k3.1-pro:high; same provider/model, high | Yes; no demonstrated defect or blocking omission | members/kimi/response.md |

All four were independent, with no assigned access to peers or earlier council work. All ran in Native process mode. MiniMax forceAdaptiveThinking:true was confirmed in configuration; actual adaptive-effort telemetry is unavailable. Three members returned full originals inline because project-scoped apply_patch was unavailable; the coordinator preserved those originals verbatim with provenance headers. Astra wrote its own response. No member is missing, replaced, or counted twice.

Initial tasks: Astra st_01a17e09; Grok st_01a17e0a; MiniMax st_01a17e0b; Kimi st_01a17e0c. Owner/root: 01a17e03-97a1-7db4-a05a-162ee50c6ff4.

The four initial answers support technical usability, not unanimous approval of the unchanged wording. Astra and Kimi requested no required correction; Grok and MiniMax retained Low concerns. The recommendations below are the coordinator's resolution proposal, not a fifth vote.

## Evidence and scope

Required document: docs/research/pairtoken-behavioral-requirements-20261027-01a17d57/handoff/REQUIREMENTS.md, identity pairtoken-requirements-final-r2, 596 lines. Complete line-preserving review copy: evidence/REQUIREMENTS-reviewed.md; identity record: evidence/REQUIREMENTS-IDENTITY.md. It is the published final, not the earlier draft reviewed by its original authors.

Public endpoint supplied by the user: https://sourcify.dev/server/v2/contract/4663/0x56C8c249d4c021e93635b120aC68A9a36eb01753?fields=sources

The coordinator fetched it afresh on October 27, 2026. Response fields identify chain 4663, address 0x56C8c249d4c021e93635b120aC68A9a36eb01753, matchId 55980642, exact creation/runtime matches, and verifiedAt 2026-10-12T10:33:37Z. Raw response SHA-256: ebbbf460a7873b7a5a1fb2802035778976ac4c5f64f3c6074776fd71aa53cd98. Decoded sources and retrieval metadata are preserved under evidence/. Members examined this coordinator-supplied public-source evidence; their responses distinguish it from their own retrieval. No live dependency calls were made.

Source locators below are relative to evidence/sources/. Requirement line numbers refer to the reviewed published document. No optional independent PRD, implementation plan or audit was supplied. No IndexedEx product preference overrides the source-fidelity baseline.

## Recommended clarifications

### C1 - Low: call event amounts pull-returned, not universally measured

Requirement locations: PT-DEP-05 at line 236 and PT-EVENT-02 at line 405. PT-DEP-03 at line 224 already defines v0/v1 as pull returns; PT-BAL-02 at line 375 correctly distinguishes native from ERC-20 receipts.

Source: src/pair/PairToken.sol:271-274 and :661-667. A native pull returns its nominal requested amount without a transfer or balance-delta measurement. ERC-20 pulls return the checked post-minus-pre balance difference.

The word measured in the two summary sentences is overbroad for native currency. The complete document already supplies the correct rule, so this is a local terminology inconsistency, not a demonstrated wrong formula or guaranteed native-funding failure. Grok's zero-native-event/refund example describes a possible incorrect implementation only if it ignores the correct cross-referenced native rule.

Smallest proposed replacement for the final clause of PT-DEP-05:

> Emit Deposit after the refund with pull-returned amounts v0,v1 and net recipient shares. A native pull returns its selected nominal amount; an ERC-20 pull returns its measured balance increase.

Smallest proposed replacement in PT-EVENT-02:

> Paired Deposit amounts are pull-returned amounts: nominal selected native amounts or measured ERC-20 receipts; zap Deposit amounts are reported add-used amounts.

Preserve every surrounding checkpoint and the existing PT-BAL-02 rule. No requirement edit has been applied.

### C2 - Low: make currency0-before-currency1 idle sampling uniform and explicit

Requirement locations: PT-VIEW-02 at line 192; PT-EXIT-01 at line 256; PT-COMP-04 at line 301; PT-CB-05 at line 358. PT-DEP-03 at line 226 explicitly states the paired-entry idle/price order; do not erase that distinction.

Source: src/pair/PairToken.sol:228-229, :295-298, :394-395, :435-436 and :599-600. Every idle pair is sampled currency0 before currency1. Paired addition reads fresh price after its two idle reads; Deploy uses its already-held initial/post-swap price.

The other sections name both idles, sometimes in that same textual order, but do not uniformly pin first/then. For exact call-trace parity, add a general requirement that whenever an idle pair is sampled, currency0 is read before currency1, while preserving all route-specific price, burn and settlement checkpoints. This is a determinism/standalone precision clarification.

Do not adopt as established the original concern's example that balanceOf reentry can mutate the other currency. The supplied IERC20Minimal.balanceOf is declared view (interfaces/external/IERC20Minimal.sol:10); that state-mutating example was not established by the source or executed. The observed ordering itself is clear and can be preserved without claiming a reachable exploit or a broad security defect.

## Optional additions and concerns not elevated to defects

### N1 - Uncapped fee rate: make its consequence easier to see, but do not invent a clamp

MiniMax F1 points to a real conditional consequence. PT-COMP-02 at lines 286-288 already gives the exact checked fee formula and explicitly says no local maximum of 10000 exists for the uint16 value. PT-COMP-03 specifies native call value; PT-BAL-01 specifies checked balance-minus-reservation idle accounting. The source implements precisely those rules at PairToken.sol:424-431, :447-456 and :646-648.

A rate above 10000 can request more than the collected amount, drawing on other instance inventory if a payment succeeds. Native reservation is an accounting exclusion, not a separate spend-limited escrow in _carve. A conditional example: with collection 100, protocol rate 20000, no old free native idle, and reserved incoming native R at least 100, a successful payment of 200 leaves R-100; the next idle calculation subtracts R and reverts. That uncaught failure rolls back the transaction, including the payment. It is not evidence of a successful permanent principal drain. Actual deployed rates and fee-manager behavior were not supplied.

Optional clarification: state the attempted protocol payment is not capped by collected fees or an independently segregated principal budget; rates above 10000 can use other balance and cause the specified downstream failures. The present formulas already determine this outcome, so the coordinator does not classify its absence as a blocking behavioral gap. Do not cap the rate/payment or alter the source behavior.

### N2 - encode versus encodePacked of two full words is not a discrepancy

MiniMax F2 notes PT-VIEW-01 uses abi.encode where StateLibrary.sol:324-325 and :339-347 use abi.encodePacked. Both inputs in each expression are 32-byte words, giving the same 64-byte preimage. The current requirement computes the correct value. An explanatory note is optional, not a correction to the slot formula. Do not generalize this equivalence to non-word operands.

### N3 - Broader acceptance evidence is advisable, not missing behavior

MiniMax F3-F5 recommend vectors for a zap with no addition leading to MinShares, native payout wrapper/zero-output calls, and compound's (0,0) return when no position liquidity exists despite idle deployment. These outcomes are already specified by PT-ZAP-04/PT-CB-05, PT-BAL-05/PT-EXIT-04, and PT-COMP-01/PT-COMP-06 respectively.

Astra also recommends more exact math vectors, explicit callback/dependency call traces and a transfer-return matrix. Grok notes some boundary cases are qualitative rather than numerical. Adopt these as later verification-plan recommendations, not proof that the requirements are false or a promise that the present 58 scenarios exhaust every input. No tests are authorized or executed by this review.

### N4 - Do not carry unsupported licensing attribution into the technical verdict

MiniMax O1 asserts the prose reproduces BUSL-covered v4-core math constants/function shapes while also describing the included v4-core files as MIT. The inspected headers are file-specific: PairToken.sol, PriceMath.sol and Position.sol say BUSL-1.1, whereas the inspected TickMath.sol, SqrtPriceMath.sol and FullMath.sol say MIT. These observations do not establish the legal status of a prose requirements document or permission for a new implementation. The coordinator does not adopt the unsupported licensing attribution or offer a license determination.

## Verified behavioral coverage

| Area | Status | Result / boundary |
| --- | --- | --- |
| Full requirements Parts I-III and 58 scenarios | Examined | All members read the published final; exact integer examples were statically checked. Scenarios are requirements, not executed tests. |
| Full PairToken source | Examined | ABI/getters/events/errors, initialization, guards, ERC-20, money paths and helpers compared. No material contrary behavior demonstrated. |
| Required math and identity helpers | Examined | FullMath, used SqrtPriceMath/TickMath, LiquidityAmounts, floor sqrt, PoolKey/PoolId/Position identity, and used StateLibrary reads. |
| Native/ERC-20 transfers, deltas and callback interfaces | Examined | Helper-specific return-data handling, signed widths, reservations, wrapped errors and separate unlock boundaries checked. |
| Unused source-bundle routines | Partial | Not every transitive helper is an obligation of PairToken; no whole-library security audit claimed. |
| Concrete manager, factory, fee manager, hook, token implementations and live settings | Not examined | Not supplied; Part III correctly makes these external dependencies rather than guessed behavior. |
| Future implementation/runtime equivalence | Not examined | No build, test, chain execution or bytecode equivalence proof. Grok's reported arithmetic sampling is member-reported, not coordinator-reexecuted runtime evidence. |
| Source-exposure history and legal clearance | Not examined | This is a source-exposed technical review, not process or legal certification. |

Correctly preserved high-risk distinctions include gross genesis minShares versus net recipient shares, true dead-share minting, unclamped basket prices, pre-pull paired pricing, measured ERC-20 receipts without share recomputation, vault-basket user-zap caps versus active-pool compound caps, separate redemption floors and retention, skip-add sale-only exits, U128 reinterpretation, conditional fee notification, nominal outgoing minima and route-specific zero-transfer behavior. No extra oracle, personal fee index, getRate, target-token normalization, safe-cast guard, principal escrow or universal full-fill check should be silently added under an equivalence claim.

## Proposed disposition

Use the requirements for the separate team's behavioral implementation plan. Before freezing an exact-parity specification, clarify C1 and C2; N1-N3 are useful explanation/verification additions, not prerequisites to understanding the existing mathematics. No architecture or economic redesign is required by this review. The user has not requested implementation or requirements edits here.

Give a source-unexposed implementer only the designated standalone handoff, with any approved clarifications incorporated there; retain source locators, originals, advisory notes and retrieved code on the analyst side. Whether that workflow satisfies legal clean-room requirements remains unverified.

## Advisory state

Pending: one review of this exact draft by all four members. Preserve this draft unchanged. The final may resolve feedback as coordinator revisions; it must not be described as newly approved by every member.

