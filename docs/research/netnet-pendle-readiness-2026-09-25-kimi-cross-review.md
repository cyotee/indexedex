# Kimi K3 — Cross-review of NetNet–Pendle PRD v0.17 readiness originals

- **Date:** 2026-09-25. **Author:** Kimi K3 (`kimi-code-plan-global/k3`, high variant; routing metadata, not provider attestation).
- **Inputs:** the other three ORIGINAL reports (`...-astra-original.md`, `...-grok-original.md`, `...-minimax-original.md` under `docs/research/`), treated as untrusted attributed evidence. My original (`...-kimi-original.md`) is preserved unchanged. No cross-review artifacts read. Research only; no shell/tests/code/config changes; no delegation.
- **Abbreviations:** P = `docs/strategies/ohm-style/netnet-pendle/NETNET_PENDLE_DETF_PRD.md` v0.17; M = sibling operation matrix; U = `docs/plans/detf/UNIVERSAL_V4_DETF_COMPOUNDED_EXPANSION_PRD.md` v0.2; ALIGN = `contracts/vaults/detf/DETF_ALIGNMENT_PRD.md`.

## 1. Agreements (convergent, evidence-backed)

All four originals independently found: (a) **M and the Q7 tracker lag v0.17** — M:3 (header to v0.15), M:49 (row 36 UNKNOWN), M:85/104/111 ("expansion unresolved") are stale against P:26,374–411/R52–R54; (b) **O01 (FoT NET / rebasing sNET supersession) is the single blocking owner decision** (`docs/agent/INDEXEDEX_AGENT_LAW.md:95–99` forbids both as configured underlyings); (c) **TWAP window and invalid-history policy are the remaining owner-shaped parameters** (P:397 "do not choose an unapproved duration"; P:391 invalid ≠ below-peg); (d) conservation/owned-book mapping, §12.3 note-array liveness, and V2 SE parity are engineering gates, not owner questions; (e) verdict: ready to seed a **gated** planning document, not a frozen executable plan. I maintain all of these from my original; the peer reports corroborate with independent citations.

## 2. Corrections to peer findings (verified against current text/source)

