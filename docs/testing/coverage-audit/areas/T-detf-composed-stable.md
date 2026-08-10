# Test Coverage Audit — T-detf-composed-stable

| Field | Value |
|-------|--------|
| Date | 2026-08-09 |
| Agent / run | Stage 1 area subagent · full · T-detf-composed-stable |
| Status | **COMPLETE** |
| Production paths | `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/**`; `contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/**` |
| Test paths | `test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/stable/**` (incl. `adversarial/`, `sequences/`); `test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/**` |
| Skills / PRD version cited | `TEST_COVERAGE_AUDIT_PRD` §2,2.3–2.4,3.8,5,6,7.2,8,19; crane-adversarial-testing A–K + `implementation-test-dod.md`; crane-testing LR-7; DETF roles only |
| Prior seed | `ADVERSARIAL_VAULT_COVERAGE_GAP_REPORT.md` §3 ComposedStable; `ADVERSARIAL_…_IMPLEMENTATION_PLAN.md` Wave 1B; `FUZZ_INVARIANT_…` Wave 3A (L2 sequences); pilot `T-basic-protocol-commons` clone inventory (CS + rebasing claim) |
| Finding ID prefix | **TCA-DETF-CS-NNN** |

---

## 1. Executive summary

### Maturity (0–5)

| Product | Maturity | Worst open severity | One-line |
|---------|----------|---------------------|----------|
| **ComposedStableCommonDetf** (+ BondNFTVault + routes) | **2** | **Blocker** (CODE, RUNTIME_UNPROVEN) | Production integrated H/claim + partial A–H adversarial; **PAT-I-ABS** on `_secureTokenTransfer`; **I/J/K incomplete**; many unit specs on **Mock** harness (not SUT); **no L1/L3**; L2 sequences thin |
| **RebasingDETFToken** (companion claim diamond) | **2** | **Blocker** (CODE, RUNTIME_UNPROVEN) | Behavior H on claim redeem; declaration D for facets; **PAT-I-ABS** + exact-out pretransfer credits `maxAmountIn`; **I1–I3 G** |
| **MixedBufferMultiVaultStableDetf** | **2** | **Blocker** (CODE, RUNTIME_UNPROVEN) | Strong hermetic H/N (mint/burn/bond/claim/nested/n-legs/residual helpers); **no `adversarial/`**; **PAT-I-ABS** `_pullToken` + burn skip-transfer; **I/J/K G**; no L1–L3 |

### Severity counts (this area)

| Severity | Count | IDs |
|----------|-------|-----|
| **Blocker** | **4** | TCA-DETF-CS-001 … 004 |
| **High** | **7** | TCA-DETF-CS-005 … 011 |
| Medium | 5 | TCA-DETF-CS-012 … 016 |
| Low / Info | 3 | TCA-DETF-CS-017 … 019 |

### Top 5 recommended WPs

1. **WP-I-DETF-CS-001** — CODE: delta-safe `_secureTokenTransfer` in `ComposedStableCommonDetfCommon` (+ RebasingDETFToken pull/exact-out) — **Blocker**
2. **WP-I-DETF-MB-001** — CODE: delta-safe `_pullToken` + burn pretransfer on MixedBuffer — **Blocker** (parallel to CS once API frozen; or fold into Wave-0 `WP-I-CLONE-001`)
3. **WP-I-DETF-CS-002** — TEST: I1–I3 (+ K1 pretransfer) on ComposedStable **production** graph + Rebasing claim — **High**
4. **WP-ADV-DETF-MB-001** — TEST: MixedBuffer dedicated `adversarial/` A–H P0 subset + I1–I3 — **High**
5. **WP-J-DETF-CS-MB-001** — TEST: J1–J3 Target-derived controls + loupe + **proxy** smoke (CS multi-facet + MB combined facet) — **High**

**Focus outcomes:** multi-leg residual partially covered (MB `_assertNoFreeInventory`, CS sequences free-detf=0, CS exchangeOut residual vault-token negative); **claim** happy + partial adversarial H2/D3 on CS; **G nested** green on MB only — **G gap on ComposedStable**; **I/J/K ship-gate fails** both money products; **PAT-I-ABS** confirmed static on CS Common + Rebasing + MB Common.

---

## 2. Product inventory

### 2.1 Production packages

| Product | DFPkg / key Targets | Facets | TestBase | Test roots | Deploy path quality |
|---------|---------------------|--------|----------|------------|---------------------|
| **ComposedStableCommonDetf** | `ComposedStableCommonDetfDFPkg.sol`; ExchangeIn, ExchangeOutQuery, Bonding, Common, Repo | `ComposedStableCommonDetfExchangeIn`; `…ExchangeOutQueryFacet`; `…BondingFacet` | `TestBase_ComposedStableCommonDetf.sol` (+ Components) | `test/.../stable/common/**` | **Gold path on integrated:** CREATE3 factories + manager/registry deploy via IntegratedDeploy. Unit ExchangeIn/Bonding/Burn harnesses use **MockStandardExchange** / mock routers — **do not count as SUT money coverage** |
| **ComposedStable BondNFTVault** | `ComposedStableCommonDetfBondNFTVaultDFPkg.sol` | `…BondNFTVaultFacet` | Deploy specs | BondNFT deploy + integrated graph | Registry/CREATE3 |
| **RebasingDETFToken** | `RebasingDETFTokenDFPkg.sol` | `RebasingDETFTokenFacet`; `RebasingDETFTokenPricingFacet` | Behavior harness + integrated claim | `RebasingDETFToken*.t.sol`; claim via IntegratedDeploy | DFPkg deploy |
| **MixedBufferMultiVaultStableDetf** | `MixedBufferMultiVaultStableDetfDFPkg.sol`; ExchangeIn/Out/Query, Bonding, Info, Common, Repo | Combined `MixedBufferMultiVaultStableDetfExchangeInFacet` (35 sels) | `TestBase_MixedBufferMultiVaultStableDetf.sol` (co-located production path) | `test/.../mixedBuffer/**` | **Gold**: CREATE3 + `indexedexManager.deployVault`; SE legs production Aerodrome-style packages via TestBase |

### 2.2 Production file inventory (high signal)

#### Composed stable (`…/stable/common/`)

