# MiniMax M3 — NN-02 External-Note Liveness (Bounded Round)

> **Scope:** explain NN-02 (PRD_OPEN_QUESTIONS.md lines 78–82) in plain English; source-grounded evaluation of wrapper-only designs. Read CLAUDE.md, PRD §§12, 14 / C08, tracker NN-02, `lib/crane/contracts/protocols/pol/net/src/BondDepository.sol` (full, 200 lines), `IBondDepository.sol` (full, 55 lines), `Constants.sol` (full, 80 lines). Research-only; no shell/RPC/tests/code/config/delegation. Routing metadata `minimax/MiniMax-M3` only (not provider attestation). Date 2026-09-27.

---

## 1. Plain English — what NN-02 actually is

The DETF wants to let users buy a NetNet **external bond** with proceeds from a DETF-out swap or eligible contraction. NetNet bonds live on a separate contract (`BondDepository 0xff32…1980C1` per PRD §4.1). The DETF wraps each position in an NFT; the NFT owns the right to collect vested NET and reinvest it. **NN-02 is the question: how does the wrapper deal with the upstream depository's interface, which lets anyone append notes to any address and offers no per-note selector?**

Two facts from the source make this hard:

1. **`BondDepository.deposit(marketId, amount, maxPriceWad, address to)`** (lines 104–140) accepts an arbitrary `to` parameter. Anyone can deposit on behalf of any address. The wrapper cannot refuse to receive a note.
2. **`BondDepository.redeem(address to)`** (lines 143–153) loops over **every** entry in `notes[msg.sender]` (line 144: `Note[] storage userNotes = notes[msg.sender]; for (uint256 i = 0; i < userNotes.length; i++)`). Same for `pendingFor(address)` (lines 156–166). No pagination, no per-note selector, no transfer selector (verified in `IBondDepository.sol` lines 11–54 — only `deposit`, `redeem`, `bondPrice`, `pendingFor`, `noteCount`, `marketCount`, `quoteToken`, `enabled`, `enable`).

**Settled**: PRD §12.1 line 786 — "Notes are address-indexed and non-NFT; no native per-note redeem or transfer selector was established." The user's brief premise is correct.

---

## 2. Source-grounded facts (verified)

| Source | Evidence |
| --- | --- |
| `BondDepository.sol:25–54` | Two markets (0=USDG, 1=NET/USDG V2 LP). `Note{payout, claimed, start, end}`. `mapping(address => Note[]) public notes` |
| `BondDepository.sol:104–140` | `deposit` accepts arbitrary `to`; appends `notes[to].push(...)`; no recipient whitelist, no rate limit, no note cap |
| `BondDepository.sol:143–153` | `redeem(to)` loops all `notes[msg.sender]`. Line 147: `if (claimable == 0) continue;` — skips already-claimed note body but the loop still walks every note |
| `BondDepository.sol:156–166` | `pendingFor(account)` loops all notes (no skip); returns `(totalPending, claimableNow)` |
| `BondDepository.sol:168–170` | `noteCount(account)` view exists |
| `BondDepository.sol:191–199` | `_claimable(Note)` returns linear vested-minus-claimed; after `end`, returns `payout - claimed` |
| `BondDepository.sol:183–189` | `_checkEpochCap` uses `Constants.BOND_EPOCH_CAP_BPS = 25` (0.25% of NET totalSupply per 8-hour epoch). Caps NET **payout**, not note count |
| `Constants.sol:17` | `EPOCH_LENGTH = 8 hours` |
| `Constants.sol:76` | `BOND_VEST = 2 days` (code). Interface line 6 still says "5-day linear vesting (DEFAULT — TUNE BEFORE DEPLOY)" — the PRD §12.1 prose-vs-code discrepancy |
| `IBondDepository.sol:11–54` | No `redeemNote(uint256)`, no `transferNote(uint256,address)`, no `burnNote(uint256)`, no cap on `notes[address].length` |

---

## 3. What "liveness" actually requires (re-stated for clarity)

The wrapper must do three things in normal operation: (a) own a small, predictable number of upstream notes; (b) iterate the upstream note array when claiming/reinvesting; (c) accept that a third party can append notes to the wrapper's upstream address, growing the wrapper's note count without consent.

(a) and (b) are the wrapper's own choice (its voluntary purchases + its own redemption timing). (c) is the unsolved part: it converts a chosen acquisition policy into an unbounded iteration cost, because `redeem` walks every note owned by `msg.sender`.

