# Test Coverage Audit — T-se-univ4-aave-balancer

| Field | Value |
|-------|--------|
| Date | 2026-08-09 |
| Agent / run | Stage 1 area subagent · full · `T-se-univ4-aave-balancer` |
| Status | **COMPLETE** |
| Production paths | `contracts/protocols/dexes/uniswap/v4/**`; `contracts/protocols/lending/aave/**`; `contracts/protocols/dexes/balancer/**` (SE routers primary; buffer pools + rate providers secondary) |
| Test paths | `test/foundry/spec/protocol/dexes/uniswap/v4/**`; `test/foundry/spec/protocol/lending/aave/**`; `test/foundry/spec/protocol/dexes/balancer/v3/**`; `test/foundry/spec/protocols/dexes/balancer/v3/pools/**`; fork: `test/foundry/fork/base_main/{aave,balancer}/**`, `test/foundry/fork/eth_main/aave/**` |
| Skills / PRD version cited | `TEST_COVERAGE_AUDIT_PRD.md` (§2 layers/catalog, §2.3 SE + Router P0, §2.4 PAT-*, §3.8 Blocker proof, §7.2 schema); SE P0 (A1, C, E1, E5, H3, F, **I1–I3**, **J1–J3**, **K1**, H, N, D, P); Router P0 (signature/allowance, **I5**, exact fail, H, N); good-pattern ref `ERC4626StandardExchangeCommon._securePull` |
| Finding ID prefix | `TCA-SE-UAB-NNN` |
| Runtime proofs | **Not executed this subagent** — PAT-I-ABS free mint/extract labeled **RUNTIME_UNPROVEN** (static overwhelming on Uni V4 + Aave Stata + CrossVersion); orchestrator O3 owns hermetic proof |
| Cross-area deps | PAT-I-ABS root also in `BasicVaultCommon` (`T-basic-protocol-commons` / `WP-I-COMMON-001`); Uni V4 is a **local clone**, not inheritance; Aave Stata In uses **inline** `if (!pretransferred)` (no delta) |

---

## 1. Executive summary

### Maturity scores by product (0–5)

| Product | Score | One-line rationale |
|---------|------:|--------------------|
| **Uniswap V4 SE** | **3** | Strong H/P + liquid-buffer suite + CREATE3/manager deploy + partial J1 (IFacet for In/Out/Query/Import); **PAT-I-ABS local clone**; **I1–I3 absent** (theater pretransfer only); no SE adversarial catalog; no LiquidReserve IFacet; **no SE-native fork P0** |
| **Aave V3.6 Stata SE** | **2** | Real hermetic + fork preview≡exec; route H/P/L1 present; deploy gold; **PAT-I-ABS free share mint on pretransfer In** (no balance check); mock unit suite is PAT-MOCK periphery; **no I / J / adversarial / K1** |
| **Aave CrossVersion Loop** | **2** | E2E deposit/out/rebalance + service unit math; registry deploy path; **pretransfer skips pull with no delta**; no I/J/adversarial catalog; no fork |
| **Balancer V3 SE Router** | **4** | Broad H/N/P hermetic + Base fork; **strong prepay-auth adversarial + L1 fuzz + L3 handler**; Permit2/query-abuse/deadline/slippage; formal `*_IFacet_Test` sparse (functional J via deploy) |
| **Balancer SE Buffer pools** (constProd / multiPair / mixed / commonBuffer) | **4** | Spec + adversarial P0 + invariants/handlers on major pool families; rate-provider edge cases; not SE vault `pretransferred` surface |
| **Balancer rate providers (wrapped SE)** | **2** | Thin smoke/deploy; not money router; J partial |

### Blocker / High counts

| Severity | Count | Notes |
|----------|------:|-------|
| **Blocker** | **2** | `TCA-SE-UAB-001` Uni V4 PAT-I-ABS free credit/extract; `TCA-SE-UAB-002` Aave Stata pretransfer free **share mint** (stata→SE and absolute inventory claim) — both **RUNTIME_UNPROVEN** |
| **High** | **9** | Missing I1–I3 (Uni V4 + Aave + CrossVersion); PAT-THEATER-PRE; Aave no J; Uni V4 adversarial + LiquidReserve J gap; CrossVersion PAT-I-ABS clone; Aave mock-unit theater; router formal J/declaration depth; K1 donation on SE deposit routes |
| **Medium** | **6** | Uni V4 fork P0 parity; bare `expectRevert` on router batch; Aave CrossVersion L1+; buffer deferred stale-rate/reentrancy cases; rate-provider depth; N exact-selector hygiene Aave |
| **Low / Info** | **4** | Router prepay auth gold-ish; buffer L3 strength; Uni V4 deploy quality; ERC4626 `_securePull` good-pattern ref |

### Top 5 recommended WPs