| Path | Role |
|------|------|
| `ComposedStableCommonDetfCommon.sol` | Multi-leg join/exit math; **`_secureTokenTransfer`** (PAT-I-ABS) |
| `ComposedStableCommonDetfExchangeIn.sol` | Mint/burn exact-in; `facetFuncs` (13) |
| `ComposedStableCommonDetfExchangeOutQueryFacet.sol` | Exact-out + claimLiquidity; `facetFuncs` (4) |
| `ComposedStableCommonDetfBondingFacet.sol` | bond/sellNFT; pull always `pretransferred=false` |
| `ComposedStableCommonDetfBondNFTVault*.sol` | Bond NFT inventory diamond |
| `RebasingDETFTokenTarget.sol` | Claim mint/redeem/exchangeIn/Out; **`_secureTokenTransfer`** + burn pretransfer |
| `RebasingDETFTokenFacet.sol` / `PricingFacet.sol` | IFacet surfaces |
| `*_FactoryService.sol` | CREATE3 |
| `TestBase_ComposedStableCommonDetf*.sol` | Gold TestBase components |

#### Mixed buffer (`…/mixedBuffer/`)

| Path | Role |
|------|------|
| `MixedBufferMultiVaultStableDetfCommon.sol` | Stable math, join/exit; **`_pullToken`** (PAT-I-ABS); residual helper |
| `MixedBufferMultiVaultStableDetfExchangeInTarget.sol` | Mint buffer/share → detfToken via `_pullToken` |
| `MixedBufferMultiVaultStableDetfExchangeOutTarget.sol` | Burn → buffer only; **skips transfer if pretransferred** |
| `MixedBufferMultiVaultStableDetfBondingTarget.sol` | bootstrapFirstBond; bond with pretransfer flag; redeemClaim → buffer |
| `MixedBufferMultiVaultStableDetfExchangeInFacet.sol` | Combined facetFuncs (35) |
| `TestBase_MixedBufferMultiVaultStableDetf.sol` | Gold TestBase |

### 2.3 Trust-flag entrypoints (I-applicable)

| Product | Entrypoint | Flag | Credit path |
|---------|------------|------|-------------|
| **CS DETF** | `exchangeIn` mint | `pretransferred` | `_secureTokenTransfer` → if true **`return amount_`** (no bal check) |
| **CS DETF** | `exchangeIn` burn | `pretransferred` | same pull on detfToken |
| **CS DETF** | `exchangeOut` | `pretransferred` | `_secureTokenTransfer(maxAmountIn)` then refund unused |
| **CS DETF** | `bond` | *none* | always `_secureTokenTransfer(..., false)` |
| **Rebasing claim** | `redeem` / `exchangeIn` | `pretransferred` | `_secureTokenTransfer` → **`return amount_`** if true |
| **Rebasing claim** | `exchangeOut` | `pretransferred` | if true sets `depositedIn = maxAmountIn` **without transfer or delta** |
| **Rebasing claim** | `burnShares` | `pretransferred` | burns from `address(this)` inventory |
| **MixedBuffer** | `exchangeIn` mint | `pretransferred` | `_pullToken` → **`return amount_`** if true |
| **MixedBuffer** | burn via exchangeIn/Out | `pretransferred` | skip `transferFrom`; burn diamond detfToken |
| **MixedBuffer** | `bond` | `pretransferred` | `_pullToken` on buffer / vaultShare / reserveBpt |

### 2.4 Facet surface (J static skim)

| Surface | Static impression |
|---------|-------------------|
| CS ExchangeIn `facetFuncs` | 13 sels: exchangeIn/preview + thresholds + expansion + compound; **split** from Out/Bonding |
| CS ExchangeOutQuery | preview/exchangeOut + claimLiquidity |
| CS Bonding | acceptedBondTokens / isAccepted / bond / sellNFT (no redeemClaim on DETF — claim is rebasing token) |
| Rebasing Facet | Declaration tests with `controlFacetFuncs` present |
| MB ExchangeInFacet | 35 sels incl. exchangeIn/Out, bootstrap, bond, redeemClaim, info, compound, expansion |

**No** Target↔facetFuncs diff suite / loupe / full proxy J3 catalog on CS DETF facets or MB (MB has length-floor + metadata↔funcs equality on **facet address**, not proxy).

### 2.5 Hermetic / property / adversarial test roots

