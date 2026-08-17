# Implementation & Test Plan: UniswapV4StandardExchangeOrbitalDETF

**PRD (product law SoT):** [`UniswapV4StandardExchangeOrbitalDETF_PRD.md`](./UniswapV4StandardExchangeOrbitalDETF_PRD.md) (**DRAFT v0.6**)  
**This plan (implementor SoT once accepted):** greenfield family package under `standardExchange/orbital/` — **do not** subclass CP UniV4 DETF or Balancer Single SE contracts.  
**Package root:** `contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/`  
**Date:** 2026-08-05  
**Status:** **Canonical plan aligned to PRD v0.6** — ready for implementor stamp after product LOCK on PRD; then phased coding. **No production code in this doc-only pass.**

---

## Authority

| Layer | Role |
|-------|------|
| **PRD v0.6** | Product law — wins on any conflict; patch this plan if PRD changes |
| **This plan** | Phases, file map, deploy path, math freeze notes, test matrix, DoD |
| **AGENTS.md** | DETF common expectations; CREATE3; manager vault registry for DETF DFPkg; production-first tests; co-located PRDs; mature-only sell→claim |
| **Crane skills** | `crane-deployment`, `crane-architecture`, `crane-testing` |
| **IndexedEx skills** | `indexedex-testing`, `indexedex-adversarial-testing`, `indexedex-uniswap-v4-hook-packages` |
| **CP UniV4 DETF peer** | Behavioral + facet/TestBase shape reference only — **do not subclass** |
| **Balancer Single SE peer** | Seigniorage split / fee-recipient NFT / bond lifecycle spirit — **do not subclass** |
| **Orbital SE Buffer Hook** | Hard dependency — multipath LP + `depositSingle` only (no zap-out) |

**Process rule:** If this plan and PRD disagree, **PRD wins** and this plan must be patched. Do not reopen PRD-locked Q1–Q26 without a PRD revision.

Deploy arity is [`UNISWAP_V4_SE_DETF_DEPLOY_MINE_NONCE_PRD.md`](../UNISWAP_V4_SE_DETF_DEPLOY_MINE_NONCE_PRD.md) / its implementation plan.

**Role names only:** `detfToken`, `pairToken0` / `pairToken1`, `standardExchange0` / `standardExchange1`, `vaultShare0` / `vaultShare1`, `rateProvider0` / `rateProvider1`, `rateAsset`, `reserveHook` / `reserveLp`, `bondNft`, `rebasingClaimToken`, `creationPair0PerDetfWad` / `creationPair1PerDetfWad`. No brand tickers.

---

## Read order for implementors

1. PRD §1 locked summary + §2 roles + §3 topology  
2. PRD §4 liveness / first bond (dual-leg, creation rates)  
3. PRD §5 pricing — **§5.3 Q15 rating**, **§5.5 FD full residual (Q21)**, **§5.6 burn + redeposit ladder**  
4. PRD §7–§9 mint / bond (mature-only, capital tokens, effectiveShares) / claim  
5. PRD §10 compound + epoch expansion; §11 PkgArgs; §15 tests; §20 Q table  
6. **This plan** §0–§7 (gates, phases, algorithms, tests)  
7. Hook plan/PRD for ABI only; CP DETF TestBase + Balancer Single SE TestBase as pattern only  

---

## 0. Starting state

| Item | Status |
|------|--------|
| PRD v0.6 | Present at package path |
| This plan | **This file** |
| DETF package Solidity | **None** — greenfield |
| Uni V4 DETF `common/nft` + `common/rebasing` | **Present but listing-era surfaces** (OOR / pair+detf absorb). **Must adapt or extend** for **fungible hook LP principal** + capital-token metadata + optional `requireMatureForSell` (PRD Q8, Q19). Prefer shared packages co-owned with CP family — do not invent a third NFT family |
| Shared `detf/common/core/*` | Exists — reuse thresholds, usage fee, bond math, compound helpers, epoch expansion (as CP peer) |
| Orbital SE Buffer Hook package | Under `contracts/hooks/uniswap/v4/standardExchange/orbital/` — **Phase 0 hard gate** |
| CP UniV4 Single SE DETF | Peer under `…/constantProduct/single/` — gold facet/DFPkg/TestBase shape |
| Balancer Single SE DETF | Gold peer for seigniorage split / fee-recipient / bond spirit |

**Do not** start by subclassing CP DETF Targets or forking monomorph orbital sources into this package.

---

## 1. Goals / non-goals

### Goals (v1 DoD)

1. Ship **true DETF** diamond + DFPkg under this path via **IndexedEx manager vault registry**.  
2. From **`PkgArgs`**, deploy **one** Orbital SE Buffer Hook via registry **`deployHookVault`**: DETF raw self-leg (any binding index) + two external pairs; **1–2** distinct SEs (≥1 required); optional RPs on SE legs only; three V4 doors in hook `postDeploy`.  
3. **Permissionless first bond** requiring **both** external pair legs at creation rates → `isReserveLive`; MINIMUM_LIQUIDITY edge.  
4. **Primary mint** (live): rate capital → funded pair-leg units (Q15) → seigniorage quote/split → hook **`depositSingle(pair)`** → protocol LP; **Policy debt-inclusive** mint gate; **revert if not zap-eligible**; **no** expansion realize.  
5. **Primary burn**: free DETF only → multipath `removeLiquidity` → **redeposit returned DETF** (ladder) → residual consolidate → chosen pair; `lpOut = detfBurned * protocolLp / effectiveSupply`; usage fee **yes**; **no** expansion realize.  
6. **Bond after live**: **no** synthetic mint gate; **single-leg OK**; multipath join; LP on bond NFT; capital metadata; `effectiveShares` via open-time sphere mids (Q18); **realizes** expansion.  
7. **Mature-only** sell→claim (DETF gate + shared flag); maturity close pays capital token(s) (single consolidate / dual residual); free NFT transfer; indefinite mature hold.  
8. Rebasing claim holds **protocol LP**; redeem matrix with redeposit DETF; prefer clean vaultShare path.  
9. **Protocol compound** single-sided DETF `depositSingle` when zap-eligible; **skip** (no revert) when not.  
10. **Epoch natural expansion** (Policy): same form as CP UniV4 DETF; pending in synthetic; realize only bond / claimRewards / compound.  
11. Production-first tests: hermetic matrix (**1 SE+bare**, **2 SE**, free binding index, RP on/off, gentle + launch-rich) + ≥1 fork profile; no SUT mocks.

