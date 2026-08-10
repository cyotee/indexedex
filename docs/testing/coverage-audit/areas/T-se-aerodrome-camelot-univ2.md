# Test Coverage Audit — T-se-aerodrome-camelot-univ2

| Field | Value |
|-------|--------|
| Date | 2026-08-09 |
| Agent / run | Stage 1 area subagent · pilot · `T-se-aerodrome-camelot-univ2` |
| Status | **COMPLETE** |
| Production paths | `contracts/protocols/dexes/aerodrome/v1/**`, `contracts/protocols/dexes/camelot/v2/**`, `contracts/protocols/dexes/uniswap/v2/**` |
| Test paths | Co-located TestBases; `test/foundry/spec/protocol/dexes/{aerodrome/v1,camelot/v2,uniswap/v2}/**`; `test/foundry/spec/vaults/standard-exchange/adversarial/**`; Aerodrome Base fork under `test/foundry/fork/base_main/aerodrome/**` |
| Skills / PRD version cited | `TEST_COVERAGE_AUDIT_PRD.md` (§2 layers/catalog, §2.4 patterns, §3.8 Blocker proof, §7.2 schema); SE P0 subset (A1, C, E1, E5, H3, F, **I1–I3**, **J1–J3**, **K1**, H, N, D, P); `crane-adversarial-testing` catalog A–K |
| Finding ID prefix | `TCA-SE-AC-NNN` |
| Runtime proofs | **Not executed this subagent** — PAT-I-ABS free-extract labeled **RUNTIME_UNPROVEN** (static overwhelming); orchestrator O3 owns hermetic proof |

---

## 1. Executive summary

### Maturity scores by product (0–5)

| Product | Score | One-line rationale |
|---------|------:|--------------------|
| **Aerodrome V1 SE** | **3** | Strong H/P + multi-pool routes + L1/L3 + Base fork; partial adversarial (A1/E1/E5/F1/H3); **I1–I3 absent**; reserved-dust patch ≠ delta credit; no `*_IFacet` / proxy J suite |
| **Camelot V2 SE** | **2** | Gold deploy path + reentrancy + slippage + thin InOut L1 + thin adversarial; **no full route H matrix**, **no K1 donation**, **no I**, **no J**, **no fork** |
| **Uniswap V2 SE** | **2** | Solid Route4 + InOut + slippage + disable + some P; **no dedicated adversarial**; **no I1–I3**; K1 only on Route4; **no J**; fork only as DualLiquidity/buffer fixture, not SE P0 suite |

### Blocker / High counts

| Severity | Count | Notes |
|----------|------:|-------|
| **Blocker** | **1** | `TCA-SE-AC-001` PAT-I-ABS free credit / free extract on swap·zap·pass-through routes via `pretransferred=true` (all three SEs inherit `BasicVaultCommon`; Aero reserved-dust only) — **RUNTIME_UNPROVEN** |
| **High** | **8** | Missing I1–I3 proofs; PAT-THEATER-PRE; thin SE adversarial + no Uni V2 instance; missing J declaration/proxy; Camelot H/K holes; bare `expectRevert` on E5/H3; shared harness stub; Aerodrome deadline at vault layer |
| **Medium** | **5** | Exact-selector hygiene; Camelot/UniV2 L2–L3; Camelot/UniV2 fork P0 parity; residual-reuse I3 depth; multi-asset surface J expansion |
| **Low / Info** | **3** | Deploy-path quality good; no Mock SE SUT in these trees; prior Wave 2B partial close |

### Top 5 recommended WPs

| Priority | WP-ID | Title |
|---------:|-------|-------|
| 1 | **WP-I-COMMON-001** | Fix `BasicVaultCommon._secureTokenTransfer` pretransfer = **delta/snapshot** (serial; owns CODE root) — *reference; owned by `T-basic-protocol-commons`* |
| 2 | **WP-I-SE-AC-001** | SE I1–I3 adversarial on Aerodrome + Camelot + Uni V2 (post-commons); prove free extract cannot succeed |
| 3 | **WP-ADV-SE-AC-001** | Expand shared SE adversarial harness + **UniV2SE_Adversarial** instance; exact selectors; C-class linkage |
| 4 | **WP-J-SE-AC-001** | Facet `Behavior_IFacet` + proxy loupe/callable J1–J3 for Aero/Camelot/UniV2 In/Out facets |
| 5 | **WP-H-CAM-001** | Camelot full route happy/negative matrix + Route4 K1 donation (parity with Aero/UniV2) |

---

## 2. Product inventory

