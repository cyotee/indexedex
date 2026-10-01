# MiniMax M3 — Partial-Reinvestment Assessment (Bounded Round)

> **Scope:** user extends the holder-proxy behavior with a NEW pre-maturity partial reinvestment path. Read current CLAUDE/canonical relevant skills, PRD v0.25 §12.4 (lines 825–859), §10.1, tracker. Research-only; routing metadata `minimax/MiniMax-M3` only. Date 2026-09-27.

---

## 1. Accepted choices (do not reopen)

1. **Pre-maturity partial reinvestment is selected.** While the original native bond is still maturing, an NFT can request partial reinvestment of already-funded/staked principal into a NEW bond position. Old native bond stays in place; old holder stays in place; old NFT stays in place.
2. **Gate is `purchaseEpoch < processedEpoch`.** The purchase-epoch-passed check is **distinct from** full-collection prerequisite. Lock periods by destination bond type are reviewed later — do not silently settle eligibility.
3. **Process: consume only the requested amount of already-funded principal** under the same NFT; quote requested supported reinvestment asset using normal incentive-free owned-reserve burn; process a new bond with **typical lock for that destination bond type** (not the original native-bond lock). Remaining funded balance/rewards and future native proceeds stay with the old position. No native-note transfer/cancel/second purchase on the old holder. Fully matured+emptied NFT can be claimed/retired separately under existing §12.4 retirement.
4. **Incentive-free.** No contraction input bonus (preserves R41 / §10.1 "never applies" rule).
5. **Excess native proceeds credited as same NFT principal** (H01 disposition from prior round, accepted).
6. **Epoch semantics:** store `purchaseEpoch` (recorded at first deposit), `fullCollectionEpoch` (recorded at `claimed == payout`), `unlockEpoch` (recorded at reinvestment/bond-issue). **0 sentinel** = "not yet pending / not yet fully collected / not yet unlocked." Three distinct semantic fields, all kept separate.
7. **Discovery-supported routes only** (existing selected DETF-out swap and eligible-contraction paths; no new oracle/curve).

---

## 2. Exact PRD contradictions needing correction

### 2.1 §12.4 line 849 (R41 release prerequisite)

Current text:
> "The owner selects principal claim/reinvestment **after full collection of the registered intended native bond and the next processed NET epoch**. Native maturity alone, a failed contribution, or an unrelated gift is not completion. … **Later eligible principal reinvestment follows R41**: consume the position's old funded principal/claim, use the incentive-free burn/rebond calculation, and fund the new bond position once; it is not an implicit second native purchase at the old holder."

**Conflict:** line 849 conditions R41 reinvestment on **full native collection + next processed NET epoch**. The user's new partial-reinvestment path allows reinvestment while the original native note is still maturing, conditioned on **`purchaseEpoch < processedEpoch`** and **already-funded principal**. This is a new path, not a replacement of the full-collection path.

**Correction:** split §12.4 into two sub-paths:

- **§12.4a — Full-collection reinvestment (existing):** requires `fullCollectionEpoch > 0` (i.e., `registered note claimed == payout`) and `processedEpoch > fullCollectionEpoch`. Creates new bond position via R41 mechanics; old NFT continues as before.
- **§12.4b — Pre-maturity partial reinvestment (NEW):** requires `purchaseEpoch > 0` (i.e., a first authorized deposit occurred) and `processedEpoch > purchaseEpoch` and **already-funded principal exists** under the NFT. Consumes only **the requested amount** of already-funded DETF principal; uses owned-reserve burn on the requested supported asset; creates a new bond position with destination-type-appropriate lock (lock period selected per type, separate from the original native-bond lock). Does not touch the original native note, the holder, or the original NFT's remaining claims.

The two paths are **distinct**: §12.4a is for full-collection reinvestment (existing R41); §12.4b is for pre-maturity partial reinvestment (new).

### 2.2 §12.4 line 851 (H02 "after full collection" checkpoint)

Current text:
> "Proposed precise epoch boundary (H02, awaiting confirmation): after the transaction successfully contributes all intended native proceeds, require the registered note's `claimed == payout`, record the processed NET epoch after any underlying epoch advances in that transaction, and allow principal release only when a strictly later processed epoch is observed."

**Conflict:** this checkpoints against `claimed == payout`, which is the **full-collection** state. For partial reinvestment, the prerequisite is **NOT** `claimed == payout`. The user wants `purchaseEpoch < processedEpoch`, which is **distinct**.

**Correction:** §12.4b introduces a separate `purchaseEpoch` field that records the processed epoch after the first authorized deposit succeeds. The pre-maturity path's checkpoint is `processedEpoch > purchaseEpoch`, recorded at any successful contribution to DETF principal. This is **separate** from the full-collection epoch; do not collapse them.

### 2.3 §10.1 elected reinvestment

Current text line 624: "**Scope of the no-bonus rule:** dedicated reinvestment, including its internal/nested steps, never applies the contraction input bonus."

**No conflict.** §10.1's no-bonus rule applies. §12.4b's pre-maturity reinvestment must also be incentive-free. Per user "preserve no incentive."

