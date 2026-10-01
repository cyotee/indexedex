# Grok original — NetNet–Pendle DETF PRD v0.17 readiness

| Field | Value |
| --- | --- |
| Researcher | Independent Grok first pass |
| Observed model metadata | Prompt names `grok-4.6`; exact ID `xai/grok-4.6`. `docs/agent/RESEARCH_COUNCIL.md:32` pins `council-grok` to `xai/grok-4.6`. Routing metadata, not provider attestation. |
| Environment date | 2026-09-25 |
| Subject | `docs/strategies/ohm-style/netnet-pendle/NETNET_PENDLE_DETF_PRD.md` v0.17 (883 lines) |
| Companion matrix | `docs/strategies/ohm-style/netnet-pendle/NETNET_PENDLE_OPERATION_MATRIX.md` (145 lines; header still “against PRD v0.12”, reconciled through v0.15) |
| Authorization | Research/document review only. No implementation plan authorization. |
| Access date for this pass | 2026-09-25 |

**Verdict:** v0.17 is a reviewable, internally coherent product draft for the *settled economic model*. It is **not** implementation-plan ready. Blocking owner work remains O01 (token-policy supersession). Blocking engineering work remains conservation, custody/liveness, TWAP specification, owned-book mapping, and matrix/tracker lag versus v0.17. Do not reopen R52–R55.

## Assumptions

1. Current CLAUDE.md / INDEXEDEX_AGENT_LAW / DETF_ALIGNMENT D32–D66 control existing families; this PRD records a proposed custom family, not silent law amendment (`PRD:45–56`, `CLAUDE.md:25–46`).
2. Historical §17–18 narratives are provenance; R01–R55 and §§4–13 control.
3. Matrix and `REQUIREMENTS_QUESTIONS.md` are companions, not peer research artifacts. Matrix expansion cells that still say UNKNOWN are documentation lag, not permission to reopen v0.17.
4. Local Solidity snapshots are unpinned; no tests, forks, or live Robinhood verification were run.
5. Context7/web sources describe upstream interfaces, not Robinhood deployments.

## Settled owner selections — do not reopen

Opening **1,000 NET/DETF**; expansion **0.5% of compounded total DETF supply** per eligible completed unprocessed NET epoch; **current hook NET/DETF TWAP strictly > 1** qualifies the whole missed batch; no premium-size multiplier, historical TWAP replay, Universal 1.05 deadband, or 8-hour DETF clock (`R52–R54`, `§9.1:374–394`). Direct mint to sNET-DETF; balance-derived rebasing from held DETF and internal shares (`R43`, `§10.2:442–456`). Hook is unified custody/vault; DETF holds only its HLP; public shared HLP; Keep YT for NET/sNET, V2 SE for USDG; standard-interface contraction below peg with input-side `p`; incentive-free reinvestment at any peg; atomic rollover; first bond supplies initial liquidity; ERC-4626 `asset()=sNET` with DETF as shares, no strict-conformance gate; cliff principal with pre-maturity rewards; PkgInit/PkgArgs split and salt `"NET-DETF"` (`R55`).

## Consistency

**Facts.** Header, R52–R55, §9, O05, A40–A45, and §18 v0.17 checkpoint agree on rate/base/TWAP/rebasing. Universal companion `docs/plans/detf/UNIVERSAL_V4_DETF_COMPOUNDED_EXPANSION_PRD.md:15–37` (v0.2) correctly keeps family clocks/gates distinct while sharing compounding and balance-derived rebasing.

**Inconsistencies (documentation, not product reopen):**

1. Matrix header (`OPERATION_MATRIX.md:1–4,85,104,111`) still treats 0.5%/catch-up as unresolved and row 36 expansion cells as UNKNOWN. PRD v0.17 settled those *economics*; remaining work is TWAP window, native `1.005^n`, invalid-TWAP behavior.
2. `REQUIREMENTS_QUESTIONS.md:7,26` still says Q7 expansion equations remain open and tracker is reconciled only through v0.12.
3. Matrix policy 9 (`:89`) says “detailed USDG-bond schedule is UNKNOWN” while row 24 and PRD O03/R50 already share Pendle-maturity cliffs for USDG-funded fresh bonds.
4. Long §17–18 history still quotes superseded v0.16 premium-scaling (`:871–873`) before the v0.17 correction. Current-control banner is adequate if planners ignore history.
5. PRD document-owner line (`:11`) omits later Kimi matrix participation; immaterial to product law.

