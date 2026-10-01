# MiniMax M3 — Partial-Reinvestment Cross-Review (Bounded Round)

> Cross-review of three peer originals (`astra-original.md`, `grok-original.md`, `kimi-original.md`) for the pre-maturity reinvestment round. Read together; no peer cross-review consulted. My `minimax-original.md` is the baseline. **User corrections applied** to this cross-review: (1) `unlockEpoch = 0` is the **assigned Pendle-market maturity sentinel**, NOT "unset/pending/unlocked"; (2) no invented `purchaseEpoch > 0` sentinel — the gate is a **comparison**, not a sentinel check on `purchaseEpoch` itself; (3) actual fields/storage layout are engineering; (4) share units ≠ raw principal — don't subtract raw `q` from `internalShares`; (5) `PkgArgs` is not an asset allowlist; (6) no extra routes/cadence/lock periods or re-approval of chosen process; (7) prior full-collection condition cannot gate selected pre-maturity reinvestment; (8) existing final-release rule recorded separately; (9) full currently-funded amount may leave old NFT with future native claim — **don't retire on zero principal alone**; (10) excess destination settled (same-NFT principal), only late timing/direct donations remain open. Research-only. Routing metadata `minimax/MiniMax-M3` only. Date 2026-09-27.

---

## 1. Convergence (all three agree)

1. **Two paths, not one gate.** Full-collection + next-processed-epoch is **path B (final withdrawal / retirement)**. Pre-maturity dedicated reinvestment is **path A**, gated on `purchaseEpoch < processedEpoch` and non-zero funded principal. The user's `purchaseEpoch < processedEpoch` is a **comparison**, not a sentinel check on `purchaseEpoch` itself.
2. **`unlockEpoch = 0` is the assigned Pendle-market maturity sentinel.** All three converged; my original incorrectly framed it as "not yet unlocked" — corrected here.
3. **Old position untouched.** Old native note, old holder, old wrapping NFT stay in place. New bond = **new tokenId / new position** with destination-type lock. **No second intended native purchase on the old holder.**
4. **Consume only the requested amount.** Burn `q ≤ P` of actually-funded principal. Reinvestment does NOT empty the old NFT by itself; full currently-funded amount may leave the old NFT with future native claim, do not retire on zero principal alone.
5. **No contraction input bonus.** R41 / §10.1 / §7.2 with `quoteInput = q` at every peg regime. No nested bonus.
6. **Atomic restore on failure.** Old principal, claims, native note, holder untouched on revert.
7. **Discovery-supported routes only.** §12.4b reuses existing §12.4 / §10 / §7.2 paths. **No new routes.**
8. **Actual funded amounts, not projections.** Per §12.2 :847 preview separation; share units ≠ raw principal — debit **only this position's** internal shares / held DETF (R41 / §10.2), floor rounding, actual `balanceOf` / shares.
9. **PkgArgs is not an asset allowlist.** Destination asset for reinvestment is not gated by PkgArgs.
10. **No field layout / storage prescription.** Three semantic fields (`purchaseEpoch`, `fullCollectionEpoch`, `unlockEpoch`) — actual layout is engineering.
11. **H01 closed** (excess = same-NFT principal); only late-excess timing/donation classification remains open. H03 (replacement identity): **answered** — new bond is new tokenId; old tokenId persists.

---

## 2. Attributed corrections to my original

