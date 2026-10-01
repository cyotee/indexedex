# MiniMax M3 — NN-02 Cross-Review (Bounded Round)

> Cross-review of three peer originals for NN-02 (external-note liveness). Read together; no peer cross-review artifacts consulted. My `minimax-original.md` is the baseline. Research-only; routing metadata `minimax/MiniMax-M3` only (not provider attestation). Date 2026-09-27.

---

## 1. Convergence (all four agree on the source facts)

1. **Arbitrary-recipient appends:** `BondDepository.deposit(marketId, amount, maxPriceWad, to)` (lines 104–140) accepts any `to`. No whitelist, no callback, no opt-out, no recipient check.
2. **All-note scan, no pruning:** `redeem(to)` (`:143–153`) loops every `notes[msg.sender]`. Line 147 `if (claimable == 0) continue;` skips the **body** of fully-claimed/zero notes; the **loop length** is unchanged. No pruning of visited entries.
3. **`pendingFor` also scans all notes** (`:156–166`). View label does not bound computation.
4. **No per-note API:** `IBondDepository.sol:11–54` exposes only `deposit`, `redeem`, `bondPrice`, `pendingFor`, `noteCount`, `marketCount`, `quoteToken`, `enabled`, `enable`. No `redeemNote(uint256)`, no range/batch redeem, no transfer selector.
5. **Vest 2d vs 5d discrepancy** (`Constants.sol:76` BOND_VEST=2 days vs `IBondDepository.sol:5` "5-day") is NN-01 evidence, not NN-02.
6. **No wrapper-only design enforces a gas bound.** Wrapper can isolate per-position history and bound **its own attribution work**; it cannot bound **upstream `redeem` cost** against attacker-injected + cumulative history.
7. **NN-01 LIVE checks still open.** Constants edit (PENDLE/NetNet additions) does not close NN-01 deployed-equivalence.

---

## 2. Attributed corrections to my original

### 2.1 P1 "instant-sweep to feeTo" introduces an owner-unselected destination — **RETRACT**

My original §6 (P1) said "sweep unsolicited notes via `redeem(to=feeSink)` to current feeTo." **The prompt is right: `feeTo` is not the owner-selected destination for unsolicited note proceeds.** Sweeping gift proceeds to feeTo is **not** the same forwarding rule as PRD §13 reward forwarding — those are Pendle market rewards routed to the oracle's `feeTo()`, not NetNet note payouts from a separate upstream contract. PRD §12.3 line 811 explicitly forbids "labeling 'escrow' [or a sweep] as a solution." My P1 invented a sweep destination without owner attestation.

**Correct framing (Kimi):** "donation treatment of unsolicited value" with **provenance only** — the wrapper recognizes the unsolicited note exists and treats its eventual payout as wrapper-level accounting, but the **destination of any swept value is a separate owner decision**, not a wrapper-side invention.

### 2.2 Nonzero vs zero-payout gifting — **Kimi's reframe is sharper than mine**

My original said "bounds yield exposure" generically. **Kimi's distinction is decisive:**
- **Nonzero-payout notes** are economically **irrational** to spam: payer transfers USDG/LP to Treasury (lines 116, 121), mints NET to note recipient (`:129`). Attacker donates real value. **Spam cost > 0 implies attacker prefers not to spam.**
- **Zero/dust-payout notes** are the actual attack vector: `payout = mulDiv(valueWad, NET_UNIT, price)` (`:126`) can round to ~0 with positive payment; `_checkEpochCap` (`:183–189`) caps payout value, not note count (25 bps × totalSupply × 8-hour epochs). An attacker can craft dust-payment notes that consume near-zero capacity but still append one entry per call.

**Adopting Kimi's reframe:** the bound on attacker-injected notes is bounded by **attacker-paid tx + small positive payment**, not by NET donation. My original treated all attacker appends as "yield exposure to be bounded"; Kimi's framing correctly identifies that **only zero-payout dust is the real residual risk**.

### 2.3 Gas/storage numbers — **placeholders, not measurements**

I wrote "a few hundred thousand gas per attacker note" — **this is an unverified placeholder**. Per the prompt, "gas estimates, storage-slot counts, per-note costs or N* actually established" — none of us measured. Kimi similarly wrote "a few hundred warm gas; `Note` spans 3 slots" — the `Note` struct actually has **4 fields** (`payout` uint256, `claimed` uint256, `start` uint64, `end` uint64); each uint256 is 1 slot, so Note spans **4 storage slots**, not 3. Minor correction. **No N*, no measured gas-per-iteration, no measured min-deposit economics — Kimi is right that this is NN-18/NN-19 work, not NN-02 closure evidence.**

### 2.4 `redeem` does NOT selectively sweep or prune — **confirming the prompt's challenge**

Source: line 147 `if (claimable == 0) continue;` skips the body but walks every index. **There is no array reset, no prune, no selective excess sweep.** A position's note count grows monotonically; only `claimed` increments per-note. Grok's note: "if LIVE bytecode **differs** [prunes on full claim], NN-01 must record it." Until then, plan as full-array walk, append-only.

