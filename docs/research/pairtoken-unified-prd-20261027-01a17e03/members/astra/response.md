# Coordinator-preserved drafting contribution

Astra returned this original contribution inline for the unified PRD authoring task. Preserved verbatim from Native final_response. It is not an advisory disposition or a replacement for the previous fidelity-review original.

---

Independent drafting contribution complete toward the unified PRD. You need: 3/3 tasks done; proposed integrated prose, eight additional acceptance rows, and preservation risks below. Now: No task remains. Next: None.

## Recommended disposition

**Consolidate into `pairtoken-unified-prd-r1`.** Retain the complete baseline, integrate the clarifications directly into their existing requirements, and include the uncapped-fee consequence explicitly. The final PRD should require neither the previous requirements nor an errata annex to interpret its behavior.

This is my new original authoring contribution, not an advisory review of the eventual unified draft.

## 1. Product purpose, authority, and provenance

### Proposed opening prose

> # Pair Token product requirements
>
> Document identity: `pairtoken-unified-prd-r1`.
>
> This PRD defines a fungible share in one directly held PoolManager position and the instance's idle pool currencies. It specifies paired deposits, single-currency zap deposits, paired and selected-currency redemptions, share transfers and approvals, current-state previews, and permissionless collective compounding. Each operation remains subject to its exact guards, arithmetic, dependency calls, and transfer outcomes below.
>
> The objective is independent implementation of the specified PairToken-local behavior. It is not an economic redesign, a new pool engine, or an IndexedEx-specific integration. The complete interface, arithmetic, operation ordering, acceptance scenarios, and external dependency boundaries are contained in this document.
>
> This PRD supersedes `pairtoken-requirements-final-r2` and its proposed errata as the single working specification. Those earlier artifacts remain unchanged archives; they are not additional normative inputs. Existing requirement identifiers and PT-AC-01 through PT-AC-58 are retained. Clarifications and additional scenarios are incorporated here rather than delegated to a companion report.
>
> The baseline describes PairToken identified by chain 4663, address `0x56C8c249d4c021e93635b120aC68A9a36eb01753`, and source match ID 55980642. Its provenance is source-informed analysis and documentation review, not executed proof of a future implementation. Neither this document nor a separate implementing team establishes legal clearance or a source-unexposed process.

Retain PT-CONFORM-01/02, all detailed functional sections, and the entire absent-behavior and dependency sections after this introduction. Do not replace them with the introductory summary.

### Proposed additional conformance requirement

> **PT-CONFORM-03 - Evidence for conformance claims.** An implementation claiming conformance shall map each requirement and acceptance-scenario identifier to its implementation responsibility and supporting verification evidence. Evidence shall address the specified integer results, ABI and event fields, failure behavior, and dependency-call ordering where these are observable requirements. Documented scenarios are expected observations, not evidence that execution occurred, and they do not exhaust every input.
>
> Identify the dependencies and assumptions used by the evidence. Distinguish PairToken-local conformance from whole-system equivalence, which additionally requires identified compatible manager, factory, fee-manager, hook, and currency behavior. Report unresolved mismatches and unverified claims explicitly rather than describing a partial result as complete equivalence. Any deliberate behavioral deviation shall identify the requirement it supersedes and remain distinguishable from this baseline.

This defines evidence for a later claim; it does not authorize implementation, testing, or deployment in the present documentation task.

## 2. Integrated behavioral prose

### Receipt terminology: PT-DEP-05

Replace its final event-description sentence with:

> Emit `Deposit` after the refund with pull-returned amounts `v0,v1` and net recipient shares. A zero selected amount returns zero without a token call. A native pull returns its selected nominal amount without balance-delta measurement. A nonzero ERC-20 pull returns the checked post-call instance balance minus its pre-call balance; the difference may be zero. A lower post-call balance fails checked subtraction. These receipt rules do not recompute the already quoted shares or bypass any later failure.

Keep its preceding rules about unpulled excess, retained idle funds, refund recipient, reservation clearing, and refund failure.

### Receipt terminology: PT-EVENT-02

Use this complete replacement:

> **PT-EVENT-02 - Values.** `sender` in deposit/redemption events is the original entrypoint caller, and `to` is the supplied recipient. Paired `Deposit` amounts are pull-returned amounts under PT-BAL-02: nominal selected native amounts or checked ERC-20 post-minus-pre balance differences, including zero. Zap `Deposit` amounts are reported add-used amounts, not the input pull return. Genesis `Deposit.shares` is the net recipient amount after the dead mint. `Redeem.shares` is the entire burned amount; zap `Redeem.amount0/amount1` remain the pair allocation before its sale. `Compounded` records reported collection, reported protocol routing, and requested successful addition as defined in section 8.