| Priority | WP-ID | Title |
|---------:|-------|-------|
| 1 | **WP-I-CLONE-UAB-001** | Align Uni V4 `_secureTokenTransfer` + Aave Stata In pretransfer + CrossVersion In to **delta-only** credit (match `ERC4626StandardExchangeCommon._securePull`); serial after or parallel to commons `WP-I-COMMON-001` |
| 2 | **WP-I-SE-UAB-001** | I1–I3 adversarial proofs on Uni V4 SE + Aave Stata SE (proxy; free mint/extract cannot succeed) |
| 3 | **WP-ADV-SE-UAB-001** | Uni V4 + Aave Stata SE adversarial suites (A1/C/E5/H3/F + I + K1) on gold TestBases |
| 4 | **WP-J-SE-UAB-001** | Aave In/Out/Marker IFacet + Uni V4 LiquidReserve IFacet + proxy loupe J2–J3 for both SE diamonds |
| 5 | **WP-J-ROUTER-UAB-001** | Formal Target↔facetFuncs declaration tests for Balancer SE Router facets (close PAT-J-CTRL risk) |

### Headline

**This area is split maturity:** Balancer **router + buffer pools** are near gold for H/N/prepay-auth and pool invariants; **Uni V4 SE and Aave Stata SE still fail the ship-gate on I (and partially J)** because:

1. **Uni V4** clones PAT-I-ABS in `UniswapV4StandardExchangeCommon._secureTokenTransfer` (`pretransferred` → absolute `balanceOf >= amount` → `return amountIn`) — free extract on direct swap / zap-in-deposit when inventory/donation exists.
2. **Aave Stata In** is **worse on the free-mint axis**: `if (!pretransferred) transferFrom`; when `pretransferred=true`, **no balance check at all**, then stata→SE mints shares from **claimed** `amountIn` via `_mintStataDeltaAsSEShares` without proving a stata **delta**. Existing reserves or donations become free shares.
3. Happy-path `*_pretransferred_true` / “pretransferred simulation” tests are **PAT-THEATER-PRE** (cannot fail if absolute/claim credit is wrong).
4. **Contrast good pattern:** `ERC4626StandardExchangeCommon._securePull` requires **delta ≥ amountIn** for pretransfer and never treats absolute reserve as deposit.

---

## 2. Product inventory

| Product | DFPkg / key Targets / Facets | TestBase(s) | Test roots | Deploy path quality |
|---------|------------------------------|-------------|------------|---------------------|
| **Uniswap V4 SE** | `UniswapV4StandardExchangeDFPkg`; In + InQuery + Out + PositionImport + LiquidReserve Facets/Targets; Common (local `_secureTokenTransfer`); FactoryService | Co-located `contracts/.../v4/test/bases/TestBase_UniswapV4StandardExchange` | `test/foundry/spec/protocol/dexes/uniswap/v4/**` (Deploy, Routes, LocalLiquidBuffer(+H2), 4× IFacet); **no** SE fork under `fork/**/uniswap/v4` SE (hooks/DETF consumers only) | **Gold:** CREATE3 facets + `vm.prank(owner); indexedexManager.deployUniswapV4StandardExchangeDFPkg(...)` |
| **Aave V3.6 Stata SE** | `AaveV3StataStandardExchangeDFPkg`; In/Out/Marker Facets; Common extends `BasicVaultCommon` (Out uses `_secureSelfBurn`; In **inline** pretransfer) | `contracts/test/bases/TestBase_AaveV3StataStandardExchange` | Hermetic: `test/.../lending/aave/v3.6/{AaveV3StataStandardExchange,AaveV3StataStandardExchange_Real}.t.sol`; Fork: `test/foundry/fork/{base_main,eth_main}/aave/v3.6/**` | **Gold** package deploy; Real/fork use real Stata; **mock unit** uses `vm.mockCall` on stata/pool/oracle |
| **Aave CrossVersion Loop** | `AaveCrossVersionLoopDFPkg`; ExchangeIn/Out + Rebalance + Marker | `TestBase_AaveCrossVersionLoop*` | `test/.../lending/aave/cross-version/**` | Registry E2E path present; facet zero-address cases in DFPkg unit |
| **Balancer V3 SE Router** | `BalancerV3StandardExchangeRouterDFPkg`; ExactIn/Out Swap+Query; Batch ExactIn/Out; Prepay + PrepayHooks; Permit2Witness | Co-located `TestBase_BalancerV3StandardExchangeRouter`; fork `TestBase_BalancerV3Fork(_StrategyVault)` | Spec: `test/.../balancer/v3/routers/**` (+ adversarial prepay + invariant); Fork: `test/foundry/fork/base_main/balancer/v3/**` | **Gold:** CREATE3 + manager/registry style package init |
| **Balancer SE Buffer pools** | StandardExchangeBufferPool; MultiPair; MixedLeg; Common/Mixed Buffer MultiVault stable/weighted pkgs | Per-pool TestBases under `test/.../pools/**` | Spec + adversarial + invariant + comparative + Base fork buffer | Strong production-first fixtures (live SE peers) |
| **Rate providers** | `StandardExchangeRateProvider*`, `WrappedStandardExchangeRateProvider*` | Thin | `WrappedStandardExchangeRateProvider.t.sol` | CREATE3 facet deploy in smoke |

### Trust-flag / pull entrypoints