### Non-goals (v1)

- Implementing the reserve hook inside this package.  
- Both-bare deploy; more than two external pairs; DETF as buffered SE leg.  
- Hook `withdrawSingle` / zap-out.  
- Subclassing CP UniV4 DETF, Balancer Single SE, or hook contracts.  
- Protocol “rebalance full book” surface.  
- MEV protection on first bond; fee-oracle expansion/threshold params.  
- FoT/rebasing pair tokens; native ETH currency; cross-chain.  
- Permit2 on DETF surface (optional later; hook may use Permit2 internally).

---

## 2. Hard gates & dependencies

| Gate | Requirement |
|------|-------------|
| **G0 Hook** | Orbital SE Buffer Hook: multipath `addLiquidity` / `removeLiquidity` / `preview*`, **`depositSingle` / `previewDepositSingle`**, fungible ERC-20 LP, `effectiveReserve(i)`, SE In/Out as needed for residual settle — **ABI frozen or DoD green** for hermetic use. **No** `withdrawSingle` |
| **G1 SE** | At least one production SE (hermetic ERC-4626 wrapper or protocol SE TestBase) with closed-form pair ↔ share routes; second SE for 2-SE matrix |
| **G2 Crane** | `CraneTest` → `IndexedexTest` → vault components; create3Factory + diamondPackageFactory |
| **G3 Registry** | DETF DFPkg via `indexedexManager.deploy*DFPkg` / registry path; hook via `deployHookVault` + hook diamond factory — **never** `new` facets/DFPkgs |
| **G4 Shared children** | Bond NFT + rebasing packages support **hook LP principal** (not listing OOR dual wings). Mature-only optional flag or DETF-only gate (Q19) |

**Coding must not invent hook APIs.** Consume only surfaces from the orbital hook PRD / frozen ABI.

**Hook ABI consumption checklist (document in TestBase comments):**

| DETF need | Hook surface |
|-----------|--------------|
| First bond / later multipath join | `addLiquidity(a0Max,a1Max,a2Max,…)` binding order |
| Primary mint / free DETF claim / compound | `depositSingle(tokenIn,…)` when zap-eligible |
| Burn / claim redeem / maturity | `removeLiquidity(shares,…)` → three amounts binding order |
| Previews | `previewAddLiquidity` / `previewRemoveLiquidity` / `previewDepositSingle` (exact names per frozen ABI) |
| FD + residual FX | `effectiveReserve` + sphere exact-in via SE In/Out or hook-exposed quote helpers if any; else DETF-layer sphere math matching hook fee-aware path — **must match execution** |
| LP token | Hook ERC-20 LP (`reserveLp`) |

---

## 3. Architecture (implementor map)

### 3.1 Deploy topology

```text
IndexedexManager / Vault Registry
  └── UniswapV4StandardExchangeOrbitalDETFDFPkg
        postDeploy:
          - deployHookVault(Orbital SE Buffer Hook PkgArgs from DETF PkgArgs):
              tokens[3] = binding order with DETF at detfBindingIndex
              standardExchange[3] (only external indices non-zero; ≥1 total)
              rateProvider[3] (only with SE)
              poolManager, feeOracle, mineNonce / salt
          - hook postDeploy inits all three V4 doors (DYNAMIC_FEE_FLAG, plumbing sqrtPrice)
          - deploy shared bond NFT package (owner=DETF; requireMatureForSell=true if flag exists)
          - deploy shared rebasing claim package (owner=DETF; holds protocol LP)
          - store PkgArgs: pairs, SEs, RPs, creation rates, rateAsset, thresholds, expansion, binding map
          - validate (PRD §11): pairs distinct; DETF raw only; ≥1 SE; SEs distinct; RP only with SE;
            pair ∈ SE.tokens() when SE set; DETF ∉ SE.tokens(); creation rates both > 0;
            rateAsset ∈ {pair0, pair1} (omit/0 → pair0); no FoT/rebasing pairs

Facets (CREATE3): Info / ExchangeIn / ExchangeOut / Bonding / Claim / (Compound on Info or Bonding)
Diamond instance = detfToken ERC-20 (immutable / unowned after deploy)
```

### 3.2 Suggested file map

```text
contracts/vaults/detf/protocols/dexes/uniswap/v4/
  standardExchange/orbital/
    UniswapV4StandardExchangeOrbitalDETF_PRD.md
    UniswapV4StandardExchangeOrbitalDETF_IMPLEMENTATION_AND_TEST_PLAN.md  # this file
    interfaces/
      IUniswapV4StandardExchangeOrbitalDETF.sol       # instance surface
      IUniswapV4StandardExchangeOrbitalDETDFPkg.sol    # PkgInit / PkgArgs HERE (Crane rule)
    UniswapV4StandardExchangeOrbitalDETFRepo.sol
    UniswapV4StandardExchangeOrbitalDETFCommon.sol     # pricing, gates, quote, FD, residual, scale
    UniswapV4StandardExchangeOrbitalDETFInfoTarget.sol
    UniswapV4StandardExchangeOrbitalDETFExchangeInTarget.sol
    UniswapV4StandardExchangeOrbitalDETFExchangeOutTarget.sol
    UniswapV4StandardExchangeOrbitalDETFBondingTarget.sol
    UniswapV4StandardExchangeOrbitalDETFClaimTarget.sol
    UniswapV4StandardExchangeOrbitalDETF*Facet.sol
    UniswapV4StandardExchangeOrbitalDETFDFPkg.sol
    UniswapV4StandardExchangeOrbitalDETF_Facet_FactoryService.sol
    UniswapV4StandardExchangeOrbitalDETF_Pkg_FactoryService.sol
    UniswapV4StandardExchangeOrbitalDETF_Component_FactoryService.sol
    TestBase_UniswapV4StandardExchangeOrbitalDETF.sol
  common/
    nft/      # SHARED with CP — extend for LP principal + capital metadata + mature flag
    rebasing/ # SHARED with CP — claim on protocol hook LP; multi-pair residual redeem via DETF
```