| Product | DFPkg / key Targets / Facets | TestBase(s) | Test roots | Deploy path quality |
|---------|------------------------------|-------------|------------|---------------------|
| **Aerodrome V1 SE** | `AerodromeStandardExchangeDFPkg`; In/Out Target+Facet; `AerodromeStandardExchangeCommon` (overrides `_secureTokenTransfer`); Repo; FactoryService | `TestBase_AerodromeStandardExchange`, `_MultiPool`; fork `TestBase_AerodromeFork` | `test/foundry/spec/protocol/dexes/aerodrome/v1/**` (routes 1–7, Out swap, fee compound, reentrancy, InOut, Fuzz, `invariant/`); `test/.../standard-exchange/adversarial/AerodromeSE_Adversarial.t.sol`; `test/foundry/fork/base_main/aerodrome/**` | **Gold:** CREATE3 facets + `vm.prank(owner); indexedexManager.deployAerodromeStandardExchangeDFPkg(...)` |
| **Camelot V2 SE** | `CamelotV2StandardExchangeDFPkg`; In/Out Target+Facet; Common extends `BasicVaultCommon` (**no** pretransfer override); FactoryService | `TestBase_CamelotV2StandardExchange` (co-located under `contracts/.../camelot/v2/`) | `test/foundry/spec/protocol/dexes/camelot/v2/**` (DeployWithPool, Slippage, Reentrancy, InOut); `CamelotSE_Adversarial.t.sol` | **Gold:** CREATE3 + `indexedexManager.deployCamelotV2StandardExchangeDFPkg` |
| **Uniswap V2 SE** | `UniswapV2StandardExchangeDFPkg`; In/Out Target+Facet; Common extends `BasicVaultCommon` (**no** pretransfer override); FactoryService | `TestBase_UniswapV2StandardExchange`, `_MultiPool` | `test/foundry/spec/protocol/dexes/uniswap/v2/**` (Deploy, Disable, InOut, Slippage, VaultDeposit, Out PassThrough, RouterRefund); buffer/DualLiquidity consumers | **Gold:** CREATE3 + manager `deployUniswapV2StandardExchangeDFPkg` |
| **Shared SE adversarial** | N/A (test infra) | `TestBase_StandardExchange_Adversarial` (**empty abstract** — virtual hooks only) | `test/foundry/spec/vaults/standard-exchange/adversarial/` | Instances inherit **protocol** TestBases, not the shared abstract |

### Trust-flag entrypoints (all three)

| API | Signature / flag | Notes |
|-----|------------------|-------|
| `exchangeIn` | `(tokenIn, amountIn, tokenOut, minAmountOut, recipient, **pretransferred**, deadline)` | All routes call `_secureTokenTransfer` / `_secureSelfBurn` |
| `exchangeOut` | `(tokenIn, maxAmountIn, tokenOut, amountOut, recipient, **pretransferred**, deadline)` | Exact-out + `_refundExcess` when pretransferred |
| Share burn path | `_secureSelfBurn(..., pretransferred)` | Withdraw / zap-out-withdraw routes |

### Facet list (SE-specific)

| Facet | `facetFuncs` (static) | Target external money/view | Control list Target-derived? |
|-------|----------------------|----------------------------|------------------------------|
| `AerodromeStandardExchangeInFacet` | `previewExchangeIn`, `exchangeIn`, `heldExcessTokens()` | Matches In Target + Common view | Manual list (not auto from Target); **includes** `heldExcessTokens` |
| `AerodromeStandardExchangeOutFacet` | `previewExchangeOut`, `exchangeOut` | Matches Out Target | Manual |
| `CamelotV2StandardExchangeInFacet` | `previewExchangeIn`, `exchangeIn` | Matches | Manual |
| `CamelotV2StandardExchangeOutFacet` | `previewExchangeOut`, `exchangeOut` | Matches | Manual |
| `UniswapV2StandardExchangeInFacet` | `previewExchangeIn`, `exchangeIn` | Matches | Manual |
| `UniswapV2StandardExchangeOutFacet` | `previewExchangeOut`, `exchangeOut` | Matches | Manual |

Plus shared diamond cuts: ERC20 / ERC2612 / ERC5267 / ERC4626 / MultiAsset Basic + Standard vault facets (J bar must include those on **proxy** smoke, not only SE facets).

### Out of area (reference only)

- Slipstream SE (`contracts/protocols/dexes/aerodrome/slipstream/**`) → later / optional `T-slipstream-buffer`
- Uni V3/V4 SE, Aave Stata, Balancer SE routers → `T-se-univ4-aave-balancer`
- `BasicVaultCommon` CODE ownership → `T-basic-protocol-commons` (this area **consumes** the bug)

---

## 3. Layer matrix

Legend: **G** = green/strong · **P** = partial · **F** = fail/missing · **N/A** · **S** = stub/theater

| Product | H | N | D | J | I | K | A–H | P | L1 | L2 | L3 | Notes |
|---------|---|---|---|---|---|---|-----|---|----|----|----|-------|
| Aerodrome V1 SE | G | P | P | F | F | P | P | G | G | F | P | Routes 1–7 + fork; N often bare `expectRevert`; no IFacet/J; I theater+reserved-dust only; K Route4 deposit; A1/E1/E5/F1/H3 + C reentrancy suite; L3 thin handler (3 inv) |
| Camelot V2 SE | P | P | F | F | F | F | P | P | P | F | F | Deploy+slippage subset; no Route H matrix; no K donation; thin A1/E5/F1/H3; C reentrancy; L1 2 fuzz + zero preview |
| Uniswap V2 SE | P | P | F | F | F | P | F | P | P | F | F | Route4 deep; InOut multi-route; no adversarial file; K Route4 only; disable guards; DualLiquidity fork consumer ≠ SE fork P0 |

---

## 4. Catalog matrix (A–K)

