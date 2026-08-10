# Test Coverage Audit — T-detf-dual-liquidity

| Field | Value |
|-------|--------|
| Date | 2026-08-09 |
| Agent / run | Stage 1 area subagent · **full** · `T-detf-dual-liquidity` |
| Status | **COMPLETE** |
| Production paths | `contracts/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/**` |
| Test paths | `test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2/**` (incl. `adversarial/`); hermetic: MathLib pure only under same tree; matrix consumers under `test/.../standardExchange/single/*DualLiquidity*` (**reference**, outer SE DETF owned elsewhere) |
| Skills / PRD version cited | `TEST_COVERAGE_AUDIT_PRD` §2,2.3–2.4,3.8,5,6,7.2,8,19 (L-TCA-5 fork P0 = hermetic severity); crane-adversarial A–K + `implementation-test-dod.md`; crane-testing LR-7; prior seeds `ADVERSARIAL_VAULT_COVERAGE_*`, `FUZZ_INVARIANT_COVERAGE_*` |
| Finding ID prefix | `TCA-DETF-DL-NNN` |
| Focus | Catalog consolidation; **ShareInflation vs I/K**; fork-first P0 gaps |

---

## 1. Executive summary

### Maturity (0–5)

| Product | Maturity | Worst open severity | One-line |
|---------|----------|---------------------|----------|
| **DualLiquidityLinkedCrossVersionUniswapVault** | **2** | **Blocker** (CODE, RUNTIME_UNPROVEN) | Rich **fork** H/N/P + partial A–H security slices; catalog “P0 complete” claim is **stale under A–K**. Package-local **PAT-I-ABS** on `_receive` / `_receiveOut`; ShareInflation is **A3-class only**, not I/K. No formal I1–I3. J partial via immutability/registry, not J1–J3 catalog. |

Product class for P0 subset: **Standard Exchange vault** (implements `IStandardExchangeIn`/`Out`; DETF-like share + `reserveBpt` economics; **no** bond/claim NFT surface). Bond/claim catalog rows (D2–D6, F2–F3 bond NFT) = **N/A**.

### Severity counts (this area)

| Severity | Count | IDs |
|----------|-------|-----|
| **Blocker** | **2** | TCA-DETF-DL-001, TCA-DETF-DL-002 |
| **High** | **3** | TCA-DETF-DL-003, TCA-DETF-DL-004, TCA-DETF-DL-005 |
| Medium | 3 | TCA-DETF-DL-006 … 008 |
| Low / Info | 3 | TCA-DETF-DL-009 … 011 |

### Top 5 recommended WPs

1. **WP-I-DETF-DL-001** — CODE: delta-safe `_receive` / `_receiveOut` (Blocker; package-local, not BasicVaultCommon)
2. **WP-I-DETF-DL-002** — TEST (fork): I1–I3 + K1 donation→pretransfer free mint/extract (High; depends on 001)
3. **WP-J-DETF-DL-001** — TEST: J1–J3 Target/interface controls + loupe + **proxy** smoke (High)
4. **WP-CAT-DETF-DL-001** — TEST: real catalog consolidation (A1 multi-asset, honest H3, ID NatSpec; kill theater map test) (Medium→High under L-TCA-5 if treated as P0 honesty)
5. **WP-N-DETF-DL-001** — TEST: exact selectors on bare `expectRevert` guards/H3 (Medium)

**Do not** count ShareInflation or happy Permit2 pretransfer as I/K. **Do not** lower severity because product is fork-only (L-TCA-5).

### Headline (ShareInflation vs I/K)

| Claim often made | Reality |
|------------------|---------|
| ShareInflation “covers donation / inflation” | **A3-class**: idle **`reserveBpt`** donation does not zero victim / free-mint on **pull-path** deposits |
| Pretransfer is “tested” | Happy-path only (`test_depositPretransferred_mintsShares`, Permit2 prefund) = **PAT-THEATER-PRE** for I |
| Wave 2A “P0 catalog complete” | A–H **partial** via scattered files + thin `adversarial/` fill; **I/J/K ship-gate fail**; CODE free principal |

---

## 2. Product inventory

### 2.1 Production package

| Product | DFPkg / key Targets | Facets | TestBase | Test roots | Deploy path quality |
|---------|---------------------|--------|----------|------------|---------------------|
| **DualLiquidityLinkedCrossVersionUniswapVault** | `DualLiquidityLinkedCrossVersionUniswapVaultDFPkg.sol`; Targets: ExchangeIn, ExchangeInQuery, ExchangeOut, ExchangeOutQuery; Common+Repo+MathLib | ExchangeIn / InQuery / Out / OutQuery + ERC20 / ERC2612 / ERC5267 / MultiAsset Basic+Standard vault facets (9 cuts) | **`TestBase_DualLiquidityLinkedCrossVersionUniswapVault.sol`** — **Base fork gold** (`TestBase_BaseFork` + IndexedexTest) | Fork tree under `test/foundry/fork/base_main/.../crossVersion/v2/**` | **Gold fork path**: CREATE3 Facet/Pkg factories + manager/registry deploy; live Uni V4/V2 + Balancer on Base. **Never** mock SUT. Hermetic full product = **absent** (intentional fork-first). |