| Root | Role | Notes |
|------|------|-------|
| CS IntegratedDeploy + Threshold/Expansion/Compound | Production-graph H | Registry + real Balancer adapters |
| CS ExchangeIn/Out/Bonding unit | Route/logic | **Mock SUT routers** — theater for money security |
| CS `adversarial/Adversarial_ComposedStable_P0.t.sol` | Partial A–H on **production** graph | ~11 tests; bare expectRevert; **no I/J/K**; C deferred NatSpec |
| CS `sequences/` | L2 fixed choreography | 3 sequences; residual free detf=0 |
| CS Rebasing behavior + IFacet | Claim H + D | pretransfer burn **happy** only |
| MB full matrix | Deploy/Mint/Burn/Bond/Claim/Guards/Routes/Liveness/Threshold/Nested/NLegs/PriceShift/Compound/Reentrancy/IFacet | Strong H/N residual asserts; **no adversarial/**; **no fuzz/invariant** |

---

## 3. Layer matrix

Legend: **F** full · **P** partial · **G** gap · **N/A** · **S** stub/theater

| Product | H | N | D | J | I | K | A–H | P | L1 | L2 | L3 | Maturity | Notes |
|---------|---|---|---|---|---|---|-----|---|----|----|----|----------|-------|
| ComposedStableCommonDetf | **P**→**F**\* | **P** | **P**/**S** | **G** | **G** | **P**‡ | **P** | **P** | **G** | **P** | **G** | **2** | Integrated H strong; unit Mock heavy |
| RebasingDETFToken | **P** | **P** | **F**/**P** | **P**/**G**† | **G** | **G** | **P**§ | **P** | **G** | **G** | **G** | **2** | Integrated claim + unit behavior |
| MixedBufferMultiVaultStableDetf | **F** | **P**→**F** | **S**/**P** | **G**/**P** | **G** | **P**‡ | **G**/**P**‖ | **P** | **G** | **G** | **G** | **2** | Nested+NLegs residual strong; no catalog suite |

\* Production IntegratedDeploy/Threshold/Compound/Expansion count as H; Mock unit exchange paths do **not**.  
† Rebasing has Behavior_IFacet controls; **proxy loupe J2–J3** incomplete.  
‡ Pull-path donation partial (A1 CS); pretransfer donation free-credit untested + CODE-broken.  
§ Claim D2/D3/H2 via CS adversarial + behavior; not full claim adversarial catalog.  
‖ MB has C-class reentrancy + residual helpers but **no** catalog-labeled A–H adversarial dir.

### Layer evidence (summary)

| Layer | ComposedStable | MixedBuffer |
|-------|----------------|-------------|
| **H** | Integrated mint, bond→sell→redeem; Threshold open round-trip; Expansion E1–E8; Compound C1–C8 | Mint buffer/share; burn buffer; bond; claim redeem; bootstrap; nested; n1–n3 lifecycle |
| **N** | Exact selectors strong on Out unit harness; adversarial often bare `expectRevert` | Exact ZeroAmount/Deadline/InvalidRoute/MintingNotAllowed on many paths |
| **D** | DFPkg packageMetadata; **no** IFacet for ExchangeIn/Out/Bonding; Rebasing IFacet OK | IFacet name/iface/length floors only |
| **J** | **G** formal; proxy exercised in H only | **G** formal; proxy H only |
| **I** | **Zero** `test_I1_`…; all live exchange use `false` | **Zero** I suite; bond/mint use `false` |
| **K** | A1 donate DAI no free detf (pull path) | Happy residual asserts; no K1 pretransfer |
| **A–H** | Partial P0 (see §4) | No catalog suite; C-like reentrancy present |
| **P** | Integrated mint `assertGe(amountOut, previewOut)`; not systematic fee-route matrix | Threshold uses preview; no dedicated preview≡execute suite |
| **L1** | **G** (fuzz plan Wave 3A deferred L1) | **G** |
| **L2** | 3 sequences (mint/burn residual, multi-actor, bond claim) | **G** (NLegs/Nested partial substitute) |
| **L3** | **G** | **G** |

---

## 4. Catalog matrix (A–K)

### 4.1 ComposedStableCommonDetf (+ claim companion where noted)

| ID | Score | Evidence (test name) or G |
|----|-------|---------------------------|
| **A1** | **F** | `Adversarial_ComposedStable_P0.test_A1_donateDai_cannotMintFreeDetf` |
| **A2** | **F** | `test_A2_donateDetfToken_noTheft` |
| **A3** | **P** | Combined with D2: donate/BPT drain via redeem without claim |
| A4–A5 | **G** / **DEFER** | multi-leg dust / FoT not cataloged |
| **B1** | **G** | no synthetic skew suite (thresholds covered separately) |
| **B3** | **P** | ThresholdMode policy deadband / open mode (not adversarial-labeled) |
| **C1–C3** | **G** / **DEFER** | NatSpec: multi-leg hostile reentrancy deferred P2 in adversarial file |
| **D2** | **F** | `test_A3_D2_redeemWithoutClaim_noPrincipalDrain` |
| **D3** | **F** | `test_D3_doubleRedeemClaim_secondReverts` |
| **D6** | **P** | over-redeem reverts in D3/H2; no explicit “cannot redeem more than principal” inventory math |
| **E1** | **P** | sequences mint partial burn; residual free detf |
| **E4** | **F** | `test_E4_holderBalance_notDilutedByOthersMint` |
| **E5** | **P** | zero preview + expired deadline (bare revert) |
| **F1** | **F** | `test_F1_diamondCut_blocked` |
| **F2** | **F** | `test_F2_bondNft_createPosition_onlyOwner` |
| **F3** | **G** | claim mintFromNFTSale / burnShares onlyOwner not adversarial-cataloged (behavior unit has owner paths) |
| **G1** | **G** | **no** nested outer/inner DETF matrix for ComposedStable (prior gap still open) |
| **H2** | **F** | `test_H2_redeemClaim_failLeavesClaim` |
| **H3** | **F** | `test_H3_minOutTooHigh_leavesNoStrandedMint` |
| **I1–I3** | **G** | no tests; CODE broken (PAT-I-ABS) |
| **J1–J3** | **G**/**P** | no J suite; H calls money API on proxy only |
| **K1** | **P** | A1 pull-path; **G** for donate+`pretransferred=true` |

**P0 DETF subset (PRD §2.3):** A1 **F**; A3 **P**; B1 **G**; B3 **P**; C1–C3 **G**; D2/D3 **F**; D6 **P**; E1 **P**; E5 **P**; F2 **F**; F3 **G**; H2/H3 **F**; **I1–I3 G**; **J1–J3 G/P**; **K1 P**.

### 4.2 MixedBufferMultiVaultStableDetf

| ID | Score | Evidence or G |
|----|-------|---------------|
| **A1–A3** | **G** | no donation adversarial; residual helper is happy-path only |
| **B1/B3** | **P** | Pricing/ThresholdMode/PriceShift gates |
| **C1–C3** | **P** | `MixedBuffer…_Reentrancy` nested mint/bond `IsLocked`-style |
| **D2/D3/D6** | **G**/**P** | Claim happy redeem only (`Claim.t.sol`); no double-redeem / no-claim adversarial |
| **E1** | **P** | Mint+Burn + `_assertNoFreeInventory`; NLegs lifecycle |
| **E5** | **F** | Guards zero + deadline exact selectors |
| **F1–F3** | **G**/**P** | Deploy via registry asserted; bond NFT access not catalog-suite |
| **G1** | **F** | `test_nestedDetf_asLeg_outerMintBurnBond` + residual both diamonds |
| **H2/H3** | **G**/**P** | no fail-atomicity claim suite; minOut via burn/mint guards partial |
| **I1–I3** | **G** | no tests; CODE broken |
| **J1–J3** | **G**/**P** | IFacet floors only |
| **K1** | **G**/**P** | residual asserts; no donation→pretransfer |

**P0 DETF subset:** largely **G/P** except E5 **F**, G1 **F**, C **P**, B3 **P**. **Adversarial catalog directory absent.**

### 4.3 RebasingDETFToken (claim)

| ID | Score | Evidence or G |
|----|-------|---------------|
| Claim H2 atomicity | **P**/**F** | behavior: failed claimLiquidity does not burn shares |
| D2/D3 | **F** | via CS adversarial on production claim |
| **I1–I3** | **G** | happy `test_burnShares_pretransferred_burnsFromTokenBalance` is **THEATER-PRE** class for burn (real transfer to token first) |
| **J** | **P** | IFacet control lists present; full proxy J incomplete |