| Product | API / flag | Pull semantics (static) |
|---------|------------|-------------------------|
| **Uni V4** | `exchangeIn` / `exchangeOut` `pretransferred` | Common: **absolute balance ≥ claimed → return claimed** (PAT-I-ABS). Pull path measures delta only when `!pretransferred`. |
| **Aave Stata** | `exchangeIn` `pretransferred` | **Skip pull if true; no `balanceOf` gate**; mint/deposit uses claimed `amountIn`. Share out: `_secureSelfBurn` (burns from vault if pretransferred; refund leftover shares). |
| **Aave CrossVersion** | `exchangeIn` `pretransferred` | `if (!pretransferred) transferFrom`; then NAV mint from **claimed** `amountIn` — same free-credit class. Out burns from vault if pretransferred. |
| **Balancer Router** | Prepay session / vault settle; calls SE with `pretransferred=true` comments | Router money safety is **session auth + Balancer unlock**, not vault absolute credit. Downstream SE still inherits SE PAT-I-ABS if residual sits on vault. |
| **Good ref** | ERC4626 SE `_securePull` | **Delta ≥ amountIn** for pretransfer; refund overshoot |

### Facet list (money-relevant, static J skim)

| Facet | `facetFuncs` (static) | Notes |
|-------|----------------------|--------|
| Uni V4 In | `exchangeIn`, `unlockCallback` | Preview on **InQuery** facet (split surface — intentional) |
| Uni V4 InQuery | `previewExchangeIn` | Covered by IFacet test |
| Uni V4 Out | `previewExchangeOut`, `exchangeOut` | IFacet test present |
| Uni V4 PositionImport | import selectors | IFacet test present |
| Uni V4 LiquidReserve | canOpen / local / deployed / target% / actual% / rebalance | **No IFacet_Test** |
| Aave Stata In/Out | preview + exchange | **No IFacet_Test** |
| Aave Marker | marker views | **No IFacet_Test** |
| Balancer Router facets | full swap/query/batch/prepay sets | Deployed via DFPkg; **no formal Behavior_IFacet suite** |

### Out of area (reference only)

- Uni V3 SE → prior SE/V3 trees (not this area’s primary allowlist though sibling)
- DualLiquidity / Uni V4 DETF / hooks → `T-detf-dual-liquidity`, `T-hooks-v4`
- `BasicVaultCommon` CODE ownership → `T-basic-protocol-commons`
- Coordinator router `balancerV3-uniswapV4` → `T-routers-permit2` / router area

---

## 3. Layer matrix

Legend: **G** = green/strong · **P** = partial · **F** = fail/missing · **N/A** · **S** = stub/theater

| Product | H | N | D | J | I | K | A–H | P | L1 | L2 | L3 | Notes |
|---------|---|---|---|---|---|---|-----|---|----|----|----|-------|
| Uni V4 SE | G | P | P | P | F | P | F | G | F | F | F | Routes + liquid buffer deep; IFacet×4; no adversarial/I; K via donation dilute note (T4d) not I-extract |
| Aave Stata SE | P | P | F | F | F | F | F | G | P | F | F | Real+fork P strong; mock unit weak; no I/J/adv |
| Aave CrossVersion | P | P | F | F | F | F | F | P | F | F | F | E2E ops; no catalog |
| Balancer SE Router | G | G | P | P | P* | P | P | G | G | P | P | *I5 prepay session strong; not vault I1–I3 |
| Buffer pools (agg.) | G | G | P | P | N/A† | P | P | G | P | P | G | †No SE `pretransferred` flag on pool BPT surface |
| Rate providers | P | F | F | F | N/A | F | F | F | F | F | F | Thin |

---

## 4. Catalog matrix (A–K)

| ID | Uni V4 SE | Aave Stata | CrossVersion | Bal SE Router | Buffer pools | Evidence (or **G**) |
|----|-----------|------------|--------------|---------------|--------------|---------------------|
| **A1** | F | F | F | P | P | Buffer donation cases (no free BPT); router residual clean paths; **G** SE-named A1 for Uni V4/Aave |
| **A3** | F | F | F | F | P | Partial pool donation |
| **B\*** | N/A* | N/A* | N/A* | N/A | N/A | SE no synthetic thresholds |
| **C1–C3** | P | F | F | P | P | Uni V4 liquid-buffer reentrancy T13; router nonReentrant/query gates; Aave **G** |
| **D\*** | N/A | N/A | N/A | N/A | N/A | No claim NFT on these SEs |
| **E1** | P | P | P | G | G | Routes/InOut conservation; router round-trips |
| **E5** | P | P | P | G | P | Uni V4 deadline on In; router deadline suite; Aave deadline present but thin negatives |
| **F1** | F | F | F | P | P | Uni V4/Aave **G** diamondCut block tests; router immutable package |
| **H2** | P | F | F | G | P | Uni V4 H2 liquid-buffer mid-swap; router H2 session clean after fail/success |
| **H3** | P | P | F | G | P | Slippage reverts routes/router; not catalog-named residual matrix for Aave |
| **I1** | F | F | F | N/A‡ | N/A | **No** false-claim without transfer. Theater happy pretransfer only |
| **I2** | F | F | F | N/A | N/A | No short-pretransfer |
| **I3** | F | F | F | N/A | N/A | No residual-reuse second call |
| **I5** | N/A | N/A | N/A | G | N/A | Prepay session auth adversarial + fuzz + invariant |
| **J1** | P | F | F | F | P | Uni V4 4 IFacet tests; LiquidReserve + Aave + Router formal lists **G** |
| **J2** | F | F | F | P | P | No loupe completeness matrix; router deploys facets in practice |
| **J3** | P | P | P | G | G | Specs call **proxy** for routes/router; no FunctionNotFound scan |
| **K1** | P | F | F | P | P | Uni V4 T4d donation dilutes (documented economic); **not** free-mint via I; Aave **G** donation mismatch |