### 2.2 Production file inventory (package root)

| Path | Role |
|------|------|
| `DualLiquidityLinkedCrossVersionUniswapVaultDFPkg.sol` | DFPkg, facetCuts (9), registry `processArgs` gate |
| `DualLiquidityLinkedCrossVersionUniswapVaultExchangeInTarget.sol` | `exchangeIn` deposit/redeem/swap; **`_receive` PAT-I-ABS** |
| `DualLiquidityLinkedCrossVersionUniswapVaultExchangeInFacet.sol` | `facetFuncs` → `exchangeIn` only |
| `DualLiquidityLinkedCrossVersionUniswapVaultExchangeInQueryTarget/Facet.sol` | `previewExchangeIn` |
| `DualLiquidityLinkedCrossVersionUniswapVaultExchangeOutTarget.sol` | `exchangeOut`; **`_receiveOut` PAT-I-ABS + donation refund** |
| `DualLiquidityLinkedCrossVersionUniswapVaultExchangeOutFacet.sol` | `facetFuncs` → `exchangeOut` only |
| `DualLiquidityLinkedCrossVersionUniswapVaultExchangeOutQueryTarget/Facet.sol` | `previewExchangeOut` |
| `DualLiquidityLinkedCrossVersionUniswapVaultCommon.sol` | share mint/burn vs `reserveBpt`, residual sweep, join/exit |
| `DualLiquidityLinkedCrossVersionUniswapVaultRepo.sol` | storage + errors |
| `DualLiquidityLinkedCrossVersionUniswapVaultMathLib.sol` | pro-rata share math (pure) |
| `*_FactoryService.sol` (Component/Facet/Pkg) | CREATE3 helpers |

### 2.3 Trust-flag entrypoints (I-applicable)

| Entrypoint | Flag | Behavior |
|------------|------|----------|
| `exchangeIn` deposit (non-BPT) | `pretransferred_` | `_receive`: **no-op** if true — credits claimed `amountIn_` from inventory |
| `exchangeIn` swap | `pretransferred_` | same `_receive` |
| `exchangeIn` redeem (`kindIn=Shares`) | ignored | burns `detfToken` from `msg.sender` via `_burnSharesForBpt` (no pretransfer credit path) |
| `exchangeIn` **reserveBpt** deposit | `pretransferred_=true` | **reverts** `UnsupportedRoute` (intentional) |
| `exchangeOut` deposit/swap (non-BPT) | `pretransferred` | `_receiveOut`: no pull; **refunds `held - amountIn` treating all held as caller’s** |
| `exchangeOut` reserveBpt | `pretransferred=true` | **reverts** `UnsupportedRoute` |
| `previewExchangeIn/Out` | N/A | views |

### 2.4 Facet surface (J static skim)

| Facet | Selectors in `facetFuncs` |
|-------|---------------------------|
| ExchangeIn | `IStandardExchangeIn.exchangeIn` |
| ExchangeInQuery | `IStandardExchangeIn.previewExchangeIn` |
| ExchangeOut | `IStandardExchangeOut.exchangeOut` |
| ExchangeOutQuery | `IStandardExchangeOut.previewExchangeOut` |
| + MultiAsset / ERC20 stack | vault views, ERC20/2612/5267 |

**Static J1 impression:** SE money API appears covered by dedicated facets. **Not** proven by Target↔facetFuncs formal suite. Immutability + DFPkg registry tests cover F1 / cut count / no `diamondCut` — **partial J/F**, not J1–J3 catalog.

### 2.5 Test roots (fork-first)

| Root | Role | Notes |
|------|------|-------|
| `TestBase_DualLiquidityLinkedCrossVersionUniswapVault.sol` | Gold fork TestBase | Permit2 helpers; bootstrap reserve; production DFPkg |
| `*_Deposits/Redemptions/Swaps/ExactOut*.t.sol` | Happy path + preview≡execute | Strong H/P |
| `*_Guards.t.sol` | N (minOut, deadline, recipient) | Some bare `expectRevert` |
| `*_ShareInflation.t.sol` | **A3-class** BPT donation | **Not I/K** |
| `*_Reentrancy*.t.sol` | C-class `IsLocked` | Exact selector |
| `*_Residual.t.sol` | E/H residual cleanliness | |
| `*_Immutability.t.sol` | F1 / no owner / loupe no cut | Partial J/F |
| `*_RateExtremes.t.sol` / `*_BestRoute.t.sol` | B-ish price/route stress | |
| `*_Invariants.t.sol` / `*_InvariantHandler.t.sol` | **L2 sequences** (not Foundry L3 runner) | Explicit fork-RPC defer of L3 |
| `*_Permit2*.t.sol` | Happy prefund + `pretransferred=true` | **Not I1–I3** |
| `adversarial/Adversarial_DualLiquidity_Catalog.t.sol` | Thin H3/F1 fill + map claim | Theater risk |
| `adversarial/DualLiquidity_ADVERSARIAL_CATALOG.md` | ID map | Claims P0 complete |
| `*MathLib.t.sol` | Hermetic pure + 1 `testFuzz_` | Only hermetic product-adjacent suite |
| Outer matrix `SingleStandardExchangeDETF_DualLiquidityMatrix.t.sol` | DualLiquidity as **underlyingVault** | Out-of-area ownership (Single SE); cite only |

