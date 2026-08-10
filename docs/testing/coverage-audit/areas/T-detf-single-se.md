# Test Coverage Audit — T-detf-single-se

| Field | Value |
|-------|--------|
| Date | 2026-08-09 |
| Agent / run | Stage 1 area subagent · full · `T-detf-single-se` |
| Status | **COMPLETE** |
| Production paths | `contracts/vaults/detf/**/standardExchange/single/**` (+ Uni V4 SE DETF peers under `…/standardExchange/constantProduct/single/**` as owned) |
| Test paths | `test/**/standardExchange/single/**` incl. `adversarial/`, `fuzz/`, `invariant/`; Uni V4 peers under `test/**/uniswap/v4/standardExchange/{single,constantProduct/single}/**` |
| Skills / PRD version cited | `TEST_COVERAGE_AUDIT_PRD` §2,2.4,3.8,5,6,7.2,8,19; DETF P0 subset §2.3; `crane-adversarial-testing` A–K + `implementation-test-dod.md`; gold A–H = MultiVault `…/multi-vault-weighted/adversarial/` |
| Prior seed | `ADVERSARIAL_VAULT_COVERAGE_GAP_REPORT.md` (Single SE **highest-priority port**; formal `adversarial/` missing in 2026-07) — **re-verified 2026-08-09: `adversarial/` now exists** |

---

## 1. Executive summary

### Maturity (0–5)

| Product | Maturity | Worst open severity | One-line |
|---------|----------|---------------------|----------|
| **SingleStandardExchangeDETF** (Balancer V3) | **3** | **Blocker** (CODE, RUNTIME_UNPROVEN) | Wave 1A A–H port largely **F**; H/N/P + L1/L3 present; **I/J ship-gate fail**; package-local **PAT-I-ABS** on `_pullToken` / burn pretransfer (same class as MultiVault gold) |
| **UniswapV4SingleStandardExchangeDETF** (constantProduct/single) | **2** | **Blocker** (CODE, RUNTIME_UNPROVEN) | Solid H + preview≡execute + thin C reentrancy; **no catalog A–K suite**; same PAT-I-ABS on `_pullToken` / burn |
| **UniswapV4SingleStandardExchangeDETF** (legacy `…/standardExchange/single`) | **1** | **Blocker** (CODE, RUNTIME_UNPROVEN) | Scaffold: T01 deploy + T02 first mint only; PAT-I-ABS is absolute-`balanceOf` form (still free credit) |

**Port completeness vs MultiVault gold (Balancer Single SE):** A–H P0 is **mostly closed** in one consolidated `Adversarial_SingleSE_P0.t.sol` (not MultiVault’s 9-file layout, but catalog IDs present). **Not gold-comparable for I/J/K** — identical ship-gate failure as MultiVault pilot. Prior claim “formal adversarial missing” is **stale**.

### Severity counts (this area)

| Severity | Count | IDs |
|----------|-------|-----|
| **Blocker** | **4** | TCA-DETF-SSE-001 … 004 |
| **High** | **5** | TCA-DETF-SSE-005 … 009 |
| Medium | 4 | TCA-DETF-SSE-010 … 013 |
| Low / Info | 2 | TCA-DETF-SSE-014, TCA-DETF-SSE-015 |

### Top 5 recommended WPs

1. **WP-I-DETF-SSE-001** — CODE: Balancer Single SE delta-safe `_pullToken` + burn pretransfer (Blocker)
2. **WP-I-DETF-SSE-002** — TEST: Balancer I1–I3 (+ bond) + K1 pretransfer (High; depends on 001)
3. **WP-J-DETF-SSE-001** — TEST: Balancer J1–J3 Target-derived controls + loupe + proxy smoke (High; **no** IFacet declaration suite today)
4. **WP-I-DETF-SSE-CP-001** — CODE+TEST: Uni V4 CP Single SE PAT-I-ABS + I1–I3 (Blocker/High)
5. **WP-I-DETF-SSE-UV4-001** — CODE: legacy Uni V4 Single SE absolute-balance pretransfer → delta (Blocker; product immature)

**Do not rewrite** Balancer A–H cases that are already green; extend with I/J/K and fix CODE.

---

## 2. Product inventory

### 2.1 Production packages

| Product | DFPkg / key Targets | Facets | TestBase | Test roots | Deploy path quality |
|---------|---------------------|--------|----------|------------|---------------------|
| **SingleStandardExchangeDETF** (Balancer) | `SingleStandardExchangeDETDFPkg.sol`; Targets: ExchangeIn, ExchangeOut (burn helper), ExchangeInQuery, Bonding, Info; Common+Repo | `SingleStandardExchangeDETFExchangeInFacet` (22 selectors: exchangeIn/preview/bond/sell/info/compound+atomic/expansion views) | `TestBase_SingleStandardExchangeDETF.sol` (co-located) | `test/.../balancer/v3/standardExchange/single/**` + fork DualLiquidity/UniV4 matrices | **Gold-class**: CREATE3 Facet/Pkg factories + `indexedexManager.deployVault` / registry; underlying SE via Aerodrome hermetic matrix |
| **UniswapV4SingleStandardExchangeDETF** (CP) | `UniswapV4SingleStandardExchangeDETDFPkg.sol`; ExchangeIn/Out, Bonding, Facet, Common+Repo | `UniswapV4SingleStandardExchangeDETFFacet` | `TestBase_UniswapV4SingleStandardExchangeDETF.sol` | `test/.../uniswap/v4/standardExchange/constantProduct/single/**` | Registry/CREATE3 path via package factories; hermetic Uni V4 stack |
| **UniswapV4SingleStandardExchangeDETF** (legacy single) | `UniswapV4SingleStandardExchangeDETFDFPkg.sol`; Bonding, ExchangeIn, Info, Facet | `UniswapV4SingleStandardExchangeDETFFacet` | `TestBase_UniswapV4SingleStandardExchangeDETF.sol` (legacy path) | `test/.../uniswap/v4/standardExchange/single/` (T01/T02 only) | Package deploys; product scaffold / early stage |