**Libs (prefer extend, not fork):**

| Lib | Use |
|-----|-----|
| `DETFThresholdPolicy` | Policy/Open resolve + gates |
| `DETFUsageFeeLib` / peer mint split | Seigniorage split; **burn usage fee** |
| `DETFBondNFTMathLib` / `DETFBondLifecycleLib` | Lock clamp, bond lifecycle |
| `DETFProtocolCompoundLib` | Compound helpers |
| `DETFNaturalExpansionLib` / epoch peer | Whole-epoch pending + mint (same as CP UniV4 DETF) |
| Pure sphere / residual helpers | Family-local lib OK if hook does not export pure quotes — **must bit-match hook fee law** |

### 3.3 Storage (Repo sketch)

```text
// UniswapV4StandardExchangeOrbitalDETFRepo (names indicative)
isReserveLive
pairToken0 / pairToken1
standardExchange0 / standardExchange1          // address(0) = bare
vaultShare0 / vaultShare1                      // when SE set
rateProvider0 / rateProvider1                  // optional; only if SE set
rateAsset                                      // pair0 or pair1
detfBindingIndex                               // 0, 1, or 2
// map product legs → binding indices (pair0Index, pair1Index, detfIndex)
reserveHook
bondNftVault
rebasingClaimToken / protocolLpHolder (= rebasing)
feeOracle
creationPair0PerDetfWad / creationPair1PerDetfWad   // both > 0
thresholdMode, mintThreshold, burnThreshold
expansionEpochLength
expansionClosureRatePerYearWad
expansionMaxCatchUpEpochs                      // 0 = unlimited
lastExpansionTimestamp                         // 0 until first realize-path seed after live
feeRecipientNftId
// optional: poolManager ref if needed for views
```

**Bond NFT position metadata (product-required; layout plan-freezes):**

```text
// per tokenId (on NFT package or DETF-side map owned by NFT)
capitalMode          // Single = 1, Dual = 2
capitalToken0        // primary capital pair (always set for single; one of two for dual)
capitalToken1        // address(0) if single; second pair if dual
// optional analytics: capitalNotional0/1 at open — NOT used for dual close proportion
effectiveShares
unlockTime
lpPrincipal (or tracked via balance)
```

Slot form: Crane ERC1967-style `DEFAULT_SLOT = bytes32(uint256(keccak256(abi.encode("…"))) - 1)`.

### 3.4 Public surface (facet split)

| Facet group | Functions (min) |
|-------------|-----------------|
| **Info** | `isReserveLive`, `syntheticPrice` (debt-inclusive), `pendingExpansionDetf`, optional `syntheticPriceSpot`, thresholds, `isMintingAllowed` / `isBurningAllowed`, creation rates, `rateAsset`, pairs, SEs, RPs, DETF binding index, reserve hook, expansion getters, `acceptedBondTokens`, protocol LP views |
| **ExchangeIn** | Mint DETF from pair0/pair1 / vaultShare / SE token (Q15 rating) |
| **ExchangeOut** | Burn free DETF → `tokenOut` ∈ {pair0, pair1} (+ SE unwrap matrix if exposed on burn); else `InvalidRoute` |
| **Bonding** | `bond`, maturity close, `sellPositionToDetfNft` (**mature only**), `claimRewards` |
| **Claim** | Direct deposit (pair/share/SE/DETF); `redeemClaim` with tokenOut matrix |
| **Compound** | `compoundProtocolRewards` (skip if not zap-eligible) |

**Previews (LOCKED):** every closed-form path has a view with preview == execution (≤ few-wei only if SE multi-leg dust; document).

**Errors (stable family):**

| Error | When |
|-------|------|
| `InvalidRoute` | Bad tokenIn/tokenOut matrix |
| `ReserveNotLive` / peer | Pre-live primary mint/burn / non-first bond |
| `MintNotAllowed` / `BurnNotAllowed` | Policy gates |
| `BondNotMature` | Pre-maturity sell or principal close |
| `FirstBondRequiresBothPairs` | Single-pair first bond |
| `NotZapEligible` | Primary mint when partial/empty book |
| `ProtocolLpEmpty` / insufficient | Burn with no protocol LP |
| `InvalidCreationRate` | Deploy: rate ≤ 0 |
| `BothBareForbidden` / peer | Deploy: zero SEs |
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

### 4.2 Capital rating to pair-leg units (PRD Q15)

```text
rateTokenInToPairLeg(tokenIn, amountIn) → (fundedPairLeg, pairNotionalWad):
  if tokenIn == pairToken0: (0, toWad(amountIn, d0))
  if tokenIn == pairToken1: (1, toWad(amountIn, d1))
  if tokenIn == vaultShare_i (SE_i set):
    pairNotional = always rate shares → pair units (RP or claim)  // never skip
    → (i, pairNotionalWad)
  if tokenIn ∈ SE_i.tokens() (SE_i set):
    SE route → pair face → (i, pairNotionalWad)
  else: revert InvalidRoute

// Mint quote: do NOT convert pairNotional through rateAsset mid
pairBoosted = pairNotionalWad * (1e18 + seigniorageIncentiveWad) / 1e18
grossDetf   = quoteDetfAgainstReserve(fundedPairLeg, pairBoosted)
```

