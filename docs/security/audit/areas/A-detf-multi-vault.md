# Security Audit — A-detf-multi-vault

| Field | Value |
|-------|--------|
| Date | 2026-08-13 |
| Git SHA | `1e0d7c48` (`1e0d7c48eff8a883837996ae700426ac5397924b`) |
| Agent / run | Stage 1 product-area subagent · MODE=pilot · A-detf-multi-vault |
| Status | **COMPLETE** |
| Production paths | `contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/**` (shared DETF commons / claim / bond NFT as **reference only**) |
| Test paths | `test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/**` including `adversarial/`, `fuzz/`, `invariant/` |
| Skills cited | `SECURITY_AUDIT_PRD` §2, §2.4, §3.8, §5–8, §19; `crane-adversarial-testing`; `indexedex-adversarial-testing`; `indexedex-testing`; `ethskills-security`; `defi-incident-patterns`; `docs/agent/INDEXEDEX_AGENT_LAW.md` DETF sections; `docs/vaults/BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_PRD.md` (L-RSRV-*); `docs/vaults/DETF_NESTED_SE_PUSH_PRETRANSFER_PRD.md` (L-DETF-*) |
| Residual-risk scores | MultiVaultWeightedDetf → **3** |
| Forge | **Not run** (orchestrator owns runtime; L-SEC-3). Static re-verify only. |

---

## 1. Executive summary

- **Residual-risk:** MultiVaultWeightedDetf **3** — no confirmed Critical/High **CODE** extract at this SHA; I/J/K production pull is reserve-delta (`U = B − R`) + catalog tests exist; leftover High is **TEST** (missing `test_A0_*`) plus Medium CODE leftovers (claim preview units; unrejoined idle `detfToken`; `initializeReserve` skip-sync).
- **Critical / High counts:** **Critical 0** · **High 1** (TEST only: `SEC-DETF-MV-007` missing A0). **No High CODE. No leftover `diamondCut` / owner on the live instance (L-SEC-11 statically clean).**
- **Top recommended WPs (this program):**
  1. `WP-SEC-DETF-MV-A0-001` — add catalog `test_A0_*` on production proxy (High TEST).
  2. `WP-SEC-DETF-MV-N2-001` — fix `previewRedeemClaim` / `previewCloseBondMature` to quote settlement asset, not raw BPT (Medium CODE).
  3. `WP-SEC-DETF-MV-IDLE-001` — burn / re-credit unrejoined `detfToken` after invariant-ratio cap (Medium CODE).
  4. `WP-SEC-DETF-MV-SYNC-001` — end-sync hold-set on `initializeReserve` (Medium CODE).
  5. `WP-SEC-DETF-MV-F1-001` — tighten F1 leftover-admin proof (loupe `diamondCut` == 0; exact `owner()` absence) (Medium THEATER/TEST).
- **OWNED_ELSEWHERE count:** **6** (`SEC-DETF-MV-001`…`006` → `TCA-DETF-MV-001`…`006`/`008` + `WP-I-DETF-MV-001/002`, `WP-J-DETF-MV-001`, `WP-K-DETF-MV-001`, `WP-N-DETF-MV-001`, `WP-L3-DETF-MV-001`). **Do not** schedule competing `sec_fix_*` on those touch-sets.
- **Re-verify vs coverage-audit (2026-08-09):** `_pullToken` is **no longer** `if (pretransferred_) return amount_`. Current body is reserve-delta + `TransferDeltaInsufficient` (`MultiVaultWeightedDetfCommon.sol` ~468–481). Burn path pulls via the same helper. Gap-closure claimed `WP-I/J/K-DETF-MV-*` closed (`docs/testing/coverage-audit/STAGE3_PROGRESS.md`); **this run confirms the CODE shape and catalog-named I/J/K tests exist**. Residual risk is **not** 5: A0 untested, claim previews lie, idle-`detfToken` dilution, F1 theater, J3 not full-API.

---

## 2. Product inventory

| Product | DFPkg / Targets | TestBase | Deploy path | Residual risk |
|---------|-----------------|----------|-------------|---------------|
| **MultiVaultWeightedDetf** | `MultiVaultWeightedDetfDFPkg.sol`; Facets: ExchangeIn (4 sels), Bonding (12), Info (23), plus ERC20 / ERC2612 / ERC5267 / MultiAsset Basic+Standard (views only); Targets: ExchangeIn/Out/Query, Bonding, Info; Common+Repo | `TestBase_MultiVaultWeightedDetf.sol` (CREATE3 facets + `indexedexManager.deploy*DFPkg` / `deployVault`; Aerodrome SE legs) | **Gold.** Facets via `*_FactoryService`; DFPkg via manager registry; never `new` on user path. Crane factory **base** cuts are ERC165 + Loupe + ERC8109 + PostHook — **not** DiamondCut / Ownable. | **3** |

### 2.1 Production file inventory

| Path | Role |
|------|------|
| `MultiVaultWeightedDetfDFPkg.sol` | Registry-gated `processArgs`; 8 facetCuts; `postDeploy` reserve pool + bond NFT + rebasing claim |
| `MultiVaultWeightedDetfExchangeInFacet.sol` | `exchangeIn` / previews / stub `exchangeOut` |
| `MultiVaultWeightedDetfBondingFacet.sol` | bond / initializeReserve / sell / buyClaim / close / redeemClaim / claimLiquidity |
| `MultiVaultWeightedDetfInfoFacet.sol` | views + `compoundProtocolRewards` + atomic self-call |
| `MultiVaultWeightedDetfCommon.sol` | pricing, thresholds, join/exit, expansion, compound, **`_pullToken`**, hold-set sync |
| `MultiVaultWeightedDetfRepo.sol` | diamond slot `keccak256("vault.detf.composed.multi-vault-weighted.multi-vault-weighted-detf.repo")` |
| `*_FactoryService.sol` | CREATE3 helpers |
| `TestBase_MultiVaultWeightedDetf.sol` | gold TestBase |

### 2.2 Trust-flag / money entrypoints

| Entrypoint | Flag | Credit path (this SHA) |
|------------|------|------------------------|
| `exchangeIn` mint | `pretransferred_` | `_pullToken` → join vaultShare → mint `detfToken` |
| `exchangeIn` burn | `pretransferred_` | `_pullToken(detfToken)` → burn → proportional exit |
| `bond` (BPT or vaultShare) | `pretransferred_` | `_pullToken` then NFT position / join |
| `buyClaim` | `pretransferred_` | `_pullToken(detfToken)` then single-sided join (uses **claimed** amount for join) |
| `initializeReserve` | always `false` | pull vaultShares; **no** end-sync |
| `exchangeOut` | flag ignored | always `InvalidRoute` |
| `redeemClaim` / `closeBondMature` | n/a | burn claim / sell mature NFT; no pretransfer flag |
| `compoundProtocolRewards` | n/a | permissionless; pays protocol NFT, not caller |
| `claimLiquidity` | n/a | gated `this` / bondNftVault / rebasingClaimToken |

### 2.3 Test roots

| Root | Role |
|------|------|
| `MultiVaultWeightedDetf_*.t.sol` | H/N matrix: deploy, mint/burn, bond, claim, product-law M1–M15, nested, expansion, compound, fees |
| `adversarial/` | A–H P0/P1 + **I1–I3/K1** + **J1–J3** + Access F1–F4 |
| `fuzz/` | L1 property fuzz (conservation, non-dilution) |
| `invariant/` | L3 Handler mint/burn/donate only (depth 10 / runs 24) |

