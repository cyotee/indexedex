# Test Coverage Audit — T-detf-multi-vault

| Field | Value |
|-------|--------|
| Date | 2026-08-09 |
| Agent / run | Stage 1 area subagent · pilot · T-detf-multi-vault |
| Status | **COMPLETE** |
| Production paths | `contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/**` |
| Test paths | `test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/**` (incl. `adversarial/`, `fuzz/`, `invariant/`) |
| Skills / PRD version cited | `TEST_COVERAGE_AUDIT_PRD` §2,2.4,3.8,5,6,7.2,8,19; crane-adversarial-testing A–K + `implementation-test-dod.md`; crane-testing LR-7; gold suite = this adversarial tree |
| Prior seed | `docs/testing/ADVERSARIAL_VAULT_COVERAGE_GAP_REPORT.md` (MultiVault P0/P1 A–H complete); `FUZZ_INVARIANT_COVERAGE_GAP_REPORT.md` (L1/L3 later filled) |

---

## 1. Executive summary

### Maturity (0–5)

| Product | Maturity | Worst open severity | One-line |
|---------|----------|---------------------|----------|
| **MultiVaultWeightedDetf** | **3** | **Blocker** (CODE, RUNTIME_UNPROVEN) | Gold A–H + H/N/P + L1/L3; **I missing**; package-local **PAT-I-ABS** on `_pullToken` / burn pretransfer; **J** formal suite missing (declaration theater) |

Prior 2026-07 claim “P0/P1 complete / no blocking gap” is **stale under A–K**: A–H P0 remains **F**, but **I/J/K** ship-gate is not met, and production trust-flag accounting is wrong.

### Severity counts (this area)

| Severity | Count | IDs |
|----------|-------|-----|
| **Blocker** | **2** | TCA-DETF-MV-001, TCA-DETF-MV-002 |
| **High** | **3** | TCA-DETF-MV-003, TCA-DETF-MV-004, TCA-DETF-MV-005 |
| Medium | 3 | TCA-DETF-MV-006 … 008 |
| Low / Info | 2 | TCA-DETF-MV-009, TCA-DETF-MV-010 |

### Top 5 recommended WPs

1. **WP-I-DETF-MV-001** — CODE: delta-safe `_pullToken` + burn pretransfer (Blocker)
2. **WP-I-DETF-MV-002** — TEST: I1–I3 (+ bond pretransfer I1) (High; depends on 001)
3. **WP-J-DETF-MV-001** — TEST: J1–J3 Target-derived controls + loupe + **proxy** smoke (High)
4. **WP-K-DETF-MV-001** — TEST: K1 donation→`pretransferred=true` mis-credit (High; couples to I)
5. **WP-N-DETF-MV-001** — TEST: exact selectors on bare `expectRevert` adversarial paths (Medium)

**Do not rewrite** the gold A–H suite; extend with I/J/K + fix CODE.

---

## 2. Product inventory

### 2.1 Production package

| Product | DFPkg / key Targets | Facets | TestBase | Test roots | Deploy path quality |
|---------|---------------------|--------|----------|------------|---------------------|
| **MultiVaultWeightedDetf** | `MultiVaultWeightedDetfDFPkg.sol`; Targets: ExchangeIn, ExchangeOut, ExchangeQuery, Bonding, Info; Common+Repo | `MultiVaultWeightedDetfExchangeInFacet` (combined query/bond/info + exchangeIn via inheritance); DFPkg also cuts ERC20 / ERC2612 / ERC5267 / MultiAsset Basic+Standard vault facets | `TestBase_MultiVaultWeightedDetf.sol` (co-located production path) | Hermetic matrix under `test/.../multi-vault-weighted/`; adversarial/; fuzz/; invariant/ | **Gold**: CREATE3 Facet/Pkg factories + `indexedexManager.deployVault` / registry `deployPkg`; SE legs via Aerodrome production SE packages. **Never** `new` production facets on user path (IFacet unit test uses `new` for declaration-only — see theater). |

### 2.2 Production file inventory (package root)