\*B N/A per PRD SE class.  
‡Router I-class is **session/auth (I5)**, not vault pretransfer I1–I3.

---

## 5. Findings

### 5.1 [TCA-SE-UAB-001] Blocker · CODE · PAT-I-ABS / catalog I1 · Uni V4 · RUNTIME_UNPROVEN

- **Summary:** `UniswapV4StandardExchangeCommon._secureTokenTransfer` credits `pretransferred=true` against **absolute** vault `balanceOf` and returns the **claimed** amount. Direct swap and zap-in-deposit then consume that credit — enabling free extract of donated/residual inventory without a matching caller transfer. This is a **local clone** of BasicVaultCommon PAT-I-ABS (not inheritance).
- **Evidence:**
  - `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeCommon.sol` L1072–1080: `if (pretransferred) { if (balanceOf < amountIn) revert; return amountIn; }`
  - Call sites: `UniswapV4StandardExchangeInTarget.sol` L56–69 (`_secureTokenTransfer` then swap/zap).
  - Contrast good: `ERC4626StandardExchangeCommon._securePull` L155–169 (delta ≥ amountIn).
  - Commons report already flags Uni V4 clone (`T-basic-protocol-commons` §2.3 B).
- **Why bar fails:** Free principal extract on money API; ship-gate I1 + PAT-I-ABS.
- **Recommended CODE:** Rewrite Uni V4 `_secureTokenTransfer` to **delta snapshot** (copy ERC4626 `_securePull` semantics); account for free-sleeve / liquid-reserve baseline so sleeve inventory is not claimable as user deposit.
- **Recommended TEST:** `test_I1_exchangeIn_directSwap_pretransferred_true_withoutTransfer_noFreeOut` on **proxy** after donate tokenIn; attacker tokenOut must not increase; vault free inventory unchanged or strict revert. Match-path: `test/foundry/spec/protocol/dexes/uniswap/v4/**` adversarial or Routes.
- **Suggested WP:** `WP-I-CLONE-UAB-001` → `WP-I-SE-UAB-001`
- **Priority:** Wave 0–1
- **Runtime status:** **RUNTIME_UNPROVEN** (static overwhelming). Orchestrator O3: hermetic on `TestBase_UniswapV4StandardExchange` + seeded pool.

### 5.2 [TCA-SE-UAB-002] Blocker · CODE · PAT-I-ABS / free share mint · Aave Stata · RUNTIME_UNPROVEN

- **Summary:** `AaveV3StataStandardExchangeInTarget.exchangeIn` skips `transferFrom` when `pretransferred=true` **with no balance check**. For **stata → SE shares**, it mints via `_mintStataDeltaAsSEShares(amountIn, …)` treating claimed `amountIn` as a stata **delta** without verifying `balanceOf(stata)` increased. Attacker can mint shares against **existing reserves** or prior donations (free mint / dilution theft). Base→SE paths may fail later on deposit if tokens missing, but donated base inventory is still claimable for free entry.
- **Evidence:**
  - In Target L125–128: `if (!pretransferred && amountIn > 0) safeTransferFrom`.
  - Stata→SE L173–175: `_mintStataDeltaAsSEShares(amountIn, recipient, totalAssetsBefore)` with no inbound proof.
  - Unit theater: `AaveV3StataStandardExchange.t.sol` `test_Route_StataToSE` uses `pretransferred=true` **without minting stata to vault** (mock path) — greenwashes free credit.
- **Why bar fails:** Free **share** mint is ship-blocking Blocker class (worse than free swap extract).
- **Recommended CODE:** Require balance **delta ≥ amountIn** (or full `_securePull` / `_secureTokenTransfer` fix) before any route that credits `amountIn`; for stata→SE, mint only measured `balanceOf - totalAssetsBefore` (and require it ≥ claimed if using exact claim).
- **Recommended TEST:** `test_I1_exchangeIn_stataToSE_pretransferred_true_withoutTransfer_reverts`; seed vault with victim stata via honest deposit; attacker claims equal amount with `pretransferred=true`, zero transfer — shares must not increase for attacker.
- **Suggested WP:** `WP-I-CLONE-UAB-001` → `WP-I-SE-UAB-001`
- **Priority:** Wave 0–1
- **Runtime status:** **RUNTIME_UNPROVEN**. Prefer Real harness (`AaveV3StataStandardExchange_Real`) over mock unit.

### 5.3 [TCA-SE-UAB-003] High · CODE · PAT-I-ABS clone · Aave CrossVersion Loop In

- **Summary:** `AaveCrossVersionLoopExchangeInTarget` same pattern: skip pull if pretransferred; mint shares from claimed `amountIn` / depositValue without delta proof.
- **Evidence:** `AaveCrossVersionLoopExchangeInTarget.sol` L56–66.
- **Why bar fails:** Same free-credit class on money path.
- **Recommended CODE/TEST:** Align with delta pull; `test_I1_exchangeIn_pretransferred_noTransfer_reverts` on loop proxy.
- **Suggested WP:** fold into `WP-I-CLONE-UAB-001` + CrossVersion test under `WP-I-SE-UAB-001` or `WP-I-CV-UAB-001`
- **Priority:** Wave 1
- **Runtime:** static CODE High (escalate Blocker if O3 proves free mint)

