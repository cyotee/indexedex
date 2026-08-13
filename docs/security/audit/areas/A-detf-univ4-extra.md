# Security Audit — A-detf-univ4-extra

| Field | Value |
|-------|--------|
| Date | 2026-08-13 |
| Git SHA | `1e0d7c48` (`1e0d7c48eff8a883837996ae700426ac5397924b`) |
| Agent / run | Stage 1 product-area subagent · MODE=full · `A-detf-univ4-extra` |
| Status | **COMPLETE** |
| Production paths | `contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/**`; `…/orbital/**`; `…/stable/quad/curve/**`; `…/uniswap/v4/common/{nft,rebasing}/**` |
| Test paths | `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/{weighted,orbital,stable/quad/curve}/**`; fork `test/foundry/fork/base_main/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/**` |
| Skills cited | `SECURITY_AUDIT_PRD` §2, §2.4, §3.8, §5–8, §19; `crane-adversarial-testing`; `indexedex-adversarial-testing`; `indexedex-testing`; `ethskills-security`; `defi-incident-patterns`; family `*_PRD.md` (weighted / orbital / curve-quad); `docs/agent/INDEXEDEX_AGENT_LAW.md` DETF; `A-commons-pull` blast table (reserve-delta peers) |
| Residual-risk scores | Weighted **2** · Orbital **2** · Curve-quad **2** · UniV4DetfBondNft **2** · UniV4DetfRebasingClaim **2** |
| Forge | **Not run** (no Critical CODE claimed; L-SEC-3 runtime not required). Static re-read only. |
| Out of area | Hooks (`A-hooks-*`); Uni V4 SE vault (`A-se-univ4`); CP-single DETF (`A-detf-single-se`); shared `detf/common/{claimToken,bondNft}` (`A-detf-commons`) — cited as wiring only |

---

## 1. Executive summary

- **Residual-risk:** all five products **2**. Mint/bond `_pullToken` is **reserve-delta** (`U = B − R`) at this SHA — **not** live PAT-I-ABS on the helper (pilot commons blast confirmed; coverage-audit `T-basic` clone list is **stale** for these three DETF commons). Leftover High is **burn-path I1** (skips `_pullToken`), **missing catalog I/J/A0 proof**, **orbital missing PRD-locked `depositClaim`**, and **unused but deployable** Uni V4 bond-NFT / rebasing-claim packages with leftover `owner` + absolute-balance pull.
- **Critical / High counts:** **Critical 0** · **High 7** (3 CODE, 4 TEST). No leftover `diamondCut` / `owner()` on the **DETF diamonds** (package cuts + Crane base; L-SEC-11 statically clean). Uni V4 **common NFT/claim** packages **do** store an `owner` (intended DETF; CFG can pass an EOA).
- **Top recommended WPs (this program):**
  1. `WP-SEC-DETF-UV4-BURN-I1-001` — route burn through reserve-delta `_pullToken` (High CODE, all three DETFs).
  2. `WP-SEC-DETF-UV4-I-SUITE-001` — catalog `test_I1_*`/`I2`/`I3` on proxy (mint + bond + **burn**) (High TEST).
  3. `WP-SEC-DETF-UV4-J-001` — Target ⊆ facetFuncs ⊆ cuts ⊆ loupe ⊆ **proxy** (High TEST).
  4. `WP-SEC-DETF-UV4-A0-001` — `test_A0_*` first-bond / empty-supply residual (High TEST).
  5. `WP-SEC-DETF-UV4-NFT-001` — Uni V4 local NFT/claim: I-bar pull, A0 first deposit, leftover-admin / `tx.origin` (High CODE+TEST; packages unused by family DFPkgs but still in-scope).
- **OWNED_ELSEWHERE count:** **2** (`SEC-DETF-UV4-001` → `WP-I-CLONE-001` / `TCA-COMMON-004` for **clone-pull CODE** already reserve-delta; `SEC-DETF-UV4-010` → `WP-I-CLAIM-001` for **shared** `RebasingClaimToken` foreign-token I, not the Uni V4 local claim pkg). **Do not** open a competing `sec_fix_*` on `_pullToken` helper bodies.
- **Coverage-audit hole:** `T-detf-single-se` explicitly **omitted** weighted/orbital (and never named curve-quad). `WP-I-CLONE-001` listed “UniV4 DETFs” as blast; **helper CODE is closed** at this SHA; **burn skip + I/J/A0 tests are not** owned there.

---

## 2. Product inventory

| Product | DFPkg / Targets | TestBase | Deploy path | Residual risk |
|---------|-----------------|----------|-------------|---------------|
| **UniswapV4StandardExchangeWeightedDETF** | `UniswapV4StandardExchangeWeightedDETDFPkg.sol`; Facets: Exchange (2 sels), Bonding (4), Compound (10), Info (39); Targets: ExchangeIn/Out, Bonding, Compound, Info; Common+Repo | `TestBase_UniswapV4StandardExchangeWeightedDETF.sol` (CREATE3 facets + `indexedexManager.deploy*DFPkg` / `deployVault`; Weighted SE Buffer Hook via hook pkg) | **Gold.** Facets via FactoryService; DFPkg via manager registry. Hook mined in `postDeploy`. Bond NFT + rebasing claim = **shared DETF commons** (`IDetfSelfNftInventoryDFPkg` / `IRebasingClaimTokenDFPkg`), **not** Uni V4 local pkgs. | **2** |
| **UniswapV4StandardExchangeOrbitalDETF** | `UniswapV4StandardExchangeOrbitalDETDFPkg.sol`; Facets: Exchange (2), Bonding (9 — includes redeem/compound), Info (37). **No CompoundFacet.** No `depositClaim`. | `TestBase_UniswapV4StandardExchangeOrbitalDETF.sol` | Gold registry path; Orbital SE Buffer Hook in `postDeploy`. Same shared commons NFT/claim. | **2** |
| **UniswapV4StandardExchangeCurveQuadStableDETF** | `UniswapV4StandardExchangeCurveQuadStableDETDFPkg.sol`; Facets: Exchange (4 — incl. exact-out **InvalidRoute** stubs), Bonding (4), Compound (10), Info | `TestBase_UniswapV4StandardExchangeCurveQuadStableDETF.sol` | Gold registry path; Curve Quad hook. Same shared commons NFT/claim. One fork smoke: `…/fork/base_main/…/curve/UniswapV4StandardExchangeCurveQuadStableDETF_Fork.t.sol`. | **2** |
| **UniV4DetfBondNft** | `UniV4DetfBondNftDFPkg.sol`; Facet 21 sels; Target+Common+Repo | **None** under `test/**` | Crane `DIAMOND_FACTORY.deploy` (**not** vault registry). `PkgArgs.owner` persisted. **Not wired** by extra-family DFPkgs (they use `detf/common` NFT). | **2** |
| **UniV4DetfRebasingClaim** | `UniV4DetfRebasingClaimDFPkg.sol`; ERC20/2612/5267 + Claim Facet (15 sels) | **None** under `test/**` | Crane `DIAMOND_FACTORY.deploy` (not registry). `PkgArgs.owner` persisted. **Not wired** by extra-family DFPkgs. | **2** |

### 2.1 Every DFPkg in allowlist (closed)

| DFPkg | Path |
|-------|------|
| `UniswapV4StandardExchangeWeightedDETDFPkg` | `…/weighted/UniswapV4StandardExchangeWeightedDETDFPkg.sol` |
| `UniswapV4StandardExchangeOrbitalDETDFPkg` | `…/orbital/UniswapV4StandardExchangeOrbitalDETDFPkg.sol` |
| `UniswapV4StandardExchangeCurveQuadStableDETDFPkg` | `…/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableDETDFPkg.sol` |
| `UniV4DetfBondNftDFPkg` | `…/common/nft/UniV4DetfBondNftDFPkg.sol` |
| `UniV4DetfRebasingClaimDFPkg` | `…/common/rebasing/UniV4DetfRebasingClaimDFPkg.sol` |

No balancer-quad DETF under `stable/quad/` (curve only). No other `*DFPkg*.sol` in the allowlist.

### 2.2 Production file inventory (families)

