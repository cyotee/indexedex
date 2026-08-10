# Test Coverage Audit — T-hooks-v4

| Field | Value |
|-------|--------|
| Date | 2026-08-09 |
| Agent / run | Stage 1 area subagent · full · `T-hooks-v4` |
| Status | **COMPLETE** |
| Production paths | `contracts/hooks/**` (all Uni V4 hook diamond packages + shared hook CREATE2 factory) |
| Test paths | `test/foundry/spec/hooks/**`; co-located `TestBase_*` under `contracts/hooks/**`; fork `test/foundry/fork/{base_main,eth_main,robinhood_4663}/hooks/**` |
| Skills / PRD version cited | `TEST_COVERAGE_AUDIT_PRD.md` (§2 layers/catalog, §2.3 **Hook diamond package** P0 subset, §2.4 patterns, §3.8 Blocker proof, §7.2 schema); hook P0: route guards, residual, reentrancy if call-out, **J** full, flag/mining, H, N; when SE `pretransferred` exists also **I1–I3** / free-only gate; `crane-adversarial-testing` A–K |
| Finding ID prefix | `TCA-HOOK-NNN` |
| Focus | Flags, `deployHookVault`, J surface, residual, pretransfer |
| Runtime proofs | **Not executed this subagent** — free-extract CODE labeled **RUNTIME_UNPROVEN** (static overwhelming on CP Single SE path); orchestrator O3 may hermetic-prove on `TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook` |

---

## 1. Executive summary

### Maturity scores by product (0–5)

| Product | Score | One-line rationale |
|---------|------:|--------------------|
| **Hook diamond factory + flags** | **4** | Strong H: flags, salt, premine, registry `deployHookVault`, immutable (no cut), multi-chain fork smoke; weak formal J Behavior_IFacet; stub package OK for factory |
| **OrbitalSwapHook** | **3** | Deploy/flags/liquidity/swap/fees/residual/reentrancy/preview solid; thin adversarial; **no** I (N/A no pretransfer); **no** systematic J; no L1–L3 |
| **WeightedSwapHook** | **3** | Broad H (n=2..4, partial book, rates, fees, Permit2, reentrancy, safety); no formal adversarial catalog file; no J suite; no L1–L3 |
| **Balancer / Curve QuadStableSwapHook** | **3** | Deploy/factory/liquidity/swap/zap/math/rates/safety/reentrancy; safety uses `test_I2_*` for **CL ban** (not trust-flag I); no SE pretransfer; no J matrix |
| **Dual SE BCP Hook** | **2** | Solid deploy/registry/flags + deposit/withdraw/zap/B6/M3 + CL swap P; **M3 pretransfer has no free-balance gate**; **no** I1–I3; **no** adversarial file; **no** J |
| **Single SE CP Hook** | **2** | Good H swap/SE routes + thin adversarial (N1–N4, donation); **Blocker: raw-in `pretransferred=true` free-extracts pair from book** (no free check); no I1–I3; no J |
| **Single SE Buffer (pricing/wrapper)** | **4** | Strongest catalog-shaped adversarial (A/C/E/F/H/B) + routes/fees/fork smoke; no trust-flag I on diamond (SE pull delegated); residual donation idle OK; J still informal |
| **SE Orbital Buffer** | **3** | Deep H (buffer/SE lifecycle/zap/fees/preview) + adversarial free-only pretransfer reverts; bare `expectRevert`; no J; no L1–L3; free-only model (not delta) |
| **SE Weighted Buffer** | **3** | H/fees/B6/partial/scale/fork smoke + adversarial (CL ban, reentrancy, full-book); **free-balance pretransfer** present; **no** named I1–I3 suite; no J |
| **SE Balancer / Curve Quad Stable Buffer** | **3** | H + math/scale/multi-asset + adversarial free-only pretransfer (raw/SE/exchangeOut); fee residual; no J; no L1–L3 |

### Blocker / High counts

| Severity | Count | Notes |
|----------|------:|-------|
| **Blocker** | **1** | `TCA-HOOK-001` — Single SE CP `exchangeIn`/`exchangeOut` with `pretransferred=true` on **raw→pair** path drains SE book without funding (**RUNTIME_UNPROVEN**) |
| **High** | **9** | Dual missing free-pretransfer gate + I tests; CP/Dual missing I1–I3; free-only residual reuse gaps; J1–J3 area-wide; Dual adversarial vacuum; bare expectRevert theater on orbital/dual; CP exchangeOut refund without free proof; weighted SE I suite missing; residual fee vs free-residual documentation |
| **Medium** | **5** | Exact-selector N hygiene; L1–L3 absent all hooks; fork depth uneven; Dual free residual as public free credit (NEEDS_OWNER if intentional); PAT-J interfaceId skew on Weighted SeFacet |
| **Low / Info** | **4** | Factory/deploy path quality generally gold; pure AMM hooks I N/A; fee residual math tested; single buffer adversarial gold peer |

