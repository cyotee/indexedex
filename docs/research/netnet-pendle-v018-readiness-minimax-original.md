# NetNet–Pendle DETF PRD v0.18 — Independent Readiness Review (MiniMax M3)

**Reviewer identity and observed metadata.** Prompt identifies me as `minimax/MiniMax-M3`. No fresh peer or council metadata in this round. PRD §17:823–829 records prior-session model metadata as routing only, not provider attestation. No secrets transmitted.

**Scope reminder.** This is the first of four independent passes. Prior knowledge is context only; no peer artifacts read. PRD v0.18 controlling amendment (lines 18–83) supersedes the legacy body; legacy text remains in §3, §9, §10.4, §13, §14, §15. V0.18 is a documentation-only editing task; no implementation was authorized (line 9).

**Sources actually read.**
- `NETNET_PENDLE_DETF_PRD.md` v0.18 (full, 950 lines).
- `NETNET_PENDLE_OPERATION_MATRIX.md` (full, 145 lines).
- `REQUIREMENTS_QUESTIONS.md` (full, 437 lines) for stale-tracker diagnosis.
- `docs/plans/detf/UNIVERSAL_V4_DETF_COMPOUNDED_EXPANSION_PRD.md` v0.5 (313 lines) for cross-family comparison.
- `docs/strategies/ohm-style/netnet-pendle/KEEP_YT_ROLLOVER_RESEARCH.md` (109 lines, prior context only).
- `CLAUDE.md`; `docs/agent/INDEXEDEX_AGENT_LAW.md` token-policy and families; `contracts/vaults/detf/DETF_ALIGNMENT_PRD.md` D32–D66/§24 (excerpts, prior context only).

No peer artifact opened. No Context7 call: PRD introduces no new library/SDK/API that changes a product decision in this round.

**Tool-availability deviation (flagged).** Prompt asked for `apply_patch`; only `write`/`edit`/`read`/`glob`/`grep` available. I used `write` after reading the target directory listing. No shell, tests, deployment, signing, instruction edit, file deletion/move, browser, MCP, subagent delegation, or peer-artifact read.

---

## 1. v0.18 controlling amendment — owner choices vs. assistant inferences

**V18-1 — Custom-family approval** (PRD lines 22–24). Owner selection. Closes O01 (token-policy reconciliation) and the O01 "do not repeatedly ask" loop. Documented but token policy law (INDEXEDEX_AGENT_LAW.md §Token policy, lines 89–101) is unchanged for other families; this is custom-family scope only.

**V18-2 — Two 1-hour arithmetic TWAPs and a standard interface** (lines 26–41). Owner-selected facts:
- Window: 3,600 seconds for both series (settled).
- Method: arithmetic time weighting (settled).
- Hook tracks cumulative **spot trading price**; DETF tracks cumulative **synthetic price** (settled separation).
- `C(t) = integral(price(u) du)`, `TWAP(t) = (C(t) - C(t - 3600)) / 3600` (settled semantic).
- A standard reusable interface is in scope of this effort; existing-hook retrofit is a separate effort (settled).

Assistant inferences (NOT owner-confirmed):
- **Oracle failure policy for NetNet TWAP.** Line 41: "Earlier assistant suggestions to skip expansion while allowing claims were not explicit owner decisions. Do not silently substitute spot or classify unavailable history as a valid below-peg value." This explicitly defers the failure policy. Universal PRD v0.5 §3.3 line 178 (cold-start skip + marker advance) is Universal-specific and does not bind NetNet.
- Initial epoch / bootstrap history policy (line 41: "remaining specification work").
- Exact pre-change accumulation / same-block / elapsed-time / boundary-retrieval mechanics (line 37).
- Consumer mapping for the DETF synthetic TWAP (line 41: "does not by itself specify which consumers replace instantaneous synthetic-price reads").
- Callback safety, rollover continuity, operation availability (line 41).