| Path (per family) | Role |
|-------------------|------|
| `*DETDFPkg.sol` | Registry-gated `processArgs`; 8–9 facetCuts; `postDeploy` reserve hook + shared bond NFT + rebasing claim |
| `*ExchangeFacet.sol` / `*ExchangeInTarget.sol` | `exchangeIn` / `previewExchangeIn` (mint, burn-when-`tokenIn=detfToken`, SE passthrough) |
| `*ExchangeOutTarget.sol` | `_burnDetfExactIn` — **no public `exchangeOut`** |
| `*Facet.sol` (bonding) | `bond` overloads + sell/close (orbital also claim/compound) |
| `*CompoundFacet.sol` | Weighted + curve only: `depositClaim` / `redeemClaim` / `claimLiquidity` / compound + `NotSelf` externals |
| `*InfoFacet.sol` | views |
| `*Common.sol` | pricing, thresholds, join/exit, expansion, compound, **`_pullToken`**, hold-set sync |
| `*Repo.sol` | unique slots (weighted / orbital / curve-quad) |
| `*_FactoryService.sol` | CREATE3 helpers |
| `TestBase_*.sol` | gold TestBase (co-located under `contracts/`) |
| `*_PRD.md` + `*_IMPLEMENTATION_AND_TEST_PLAN.md` | family law |

### 2.3 Trust-flag / money entrypoints (three DETFs)

| Entrypoint | Flag | Credit path (this SHA) |
|------------|------|------------------------|
| `exchangeIn` mint | `pretransferred_` | `_settleToPairLeg` → **`_pullToken` reserve-delta** → join/mint `detfToken` |
| `exchangeIn` burn (`tokenIn == address(this)`) | `pretransferred_` | **`if (!pretransferred_) transferFrom`; then burn `address(this)`** — **no `_pullToken`** |
| SE passthrough | `pretransferred_` | `_pullToken` then nested push `true` to configured `underlyingVault` |
| `bond` first / later | `pretransferred_` | `_settleToPairLeg` → `_pullToken` |
| `depositClaim` (weighted + curve only) | `pretransferred_` | `_pullToken` / `_settleToPairLeg` |
| `redeemClaim` / `closeBondMature` / `sellPositionToDetfNft` | n/a | burn claim / sell mature NFT; DETF `_requireMature` |
| `compoundProtocolRewards` | n/a | permissionless; credits protocol NFT LP, not caller |
| `claimLiquidity` | n/a | gated `this` / bondNftVault / rebasingClaimToken |
| Exact-out (curve only) | n/a | **always `InvalidRoute`** (Phase 0; selectors present — J-complete) |
| `exchangeOut` | n/a | **no selector** (burn is `exchangeIn(detfToken, …)`) |

### 2.4 Uni V4 local NFT / claim (not family-wired)

| Entrypoint | Auth | Pull |
|------------|------|------|
| `openBond` / `openHookLpBond` | `_requireOwner` (stored `owner`) | `if (bal < amount) transferFrom(amount − bal)` — **absolute** |
| `closeBondMature` / `sellBond` / hook-LP twins | owner + caller∈{holder, owner} | LP/pair sent to `s.owner` |
| `claimRewards` | holder **or** `s.owner` | reward harvest |
| `initializeHookLpMode` | owner | sets `requireMatureForSell` (**can be false**) |
| `deposit` / `redeem` (claim) | **permissionless** | `safeTransferFrom` then `_depositBalancesIntoWings` (donations ride along) |
| `absorbBondProceeds` / `donateDetf` / `absorbHookLp` | owner | absolute `bal < amount` top-up |

### 2.5 Test roots

| Root | Role |
|------|------|
| Weighted `*_Core.t.sol` + NestedPush + Adversarial | H/N deploy/mint/bond/claim/expansion; **weak** `T_LOCAL_I1`; C mint only |
| Orbital `*_Deploy/FirstBond/MintBurn/Bond/Claim/Expansion/PolicyNotZap/NestedPush/Adversarial` | Same shape; **no `depositClaim` tests** (surface absent) |
| Curve `*_Core.t.sol` + Adversarial | Stronger C (mint/burn/bond/claim) + H atomicity + D pre-maturity; **no I/J/A0 names** |
| Fork curve DETF | one Base-main smoke |
| Uni V4 NFT / rebasing | **zero** `test/**` hits |

---

## 3. Threat models

### 3.1 UniswapV4StandardExchangeWeightedDETF

| Actor | Surface (fn) | Asset moved | Trust flags | Admin / oracle | Worst case |
|-------|--------------|-------------|-------------|----------------|------------|
| EXT | `exchangeIn` mint | pairToken / vaultShare → detfToken | `pretransferred` | fee oracle; Policy/Open | free mint from **booked** inventory (**blocked** by `_pullToken` when `R==B`) |
| EXT | `exchangeIn` burn | diamond detfToken inventory → pairToken / vaultShare | `pretransferred` | burn gate | **I1:** burn leftover/donated/`push`ed `detfToken` on diamond **without delivery** → extract protocol LP (`SEC-DETF-UV4-002`) |
| EXT | `bond` first | all externals → bond NFT + hook LP | `pretransferred`; `R=0` bootstrap | none | **A0:** pre-seeded pair inventory credited when `pretransferred=true` (`SEC-DETF-UV4-005`) |
| EXT | `bond` later | one pairToken → NFT | `pretransferred` | no mint gate | same I-bar as mint (helper OK) |
| EXT | `sellPositionToDetfNft` / `closeBondMature` | bond NFT → claim / capitalToken | maturity | none | pre-maturity exit (**blocked** `_requireMature`) |
| EXT | `depositClaim` / `redeemClaim` | pair / detfToken / claim | `pretransferred` on deposit | single-asset eligible | D2 without claim (**blocked** `burnShares`); H2 full-tx revert |
| EXT | `compoundProtocolRewards` | pending detfToken → protocol NFT LP | none | none | F5 skim to caller (**no**; protocol NFT only) |
| EXT | `claimLiquidity` | reserve hook LP | none | none | unprivileged (**`NotAuthorized`**) |
| EXT | `diamondCut` / `owner()` | whole diamond | n/a | n/a | leftover upgrade (**statically absent** on instance) |
| CAP | skew hook book + mint/burn | pairToken / detfToken | Open vs Policy | thresholds | Open seigniorage **ACCEPTED_RISK** with B1 invariants; Policy deadband |
| HOS | hostile `pairTokens[i]` via PkgArgs | same | pull | none | reenter mint/bond (**C `IsLocked`** — mint tested; burn/bond not on weighted) |
| INT | push + `pretransferred=true` | pair / vaultShare / detfToken | L-RSRV-CALLER | none | mint/bond: `claimed > U` → `TransferDeltaInsufficient`; burn: **no U check** |
| ADM | fee oracle `feeTo` / usage | fee slice | n/a | **manager/oracle** (out of area) | fee hike — `A-manager-fee-registry` |
| CFG | hostile share / Open / `minOut=0` | all | PkgArgs | deploy-time | Open seigniorage; hostile pair accepted |

### 3.2 UniswapV4StandardExchangeOrbitalDETF

Same as §3.1 with: dual-leg first bond; `rateAsset ∈ {pairToken0, pairToken1}`; **no `depositClaim`** (PRD §14.8 requires it — `SEC-DETF-UV4-008`); redeemClaim / claimLiquidity settle to `rateAsset` or pairs; close may pay single or dual capital.

### 3.3 UniswapV4StandardExchangeCurveQuadStableDETF

Same as §3.1 with: n=4 / m=3; `baseAmp` deploy-time; exact-out selectors **always `InvalidRoute`**; adversarial C covers mint/burn/bond/claim; **no I/J/A0**.

### 3.4 UniV4DetfBondNft