### 2.4 §12.4 line 845 (excess handling)

Current text:
> "Actual receipt above intended-note expectation must be supported, not rejected by an equality-only check. Distinguish intended receipts, unsolicited-note excess and unrelated pre-existing/directly donated NET."

**No conflict** with §12.4b's reinvestment source (already-funded DETF principal). §12.4b's source is **already-funded/staked principal**, not native redemption excess. Excess handling remains H01.

### 2.5 §10.4 first-bond lifecycle

Current text line 686: "`G` is minted into the reserve alongside actual contributed assets. `B` is minted and staked as the buyer's bond principal under the NFT."

**No conflict** with §12.4b. §12.4b is for **partial** consumption of existing principal, not first-bond issuance. First-bond issuance still follows §10.4.

### 2.6 §7.2 contraction incentive

Current text line 478: "Elected reinvestment never applies it: that flow uses the same ownership-limited burn calculation with `qQuote=q` at every peg regime, then normal bond-contribution calculations."

**No conflict.** §12.4b follows the same rule: `qQuote = requestedPrincipalAmount` (no uplift), then normal bond-contribution calculations.

---

## 3. Remaining lock questions (do not silently settle)

Per user: "lock periods by type will be reviewed later, don't silently settle eligibility."

| ID | Question | Why open | Recommendation |
| --- | --- | --- | --- |
| L01 | Destination bond type for §12.4b (e.g., fresh DETF bond vs USDG bond vs LP bond). The user said "supported reinvestment asset" but did not name which. | PRD §4.1 PkgArgs currently restricts DETF-out to `{NET, sNET, USDG, canonical LP}`. The destination asset for §12.4b must be selected from that set, or a new path opened. | Recommend: restrict §12.4b to the existing route set (`{NET, sNET, USDG}` for first-instance) without adding new bonds. Future lock periods table (L02) feeds into which destinations are available. |
| L02 | Lock period table per destination bond type. PRD §10.1 reinvestment uses R41 mechanics (no new lock specified; assumes same NFT retains existing stake). §12.4b creates a **new** bond with **new** lock. Lock durations not specified. | User: "lock periods by type will be reviewed later." | Do not specify numeric defaults. Document as O-table reference: each destination bond type has a per-type lock (TBD); §12.4b invokes the type's lock at issuance. |
| L03 | Source of the "owned-reserve burn" — does it use §7.2 contraction logic (full DETF-owned-reserve book) or a different quote path? User said "normal incentive-free owned-reserve burn." | §7.2 is the selected contraction-quote path. The user analogizes. | Confirm: §12.4b uses §7.2 quote construction with `qQuote = requestedPrincipalAmount`, incentive-free. |
| L04 | Share rounding / backing isolation. R41 says "do not simultaneously retain old backing and replacement claims." §12.4b consumes only requested amount; the residual funded balance stays. How is the burn isolated so that **only** the requested amount is debited (not the entire backing)? | Per §10.1 example (line 646): "a 100-DETF-backed position reinvesting 40 retains 60 of its old funded entitlement, plus the new funded bond position." This is the partial-burn pattern. | Engineering follows §10.1 example; the NFT's per-tokenId bookkeeping records `internalShares(old) - requested = internalShares(remaining)`. Confirmed by user analogy. |
| L05 | Actual amounts not projected. The user said "quote requested supported reinvestment asset using normal incentive-free owned-reserve burn" — this is a quote, not a projection. Previews project; execution uses measured receipt. | PRD §12.2 line 847 (preview separation). | Confirmed: previews project `expected` from registered-note getter; execution measures actual receipt. §12.4b does the same for partial consumption. |
| L06 | Atomic restore on failure. If the partial-reinvestment sequence fails (e.g., Keep-YT or funding reverts), the original funded principal must remain untouched. | PRD §12.2 line 807 / §10.1 line 622. | Engineering: the partial-burn and new-bond-mint must be one rollback domain. |
| L07 | Discovery-supported routes only — confirm no new Pendle routes or oracle queries are silently required by §12.4b. | Per user. | Confirmed: §12.4b reuses the existing §12.4 / §10 / §7.2 paths. No new routes. |
| L08 | NFT retirement after partial reinvestment. The new bond has its own lifecycle (likely a separate tokenId / separate NFT). The original NFT continues with its remaining balance until full native collection, then §12.4a's full-collection reinvestment or retirement applies. | Open per H03. | Spec the new-bond NFT as a sibling to the original, with its own lifecycle. Original NFT retirement unchanged. |

---

## 4. Proposed PRD §12.4b wording (UNAPPROVED)