**Hermetic product SUT suite:** **G** (none). Per L-TCA-5, do **not** treat as excuse to downgrade fork P0 gaps.

---

## 3. Layer matrix

Legend: **F** full · **P** partial · **G** gap · **N/A** · **S** stub/theater

| Product | H | N | D | J | I | K | A–H | P | L1 | L2 | L3 | Maturity | Notes |
|---------|---|---|---|---|---|---|-----|---|----|----|----|----------|-------|
| DualLiquidityLinked… | **F** (fork) | **P** | **P** | **P** | **G** / **S**† | **G** | **P**‡ | **F** | **P** (math) | **P**/**F** seq | **G** (fork defer) | **2** | Blocker CODE I; ShareInflation ≠ I/K |

† Happy pretransfer only (theater for I); zero `test_I1_`/`I2_`/`I3_`.  
‡ Scattered security files + thin adversarial fill; not MultiVault-grade ID suite.

### Layer evidence (summary)

| Layer | Evidence |
|-------|----------|
| **H** | Deposits, redemptions, swaps, exact-out matrix, bootstrap, fees, fee routes, redeposit, partial value, rates on/off, deploy variants, Permit2 cycles, disable/registry |
| **N** | Zero/deadline/minOut/maxIn/unsupported route; registry non-caller; BPT pretransfer reverts; some bare reverts |
| **D** | DFPkg registry metadata + facetCuts length; FactoryService deploy facets; **no** Behavior_IFacet Target-derived controls |
| **J** | Immutability loupe (no diamondCut/owner); facet count floors; money paths exercised on **proxy** in H — **no** `test_J1/J2/J3_*` |
| **I** | **G** for adversarial I; happy pretransfer = THEATER for I bar |
| **K** | A3 BPT idle donation (pull path) **P** for inflation only; **G** for donation + `pretransferred=true` free credit/extract |
| **A–H** | See §4 |
| **P** | Multiple `previewMatchesExecution` on deposit/redeem/swap/ratesOn |
| **L1** | MathLib `testFuzz_roundTrip_neverProfits` only |
| **L2** | `*_Invariants.t.sol` + `*_InvariantHandler.t.sol` multi-op sequences |
| **L3** | Explicitly avoided on fork (RPC); no hermetic L3 substitute |

---

## 4. Catalog matrix (A–K)

Product-class P0 default (**SE vault**, PRD §2.3): A1, C (in/out), E1, E5, H3, F (if unowned), **I1–I3**, **J1–J3**, **K1**, H, N, D, P.

| ID | Score | Evidence (test name) or G |
|----|-------|---------------------------|
| **A1** | **P** | Idle non-BPT inventory not auto-credited on pull path is **implicit**; no dedicated multi-asset donate suite. BPT idle covered by ShareInflation (A3 overlap) |
| **A3** | **F** | `test_bptDonation_cannotStealVictimDeposit`, `test_frontRunDonation_doesNotZeroVictim` (**ShareInflation** — BPT only) |
| A2/A4–A5 | **G** / **DEFER** | detfToken donate-to-diamond / P2 |
| **B** (rate) | **P** | `*_RateExtremes`, `*_BestRoute` — not formal B1/B3 threshold gates (N/A synthetic thresholds) |
| **C1–C3** | **F**/**P** | `test_reentrancy_exchangeIn_deposit_revertsIsLocked`, cross-function exchangeOut, redeem reentry (`*_Reentrancy*.t.sol`) — exact `IsLocked` |
| **D2–D6** | **N/A** | No bond/claim NFT surface |
| **E1** | **P**/**F** | Invariants deposit→redeem never profits; residual suites; fee non-dilution |
| **E5** | **F**/**P** | Zero/deadline in Deposits/Guards/AssetRedemptions; some bare reverts |
| **F1** | **F**/**P** | Immutability + `test_F1_diamondCut_notCallable` + registry facetCuts |
| F2–F3 | **N/A** | No onlyOwner inventory NFT mint/burn |
| **H2** | **N/A** / **P** | Claim redeem N/A; residual after ops covered |
| **H3** | **S**/**P** | Catalog `test_H3_failedMint_minOut_leavesNoInventoryOnVault` is **weak** (zero amount + `address(0)`, bare revert). Stronger residual after success paths in `*_Residual.t.sol` / Guards minOut |
| **I1** | **G** | no test; happy pretransfer is **not** I1 |
| **I2** | **G** | no short-pretransfer test |
| **I3** | **G** | no residual-reuse second call |
| I4 | **G**/**DEFER** | FoT on Base legs uncommon |
| **I5** | **P** | Permit2 happy; not adversarial signature/replay suite (router area may own) |
| **J1** | **G** | no Target/interface ↔ `facetFuncs` control test |
| **J2** | **P** | loupe used in immutability (negative selectors); not full product selector map |
| **J3** | **P** | proxy heavily used in H; no systematic J3 catalog |
| **K1** | **G**/**P** | A3 ≠ K1 pretransfer; **CODE** free credit via donation + flag (001/002) |