| Path | Role |
|------|------|
| `MultiVaultWeightedDetfDFPkg.sol` | DFPkg, facetCuts, processArgs registry gate |
| `MultiVaultWeightedDetfExchangeInFacet.sol` | Combined IFacet + facetFuncs (33 selectors) |
| `MultiVaultWeightedDetfExchangeInTarget.sol` | `exchangeIn` mint/burn exact-in |
| `MultiVaultWeightedDetfExchangeOutTarget.sol` | `_burnDetfExactIn` (+ pretransfer branch) |
| `MultiVaultWeightedDetfExchangeQueryTarget.sol` | previewExchangeIn/Out; exchangeOut always InvalidRoute |
| `MultiVaultWeightedDetfBondingTarget.sol` | bond, initializeReserve, sell*, redeemClaim |
| `MultiVaultWeightedDetfInfoTarget.sol` | views + compoundProtocolRewards |
| `MultiVaultWeightedDetfCommon.sol` | accounting, **`_pullToken`**, compound atomic |
| `MultiVaultWeightedDetfRepo.sol` | storage + errors |
| `*_FactoryService.sol` (Component/Facet/Pkg) | CREATE3 deploy helpers |
| `TestBase_MultiVaultWeightedDetf.sol` | gold TestBase |

### 2.3 Trust-flag entrypoints (I-applicable)

| Entrypoint | Signature / flag | Credit path |
|------------|------------------|-------------|
| `exchangeIn` | `bool pretransferred_` | Mint: `_pullToken`; Burn: skip transfer if true, burn from diamond |
| `bond` | `bool pretransferred_` | `_pullToken` for BPT or vaultShare |
| `exchangeOut` | `bool pretransferred_` | Always reverts `InvalidRoute` (N/A money path) |
| `previewExchangeIn` | ignores flag | view only |

### 2.4 Facet surface (J static skim)

`MultiVaultWeightedDetfExchangeInFacet.facetFuncs()` lists 33 selectors: `exchangeIn`, `previewExchangeIn`, `previewExchangeOut`, `exchangeOut`, bonding suite, info suite, `compoundProtocolRewards`, `compoundProtocolRewardsAtomic`.

**Static J1 impression:** product Target API appears **included** in facetFuncs (no obvious money-API omission on the combined facet). **Not proven** by Target-diff test or proxy loupe (J1–J3 **G** as formal suite).

### 2.5 Hermetic / property / adversarial test roots

| Root | Role | Count (approx.) |
|------|------|-----------------|
| `MultiVaultWeightedDetf_*.t.sol` (package dir) | Deploy, mint/burn, bond, claim, threshold, multi-leg, nested, expansion, compound, fee, reentrancy, N-range, price shift, IFacet | Broad H/N matrix |
| `adversarial/` | Catalog A–H (P0/P1) | **~30** `test_*` across 9 files + adversarial TestBase |
| `fuzz/` | L1 property fuzz | 4 `testFuzz_*` |
| `invariant/` | L3 Handler + invariants | 5 `invariant_*`; handler mint/burn/donate |

---

## 3. Layer matrix

Legend: **F** full · **P** partial · **G** gap · **N/A** · **S** stub/theater

| Product | H | N | D | J | I | K | A–H | P | L1 | L2 | L3 | Maturity | Notes |
|---------|---|---|---|---|---|---|-----|---|----|----|----|----------|-------|
| MultiVaultWeightedDetf | **F** | **P**→**F**\* | **S**/**P** | **P**/**G**† | **G** | **P**‡ | **F** (P0/P1) | **F** | **P**/**F** | **G**/**P** | **P** | **3** | Gold A–H; I/J ship-gate fail; CODE free-credit |

\* Exact selectors strong on E5/routes; several adversarial paths still bare `expectRevert()`.  
† Production selectors look complete; **no** J1–J3 tests; proxy heavily exercised by H only.  
‡ A1 proves idle donation not joined on pull-path mint; **pretransfer** donation credit untested and CODE-broken.

### Layer evidence (summary)

| Layer | Evidence |
|-------|----------|
| **H** | Deploy, Liveness, MintBurn, Bonding, Claim, MultiLeg, Nested, ThresholdMode, NaturalExpansion, ProtocolCompound, FeeNonDilution, NRange, PriceShift — all production TestBase |
| **N** | Guards (zero/deadline/route/preLive/threshold); Claim without inventory; Bonding lock clamp; Deploy invalid weights |
| **D** | `MultiVaultWeightedDetfExchangeInFacet_IFacet_Test.t.sol` — **nonEmpty only** (theater for J control) |
| **J** | No loupe / no Target-derived controlFacetFuncs / no catalog J1–J3; proxy used throughout H |
| **I** | **Zero** `test_I1_` / `test_I2_` / `test_I3_`; all live exchangeIn use `pretransferred=false` |
| **K** | A1 victim mint vs idle donation (pull path); no K1 for `pretransferred=true` |
| **A–H** | See §4 catalog matrix — P0 complete, P2 deferred in NatSpec |
| **P** | `test_mint_previewEqualsExecution`, `test_burn_previewEqualsExecution` |
| **L1** | `MultiVaultWeightedDetf_Fuzz.t.sol` (conservation, non-dilution, tiny, multi-actor) |
| **L2** | No dedicated sequence-invariant file (L3 partially substitutes) |
| **L3** | `MultiVaultWeightedDetf.invariant.t.sol` + Handler (mint/burn/donate; residual/ghosts/live) |