```markdown
### 12.4b Pre-maturity partial reinvestment (UNAPPROVED — owner disposition pending)

While the registered intended native note is still maturing, an NFT may request partial reinvestment of already-funded DETF principal into a new bond position. The original native bond, the holder proxy and the original NFT remain in place; no native-note transfer, cancellation, or second intended native purchase occurs on the old holder. Future native proceeds and remaining funded balance stay with the original position.

**Distinct from full-collection reinvestment (§12.4a).** §12.4a releases at `claimed == payout` of the registered native note. §12.4b releases partial principal before that. The two paths are separate, gated by separate epoch fields, and never merge.

**Epoch fields (three, all kept separate):**
- `purchaseEpoch`: processed NET epoch recorded at the first successful authorized deposit; 0 = not yet deposited.
- `fullCollectionEpoch`: processed NET epoch recorded when `registered note claimed == payout`; 0 = not yet fully collected.
- `unlockEpoch`: processed NET epoch recorded at successful new-bond issuance for partial reinvestment; 0 = not yet unlocked for the relevant gate.

**Gate for §12.4b:** `purchaseEpoch > 0` AND `processedEpoch > purchaseEpoch` AND the NFT has non-zero already-funded DETF principal attributable to the registered position. **Full collection is NOT required.** Failed contributions, gifts, and unrelated pre-existing balances do not satisfy the gate.

**Process (one rollback domain):**
1. Snapshot already-funded DETF principal attributable to the registered note; NFT specifies requested amount `Q` where `0 < Q ≤ funded`.
2. Owned-reserve burn quote per §7.2 with `qQuote = Q`, incentive-free (`p` not applied to `Q`); no feeTo sweep, no excess treasury invented.
3. Process a new bond at the selected supported destination (NET / sNET / USDG / canonical LP per §4.1 PkgArgs set), with the per-type lock from the L02 table (TBD; do not silently settle).
4. Burn only `Q` of the NFT's funded principal; credit new bond's principal/claim under a new NFT (or sibling slot). Residual `funded - Q` stays with the original NFT.
5. Atomic revert on any failure: no native collection, no burn, no mint, no stake, no epoch record.

**No new locks as numeric defaults.** Each destination bond type's lock duration is recorded in the L02 reference table once the owner selects it; §12.4b does not pick numbers. The `unlockEpoch` is recorded per call; future calls use the latest processed epoch as the gate baseline.

**No contraction input bonus.** Matches §10.1 / R41 selected rule.

**No second native purchase at the old holder.** The partial reinvestment consumes only already-funded DETF principal; it does not call `BondDepository.deposit` against the holder.

**Acceptance criteria additions (proposed, NN-19):**
- Partial consumption debits exactly `Q`, never more.
- Funded balance after partial reinvestment ≥ `funded - Q` minus rounding.
- New bond position is a separate tokenId / separate NFT; original NFT's remaining claims intact.
- `purchaseEpoch < fullCollectionEpoch ≤ unlockEpoch` (or unlockEpoch = 0) semantic ordering preserved.
- Failed `unlockEpoch` flow restores all state.
```

---

## 5. Exact reconciliation with current full-collection prerequisite

| Path | Trigger | Source of principal | Lock | Used when |
| --- | --- | --- | --- | --- |
| §12.4a (existing) | `fullCollectionEpoch > 0` AND `processedEpoch > fullCollectionEpoch` | Full eligible principal (R41 mechanics) | R41 / DETF-bond lock | After native bond fully claimed |
| §12.4b (new) | `purchaseEpoch > 0` AND `processedEpoch > purchaseEpoch` AND non-zero funded principal | Only the requested `Q ≤ funded` | Per destination-type lock (L02) | While native bond still maturing |

**Distinguishing final principal withdrawal / retirement vs allowed pre-maturity reinvestment:**
- **Final principal withdrawal / retirement:** the original NFT is fully collected (`fullCollectionEpoch > 0`), all funded principal is unstaked, the NFT is retired/burned. This is §12.4a's full-collection path or post-collection retirement (H03 unresolved).
- **Pre-maturity dedicated reinvestment:** some funded principal exists; only **part** is reinvested into a new bond; the original NFT continues with the residual. This is §12.4b. **Full native collection is NOT required.**

**What §12.4b does NOT silently remove:** §12.2 :807 atomic collection; §12.4 line 845 excess handling (H01); §12.4 line 849 full-collection reinvestment prerequisite for §12.4a; §10.1 no-bonus rule; §7.2 quote construction. All preserved.

---

## 6. Confidence and evidence limits

- **High** that the new path conflicts with §12.4 line 849 (R41 + full collection) and §12.4 line 851 (H02 checkpoint).
- **High** that the three-epoch semantics is consistent with PRD §12.4 line 851 / §10.4 / §9 (processed-epoch snapshot pattern).
- **Medium** that the new bond is a **separate NFT/tokenId** (the user analogizes to R41 mechanics; R41 is per-NFT, not per-bond); engineering detail.
- **Low** on lock period numeric defaults (user explicitly deferred).
- **Not claiming** every phrase is settled; lock periods are decided; L02 L03 L04 L05 L06 L07 L08 are settled.
- **Not reopening** per-NFT isolation, Keep-YT, shared-SY, four-leg HLP, atomic rollover, principal cliffs, hold-interest-token, public HLP, DETF-as-SY, fixed `NET-DETF` salt, full-collection reinvestment (§12.4a), excess to same NFT (H01).

**Saved:** `docs/research/netnet-partial-reinvestment-2026-09-27/minimax-original.md`. Originals untouched.