| ID | Aerodrome | Camelot | Uni V2 | Evidence (or **G**) |
|----|-----------|---------|--------|---------------------|
| **A1** | P | P | G | `AerodromeSE_Adversarial.test_A1_*`; `CamelotSE_Adversarial.test_A1_*` — donate token, no free **shares**. Does **not** prove donate→pretransfer swap extract. Uni V2: **G** for dedicated A1 |
| **A3** | F | F | F | No LP-donation-as-principal free-mint cases beyond Route4 K-style mismatch |
| **B\*** | N/A* | N/A* | N/A* | No synthetic mint thresholds on SE; rate/route conservation via E1/InOut |
| **C1–C3** | P | P | F | `AerodromeStandardExchange_ReentrancyGuard` / `CamelotV2..._ReentrancyGuard` (IsLocked on in/out). Uni V2: **G** dedicated. Not catalog-named C1–C3 multi-entry |
| **D\*** | N/A | N/A | N/A | No claim/NFT on SE vault |
| **E1** | P | F | P | Aero adversarial `test_E1_swapRoundTrip_bounded`; UniV2/Aero InOut conservation partial; Camelot **G** named E1 |
| **E5** | P | P | F | Adversarial zero-amount bare `expectRevert` (Aero+Camelot); deadline: Camelot/UniV2 have vault-level check; **Aerodrome In/Out lack `DeadlineExceeded` at vault** (router only). Uni V2: no E5 adversarial |
| **F1** | P | P | P | Adversarial diamondCut blocked (Aero+Camelot); UniV2 has **disable** suite (registry), not F1 cut |
| **F2–F3** | N/A | N/A | N/A | Unowned instance after deploy — F1 sufficient class |
| **H2** | F | F | F | Failed-path claim N/A; failed withdraw residual not cataloged |
| **H3** | P | P | P | Adversarial minOut too high residual shares=0 (Aero+Camelot); route slippage suites (all three) often bare revert |
| **I1** | F | F | F | **No** `test_I1_*` false-claim without transfer. Happy `*_pretransferred_true` with **real** transfer only → **PAT-THEATER-PRE** |
| **I2** | F | F | F | No short-pretransfer cases |
| **I3** | F | F | F | No residual-reuse second call |
| **I4** | F | F | F | FoT not product-required P0; score gap |
| **J1** | F | F | F | No `*_IFacet_Test` / Target↔facetFuncs diff tests (contrast Slipstream/UniV3/V4) |
| **J2** | F | F | F | No loupe `facetAddress(sel)` on deployed proxy |
| **J3** | F | F | F | Specs call proxy in practice for routes, but no J surface matrix / FunctionNotFound scan |
| **K1** | P | F | P | Route4: `test_Route4VaultDeposit_reverts_whenDonation*` (Aero + UniV2). Camelot **G**. Swap-path donation inventory steals via I1 → not covered |

\*B1/B3 N/A per PRD SE class when no synthetic thresholds.

---

## 5. Findings

### 5.1 [TCA-SE-AC-001] Blocker · CODE · PAT-I-ABS / catalog I1 · RUNTIME_UNPROVEN

- **Summary:** All three SE packages credit `pretransferred=true` against **absolute** vault balance (`balanceOf >= claimed` → return claimed), not inbound **delta**. Pass-through **swap / zap** paths then spend that credited amount from vault inventory to `recipient` — enabling free extract of donations / residual underlyings without a matching caller transfer. Aerodrome overrides only **reserved fee-compound dust**, still returns claimed amount (no delta).
- **Evidence:**
  - `contracts/vaults/basic/BasicVaultCommon.sol` L33–38: pretransfer branch returns `amountTokenToDeposit`.
  - `contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeCommon.sol` L52–75: reserved subtract then **still** `return amountTokenToDeposit`.
  - Camelot/UniV2 Common: inherit BasicVaultCommon with **no** override.
  - Call sites e.g. Aero `_swapReserveAssets` L460; Camelot In Target L344–350; UniV2 In Target L403–409 → swap after secure transfer.
  - Reserved-dust tests (`test_Route1Swap_pretransferred_true_reverts_whenOnlyReservedDust`) prove dust reservation only — **not** I1 free claim of unreserved donation.
- **Why bar fails:** Catalog I1 + ship-gate “credit = observed inbound delta”; free principal extract on money API.
- **Recommended CODE:** Owned primarily by **WP-I-COMMON-001** (`BasicVaultCommon`): snapshot balance / last known free inventory; credit only delta; update snapshot. Aerodrome reserved amounts fold into free-inventory baseline. Optionally product-level hard fail if delta &lt; claimed without pull.
- **Recommended TEST:** After CODE: `test_I1_claimPretransfer_noTransfer_reverts_orZeroCredit` on **proxy** for Route1 swap (and zap) on all three products; attacker tokenOut balance must not increase; vault free inventory unchanged or strict revert.
- **Suggested WP:** `WP-I-COMMON-001` → `WP-I-SE-AC-001`
- **Priority:** Wave 0 CODE then Wave 1 SE proofs
- **Runtime status:** **RUNTIME_UNPROVEN** this run (static overwhelming). Orchestrator O3 should hermetic-prove on `TestBase_AerodromeStandardExchange_MultiPool` Route1.

### 5.2 [TCA-SE-AC-002] High · TEST · I1–I3 missing (all products)

- **Summary:** No catalog-named or behavioral I1/I2/I3 tests for Aerodrome, Camelot, or Uni V2 SE. Adversarial suites omit trust-flag abuse entirely.
- **Evidence:** `rg test_I[123]_` under SE adversarial + aero/camelot/univ2 trees → empty for SE I-class. Only happy `*_pretransferred_true` with prior real transfer.
- **Why bar fails:** SE P0 requires I1–I3 when `pretransferred` exists.
- **Recommended TEST:**
  - `test_I1_exchangeIn_swap_pretransferred_true_withoutTransfer_reverts`
  - `test_I2_exchangeIn_swap_shortPretransfer_reverts`
  - `test_I3_exchangeIn_residualReuse_secondCall_noFreeOut`
  - Mirror for `exchangeOut` maxIn pretransfer + `_refundExcess` semantics
  - Match-path: `test/foundry/spec/vaults/standard-exchange/adversarial/**` or per-protocol adversarial
