# Implementation & Test Plan: UniswapV4StandardExchangeWeightedDETF

**PRD (product law SoT):** [`UniswapV4StandardExchangeWeightedDETF_PRD.md`](./UniswapV4StandardExchangeWeightedDETF_PRD.md) (**DRAFT v0.4**)  
**This plan (implementor SoT once accepted):** greenfield family package under `standardExchange/weighted/` — **do not** subclass CP UniV4 DETF, Orbital UniV4 DETF, or Balancer Single SE contracts.  
**Package root:** `contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/`  
**Date:** 2026-08-05  
**Status:** **Canonical plan aligned to PRD v0.4** — ready for implementor stamp after product LOCK on PRD; then phased coding. **No production code in this doc-only pass.**

---

## Authority

| Layer | Role |
|-------|------|
| **PRD v0.4** | Product law — wins on any conflict; patch this plan if PRD changes |
| **This plan** | Phases, file map, deploy path, algorithm freezes, test matrix, DoD |
| **AGENTS.md** | DETF common expectations; CREATE3; manager vault registry for DETF DFPkg; production-first tests; co-located PRDs; mature-only sell→claim. **Note:** generic `rateAsset` role does **not** apply to this family (per-route pair unit; per-leg RP only) |
| **Crane skills** | `crane-deployment`, `crane-architecture`, `crane-testing` |
| **IndexedEx skills** | `indexedex-testing`, `indexedex-adversarial-testing`, `indexedex-uniswap-v4-hook-packages` |
| **Orbital UniV4 DETF peer** | Multi-external process + facet/TestBase shape reference only — **do not subclass** |
| **CP UniV4 DETF peer** | Seigniorage split / epoch expansion form reference — **do not subclass** |
| **Balancer Single SE peer** | Fee-recipient NFT / bond lifecycle spirit — **do not subclass** |
| **Weighted SE Buffer Hook** | Hard dependency — weighted multi-door book, `depositSingle` / multipath join-exit, full-book floors |

**Process rule:** If this plan and PRD disagree, **PRD wins** and this plan must be patched. Do not reopen PRD-locked Q1–Q14 / H1–H23 without a PRD revision.

Deploy arity is [`UNISWAP_V4_SE_DETF_DEPLOY_MINE_NONCE_PRD.md`](../UNISWAP_V4_SE_DETF_DEPLOY_MINE_NONCE_PRD.md) / its implementation plan.

**Role names only:** `detfToken`, `pairToken[i]` / `pairTokens`, `standardExchange[i]`, `vaultShare[i]`, `rateProvider[i]`, `weights`, `reserveHook` / `reserveLp`, `bondNft`, `rebasingClaimToken`, `creationPairPerDetfWad[i]`, `capitalToken`, `syntheticVs(pair)`. **No** whole-DETF `rateAsset`. No brand tickers.

---

## Read order for implementors

1. PRD §1 locked summary + §2 roles + §3 topology  
2. PRD §4 liveness / first bond (all externals, refund, full book, capitalToken)  
3. PRD §5 pricing — **§5.3 hook-SoT quote**, **§5.4 full-book lifecycle**, **§5.5 whole-reserve per-route FD**, **§5.6 burn + redeposit**  
4. PRD §7–§9 mint / bond (single-external later, mature-only, single capitalToken) / claim  
5. PRD §10 compound + **epoch-end all-legs-rich** expansion; §11 PkgArgs; §15 tests; §20 Q/H tables  
6. **This plan** §0–§8 (gates, phases, algorithms, tests)  
7. Hook PRD/plan for **ABI only**; Orbital + CP DETF TestBases as pattern only  

---

## 0. Starting state

| Item | Status |
|------|--------|
| PRD v0.4 | Present at package path |
| This plan | **This file** |
| DETF package Solidity | **None** — greenfield |
| Uni V4 DETF `common/nft` + `common/rebasing` | Share with CP + Orbital — **must** support **fungible hook LP principal** + **single `capitalToken` metadata** + optional `requireMatureForSell`. Prefer co-owned packages — do not invent a third NFT family |
| Shared `detf/common/core/*` | Exists — reuse thresholds, usage fee, bond math, compound helpers, epoch expansion (as CP/Orbital peer); **family gate** for all-legs + epoch-end |
| Weighted SE Buffer Hook package | Under `contracts/hooks/uniswap/v4/standardExchange/weighted/` — **Phase 0 hard gate** |
| Orbital UniV4 SE DETF | Peer under `…/orbital/` — gold multi-leg facet/DFPkg/TestBase shape |
| CP UniV4 Single SE DETF | Peer under `…/constantProduct/single/` — gold epoch expansion + seigniorage form |
| Balancer Single SE DETF | Gold peer for seigniorage split / fee-recipient / bond spirit |

**Do not** start by subclassing CP / Orbital DETF Targets or forking monomorph weighted sources into this package.

---

## 1. Goals / non-goals

### Goals (v1 DoD)