### 4.3 `quoteDetfAgainstReserve` (PRD Q22)

**Economic identity:** fee-aware closed-form DETF gross for exact-in **pair-leg** notional against **live effective reserves** — inverse of single-sided capital priced vs live book (primary-mint / `depositSingle` spirit).

```text
// Implementor freeze (Phase 3):
// - Prefer hook-native pure helpers if exported
// - Else family lib that mirrors hook sphere + fee residual for “pair leg in → DETF out”
// - MUST share one path for preview + execution mint/bond quotes
// - NOT creation rate after live
// - NOT forced convert via other pair / rateAsset mid
// - NOT tick-walk / unbounded binary search
// - Document ≤ few-wei only if SE multi-leg dust forces it
```

Unit tests: fixed book state → quote; execute mint; assert user DETF within wei budget of preview.

### 4.4 Debt-inclusive synthetic + FD (PRD §5.5, Q21)

**Peg:** abstract 1e18 = FD **rateAsset** backing per DETF equals **creation rate of rateAsset** only. Other pair floats freely.

```text
previewLpToRateAsset(lp):
  (a_detf, a_p0, a_p1) = previewRemoveLiquidity(lp)  // binding order → product map
  // FULL residual → rateAsset (include DETF self-leg):
  fd = toWad(a_rateAsset face)
  fd += sphereExactInSell(otherPair → rateAsset, a_other)
  fd += sphereExactInSell(DETF → rateAsset, a_detf)
  return fd

// Counted LP set (peer): protocol LP holder (rebasing) + bond NFT package LP
//   + diamond only if product holds free LP (prefer zero free LP on diamond)
// Exclude address(0) MINIMUM_LIQUIDITY residual

fdRateAssetWad = sum previewLpToRateAsset(lp) over counted holders

creationRateAssetPerDetfWad =
  rateAsset == pair0 ? creationPair0PerDetfWad : creationPair1PerDetfWad

S_spot = (fdRateAssetWad * 1e18 / max(totalSupply,1)) * 1e18 / creationRateAssetPerDetfWad
// totalSupply==0 → treat as 1e18 for inert info if needed

pending = previewPendingExpansionMint()
effectiveSupply = totalSupply + pending
synthetic = (fdRateAssetWad * 1e18 / max(effectiveSupply,1)) * 1e18 / creationRateAssetPerDetfWad
```

**Important:** execution redeposit of DETF on burn/claim does **not** redefine FD. FD answers extractable LP claim in rateAsset.

**Gates:** Policy primary mint/burn use debt-inclusive `synthetic`. Open: gates always pass when live; pending expansion = 0. First bond: ungated. Bonds after live: **no** synthetic mint gate.

### 4.5 Pending expansion + realize (same as CP UniV4 DETF)

```text
previewPendingExpansionMint():
  if !live || Open || lastExpansionTimestamp == 0: return 0
  if now <= last: return 0
  epochs = (now - last) / expansionEpochLength
  if maxCatchUpEpochs > 0: epochs = min(epochs, maxCatchUpEpochs)
  if epochs == 0: return 0
  S_spot = … §4.4
  if S_spot <= 1e18: return 0
  closurePerEpoch = expansionClosureRatePerYearWad * expansionEpochLength / YEAR
  premium = S_spot - 1e18
  mintPerEpoch = totalSupply * premium * closurePerEpoch / (1e18 * S_spot)
  mint = mintPerEpoch * epochs
  return mint <= dust ? 0 : mint

_realizeExpansionIfNeeded():
  if !live || Open: return
  if last == 0: last = now; return   // seed after live; no pre-live backlog
  pending = previewPendingExpansionMint()
  if pending == 0: return
  _mintDetf(bondNftVault, pending)   // reward ledger sink
  epochs = … same as preview …
  last += epochs * expansionEpochLength
```

**Forbidden on primary mint/burn:** realize + any advance of `lastExpansionTimestamp`.

**Realize paths:** bond, `claimRewards`, `compoundProtocolRewards` (+ reward updates on those paths).

### 4.6 Seigniorage mint split (peer)

```text
pairBoosted = pairNotionalWad * (1e18 + seigniorageIncentive) / 1e18
gross = quoteDetfAgainstReserve(fundedPairLeg, pairBoosted)
feeTo = gross * usageFee / 1e18
afterFee = gross - feeTo
inventory = afterFee * (seigniorageIncentive / 2) / 1e18   // peer half-incentive inventory
user = afterFee - inventory
```

| Path | Capital → reserve | Free DETF |
|------|-------------------|-----------|
| Live primary mint | Settle → `depositSingle(pairLeg)`; **revert if not zap-eligible** | Mint user / feeTo / inventory only |
| Bond (live) | Multipath maxes (1 or 2 pairs + join DETF); LP → NFT | Also free legs from split |
| First bond | Creation-rate sized join DETF + **both** pairs | Free legs from split of gross |

### 4.7 First bond (PRD §4.4)

```text
// require both pair notionals C0, C1 > 0 after settle (else FirstBondRequiresBothPairs)
detfFrom0 = pair0NotionalWad * 1e18 / creationPair0PerDetfWad
detfFrom1 = pair1NotionalWad * 1e18 / creationPair1PerDetfWad
detfForJoinWad = min(detfFrom0, detfFrom1)
require detfForJoinWad > 0

// Apply mint modifiers / seigniorage split on join-sized gross (peer spirit)
// Only join-sized DETF enters multipath; free user/fee/inventory stay outside pool

// Binding-order maxes: put DETF on detfBindingIndex, pairs on their indices
// addLiquidity multipath; LP → bond NFT
// capitalMode = Dual; record both capital tokens
// effectiveShares = rateAsset value of both legs at open (creation mids ≈ creation rates on empty book)
// isReserveLive = true
```