---

## 3. Threat models

**Product:** MultiVaultWeightedDetf (live, unowned diamond).

| Actor | Surface (fn) | Asset moved | Trust flags | Admin / oracle | Worst case |
|-------|--------------|-------------|-------------|----------------|------------|
| EXT | `exchangeIn` mint | vaultShare → detfToken | `pretransferred` | fee oracle split; Policy/Open gates | free mint from booked inventory (**blocked** at SHA); unbooked donation sniping (**L-RSRV-DUST**, accepted) |
| EXT | `exchangeIn` burn | detfToken → vaultShare | `pretransferred` | burn gate | free extract of diamond detfToken inventory (**blocked** once booked) |
| EXT | `bond` | vaultShare / reserveBpt → bond NFT | `pretransferred` | lock terms from fee oracle | free bond principal from unbooked BPT (dust); leftover admin n/a |
| EXT | `initializeReserve` then first `bond(BPT)` | vaultShare → reserveBpt | pull `false` on init | none | A0 first-minter drain of pre-seeded inventory (**inert until first BPT bond**; init does not consume donations) |
| EXT | `sellPositionToDetfNft` / `closeBondMature` | bond NFT → claim / settlement | maturity | none | pre-maturity exit (**blocked** `BondNotMature`); extra detfToken to closer (**M5 bounds**) |
| EXT | `redeemClaim` | rebasingClaimToken → rateAsset / vaultShare | none | none | D2 free BPT without claim (**blocked**); H2 burn-without-payout (**full-tx revert**) |
| EXT | `buyClaim` | detfToken → claim | `pretransferred` | none | join uses claimed not measured actual (FoT N/A on detfToken) |
| EXT | `compoundProtocolRewards` | protocol pending detfToken → reserveBpt on protocol NFT | none | none | F5 skim to caller (**no**; credits protocol NFT only) |
| EXT | `claimLiquidity` | reserve BPT unwind | none | none | unprivileged call (**`NotAuthorized`** unless self/NFT/claim) |
| EXT | `diamondCut` / `owner()` | whole diamond | n/a | n/a | leftover upgrade (**statically absent**; F1 test is weak ABI) |
| CAP | skew underlying Aerodrome + mint/burn | vaultShare / detfToken | open vs Policy | thresholds | unbounded seigniorage (**Open = ACCEPTED_RISK** with B1 invariants; Policy deadband **B1b**) |
| HOS | `PkgArgs.vaultShares[i]` reentrant ERC20 | same | pull | none | reenter mint/bond/init/redeem (**C1–C3 `IsLocked`**) |
| INT | push + `pretransferred=true` | vaultShare / detfToken / BPT | L-RSRV-CALLER any caller | none | claimed > U reverts `TransferDeltaInsufficient`; claimed ≤ U credits (same-tx push **or** unbooked dust) |
| ADM | fee oracle `feeTo` / usage / seigniorage % | fee slice of mint | n/a | **manager/oracle** (out of area) | fee hike / beneficiary swap — **A-manager-fee-registry** |
| CFG | hostile share / zero minOut / Open mode | all | PkgArgs | deploy-time only | misconfigured Open seigniorage; hostile share accepted if passed at deploy |

---

## 4. Catalog matrix (A–O, E6, F5)

| ID | Product | F/P/G/N/A/VULN | Evidence |
|----|---------|----------------|----------|
| A1 | MV | **F** | `Adversarial_Donation.test_A1_donateVaultShares_cannotMintFreeDetf` (pull path; idle not joined) |
| A2 | MV | **F** | `test_A2_donateDetfToDiamond_noTheft` |
| A3 | MV | **F** | `test_A3_donateBpt_cannotRedeemOthersPrincipal` |
| A4–A5 | MV | **N/A** | Deferred P2 in Donation NatSpec |
| **A0** | MV | **G** | **No `test_A0_*`.** Production: inert until first BPT bond; `initializeReserve` pulls `false` and does not credit donations. Residual-risk hole is **proof**, not confirmed drain. → `SEC-DETF-MV-007` |
| B1 | MV | **F** | `test_B1_skewMintReverseBurn_seigniorageBounds` + invariants |
| B1b | MV | **F** | `test_B1b_defaultThresholds_cannotMintAndBurnSameRegime` |
| B2 | MV | **N/A** | Deferred P2 |
| B3 | MV | **F** | `test_B3_thresholdGates_blockMintWhenNotAllowed` |
| C1–C3 | MV | **F** | Reentrancy suite; exact `IsLocked` |
| C4–C5 | MV | **N/A** | Deferred P2 |
| D2 | MV | **F** | `test_D2_redeemClaim_withoutClaim_noBptDrain`; Claim suite without inventory |
| D3 | MV | **F** | `test_D3_doubleRedeem_secondReverts` |
| D4–D6 | MV | **F** | BondClaim suite |
| D7 | MV | **N/A** | Deferred P2 |
| E1 | MV | **F** | `test_E1_mintThenPartialBurn_conservation` |
| E4 | MV | **F** | `test_E4_holderBalance_notDilutedByOthersMint` |
| E5 | MV | **F** | zero / deadline exact selectors |
| **E6** | MV | **N/A** | No `balance − floor` refund / reclaim / surplus-pay-to-caller on this package. Nested SE push does not refund leftover to `msg.sender`. L-RSRV-ABSORB (unclaimed push absorbed). |
| F1 | MV | **P** | `test_F1_noOwnerOnInstance` exists but **diamondCut calldata is not a valid `FacetCut[]`** (theater). Static cuts have **no** DiamondCut/Ownable. → `SEC-DETF-MV-008` / `SEC-DETF-MV-015` |
| F2–F3 | MV | **F** | bond NFT / claim mint/burn onlyOwner (bare `expectRevert` residual) |
| F4 | MV | **F** | weights immutable; no `setWeights` |
| **F5** | MV | **F** | `compoundProtocolRewards` is permissionless by product law; credits **protocol NFT BPT**, not caller. `claimLiquidity` auth-gated. No migrate/resize/reclaim. |
| G1 | MV | **F** | `test_G1_outerActivity_doesNotBrickInner` |
| G2–G3 | MV | **N/A** | Deferred P2 |
| H2 | MV | **F** | `test_H2_redeemClaim_revert_claimUnchanged` (atomicity) |
| H3 | MV | **F** | minOut fail; residual asserts |
| **I1** | MV | **F** | mint / burn / bond booked-inventory + no transfer → `TransferDeltaInsufficient(claimed, 0)` |
| **I2** | MV | **F** | short same-tx push → `(claimed, shortDelta)` |
| **I3** | MV | **F** | residual after honest end-sync cannot fund second `true` |
| I4 | MV | **N/A** | Legs are SE vaultShare (not FoT product); detfToken is this diamond ERC-20 |
| I5 | MV | **N/A** | No Permit2 / product EIP-712 money path (ERC-2612 is standard share permit only) |
| **J1** | MV | **P** | `test_J1_targetSelectors_subseteq_facetFuncs` is **subset** smoke, not a full Target-derived control list |
| **J2** | MV | **P** | Loupe loop covers ExchangeIn + Bonding; **Info facetFuncs not iterated** |
| **J3** | MV | **P** | Proxy smoke of views + one mint + loupe; not each product selector (e.g. `exchangeOut` InvalidRoute, `redeemClaim`, `compoundProtocolRewards`) |
| J4 | MV | **P** | DFPkg `facetCuts` bind `facetFuncs()`; no dedicated J4 length test |
| **K1** | MV | **P** | `test_K1_donation_cannotFundPretransferCredit_mint` after honest sync. Bare donation **does** free-credit until sync (**L-RSRV-DUST**, accepted — not VULN) |
| L1 | MV | **P** | Fuzz conservation; no public skim. Burn formula `_bptForDetfShares` uses raw diamond BPT (donation subsidizes burners, not a skim). Idle leftover detfToken is **booked** after money-route sync |
| L2 | MV | **N/A** | FoT underlyings not a product claim |
| L3 | MV | **P** | Invariant handler mint/burn/donate; no bond/claim/pretransfer ops |
| M1–M3 | MV | **N/A** | No user `target+calldata`; nested call is configured `underlyingVault`. ProductLaw `test_M1_*` are **maturity** IDs, not catalog M |
| N1 | MV | **P** | No dedicated TOCTOU suite; C lock covers same-tx reentry; Balancer join/exit under outer `nonReentrant` |
| N2 | MV | **VULN** | mint/burn preview≡exec **F**; **`previewRedeemClaim` / `previewCloseBondMature` return `bptIn_`** (`_previewExitSettle`) — not settlement-asset out. `previewBuyClaim` is linear vs unbalanced join (documented M8). → `SEC-DETF-MV-009` |
| O1–O3 | MV | **N/A** | No product permit/signature money path; ERC-2612 on detfToken is standard share permit (commons / token specialist) |