**Out of this area (adjacent, not scored as primary):** Uni V4 **orbital** / **weighted** under `standardExchange/{orbital,weighted}` (not `**/single/**`); hooks under `contracts/hooks/**` (T-hooks-v4).

### 2.2 Balancer production file inventory (primary)

| Path | Role |
|------|------|
| `SingleStandardExchangeDETDFPkg.sol` | DFPkg, facetCuts, processArgs |
| `SingleStandardExchangeDETFExchangeInFacet.sol` | Combined IFacet + `facetFuncs` (22) |
| `SingleStandardExchangeDETFExchangeInTarget.sol` | `exchangeIn` mint / routes burn via helper |
| `SingleStandardExchangeDETFExchangeOutTarget.sol` | `_burnDetfExactIn` (+ pretransfer branch) — **no public `exchangeOut`** |
| `SingleStandardExchangeDETFExchangeInQueryTarget.sol` | `previewExchangeIn` |
| `SingleStandardExchangeDETFBondingTarget.sol` | `bond`, `sellPositionToDetfNft` |
| `SingleStandardExchangeDETFInfoTarget.sol` | views + `compoundProtocolRewards` |
| `SingleStandardExchangeDETFCommon.sol` | accounting, **`_pullToken`**, compound atomic |
| `SingleStandardExchangeDETFRepo.sol` | storage + errors |
| `*_FactoryService.sol` | CREATE3 deploy helpers |
| `TestBase_SingleStandardExchangeDETF.sol` | production TestBase |

### 2.3 Trust-flag entrypoints (I-applicable)

| Product | Entrypoint | Flag | Credit path |
|---------|------------|------|-------------|
| Balancer Single SE | `exchangeIn` | `bool pretransferred_` | Mint: `_pullToken`; Burn: skip `transferFrom` then burn from diamond |
| Balancer Single SE | `bond` | `bool pretransferred_` | `_pullToken` vaultShare / allowlisted |
| Uni V4 CP | `exchangeIn` / `bond` | `pretransferred_` | `_pullToken` / `_settleToPair`; burn skips pull |
| Uni V4 legacy | `exchangeIn` / `bond` | `pretransferred_` | `_pullToken` absolute bal check; burn skips pull |

### 2.4 Facet surface (J static skim) — Balancer

`SingleStandardExchangeDETFExchangeInFacet.facetFuncs()` lists **22** selectors: `exchangeIn`, `previewExchangeIn`, `bond`, `sellPositionToDetfNft`, info suite, `compoundProtocolRewards`, `compoundProtocolRewardsAtomic`, expansion views.

**No** public `exchangeOut` / `previewExchangeOut` (burn is `exchangeIn` with `tokenIn = detfToken`) — intentional vs MultiVault stub route.

**Static J1 impression:** product Target money APIs appear **included**. **Not proven** by Target-diff test, loupe, or J3 catalog. **Zero** Behavior_IFacet / declaration suite under Single SE tests.

### 2.5 Test roots (Balancer Single SE)

| Root | Role | Count (approx.) |
|------|------|-----------------|
| `SingleStandardExchangeDETF_*.t.sol` (package dir) | Deploy, Mint, Burn, Bonding, Guards, Info, Requirements, ThresholdMode, NaturalExpansion, ProtocolCompound, Reentrancy, Disable, ComposedStable matrix | Broad H/N matrix |
| `adversarial/` | Wave 1A catalog A–H (P0/P1 subset) | **1** file `Adversarial_SingleSE_P0.t.sol` + adversarial TestBase; **~20** `test_*` |
| `fuzz/` | L1 property fuzz | 3 `testFuzz_*` |
| `invariant/` | L3 Handler + invariants | 4 `invariant_*`; handler mint/burn/donateShares |
| Fork `…/base_main/…/standardExchange/single/` | DualLiquidity + Uni V4 outer matrices | Nested G-class partial |

### 2.6 Uni V4 peer test roots

| Product | Roots | Adversarial depth |
|---------|-------|-------------------|
| CP single | Deploy, FirstBond, MintBurn, Bond, Claim, Expansion, PriceMovement, Adversarial, unit expansion lib | Thin: reentrancy + partition asserts — **not** A–K catalog |
| Legacy single | T01_Deploy, T02_FirstMint | Scaffold only |

---

## 3. Layer matrix

Legend: **F** full · **P** partial · **G** gap · **N/A** · **S** stub/theater

| Product | H | N | D | J | I | K | A–H | P | L1 | L2 | L3 | Maturity | Notes |
|---------|---|---|---|---|---|---|-----|---|----|----|----|----------|-------|
| SingleStandardExchangeDETF (Balancer) | **F** | **P**→**F**\* | **G** | **G**/**P**† | **G** | **P**‡ | **P**→**F** (P0 core) | **F** | **P**/**F** | **G** | **P** | **3** | Port closed A–H core; I/J fail; CODE free-credit |
| UniV4 CP Single SE | **F** | **P** | **G** | **G** | **G** | **G** | **P** (C only) | **F** | **G** | **G** | **G** | **2** | Happy/claim/bond strong; no I/J/K; PAT-I-ABS |
| UniV4 legacy Single SE | **P** | **G** | **G** | **G** | **G** | **G** | **G** | **G** | **G** | **G** | **G** | **1** | Scaffold |