### Top 5 recommended WPs

| Priority | WP-ID | Title |
|---------:|-------|-------|
| 1 | **WP-I-HOOK-CP-001** | **CODE:** Single SE CP free-balance (or delta) gate on `pretransferred`; fix raw-in free extract + exchangeOut refund; hermetic I1–I3 |
| 2 | **WP-I-HOOK-DUAL-001** | **CODE+TEST:** Dual SE BCP `_requirePretransferred` free-only gate + I1–I3 adversarial (mirror orbital/stable SE) |
| 3 | **WP-I-HOOK-SEBUF-001** | I1–I3 suite for Orbital / Weighted / Bal+Curve SE buffers (typed `InsufficientPretransfer`; residual reuse I3) |
| 4 | **WP-J-HOOK-001** | Area-wide J1–J3: Target⊆facetFuncs + loupe + proxy smoke per package (factory flags facet + all product facets) |
| 5 | **WP-ADV-HOOK-001** | Dual + pure AMM adversarial catalog ports (A residual/donation, C reentrancy, F cut, H route guards); exact selectors |

---

## 2. Product inventory

| Product | DFPkg / key Targets / Facets | TestBase(s) | Test roots | Deploy path quality |
|---------|------------------------------|-------------|------------|---------------------|
| **Hook CREATE2 factory** | `UniswapV4HookDiamondPackageCallBackFactory`; `UniswapV4HookFlagsFacet` / `FlagsTarget` / `FlagsRepo`; Create2Lib | `TestBase_UniswapV4HookDiamondPackageCallBackFactory` + stub package | `test/.../hooks/uniswap/v4/factory/**` (+ Base/Eth/Robinhood fork variants) | **Gold:** CREATE3 flags facet; product path Package → `registry.deployHookVault` → factory (Registry.t.sol H15) |
| **OrbitalSwapHook** | `UniswapV4OrbitalSwapHookDFPkg`; Hooks+Liquidity facets; Target; Math; PairPoolLib | Co-located + mirrored `test/.../orbital/TestBase_*` | `test/.../orbital/**`; fork base/eth/robinhood | Package → `deployHookVault` / FactoryService `deployHook` |
| **WeightedSwapHook** | `UniswapV4WeightedSwapHookDFPkg`; Hooks+Liquidity facets | Co-located `TestBase_UniswapV4WeightedSwapHook` | `test/.../weighted/**`; fork | Same |
| **Balancer QuadStableSwapHook** | `UniswapV4BalancerQuadStableSwapHookDFPkg` | Co-located TestBase | `test/.../stable/quad/balancer/**` | Same |
| **Curve QuadStableSwapHook** | `UniswapV4CurveQuadStableSwapHookDFPkg` | Co-located TestBase | `test/.../stable/quad/curve/**` | Same |
| **Dual SE BCP** | Dual DFPkg; Hooks/Deposit/Withdraw/Se facets; Target | `TestBase_UniswapV4DualSEBCPHook` | `test/.../standardExchange/dual/**` | Same; Core asserts `isVault` |
| **Single SE CP** | CP single DFPkg; Deposit/Withdraw/Se facets; SeTarget | Co-located TestBase | `test/.../standardExchange/constantProduct/single/**` | Same |
| **Single SE Buffer (wrapper)** | Single DFPkg; single Facet; Common+Target | Co-located TestBase | `test/.../standardExchange/single/**` + `adversarial/**` + nested fork | Same |
| **SE Orbital Buffer** | Orbital SE DFPkg; Hooks/Deposit/Withdraw/Se facets | Co-located TestBase | `test/.../standardExchange/orbital/**`; fork | Same |
| **SE Weighted Buffer** | Weighted SE DFPkg; Hooks/Liquidity/Se facets | Spec TestBase + DeployLib | `test/.../standardExchange/weighted/**`; fork | Same |
| **SE Balancer Quad Stable Buffer** | Bal SE DFPkg | Spec TestBase + DeployLib | `test/.../standardExchange/stable/quad/balancer/**` | Same |
| **SE Curve Quad Stable Buffer** | Curve SE DFPkg | Spec TestBase + DeployLib | `test/.../standardExchange/stable/quad/curve/**` | Same |

### Trust-flag / pretransfer entrypoints

| Product | API | Gate model | Notes |
|---------|-----|------------|-------|
| Dual SE BCP | `exchangeIn` / `exchangeOut` (`pretransferred`) | **None** — skip `transferFrom` only; buffer needs free face or SE fails | **No** `_requirePretransferred` |
| Single SE CP | same | **None** — raw-in unwraps book without free check | **Blocker** on raw→pair |
| SE Orbital / Bal / Curve SE | same | **Free-only:** `_freeTokenBalance` / book-subtract for raw | Documented peer pattern |
| SE Weighted | same | **Free-only** inline free vs `rawReserves` | Dead-code branch before free check (hygiene) |
| Single SE Buffer wrapper | internal SE calls with flag | Delegates to underlying SE | Diamond not a pretransfer credit surface for free mint |
| Pure AMM hooks (orbital/weighted/quad) | N/A | PM settle path only | I catalog N/A |