| Actor | Surface (fn) | Asset moved | Trust flags | Admin / oracle | Worst case |
|-------|--------------|-------------|-------------|----------------|------------|
| ADM / CFG | `openBond` / `openHookLpBond` | pairToken / detfToken / reserveLp | absolute `bal >= amount` | `PkgArgs.owner` | treat **pre-existing inventory** as delivered; EOA owner if CFG ≠ DETF |
| EXT | `claimRewards` | reward detfToken | holder or owner | owner | owner can harvest any bond |
| EXT | `sellBond` if `requireMatureForSell=false` | LP/pair to owner | flag | `initializeHookLpMode` | **pre-maturity principal migrate** (package-level; families enforce on DETF surface instead) |
| EXT | `tx.origin` recipient default | NFT assignment | `recipient=0` | none | phishing / unexpected holder |
| EXT | `diamondCut` | package diamond | n/a | Crane factory base | leftover cut if factory includes it (not in this pkg’s cuts) |

### 3.5 UniV4DetfRebasingClaim

| Actor | Surface (fn) | Asset moved | Trust flags | Admin / oracle | Worst case |
|-------|--------------|-------------|-------------|----------------|------------|
| EXT | `deposit` | pairToken / detfToken → claim shares | none (pull) | none | **A0:** `supply==0 \|\| preZap==0` mints `contribution`; prior donated inventory deposited via `_depositBalancesIntoWings` inflates first minter |
| EXT | `redeem` | claim → pairToken | none | none | D3 double redeem (**burn first**); preview uses zapOut (N2 drift vs execute ladder) |
| ADM | `absorbBondProceeds` / `donateDetf` | pair / detfToken | absolute top-up | owner | owner mints claim from already-sitting balances |
| CFG | `PkgArgs.owner` EOA | all privileged | n/a | leftover admin | CROPS-S if not DETF |

---

## 4. Catalog matrix (A–O, E6, F5)

| ID | Product | F/P/G/N/A/VULN | Evidence |
|----|---------|----------------|----------|
| A1 | W/O/Q | **P** | Donation → unbooked `U`; next `pretransferred` mint/bond may credit. No `test_A1_*`. |
| A2 | W/O/Q | **VULN** | Donate `detfToken` then `exchangeIn(detfToken, …, pretransferred=true)` burns diamond inventory. → `SEC-DETF-UV4-002` |
| A3 | W/O/Q | **P** | Hook LP on NFT/claim pkgs; D2-class redeem without claim not catalog-tested (curve/weighted have redeem happy paths). |
| A4–A5 | all | **N/A** | Deferred P2. |
| **A0** | W/O/Q | **G** | **No `test_A0_*`.** Inert until first bond; `_pullToken` with `R=0` ⇒ `U=B`. First `pretransferred` bond can consume pre-seeded pair inventory. → `SEC-DETF-UV4-005` |
| **A0** | UniV4 claim | **VULN** | `_mintFromContribution`: `supply==0 \|\| preZapOut==0` → mint `contribution`; `deposit` dumps **all** balances into wings first. → `SEC-DETF-UV4-007` |
| B1 | W/O/Q | **P** | Policy mint/burn gate tests exist (weighted/orbital/curve Core). No catalog `test_B1_*` skew-extract bounds. Open = ACCEPTED_RISK. |
| B3 | W/O/Q | **P** | `test_policy_mint_blocked_*` / burn-allowed. Not catalog-named. |
| C1–C3 | W | **P** | Mint reentrancy `IsLocked` only. |
| C1–C3 | O | **P** | Mint + burn-path transfer reentry (hostile pair on residual). |
| C1–C3 | Q | **F** | Mint / burn / bond / claim `IsLocked`. |
| C* | NFT/claim | **P** | `nonReentrant` on money; **no tests**. |
| D2 | W/Q | **P** | Redeem requires `burnShares`; no `test_D2_*`. |
| D2 | O | **P** | Redeem exists; no D2 name. |
| D3 | W/O/Q | **G** | No double-redeem test. |
| D6 | W/O/Q | **F** | Pre-maturity sell/close revert (`test_matureOnly_*` / `test_preMaturity_*`). |
| E1 | W/O/Q | **P** | Preview≡exec mint/burn few-wei (weighted/orbital). Not conservation-named. |
| E5 | W/O/Q | **P** | Zero/deadline via `_requireActive`; not catalog-named. |
| **E6** | W/O/Q | **F** | First-bond excess refund is **this-call unused** (`pairNatives − needed`). Not `balance − floor`. |
| **E6** | NFT/claim | **N/A** | No surplus-refund-to-caller. Close sends to `owner`. |
| F1 | W/O/Q | **P** | Static: package `facetCuts` have **no** DiamondCut/Ownable. **No `test_F1_*`.** → Medium TEST |
| F1 | NFT/claim | **VULN** | Persistent `owner`; CFG EOA. → `SEC-DETF-UV4-006/007` |
| F2–F3 | W/O/Q | **P** | Shared NFT/claim onlyOwner is **commons** (`A-detf-commons` / `WP-I-CLAIM-001`). Family `claimRewards` is holder-only. |
| F4 | W/O/Q | **F** | Weights / amp / binding immutable after deploy. |
| **F5** | W/O/Q | **F** | `compoundProtocolRewards` permissionless; credits **protocol NFT**, not caller. `claimLiquidity` auth-gated. `NotSelf` on atomic/redeposit/swap. |
| G1 | W/O | **P** | NestedPush suite vs host SE/hook (not MultiVault-nested DETF). |
| G1 | Q | **G** | No NestedPush tree. |
| H2 | Q | **F** | `test_burn_atomicRevert_leavesDetfUnburned`. |
| H2 | W/O | **P** | Orbital `test_burn_redeposit_atomicity_or_success` happy-only. |
| H3 | W/O/Q | **P** | minOut on burn/claim; residual not systematically asserted. |
| **I1** mint/bond | W/O | **P** | Helper reserve-delta. `test_T_LOCAL_I1_*` is **I2-shaped** (`U+1`) + bare `expectRevert` — **PAT-THEATER-PRE**. Nested `T_NEST_3` is **host** I1, not DETF. |
| **I1** mint/bond | Q | **G** | Helper OK; **no I1 test**. |
| **I1** burn | W/O/Q | **VULN** | Skip `_pullToken`. → `SEC-DETF-UV4-002` |
| **I1** NFT/claim | NFT/claim | **VULN** | Absolute `bal < amt` top-up. → `SEC-DETF-UV4-006` |
| **I2** | W/O/Q | **P** | Helper `TransferDeltaInsufficient(claimed, U)`. No `test_I2_*`. |
| **I3** | W/O/Q | **G** | End-sync exists (`_syncAllExpectedHoldReserves`). No second-`true` test. |
| I4 | W/O/Q | **N/A** | FoT pair forbidden by family PRD / hook. |
| I5 | all | **N/A** | No Permit2 money path (ERC-2612 share permit only). |
| **J1–J3** | W/O/Q | **G** | No Surface / IFacet suite. FacetFuncs look complete vs interfaces (curve exact-out stubs **present**). Orbital **no** `depositClaim` in interface — not J-omit, spec hole. |
| **J1–J3** | NFT/claim | **P** | FacetFuncs cover interface except Bond NFT `updateGlobalRewards()` public Target fn **omitted** (view-adjacent). **No tests.** |
| J4 | all | **P** | DFPkg `facetCuts` bind `facetFuncs()`. No length test. |
| **K1** | W/O/Q | **P** | End-sync after money routes. Donation funds `U` until sync (L-RSRV-DUST). No `test_K1_*`. |
| L1 | W/O/Q | **P** | No public skim. Burn prices protocol LP / effectiveSupply. Residual dust may stay on diamond (PRD-documented). |
| L2 | W/O/Q | **N/A** | FoT pair forbidden. |
| L3 | W/O/Q | **P** | Policy synthetic vs hook book; no invariant handler. |
| M1–M3 | W/O/Q | **N/A** | No user `target+calldata`. Nested call = configured `underlyingVault`. |
| N1 | W/O/Q | **P** | Hook callbacks under outer `nonReentrant`. No dedicated TOCTOU suite. |
| N2 | W/O | **P** | Mint/burn preview≡exec tests. **No** previewBond / previewRedeemClaim / previewClose (PRD LOCKED “every path has preview”). |
| N2 | Q | **P** | Same; exact-out preview N/A (`InvalidRoute`). |
| N2 | claim pkg | **P** | `previewDeposit` approximates swap; execute zaps wings. |
| O1–O3 | all | **N/A** | No product permit money path. |