- **Suggested WP:** `WP-I-SE-AC-001`
- **Priority:** Wave 1 (after or with commons CODE)

### 5.3 [TCA-SE-AC-003] High · THEATER · PAT-THEATER-PRE

- **Summary:** Pretransfer “coverage” is almost entirely happy-path with real tokens already transferred — cannot fail if absolute-balance credit is wrong.
- **Evidence:** e.g. `AerodromeStandardExchangeIn_Swap.t.sol` `test_Route1Swap_pretransferred_true`; Route2–7 `*_pretransferred_true`; UniV2 `test_Route4VaultDeposit_pretransferred_true`; fork mirrors `*_pretransferred_true`. Aero reserved-dust tests are real negatives but **narrow** (tracked excess only).
- **Why bar fails:** PRD I bar: happy pretransfer + real transfer ≠ I1–I3.
- **Recommended TEST:** Replace theater classification by adding false-claim cases (TCA-SE-AC-002); keep happy paths as H-layer only.
- **Suggested WP:** `WP-I-SE-AC-001`
- **Priority:** Wave 1

### 5.4 [TCA-SE-AC-004] High · TEST · PAT-J (declaration + proxy) · J1–J3

- **Summary:** No `Behavior_IFacet` / `controlFacetFuncs` tests for Aerodrome/Camelot/UniV2 SE facets (unlike Slipstream + Uni V3/V4). No loupe completeness or FunctionNotFound scan on deployed SE diamonds for full product selector set (SE + MultiAsset + ERC4626).
- **Evidence:** `rg controlFacetFuncs` / `*_IFacet_Test` under aero v1 / camelot v2 / uniswap v2 test trees → none. Facet lists appear complete vs In/Out Targets **statically**, but **unproven** J bar.
- **Why bar fails:** J is P0; declaration-only elsewhere rubber-stamps incomplete lists (PAT-J-CTRL risk if someone later adds Target fn without facetFuncs).
- **Recommended TEST:** Six `*_IFacet_Test.t.sol` (In/Out × 3) with Target-derived controls; package deploy → loupe; proxy smoke each selector.
- **Suggested WP:** `WP-J-SE-AC-001`
- **Priority:** Wave 1

### 5.5 [TCA-SE-AC-005] High · TEST · Uni V2 adversarial gap

- **Summary:** Prior plan Wave 2B shipped Aerodrome + Camelot SE adversarial only; Uni V2 still has **no** `UniswapV2SE_Adversarial.t.sol` (A1/E5/H3/F/I/J/K).
- **Evidence:** `test/foundry/spec/vaults/standard-exchange/adversarial/` contains only Aero + Camelot + empty abstract TestBase. Impl plan checklist: Uni V2 deferred.
- **Why bar fails:** Ship-blocking SE product without P0 adversarial subset.
- **Recommended TEST:** `instances/UniswapV2SE_Adversarial.t.sol` on `TestBase_UniswapV2StandardExchange_MultiPool`.
- **Suggested WP:** `WP-ADV-SE-AC-001`
- **Priority:** Wave 1–2

### 5.6 [TCA-SE-AC-006] High · TEST / THEATER · Thin shared SE adversarial + bare selectors

- **Summary:** Existing SE adversarial covers only A1, E5 (zero), H3 (minOut), F1 (cut), E1 (Aero only). Missing C catalog linkage, I, J, K, deadline E5, exact selectors. `TestBase_StandardExchange_Adversarial` is a non-functional stub (instances don’t use it).
- **Evidence:** `AerodromeSE_Adversarial.t.sol`, `CamelotSE_Adversarial.t.sol` — `vm.expectRevert()` without selector; abstract base L10–23 empty hooks.
- **Why bar fails:** Catalog incomplete; bare expectRevert is weak N/theater risk.
- **Recommended TEST:** Expand harness; `expectRevert` typed (`DeadlineExceeded`, `MinAmountNotMet`, custom strings where applicable).
- **Suggested WP:** `WP-ADV-SE-AC-001`
- **Priority:** Wave 2

### 5.7 [TCA-SE-AC-007] High · TEST · Camelot H + K1 holes

- **Summary:** Camelot lacks Aero/UniV2-class route matrix (execVsPreview, balance changes, per-route pretransfer, donation K1 on VaultDeposit). Only DeployWithPool, SlippageProtection (partial routes), Reentrancy, thin InOut fuzz, thin adversarial.
- **Evidence:** `test/foundry/spec/protocol/dexes/camelot/v2/` file list; no `*VaultDeposit*` donation tests; no `*_pretransferred_true` route tests outside reentrancy wiring.
- **Why bar fails:** H + K1 required for money SE; Camelot is production package.
- **Recommended TEST:** Port Aero Route1/4/6 patterns onto `TestBase_CamelotV2StandardExchange`; add Route4 `ERC4626TransferNotReceived` donation cases.
- **Suggested WP:** `WP-H-CAM-001`
- **Priority:** Wave 1–2

### 5.8 [TCA-SE-AC-008] High · CODE · Aerodrome missing vault-level deadline guard