1. Ship **true DETF** diamond + DFPkg under this path via **IndexedEx manager vault registry**.  
2. From **`PkgArgs`**, deploy **one** Weighted SE Buffer Hook via registry **`deployHookVault`**: \(n \in [2,8]\) tokens (DETF raw self-leg at address-sorted index + \(m = n-1\) external pairs); **weights** (sum \(1\mathrm{e}18\), each \(\ge 1\%\)); **≥1** distinct SE on external legs; optional RPs on SE legs only; **all** \(\binom{n}{2}\) V4 doors in hook `postDeploy`.  
3. **Permissionless first bond** requiring **all** external pair legs at creation rates → full book → `isReserveLive`; **refund excess** external capital; **required** `capitalToken`; MINIMUM_LIQUIDITY edge.  
4. **Primary mint** (live): rate capital → funded pair-leg units → seigniorage quote (**hook SoT**) / split → hook **`depositSingle(pair)`** → protocol LP; **Policy per-route debt-inclusive** mint gate; **no** expansion realize.  
5. **Primary burn**: free DETF only → multipath/prop `removeLiquidity` (**normative**) → **redeposit returned DETF** (ladder) → residual consolidate → `tokenOut` pair; `lpOut = detfBurned * protocolLp / effectiveSupply`; usage fee **yes**; **`withdrawSingle` optional optimization only**; **no** expansion realize.  
6. **Bond after live**: **no** synthetic mint gate; **exactly one external pair**; protocol mints join DETF + multipath; LP on bond NFT; `capitalToken` = that pair; `effectiveShares` via open-time weighted mids (**DETF-valued**); **realizes** expansion.  
7. **Mature-only** sell→claim (DETF gate + shared flag); maturity close pays **single recorded capitalToken**; free NFT transfer; indefinite mature hold.  
8. Rebasing claim holds **protocol LP**; redeem matrix with redeposit DETF; **`tokenOut = DETF` → InvalidRoute**; prefer clean vaultShare path. User claim deposit **reverts** if not single-asset eligible.  
9. **Protocol compound** single-sided DETF `depositSingle` when single-asset eligible; **skip** (no revert) when not.  
10. **Epoch natural expansion** (Policy): CP-form premium-closure; accrue for an epoch **only if all-legs mint-rich at epoch end**; size scalar = **min** \(S_{spot,k}\); pending in every per-route synthetic; realize only bond / claimRewards / compound.  
11. Production-first tests: hermetic matrix \(n \in \{2,3,4,8\}\), 1 SE+bare / all-external-SE, free DETF binding, RP on/off, gentle + launch-rich, per-route skew, refund, epoch-end expansion + ≥1 fork profile; no SUT mocks.

### Non-goals (v1)

- Implementing the reserve hook inside this package.  
- All-external-bare deploy; \(n \notin [2,8]\); DETF as buffered SE leg.  
- Whole-DETF `rateAsset` field / single-numeraire gates.  
- Multi-leg later bonds; multi-token maturity baskets; user-paid DETF as bond capital.  
- Subclassing CP / Orbital UniV4 DETF, Balancer Single SE, or hook contracts.  
- Protocol “rebalance full book” surface (not needed for designed lifecycle).  
- Treating swaps/later bonds as routine zero-leg partial-book sources (PRD §5.4).  
- MEV protection on first bond; fee-oracle expansion/threshold params.  
- FoT/rebasing pair tokens; native ETH currency; cross-chain.  
- Binary-search solvers; inventing hook APIs.  
- `withdrawSingle` as DoD requirement (optional optimization only).  
- Permit2 on DETF surface (optional later; hook may use Permit2 internally).

---

## 2. Hard gates & dependencies

| Gate | Requirement |
|------|-------------|
| **G0 Hook** | Weighted SE Buffer Hook: multipath join/exit + previews, **`depositSingle` / `joinSingleAssetExactIn` (+ previews)**, optional `withdrawSingle`, fungible ERC-20 LP, native inventory views, SE In/Out as needed for residual settle, full-book exit floors — **ABI frozen or DoD green** for hermetic use |
| **G1 SE** | At least one production SE (hermetic ERC-4626 wrapper or protocol SE TestBase) with closed-form pair ↔ share routes; matrix needs bare + multi-SE rows |
| **G2 Crane** | `CraneTest` → `IndexedexTest` → vault components; create3Factory + diamondPackageFactory |
| **G3 Registry** | DETF DFPkg via `indexedexManager.deploy*DFPkg` / registry path; hook via `deployHookVault` + hook diamond factory — **never** `new` facets/DFPkgs |
| **G4 Shared children** | Bond NFT + rebasing packages support **hook LP principal**, **single `capitalToken` metadata**, mature-only optional flag or DETF-only gate |

**Coding must not invent hook APIs.** Consume only surfaces from the Weighted SE Buffer Hook PRD / frozen ABI.

### Hook ABI consumption checklist (document in TestBase comments)

| DETF need | Hook surface (names indicative — freeze to real ABI in Phase 0) |
|-----------|------------------------------------------------------------------|
| First bond / later multipath join | Multi-asset / proportional / unbalanced join with maxes in **binding order** (`n` amounts) |
| Primary mint / free DETF claim / compound | `depositSingle` / `joinSingleAssetExactIn` when single-asset eligible |
| Burn / claim redeem / maturity (normative) | Prop / multipath `removeLiquidity` / `exitProportional` → `n` amounts binding order |
| Optional burn/claim optimization | `withdrawSingle` **only if** preview-equal to multipath+residual and depth OK |
| Previews | Hook `preview*` for join/exit/single-asset — **SoT for mint quotes** |
| FD residual / weighted exact-in | Prefer hook previews/quotes for residual sells; if pure math required, match hook fee law bit-exact |
| LP token | Hook ERC-20 LP (`reserveLp`) |
| Full book | All native inventory legs \(> 0\) + supply past MIN (hook law) |

---

## 3. Architecture (implementor map)

### 3.1 Deploy topology

```text
IndexedexManager / Vault Registry
  └── UniswapV4StandardExchangeWeightedDETFDFPkg
        postDeploy (after DETF diamond exists — address known for sort):
          - Build binding-order arrays:
              tokens[n] = sort(DETF, pairTokens[0..m-1]) by address ascending
              weights[n] already binding-order (or remap from product order — freeze one)
              standardExchanges[n]: DETF index = 0; external bare or SE
              rateProviders[n]: non-zero only if SE set
          - deployHookVault(Weighted SE Buffer Hook PkgArgs):
              tokens, weights, SEs, RPs, poolManager, feeOracle, mineNonce / salt
          - hook postDeploy inits all C(n,2) V4 doors (DYNAMIC_FEE_FLAG, plumbing sqrtPrice)
          - deploy shared bond NFT package (owner=DETF; requireMatureForSell=true if flag exists)
          - deploy shared rebasing claim package (owner=DETF; holds protocol LP)
          - store PkgArgs: pairTokens (product order), creation rates (m), binding maps,
            thresholds, expansion, detfBindingIndex, reserveHook, refs
          - validate (PRD §11):
              m∈[1,7], n=m+1∈[2,8]; pairs distinct; DETF raw only; ≥1 SE; SEs distinct;
              RP only with SE; pair ∈ SE.tokens() when SE set; DETF ∉ SE.tokens();
              all creation rates > 0; weights sum 1e18 each ≥1%; no FoT/rebasing pairs;
              NO whole-DETF rateAsset field

Facets (CREATE3): Info / ExchangeIn / ExchangeOut / Bonding / Claim / (Compound on Info or Bonding)
Diamond instance = detfToken ERC-20 (immutable / unowned after deploy)
```