\* Exact selectors strong on E5/Guards; several adversarial negatives still bare `expectRevert()`.  
† Proxy heavily used in H/adversarial; **no** J1–J3 formal suite.  
‡ A1 proves idle donation not joined on pull-path mint; pretransfer donation credit untested and CODE-broken.

### Layer evidence (Balancer summary)

| Layer | Evidence |
|-------|----------|
| **H** | Deploy, Mint, Burn, Bonding, ThresholdMode, NaturalExpansion, ProtocolCompound, Requirements, ComposedStable matrix, fork matrices |
| **N** | Guards zero/deadline/route; preLive; lock clamp; threshold deadband; Disable registry |
| **D** | **None** dedicated IFacet Behavior / `facetMetadata` suite |
| **J** | No loupe / no Target-derived controls / no catalog J1–J3 |
| **I** | **Zero** `test_I1_` / `test_I2_` / `test_I3_`; **zero** `pretransferred=true` call sites in Single SE tests |
| **K** | A1 pull-path non-credit of idle vaultShare; **G** for donation + `pretransferred=true` |
| **A–H** | See §4 — P0 core F; D6/H2 N/A (no rebasing claim v1); F3 claim-token onlyOwner N/A same reason |
| **P** | Mint/Burn/ThresholdMode `preview ≈ execution` (1 wei) |
| **L1** | `SingleStandardExchangeDETF_Fuzz.t.sol` (conservation, non-dilution, zero preview) |
| **L2** | No dedicated sequence-invariant file |
| **L3** | Handler mint/burn/donateShares; residual / ghost / supply / live |

---

## 4. Catalog matrix (A–K)

### 4.1 Balancer SingleStandardExchangeDETF

| ID | Score | Evidence (test name) or G |
|----|-------|---------------------------|
| **A1** | **F** | `Adversarial_SingleSE_P0.test_A1_donateVaultShares_cannotMintFreeDetf` |
| **A2** | **F** | `test_A2_donateDetfToDiamond_noTheft` |
| **A3** | **F** | `test_A3_cannotDrainBptWithoutBondAuthority` |
| A4–A5 | **DEFER** (P2) | not ported |
| **B1** | **P**/**F** | `test_B1_openThresholds_mintBurn_boundsSafety` (weaker than MultiVault skew seigniorage bounds) |
| B2 | **DEFER** | not ported |
| **B3** | **F** | `test_B3_thresholdGates_coupleToSynthetic` + hermetic ThresholdMode |
| **C1** | **F** | `test_C1_reenterBond_duringFirstBond_hitsIsLocked` (+ Reentrancy.t.sol) |
| **C2** | **F** | `test_C2_reenterExchangeIn_duringMint_hitsIsLocked` |
| **C3** | **F** | `test_C3_mintReenterBond_hitsIsLocked` |
| C4–C5 | **DEFER** | not ported |
| **D2** | **F** | `test_D2_sellPosition_nonOwner_reverts` |
| **D3** | **F** | `test_D3_doubleSell_secondReverts` |
| D5 | **F** | `test_D5_lockClamp_minRevert_maxOk` |
| **D6** | **N/A** | NatSpec: no rebasing claim v1 |
| **E1** | **F** | `test_E1_mintThenPartialBurn_conservation` |
| **E4** | **F** | `test_E4_holderBalance_notDilutedByOthersMint` |
| **E5** | **F** | `test_E5_zeroAmount_reverts`, `test_E5_expiredDeadline_reverts` (+ Guards) |
| **F1** | **F** | `test_F1_diamondCut_notCallableByAttacker` |
| **F2** | **F** | `test_F2_bondNftVault_createPosition_onlyOwner` |
| **F3** | **N/A**/**G** | MultiVault-style claim mintFromNFT onlyOwner N/A without claim token path; sell authority covered D2 |
| **F4** | **F** | `test_F4_noSetWeights` |
| **G1** | **P** | ComposedStable outer matrix + fork DualLiquidity/UniV4; not formal adversarial G1 |
| H1 | **DEFER** | not ported |
| **H2** | **N/A** | NatSpec: claim path N/A — sellPosition substitutes via D3 |
| **H3** | **F** | `test_H3_minOutTooHigh_leavesNoInventory` + residual helpers |
| **I1** | **G** | no test; pure gap (not THEATER-PRE) |
| **I2** | **G** | no test |
| **I3** | **G** | no test |
| I4 | **DEFER** | FoT less relevant on SE vaultShare legs |
| **J1** | **G** | no Target↔facetFuncs diff; no declaration controls |
| **J2** | **G** | no `facetAddress(sel)` loupe after DFPkg deploy |
| **J3** | **P**/**G** | money paths on **proxy** in H/adversarial; no systematic J3 catalog |
| **K1** | **P** | A1 pull-path; **G** for donation + `pretransferred=true` (CODE path credits claim) |

**P0 DETF subset (PRD §2.3):** A1,A3,B1\*,B3,C1–C3,D2,D3,D6†,E1,E5,F2–F3†,H2†,H3 = **F** where applicable; **I1–I3 = G**; **J1–J3 = G/P**; **K1 = P**.  
\* B1 weaker than MultiVault. † N/A product shape.

### 4.2 Uni V4 CP Single SE (abbreviated)

| ID | Score | Notes |
|----|-------|-------|
| A1–A3, B*, D*, E*, F*, H*, I*, J*, K* | **G** | No catalog-named suite |
| C (reentrancy) | **P** | `test_reentrancy_mint_hitsIsLocked` only |
| H/N/P happy | **F**/**P** | MintBurn/Bond/Claim/FirstBond |

