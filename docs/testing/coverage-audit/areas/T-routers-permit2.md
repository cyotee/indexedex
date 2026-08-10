# Test Coverage Audit — T-routers-permit2

| Field | Value |
|-------|--------|
| Date | 2026-08-09 |
| Agent / run | Stage 1 area subagent · full · `T-routers-permit2` |
| Status | **COMPLETE** |
| Production paths | `contracts/routers/**` (primary: `balancerV3-uniswapV4` Coordinator diamond + adapters + DFPkg + FactoryService); Permit2 coordinator pull/funding paths on that diamond; **reference-only** child Balancer SE routers under `contracts/protocols/dexes/balancer/v3/routers/**` (owned by `T-se-univ4-aave-balancer`) |
| Test paths | `test/foundry/spec/routers/balancerV3-uniswapV4/**`; `test/foundry/fork/base_main/routers/balancerV3-uniswapV4/**`; `test/foundry/spec/routers/universal_router_port/**`; cross-cite BasicVaultCommon Permit2 (commons-owned) |
| Skills / PRD version cited | `docs/testing/TEST_COVERAGE_AUDIT_PRD.md` (DRAFT, L-TCA-1…8, §2.2–2.4, §2.3 Router/Permit2 P0, §7.2, §8); `crane-adversarial-testing` (I5, A–K); `crane-testing` LR-7; Coordinator PRD + T1–T32 plan under `contracts/routers/balancerV3-uniswapV4/` |
| Finding ID prefix | `TCA-RTR-NNN` |

---

## 1. Executive summary

### Maturity (0–5)

| Product / surface | Maturity | Worst open severity |
|-------------------|----------|---------------------|
| **BalancerV3UniswapV4CoordinatorRouter** (diamond DFPkg) | **3** | **High TEST** (I5/signature P0 suite incomplete; D/J formal gap; bare-revert theater) |
| **ExactIn + Permit2 pull** (`swapExactInWithPermit`, `_pullPermit`) | **3–4** | High TEST (replay / wrong spender / token-mismatch unproven) |
| **ETH entry/exit** (`swapExactInEth` / `ethOut`) | **3–4** | Medium (N exactness partial) |
| **Adapters** (Stock / Batch / SE / UR) | **3** | Medium (UR allowance-clear unproven) |
| **Admin / rescue / allowlist** | **3** | Medium (bare owner reverts; T21 incomplete) |
| **Query** (`queryExactIn`) | **3–4** | Medium (P strong on stock/SE/UR templates) |
| **UniversalRouter vendor smoke** | **1** | Info (not Coordinator SUT) |
| **BasicVaultCommon Permit2** (reference) | **1** | Owned by `T-basic-protocol-commons` (theater I) |

### Blocker / High counts

| Severity | Count | Notes |
|----------|------:|-------|
| **Blocker** | **0** | No free-mint / unbounded extract CODE proven. Coordinator pull is **delta-based** after Permit2; hop input is **ledger** (not raw inventory). |
| **High** | **3** | Permit2 P0 suite gaps (replay/spender/I5); exact-fail theater on money negatives; formal J/D surface unproven |
| **Medium** | **6** | Missing N selectors; T15/T21 theater; UR T23; fork depth; L1; residual N hygiene |
| **Low / Info** | **3** | Vendor smoke; CODE health notes; commons ownership boundary |

### Top 5 recommended WPs

1. **`WP-I5-RTR-001`** — Wave-1 TEST: P0 Permit2 suite on production proxy — **signature replay**, **wrong spender**, **permit.token ≠ tokenIn** (`InvalidPermitWitness`), permit amount short vs `amountIn`, extended witness-field mismatches with **exact** fail (not bare `expectRevert`).
2. **`WP-N-RTR-001`** — Wave-1 TEST: exact-selector hygiene + missing negatives (`EmptyRoute`, `TokenOutMismatch`, `InvalidEthOut`, `ZeroAmount`, minOut typed, access control typed).
3. **`WP-J-RTR-001`** — Wave-1 TEST: Facet `facetFuncs` declaration (ExactIn / Query / Admin / Permit2Witness + MultiStepOwnable) + DFPkg cuts + loupe + **proxy** smoke of full money API (J1–J3).
4. **`WP-ALLOW-RTR-001`** — Wave-2 TEST: complete T23 for **UR ERC-20 approve** residual-0; mid-step failure residual clear if reachable.
5. **`WP-THEATER-RTR-001`** — Wave-2 TEST: replace T15 selector theater + complete T21 (unregister then **execute** reverts `RouterNotAllowed`).

### Headline