- **Summary:** Camelot + UniV2 `exchangeIn`/`exchangeOut` revert `DeadlineExceeded` when `block.timestamp > deadline`. Aerodrome In/Out pass `deadline` to router/compound only — **no** vault-level check (router may still enforce, but vault API contract differs; pure LP deposit/burn paths may not hit router deadline).
- **Evidence:** Camelot In L308–309; UniV2 In L370–371; Aero In `exchangeIn` has no `DeadlineExceeded` / `block.timestamp > deadline` (grep empty on Targets for that error).
- **Why bar fails:** E5 deadline consistency; stale-tx risk on routes that don’t hit router deadline.
- **Recommended CODE:** Add same `DeadlineExceeded` check at start of Aero `exchangeIn` / `exchangeOut`.
- **Recommended TEST:** `test_E5_deadlineExpired_reverts` exact selector on Aero proxy (all primary routes).
- **Suggested WP:** `WP-E5-AERO-001`
- **Priority:** Wave 1
- **Runtime:** static CODE; severity High (not free-mint Blocker)

### 5.9 [TCA-SE-AC-009] Medium · TEST · Exact-selector hygiene (N layer)

- **Summary:** Many slippage / adversarial negatives use bare `vm.expectRevert()` (Camelot slippage suite, SE adversarial, some Aero route reverts).
- **Evidence:** Camelot `CamelotV2StandardExchangeIn_SlippageProtection.t.sol` multiple bare reverts; SE adversarial E5/H3.
- **Recommended TEST:** Prefer `abi.encodeWithSelector` / typed custom errors.
- **Suggested WP:** cluster under `WP-ADV-SE-AC-001` / `WP-N-SE-AC-001`
- **Priority:** Wave 2

### 5.10 [TCA-SE-AC-010] Medium · TEST · L2/L3 property depth (Camelot, Uni V2)

- **Summary:** Aerodrome has L1 fuzz + thin L3 handler invariants. Camelot has only thin L1 InOut; Uni V2 has strong InOut L1-ish examples but no L3 handler. Sequence L2 absent all three.
- **Evidence:** `aerodrome/v1/invariant/**`; Camelot `InOutInvariant` (3 tests); UniV2 `InOutInvariant` multi-route without handler.
- **Suggested WP:** `WP-L3-SE-AC-001` (Wave 3; may share abstract SE handler)
- **Priority:** Wave 3

### 5.11 [TCA-SE-AC-011] Medium · TEST · Fork P0 parity (Camelot; Uni V2 SE-native)

- **Summary:** Aerodrome has full Base mainnet fork route suite. Camelot has **no** fork suite. Uni V2 appears on fork DualLiquidity / buffer fixtures but not a dedicated SE fork adversarial/P0 matrix. Per L-TCA-5 fork gaps = hermetic severity when product is fork-first; Camelot is primarily Arbitrum — document intended fork chain or accept hermetic as primary with explicit DEFER.
- **Suggested WP:** `WP-FORK-SE-AC-001` or DEFER with chain owner decision
- **Priority:** Wave 2–3 / NEEDS_OWNER for Camelot chain

### 5.12 [TCA-SE-AC-012] Medium · TEST · Route-level pretransfer theater residual (Aero Out refund)

- **Summary:** Aero `exchangeOut` pretransfer refund tests prove refund when **real** over-pretransfer exists — good H/P for refund math, still not I1 false claim.
- **Evidence:** `AerodromeStandardExchangeOut_Swap.t.sol` `test_exchangeOut_swap_pretransferredRefund_*`
- **Suggested WP:** fold into `WP-I-SE-AC-001`
- **Priority:** Wave 1

### 5.13 [TCA-SE-AC-013] Low · Info · Deploy path quality good

- **Summary:** All three TestBases use CREATE3 facets + manager registry DFPkg deploy — production-first bar met. No `MockStandardExchange` / `vm.mockCall` on SUT in these protocol trees.
- **Priority:** none

### 5.14 [TCA-SE-AC-014] Low · THEATER / process · Empty shared adversarial TestBase

- **Summary:** `TestBase_StandardExchange_Adversarial` documents a shared harness but implements nothing; instances duplicate logic.
- **Suggested WP:** `WP-ADV-SE-AC-001` (replace stub with real virtual helpers)
- **Priority:** Wave 2

---

## 6. Theater list

| Test / control | Why theater | Fix |
|----------------|-------------|-----|
| All `*_pretransferred_true` with prior real `transfer` (Aero routes, UniV2 Route4, fork mirrors) | Proves UX only; cannot catch absolute-balance free credit | Add I1–I3 false-claim / short / residual cases |
| Aero `test_Route1Swap_pretransferred_true_reverts_whenOnlyReservedDust` alone as “I coverage” | Only reserved tracked dust; unreserved donation still claimable under PAT-I-ABS | I1 with unreserved donation + no transfer |
| SE adversarial `test_E5_zeroAmount_reverts` / `test_H3_*` bare `expectRevert()` | Any revert passes; wrong selector/path OK | Exact selector + state-unchanged |
| SE adversarial A1 “no free shares” as full donation safety | Does not cover free **swap out** of donated underlyings via pretransfer | Pair with I1 extract test |
| Missing IFacet controls (n/a control list) | Future Target API can ship silent if no J1 | Add declaration tests from Target interface |
| `TestBase_StandardExchange_Adversarial` empty abstract | Looks like shared harness; provides zero cases | Implement or delete |

---

## 7. Prior-report diff