---

## 5. Findings

### 5.1 [TCA-DETF-CS-001] Blocker · CODE · PAT-I-ABS (ComposedStable pull)

- **Summary:** `ComposedStableCommonDetfCommon._secureTokenTransfer` with `pretransferred_=true` returns caller-claimed `amount_` with **no** balance check and **no** inbound delta. Mint (`_executeMintRoute`), burn exact-in (`_executeBurnRoute`), and exchangeOut (`_executeExchangeOut`) credit free principal against diamond inventory (or invent credit if downstream join tolerates).
- **Evidence:**
  - `ComposedStableCommonDetfCommon.sol` ~297–300: `if (pretransferred_) { return amount_; }`
  - Call sites: `ComposedStableCommonDetfExchangeIn.sol` ~160, ~189; `ComposedStableCommonDetfExchangeOutQueryFacet.sol` ~172
- **Why bar fails:** Ship gate I + L-CLAIM-3 / `implementation-test-dod.md` — credit must be observed delta.
- **Recommended CODE:** Always snapshot `balanceOf(this)` before; if pretransferred require `balAfter - balBefore >= amount_` (or credit **only** measured delta); update any reserve snapshot. Align with Wave-0 commons / clone API if orchestrator serializes.
- **Recommended TEST:** `test_I1_pretransferred_true_noTransfer_existingInventory_noFreeMint` on IntegratedDeploy graph — donate pairToken/rateAsset inventory, call `exchangeIn(..., pretransferred=true)` without transfer; attacker detfToken unchanged; exact selector on shortfall path. Match-path: `…/stable/common/adversarial/**`.
- **Suggested WP:** WP-I-DETF-CS-001
- **Priority:** Wave 0/1 — Blocker
- **Runtime:** **RUNTIME_UNPROVEN** this run; static evidence overwhelming (literal early return). Cross-ref pilot `TCA-COMMON-004` clone inventory.

### 5.2 [TCA-DETF-CS-002] Blocker · CODE · PAT-I-ABS (RebasingDETFToken claim pull + exact-out)

- **Summary:** (1) `_secureTokenTransfer` same blind `return amount_` for `pretransferred=true`. (2) `exchangeOut` when `pretransferred` sets `depositedIn = maxAmountIn` without any transfer/delta — free claim of common/rateAsset out against idle rebasingClaimToken inventory. (3) `burnShares(..., pretransferred=true)` burns from `address(this)` without proving inbound claim tokens (owner-gated mitigates external attacker but still wrong inventory attribution if owner is compromised or mis-integrated).
- **Evidence:**
  - `RebasingDETFTokenTarget.sol` ~409–411 (`return amount_`); ~205–210 (`depositedIn = maxAmountIn`); ~245–247 (`burnFrom = address(this)`)
  - Call sites: redeem ~155; exchangeIn ~176
- **Why bar fails:** Trust-flag free principal on claim money path; claim is DETF P0 surface.
- **Recommended CODE:** Delta-safe pull for self and foreign tokens; exact-out must measure inbound claim tokens then refund unused; burn pretransfer requires measured escrow or always burn from owner with transfer.
- **Recommended TEST:**
  - `test_I1_claim_redeem_pretransferred_noTransfer_noFreeRateAsset`
  - `test_I1_claim_exchangeOut_pretransferred_maxIn_noInventoryCredit`
  - Match-path: claim/rebasing specs + CS adversarial
- **Suggested WP:** WP-I-DETF-CS-001 (same CODE touch set as CS DETF if shared helper; else WP-I-DETF-CS-001b)
- **Priority:** Wave 0/1 — Blocker
- **Runtime:** RUNTIME_UNPROVEN; static overwhelming. Cross-ref `TCA-COMMON-004` / `TCA-COMMON-005` (common RebasingClaimToken residual is related but separate package).

### 5.3 [TCA-DETF-CS-003] Blocker · CODE · PAT-I-ABS (MixedBuffer `_pullToken`)

- **Summary:** `MixedBufferMultiVaultStableDetfCommon._pullToken` returns claimed amount on `pretransferred_=true` with no check. Mint (buffer/share) and bond (buffer/share/BPT) free-credit donated inventory.
- **Evidence:** `MixedBufferMultiVaultStableDetfCommon.sol` ~510–511; mint `ExchangeInTarget` ~50, ~58; bond `BondingTarget` ~148, ~153, ~163.
- **Why bar fails:** Same I free-mint class as MultiVault `_pullToken` (`TCA-DETF-MV-001` clone).
- **Recommended CODE:** Identical delta-safe pull; prefer shared DETF helper.
- **Recommended TEST:** `test_I1_mb_pretransferred_mint_noTransfer_donatedBuffer_noFreeDetf` after live bootstrap. Match-path: `…/mixedBuffer/adversarial/**` (new).
- **Suggested WP:** WP-I-DETF-MB-001
- **Priority:** Wave 0/1 — Blocker
- **Runtime:** RUNTIME_UNPROVEN

### 5.4 [TCA-DETF-CS-004] Blocker · CODE · PAT-I-ABS (MixedBuffer burn pretransfer)

- **Summary:** `_burnDetfExactInToBuffer` skips `transferFrom` when `pretransferred_=true`, then burns `detfIn_` from `address(this)` and pays bufferToken — free extract of buffer against donated detfToken inventory (A2 hybrid).
- **Evidence:** `MixedBufferMultiVaultStableDetfExchangeOutTarget.sol` ~42–47.
- **Why bar fails:** Free principal extract; mirrors MultiVault burn pretransfer (`TCA-DETF-MV-002`).
- **Recommended CODE:** Require measured inbound detfToken to diamond **or** burn from msg.sender balance; never attribute diamond free detfToken to pretransfer claim without delta.
- **Recommended TEST:** `test_I1_mb_burn_pretransferred_donatedDetf_noBufferExtract`.
- **Suggested WP:** WP-I-DETF-MB-001 (same CODE set)
- **Priority:** Wave 0/1 — Blocker
- **Runtime:** RUNTIME_UNPROVEN