**Coordinator is one of the stronger money-router surfaces in-repo for happy path (H) and product plan T1–T32**, with production-first CREATE3 + DFPkg deploy, real Permit2 witness signing, stock/SE/UR hops, preview≡execute, donation-safe ledger (T26), FoT short-pull **I5-class** (T32), and child Permit2 allowance clear (stock/SE). **It does not meet the PRD §2.3 Router/Permit2 P0 bar** without dedicated **signature replay**, **wrong spender**, and **exact-fail** proofs. Several “security” negatives use bare `vm.expectRevert()` (**exact fail** theater). Formal **D/J** declaration tests are **absent** (proxy smoke exists only via functional suites). **No Blocker CODE** found on static review of `_pullPermit` (delta) + `_fundChild`/`_clearChild` (amount-scoped).

---

## 2. Product inventory

### 2.1 Packages / surfaces in allowlist

| Product | DFPkg / key Targets | TestBase | Test roots | Deploy path quality |
|---------|---------------------|----------|------------|---------------------|
| **BalancerV3UniswapV4CoordinatorRouter** | `BalancerV3UniswapV4CoordinatorRouterDFPkg`; Targets: ExactIn, Query, Admin, Permit2Witness; Facets ×4 + MultiStepOwnable; Adapters: Stock, Batch, SE, UR | `contracts/routers/.../TestBase_BalancerV3UniswapV4CoordinatorRouter.sol`; stock/SE also use `TestBase_BalancerV3_8020WeightedPool` | `test/foundry/spec/routers/balancerV3-uniswapV4/*` (10 suites + helpers); fork `test/foundry/fork/base_main/routers/balancerV3-uniswapV4/*` | **Good** — CREATE3 facets via `BalancerV3UniswapV4CoordinatorRouter_FactoryService`; diamond via `diamondPackageFactory`; **pure Crane**, not vault registry (T28 intentional per product D21) |
| **Universal Router vendor port** | Crane-vendored `UniversalRouter` (not IndexedEx DFPkg) | none | `UniversalRouter_VendorSmoke.t.sol` | Hermetic `new` only — **not** Coordinator H coverage |
| **Permit2 on vaults** (reference) | `BasicVaultCommon` + SE/DETF pull | harness / product TestBases | `BasicVaultCommon_Permit2.t.sol` + forks | **Commons-owned**; PAT-I-ABS / theater tracked under `T-basic-protocol-commons` |

### 2.2 Coordinator production map (money path)

| Component | Path | Role |
|-----------|------|------|
| ExactIn Target | `.../targets/BalancerV3UniswapV4CoordinatorRouterExactInTarget.sol` | `swapExactInWithPermit`, `swapExactInEth`, `_pullPermit`, `_executeRoute`, payout |
| Common | `.../common/BalancerV3UniswapV4CoordinatorRouterCommon.sol` | Witness typehash/string, `_validateParams`, child Permit2/ERC20 fund+clear |
| Repo | `.../common/BalancerV3UniswapV4CoordinatorRouterRepo.sol` | Allowlist + kinds + v4 quoter |
| Query Target | `.../targets/...QueryTarget.sol` | `queryExactIn` dispatch |
| Admin Target | `.../targets/...AdminTarget.sol` | register/unregister, rescue, views |
| Witness Target | `.../targets/...Permit2WitnessTarget.sol` | `WITNESS_TYPE_*` getters only |
| DFPkg | `.../BalancerV3UniswapV4CoordinatorRouterDFPkg.sol` | 5 facet cuts; init Permit2/WETH/owner/seed routers |
| FactoryService | `.../BalancerV3UniswapV4CoordinatorRouter_FactoryService.sol` | CREATE3 facets + package deploy |

### 2.3 Trust-flag / funding model (Router class)

| Flag / path | Present? | Notes |
|-------------|----------|-------|
| `pretransferred` | **No** | I1–I3 N/A for Coordinator itself |
| Permit2 SignatureTransfer + witness | **Yes** | Primary ERC-20 funding; owner=`msg.sender`; spender bound in EIP-712 = Coordinator |
| `msg.value` / ethIn | **Yes** | Separate entry `swapExactInEth` |
| Child funding | Permit2 AllowanceTransfer (Balancer/SE) or ERC-20 approve (UR); amount-scoped; clear residual |

**I bar for this product = I5** (signed amount ≠ delivered / Permit2 integrity), **not** PAT-I-ABS free mint. Production `_pullPermit` measures **balance delta** and reverts `InvalidAmount` if short — anti-I5 design.

### 2.4 Test inventory (this area)