### 5.4 [TCA-SE-UAB-004] High · TEST · I1–I3 missing (Uni V4 + Aave Stata + CrossVersion)

- **Summary:** No catalog-named or behavioral I1/I2/I3 tests. Adversarial trees absent for these SEs.
- **Evidence:** `rg test_I[123]_` under uniswap/v4 + aave test trees → empty. Only happy pretransfer.
- **Why bar fails:** SE P0 requires I1–I3 when `pretransferred` exists.
- **Recommended TEST:**
  - `test_I1_*_pretransferred_true_withoutTransfer_reverts_orZeroCredit`
  - `test_I2_*_shortPretransfer_reverts`
  - `test_I3_*_residualReuse_secondCall_noFreeCredit`
  - Uni V4: direct swap + zap-in-deposit + exchangeOut share burn
  - Aave: stata→SE + base→SE + SE out burn pretransfer
- **Suggested WP:** `WP-I-SE-UAB-001`
- **Priority:** Wave 1 (can land failing proofs before CODE)

### 5.5 [TCA-SE-UAB-005] High · THEATER · PAT-THEATER-PRE

- **Summary:** Pretransfer “coverage” is happy-path with real transfer (Uni V4 Routes) or mock simulation without proving inbound inventory (Aave unit stata→SE).
- **Evidence:**
  - `UniswapV4StandardExchangeRoutes_Test.t.sol` `test_exchangeIn_zap_pretransferred_true`, `test_exchangeOut_zap_pretransferred_true`
  - `AaveV3StataStandardExchange.t.sol` `test_Route_StataToSE` / `*_Pretransferred` with real or simulated funds already assumed
  - Real suite `testFuzz_Real_SEToStata_Pretransferred` transfers shares first — H-layer only
- **Why bar fails:** PRD I bar: happy pretransfer + real transfer ≠ I1–I3.
- **Suggested WP:** `WP-I-SE-UAB-001`
- **Priority:** Wave 1

### 5.6 [TCA-SE-UAB-006] High · TEST · Aave Stata J1–J3 missing

- **Summary:** No `Behavior_IFacet` / `controlFacetFuncs` tests for Aave In/Out/Marker. No loupe completeness or FunctionNotFound scan on deployed Stata SE diamond.
- **Evidence:** No `*_IFacet_Test` under `test/.../lending/aave/**`. Facet lists appear complete vs Targets **statically**, unproven.
- **Why bar fails:** J is P0 for SE packages.
- **Recommended TEST:** Three IFacet tests + package deploy loupe + proxy smoke for preview/exchange/marker.
- **Suggested WP:** `WP-J-SE-UAB-001`
- **Priority:** Wave 1

### 5.7 [TCA-SE-UAB-007] High · TEST · Uni V4 incomplete J + no SE adversarial

- **Summary:** Uni V4 has declaration tests for In/Out/Query/Import but **not LiquidReserve** (money-adjacent rebalance + reserve views). No catalog adversarial suite (A1/E5/H3/F/I/K). Liquid-buffer suite covers product-specific H/C/H2/H4 but is **not** a substitute for SE catalog I/J/K free-credit proofs.
- **Evidence:** IFacet files under `uniswap/v4/` (4); zero `adversarial/` dir; LiquidReserveFacet has 6 funcs, no IFacet test.
- **Why bar fails:** J partial; A–H/I P0 incomplete for ship-blocking SE.
- **Recommended TEST:** `UniswapV4StandardExchangeLiquidReserveFacet_IFacet_Test`; `UniswapV4SE_Adversarial.t.sol` on gold TestBase.
- **Suggested WP:** `WP-J-SE-UAB-001` + `WP-ADV-SE-UAB-001`
- **Priority:** Wave 1–2

### 5.8 [TCA-SE-UAB-008] High · THEATER / TEST · PAT-MOCK · Aave unit suite over-relies on mockCall

- **Summary:** `AaveV3StataStandardExchange.t.sol` mocks stata ERC4626/pool/oracle extensively. Vault diamond is real, but routes under mock do **not** count as production-path H for adversarial/I. Real + fork suites mitigate but are narrower (preview match focus).
- **Evidence:** L30–82 mockCall surface; vs `_Real` + fork PreviewMatch.
- **Why bar fails:** PRD PAT-MOCK / production-first — mock periphery tests cannot close I/K.
- **Recommended TEST:** Move security cases to Real/fork TestBases only; keep mock for marker smoke if needed.
- **Suggested WP:** `WP-ADV-SE-UAB-001` / `WP-H-AAVE-UAB-001`
- **Priority:** Wave 1–2

### 5.9 [TCA-SE-UAB-009] High · TEST · K1 donation free-credit linkage (Aave + Uni V4)