### Facet / flags surface (representative)

| Component | `facetFuncs` highlights | Control Target-derived? |
|-----------|------------------------|-------------------------|
| `UniswapV4HookFlagsFacet` | `requiredHookFlags` only | Yes (thin) |
| Dual SeFacet | `preview/exchange` In+Out | Manual 4-sel |
| CP Single SeFacet | hooks + views + SE In/Out + `getHookPermissions` | Manual split `_a`/`_b` |
| SE Weighted SeFacet | SE In/Out only (4); **also declares** `IStandardExchangeMultiAssetLiquidity` interfaceId | Liquidity facet carries multi-asset money APIs |
| Product DFPkgs | ERC20/5267/2612 + MultiAsset vault + product facets; `requiredHookFlags()` pure | Cuts use `FACET.facetFuncs()` |

### Out of area (reference only)

- Underlying SE vaults (Uni V2/V4, ERC4626, etc.) → `T-se-*` areas
- `BasicVaultCommon` PAT-I-ABS epicenter → `T-basic-protocol-commons` (hooks largely **do not** use that pull; local free-only instead)
- Manager registry implementation of `deployHookVault` ACL → `T-manager-fee-registry` (factory/product path still audited here)

---

## 3. Layer matrix

Legend: **G** = green/strong · **P** = partial · **F** = fail/missing · **N/A** · **S** = stub/theater

| Product | H | N | D | J | I | K | A–H | P | L1 | L2 | L3 | Notes |
|---------|---|---|---|---|---|---|-----|---|----|----|----|-------|
| Hook factory | G | P | P | P | N/A | N/A | P | N/A | F | F | F | Flags/salt/premine/registry/immutable; loupe partial |
| OrbitalSwap | G | P | P | F | N/A | P | P | G | F | F | F | Fee residual + donation ignore; thin adv |
| WeightedSwap | G | P | P | F | N/A | P | P | G | F | F | F | No dedicated adversarial file |
| Bal/Curve QuadStable | G | P | P | F | N/A | P | P | G | F | F | F | `test_I2_*` = CL ban not trust I |
| Dual SE BCP | G | P | P | F | F | P | F | G | F | F | F | M3 SE without I; no adv |
| Single SE CP | G | P | P | F | F | P | P | G | F | F | F | **I CODE Blocker** raw pretransfer |
| Single SE Buffer | G | P | P | P | N/A* | G | G | G | F | F | F | Best A–H; *I via underlying SE |
| SE Orbital Buffer | G | P | P | F | P | P | P | G | F | F | F | Free-only I1 partial; bare revert |
| SE Weighted Buffer | G | P | P | F | P | P | P | G | F | F | F | Free gate CODE; I tests missing |
| SE Bal/Curve Buffer | G | P | P | F | P | P | P | G | F | F | F | Named pretransfer tests good |

\*Wrapper diamond does not credit `pretransferred` itself; score I as N/A for diamond, with residual risk if SE peer broken (owned by SE areas).

---

## 4. Catalog matrix (A–K)

| ID | Factory | Pure AMM (orb/wt/quad) | Dual | SE CP | SE Buffer wrap | SE Orb | SE Wt | SE Bal/Crv | Evidence / **G** |
|----|---------|------------------------|------|-------|----------------|--------|-------|------------|------------------|
| **A1** | N/A | P | F | P | G | P | P | P | Single buffer `Adversarial_Donation`; CP N2 donation dilutes; Dual **G** donation→SE swap |
| **A3** | N/A | P | F | P | G | P | F | P | Buffer A3 idle not credited; SE free-only accepts free residual as funding (product model) |
| **B\*** | N/A | P | P | P | P | P | P | P | Fee growth / usage fee suites (not synthetic mint thresholds) |
| **C1–C3** | N/A | P | F | P | G | P | P | P | Reentrancy suites on most products; Dual **G** dedicated C |
| **D\*** | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A | No DETF claim NFT on hooks |
| **E1** | N/A | P | P | P | G | P | P | P | Preview≈exec swap suites common |
| **E5** | N/A | P | P | P | P | P | P | P | Deadline/zero often bare `expectRevert` |
| **F1** | P | P | F | F | G | P | P | P | Factory Immutable no diamondCut; single Access F2; Dual **G** cut test |
| **H2/H3** | N/A | P | P | P | G | P | P | P | Slippage / CL ban / pre-live swap |
| **I1** | N/A | N/A | F | F | N/A | P | F | P | Orbital + Bal/Crv unfunded reverts; Dual/CP **F**; Wt **F** named |
| **I2** | N/A | N/A | F | F | N/A | F | F | F | Short free funding not explicit |
| **I3** | N/A | N/A | F | F | N/A | F | F | F | Residual free reuse second call unproven |
| **I4** | N/A | N/A | F | F | N/A | F | F | F | FoT optional |
| **J1** | P | F | F | F | F | F | F | F | No `controlFacetFuncs` / Behavior_IFacet trees |
| **J2** | P | P | F | F | F | F | F | F | Factory loupe H9; products sparse |
| **J3** | P | P | P | P | P | P | P | P | Specs call proxy in practice; no FunctionNotFound matrix |
| **K1** | N/A | P | P | P | G | P | P | P | Donation idle / free-only separation from book |