| Suite | Path | Plan IDs / focus | Counts for Router P0? |
|-------|------|------------------|------------------------|
| Deploy | `..._Deploy.t.sol` | T1, T25, T28–T30, witness getters | Partial D (deploy only) |
| Admin | `..._Admin.t.sol` | T21 (weak), zero register, onlyOwner bare | Partial N |
| Negative | `..._Negative.t.sol` | T2, T15, T19, T20, T27, T32 | **I5 partial (T32)**; exact N partial |
| Permit2Witness | `..._Permit2Witness.t.sol` | T14 recipient tamper | Partial witness; **bare revert** |
| ExactIn Stock | `..._ExactIn_Stock.t.sol` | T3–T4, T11–T13, T22–T23, P | H/P strong; minOut bare |
| ExactIn SE | `..._ExactIn_SE.t.sol` | T5–T6, T23 SE | H/P |
| ExactIn UR | `..._ExactIn_UR.t.sol` | T7–T8, T24 | H/P; **no T23 UR clear** |
| Interleaved | `..._ExactIn_Interleaved.t.sol` | T9–T10, T26 | H + K-class ledger |
| Eth | `..._Eth.t.sol` | T16–T18 | H/N eth |
| LedgerAndRescue | `..._LedgerAndRescue.t.sol` | T31 residual/rescue/reentrancy | H + C-ish |
| Base fork | `..._BaseMain_Fork.t.sol` | deploy, witness, live stock hop | Fork H partial |
| UR vendor smoke | `universal_router_port/...` | Commands constant | Not SUT |
| Helpers | `CoordinatorWitnessSignLib`, `CoordinatorSeRouterDeployLib` | signing + SE deploy | — |

**~44 hermetic `test_*` functions** under Coordinator suites; **3** fork tests. **No** `testFuzz_` / `invariant_` under `test/**/routers/**`. **No** `Behavior_IFacet` / `controlFacetFuncs` for Coordinator facets.

### 2.5 Out-of-area (reference only)

| Surface | Owner area | Why cited |
|---------|------------|-----------|
| Balancer V3 SE router diamond | `T-se-univ4-aave-balancer` | Child adapter in T5/T6/T9; not audited for SE I/J here |
| BasicVaultCommon Permit2 | `T-basic-protocol-commons` | Shared Permit2 pull pattern; PAT-I-ABS not Coordinator |
| Vault SE routes approving Permit2 on fork | product SE areas | Funding hygiene only |

---

## 3. Layer matrix

Legend: **F** full · **P** partial · **G** gap · **N/A** · **S** stub/theater · maturity 0–5.

| Product | H | N | D | J | I | K | A–H | P | L1 | L2 | L3 | Maturity | Notes |
|---------|---|---|---|---|---|---|-----|---|----|----|----|----------|-------|
| Coordinator diamond | **F** | **P/S** | **G** | **P** | **P** (I5) | **P** (T26/T31) | **P** (C reentry, F allowlist) | **F** stock/SE/UR | **G** | **G** | **G** | **3** | H covers T3–T10, T13, T16–T18; N missing many exacts; I5=T32 only; J via functional proxy only |
| ExactIn Permit2 pull | F | P | — | P | **P** I5 | N/A | — | F | G | G | G | **3** | Delta pull + FoT; no replay/spender |
| Admin/rescue | P | P/S | G | P | N/A | P residual | P F | N/A | G | G | G | **3** | Rescue + residual; bare owner |
| UR adapter path | F | P | — | — | — | — | — | F | G | G | G | **3** | Templates A/B; no approve-clear assert |
| UR vendor smoke | P | G | N/A | N/A | N/A | N/A | N/A | N/A | G | G | G | **1** | Deploy only |

---

## 4. Catalog matrix (A–K)

Router / Permit2 class default P0 (PRD §2.3): **signature replay, allowance, wrong spender, I5, exact fail, H, N**.

| ID | Coordinator | Evidence (test name or **G**) |
|----|-------------|-------------------------------|
| **A1** donation free extract | **P** | T26 donation not spent as hop input; T31 residual not paid as `amountOut` — not vault share mint |
| **A3** | G/N/A | No share mint surface |
| **B*** | N/A | No DETF thresholds |
| **C1–C3** reentrancy | **P** | `test_T31_reentrancyDuringPullIsLocked` (shared lock vs `queryExactIn`); no full child-callback catalog |
| **D*** authority | **P** | onlyOwner register/rescue (bare); MultiStepOwnable T25 |
| **E1/E5** zero/deadline | **P** | T20 deadline; **G** explicit ZeroAmount / empty route |
| **F2–F3** allowlist | **P** | T2 `RouterNotAllowed`; T22 stock-only; T21 unregister **without** execute step |
| **H2/H3** slippage | **P/S** | T11/T12 minOut reverts but **bare** `expectRevert()` |
| **I1–I3** pretransfer | **N/A** | No `pretransferred` flag on Coordinator |
| **I5** Permit2 signed≠delivered | **P** | `test_T32_fotShortPullRevertsInvalidAmount` (**exact** `InvalidAmount`); **G** replay, wrong spender, short permit amount, token mismatch |
| **J1–J3** surface | **P/G** | Functional proxy calls prove money selectors exist; **G** declaration matrix / loupe completeness / PAT-J hunt formalized |
| **K1** reserve sync | **P** | Ledger amount-for-step (T26); residual rescue (T31) — not vault reserve accounting |
| **H** happy path | **F** | Stock/SE/UR/interleaved/eth + fork live hop |
| **N** exact fail | **P/S** | Several typed (T2, T19, T20, T27, T32); many bare |
| **P** preview≡execute | **F** | T3, T5, T7 template A/B with snapshot/revert |