### 4.3 Uni V4 legacy Single SE

All A–K **G** except incidental H on T01/T02.

---

## 5. Findings

### 5.1 [TCA-DETF-SSE-001] Blocker · CODE · PAT-I-ABS (Balancer mint / bond pull)

- **Summary:** `_pullToken(..., pretransferred_=true)` returns the **caller-claimed** `amount_` with **no** balance check and **no** inbound delta. Mint and bond credit free vaultShare principal against any inventory already on the diamond (or invent credit if join tolerates — primary exploit is credit against donated inventory).
- **Evidence:**
  - `SingleStandardExchangeDETFCommon.sol` ~463–464: `if (pretransferred_) return amount_;`
  - Mint: `SingleStandardExchangeDETFExchangeInTarget.sol` uses `_pullToken(..., pretransferred_)`
  - Bond: `SingleStandardExchangeDETFBondingTarget.sol` ~56–58
- **Why bar fails:** Ship gate I + accounting primitives: credit must be observed delta, never claim alone (`implementation-test-dod.md` §2; L-CLAIM-3).
- **Recommended CODE:** Measure `balBefore` always; if pretransferred, require `balAfter - balBefore >= amount_` **or** credit only delta. Align with MultiVault WP-I-DETF-MV-001 / Wave-0 secure-pull semantics; package-local clone of MultiVault bug (not BasicVaultCommon).
- **Recommended TEST:** `test_I1_pretransferred_true_noTransfer_existingVaultShareInventory_noFreeMint` — donate vaultShare, call `exchangeIn` with `pretransferred=true` without transfer; assert attacker `detfToken` unchanged and revert or zero credit.
- **Suggested WP:** WP-I-DETF-SSE-001
- **Priority:** Wave 1 — Blocker
- **Runtime:** **RUNTIME_UNPROVEN** this run; static evidence overwhelming (literal `return amount_`). Stage 2 must forge-prove I1 before marking CODE closed.

### 5.2 [TCA-DETF-SSE-002] Blocker · CODE · PAT-I-ABS (Balancer burn pretransfer)

- **Summary:** `_burnDetfExactIn` with `pretransferred_=true` **skips** `transferFrom` then burns `detfIn_` from `address(this)` and pays vault shares. Free detfToken inventory on the diamond (A2 pattern) becomes **free extract** of vaultShare without the attacker transferring detfToken.
- **Evidence:** `SingleStandardExchangeDETFExchangeOutTarget.sol` ~38–44.
- **Why bar fails:** Same trust-flag free principal class; A2 only proves pull-path burn does not spend diamond free detfToken.
- **Recommended CODE:** Always require measured inbound detfToken **or** burn from `msg.sender` with transfer; never burn diamond inventory attributed to a claimed pretransfer without delta proof.
- **Recommended TEST:** `test_I1_burn_pretransferred_true_usesOnlyCallerTransferredDetf` — donate detfToken; attacker with 0 detfToken calls burn route with `pretransferred=true`; expect revert; diamond reserves unchanged.
- **Suggested WP:** WP-I-DETF-SSE-001 (same CODE touch set)
- **Priority:** Wave 1 — Blocker
- **Runtime:** RUNTIME_UNPROVEN (paired with 001)

### 5.3 [TCA-DETF-SSE-003] Blocker · CODE · PAT-I-ABS (Uni V4 CP mint/bond/burn)

- **Summary:** Same absolute-claim pattern as Balancer: `_pullToken` returns claimed amount when pretransferred; burn skips transferFrom then burns diamond inventory.
- **Evidence:**
  - `…/constantProduct/single/UniswapV4SingleStandardExchangeDETFCommon.sol` ~478–479: `if (pretransferred_) return amount_;`
  - `…/ExchangeOutTarget.sol` ~48–50 skip pull
- **Why bar fails:** Identical I ship-gate failure on live money product with claim path and bond.
- **Recommended CODE:** Delta-safe pull + burn inbound proof (mirror Balancer/MultiVault).
- **Recommended TEST:** I1 mint + I1 burn under CP TestBase; use production SE path (not only hostile SimpleYield for I suite).
- **Suggested WP:** WP-I-DETF-SSE-CP-001
- **Priority:** Wave 1 — Blocker
- **Runtime:** RUNTIME_UNPROVEN

### 5.4 [TCA-DETF-SSE-004] Blocker · CODE · PAT-I-ABS (Uni V4 legacy single absolute balance)

- **Summary:** `_pullToken` when pretransferred requires `balanceOf(this) >= amount_` then **returns claimed amount** — classic absolute-balance free credit (donations / prior reserves satisfy check without inbound delta). Burn path also skips transferFrom.
- **Evidence:**
  - `…/standardExchange/single/UniswapV4SingleStandardExchangeDETFCommon.sol` ~293–299
  - `…/ExchangeInTarget.sol` `_burnDetfExactIn` ~185–187
- **Why bar fails:** Absolute check ≠ delta proof (PAT-I-ABS table).
- **Recommended CODE:** Credit only measured delta; fail if short.
- **Recommended TEST:** After product H matures, I1–I3 on this TestBase.
- **Suggested WP:** WP-I-DETF-SSE-UV4-001
- **Priority:** Wave 1 CODE; full I suite may trail product maturity
- **Runtime:** RUNTIME_UNPROVEN

### 5.5 [TCA-DETF-SSE-005] High · TEST · catalog I1–I3 (Balancer)