### 2.5 Forced binary choice — **Astra's framing is more honest**

I framed P1+P2+P3 as a path forward. **Astra's checkpoint (§4) is sharper: "should the specification author first quantify option A's residual risk, with NN-02 remaining open, or require bounded upstream redemption before this external-note feature may proceed?"** This is a binary owner choice, not an executable proposal. My P1+P2+P3 closure framing is **too ready** given that the attacker-cost model is unmeasured.

---

## 3. Genuine dissent (on framing, not source)

- **Astra** (strictest): no wrapper-only design bounds the work; only isolates. Residual-risk design needs explicit owner attestation. Recommends deferred descope if owner rejects.
- **Grok** (had `RC_UNAVAILABLE` tool failure on BondDepository source; used PRD-documented ABI): same conclusion as Kimi; refuses to claim "attack costs money" is closure.
- **Kimi** (sharpest reframe): nonzero-payout spam is irrational; zero-payout dust is the attack; wrapper-side bookkeeping (purchase-time index recording) bounds O(own purchases); quantified envelope for upstream `redeem`; owner attestation required.
- **Me**: same conclusion on the source; **introduced unsanctioned feeTo sweep in P1** (now retracted per §2.1); **incomplete on nonzero/zero-payout distinction** (now adopted from Kimi); **placeholders dressed as estimates**.

---

## 4. Where my original is correct

- Source facts table (BondDepository.sol:25–200, IBondDepository.sol:11–54, Constants.sol:1–80).
- "No per-note selector" finding.
- "No wrapper-only design enforces a gas bound" finding.
- `redeem` and `pendingFor` loop all notes, no skip — confirmed.
- "Frequent claiming bounds frequency not length" — confirmed by all.
- "Wrapper-side bookkeeping can be O(own purchases)" — confirmed by Kimi's purchase-time index recording observation.
- "No invented recovery API" finding.
- "Attacker-injected notes bounded by attacker's gas + positive-payment budget, not mathematical impossibility" — confirmed.
- Constants edit ≠ NN-01 LIVE close — confirmed by all four.

---

## 5. Recommended next human checkpoint

Adopting Kimi's framing with my retraction:

> **Given that upstream `BondDepository` accepts arbitrary `to` and `redeem` walks the entire note array including attacker-injected and cumulative history (no per-note, batch, prune or minimum-payout selector in the inspected source), should NN-02 close by (A) wrapper-side bookkeeping bounded to O(own purchases) via purchase-time index recording plus quantified attacker-cost envelope with owner attestation of residual stranding risk, or (B) descoping the external-bond wrapper until upstream offers a bounded claim selector, or (C) keeping the route and explicitly accepting O(n) redeem + harvest OOG as a documented owner-approved residual (which the prompt forbids as "automatic scope/risk acceptance without investigation")?**
>
> Not asked: family re-approval, inventing `redeem(noteId)`, closing NN-01, setting `feeTo` as the destination of unsolicited note proceeds (this is **not** owner-selected; a separate decision).

---

## 6. Optional UNAPPROVED PRD clause (corrected)

```markdown
### 12.4 NN-02 external-note liveness closure (UNAPPROVED)

The upstream note array is append-only for arbitrary recipients (`BondDepository.sol:54,104–140`); `redeem(to)` (`:143–153`) walks every entry of `notes[msg.sender]` including fully claimed and zero-payout notes (line 147 skips the body, not the index). No per-note, batch, minimum-payout or pruning mechanism exists in the inspected source. The wrapper bounds its own attribution and valuation work to O(own purchases) via purchase-time note-index recording (storing `noteId` returned by `deposit`) plus the public per-note getter; it recognizes unsolicited note value as donations to wrapper-level accounting and does NOT pre-commit a sweep destination. Nonzero-payout spam is economically self-defeating (donates NET to the holder); zero-payout dust spam is the residual attack surface. The upstream scan itself is unbounded by design; the wrapper operates under a quantified envelope: an analytically derived and later measured maximum note count N* (NN-18), `noteCount` monitoring at every claim, claim cadence that extracts value while N ≪ N*, and a pre-terminal headroom check. The residual risk of a financed attacker stranding unclaimed value by exhausting N* requires explicit owner acceptance as the basis of this feature, or the feature is deferred. No hypothetical upstream selector is assumed; sweep destination for any unsolicited value is a separate owner decision.
```

---

## 7. Confidence and evidence limits

- **High** on source facts (all four peers read BondDepository.sol, IBondDepository.sol, Constants.sol).
- **High** that no per-note selector exists in the inspected source.
- **Medium** on the nonzero/zero-payout distinction (Kimi's analysis is sound; not measured live).
- **Low** on gas/storage numbers (no measurement; placeholders only).
- **Low** on whether deployed code prunes/sweeps — pending NN-01 LIVE verification.
- **Not claiming**: mathematical impossibility; wrapper closes NN-02 without owner attestation; "attack costs money" is closure; sweep to feeTo is owner-selected.
- **Not reopening**: any settled owner decision.

**Saved:** `docs/research/netnet-nn02-2026-09-27/minimax-cross-review.md`. Original `minimax-original.md` untouched.
