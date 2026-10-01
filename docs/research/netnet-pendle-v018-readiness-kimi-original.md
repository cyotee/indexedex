# Kimi K3 — Independent first-pass readiness review of NETNET_PENDLE_DETF_PRD.md v0.18

- **Date:** 2026-09-25 (environment). **Author:** Kimi K3 (reported metadata: `kimi-code-plan-global/k3`, variant high; routing metadata, not provider attestation). Preserved session; prior passes are context, not authority. No peer originals or cross-reviews were read via any tool in this pass.
- **Method:** re-read the full current PRD (950 lines) directly; CLAUDE.md, agent law, alignment D9/D50/D52, and companions (operation matrix header, REQUIREMENTS_QUESTIONS.md header, Universal remediation PRD v0.2) checked directly. No shell/tests/code/config edits; no delegation. Research only.
- **Abbreviations:** P = `docs/strategies/ohm-style/netnet-pendle/NETNET_PENDLE_DETF_PRD.md` v0.18; M = sibling operation matrix; Q = `REQUIREMENTS_QUESTIONS.md`; U = `docs/plans/detf/UNIVERSAL_V4_DETF_COMPOUNDED_EXPANSION_PRD.md` v0.2; ALIGN = `contracts/vaults/detf/DETF_ALIGNMENT_PRD.md`.

## 1. v0.18 content — verified structure (facts)

The controlling amendment (P:18–83) records five owner decisions:

- **V18-1 (P:22–24):** owner approves the custom family, "including its configured conditionally fee-on-transfer NET and rebasing sNET and the described family-specific behavior." O01 answered; not general FoT/rebasing permission; shared instruction files unchanged; no council execution permissions added. P:9 status now reads "Custom-family implementation approved… specification not frozen."
- **V18-2 (P:26–41):** two distinct **one-hour (3,600 s) arithmetic TWAPs** — hook **spot trading price** and DETF **synthetic price** — as `TWAP(t) = (C(t) − C(t−3600))/3600`; a reusable standard interface is to be specified; **existing-hook TWAP implementation is a separate effort** (P:35). Window and arithmetic method are settled (P:39). Expansion gate remains the hook TWAP (P:41).
- **V18-3 (P:43–51):** all attributable Pendle rewards **except the designated interest-reserve yield token** go to current `feeTo()`; owner's example retains sNET/SY interest-reserve exposure while PENDLE and USDG rewards forward; reward USDG is fee-owned, not backing (P:47). This closes §13's "other reward destinations are OPEN" and O08's residual.
- **V18-4 (P:53–73):** compounded missed epochs replaced by **single catch-up expansion**; `S0*(1.005^n − 1)` and the 15.075125 example superseded (P:55); no per-missed-epoch production loop (P:55); baseline retained: 0.5% per eligible processed NET epoch, one current hook TWAP > 1 qualifies the batch, direct mint to sNET-DETF, once-only markers, settle-first, balance-derived staking (P:57).
- **V18-5 (P:75–81):** acceptance deltas for A11/A40/A43/A44.

**Quality note:** the amendment is epistemically careful — it labels the linear equation a "working interpretation for planning, not a separately confirmed owner equation" (P:59,71), admits compounding did not inherently require a loop (P:73), and discloses failed writes/identity-guard denials (P:83). Good.

## 2. Human choices vs assistant-inferred items

Per the round instruction, three items are **not** owner-chosen and must not be treated as settled:

1. **Linear catch-up formula** `pendingMint = floor(S0 * n / 200)` (P:59–71). Explicitly unconfirmed; the document itself requests confirmation before freezing (P:71), and forbids silently substituting one flat 0.5% regardless of elapsed epochs. This is the one remaining economic-formula question.
2. **Oracle failure policy** (initialization, insufficient history): "remain specification work" (P:39); "Earlier assistant suggestions to skip expansion while allowing claims were not explicit owner decisions" (P:39). Engineering specification, with the availability-coupling caveat (settle-first P:472–476 vs blocked operations) to be analyzed by engineers; invalid TWAP ≠ below-peg (P:39,71).
3. **Same-token reward classification:** the owner's exception covers the designated yield token only; the earlier assistant assertion that every same-token incentive must be forwarded "was not an owner-selected override" (P:49). If the market emits the retained token as an incentive, allocation/classification "must be explicitly specified before admitting it to the interest-only trading inventory; do not silently relabel incentive receipts as accrued YT interest" (P:49). Conservative default is therefore *not-interest*; final classification is specification work (engineering proposal; escalate only if the chosen classification changes fee/LP entitlements).

## 3. Contradictory legacy operative requirements (superseded by P:20 precedence, text retained)

A planner reading operative sections alone would implement retired behavior:

- **R52 (P:189)** still says expansion is "compounded: 0.5% of projected total DETF supply per eligible … epoch" — contradicts V18-4.
- **R53 (P:190)** says "Window … require explicit oracle specification" — window now settled (V18-2, 3,600 s arithmetic).
- **§9.1 (P:440–460)**, including the compounded formula and `1,000 → 1,015.075125` illustration, and the v0.17 amendment (P:93) — superseded by V18-4 (P:55).
- **§10.4 (P:580)** "0.5% of compounded total supply per missed epoch" — superseded.
- **O05 (P:715)** records "Resolved: … 0.5% compounded" and lists "TWAP window" as remaining — both stale.
- **A40 (P:769)** requires compounding and says "Verify no … linear catch-up" with the 15.075125 example — now inverted by V18-4/V18-5; highest-risk single contradiction.
- **A44 (P:773)** describes a single hook TWAP; V18-5 expands it to two series plus interface units/readiness.
- **A11 (P:740)** and **R13/R30 (P:150,167)** are PENDLE-only; V18-3/V18-5 generalize to all fee-destined reward tokens with retained yield-token protection and provenance rules.
- **§13 (P:699)** "Other reward-token destinations are OPEN" — closed by V18-3.
- **O01 (P:711)** and **§2.1 (P:117–120)** still frame FoT/rebasing and related departures as unreconciled conflicts "requir[ing] formal reconciliation before implementation" — answered by V18-1; §2 is explicitly inside the P:20 precedence list, but the retained text reads as still-blocking.
- **O08 (P:718)** "other reward destinations" residual — closed.

**Additional gap (editorial, not a reopen):** §2.1 never listed **D9** (ALIGN:42: Uni V4 DETF must be the only reserve-LP adder/remover, hook deployed owner-only-LP) against settled public shared HLP (P:232/R32). V18-1's plain text ("the described family-specific behavior," P:24) covers public HLP, so no new approval is needed; but because the conflict is unrecorded, a planner consulting ALIGN could implement owner-only LP. §2.1 should enumerate the D9 departure in the next edit.

## 4. Stale companions (verified current headers/text)

- **M:3** header still "reconciled with … PRD v0.15"; M retains pre-v0.17 expansion cells (row 36 UNKNOWN; M:85/104 "unresolved") and PENDLE-only harvest row 41; no rows for the two TWAP series or the standard interface. P:20 correctly states M "must not override these NetNet-specific decisions," but M is the artifact a planner expands row-by-row — sync before planning.
- **Q:7** tracker reconciled "through version 0.12"; Q7 expansion row predates v0.16–v0.18 entirely.
- **U v0.2** states NetNet selects "0.5% … compounded, using the current NET/DETF TWAP" (U:19) and that "NetNet's coefficient still needs explicit selection" (U:111) — both stale after V18-4 (single catch-up) and V18-2. Families now deliberately diverge (Universal compounds; NetNet linear catch-up); U should record that divergence.

## 5. Engineering gates (existing plus new)

Retained: Weighted multi-reserve quote/settlement conservation; §12.3 external-note ownership/aggregate-redemption liveness; V2 SE full parity; zero-interest bootstrap; atomic rollover execution; fixed-salt singleton proof (A45); owned-book construction; exact-output inverse.