---

## 5. Findings

### 5.1 [TCA-HOOK-001] Blocker · CODE · PAT-I-ABS / free extract · catalog I1 · RUNTIME_UNPROVEN

- **Summary:** `UniswapV4SingleStandardExchangeBufferConstantProductHookSeTarget.exchangeIn` / `exchangeOut` accept `pretransferred=true` with **no free-balance or delta check**. On the **raw→pair** path the hook **unwraps SE book** and transfers `pairToken` to `recipient` without ever requiring `rawToken` on the diamond — pure free extract of LP inventory. Pair→raw path fails closed only because `_bufferPair` needs free pair face (opaque SE revert).
- **Evidence:**
  - `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookSeTarget.sol` L633–661 (`exchangeIn`: skip pull when pretransferred; `rawIn` → `_unwrapExactPairOut` + transfer pair).
  - Same file L672–701 (`exchangeOut`: optional refund `maxAmountIn - amountIn` without free proof, then same rawIn unwrap).
  - Facet inherits SeTarget: `.../facets/UniswapV4SingleStandardExchangeBufferConstantProductHookSeFacet.sol`.
  - Happy tests only use `pretransferred=false`: `UniswapV4SingleStandardExchangeBufferConstantProductHook_Swap.t.sol` `test_SE1_*` / `test_SE2_*`.
  - Adversarial file has **no** pretransfer I cases (`..._Adversarial.t.sol` N1–N4 / I4 deposit-without-init only).
- **Why bar fails:** Hook money API free principal extract; catalog I1; ship-blocking SE buffer product.
- **Recommended CODE:** Before executing book:
  1. Free-only gate: `free = bal - book` for raw inventory (raw is face-held); require `free >= amountIn` (or `amountIn` for exact-out quote) else `InsufficientPretransfer`.
  2. Prefer **delta/snapshot** if product law requires exclusive caller credit (align with L-CLAIM-3 / commons) — free-only still allows donation sniping (document if intentional).
  3. `exchangeOut` refund only from free excess above quoted `amountIn`, never from book.
- **Recommended TEST:**
  - `test_I1_exchangeIn_rawToPair_pretransferred_unfunded_reverts` — seed LP; no transfer; `pretransferred=true`; expect typed revert; attacker pair bal unchanged; SE claim unchanged.
  - `test_I1_exchangeOut_rawToPair_pretransferred_unfunded_reverts`
  - `test_I1_exchangeIn_rawToPair_pretransferred_withFreeFunding_works` (happy free-only)
  - Match-path: `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/**`
- **Suggested WP:** `WP-I-HOOK-CP-001`
- **Priority:** Wave 0/1 CODE then tests
- **Runtime status:** **RUNTIME_UNPROVEN** (static overwhelming). Suggested proof: fund LP via TestBase deposit; call proxy `exchangeIn(raw, amount, pair, 0, attacker, true, deadline)` without transfer; observe attacker pair increase.

### 5.2 [TCA-HOOK-002] High · CODE · Dual missing free-pretransfer gate · catalog I1

- **Summary:** Dual SE BCP `exchangeIn`/`exchangeOut` skip pull when `pretransferred=true` without `_requirePretransferred`. Unfunded calls typically fail inside `_buffer` (SE pull) with **non-typed** errors; funded residual/donation free face is spendable by any caller (free-only without explicit gate or I tests). `exchangeOut` refunds `maxAmountIn - amountIn` before buffer without free accounting (atomicity prevents partial refund+success if free short, but API is unsafe vs orbital peer).
- **Evidence:**
  - `.../dual/UniswapV4DualStandardExchangeBufferConstantProductHookTarget.sol` L510–561.
  - M3 tests only `pretransferred=false`: `UniswapV4DualSEBCPHook_B6M3.t.sol` `test_M3_exchangeIn_*`.
  - Contrast free gate: orbital `...OrbitalBufferHookTarget.sol` L2454–2466; bal SE L264–277.
- **Why bar fails:** I P0 when flag exists; peer products already free-gated.
- **Recommended CODE:** Add `_freeTokenBalance` / `_requirePretransferred` (free face only — SE book is shares). Refund only free excess on exact-out.
- **Recommended TEST:** Port orbital/bal `test_pretransfer_unfunded_*` + funded preview≡exec to Dual.
- **Suggested WP:** `WP-I-HOOK-DUAL-001`
- **Priority:** Wave 1