---

## 5. Findings

### 5.1 [TCA-RTR-001] High · TEST · I5 / signature replay / wrong spender (Router P0)

- **Summary:** PRD §2.3 requires **signature replay**, **wrong spender**, and **I5** proofs for Router/Permit2 coordinators. Present coverage is happy witness (T13), recipient-only witness mismatch (T14 bare), and FoT short-pull (T32). **No** test reuses a spent Permit2 nonce; **no** test signs spender ≠ Coordinator; **no** test for `permit.permitted.token != params.tokenIn` → `InvalidPermitWitness`; **no** test for permit amount &lt; `amountIn`.
- **Evidence:**
  - Production: `_pullPermit` uses `permitWitnessTransferFrom(..., msg.sender, _witnessHash(params), ...)` and `requestedAmount: params.amountIn` — [`ExactInTarget.sol` L67–80](contracts/routers/balancerV3-uniswapV4/targets/BalancerV3UniswapV4CoordinatorRouterExactInTarget.sol); token mismatch check L44–46.
  - Tests: `test_T13_happyPathWitness`, `test_T14_witnessMismatchReverts` (bare), `test_T32_fotShortPullRevertsInvalidAmount`; `rg` under `test/**/routers` finds **no** replay / wrongSpender / `InvalidPermitWitness`.
- **Why bar fails:** Router P0 incomplete; cannot ship-claim Permit2 integrity from FoT-only I5.
- **Recommended CODE:** none expected if Permit2 + witness wiring correct (static review clean).
- **Recommended TEST:**
  - `test_I5_signatureReplay_sameNonce_reverts` — successful swap then second call same permit/sig → Permit2 nonce error (exact selector if available, else documented Permit2 bytes).
  - `test_I5_wrongSpender_signatureForOtherRouter_reverts` — sign spender=`address(0xBEEF)` (or second coordinator), call real coordinator.
  - `test_I5_permitTokenMismatch_reverts_InvalidPermitWitness` — permit.token ≠ tokenIn.
  - `test_I5_permitAmountShort_reverts` — permitted.amount &lt; amountIn.
  - `test_I5_witness_amountIn_or_steps_tamper_reverts` — exact fail preferred.
  - Match-path: `test/foundry/spec/routers/balancerV3-uniswapV4/**` (extend `*_Permit2Witness.t.sol` or new `*_Permit2Security.t.sol`).
  - Pass: attacker cannot move principal funds without valid unused (nonce,spender,witness) triple; state-unchanged on fail.
- **Suggested WP:** `WP-I5-RTR-001`
- **Priority:** Wave 1

### 5.2 [TCA-RTR-002] High · THEATER / TEST · exact fail theater (minOut, witness, access)

- **Summary:** Multiple money/security negatives use bare `vm.expectRevert()` so **any** revert passes — fails PRD N bar (“exact selector preferred”) and “exact fail” Router P0.
- **Evidence:**
  - `test_T11_globalMinOutReverts`, `test_T12_stepMinOutReverts` — bare (`ExactIn_Stock.t.sol`).
  - `test_T14_witnessMismatchReverts` — bare (`Permit2Witness.t.sol`).
  - `test_T31_rescueOnlyOwner`, `test_onlyOwnerRegister` — bare.
- **Why bar fails:** Theater risk: wrong error path (e.g. expired deadline vs minOut) still greens.
- **Recommended TEST:** `expectRevert` with `MinAmountOutNotMet(min, actual)`, Permit2/InvalidPermitWitness/ECDSA errors as applicable, MultiStepOwnable/Ownable selector for access.
- **Suggested WP:** `WP-N-RTR-001` (+ fold into I5 suite for T14)
- **Priority:** Wave 1

### 5.3 [TCA-RTR-003] High · TEST · J1–J3 / D declaration gap (PAT-J)

- **Summary:** No `Behavior_IFacet` / `controlFacetFuncs` tests for Coordinator facets. DFPkg cuts appear complete **statically** (ExactIn: 2 fns; Query: 1; Admin: 8; Witness: 2 + MultiStepOwnable), and functional tests call money APIs on **proxy** — but **formal** Target ⊆ facetFuncs ⊆ facetCuts ⊆ loupe ⊆ proxy matrix is **unproven**. Future Target addition can ship silent (PAT-J-OMIT).
- **Evidence:** `rg Behavior_IFacet|controlFacetFuncs|facetFuncs` under `test/**/routers` → empty for declaration suites. Deploy suite only checks owner + allowlist seed.
- **Static facet inventory (review note, not a test):**
  - ExactIn: `swapExactInWithPermit`, `swapExactInEth`
  - Query: `queryExactIn`
  - Admin: register/unregister/isAllowed/kind/count/at/rescueTokens/rescueETH
  - Witness: `WITNESS_TYPE_STRING`, `WITNESS_TYPEHASH`