| Claim (doc) | Status now (2026-08-09) |
|-------------|-------------------------|
| **ADVERSARIAL_VAULT_COVERAGE_GAP_REPORT** — SE gap: no product-level adversarial catalog | **Partial close:** Aero+Camelot thin adversarial (A1/E5/F1/H3[+E1 Aero]) exists; **still gap** I/J/K/C catalog depth; Uni V2 still **G** |
| **ADVERSARIAL_VAULT_COVERAGE_IMPLEMENTATION_PLAN** Wave 2B — Aero+Camelot green; Uni V2 later | **Confirmed:** files present; harness incomplete vs plan’s multi-file catalog layout; Uni V2 still open |
| **NEGATIVE_TEST_COVERAGE_REPORT** B1/B2 Route4 donation → `ERC4626TransferNotReceived` | **Closed** for Aero + UniV2 Route4; **still open** for Camelot; does **not** close I1 on swap |
| **NEGATIVE_TEST** C1 pretransfer UX notes | **Still open** as I-class; happy pretransfer still dominant |
| **aerodrome-v1-vault-test-coverage.md** (2025-12-31) “comprehensive 119 tests / pretransferred covered” | **Stale optimism:** H/P strong; pretransfer claim **overstates** security (theater vs I1–I3); adversarial/I/J not in that doc |
| **FUZZ_INVARIANT** Wave 2A Aerodrome L3; 2B Camelot InOut; 2C UniV2 InOut | **Still true:** Aero invariant/ + Fuzz exist; Camelot InOut thin; UniV2 InOut exists; L2 still weak |
| Struct-audit I/J/K supersession (L-TCA-4) | This report **owns** SE I/J/K TEST/CODE WPs; link commons CODE to `T-basic-protocol-commons` |

---

## 8. Work package stubs

### WP-I-COMMON-001 (reference — commons area owns)

| Field | Value |
|-------|--------|
| **Title** | Fix PAT-I-ABS in `BasicVaultCommon._secureTokenTransfer` |
| **Severity** | Blocker |
| **Class** | CODE (+ shared unit tests) |
| **Products** | All SE/DETF consumers including Aero/Camelot/UniV2 |
| **Finding IDs** | TCA-SE-AC-001 (+ commons TCA-COMMON-*) |
| **Problem** | Pretransfer returns claimed amount on absolute balance; free extract on swap/zap. |
| **Production files** | `contracts/vaults/basic/BasicVaultCommon.sol`; possibly Aerodrome override rework |
| **Test files** | Commons unit + SE I1 suite |
| **Out of scope** | Unrelated ERC4626 deposit accounting unless coupled |
| **Depends on** | none |
| **Parallelizable with** | J/N WPs that don’t edit BasicVaultCommon |
| **Suggested worktree** | `gap_cover_i-common` |
| **Implementation notes** | Delta vs balBefore or free-inventory snapshot; update NatSpec to match; keep Permit2 pull path |
| **Acceptance** | Hermetic I1 free-extract fails to profit on Aero Route1; reserved dust still protected |
| **Anti-theater** | I1 must **not** transfer tokens from attacker |
| **Estimate** | M |

### WP-I-SE-AC-001

| Field | Value |
|-------|--------|
| **Title** | SE I1–I3 + residual extract proofs on Aero, Camelot, Uni V2 |
| **Severity** | High (Blocker until commons CODE lands) |
| **Class** | TEST (BOTH if product-local mitigations) |
| **Products** | Aerodrome V1, Camelot V2, Uni V2 SE |
| **Finding IDs** | TCA-SE-AC-001, 002, 003, 012 |
| **Problem** | No false-claim / short / residual-reuse tests; theater happy pretransfer only. |
| **Production files** | none if commons-only fix; else SE Common overrides |
| **Test files** | `test/foundry/spec/vaults/standard-exchange/adversarial/*`; optional per-protocol |
| **Out of scope** | DETF mint pretransfer |
| **Depends on** | WP-I-COMMON-001 (for green-after-fix); can land **failing** proofs first |
| **Parallelizable with** | WP-J-SE-AC-001, WP-H-CAM-001 |
| **Suggested worktree** | `gap_cover_i-se-ac` |
| **Implementation notes** | Gold: MultiVault I-class patterns; use production TestBases; Route1 swap primary; add zap + exchangeOut |
| **Acceptance** | `forge test --match-path 'test/foundry/spec/vaults/standard-exchange/adversarial/**' --match-test 'test_I'` green after CODE; I1 no attacker tokenOut gain |
| **Anti-theater** | I1 no transfer; I2 short transfer; I3 second call without new funds |
| **Estimate** | M |

### WP-ADV-SE-AC-001

| Field | Value |
|-------|--------|
| **Title** | Expand SE adversarial harness + UniV2 instance + exact selectors |
| **Severity** | High |
| **Class** | TEST |
| **Products** | All three SE |
| **Finding IDs** | TCA-SE-AC-005, 006, 009, 014 |
| **Problem** | Thin A1/E5/H3/F only; no UniV2; bare reverts; empty abstract base. |
| **Test files** | `test/foundry/spec/vaults/standard-exchange/adversarial/**` |
| **Out of scope** | Uni V4 / Aave (other area) |
| **Depends on** | none for A/E/H/F; I cases depend WP-I-SE-AC-001 |
| **Parallelizable with** | WP-J-SE-AC-001, WP-H-CAM-001 |
| **Suggested worktree** | `gap_cover_adv-se-ac` |
| **Acceptance** | UniV2 A1/E5/H3/F1 green; typed reverts; shared base used by 3 instances |
| **Anti-theater** | A1 not counted as I1; H3 asserts residual 0 |
| **Estimate** | M |

### WP-J-SE-AC-001

