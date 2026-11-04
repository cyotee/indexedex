# Coordinator-preserved drafting contribution

MiniMax returned this original contribution inline for the unified PRD authoring task. Preserved verbatim from Native final_response. It is not an advisory disposition or a replacement for the previous fidelity-review original.

---

All three admitted inputs read (plus r2 retained from my first pass). Here is my independent authoring contribution.

---

# MiniMax — initial authoring contribution to the unified Pair Token PRD

**Role:** one of four council members contributing independent drafting material for the unified PRD (`pairtoken-unified-prd-r1`). This is consolidation work: proposed exact prose, new acceptance rows, and preservation/standalone risks. It does not repeat the fidelity review and adds no new behavioral findings — every behavior I reference is already specified in r2.

## 1. Requirement-text edits to integrate in place

### 1.1 C1 — pull-returned deposit amounts

**PT-DEP-05**, replace only the final clause (`Emit Deposit after the refund with measured amounts v0,v1 and net recipient shares.`):

> Emit `Deposit` after the refund with pull-returned amounts `v0,v1` and net recipient shares. A native pull returns its selected nominal amount; an ERC-20 pull returns its checked post-call balance minus pre-call balance difference, including zero. A negative difference fails checked subtraction.

**PT-EVENT-02**, replace the paired/zap amount sentence:

> Paired `Deposit` amounts are pull-returned amounts: nominal selected native amounts or measured ERC-20 receipts as defined by PT-BAL-02; zap `Deposit` amounts are reported add-used amounts.

### 1.2 C2 — idle-pair sampling order

**PT-BAL-01**, append a second paragraph (existing text untouched):

> Idle-pair sampling order. Whenever both configured idle balances are sampled as a pair, read currency0 idle before currency1 idle. This is a call-order rule only: it introduces no snapshot guarantee, no balance budget, no positive-receipt requirement and no new rejection condition. Each route's price, burn, settlement and reservation checkpoints remain as stated: paired-entry addition reads a fresh price after its two idle reads (PT-DEP-03), and Deploy uses its already-held initial or post-swap price (PT-CB-04, PT-CB-05).

**PT-VIEW-02, PT-EXIT-01, PT-COMP-04, PT-CB-05**: append the cross-reference `(Idle pairs are sampled currency0 then currency1; see PT-BAL-01.)` — these four only.

### 1.3 Uncapped protocol rate — normative consequence**PT-COMP-03**, append:

> Uncapped rate consequence. The protocol rate is a `uint16` and is not locally bounded by 10000, so an attempted protocol payment is `floor(fees_i * rate / 10000)` and is not capped by the collected amount, by the instance's idle balance, or by a separately segregated principal budget. The native reservation is an idle-accounting exclusion only, not a spending limit: a native payment above 10000 basis points may consume other instance balance, including a reserved incoming amount held during an entry operation. If such a payment succeeds and the next idle computation subtracts a reservation larger than the remaining balance, the checked subtraction fails and the whole operation reverts, including the payment, the collection and the share mutations together. No permanent loss of principal is observable through this path. This describes specified behavior; it is not a recommendation to clamp the rate or the payment.

### 1.4 Optional PT-VIEW-01 clarification (no value change)

> (Both operands are 32-byte words, so the non-packed and packed encodings produce the same 64-byte preimage; the computed value is unaffected. Do not generalize this equivalence to non-word operands.)

## 2. New PRD front matter (exact prose)

Keep the existing r2 IDs and add five, in one new unnumbered section before Part I:

**PT-PRD-01 — Purpose.** This document is the single working specification for a Pair Token: one freely transferable ERC-20 share representing one full-range Uniswap v4 position together with the instance's idle pool-currency balances. A depositor contributes one or both legs of a configured currency pair; the position's earnings are collective property that compound back into the position on each touch; a holder redeems pro rata at any time, net of a fixed retention. The document is a source-equivalent behavioral baseline: it specifies observable behavior, exact integer results and integration contracts, and it prescribes no architecture, deployment topology or economics beyond that behavior.

**PT-PRD-02 — User operations.** A user may hold and transfer shares, approve a spender, deposit both legs, zap in with a single leg, redeem for both legs, redeem for a single leg, and obtain a preview of a paired deposit or a redemption. Any party may trigger collective collection and compounding. Every operation's preconditions, ordering, rounding and failure modes are the requirements below; this list is navigational and adds no operation, no priority and no guarantee.