**P0 SE subset:** C/E5/F1/H/P strong-partial; **I1–I3 = G**; **J1–J3 = G/P**; **K1 = G** with **CODE**; A1 incomplete; H3 theater risk.

---

## 5. Findings

### 5.1 [TCA-DETF-DL-001] Blocker · CODE · PAT-I-ABS (`_receive` exact-in)

- **Summary:** `_receive(..., pretransferred_=true)` is a **no-op**. Deposit and swap routes then consume claimed `amountIn_` from whatever inventory sits on the diamond (including prior donations of `pairToken` / `rateAsset` / leg `vaultShare`), minting `detfToken` or paying swap output — **free principal**.
- **Evidence:**
  - `DualLiquidityLinkedCrossVersionUniswapVaultExchangeInTarget.sol` ~463–468 (`_receive`)
  - Call sites: `_deposit` non-BPT ~87–94; swap branch ~62
  - Residual snapshot/sweep: `DualLiquidityLinkedCrossVersionUniswapVaultCommon.sol` ~580–597 (resting balances protect **pre-call** inventory as “normal”, do not require inbound delta)
- **Why bar fails:** Ship-gate I + L-CLAIM-3 style accounting: credit observed inbound delta, never claim alone.
- **Recommended CODE:** Always measure `balBefore`; if pretransferred, require `balAfter - balBefore >= amountIn_` (or credit **only** delta and reject shortfall with exact error). Align with ERC4626 `_securePull` / Wave-0 commons pattern **but this package does not use BasicVaultCommon** — package-local fix required.
- **Recommended TEST:** `test_I1_pretransferred_true_noTransfer_existingPairTokenInventory_noFreeMint` on fork TestBase (see WP-I-DETF-DL-002).
- **Suggested WP:** WP-I-DETF-DL-001
- **Priority:** Wave 0/1 — Blocker
- **Runtime:** **RUNTIME_UNPROVEN** — static overwhelming; repro: `docs/testing/coverage-audit/repro/TCA-DETF-DL-001/notes.md`

### 5.2 [TCA-DETF-DL-002] Blocker · CODE · PAT-I-ABS + donation theft (`_receiveOut` exact-out)

- **Summary:** `_receiveOut` with `pretransferred=true` does not verify caller funding. It treats **entire** `balanceOf(this)` as caller prefund and **refunds `held - amountIn` to `msg.sender`**. Attacker can: (a) fund exact-out deposit/swap from donated inventory, and (b) **steal residual donation** as “surplus refund”. Happy-path `test_exactOutMatrix_swap_pretransferredRefundsSurplus` only proves refund when **caller** prefunded surplus.
- **Evidence:** `DualLiquidityLinkedCrossVersionUniswapVaultExchangeOutTarget.sol` ~356–366; call sites depositOut/swapOut `_receiveOut(..., req_.pretransferred)`.
- **Why bar fails:** Same free principal class; worse than mint-only because excess inventory is transferred out.
- **Recommended CODE:** Track inbound delta from `msg.sender` (or snapshot token before any external effects); credit min(delta, amountIn); never refund above **caller-attributable** inbound. If product law allows multi-hop prefund, still require delta ≥ amountIn before spend.
- **Recommended TEST:** `test_I1_exactOut_pretransferred_true_donatedInventory_noSpendNoRefund` + I2 short prefund.
- **Suggested WP:** WP-I-DETF-DL-001 (same CODE touch set)
- **Priority:** Wave 0/1 — Blocker
- **Runtime:** RUNTIME_UNPROVEN (paired with 001)

### 5.3 [TCA-DETF-DL-003] High · TEST + THEATER · catalog I1–I3 / PAT-THEATER-PRE

- **Summary:** Zero `test_I1_` / `test_I2_` / `test_I3_`. Existing pretransfer tests **always** transfer first:
  - `test_depositPretransferred_mintsShares`
  - Permit2 deposit/swap exact-in/out suites
  - `test_exactOutMatrix_swap_pretransferredRefundsSurplus`
- **Evidence:** `rg 'test_I[123]_|pretransferred' .../crossVersion/v2` → happy only; no adversarial trust-flag file.
- **Why bar fails:** PRD §2.3 SE/DETF P0 requires I1–I3 when flag exists; happy pretransfer is **not** coverage (skill anti-theater).
- **Recommended TEST (fork, L-TCA-5 equal severity):**
  - `test_I1_claimPretransfer_noTransfer_donatedPairToken_noFreeMint`
  - `test_I1_claimPretransfer_noTransfer_donatedRateAsset_noFreeSwap`
  - `test_I1_exactOut_donatedInventory_noRefundTheft`
  - `test_I2_shortPretransfer_revertsExact`
  - `test_I3_residualReuse_secondCall_noFreeCredit`
  - Pass: attacker enrichment zero; diamond inventory/accounting unchanged or exact revert selector
- **Suggested WP:** WP-I-DETF-DL-002
- **Priority:** High — Wave 1 (depends on CODE 001)

