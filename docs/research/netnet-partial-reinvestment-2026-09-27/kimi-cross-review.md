# Kimi K3 — Pre-maturity reinvestment CROSS-REVIEW (Astra / Grok / MiniMax M3)

| Field | Value |
| --- | --- |
| Author | Kimi K3 (`kimi-code-plan-global/k3`) — routing metadata only |
| Date | 2026-09-27 |
| Basis | Full reads of the three originals (untrusted evidence); my unchanged original; moderator corrections treated as authority. |

## 1. Corrections to my original (moderator-directed)

- **C1 — unlock-epoch 0 semantics.** I wrote "0 = unset sentinel." Correct per user: **0 = assigned Pendle market maturity** (a release-at-Pendle-maturity marker) — NOT unset, pending, or unlocked. Astra (:31) and Grok (:53) had this right; MiniMax (:100 "not yet unlocked") is wrong alongside me. No invented `purchaseEpoch > 0` sentinel semantics either.
- **C2 — my L4 withdrawn.** "Is excess-funded principal reinvestable pre-maturity?" is answered by the settled excess destination: excess is same-NFT principal, therefore funded principal like any other. Only late-excess timing and direct-donation classification remain open (Astra :17).
- **C3 — share-unit discipline added.** "Burn requested q" must retire the position's **corresponding internal shares via the current backing/share rate**; internal share units ≠ raw DETF principal. Astra (:39–43) states this correctly; my "A29 participant-only debit" was incomplete without the conversion note.

## 2. Corrections to peers (attributed)

- **C4 (MiniMax, gate invention — rejected):** his §12.4b gate (:102) settles `purchaseEpoch > 0 AND processedEpoch > purchaseEpoch` as THE eligibility condition, with invented sentinel table (:98–100) and cadence semantics ("future calls use the latest processed epoch as the gate baseline," :111). The user expressly retained the purchase-epoch check as **distinct** but deferred its exact predicate and all lock/cadence questions ("don't silently settle eligibility"). Astra (:35: "do not claim purchase-epoch passage alone settles every eligibility condition") and Grok (Q2 :74) hold the correct deferral posture.
- **C5 (MiniMax L01/:107 — PkgArgs misuse):** "restrict §12.4b to the §4.1 PkgArgs set ({NET, sNET, USDG, canonical LP})" — PkgArgs supplies three dependency addresses (market, depository, staking), not an asset allowlist. Supported reinvestment assets come from the selected route semantics (R22/§7.4), not PkgArgs.
- **C6 (MiniMax §12.4a framing):** the full-collection gate governs **final principal withdrawal/retirement**, not a separate "full-collection reinvestment path" (:131). Post-collection, remaining principal is released under the final-release rule (recorded separately, subject to the upcoming lock review) — Grok's A/B split (:42–45) and Astra's framing (:9–19) are the accurate ones.
- **C7 (MiniMax :75 — unnecessary upstream scan):** previewing via `pendingFor` reintroduces the all-note scan; the reinvestment path needs **no native call at all** — it consumes already-funded DETF principal. Registered-note getter reads suffice for the claim path; the reinvestment path touches only DETF-side state. Per moderator: don't require an unnecessary native redeem, and don't promise immunity from other dependency-sync failures (expansion/reward checkpoints can still revert the compose — failure restores state, per all four).

## 3. Four-way consensus (after corrections)

- v0.25 over-gates reinvestment with the full-collection prerequisite; the same edit set needs scoping (:25, R19 :165, §10 :610, §12.2 :797, §12.4 :849, O03 :885, A08 :932, tracker rows). Astra's list and mine match nearly verbatim.
- Split: **(A) pre-maturity dedicated reinvestment** of requested already-funded principal — no `claimed == payout` requirement, no future-vest consumption, no holder movement; **(B) final withdrawal/retirement** — full-collection + next-processed-epoch gate retained, subject to upcoming lock review.
- Full currently funded amount may leave the old NFT while future native claims remain; **zero current principal alone never retires** the old NFT (Grok Q3, Astra :9).
- New bond = **new tokenId**, destination type's normal lock (numbers deferred); R41 incentive-free burn (`quoteInput = actualDetfIn`); atomic restore; actual not projected amounts; discovery-supported routes only; early funded rewards unchanged.
- Epoch fields: `purchaseEpoch` / `fullCollectionEpoch` / `unlockEpoch` distinct; `unlockEpoch == 0` = assigned Pendle maturity; epoch snapshots vs unlock target are distinct concepts; actual storage layout is engineering work (Astra :25–33; `IStaking.sol:27–35` exposes the processed counter).

## 4. Concrete correct amendment (merged UNAPPROVED wording)

> **Pre-maturity dedicated reinvestment (selected).** While the registered intended native note is still maturing, the tokenId's authorized holder may reinvest requested amounts of principal already funded by successfully collected and contributed installments. The operation debits the old position's corresponding internal shares at the current backing/share rate and burns exactly the requested actual funded principal; quotes the requested supported reinvestment asset through the incentive-free owned-reserve burn (`quoteInput = actualDetfIn`, no contraction bonus at any step); and funds a **new bond under a new tokenId with that destination bond type's normal lock**. It requires **no** native-note collection, transfer, cancellation or second intended purchase at the old holder. The old NFT retains remaining funded principal, funded rewards and all future native proceeds; zero current principal alone does not retire it. Final principal withdrawal and retirement remain gated by full collection of the intended note plus the next processed NET epoch, recorded separately and subject to the announced per-type lock review. The purchase-epoch check remains distinct from the full-collection checkpoint; its exact predicate, per-type lock durations and any cadence are deferred to that review — none are settled here. `purchaseEpoch`, `fullCollectionEpoch` and `unlockEpoch` are distinct semantic fields; `unlockEpoch == 0` denotes assigned Pendle maturity. Amounts are actual funded balances, never projections; any failure restores the old position, burn, quotes and markers atomically.

## 5. Accepted vs deferred scope

**Accepted (settled by user):** the (A) path exists; its mechanics (R41 burn, new bond, old-position retention); excess = same-NFT principal; three epoch fields with the corrected 0-sentinel; purchase-epoch check retained-but-distinct. **Deferred (per user):** exact eligibility predicate, per-type lock durations, cadence/repeat rules, L5-style rounding proof obligations (engineering), late-excess timing and direct-donation edges (H01 residue), retirement terminal handling (H03 residue).

## 6. Dissent record

MiniMax's settled-gate/sentinel formalization vs the other three's deferral — resolved by user instruction (defer). MiniMax's unlockEpoch sentinel — resolved by user correction. No remaining substantive dissent.

## 7. Limits

PRD lines cited from direct v0.25 reads; peer claims untrusted; no execution; no external lookups required; originals unchanged. No new round initiated.