**PT-PRD-03 — Scope and non-goals.** The scope is exactly the behaviors specified by this document and the external dependencies it names. The non-goals are exactly PT-ABSENT-01 and PT-ABSENT-02, which remain authoritative and are deliberately not restated here; in particular this document specifies no `getRate`, no target-token or redemption-target normalization, no fee index, no oracle or manipulation-resistance guarantee, no permit approval, no rescue or sweep, no pause, no range change, and no rebalancing policy. Nothing here is an IndexedEx architecture, IRateProvider, Crane facet, registry or deployment recommendation, and no roadmap is implied.

**PT-PRD-04 — Conformance and release evidence.** A release implementing this document is conformant only when: (a) every PT-* requirement ID is mapped to planned work and to at least one observable PT-AC row, or to an explicit statement that the requirement is not separately observable; (b) every PT-AC row is satisfied under its stated dependency premise, with exact-integer results matching the formulas, rounding and cast rules of PT-MATH-01 through PT-MATH-05; (c) the public ABI, constants, events and errors match PT-API-01 through PT-API-18, PT-GET-01 through PT-GET-17, PT-CONST-01, PT-CONST-02, PT-EVENT-01 and PT-ERROR-01 exactly; (d) no behavior listed in PT-ABSENT-01 is present; and (e) the implementation is compared against this document alone, without reference to the target implementation. Evidence must be sufficient to demonstrate the required observations; this document prescribes no test plan, framework, schedule or release process.

**PT-PRD-05 — Provenance and limits.** This document consolidates the published behavioral requirements identity `pairtoken-requirements-final-r2` (SHA-256 `8060c1e3d6ec225f761de647ca29c12536712d1d9188a6600a694d72d44ea848`) with the clarifications recorded in the fidelity council report `pairtoken-fidelity-final-r1`: the pull-returned deposit amount wording (PT-DEP-05, PT-EVENT-02), the uniform idle-pair sampling rule (PT-BAL-01 and its cross-references), the explicit uncapped-rate consequence (PT-COMP-02, PT-COMP-03), the optional PT-VIEW-01 note, and acceptance rows PT-AC-59 onward. The consolidated requirements, the fidelity report and their evidence remain unchanged in their own archives and are not prerequisites for understanding this document. This document contains no source listing, no source locator and no instruction to consult the target implementation. It is a static specification: no runtime, bytecode or deployed-dependency equivalence is established by it, and it certifies no legal clearance and no unexposed development workflow.

Header block (above the title):

> Document identity: `pairtoken-unified-prd-r1`. Status: single working specification; supersedes `pairtoken-requirements-final-r2` as the working document. The consolidated requirements and the fidelity report remain byte-identical archives; this document is not a modification of either, and there is no r3 of the requirements. The proposed errata annex is superseded by direct integration and does not accompany this document.

## 3. New acceptance rows

Append to Part II, continuing the existing numbering. Each is conditional on its stated premises and adds no new behavior.