**Distinguishing absolute non-boundedness from practical feasibility:** the loop bound `notes[msg.sender].length` grows by 1 per upstream `deposit(..., msg.sender)` call. There is no upstream rate-limit, no per-address cap, no per-note selector that would let the wrapper skip arbitrary entries. **Mathematically, the loop cost is unbounded in adversarial growth** unless either (i) upstream changes its interface, or (ii) the wrapper restricts who can call its voluntary acquisition path AND immediately sweeps any gifted notes to a sink. **A wrapper-only design cannot bind the loop to O(1) without an upstream per-note selector.**

---

## 4. Wrapper-only design options — evaluation

**(A) Per-position escrow / precomputed addresses.** The upstream `BondDepository` is a singleton (`0xff32…1980C1`). Wrapper cannot precompute multiple upstream escrows. **Not feasible wrapper-only.**

**(B) Batching / aggregate-redeem.** Wrapper batches across many NFTs in a single upstream `redeem`. **Does not help loop bound** — the wrapper already owns a single `msg.sender` upstream; batching across wrappers requires a separate singleton aggregator, which is a wrapper, not an upstream change. **Helper, not a bound.**

**(C) Local caps.** Wrapper enforces `MAX_NOTES_PER_POSITION` and refuses voluntary purchases above N. **Bounds wrapper's own acquisition.** Does NOT bound attacker-injected notes via `deposit(..., wrapper)`. **Partial.**

**(D) Frequent claiming.** Wrapper calls `redeem` after every block/deposit to keep the unclaimed/claimed ratio low. Line 147 skips fully-claimed note **bodies**, but the **loop still walks every index**. Storage still grows. **Does not reduce loop iterations.**

**(E) Voluntary note gifting refusal.** Wrapper cannot reject upstream `deposit(..., wrapper)` (any `to` is accepted). Can refuse to harvest gifted notes' yield. **Cannot refuse the note itself.**

**(F) Min-payout / cap assumptions.** `BOND_EPOCH_CAP_BPS = 25` caps NET payout, not note count. A dust deposit (minimum-amount avoiding `ZeroAmount` at line 109) still appends one note per call. **Does not bound note count growth.**

**(G) Wrapper-side sweep-to-sink.** Wrapper treats any received note as unowned: calls `redeem(to=feeSink)` for any unexpected (gifted) note, never reinvests gifts. **Bounded by what the wrapper voluntarily accepts.** Still requires iterating the entire note array to redeem anything. **Bounds *yield* but not *loop iterations*.**

**Honest summary:** without an upstream per-note selector, the wrapper can bound **its own purchase count** and can bound **the yield it accepts from gifts** by sweeping them to a sink. It cannot bound the **loop iterations of `redeem` / `pendingFor`**, which grow linearly with the cumulative count of `deposit(..., wrapper)` calls an attacker is willing to pay gas for. The cost per attacker call is the upstream `deposit` gas (mint, push, two transfers, TWAP read, cap check). On Robinhood Chain at standard gas prices this is on the order of a few hundred thousand gas per attacker note — not free, but not prohibitive at scale.

---

## 5. Distinguishing absolute non-boundedness from quantified feasibility

Per the user's brief: "don't invent recovery API or conclude mathematical impossibility beyond evidence."

**What the evidence supports:**
- **No upper bound** on `notes[address].length` growth via `deposit`. The interface has no cap, no whitelist, no pause, no per-note selector.
- **No upper bound** on loop iterations of `redeem` / `pendingFor` for a given address, given arbitrary `deposit` calls.
- **The wrapper's own yield exposure** is bounded by what it voluntarily acquires + any gifts it does not sweep; this is **practically controllable** by wrapper-side caps (C) and sweep-to-sink (G).

**What the evidence does NOT support:**
- A claim of mathematical impossibility. The attacker's cost is gas per `deposit` call; an economically rational attacker has a per-call cost ceiling.
- A claim of safe-enough-as-is. The cost-per-attacker-note analysis is missing from PRD §12.3 and §14.1 C08; the council flagged this as engineering work, not as an owner decision.

