# Kimi K3 — Independent review: UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md

**Date:** 2026-09-27 · **Researcher:** Kimi K3 (independent first pass; no peer artifacts read)
**Object:** `docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md` ("the PRD"), reviewed for consistency, quality, and readiness to write an implementation plan.
**Method:** Read CLAUDE.md, canonical pretransfer law, DETF alignment D57–D59/§24.7.1, the co-located older V4 SE PRDs, and the current V4 SE code; verified the PRD's upstream Universal Router claim against primary sources.

---

## 1. Verdict

The PRD is internally consistent, unusually precise for a requirements document (formulas, worked examples, acceptance list), and **close to implementation-plan ready**. It correctly defers solver/parameter mechanics to engineering (§14) and respects all settled owner decisions (pretransfer, direct PoolManager, deployer hook assurance, immediate repeated rebalances, full booking). I found **no true blocker**. A small number of cheap owner-confirmation questions remain (§4); everything else is engineering specification that planning can safely own.

## 2. Verified consistencies (facts, with code/law evidence)

| PRD clause | Evidence | Status |
|---|---|---|
| §4 PoolManager idle/in-session gate | `UniswapV4StandardExchangeCommon.sol:315-317` (`canOpenPoolManagerUnlock = !TransientStateLibrary.isUnlocked`); old Local Liquid Buffer PRD D1/D2 | Matches code and law |
| §4 blocked withdrawals cover-or-revert | `UniswapV4StandardExchangeInBase.sol:154-167` (`InsufficientLocalReserve` when free < quoted) | Matches |
| §6.3 proportional mint `min(S*C0/B0, S*C1/B1)` | `UniswapV4StandardExchangeCommon.sol:700-705` (existing dual-token branch) | Formula already exists |
| §5 deadband = max(abs floor, 5% of targetFree) | `UniswapV4StandardExchangeCommon.sol:306,353-379` (`LIQUID_RESERVE_RELATIVE_TOL_WAD = 0.05e18`) | Matches |
| D3 live oracle %, stored-zero fallthrough | `VaultFeeOracleManagerFacet.sol:178-204`; old PRD §5.1/D8 (three-tier cascade, stored 0 = unset) | Surface exists; no new knob needed |
| §5 `targetFree = floor(T*p/(1e18+p))` ≡ `F = p*D` at equilibrium | Algebra checks; worked example (100/40 → 116⅔/23⅓) recomputed | Internally consistent; T-formula is placement-stable (T invariant under placement) |
| §10 Universal Router V4 PM command rejects increase/decrease/burn | Verified against upstream `main` 2026-09-27: `Dispatcher.sol` `V4_POSITION_MANAGER_CALL` → `_checkV4PositionManagerCall` in `V3ToV4Migrator.sol` reverts `OnlyMintAllowed()` for `INCREASE_LIQUIDITY`, `INCREASE_LIQUIDITY_FROM_DELTAS`, `DECREASE_LIQUIDITY`, `BURN_POSITION` | PRD claim accurate |
| §15 compiler claim (solc 0.8.35, runs 1, no via-IR) | `foundry.toml:29-36` | Matches |
| §3 preserved requirements vs DETF law | `DETF_ALIGNMENT_PRD.md` D57–D59, §24.7.1 (lines 1153-1163): full-range, exact position math + sleeve + fees once, two-token activation, single-token deposits after | No conflict |
| §11 pretransfer law restatement | `docs/vaults/BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_PRD.md` §1.1/§4 + APEX 2026-09-17 D9 | Faithful; nothing reopened |

## 3. Intentional deltas from current code the plan must implement (facts; PRD wins per §3)