### 5.5 [TCA-DETF-CS-005] High · TEST · catalog I1–I3 absent (ComposedStable + claim)

- **Summary:** No `test_I1_` / `test_I2_` / `test_I3_` under stable tests. All production exchange paths use `pretransferred=false`. Rebasing has happy pretransfer burn only (not I1).
- **Evidence:** `rg 'test_I[123]_' test/.../stable` → empty; adversarial + IntegratedDeploy call sites `false`.
- **Why bar fails:** DETF P0 requires I1–I3 when flag exists.
- **Recommended TEST:** Trust-flag suite on IntegratedDeploy: I1 no-transfer free mint/burn/claim redeem; I2 short transfer exact selector; I3 residual reuse second call. Pass criteria: attacker balances + residual helpers + exact errors.
- **Suggested WP:** WP-I-DETF-CS-002 (depends on WP-I-DETF-CS-001)
- **Priority:** High — Wave 1

### 5.6 [TCA-DETF-CS-006] High · TEST · catalog I1–I3 + K1 absent (MixedBuffer)

- **Summary:** Zero I suite; no K1 donate→pretransfer. Residual `_assertNoFreeInventory` does not prove trust-flag abuse.
- **Evidence:** `rg test_I|pretransferred.*true` under mixedBuffer tests → only reentrancy mock surface / `false` bond flags.
- **Recommended TEST:** New `adversarial/Adversarial_TrustFlag.t.sol` I1–I3 mint/bond/burn + K1 donation.
- **Suggested WP:** WP-ADV-DETF-MB-001 (or split WP-I-DETF-MB-002 after CODE)
- **Priority:** High

### 5.7 [TCA-DETF-CS-007] High · TEST + THEATER · PAT-THEATER-FACET / J1–J3 (both products)

- **Summary:** CS lacks IFacet declaration tests for money facets (only DFPkg packageMetadata + Rebasing IFacet). MB IFacet tests only name/iface length floors + funcs==metadata on **facet impl**, never loupe/`facetAddress` after registry deploy, never Target-derived control list, never systematic proxy smoke of full API.
- **Evidence:**
  - `MixedBufferMultiVaultStableDetfExchangeInFacet_IFacet_Test.t.sol` entire file
  - CS: only `RebasingDETFTokenFacet_IFacet_Test` / Pricing; no ExchangeIn/Out/Bonding IFacet
  - `rg facetAddress|IDiamondLoupe|controlFacetFuncs` under mixedBuffer → empty; under stable only Rebasing controls
- **Why bar fails:** J scored on **proxy**; declaration must not rubber-stamp incomplete Facet.
- **Recommended TEST:** `test_J1_facetFuncs_coversTargetApi`; `test_J2_proxyLoupe_allProductSelectors`; `test_J3_proxyCallable_smoke` (views + access-expected reverts). CS must cover **all three** product facets + companions.
- **Suggested WP:** WP-J-DETF-CS-MB-001
- **Priority:** High

### 5.8 [TCA-DETF-CS-008] High · TEST · MixedBuffer missing adversarial A–H P0 suite

- **Summary:** MixedBuffer has extensive happy/negative product tests and a reentrancy file, but **no** catalog-driven `adversarial/` (A1 donation, D2 claim, H2/H3, F2/F3, E4, etc.). Under A–K ship gate this is High for a money DETF.
- **Evidence:** `test/.../mixedBuffer/` listing — no adversarial dir; prior adversarial reports never claimed MB complete.
- **Recommended TEST:** Port MultiVault / CS adversarial patterns onto `TestBase_MixedBufferMultiVaultStableDetf`: A1–A3, D2/D3/D6, E1/E4/E5, F1–F3, H2/H3, plus existing C/G reuse. Match-path: `…/mixedBuffer/adversarial/**`.
- **Suggested WP:** WP-ADV-DETF-MB-001
- **Priority:** High — Wave 1–2

### 5.9 [TCA-DETF-CS-009] High · CODE+TEST · PAT-K-DONATE / K1 incomplete (both)

- **Summary:** CS A1 proves idle DAI donation does not auto-mint on pull path. Combined with CS-001/003, attacker converts donation → free detfToken/buffer via `pretransferred=true`. MB has no A1 and no K1.
- **Evidence:** CS A1; CODE PAT-I-ABS; missing I/K pretransfer tests both products.
- **Recommended CODE:** Fixed by CS-001 / MB-001.
- **Recommended TEST:** `test_K1_donateThenPretransferMint_noFreeCredit` (may alias I1).
- **Suggested WP:** fold into WP-I-DETF-CS-002 / WP-ADV-DETF-MB-001
- **Priority:** High

### 5.10 [TCA-DETF-CS-010] High · TEST · ComposedStable G nested gap + multi-leg residual incomplete as adversarial E2

- **Summary:** Focus bar: **G nested** exists for MixedBuffer only. ComposedStable has multi-route topology but **no** outer DETF with nested SE/DETF leg matrix (prior adversarial gap report §3 P1 G still open). Multi-leg residual: sequences assert free detf=0; exchangeOut unit tests residual vault-token leave (Mock harness); **no** production-graph multi-leg residual adversarial (E2) after failed partial unwind / multi-actor multi-route mint.
- **Evidence:** Nested only under mixedBuffer; CS sequences residual limited to free detfToken; adversarial NatSpec defers C multi-leg.
- **Recommended TEST:**
  - `test_G1_composedOuter_nestedSeDetf_outerActivityDoesNotBrickInner` (if product law supports nested composition on CS)
  - `test_E2_multiLeg_mintBurn_noStrandedVaultShareOrBptOnDiamond` on IntegratedDeploy
- **Suggested WP:** WP-G-E-DETF-CS-001
- **Priority:** High (G for CS; E residual production proof)

### 5.11 [TCA-DETF-CS-011] High · TEST · claim path adversarial incomplete (CS mature-ish; MB thin)