**P0 DETF subset:** D6 **F**; C **P/F**; I1 mint **P/G**, I1 burn **VULN**; J **G**; A0 **G/VULN**; E6 **F**; F5 **F**.

---

## 5. Domain notes

Walked locally (evm-audit domains as hunt lists; ship-gate remains Crane DoD):

| Domain | Notes |
|--------|--------|
| **general** | Closed-form exact-in; curve exact-out `InvalidRoute`; CEI + `nonReentrant`; `try/catch` only on best-effort compound / expansion / first-bond NFT init / close fallback. |
| **precision-math** | WAD + hook SoT; burn `lpOut = burnPrincipal * protocolLp / effectiveSupply` (includes pending expansion, **does not realize**). Weighted first-bond sizes join by min creation-rate DETF; refunds excess. |
| **erc20** | `BetterSafeERC20`; mint/bond pull FoT-safe on `false`. Burn `true` ignores delta. |
| **erc4626** | detfToken is diamond ERC-20. Shared rebasing claim is 4626-like (**commons**). Uni V4 local claim is custom zap-share. |
| **defi-amm** | Pricing = Weighted / Orbital / Curve-quad **SE buffer hook** book + optional SE rate providers. Spot skew = B1. |
| **proxies** | Crane MinimalDiamond + package cuts. Unique repo slots. No DiamondCut in family DFPkg cuts. Uni V4 NFT/claim: one/four facet cuts + factory base. |
| **access-control** | DETF instance unowned. `claimLiquidity` allowlist. Compound atomic `NotSelf`. NFT/claim `owner` leftover if standalone. |
| **oracles** | Thresholds deploy-time; fees via fee oracle (blast → manager). Synthetic from whole-reserve FD, not spot-only. |
| **flashloans** | CAP skew = B1; Open seigniorage accepted. |
| **dos** | minOut / deadline / first-bond full-book floors. Registry `isDisabled` bricks mint/bond (`_requireNotDisabled` on bond; `_requireActive` includes disable). Walkaway: live users can still burn/sell-mature/redeem if disable only gates new bond — **needs confirm on `_requireActive` for burn**. Weighted `_requireActive` is used on mint/burn/depositClaim; **registry disable can freeze burn/claim** (CROPS-P — Medium; manager area). |
| **erc721** | Families use **shared** DETFNFTVault (commons). Uni V4 local NFT is **not ERC-721** (mapping `ownerOf` only). Maturity gated on DETF. |
| **CROPS** | DETF walkaway: mint/burn/bond/sell-mature/redeem without team **if not disabled**. Fee oracle residual trust. Uni V4 local pkgs: leftover owner. **L-SEC-11 leftover admin on DETF diamonds: statically absent.** |
| **sharp-edges** | `pretransferred` caller-supplied. PkgArgs zeros → Policy + 1.05/0.95 + expansion defaults. `minOut=0` in tests. Hostile pair accepted if CFG deploys. NFT `requireMatureForSell` optional. `tx.origin` recipient. |
| **spec** | Sell/close only after maturity — **code matches** (`_requireMature`). Compound public + skip if not single-asset — matches. **Orbital PRD §14.8 direct claim** — **code missing** (`SEC-DETF-UV4-008`). PRD “share Uni V4 common NFT/claim” vs code using **`detf/common`** packages — **NEEDS_OWNER** (families function; local pkgs orphan). Weighted/curve previews-for-every-path — **not implemented**. |
| **incidents** | A0 empty/pre-live; I trust-flag (helper fixed, burn live); L1 skim (no public reclaim); E6 (first-bond refund this-call); F5 (compound does not pay caller); leftover admin (NFT/claim). |

---

## 6. Findings

### 6.1 [SEC-DETF-UV4-001] — Clone `_pullToken` already reserve-delta

| Field | Value |
|-------|--------|
| **FINDING_ID** | SEC-DETF-UV4-001 |
| **Title** | Historical PAT-I-ABS on family `_pullToken` (re-verified closed) |
| **Severity** | Info (was coverage Blocker class) |
| **Class** | **OWNED_ELSEWHERE** |
| **Confidence** | static-high (re-read at `1e0d7c48`) |
| **Catalog IDs** | I1–I3 |
| **Pattern IDs** | PAT-I-ABS |
| **EVM-audit domain** | erc20 |
| **CROPS pillar** | n/a |
| **Incident theme** | trust-flag free mint |
| **Products** | Weighted, Orbital, Curve-quad DETFs |
| **Blast radius** | family commons only (same helper shape as MultiVault / CP-single) |
| **Attacker** | n/a |
| **Impact** | None remaining on **mint/bond/passthrough/depositClaim** when `R==B` |
| **Evidence** | `UniswapV4StandardExchangeWeightedDETFCommon.sol` 811–822; Orbital 743–754; Curve-quad 815–826: `U = B0 − R`; `amount_ > U` → `TransferDeltaInsufficient`; pull-false returns `balance − B0`. Pilot `A-commons-pull` §2.2.A lists these three as reserve-delta peers. Coverage `T-basic` §2.3.B “`if (pretransferred_) return amount_`” is **stale**. `WP-I-CLONE-001` / `TCA-COMMON-004`. |
| **Recommended TEST** | none new for helper CODE — I-suite is `SEC-DETF-UV4-003` |
| **Anti-theater** | n/a |
| **Suggested WP-ID** | none — **do not** open `sec_fix_*` on helper bodies |
| **Link TCA / prior** | TCA-COMMON-004, WP-I-CLONE-001 |
| **Depends / parallel** | n/a |

### 6.2 [SEC-DETF-UV4-002] — Burn path skips reserve-delta pull

| Field | Value |
|-------|--------|
| **FINDING_ID** | SEC-DETF-UV4-002 |
| **Title** | `exchangeIn` burn credits `pretransferred` without `_pullToken` |
| **Severity** | **High** |
| **Class** | **CODE** |
| **Confidence** | static-high · **RUNTIME_UNPROVEN** |
| **Catalog IDs** | I1, I3, A2 |
| **Pattern IDs** | PAT-I-ABS, PAT-THEATER-PRE |
| **EVM-audit domain** | erc20 |
| **CROPS pillar** | n/a |
| **Incident theme** | trust-flag free extract / donation skim |
| **Products** | Weighted, Orbital, Curve-quad DETFs |
| **Blast radius** | all three `*ExchangeOutTarget._burnDetfExactIn`; same class as commons `_secureSelfBurn` / historical MultiVault burn |
| **Attacker** | EXT / INT / CAP |
| **Attack scenario** | 1. DETF live with protocol hook LP. 2. Diamond holds `detfToken` (donation, two-tx victim push, or leftover after redeposit). 3. Attacker `exchangeIn(detfToken, amount, pairToken, minOut=0, attacker, pretransferred=true, deadline)`. 4. No `transferFrom`; `_takeBurnUsageFee` pays fee from diamond inventory; `_burnDetf(address(this), …)` burns that inventory; `_burnAndRemoveProtocolLp` pays attacker pairToken. |
| **Preconditions** | Live reserve + `protocolLp > 0` + diamond `detfToken` balance ≥ claimed (not necessarily attacker-owned). |
| **Impact** | Extract protocol LP (and usage-fee slice to `feeTo`) by burning **non-attacker** `detfToken` sitting on the diamond. Frontrun of a victim two-tx burn. |
| **Evidence** | Weighted `UniswapV4StandardExchangeWeightedDETFExchangeOutTarget.sol` 51–57; Orbital `…ExchangeOutTarget.sol` 55–59; Curve `…ExchangeOutTarget.sol` 51–55: `if (!pretransferred_) safeTransferFrom; … _takeBurnUsageFee(detfIn_); _burnAndRemoveProtocolLp`. Contrast mint: ExchangeInTarget `_settleToPairLeg` / `_pullToken`. MultiVault gold burn **does** call `_pullToken`. |
| **Runtime** | not run · High max without proof (L-SEC-3) |
| **Recommended CODE** | Call `_pullToken(IERC20(address(this)), detfIn_, pretransferred_)` (or unbooked-share equivalent) **before** fee/burn; credit/burn only measured `U`. |
| **Recommended TEST** | `test_I1_pretransferred_burn_bookedDetfInventory_revertsDelta0` on production proxy: mint, sync (`R==B` for detfToken), **no** transfer, `pretransferred=true` → `TransferDeltaInsufficient(claimed, 0)`; attacker pairToken unchanged. Also I1 donate-then-burn after sync; I3 second burn. |
| **Anti-theater** | Must **not** transfer detfToken in the I1 setup. Bare `expectRevert()` insufficient — exact selector + args. Do not only test `pretransferred=false`. |
| **Suggested WP-ID** | `WP-SEC-DETF-UV4-BURN-I1-001` |
| **Link TCA / prior** | related class TCA-DETF-SSE burn skip; **not** owned by `WP-I-CLONE-001` (helper already fixed; this is a **missing call**) |
| **Depends / parallel** | parallel with I-suite TEST after CODE; serial on each family’s `*ExchangeOutTarget.sol` |