- **Summary:** Aave lacks donation→next-deposit / donation→pretransfer extract cases. Uni V4 documents donation dilutes share price (`test_T4d_donationDilutesSharePrice`) — good economic honesty — but does not prove donation cannot be **extracted as swap out via I1**.
- **Evidence:** T4d liquid-buffer; Aave trees no donation expect.
- **Recommended TEST:** K1 honest deposit after donation (share price); pair with I1 extract negative.
- **Suggested WP:** `WP-ADV-SE-UAB-001`
- **Priority:** Wave 1–2

### 5.10 [TCA-SE-UAB-010] High · TEST · Balancer Router formal J declaration gap

- **Summary:** Router has excellent functional coverage on deployed diamonds but **no** Target-derived `controlFacetFuncs` IFacet suite per facet. PAT-J-CTRL risk if Target gains money selector without facetFuncs.
- **Evidence:** `rg controlFacetFuncs` under balancer router tests → harness-only; no `*_IFacet_Test.t.sol`.
- **Why bar fails:** J1 declaration bar incomplete (severity High for money router; functional J3 partial mitigates).
- **Recommended TEST:** One IFacet test per production router facet (or single package surface matrix from interface list).
- **Suggested WP:** `WP-J-ROUTER-UAB-001`
- **Priority:** Wave 2

### 5.11 [TCA-SE-UAB-011] Medium · TEST · Uni V4 SE-native fork P0 missing

- **Summary:** No `FOUNDRY_PROFILE=fork` suite for Uni V4 SE vault itself (Base PM + production pools). Hooks/DETF fork consumers ≠ SE P0. Per L-TCA-5 fork gaps equal hermetic when product is fork-first; Uni V4 is hermetic-first today — still Medium until product law says Base launch requires fork SE.
- **Suggested WP:** `WP-FORK-U4-UAB-001` or DEFER with owner chain decision
- **Priority:** Wave 2–3 / NEEDS_OWNER

### 5.12 [TCA-SE-UAB-012] Medium · TEST · Router batch bare expectRevert

- **Summary:** Some batch/Permit2 negatives use bare `vm.expectRevert()` (BatchExactIn/Out, Permit2). Prepay auth suite is selector-strong — uneven N hygiene.
- **Evidence:** `BalancerV3StandardExchangeRouter_BatchExactIn.t.sol` L404+; Permit2 suites.
- **Suggested WP:** `WP-N-ROUTER-UAB-001`
- **Priority:** Wave 2

### 5.13 [TCA-SE-UAB-013] Medium · TEST · Buffer deferred adversarial cases

- **Summary:** Buffer adversarial docs defer stale-rate sandwich (Case 1) and reentrant SE (Case 4) to mock SE — currently DEFER with reason. Still score Medium until ship gate for buffer launch.
- **Evidence:** `Behavior_StandardExchangeBufferPool_Adversarial.sol` deferred Cases 1/4.
- **Suggested WP:** `WP-ADV-BUFFER-UAB-001` or DEFER
- **Priority:** Wave 3 / product launch gate

### 5.14 [TCA-SE-UAB-014] Medium · TEST · CrossVersion L1–L3 + I/J depth

- **Summary:** CrossVersion has E2E and pure service unit math; no fuzz/invariant on leverage NAV conservation; no I/J.
- **Suggested WP:** `WP-L1-CV-UAB-001`
- **Priority:** Wave 3

### 5.15 [TCA-SE-UAB-015] Low · Info · Balancer Router prepay-auth is gold-comparable for I5

- **Summary:** `Adversarial_PrepayAuth`, PrepayAuth fuzz/sequences, L3 handler invariants (`invariant_I_AUTH_*`, session inactive) — strong router ship-gate for prepay steal. Do not regress.
- **Priority:** none (maintain)

### 5.16 [TCA-SE-UAB-016] Low · Info · Uni V4 / Aave / Router deploy path quality good

- **Summary:** CREATE3 + manager registry DFPkg deploy on primary TestBases. No MockStandardExchange as SUT for Uni V4/Router. Aave mock is periphery-only.
- **Priority:** none

### 5.17 [TCA-SE-UAB-017] Low · Info · Good-pattern reference `_securePull`

- **Summary:** `ERC4626StandardExchangeCommon._securePull` is the Wave-0 target shape for Uni V4 clone + Aave In (delta-only; no absolute reserve credit).
- **Priority:** reference for `WP-I-CLONE-UAB-001`

---

## 6. Theater list

| Test / control | Why theater | Fix |
|----------------|-------------|-----|
| Uni V4 `test_exchangeIn_zap_pretransferred_true` / Out mirror | Real transfer first; cannot catch absolute-balance free credit | Add I1 false-claim no-transfer |
| Aave `test_Route_StataToSE` pretransferred=true without funding vault stata | Proves free mint works under mocks or assumes ambient inventory | Fail under honest Real fixture; add I1 |
| Aave unit suite heavy `vm.mockCall` on stata/pool | Security-looking routes without real reserve math | Prefer Real/fork for I/K/H security |
| Uni V4 IFacet controls mirror Facet lists only | PAT-J-CTRL if incomplete (LiquidReserve omitted entirely) | Target/interface-derived controls + LiquidReserve test |
| Router bare `expectRevert` batch/Permit2 | Any revert passes | Typed selectors |
| Buffer “adversarial” rate=0 via mockCall on rate provider | Valid for rate edge; not SE trust-flag I | Keep; don’t count as I1 |
| Aave fork/Real preview-match only as “security complete” | Strong P layer; not A–K/I/J | Add adversarial + I suites |