| Field | Value |
|-------|--------|
| **Title** | J1–J3 Facet declaration + proxy surface for SE packages |
| **Severity** | High |
| **Class** | TEST (CODE only if omission found) |
| **Products** | All three SE |
| **Finding IDs** | TCA-SE-AC-004 |
| **Problem** | No IFacet controls or loupe/proxy matrix. |
| **Test files** | new `*_IFacet_Test.t.sol` under each protocol test tree; optional package surface test |
| **Out of scope** | MultiAsset facet unit ownership (may smoke only) |
| **Depends on** | none |
| **Parallelizable with** | all I/ADV WPs |
| **Suggested worktree** | `gap_cover_j-se-ac` |
| **Acceptance** | Control lists from Target/interface; `facetAddress` non-zero; proxy calls succeed for views / revert access-correct for state |
| **Anti-theater** | J3 calls **proxy**, not facet impl address |
| **Estimate** | S–M |

### WP-H-CAM-001

| Field | Value |
|-------|--------|
| **Title** | Camelot route H matrix + Route4 K1 donation parity |
| **Severity** | High |
| **Class** | TEST |
| **Products** | Camelot V2 SE |
| **Finding IDs** | TCA-SE-AC-007 |
| **Problem** | Camelot lacks Aero-class happy/negative/donation coverage. |
| **Test files** | `test/foundry/spec/protocol/dexes/camelot/v2/**` |
| **Out of scope** | DFPkg deploy (already strong) |
| **Depends on** | none |
| **Parallelizable with** | WP-J-SE-AC-001, WP-ADV-SE-AC-001 |
| **Suggested worktree** | `gap_cover_h-cam` |
| **Acceptance** | Route1 + Route4 execVsPreview + donation mismatch selectors; optional Route6 smoke |
| **Anti-theater** | No mock SUT; exact `ERC4626TransferNotReceived` where applicable |
| **Estimate** | M |

### WP-E5-AERO-001

| Field | Value |
|-------|--------|
| **Title** | Aerodrome vault-level deadline + E5 tests |
| **Severity** | High |
| **Class** | BOTH |
| **Products** | Aerodrome V1 SE |
| **Finding IDs** | TCA-SE-AC-008 |
| **Production files** | `AerodromeStandardExchangeInTarget.sol`, `...OutTarget.sol` |
| **Test files** | adversarial or route negatives |
| **Depends on** | none |
| **Parallelizable with** | WP-J-SE-AC-001 |
| **Suggested worktree** | `gap_cover_e5-aero` |
| **Acceptance** | `DeadlineExceeded` on expired deadline for deposit-only and swap routes |
| **Anti-theater** | Exact selector |
| **Estimate** | S |

### WP-L3-SE-AC-001 (Wave 3)

| Field | Value |
|-------|--------|
| **Title** | Camelot/UniV2 L1 tighten + optional shared SE L3 handler |
| **Severity** | Medium |
| **Class** | TEST |
| **Finding IDs** | TCA-SE-AC-010 |
| **Depends on** | Aero handler patterns |
| **Suggested worktree** | `gap_cover_l3-se-ac` |
| **Estimate** | L |

---

## 9. Deferred / N/A / NEEDS_OWNER

| Item | Class | Note |
|------|-------|------|
| DETF-style B1/B3 synthetic gates | N/A | SE has no synthetic mint threshold |
| Claim/NFT D-class | N/A | Not SE surface |
| Camelot production fork chain (Arbitrum vs hermetic-only) | NEEDS_OWNER | Whether missing fork is P0 (L-TCA-5) |
| Donation economic beneficiary vs strict revert (swap dust) | NEEDS_OWNER if product wants “next user benefits” — today absolute pretransfer enables **attacker** benefit → CODE fix preferred over product-law accept |
| Slipstream SE | DEFER | Out of this area |
| Full MEV sandwich reconstruction | DEFER | P2 per prior adversarial report |
| FoT I4 | DEFER | P1 unless product supports FoT underlyings |
| Runtime Blocker proof | Orchestrator O3 | Hermetic Aero Route1 donate + pretransfer claim |

---

## 10. Commands run

Static inventory only (no forge suite execution this subagent; no production/test edits).

```bash
# Production trees
ls contracts/protocols/dexes/aerodrome/v1/
ls contracts/protocols/dexes/camelot/v2/
ls contracts/protocols/dexes/uniswap/v2/

# Pattern / signal greps (workspace-scoped)
rg -n --type sol 'pretransferred|_secureTokenTransfer|function facetFuncs' \
  contracts/protocols/dexes/aerodrome/v1 \
  contracts/protocols/dexes/camelot/v2 \
  contracts/protocols/dexes/uniswap/v2

rg -n --type sol 'function test_I[0-9]_|function test_A1_|function test_J[0-9]_|function test_K1_' \
  test/foundry/spec/vaults/standard-exchange/adversarial \
  test/foundry/spec/protocol/dexes/aerodrome/v1 \
  test/foundry/spec/protocol/dexes/camelot/v2 \
  test/foundry/spec/protocol/dexes/uniswap/v2

rg -n --type sol 'controlFacetFuncs|Behavior_IFacet|_IFacet_Test' test --glob '*{Aerodrome,Camelot,UniswapV2}*'

rg -n --type sol 'MockStandardExchange|vm\.mockCall' \
  test/foundry/spec/protocol/dexes/aerodrome \
  test/foundry/spec/protocol/dexes/camelot \
  test/foundry/spec/protocol/dexes/uniswap/v2

# Adversarial + prior docs
ls test/foundry/spec/vaults/standard-exchange/adversarial/
# Read: ADVERSARIAL_VAULT_COVERAGE_GAP_REPORT.md, IMPLEMENTATION_PLAN Wave 2B,
#       NEGATIVE_TEST_COVERAGE_REPORT.md §B, aerodrome-v1-vault-test-coverage.md,
#       BasicVaultCommon.sol, *SE_Adversarial.t.sol, Route4 donation tests

# Suggested acceptance commands (Stage 3 — not run here)
forge test --match-path 'test/foundry/spec/vaults/standard-exchange/adversarial/**'
forge test --match-path 'test/foundry/spec/protocol/dexes/aerodrome/v1/**'
forge test --match-path 'test/foundry/spec/protocol/dexes/camelot/v2/**'
forge test --match-path 'test/foundry/spec/protocol/dexes/uniswap/v2/**'
# FOUNDRY_PROFILE=fork forge test --match-path 'test/foundry/fork/base_main/aerodrome/**' --fork-url base_mainnet_alchemy
```