### 6.3 [SEC-DETF-UV4-003] — Catalog I1–I3 tests missing / theater

| Field | Value |
|-------|--------|
| **FINDING_ID** | SEC-DETF-UV4-003 |
| **Title** | No ship-gate `test_I1_*`/`I2`/`I3` on extra Uni V4 DETFs |
| **Severity** | **High** |
| **Class** | **TEST** |
| **Confidence** | confirmed (file inventory) |
| **Catalog IDs** | I1–I3 |
| **Pattern IDs** | PAT-THEATER-PRE |
| **EVM-audit domain** | erc20 |
| **CROPS pillar** | n/a |
| **Incident theme** | none |
| **Products** | Weighted, Orbital, Curve-quad |
| **Blast radius** | tests only |
| **Attacker** | n/a |
| **Attack scenario** | n/a (proof gap) |
| **Preconditions** | n/a |
| **Impact** | Cannot claim “I-bar green”; hides `SEC-DETF-UV4-002`. |
| **Evidence** | `rg test_I1` under extra-family test trees: **no matches**. Weighted/Orbital `test_T_LOCAL_I1_bookedDetf_trueWithoutPushReverts` claims `U+1` (I2) with **bare** `expectRevert()` after mint — not booked `R==B` + zero transfer of claimed amount. `T_NEST_3` is **host hook/SE** I1. Curve: no NestedPush I tests. Adversarial files: C + empty LP only. |
| **Recommended TEST** | Port MultiVault `Adversarial_TrustFlags.t.sol` I1/I2/I3 for mint, later-bond, first-bond (pre-live `R=0` documented), **burn**, and `depositClaim` (W/Q). |
| **Anti-theater** | I1 must not transfer; exact `TransferDeltaInsufficient(claimed, 0)`; call **proxy**. |
| **Suggested WP-ID** | `WP-SEC-DETF-UV4-I-SUITE-001` |
| **Link TCA / prior** | none (omitted from `T-detf-single-se`) |
| **Depends / parallel** | depends on `WP-SEC-DETF-UV4-BURN-I1-001` for burn I1 green; mint/bond I tests can start now |

### 6.4 [SEC-DETF-UV4-004] — J1–J3 surface proof missing

| Field | Value |
|-------|--------|
| **FINDING_ID** | SEC-DETF-UV4-004 |
| **Title** | No Target ⊆ facetFuncs ⊆ loupe ⊆ proxy suite |
| **Severity** | **High** |
| **Class** | **TEST** |
| **Confidence** | confirmed |
| **Catalog IDs** | J1–J4 |
| **Pattern IDs** | PAT-THEATER-FACET |
| **EVM-audit domain** | proxies |
| **CROPS pillar** | n/a |
| **Incident theme** | none |
| **Products** | Weighted, Orbital, Curve-quad (+ NFT/claim pkgs) |
| **Blast radius** | tests; static facetFuncs vs interfaces look complete for **declared** API |
| **Attacker** | n/a |
| **Impact** | Silent omitted money/view selector would not fail CI. |
| **Evidence** | No `Adversarial_Surface.t.sol` / `*IFacet.t.sol` under extra-family tests. Static: Weighted Exchange 2, Bonding 4, Compound 10, Info 39; Orbital Exchange 2, Bonding 9, Info 37; Curve Exchange 4 (exact-out stubs), Bonding 4, Compound 10. NFT `updateGlobalRewards()` on Target **not** in `facetFuncs` (21). |
| **Recommended TEST** | `test_J1_targetSelectors_subseteq_facetFuncs` (control from **interface/Target**, not Facet source); `test_J2_facetFuncs_subseteq_loupe_onProxy`; `test_J3_*` smoke each money selector on **proxy** (incl. `exchangeIn` burn, `InvalidRoute` exact-out, `redeemClaim`, `compoundProtocolRewards`). |
| **Anti-theater** | J3 must call proxy, not facet impl. Do not copy control list from Facet. |
| **Suggested WP-ID** | `WP-SEC-DETF-UV4-J-001` |
| **Link TCA / prior** | none |
| **Depends / parallel** | parallel with I-suite |

### 6.5 [SEC-DETF-UV4-005] — A0 untested; first-bond pretransfer at `R=0`

| Field | Value |
|-------|--------|
| **FINDING_ID** | SEC-DETF-UV4-005 |
| **Title** | Empty / pre-live residual can fund first `pretransferred` bond |
| **Severity** | **High** |
| **Class** | **TEST** (CODE sketch if product law forbids first-mover drain) |
| **Confidence** | static-high · RUNTIME_UNPROVEN for victim-loss |
| **Catalog IDs** | A0, I1 |
| **Pattern IDs** | PAT-A0-EMPTY |
| **EVM-audit domain** | erc4626 / general |
| **CROPS pillar** | n/a |
| **Incident theme** | empty-vault first depositor |
| **Products** | Weighted, Orbital, Curve-quad |
| **Blast radius** | first-bond `_settleToPairLeg` while MultiAsset `R=0` after `_initialize` |
| **Attacker** | EXT |
| **Attack scenario** | 1. Deploy inert DETF. 2. Victim (or protocol) transfers pairToken to diamond. 3. Attacker `bond(..., pretransferred=true)` claiming `U=B`. 4. First bond goes live; attacker receives NFT/shares sized from victim inventory; excess refunded to attacker. |
| **Preconditions** | Residual pairToken on inert instance; attacker uses `pretransferred=true`. `pretransferred=false` credits **pull delta only** (donation stays idle until end-sync). |
| **Impact** | First bonder drains pre-seeded pair inventory into a live bond. Agent-law A0. |
| **Evidence** | No `test_A0_*`. `_pullToken` `U = B0 − R` with post-init `R=0`. No `initializeReserve`. Weighted `_firstBond` 97–98 settles via `_pullToken`. Product law: inert until first bond; A0 = first minter cannot free-drain pre-seeded inventory. Commons bootstrap `R=0` is documented absorb — **DETF first bond is the go-live**, so this is the A0 surface. |
| **Recommended CODE** | If law is hard A0: reject `pretransferred` on first bond, or snapshot/sync `R:=B` at end of `postDeploy` (still 0) **and** treat pre-live unbooked as non-credit (force pull-false / ignore `U` until live). Else document ACCEPTED_RISK + test. |
| **Recommended TEST** | `test_A0_preLive_donatePair_pretransferredBond_cannotMintFromResidual` (or documented absorb with victim-balance invariant). Also `test_A0_preLive_pullFalse_doesNotCreditDonation`. |
| **Anti-theater** | Seed residual **without** attacker transferFrom; assert attacker NFT/shares **or** revert; do not only test inert mint revert. |
| **Suggested WP-ID** | `WP-SEC-DETF-UV4-A0-001` |
| **Link TCA / prior** | none |
| **Depends / parallel** | NEEDS_OWNER if absorb vs revert is product choice; else CODE+TEST |

### 6.6 [SEC-DETF-UV4-006] — UniV4DetfBondNft leftover owner + absolute pull