1. **Sleeve semantics change.** Current code computes `targetFree_i = total_i * pct / 1e18` (percent of *total*; `UniswapV4StandardExchangeCommon.sol:349-351,755-756`; old Local Liquid Buffer PRD D17/§5.2). New D3 = percent of *owned deployed principal*. Plan must change `_targetFree`/`_loadRebalanceSnap` and review `actualLiquidReservePercentage` (`UniswapV4StandardExchangeLiquidReserveTarget.sol:69-83`, currently free/total).
2. **Deposit route rebuild.** Current single-token zap-in does **no** composition swap; it mints against free+deployed totals using the single-sided invariant-growth branch (`UniswapV4StandardExchangeInBase.sol:273-315`; `UniswapV4StandardExchangeCommon.sol:706-712`). New D4/D5 require composition swap → allocation → proportional mint, and §6.3 forbids silently falling back to the invariant-growth formula. Quote surfaces (`_previewZapInDeposit`, InBase.sol:256-266) must model the swap.
3. **Rebalance swaps.** Current `_rebalanceLiquidReserveInternal` is add/remove-liquidity only ("no swaps", Common.sol:731-732 doc; old PRD D28). New D9 permits bounded swaps of vault-owned imbalanced inventory — a **direct textual conflict** with old Local Liquid Buffer PRD D28, which remains in the repo until the separately authorized docs reconciliation (PRD §3). Plan must design the swap step, funding leg, and progress metric.
4. **Local snapshot defect (validates §12).** Current `_secureTokenTransfer` derives `faceBooked = R − deployed` with *live repriced* deployed amounts (Common.sol:1281-1284). When price moves so deployed(token) grows, `faceBooked` shrinks — and the clamp `R > deployed ? R − deployed : 0` can zero it, making the **entire live sleeve balance claimable as "unbooked"** via `pretransferred=true`. This is exactly the "position repricing must not manufacture local pretransfer credit" hazard §12 names. Plan must introduce durable local face snapshots distinct from economic totals (§12 items 1–4).
5. **Missing contract-caller guard.** No `EOAPretransferNotAllowed`/`LocalCreditLib.requirePretransferCaller` anywhere on the V4 SE pretransfer paths (`UniswapV4StandardExchangeInTarget.sol:56,64,71`; Common.sol:1270-1330; grep for `extcodesize|EOAPretransfer|LocalCreditLib` in `contracts/protocols/dexes/uniswap/v4/` → nothing). Settled APEX 2026-09-17 D9 and PRD §11/D15 require the contract-only guard. Plan must add it (engineering execution of settled law, not an owner question).
6. **Self-share booking deviation (document, don't redesign).** `_syncVaultReserves` books `vaultShare` self-balance (Common.sol:609-612) while canonical hold-set law excludes the share token (pretransfer PRD L-RSRV-HOLD-SET). The V4 package uses this deliberately for E6/I1 leftover protection (`_secureShareDelivery`, Common.sol:1313-1330). Canonical PRD §4.4 allows per-package documented exceptions; the plan should document this one.
7. **Decision-ID collision.** New PRD D1–D16 collide with older D-numbers embedded in code NatSpec and the co-located PRDs (e.g., code D22 = deadband; old D10 = permissionless rebalance reverting when blocked; new D10 = immediate repeated rebalances). High confusion risk for implementers. Plan should cite new decisions with a distinguishing prefix and include an ID map. Documentation hygiene, not an owner question.

## 4. Owner questions vs engineering items

### 4.1 Recommended owner-confirmation questions (few, cheap)

- **Q1 (P1).** §9: "The owner accepted protection generally and *most* suggested values." Which (if any) of the four working defaults — 25 bp rebalance impact, 50 bp deposit-composition impact, 10 bp fee-inclusive-quote shortfall, 1 bp alignment — was **not** accepted? Recommend confirming the table as accepted constants so calibration-sensitive acceptance tests (#10, #11) have fixed targets.
- **Q2 (P2).** D12 stops rebalance trades when "both proportionality and sleeve thresholds are satisfied," but no numeric **proportionality satisfaction band** is defined (the sleeve has the D22 deadband; proportionality has nothing). Recommend adopting the accepted 1 bp alignment tolerance plus the absolute token floor as the rebalance proportionality deadband — needed to satisfy §8's "avoid pointless fee-generating churn" and acceptance #8. Owner ratification avoids late churn; otherwise planning will default to this.
- **Q3 (P2, optional).** Old Local Liquid Buffer PRD D24 locked preview == execution for the user path. The new PRD preserves route authorization/min-output but does not restate preview parity for composition-swap deposits. Recommend planning assume parity **is** required (hooks/consumers quote off these views, and §10 forbids inaccurate vanilla quotes); flag only if the owner intends otherwise.

### 4.2 Safely engineering (per PRD §14 and CLAUDE.md non-negotiables)

Protection-parameter storage/authority (constants on CREATE3 facets or fee-oracle fields — PRD forbids overloading the sleeve % and forbids new admin ownership on immutable vaults); solver fixed-point for D5's post-swap ratio (swap size ↔ post-swap incumbent ratio is a monotone fixed point; bounded iteration); rounding/zero-denominator handling (§7 already mandates); single vs batched unlock sessions for swap+add; rebalance swap funding leg and holder-funded attribution (§14); native/WETH composition handling (§3 preserved behavior); events for residual disclosure (D8); full test matrix incl. adversarial cross-mode cycles (acceptance #16); consumer impact review (Multi routes, imports, DETF nested SE, SY).

## 5. Quality assessment

**Strengths:** decisions D1–D16 are crisp and testable; formulas are given in WAD with worked examples; §9's "price, not sqrt-price" and "don't double-count fee-inclusive quotes" notes prevent real implementation errors; acceptance list maps 1:1 to product law; §15 honestly labels upstream `main` as non-pinned.

**Weaknesses:** (a) decision-ID collision with existing code comments (§3.7 above); (b) §9's "most suggested values" hedge (Q1); (c) undefined proportionality satisfaction band (Q2); (d) preview parity unstated (Q3); (e) dual-token deposit surface (`_executeZapInDualDeposit`, InBase.sol:338-377; old D45) is not explicitly addressed — presumably unchanged, plan should state so.

## 6. Facts vs inference vs speculation

- **Facts:** everything in §2 and §3 items 1–6 (direct code reads and primary-source fetches, 2026-09-27).
- **Inference:** that the faceBooked derivation (§3.4) is exploitable as booked-inventory free credit after favorable price moves (mechanics verified; exploit magnitude depends on sleeve size/oracle target); that planning can default Q2/Q3 as recommended without owner harm.
- **Speculation:** none relied upon.

## 7. Evidence gaps and confidence

- Did not enumerate the `exchangeInMulti` dual-deposit surface or its tests (minor; plan-scope enumeration).
- Did not inspect `UniswapV4QuoteService`/`_supportsProjectedHook` internals for hook-adjusted quote accuracy (engineering; §10 already covers).
- `_checkV4PositionManagerCall` verified on upstream `main` as of 2026-09-27; like the PRD, this is not a deployed-version pin.
- Confidence: **High** on code-evidence findings and PRD-internal consistency; **high** on the upstream UR claim (verified primary source); **medium-high** on the owner-question framing (Q1 may resolve to "all four accepted").

## 8. Bottom line

Ready for implementation planning. No owner blockers; three confirmation questions (Q1 priority). The plan's heavy lifting is engineering: composition-swap solver, durable local snapshots replacing the repricing-vulnerable `R − deployed` derivation, the missing contract-caller guard, sleeve-semantics change, and rebalance swap design — all within the PRD's stated scope and settled law.