**P0 DETF subset:** A1/A3/B1/B3/C1–C3/D2/D3/D6/E1/E5/F2–F3/H2/H3 = **F**; I1–I3 = **F**; J1–J3 = **P**; K1 = **P**; **A0 = G**; E6/F5 = N/A / F; N2 claim previews = **VULN** (Medium).

---

## 5. Domain notes

Walked locally (evm-audit domains as hunt lists; ship-gate remains Crane DoD):

| Domain | Notes |
|--------|--------|
| **general** | Routes closed-form; `InvalidRoute` on exact-out; CEI + `nonReentrant` on money paths; `try/catch` only on best-effort compound (product law). |
| **precision-math** | WAD / Balancer `FixedPoint`; `_bptForDetfShares` and `_previewJoinDetfOnly` are linear; claim redeem uses shares-before burn. Unrejoined detfToken stays in `totalSupply` → synthetic + burn dilution (`SEC-DETF-MV-010`). |
| **erc20** | `BetterSafeERC20`; pull false is FoT-safe (returns delta). `buyClaim` join uses claimed amount after pull. |
| **erc4626** | detfToken is diamond ERC-20, not 4626. Rebasing claim is 4626-like (commons; M4/M8). |
| **defi-amm** | Pricing = Balancer V3 weighted reserve + rate providers; synthetic from owned BPT (diamond + bond NFT). Spot skew = B1 / L3. |
| **proxies** | Crane MinimalDiamond + package cuts. Storage slot unique. No DiamondCut in factory base or DFPkg. PostHook removed after `postDeploy`. |
| **access-control** | Instance unowned. `claimLiquidity` allowlist. `compoundProtocolRewardsAtomic` `NotSelf`. Bond NFT / claim token onlyOwner for mint/burn (separate packages). |
| **oracles** | Thresholds deploy-time storage; fees via fee oracle (blast → manager area). No spot-as-sole mint oracle (synthetic + deadband). |
| **flashloans** | CAP skew covered by B1; Open seigniorage accepted. |
| **dos** | minOut / deadline / `InvariantRatioAboveMax` workaround (idle detfToken). N=7 gas deferred P2. |
| **erc721** | Bond NFT maturity gates sell/close; rewards claimable while locked (M3). |
| **CROPS** | Walkaway: users can mint/burn/bond/sell-mature/redeem without team. Registry disable cannot brick instance functions. Fee oracle is residual trust (other area). **L-SEC-11 leftover admin: statically absent.** |
| **sharp-edges** | `pretransferred` default is caller-supplied (L-RSRV-CALLER). PkgArgs zeros → Policy + 1.05/0.95. `minOut=0` common in tests (user footgun, not CODE). Hostile `vaultShares` accepted if CFG deploys them. |
| **spec** | Sell→claim / close only after maturity — **code matches** (`_requireMature` + ProductLaw M1/M2). Compound public + lazy — matches. `initializeReserve` missing end-sync vs L-DETF-END-ORDER / L-RSRV-SYNC-ROUTES. |
| **incidents** | A0 empty-vault (untested); I trust-flag (fixed+tested); L1 skim (no public reclaim); E6 surplus-refund (no path); F5 structural (compound does not pay caller). |

---

## 6. Findings

### 6.1 [SEC-DETF-MV-001] — PAT-I-ABS mint/bond/burn (re-verified closed)

| Field | Value |
|-------|--------|
| **FINDING_ID** | SEC-DETF-MV-001 |
| **Title** | Historical absolute / blind pretransfer credit on `_pullToken` / burn |
| **Severity** | Info (was coverage Blocker) |
| **Class** | **OWNED_ELSEWHERE** |
| **Confidence** | static-high (CODE shape re-read at `1e0d7c48`; forge not run) |
| **Catalog IDs** | I1–I3 |
| **Pattern IDs** | PAT-I-ABS |
| **EVM-audit domain** | erc20 |
| **CROPS pillar** | n/a |
| **Incident theme** | trust-flag free mint |
| **Products** | MultiVaultWeightedDetf |
| **Blast radius** | this package (clone of commons pattern; commons owned by A-commons-pull) |
| **Impact** | None remaining on booked inventory if reserve-delta + end-sync hold |
| **Evidence** | `MultiVaultWeightedDetfCommon.sol` 468–481: `U = B0 - R`; `amount_ > U` → `TransferDeltaInsufficient`; pull-false returns `balance − B0`. Burn: `ExchangeOutTarget.sol` 41–42 calls `_pullToken`. Coverage: `TCA-DETF-MV-001/002`, `WP-I-DETF-MV-001` (STAGE3 closed). Tests: `Adversarial_TrustFlags.t.sol` I1/I2/I3. |
| **Recommended TEST** | none new (owned) |
| **Anti-theater** | n/a |
| **Suggested WP-ID** | none — **do not** open `sec_fix_*` |
| **Link TCA / prior** | TCA-DETF-MV-001, TCA-DETF-MV-002, WP-I-DETF-MV-001 |
| **Depends / parallel** | n/a |

### 6.2 [SEC-DETF-MV-002] — I-suite ownership

| Field | Value |
|-------|--------|
| **FINDING_ID** | SEC-DETF-MV-002 |
| **Title** | Catalog I1–I3 tests already filed |
| **Severity** | Info |
| **Class** | **OWNED_ELSEWHERE** |
| **Confidence** | confirmed (files present) |
| **Catalog IDs** | I1–I3 |
| **Pattern IDs** | PAT-THEATER-PRE (absent — I1 does **not** transfer) |
| **EVM-audit domain** | erc20 |
| **Products** | MultiVaultWeightedDetf |
| **Blast radius** | tests only |
| **Impact** | none |
| **Evidence** | `Adversarial_TrustFlags.t.sol` I1 mint/burn/bond, I2 mint/burn, I3 mint/burn; helper does **not** transfer on I1. |
| **Recommended TEST** | none |
| **Anti-theater** | n/a |
| **Suggested WP-ID** | none |
| **Link TCA / prior** | TCA-DETF-MV-003, WP-I-DETF-MV-002 |
| **Depends / parallel** | n/a |