### 3.2 Index / order mapping (implementor card)

| Array | Order | Length |
|-------|-------|--------|
| `pairTokens[]` | **Product order** (deployer-chosen) | \(m\) |
| `creationPairPerDetfWad[]` | Aligned with `pairTokens[]` | \(m\) |
| Hook `tokens[]` / `weights[]` / `standardExchanges[]` / `rateProviders[]` / amount maxes | **Address-ascending binding order** | \(n = m+1\) |

```text
// After DETF address known:
// 1) bindingTokens = sort ascending(DETF, pairTokens…)
// 2) detfBindingIndex = index of DETF in bindingTokens
// 3) for each pairToken[i]: pairBindingIndex[i] = index in bindingTokens
// 4) weights[] MUST be binding-order: weights[j] = weight of bindingTokens[j]
// 5) SEs/RPs: product-supplied parallel to binding OR product parallel to pairTokens
//    + DETF zero — freeze ONE encoding in interface NatSpec (recommend binding-order
//    length-n arrays in PkgArgs for hook pass-through; product-order m for pairs/rates)
```

**Worked example (\(m=2\)):**  
Pairs product order `[USDC, WETH]`. DETF address sorts between them → binding  
`[USDC, DETF, WETH]` → `detfBindingIndex=1`, `pairBindingIndex=[0,2]`.  
Weights e.g. `[0.3e18, 0.4e18, 0.3e18]` bind to USDC / DETF / WETH.  
`creationPairPerDetfWad = [2e18, 0.001e18]` still product-order USDC then WETH.

### 3.3 Suggested file map

```text
contracts/vaults/detf/protocols/dexes/uniswap/v4/
  standardExchange/weighted/
    UniswapV4StandardExchangeWeightedDETF_PRD.md
    UniswapV4StandardExchangeWeightedDETF_IMPLEMENTATION_AND_TEST_PLAN.md  # this file
    interfaces/
      IUniswapV4StandardExchangeWeightedDETF.sol       # instance surface
      IUniswapV4StandardExchangeWeightedDETDFPkg.sol    # PkgInit / PkgArgs HERE (Crane rule)
    UniswapV4StandardExchangeWeightedDETFRepo.sol
    UniswapV4StandardExchangeWeightedDETFCommon.sol     # gates, rating, FD, residual, scale, join sizing
    UniswapV4StandardExchangeWeightedDETFInfoTarget.sol
    UniswapV4StandardExchangeWeightedDETFExchangeInTarget.sol
    UniswapV4StandardExchangeWeightedDETFExchangeOutTarget.sol
    UniswapV4StandardExchangeWeightedDETFBondingTarget.sol
    UniswapV4StandardExchangeWeightedDETFClaimTarget.sol
    UniswapV4StandardExchangeWeightedDETF*Facet.sol
    UniswapV4StandardExchangeWeightedDETFDFPkg.sol
    UniswapV4StandardExchangeWeightedDETF_Facet_FactoryService.sol
    UniswapV4StandardExchangeWeightedDETF_Pkg_FactoryService.sol
    UniswapV4StandardExchangeWeightedDETF_Component_FactoryService.sol
    TestBase_UniswapV4StandardExchangeWeightedDETF.sol
  common/
    nft/      # SHARED with CP + Orbital — LP principal + capitalToken metadata + mature flag
    rebasing/ # SHARED — claim on protocol hook LP
```

**Libs (prefer extend, not fork):**

| Lib | Use |
|-----|-----|
| `DETFThresholdPolicy` | Policy/Open resolve + gates |
| `DETFUsageFeeLib` / peer mint split | Seigniorage split; **burn usage fee** |
| `DETFBondNFTMathLib` / `DETFBondLifecycleLib` | Lock clamp, bond lifecycle |
| `DETFProtocolCompoundLib` | Compound helpers |
| `DETFNaturalExpansionLib` / epoch peer | Whole-epoch pending + mint; **wrap** with all-legs + epoch-end gate |
| Family-local residual helpers | Only if hook lacks pure residual quotes — **must bit-match hook fee law**; prefer hook SoT |

### 3.4 Storage (Repo sketch)

```text
// UniswapV4StandardExchangeWeightedDETFRepo (names indicative)
isReserveLive
n / m
pairTokens[]                         // product order, length m
pairBindingIndex[]                   // product → binding
detfBindingIndex
weights[]                            // binding order, length n (or re-read from hook)
standardExchanges[]                  // binding order, length n (DETF slot 0)
rateProviders[]                      // binding order, length n
creationPairPerDetfWad[]             // product order, length m; each > 0
reserveHook
bondNftVault
rebasingClaimToken / protocolLpHolder (= rebasing)
feeOracle
thresholdMode, mintThreshold, burnThreshold
expansionEpochLength
expansionClosureRatePerYearWad
expansionMaxCatchUpEpochs            // 0 = unlimited
lastExpansionTimestamp               // 0 until first realize-path seed after live
feeRecipientNftId
// optional: poolManager ref if needed for views
```

**Bond NFT position metadata (product-required; layout plan-freezes):**