| Field | Value |
|-------|--------|
| **FINDING_ID** | SEC-DETF-UV4-006 |
| **Title** | Standalone Uni V4 bond NFT: owner-gated absolute pull, `tx.origin`, optional mature-sell |
| **Severity** | **High** |
| **Class** | **CODE** |
| **Confidence** | static-high · RUNTIME_UNPROVEN |
| **Catalog IDs** | I1, D, F1, A0 |
| **Pattern IDs** | PAT-I-ABS, PAT-CROPS-ADMIN, PAT-SHARP-FLAG |
| **EVM-audit domain** | access-control / erc20 / erc721 |
| **CROPS pillar** | S / O |
| **Incident theme** | leftover admin; trust-flag |
| **Products** | UniV4DetfBondNft |
| **Blast radius** | `…/common/nft/**` only. **Not** used by extra-family DFPkgs (they deploy `detf/common` DETFNFTVault). Still deployable via `UniV4DetfBondNftDFPkg.deployBondNft`. |
| **Attacker** | CFG / ADM / EXT |
| **Attack scenario** | 1. CFG deploys with `owner = EOA`. 2. `openBond` treats `pairToken.balanceOf(this) >= pairAmountForLp` as delivery (no delta). 3. `recipient=0` assigns NFT to `tx.origin`. 4. `initializeHookLpMode(lp, requireMatureForSell=false)` allows `sellBond` before unlock. |
| **Preconditions** | Package actually deployed (families do not today). |
| **Impact** | Free credit of inventory as bond principal; phishing recipient; pre-maturity principal if flag off; EOA can open/close/sell all bonds. |
| **Evidence** | `UniV4DetfBondNftTarget.sol` 33–51 (`_requireOwner`; `if (bal < amt) transferFrom(amt-bal)`); 35 `tx.origin`; 153–155 `requireMatureForSell` optional; Repo `owner` + `_requireOwner`. Facet omits `updateGlobalRewards`. **Zero tests.** |
| **Recommended CODE** | If product is live-path: delta pull; no `tx.origin`; force mature-sell; owner must be DETF and non-EOA (or strip). If abandoned: do not deploy; document DEFER. Stage 2 / owner: **NEEDS_OWNER** on keep-vs-delete. |
| **Recommended TEST** | If kept: I1 openBond booked inventory; F1 owner≠DETF revert or documented; mature-sell default true + pre-maturity revert; J1–J3. |
| **Anti-theater** | Deploy via FactoryService, not mock Target. |
| **Suggested WP-ID** | `WP-SEC-DETF-UV4-NFT-001` |
| **Link TCA / prior** | none (not in `T-detf-single-se`) |
| **Depends / parallel** | pair with `SEC-DETF-UV4-007` same worktree |

### 6.7 [SEC-DETF-UV4-007] — UniV4DetfRebasingClaim first-deposit A0 + owner

| Field | Value |
|-------|--------|
| **FINDING_ID** | SEC-DETF-UV4-007 |
| **Title** | Uni V4 rebasing claim: empty-supply mint from donated inventory; leftover owner |
| **Severity** | **High** |
| **Class** | **CODE** |
| **Confidence** | static-high · RUNTIME_UNPROVEN |
| **Catalog IDs** | A0, A1, F1, I1 |
| **Pattern IDs** | PAT-A0-EMPTY, PAT-CROPS-ADMIN, PAT-I-ABS (absorb paths) |
| **EVM-audit domain** | erc20 / erc4626 |
| **CROPS pillar** | S |
| **Incident theme** | empty-vault inflation |
| **Products** | UniV4DetfRebasingClaim |
| **Blast radius** | `…/common/rebasing/**`. Unused by family DFPkgs (`IRebasingClaimTokenDFPkg` instead). Deployable via `deployClaim`. |
| **Attacker** | EXT / ADM / CFG |
| **Attack scenario** | 1. Donate pairToken/detfToken to claim diamond (`supply==0`). 2. Attacker `deposit` tiny amount. 3. `_depositBalancesIntoWings` consumes **all** balances; `_mintFromContribution` if `supply==0 \|\| pre==0` mints full `post−pre` (includes donation). 4. `redeem` drains zapOut. Owner `absorbBondProceeds` same absolute top-up. |
| **Preconditions** | Package deployed; first deposit / zero zapOut. |
| **Impact** | First depositor (or owner absorb) captures donated / pre-seeded inventory as claim shares. |
| **Evidence** | `UniV4DetfRebasingClaimTarget.sol` 26–41 (`deposit` permissionless; transferFrom then deposit **all** balances); 530–544 `_mintFromContribution`; 99–121 absorb absolute pull; Repo `owner`. **Zero tests.** Shared-claim I (`WP-I-CLAIM-001`) does **not** cover this package. |
| **Recommended CODE** | Credit only same-tx inbound delta; first-deposit virtual shares / dead shares; owner = DETF only. |
| **Recommended TEST** | `test_A0_donateThenFirstDeposit_noFreeMint`; I1 absorb booked; F1 EOA owner. |
| **Anti-theater** | Real package proxy; do not mock `_zapOutToPair`. |
| **Suggested WP-ID** | `WP-SEC-DETF-UV4-NFT-001` (same worktree as 006) |
| **Link TCA / prior** | **not** WP-I-CLAIM-001 (different SUT) |
| **Depends / parallel** | with 006 |

### 6.8 [SEC-DETF-UV4-008] — Orbital missing PRD-locked `depositClaim`

| Field | Value |
|-------|--------|
| **FINDING_ID** | SEC-DETF-UV4-008 |
| **Title** | Orbital DETF has no direct claim-deposit surface |
| **Severity** | **High** |
| **Class** | **CODE** |
| **Confidence** | confirmed (interface + facetFuncs) |
| **Catalog IDs** | D, J (n/a — never declared), PAT-SPEC-DRIFT |
| **Pattern IDs** | PAT-SPEC-DRIFT |
| **EVM-audit domain** | general |
| **CROPS pillar** | n/a |
| **Incident theme** | none |
| **Products** | UniswapV4StandardExchangeOrbitalDETF |
| **Blast radius** | orbital BondingTarget / interface / Facet |
| **Attacker** | n/a (missing user path) |
| **Attack scenario** | User cannot deposit pairToken / detfToken into rebasing claim except by **selling a mature bond**. PRD §14.8 “Direct claim — pair/SE or free DETF via depositSingle”. Weighted/curve implement `depositClaim`. |
| **Preconditions** | n/a |
| **Impact** | Spec/code divergence; claim package only reachable via sell. Not a steal; product-incomplete money API. **Not** Critical (not a silent omit of a declared Target fn). |
| **Evidence** | `IUniswapV4StandardExchangeOrbitalDETF.sol` has `redeemClaim` / `claimLiquidity` only. BondingTarget 367–383 redeem only. Orbital PRD ~740 flow 8. Weighted interface 114–121 `depositClaim`. |
| **Recommended CODE** | Add `depositClaim` peer to weighted/curve (or amend PRD via `S-spec-detf` / NEEDS_OWNER). |
| **Recommended TEST** | `test_depositClaim_pair_mintsClaim` / free detfToken / not-zap revert — after surface exists. |
| **Anti-theater** | Must hit proxy; revert if not zap-eligible (do not copy compound skip). |
| **Suggested WP-ID** | `WP-SEC-DETF-UV4-ORB-CLAIM-001` |
| **Link TCA / prior** | none |
| **Depends / parallel** | `S-spec-detf` may reclass NEEDS_OWNER |

### 6.9 Clustered Medium / Low (not full High schema)