### 6.3 [SEC-DETF-MV-003] — J-suite ownership

| Field | Value |
|-------|--------|
| **FINDING_ID** | SEC-DETF-MV-003 |
| **Title** | J1–J3 suite exists (partial completeness leftover in 6.12) |
| **Severity** | Info |
| **Class** | **OWNED_ELSEWHERE** |
| **Confidence** | confirmed |
| **Catalog IDs** | J1–J3 |
| **Pattern IDs** | PAT-THEATER-FACET (historical; Surface now deploys proxy) |
| **EVM-audit domain** | proxies |
| **Products** | MultiVaultWeightedDetf |
| **Blast radius** | tests |
| **Impact** | none for ownership; residual incompleteness = `SEC-DETF-MV-012` |
| **Evidence** | `adversarial/Adversarial_Surface.t.sol`; `WP-J-DETF-MV-001` STAGE3 closed. |
| **Recommended TEST** | none (residual → 6.12) |
| **Anti-theater** | n/a |
| **Suggested WP-ID** | none |
| **Link TCA / prior** | TCA-DETF-MV-004, TCA-DETF-MV-010, WP-J-DETF-MV-001 |
| **Depends / parallel** | n/a |

### 6.4 [SEC-DETF-MV-004] — K1 ownership

| Field | Value |
|-------|--------|
| **FINDING_ID** | SEC-DETF-MV-004 |
| **Title** | K1 booked-donation regression exists |
| **Severity** | Info |
| **Class** | **OWNED_ELSEWHERE** |
| **Confidence** | confirmed |
| **Catalog IDs** | K1 |
| **Pattern IDs** | PAT-K-DONATE |
| **EVM-audit domain** | erc20 |
| **Products** | MultiVaultWeightedDetf |
| **Blast radius** | tests |
| **Impact** | none (unbooked donation is L-RSRV-DUST, 6.13) |
| **Evidence** | `test_K1_donation_cannotFundPretransferCredit_mint`; WP-K-DETF-MV-001 closed. |
| **Recommended TEST** | none |
| **Anti-theater** | n/a |
| **Suggested WP-ID** | none |
| **Link TCA / prior** | TCA-DETF-MV-005, WP-K-DETF-MV-001 |
| **Depends / parallel** | n/a |

### 6.5 [SEC-DETF-MV-005] — bare expectRevert ownership

| Field | Value |
|-------|--------|
| **FINDING_ID** | SEC-DETF-MV-005 |
| **Title** | Adversarial P0 still uses bare `expectRevert` on several paths |
| **Severity** | Medium |
| **Class** | **OWNED_ELSEWHERE** |
| **Confidence** | confirmed |
| **Catalog IDs** | D2, D3, F2, F3, H2, H3 |
| **Pattern IDs** | none |
| **EVM-audit domain** | general |
| **Products** | MultiVaultWeightedDetf |
| **Blast radius** | tests |
| **Impact** | wrong revert can still pass |
| **Evidence** | `Adversarial_BondClaim.t.sol` 31, 64, 89; `Adversarial_Access.t.sol` 40, 50, 59; `Adversarial_Donation.t.sol` 67, 112; `Adversarial_Griefing.t.sol` 42; `Adversarial_Guards.t.sol` 67, 82. Coverage WP-N-DETF-MV-001 / TCA-DETF-MV-006. |
| **Recommended TEST** | owned by coverage-audit |
| **Anti-theater** | n/a |
| **Suggested WP-ID** | none — no `sec_fix_*` |
| **Link TCA / prior** | TCA-DETF-MV-006, WP-N-DETF-MV-001 |
| **Depends / parallel** | n/a |

### 6.6 [SEC-DETF-MV-006] — L3 handler surface ownership

| Field | Value |
|-------|--------|
| **FINDING_ID** | SEC-DETF-MV-006 |
| **Title** | L3 Handler still mint/burn/donate only |
| **Severity** | Medium |
| **Class** | **OWNED_ELSEWHERE** |
| **Confidence** | confirmed |
| **Catalog IDs** | L3 |
| **Pattern IDs** | none |
| **EVM-audit domain** | defi-amm |
| **Products** | MultiVaultWeightedDetf |
| **Blast radius** | tests |
| **Impact** | bond/claim/pretransfer not in invariant surface |
| **Evidence** | `invariant/MultiVaultWeightedDetf.invariant.t.sol` selectors 43–46; TCA-DETF-MV-008 / WP-L3-DETF-MV-001. |
| **Recommended TEST** | owned |
| **Anti-theater** | n/a |
| **Suggested WP-ID** | none |
| **Link TCA / prior** | TCA-DETF-MV-008, WP-L3-DETF-MV-001 |
| **Depends / parallel** | n/a |

### 6.7 [SEC-DETF-MV-007] — Missing A0 empty-inventory proof

| Field | Value |
|-------|--------|
| **FINDING_ID** | SEC-DETF-MV-007 |
| **Title** | Add catalog A0 proof that first live minter cannot drain pre-seeded inventory |
| **Severity** | **High** |
| **Class** | **TEST** |
| **Confidence** | static-high (no `test_A0_*`; production **appears** gated) |
| **Catalog IDs** | A0 |
| **Pattern IDs** | PAT-A0-EMPTY |
| **EVM-audit domain** | erc4626 |
| **CROPS pillar** | n/a |
| **Incident theme** | empty vault / first deposit drain |
| **Products** | MultiVaultWeightedDetf |
| **Blast radius** | single package (gold DETF — ports copy this suite) |
| **Attacker** | EXT / CFG |
| **Attack scenario** | 1. Deploy inert DETF (`totalSupply` of user detfToken = 0 until `initializeReserve` mints self-leg into the pool). 2. Donate vaultShare and/or reserveBpt to the diamond. 3. Attacker calls `initializeReserve` (should only join **pulled** amounts; extra donation stays idle). 4. Attacker `bond(reserveBpt)` to go live. 5. Attacker `exchangeIn(pretransferred=true)` or first mint — **must not** convert pre-seeded idle inventory into attacker principal beyond L-RSRV-DUST window. 6. Pass = attacker detfToken / bond principal does not include **other users’** pre-seeded assets after first honest money-route sync; first mint cannot drain pool self-leg. |
| **Preconditions** | Fresh instance; donated inventory before live; no mock SUT |
| **Impact** | Unproven P0: if A0 were live, first minter drains residual. Static read says drain via mint is blocked pre-live and init does not credit donations; **ship-gate still requires the test**. |
| **Evidence** | `rg test_A0_` under multi-vault-weighted → **no matches**. `initializeReserve` (`BondingTarget.sol` 82–123) pulls `false` and never `_syncAllExpectedHoldReserves`. Mint requires `_requireReserveLive`. Skill `indexedex-adversarial-testing` lists A0 as mandatory P0. |
| **Runtime** | n/a (not Critical CODE) |
| **Recommended CODE** | none unless A0 test fails (then treat as CODE) |
| **Recommended TEST** | `test_A0_preLive_donatedVaultShare_cannotBeFirstMinted`; `test_A0_donatedBpt_firstBondDoesNotStealOthersSeed`; `test_A0_emptyUserSupply_donatedInventory_notDrainedByFirstMint`. Setup: registry-deploy N=1; donate; init+bond as specified; assert attacker enrichment ≤ their own pull. `forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/adversarial/**' --match-test 'test_A0_'` |
| **Anti-theater** | Must donate **before** live; must not count L-RSRV-DUST same-tx self-push as A0; must call **proxy**; no `MockStandardExchange` |
| **Suggested WP-ID** | `WP-SEC-DETF-MV-A0-001` |
| **Link TCA / prior** | none (coverage-audit did not file A0) |
| **Depends / parallel** | Parallel with N2/idle/sync WPs; do not touch `_pullToken` (owned) |