### Suggested O3 runtime proof sketch (orchestrator)

```text
Hermetic: TestBase_AerodromeStandardExchange_MultiPool
1) Deploy balanced vault
2) deal/mint tokenA to attacker; transfer donation D to vault (no exchange)
3) attacker: exchangeIn(tokenA, D, tokenB, 0, attacker, pretransferred=true, deadline)
4) Observe: tokenB balance of attacker increases without attacker balance decrease beyond gas
→ confirms TCA-SE-AC-001; log under docs/testing/coverage-audit/repro/TCA-SE-AC-001/
```

---

## Appendix A — Test root map (detail)

### Aerodrome hermetic

| File / dir | Role |
|------------|------|
| `AerodromeStandardExchangeIn_{Swap,ZapIn,ZapOut,VaultDeposit,VaultWithdraw,ZapInDeposit,ZapOutWithdraw}.t.sol` | H/P/N route matrix |
| `AerodromeStandardExchangeOut_Swap.t.sol` | exchangeOut + pretransfer refund H |
| `AerodromeStandardExchange_FeeCompound.t.sol` | compound / dust |
| `AerodromeStandardExchange_ReentrancyGuard.t.sol` | C-class |
| `AerodromeStandardExchange_InOutInvariant.t.sol` | L1 route inverse |
| `AerodromeStandardExchange_Fuzz.t.sol` | math L1 |
| `AerodromeStandardExchange_DeployWithPool.t.sol` | DFPkg deploy |
| `invariant/*` | L3 thin |
| `.../standard-exchange/adversarial/AerodromeSE_Adversarial.t.sol` | A1/E1/E5/F1/H3 |

### Camelot hermetic

| File | Role |
|------|------|
| `CamelotV2StandardExchange_DeployWithPool.t.sol` | deploy H/N (strong exact selectors) |
| `CamelotV2StandardExchangeIn_SlippageProtection.t.sol` | partial route N |
| `CamelotV2StandardExchange_ReentrancyGuard.t.sol` | C |
| `CamelotV2StandardExchange_InOutInvariant.t.sol` | thin L1 |
| `CamelotSE_Adversarial.t.sol` | A1/E5/F1/H3 |

### Uni V2 hermetic

| File | Role |
|------|------|
| `UniswapV2StandardExchange_DeployWithPool.t.sol` | deploy |
| `UniswapV2StandardExchange_InOutInvariant.t.sol` | multi-route P |
| `UniswapV2StandardExchangeIn_VaultDeposit.t.sol` | Route4 H + K donation |
| `UniswapV2StandardExchangeIn_SlippageProtection.t.sol` | N partial |
| `UniswapV2StandardExchangeOut_PassThrough.t.sol` | Out H |
| `UniswapV2StandardExchange_Disable.t.sol` | registry disable |
| `UniswapV2Vault_RouterRefund.t.sol` | pretransfer refund H |
| *(missing)* `UniswapV2SE_Adversarial.t.sol` | gap |

### Aerodrome fork

`test/foundry/fork/base_main/aerodrome/AerodromeFork_{Swap,ZapIn,ZapOut,VaultDeposit,VaultWithdraw,ZapInDeposit,ZapOutWithdraw,IStandardExchangeIn}.t.sol` + `TestBase_AerodromeFork.sol`.

---

## Appendix B — Pattern hunt summary

| Pattern | Hit? | Products | Finding |
|---------|------|----------|---------|
| **PAT-I-ABS** | **YES** | All three (+ Aero partial reserved) | TCA-SE-AC-001 |
| **PAT-J-OMIT** | Unproven / low static risk for SE In/Out API | — | TCA-SE-AC-004 (TEST proof required) |
| **PAT-J-CTRL** | No controls exist → risk if added later | All | TCA-SE-AC-004 |
| **PAT-K-DONATE** | Partial (Route4 Aero/UniV2); swap free inventory via I | All | TCA-SE-AC-001/007 |
| **PAT-THEATER-PRE** | **YES** | All three | TCA-SE-AC-003 |
| **PAT-THEATER-FACET** | Declaration tests absent | All | TCA-SE-AC-004 |
| **PAT-PREV** | No major static mismatch found; P strong on Aero | — | Info |
| **PAT-MOCK** | **No** in these trees | — | TCA-SE-AC-013 |

---

**Area status: COMPLETE** · Report path: `docs/testing/coverage-audit/areas/T-se-aerodrome-camelot-univ2.md` · Blockers: **1** · Highs: **8** · Top WPs: `WP-I-COMMON-001`, `WP-I-SE-AC-001`, `WP-ADV-SE-AC-001`, `WP-J-SE-AC-001`, `WP-H-CAM-001`.