Pre-live: primary mint/burn revert; non-first bond revert.  
If hook geometric / MIN liquidity fails → clear product error (cannot go live).

### 4.8 Primary burn (PRD §5.6, Q3, Q23, Q24)

```text
// no expansion realize
require live + debt-inclusive burn gate (Open: when live)
pending = previewPendingExpansionMint()
effectiveSupply = totalSupply + pending
protocolLp = reserveLp.balanceOf(protocolLpHolder)
lpOut = detfBurned * protocolLp / effectiveSupply
if protocolLp == 0 || lpOut == 0: revert ProtocolLpEmpty

// order freezes in Phase 3 — atomic full success or full revert:
1. pull + burn only detfBurned (user free DETF)
2. apply burn usage fee (YES — DETFUsageFeeLib peer)
3. removeLiquidity(lpOut) → (a_detf, a_p0, a_p1)
4. redeposit all a_detf:
     prefer depositSingle(DETF) if zap-eligible
     else multipath addLiquidity DETF-max / zero other maxes if hook accepts
     else revert entire tx
5. consolidate non-tokenOut pair → tokenOut (sphere / SE In-Out)
6. pay tokenOut (+ tokenOut dust to user)
7. enforce minOut

// Dust of other pair below plan dust threshold may remain on diamond — NatSpec + tests
```

**Do not** burn returned DETF. **Do not** pay returned DETF to burner. **Do not** draw bond-NFT LP.

### 4.9 Redeposit ladder (shared helper)

Used by: primary burn, claim redeem, maturity close, sell fallback.

```text
_redepositDetfSelfLeg(amountNative):
  if amount == 0: return
  if zapEligible: depositSingle(DETF, amount, …) → protocol LP holder
  else if multipath single-leg DETF accepted: addLiquidity with DETF max only
  else: revert
```

### 4.10 Residual consolidate + sphere exact-in

```text
// Convert amount of tokenA → tokenB using same fee-aware closed form as hook SE In/Out / sphere
// Prefer hook SE In/Out when both are pool tokens on doors
// Order of multi-hop sells for FD (DETF + other pair → rateAsset) frozen in Phase 3 tests
// Preview path MUST match execution path bit-exact at same fee/oracle reads
```

### 4.11 Bond after live (PRD §8)

```text
_realizeExpansionIfNeeded()
// NO synthetic mint gate
// Capital: one or both external pairs (or SE capital settling to them)
// Quote join DETF + free legs (Q15 rating per funded leg; multipath maxes)
// addLiquidity; LP → NFT
// capitalMode = Single if one pair funded else Dual
// effectiveShares (Q18):
//   for each funded external pair notional:
//     convert to rateAsset at open-time sphere mids (fee-aware closed form)
//   sum * lockBonus
//   DETF join leg does NOT add to effectiveShares
// lock: revert if < min; clamp to max (bonus at max)
```

**Pre-maturity:** only `claimRewards` (+ free ERC-721 transfer). No early close, no early sell.

### 4.12 Maturity close (PRD §8.2.1, Q13, Q20)

```text
require mature
pay pending rewards (realize path)
withdraw all position LP from NFT
removeLiquidity(lp)
_redepositDetfSelfLeg(a_detf)
if capitalMode == Single:
  sell other pair → capitalToken (sphere/SE)
  pay only capitalToken
if capitalMode == Dual:
  pay residual a_p0 and a_p1 as-is  // residual composition, NOT open notionals
retire NFT
```

### 4.13 Sell → rebasing claim (PRD §8.3, Q11, Q19)

```text
require mature  // DETF surface ALWAYS; shared flag true if present
pay pending rewards
transfer reserveLp from bond NFT → rebasing package (prefer ERC-20 transfer)
mint claim from Δ protocol LP contribution valued as previewLpToRateAsset(Δlp)
credit protocol NFT id 0 if peer ledger requires
retire user NFT

// Fallback if transfer blocked: remove → redeposit DETF → remint LP / residual deposit — still mature only
```

### 4.14 Claim mint / redeem (PRD §9)

**Mint claim (no seigniorage):**

| Path | Mechanics |
|------|-----------|
| Bond sell (mature) | §4.13 |
| New money pair/share/SE | Settle → `depositSingle(pair)` when zap-eligible → LP to protocol → mint claim |
| Free DETF | `depositSingle(DETF)` → LP to protocol → mint claim (user impact) |

**Redeem:**

```text
lpOut = claimSharesBurned * protocolLp / claimTotalSupply
burn claim shares only
removeLiquidity(lpOut)
_redepositDetfSelfLeg(a_detf)
residual → tokenOut matrix:
  rateAsset | other pair | vaultShare_i (prefer clean share path) | SE token
else InvalidRoute
```

### 4.15 Protocol compound (PRD §10.1, Q6)

```text
compoundProtocolRewards():
  _realizeExpansionIfNeeded()   // public compound IS a realize path
  update bond rewards
  harvest protocol NFT pending free DETF
  if !zapEligible: return (0,0)  // SKIP — do not revert
  depositSingle(DETF) → protocol LP ↑
  no new claim shares
```

Lazy: on bond / claimRewards after realize; **not** on primary mint/burn. Join failure on lazy: best-effort leave pending.

### 4.16 PkgArgs resolve