### 6.8 [SEC-DETF-MV-008] — F1 leftover-admin theater

| Field | Value |
|-------|--------|
| **FINDING_ID** | SEC-DETF-MV-008 |
| **Title** | F1 `diamondCut` call uses invalid ABI; cannot fail if Cut is live |
| **Severity** | Medium |
| **Class** | **THEATER** |
| **Confidence** | confirmed |
| **Catalog IDs** | F1 |
| **Pattern IDs** | PAT-THEATER-FACET, PAT-CROPS-ADMIN |
| **EVM-audit domain** | access-control / proxies |
| **CROPS pillar** | S (upgrade surface) |
| **Incident theme** | none |
| **Products** | MultiVaultWeightedDetf |
| **Blast radius** | tests (production statically clean — 6.15) |
| **Impact** | False confidence on L-SEC-11 |
| **Evidence** | `Adversarial_Access.t.sol` 25–33 encodes `diamondCut((address,uint8,bytes4[])[],address,bytes)` with `new bytes(0)` as the **first** argument (not a `FacetCut[]`). Call fails ABI decode even if selector exists. `owner()==instance` is treated as pass. |
| **Recommended CODE** | none |
| **Recommended TEST** | See WP-SEC-DETF-MV-F1-001 |
| **Anti-theater** | Loupe `facetAddress(IDiamondCut.diamondCut.selector)==0`; low-level call with **valid empty `FacetCut[]`**; `owner()` FunctionNotFound **or** address(0) only |
| **Suggested WP-ID** | `WP-SEC-DETF-MV-F1-001` |
| **Link TCA / prior** | none |
| **Depends / parallel** | Parallel with A0 |

### 6.9 [SEC-DETF-MV-009] — Claim/close preview returns BPT, not tokenOut

| Field | Value |
|-------|--------|
| **FINDING_ID** | SEC-DETF-MV-009 |
| **Title** | `previewRedeemClaim` / `previewCloseBondMature` quote BPT units as settlement out |
| **Severity** | **Medium** |
| **Class** | **CODE** |
| **Confidence** | static-high |
| **Catalog IDs** | N2 |
| **Pattern IDs** | PAT-N-TOCTOU |
| **EVM-audit domain** | general |
| **CROPS pillar** | n/a |
| **Incident theme** | none |
| **Products** | MultiVaultWeightedDetf |
| **Blast radius** | family pattern if ports copied `_previewExitSettle` |
| **Attacker** | INT / EXT (integrator minOut from preview) |
| **Attack scenario** | 1. Holder sells mature bond → claim. 2. Integrator sets `minOut = previewRedeemClaim(claimAmt, rateAsset)`. 3. Preview returns `bptIn_` (`BondingTarget.sol` 518–523), not rateAsset/vaultShare. 4. If that number **exceeds** actual settlement, redeem **reverts** (grief / frozen exit until minOut lowered). 5. If it is **below** actual out, user has **no slippage protection** on the SE unwind (`_exchangeShareToRateAsset`). |
| **Preconditions** | Live instance; claim or mature bond; caller trusts preview |
| **Impact** | Wrong minOut: revert (exit grief) or sandwichable SE hop. Not unbounded extract. |
| **Evidence** | `_previewExitSettle` ignores `legIndex_` and `tokenOut_`, `return bptIn_`. Used by `previewRedeemClaim` and `previewCloseBondMature`. Contrast mint/burn: `test_mint_previewEqualsExecution` exact. ProductLaw M8 already admits buyClaim preview ≠ join. |
| **Runtime** | n/a (Medium) |
| **Recommended CODE** | `MultiVaultWeightedDetfBondingTarget.sol`: preview via `_previewExitSettle` → proportional vaultShare then `underlyingVault.previewExchangeIn` (mirror `_previewBptToRateAsset` in QueryTarget). |
| **Recommended TEST** | `test_N2_previewRedeemClaim_equalsExecute`; `test_N2_previewCloseBondMature_equalsExecute` (documented ≤ few-wei if Balancer forces). `forge test --match-path '.../multi-vault-weighted/**' --match-test 'test_N2_'` |
| **Anti-theater** | Must compare preview to **execute out** of the same tokenOut; not merely `preview > 0` |
| **Suggested WP-ID** | `WP-SEC-DETF-MV-N2-001` |
| **Link TCA / prior** | none |
| **Depends / parallel** | Parallel with A0 / F1; serial with idle-detf if both edit BondingTarget |

### 6.10 [SEC-DETF-MV-010] — Unrejoined detfToken leftover dilutes backing

| Field | Value |
|-------|--------|
| **FINDING_ID** | SEC-DETF-MV-010 |
| **Title** | Invariant-ratio cap leaves idle detfToken in supply; dilutes burn + synthetic |
| **Severity** | **Medium** |
| **Class** | **CODE** |
| **Confidence** | static-high |
| **Catalog IDs** | K, E |
| **Pattern IDs** | PAT-K-DONATE (inventory desync), PAT-SPEC-DRIFT |
| **EVM-audit domain** | precision-math |
| **CROPS pillar** | n/a |
| **Incident theme** | none |
| **Products** | MultiVaultWeightedDetf |
| **Blast radius** | this family; same helper if cloned |
| **Attacker** | EXT (large closer / redeemer) |
| **Attack scenario** | 1. Live pool with self-leg + minters. 2. Majority closer / claim redeem exits large BPT (`closeBondMature` / `redeemClaim` → `_rejoinDetfAndOtherLegs`). 3. If remaining pool detfToken is 0 or `detfLeg > remaining`, **no DETF is rejoined**; leftover sits on the diamond (comment at `BondingTarget.sol` 476–478). 4. End-sync **books** it (I1-safe) but does **not** burn it. 5. `totalSupply` still includes leftover; `_bptForDetfShares` = `detfShares * diamondBpt / supply` under-pays remaining burners; `_syntheticPrice` = value / supply **drops** (can flip Policy gates). |
| **Preconditions** | Large proportional exit vs remaining self-leg (first-bonder close is the documented case) |
| **Impact** | Permanent stranded detfToken; remaining holders diluted; possible mint/burn gate flip. **Not** attacker extract (I1 blocks pretransfer after sync). |
| **Evidence** | `BondingTarget.sol` 466–516; `_bptForDetfShares` `Common.sol` 355–361; `_syntheticPrice` uses full `totalSupply` (107–134). ProductLaw M5 allows protocol redeposit, not idle supply inflation. |
| **Runtime** | n/a (Medium) |
| **Recommended CODE** | After cap: `_burnDetf(address(this), leftover)` **or** send leftover to protocol NFT inventory per product owner; do not leave it in circulating supply. |
| **Recommended TEST** | `test_E_majorityClose_noIdleDetfDilution`; assert diamond `balanceOf(this)` detfToken == 0 **or** excluded from burn/synthetic denominator. |
| **Anti-theater** | Must actually take the cap branch (majority close), not only N=1 dust join |
| **Suggested WP-ID** | `WP-SEC-DETF-MV-IDLE-001` |
| **Link TCA / prior** | none (may need `NEEDS_OWNER` if leftover is intentional inventory) |
| **Depends / parallel** | Serial with N2 if same file; else parallel |