- **Summary:** CS claim lifecycle green on integrated + H2/D3 adversarial. Gaps: D6 formal principal cap; F3 onlyOwner claim mint/burn on production claim diamond; redeemClaim N/A on CS DETF (claim is rebasing). MB has single happy `test_sell_to_claim_and_redeem_buffer` — no fail-atomicity, double redeem, over-redeem, or unauthorized claim drain.
- **Evidence:** CS adversarial D3/H2; MB `Claim.t.sol` only.
- **Recommended TEST:** MB D2/D3/D6/H2; CS F3 on rebasing onlyOwner entrypoints via production proxy.
- **Suggested WP:** WP-CLAIM-DETF-CS-MB-001 (can merge into ADV WPs)
- **Priority:** High

### 5.12 [TCA-DETF-CS-012] Medium · THEATER · PAT-MOCK unit harnesses counted as money coverage risk

- **Summary:** `ComposedStableCommonDetfExchangeIn.t.sol` defines `MockStandardExchange` and drives mint routing against harness, not production diamond/registry. Bonding/Burn/Out unit suites use mock routers. These are useful for route selection math but **must not** be scored as H/A–K for SUT. Risk: implementors “fix” bugs only on mocks.
- **Evidence:** ExchangeIn.t.sol MockStandardExchange; BondingFacet.t.sol MockBondExchange; BurnExchangeIn / Out harnesses.
- **Recommended:** Label unit files as logic-only; require security regressions on IntegratedDeploy / adversarial only. Do not expand Mock SUT.
- **Suggested WP:** WP-THEATER-DETF-CS-001 (doc/process) + any new tests only on gold path
- **Priority:** Medium

### 5.13 [TCA-DETF-CS-013] Medium · TEST · bare expectRevert in CS adversarial + some MB paths

- **Summary:** CS adversarial uses bare `vm.expectRevert()` for deadline, redeem, minOut, F2. Weak N bar (can pass wrong failure mode).
- **Recommended TEST:** Typed selectors (`DeadlineExceeded`, `ZeroAmount`, `SlippageExceeded`, Ownable/IsLocked, etc.).
- **Suggested WP:** WP-N-DETF-CS-001
- **Priority:** Medium

### 5.14 [TCA-DETF-CS-014] Medium · TEST · C reentrancy deferred on ComposedStable

- **Summary:** Adversarial NatSpec defers C1–C3 multi-leg reentrancy as P2. DETF P0 includes C1–C3. MB has partial reentrancy — CS does not.
- **Recommended TEST:** Hostile token/router reenter mint/bond/redeem during multi-leg join; expect lock. May need production graph fixtures.
- **Suggested WP:** WP-C-DETF-CS-001
- **Priority:** Medium–High borderline; score **Medium** if reentrancy modifiers present statically on entrypoints (verify before Stage 2) — still **missing proof**.
- **Note:** Entry `exchangeIn` on CS ExchangeIn facet is **not** obviously `nonReentrant` in skimmed signature block (Out is `nonReentrant`); **confirm CODE** for C on mint/bond before downgrading.

### 5.15 [TCA-DETF-CS-015] Medium · TEST · L1/L3 property gap both products; L2 thin CS only

- **Summary:** Fuzz 2026-07 Wave 3A shipped CS L2 sequences only (3 tests). No L1 fuzz / L3 Handler for CS or MB. Prior “critical property gap” only partially closed.
- **Recommended TEST:** L1 conservation fuzz after I CODE; L3 handler mint/burn/bond/donate; MB L2 multi-op sequences reusing Nested/NLegs.
- **Suggested WP:** WP-L-DETF-CS-MB-001 (Wave 3)
- **Priority:** Medium

### 5.16 [TCA-DETF-CS-016] Medium · TEST · Preview ≡ execute incomplete (P)

- **Summary:** CS integrated mint checks `amountOut >= previewOut` once; MB threshold uses preview as minOut; no fee-inclusive / multi-route / burn preview≡execute matrix on production graph.
- **Recommended TEST:** `test_P_mint_previewEqualsExecution`; `test_P_burn_previewEqualsExecution` (and buffer/share routes on MB).
- **Suggested WP:** WP-P-DETF-CS-MB-001
- **Priority:** Medium

### 5.17 [TCA-DETF-CS-017] Low · TEST · PAT-THEATER-PRE on Rebasing burnShares

- **Summary:** `test_burnShares_pretransferred_burnsFromTokenBalance` first **transfers** claim tokens to diamond then burns with `pretransferred=true` — happy escrow path, not I1 false claim.
- **Fix:** Keep as happy path; add true I1 without transfer.
- **Suggested WP:** fold into WP-I-DETF-CS-002
- **Priority:** Low

### 5.18 [TCA-DETF-CS-018] Low · hygiene · brand naming residual

- **Summary:** IntegratedDeploy still uses `redeemRichir` test name / “richir” comments — DETF role naming law prefers `rebasingClaimToken`.
- **Suggested WP:** opportunistic rename when touching file
- **Priority:** Low

### 5.19 [TCA-DETF-CS-019] Info · baseline strengths

- **Summary:** CS production IntegratedDeploy + Threshold/Expansion/Compound matrix is high-quality hermetic H. MB Nested G1 + NLegs residual + bootstrap/liveness/routes are strong product coverage. CS adversarial A1/A2/D2/D3/E4/H2/H3/F1/F2 is a real (if incomplete) P0 start. Deploy paths respect manager registry (MB explicitly tests not-`new`).
- **Priority:** none

---

## 6. Theater list

| Test / control | Why theater / weak | Fix |
|----------------|--------------------|-----|
| CS ExchangeIn/Bonding/Burn/Out **Mock** harness money paths | MockStandardExchange / mock routers — not production SUT | Score only IntegratedDeploy + adversarial for security |
| MB `…_IFacet_Test` length floors | Not Target-derived; no proxy/loupe | J1–J3 rewrite |
| CS missing money-facet IFacet | Package metadata ≠ surface proof | Add Behavior_IFacet + J |
| `test_burnShares_pretransferred_*` | Happy transfer-then-burn; not I1 | Add false-claim I1 |
| CS adversarial bare `expectRevert` | Wrong-mode pass risk | Exact selectors |
| Implicit “A1 covers I/K” | A1 never sets `pretransferred=true` | Explicit I1/K1 |
| Counting unit residual on Mock Out as multi-leg residual security | Harness not diamond | Production E2 residual suite |