**The honest framing:** NN-02 is not "impossible" but "not closed without either (i) an upstream interface change, (ii) an explicit owner-approved economic assumption (e.g., attacker gas cost >= lost-yield-per-note, plus the wrapper sweeps gifts), or (iii) a wrapper design that treats gifts as instant-sweep + caps voluntary acquisitions, with quantified gas bounds."

---

## 6. Conditional design proposals (not owner decisions)

**(P1) Wrapper caps voluntary purchases + sweeps gifts.** Wrapper contract enforces `MAX_VOLUNTARY_NOTES` (e.g., 50). Beyond N, wrapper refuses `deposit` calls. Wrapper `harvest` function checks `noteCount(wrapper)`; if > MAX, calls `redeem(to=feeSink)` on excess to keep the loop bounded within an economic window. **This bounds yield exposure but not loop bound.** Requires quantified cost-of-attack vs cost-of-sweep table.

**(P2) Wrapper-side per-note redemption pattern.** Since the upstream `redeem` is monolithic, the wrapper **must** accept the full iteration cost on every claim. The wrapper can call `redeem` only when it has actual reinvestment work to do, bounding the **frequency** of iteration. The loop **length** still grows with cumulative note count. **Practical mitigation.**

**(P3) Owner-approved scope.** Document in PRD §12.3 that the external-bond feature operates under an **explicit owner-stated cost model** (e.g., "attacker spam cost > 1% of totalSupply per epoch in attacker gas; wrapper sweep absorbs the rest"). This is **not** a calculation but an owner attestation. The tracker closure criterion (line 82) accepts "owner-approved scope resolution."

**(P4) Upstream interface change (out of wrapper scope).** A native `redeemNote(uint256 noteId)` selector or `redeemUpTo(uint256 maxNotes)` or per-address note cap would close NN-02 properly. **Requires NetNet team action; not in scope of this wrapper.**

**Recommended path:** (P1) + (P2) + (P3) jointly close NN-02 if the owner accepts the economic attestation. (P4) is preferred but is upstream.

---

## 7. Narrow human checkpoint

**Question:** Is "wrapper caps voluntary purchases + sweeps gifts + owner-attested economic cost model" an acceptable closure for NN-02, **without** a per-note upstream selector? This is not a request to redesign the upstream; it is a request to confirm the selected wrapper pattern treats gifts as instant-sweep and accepts the resulting gas-bound as a documented owner assumption.

---

## 8. Optional UNAPPROVED PRD clause

```markdown
### 12.4 External-note liveness closure (NN-02 — UNAPPROVED)

The DETF external-note wrapper binds its own acquisition to MAX_VOLUNTARY_NOTES (configuration parameter) and treats unsolicited gifted notes as instant-sweep to the current feeTo via BondDepository.redeem, never reinvesting gifts. Voluntary note count N satisfies N ≤ MAX_VOLUNTARY_NOTES at all times the wrapper acquires notes. The owner attests an economic cost model: per-attacker-note gas cost exceeds the wrapper's per-iteration redeem cost by a factor accepted as economically safe (parameter; recorded in implementation plan; not derived from this PRD). The wrapper does not call redeem() on a loop whose length exceeds a separate configuration cap (MAX_REDEEM_NOTES, recorded in implementation plan; resets on sweep). This wrapper pattern is the selected design; it is NOT an upstream change and does not modify BondDepository. Pending NN-01 live verification of the canonical BondDepository address and BOND_VEST value.
```

---

## 9. Confidence and evidence limits

- **High** on the interface facts (BondDepository.sol:25–200, IBondDepository.sol:11–54, Constants.sol:1–80 all read directly).
- **High** that no upstream per-note selector exists in the current source.
- **Medium** on the attacker cost model — gas costs are chain- and time-dependent; not measured here.
- **Low** on whether the deployed `BondDepository 0xff32…1980C1` matches the local source snapshot (pending NN-01 verification).
- **Not claiming**: mathematical impossibility; safe-enough-as-is; that a wrapper-only design closes NN-02 without owner attestation.
- **Not asserting**: any per-note selector exists in an interface not yet inspected.
- **Not reopening**: any settled owner decision. Scoped custom-family approval, Keep-YT ingress, shared-SY egress, four-leg HLP, atomic rollover, principal cliffs, native-wrapper exception, hold-interest-token, public HLP, DETF-as-SY, fixed `NET-DETF` salt.

**Saved:** `docs/research/netnet-nn02-2026-09-27/minimax-original.md`. PRD **not** modified.
