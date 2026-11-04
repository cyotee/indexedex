# Council advisory resolution

Reviewed draft: `pairtoken-se-stage-one-council-20261028-01a1810f-draft-r1`
at `coordinator/draft.md`. The reviewed bytes remain unchanged.

All four advisory tasks settled. Every disposition was
**support-with-reservations**, not unconditional approval. This resolution and
`REPORT.md` are coordinator revisions after that pass, not newly member-approved
documents. No second review round was requested or launched.

All feedback is preserved verbatim under `coordinator/received/`.
The frozen draft section 6 maps all 58 initial recommendations. The dispositions
below amend that map where needed and carry every substantive advisory concern.

## Shared material revisions

1. Separate source-confirmed defects from proposed accounting-policy changes.
   In particular, including all fees through compound completion and allocating
   whole-position fees among partial exit/remaining holders is a **proposed
   policy direction** for Q1, not a verified complete algorithm.
2. Expand Q1 to cover both entry and exit attribution, fee checkpoints, and
   residuals. Preserve the candidate of isolating entrant inventory, without
   claiming its full pricing/fairness proof. Paired-only deferral is retained
   as a possible owner-authorized scope reduction, not silently selected.
3. State preview parity's economic domain, external-interaction revalidation,
   and the common preflight sequence explicitly in the final report.
4. Add concrete retained technical details that appeared only in traceability:
   one-sided accepted maxima, empty-book compound, final selector manifest/
   absence checks, package binding identity, canonical state reads, and exact
   error/rounding rules.
5. Clarify donation-disable trade-offs and retain smaller policy decisions as
   proposed, not confirmed. No claim that donation or public compound guarantees
   exit recovery.

## Astra advisory

| Concern | Resolution |
| --- | --- |
| 1: Economic parity and invalidated preflight assumptions are absent from body | Accepted. Final section 4 states caller-specific exclusions, actual-delta authority, revalidation after token/wrapper interactions, and the full operation sequence. |
| 2: R7 one-sided input rule, R10 empty compound, and R12 manifest/absence/identity controls only in traceability | Accepted. Final section 4 supplies the requirements explicitly, without new owner questions. |
| 3: Blocking donation while disabled is a new policy with maintenance trade-off | Accepted. Final secondary-policy table distinguishes stopping capital contributions from stopping issuance and notes possible maintenance funding without promising recovery. |
| 4: Heading overstates verification of complete fee-allocation and projector designs | Accepted. Final separates concrete compatibility corrections from accounting/projector specifications and owner choices. |
| Not-adopted alternatives and limits | Preserved. No formula, fallback, conservative bound, guarded canonical facet, or genesis minimum becomes approved by this resolution. Sorted registry identity remains coordinator-verified evidence, not an Astra independent finding. |

## Grok advisory

| Concern | Resolution |
| --- | --- |
| C5 recommends and reserves all-fees snapshot simultaneously | Accepted. Final presents include-through-completion as the coordinator's preferred direction under owner Q1, explicitly covering entry and exit. The source observation is branch-dependent fee realization, not a settled allocation rule. |
| C1 correction and C3 shared-view split are fairly represented | Retained. Rate arithmetic is a technical correction; shared facets remain unchanged. |
| R13 characterized too broadly as blanket risk acceptance | Clarified. Final preserves the point that A46 cannot reintroduce dead/virtual shares, while refusing to infer acceptance of every economic outcome. |
| Paired-only deferral missing from Q1 alternatives | Accepted as an owner-authorized scope-reduction alternative. The current stage-one scope still includes single-token SE/SY routes. |
| R4 does not demonstrate an interior mismatch; Fit capacity liveness remains open | Accepted. Final demands manager-equivalent controls and explicit capacity/failure policy, without asserting an observed interior defect or silently clamping additions. |
| R5/R6 fee-exclusion attribution | Clarified. Branch-dependent fee-snapshot dissent is recorded under R6; copied-state projector details from R5 remain retained. |
| Declined peer claims and limitations | Preserved without claiming Grok independently revalidated new coordinator sources in this restricted pass. |

## Kimi advisory

| Concern | Resolution |
| --- | --- |
| 1: Common preflight ordering exists only in traceability | Accepted. Final supplies the exact sequence, including native reservations and shared reserve publication. |
| 2: All-fees snapshot both recommended/reserved; Q1 framed only as entry | Accepted. Final Q1 expressly includes entry and exit ownership, whole-position fees, swap-generated fees, and residuals. No completed formula is claimed. |
| Original scaling issue was not independently found by Kimi | Attribution retained: Astra, Grok and MiniMax raised the unit defect; Kimi accepted it during advisory review. |
| Fallback changes confirmed baseline compounding | Retained explicitly as a proposed owner departure, not an already-compatible interpretation. |

## MiniMax advisory

MiniMax withdraws its inherited-interface-ID argument, alleged premature native
refund release, universal zero-tick-movement claim, exact-parity infeasibility
framing, and overstated dust-branch language. These withdrawals do not erase
the preserved original.

