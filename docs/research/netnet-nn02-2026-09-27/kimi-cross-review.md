# Kimi K3 — NN-02 CROSS-REVIEW (Astra / Grok / MiniMax M3 originals)

| Field | Value |
| --- | --- |
| Author | Kimi K3 (`kimi-code-plan-global/k3`) — routing metadata only |
| Date | 2026-09-27 |
| Basis | Full reads of the three NN-02 originals (untrusted evidence); my unchanged original. No peer cross-reviews. |

## 1. Four-way consensus (verified, high confidence)

All four agree on the source facts: arbitrary-`to` appends (`BondDepository.sol:104–140`); append-only array with **no pruning, no length reset, no selective sweep** — `redeem` (:143–153) visits every note, skips zero-claimable only *after* visiting (:147); `pendingFor` scans all (:156–166); epoch cap bounds payout *value* (25 bps, `Constants.sol:79`), never count; no per-note/batch/transfer selector in `IBondDepository.sol`; local 2-day vs interface-prose 5-day vesting unresolved (`Constants.sol:76` vs `IBondDepository.sol:5`); constants edit ≠ NN-01 live close. All four agree **no wrapper-only mechanism enforces a gas bound on the upstream scan** (Astra: "narrower than a mathematical impossibility theorem"; Grok: "no enforceable gas bound… not a theorem"; MiniMax: "cannot bind the loop to O(1)"; me: attribution bound yes, scan bound no). Escrows, caps, cadence, batching are mitigations, not bounds. Nobody may invent an upstream selector.

## 2. Source-inconsistent peer proposals (rejected)

- **R1 (MiniMax G/P1/clause — the biggest error): "sweep-to-sink" / "redeem(to=feeSink) on excess" / "resets on sweep."** Source-inconsistent on three counts. (a) `redeem(to)` is **not selective**: it pays *everything vested* — including the wrapper's own registered notes — to `to`; there is no "excess-only" sweep. Sweeping gifts to a sink donates the wrapper's own vested yield too. (b) Nothing "resets": the array is append-only; a sweep changes `claimed`, never length, so the loop bound is untouched — MiniMax's own §4(D) says this, contradicting its P1/clause. (c) The `feeTo` destination is not owner-selected for native-note proceeds (§13's feeTo rule covers Pendle reward tokens, not unsolicited native-note value). Rejected.
- **R2 (MiniMax A): "wrapper cannot precompute multiple upstream escrows — upstream is a singleton."** Misreads the design: per-position escrows are *wrapper-side* contracts, each a distinct `to` at the one depository; nobody proposed multiple upstream contracts. Astra/Grok/I have this right.
- **R3 (MiniMax P3 + checkpoint): "owner-attested economic cost model… not derived from this PRD… recorded in implementation plan."** This asks the owner to *attest* the critical quantity (attacker cost vs iteration cost) in place of measuring it. That is attestation-as-substitute-for-evidence — the exact "accept risk without investigation" the brief forbids. Rejected as a closure basis; the cost model must be *derived and measured first*, then accepted or rejected.
- **R4 (Grok's binary checkpoint):** "descope **or** accept O(n) residual" forces the choice before the quantification exists. Astra's sequencing is correct: commission the measurement, keep NN-02 open, decide after. Grok's own text supports this ("without LIVE min amount and gas-per-iteration, do not treat 'bonds cost money' as closure") — the binary framing contradicts his own caveat.

## 3. Corrections to my own original (attributed)

- **C1 (Astra): "economically irrational" overstrong.** Nonzero-value spam donates principal (self-defeating for a *profit* motive), but the operative attack is dust: near-zero donation, gas-only cost, and Astra correctly notes zero-payout feasibility is itself conditional (payout floors when numerator < price, :126; LP valuation rounding :174–180; oracle/wiring validity — peer-cited `Treasury.sol`/`NET.sol` zero-mint behavior not independently verified by me). Reframe: value-spam is self-taxed; dust-spam is cheap; neither establishes safety or unsafety without measurement.
- **C2 (Astra): cadence guarantees nothing terminal.** My "extracts value while N ≪ N*" must not read as completion assurance: accumulated spam, delayed holders and indefinite inactivity can defeat any cadence; the terminal redeem remains O(N). Mitigation, not guarantee — stated.
- **C3 (all three): my gas figures were illustrative, not established.** "700 gas/note, ~37.5k notes to 30M gas" and MiniMax's "few hundred thousand gas per attacker note" are both unmeasured. Established layout fact only: `Note{payout, claimed, start, end}` packs to 3 slots/element (:35–40). N* is an analytic target for NN-18 measurement, not a number I have.
- **C4 (Astra, gift attribution precision):** my "donation treatment with provenance" was glib. `redeem` returns one **aggregate** `paid`; unsolicited proceeds arrive mixed with the wrapper's own. On-chain reconciliation is possible with bounded O(own-notes) reads (own indices recorded at purchase; compare expected own-claimable vs received — excess = unsolicited) — but the *rights/destination* of that excess (not feeTo, not automatically the registered note's schedule) is an **undecided product point**, not solved by bookkeeping. Astra's warning stands: aggregate collection ≠ aggregate provenance solved.

## 4. Genuine dissent (narrow)

- **Astra vs Grok on framing:** "no enforceable wrapper bound" (shared) vs Grok's stronger "incompatibility of selected custody + atomic harvest with this interface." I side with Astra: incompatibility is with *guaranteed timely terminal collection*, not with custody itself — custody and bounded own-note bookkeeping survive; only the liveness guarantee fails. The distinction matters for what the owner is actually deciding.
- **MiniMax's (P1)+(P2)+(P3) "jointly close NN-02 if owner accepts attestation"** vs my/Astra's position: (P1)'s cap binds only own purchases (fine, retained), (P2) frequency-shaping (retained), but (P3) attestation-without-measurement is rejected (R3) — so the joint package does not close as proposed.

## 5. Recommended next human checkpoint (one question, investigation-first)

> "NN-02 stays OPEN. Shall the specification author first produce the quantified liveness study — minimum successful spam payment for both markets (incl. zero-payout dust feasibility under live price/LP/oracle), measured per-iteration redeem cost and analytic-then-measured N*, attacker-cost model, pre-creation spam and deferred-claim cases, and a proposed rights/destination rule for unsolicited aggregate proceeds — for owner disposition (accept residual / descope / pursue upstream), rather than deciding acceptance or deferral before that evidence exists?"

## 6. Limits

All shared source facts re-verified against my own full reads of `BondDepository.sol` (200 lines), `IBondDepository.sol`, `Constants.sol`. Peer-only citations (`Treasury.sol:127–131`, `NET.sol:150–156`) flagged unverified. Deployed 4663 equivalence pending NN-01. No gas measured. Originals unchanged; research-only restrictions retained.