| Arg | Resolve |
|-----|---------|
| `expansionEpochLength == 0` | `8 hours` |
| `expansionClosureRatePerYearWad == 0` | `0.10e18` (10% premium/yr gentle) |
| `expansionMaxCatchUpEpochs == 0` | unlimited |
| thresholds 0 | `DETFThresholdPolicy` defaults (1.05e18 / 0.95e18) |
| `thresholdMode` 0 / omit | Policy |
| `rateAsset` omit / 0 | `pairToken0` |
| `creationPair*PerDetfWad` | **must both be > 0** — no default; deploy reverts |
| SE slots | **≥1 non-zero** among external legs; both bare reverts |
| `detfBindingIndex` | 0, 1, or 2; external pairs fill other indices |

Launch-rich templates set explicit `R` (e.g. `4.4e18`) — copy CP UniV4 DETF §10.3–§10.4 tables; do not re-derive ad hoc.

---

## 5. Phased implementation

### Phase 0 — Dependency readiness (no DETF product logic)

| ID | Work | Exit |
|----|------|------|
| 0.1 | Confirm orbital hook TestBase: multipath add/remove, `depositSingle` when full book, LP ERC-20, effective reserves; **1 SE + bare** and **2 SE** configs | Green hermetic hook tests reusable by DETF TestBase |
| 0.2 | Document hook selectors/ABI surface consumed by DETF (checklist §2) | Checklist in TestBase / plan comments |
| 0.3 | Confirm SE closed-form pair ↔ share + optional RP | Reuse in DFPkg validation |
| 0.4 | Gap analysis: shared `common/nft` + `common/rebasing` vs **hook LP principal** + capital metadata + mature flag | Written delta; either extend packages or schedule Phase 0.5 |

**Phase 0.5 — Shared package adaptation (if gap analysis requires)**

| ID | Work | Exit |
|----|------|------|
| 0.5.1 | Bond NFT: hold ERC-20 hook LP; open with lp amount + effectiveShares + unlock + **capital mode/tokens**; free transfer; optional `requireMatureForSell` | Unit tests green |
| 0.5.2 | Rebasing: hold protocol LP; mint/redeem contribution via DETF-orchestrated `previewLpToRateAsset` / residual | Unit tests green |
| 0.5.3 | CP family still builds/tests if packages shared | No silent CP regression (or document CP migration follow-through) |

**Do not** start Phase 1 DETF diamond until 0.1 is usable in-process.

### Phase 1 — Scaffold + deploy path

| ID | Work | Exit |
|----|------|------|
| 1.1 | Interfaces with **`PkgInit` / `PkgArgs` on interface** (Crane rule) | Compiles |
| 1.2 | Repo + Common stubs (scale, getters, gate shells) | Compiles |
| 1.3 | Facets + FactoryService CREATE3 deploy paths | Facet registry labels |
| 1.4 | DFPkg + manager `deploy*Orbital*DFPkg` + postDeploy: `deployHookVault`, children, validations | Inert instance deployable |
| 1.5 | Reject both-bare, creation rate 0, RP without SE, same SE twice, DETF in SE tokens, DETF not raw | Deploy negative tests green |
| 1.6 | TestBase: `CraneTest` → `IndexedexTest` → … → deploy DFPkg | `test_deploy_inert` green |
| 1.7 | Free binding index deploy row (DETF not at index 0) | Green |

### Phase 2 — First bond → live

| ID | Work | Exit |
|----|------|------|
| 2.1 | Wire bond NFT package (LP principal + dual capital metadata) | Create position with LP |
| 2.2 | First bond: both pairs required; creation-rate join DETF; multipath; free legs outside; LP on NFT; live=true | Permissionless first bond green |
| 2.3 | Single-pair first bond reverts `FirstBondRequiresBothPairs` | Spec green |
| 2.4 | Pre-live: primary mint/burn revert; non-first bond revert | Spec green |
| 2.5 | MINIMUM_LIQUIDITY / geometric first-bond fail clear error | Spec green |
| 2.6 | Mids ≈ creation at join (modulo SE fees/dust); free legs do not re-size join | Asserts documented |

### Phase 3 — Primary mint / burn + seigniorage + FD

| ID | Work | Exit |
|----|------|------|
| 3.1 | Q15 capital rating + `quoteDetfAgainstReserve` + split | Unit/integration vs hook state |
| 3.2 | Live primary mint either pair; `depositSingle`; preview == execution | Spec green |
| 3.3 | Primary mint reverts `NotZapEligible` on partial book | Spec green |
| 3.4 | FD `previewLpToRateAsset` **includes DETF→rateAsset**; debt-inclusive synthetic | Assert FD > pairs-only residual |
| 3.5 | Primary burn: user free DETF only; usage fee; redeposit ladder; residual consolidate; effectiveSupply | Preview == execution |
| 3.6 | After first bond only: burn reverts (protocol LP empty) until mint/sell/compound | Spec green |
| 3.7 | Primary mint/burn **do not** change `lastExpansionTimestamp` / mint expansion | Explicit asserts |
| 3.8 | Policy/Open gate matrix; invalid tokenOut → `InvalidRoute` | Spec green |

### Phase 4 — Bond lifecycle + claim

| ID | Work | Exit |
|----|------|------|
| 4.1 | Second+ bond: **no** synthetic gate; single-leg OK; realize expansion; LP on NFT | Spec green |
| 4.2 | `effectiveShares` multi-leg: open-time sphere mids → rateAsset (not creation rates after live) | Spec green |
| 4.3 | Lock clamp; claimRewards free DETF while locked (realize) | Spec green |
| 4.4 | Pre-maturity: sell and close **revert** `BondNotMature`; only claimRewards + NFT transfer | Spec green |
| 4.5 | NFT transfer mid-lock preserves unlock + capital metadata | Spec green |
| 4.6 | Maturity close single capital: consolidate other pair → capital token | Spec green |
| 4.7 | Maturity close dual capital: residual composition (skew book then assert ≠ open notionals) | Spec green |
| 4.8 | Sell → protocol LP + claim mint; contribution = previewLpToRateAsset | Spec green |
| 4.9 | Indefinite mature hold (no forced close) | Spec green |
| 4.10 | Rebasing holds protocol LP; direct claim deposits (pair/SE/DETF) | Spec green |
| 4.11 | Claim redeem: rateAsset, other pair, vaultShare (clean path), SE token; redeposit DETF | Spec green |
| 4.12 | Fee-recipient NFT like peer; same mature-only if they bond | Spec green |