**V18-3 — Generalized reward routing to `feeTo()`, retained interest-reserve yield token** (lines 43–51). Owner-selected facts:
- All attributable Pendle rewards EXCEPT the designated interest-reserve yield token go to current `feeTo()` (settled, closes §13/O08 non-PENDLE-rewards question).
- Designated sNET/SY interest-reserve exposure retained to support NET/sNET outputs (settled).
- Generalized permissionless collection/forwarding covers previously force-claimed balances and historical-series claims (settled).

Assistant inferences (NOT owner-confirmed):
- **Same-token incentive classification.** Line 47–49: "If a market emits the retained token as an incentive, explicitly specify its allocation/classification before admitting it to the interest-only trading inventory." This is a specified gap, not a resolved one.
- Actual deployed market reward-token list (line 47: "This example is not verification that a deployed SY address equals sNET").
- Forwarding-failure handling (line 51: "Define forwarding failure without losing the entitlement" — remains engineering).

**V18-4 — Replace compounded with single catch-up** (lines 53–73). Owner-selected facts:
- Compounding superseded; `S0 * (1.005^n - 1)` and the 15.075125 example are superseded (settled).
- 0.5% per eligible processed NET epoch rate retained (settled).
- Current hook TWAP strictly > 1 NET qualifies the batch (settled).
- Direct aggregate mint to sNET-DETF, once-only markers, settle-before-participation, balance-derived staking (settled).

Assistant inferences (NOT owner-confirmed):
- **Single-catch-up equation.** Lines 59–71: `pendingMint = floor(S0 * n / 200)`. PRD itself labels this as "Working interpretation for planning, not a separately confirmed owner equation" and explicitly demands confirmation: "Confirm this interpretation before freezing the executable specification; do not silently substitute one flat 0.5% regardless of elapsed epochs" (line 71).
- Operating-horizon bound, overflow-safe intermediates, final-supply representability (line 73).
- Atomic marker update exact semantics (line 73).

**V18-5 — Acceptance delta** (lines 76–83). Updates A11/A40/A43/A44 to cover new TWAP/generalized reward/single-catch-up semantics. Settled.

## 2. Contradictory legacy operative text in PRD body

PRD line 20 itself names the scope of contradiction: "supersedes conflicting v0.17 and earlier text anywhere below, including R13/R30/R52/R53, §§2/9/13/14, A11/A40/A43/A44." The text below is not removed; it remains in the file. A plan author or contract reader cannot rely on the body alone.

Verified residual conflicts in v0.18 body:
- **R13** (line 150): "Attributable PENDLE incentives go to the current `feeTo()`. YT-derived SY interest remains strategy-owned." → V18-3 generalized to all fee-destined reward tokens; R13 stays PENDLE-only.
- **R30** (line 167): PENDLE-only public hook function. → V18-3 supersedes; generalized.
- **R52** (line 189): "0.5% of projected total DETF supply per eligible completed unprocessed NET epoch" — still says "compounded" with `S0 * (1.005^n - 1)`. → V18-4 supersedes; single catch-up.
- **R53** (line 190): hook-only TWAP. → V18-2 supersedes; hook spot AND DETF synthetic, both 1-hour arithmetic.
- **§9.1** lines 440–456: still shows compounded formula with `S0 * (1.005^n - 1)` and the 1,015.075125 illustration (line 460). Superseded.
- **§9.2** lines 462–466: "hook owns the TWAP calculation and observation storage and exposes a NET-per-DETF trading-price view for DETF consumption" — single-series, hook-only. Superseded by V18-2.
- **§10.4** line 580: "Expansion is fixed at **0.5% of compounded total supply per missed epoch when the current hook TWAP is above 1 NET**" — superseded.
- **§13** lines 693–703: PENDLE-only forwarding, "Other reward-token destinations are OPEN" — superseded by V18-3.
- **O05** (line 715): "0.5% compounded total-supply growth" — superseded.
- **A11** (line 740): PENDLE-only — superseded.
- **A40** (line 769): "0.5%-of-total-supply compounding" with 1,000 → 1,015.075125 example — superseded.
- **A43** (line 772): "No hidden epoch cap or unbounded production replay" — V18-4 removed the cap-removal emphasis; V18-5 specifies the new behavior.
- **A44** (line 773): hook-only TWAP — superseded; V18-5 redefines to cover both series.