### 5.3 [TCA-HOOK-003] High · TEST · I1–I3 missing (Dual, CP, Weighted SE; incomplete Orbital/Bal/Crv)

- **Summary:** No catalog-named `test_I1_*` / I2 / I3 on Dual or CP. Weighted SE has free gate but **no** unfunded/short/residual-reuse tests. Orbital + Bal/Crv have unfunded + funded happy paths but bare `expectRevert`, no I2 short free, no I3 residual sniping.
- **Evidence:** `rg pretransfer` under `test/.../hooks` — only orbital + bal/crv SE adversarial files; dual/cp/weighted empty for I-class.
- **Why bar fails:** PRD I bar + free-only products still need I1–I3 proofs.
- **Recommended TEST:** Shared template `test_I1_unfunded_reverts`, `test_I2_shortFree_reverts`, `test_I3_residualReuse_secondCaller_noExtraOut` with exact `InsufficientPretransfer`.
- **Suggested WP:** `WP-I-HOOK-SEBUF-001` (+ CP/Dual WPs)
- **Priority:** Wave 1

### 5.4 [TCA-HOOK-004] High · THEATER · PAT-THEATER-PRE / bare expectRevert on pretransfer

- **Summary:** Orbital SE adversarial pretransfer tests use `vm.expectRevert()` without selector; funded path is necessary H but does not substitute for I1. CP happy SE routes never exercise false claim.
- **Evidence:** `UniswapV4StandardExchangeOrbitalBufferHook_Adversarial.t.sol` L52–80; CP Swap SE1/SE2.
- **Why bar fails:** Anti-theater skill — happy pretransfer ≠ I1; bare revert weak N.
- **Recommended TEST:** Typed errors; state-unchanged asserts on book/SE claim.
- **Suggested WP:** fold into `WP-I-HOOK-SEBUF-001` / `WP-I-HOOK-CP-001`
- **Priority:** Wave 1

### 5.5 [TCA-HOOK-005] High · TEST · PAT-J · J1–J3 area-wide

- **Summary:** No `Behavior_IFacet` / `controlFacetFuncs` Target-derived declaration suites for product facets. Factory has partial loupe (H9 flags/ERC165/8109) and Immutable (no diamondCut). Product Deploy/Factory tests assert flags + some views, not full Target API ⊆ facetFuncs ⊆ loupe ⊆ proxy callable.
- **Evidence:** `rg controlFacetFuncs` / `*_IFacet_Test` under `test/.../hooks` → empty. Facet lists exist and appear broadly complete **statically** (e.g. Dual SeFacet 4 SE selectors; CP SeFacet includes exchangeIn/Out) but **unproven** J bar → PAT-J-CTRL risk on future Target adds.
- **Why bar fails:** Hook P0 includes **J full**.
- **Recommended TEST:** Per-package `*_IFacet.t.sol` + package deploy loupe matrix + proxy smoke (including MultiAsset/ERC20 facets on diamond).
- **Suggested WP:** `WP-J-HOOK-001`
- **Priority:** Wave 1–2

### 5.6 [TCA-HOOK-006] High · TEST · Dual adversarial vacuum

- **Summary:** Dual has Core/Swap/B6M3 only — no donation, reentrancy, diamondCut, pre-live, residual, or I-class adversarial file despite dual SE + M3 money surface.
- **Evidence:** `test/.../standardExchange/dual/` file list (3 suites).
- **Why bar fails:** Ship-blocking hook money product without P0 A/C/F/I subset.
- **Recommended TEST:** `UniswapV4DualSEBCPHook_Adversarial.t.sol` port from SE Orbital + Single Buffer catalogs.
- **Suggested WP:** `WP-ADV-HOOK-001`
- **Priority:** Wave 1–2

### 5.7 [TCA-HOOK-007] High · CODE/TEST · residual free credit product-law + fee residual

- **Summary:** Free-only SE buffers intentionally treat free face above book as spendable pretransfer (orbital/bal/crv/weighted). That is **not** absolute book credit, but **is** residual/donation sniping (I3/K-adjacent). Fee residual (swap fee stays in reserve) is tested (e.g. orbital `test_tradingFee_residualStaysInReserve`, weighted/SE fee suites) and is distinct. Dual/CP lack explicit free residual policy tests. Pure AMM orbital `test_donationsIgnored_reserveOfUnchanged` is good A1 peer.
- **Evidence:** free helpers L2454–2466 orbital SE; bal SE L264–277; fee residual math tests under Fees.t.sol / Math.t.sol.
- **Why bar fails:** Residual program incomplete without I3 + documented beneficiary.
- **Recommended CODE:** none if free-only is law; document NEEDS_OWNER if exclusive caller credit desired (then delta).
- **Recommended TEST:** I3 residual race; K1 donation does not reprice book incorrectly; fee residual conservation.
- **Suggested WP:** `WP-I-HOOK-SEBUF-001` + optional `NEEDS_OWNER` residual policy
- **Priority:** Wave 1–2