| Concern | Resolution |
| --- | --- |
| A: Keep ERC-165 Out-advertisement objection after fixing ID arithmetic | Partially retained as an integration-convention concern, not a proven technical contradiction. Installed canonical methods may intentionally signal `ExchangeOutNotAvailable`; interface detection is not a per-route execution guarantee. Recommend explicit In/Out declarations consistent with the installed canonical ABI and explicit unsupported-route handling, not automatic removal of Out's declaration. Do not register an empty combined marker as a useful capability signal. This registration policy is not described as separately owner-confirmed. |
| B: Supply concrete interface-ID guidance and local corroboration | Accepted in part. Final says use directly declared canonical IDs; inheritance-only `IStandardExchange` contributes no distinct function ID and cannot represent an In/Out union. No duplicate metadata selectors. The canonical source declarations and Solidity documentation support this; member inference alone is not proof. |
| C: Keep refund invariant while withdrawing alleged baseline defect | Accepted. It is preserved baseline behavior plus explicit ledger specification, not a defect finding. |
| D: Retain native validity derivation, native/wrapped preview parity, and native dispatch hazard | Accepted with source correction: shared `redeem` has distinct `_standardRoute` and `_redeemVaultHeld` seams, not both exclusively `_exchangeIn`. Final states discovery-derived validity and override-seam adaptation without requiring a full public redeem rewrite. |
| E: Operation-generated terminal receipts must be booked to last holder | Accepted. Every owned settled receipt is booked/allocated once; terminal owned receipts go to the last holder, unsolicited funds remain unbooked. Do not posit a guaranteed stranded rounding asset without evidence. |
| F: `deployed_i - max(0,idleBefore_i)` allegedly cannot be negative | Rejected. The max lower-bounds the subtrahend, not the subtraction result. For deployed 3 and prior idle 5, the written expression is -2 (or checked unsigned underflow). Its swap/fee attribution defects remain independently sufficient. MiniMax withdrew the proposed formula; no revised formula is adopted. |
| G: Parameter coupling retained after tick/price correction | Accepted. Keep maxZapBps's two roles and the exact tick predicate; no universal price-movement assertion. |
| H: Withdraw infeasibility framing and concur with defined exact-parity domain | Retained. No gas prototype or cap feasibility evidence is claimed. |
| I: Withdraw broad multi-asset-shape proposal; distinguish shape from full interface | Accepted. Final distinguishes adopting a selector shape from claiming the full interface. Native paired deposits need payable behavior, unlike the current canonical nonpayable declaration; argument shape alone does not add all sibling operations. |
| J: Rewrite contents-ID formula and test two list orderings | Accepted. Final explicitly replaces unsorted hash with registry-sorted copy while preserving PoolKey face order for token/reserve views. |
| K: Sequential-floor/overflow sharpening | Retained. Pin exact arithmetic and admitted domain; no universal two-mulDiv proof. |
| L: 18 decimals is baseline-preserving, Wings-relative context only | Accepted. No baseline-deviation row for an already-18-decimal baseline. |
| M: Canonical state reads preserve behavior, not unsupported scope | Accepted. Final calls for equivalence controls and canonical readers. |
| N: Explicit native sync is a sequencing deviation | Accepted. Record it as an intentional integration-sequence change from the baseline, without claiming the baseline always fails. |
| O: Body should carry fee-ID verification, raw DUST, new-capability taxonomy, unlock read, ABI details | Accepted. Final technical checklist includes each; no new fee-routing fallback is authorized. |
| P: “Draft” ambiguously names PRD and synthesis | Accepted. Final uses “target PRD” or “reviewed synthesis” explicitly. |
| Q: Write-tool process note | Accepted as provenance detail: member used a first-class Markdown creation tool only at assigned path and disclosed it, but did not follow the brief's inline-only fallback for unavailable apply_patch. No equivalent violation occurred in advisory phase. |
| Advisory document counts | Not adopted. The actual initial set is 58 recommendations (13 Astra, 13 Grok, 23 MiniMax, 9 Kimi), not 52. The synthesis has six C headings, not three. These counting errors do not affect substantive dispositions. |

## Dissent and unresolved policy

- Fee recognition/allocation through compound completion remains a proposed
  owner decision; Grok's baseline-exclusion preference is retained as dissent
  with the positive-add/no-add qualification.
- MiniMax continues to prefer not advertising Out in ERC-165. The coordinator
  does not treat this as required by the owner-confirmed unsupported operations.
- Kimi prefers a collect-only exit fallback, requiring an explicit change to
  the confirmed mandatory baseline compound sequence.
- Genesis minima, zero-output burns, disabled donation, unsolicited fund
  recovery, and decimals caching remain proposed policy details.

The final report delivers these unresolved choices rather than pretending
unanimity or editing the target PRD. No implementation is authorized.