**Law tension, not reopen:** FoT NET and rebasing sNET as configured underlyings remain forbidden (`INDEXEDEX_AGENT_LAW.md:89–99`; `CLAUDE.md:46`). PRD O01 correctly refuses to invent an exemption. NET-epoch clock, cliff principal, DETF-as-SY, and no Universal swap-fallback on failed contraction are explicit custom-family departures requiring approved supersession (`PRD:49–56`; alignment §24.3.2/§24.4/§24.7).

**Inference.** Quality is high on later-selection discipline (R IDs, “must” scoped to intended product). Clarity suffers from companion lag and 883-line history. That is an editorial gate before planning, not an owner economic reopen.

## Custody / accounting

**Facts.** DETF holds HLP; hook holds PLP, YT, interest, V2 SE shares; sNET-DETF holds minted DETF backing (`§4:131–156`, `R29/R43`). Proportional HLP formula is per-component floor (`§7.1:265–271`). Burn quotes use owned HLP fraction only (`R39`, `§7.2:286–297`). Bond target `createFundedPosition` at `DETFFundedBondTarget.sol:93–125` receives already-calculated principal; `_claim` via `DETFFundedStakingMath.sol:96–116` vests principal linearly — PRD correctly flags this as incompatible with cliffs (`§10.3:473–474`). Split `DETFMintSplitLib.sol:45–52` matches G/U/B/R (`§10.4:484–497`). `firstJoinMustBeFullBook()` is `true` (`UniswapV4StandardExchangeWeightedBufferHookTarget.sol:243–248`).

**Engineering gates, not owner choices:** one authoritative hook book; no double-count of SE share vs VLP vs Pendle SY; interest vs principal SY; fee-owned PENDLE offset once; child callbacks cannot spend another user’s backing; first-depositor/zero-share/rounding of `floor(B*u/U)`; self-leg representation (O10 remaining); Weighted `MIN_N=2`/`MAX_N=8` (`UniswapV4StandardExchangeWeightedBufferHookMath.sol:30–37`) vs many internal components.

**Safely deferred to planning:** Repo slot layout, checkpoint algorithm, exhaustive callback/authority table, pin of math revision.

## Expansion / TWAP

**Facts.** Formula `pendingMint = S0*(1.005^n)-S0` when valid current T>1, else 0; consume n even when mint is 0 (`§9.1:379–391`). Illustration 1,000 → 1,015.075125 over three epochs is arithmetically correct before native rounding. TWAP is hook-owned NET/DETF, not Universal highest-leg mark (`§9.2:396–399`). Burn after expansion uses new supply and owned-reserve synthetic price — TWAP does not replace burn pricing. D52 forbids catch-up caps (`DETF_ALIGNMENT_PRD.md:993–995`); A43 forbids a hidden epoch cap. Invalid TWAP is explicitly *not* auto-below-peg (`§9.1:391`).

**Owner vs engineering.** Rate/base/current-TWAP catch-up are settled. Still owner-shaped if unspecified: **TWAP window** (“do not choose an unapproved duration”, `§9.2:397`); **invalid/stale/insufficient-history failure** (revert vs skip vs other). Native-unit compounding method, observation update/bootstrap, callback-safe reads, and manipulation residual are engineering. Uniswap V4/Pendle PYLpOracle are not selected substitutes.

**Speculation.** Unbounded `1.005^n` after long inactivity is economically large; that is an accepted D52 consequence, not a license to restore caps.

## Bootstrap