### 5.8 [TCA-HOOK-008] High · TEST · pure AMM adversarial depth (Orbital/Weighted/Quad)

- **Summary:** Pure AMM hooks have reentrancy + safety CL bans + some donation, but not full catalog packaging (F cut on all, A donation on weighted/quad, H griefing matrix). Weighted has no `*_Adversarial.t.sol`.
- **Evidence:** orbital `UniswapV4OrbitalSwapHook_Adversarial.t.sol` (4 tests); weighted safety/reentrancy split across files; bal/curve `*_Safety.t.sol` CL bans labeled `test_I2_*` (naming collision with trust I).
- **Recommended TEST:** Rename CL bans to `test_H_*` / `test_route_*`; add F1 cut; donation matrix where reserves are balance-derived.
- **Suggested WP:** `WP-ADV-HOOK-001`
- **Priority:** Wave 2

### 5.9 [TCA-HOOK-009] High · TEST · Weighted SE missing pretransfer adversarial

- **Summary:** Weighted SE implements free-balance checks in SeTarget but adversarial suite covers CL ban, reentrancy, full-book exit, pre-live — **not** pretransfer.
- **Evidence:** `UniswapV4StandardExchangeWeightedBufferHookSeTarget.sol` L92–107, L157–165; `..._Adversarial.t.sol` (no pretransfer).
- **Recommended TEST:** Mirror bal/crv pretransfer suite.
- **Suggested WP:** `WP-I-HOOK-SEBUF-001`
- **Priority:** Wave 1

### 5.10 [TCA-HOOK-010] Medium · TEST · N exact-selector hygiene

- **Summary:** Widespread bare `vm.expectRevert()` on deadlines, route guards, pretransfer (orbital, dual Core, many Safety files).
- **Recommended TEST:** Typed custom errors (`DeadlineExpired`, `InsufficientPretransfer`, `LiquidityNotAllowed`, `NotPoolManager`).
- **Suggested WP:** cluster under product WPs / `WP-N-HOOK-001`
- **Priority:** Wave 2

### 5.11 [TCA-HOOK-011] Medium · TEST · L1–L3 absent

- **Summary:** No `testFuzz_` / `invariant_` under `test/.../hooks`. Math unit tests exist for some products but not property fuzz on conservation / free-balance invariant.
- **Evidence:** `rg testFuzz_|invariant_` hooks tests → empty.
- **Suggested WP:** `WP-L3-HOOK-001` (Wave 3)
- **Priority:** Wave 3

### 5.12 [TCA-HOOK-012] Medium · TEST · fork P0 uneven

- **Summary:** Factory + several products have base/eth/robinhood fork smokes; Dual hermetic-only; depth is smoke not adversarial/fork I.
- **Suggested WP:** `WP-FORK-HOOK-001` or accept hermetic as primary for Dual with explicit DEFER
- **Priority:** Wave 2–3

### 5.13 [TCA-HOOK-013] Medium · CODE hygiene · Weighted SeFacet interfaceId skew

- **Summary:** `UniswapV4StandardExchangeWeightedBufferHookSeFacet.facetInterfaces` advertises `IStandardExchangeMultiAssetLiquidity` while `facetFuncs` only SE In/Out; multi-asset lives on LiquidityFacet. Risk of supportsInterface true without selectors on **that** facet (diamond may still support via other facet — loupe J must prove).
- **Evidence:** SeFacet L22–34 vs LiquidityFacet L25–59.
- **Recommended CODE:** Drop multi-asset from SeFacet interfaces **or** move selectors; J test proves ERC165 + loupe consistency.
- **Suggested WP:** fold into `WP-J-HOOK-001`
- **Priority:** Wave 2

### 5.14 [TCA-HOOK-014] Low · Info · Flags + deployHookVault path quality

- **Summary:** Shared factory Flags tests (H3 address flags, H12 instance `requiredHookFlags`), salt/premine, Registry H15 product `deployHookVault`, product DFPkgs call `VAULT_REGISTRY_DEPLOYMENT.deployHookVault`. Low-level `FactoryService.deployHook` used in many TestBases for gas/simplicity but package path remains product law. **Not** a coverage fail.
- **Priority:** none (baseline Info)

### 5.15 [TCA-HOOK-015] Low · Info · Single SE Buffer adversarial maturity

- **Summary:** Single SE Buffer adversarial (A1–A3, B, C1–C3, E, F1–F3, H1–H4) is the area gold peer. Residual donation idle model (O11) is explicit and tested. Use as template for Dual/CP/SE buffers — without importing theater.
- **Priority:** none

### 5.16 [TCA-HOOK-016] Info · Pure AMM I N/A