- **Why bar fails:** J is P0 for diamond money products; declaration theater is a known monorepo failure mode.
- **Recommended TEST:** Four `*_IFacet_Test` (or one multi-facet) with controls from interface/Target; after `deployCoordinator`, loupe all selectors; proxy smoke each money + admin view; assert no missing `IBalancerV3UniswapV4CoordinatorRouter` external.
- **Suggested WP:** `WP-J-RTR-001`
- **Priority:** Wave 1

### 5.4 [TCA-RTR-004] Medium · TEST · Missing N-layer selectors

- **Summary:** Production errors **untested** by name: `EmptyRoute`, `TokenOutMismatch`, `InvalidEthOut`, `ZeroAmount`; `InvalidPermitWitness` only reachable via token mismatch (untested).
- **Evidence:** `rg EmptyRoute|TokenOutMismatch|InvalidPermitWitness|InvalidEthOut|ZeroAmount` under `test/foundry/spec/routers` → **no matches**. Validation lives in `_validateParams` / ExactIn Target.
- **Recommended TEST:** one exact-selector case each on proxy.
- **Suggested WP:** `WP-N-RTR-001`
- **Priority:** Wave 1–2

### 5.5 [TCA-RTR-005] Medium · THEATER · T15 / T21 incomplete vs product plan claims

- **Summary:**
  - **T15** (`test_T15_noTransferFromUserEntry`) only asserts non-zero selectors for `swapExactInWithPermit` / `swapExactInEth` — does **not** prove absence of a `transferFrom` user entry (compile-time / interface scan would; runtime is no-op theater).
  - **T21** (`test_T21_unregisterThenStepReverts`) unregisters and checks `isRouterAllowed` only — does **not** execute a step/swap to prove `RouterNotAllowed` after unregister (T2 covers never-allowed; not unregister-then-execute).
- **Evidence:** `Negative.t.sol` L158–162; `Admin.t.sol` L24–30.
- **Recommended TEST:** Replace T15 with interface/ABI scan or documented compile-time assertion + comment; T21 call `swapExactInWithPermit` after unregister with exact `RouterNotAllowed`.
- **Suggested WP:** `WP-THEATER-RTR-001`
- **Priority:** Wave 2

### 5.6 [TCA-RTR-006] Medium · TEST · T23 incomplete for Uniswap V4 Universal Router

- **Summary:** Product law (D18): UR child funding is **ERC-20 approve** amount-scoped then clear to 0. T23 asserts **Permit2** residual 0 for stock + SE only. **No** post-hop `allowance(coordinator, ur) == 0` for UR path.
- **Evidence:** `test_T23_permit2AllowanceCleared` (stock), `test_T23_sePermit2AllowanceCleared`; UR suite has no allowance assert after `test_T7_templateA_queryAndExecute`.
- **Production:** `_fundChild` / `_clearChild` branch ERC20 for UR (`ExactInTarget` L149–167).
- **Recommended TEST:** `test_T23_urErc20AllowanceCleared` after successful Template A.
- **Suggested WP:** `WP-ALLOW-RTR-001`
- **Priority:** Wave 2

### 5.7 [TCA-RTR-007] Medium · TEST · I5 partial — FoT only

- **Summary:** T32 is a **strong** I5 proof (FoT short → exact `InvalidAmount`). Remaining I5 variants (signed amount / permit short / replay) clustered under TCA-RTR-001. Tracking residual so aggregate does not treat T32 as full I5 close.
- **Evidence:** `test_T32_fotShortPullRevertsInvalidAmount`.
- **Suggested WP:** `WP-I5-RTR-001`
- **Priority:** Wave 1

### 5.8 [TCA-RTR-008] Medium · TEST · L1 fuzz / sequence invariants absent

- **Summary:** No `testFuzz_` / `invariant_` under router trees. Hot math is hop ledger conservation (donation cannot inflate next hop; residual ≠ payout). T26 is example-level only.
- **Recommended TEST:** Wave 3 `testFuzz_ledgerHopInput_equalsPriorDelta` / multi-hop conservation with bounded amounts on stock fixture.
- **Suggested WP:** `WP-L1-RTR-001`
- **Priority:** Wave 3

### 5.9 [TCA-RTR-009] Medium · TEST · Fork P0 thin (L-TCA-5)

- **Summary:** Base fork covers deploy allowlist + witness getters + **one** live stock Balancer hop. Missing: live UR hop, SE child on fork, multi-step, negative fork (deadline/allowlist), allowance-clear on live Permit2.
- **Evidence:** `BalancerV3UniswapV4CoordinatorRouter_BaseMain_Fork.t.sol` (3 tests).
- **Recommended TEST:** extend fork suite when venues present; equal severity to hermetic gaps for launch routes that are fork-first.
- **Suggested WP:** `WP-FORK-RTR-001`
- **Priority:** Wave 2–3