| ID | Sev | Class | Title | Evidence |
|----|-----|-------|-------|----------|
| SEC-DETF-UV4-009 | Medium | THEATER | `T_LOCAL_I1` / curve `test_emptyProtocolLp_burn` cannot fail I1 | `U+1` + bare revert; curve `if (free_==0) return` / `if (protocolLp()==0)` optional path |
| SEC-DETF-UV4-010 | Info | OWNED_ELSEWHERE | Shared rebasing claim I (foreign token) | Families wire `IRebasingClaimTokenDFPkg` → `WP-I-CLAIM-001` / `A-detf-commons` |
| SEC-DETF-UV4-011 | Medium | TEST | No `test_F1_*` leftover-admin on DETF proxy | Static cuts clean; MultiVault F1 theater lesson — loupe `diamondCut==0` + no `owner()` |
| SEC-DETF-UV4-012 | Medium | CODE | PRD-locked previews missing (bond/claim/close) | Weighted PRD §12 “every closed-form path exposes preview”; only `previewExchangeIn` |
| SEC-DETF-UV4-013 | Medium | NEEDS_OWNER | PRD says share Uni V4 `common/{nft,rebasing}`; code uses `detf/common` | Family DFPkgs `_deployBondNftVault` / `_deployRebasingClaimToken`. Local pkgs orphan. |
| SEC-DETF-UV4-014 | Low | CODE | Bond NFT `updateGlobalRewards` omitted from `facetFuncs` | Target public; Facet 21 sels. Permissionless snapshot if added. |
| SEC-DETF-UV4-015 | Medium | CROPS / TEST | Registry disable via `_requireActive` can freeze burn/claim | Confirm `_requireNotDisabled` on burn; walkaway if manager disappears |
| SEC-DETF-UV4-016 | Info | ACCEPTED_RISK | Open-threshold seigniorage; L-RSRV-DUST unbooked `U` | Policy tests exist; Open = documented |

---

## 7. Theater / false confidence

| Test / control | Why it cannot catch the bug | Fix |
|----------------|----------------------------|-----|
| Weighted/Orbital `test_T_LOCAL_I1_bookedDetf_trueWithoutPushReverts` | Claims `U+1` (I2) after mint; bare `expectRevert()`; does not prove booked `R==B` + zero transfer of a **creditable** claimed amount; does not cover **burn** | Replace with catalog `test_I1_*` / `test_I2_*` |
| `test_T_NEST_3_nestedI1_*` | Host hook/SE I1, not DETF `_pullToken` | Keep as nested; add DETF I1 |
| Weighted/Orbital adversarial only mint `IsLocked` + empty protocol LP | No I/J/A0/D2/E1 catalog | Port MultiVault adversarial layout |
| Curve `test_emptyProtocolLp_burn_reverts` | Early `return` if no free detfToken; `if (protocolLp()==0)` optional; bare `expectRevert()` | Force empty LP + exact selector |
| Core happy `pretransferred=false` mint/bond | PAT-THEATER-PRE | I1–I3 |
| Facet `facetFuncs` length comments | No Target-derived J1 / proxy J3 | Surface suite |
| Coverage-audit “UniV4 DETF `_pullToken` is blind return” | Stale vs SHA helper | Cite this report; do not re-fix helper |

---

## 8. Coverage-audit linkage

| TCA / WP | Same touch-set? | Action |
|----------|-----------------|--------|
| `WP-I-CLONE-001` / `TCA-COMMON-004` | **Helper `_pullToken` CODE** on UniV4 DETF commons — **already reserve-delta** | **OWNED_ELSEWHERE** — no `sec_fix_*` on helper |
| `WP-I-DETF-SSE-*` / `WP-I-DETF-SSE-CP-001` / `WP-I-DETF-SSE-UV4-001` | CP-single / Balancer single / legacy single | **Not this area** (`A-detf-single-se`) |
| `WP-I-CLAIM-001` | Shared `RebasingClaimToken` foreign I | **OWNED_ELSEWHERE** for family-wired claim; **not** Uni V4 local claim pkg |
| `WP-J-DETF-SSE-*` / `WP-J-DETF-MV-001` | Other families’ J suites | no |
| `T-detf-single-se` | Explicitly **out of scope** orbital/weighted | extra families were **omitted** — new I/J/A0 WPs here |
| `WP-I-CLONE-001` burn skip | WP text is clone **helpers**, not missing burn call | **still new** `SEC-DETF-UV4-002` |

---

## 9. Work package stubs