**Facts.** First bond is the live-making join, not a prior seed (`R51`, `§10.4:479–513`). Opening quote `_openingBondQuote` at `UniswapV4DetfCommon.sol:258–263` matches Q(x). Duration multiplier applied once; no stacked mint `1+p` (`:284–289`). Full-book additional legs required. Zero-interest first book must not relabel principal as yield (`A35`).

**Engineering:** map NET/sNET/USDG/PLP/SE into rated Weighted legs; nonzero HLP; initial TWAP history vs activation (separate conditions, `§10.4:513`); input cell UNKNOWN in matrix row 02–03 is remaining asset mapping, not whether first bond seeds.

## Maturity / rollover

**Facts.** Three release classes selected (`§10:416–423`). Atomic rollover selected (`R09`, `§11.3–11.4`). Keep YT: Context7 `/websites/pendle_finance` 2026-09-25 and Pendle Chapter 7 confirm SY→mint PT+YT, LP PT+remaining SY, retain YT, no PT buy. Local `ActionAddRemoveLiqV3` cited in PRD E; empty target divides by zero — revert unless a later seed path is approved (`§11.4:577`). Old YT `userInterest` stays on hook address; new SY is not old SY (`§11.1`). Native wrapper exception and non-blocking matured positions are settled.

**Engineering:** settlement order, old-SY conversion, successor allocation, residual access, gas, reentrancy-safe intermediate book. **Owner-shaped leftover:** empty-target policy (revert-only vs later seed) if not already “revert unless separately specified.”

## Interfaces