### 5.10 [TCA-RTR-010] Info · CODE health — no Blocker PAT-I-ABS on Coordinator pull

- **Summary:** Static review: `_pullPermit` records `balBefore`, pulls via Permit2, requires `received >= amountIn` — **delta-based**, not absolute credit of claimed amount. Hop input is `amountForStep` ledger, not `balanceOf`. Child Permit2 approvals are amount-scoped with clear. **No runtime Blocker proof required** (no free-mint candidate escalated).
- **Evidence:** `ExactInTarget.sol` L67–80, L88–99, L149–167; Common L98–107.
- **Class:** Info (clean bill for PAT-I-ABS on this product)
- **Priority:** none

### 5.11 [TCA-RTR-011] Low · Info · UniversalRouter vendor smoke ≠ Coordinator coverage

- **Summary:** `UniversalRouter_VendorSmoke.t.sol` only proves vendored UR deploys + `Commands.V4_SWAP`. Does not exercise Coordinator adapter, witness, or DFPkg.
- **Suggested WP:** none (or absorb into UR H as dependency note)
- **Priority:** none

### 5.12 [TCA-RTR-012] Info · Boundary — BasicVaultCommon Permit2 owned by commons

- **Summary:** Area allowlist “Permit2 paths” includes vault Permit2 pulls; **ownership** of PAT-I-ABS / theater remains `T-basic-protocol-commons`. This area does **not** re-open commons CODE WPs.
- **Priority:** none (cross-link only)

### 5.13 [TCA-RTR-013] Low · TEST · Access-control exact selectors

- **Summary:** Owner-only register/rescue use bare reverts; should use MultiStepOwnable / access error selectors once identified from Crane.
- **Suggested WP:** `WP-N-RTR-001`
- **Priority:** Wave 2

---

## 6. Theater list

| Test / control | Why theater | Fix |
|----------------|-------------|-----|
| `test_T15_noTransferFromUserEntry` | Only checks selectors non-zero; cannot fail if a third funding entry exists | ABI/interface assertion or remove claim |
| `test_T21_unregisterThenStepReverts` | No step/swap after unregister | Execute with exact `RouterNotAllowed` |
| `test_T11_*` / `test_T12_*` bare `expectRevert()` | Any revert greens | `MinAmountOutNotMet` exact |
| `test_T14_witnessMismatchReverts` bare | Wrong path could green | Typed Permit2 / witness fail |
| `test_onlyOwnerRegister` / `test_T31_rescueOnlyOwner` bare | Same | Exact access selector |
| Happy T13 alone as “Permit2 security” | Proves UX only | Add replay/spender/I5 suite |
| Fork allowlist-only as full fork P0 | No multi-venue money path matrix | Extend live hops |

---

## 7. Prior-report diff

| Claim (doc) | Status now (2026-08-09) |
|-------------|-------------------------|
| **Coordinator PRD / plan T1–T32** “suites pass for supported venues” | **Mostly implemented** as named T* tests; **gaps:** T15/T21 quality, T23 UR, formal D/J, exact selectors on T11/T12/T14; **beyond plan:** PRD Router P0 replay/spender not in T1–T32 |
| **TEST_COVERAGE_AUDIT_PRD §2.3 Router P0** (replay, allowance, wrong spender, I5, exact fail, H, N) | **Partial:** H strong; allowance stock/SE yes / UR no; I5 FoT only; exact fail mixed; **replay + wrong spender G** |
| **ADVERSARIAL / NEGATIVE vault reports (2026-07)** | Largely **vault/DETF-centric**; Coordinator **not** scored — this report is first systematic Router-class score |
| **Struct-audit 2026-08-08** | No dedicated Coordinator free-mint claim found in this pass; I/J/K for routers **owned here** (L-TCA-4) |
| **Commons Permit2 theater** | Still true under commons area; **not** Coordinator pull bug |

---

## 8. Work package stubs

### WP-I5-RTR-001