### Phase 5 — Epoch expansion + compound

| ID | Work | Exit |
|----|------|------|
| 5.1 | Epoch expansion (shared or family) + storage | Pure unit tests on formula |
| 5.2 | `pendingExpansionDetf` + debt-inclusive `syntheticPrice` | Warp without realize → synthetic falls |
| 5.3 | Realize on bond / claimRewards / compound only | Cross-path matrix |
| 5.4 | `compoundProtocolRewards`: zap-eligible join; **skip without revert** when not | Spec green |
| 5.5 | **Gentle** and **launch-rich** PkgArgs matrix equal priority | Both green |
| 5.6 | Open never expands; Policy only | Spec green |

### Phase 6 — Hardening

| ID | Work | Exit |
|----|------|------|
| 6.1 | Config matrix: **1 SE + bare**, **2 SE**, RP on/off, bare rateAsset + buffered other, free DETF binding | All green |
| 6.2 | Three V4 doors swap after live (via hook/public path) | Smoke green |
| 6.3 | Decimal scaling: 6-dec + 18-dec pairs | Spec green |
| 6.4 | Price movement under **default** thresholds via real door trades + seigniorage dilution | Spec green |
| 6.5 | Adversarial: nested reentrancy → `IsLocked`; donation notes; empty protocol burn; redeposit failure reverts whole burn | Spec green |
| 6.6 | Residual free inventory zero on success paths where peers require; dust policy documented | Spec green |
| 6.7 | Fork TestBase (Base and/or Ethereum / Robinhood 4663 as available) | Smoke + one full lifecycle |
| 6.8 | Size / forge build | Facets within project limits |

### Phase 7 — Docs / shared law follow-through

| ID | Work | Exit |
|----|------|------|
| 7.1 | PRD LOCK stamp when product signs off | Status LOCK |
| 7.2 | Note shared expansion PRD alignment (epoch form; this family in scope) | PR open or merged if needed |
| 7.3 | Optional: UI handoff (APY honesty, debt-inclusive synthetic, dual-pair UX, mature-only) | Doc only |
| 7.4 | If CP still early-sell: migration note for DETF-wide mature-only standard | Tracking issue / PR |

---

## 6. Testing plan

### 6.1 Test layout

```text
contracts/.../standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalDETF.sol

test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/
  UniswapV4StandardExchangeOrbitalDETF_Deploy.t.sol
  UniswapV4StandardExchangeOrbitalDETF_FirstBond.t.sol
  UniswapV4StandardExchangeOrbitalDETF_MintBurn.t.sol
  UniswapV4StandardExchangeOrbitalDETF_Bond.t.sol
  UniswapV4StandardExchangeOrbitalDETF_Claim.t.sol
  UniswapV4StandardExchangeOrbitalDETF_Expansion.t.sol
  UniswapV4StandardExchangeOrbitalDETF_Compound.t.sol
  UniswapV4StandardExchangeOrbitalDETF_Adversarial.t.sol

test/foundry/fork/.../uniswap/v4/standardExchange/orbital/
  UniswapV4StandardExchangeOrbitalDETF_Fork.t.sol
```

### 6.2 TestBase requirements

- Inherit production ladder (`CraneTest` → `IndexedexTest` → vault/hook/SE bases as needed).  
- Deploy real DETF DFPkg via **manager registry**; real orbital hook via **`deployHookVault`**; real SEs (wrapper hermetic acceptable).  
- **No** mocks of SUT: DETF, facets, DFPkg, manager, registry, fee oracle, hook, attached SEs.  
- Helpers: fund pairs/shares; `firstBondBothPairs`; `bondSingleLeg`; warp epochs; force partial book; read synthetic / pending / protocol LP / capital metadata; assert preview==exec.  
- **First-class config rows:**  
  - **1 SE + 1 bare**  
  - **2 SE**  
  - **RP on / off** for ≥1 buffered config  
  - **DETF binding index ≠ 0**  
  - **Gentle** expansion (epoch 0→8h, R 0→10%/yr)  
  - **Launch-rich** expansion (explicit high R)  
  - bare `rateAsset` + buffered other leg  

### 6.3 Spec matrix (minimum)

| Area | Cases |
|------|--------|
| Deploy | Inert; both-bare revert; creation 0 revert; RP without SE; same SE twice; DETF in SE; free binding |
| Live | Dual first bond; single first bond reverts; pre-live blocks |
| Mint | Either pair; share/SE token; NotZapEligible; Policy/Open; no expansion realize |
| Burn | EffectiveSupply; usage fee; redeposit; residual; empty protocol LP; InvalidRoute |
| FD | Includes DETF→rateAsset; debt-inclusive synthetic |
| Bond | Single-leg after live; multi-leg effectiveShares; mature-only; transfer; dual residual close |
| Claim | Deposit matrix; redeem matrix; redeposit DETF |
| Expansion | Policy only; Open never; realize paths only; gentle + launch-rich |
| Compound | Join when eligible; skip when not |
| Market | Three doors trade after live |
| Adversarial | Reentrancy IsLocked; donation; redeposit atomicity |

### 6.4 Commands (indicative)

```bash
forge test --match-path test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/** -vv
forge test --match-contract UniswapV4StandardExchangeOrbitalDETF -vvv
forge test --match-path test/foundry/fork/**/orbital/** -vv   # when RPC configured
forge build --sizes
```