| ID | Scenario | Expected observation | Requirements |
| --- | --- | --- | --- |
| PT-AC-59 | Zap whose Deploy performs no liquidity addition (no idle fits the full range at the post-swap price), with the tick-movement limit satisfied | Deploy reports zero used amounts and zero added liquidity; the pre-zap issuance quote `min(MD(w0,S,r0), MD(w1,S,r1))` is zero; the entry rejects `MinShares` and the whole operation, including pull, swap and deployment, is rolled back. A tick movement above the limit is rejected earlier with `ZapMovesPrice`, and the nominal cap is checked before the pull. | PT-ZAP-02, PT-ZAP-03, PT-ZAP-04, PT-ERROR-02, PT-ERROR-04 |
| PT-AC-60 | Native redemption payout to a recipient that rejects received value, with otherwise successful dependencies | The payout failure is reported as `WrappedError(recipient, bytes4(0), reason, details)`, where `details` is the four-byte `NativeTransferFailed()` context and `reason` is the raw return data of the failed call. The whole operation reverts, so no shares are burned and no earlier compound effect persists. | PT-BAL-05, PT-ERROR-04 |
| PT-AC-61 | Chosen-leg redemption whose final one-leg output is zero, with zero minima and otherwise successful dependencies | The selected-currency transfer is still attempted with a zero amount. The `Redeem` event reports the pre-swap pair amounts and the burned shares, not the final one-leg output. | PT-EXIT-04, PT-EVENT-02 |
| PT-AC-62 | Compound with zero position liquidity and idle balances above the dust threshold | No collection unlock occurs and the reported collection pair is `(0,0)`; the ratio calculation and Deploy still run, and the public call returns `(0,0)`. `Compounded` is emitted only if the Deploy requested a positive addition. | PT-COMP-01, PT-COMP-04, PT-COMP-06 |
| PT-AC-63 | Paired deposit whose ERC-20 leg delivers exactly the selected amount; separately, a leg that delivers less; separately, a pull whose post-call balance is lower than its pre-call balance | Exact delivery measures as the selected amount. A short delivery measures as the reduced balance difference and changes the funding and the event amounts but not the already-checked share count. A lowered balance fails the checked subtraction and reverts the operation. A zero difference is a valid measurement. | PT-DEP-05, PT-BAL-02, PT-BAL-03 |
| PT-AC-64 | Any route that samples both idle balances | Currency0 idle is read before currency1 idle. In the paired-entry addition the fresh price is read after both idle reads; in Deploy the price already held from before the swap, or read after the swap, is used. The ordering is a call-order rule and creates no snapshot guarantee, balance budget or new rejection. | PT-BAL-01, PT-DEP-03, PT-CB-04, PT-CB-05 |
| PT-AC-65 | Collection of 100 units, protocol rate 20000 basis points, no other free native idle, a reserved incoming native amount of at least 100, and a fee manager that accepts the native payment | The attempted protocol payment is 200 units, which exceeds the collected amount. If the payment succeeds, the instance's native balance becomes the reserved amount minus 100, and the next idle computation subtracts the full reservation and reverts, rolling back the payment, the collection and the share mutations together. No permanent loss of principal is observable. | PT-COMP-02, PT-COMP-03, PT-BAL-01, PT-ERROR-04 |

## 4. Preservation and standalone risks

**P1 — Numeric section pointers will break silently.** r2 contains four *numeric* cross-references: `section 5` (PT-API-09), `section 10` (PT-API-17 and PT-ZAP-03), `section 11` (PT-DEP-03), plus `Part III` (PT-CONFORM-01) and `Parts I-III` (PT-HANDOFF-01). Adding front matter or renumbering breaks them without any warning. *Action:* convert the four numeric pointers to ID pointers (PT-API-09 → the basket/quote requirements; PT-API-17 and PT-ZAP-03 → PT-CB-01 through PT-CB-07; PT-DEP-03 → PT-BAL-02), or keep the existing numbering verbatim and put the new PRD material in an unnumbered preamble. Do not renumber Part I–III.

**P2 — The notation glossary and formula tables are load-bearing.** PT-MATH-01 through PT-MATH-05 define MD, MU, `A0down`/`A0up`/`A1down`/`A1up`, `L0`/`L1`/`Fit`, `T(t)` with its 20-row coefficient table, `U128`, and the genesis floor square root. PT-QUOTE-01, PT-VIEW-02, PT-EXIT-02, PT-ZAP-02/04 and PT-COMP-04/05 all reference that notation by name. *Action:* copy Part I sections 3–9, 12 and 13 as-is; only surrounding prose may be restructured. Do not restate a formula table as prose, and do not renumber the coefficient table's rows.

**P3 — C1 must not be applied to PT-DEP-05's first sentence.** Only the final clause changes. The first sentence — "Measured ERC-20 receipts shall replace selected amounts for the event and liquidity funding, but shall not change the already computed or checked shares" — is the rule that couples the receipt to *funding*, not just to the event. A merge that globally replaces "measured" with "pull-returned" silently drops that coupling.

**P4 — The zero/negative difference clause must survive verbatim.** "including zero. A negative difference fails checked subtraction." is what makes a zero-measurement receipt legal and a lowered balance a failure. Summarising it as "measured receipts" loses both halves. Keep PT-BAL-02's rule as well; it is the cross-reference PT-EVENT-02 now points at.