| Field | Value |
|-------|--------|
| **Title** | Coordinator Permit2 P0: replay, wrong spender, I5 variants, typed witness fails |
| **Severity** | High |
| **Class** | TEST |
| **Products** | BalancerV3UniswapV4CoordinatorRouter |
| **Finding IDs** | TCA-RTR-001, TCA-RTR-007, TCA-RTR-002 (T14 portion) |
| **Problem** | Router P0 signature integrity unproven beyond happy witness + FoT short-pull. |
| **Production files (touch set)** | none expected |
| **Test files (touch set)** | `test/foundry/spec/routers/balancerV3-uniswapV4/BalancerV3UniswapV4CoordinatorRouter_Permit2Witness.t.sol` and/or new `..._Permit2Security.t.sol`; reuse `TestBase_BalancerV3UniswapV4CoordinatorRouter` + stock fixture if execute needed |
| **Out of scope files** | Vault SE routers; BasicVaultCommon; Balancer SE DFPkg internals |
| **Depends on** | none |
| **Parallelizable with** | WP-J-RTR-001, WP-N-RTR-001, WP-ALLOW-RTR-001 |
| **Suggested worktree** | `gap_cover_i5-rtr` / branch `gap_cover/i5-rtr` |
| **Implementation notes** | Sign helpers already encode spender=`address(coordinator)` — mutate for wrong spender; after success, replay same nonce; use stock single-hop for funded cases; Prefer exact Permit2 error selectors from Crane `IPermit2` / `ISignatureTransfer` |
| **Acceptance** | `forge test --match-path 'test/foundry/spec/routers/balancerV3-uniswapV4/**' --match-test 'test_I5_'` green; includes replay + wrong spender + token mismatch + FoT (existing T32 may rename/alias) |
| **Anti-theater** | Replay must use **successful first spend** then second call; wrong spender must use **cryptographically valid** sig for wrong address; no `vm.mockCall` on Permit2/Coordinator |
| **Estimate** | M |

### WP-N-RTR-001

| Field | Value |
|-------|--------|
| **Title** | Exact-selector N matrix + missing validation negatives |
| **Severity** | High (clusters TCA-RTR-002 High theater + Medium missing) |
| **Class** | TEST |
| **Products** | Coordinator |
| **Finding IDs** | TCA-RTR-002, TCA-RTR-004, TCA-RTR-013 |
| **Problem** | Bare reverts + untested EmptyRoute/TokenOutMismatch/InvalidEthOut/ZeroAmount. |
| **Test files** | `..._Negative.t.sol`, `..._ExactIn_Stock.t.sol`, `..._Admin.t.sol`, `..._LedgerAndRescue.t.sol` |
| **Out of scope** | Product economics; adapter internal Balancer errors beyond Coordinator selectors |
| **Depends on** | none |
| **Parallelizable with** | WP-I5-RTR-001, WP-J-RTR-001 |
| **Suggested worktree** | `gap_cover_n-rtr` |
| **Acceptance** | All listed errors asserted with `abi.encodeWithSelector` / typed custom errors; `forge test --match-path '.../balancerV3-uniswapV4/**Negative**'` green |
| **Anti-theater** | No bare `expectRevert()` on money negatives in touched files |
| **Estimate** | S–M |

### WP-J-RTR-001

| Field | Value |
|-------|--------|
| **Title** | Coordinator Facet declaration + loupe + proxy surface (J1–J3) |
| **Severity** | High |
| **Class** | TEST |
| **Products** | Coordinator facets + DFPkg |
| **Finding IDs** | TCA-RTR-003 |
| **Problem** | No formal Target⊆facetFuncs⊆cuts⊆loupe⊆proxy proof. |
| **Production files** | none unless PAT-J-OMIT found at implement time |
| **Test files** | new `test/foundry/spec/routers/balancerV3-uniswapV4/behavior/*IFacet*` or package surface suite |
| **Out of scope** | MultiStepOwnable facet unit beyond selectors cut |
| **Depends on** | none |
| **Parallelizable with** | WP-I5-RTR-001, WP-N-RTR-001 |
| **Suggested worktree** | `gap_cover_j-rtr` |
| **Implementation notes** | Crane `Behavior_IFacet` patterns; controls from `IBalancerV3UniswapV4CoordinatorRouter` + Target externals; call on **proxy** from FactoryService deploy |
| **Acceptance** | J1 controls match facetFuncs; J2 loupe complete; J3 every money selector callable on proxy (view ok for pure/view) |
| **Anti-theater** | Must not only call facet implementation address; PAT-J-CTRL: controls not copied from incomplete Facet |
| **Estimate** | S–M |

### WP-ALLOW-RTR-001

| Field | Value |
|-------|--------|
| **Title** | Complete T23 UR ERC-20 residual allowance clear |
| **Severity** | Medium |
| **Class** | TEST |
| **Products** | Coordinator + UR adapter |
| **Finding IDs** | TCA-RTR-006 |
| **Problem** | UR path law unproven post-step `approve(ur)=0`. |
| **Test files** | `..._ExactIn_UR.t.sol` |
| **Depends on** | none |
| **Parallelizable with** | all Wave 1 WPs |
| **Suggested worktree** | `gap_cover_allow-rtr` |
| **Acceptance** | `test_T23_urErc20AllowanceCleared` asserts ERC-20 allowance coordinator→UR == 0 after success |
| **Anti-theater** | Assert after real execute, not only query |
| **Estimate** | S |

### WP-THEATER-RTR-001