```text
// per tokenId
capitalToken           // single external pair address — ALWAYS set (first + later)
// optional analytics: open notionals — NOT used for close basket
effectiveShares        // DETF-valued principal × lock bonus
unlockTime
lpPrincipal (or tracked via balance)
```

Slot form: Crane ERC1967-style `DEFAULT_SLOT = bytes32(uint256(keccak256(abi.encode("…"))) - 1)`.

### 3.5 Public surface (facet split)

| Facet group | Functions (min) |
|-------------|-----------------|
| **Info** | `isReserveLive`, `syntheticPrice(pair)` / `syntheticVs(pair)` (debt-inclusive whole-reserve), optional spot, `isMintingAllowed(pair)` / `isBurningAllowed(pair)`, optional `isAllLegsMintRich()`, `pendingExpansionDetf`, thresholds, creation rates, pairs, SEs, RPs, weights, \(n\)/\(m\), DETF binding index, reserve hook, expansion getters — **no** `rateAsset()` |
| **ExchangeIn** | Mint DETF from any pair / vaultShare / SE token (pair face OK on buffered legs) |
| **ExchangeOut** | Burn free DETF → `tokenOut` ∈ pair legs (+ SE unwrap); **not** DETF |
| **Bonding** | `bond` (first: all externals + required capitalToken; later: single external), maturity close, `sellPositionToDetfNft` (**mature only**), `claimRewards`, `acceptedBondTokens` |
| **Claim** | Direct deposit (pair/share/SE/DETF); `redeemClaim` with tokenOut matrix (**DETF out InvalidRoute**) |
| **Compound** | `compoundProtocolRewards` (skip if not single-asset eligible) |

**Previews (LOCKED):** every closed-form path has a view with preview == execution (≤ few-wei only if SE multi-leg dust; document). Mint/bond quotes **must** match hook previews (hook SoT).

**Errors (stable family):**

| Error | When |
|-------|------|
| `InvalidRoute` | Bad tokenIn/tokenOut matrix |
| `ReserveNotLive` / peer | Pre-live primary mint/burn / non-first bond |
| `MintNotAllowed` / `BurnNotAllowed` | Policy gates (per-route) |
| `BondNotMature` | Pre-maturity sell or principal close |
| `FirstBondRequiresAllExternalPairs` | Missing any external on first bond |
| `LaterBondSingleExternalOnly` | Multi-external later bond |
| `NotSingleAssetEligible` | Single-asset path when hook not full-book eligible (exceptional after correct first bond) |
| `ProtocolLpEmpty` / insufficient | Burn with no/insufficient protocol LP |
| `InvalidCapitalToken` | capitalToken ∉ pairTokens |
| `InvalidCreationRate` | Deploy: any rate ≤ 0 |
| `AllExternalBareForbidden` / peer | Deploy: zero SEs |
| `InvalidWeights` | Sum/min weight fail |
| Lock too short / min out | Peer |

**No** `UnsupportedRoute` on this family.

---

## 4. Core algorithms (freeze for implementors)

All internal math in **1e18 WAD**; scale at ERC-20 boundary. `YEAR = 365 days`.

### 4.1 Decimal scale

```text
toWad(amount, decimals) / fromWadFloor / fromWadCeil — consistent with hook peer
creation rates stored and consumed only in WAD space
SE share → pair: if RP: shares * getRate() / 1e18 (then toWad); else fee-inclusive SE unwrap preview
```

### 4.2 Capital rating to pair-leg units (PRD §5.3–§5.4)

```text
rateTokenInToPairLeg(tokenIn, amountIn) → (fundedPairIndex /* product i */, pairNotionalWad):
  if tokenIn == pairToken[i]: (i, toWad(amountIn, d_i))
  if tokenIn == vaultShare[i] (SE_i set):
    pairNotional = always rate shares → pair units (RP or claim)  // never skip
    → (i, pairNotionalWad)
  if tokenIn ∈ SE_i.tokens() (SE_i set):
    SE route → pair face → (i, pairNotionalWad)
  else: revert InvalidRoute

// Mint quote: do NOT convert pairNotional through another pair mid
pairBoosted = pairNotionalWad * (1e18 + seigniorageIncentiveWad) / 1e18
grossDetf   = quoteDetfAgainstReserve(fundedPairIndex, pairBoosted)  // hook SoT
```

### 4.3 `quoteDetfAgainstReserve` — **hook source of truth** (PRD §5.3, Q12, H17)

**Economic identity:** fee-aware DETF gross for exact-in **pair-leg** notional against **live weighted book** — inverse of single-sided capital priced vs live book (`depositSingle` / single-asset join spirit).

```text
// LOCKED implementation rule:
// 1. Call hook preview for single-asset join impact / BPT out / economic inverse
//    for the funded pair leg (exact selector names frozen in Phase 0 against hook ABI).
// 2. Map that impact to DETF gross seigniorage size per economic identity.
// 3. DETF MUST NOT reimplement WeightedMath / Balancer join algebra for this quote.
// 4. Preview + execution MUST share one path.
// 5. NOT creation rate after live; NOT cross-pair mid convert; NOT binary search.
// 6. Document ≤ few-wei only if SE multi-leg dust forces it.
```

Unit tests: fixed book state → quote via hook preview; execute mint; assert user DETF within wei budget of preview.

### 4.4 Debt-inclusive per-route synthetic — **whole reserve** (PRD §5.5, Q7, H6)

**Peg (per pair \(k\)):** abstract 1e18 on `syntheticVs(pair_k)` means FD claim of **whole reserve** in pair \(k\) per DETF equals `creationPairPerDetfWad[k]`.