- **Summary:** No I1/I2/I3 adversarial (or hermetic) tests. All live `exchangeIn`/`bond` use `pretransferred=false`. Catalog P0 incomplete. Not theater-pretransfer (total absence of pretransfer happy path).
- **Evidence:** `rg 'test_I[123]_|pretransferred' test/.../standardExchange/single` → no I-suite; adversarial always `false`.
- **Why bar fails:** PRD §2.3 DETF P0 requires I1–I3 when flag exists.
- **Recommended TEST:**
  - `test_I1_claimPretransfer_noTransfer_existingReserves_noFreeMint`
  - `test_I2_shortPretransfer_revertsExact`
  - `test_I3_residualReuse_secondCall_noFreeMint`
  - Bond variants; burn I1
- **Suggested WP:** WP-I-DETF-SSE-002 (depends on WP-I-DETF-SSE-001)
- **Priority:** High — Wave 1

### 5.6 [TCA-DETF-SSE-006] High · TEST · PAT-THEATER-FACET / J1–J3 (Balancer)

- **Summary:** **No** Facet declaration / Behavior_IFacet test at all (worse than MultiVault’s length-floor theater). No loupe after registry deploy; no J3 full API catalog (though H exercises core money selectors on proxy).
- **Evidence:** no `facetMetadata` / `controlFacetFuncs` / `facetAddress` under Single SE tests; `facetFuncs` only in production Facet.
- **Why bar fails:** J scored on **proxy**; declaration must not be absent for DFPkg facets.
- **Recommended CODE:** Only if J1 static diff finds omission (none confirmed — 22 selectors look complete for exposed Targets).
- **Recommended TEST:**
  - `test_J1_facetFuncs_coversTargetApi` — controls from `IStandardExchangeIn` + `ISingleStandardExchangeDETFBonding` + `ISingleStandardExchangeDETFInfo` (+ atomic compound)
  - `test_J2_proxyLoupe_allProductSelectors`
  - `test_J3_proxyCallable_smoke_eachSelector`
- **Suggested WP:** WP-J-DETF-SSE-001
- **Priority:** High — Wave 1

### 5.7 [TCA-DETF-SSE-007] High · CODE+TEST · PAT-K-DONATE / K1 incomplete (Balancer)

- **Summary:** A1 correctly shows idle vaultShare donation is **not** joined on victim mint with pull path. Combined with 001, attacker can convert **donation into free detfToken** via `pretransferred=true` — classic K1/I hybrid. No dedicated K1 pretransfer case.
- **Evidence:** A1; `_pullToken` CODE; missing I/K pretransfer tests.
- **Recommended CODE:** Fixed by 001.
- **Recommended TEST:** `test_K1_donateVaultShares_thenPretransferMint_noFreeCredit` (may alias I1).
- **Suggested WP:** WP-K-DETF-SSE-001 (prefer merge into WP-I-DETF-SSE-002)
- **Priority:** High

### 5.8 [TCA-DETF-SSE-008] High · TEST · Uni V4 CP I/J/K + A–H port incomplete

- **Summary:** CP product has production-grade H/P and one reentrancy adversarial case, but no A1–A3, D*, E1/E5 catalog, I1–I3, J1–J3, or K1. After CODE fix (003), still ship-blocks on I/J for money product.
- **Evidence:** `UniswapV4SingleStandardExchangeDETF_Adversarial.t.sol` — reentrancy + partition only; no `test_I*` / `test_J*` / `test_A1_*`.
- **Recommended TEST:** Port MultiVault/Single SE adversarial harness patterns to CP TestBase; at minimum P0 DETF subset including I/J/K after CODE.
- **Suggested WP:** WP-I-DETF-SSE-CP-001 (CODE+I) + WP-ADV-DETF-SSE-CP-001 (A–H residual, Medium if I lands first)
- **Priority:** High for I/J after CODE; Wave 2 for remaining A–H

### 5.9 [TCA-DETF-SSE-009] High · TEST · Uni V4 CP / legacy J surface gap

- **Summary:** Facet declaration + loupe + proxy J suite absent for both Uni V4 single peers (same as Balancer).
- **Recommended TEST:** J1–J3 per product after inventory of `facetFuncs` vs Target interfaces.
- **Suggested WP:** WP-J-DETF-SSE-CP-001 (can batch with CP I after CODE)
- **Priority:** High

### 5.10 [TCA-DETF-SSE-010] Medium · THEATER / TEST · bare expectRevert (Balancer adversarial)

- **Summary:** Several adversarial negatives use bare `vm.expectRevert()` (H3 minOut, preLive, D2, D3, D5, A3, F2). E5/C use exact selectors — mixed quality.
- **Evidence:** `Adversarial_SingleSE_P0.t.sol`
- **Recommended TEST:** Typed selectors (`ZeroAmount`, `DeadlineExpired`, `IsLocked`, Ownable, etc.).
- **Suggested WP:** WP-N-DETF-SSE-001
- **Priority:** Medium

### 5.11 [TCA-DETF-SSE-011] Medium · TEST · L2 thin; L3 limited surface (Balancer)

- **Summary:** L1 + L3 close 2026-07 fuzz critical gap claim for Single SE. L3 surface is mint/burn/donate only (no bond/sell/pretransfer); runs modest (depth 10, runs 24 typical). L2 absent.
- **Evidence:** `fuzz/`, `invariant/`
- **Suggested WP:** WP-L3-DETF-SSE-001 (Wave 3)
- **Priority:** Medium

### 5.12 [TCA-DETF-SSE-012] Medium · TEST · port residual vs MultiVault layout

- **Summary:** Single consolidated adversarial file vs MultiVault multi-file; B1 weaker (no skew seigniorage bounds); G1 not formal adversarial; F3/D6/H2 N/A documented. Acceptable for ship of I/J wave if P0 IDs remain F where product-applicable.
- **Suggested WP:** optional WP-P1-DETF-SSE-001 after I/J
- **Priority:** Medium / opportunistic