The PRD body remains self-aware of these conflicts via line 20, but it is editorial risk that an implementation plan could quote R52/§9.1/§10.4/§13/A11/A40 and silently reintroduce retired requirements.

## 3. Stale companion artifacts

- `NETNET_PENDLE_OPERATION_MATRIX.md` header line 3 says "against PRD v0.12"; row 36 cells UNKNOWN; line 85 "expansion base, gate and catch-up calculation are not silently selected"; line 104 "remain unresolved". All superseded by V18-4 and V18-2.
- `REQUIREMENTS_QUESTIONS.md` line 7 says "reconciled through version 0.12" and Q7 line 28 is "Partially answered; exact expansion equations … remain". Superseded by V18-4.
- `docs/plans/detf/UNIVERSAL_V4_DETF_COMPOUNDED_EXPANSION_PRD.md` v0.5 line 11 says "Related custom family: NetNet/Pendle: v0.17"; line 19 says "NetNet remains 0.5% of compounded total DETF supply per eligible processed NET epoch"; line 164 "NetNet mints 0.5% of the compounded supply base"; line 281 "0.5% compounded eligible expansion". All stale per V18-4. Universal PRD §3.3 line 178 (cold-start skip + advance marker) is Universal's chosen oracle-failure policy; the PRD does not bind NetNet to it (V18-2 line 41).

These stale companions will re-open settled economics if not corrected before planning begins.

## 4. Engineering gates vs. narrow owner questions

**Engineering gates (not owner questions, per PRD §14):** direct-custody Weighted hook multi-reserve joins/exits and quote/settlement conservation; safe DETF/child callback authority; full-feature NetNet V2 SE parity with taxed/untaxed execution; external-note ownership/aggregate redemption liveness (§12.3); deployment/code verification; epoch/reward attribution; execution/gas bounds; pricing and rollover recovery; V2 SE full surface inventory (A21); Weighted `MIN_N/MAX_N` ledger mapping (PRD line 268); singleton-salt enforcement mechanism (PRD §4.1); V2 SE binding query implementation (PRD §4.1 lines 244–246); bond depository 2-day vs 5-day vesting verification (E06 / PRD line 598).

**TWAP implementation specifics (engineering, not owner):** cumulative observation storage layout; bootstrap initialization source; one-hour boundary semantics for both series (Universal PRD §3.3 lines 176–178 apply to Universal only); same-block update rules; elapsed-time extension at consultation; spot observation when swap price is unchanged (no unbounded growth — Universal PRD §6 line 246); quiet-period carry-forward.