```text
previewWholeReserveToPair(pair_k):
  // Basis: ENTIRE reserve pool (full hook inventory / full LP supply)
  // NOT protocol-only; NOT bond-NFT-only
  residual[n] = preview proportional remove of total hook LP supply
                (or inventory residual representing entire book — freeze vs hook)
  map binding → (a_detf, a_pair[0..m-1])
  // FULL residual → pair_k:
  fd = toWad(a_pair_k face)
  for each other pair j != k:
    fd += weightedExactInSell(pair_j → pair_k, a_j)   // prefer hook quote SoT
  fd += weightedExactInSell(DETF → pair_k, a_detf)
  return fd

// Order of multi-hop residual sells: freeze in Phase 3 tests (fee-aware; product accepts path impact)

S_spot_k = (fdPair_k * 1e18 / max(detfTotalSupply,1)) * 1e18 / creationPairPerDetfWad[k]

pending = previewPendingExpansionMint()
effectiveSupply = detfTotalSupply + pending
syntheticVs(pair_k) = (fdPair_k * 1e18 / max(effectiveSupply,1)) * 1e18 / creationPairPerDetfWad[k]
```

**Important:** execution redeposit of DETF on burn/claim does **not** redefine FD. FD answers extractable **market** claim in pair \(k\).

**Gates:**

| Path | Gate |
|------|------|
| Primary mint → pair \(i\) | Policy: `syntheticVs(pair_i) > mintThreshold` |
| Primary burn → pair \(j\) | Policy: `syntheticVs(pair_j) < burnThreshold` |
| Equality | Deadband on that route only |
| Open | Gates always pass when live; pending expansion = 0 |
| First bond | Ungated |
| Bonds after live | **No** synthetic mint gate |

### 4.5 All-legs mint-rich + pending expansion (PRD §10.2, Q10, H21)

```text
allLegsMintRich():
  if !live || Open: return false
  for each external pair_k:
    if syntheticVs(pair_k) <= mintThreshold: return false
  return true

// Epoch-end accrual (LOCKED):
// For each whole completed epoch ending at T_end = last + e * epochLength:
//   if allLegsMintRich() evaluated at T_end (state at that time — see note):
//     include that epoch in catch-up mint
//   else:
//     that epoch contributes 0
// No pro-rate of partial epochs that flipped mid-window.
// maxCatchUpEpochs caps how many whole epochs are scanned (0 = unlimited).

// Size scalar for premium-closure when accruing:
//   S_size = min_k S_spot_k   // most conservative leg; max/avg OUT for v1
// Then same O(1) premium-closure form as CP UniV4 DETF §10 using S_size.
```

**Note on “state at epoch end”:** Foundry/tests use `vm.warp` + realize path. On-chain realize scans completed epochs; for each candidate epoch end timestamp, compute all-legs richness from **current** book only if product accepts “evaluate richness now for past epochs” — **prefer strict product law:** store or recompute using the rule that an epoch only pays if rich when it **ended**.  

**Implementor freeze (Phase 3 — product-aligned, simple):**

```text
// Preferred simple realization matching “whole epoch only if still rich at end”:
// When realizing at time `now`:
//   completedEpochs = (now - last) / epochLength
//   For catch-up, only mint for epochs if ALLLEGS is true *at realize time*
//   AND we only count whole completed epochs.
// Interpretation: if the book is not all-rich at realize, pending = 0
//   (forfeits incomplete/failed end-of-epoch richness). If book is all-rich now,
//   pay up to completedEpochs (capped) — assumes end-of-epoch richness coincides
//   with “still rich now” for continuous all-rich intervals.
//
// If product later requires true historical end-of-epoch snapshots, plan amendment
// adds checkpoint storage. v1 ships the simple rule above + tests:
//   - warp full epoch while always all-rich → accrues
//   - warp full epoch while not all-rich at end (warp then trade then end) → 0
//   - flip mid-epoch then end not-rich → 0 for that epoch
```

**Realize paths:** bond, `claimRewards`, `compoundProtocolRewards` (+ reward updates).  
**Forbidden on primary mint/burn:** realize + advance of `lastExpansionTimestamp`.

```text
_realizeExpansionIfNeeded():
  if !live || Open: return
  if last == 0: last = now; return   // seed after live; no pre-live backlog
  pending = previewPendingExpansionMint()  // includes epoch-end / all-legs rules
  if pending == 0: return
  _mintDetf(bondNftVault, pending)   // reward ledger sink
  epochs = … same as preview …
  last += epochs * expansionEpochLength
```

### 4.6 Seigniorage mint split (peer)

```text
pairBoosted = pairNotionalWad * (1e18 + seigniorageIncentive) / 1e18
gross = quoteDetfAgainstReserve(fundedPair, pairBoosted)  // hook SoT
feeTo = gross * usageFee / 1e18
afterFee = gross - feeTo
inventory = afterFee * (seigniorageIncentive / 2) / 1e18   // peer half-incentive inventory
user = afterFee - inventory
```

| Path | Capital → reserve | Free DETF |
|------|-------------------|-----------|
| Live primary mint | Settle → `depositSingle(pairLeg)`; revert if not single-asset eligible | Mint user / feeTo / inventory only |
| Bond (live) | Multipath: join DETF + **one** external max; LP → NFT | Also free legs from split |
| First bond | Creation-rate sized join DETF + **all** externals | Free legs from split of gross |

### 4.7 First bond (PRD §4.4, Q2, Q11)

```text
// require all m external notionals C_i > 0 after settle (else FirstBondRequiresAllExternalPairs)
// require capitalToken ∈ pairTokens
for each external i:
  detfFrom[i] = pairNotionalWad[i] * 1e18 / creationPairPerDetfWad[i]
detfForJoinWad = min_i(detfFrom[i])
require detfForJoinWad > 0

// Size external amounts used in join from detfForJoinWad * creation rates
// (or min-implied clamp per hook); REFUND unused external capital to caller

// Apply mint modifiers / seigniorage split on join-sized gross
// Only join-sized DETF enters multipath; free user/fee/inventory stay outside pool

// Binding-order maxes: DETF on detfBindingIndex, pairs on pairBindingIndex[*]
// multipath / proportional join; require post-join full book (all legs > 0) else revert
// LP → bond NFT
// capitalToken = caller arg (required even if m=1)
// effectiveShares = DETF-value of all m funded externals at open mids × lock bonus
// isReserveLive = true
```