### 5.13 [TCA-DETF-SSE-013] Medium · TEST · Uni V4 legacy product maturity

- **Summary:** Only T01/T02; no burn/bond suite, no adversarial, no fuzz. Product PRD/plan co-located — treat as scaffold. CODE pretransfer fix still Blocker if package is deployable to users.
- **Suggested WP:** fold product H matrix into Stage 2 product plans; keep CODE in WP-I-DETF-SSE-UV4-001
- **Priority:** Medium (test depth); Blocker remains CODE

### 5.14 [TCA-DETF-SSE-014] Info · baseline closed

- **Summary:** Wave 1A adversarial **exists** and covers A1–A3, B1/B3, C1–C3, D2/D3/D5, E1/E4/E5, F1/F2/F4, H3 on production TestBase with hostile share reentrancy. Production-first deploy path exemplary. Preview≡execute green.
- **Priority:** none

### 5.15 [TCA-DETF-SSE-015] Info · no PAT-MOCK SUT on Balancer Single SE money paths

- **Summary:** Spec uses real registry + Aerodrome SE packages. Uni V4 CP adversarial uses SimpleYieldERC4626 **only** for hostile reentrancy pair — DETF SUT remains production DFPkg proxy (acceptable pattern; do not count as mock SUT of DETF).
- **Priority:** none

---

## 6. Theater list

| Test / control | Why theater / weak | Fix |
|----------------|--------------------|-----|
| **Absent** IFacet declaration (Balancer / Uni V4) | No rubber-stamp yet — pure **gap** (better than false green; still fails D/J bar) | Add Target-derived Behavior + J2/J3 |
| Implicit “I covered by A1” | A1 does not call `pretransferred=true` | Add I1–I3; never count A1 as I |
| Bare `expectRevert` on D2/D3/F2/H3/preLive | Can pass on wrong failure mode | Exact selectors |
| E1 early `return` if burn not allowed | Soft skip reduces conservation proof under open burn regimes | Prefer open-threshold instance only (already mostly open) |

**Not theater:** A1–A3, C1–C3 (exact `IsLocked`), E5 exact selectors, production proxy mint/burn matrix, hostile share reentrancy harness.

**No PAT-THEATER-PRE** found (no pretransfer happy-path tests at all).

**No PAT-MOCK** of Balancer DETF SUT.

---

## 7. Prior-report diff

| Claim (doc) | Status now (2026-08-09) |
|-------------|-------------------------|
| Single SE formal `adversarial/` **missing** (highest-priority port) | **Closed for A–H core** — `adversarial/Adversarial_SingleSE_P0.t.sol` + TestBase present |
| Single SE Critical gaps A1,A3,D2,C*,E1,H3,F2… | **Closed** for listed IDs where product-applicable |
| Single SE L1/L3 **G** (fuzz gap report) | **Closed** — `fuzz/` + `invariant/` present (Wave 1B plan) |
| I/J/K columns (not in 2026-07 A–H report) | **New / open** — I=G, J=G, K=P on Balancer; all G on Uni V4 peers |
| MultiVault-comparable “no blocking gap” | **False under A–K** — PAT-I-ABS Blockers + I/J High (same class as MultiVault pilot) |
| Seed: “adversarial dir may now exist — re-verify” | **Confirmed exists**; re-audit finds **I/J/K + CODE** still blocking |

---

## 8. Work package stubs

### WP-I-DETF-SSE-001

| Field | Value |
|-------|--------|
| **WP-ID** | WP-I-DETF-SSE-001 |
| **Title** | Fix Balancer Single SE pretransfer credit to balance-delta (mint/bond/burn) |
| **Severity** | Blocker |
| **Class** | CODE (+ minimal regression) |
| **Products** | SingleStandardExchangeDETF (Balancer) |
| **Finding IDs** | TCA-DETF-SSE-001, TCA-DETF-SSE-002, TCA-DETF-SSE-007 (CODE half) |
| **Problem** | `pretransferred=true` trusts claimed amounts: mint/bond via `_pullToken` return claim; burn burns diamond inventory without inbound proof. Free mint / free extract. |
| **Production files** | `…/standardExchange/single/SingleStandardExchangeDETFCommon.sol` (`_pullToken`); `SingleStandardExchangeDETFExchangeOutTarget.sol` (`_burnDetfExactIn`); Bonding/ExchangeIn call sites if signatures need adjust |
| **Test files** | temporary proof under `adversarial/`; full I suite in WP-I-DETF-SSE-002 |
| **Out of scope** | MultiVault / Uni V4 packages (separate WPs); A–H rewrite; BasicVaultCommon |
| **Depends on** | Prefer semantics freeze with WP-I-DETF-MV-001 / Wave-0 pull pattern |
| **Parallelizable with** | WP-J-DETF-SSE-001; WP-I-DETF-SSE-CP-001 (different files) |
| **Suggested worktree** | `gap_cover_i-detf-sse` · branch `gap_cover/i-detf-sse` |
| **Implementation notes** | Mirror MultiVault CODE fix; crane-adversarial Category I; DETF role names; no `via_ir` |
| **Acceptance** | `forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/**' --match-test 'test_I1_'` green; free-mint setup fails attacker enrichment |
| **Anti-theater** | I1 must **not** transfer tokens for the attacker; diamond may already hold inventory ≥ amount |
| **Estimate** | M |

### WP-I-DETF-SSE-002