---

## 7. Anti-patterns (reject in review)

| Reject | Instead |
|--------|---------|
| `new` facet / DFPkg | CREATE3 FactoryService + manager registry |
| `deployHookVault` bypass / monomorph CREATE3 product factory as primary | Registry + hook diamond factory (skill) |
| Subclass CP DETF / Balancer Single SE / hook Targets | Fresh Targets; shared libs only |
| Invent `withdrawSingle` on hook or DETF | Multipath remove + residual + redeposit |
| Burn DETF returned from remove | Redeposit ladder |
| Pairs-only FD | Full residual incl. DETF→rateAsset (Q21) |
| Dual close using open notionals | Residual composition (Q20) |
| Early sell→claim | Mature only; DETF gate mandatory |
| Mock SUT vaults/manager/registry/hook/SEs under test | Production-first TestBases |
| Expansion / thresholds on fee oracle | Deploy-time PkgArgs only |
| Rate capital through rateAsset mid for mint quote | Q15 pair-leg rating only |
| Single expansion TestBase only | Gentle **and** launch-rich equal rows |
| Both-bare production config | ≥1 SE (Q12) |
| `UnsupportedRoute` | `InvalidRoute` + family errors |

---

## 8. Definition of Done (product + engineering)

### Product (from PRD §18)

- [ ] Inert deploy; live only via permissionless first bond with **both** pairs  
- [ ] Creation-rate first bond (both rates `> 0`); mids ≈ creation at join; MINIMUM_LIQUIDITY handled  
- [ ] Live mint (either pair) / bond seigniorage split peer-compatible; preview == execution  
- [ ] Primary mint reverts when not zap-eligible; no protocol rebalance API  
- [ ] Primary burn: only user free DETF; usage fee; redeposit ladder; protocol LP / effectiveSupply  
- [ ] Claim redeem redeposits DETF; tokenOut matrix; InvalidRoute elsewhere  
- [ ] Sell→claim and maturity close **revert pre-maturity**; post-maturity single/dual capital rules; NFT transfer preserves metadata  
- [ ] Later bonds single-leg OK; multi-leg `effectiveShares` via open-time sphere mids  
- [ ] Compound skips when not zap-eligible  
- [ ] Policy/Open debt-inclusive synthetic with **FD full residual incl. DETF→rateAsset**; expansion realize only bond/claim/compound  
- [ ] PkgArgs: 1–2 SEs, optional RPs, free DETF binding; both-bare reverts; rateAsset default pair0  
- [ ] Shared common bond/rebasing; mature-only DETF gate (+ shared flag true)  

### Engineering

- [ ] Phases 0–6 green hermetic (or documented skip with owner approval)  
- [ ] At least one fork lifecycle smoke green (or documented env block)  
- [ ] No SUT mocks; production deploy path only  
- [ ] `forge build --sizes` acceptable for facets  
- [ ] Plan deviations recorded in §10 if any  

---

## 9. Suggested work ordering for agents

1. **Phase 0** hook readiness + ABI checklist.  
2. **Phase 0.5** shared NFT/rebasing LP-principal adaptation (if needed).  
3. **Phase 1** scaffold + inert deploy + validation negatives.  
4. **Phase 2** first bond → live.  
5. **Phase 3** mint/burn + FD + quote freeze (before expansion).  
6. **Phase 4** bond/claim/maturity/sell (realize hooks stubbed then wired).  
7. **Phase 5** expansion + compound.  
8. **Phase 6** matrix + adversarial + fork.  
9. **Phase 7** docs / LOCK / shared-law notes.

---

## 10. Implementation status

| Phase | Status | Evidence |
|-------|--------|----------|
| 0 | [ ] | — |
| 0.5 | [ ] | — |
| 1 | [ ] | — |
| 2 | [ ] | — |
| 3 | [ ] | — |
| 4 | [ ] | — |
| 5 | [ ] | — |
| 6 | [ ] | — |
| 7 | [ ] | — |

---

## 11. Deviations (honest log)

| Topic | Plan / PRD | Actual | Why |
|-------|------------|--------|-----|
| — | — | — | Fill only when shipping diverges; prefer patch PRD/plan first |

---

## 12. Plan-only freezes (not product forks)

Track here during Phase 3–4; do not invent product law:

| Item | Owner phase |
|------|-------------|
| Exact hook preview selector names | 0 / 3 |
| `quoteDetfAgainstReserve` fixed-point + fee terms matching hook | 3 |
| Sphere exact-in hop order for FD (DETF vs other pair first) | 3 |
| Atomic burn order: burn DETF vs remove vs redeposit vs pay | 3 |
| Bond NFT storage slots for capital mode/tokens | 0.5 / 4 |
| Shared package `requireMatureForSell` flag name/ABI | 0.5 / 4 |
| Dust threshold for uneconomic residual pair | 3 |
| Multipath max array order for free DETF binding index | 2 |
| Whether multipath DETF-only max is accepted by live hook (redeposit fallback) | 0 / 3 |

---

## 13. Revision history

| Version | Date | Notes |
|---------|------|-------|
| **v0.1** | 2026-08-05 | First plan aligned to PRD v0.6: dual-leg first bond; Q15 rating; FD full residual; redeposit ladder; mature-only; dual residual close; effectiveShares open mids; hook no zap-out; shared package Phase 0.5; hermetic matrix |

---

## 14. Acceptance

| Role | Sign-off |
|------|----------|
| Product | Pending (PRD LOCK first) |
| Protocol / implementor | Pending — stamp this plan before Phase 1 coding |

**Status:** Plan v0.1 ready for implementor stamp **after** PRD v0.6 product LOCK (or concurrent stamp with product acceptance of v0.6 decisions). Then Phase 0 → 0.5 → 1….