Pre-live: primary mint/burn revert; non-first bond revert.  
If hook geometric / MIN liquidity fails → clear product error (cannot go live).  
Unequal weights: no exact mid equality required; refund + tests cover.

### 4.8 Primary burn (PRD §5.6, Q4)

```text
// no expansion realize
require live + debt-inclusive burn gate on tokenOut pair (Open: when live)
tokenOut ∈ pairTokens (else InvalidRoute); tokenOut == DETF → InvalidRoute
pending = previewPendingExpansionMint()
effectiveSupply = totalSupply + pending
protocolLp = reserveLp.balanceOf(protocolLpHolder)
lpOut = detfBurned * protocolLp / effectiveSupply
if protocolLp == 0 || lpOut == 0: revert ProtocolLpEmpty

// atomic full success or full revert:
1. pull + burn only detfBurned (user free DETF)
2. apply burn usage fee (YES — DETFUsageFeeLib peer)
3. NORMATIVE: removeLiquidity/exitProportional(lpOut) → residual n-leg amounts
4. redeposit all returned DETF (ladder §4.9)
5. consolidate non-tokenOut pairs → tokenOut (hook SE In/Out / weighted exact-in; prefer hook)
6. pay tokenOut (+ tokenOut dust to user)
7. enforce minOut

// OPTIONAL: withdrawSingle(lpOut, tokenOut) only if preview-equal + depth OK — not DoD
// Dust of other pairs below plan dust threshold may remain on diamond — NatSpec + tests
```

**Do not** burn returned DETF. **Do not** pay returned DETF to burner. **Do not** draw bond-NFT LP.

### 4.9 Redeposit ladder (shared helper)

Used by: primary burn, claim redeem, maturity close, sell fallback.

```text
_redepositDetfSelfLeg(amountNative):
  if amount == 0: return
  if singleAssetEligible: depositSingle(DETF, amount, …) → protocol LP holder
  else if multipath single-leg DETF accepted: join with DETF max only
  else: revert entire outer tx
```

### 4.10 Residual consolidate (hook SoT preferred)

```text
// Convert amount of tokenA → tokenB using same fee-aware path as hook doors / SE In/Out
// Prefer hook surfaces when both are pool tokens
// Order of multi-hop sells for FD and for execution residual: freeze in Phase 3 tests
// Preview path MUST match execution path at same fee/oracle reads
```

### 4.11 Bond after live (PRD §8, Q8)

```text
_realizeExpansionIfNeeded()
// NO synthetic mint gate
// Capital: exactly ONE external pair (or SE capital settling to it)
// Multi-external → LaterBondSingleExternalOnly
// User never pays DETF; protocol mints join DETF
// Quote via hook SoT + free legs split
// multipath join DETF + that pair max (adds liquidity — does not remove other legs)
// LP → NFT
// capitalToken = funded pair (store explicitly)
// effectiveShares (H13):
//   convert funded external pair notional → DETF at open-time weighted mids
//   (fee-aware closed form; prefer hook mid/quote SoT)
//   × lock bonus
//   DETF join leg does NOT add to effectiveShares
// lock: revert if < min; clamp to max (bonus at max)
```

**Pre-maturity:** only `claimRewards` (+ free ERC-721 transfer). No early close, no early sell.

### 4.12 Maturity close (PRD §8.2.1, Q9)

```text
require mature
pay pending rewards (realize path)
withdraw all position LP from NFT
removeLiquidity(lp)  // multipath/prop
_redepositDetfSelfLeg(a_detf)
consolidate all other non-DETF pair residual → capitalToken
pay only capitalToken
retire NFT
```

**Do not** pay multi-token residual basket. **Do not** default to an implicit global numeraire.

### 4.13 Sell → rebasing claim (PRD §8.3, H7, H14)

```text
require mature  // DETF surface ALWAYS; shared flag true if present
pay pending rewards
transfer reserveLp from bond NFT → rebasing package (prefer ERC-20 transfer)
mint claim from Δ protocol LP contribution (LP-pro-rata — no global numeraire)
credit protocol NFT id 0 if peer ledger requires
retire user NFT

// Fallback if transfer blocked: remove → redeposit DETF → remint LP / residual deposit — still mature only
```

### 4.14 Claim mint / redeem (PRD §9, Q14, H23)

**Mint claim (no seigniorage):**

| Path | Mechanics |
|------|-----------|
| Bond sell (mature) | §4.13 |
| New money pair/share/SE | Settle → `depositSingle(pair)` when single-asset eligible → LP to protocol → mint claim. **Else REVERT** (not compound skip) |
| Free DETF | `depositSingle(DETF)` → LP to protocol → mint claim (user impact). **Else REVERT** |

**Redeem:**

```text
lpOut = claimSharesBurned * protocolLp / claimTotalSupply
burn claim shares only
removeLiquidity(lpOut)  // normative multipath
_redepositDetfSelfLeg(a_detf)
residual → tokenOut matrix:
  any external pair | vaultShare_i (prefer clean share path) | SE token
tokenOut == DETF → InvalidRoute
else InvalidRoute
// optional withdrawSingle if preview-equal
```

### 4.15 Protocol compound (PRD §10.1, H3)

```text
compoundProtocolRewards():
  _realizeExpansionIfNeeded()   // public compound IS a realize path
  update bond rewards
  harvest protocol NFT pending free DETF
  if !singleAssetEligible: return  // SKIP — do not revert
  depositSingle(DETF) → protocol LP ↑
  no new claim shares
```

Lazy: on bond / claimRewards after realize; **not** on primary mint/burn. Join failure on lazy: best-effort leave pending.

### 4.16 Full book lifecycle (PRD §5.4, Q13, H20) — implementor note