### 6.11 [SEC-DETF-MV-011] — initializeReserve skips hold-set sync

| Field | Value |
|-------|--------|
| **FINDING_ID** | SEC-DETF-MV-011 |
| **Title** | `initializeReserve` does not end-sync expected-hold reserves |
| **Severity** | **Medium** |
| **Class** | **CODE** |
| **Confidence** | static-high |
| **Catalog IDs** | K1 |
| **Pattern IDs** | PAT-K-DONATE, PAT-SPEC-DRIFT |
| **EVM-audit domain** | erc20 |
| **CROPS pillar** | n/a |
| **Incident theme** | none |
| **Products** | MultiVaultWeightedDetf |
| **Blast radius** | this package |
| **Impact** | After init, `R=0` until first `bond` sync. Unbooked leftover / donation is L-RSRV-DUST (accepted) **and** L-RSRV-BOOTSTRAP. Violates L-DETF-END-ORDER / L-RSRV-SYNC-ROUTES (“every money route”). Pre-live mint blocked, so extract window is mainly first `bond(BPT, pretransferred=true)` claiming donated BPT — **accepted dust**, but init should still book remaining vaultShare/detfToken/BPT after transferring BPT out. |
| **Evidence** | `BondingTarget.sol` 82–123: pulls, mints self-leg, `_initializeReserve`, `safeTransfer` BPT to caller; **no** `_syncAllExpectedHoldReserves`. All other money routes sync (bond/sell/buyClaim/close/redeem/claimLiquidity/mint/burn). |
| **Recommended CODE** | Call `_syncAllExpectedHoldReserves()` after BPT transfer out. |
| **Recommended TEST** | `test_K_initializeReserve_endSyncsHoldSet` — after init, `reserveOfToken` == `balanceOf` for detfToken, vaultShare, reserveBpt. |
| **Anti-theater** | Check **all** hold-set tokens, not only BPT |
| **Suggested WP-ID** | `WP-SEC-DETF-MV-SYNC-001` |
| **Link TCA / prior** | none |
| **Depends / parallel** | Parallel with A0 (same setup helper) |

### 6.12 [SEC-DETF-MV-012] — J residual incompleteness

| Field | Value |
|-------|--------|
| **FINDING_ID** | SEC-DETF-MV-012 |
| **Title** | J2 skips Info facet; J3 is not full-API proxy smoke |
| **Severity** | Medium |
| **Class** | **TEST** |
| **Confidence** | confirmed |
| **Catalog IDs** | J1–J3 |
| **Pattern IDs** | PAT-J-CTRL |
| **EVM-audit domain** | proxies |
| **Products** | MultiVaultWeightedDetf |
| **Blast radius** | tests |
| **Impact** | Silent omit on Info (compound / expansion views) or stub `exchangeOut` would not fail J suite |
| **Evidence** | `Adversarial_Surface.t.sol` 45–66 loops ExchangeIn + Bonding only; J3 69–104 smokes a subset. IFacet unit test still `new` facets (`MultiVaultWeightedDetfExchangeInFacet_IFacet_Test.t.sol`) — declaration theater remains **beside** real Surface tests. |
| **Recommended TEST** | Extend J2 to Info `facetFuncs`; J3 each bonding/info selector (views + expected revert). Fold `exchangeOut` → exact `InvalidRoute`. |
| **Anti-theater** | Never assert only on `new Facet()` for J2/J3 |
| **Suggested WP-ID** | fold into `WP-SEC-DETF-MV-F1-001` or small `WP-SEC-DETF-MV-J-001` |
| **Link TCA / prior** | TCA-DETF-MV-004 (closed WP-J) — **new residual**, not a second CODE WP on Facet files |
| **Depends / parallel** | Parallel |

### 6.13 [SEC-DETF-MV-013] — L-RSRV-DUST unbooked pretransfer

| Field | Value |
|-------|--------|
| **FINDING_ID** | SEC-DETF-MV-013 |
| **Title** | Unbooked surplus funds `pretransferred=true` by product law |
| **Severity** | Info |
| **Class** | **ACCEPTED_RISK** |
| **Confidence** | confirmed (law + tests) |
| **Catalog IDs** | I, K |
| **Pattern IDs** | PAT-K-DONATE, PAT-I-ABS (mitigated to unbooked-only) |
| **EVM-audit domain** | erc20 |
| **Products** | MultiVaultWeightedDetf |
| **Blast radius** | all reserve-delta vaults (commons law) |
| **Impact** | Anyone may snipe **not-yet-synced** donations. After honest money-route sync, booked residual cannot free-credit (I1/I3/K1). |
| **Evidence** | `docs/vaults/BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_PRD.md` L-RSRV-DUST / L-RSRV-BOOTSTRAP / L-RSRV-CALLER; TrustFlags NatSpec; `_pullToken` U = B − R. |
| **Invariants required for acceptance** | Victim pull-path balances unchanged (A1); no free **booked** principal (I1); residual after fail = 0 (H3); unbooked window is intentional recovery, not victim mint inventory. |
| **Recommended TEST** | already in I/K suite |
| **Anti-theater** | n/a |
| **Suggested WP-ID** | none |
| **Link TCA / prior** | L-RSRV-* PRD |
| **Depends / parallel** | n/a |

### 6.14 [SEC-DETF-MV-014] — Open-threshold seigniorage

| Field | Value |
|-------|--------|
| **FINDING_ID** | SEC-DETF-MV-014 |
| **Title** | Skew mint/burn under Open thresholds is intentional seigniorage |
| **Severity** | Info |
| **Class** | **ACCEPTED_RISK** |
| **Confidence** | confirmed |
| **Catalog IDs** | B1, L3 |
| **Pattern IDs** | none |
| **EVM-audit domain** | defi-amm |
| **Products** | MultiVaultWeightedDetf |
| **Blast radius** | Open-mode instances |
| **Impact** | Bounded extract when both gates open |
| **Evidence** | `test_B1_*` + victim-balance / no-free-principal / residual invariants; Policy deadband `test_B1b_*`. Agent law: Open gates always pass. |
| **Invariants** | Victim token balances unchanged by attacker path; no free reserve principal without claim/NFT; residual inventory clean; Policy cannot mint-and-burn same regime. |
| **Recommended TEST** | existing |
| **Anti-theater** | n/a |
| **Suggested WP-ID** | none |
| **Link TCA / prior** | none |
| **Depends / parallel** | n/a |

### 6.15 [SEC-DETF-MV-015] — L-SEC-11 leftover admin clean bill