- **Summary:** Orbital/Weighted/QuadStable pure swap hooks have no `pretransferred` money API; I1–I3 N/A. Do not force I WPs on those products.
- **Priority:** none

---

## 6. Theater list

| Test / control | Why theater | Fix |
|----------------|-------------|-----|
| Orbital SE `test_pretransferred_*_withoutFunding_reverts` bare `expectRevert` | Could pass on unrelated revert; no book-invariant assert | Typed `InsufficientPretransfer` + SE claim/pair bal unchanged |
| CP `test_SE1` / Dual `test_M3_exchangeIn` with `pretransferred=false` only | Cannot fail if free extract exists | Add I1 false-claim cases |
| Bal/Curve Safety `test_I2_clAddLiquidity_reverts` naming | Collides with catalog **I2 trust-flag** | Rename to route/H catalog IDs |
| Declaration-less facetFuncs “look complete” | PAT-THEATER-FACET / PAT-J-CTRL | J1 Target-derived controls + J2 loupe |
| Happy free funding pretransfer without I1 peer | PAT-THEATER-PRE | Keep as H; add unfunded siblings |

---

## 7. Prior-report diff

| Claim (doc) | Status now |
|-------------|------------|
| 2026-07 adversarial vault matrix (mostly DETF/SE, hooks thin) | **Still gap** — hooks not in classic MultiVault gold; product-local adversarial uneven |
| Fuzz/invariant 2026-07 (no hook L3) | **Still gap** — zero L1–L3 under `test/.../hooks` |
| Uni V4 hook package PRDs / remediation (B6, M3, factory refactor) | **Partial close** — B6/M3 dual tests present; free-pretransfer not remediated on Dual/CP |
| Hook factory flags/mining PRDs | **Mostly closed** in factory test suite (Flags/Premine/Salt/Registry) |
| Struct-audit I/J/K on SE vaults | **Superseded** for ownership of shared pull; **hooks-local free-only** is this area’s parallel track |
| `docs/NEGATIVE_TEST_COVERAGE_REPORT` pretransfer | Focused on BasicVaultCommon/SE — **does not cover** hook free-extract CP path (**New**) |

---

## 8. Work package stubs

### WP-I-HOOK-CP-001

| Field | Value |
|-------|--------|
| **Title** | Fix Single SE CP pretransfer free extract + I1–I3 |
| **Severity** | Blocker |
| **Class** | BOTH |
| **Products** | Single SE Buffer Constant Product Hook |
| **Finding IDs** | TCA-HOOK-001, TCA-HOOK-003, TCA-HOOK-004 |
| **Problem** | `pretransferred=true` on raw→pair drains SE book without funding. |
| **Production files** | `.../constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookSeTarget.sol` (+ Target.sol if still compiled peer) |
| **Test files** | `test/.../constantProduct/single/*Adversarial*` or new `*_Pretransfer.t.sol` |
| **Out of scope** | Dual, other SE buffers, BasicVaultCommon |
| **Depends on** | none (hook-local free gate) |
| **Parallelizable with** | WP-I-HOOK-DUAL-001, WP-J-HOOK-001, SEBUF I suite |
| **Suggested worktree** | `gap_cover_i-hook-cp` |
| **Implementation notes** | Mirror orbital `_freeTokenBalance` / `_requirePretransferred`; raw book = face bal; pair book = SE claim not free face |
| **Acceptance** | `forge test --match-path 'test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/**' --match-test 'test_I1_'` green; unfunded raw→pair no attacker gain |
| **Anti-theater** | I1 must not transfer raw; assert SE claim and attacker pair bal |

### WP-I-HOOK-DUAL-001

| Field | Value |
|-------|--------|
| **Title** | Dual free-pretransfer gate + I suite |
| **Severity** | High |
| **Class** | BOTH |
| **Products** | Dual SE BCP Hook |
| **Finding IDs** | TCA-HOOK-002, TCA-HOOK-003, TCA-HOOK-006 |
| **Problem** | M3 SE API has flag without free gate or I proofs. |
| **Production files** | `.../dual/UniswapV4DualStandardExchangeBufferConstantProductHookTarget.sol` |
| **Test files** | new `UniswapV4DualSEBCPHook_Adversarial.t.sol` / Pretransfer suite |
| **Out of scope** | CP Single CODE, pure AMM |
| **Depends on** | none |
| **Parallelizable with** | WP-I-HOOK-CP-001, WP-I-HOOK-SEBUF-001 |
| **Suggested worktree** | `gap_cover_i-hook-dual` |
| **Acceptance** | unfunded pretransfer typed revert; funded free preview≡exec; residual I3 |
| **Anti-theater** | no happy-only pretransfer |

### WP-I-HOOK-SEBUF-001