- **My `purchaseEpoch` and `unlockEpoch` sentinels were wrong.** I wrote: "`purchaseEpoch`: 0 = not yet deposited; `unlockEpoch`: 0 = not yet unlocked." Per user correction: **`unlockEpoch = 0` is the assigned Pendle-market maturity sentinel** (target epoch, not state). `purchaseEpoch` is a comparison operand, not a sentinel — the gate is `purchaseEpoch < processedEpoch`, regardless of whether `purchaseEpoch` itself is zero. **My §4 wording had this backwards.** I had "0 = not yet unlocked" which Grok correctly flagged as wrong.
- **My L01 / L02 framing still applies** — destination bond type and lock period remain unsettled — but **lock period default must be 0 = assigned Pendle maturity**, not "unset/pending."
- **My "no native redeem required to reinvest" framing**: I correctly captured this. All three peers agree (Astra: "no native-note transfer/cancel/second intended purchase"; Grok: "Path A does not require `claimed == payout`"; Kimi: §4 :849 split). My original §2.2 / §3 / §5 are aligned.
- **My "share rounding / backing isolation"**: my L04 is correct, but I had a typo/error in the original wording suggesting "subtract raw q from internalShares." Per user correction, internal shares / balanceOf is the unit; raw q is in DETF units; debit must be the **share-unit equivalent** of `q`, not raw `q`. **My original §3 L04 says "internalShares(old) - requested = internalShares(remaining)"** — that's wrong because `requested` is in DETF units, not share units. The correct statement is: "redeem `q`'s share-unit equivalent from internalShares(old); internalShares(remaining) = internalShares(old) − shareUnits(q)." Fix in the proposal wording.
- **My "no PkgArgs allowlist"**: my L01 said "destination bond type." Per user: PkgArgs is not the gating. The destination is **selected by the operation**, not pre-configured. **Fix:** remove the suggestion that PkgArgs is the allowlist.
- **My "lock periods deferred, no numeric defaults"**: aligned with all three peers and user instruction. **Fix wording:** explicitly state that lock periods are engineering, not PRD; the §12.4b wording must not specify hours/days.

---

## 3. Genuine differences

- **Astra** is the strongest on the "no native redeem required to reinvest" framing. Frame: blocked `redeem` stranding uncollected **native** is real; blocked `redeem` stranding already-funded DETF is **not** — already-staked DETF can be burned into a new bond independent of upstream state. **Correct and accepted.**
- **Grok** correctly framed the `unlockEpoch = 0` = assigned Pendle maturity semantics (line 26, 53). Catches my error.
- **Kimi** is sharpest on the **three-epoch semantic-field table** without prescribing storage (line 44). Distinguishes from sentinel logic. **Accepted.**
- All three converge on the **two-path split** (A = pre-maturity reinvest, B = full-collection withdrawal/retirement). All three explicitly say full-collection does not gate A. None of them invented `purchaseEpoch > 0` as a sentinel — only my original did.

---

## 4. Accepted choices (do not reopen)

1. **Pre-maturity dedicated reinvestment exists** (path A).
2. **Old position untouched:** native note, holder, NFT, remaining principal/rewards, future native proceeds all stay.
3. **New bond = new tokenId** with destination-type lock. **No** second native purchase on old holder.
4. **Consume only requested `q ≤ P`** of actually-funded DETF principal; quote incentive-free via §7.2 owned-reserve burn; route via existing discovery-supported destinations.
5. **Atomic restore** on failure; old principal/claims untouched.
6. **No contraction input bonus** at any nested step.
7. **Excess native proceeds = same-NFT principal** (H01 closed headline). Only late timing/donation remain.
8. **Three semantic epochs** (`purchaseEpoch`, `fullCollectionEpoch`, `unlockEpoch`), kept distinct. **`unlockEpoch = 0` = assigned Pendle-market maturity sentinel** (not "unset"). Actual layout engineering.
9. **`purchaseEpoch < processedEpoch`** is the comparison gate for path A. **No invented sentinel** on `purchaseEpoch`.
10. **Full currently-funded amount** may leave the old NFT with future native claim — **don't retire on zero principal alone.**
11. **No PkgArgs asset allowlist.** Destination chosen at operation.
12. **No extra routes, cadence, lock periods, or re-approval** of the chosen process. Lock periods by type deferred.
13. **Final-release rule** (path B, full-collection + next processed epoch) **recorded separately**, subject to upcoming lock review.

---

## 5. Deferred / not silently settled

- **L1** Exact form of `purchaseEpoch < processedEpoch` predicate (snapshot timing, batch interaction).
- **L2** Lock durations by destination type (no numeric defaults; C05 / NN-04 reference-duration compatibility still applies).
- **L3** Per-call cadence / partial-vs-all current principal selection. No frequency rule selected.
- **L4** Late-excess release timing / direct-donation classification (subset of H01).
- **L5** Accounting isolation proof — share-unit conversion of `q`, R41 / §10.2 share rounding, backing isolation (A29 semantics).
- **H03** terminal late-gift / retirement behavior beyond "full matured + emptied = retire separately." Persistent proxy after retirement, by whom, with what final destination.
- **No claimed measurement** of `internalShares(q)` rounding, gas, attacker cost, N*, blocked-redesign impact.