**Not theater:** CS IntegratedDeploy mint/bond/claim; CS adversarial A1/A2/E4/H2/H3 on production graph; MB Nested residual + Mint/Burn residual helpers on production diamond; MB reentrancy nested lock.

**No PAT-THEATER-PRE** on CS DETF exchange (no pretransfer happy tests).  
**PAT-THEATER-PRE** present on Rebasing burnShares only.

---

## 7. Prior-report diff

| Claim (doc) | Status now (2026-08-09) |
|-------------|-------------------------|
| ComposedStable adversarial **P0** (Wave 1B) “full” vs gap report critical gaps | **Partial only** — A1/A2/D2/D3/E4/E5/F1/F2/H2/H3 present; **C G**; **I/J/K G**; B thin; G nested **G** |
| ComposedStable multi-leg residual / failed path atomicity critical | **Partially closed** (H3 mint fail; sequences free detf; Out residual on harness) — **production multi-leg residual adversarial still weak** |
| ComposedStable claim H2-class | **Still true** (behavior + adversarial H2) |
| ComposedStable L2 sequences Wave 3A green | **Still true** (3 tests); **L1/L3 still G** |
| ComposedStable G nested (gap report P1) | **Still G** |
| MixedBuffer not listed as adversarial gold | **Still true** — no adversarial dir; product H/N mature |
| Fuzz report: ComposedStable L1/L3 G | **Still G** for L1/L3; L2 P |
| Pilot commons: CS + Rebasing PAT-I-ABS clones | **Confirmed** package-local Blockers CS-001/002; MB-003/004 same class |
| MultiVault gold I/J missing | **Same pattern** on CS/MB — clone of MV-001/002 free-credit |

---

## 8. Work package stubs

### WP-I-DETF-CS-001

| Field | Value |
|-------|--------|
| **WP-ID** | WP-I-DETF-CS-001 |
| **Title** | Fix ComposedStable + RebasingDETFToken pretransfer credit to balance-delta |
| **Severity** | Blocker |
| **Class** | CODE (+ minimal regression tests) |
| **Products** | ComposedStableCommonDetf; RebasingDETFToken |
| **Finding IDs** | TCA-DETF-CS-001, TCA-DETF-CS-002, TCA-DETF-CS-009 (CODE half) |
| **Problem** | Blind `return amount_` / exact-out `maxAmountIn` credit enables free mint/extract via donated inventory. |
| **Production files** | `ComposedStableCommonDetfCommon.sol`; `RebasingDETFTokenTarget.sol` (pull + exchangeOut + burnShares pretransfer) |
| **Test files** | temporary I1 under adversarial; full suite WP-I-DETF-CS-002 |
| **Out of scope** | MixedBuffer (WP-I-DETF-MB-001); BasicVaultCommon (commons area) |
| **Depends on** | optional Wave-0 shared pull API freeze (`WP-I-CLONE-001` / `WP-I-COMMON-001`) |
| **Parallelizable with** | WP-I-DETF-MB-001 if helper API agreed; WP-J-DETF-CS-MB-001 |
| **Suggested worktree** | `gap_cover_i-detf-cs` · branch `gap_cover/i-detf-cs` |
| **Implementation notes** | L-CLAIM-3; crane I patterns; no `via_ir`; DETF role names only |
| **Acceptance** | `forge test --match-path 'test/.../stable/common/**' --match-test 'test_I1_'` green; no free mint on donate+pretransfer |
| **Anti-theater** | I1 must not transfer for attacker; diamond may hold inventory ≥ amount |
| **Estimate** | M |

### WP-I-DETF-MB-001

| Field | Value |
|-------|--------|
| **WP-ID** | WP-I-DETF-MB-001 |
| **Title** | Fix MixedBuffer `_pullToken` + burn pretransfer to balance-delta |
| **Severity** | Blocker |
| **Class** | CODE |
| **Products** | MixedBufferMultiVaultStableDetf |
| **Finding IDs** | TCA-DETF-CS-003, TCA-DETF-CS-004 |
| **Problem** | Same PAT-I-ABS as MultiVault package-local pull/burn. |
| **Production files** | `MixedBufferMultiVaultStableDetfCommon.sol`; `MixedBufferMultiVaultStableDetfExchangeOutTarget.sol` |
| **Depends on** | same helper freeze as CS if shared |
| **Parallelizable with** | WP-I-DETF-CS-001 after API freeze |
| **Suggested worktree** | `gap_cover_i-detf-mb` |
| **Acceptance** | I1 mint/bond/burn free-credit setups fail enrichment |
| **Anti-theater** | no attacker transfer; donated buffer/share/detfToken present |
| **Estimate** | M |

### WP-I-DETF-CS-002

| Field | Value |
|-------|--------|
| **WP-ID** | WP-I-DETF-CS-002 |
| **Title** | ComposedStable + claim adversarial I1–I3 (+ K1) |
| **Severity** | High |
| **Class** | TEST |
| **Products** | ComposedStableCommonDetf; RebasingDETFToken |
| **Finding IDs** | TCA-DETF-CS-005, TCA-DETF-CS-009, TCA-DETF-CS-017 |
| **Depends on** | WP-I-DETF-CS-001 |
| **Test files** | extend `Adversarial_ComposedStable_P0.t.sol` or `Adversarial_TrustFlag.t.sol` |
| **Acceptance** | `test_I1_*`, `test_I2_*`, `test_I3_*` green on production graph |
| **Anti-theater** | I1 no transfer; I2 short; I3 second call without new funds |
| **Suggested worktree** | `gap_cover_i-detf-cs-tests` |
| **Estimate** | S–M |

### WP-ADV-DETF-MB-001