New from v0.18:
- **TWAP standard interface:** selectors, cumulative-observation semantics, units/scaling/rounding, same-block updates, elapsed-time extension at consultation, one-hour boundary retrieval, history availability, preview/consultation consistency (P:33–37).
- **Spot series definition:** what is "spot NET per DETF" inside a four-currency Weighted hook (reference leg/rate derivation); swap-accounting accumulation (P:37).
- **Synthetic series update points:** supply, owned-reserve and valuation changes — swaps alone insufficient (P:37).
- **Rollover continuity** of both series and **quiet-trading vs stale** distinction (P:39).
- **Consumer mapping** for the synthetic TWAP (P:41): which consumers, if any, replace instantaneous synthetic reads (e.g., the ≥1/<1 branch price currently instantaneous per P:466); finite-size quotation must not be replaced by an average price.
- **Linear catch-up arithmetic:** overflow-safe intermediates for `S0*n`, representability, rounding, atomic markers, defensible operating horizon; a repeatable overflow revert can itself block settlement and "no claim that reverting automatically guarantees recovery is accepted" (P:73); no invented cap or skipped epochs.
- **Generalized reward accounting:** per-token payable reconciliation once, force-claims, historical-series claims, dynamic `feeTo()`, provenance separation of principal/interest/incentive/donation/fee-payable even at identical addresses (P:49), reward-USDG exclusion from backing (P:47), forwarding-failure policy without losing entitlement.

## 6. Narrow owner questions (only necessary ones)

1. **Confirm the single-catch-up equation:** is `pendingMint = floor(S0 * n / 200)` (per-epoch 0.5% applied linearly to starting supply, no compounding, one aggregate mint) the intended formula? The PRD itself requests this confirmation (P:71). Everything else in V18-4 is settled.
2. **(Optional, zero-ambiguity only):** confirm V18-1's approval encompasses the public shared hook-LP departure from D9 owner-only reserve-LP (ALIGN:42 vs P:232/R32), so §2.1 can enumerate it. Plain text ("the described family-specific behavior," P:24) already reads as covering it; I do not treat this as reopening approval.

I identify **no other owner questions**: TWAP window/method are settled (P:39); failure policy, consumer mapping, same-token incentive classification, interface selectors and linear-catch-up safety are specification/engineering work the PRD itself assigns there (P:35–41,49,73).

## 7. Readiness assessment

- **For a gated, specification-first implementation plan:** yes, once owner question 1 is answered and the §3/§4 contradictions are editorially reconciled (or the planner is disciplined by P:20's precedence banner). The v0.18 handoff line (P:950) matches this: define the two TWAP interfaces, finalize consumer/readiness behavior, confirm the single-catch-up equation, specify generalized reward accounting, retain engineering gates.
- **For a frozen executable plan:** no. The TWAP standard interface, spot/synthetic series semantics, consumer mapping, reward provenance/classification, linear-catch-up safety analysis, and all prior feasibility gates (conservation, note liveness, V2 parity, bootstrap, rollover, singleton proof) must produce evidence first. V18-1 approves the family; it does not certify feasibility (P:24 "Engineering feasibility … remain obligations") and grants no execution permission to this council (P:24,83).

## 8. Confidence and limitations

- **High confidence:** v0.18 change inventory, the human-vs-inferred split (each item is labeled in P itself: P:39,49,59–71), and the contradiction map (all lines re-read directly this pass).
- **Medium confidence:** completeness of legacy-contradiction enumeration beyond the P:20 list (I found all listed items plus §2.1/O01/O08/O05/§13; a full-line audit of §§10–12 against V18-3/4 was targeted, not exhaustive).
- **Limitations:** no live-chain, deployment, gas or equivalence verification; companions checked at headers/known-stale lines, not re-audited in full; no Context7 call was needed — v0.18 introduces specification targets (TWAP interface semantics), not external library/API claims requiring current vendor docs. This is one of four independent passes; no consensus is claimed, and reviewer agreement would prove neither security nor economic soundness.