---

## 7. Prior-report diff

| Claim (doc) | Status now (2026-08-09) |
|-------------|-------------------------|
| **ADVERSARIAL_VAULT_COVERAGE_GAP_REPORT** lists Aave Stata TestBase, no adversarial suite | **Still gap** — still no Aave/Uni V4 SE adversarial catalog files |
| **FUZZ_INVARIANT** cites Aave L1 + Balancer router L1 | **Still true** — Aave fuzz exists; router PrepayAuth L1/L3 strong; Uni V4 SE L1 still weak |
| **T-basic-protocol-commons** flags Uni V4 local PAT-I-ABS clone + Aave `_secureSelfBurn` inheritance | **Confirmed** this area; Aave **In** free-mint escalated to area Blocker (beyond Out burn) |
| **NEGATIVE_TEST** pretransfer UX notes | **Still open** as I-class for Uni V4/Aave |
| Struct-audit I/J/K supersession (L-TCA-4) | This report **owns** Uni V4 / Aave / Balancer-router I/J TEST+CODE WPs for this partition |
| Buffer pool plans (MultiPair/Mixed adversarial plans) | **Partial close** — P0 adversarial + L3 exist for major families; deferred cases remain |

---

## 8. Work package stubs

### WP-I-CLONE-UAB-001

| Field | Value |
|-------|--------|
| **Title** | Delta-only secure pull for Uni V4 Common + Aave Stata In + CrossVersion In |
| **Severity** | Blocker |
| **Class** | CODE |
| **Products** | Uni V4 SE, Aave Stata SE, Aave CrossVersion Loop |
| **Finding IDs** | TCA-SE-UAB-001, 002, 003 |
| **Problem** | Absolute/claim pretransfer credits free inventory → free extract or free share mint. |
| **Production files** | `UniswapV4StandardExchangeCommon.sol`; `AaveV3StataStandardExchangeInTarget.sol` (+ helpers); `AaveCrossVersionLoopExchangeInTarget.sol` |
| **Test files** | paired with WP-I-SE-UAB-001 |
| **Out of scope** | `BasicVaultCommon` body (commons WP) unless shared helper extracted |
| **Depends on** | Prefer after or with `WP-I-COMMON-001` for shared helper; Uni V4 can land independently |
| **Parallelizable with** | J WPs; router WPs |
| **Suggested worktree** | `gap_cover_i-clone-uab` |
| **Implementation notes** | Copy `ERC4626StandardExchangeCommon._securePull` semantics; Uni V4 must exclude liquid-reserve sleeve from claimable free inventory or snapshot free-before correctly |
| **Acceptance** | I1 free mint/extract fails; hermetic Real Aave + Uni V4 Routes green |
| **Anti-theater** | I1 without attacker transfer; balances assert no profit |
| **Estimate** | M–L |

### WP-I-SE-UAB-001

| Field | Value |
|-------|--------|
| **Title** | I1–I3 proofs Uni V4 + Aave Stata (+ CrossVersion) |
| **Severity** | High (Blocker until CODE green) |
| **Class** | TEST |
| **Products** | Uni V4 SE, Aave Stata SE, CrossVersion |
| **Finding IDs** | TCA-SE-UAB-001–005, 009 |
| **Problem** | No false-claim / short / residual-reuse coverage; theater happy pretransfer only. |
| **Test files** | new adversarial under `test/foundry/spec/protocol/dexes/uniswap/v4/adversarial/**` and `.../lending/aave/**/adversarial/**` |
| **Depends on** | CODE WP for green; can land failing first |
| **Suggested worktree** | `gap_cover_i-se-uab` |
| **Acceptance** | `forge test --match-path '…/adversarial/**' --match-test 'test_I'` green after CODE |
| **Anti-theater** | I1 no transfer; I2 short; I3 second call |
| **Estimate** | M |

### WP-ADV-SE-UAB-001

| Field | Value |
|-------|--------|
| **Title** | Uni V4 + Aave Stata SE adversarial catalog (A1/C/E5/H3/F + K1) |
| **Severity** | High |
| **Class** | TEST |
| **Finding IDs** | TCA-SE-UAB-007, 008, 009 |
| **Problem** | No SE adversarial suites for these products. |
| **Depends on** | none for A/E/H/F; I depends WP-I-SE-UAB-001 |
| **Suggested worktree** | `gap_cover_adv-se-uab` |
| **Acceptance** | Named catalog tests on production proxies; typed reverts |
| **Estimate** | M |

### WP-J-SE-UAB-001

| Field | Value |
|-------|--------|
| **Title** | Aave IFacet suite + Uni V4 LiquidReserve IFacet + proxy loupe J2–J3 |
| **Severity** | High |
| **Class** | TEST (CODE if omission found) |
| **Finding IDs** | TCA-SE-UAB-006, 007 |
| **Suggested worktree** | `gap_cover_j-se-uab` |
| **Acceptance** | Controls Target-derived; loupe non-zero; proxy callable |
| **Anti-theater** | J3 on **proxy**, not facet impl |
| **Estimate** | S–M |