**P5 — C2 must not overwrite PT-DEP-03's route-specific order.** PT-DEP-03 already says "For the paired-entry addition, sample currency0 idle, then currency1 idle, then read the fresh manager price" and adds "This read order is specific to paired entry and does not replace the separate Deploy price/idle checkpoints." Those sentences are the route distinction; replacing them with a bare reference to PT-BAL-01 would destroy it. PT-CB-04/PT-CB-05's already-held-price rule must stay equally distinct.

**P6 — The review grading dispute should not enter the requirement body.** The uncapped-rate behavior is deterministic and belongs in the PRD as prose (§1.3). Whether the omission was a "completeness gap" or an "optional explanation" is review-process metadata; at most one sentence in PT-PRD-05, and it belongs in the archived report.

**P7 — Licensing characterization must not be restated anywhere.** The PRD should not say the prose "reproduces BUSL-covered material" and should not describe the included dependency files as MIT or BUSL. Say nothing about licensing in the PRD beyond "no license determination is made". (This is the specific overstatement the council flagged in my own original; it should not be reintroduced during the merge.)

**P8 — Group tokens that are not IDs must not be "fixed".** PT-AC-01's requirements column cites `PT-API` and `PT-GET`, which are group tokens, not requirement IDs. Keep them as written or expand them consistently across all65 rows; do not rewrite them ad hoc.

**P9 — Product-voice prose is new and must not add guarantees.** PT-PRD-01/02/03 are the first product-voice text. Write them strictly from PT-SCOPE-01/02/03 and the API table. Avoid "earns", "guaranteed", "no loss", "protected": PT-EXIT-05 states that dead-address shares normally remain in supply and that the contract makes no claim all backing property is recoverable by the last ordinary holder, and PT-SCOPE-03 forbids a fee index. A purpose paragraph promising "collective earnings compound into your position" without the qualifiers would contradict the body.

**P10 — The meta-requirements need re-pointing, not deletion.** PT-HANDOFF-01 instructs publication of "this complete standalone requirements document, including Scope and Origin, Conformance and Planning Use, and Parts I-III, not raw source or instructions to consult it". In the unified PRD that instruction is satisfied *by* the PRD, and PT-CONFORM-02's "later implementation plan" framing still holds. *Action:* re-point PT-HANDOFF-01 at this document in one line and mark it satisfied; do not delete it or the ID. Same for PT-HANDOFF-02, whose limits belong in the PRD's limits text rather than only in an annex.

**P11 — Do not abbreviate during the merge.** The consolidation contract is that every requirement ID, all 58 original scenarios, the exact formulas, the operation/check ordering and the dependency limits survive. The only edits are the four approved ones (C1 twice, C2 once plus four cross-references, the §1.3 paragraph, the §1.4 note) and the seven new rows. Any other rewording is a new revision and must be tracked as one.

**P12 — Part III must remain inside the PRD.** The contract requires the external dependency unknowns to live in the PRD so no companion report is needed. Concretely, keep PT-DEPENDS-01 through PT-DEPENDS-05 and the §16 table in full, including the rows that say the manager engine, hook behavior, fee-manager pull, token support and live outputs are unknown — and keep the last row ("Workflow provenance") intact.

## 5. Recommended disposition

Proceed to one consolidated PRD, identity `pairtoken-unified-prd-r1`, as the sole working document. Integrate C1 and C2 in place per §1.1–1.2, guarded by P3–P5; integrate the uncapped-rate consequence as normative prose per §1.3; add the optional PT-VIEW-01 note per §1.4; adopt PT-AC-59 through PT-AC-65 per §3; add PT-PRD-01 through PT-PRD-05 and the identity block per §2; keep every existing ID, table, formula, event and error schema verbatim per P2, P8 and P11; convert the four numeric section pointers per P1; and keep the dependency limits and absence list inside the document per P12. The errata annex is superseded by direct integration and does not need to ship with the PRD; r2 and the fidelity report stay byte-identical archives.

I did not re-read source, add behavioral findings, draft a verification plan, or analyze licensing; every behavior referenced above is already specified in r2, and the only additions are conditional acceptance rows and PRD framing that the brief explicitly invites.