| Rule | Action |
|------|--------|
| First bond | Require all externals; post-join all native legs \(> 0\) |
| Later bonds / primary mint | **Add** inventory; do not design as zeroing sibling legs |
| Swaps | Curve asymptotics; do not treat full drain as normal |
| Hook full-book exits | Must leave all legs \(> 0\) (hook law) |
| `NotSingleAssetEligible` | Exceptional; still **revert** on user mint/claim deposit; **skip** on compound |
| Do not implement | Protocol rebalance API “to restore full book” as a product surface |

### 4.17 PkgArgs resolve

| Arg | Resolve |
|-----|---------|
| `expansionEpochLength == 0` | `8 hours` |
| `expansionClosureRatePerYearWad == 0` | `0.10e18` (10% premium/yr gentle) |
| `expansionMaxCatchUpEpochs == 0` | unlimited |
| thresholds 0 | `DETFThresholdPolicy` defaults (1.05e18 / 0.95e18) |
| `thresholdMode` 0 / omit | Policy |
| `creationPairPerDetfWad[i]` | **each must be > 0** — no default; deploy reverts |
| SE slots | **≥1 non-zero** among external legs; all-external-bare reverts |
| weights | sum \(1\mathrm{e}18\); each \(\ge 0.01\mathrm{e}18\); binding order |
| `detfBindingIndex` | derived from address sort after diamond exists |
| whole-DETF `rateAsset` | **absent** — do not add field |

Launch-rich templates set explicit `R` (e.g. `4.4e18`) — copy CP UniV4 DETF §10.3–§10.4 tables; interpret richness via per-route whole-reserve synthetics + all-legs + epoch-end.

---

## 5. Phased delivery

| Phase | Deliverable | Exit criteria |
|-------|-------------|---------------|
| **0** | Hook ABI freeze / hermetic green; shared nft+rebasing LP principal + capitalToken + mature flag design | G0–G4 ready; consumption checklist filled with real selectors |
| **1** | Interfaces + Repo + DFPkg postDeploy + facet stubs + FactoryServices | Deploy inert diamond; hook bound; all doors exist; validations reject bad PkgArgs |
| **2** | First bond (all externals, refund, capitalToken, full book) → live | §4.7 tests green |
| **3** | Common: WAD scale, capital rating, **hook-SoT quote**, whole-reserve FD, per-route gates, residual | Preview == execution unit rows |
| **4** | Primary mint + seigniorage split | Any pair face/share/SE; Policy/Open; pair-face on buffered |
| **5** | Primary burn + redeposit ladder (+ optional withdrawSingle) | Multipath conformance; ProtocolLpEmpty; usage fee |
| **6** | Later bonds single-external; effectiveShares DETF-mids; free NFT transfer | Multi-external reverts; no synthetic gate |
| **7** | Mature-only sell→claim; maturity close single capitalToken; indefinite hold | Pre-maturity reverts |
| **8** | Claim deposit/redeem matrix; DETF out InvalidRoute; deposit reverts if not eligible | §4.14 green |
| **9** | Compound skip + epoch expansion epoch-end all-legs + min S_spot | Gentle + launch-rich rows |
| **10** | TestBase matrix \(n\in\{2,3,4,8\}\) + SE/RP/binding/refund/skew | §6 matrix |
| **11** | Adversarial + fork smoke | Reentrancy IsLocked; ≥1 fork profile |
| **12** | NatSpec + DoD checklist §7 | Product DoD boxes can be ticked |

**After each phase:** `forge build` green and that phase’s tests green before the next.

---

## 6. Testing expectations

### 6.1 TestBase ladder

```text
CraneTest
  → IndexedexTest
    → TestBase_VaultComponents (as needed)
      → (hook / SE / V4 PM TestBases as peers provide)
        → TestBase_UniswapV4StandardExchangeWeightedDETF
```

Production-first: real DFPkg, real manager/registry, real Weighted SE Buffer Hook package, real SEs. **No SUT mocks.** Mintable ERC20 OK for funding; reentrancy hostile ERC20 only for attack suites as vault share.

### 6.2 Priority matrix

| Row | Priority |
|-----|----------|
| \(n \in \{2,3,4,8\}\) hermetic | **Required** (n=8 smoke OK if heavy) |
| 1 SE + bare rest | **Required** (≥1 row for \(n \ge 3\)) |
| All external SE | **Required** (≥1 row for \(n \ge 3\)) |
| Reject all-external-bare | **Required** |
| DETF not binding index 0 | **Required** ≥1 row |
| RP on/off | ≥1 buffered config |
| Equal + unequal weights | Unequal required; equal optional |
| First-bond refund excess | **Required** |
| capitalToken always required (incl. \(m=1\)) | **Required** |
| Later single-pair bond adds only | **Required** |
| Multi-pair later bond reverts | **Required** |
| Per-route mint open / burn open skew | **Required** (via trades/seigniorage — not empty legs) |
| Epoch-end all-legs expansion | **Required** (rich end accrues; not-rich end 0; mid flip → 0) |
| Gentle + launch-rich \(R\) | Equal priority |
| Hook-SoT mint preview == exec | **Required** |
| Mature-only sell/close | **Required** |
| Claim DETF out InvalidRoute | **Required** |
| Fork smoke | ≥1 profile |

### 6.3 Spec list (map to PRD §15)