### WP-J-ROUTER-UAB-001

| Field | Value |
|-------|--------|
| **Title** | Balancer SE Router formal facet declaration matrix |
| **Severity** | High |
| **Class** | TEST |
| **Finding IDs** | TCA-SE-UAB-010 |
| **Suggested worktree** | `gap_cover_j-router-uab` |
| **Acceptance** | All money selectors ⊆ facetFuncs ⊆ loupe ⊆ proxy |
| **Estimate** | M |

### WP-N-ROUTER-UAB-001

| Field | Value |
|-------|--------|
| **Title** | Typed exact selectors for batch/Permit2 negatives |
| **Severity** | Medium |
| **Class** | TEST |
| **Finding IDs** | TCA-SE-UAB-012 |
| **Estimate** | S |

### WP-FORK-U4-UAB-001

| Field | Value |
|-------|--------|
| **Title** | Uni V4 SE Base-mainnet fork P0 smoke (routes + I1 after CODE) |
| **Severity** | Medium |
| **Class** | TEST |
| **Finding IDs** | TCA-SE-UAB-011 |
| **Depends on** | NEEDS_OWNER if hermetic-only is product law |
| **Estimate** | M |

---

## 9. Deferred / N/A / NEEDS_OWNER

| Item | Class | Notes |
|------|-------|-------|
| Buffer Case 1 stale-rate sandwich / Case 4 reentrant SE | DEFER | Documented; needs controlled SE fixture — Wave 3 |
| Uni V4 SE-native fork mandatory? | NEEDS_OWNER | Hermetic strong; fork consumers exist for DETF/hooks |
| Aave CrossVersion production readiness vs Stata priority | NEEDS_OWNER | Still ship-blocking per L-TCA-2 if deployed; score 2 |
| Router I1 on downstream SE residual | DEFER/cross | Owned by SE I WPs; router passes `pretransferred=true` by design when it prepays vaults |
| Permit2 witness full I5 surface | Partial | Covered in router Permit2 suites; deep sig replay may belong `T-routers-permit2` |
| Rate provider deep adversarial | DEFER | Thin smoke OK for non-primary money path |

---

## 10. Commands run

```text
# Inventory
ls contracts/protocols/dexes/uniswap/v4
ls contracts/protocols/lending/aave/{v3.6,cross-version}
ls contracts/protocols/dexes/balancer/v3/{routers,pools,rateProviders}
ls test/foundry/spec/protocol/dexes/{uniswap/v4,balancer/v3}
ls test/foundry/spec/protocol/lending/aave
ls test/foundry/spec/protocols/dexes/balancer/v3/pools
ls test/foundry/fork/base_main/{aave,balancer}

# Pattern hunt
rg -n 'pretransferred|_secureTokenTransfer|_securePull|_secureSelfBurn' \
  contracts/protocols/dexes/uniswap/v4 \
  contracts/protocols/lending/aave \
  contracts/protocols/dexes/balancer/v3/routers --glob '*.sol'
rg -n 'function facetFuncs|controlFacetFuncs' \
  contracts/protocols/dexes/uniswap/v4 \
  contracts/protocols/lending/aave \
  contracts/protocols/dexes/balancer/v3 --glob '*.sol'
rg -n 'test_I[0-9]_|test_A1_|test_J[0-9]_|adversarial|testFuzz_|invariant_' \
  test/foundry/spec/protocol/dexes/uniswap/v4 \
  test/foundry/spec/protocol/lending/aave \
  test/foundry/spec/protocol/dexes/balancer/v3 --glob '*.sol'
rg -n 'function test_' test/foundry/spec/protocol/dexes/uniswap/v4 --glob '*.sol'
rg -n 'function test_' test/foundry/spec/protocol/lending/aave --glob '*.sol'
rg -n 'AaveV3Stata|UniswapV4StandardExchange|BalancerV3StandardExchange' docs/testing --glob '*.md'

# Good-pattern ref
rg -n 'function _securePull' contracts/vaults/standard/erc4626 --glob '*.sol'
```

**Not run:** `forge test` runtime proofs (Stage 1 area subagent; O3 owns Blocker confirmation under `docs/testing/coverage-audit/repro/`).

---

## 11. Return summary (orchestrator)

| Field | Value |
|-------|--------|
| **Status** | **COMPLETE** |
| **Blocker** | **2** — TCA-SE-UAB-001 (Uni V4 PAT-I-ABS extract), TCA-SE-UAB-002 (Aave Stata free share mint); both RUNTIME_UNPROVEN |
| **High** | **9** — I1–I3 gaps; theater; Aave J; Uni V4 adv/LiquidReserve J; CrossVersion clone; Aave mock unit; router formal J; K1 linkage |
| **Top WPs** | WP-I-CLONE-UAB-001 → WP-I-SE-UAB-001 → WP-ADV-SE-UAB-001 → WP-J-SE-UAB-001 → WP-J-ROUTER-UAB-001 |
| **Maturity contrast** | Router/buffer **~4** vs Uni V4 **3** vs Aave Stata **2** |
| **Shared epic link** | Commons `WP-I-COMMON-001` + this area **clone** WP for Uni V4/Aave In (not BasicVaultCommon inheritance on the free-mint path) |