| Field | Value |
|-------|--------|
| **FINDING_ID** | SEC-DETF-MV-015 |
| **Title** | Live DETF has no DiamondCut / Ownable facet |
| **Severity** | Info |
| **Class** | **ACCEPTED_RISK** (intentional unowned; not a leftover-admin High) |
| **Confidence** | static-high |
| **Catalog IDs** | F1 |
| **Pattern IDs** | PAT-CROPS-ADMIN |
| **EVM-audit domain** | access-control |
| **CROPS pillar** | S |
| **Products** | MultiVaultWeightedDetf |
| **Blast radius** | instance |
| **Impact** | None — cannot upgrade / pause instance |
| **Evidence** | Factory base cuts (`DiamondPackageCallBackFactory.sol` 261–294): ERC165, Loupe, ERC8109, PostHook only. DFPkg `facetCuts()` 255–275: ERC20, ERC5267, ERC2612, MultiAsset Basic/Standard (views), ExchangeIn, Bonding, Info. No `onlyOwner` / `diamondCut` in package sources. Product law: immutable/unowned after deploy. |
| **Recommended TEST** | tighten via 6.8 |
| **Anti-theater** | n/a |
| **Suggested WP-ID** | none |
| **Link TCA / prior** | L-SEC-11 |
| **Depends / parallel** | n/a |

---

## 7. Theater / false confidence

| Test / control | Why it cannot catch the bug | Fix |
|----------------|----------------------------|-----|
| `Adversarial_Access.test_F1_noOwnerOnInstance` diamondCut branch | First arg is `bytes(0)`, not `FacetCut[]` — always fails decode | Valid empty cuts + loupe `facetAddress(cutSel)==0` |
| `MultiVaultWeightedDetfExchangeInFacet_IFacet_Test` | `new` facets; length floors; never deploys DFPkg/proxy | Keep as metadata unit test only; do **not** cite as J |
| Implicit “K1 = donations never credit” | TrustFlags **document** bare donation free-credit (L-RSRV-DUST) | Cite law; I1 is **booked** residual only |
| Implicit “I covered by A1” | A1 is pull-path; I is `pretransferred=true` | I suite now exists — do not regress |
| Bare `expectRevert` on D2/D3/F2/F3/H2/preLive | Wrong selector still passes | OWNED_ELSEWHERE WP-N |
| J3 “proxy smoke” | Does not call each money selector | `SEC-DETF-MV-012` |
| L3 residual after donate | Handler relaxes residual when donate ghost > 0 | Documented; do not claim hard residual under donate |

**Not theater:** I1 (no in-call transfer, inventory present); C1–C3 exact `IsLocked`; E5 exact selectors; mint/burn preview≡exec; ProductLaw M1/M2 exact `BondNotMature`; production registry deploy.

**PAT-THEATER-PRE:** not present on I suite.

**PAT-MOCK:** no mock SUT on MultiVault money paths.

---

## 8. Coverage-audit linkage

| TCA / WP | Same touch-set? | Action |
|----------|-----------------|--------|
| TCA-DETF-MV-001 / 002 · WP-I-DETF-MV-001 | Yes — `_pullToken` + burn pull | **OWNED_ELSEWHERE** — CODE re-verified **fixed** (reserve-delta). No `sec_fix_*`. |
| TCA-DETF-MV-003 · WP-I-DETF-MV-002 | Yes — I tests | **OWNED_ELSEWHERE** — tests present |
| TCA-DETF-MV-004 / 010 · WP-J-DETF-MV-001 | Yes — J suite | **OWNED_ELSEWHERE**; residual incompleteness = new TEST `SEC-DETF-MV-012` (do not re-edit Facet decls unless omit found — none found) |
| TCA-DETF-MV-005 · WP-K-DETF-MV-001 | Yes — K1 | **OWNED_ELSEWHERE** |
| TCA-DETF-MV-006 · WP-N-DETF-MV-001 | Yes — bare revert | **OWNED_ELSEWHERE** |
| TCA-DETF-MV-007 P2 defer | Yes | **DEFER** (keep) |
| TCA-DETF-MV-008 · WP-L3-DETF-MV-001 | Yes — handler | **OWNED_ELSEWHERE** |
| TCA-DETF-MV-009 baseline | n/a | Info |
| WP-I-COMMON-001 | Commons `_secureTokenTransfer` | **Out of area** (blast only) |

**Stale coverage claim:** 2026-08-09 “I = G / `_pullToken` returns amount_” is **false** at `1e0d7c48`.

---

## 9. Work package stubs