| Field | Value |
|-------|--------|
| **Title** | SE buffer free-only I1–I3 (Orbital, Weighted, Bal, Curve) |
| **Severity** | High |
| **Class** | TEST (CODE only if free gate bug found) |
| **Products** | SE Orbital / Weighted / Bal Quad / Curve Quad buffers |
| **Finding IDs** | TCA-HOOK-003, TCA-HOOK-004, TCA-HOOK-007, TCA-HOOK-009 |
| **Problem** | Partial or missing I proofs; residual reuse unproven. |
| **Test files** | existing `*_Adversarial.t.sol` per product |
| **Depends on** | none (gates already present except weighted needs suite only) |
| **Parallelizable with** | CP/Dual CODE WPs, J WP |
| **Suggested worktree** | `gap_cover_i-hook-sebuf` |
| **Acceptance** | each product: I1 unfunded, I2 short free, I3 residual; exact selector |
| **Anti-theater** | funded path not counted as I1 |

### WP-J-HOOK-001

| Field | Value |
|-------|--------|
| **Title** | Hook diamond J1–J3 surface matrix |
| **Severity** | High |
| **Class** | TEST (+ CODE if omissions found) |
| **Products** | All packages in inventory + flags facet |
| **Finding IDs** | TCA-HOOK-005, TCA-HOOK-013 |
| **Problem** | No systematic Target⊆facetFuncs⊆loupe⊆proxy proof. |
| **Test files** | `test/.../hooks/**/facets/*_IFacet.t.sol` or shared Behavior harness |
| **Depends on** | none |
| **Parallelizable with** | all I WPs |
| **Suggested worktree** | `gap_cover_j-hook` |
| **Acceptance** | per facet control list; package deploy loupe; proxy call each money/view selector |
| **Anti-theater** | controls from Target/interface not Facet copy-paste; J3 on proxy not facet impl |

### WP-ADV-HOOK-001

| Field | Value |
|-------|--------|
| **Title** | Dual + pure AMM adversarial catalog ports |
| **Severity** | High |
| **Class** | TEST |
| **Products** | Dual; Orbital/Weighted/Quad pure AMM |
| **Finding IDs** | TCA-HOOK-006, TCA-HOOK-008 |
| **Problem** | Catalog holes vs single-buffer gold. |
| **Depends on** | WP-I-HOOK-DUAL-001 for Dual I cases (or include I there) |
| **Suggested worktree** | `gap_cover_adv-hook` |
| **Acceptance** | A1 donation, C reentrancy, F1 cut, H CL ban / minOut with exact selectors |

---

## 9. Deferred / N/A / NEEDS_OWNER

| Item | Class | Reason |
|------|-------|--------|
| Pure AMM trust-flag I | N/A | No `pretransferred` API |
| Free-only vs exclusive-caller delta on SE buffers | NEEDS_OWNER | Free-only is implemented + partially tested; delta would change product economics for residual/donation |
| Full Echidna/Medusa campaigns | DEFER | Stage 1 out of scope |
| Via_ir optimization | DEFER / forbidden | Never recommend |
| Manager ACL on `deployHookVault` depth | Out of area | Cite `T-manager-fee-registry` |
| Underlying SE PAT-I-ABS | Out of area | `T-basic-protocol-commons` / `T-se-*` |
| L2/L3 handlers | DEFER Wave 3 | TCA-HOOK-011 |

---

## 10. Commands run

```bash
# Inventory (workspace root = indexedex)
ls contracts/hooks/uniswap/v4
ls test/foundry/spec/hooks/uniswap/v4
rg -n --type sol 'pretransferred|deployHookVault|requiredHookFlags|function facetFuncs|_requirePretransferred|_freeTokenBalance' contracts/hooks --glob '!**/lib/**'
rg -n --type sol 'pretransfer|test_I[0-9]_|adversarial|controlFacetFuncs|facetAddress|testFuzz_|invariant_' test/foundry/spec/hooks
rg -n --type sol 'function test_' test/foundry/spec/hooks/uniswap/v4/standardExchange/dual
rg -n --type sol 'function test_' test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single
# Static review of free-extract path
# .../constantProduct/single/*SeTarget.sol exchangeIn/Out
# .../dual/*Target.sol exchangeIn/Out
# .../orbital/*Target.sol _requirePretransferred
# No forge runtime proof executed this subagent
```

---

## Return summary (orchestrator)

| Field | Value |
|-------|--------|
| **Status** | **COMPLETE** |
| **Blocker** | **1** — `TCA-HOOK-001` Single SE CP raw-in free extract (`pretransferred=true`) · RUNTIME_UNPROVEN |
| **High** | **9** — Dual free gate; I suites; theater; J; Dual adv vacuum; residual law; pure AMM adv; Weighted SE I; (clustered) |
| **Top WPs** | `WP-I-HOOK-CP-001` · `WP-I-HOOK-DUAL-001` · `WP-I-HOOK-SEBUF-001` · `WP-J-HOOK-001` · `WP-ADV-HOOK-001` |
| **OUT_FILE** | `docs/testing/coverage-audit/areas/T-hooks-v4.md` |