### 5.4 [TCA-DETF-DL-004] High · TEST · J1–J3 incomplete (partial F/J only)

- **Summary:** No formal J1 Target-derived `controlFacetFuncs`; J2 not a full product-selector loupe after deploy; J3 not catalogued (H exercises main money selectors on proxy). Registry/Immutability prove 9 cuts and absence of diamondCut/owner — necessary but not sufficient for ship-gate J.
- **Evidence:** `*_Immutability.t.sol`, `*DFPkg_Registry.t.sol`; no `test_J1_*` / `controlFacetFuncs` under dual-liquidity tree.
- **Recommended TEST:**
  - `test_J1_facetFuncs_coversIStandardExchangeInOut`
  - `test_J2_proxyLoupe_exchangeAndPreviewSelectors`
  - `test_J3_proxyCallable_smoke_exchangeInOut_preview`
- **Suggested WP:** WP-J-DETF-DL-001
- **Priority:** High — Wave 1; parallel with I CODE

### 5.5 [TCA-DETF-DL-005] High · CODE+TEST · PAT-K-DONATE / K1 incomplete (ShareInflation confusion)

- **Summary:** ShareInflation proves **A3** (BPT donation inflation) on pull path. Combined with 001/002, attacker converts **donated non-BPT inventory into free shares / free swap / free refund** via `pretransferred=true` — classic **K1∩I**. No K1 pretransfer case. Catalog md maps A3→ShareInflation and claims P0 complete — **misleading under A–K**.
- **Evidence:** ShareInflation file NatSpec “A3-class”; `_receive`/`_receiveOut` CODE; missing I/K tests.
- **Recommended CODE:** Fixed by WP-I-DETF-DL-001.
- **Recommended TEST:** `test_K1_donatePairToken_thenPretransferMint_noFreeCredit` (may alias I1 with donate setup); document in catalog that A3 ≠ K1.
- **Suggested WP:** WP-K-DETF-DL-001 (merge into WP-I-DETF-DL-002 preferred)
- **Priority:** High

### 5.6 [TCA-DETF-DL-006] Medium · TEST + THEATER · catalog consolidation incomplete

- **Summary:** Wave 2A intended ID map + fill. Delivered:
  - `DualLiquidity_ADVERSARIAL_CATALOG.md` claims **IMPLEMENTED (P0 via catalog + fill)**
  - `test_catalog_existingSecurityFiles_present` only asserts `linkedVault != 0` — **structural theater**
  - H3 fill is not a real minOut-after-fund residual proof
  - Existing security suites **not** renamed/tagged with `test_A3_*` / `test_C1_*` consistently (NatSpec only on ShareInflation)
- **Recommended TEST:** Expand `adversarial/` into real catalog files or rename+NatSpec gold map; replace map test with file-level CI path list; rewrite H3 to fund + impossible minOut + residual asserts (copy MultiVault H3 pattern).
- **Suggested WP:** WP-CAT-DETF-DL-001
- **Priority:** Medium (Wave 2); do not block I CODE

### 5.7 [TCA-DETF-DL-007] Medium · TEST · L1 thin; L3 gap (fork-aware)

- **Summary:** L2 sequences are solid for a fork product. L1 is MathLib pure only (no route conservation fuzz on live vault). L3 Foundry handler intentionally deferred (RPC). Fuzz gap report still accurate: DualLiquidity L2 partial, L3 G.
- **Recommended TEST:** Optional hermetic MathLib expand already OK; add fork L1 property fuzz sparingly (bounded runs) or hermetic mock-free unit tests for share fee split; L3 only if hermetic dual-liquidity ever exists — else document DEFER with residual L2 expansion (pretransfer attack ops post-CODE).
- **Suggested WP:** WP-L-DETF-DL-001 (Wave 3)
- **Priority:** Medium

### 5.8 [TCA-DETF-DL-008] Medium · THEATER / TEST · bare expectRevert + weak H3

- **Summary:** Several guards/catalog paths use bare `vm.expectRevert()` (Deposits minOut, Guards maxIn path, catalog H3, ERC2612, FactoryService). State asserts often present — weak N bar, not pure theater everywhere.
- **Recommended TEST:** Typed selectors (`ZeroAmount`, `DeadlineExpired`, `MinAmountNotMet` / `IStandardExchangeErrors`, `UnsupportedRoute`, `IsLocked`).
- **Suggested WP:** WP-N-DETF-DL-001
- **Priority:** Medium

### 5.9 [TCA-DETF-DL-009] Info · ShareInflation baseline (A3) — keep, re-label

- **Summary:** A3 BPT donation / front-run resistance remains valuable and should stay. Correct mental model: **A3 only**. Explicitly **not** I1–I3 or K1 pretransfer.
- **Priority:** none (documentation in catalog WP)

### 5.10 [TCA-DETF-DL-010] Low / DEFER · hermetic full-product suite absent

- **Summary:** No hermetic DualLiquidity TestBase (live Uni V4/V2 + Balancer dependency). MathLib is hermetic. Prior plan: do not invent hermetic dual-liquidity if ports incomplete.
- **Recommended:** **DEFER** full hermetic product; invest in **fork P0 I/J/K** (L-TCA-5). Optional long-term: extract pure accounting tests.
- **Suggested WP:** none (or long-horizon research)
- **Priority:** Low / DEFER