For consistency, replace only the first sentence of PT-ZAP-03 with:

> Pull the selected input under PT-BAL-02 and let the returned amount be `v`; clear the native reservation.

This avoids describing a native zap pull as balance-measured while retaining the existing `floor(v/2)` rule and every subsequent checkpoint.

### Idle sampling: append to PT-BAL-01

> Whenever both configured idle balances are sampled as a pair, read currency0 idle before currency1 idle. This order does not establish a shared snapshot or authorize moving reads across a route's price, burn, settlement, or reservation checkpoints. A native idle read uses the instance's native balance minus its current reservation; it does not call an ERC-20 balance function. Paired-entry addition reads a fresh manager price after its two idle reads. Deploy instead uses the initial or post-swap price already obtained at its specified checkpoint.

Apply the rule directly at these local passages:

| Requirement | Proposed local wording |
| --- | --- |
| PT-VIEW-02 | “Read price, then position liquidity, then add currency0 idle before currency1 idle, preserving the principal calculations and checked additions specified below.” |
| PT-EXIT-01 | “Snapshot currency0 idle, then currency1 idle, then burn **the caller's** `s` shares, without using an allowance or accepting an owner parameter.” |
| PT-COMP-04 | “After protocol routing, sample currency0 idle as `i0`, then currency1 idle as `i1`.” |
| PT-CB-05 | “If skip-add is true, return the swap report with zero used amounts and zero reported addition. Otherwise sample currency0 idle, then currency1 idle, and calculate fundable liquidity using the current price already held by Deploy.” |

Retain the remaining text of each requirement. In particular, the skip-add return remains before Deploy's idle reads; the general sampling rule must not introduce reads on a skipped path.

### Uncapped protocol payment: append to PT-COMP-02

> The attempted protocol amount is not capped at the corresponding reported collection or by a separately segregated principal budget. A returned `uint16` fee rate above 10000 can therefore request more than was collected. If the payment or token pull succeeds, it can consume other held balance. Native reservation excludes an amount from idle accounting; it does not create an independent spending restriction on protocol notification.
>
> This consequence does not change notification failure handling or checked idle subtraction. For example, suppose currency0 is native, the collection pair is `(100,0)`, the protocol rate is 20000, and the instance has native balance `R+100` with reservation `R`, where `R>=100`. Assume a nonzero fee manager accepts the attempted native payment of 200 and no intervening call changes the remaining balance. The payment leaves `R-100`. The subsequent native idle calculation subtracts the still-active reservation `R` and fails checked subtraction. That uncaught failure rolls back the entire transaction, including the payment. It is not a successful permanent principal drain.
>
> Preserve the uncapped calculation and these failure semantics. Do not add a rate clamp, a collected-fee cap, or a principal-spending guard to make this conditional case succeed.

## 3. Additional acceptance rows

Retain PT-AC-01 through PT-AC-58 in full. The following proposed identifiers do not overlap them. Apply PT-AC-BASE: premises are conditional, earlier failures retain precedence, and these are unexecuted scenarios.