---

## 4. Catalog matrix (A–K)

| ID | Score | Evidence (test name) or G |
|----|-------|---------------------------|
| **A1** | **F** | `Adversarial_Donation.test_A1_donateVaultShares_cannotMintFreeDetf` |
| **A2** | **F** | `test_A2_donateDetfToDiamond_noTheft` |
| **A3** | **F** | `test_A3_donateBpt_cannotRedeemOthersPrincipal` |
| A4–A5 | **DEFER** (P2) | NatSpec in Adversarial_Donation |
| **B1** | **F** | `test_B1_skewMintReverseBurn_seigniorageBounds`, `test_B1b_defaultThresholds_cannotMintAndBurnSameRegime` |
| B2 | **DEFER** (P2) | NatSpec Adversarial_PriceManipulation |
| **B3** | **F** | `test_B3_thresholdGates_blockMintWhenNotAllowed` |
| **C1** | **F** | `test_C1_reenterInitializeReserve_hitsIsLocked` |
| **C2** | **F** | `test_C2_reenterRedeemClaim_duringMint_hitsIsLocked` |
| **C3** | **F** | `test_C3_mintReenterBond_hitsIsLocked` |
| C4–C5 | **DEFER** (P2) | NatSpec Adversarial_Reentrancy |
| **D2** | **F** | `test_D2_redeemClaim_withoutClaim_noBptDrain` |
| **D3** | **F** | `test_D3_doubleRedeem_secondReverts` |
| D4 | **F** (P1+) | `test_D4_redeem_junkRateAsset_InvalidRoute` |
| D5 | **F** (P1+) | `test_D5_lockClamp_minRevert_maxOk` |
| **D6** | **F** | `test_D6_cannotRedeemMoreThanClaimPrincipal` |
| D7 | **DEFER** (P2) | NatSpec Adversarial_BondClaim |
| **E1** | **F** | `test_E1_mintThenPartialBurn_conservation` |
| E2 | **DEFER** (P2) | residual covered partially in MultiLeg/FeeNonDilution |
| **E4** | **F** | `test_E4_holderBalance_notDilutedByOthersMint` |
| **E5** | **F** | `test_E5_zeroAmount_reverts`, `test_E5_expiredDeadline_reverts` |
| **F1** | **F** | `test_F1_noOwnerOnInstance` |
| **F2** | **F** | `test_F2_bondNftVault_onlyOwner` |
| **F3** | **F** | `test_F3_claim_mintFromNFTSale_onlyOwner`, `test_F3_claim_burnShares_onlyOwner` |
| **F4** | **F** | `test_F4_weightsImmutable_afterOps` |
| **G1** | **F** | `test_G1_outerActivity_doesNotBrickInner` |
| G2–G3 | **DEFER** (P2) | NatSpec Adversarial_Nested |
| H1 | **DEFER** (P2) | NRange N=7 live path partial substitute |
| **H2** | **F** | `test_H2_redeemClaim_revert_claimUnchanged`, `test_H2_fullRedeem_atomic` |
| **H3** | **F** | `test_H3_minOutTooHigh_leavesNoInventory` (+ residual asserts in Guards) |
| **I1** | **G** | no test; happy-path pretransfer also absent (not THEATER-PRE — pure gap) |
| **I2** | **G** | no test |
| **I3** | **G** | no test |
| I4 | **G** / **DEFER** | FoT not exercised on MultiVault legs (SE shares typically not FoT) |
| **J1** | **G** | no Target↔facetFuncs diff test; IFacet control not Target-derived |
| **J2** | **G** | no `facetAddress(sel)` loupe after DFPkg deploy |
| **J3** | **P**/**G** | money paths called on **proxy** in H/adversarial; **no** systematic J3 catalog / full API smoke |
| **K1** | **P** | A1 covers pull-path non-credit of idle donation; **G** for donation + `pretransferred=true` (CODE path credits claim) |

**P0 DETF subset (PRD §2.3):** A1,A3,B1,B3,C1–C3,D2,D3,D6,E1,E5,F2–F3,H2,H3 = **F**; **I1–I3 = G**; **J1–J3 = G/P**; **K1 = P**.

---

## 5. Findings

### 5.1 [TCA-DETF-MV-001] Blocker · CODE · PAT-I-ABS (mint / bond pull)

- **Summary:** `_pullToken(..., pretransferred_=true)` returns the **caller-claimed** `amount_` with **no** balance check and **no** inbound delta. Mint and bond credit free vaultShare/BPT principal against any inventory already on the diamond (or invent credit with zero inventory if join tolerates — primary exploit is credit against donated inventory).
- **Evidence:**
  - `MultiVaultWeightedDetfCommon.sol` ~442–447: `if (pretransferred_) return amount_;`
  - Mint call site: `MultiVaultWeightedDetfExchangeInTarget.sol` ~52: `vaultShares_ = _pullToken(...)`
  - Bond call sites: `MultiVaultWeightedDetfBondingTarget.sol` ~127, ~137
- **Why bar fails:** Ship gate I + accounting primitives: credit must be observed delta, never claim alone (`implementation-test-dod.md` §2).
- **Recommended CODE:** Measure `balBefore` always; if pretransferred, require `balAfter - balBefore >= amount_` **or** credit only delta (product law L-CLAIM-3 / secure pull). Prefer shared DETF/common helper if Wave-0 commons WP lands; else package-local fix first.
- **Recommended TEST:** `test_I1_pretransferred_true_noTransfer_existingVaultShareInventory_noFreeMint` — donate vaultShare, call exchangeIn with `pretransferred=true` without approving/sending; assert attacker detfToken balance unchanged and revert or zero credit. Match-path: `.../multi-vault-weighted/adversarial/**`.
- **Suggested WP:** WP-I-DETF-MV-001
- **Priority:** Wave 0/1 — Blocker
- **Runtime:** **RUNTIME_UNPROVEN** this run; static evidence overwhelming (literal `return amount_`). Repro notes: `docs/testing/coverage-audit/repro/TCA-DETF-MV-001/notes.md`. Stage 2 must forge-prove I1 before marking CODE closed.

### 5.2 [TCA-DETF-MV-002] Blocker · CODE · PAT-I-ABS (burn pretransfer)

- **Summary:** `_burnDetfExactIn` with `pretransferred_=true` **skips** `transferFrom` then burns `detfIn_` from `address(this)` and pays vault shares. Free detfToken inventory on the diamond (donation A2 pattern) becomes **free extract** of vaultShare without the attacker transferring detfToken.
- **Evidence:** `MultiVaultWeightedDetfExchangeOutTarget.sol` ~40–45, then exit/payout.
- **Why bar fails:** Same trust-flag free principal class; A2 only proves pull-path burn does not spend diamond free detfToken.
- **Recommended CODE:** Always require measured inbound detfToken to diamond **or** burn from `msg.sender` balance with transfer; never burn diamond inventory attributed to a claimed pretransfer without delta proof.
- **Recommended TEST:** `test_I1_burn_pretransferred_true_usesOnlyCallerTransferredDetf` — donate detfToken to diamond; attacker with 0 detfToken calls exchangeIn(detf→share, pretransferred=true); expect revert; diamond vaultShare/BPT unchanged.
- **Suggested WP:** WP-I-DETF-MV-001 (same CODE touch set)
- **Priority:** Wave 0/1 — Blocker
- **Runtime:** RUNTIME_UNPROVEN (paired with 001)

### 5.3 [TCA-DETF-MV-003] High · TEST · catalog I1–I3

- **Summary:** No I1/I2/I3 adversarial (or hermetic) tests. Catalog P0 incomplete for DETF class. Not theater-pretransfer (no happy-only pretransfer either — total absence).
- **Evidence:** `rg 'test_I[123]_|pretransferred.*true' test/.../multi-vault-weighted` → no I-suite; all exchangeIn call sites use `false`.
- **Why bar fails:** PRD §2.3 DETF P0 requires I1–I3 when flag exists.
- **Recommended TEST:**
  - `test_I1_claimPretransfer_noTransfer_existingReserves_noFreeMint`
  - `test_I2_shortPretransfer_revertsExact`
  - `test_I3_residualReuse_secondCall_noFreeMint`
  - Bond variants: `test_I1_bond_pretransferred_...`
  - Pass criteria: attacker balances; exact selectors; residual inventory helpers from adversarial TestBase
- **Suggested WP:** WP-I-DETF-MV-002 (depends on WP-I-DETF-MV-001 CODE)
- **Priority:** High — Wave 1

### 5.4 [TCA-DETF-MV-004] High · TEST + THEATER · PAT-THEATER-FACET / J1–J3

- **Summary:** Only declaration test is `test_facetMetadata_nonEmpty` on **`new MultiVaultWeightedDetfExchangeInFacet()`** — length floors only; controls not Target-derived; **no** loupe after registry deploy; **no** J3 full API catalog (though happy paths exercise core money selectors on proxy).
- **Evidence:**
  - `MultiVaultWeightedDetfExchangeInFacet_IFacet_Test.t.sol` entire file
  - `rg facetAddress|IDiamondLoupe|controlFacetFuncs` under multi-vault-weighted tests → empty
- **Why bar fails:** J scored on **proxy**; declaration must not rubber-stamp incomplete Facet.
- **Recommended CODE:** Only if J1 static diff finds omission (none confirmed this pass); otherwise TEST-only.
- **Recommended TEST:**
  - `test_J1_facetFuncs_coversTargetApi` — control list from `IStandardExchangeIn` + `IMultiVaultWeightedDetfBonding` + `IMultiVaultWeightedDetfInfo` (+ atomic compound)
  - `test_J2_proxyLoupe_allProductSelectors`
  - `test_J3_proxyCallable_smoke_eachSelector` (views + access-expected reverts)
- **Suggested WP:** WP-J-DETF-MV-001
- **Priority:** High — Wave 1

### 5.5 [TCA-DETF-MV-005] High · CODE+TEST · PAT-K-DONATE / K1 incomplete

- **Summary:** A1 correctly shows idle vaultShare donation is **not** joined on victim mint with pull path. Combined with 001, attacker can convert **donation into free detfToken** via `pretransferred=true` — classic K1/I hybrid. No dedicated K1 pretransfer case.
- **Evidence:** A1; `_pullToken` CODE; missing I/K pretransfer tests.
- **Recommended CODE:** Fixed by 001.
- **Recommended TEST:** `test_K1_donateVaultShares_thenPretransferMint_noFreeCredit` (may alias I1).
- **Suggested WP:** WP-K-DETF-MV-001 (can merge into WP-I-DETF-MV-002)
- **Priority:** High

### 5.6 [TCA-DETF-MV-006] Medium · THEATER / TEST · bare expectRevert

- **Summary:** Several adversarial negatives use bare `vm.expectRevert()` without exact selector (D2, D3, A2, A3, H3 minOut, preLive, F2/F3 access). State asserts often present — not pure theater, but weak N bar.
- **Evidence:** Adversarial_Donation, BondClaim, Guards, Access, Griefing (grep expectRevert).
- **Recommended TEST:** Tighten to typed selectors where known (`ZeroAmount`, `DeadlineExpired`, `InvalidRoute`, `IsLocked`, Ownable/authority errors).
- **Suggested WP:** WP-N-DETF-MV-001
- **Priority:** Medium

### 5.7 [TCA-DETF-MV-007] Medium · DEFER · P2 catalog residual

- **Summary:** A4–A5, B2, C4–C5, D7, E2, G2–G3, H1 deferred with NatSpec reasons; prior report correctly marked MultiVault P2 optional.
- **Recommended:** Keep DEFER until post-I/J wave; do not block ship of I/J CODE.
- **Suggested WP:** none (or WP-P2-DETF-MV-OPTIONAL later)
- **Priority:** Medium / opportunistic

### 5.8 [TCA-DETF-MV-008] Medium · TEST · L2 thin; L3 limited surface

- **Summary:** L1 fuzz + L3 Handler exist (closes 2026-07 fuzz critical gap claim). L3 surface is mint/burn/donate only (no bond/claim/redeem/pretransfer); depth/runs modest (depth 10, runs 24). L2 sequence suite absent.
- **Evidence:** `fuzz/MultiVaultWeightedDetf_Fuzz.t.sol`; `invariant/MultiVaultWeightedDetf.invariant.t.sol` + Handler.
- **Recommended TEST:** Expand Handler selectors (bond, redeemClaim, donate detfToken, pretransfer attack ops after CODE fix); optional L2 multi-op sequences.
- **Suggested WP:** WP-L3-DETF-MV-001 (Wave 3)
- **Priority:** Medium

### 5.9 [TCA-DETF-MV-009] Info · already covered baseline

- **Summary:** A–H P0/P1 adversarial suite is still the monorepo gold standard. Production-first TestBase path is exemplary (registry + CREATE3 + real SE). Preview≡execute green. Reentrancy C1–C3 strong with exact `IsLocked`.
- **Priority:** none

### 5.10 [TCA-DETF-MV-010] Low · TEST · exchangeOut dead route surface

- **Summary:** `exchangeOut` / `previewExchangeOut` always InvalidRoute but remain on facet surface. J3 should smoke-call and expect exact InvalidRoute (documents intentional stub).
- **Suggested WP:** fold into WP-J-DETF-MV-001
- **Priority:** Low

---

## 6. Theater list

| Test / control | Why theater / weak | Fix |
|----------------|--------------------|-----|
| `MultiVaultWeightedDetfExchangeInFacet_IFacet_Test.test_facetMetadata_nonEmpty` | `new` facet; length floors only; not Target-derived; never deploys DFPkg/proxy | Replace with Behavior_IFacet + Target controls + J2/J3 on proxy |
| Implicit “I covered by A1” (prior culture) | A1 does not call `pretransferred=true`; happy donation ≠ trust-flag proof | Add I1–I3; never count A1 as I |
| Bare `expectRevert` on D2/D3/F2/F3/H3/preLive | Can pass on wrong failure mode | Exact selectors |
| L3 residual when donate ghost > 0 | Intentionally relaxes share residual after donate — OK if documented; do not claim full residual hard invariant under donate | Keep; add I/K-specific residual asserts in L0 |

**Not theater:** A1–A3, C1–C3 (exact IsLocked), E5 exact selectors, production proxy mint/burn matrix.

**No PAT-THEATER-PRE** found (no pretransfer happy-path tests at all).

**No PAT-MOCK SUT** on MultiVault money paths (Aerodrome SE real packages via TestBase).

---

## 7. Prior-report diff

| Claim (doc) | Status now (2026-08-09) |
|-------------|-------------------------|
| MultiVault adversarial P0/P1 **complete** (A–H) | **Still true** for A–H P0/P1 |
| MultiVault **no blocking gap** | **Stale** — I/J P0 missing; **CODE** PAT-I-ABS Blocker on package `_pullToken` / burn |
| Catalog matrix MultiVault A–H = **F** | **Still F** for listed P0 rows |
| I/J/K columns (not in 2026-07 A–H report) | **New** — I=G, J=G/P, K=P |
| MultiVault L1/L3 **G** (fuzz report initial) | **Closed** — fuzz/ + invariant/ present (changelog Wave 1A) |
| MultiVault P2 optional residual | **Still deferred** (NatSpec) — non-blocking |
| Gold standard for peer ports | **Still** gold for A–H methodology; **not** gold for I/J until fixed |

---

## 8. Work package stubs

### WP-I-DETF-MV-001

| Field | Value |
|-------|--------|
| **WP-ID** | WP-I-DETF-MV-001 |
| **Title** | Fix MultiVault pretransfer credit to balance-delta (mint/bond/burn) |
| **Severity** | Blocker |
| **Class** | CODE (+ minimal regression tests) |
| **Products** | MultiVaultWeightedDetf |
| **Finding IDs** | TCA-DETF-MV-001, TCA-DETF-MV-002, TCA-DETF-MV-005 (CODE half) |
| **Problem** | `pretransferred=true` trusts claimed amounts: mint/bond via `_pullToken` return claim; burn burns diamond inventory without inbound proof. Free mint / free extract. |
| **Production files** | `MultiVaultWeightedDetfCommon.sol` (`_pullToken`); `MultiVaultWeightedDetfExchangeOutTarget.sol` (`_burnDetfExactIn`); possibly Bonding if bond-only edge |
| **Test files** | temporary proof under adversarial or mint/burn; full I suite in WP-I-DETF-MV-002 |
| **Out of scope** | Peer DETFs (Single SE, ComposedStable) — separate WPs; BasicVaultCommon (owned by T-basic-protocol-commons) |
| **Depends on** | none (or align with Wave-0 shared pull if orchestrator serializes) |
| **Parallelizable with** | WP-J-DETF-MV-001 |
| **Suggested worktree** | `gap_cover_i-detf-mv` · branch `gap_cover/i-detf-mv` |
| **Implementation notes** | Match ERC4626-style delta / L-CLAIM-3; crane-adversarial I patterns; do not use `via_ir` |
| **Acceptance** | `forge test --match-path 'test/.../multi-vault-weighted/**' --match-test 'test_I1_'` green; free-mint setup fails attacker enrichment; residual asserts |
| **Anti-theater** | I1 must **not** transfer tokens for the attacker; diamond may already hold inventory ≥ amount |
| **Estimate** | M |

### WP-I-DETF-MV-002

| Field | Value |
|-------|--------|
| **WP-ID** | WP-I-DETF-MV-002 |
| **Title** | Add MultiVault adversarial I1–I3 (+ bond pretransfer) |
| **Severity** | High |
| **Class** | TEST |
| **Products** | MultiVaultWeightedDetf |
| **Finding IDs** | TCA-DETF-MV-003, TCA-DETF-MV-005 |
| **Problem** | Catalog I P0 absent; K1 pretransfer unproven. |
| **Production files** | none (after 001) |
| **Test files** | `test/.../multi-vault-weighted/adversarial/Adversarial_TrustFlag.t.sol` (new) or extend Guards/Donation |
| **Out of scope** | Facet declaration rewrite (WP-J); P2 catalog |
| **Depends on** | WP-I-DETF-MV-001 |
| **Parallelizable with** | WP-N-DETF-MV-001 after 001 lands |
| **Suggested worktree** | `gap_cover_i-detf-mv-tests` (or same as 001) |
| **Implementation notes** | Copy MultiVault adversarial TestBase; mirror crane I1–I3; exact selectors |
| **Acceptance** | `forge test --match-path '.../adversarial/**' --match-test 'test_I'` green; names `test_I1_*`, `test_I2_*`, `test_I3_*` |
| **Anti-theater** | I1 no transfer; I2 short transfer; I3 second call without new funds |
| **Estimate** | S–M |

### WP-J-DETF-MV-001

| Field | Value |
|-------|--------|
| **WP-ID** | WP-J-DETF-MV-001 |
| **Title** | MultiVault J1–J3 surface suite on production proxy |
| **Severity** | High |
| **Class** | TEST (CODE only if omit found) |
| **Products** | MultiVaultWeightedDetf |
| **Finding IDs** | TCA-DETF-MV-004, TCA-DETF-MV-010 |
| **Problem** | Declaration theater; no loupe/proxy catalog proof. |
| **Production files** | only if PAT-J-OMIT confirmed |
| **Test files** | replace/extend `MultiVaultWeightedDetfExchangeInFacet_IFacet_Test.t.sol`; add `Adversarial_Surface.t.sol` or Behavior under multi-vault-weighted |
| **Out of scope** | A–H rewrite; I suite |
| **Depends on** | none |
| **Parallelizable with** | WP-I-DETF-MV-001 |
| **Suggested worktree** | `gap_cover_j-detf-mv` |
| **Implementation notes** | Controls from Target/interfaces; J3 calls **proxy** after `indexedexManager.deployVault` |
| **Acceptance** | `test_J1_*`, `test_J2_*`, `test_J3_*` green; loupe non-zero all product sels |
| **Anti-theater** | Never assert only on facet implementation address for J2/J3 |
| **Estimate** | S–M |

### WP-K-DETF-MV-001

| Field | Value |
|-------|--------|
| **WP-ID** | WP-K-DETF-MV-001 |
| **Title** | K1 donation + pretransfer credit regression |
| **Severity** | High |
| **Class** | TEST |
| **Products** | MultiVaultWeightedDetf |
| **Finding IDs** | TCA-DETF-MV-005 |
| **Problem** | K1 incomplete once I path considered. |
| **Test files** | may live inside Adversarial_TrustFlag / Donation |
| **Depends on** | WP-I-DETF-MV-001 |
| **Parallelizable with** | WP-I-DETF-MV-002 (merge preferred) |
| **Suggested worktree** | merge with `gap_cover_i-detf-mv-tests` |
| **Acceptance** | `test_K1_*` or documented alias of I1 with donate setup |
| **Anti-theater** | Must use `pretransferred=true` after donate |
| **Estimate** | S |

### WP-N-DETF-MV-001

| Field | Value |
|-------|--------|
| **WP-ID** | WP-N-DETF-MV-001 |
| **Title** | Exact selectors on MultiVault adversarial bare reverts |
| **Severity** | Medium |
| **Class** | TEST |
| **Finding IDs** | TCA-DETF-MV-006 |
| **Depends on** | none |
| **Parallelizable with** | WP-J-DETF-MV-001 |
| **Suggested worktree** | `gap_cover_n-detf-mv` |
| **Acceptance** | no bare `expectRevert()` on P0 adversarial without NatSpec reason |
| **Estimate** | S |

### WP-L3-DETF-MV-001

| Field | Value |
|-------|--------|
| **WP-ID** | WP-L3-DETF-MV-001 |
| **Title** | Expand MultiVault Handler (bond/claim/pretransfer) |
| **Severity** | Medium |
| **Class** | TEST |
| **Finding IDs** | TCA-DETF-MV-008 |
| **Depends on** | WP-I-DETF-MV-001 for pretransfer ops |
| **Wave** | 3 |
| **Suggested worktree** | `gap_cover_l3-detf-mv` |
| **Estimate** | M |

---

## 9. Deferred / N/A / NEEDS_OWNER

| Item | Class | Note |
|------|-------|------|
| A4–A5, B2, C4–C5, D7, E2, G2–G3, H1 | **DEFER** | Documented P2 in suite NatSpec |
| exchangeOut money path | **N/A** | Always InvalidRoute by design |
| I4 FoT | **DEFER** / low | Legs are SE vaultShare; FoT less relevant |
| Donation beneficiary policy (if delta fix credits next depositor) | **NEEDS_OWNER** only if product chooses soft accounting; default law is no free credit / strict mismatch |
| Shared pull with BasicVaultCommon | Cross-area | Coordinate Wave-0 with T-basic-protocol-commons; MultiVault bug is **package-local** `_pullToken`, not BasicVaultCommon call |
| Runtime forge PoC this session | **RUNTIME_UNPROVEN** | Static overwhelming; Stage 2 proof-first |

---

## 10. Commands run

```bash
# Inventory (workspace)
rg -n "function test_|testFuzz_|invariant_" \
  test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted --glob '*.sol'

rg -n "pretransferred|facetFuncs|_pullToken" \
  contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted --glob '*.sol'

rg -n "test_I[123]_|test_J[123]_|test_K1_|facetAddress|controlFacetFuncs|loupe" \
  test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted --glob '*.sol'

rg -n "function test_" \
  test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/adversarial --glob '*.sol'

# Prior seeds
rg -n "MultiVault|multi-vault" docs/testing/ADVERSARIAL_VAULT_COVERAGE_GAP_REPORT.md
rg -n "MultiVault" docs/testing/FUZZ_INVARIANT_COVERAGE_GAP_REPORT.md

# Forge runtime for Blocker (not executed this run — RUNTIME_UNPROVEN)
# forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/adversarial/**' -vv
```

**Reads:** PRD §2/2.4/3.8/5–8/19; attack-catalog-template A–K; implementation-test-dod; package Targets/Common/Facet/DFPkg; adversarial suite files; fuzz + invariant; TestBase deploy path; prior adversarial + fuzz gap reports.

---

## Appendix A — Adversarial suite file map

| File | Catalog |
|------|---------|
| `Adversarial_Donation.t.sol` | A1–A3 |
| `Adversarial_PriceManipulation.t.sol` | B1, B1b, B3 |
| `Adversarial_Reentrancy.t.sol` | C1–C3 |
| `Adversarial_BondClaim.t.sol` | D2–D6 |
| `Adversarial_Economic.t.sol` | E1, E4 |
| `Adversarial_Guards.t.sol` | E5, H3, routes, preLive, threshold |
| `Adversarial_Access.t.sol` | F1–F4 |
| `Adversarial_Nested.t.sol` | G1 |
| `Adversarial_Griefing.t.sol` | H2 |
| `TestBase_MultiVaultWeightedDetf_Adversarial.sol` | hostile share + helpers |

## Appendix B — Pattern hunt summary

| Pattern | Hit? | Finding |
|---------|------|---------|
| PAT-I-ABS | **Yes** (package `_pullToken` + burn) | TCA-DETF-MV-001/002 |
| PAT-J-OMIT | Not confirmed (static looks complete) | open under J1 test |
| PAT-J-CTRL | **Yes** (declaration mirrors length, not Target) | TCA-DETF-MV-004 |
| PAT-K-DONATE | Partial (A1 OK; pretransfer bad) | TCA-DETF-MV-005 |
| PAT-THEATER-PRE | No | — |
| PAT-THEATER-FACET | **Yes** | TCA-DETF-MV-004 |
| PAT-PREV | No (preview tests pass) | — |
| PAT-MOCK | No | — |