| Field | Value |
|-------|--------|
| **WP-ID** | WP-I-DETF-SSE-002 |
| **Title** | Add Balancer Single SE adversarial I1–I3 (+ bond + burn) and K1 |
| **Severity** | High |
| **Class** | TEST |
| **Products** | SingleStandardExchangeDETF |
| **Finding IDs** | TCA-DETF-SSE-005, TCA-DETF-SSE-007 |
| **Problem** | Catalog I P0 absent; K1 pretransfer unproven. |
| **Production files** | none (after 001) |
| **Test files** | `…/standardExchange/single/adversarial/Adversarial_TrustFlag.t.sol` (new) or extend `Adversarial_SingleSE_P0.t.sol` |
| **Out of scope** | Facet declaration (WP-J); Uni V4; P2 catalog |
| **Depends on** | WP-I-DETF-SSE-001 |
| **Parallelizable with** | WP-N-DETF-SSE-001 after 001 |
| **Suggested worktree** | `gap_cover_i-detf-sse-tests` (or same as 001) |
| **Implementation notes** | Copy MultiVault I patterns once green; exact selectors; residual helpers from adversarial TestBase |
| **Acceptance** | `forge test --match-path '.../standardExchange/single/adversarial/**' --match-test 'test_I'` green; names `test_I1_*`, `test_I2_*`, `test_I3_*`; optional `test_K1_*` |
| **Anti-theater** | I1 no transfer; I2 short transfer; I3 second call without new funds; K1 must use `pretransferred=true` after donate |
| **Estimate** | S–M |

### WP-J-DETF-SSE-001

| Field | Value |
|-------|--------|
| **WP-ID** | WP-J-DETF-SSE-001 |
| **Title** | Balancer Single SE J1–J3 surface suite on production proxy |
| **Severity** | High |
| **Class** | TEST (CODE only if omit found) |
| **Products** | SingleStandardExchangeDETF |
| **Finding IDs** | TCA-DETF-SSE-006 |
| **Problem** | No declaration suite; no loupe/proxy catalog proof. |
| **Production files** | only if PAT-J-OMIT confirmed |
| **Test files** | new `SingleStandardExchangeDETFExchangeInFacet_IFacet.t.sol` + `Adversarial_Surface.t.sol` under single/ |
| **Out of scope** | A–H rewrite; I suite |
| **Depends on** | none |
| **Parallelizable with** | WP-I-DETF-SSE-001 |
| **Suggested worktree** | `gap_cover_j-detf-sse` |
| **Implementation notes** | Controls from Target/interfaces; J3 calls **proxy** after `indexedexManager.deployVault` |
| **Acceptance** | `test_J1_*`, `test_J2_*`, `test_J3_*` green; loupe non-zero all product sels |
| **Anti-theater** | Never assert only on facet implementation address for J2/J3 |
| **Estimate** | S–M |

### WP-K-DETF-SSE-001

| Field | Value |
|-------|--------|
| **WP-ID** | WP-K-DETF-SSE-001 |
| **Title** | K1 donation + pretransfer credit regression (Balancer Single SE) |
| **Severity** | High |
| **Class** | TEST |
| **Products** | SingleStandardExchangeDETF |
| **Finding IDs** | TCA-DETF-SSE-007 |
| **Problem** | K1 incomplete once I path considered. |
| **Test files** | may live inside Adversarial_TrustFlag |
| **Depends on** | WP-I-DETF-SSE-001 |
| **Parallelizable with** | WP-I-DETF-SSE-002 (**merge preferred**) |
| **Suggested worktree** | merge with `gap_cover_i-detf-sse-tests` |
| **Acceptance** | `test_K1_*` or documented alias of I1 with donate setup |
| **Anti-theater** | Must use `pretransferred=true` after donate |
| **Estimate** | S |

### WP-I-DETF-SSE-CP-001

| Field | Value |
|-------|--------|
| **WP-ID** | WP-I-DETF-SSE-CP-001 |
| **Title** | Fix Uni V4 CP Single SE pretransfer + add I1–I3 |
| **Severity** | Blocker (CODE) / High (TEST) |
| **Class** | BOTH |
| **Products** | UniswapV4SingleStandardExchangeDETF (constantProduct/single) |
| **Finding IDs** | TCA-DETF-SSE-003, TCA-DETF-SSE-008 (I portion) |
| **Problem** | Identical claim-return `_pullToken` and burn skip; no I suite. |
| **Production files** | `…/constantProduct/single/UniswapV4SingleStandardExchangeDETFCommon.sol`; `…ExchangeOutTarget.sol` |
| **Test files** | new under `test/.../constantProduct/single/` adversarial or extend existing |
| **Out of scope** | Balancer Single SE; orbital/weighted |
| **Depends on** | Prefer same pull semantics as WP-I-DETF-SSE-001 |
| **Parallelizable with** | WP-I-DETF-SSE-001 (different trees) |
| **Suggested worktree** | `gap_cover_i-detf-sse-cp` |
| **Implementation notes** | Production TestBase; no mock DETF; role names pairToken / vaultShare / detfToken |
| **Acceptance** | `forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/**' --match-test 'test_I'` green |
| **Anti-theater** | I1 no transfer; production SE for I1 (hostile SE optional for C only) |
| **Estimate** | M |

### WP-I-DETF-SSE-UV4-001