1. Deploy inert; primary mint reverts; non-first bond reverts.  
2. First bond all externals + capitalToken → live; missing external reverts; invalid capitalToken reverts; mids ≈ creation; MIN liquidity; **refund excess**; **full book** post-join.  
3. After first bond only: burn reverts (`ProtocolLpEmpty`) until mint/sell/compound.  
4. Later single-pair bond succeeds (adds); multi-pair later reverts; user DETF bond capital reverts; primary mint per-route Policy-gated; Open ungated.  
5. Whole-reserve `syntheticVs(pair)`; skew mint-open A / closed B; no rateAsset getter.  
6. Preview == execution mint/bond/burn/claim/maturity/sell contribution; mint matches **hook** preview.  
7. Seigniorage split peer ratios; burn usage fee.  
8. Bond LP on NFT; claimRewards while locked; pre-maturity principal exit reverts; NFT transferable; post-maturity close **only capitalToken** or sell→claim; hold indefinite.  
9. Claim redeem matrix; DETF out reverts; redeposit DETF; claim **deposit** reverts if not single-asset eligible.  
10. Primary burn multipath conformance; redeposit ladder; InvalidRoute on bad tokenOut.  
11. Compound increases protocol LP when eligible; **skips** when not.  
12. Expansion: epoch accrues only if all-legs mint-rich **at epoch end**; Open never; \(n=8\) gas smoke on realize.  
13. Decimal 6 + 18 pairs.  
14. Real hook + real SEs; hermetic + fork; no SUT mocks.  
15. Config rejects: all-bare, same SE twice, RP without SE, DETF in SE tokens, creation rate 0, bad weights, \(n\) OOB.  
16. Price movement under **default** thresholds via real reserve trades + seigniorage dilution.  
17. Nested reentrancy → `IsLocked`.  
18. Residual free inventory policy on success paths.  
19. All V4 doors swap after live (per priority \(n\); n=8 smoke OK).  
20. Primary mint `depositSingle` each external pair after full first bond.  
21. Free DETF binding not only index 0.  
22. `effectiveShares` multi-leg first bond / single-leg later (open-time DETF mids, not creation rates after live).  
23. Unequal weights + refund; no exact mid requirement.  
24. Pair-face mint on buffered leg.  
25. Expansion mid-epoch flip then end not-rich → 0 for that epoch.  

### 6.4 Adversarial (minimum)

| Attack | Expectation |
|--------|-------------|
| Reentrancy on mint/burn/bond/claim via hostile ERC20 share | `IsLocked` / nonReentrant |
| Donation DETF or SE shares to hook | Dilutes whole-reserve FD / LP ownership per hook law; document |
| Pre-maturity sell→claim | Revert `BondNotMature` |
| Burn with empty protocol LP | Revert |
| Redeposit failure mid-burn | Full tx revert (no burned DETF without payout) |
| First bond incomplete external set | Revert |
| Later multi-external bond | Revert |

---

## 7. Definition of Done (implementor)

Mirror PRD §18; all must be green before family stamp:

- [ ] Inert deploy; live only via permissionless first bond (all externals + capitalToken)  
- [ ] Creation-rate first bond; rates all `> 0`; mids ≈ creation; MIN liquidity; weights; unequal + **refund**; **full book**  
- [ ] Live mint / bond seigniorage peer-compatible; preview == execution; **hook SoT** quotes  
- [ ] Primary mint normal after full first bond; later bonds **add** only  
- [ ] Primary burn: user free DETF only; usage fee; redeposit ladder; multipath conformance  
- [ ] Claim redeem redeposits DETF; matrix; DETF out InvalidRoute; claim deposit reverts if not eligible  
- [ ] Mature-only sell/close; single capitalToken; NFT transfer metadata  
- [ ] Later bonds single external; multi-leg later reverts; effectiveShares DETF open-time mids  
- [ ] Compound skip when not eligible; user claim deposit does not skip  
- [ ] Per-route whole-reserve debt-inclusive synthetic; epoch-end all-legs expansion; no whole-DETF rateAsset  
- [ ] PkgArgs → hook \(n\in[2,8]\), weights, ≥1 SE + optional RPs + free DETF binding; all-bare reverts  
- [ ] Shared common bond/rebasing; mature-only DETF gate + shared flag true if present  
- [ ] §6 tests green (hermetic matrix + ≥1 fork profile)  

---

## 8. Sequencing vs other work

| Order | Work |
|-------|------|
| 1 | Weighted SE Buffer Hook PRD + plan + **frozen ABI** / DoD green (**hard coding gate**) |
| 2 | This DETF PRD product LOCK (may precede hook LOCK for product; coding still waits on 1) |
| 3 | **This plan** implementor stamp |
| 4 | Shared bond NFT + rebasing packages (LP principal + capitalToken + mature flag) — co-owned with CP/Orbital |
| 5 | DETF DFPkg + facets + tests (phases §5) |

**Hard gate:** DETF package coding **must not** invent hook APIs.

---

## 9. Risks & mitigations (implementor)

| Risk | Mitigation |
|------|------------|
| Divergent mint math | Hook SoT only; tests assert quote path == execution |
| Index remapping bugs | Worked examples in TestBase; binding maps storage; fuzz address sort |
| Whole-reserve FD gas at \(n=8\) | One residual preview + pure loop; fail-fast on all-legs boolean; n=8 smoke |
| Epoch-end richness semantics | Simple rule §4.5 + explicit tests; no pro-rate |
| Shared package immature for LP principal | Phase 0 extend common/ before family features that depend on it |
| Stack-too-deep on n-leg arrays | viaIR / Common helpers / binding-order structs |
| Confusing AGENTS rateAsset | Code + NatSpec: no rateAsset field; per-route getters only |

---

## 10. Revision history

| Version | Date | Notes |
|---------|------|-------|
| **v1.0** | 2026-08-05 | Initial plan aligned to PRD **v0.4**: whole-reserve per-route FD; hook-SoT quotes; first-bond refund + full book; single-external later bonds; single capitalToken; epoch-end all-legs expansion; claim deposit revert vs compound skip; partial-book myth out; \(n\in[2,8]\) matrix; phases + algorithms + DoD |

---

## 11. Approval

| Role | Sign-off |
|------|----------|
| Product | Pending (PRD v0.4 LOCK) |
| Protocol / implementor | Pending (this plan stamp) |

**Status:** Plan **v1.0** ready for implementor stamp after PRD product LOCK; coding gated on Weighted SE Buffer Hook frozen ABI (Phase 0).