### 9.1 WP-SEC-DETF-UV4-BURN-I1-001

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-DETF-UV4-BURN-I1-001` |
| **Title** | Route extra Uni V4 DETF burn through reserve-delta `_pullToken` |
| **Severity** | High |
| **Class** | BOTH |
| **Products** | Weighted, Orbital, Curve-quad DETFs |
| **Finding IDs** | SEC-DETF-UV4-002 |
| **Problem** | Burn `pretransferred=true` skips `_pullToken` and burns diamond `detfToken` inventory. Mint/bond helper is already reserve-delta. |
| **Production files (touch set)** | `…/weighted/UniswapV4StandardExchangeWeightedDETFExchangeOutTarget.sol`; `…/orbital/UniswapV4StandardExchangeOrbitalDETFExchangeOutTarget.sol`; `…/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableDETFExchangeOutTarget.sol` |
| **Test files (touch set)** | new or extend `…/adversarial/` I-burn tests on each TestBase |
| **Out of scope files** | `_pullToken` helper bodies; hooks; CP-single |
| **Depends on** | none (helper already correct) |
| **Parallelizable with** | J-suite, A0 TEST, NFT WP (disjoint files) |
| **Conflicts with coverage-audit WP** | none (`WP-I-CLONE-001` is helper, not this call site) |
| **Suggested worktree** | `sec_fix_detf-uv4-burn-i1` |
| **Implementation notes** | Copy MultiVault burn `_pullToken` order; DETF role names; no `via_ir`. |
| **Acceptance** | `forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/**' --match-test 'test_I1_pretransferred_burn' -vv` (3 families) |
| **Anti-theater checks** | I1 no transfer; exact `TransferDeltaInsufficient`; proxy; protocol LP / attacker pairToken unchanged |
| **Proof-first?** | yes (High CODE was RUNTIME_UNPROVEN) |

### 9.2 WP-SEC-DETF-UV4-I-SUITE-001

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-DETF-UV4-I-SUITE-001` |
| **Title** | Catalog I1–I3 on extra Uni V4 DETF proxies |
| **Severity** | High |
| **Class** | TEST |
| **Products** | Weighted, Orbital, Curve-quad |
| **Finding IDs** | SEC-DETF-UV4-003, SEC-DETF-UV4-009 |
| **Problem** | No catalog I suite; existing `T_LOCAL_I1` is theater. |
| **Production files** | none |
| **Test files** | `test/…/weighted/adversarial/`; `…/orbital/adversarial/`; `…/stable/quad/curve/adversarial/` (new TrustFlags files) |
| **Out of scope files** | hook adversarial; CP-single |
| **Depends on** | burn I1 CODE for burn cases green |
| **Parallelizable with** | J, A0 (mint/bond I can start immediately) |
| **Conflicts with coverage-audit WP** | none |
| **Suggested worktree** | `sec_fix_detf-uv4-i-suite` |
| **Implementation notes** | Gold: MultiVault `Adversarial_TrustFlags.t.sol`. Cover mint, later bond, burn, depositClaim (W/Q). |
| **Acceptance** | `forge test --match-path 'test/**/uniswap/v4/standardExchange/{weighted,orbital,stable/quad/curve}/**' --match-test 'test_I' -vv` |
| **Anti-theater checks** | I1 no transfer; exact selector; proxy |
| **Proof-first?** | no |

### 9.3 WP-SEC-DETF-UV4-J-001

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-DETF-UV4-J-001` |
| **Title** | J1–J3 Target / loupe / proxy for extra Uni V4 DETFs |
| **Severity** | High |
| **Class** | TEST (+ CODE if OMIT found) |
| **Products** | Weighted, Orbital, Curve-quad |
| **Finding IDs** | SEC-DETF-UV4-004, SEC-DETF-UV4-011 |
| **Problem** | No surface matrix; F1 leftover-admin unproven on proxy. |
| **Production files** | only if J-omit (e.g. add `updateGlobalRewards` or missing view) |
| **Test files** | `Adversarial_Surface.t.sol` per family |
| **Out of scope files** | hooks |
| **Depends on** | none |
| **Parallelizable with** | I-suite, A0, NFT |
| **Conflicts with coverage-audit WP** | none |
| **Suggested worktree** | `sec_fix_detf-uv4-j` |
| **Implementation notes** | Control from **interface**; include Info + Compound `NotSelf` reverts; loupe `diamondCut==0`. |
| **Acceptance** | `forge test --match-path 'test/**/uniswap/v4/standardExchange/**' --match-test 'test_J' -vv` |
| **Anti-theater checks** | J3 proxy not facet address |
| **Proof-first?** | no |

### 9.4 WP-SEC-DETF-UV4-A0-001

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-DETF-UV4-A0-001` |
| **Title** | A0 first-bond / pre-live residual tests (+ CODE if law forbids absorb) |
| **Severity** | High |
| **Class** | TEST (BOTH if owner chooses revert) |
| **Products** | Weighted, Orbital, Curve-quad |
| **Finding IDs** | SEC-DETF-UV4-005 |
| **Problem** | No `test_A0_*`; `R=0` first `pretransferred` bond can consume donations. |
| **Production files** | first-bond helpers only if CODE |
| **Test files** | `adversarial/Adversarial_Donation.t.sol` or A0 file |
| **Out of scope files** | hooks |
| **Depends on** | product-owner absorb vs revert (`SEC-DETF-UV4-005`) |
| **Parallelizable with** | J; serial with I if sharing TestBase helpers |
| **Conflicts with coverage-audit WP** | none |
| **Suggested worktree** | `sec_fix_detf-uv4-a0` |
| **Implementation notes** | If ACCEPTED_RISK: document invariants (victim other balances; no booked inventory). |
| **Acceptance** | `forge test --match-path 'test/**/uniswap/v4/standardExchange/**' --match-test 'test_A0' -vv` |
| **Anti-theater checks** | Residual without attacker `transferFrom` in the bond call |
| **Proof-first?** | yes if upgraded to CODE |

### 9.5 WP-SEC-DETF-UV4-NFT-001

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-DETF-UV4-NFT-001` |
| **Title** | Harden or quarantine Uni V4 local bond-NFT + rebasing-claim pkgs |
| **Severity** | High |
| **Class** | BOTH |
| **Products** | UniV4DetfBondNft, UniV4DetfRebasingClaim |
| **Finding IDs** | SEC-DETF-UV4-006, SEC-DETF-UV4-007, SEC-DETF-UV4-014 |
| **Problem** | Deployable unused packages: leftover owner, PAT-I-ABS pull, A0 first deposit, `tx.origin`, optional mature-sell. No tests. |
| **Production files** | `contracts/vaults/detf/protocols/dexes/uniswap/v4/common/nft/**`; `…/common/rebasing/**` |
| **Test files** | new `test/**/uniswap/v4/common/{nft,rebasing}/**` |
| **Out of scope files** | `detf/common/bondNft` / `claimToken` (commons area) |
| **Depends on** | NEEDS_OWNER keep-vs-delete (`SEC-DETF-UV4-013`) |
| **Parallelizable with** | family I/J/A0 (disjoint) |
| **Conflicts with coverage-audit WP** | none (`WP-I-CLAIM-001` is shared claim) |
| **Suggested worktree** | `sec_fix_detf-uv4-nft-claim` |
| **Implementation notes** | If unused: quarantine (do not registry-list) + document. If kept: delta pull, dead shares, owner=DETF, mature-sell forced, drop `tx.origin`. |
| **Acceptance** | If kept: `forge test --match-path 'test/**/uniswap/v4/common/**' --match-test 'test_I1|test_A0|test_F1|test_J' -vv` |
| **Anti-theater checks** | Production DFPkg deploy; I1 no transfer |
| **Proof-first?** | yes |

### 9.6 WP-SEC-DETF-UV4-ORB-CLAIM-001

| Field | Value |
|-------|--------|
| **WP-ID** | `WP-SEC-DETF-UV4-ORB-CLAIM-001` |
| **Title** | Add orbital `depositClaim` or amend PRD |
| **Severity** | High |
| **Class** | BOTH (or DOCS if NEEDS_OWNER) |
| **Products** | Orbital DETF |
| **Finding IDs** | SEC-DETF-UV4-008 |
| **Problem** | PRD flow 8 requires direct claim; interface/facet omit it. |
| **Production files** | `IUniswapV4StandardExchangeOrbitalDETF.sol`; `…BondingTarget.sol`; `…Facet.sol` (add selectors) |
| **Test files** | `UniswapV4StandardExchangeOrbitalDETF_Claim.t.sol` |
| **Out of scope files** | weighted/curve depositClaim (already present) |
| **Depends on** | `S-spec-detf` / owner |
| **Parallelizable with** | I/J on other families |
| **Conflicts with coverage-audit WP** | none |
| **Suggested worktree** | `sec_fix_detf-uv4-orb-claim` |
| **Implementation notes** | Copy weighted `depositClaim` (revert if not zap-eligible). |
| **Acceptance** | `forge test --match-path 'test/**/orbital/**' --match-test 'test_depositClaim' -vv` |
| **Anti-theater checks** | Proxy; no compound-style silent skip |
| **Proof-first?** | no |

---

## 10. Deferred / N/A / NEEDS_OWNER / ACCEPTED_RISK

| Item | Class | Note |
|------|-------|------|
| Open-threshold seigniorage | ACCEPTED_RISK | Policy deadband tests exist; Open mint+burn same regime is product law. Need B1 victim-balance invariants (P). |
| Unbooked `U` absorb (L-RSRV-DUST) | ACCEPTED_RISK | Same as commons: donation benefits next pretransfer until end-sync. |
| First-bond this-call excess refund | ACCEPTED_RISK / E6-safe | Not `balance − floor`. |
| FoT / rebasing pairToken | N/A | Family PRD / hook forbid. |
| Permit2 / O* | N/A | No product sig money path. |
| M1–M3 arbitrary call | N/A | No user target+calldata. |
| Hooks / Uni V4 SE vault | N/A | Other areas. |
| Shared DETFNFTVault / RebasingClaimToken internals | N/A | `A-detf-commons` / `WP-I-CLAIM-001`. |
| Keep vs delete Uni V4 local NFT/claim | NEEDS_OWNER | PRD “share Uni V4 common” vs code using `detf/common`. |
| A0 first-bond: revert vs absorb | NEEDS_OWNER | If absorb, document + test; if revert, CODE in A0 WP. |
| Orbital `depositClaim` vs PRD amend | NEEDS_OWNER | Default: add surface (`SEC-DETF-UV4-008`). |
| Registry disable vs burn walkaway | NEEDS_OWNER / Medium | Confirm whether disable freezes exit. |
| Preview-every-path | DEFER / Medium | N2 P1; `S-spec-detf`. |
| Gas grief N-max / fork MEV | DEFER | P2. |
| BUILD_BLOCKED | n/a | Static complete; forge not run. |

---

## 11. Commands run

```text
# Inventory
rg --glob '*.sol' -n 'function _pullToken|pretransferred|facetFuncs|diamondCut|onlyOwner' \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/{weighted,orbital,stable/quad/curve} \
  contracts/vaults/detf/protocols/dexes/uniswap/v4/common/{nft,rebasing}

rg -n 'WP-I-CLONE-001|WP-I-DETF-SSE|weighted|orbital|UniV4Detf' \
  docs/testing/coverage-audit/WORK_PACKAGE_BACKLOG.md \
  docs/testing/coverage-audit/areas/T-detf-single-se.md \
  docs/security/audit/areas/A-commons-pull.md

rg -n 'test_I1|test_I2|test_I3|test_A0|test_J1|test_F1' \
  test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/{weighted,orbital,stable}

rg -n 'UniV4DetfBondNft|UniV4DetfRebasingClaim' test contracts --glob '*.sol'

# Re-read pull bodies (lines)
# weighted Common 811-822; orbital 743-754; curve 815-826 — reserve-delta
# burn skip: *ExchangeOutTarget if (!pretransferred_) transferFrom
```

Forge: **not executed** (no Critical CODE; monorepo compile 20–40+ min; L-SEC-3 not triggered).

---

**Area status: COMPLETE.** Five products named; five DFPkgs inventoried; catalog A–O + E6/F5 scored; PAT-* hunted; family PRDs spot-checked; coverage-audit clone-pull CODE linked not re-owned.