### 5.11 [TCA-DETF-DL-011] Info · already covered baseline

- **Summary:** Production-first fork TestBase (registry + CREATE3 + real SE legs); strong H/P matrix; C reentrancy with exact `IsLocked`; residual E; fee non-dilution; BPT pretransfer correctly forbidden; immutability F1-ish; L2 sequences. Outer Single SE matrix using DualLiquidity as `underlyingVault` is a positive composition signal (owned by Single SE area).
- **Priority:** none

---

## 6. Theater list

| Test / control | Why theater / weak | Fix |
|----------------|--------------------|-----|
| `test_depositPretransferred_mintsShares` | Happy transfer then `pretransferred=true` only | Keep as H; add I1 no-transfer |
| Permit2 `pretransferred=true` suite | Prefund is real transfer | Not I; optional I5 adversarial elsewhere |
| `test_exactOutMatrix_swap_pretransferredRefundsSurplus` | Caller-funded surplus only | Add donation-inventory I1 exact-out |
| `test_catalog_existingSecurityFiles_present` | Asserts vault non-zero | Delete or replace with CI path inventory |
| `test_H3_failedMint_minOut_leavesNoInventoryOnVault` | Zero amount + `tokenIn=address(0)` + bare revert | Fund live route; impossible minOut; residual asserts |
| Implicit “ShareInflation covers donation/I/K” | A3 BPT pull-path only | Catalog rewrite; add I/K |
| `test_immutability_packageFacetCountMatchesDeploy` floor `selectors > 20` | Weak J2 substitute | Full loupe map J2 |

**Not theater:** ShareInflation A3 cases; reentrancy IsLocked; residual cleanliness; preview≡execute matrix; production proxy money paths; BPT pretransfer reject tests.

**No PAT-MOCK SUT** on DualLiquidity money paths (fork real packages).

**PAT-THEATER-PRE:** yes (happy pretransfer counted culturally as security).

---

## 7. Prior-report diff

| Claim (doc) | Status now (2026-08-09) |
|-------------|-------------------------|
| DualLiquidity “partial security; needs catalog suite” (adversarial gap report §5) | **Partially closed** — `adversarial/` + NatSpec map exists; **still incomplete** under A–K |
| Wave 2A “P0 via catalog + fill” / catalog md IMPLEMENTED | **Stale / overstated** — I/J/K missing; H3 fill weak; CODE PAT-I-ABS |
| ShareInflation = A3-class | **Still true** — do not expand claim to I/K |
| DualLiquidity L2 sequences; L3 gap (fuzz report) | **Still true** — L2 expanded; L3 Foundry runner still G (fork defer) |
| Fork P0 gaps lower priority than hermetic | **False under L-TCA-5** — treat I/J/K fork gaps as High/Blocker |
| DualLiquidity optional rate providers “gold path done” | Orthogonal product work; ratesOn tests present — not security I/K |

---

## 8. Work package stubs

### WP-I-DETF-DL-001

| Field | Value |
|-------|--------|
| **WP-ID** | WP-I-DETF-DL-001 |
| **Title** | Fix DualLiquidity pretransfer credit to balance-delta (exact-in + exact-out) |
| **Severity** | Blocker |
| **Class** | CODE (+ minimal regression tests) |
| **Products** | DualLiquidityLinkedCrossVersionUniswapVault |
| **Finding IDs** | TCA-DETF-DL-001, TCA-DETF-DL-002, TCA-DETF-DL-005 (CODE half) |
| **Problem** | `_receive` no-ops on pretransfer; `_receiveOut` spends/refunds absolute held inventory. Free mint, free swap, donation theft. |
| **Production files** | `DualLiquidityLinkedCrossVersionUniswapVaultExchangeInTarget.sol` (`_receive`); `DualLiquidityLinkedCrossVersionUniswapVaultExchangeOutTarget.sol` (`_receiveOut`); possibly Common if shared helper extracted |
| **Test files** | temporary fork I1 smoke; full suite in WP-I-DETF-DL-002 |
| **Out of scope** | BasicVaultCommon Wave-0 (T-basic-protocol-commons) unless extracting shared helper by design; MultiVault; outer Single SE matrix; hermetic invention |
| **Depends on** | none (align pattern with Wave-0 commons delta law; **not** file-coupled to BasicVaultCommon) |
| **Parallelizable with** | WP-J-DETF-DL-001, WP-CAT-DETF-DL-001 (test-only) |
| **Suggested worktree** | `gap_cover_i-detf-dl` · branch `gap_cover/i-detf-dl` |
| **Implementation notes** | ERC4626-style delta; keep BPT pretransfer revert behavior; do not break Permit2 happy prefund (real delta must still pass); no `via_ir` |
| **Acceptance** | `FOUNDRY_PROFILE=fork forge test --match-path 'test/.../crossVersion/v2/**' --match-test 'test_I1_'` green after tests land; static no bare `if (pretransferred) return` / absolute-held refund |
| **Anti-theater** | I1 must not transfer for attacker; diamond may already hold donated inventory ≥ amount |
| **Estimate** | M |