**Facts.** ERC-4626 `deposit`/`mint` MUST exchange assets for newly issued shares ([EIP-4626](https://eips.ethereum.org/EIPS/eip-4626), fetched 2026-09-25). Owner selected deposit-side *existing-token swap* and expressly declined certification (`R37`, `§7.4:334`). That is a product choice, not a standards proof. `redeem` = exact shares in; `withdraw` = exact assets out; `convertTo*` vs `preview*` vs `max*` remain implementation obligations (`A16`). SY DETF-as-shares differs from Universal separate raw wrapper. Contraction eligibility P≥1 swap / P<1 burn is settled; **authoritative P** is still UNKNOWN in matrix policy 3 (`OPERATION_MATRIX.md:65`) and O02 remaining.

**Do not invent** `minAmountOut` on ERC-4626 signatures. Exact-output inverse is an engineering gate.

## External dependencies

**Facts.** NET tax predicates match `INET.sol:31–77`; tax 500 bps (`Constants.sol:32`); queued vs active exemption (`:41,68–77`). Pair `0x59F95461…` on 4663 is named, not live-verified (`PRD:344`). BondDepository `deposit(..., to)` and `redeem` looping `notes[msg.sender]` (`BondDepository.sol:104–153`) confirm unsolicited-note liveness gate. `BOND_VEST = 2 days` (`Constants.sol:76`); `GENESIS_VEST = 5 days` (`:54`) explains historical five-day prose. NET epoch 8 hours (`:17`) is NetNet’s clock, not D50’s first-bond wall clock. WeightedMath pragma `^0.8.24`, 30% in/out ratios (`WeightedMath.sol:3–39`); Balancer docs 2026-09-25 confirm those limits. Crane: PkgInit/PkgArgs on interface; never `new`; V4 hooks via registry/hook factory (`crane-architecture`, `indexedex-uniswap-v4-hook-packages`). Salt string `"NET-DETF"` is not singleton proof (`R55`, matrix `:96`).

**Missing live evidence:** deployed pair/code/fees, active Pendle market (prior series expired 2026-09-17 per `PRD:713`), oracle values, gas.

## Acceptance criteria

A01–A45 are strong as a planning test map if companions are updated. Gaps: A40–A45 are not reflected in matrix row 36; A09 cannot be closed by happy paths; A43 vs unbounded compounding needs an explicit evaluation strategy without restoring D52 caps; A16 must document non-conformance rather than claim EIP-4626 compliance.

## Prioritized narrow clarification list

Ask the owner only these. Everything else is engineering or planning.

1. **O01 (blocking):** approve explicit custom-family supersession for configured FoT NET and rebasing sNET, or refuse this family. No exemption campaign. Without this, no implementation plan can be authorized.
2. **Authoritative contraction price P:** confirm whether the ≥1 / <1 branch uses post-expansion owned-reserve synthetic NET/DETF (implied by §9.2) or a different mark. Do not silently reuse expansion TWAP.
3. **TWAP window and invalid-history policy:** approve a duration/band and fail-closed behavior (revert vs skip expansion). Do not treat missing TWAP as below-peg.
4. **Empty successor market:** confirm revert-only for v1, versus a later specified dual SY/PT seed. Do not enable first-bond G/U/B/R as a silent rollover seed.
5. **Non-PENDLE reward tokens:** keep OPEN as “not swept,” or name destinations.
6. **Optional, only if owner wants a product control:** additional contraction eligibility beyond P<1. PRD forbids inventing hysteresis/caps.

**Not owner questions:** Weighted input mapping; V2 SE selector matrix; note-array custody design; native `1.005^n`; bond min-duration vs next-epoch; exact-output inverse; salt encoding; hook-package wiring; historical-series Repo; fee percentages.

## Facts / inference / speculation

| Kind | Claim |
| --- | --- |
| Fact | v0.17 settles 0.5% compounded, current-TWAP catch-up, balance-derived rebasing. |
| Fact | Matrix/Q7 tracker lag those settlements. |
| Fact | Current law forbids FoT/rebasing underlyings; O01 is unresolved authority. |
| Fact | Bond math source lines cited in PRD E15–E16 match this snapshot. |
| Fact | Keep YT semantics match Pendle docs 2026-09-25. |
| Fact | Native bond vest is 2 days in vendored Constants; redeem is aggregate. |
| Inference | Planning should update matrix row 36 and Q7 before an impl plan, or the plan will re-litigate settled economics. |
| Inference | Hook DFPkg must follow V4 hook-registry path, not monomorph CREATE3. |
| Speculation | Peg support and unbounded catch-up solvency are unproven; A12/A17 remain real. |

## Counterarguments

- “v0.17 is enough to plan.” Partial: economic rate/base/custody model is specified enough to *scope* a plan, but O01, TWAP policy, owned-book mapping, and matrix lag would cause the plan to invent product. Better: freeze companions, then plan.
- “Ask owner for expansion caps.” Reject: D52 + A43 + R52 already forbid restoring caps.
- “Require ERC-4626 certification.” Reject: owner closed this in v0.11.
- “Linear bond claim can be copied.” Reject: `DETFFundedStakingMath._claim` is incompatible with cliffs.

## Missing evidence / tool limits

- No forge/tests/forks/live 4663 reads.
- Context7 Pendle ID `/websites/pendle_finance`; Balancer `/llmstxt/balancer_fi_llms-full_txt`; ERC-4626 via EIP fetch. Context7 had no first-class EIP-4626 library ID.
- Did not re-read entire `DETF_ALIGNMENT_PRD.md` §24.7 or exhaustive V2 SE facet list; E14 already says parity matrix is incomplete.
- Did not open `KEEP_YT_ROLLOVER_RESEARCH.md` body beyond PRD citation.
- No peer-artifact reads. Skill tool / `call_omo_agent` not used.
- Unpinned local Pendle/Net snapshots; no code hashes.

## Confidence

- **High** that v0.17’s rate/TWAP/rebasing/custody selections are captured and should not be reopened.
- **High** that O01, TWAP window/invalid policy, and authoritative P are the only narrow owner leftovers besides empty-target/other-rewards.
- **High** that the design is not implementation-authorized (`PRD:9,14,883`).
- **Medium** that matrix lag is the main clarity defect vs hidden product contradictions.
- **Low/none** on solvency, peg, gas, live market, or note-array liveness.

**Handoff:** update matrix + Q7 to v0.17; obtain O01; then a separately authorized plan can pin sources, map A01–A45, and specify engineering gates. This review authorizes none of that work.
