# Kimi K3 — ORIGINAL: pre-maturity reinvestment of wrapped NetNet bonds (v0.25 reconciliation)

| Field | Value |
| --- | --- |
| Author | Kimi K3 (`kimi-code-plan-global/k3`) — routing metadata only |
| Date | 2026-09-27 |
| Scope | Reconcile the user's newly selected pre-maturity reinvestment with PRD v0.25 §§10/12.4/H01–H03. Research only; no execution/delegation; no new-round peer artifacts read. |

## 1. Accepted choices (user-selected this round — do not reopen)

1. **Pre-maturity dedicated reinvestment exists:** while the original native note is still maturing, the holder may reinvest **already-funded** wrapper principal — principal funded by installments already collected and atomically contributed/minted/staked under the same NFT.
2. **Old position untouched:** old native bond, old wrapping NFT and old holder stay in place; **no** native-note transfer/cancel/second intended purchase on the old holder; remaining funded balance, funded rewards and all future native proceeds stay with the old position.
3. **Mechanics:** consume/burn **only the requested** already-funded principal (partial allowed); quote the requested supported reinvestment asset through the normal **incentive-free owned-reserve burn** (R41, no contraction bonus); process a **new bond with the typical lock for that destination bond type**; actual funded amounts, not projections; any failure restores the old principal atomically; discovery-supported routes only.
4. **Retirement separation:** a fully matured and emptied NFT is claimed/retired separately under the normal path.
5. **Epoch bookkeeping (earlier latest decisions, now operative):** excess native proceeds are credited as same-NFT principal; purchase epoch is stored; release checks use the exposed NetNet processed-epoch counter; an unlock-epoch value of **0 is an unset sentinel** — never "pending" or "fully collected."
6. **Distinct checks:** the purchase-epoch-passed check remains **distinct** from the full-collection epoch checkpoint; lock periods by type are reviewed later; eligibility is not silently settled.

## 2. Exact v0.25 contradictions requiring correction

v0.25's full-collection gate is written **absolutely**, covering both claim and reinvestment. Under the new selection it must govern only **final principal withdrawal/retirement**, while pre-maturity dedicated reinvestment of funded-to-date principal is a separate allowed path. Lines needing scoped amendment:

- **:849 (§12.4):** "The owner selects principal claim/reinvestment **after full collection**…" — contradicts pre-maturity reinvestment directly; must be split.
- **R19 (:165):** "wrapper principal is **claimable/reinvestable only after** full collection…" — the "reinvestable only" clause is superseded for the dedicated path.
- **R12 (:158), :610 (§10 table), :617, :797, R21 (:165 area), O03 (:885), A08 (:932):** each states or repeats full-collection-gated principal release; all need the same scoping phrase ("final withdrawal/retirement"), not deletion.
- **H03 (:859):** largely answered — the replacement is a **new bond (new tokenId)** under the destination type's normal lifecycle; the old NFT/holder persist and retire separately when emptied. Update the row rather than leave it open-ended.
- **H01 (:857):** the headline question is answered (excess credited as same-NFT principal); only late-excess release/donation edges remain.

No contradiction with R41 (no incentive), atomicity (:847), or early funded-reward claims (:849/:809) — all preserved.

## 3. Reconciliation statement (proposed framing)

The full-collection + next-processed-epoch gate (§12.4, H02 boundary) is the **release rule for the old wrapper position's final principal withdrawal and retirement**. The new path is **pre-maturity dedicated reinvestment**: an owner-authorized operation on the *currently funded* principal balance that burns only the requested amount, quotes it incentive-free against the owned reserve, and funds a **new, separate bond** under that bond type's normal rules. It neither accelerates nor relaxes the old position's gate, touches future native proceeds, nor performs any second native purchase.

## 4. Remaining lock/eligibility questions (explicitly NOT settled — user's instruction)

- **L1 — purchase-epoch predicate:** the exact form of the purchase-epoch-passed check for pre-maturity reinvestment (e.g., a strictly later processed epoch than stored `purchaseEpoch`, mirroring H02's discipline) — distinct field, distinct predicate, no silent merge with `fullCollectionEpoch`.
- **L2 — lock durations by destination type:** "typical lock for that destination bond type" with exact values deferred to the announced later review; **no numeric defaults may be invented now**, and C05/NN-04 reference-duration compatibility (oracle min/max vs short locks) still applies to whatever is later selected.
- **L3 — repeat cadence/eligibility:** whether each newly funded installment becomes reinvestable immediately or under an epoch condition; partial-vs-all selection per operation; no per-position frequency rule is selected.
- **L4 — excess-funded principal:** whether excess credited as same-NFT principal (H01 headline answer) is reinvestable pre-maturity on identical terms — presumed consistent, but flag for confirmation since H01's late-excess edges remain open.
- **L5 — accounting isolation proof:** share rounding and backing isolation when part of a funded position burns (participant-only debit, others' backing untouched — A29 semantics), to be demonstrated, not assumed.

## 5. Proposed wording (UNAPPROVED — additive §12.4 paragraph)

> **Pre-maturity dedicated reinvestment (selected).** While the registered intended native note is still vesting, the tokenId's authorized holder may reinvest principal **already funded** by successfully collected and contributed installments. The operation burns only the requested already-funded principal, quotes the requested supported reinvestment asset through the incentive-free owned-reserve burn calculation (no contraction bonus at any step), and processes a **new bond with the typical lock for that destination bond type**, issued as a separate new position. The original native note, wrapping NFT and holder remain in place: no native-note transfer, cancellation or second intended purchase occurs at the old holder; remaining funded principal, funded rewards and all future native proceeds stay with the old position; its final principal withdrawal and retirement remain gated by full collection plus the next processed NET epoch. Amounts are actual funded balances, never projections; failure restores the old principal and all related state atomically. The stored purchase epoch, the full-collection epoch and the release-unlock epoch are distinct fields; an unlock-epoch value of 0 means unset. Lock durations per bond type and the purchase-epoch eligibility predicate remain under later owner review and are not settled here.

## 6. Limits

All PRD citations from direct reads of v0.25 this session; upstream depository semantics from prior verified reads. No execution, no external lookups (no new external library/API claims arose). The user's message treated as the selection text; nothing beyond its explicit wording attributed to the owner. L1–L5 are questions, not proposals of answers.