### WP-I-DETF-DL-002

| Field | Value |
|-------|--------|
| **WP-ID** | WP-I-DETF-DL-002 |
| **Title** | Add DualLiquidity fork adversarial I1–I3 + K1 (pretransfer) |
| **Severity** | High |
| **Class** | TEST |
| **Products** | DualLiquidityLinkedCrossVersionUniswapVault |
| **Finding IDs** | TCA-DETF-DL-003, TCA-DETF-DL-005 |
| **Problem** | Catalog I/K P0 absent; happy pretransfer theater. |
| **Production files** | none (after 001) |
| **Test files** | `test/.../crossVersion/v2/adversarial/Adversarial_TrustFlag.t.sol` (new) or extend Catalog |
| **Out of scope** | ShareInflation rewrite (keep A3); J suite; hermetic port |
| **Depends on** | WP-I-DETF-DL-001 |
| **Parallelizable with** | WP-N-DETF-DL-001 after 001 |
| **Suggested worktree** | `gap_cover_i-detf-dl-tests` (or same as 001) |
| **Implementation notes** | Fork TestBase; crane I1–I3; donate `pairToken`/`rateAsset`/leg `vaultShare`; exact-out refund case; exact selectors |
| **Acceptance** | `FOUNDRY_PROFILE=fork forge test --match-path '.../adversarial/**' --match-test 'test_I\|test_K1'` green |
| **Anti-theater** | I1 no attacker transfer; I2 short; I3 second call; never count ShareInflation as I |
| **Estimate** | M |

### WP-J-DETF-DL-001

| Field | Value |
|-------|--------|
| **WP-ID** | WP-J-DETF-DL-001 |
| **Title** | DualLiquidity J1–J3 surface suite on production proxy |
| **Severity** | High |
| **Class** | TEST (CODE only if PAT-J-OMIT found) |
| **Products** | DualLiquidityLinkedCrossVersionUniswapVault |
| **Finding IDs** | TCA-DETF-DL-004 |
| **Problem** | No Target-derived J suite; loupe only negative-path immutability. |
| **Production files** | only if omit found |
| **Test files** | `adversarial/Adversarial_Surface.t.sol` or extend Immutability/Registry |
| **Out of scope** | I suite; A–H rewrite |
| **Depends on** | none |
| **Parallelizable with** | WP-I-DETF-DL-001 |
| **Suggested worktree** | `gap_cover_j-detf-dl` |
| **Implementation notes** | Controls from `IStandardExchangeIn`/`Out` + multi-asset views if required; J3 on **proxy** after registry deploy |
| **Acceptance** | `test_J1_*`, `test_J2_*`, `test_J3_*` green |
| **Anti-theater** | Never assert only on facet implementation address for J2/J3 |
| **Estimate** | S–M |

### WP-K-DETF-DL-001

| Field | Value |
|-------|--------|
| **WP-ID** | WP-K-DETF-DL-001 |
| **Title** | K1 donation + pretransfer free-credit regression |
| **Severity** | High |
| **Class** | TEST |
| **Products** | DualLiquidityLinkedCrossVersionUniswapVault |
| **Finding IDs** | TCA-DETF-DL-005 |
| **Problem** | K1 unproven; A3 misread as K. |
| **Test files** | merge into Adversarial_TrustFlag |
| **Depends on** | WP-I-DETF-DL-001 |
| **Parallelizable with** | WP-I-DETF-DL-002 (**merge preferred**) |
| **Suggested worktree** | merge with `gap_cover_i-detf-dl-tests` |
| **Acceptance** | `test_K1_*` or documented I1 alias with donate setup |
| **Anti-theater** | Must use `pretransferred=true` after donate |
| **Estimate** | S |

### WP-CAT-DETF-DL-001

| Field | Value |
|-------|--------|
| **WP-ID** | WP-CAT-DETF-DL-001 |
| **Title** | DualLiquidity adversarial catalog honesty + consolidation |
| **Severity** | Medium |
| **Class** | TEST |
| **Products** | DualLiquidityLinkedCrossVersionUniswapVault |
| **Finding IDs** | TCA-DETF-DL-006, TCA-DETF-DL-009 |
| **Problem** | Catalog claims P0 complete; map test theater; H3 weak; IDs not on test names. |
| **Test files** | `adversarial/**`, `DualLiquidity_ADVERSARIAL_CATALOG.md`, NatSpec on ShareInflation/Reentrancy/Residual |
| **Out of scope** | CODE pull fix; invent hermetic product |
| **Depends on** | none (can land before I CODE; update matrix after I suite) |
| **Parallelizable with** | WP-J-DETF-DL-001, WP-I-DETF-DL-001 |
| **Suggested worktree** | `gap_cover_cat-detf-dl` |
| **Implementation notes** | MultiVault adversarial layout as gold **methodology**; keep fork TestBase; label A3/C/E/F explicitly; mark I/K G until 002 |
| **Acceptance** | Catalog md matches real scores; no “P0 complete” while I/K G; real H3 test |
| **Anti-theater** | Delete vault!=0 map test; no claiming ShareInflation as I |
| **Estimate** | S–M |