### WP-SEC-DETF-MV-A0-001

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-DETF-MV-A0-001` |
| **Title** | Add MultiVault catalog A0 residual-inventory tests |
| **Severity** | High |
| **Class** | TEST |
| **Products** | MultiVaultWeightedDetf |
| **Finding IDs** | SEC-DETF-MV-007 |
| **Problem** | P0 A0 has no `test_A0_*`. First-minter drain of pre-seeded inventory is unproven. Production looks gated (inert + pull-false init) but ship-gate requires the test. |
| **Production files (touch set)** | none unless test fails |
| **Test files (touch set)** | `test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/adversarial/Adversarial_Donation.t.sol` (or new `Adversarial_EmptyVault.t.sol`) |
| **Out of scope files** | `_pullToken` / TrustFlags (owned); peer DETFs |
| **Depends on** | none |
| **Parallelizable with** | `WP-SEC-DETF-MV-F1-001`, N2/idle/sync |
| **Conflicts with coverage-audit WP** | none |
| **Suggested worktree** | `sec_fix_detf-mv-a0` · branch `sec_fix/detf-mv-a0` |
| **Implementation notes** | Gold `TestBase_MultiVaultWeightedDetf_Adversarial`; donate vaultShare/BPT before live; DETF role names; L-RSRV-DUST ≠ A0 |
| **Acceptance** | `forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/adversarial/**' --match-test 'test_A0_'` green; names `test_A0_*` |
| **Anti-theater checks** | Donate before first bond; proxy calls; no mock SE; attacker cannot drain **others’** seed after first honest sync |
| **Proof-first?** | no (TEST; if it fails, escalate to CODE + proof) |
| **Estimate** | S |

### WP-SEC-DETF-MV-N2-001

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-DETF-MV-N2-001` |
| **Title** | Quote claim/close preview in settlement asset |
| **Severity** | Medium |
| **Class** | BOTH |
| **Products** | MultiVaultWeightedDetf |
| **Finding IDs** | SEC-DETF-MV-009 |
| **Problem** | `_previewExitSettle` returns `bptIn_`. Integrators using preview as `minOut` grief or under-protect the SE hop. |
| **Production files (touch set)** | `contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfBondingTarget.sol` |
| **Test files (touch set)** | `MultiVaultWeightedDetf_Claim.t.sol` and/or `adversarial/Adversarial_BondClaim.t.sol` |
| **Out of scope files** | ExchangeIn mint/burn previews (already exact); peer DETFs unless same helper copied later |
| **Depends on** | none |
| **Parallelizable with** | A0, F1, SYNC |
| **Conflicts with coverage-audit WP** | none |
| **Suggested worktree** | `sec_fix_detf-mv-preview` · branch `sec_fix/detf-mv-preview` |
| **Implementation notes** | Reuse `_previewBptToRateAsset` / proportional leg math; no `via_ir` |
| **Acceptance** | `forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/**' --match-test 'test_N2_'` ; preview ≈ execute |
| **Anti-theater checks** | Compare to execute `amountOut` of the same `tokenOut` |
| **Proof-first?** | no |
| **Estimate** | S–M |

### WP-SEC-DETF-MV-IDLE-001

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-DETF-MV-IDLE-001` |
| **Title** | Do not leave unrejoined detfToken in circulating supply |
| **Severity** | Medium |
| **Class** | BOTH |
| **Products** | MultiVaultWeightedDetf |
| **Finding IDs** | SEC-DETF-MV-010 |
| **Problem** | Majority close / redeem can leave idle detfToken on the diamond. Booked (I1-safe) but dilutes `_bptForDetfShares` and `_syntheticPrice`. |
| **Production files (touch set)** | `MultiVaultWeightedDetfBondingTarget.sol` (`_rejoinDetfAndOtherLegs`); possibly `MultiVaultWeightedDetfCommon.sol` if burn helper added |
| **Test files (touch set)** | `MultiVaultWeightedDetf_ProductLaw.t.sol` (extend M5) and/or new adversarial economic case |
| **Out of scope files** | TrustFlags; commons pull |
| **Depends on** | `NEEDS_OWNER` if leftover is declared protocol inventory (then exclude from supply math instead of burn) |
| **Parallelizable with** | A0, F1; **serial with N2** (same BondingTarget) |
| **Conflicts with coverage-audit WP** | none |
| **Suggested worktree** | `sec_fix_detf-mv-idle` · branch `sec_fix/detf-mv-idle` (merge with preview tree if same week) |
| **Implementation notes** | Prefer burn leftover to `address(this)` after cap; keep Balancer invariant workaround |
| **Acceptance** | Majority-close test: circulating dilution does not increase; residual free user detfToken = 0 |
| **Anti-theater checks** | Must hit `joinDetf_ = 0` / cap branch |
| **Proof-first?** | no |
| **Estimate** | M |

### WP-SEC-DETF-MV-SYNC-001

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-DETF-MV-SYNC-001` |
| **Title** | End-sync hold-set after `initializeReserve` |
| **Severity** | Medium |
| **Class** | BOTH |
| **Products** | MultiVaultWeightedDetf |
| **Finding IDs** | SEC-DETF-MV-011 |
| **Problem** | Init is a money route without `_syncAllExpectedHoldReserves`, violating L-DETF-END-ORDER. |
| **Production files (touch set)** | `MultiVaultWeightedDetfBondingTarget.sol` (`initializeReserve`) |
| **Test files (touch set)** | `MultiVaultWeightedDetf_Deploy.t.sol` or adversarial K |
| **Out of scope files** | SE commons |
| **Depends on** | none |
| **Parallelizable with** | A0 |
| **Conflicts with coverage-audit WP** | none |
| **Suggested worktree** | `sec_fix_detf-mv-initsync` (or fold into idle tree) |
| **Implementation notes** | Sync **after** BPT transfer to caller |
| **Acceptance** | After init, `reserveOfToken` == `balanceOf` for hold-set |
| **Anti-theater checks** | Check detfToken + vaultShare + reserveBpt |
| **Proof-first?** | no |
| **Estimate** | S |

### WP-SEC-DETF-MV-F1-001

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-DETF-MV-F1-001` |
| **Title** | Tighten F1 leftover-admin + residual J2/J3 |
| **Severity** | Medium |
| **Class** | TEST |
| **Products** | MultiVaultWeightedDetf |
| **Finding IDs** | SEC-DETF-MV-008, SEC-DETF-MV-012, SEC-DETF-MV-015 |
| **Problem** | F1 cannot prove Cut absent; J2 skips Info; J3 not full API. |
| **Production files (touch set)** | none (unless loupe finds omit — none expected) |
| **Test files (touch set)** | `adversarial/Adversarial_Access.t.sol`; `adversarial/Adversarial_Surface.t.sol` |
| **Out of scope files** | IFacet `new` unit test (leave as metadata-only) |
| **Depends on** | none |
| **Parallelizable with** | A0 |
| **Conflicts with coverage-audit WP** | none on primary files (WP-J closed; this is residual TEST only) |
| **Suggested worktree** | `sec_fix_detf-mv-f1j` |
| **Implementation notes** | Loupe `IDiamondCut.diamondCut` == 0; valid empty cut call; Info facetFuncs loop |
| **Acceptance** | `test_F1_*` + `test_J2_*` + `test_J3_*` prove Cut absent and Info wired |
| **Anti-theater checks** | Valid `FacetCut[]`; J3 on **proxy** |
| **Proof-first?** | no |
| **Estimate** | S |

---

## 10. Deferred / N/A / NEEDS_OWNER / ACCEPTED_RISK

| Item | Class | Note |
|------|-------|------|
| A4–A5, B2, C4–C5, D7, E2, G2–G3, H1 | **DEFER** | Suite NatSpec P2 |
| E6 surplus-refund | **N/A** | No `balance − floor` pay-to-caller |
| M1–M3 arbitrary call | **N/A** | No helper calldata surface |
| O1–O3 / I5 | **N/A** | No product Permit2; ERC-2612 is share permit |
| I4 FoT | **DEFER** | SE shares / detfToken not FoT product |
| exchangeOut money path | **N/A** | Always `InvalidRoute` |
| L-RSRV-DUST unbooked sniping | **ACCEPTED_RISK** | `SEC-DETF-MV-013` + invariants |
| Open seigniorage | **ACCEPTED_RISK** | `SEC-DETF-MV-014` + B1 invariants |
| Unowned / no Cut | **ACCEPTED_RISK** | `SEC-DETF-MV-015` (clean) |
| Idle leftover dest (burn vs protocol inventory) | **NEEDS_OWNER** | If not burn, must exclude from `totalSupply` math |
| Fee oracle authority | **OWNED_ELSEWHERE** | A-manager-fee-registry |
| Shared claim / bond NFT packages | **reference** | Commons / claim area |
| Runtime forge this session | **not run** | Orchestrator owns; no Critical CODE to prove |
| `via_ir` | **forbidden** | not recommended |

---

## 11. Commands run

```bash
# Inventory
rg --glob '*.sol' -n 'function _pullToken|pretransferred|TransferDeltaInsufficient|diamondCut|onlyOwner|test_I[123]_|test_J[123]_|test_K1_|test_A0_|test_E6_|test_F5_' \
  contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted \
  test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted

rg --glob '*.sol' -n 'function test_' \
  test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/adversarial

rg --glob '*.sol' -n 'expectRevert\(\)' \
  test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/adversarial

rg -n 'WP-I-DETF-MV-001|WP-J-DETF-MV-001|WP-K-DETF-MV-001|L-RSRV-DUST|L-DETF-LOCAL-PUSH' \
  docs/testing/coverage-audit docs/vaults docs/agent

# Reads (normative)
# SECURITY_AUDIT_PRD §2/2.4/3.8/5–8/19
# crane-adversarial-testing + indexedex-adversarial-testing + indexedex-testing
# ethskills-security + defi-incident-patterns
# INDEXEDEX_AGENT_LAW DETF sections
# T-detf-multi-vault.md + WORK_PACKAGE_BACKLOG + STAGE3_PROGRESS
# Production: Common, ExchangeIn/Out/Query, Bonding, Info, DFPkg, Repo, Facets
# Tests: TrustFlags, Surface, Access, BondClaim, Donation, ProductLaw, IFacet

# Forge (orchestrator-owned; NOT executed)
# forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/adversarial/**' -vv
```

**Not run:** `forge` (hard rule 10). Critical CODE count = 0 → no L-SEC-3 runtime proof required this area.