1. **To MiniMax (cross-family §5, "D9 … flag on. Plan must implement"):** D9 (ALIGN:42) mandates that for Uni V4 the DETF is the *only* party adding/removing reserve liquidity, with the hook deployed owner-only-LP. This **conflicts with the settled public shared HLP selection** (P:165 "Public, shared hook liquidity is SELECTED: any caller may add funded liquidity"; R32). Applying D9 to this hook would override an owner selection; omitting it leaves a silent law conflict. Correct disposition: D9 is a **further custom-family departure that must join the O01-class supersession map** — and P §2.1 (lines 48–55) currently does **not** list it. Neither Astra nor Grok caught this; MiniMax raised D9 but drew the wrong conclusion. This is my main new finding.
2. **To MiniMax (§3, "funding waterfall" presented as a fixed sequence):** P:309 says the listed realization steps "are possible realization steps; **the precise funding waterfall is not fixed**." The waterfall is possible-not-fixed; MiniMax overstated it as a selected order.
3. **To Grok (clarification Q4, empty successor market):** already settled. P:577 — "A successor must support the chosen entry; otherwise rollover reverts atomically. A Pendle-level dual SY/PT seed path could be specified separately, but … is not silently enabled." Revert-only is current text; a seed path would require separate specification. Not an open owner question.
4. **To Grok Q6 and my own original Q6 (confirm "no extra contraction eligibility"):** redundant. P:340 already records that no additional default/cap/hysteresis/eligibility is selected, and R11/P:338 require any future addition to be explicitly proposed. Asking the owner to confirm "none" re-asks settled text. Withdrawn (mine) / downgraded (Grok's).
5. **To MiniMax clarification #2 (singleton mechanism as owner question) and #5 (self-leg representation as owner question):** both are engineering. P:715/A45 assign salt-enforcement *proof* to implementation; O10's remainder (P:653) is specification work. Grok's "not owner questions" list is correct on salt encoding.
6. **To MiniMax #9 (confirm numeric defaults remain unselected):** redundant with P:340 for the same reason as item 4.

## 3. Corrections to my own original (evidence that changes my view)

1. **Retract the "price-decay path" framing of my Q2.** Astra's citation of P:399 is decisive: "Minting solely to staking does not mechanically add tokens to the reserve pool or rewrite past TWAP observations." Nothing in the selected design mechanically closes the 1,000→1 gap; my inference of an intended decay path was speculation. What remains is a settled consequence, not a question: expansion mints only to sNET-DETF (R43/R54), so liquid DETF holders are diluted relative to stakers while price stays far above the contraction threshold. I downgrade Q2 to a **non-blocking economic-risk note**; no owner confirmation is required, and I no longer list it as a clarification.
2. **My Q5 (vesting discrepancy) is substantially resolved by Grok's evidence, which I verified:** `lib/crane/contracts/protocols/pol/net/src/Constants.sol:76` `BOND_VEST = 2 days` and `:54` `GENESIS_VEST = 5 days` — the "five-day prose" plausibly refers to genesis bonds, not the note vesting P:598 flags. Remaining residue: deployed-instance verification (planning gate), not an owner question. I also verified Grok's other Constants claims: `EPOCH_LENGTH = 8 hours` (:17), `TAX_TOTAL_BPS = 500` (:32), `EXEMPT_DELAY = 2 days` (:41).
3. **My matrix-staleness finding extends to U.** Astra's claim verified: U:111 ("do not interpret 0.5% as flat supply growth now that premium dependence is selected… NetNet's coefficient still needs explicit selection") is stale against U:19 and P v0.17, which select exactly 0.5% fixed-rate compounded growth for NetNet. Companion synchronization must include U:111, not just M.

## 4. New evidence from peers I adopt

- **Astra — TWAP-availability coupling (engineering gate, owner escalation only if entitlements change):** settle-before-everything (P:403–411) plus invalid-TWAP handling can circularly block funded unstakes/transfers/mature claims if observation-producing operations themselves require settlement. Requires an explicit availability/dependency analysis. Valid and not in my original.
- **Astra — pre-activation public HLP joins:** R32 selects public joins while R51/P:121 make the first bond the reserve activation. The pre-live state machine (reject, queue, or permit) is unspecified. Valid engineering gap.
- **Astra — rollover slippage authority:** permissionless target submission (P:519) must not let callers set permissive minima controlling collective conversion cost; protocol-enforced bounds needed (P:567 lists execution bounds as spec work). Valid sharpening.
- **Astra — U=0 staking ownership edge:** P:443–455 defines B/U for positive U only; zero-share/pre-existing-backing behavior needs definition. Valid.
- **Grok — matrix policy 3 (M:65) and O02:** the authoritative contraction branch price remains unconstructed; P:399 implies post-expansion owned-reserve synthetic pricing, so this is engineering specification, not an owner fork — I classify it below accordingly (partial dissent from Grok's owner framing).
- **MiniMax — unaddressed cross-family surfaces worth planning-time reconciliation:** D55 NFT metadata and `DETF_INSTANCE_IO_ROUTING_PRD.md` §16 route-table reconciliation are real omissions in P (valid as *planning* items; MiniMax's D9 conclusion is corrected in §2.1).

## 5. Unresolved dissent

- **Grok Q2 (authoritative P) as an owner question:** I dissent. P:399 already fixes the source class (post-expansion synthetic price on the new supply and owned reserve); exact construction/units are engineering per P:338. Only if engineering finds that mark inadequate should it escalate.
- **MiniMax's readiness framing ("ready to seed an implementation plan after O01, singleton mechanism, TWAP failure-mode"):** I dissent on including the singleton mechanism as a precondition — it is an engineering proof obligation inside planning (A45), not a gate on starting a gated plan. O01 (+D9) and TWAP policy are the genuine pre-planning owner items.
- No peer disputed my core findings; I dispute the classification errors listed above, not their underlying facts.

## 6. Final prioritized decision checkpoint

**Owner decisions required before a gated implementation plan is authorized:**
1. **O01, widened:** approve the custom-family supersession map covering (a) FoT NET and rebasing sNET as configured underlyings (`INDEXEDEX_AGENT_LAW.md:95–99`), and (b) **D9 owner-only-reserve-LP versus settled public shared HLP** (ALIGN:42 vs P:165/R32) — the latter newly identified and absent from P §2.1. Refusal of either blocks the family as designed.
2. **TWAP policy:** approve window/duration and invalid/stale/insufficient-history behavior for the expansion gate (P:397,391; A44). Engineers first supply the availability/dependency analysis (Astra's coupling point).
3. **Non-PENDLE reward destinations (P:632, still OPEN):** name destinations or confirm "not swept" as the standing disposition.

**Explicitly not owner questions (settled text or engineering):** empty-target rollover (revert-only, P:577); additional contraction eligibility (none selected, P:340/R11); singleton salt mechanism (A45 engineering proof); self-leg representation (O10 engineering); funding waterfall order (P:309, possible-not-fixed); authoritative branch price (P:399, engineering construction); vesting constants (verified 2-day `BOND_VEST`, deployed check is planning).

**Documentation closure before planning (editorial, no decision reopen):** sync M to v0.17 (rows 36, lines 85/104/111, policy 9 vs row 24), fix U:111, update Q7 tracker (`REQUIREMENTS_QUESTIONS.md:28`), and qualify P:228/236's proportional-exit language against P:264–275.

**Readiness verdict (mine, unchanged in kind):** with items 1–3 answered and the editorial closure done, P v0.17 supports a **gated, specification-first implementation plan** with stop/go at the named engineering gates (§12.3 note liveness, Weighted multi-reserve conservation, zero-interest bootstrap, rollover execution). It does not support a frozen executable plan. Consensus among reviewers is evidence of shared reading, not of security or economic soundness; solvency, peg efficacy, gas and live-deployment equivalence remain unproven.