### WP-N-DETF-DL-001

| Field | Value |
|-------|--------|
| **WP-ID** | WP-N-DETF-DL-001 |
| **Title** | Exact selectors on DualLiquidity bare reverts |
| **Severity** | Medium |
| **Class** | TEST |
| **Products** | DualLiquidityLinkedCrossVersionUniswapVault |
| **Finding IDs** | TCA-DETF-DL-008 |
| **Problem** | Bare `expectRevert` weakens N bar. |
| **Test files** | Guards, Deposits, adversarial H3, misc |
| **Depends on** | none |
| **Parallelizable with** | most TEST WPs |
| **Suggested worktree** | `gap_cover_n-detf-dl` |
| **Acceptance** | Typed selectors on touched paths |
| **Anti-theater** | Prefer `abi.encodeWithSelector` |
| **Estimate** | S |

### WP-L-DETF-DL-001

| Field | Value |
|-------|--------|
| **WP-ID** | WP-L-DETF-DL-001 |
| **Title** | DualLiquidity L1 expand + L2 pretransfer attack ops (post I fix) |
| **Severity** | Medium |
| **Class** | TEST |
| **Products** | DualLiquidityLinkedCrossVersionUniswapVault |
| **Finding IDs** | TCA-DETF-DL-007 |
| **Problem** | L1 only MathLib; L2 lacks trust-flag attack ops; L3 deferred. |
| **Depends on** | WP-I-DETF-DL-001 for pretransfer attack ops |
| **Parallelizable with** | late Wave 3 peers |
| **Suggested worktree** | `gap_cover_l-detf-dl` |
| **Acceptance** | Additional property tests documented; no full fork L3 required if L2 expanded |
| **Anti-theater** | Do not claim L3 if only sequences |
| **Estimate** | M |

---

## 9. Deferred / N/A / NEEDS_OWNER

| Item | Class | Reason |
|------|-------|--------|
| Bond/claim D2–D6, F2–F3 | **N/A** | Product is SE-style dual-liquidity vault; no NFT bond/claim |
| Full Foundry L3 handler on fork | **DEFER** | Explicit RPC cost; prefer L2 + optional future hermetic |
| Full hermetic DualLiquidity product suite | **DEFER** | Live Uni V4/V2 + Balancer; plan says do not invent if ports incomplete (TCA-DETF-DL-010) |
| Full MEV sandwich reconstruction | **DEFER** | P2 historical non-goal |
| Donation beneficiary product law (should donate revert vs feeTo?) | **NEEDS_OWNER** only if after delta-fix product wants explicit donate policy; **default** is no free credit to arbitrary caller |
| Outer Single SE over DualLiquidity matrix | Out of area | Cite only; owned by `T-detf-single-se` |
| Shared BasicVaultCommon Wave-0 | Reference | DualLiquidity **does not inherit** it; still align delta **semantics** |

---

## 10. Commands run

```bash
# Inventory (read-only)
rg -n --type sol 'pretransferred|function _receive|facetFuncs' \
  contracts/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2

rg -n --type sol 'test_I[0-9]|test_A[0-9]|test_J[0-9]|test_K[0-9]|ShareInflation|pretransferred|expectRevert|testFuzz_|invariant_' \
  test/foundry/fork/base_main/vaults/detf/protocols/dexes/balancer/v3/uniswap/v4/crossVersion/v2

rg -n 'DualLiquidity|crossVersion' docs/testing --glob '*.md' | head -40

# List trees
# contracts/.../crossVersion/v2/
# test/foundry/fork/.../crossVersion/v2/ (+ adversarial/)

# Runtime forge PoC for free mint: NOT executed this run (RUNTIME_UNPROVEN on Blockers)
```

**Files read (representative):** ExchangeIn/Out Targets (`_receive`, `_receiveOut`, deposit/redeem), four product Facets, Common mint/burn/sweep, ShareInflation, Deposits pretransfer, ExactOutMatrix surplus refund, Adversarial catalog + md, Immutability, DFPkg_Registry, Invariants/Handler, TestBase header, prior adversarial/fuzz reports, multi-vault pilot report schema, PRD §7.2 / L-TCA-5.

---

## Return summary (orchestrator)

| Field | Value |
|-------|--------|
| **Status** | **COMPLETE** |
| **Blocker** | **2** — TCA-DETF-DL-001, TCA-DETF-DL-002 (CODE PAT-I-ABS; RUNTIME_UNPROVEN) |
| **High** | **3** — TCA-DETF-DL-003 (I tests/theater), TCA-DETF-DL-004 (J), TCA-DETF-DL-005 (K1/ShareInflation confusion) |
| **Top WPs** | WP-I-DETF-DL-001 → WP-I-DETF-DL-002 (+K) · WP-J-DETF-DL-001 · WP-CAT-DETF-DL-001 · WP-N-DETF-DL-001 |
| **OUT_FILE** | `docs/testing/coverage-audit/areas/T-detf-dual-liquidity.md` |
| **Repro** | `docs/testing/coverage-audit/repro/TCA-DETF-DL-001/notes.md` |