| ID | Scenario | Expected observation | Requirements |
| --- | --- | --- | --- |
| PT-AC-U01 | Successful native paired deposit whose quote selects less native than `msg.value` | Native pull return and the native `Deposit` amount equal the selected nominal amount, not a transfer-time balance increase. The unselected reservation is cleared and refunded to the caller after minting and before `Deposit`. | PT-DEP-03/05, PT-BAL-02/06, PT-EVENT-02/03 |
| PT-AC-U02 | Established paired entry accepts a positive gross share quote; a nonzero ERC-20 pull succeeds but its post-call instance balance equals its pre-call balance | The pull returns zero. There is no strictly-positive-receipt guard or share recomputation. If subsequent steps succeed, the deposit event reports zero for that receipt and the earlier accepted share count is minted. | PT-DEP-02/04/05, PT-BAL-02 |
| PT-AC-U03 | A nonzero ERC-20 pull passes its low-level return-data check, but the post-call instance balance is lower than the pre-call balance | Checked subtraction fails. The operation rolls back; the receipt is not clamped to zero or replaced with the nominal request. | PT-BAL-02/03, PT-ERROR-03/04 |
| PT-AC-U04 | Trace idle-pair sampling across basket, paired addition, redemption, compounding, and Deploy | Each reached pair is sampled currency0 before currency1. Paired addition reads fresh price afterward; Deploy uses its already-held price. Redemption samples before burning. Skip-add Deploy returns without introducing idle-pair sampling. Earlier failures still stop later reads. | PT-BAL-01, PT-VIEW-02, PT-DEP-03, PT-EXIT-01, PT-COMP-04, PT-CB-04/05 |
| PT-AC-U05 | Native collection `(100,0)`, rate 20000, reservation `R>=100`, pre-notification native balance `R+100`; notification accepts 200 without returning funds and no intervening balance change occurs | The next native idle subtraction underflows. The uncaught failure reverts the whole transaction, including notification payment. No clamp, caught-zero-protocol substitution, or successful permanent drain is inferred. | PT-COMP-02/03/04, PT-BAL-01, PT-ERROR-04 |
| PT-AC-U06 | Zap entry passes earlier guards; Deploy succeeds but computes no addition and reports both used amounts zero; subsequent tick arithmetic and movement check pass | The final share quote is zero and `MinShares` rejects, including with `minShares=0`. Earlier pull, swap, and compound effects roll back. | PT-ZAP-03/04, PT-CB-05, PT-ERROR-04 |
| PT-AC-U07 | Caller can burn one raw share with zero output minimum; selected output is native and the recipient rejects an empty-calldata zero-value payout call; all earlier steps succeed | Chosen-leg redemption still attempts that call and fails with the specified `WrappedError`, recipient target, zero selector, returned reason bytes, and `NativeTransferFailed()` context. The burn rolls back. Under the corresponding paired zero-output case, both payout calls are skipped. | PT-EXIT-02/03/04, PT-BAL-05, PT-ERROR-04 |
| PT-AC-U08 | Public `compound` begins with zero position liquidity; an idle balance exceeds DUST and Deploy successfully reports positive addition `A` | No Collect unlock occurs. Return remains `(0,0)` despite deployment. Emit `Compounded(0,0,0,0,A)` and mint no shares. Collection-routing getters are skipped, although ratio sizing may require the cap getter. | PT-COMP-01/02/04/05/06 |

## 4. Standalone handoff wording

### PT-HANDOFF-01 replacement

> **PT-HANDOFF-01 - Standalone use.** Publish this complete PRD as the single planner-facing working specification, including its purpose, conformance rules, full functional requirements, complete acceptance scenarios, and external dependency limits. No earlier requirements document, errata annex, council report, source listing, or instruction to inspect target code is required to interpret it. Preserve analyst traceability separately. If a later plan deliberately changes a specified behavior, identify the requirement it supersedes and obtain the separate product decision; do not describe that change as source equivalence.

### PT-HANDOFF-02 replacement

> **PT-HANDOFF-02 - Limits of this document.** This task authorizes documentation consolidation, not implementation, execution, deployment, or legal determinations. The PRD is source-informed; its acceptance scenarios are not executed evidence. No license opinion, legal clearance, or source-unexposed workflow is certified. These limits do not prevent requirements-based planning, but unknown external behavior must remain an explicit dependency rather than an invented guarantee.

## 5. Preservation and standalone risks

- **Preserve the actual specification, not just its inventory.** Every existing ID, all 58 original scenarios, ABI rows, tick coefficients, formulas, casts, errors, events, and dependency limits must remain in the unified document.
- **Do not turn C1 into receipt-based repricing.** Paired shares remain quoted before pulls; zap shares remain based on reported add-used amounts. A zero receipt is not automatically a successful operation.
- **Do not turn C2 into one universal snapshot.** Preserve route-specific reads and the absence of reads on early-return paths. The clarification does not establish state-mutating behavior inside `balanceOf`.
- **Keep fee assessment separate from payment funding.** Donations are not independently assessed as collected fees, yet other held funds can finance an uncapped attempted payment. Both statements must remain.
- **Retain conditional examples and failure precedence.** No-add zap reaches `MinShares` only if the preceding tick check succeeds. A caught notification failure differs from successful notification followed by uncaught idle underflow.
- **Use the new identity consistently.** Remove inherited claims that the current working document is unchanged r2 or requires proposed errata. Do not claim that this new final text has already received its later advisory review.
- **Keep unknown dependencies inside the PRD.** Do not replace Part III with links or invent manager versions, factory defaults, token restrictions, deployment architecture, or legal conclusions.

Only the brief and its admitted initial-authoring documents were read. No source retrieval, project commands, tests, edits, memory operations, or delegation occurred. No file was written.