**Narrow owner questions (only what cannot be defaulted; per PRD V18-2/3/4 self-identification):**
1. **Single-catch-up equation confirmation** (V18-4 line 71 explicitly: "Confirm this interpretation before freezing the executable specification"). The assistant inference `floor(S0 * n / 200)` is not owner-confirmed; the alternative interpretations include capped per-eligible-epoch, absolute flat 0.5%, or a different non-compounded formula. **Blocking.**
2. **Oracle failure policy** (V18-2 line 41 explicitly: "Earlier assistant suggestions to skip expansion while allowing claims were not explicit owner decisions"). Owner must select: skip-and-advance-marker (Universal's choice), revert, or another. **Blocking.**
3. **Same-token incentive classification when market emits the retained yield token** (V18-3 lines 47–49 explicitly: "explicitly specify its allocation/classification before admitting it to the interest-only trading inventory"). Owner must select: route to `feeTo()`, retain as interest inventory, split, or another. **Blocking.**
4. **Actual deployed market reward-token list and designated interest-reserve yield token address binding** (V18-3 line 47 explicitly: "Bind the actual market/SY and designated retained token explicitly"). Owner must supply or confirm the canonical address. **Engineering-binding; not blocking if defaultable later but PRD lists as OPEN.**
5. **Confirmation that no consumer of DETF synthetic TWAP exists today** (V18-2 line 41: "does not by itself specify which consumers replace instantaneous synthetic-price reads"). If a consumer exists, it must be enumerated; otherwise plan specifies the empty-set default. **Confirmatory.**

**Confirmatory (already settled, do not reopen):** O01 (closed by V18-1); D9 owner-only hook + R32 public shared HLP reconciliation (engineering gate, encapsulation reconciles, see my prior cross-review); empty-target rollover = revert-only v1 (PRD §11.4:644); no additional contraction eligibility beyond P<1 + funded delivery (PRD §7.5:407).

## 5. Readiness verdict

**Verdict.** Not a frozen executable plan. PRD v0.18 is **gated-planning-ready** once the three blocking owner clarifications above are confirmed and the legacy contradictory text in the body is editorially reconciled (or formally flagged with strikethrough annotations pointing at the controlling v0.18 amendment). The matrix and the Universal PRD must be updated to reflect V18-4 and V18-2 before the plan author works from them, or the plan will re-litigate settled economics.

## 6. Narrow prioritized decision checkpoint (5 items)

1. **Confirm single-catch-up equation** as `pendingMint = floor(S0 * n / 200)` or specify alternative. (V18-4 line 71.)
2. **Select NetNet TWAP oracle failure policy.** (V18-2 line 41; distinguish from Universal §3.3 line 178.)
3. **Specify classification when market emits the retained interest-reserve yield token as incentive.** (V18-3 lines 47–49.)
4. **Bind the actual deployed market reward-token list and the canonical address of the designated interest-reserve yield token.** (V18-3 line 47.)
5. **Confirm DETF synthetic TWAP consumer set is empty today** (or enumerate any existing consumers). (V18-2 line 41.)

**Non-owner / engineering gates (not listed above):** §12.3 note-array liveness; multi-reserve conservation; V2 SE parity inventory; Weighted `MIN_N/MAX_N` ledger mapping; singleton-salt enforcement mechanism; external evidence pins (Pendle V7, NetNet BondDepository `BOND_VEST` on 4663, canonical V2 SE binding query); bond duration compatibility; rollover execution ordering.

## 7. Stale-companion remediation needed before planning

The matrix, REQUIREMENTS_QUESTIONS, and Universal PRD v0.5 must be updated to reflect V18-4 (single catch-up) and V18-2 (two-series 1-hour arithmetic TWAPs). Failure to update will cause the plan author to read stale "compounded" and "TWAP gate" references as still-controlling.

## 8. Confidence and limits

**High confidence:** v0.18 amendment captures owner selections for custom-family approval, two 1-hour arithmetic TWAPs with separation of series, generalized reward routing with retained interest-reserve yield token, single catch-up (rate, gate, mint target, marker policy). Confirmed by direct read of PRD lines 18–83 and legacy §18 v0.18 narrative lines 950.

**Medium confidence:** legacy body contradictions are exactly those listed in PRD line 20; I verified the named items (R13/R30/R52/R53, §9.1, §9.2, §13, A11/A40/A43/A44) plus the residual at §10.4 line 580 and O05 line 715. Did not exhaustively search the body for every residual inconsistency.

**Low confidence:** single-catch-up equation is the correct linear interpretation; oracle failure policy selection; same-token incentive classification; that no consumer of DETF synthetic TWAP exists today. These are owner-shaped, not assistant-resolvable.

**Not asserted:** security, economic soundness, solvency, peg effectiveness, native-note liveness, executable gas bounds, on-chain equivalence, deployed Pendle V7/NetNet fidelity. PRD does not claim these; neither do I.

**Tool availability note** is in §0 above. Stopping here for the human moderator.