| Field | Value |
|-------|--------|
| **WP-ID** | WP-ADV-DETF-MB-001 |
| **Title** | MixedBuffer adversarial A–H P0 + I1–I3 + claim D/H |
| **Severity** | High |
| **Class** | TEST |
| **Products** | MixedBufferMultiVaultStableDetf |
| **Finding IDs** | TCA-DETF-CS-006, TCA-DETF-CS-008, TCA-DETF-CS-009, TCA-DETF-CS-011 |
| **Depends on** | WP-I-DETF-MB-001 for I cases |
| **Test files** | `test/.../mixedBuffer/adversarial/*.t.sol` (new) |
| **Acceptance** | Catalog-labeled tests for A1,A3,D2,D3,D6,E1,E5,F2,F3,H2,H3,I1–I3,K1; G1 already covered can link |
| **Suggested worktree** | `gap_cover_adv-detf-mb` |
| **Estimate** | M–L |

### WP-J-DETF-CS-MB-001

| Field | Value |
|-------|--------|
| **WP-ID** | WP-J-DETF-CS-MB-001 |
| **Title** | J1–J3 surface suite CS multi-facet + MB combined facet on proxy |
| **Severity** | High |
| **Class** | TEST (CODE only if PAT-J-OMIT found) |
| **Products** | ComposedStableCommonDetf (+ Bonding/Out facets); MixedBufferMultiVaultStableDetf; optionally Rebasing J2–J3 |
| **Finding IDs** | TCA-DETF-CS-007 |
| **Depends on** | none |
| **Parallelizable with** | CODE I WPs |
| **Acceptance** | `test_J1_*`, `test_J2_*`, `test_J3_*` green; loupe non-zero all product sels |
| **Suggested worktree** | `gap_cover_j-detf-cs-mb` |
| **Estimate** | M |

### WP-G-E-DETF-CS-001

| Field | Value |
|-------|--------|
| **WP-ID** | WP-G-E-DETF-CS-001 |
| **Title** | ComposedStable nested G1 (if product-supported) + production multi-leg residual E2 |
| **Severity** | High |
| **Class** | TEST |
| **Finding IDs** | TCA-DETF-CS-010 |
| **Depends on** | none for residual; nested may need product-law confirm |
| **Acceptance** | production-graph residual asserts on free vaultShare/BPT/pairToken dust after multi-route ops; G1 if applicable |
| **Suggested worktree** | `gap_cover_g-e-detf-cs` |
| **Estimate** | M |

### WP-C-DETF-CS-001 / WP-N-DETF-CS-001 / WP-P-DETF-CS-MB-001 / WP-L-DETF-CS-MB-001

| WP-ID | Severity | Class | Finding IDs | One-line |
|-------|----------|-------|-------------|----------|
| WP-C-DETF-CS-001 | Medium | TEST (+CODE if missing lock) | TCA-DETF-CS-014 | CS multi-leg reentrancy C1–C3 proof |
| WP-N-DETF-CS-001 | Medium | TEST | TCA-DETF-CS-013 | Exact selectors on adversarial bare reverts |
| WP-P-DETF-CS-MB-001 | Medium | TEST | TCA-DETF-CS-016 | Preview≡execute matrix production graph |
| WP-L-DETF-CS-MB-001 | Medium | TEST | TCA-DETF-CS-015 | L1 fuzz + L3 handlers Wave 3 |

---

## 9. Deferred / N/A / NEEDS_OWNER

| Item | Class | Reason |
|------|-------|--------|
| CS C1–C3 historically deferred P2 | **DEFER** → **elevate** | PRD DETF P0 includes C; track as TCA-DETF-CS-014 Medium/High |
| A4–A5 FoT / dust grief | **DEFER** | P2; multi-leg dust after E2 production residual |
| B route grief “most liquid” | **DEFER** / Medium later | Unit mock covers selection; adversarial B optional |
| Nested G1 on ComposedStable if product law forbids outer CS over nested DETF | **NEEDS_OWNER** | Confirm whether CS composition supports nested DETF share legs like MB; if no, mark G N/A with product-law cite |
| Shared `_pullToken` vs package-local fix order | **NEEDS_OWNER** / orchestrator | Align with Wave-0 commons clone DAG |
| Rebasing `burnShares` onlyOwner free-burn severity | **DEFER** external attacker | Still CODE-wrong inventory attribution for privileged caller |
| Mock unit harness retention | **DEFER** rewrite | Keep for route math; do not expand as security |

---

## 10. Commands run

```bash
# Inventory (workspace-relative under lib/indexedex)
ls contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/
ls contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/
ls test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/stable/common/
ls test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/

# Trust-flag / surface / catalog signals
rg -n 'pretransferred|_pullToken|_secureTokenTransfer|function facetFuncs' \
  contracts/vaults/detf/protocols/dexes/balancer/v3/stable \
  contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer

rg -n 'function test_|function testFuzz_|function invariant_|test_I[0-9]|test_A[0-9]|test_J[0-9]|adversarial|pretransferred|MockStandardExchange|controlFacetFuncs|facetAddress' \
  test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/stable \
  test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer

# Static PAT-I-ABS epicenters (confirmed by read_file)
# ComposedStableCommonDetfCommon.sol:297-300
# RebasingDETFTokenTarget.sol:205-210, 409-411
# MixedBufferMultiVaultStableDetfCommon.sol:510-511
# MixedBufferMultiVaultStableDetfExchangeOutTarget.sol:42-47
```

**Not run this pass:** `forge test` runtime proofs for free-mint (Blockers left **RUNTIME_UNPROVEN**; static early-return is overwhelming). Orchestrator may add `docs/testing/coverage-audit/repro/TCA-DETF-CS-001/` later.

---

## Return status (orchestrator)

| Field | Value |
|-------|--------|
| **Status** | **COMPLETE** |
| **Blockers** | TCA-DETF-CS-001, 002, 003, 004 (all CODE · PAT-I-ABS · RUNTIME_UNPROVEN) |
| **High** | TCA-DETF-CS-005 … 011 |
| **Top WPs** | WP-I-DETF-CS-001 · WP-I-DETF-MB-001 · WP-I-DETF-CS-002 · WP-ADV-DETF-MB-001 · WP-J-DETF-CS-MB-001 |
| **Focus coverage note** | Multi-leg residual: **P** (MB strong happy residual + Nested/NLegs; CS sequences + partial Out); Claim: **P** (CS good H/H2; MB happy-only); G nested: **F** on MB, **G** on CS; I/J/K: **fail** both money products; PAT-I-ABS in `ComposedStableCommonDetfCommon` **confirmed** (+ Rebasing + MB clones) |