| Field | Value |
|-------|--------|
| **WP-ID** | WP-I-DETF-SSE-UV4-001 |
| **Title** | Fix legacy Uni V4 Single SE absolute-balance pretransfer |
| **Severity** | Blocker |
| **Class** | CODE (+ smoke tests) |
| **Products** | UniswapV4SingleStandardExchangeDETF (legacy single path) |
| **Finding IDs** | TCA-DETF-SSE-004 |
| **Problem** | `balanceOf >= amount` then return claim enables free credit. |
| **Production files** | `…/standardExchange/single/UniswapV4SingleStandardExchangeDETFCommon.sol`; burn path in ExchangeInTarget |
| **Test files** | extend T02 or new TrustFlag once H matures |
| **Out of scope** | Full A–H product suite (product plan) |
| **Depends on** | same pull semantics freeze |
| **Parallelizable with** | other product CODE WPs |
| **Suggested worktree** | `gap_cover_i-detf-sse-uv4` |
| **Acceptance** | unit/path test that donate + pretransfer does not mint free detfToken |
| **Anti-theater** | absolute inventory must not satisfy I1 |
| **Estimate** | S–M |

### WP-J-DETF-SSE-CP-001

| Field | Value |
|-------|--------|
| **WP-ID** | WP-J-DETF-SSE-CP-001 |
| **Title** | Uni V4 CP Single SE J1–J3 surface suite |
| **Severity** | High |
| **Class** | TEST |
| **Products** | UniswapV4SingleStandardExchangeDETF (CP) |
| **Finding IDs** | TCA-DETF-SSE-009 |
| **Problem** | No J proof on CP facet/proxy. |
| **Depends on** | none |
| **Parallelizable with** | WP-I-DETF-SSE-CP-001 |
| **Suggested worktree** | `gap_cover_j-detf-sse-cp` |
| **Acceptance** | `test_J1_*`…`test_J3_*` on CP proxy |
| **Anti-theater** | J3 on proxy not facet impl |
| **Estimate** | S–M |

### WP-N-DETF-SSE-001

| Field | Value |
|-------|--------|
| **WP-ID** | WP-N-DETF-SSE-001 |
| **Title** | Exact selectors on Balancer Single SE adversarial bare reverts |
| **Severity** | Medium |
| **Class** | TEST |
| **Finding IDs** | TCA-DETF-SSE-010 |
| **Depends on** | none |
| **Parallelizable with** | WP-J-DETF-SSE-001 |
| **Suggested worktree** | `gap_cover_n-detf-sse` |
| **Acceptance** | no bare `expectRevert()` on P0 adversarial without NatSpec reason |
| **Estimate** | S |

### WP-L3-DETF-SSE-001

| Field | Value |
|-------|--------|
| **WP-ID** | WP-L3-DETF-SSE-001 |
| **Title** | Expand Single SE Handler (bond/sell/pretransfer) |
| **Severity** | Medium |
| **Class** | TEST |
| **Finding IDs** | TCA-DETF-SSE-011 |
| **Depends on** | WP-I-DETF-SSE-001 for pretransfer ops |
| **Wave** | 3 |
| **Suggested worktree** | `gap_cover_l3-detf-sse` |
| **Estimate** | M |

---

## 9. Deferred / N/A / NEEDS_OWNER

| Item | Class | Note |
|------|-------|------|
| D6, H2, F3 claim-token paths | **N/A** | Balancer Single SE v1 uses sellPosition; no rebasing claim (NatSpec) |
| A4–A5, B2, C4–C5, H1 | **DEFER** | P2 residual vs MultiVault |
| exchangeOut public API | **N/A** | Burn via exchangeIn; no MultiVault-style InvalidRoute stub |
| I4 FoT | **DEFER** | SE vaultShare legs |
| Orbital / Weighted Uni V4 DETF | **Out of area** | Not under `**/standardExchange/single/**` |
| Donation beneficiary soft-credit policy | **NEEDS_OWNER** only if product chooses soft accounting; default law is no free credit |
| Shared pull library across DETFs | Cross-area | Coordinate with MultiVault / Wave-0; bugs are **package-local** clones |
| Runtime forge PoC this session | **RUNTIME_UNPROVEN** | Static overwhelming for all four CODE Blockers |

---

## 10. Commands run

```bash
# Inventory
ls contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/
ls test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/
ls test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/adversarial/

# Production trust-flag / surface
rg -n "pretransferred|_pullToken|function facetFuncs" \
  contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single --glob '*.sol'
rg -n "pretransferred|_pullToken|function facetFuncs" \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/single --glob '*.sol'
rg -n "pretransferred|_pullToken|function facetFuncs" \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single --glob '*.sol'

# Catalog / I-J-K presence
rg -n "function test_|test_I|test_J|test_K|pretransferred|facetAddress|IDiamondLoupe|expectRevert" \
  test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single --glob '*.sol'
rg -n "function test_|test_I|test_J|test_A|pretransferred" \
  test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/standardExchange --glob '**/single/**/*.sol'
rg -n "function testFuzz_|function invariant_" \
  test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single --glob '*.sol'

# Prior reports
rg -n "SingleStandardExchange|standardExchange/single" docs/testing/ADVERSARIAL_VAULT_COVERAGE_GAP_REPORT.md
```

**Not run this session:** live `forge test` / runtime free-mint PoC (Blockers marked RUNTIME_UNPROVEN per §3.8).

---

## Return summary (orchestrator)

| Field | Value |
|-------|--------|
| **Status** | **COMPLETE** |
| **Path** | `docs/testing/coverage-audit/areas/T-detf-single-se.md` |
| **Blocker count** | **4** (TCA-DETF-SSE-001…004) |
| **High count** | **5** (TCA-DETF-SSE-005…009) |
| **Top WPs** | WP-I-DETF-SSE-001 · WP-I-DETF-SSE-002 · WP-J-DETF-SSE-001 · WP-I-DETF-SSE-CP-001 · WP-I-DETF-SSE-UV4-001 |
| **Seed outcome** | Adversarial **exists** (A–H port largely done); **I/J/K + PAT-I-ABS CODE** remain first-wave blockers (parity with MultiVault pilot under A–K) |