---

## 6. Concrete PRD amendment (UNAPPROVED)

```markdown
### §12.4b Pre-maturity dedicated reinvestment (selected; UNAPPROVED drafting)

While the registered intended native note is still vesting, the wrapping NFT's authorized holder may reinvest **already-funded** principal — principal sourced from successfully collected and atomically contributed/minted/staked installments on this NFT. The original native note, wrapping NFT and holder remain in place: **no** native-note transfer, cancellation or second intended purchase on the old holder; remaining funded principal, funded rewards and **all future native proceeds** stay with the old position.

**Path A is separate from path B.** Path B (final principal withdrawal / retirement of the old NFT) remains gated by full collection of the registered intended native note plus the next processed NET epoch. Path A is **not** gated by that. **Full collection is not required for path A.**

**Gate for path A:** the recorded `purchaseEpoch` is strictly less than the current processed NET epoch, **and** the NFT has non-zero already-funded DETF principal attributable to the registered position. The `purchaseEpoch < processedEpoch` comparison is the eligibility predicate; the **value** of `purchaseEpoch` is not a sentinel — it is the recorded NetNet-processed counter at the first successful authorized deposit. Failed contributions, gifts and unrelated pre-existing balances do not satisfy this gate.

**Distinct epoch semantics:**
- `purchaseEpoch`: NetNet processed counter recorded at first successful authorized deposit; used as the comparison operand for path A.
- `fullCollectionEpoch`: NetNet processed counter recorded when the registered intended note's `claimed == payout` and the last installment has been contributed; gates path B.
- `unlockEpoch`: target epoch for the destination bond's Pendle-market maturity. **0 = assigned Pendle-market maturity sentinel**, not "unset / pending / fully collected." The exact value is engineering.

The three fields are distinct. None aliases another; none collapses into a sentinel check on the operand itself. Stored layout is engineering.

**Process (one rollback domain):**
1. Snapshot funded DETF principal attributable to this NFT; record requested amount `q` with `0 < q ≤ funded` (share-unit conversion of `q`, not raw subtraction).
2. Owned-reserve burn per §7.2 with `quoteInput = q` at every peg regime; **no** contraction input bonus at any nested step.
3. Route through a discovery-supported destination bond accepting the realized asset; preserve normal bond calculations, fees and end-to-end limits.
4. Process a **new bond with the typical lock for that destination bond type**, issued as a **separate new position** (new tokenId). **Lock durations per bond type are not settled here** and remain under separate review; **no numeric defaults may be invented now.**
5. Burn **only** the share-unit equivalent of `q` from this NFT's internal shares; residual `funded − q` stays with the original NFT. **Full currently-funded amount may leave the old NFT with future native claim — do not retire on zero principal alone.**
6. Atomic revert on any failure: restore old principal, claims, native note, holder state and all related markers; **no** new bond, **no** native collection, **no** second purchase.

**H01 already settled:** excess native proceeds credit same-NFT principal; only late timing and direct-donation classification remain. **H03 partial:** replacement is a new tokenId; old tokenId persists and retires separately when fully matured and emptied. Persistent proxy after retirement / late-gift terminal destination remains open.

**No second native purchase** at the old holder. **No contraction input bonus.** **No new routes / cadence / lock periods invented.** No re-approval of the chosen process.
```

---

## 7. Confidence and evidence limits

- **High** that path A and path B are distinct, and full-collection does not gate path A.
- **High** that `unlockEpoch = 0` is the assigned Pendle-market maturity sentinel (per user).
- **High** that my original's `purchaseEpoch > 0` / `unlockEpoch = 0 = not yet unlocked` framing was incorrect; corrected here.
- **High** share-unit conversion required for `q`; raw subtraction forbidden.
- **Medium** on the three-epoch field mapping (engineering detail).
- **Low** on share rounding math, gas, N*, blocked-redesign impact.
- **Not claiming** lock periods decided; exact epoch comparison predicate settled; share-unit math implemented; persistent-proxy retirement decided.
- **Not reopening** per-NFT isolation, R41 no-bonus, atomic installment, excess-as-same-NFT, H01 headline.

**Saved:** `docs/research/netnet-partial-reinvestment-2026-09-27/minimax-cross-review.md`. Original untouched.