| Field | Value |
|-------|--------|
| **Title** | Replace T15/T21 theater with real proofs |
| **Severity** | Medium |
| **Class** | TEST |
| **Products** | Coordinator |
| **Finding IDs** | TCA-RTR-005 |
| **Problem** | Plan IDs claim security without failure modes. |
| **Test files** | `..._Negative.t.sol`, `..._Admin.t.sol` |
| **Depends on** | none (T21 may share stock fixture) |
| **Parallelizable with** | WP-N-RTR-001 (can merge) |
| **Suggested worktree** | `gap_cover_theater-rtr` or fold into `gap_cover_n-rtr` |
| **Acceptance** | T21 execute after unregister reverts `RouterNotAllowed`; T15 rewritten or demoted to Info comment |
| **Anti-theater** | T21 must call money entry, not only view allowlist |
| **Estimate** | S |

### WP-FORK-RTR-001 / WP-L1-RTR-001

| Field | Value |
|-------|--------|
| **Title** | Fork multi-venue depth · L1 ledger fuzz |
| **Severity** | Medium |
| **Class** | TEST |
| **Finding IDs** | TCA-RTR-008, TCA-RTR-009 |
| **Suggested worktree** | `gap_cover_fork-rtr`, `gap_cover_l1-rtr` |
| **Depends on** | Wave 1 security suite preferred first |
| **Priority** | Wave 2–3 |
| **Acceptance** | Fork: ≥1 live UR or multi-step when code present; L1: fuzz hop conservation vs donation |

---

## 9. Deferred / N/A / NEEDS_OWNER

| Item | Class | Reason |
|------|-------|--------|
| I1–I3 pretransfer on Coordinator | **N/A** | No `pretransferred` flag; Permit2/eth only |
| PAT-I-ABS free mint on Coordinator pull | **N/A / clean** | Delta pull + ledger hop (TCA-RTR-010) |
| BasicVaultCommon Permit2 PAT-I-ABS CODE | **DEFER** to commons | Owned by `T-basic-protocol-commons` |
| Balancer SE router full adversarial | **DEFER** | `T-se-univ4-aave-balancer` |
| Exact-out Coordinator API | **N/A** | Product is exact-in only (PRD) |
| Gas-grief max steps | **DEFER** | P2; document route length limits if product adds later |
| `receive()` diamond ETH handling | **Info** | ethOut hermetic tests green; no CODE claim without fail |
| Via_ir / package profiles | **Forbidden** | Do not recommend |

---

## 10. Commands run

```text
# Inventory (repo root /Users/cyotee/Development/projects-defi/daosys/lib/indexedex)
rg -n --type sol 'permit2|Permit2|CoordinatorRouter' contracts/routers test --glob '!lib/**' | head -120
rg -n 'function test_' test/foundry/spec/routers/balancerV3-uniswapV4 --glob '*.sol'
rg -n 'expectRevert\(\)|replay|wrongSpender|InvalidPermit|EmptyRoute|TokenOutMismatch' test/foundry/spec/routers --glob '*.sol'
rg -n 'function testFuzz_|function invariant_' test/foundry/spec/routers --glob '*.sol'
rg -n 'Behavior_IFacet|controlFacetFuncs|facetFuncs' test/foundry/spec/routers --glob '*.sol'
rg -n 'I5|signature replay|wrong spender' lib/crane/.claude/skills/crane-adversarial-testing --glob '**/*'

# Static production reads
# contracts/routers/balancerV3-uniswapV4/{targets,facets,common,interfaces,adapters,DFPkg,FactoryService,TestBase}_*
# test/foundry/spec/routers/balancerV3-uniswapV4/*
# test/foundry/fork/base_main/routers/balancerV3-uniswapV4/*
# docs/testing/TEST_COVERAGE_AUDIT_PRD.md §2.3, §7.2
# contracts/routers/.../BALANCER_V3_UNISWAP_V4_COORDINATOR_ROUTER_PRD.md T1–T32

# Runtime forge (not required for Blocker — none escalated)
# forge test --match-path 'test/foundry/spec/routers/balancerV3-uniswapV4/**' --list
# FOUNDRY_PROFILE=fork forge test --match-path 'test/foundry/fork/base_main/routers/balancerV3-uniswapV4/*'
```

**Runtime proof status:** No Blocker CODE candidate → **no §3.8 Blocker proof run**. Production `_pullPermit` static review = **clean bill** for free-credit class (TCA-RTR-010).

---

## Return summary (orchestrator)

| Field | Value |
|-------|--------|
| **Status** | **COMPLETE** |
| **Blocker** | **0** |
| **High** | **3** (TCA-RTR-001 I5/replay/spender; TCA-RTR-002 exact-fail theater; TCA-RTR-003 J/D surface) |
| **Top WPs** | `WP-I5-RTR-001`, `WP-N-RTR-001`, `WP-J-RTR-001`, `WP-ALLOW-RTR-001`, `WP-THEATER-RTR-001` |
| **OUT_FILE** | `docs/testing/coverage-audit/areas/T-routers-permit2.md` |
