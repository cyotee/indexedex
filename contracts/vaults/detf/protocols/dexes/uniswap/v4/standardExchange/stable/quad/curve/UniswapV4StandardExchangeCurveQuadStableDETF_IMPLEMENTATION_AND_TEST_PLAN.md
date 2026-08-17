# Implementation & Test Plan: UniswapV4StandardExchangeCurveQuadStableDETF

**PRD (product law SoT):** [`UniswapV4StandardExchangeCurveQuadStableDETF_PRD.md`](./UniswapV4StandardExchangeCurveQuadStableDETF_PRD.md) (**LOCKED v0.4**)  
**This plan (implementor SoT once accepted):** greenfield family package under `standardExchange/stable/quad/curve/` — **do not** subclass CP / Orbital / Weighted UniV4 DETF or Balancer Single SE contracts.  
**Package root:** `contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/`  
**Date:** 2026-08-12  
**Status:** **Canonical plan aligned to PRD LOCKED v0.4** — ready for implementor stamp; then phased coding. **No production code in this doc-only pass.**

---

## Authority

| Layer | Role |
|-------|------|
| **PRD LOCKED v0.4** | Product law — wins on any conflict; patch this plan if PRD changes |
| **This plan** | Phases, file map, deploy path, algorithm freezes, test matrix, DoD |
| **INDEXEDEX_AGENT_LAW.md** | DETF common expectations; CREATE3; manager vault registry; production-first tests; mature-only sell→claim. Generic whole-DETF `rateAsset` role does **not** apply (per-route pair unit; per-leg RP only) |
| **Crane skills** | `crane-deployment`, `crane-architecture`, `crane-testing` |
| **IndexedEx skills** | `indexedex-testing`, `indexedex-adversarial-testing`, `indexedex-uniswap-v4-hook-packages` |
| **Weighted UniV4 DETF peer** | n>2 host + hook-SoT + per-route synthetic + all-legs-rich — **do not subclass** |
| **Orbital UniV4 DETF peer** | Multi-external process + facet/TestBase shape — **do not subclass** |
| **CP UniV4 DETF peer** | Seigniorage split / epoch expansion form — **do not subclass** |
| **Curve Quad Stable Buffer Hook** | Hard dependency — 4-asset StableSwap book, `depositSingle` / `joinUnbalanced` / `exitProportional`, Flexible deposit units |

**Process rule:** If this plan and PRD disagree, **PRD wins** and this plan must be patched. Do not reopen PRD-locked Q1–Q23 without a PRD revision.

Deploy arity is [`UNISWAP_V4_SE_DETF_DEPLOY_MINE_NONCE_PRD.md`](../../../UNISWAP_V4_SE_DETF_DEPLOY_MINE_NONCE_PRD.md) / its implementation plan.

**Role names only:** `detfToken`, `pairToken0` / `pairToken1` / `pairToken2`, `standardExchange[i]`, `vaultShare[i]`, `rateProvider[i]`, `baseAmp`, `reserveHook` / `reserveLp`, `bondNft`, `rebasingClaimToken`, `creationPairPerDetfWad[i]`, `capitalToken`, `syntheticVs(pair)`. **No** whole-DETF `rateAsset`. No brand tickers.

**LOCK-time plan-scope (PRD §20):**

| Topic | Freeze |
|-------|--------|
| Deposit / mint / bond capital | **Whatever the reserve hook already accepts as a liquidity deposit.** Pair face always. Vault shares via hook Flexible (`amountIsSeShare`) when the hook accepts them. No extra DETF-only capital types. Do not refuse a unit the hook would take. |
| Exact-out mint / burn | **Phase 0 invert spike.** Ship iff closed-form + bit-exact preview==exec. Else selector `InvalidRoute`. Never binary-search. Never execute hook `withdrawSingle`. |
| Inventories | This family added to agent-law families table + shared compound/expansion inventory at LOCK |

---

## Read order for implementors

1. PRD §1 locked summary + §2 roles + §3 topology  
2. PRD §4 liveness / first bond (all three pairs, refund, full book, chosen `capitalToken`)  
3. PRD §5 pricing — **§5.3 hook-SoT quote**, **§5.4 full-book lifecycle**, **§5.5 whole-reserve per-route FD**, **§5.6 burn + redeposit (no `withdrawSingle`)**  
4. PRD §7–§9 mint / bond (single-pair later, mature-only, single `capitalToken`) / claim  
5. PRD §10 compound + **all-legs-rich** expansion with **`min S_spot_k`**; §11 PkgArgs; §15 tests; §20 Q table  
6. **This plan** §0–§8  
7. Hook PRD/ABI for **selectors only**; Weighted + Orbital + CP DETF TestBases as pattern only  

---

## 0. Starting state

| Item | Status |
|------|--------|
| PRD LOCKED v0.4 | Present at package path |
| This plan | **This file** |
| DETF package Solidity | **None** — greenfield |
| Uni V4 DETF `common/nft` + `common/rebasing` | Share with CP + Orbital + Weighted — **must** support **fungible hook LP principal** + **single `capitalToken` metadata** + `requireMatureForSell`. Today's `IUniV4DetfBondNft` is still the CP dual-OOR CL shape — **Phase 0 extends it** (do not invent a third NFT family) |
| Shared `detf/common/core/*` | Exists — reuse thresholds, usage fee, bond math, compound helpers, epoch expansion; **family gate** for all-legs + `min S_spot_k` |
| Curve Quad Stable Buffer Hook | Under `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/` — ABI frozen (`IUniswapV4StandardExchangeCurveQuadStableBufferHook`) — **Phase 0 hard gate** |
| Weighted / Orbital / CP UniV4 DETF | Peers — gold shape / economics only — **do not subclass** |

**Do not** start by subclassing peer DETF Targets or forking hook sources into this package.

---

## 1. Goals / non-goals

### Goals (v1 DoD)

1. Ship **true DETF** diamond + DFPkg under this path via **IndexedEx manager vault registry**.  
2. From **`PkgArgs`**, deploy **one** Curve Quad Stable Buffer Hook via registry **`deployHookVault`**: exactly **4** tokens (DETF raw self-leg at its address-sorted index + **3** like-kind external pairs); **`baseAmp`**; **≥1** distinct SE on external legs; optional RPs on SE legs only; **all six** V4 doors in hook `postDeploy`.  
3. **Permissionless first bond** requiring **all three** external pair legs at creation rates → full book → `isReserveLive`; **refund excess**; caller **picks** `capitalToken` among the three funded pairs; MINIMUM_LIQUIDITY edge.  
4. **Primary mint** (live): rate capital → funded pair-leg units → seigniorage quote (**hook SoT**) / split → hook **`depositSingle(pair)`** or **`depositSingleFlexible`** when the unit is already vault share → protocol LP; **Policy per-route debt-inclusive** mint gate; **no** expansion realize.  
5. **Primary burn**: free DETF only → `exitProportional` → **redeposit returned DETF** → residual consolidate → `tokenOut` pair; `lpOut = detfBurned * protocolLp / effectiveSupply`; usage fee **yes**; **`withdrawSingle` forbidden** even as an optimization.  
6. **Bond after live**: **no** synthetic mint gate; **exactly one** external pair; protocol mints join DETF + hook **`joinUnbalanced`**; LP on bond NFT; `capitalToken` = that pair; `effectiveShares` via open-time rated StableSwap mids; **realizes** expansion.  
7. **Mature-only** sell→claim (DETF gate + shared flag); maturity close pays **single recorded capitalToken**; free NFT transfer; indefinite mature hold.  
8. Rebasing claim holds **protocol LP**; redeem matrix with redeposit DETF; **`tokenOut = DETF` → InvalidRoute**; prefer clean vaultShare path when the hook Flexible exit accepts shares.  
9. **Protocol compound** single-sided DETF `depositSingle` when single-asset eligible; **skip** (no revert) when not.  
10. **Epoch natural expansion** (Policy): CP-form premium-closure; accrue only if **all three** legs mint-rich at epoch end; size scalar = **`min(S_spot_0, S_spot_1, S_spot_2)`**; pending in every per-route synthetic; realize only bond / claimRewards / compound.  
11. Production-first tests: hermetic **1 SE + 2 bare**, **2 SE + 1 bare**, **3 SE**; reject all-bare; free DETF binding; RP on/off; mixed 6/18 decimals; gentle + launch-rich; per-route skew; refund; all-legs expansion + ≥1 fork profile; no SUT mocks.

### Non-goals (v1)

- Implementing the reserve hook inside this package.  
- All-external-bare deploy; \(n \neq 4\); DETF as buffered SE leg.  
- Whole-DETF `rateAsset` field / single-numeraire gates.  
- Multi-leg later bonds; multi-token maturity baskets; user-paid DETF as bond capital.  
- Subclassing CP / Orbital / Weighted UniV4 DETF, Balancer Single SE, or hook contracts.  
- Protocol “rebalance full book” surface.  
- Calling hook **`withdrawSingle` / `exitSingleAssetExactTokenOut`** on DETF burn, claim redeem, or maturity close.  
- Reimplementing StableSwap \(D\) / \(y\) inside the DETF.  
- MEV protection on first bond; fee-oracle expansion/threshold params.  
- FoT/rebasing pair tokens; native ETH currency; cross-chain.  
- Binary-search solvers; inventing hook APIs.  
- Amp ramping; like-kind deploy check beyond hook token rules.  
- Permit2 on the DETF surface (hook may use Permit2 internally).

---

## 2. Hard gates & dependencies

| Gate | Requirement |
|------|-------------|
| **G0 Hook** | Curve Quad Stable Buffer Hook: ABI frozen; hermetic join/exit/previews green enough to consume. Surfaces in §2.1. |
| **G1 SE** | At least one production SE (hermetic ERC-4626 wrapper or protocol SE TestBase) with closed-form pair ↔ share routes; matrix needs 1/2/3 SE rows |
| **G2 Crane** | `CraneTest` → `IndexedexTest` → vault components; create3Factory + diamondPackageFactory |
| **G3 Registry** | DETF DFPkg via `indexedexManager.deploy*DFPkg` / registry; hook via `deployHookVault` + hook diamond factory — **never** `new` facets/DFPkgs |
| **G4 Shared children** | Bond NFT + rebasing support **hook LP principal**, **single `capitalToken`**, **`requireMatureForSell = true`** |

**Coding must not invent hook APIs.** Consume only `IUniswapV4StandardExchangeCurveQuadStableBufferHook` + `IStandardExchange*` / In / Out / MultiAssetLiquidity.

### 2.1 Hook ABI consumption (frozen to current interface)

| DETF need | Hook selector | Allowed? |
|-----------|---------------|----------|
| First bond (pair-face) | `joinProportional` / `previewJoinProportional` | **Yes** |
| First bond (vault-share legs the hook accepts) | `joinProportionalFlexible` / `previewJoinProportionalFlexible` | **Yes** — hook-accepted deposit units |
| Later bond | `joinUnbalanced` / `previewJoinUnbalanced` | **Yes** — DETF + one pair; zeros on other legs |
| Live primary mint / compound / free-DETF claim | `depositSingle` / `joinSingleAssetExactIn` + previews | **Yes** |
| Mint / claim when `tokenIn` is already vault share | `depositSingleFlexible` / `joinSingleAssetExactInFlexible` (`amountIsSeShare=true`) + previews | **Yes** |
| Burn / claim redeem / maturity close | `exitProportional` / `previewExitProportional` | **Yes — normative** |
| Claim redeem / close wanting clean vault shares | `exitProportionalFlexible` (`receiveSeShare`) + preview | **Yes** — still prop-remove, not `withdrawSingle` |
| Residual consolidate / FD sells | `previewSwapExactIn` + SE In/Out execution | **Yes** |
| Info / gates | `nativeReserve`, `ratedBalance`, `isFullBook`, `baseAmp`, `tokens()` | **Yes** |
| Quote helper (**view only**) | `previewDepositSingle` then `previewExitSingleAssetExactBptIn(DETF, shares)` | **Yes — view only** (Weighted peer). **Must not** execute `withdrawSingle` |
| Exact-out mint invert (**view only**, Phase 0) | `previewExitSingleAssetExactTokenOut(DETF, …)` + `previewJoinSingleAssetExactOut(pair, shares)` | **View only** if Phase 0 proves bit-exact |
| Burn / redeem / close execution | `withdrawSingle`, `withdrawSingleExactOut`, `exitSingleAssetExactBptIn`, `exitSingleAssetExactTokenOut` (+ Flexible outs) | **Forbidden** (Q4 / Q20) |

---

## 3. Architecture (implementor map)

### 3.1 Deploy topology

```text
IndexedexManager / Vault Registry
  └── UniswapV4StandardExchangeCurveQuadStableDETDFPkg
        postDeploy (after DETF diamond exists — address known for sort):
          - bindingTokens[4] = sort(DETF, pair0, pair1, pair2) address-ascending
          - detfBindingIndex = index of DETF
          - pairBindingIndex[3] = product pair i → binding index
          - SEs/RPs remapped to binding order; DETF slot SE=0, RP=0
          - deployHookVault(Curve Quad Stable Buffer Hook PkgArgs):
              tokens[4], SEs[4], RPs[4], baseAmp, poolManager, feeOracle, mineNonce / salt
          - hook postDeploy inits all 6 V4 doors (DYNAMIC_FEE_FLAG, plumbing sqrtPrice)
          - deploy shared bond NFT (owner=DETF; requireMatureForSell=true)
          - deploy shared rebasing claim (owner=DETF; holds protocol LP)
          - store PkgArgs: pairs (product order), creation rates (3), binding maps,
            thresholds, expansion, detfBindingIndex, reserveHook, refs
          - validate (PRD §11):
              pairs distinct ≠ DETF; DETF raw only; ≥1 SE; SEs distinct when set;
              RP only with SE; pair ∈ SE.tokens() when SE set; DETF ∉ SE.tokens();
              all three creation rates > 0; baseAmp in hook D7 bounds;
              no FoT/rebasing pairs; decimals [6, 18];
              NO whole-DETF rateAsset field

Facets (CREATE3): Info / ExchangeIn / ExchangeOut / Bonding / Claim / Compound
Diamond instance = detfToken ERC-20 (immutable / unowned after deploy)
```

### 3.2 Index / order mapping

| Array | Order | Length |
|-------|-------|--------|
| `pairToken0/1/2` + `creationPair*PerDetfWad` | **Product order** (deployer-chosen) | 3 |
| Hook `tokens[]` / `standardExchanges[]` / `rateProviders[]` / join amount arrays | **Address-ascending binding order** | 4 |

```text
// After DETF address known:
// 1) bindingTokens = sort ascending(DETF, pair0, pair1, pair2)
// 2) detfBindingIndex = index of DETF
// 3) pairBindingIndex[i] = index of pairToken[i] in bindingTokens
// 4) SEs/RPs: PkgArgs product-parallel to pair0/1/2 + DETF zeros;
//    remap to length-4 binding arrays for hook deploy
```

**Worked example:**  
Pairs product order `[USDC, USDT, DAI]`. DETF address sorts between DAI and USDC → binding  
`[DAI, DETF, USDC, USDT]` → `detfBindingIndex=1`, `pairBindingIndex=[2,3,0]`.  
`creationPair*PerDetfWad` stays product-order USDC, USDT, DAI.

### 3.3 File map

```text
contracts/vaults/detf/protocols/dexes/uniswap/v4/
  standardExchange/stable/quad/curve/
    UniswapV4StandardExchangeCurveQuadStableDETF_PRD.md
    UniswapV4StandardExchangeCurveQuadStableDETF_IMPLEMENTATION_AND_TEST_PLAN.md  # this file
    interfaces/
      IUniswapV4StandardExchangeCurveQuadStableDETF.sol
      IUniswapV4StandardExchangeCurveQuadStableDETDFPkg.sol   # PkgInit / PkgArgs HERE
    UniswapV4StandardExchangeCurveQuadStableDETFRepo.sol
    UniswapV4StandardExchangeCurveQuadStableDETFCommon.sol
    UniswapV4StandardExchangeCurveQuadStableDETFInfoTarget.sol
    UniswapV4StandardExchangeCurveQuadStableDETFExchangeInTarget.sol
    UniswapV4StandardExchangeCurveQuadStableDETFExchangeOutTarget.sol
    UniswapV4StandardExchangeCurveQuadStableDETFBondingTarget.sol
    UniswapV4StandardExchangeCurveQuadStableDETFClaimTarget.sol
    UniswapV4StandardExchangeCurveQuadStableDETFCompoundTarget.sol
    UniswapV4StandardExchangeCurveQuadStableDETF*Facet.sol
    UniswapV4StandardExchangeCurveQuadStableDETDFPkg.sol
    UniswapV4StandardExchangeCurveQuadStableDETF_Facet_FactoryService.sol
    UniswapV4StandardExchangeCurveQuadStableDETF_Pkg_FactoryService.sol
    UniswapV4StandardExchangeCurveQuadStableDETF_Component_FactoryService.sol
    TestBase_UniswapV4StandardExchangeCurveQuadStableDETF.sol
  common/
    nft/      # SHARED — extend for LP principal + capitalToken + requireMatureForSell
    rebasing/ # SHARED — claim on protocol hook LP
```

**PRODUCT_ID (DETF pkg salt):** `"UniswapV4StandardExchangeCurveQuadStableDETF"`.  
Hook salt **PRODUCT_ID** remains the **hook** type name.

**Libs (prefer extend, not fork):**

| Lib | Use |
|-----|-----|
| `DETFThresholdPolicy` | Policy/Open resolve + gates |
| `DETFUsageFeeLib` / peer mint split | Seigniorage split; **burn usage fee** |
| `DETFBondNFTMathLib` / `DETFBondLifecycleLib` | Lock clamp, bond lifecycle |
| `DETFProtocolCompoundLib` | Compound helpers |
| `DETFNaturalExpansionLib` / epoch peer | Whole-epoch pending + mint; **wrap** with all-legs + `min S_spot_k` |
| Family-local residual helpers | Only if hook lacks a sell preview — **must bit-match hook fee law**; prefer hook SoT |

### 3.4 Storage (Repo sketch)

```text
// UniswapV4StandardExchangeCurveQuadStableDETFRepo
isReserveLive
pairTokens[3]                        // product order
pairBindingIndex[3]                  // product → binding
detfBindingIndex                     // 0..3
standardExchanges[3]                 // product order (external only)
rateProviders[3]                     // product order
creationPairPerDetfWad[3]            // product order; each > 0
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
// baseAmp: view passthrough to hook — do not store a second A
```

**Bond NFT position metadata:**

```text
// per tokenId
capitalToken           // single external pair — ALWAYS set (first + later)
effectiveShares        // DETF-valued principal × lock bonus
unlockTime
lpPrincipal (or tracked via balance)
```

Slot form: Crane ERC1967-style `DEFAULT_SLOT = bytes32(uint256(keccak256(abi.encode("…"))) - 1)`.

### 3.5 Public surface (facet split)

| Facet group | Functions (min) |
|-------------|-----------------|
| **Info** | `isReserveLive`, `syntheticPrice(pair)` / `syntheticVs(pair)` (debt-inclusive whole-reserve), optional spot, `isMintingAllowed(pair)` / `isBurningAllowed(pair)`, `isAllLegsMintRich()`, `pendingExpansionDetf`, thresholds, creation rates, pairs, SEs, RPs, `baseAmp` (hook passthrough), DETF binding index, reserve hook, expansion getters — **no** `rateAsset()` |
| **ExchangeIn** | Mint DETF from any hook-accepted deposit unit that settles to a pair (pair face, vaultShare, SE token) |
| **ExchangeOut** | Burn free DETF → `tokenOut` ∈ pair legs (+ SE unwrap / clean share); **not** DETF |
| **Bonding** | `bond` (first: all three + required `capitalToken`; later: single pair), maturity close, `sellPositionToDetfNft` (**mature only**), `claimRewards`, `acceptedBondTokens` |
| **Claim** | Direct deposit (hook-accepted units + free DETF); `redeemClaim` with tokenOut matrix (**DETF out InvalidRoute**) |
| **Compound** | `compoundProtocolRewards` (skip if not single-asset eligible) |

**Exact-out selectors** (`mintExactDetfOut` / `burnExactTokenOut` or peer names): expose on ExchangeIn/Out **iff** Phase 0 ships them; otherwise the selector **reverts `InvalidRoute`** (do not omit the selector if the interface already names it — same as “route exists, solver does not”).

**Previews (LOCKED):** every closed-form path has a view with preview == execution (≤ few-wei only if SE multi-leg dust; document). Mint/bond quotes **must** match hook previews.

**Errors (stable family):**

| Error | When |
|-------|------|
| `InvalidRoute` | Bad tokenIn/tokenOut; non-closed-form exact-out |
| `ReserveNotLive` | Pre-live primary mint/burn / non-first bond |
| `MintNotAllowed` / `BurnNotAllowed` | Policy gates (per-route) |
| `BondNotMature` | Pre-maturity sell or principal close |
| `FirstBondRequiresAllExternalPairs` | Missing any external on first bond |
| `LaterBondSinglePairOnly` | Multi-pair later bond |
| `NotSingleAssetEligible` | Single-asset path when hook not full-book eligible |
| `ProtocolLpEmpty` | Burn with no/insufficient protocol LP |
| `InvalidCapitalToken` | First bond: not one of the three **funded** pairs. Later: not the one funded pair |
| `InvalidCreationRate` | Deploy: any rate ≤ 0 |
| `AllExternalBareForbidden` | Deploy: zero SEs |
| `InvalidBaseAmp` | Deploy: outside hook D7 bounds |
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

### 4.2 Capital rating + hook-accepted deposit units

```text
rateTokenInToPairLeg(tokenIn, amountIn) → (fundedPairIndex, pairNotionalWad, depositUnit):
  if tokenIn == pairToken[i]:
      (i, toWad(amountIn, d_i), PairFace)
  if tokenIn == vaultShare[i] (SE_i set):
      pairNotional = always rate shares → pair units (RP or claim)  // never skip
      (i, pairNotionalWad, VaultShare)   // hook Flexible deposit
  if tokenIn ∈ SE_i.tokens() (SE_i set):
      SE route → pair face → (i, pairNotionalWad, PairFace)
  else: revert InvalidRoute

// Mint quote: do NOT convert pairNotional through another pair mid
pairBoosted = pairNotionalWad * (1e18 + seigniorageIncentiveWad) / 1e18
grossDetf   = quoteDetfAgainstReserve(fundedPairIndex, pairBoostedNative)
```

**Execution of the join/deposit (LOCK-time “hook-accepted units”):**

| `depositUnit` | Live mint / claim new-money / compound-of-pair | First bond | Later bond |
|---------------|--------------------------------------------------|------------|------------|
| PairFace | `depositSingle(pair)` | `joinProportional` native pair amounts | `joinUnbalanced` DETF + that pair |
| VaultShare | `depositSingleFlexible(pair or share token, amount, amountIsSeShare=true)` | `joinProportionalFlexible` with `amountIsSeShare[leg]=true` on that buffered leg | `joinUnbalanced` **or** Flexible equivalent **iff the hook accepts share units on unbalanced**. If hook unbalanced is pair-native only: unwrap share → pair (still hook-accepted pair deposit), document. **Do not refuse vaultShare `tokenIn`.** |

Preview selector **must** match the execution selector.

`acceptedBondTokens()`: all three pair tokens; vault shares for each set SE; tokens from each set SE; **not** DETF.

### 4.3 `quoteDetfAgainstReserve` — hook source of truth

**Economic identity:** fee-aware DETF gross for exact-in **pair-leg** notional against the **live rated StableSwap book** — inverse of single-sided capital priced vs live book (`depositSingle` spirit).

**Frozen algorithm (Weighted peer, view-only):**

```text
if !live:
  return pairWad * 1e18 / creationPairPerDetfWad[k]   // first-bond join sizing uses §4.7, not this

shares = hook.previewDepositSingle(pair, pairNative)
         else hook.previewJoinSingleAssetExactIn(pair, pairNative)
if shares > 0:
  detfOut = hook.previewExitSingleAssetExactBptIn(DETF, shares)   // VIEW ONLY
  if detfOut > 0: return detfOut

// Fallback: hook swap preview pair → DETF (SE In preview, else previewSwapExactIn)
detfOut = previewExactIn(pair, DETF, pairNative)
if detfOut == 0: detfOut = pairWad * 1e18 / creationPairPerDetfWad[k]
```

**Rules:**

1. DETF **must not** reimplement StableSwap \(D\) / \(y\).  
2. Preview + execution mint **share one quote path**.  
3. Using `previewExitSingleAssetExactBptIn` for the **quote** does **not** authorize executing `withdrawSingle` on burn/redeem.  
4. Not creation rate after live. Not cross-pair mid convert. Not binary search.  
5. Document ≤ few-wei only if SE multi-leg dust forces it.

### 4.4 Exact-out Phase 0 spike

**Exact DETF-out mint** (user names DETF the **user** receives):

```text
// Invert seigniorage split (peer):
//   user = gross * (1 - usageFee) * (1 - incentive/2)
//   gross = ceil_div(user, that factor)
// Then invert quoteDetfAgainstReserve:
//   shares = previewExitSingleAssetExactTokenOut(DETF, gross)     // VIEW
//   pairIn = previewJoinSingleAssetExactOut(pair, shares)         // VIEW
// Execute: pull pairIn (or hook-accepted unit rating to that pair native),
//          depositSingle / Flexible as §4.2, mint split so user == requested.
// Ship iff preview == execution bit-exact (≤ few-wei only if SE dust; document).
// Else selector InvalidRoute.
```

**Exact tokenOut burn** (user names exact pair out):

```text
// Execution is STILL exitProportional + redeposit + residual (§4.8).
// Invert must map tokenOut → detfBurned / lpOut through that same path.
// Dual residual + redeposit book change is unlikely closed-form.
// Phase 0: attempt a closed-form invert using only hook previews
//   (previewExitProportional, previewDepositSingle(DETF), previewSwapExactIn).
// If not bit-exact without search: selector InvalidRoute.
// NEVER execute withdrawSingle / exitSingleAssetExactTokenOut.
// NEVER binary-search.
```

Phase 0 writes the ship / `InvalidRoute` decision into this plan’s revision history and TestBase comments before Phase 4/5 code.

### 4.5 Debt-inclusive per-route synthetic — whole reserve

**Peg (per pair \(k\)):** abstract 1e18 on `syntheticVs(pair_k)` means FD claim of **whole reserve** in pair \(k\) per DETF equals `creationPairPerDetfWad[k]`.

```text
previewWholeReserveToPair(pair_k):
  residual[4] = hook.previewExitProportional(totalSupply hook LP)
  map binding → (a_detf, a_pair0, a_pair1, a_pair2)
  fd = toWad(a_pair_k)
  // Residual sell order (FROZEN): the two non-out external pairs,
  //   address-ascending, each via previewSwapExactIn / SE In-Out into pair_k;
  //   then DETF self-leg → pair_k last.
  for each other pair j != k in address-ascending order:
    fd += exactInSell(pair_j → pair_k, a_j)
  fd += exactInSell(DETF → pair_k, a_detf)
  return fd

S_spot_k = (fdPair_k * 1e18 / max(detfTotalSupply,1)) * 1e18 / creationPairPerDetfWad[k]
pending = previewPendingExpansionMint()
effectiveSupply = detfTotalSupply + pending
syntheticVs(pair_k) = (fdPair_k * 1e18 / max(effectiveSupply,1)) * 1e18 / creationPairPerDetfWad[k]
```

Redeposit on burn/claim does **not** redefine FD.

**Gates:**

| Path | Gate |
|------|------|
| Primary mint → pair \(i\) | Policy: `syntheticVs(pair_i) > mintThreshold` |
| Primary burn → pair \(j\) | Policy: `syntheticVs(pair_j) < burnThreshold` |
| Equality | Deadband on that route only |
| Open | Gates always pass when live; pending expansion = 0 |
| First bond | Ungated |
| Bonds after live | **No** synthetic mint gate |

**Dust (FROZEN):** after residual consolidate, leftover of `tokenOut` goes to the user. Leftover of other pairs below **max(1 native unit, hook min swap in)** may remain on the DETF diamond — **not** a user claim in v1. Tests assert no **material** free inventory of user capital on success paths. NatSpec the threshold.

### 4.6 All-legs mint-rich + pending expansion

```text
allLegsMintRich():
  if !live || Open: return false
  for each external pair_k:
    if syntheticVs(pair_k) <= mintThreshold: return false
  return true

// Size scalar when accruing (Q21):
S_size = min(S_spot_0, S_spot_1, S_spot_2)
// Then same O(1) premium-closure form as CP UniV4 DETF §10 using S_size.
// Copy CP §10.3–§10.4 launch-rich R tables; per-leg creation rates are peg refs.
```

**Epoch-end accrual (same simple rule as Weighted plan §4.5):**

```text
// When realizing at time `now`:
//   completedEpochs = (now - last) / epochLength
//   If allLegsMintRich() is true *at realize time*, mint for those whole epochs (capped).
//   If not all-rich now, pending = 0 for this realize.
//   No pro-rate of partial epochs.
//   maxCatchUpEpochs == 0 → unlimited.
// If product later needs true historical end-of-epoch snapshots, amend with checkpoints.
```

**Realize paths:** bond, `claimRewards`, `compoundProtocolRewards` (+ reward updates).  
**Forbidden on primary mint/burn:** realize + advance of `lastExpansionTimestamp`.

```text
_realizeExpansionIfNeeded():
  if !live || Open: return
  if last == 0: last = now; return   // seed after live; no pre-live backlog
  pending = previewPendingExpansionMint()
  if pending == 0: return
  _mintDetf(bondNftVault, pending)
  last += epochs * expansionEpochLength
```

### 4.7 Seigniorage mint split (peer)

```text
pairBoosted = pairNotionalWad * (1e18 + seigniorageIncentive) / 1e18
gross = quoteDetfAgainstReserve(fundedPair, pairBoostedNative)
feeTo = gross * usageFee / 1e18
afterFee = gross - feeTo
inventory = afterFee * (seigniorageIncentive / 2) / 1e18
user = afterFee - inventory
```

| Path | Capital → reserve | Free DETF |
|------|-------------------|-----------|
| Live primary mint | Settle → `depositSingle` / Flexible; revert if not single-asset eligible | Mint user / feeTo / inventory only |
| Bond (live) | `joinUnbalanced` DETF + **one** pair; LP → NFT | Also free legs from split |
| First bond | Creation-rate sized join DETF + **all three** pairs | Free legs from split of **join-sized gross**; free legs stay **outside** the pool |

### 4.8 First bond (PRD §4.4)

```text
require all three external notionals C_i > 0 after settle
  else FirstBondRequiresAllExternalPairs
require capitalToken ∈ the three funded pairTokens
  else InvalidCapitalToken

for each external i:
  detfFrom[i] = pairNotionalWad[i] * 1e18 / creationPairPerDetfWad[i]
detfForJoinWad = min_i(detfFrom[i])
require detfForJoinWad > 0

// Size each pair used at join = detfForJoinWad * creationPair_i / 1e18
// REFUND unused external capital (and unused SE-routed remainder) to caller

// Seigniorage split on join-sized gross (peer mint modifiers)
// Mint join-sized DETF into the reserve; ALSO mint free user/feeTo/inventory
//   on top of join-sized (free legs do not enter the pool)

// Binding-order amounts: DETF on detfBindingIndex, pairs on pairBindingIndex[*]
// joinProportional or joinProportionalFlexible (§4.2)
// require post-join full book (all four native > 0) else revert
// LP → bond NFT
// capitalToken = caller arg (must be a funded pair)
// effectiveShares: AFTER join (mids now exist), convert each funded external
//   pair notional → DETF via hook previewSwapExactIn(pair → DETF) (fee-aware)
//   sum × lock bonus. DETF join leg excluded. Do not use creation rates for this FX.
// isReserveLive = true
```

Pre-live: primary mint/burn revert; non-first bond revert.  
If hook geometric / MIN liquidity fails → clear product error (cannot go live).

### 4.9 Primary burn (PRD §5.6) — atomic order frozen

```text
// no expansion realize
require live + debt-inclusive burn gate on tokenOut pair (Open: when live)
tokenOut ∈ pairTokens (else InvalidRoute); tokenOut == DETF → InvalidRoute
pending = previewPendingExpansionMint()
effectiveSupply = totalSupply + pending
protocolLp = reserveLp.balanceOf(protocolLpHolder)
lpOut = detfBurned * protocolLp / effectiveSupply
if protocolLp == 0 || lpOut == 0: revert ProtocolLpEmpty

// ATOMIC — full success or full revert (no burned DETF without payout):
1. pull + burn only detfBurned (user free DETF)
2. apply burn usage fee (YES — DETFUsageFeeLib)
3. hook.exitProportional(lpOut) → four-leg amounts
4. _redepositDetfSelfLeg(a_detf)          // §4.10
5. residual: two non-tokenOut pairs → tokenOut
     sell order = address-ascending of those two pairs (§4.5)
6. pay tokenOut (+ tokenOut dust to user)
7. enforce minOut

// withdrawSingle / exitSingleAssetExact* — FORBIDDEN on this path
```

**Do not** burn returned DETF. **Do not** pay returned DETF to burner. **Do not** draw bond-NFT LP.

### 4.10 Redeposit ladder

Used by: primary burn, claim redeem, maturity close, sell fallback.

```text
_redepositDetfSelfLeg(amountNative):
  if amount == 0: return
  if hook.isFullBook() && supply > MINIMUM_LIQUIDITY:
    depositSingle(DETF, amount) → protocol LP holder
    return
  // Fallback only if hook previewJoinUnbalanced accepts DETF-only + zeros on 3 pairs
  shares = previewJoinUnbalanced(binding amounts: DETF=amount, pairs=0)
  if shares > 0:
    joinUnbalanced(...) → protocol LP holder
    return
  revert entire outer tx
```

### 4.11 Residual consolidate

```text
// Prefer hook previewSwapExactIn + IStandardExchangeIn execution (same path)
// Order: address-ascending of the tokens being sold into tokenOut / capitalToken
// Preview path MUST match execution path at same fee/oracle reads
// Nested hook fund: peer push + pretransferred pattern (do not invent a third fund style)
```

### 4.12 Bond after live

```text
_realizeExpansionIfNeeded()
// NO synthetic mint gate
// Capital: exactly ONE external pair (or SE / share settling to it)
// Multi-pair → LaterBondSinglePairOnly
// User never pays DETF; protocol mints join DETF
// Quote via hook SoT + free legs split
// joinUnbalanced: DETF + that pair; zeros on the other two externals
// LP → NFT
// capitalToken = that funded pair
//   if caller passes capitalToken and it is not that pair → InvalidCapitalToken
//   if omitted, force-store the funded pair
// effectiveShares:
//   convert funded external pair notional → DETF at open-time rated mids
//   (hook previewSwapExactIn pair → DETF, fee-aware)
//   × lock bonus
//   DETF join leg does NOT add
// lock: revert if < min; clamp to max (bonus at max)
```

**Pre-maturity:** only `claimRewards` (+ free ERC-721 transfer). No early close, no early sell.

### 4.13 Maturity close

```text
require mature
pay pending rewards (realize path)
withdraw all position LP from NFT
exitProportional(lp)
_redepositDetfSelfLeg(a_detf)
consolidate the two non-capitalToken pairs → capitalToken (§4.11)
pay only capitalToken
retire NFT
```

### 4.14 Sell → rebasing claim

```text
require mature  // DETF surface ALWAYS; shared requireMatureForSell = true
pay pending rewards
transfer reserveLp from bond NFT → rebasing package (prefer ERC-20 transfer)
mint claim from Δ protocol LP contribution (LP-pro-rata)
credit protocol NFT id 0 if peer ledger requires
retire user NFT

// Fallback if transfer blocked: exitProportional → redeposit DETF → remint LP / residual deposit
//   — still mature only
```

DETF-level maturity check remains even if the shared flag is missing.

### 4.15 Claim mint / redeem

**Mint claim (no seigniorage):**

| Path | Mechanics |
|------|-----------|
| Bond sell (mature) | §4.14 |
| New money pair/share/SE | Hook-accepted deposit unit → `depositSingle` / Flexible when single-asset eligible → LP to protocol → mint claim. **Else REVERT** (not compound skip) |
| Free DETF | `depositSingle(DETF)` → LP to protocol → mint claim (user impact). **Else REVERT** |

**Redeem:**

```text
lpOut = claimSharesBurned * protocolLp / claimTotalSupply
burn claim shares only
exitProportional(lpOut)   // or exitProportionalFlexible if tokenOut is vaultShare
                          //    and hook accepts receiveSeShare on that leg
_redepositDetfSelfLeg(a_detf)
residual → tokenOut matrix:
  any external pair | vaultShare_i (clean share path) | SE token
tokenOut == DETF → InvalidRoute
else InvalidRoute
// never withdrawSingle
```

### 4.16 Protocol compound

```text
compoundProtocolRewards():
  _realizeExpansionIfNeeded()
  update bond rewards
  harvest protocol NFT pending free DETF
  if !singleAssetEligible: return  // SKIP — do not revert
  depositSingle(DETF) → protocol LP ↑
  no new claim shares
  // If eligible but join reverts: public compound MAY surface the join failure
```

Lazy: on bond / claimRewards after realize; **not** on primary mint/burn. Join failure on lazy: best-effort leave pending.

### 4.17 Full book lifecycle

| Rule | Action |
|------|--------|
| First bond | Require all three externals; post-join all four native legs \(> 0\) |
| Later bonds / primary mint | **Add** inventory |
| Swaps | StableSwap does not fully drain a leg at finite size |
| Hook full-book exits | Must leave all legs \(> 0\) |
| `NotSingleAssetEligible` | Exceptional; **revert** on user mint/claim deposit; **skip** on compound |
| Do not implement | Protocol rebalance API |

### 4.18 PkgArgs resolve

| Arg | Resolve |
|-----|---------|
| `expansionEpochLength == 0` | `8 hours` |
| `expansionClosureRatePerYearWad == 0` | `0.10e18` |
| `expansionMaxCatchUpEpochs == 0` | unlimited |
| thresholds 0 | `DETFThresholdPolicy` defaults (1.05e18 / 0.95e18) |
| `thresholdMode` 0 / omit | Policy |
| `creationPair*PerDetfWad` | **each must be > 0** — no default |
| SE slots | **≥1 non-zero** among the three externals |
| `baseAmp` | hook D7: `0 < baseAmp < 1_000_000`; product guidance \(A \ge 10\) is operator-owned, not an extra revert |
| `detfBindingIndex` | derived from address sort after diamond exists |
| whole-DETF `rateAsset` | **absent** |

Launch-rich templates set explicit `R` — copy CP UniV4 DETF §10.3–§10.4.

---

## 5. Phased delivery

| Phase | Deliverable | Exit criteria |
|-------|-------------|---------------|
| **0** | Hook ABI consumption filled (done in §2.1); shared nft+rebasing LP + `capitalToken` + `requireMatureForSell`; **exact-out invert spike** (ship or `InvalidRoute`); confirm `joinUnbalanced` DETF-only zeros accepted or not for redeposit fallback | G0–G4; spike decision written in TestBase / this plan rev |
| **1** | Interfaces + Repo + DFPkg postDeploy + facet stubs + FactoryServices | Deploy inert diamond; hook bound; six doors exist; validations reject bad PkgArgs |
| **2** | First bond (all three, refund, chosen `capitalToken`, full book) → live | §4.8 tests green |
| **3** | Common: WAD scale, capital rating, **hook-SoT quote**, whole-reserve FD, per-route gates, residual order | Preview == execution unit rows |
| **4** | Primary mint + seigniorage split + hook-accepted units (pair face **and** vault share) | Policy/Open; `NotSingleAssetEligible` revert |
| **5** | Primary burn + redeposit ladder — **no** `withdrawSingle` | ProtocolLpEmpty; usage fee; atomic revert |
| **6** | Later bonds `joinUnbalanced`; effectiveShares DETF-mids; free NFT transfer | Multi-pair reverts; no synthetic gate |
| **7** | Mature-only sell→claim; maturity close single `capitalToken`; indefinite hold | Pre-maturity reverts |
| **8** | Claim deposit/redeem matrix; DETF out InvalidRoute; deposit reverts if not eligible | §4.15 green |
| **9** | Compound skip + epoch expansion all-legs + `min S_spot_k` | Gentle + launch-rich rows |
| **10** | TestBase matrix 1/2/3 SE + RP/binding/refund/skew/decimals | §6 matrix |
| **11** | Adversarial + fork smoke | Reentrancy `IsLocked`; ≥1 fork profile |
| **12** | NatSpec + DoD checklist §7; agent-law + compound inventory already patched at LOCK | Product DoD boxes can be ticked |

**After each phase:** `forge build` green and that phase’s tests green before the next. Forge patience + worktree cache seed per `CLAUDE.md`.

---

## 6. Testing expectations

### 6.1 TestBase ladder

```text
CraneTest
  → IndexedexTest
    → TestBase_VaultComponents (as needed)
      → TestBase_UniswapV4StandardExchangeCurveQuadStableBufferHook (as needed)
        → TestBase_UniswapV4StandardExchangeCurveQuadStableDETF
```

Production-first: real DFPkg, real manager/registry, real Curve Quad Stable Buffer Hook package, real SEs. **No SUT mocks.** Mintable ERC20 OK for funding; reentrancy hostile ERC20 only for attack suites.

### 6.2 Priority matrix

| Row | Priority |
|-----|----------|
| 1 SE + 2 bare | **Required** |
| 2 SE + 1 bare | **Required** |
| 3 SE | **Required** |
| Reject all-external-bare | **Required** |
| DETF not binding index 0 | **Required** ≥1 row |
| RP on/off | ≥1 buffered config |
| Mixed decimals 6 + 18 | **Required** |
| First-bond refund excess | **Required** |
| First-bond `capitalToken` = one funded pair | **Required** |
| Later single-pair `joinUnbalanced` | **Required** |
| Multi-pair later bond reverts | **Required** |
| Per-route mint-open / burn-open skew | **Required** (trades/seigniorage — not empty legs) |
| All-legs expansion + `min S_spot_k` | **Required** (rich end accrues; not-rich end 0; mid flip → 0) |
| Gentle + launch-rich \(R\) | Equal priority |
| Hook-SoT mint preview == exec | **Required** |
| Hook-accepted vaultShare deposit | **Required** (≥1 buffered row) |
| Mature-only sell/close | **Required** |
| Claim DETF out InvalidRoute | **Required** |
| Burn never calls `withdrawSingle` | **Required** (trace / negative) |
| Exact-out mint/burn | Ship or `InvalidRoute` per Phase 0 |
| Fork smoke | ≥1 profile (Ethereum / Base / 4663 when hook fork DoD applies) |

### 6.3 Spec list (map to PRD §15)

1. Deploy inert; primary mint reverts; non-first bond reverts.  
2. First bond all three + chosen `capitalToken` → live; two-pair first bond reverts; invalid `capitalToken` reverts; mids ≈ creation; MIN liquidity; **refund excess**; **full book** post-join.  
3. After first bond only: burn reverts (`ProtocolLpEmpty`) until mint/sell/compound.  
4. Later single-pair bond succeeds (adds); multi-pair later reverts; user DETF bond capital reverts; primary mint per-route Policy-gated; Open ungated.  
5. Whole-reserve `syntheticVs(pair)` incl. DETF→pair_k; skew mint-open A / closed B; no `rateAsset()` getter.  
6. Preview == execution mint/bond/burn/claim/maturity/sell contribution; mint matches **hook** preview.  
7. Seigniorage split peer ratios; burn usage fee; quotes via hook previews (no DETF-side StableSwap).  
8. Bond LP on NFT; claimRewards while locked; pre-maturity principal exit reverts; NFT transferable; post-maturity close **only capitalToken** or sell→claim; hold indefinite.  
9. Claim redeem matrix (each pair, vaultShare if SE, SE token); DETF out reverts; redeposit DETF; claim **deposit** reverts if not single-asset eligible.  
10. Primary burn: only user free DETF burned; redeposit ladder; no `withdrawSingle`; InvalidRoute on bad tokenOut.  
11. Compound increases protocol LP when eligible; **skips** when not.  
12. Expansion: epoch accrues only if all-legs mint-rich **at epoch end**; formula uses `min S_spot_k`; Open never.  
13. Decimal 6 + 18 pairs.  
14. Real hook + real SEs; hermetic + fork; no SUT mocks.  
15. Config rejects: all-bare, same SE twice, RP without SE, DETF in SE tokens, creation rate 0, `baseAmp` OOB.  
16. Price movement under **default** thresholds via real reserve trades on six doors + seigniorage dilution.  
17. Nested reentrancy → `IsLocked`.  
18. Residual free inventory policy on success paths.  
19. Six V4 doors swap after live.  
20. Primary mint `depositSingle` each pair after full first bond; mint reverts when not single-asset eligible.  
21. Free DETF binding not only index 0.  
22. `effectiveShares` multi-leg first bond / single-leg later (open-time DETF mids, not creation rates).  
23. Per-route mint-open / burn-open skew; `allLegsMintRich` expansion rows.  
24. Exact-out mint/burn: ship iff closed-form + preview==exec; else `InvalidRoute`.  
25. Vault-share `tokenIn` on a buffered leg (hook Flexible) preview == exec.  

### 6.4 Adversarial (minimum)

| Attack | Expectation |
|--------|-------------|
| Reentrancy on mint/burn/bond/claim via hostile ERC20 share | `IsLocked` / nonReentrant |
| Donation DETF or SE shares to hook | Dilutes whole-reserve FD / LP ownership per hook law; document |
| Pre-maturity sell→claim | Revert `BondNotMature` |
| Burn with empty protocol LP | Revert |
| Redeposit failure mid-burn | Full tx revert (no burned DETF without payout) |
| First bond incomplete external set | Revert |
| Later multi-pair bond | Revert |
| Burn path calls `withdrawSingle` | Must not — negative / selector-trace |

---

## 7. Definition of Done (implementor)

Mirror PRD §18; all must be green before family stamp:

- [ ] Inert deploy; live only via permissionless first bond (all three pairs + chosen `capitalToken`)  
- [ ] Creation-rate first bond; rates all `> 0`; mids ≈ creation; MIN liquidity; **refund**; **full book**  
- [ ] Live mint / bond seigniorage peer-compatible; preview == execution; **hook SoT** quotes  
- [ ] Primary mint normal after full first bond; later bonds **add** only; hook-accepted deposit units  
- [ ] Primary burn: user free DETF only; usage fee; redeposit ladder; **never** `withdrawSingle`  
- [ ] Claim redeem redeposits DETF; matrix; DETF out InvalidRoute; claim deposit reverts if not eligible  
- [ ] Mature-only sell/close; single `capitalToken`; NFT transfer metadata  
- [ ] Later bonds single pair `joinUnbalanced`; multi-pair later reverts; effectiveShares DETF open-time mids  
- [ ] Compound skip when not eligible; user claim deposit does not skip  
- [ ] Per-route whole-reserve debt-inclusive synthetic; all-legs expansion with `min S_spot_k`; no whole-DETF `rateAsset`  
- [ ] PkgArgs → hook n=4, `baseAmp`, 1–3 SEs + optional RPs + free DETF binding; all-bare reverts  
- [ ] Exact-out mint/burn shipped iff Phase 0 closed-form; else `InvalidRoute`  
- [ ] Shared common bond/rebasing; mature-only DETF gate + `requireMatureForSell = true`  
- [ ] §6 tests green (hermetic matrix + ≥1 fork profile)  

---

## 8. Sequencing vs other work

| Order | Work |
|-------|------|
| 1 | Curve Quad Stable Buffer Hook PRD **LOCKED** + frozen ABI (done enough to plan; coding waits on hermetic hook green) |
| 2 | This DETF PRD **LOCKED v0.4** |
| 3 | **This plan** implementor stamp |
| 4 | Shared bond NFT + rebasing (LP principal + `capitalToken` + `requireMatureForSell`) — co-owned with CP/Orbital/Weighted |
| 5 | DETF DFPkg + facets + tests (phases §5) |

**Hard gate:** DETF package coding **must not** invent hook APIs. Missing selector → revise the **hook** PRD first.

Hook DoD does **not** include this DETF. Do not block hook completion on DETF work.

---

## 9. Risks & mitigations (implementor)

| Risk | Mitigation |
|------|------------|
| Divergent mint math | Hook SoT only; tests assert quote path == execution |
| Quote view uses single-asset exit preview | Document view-only; burn execution stays prop+redeposit |
| Index remapping bugs | Worked examples in TestBase; binding maps storage; fuzz address sort |
| Shared NFT still CL-shaped | Phase 0 extend `common/nft` before family features that depend on it |
| `joinUnbalanced` rejects DETF-only zeros | Redeposit ladder step 2 skipped; eligible `depositSingle(DETF)` is the normal path after full-book first bond |
| Exact-out burn not closed-form | `InvalidRoute` — do not search |
| Epoch-end richness semantics | Simple rule §4.6 + explicit tests; no pro-rate |
| Confusing AGENTS `rateAsset` | Code + NatSpec: no `rateAsset` field; per-route getters only |
| Like-kind assumption breaks | Per-route gates + all-legs-rich cover a depeg; no extra deploy check (Q22) |

---

## 10. Revision history

| Version | Date | Notes |
|---------|------|-------|
| **v1.1** | 2026-08-12 | Phase 0 decisions: **exact-out mint/burn selectors revert `InvalidRoute`** (burn invert through prop+redeposit+residual is not closed-form; no binary search). **`joinUnbalanced` DETF-only + zeros is accepted after first mint** (hook skips zero legs; requires full book / non-zero supply). Shared Uni V4 `common/nft` + `common/rebasing` extended additively for hook-LP principal + `capitalToken` + `requireMatureForSell` (CP dual-OOR unchanged). Family consumes `IDetfSelfNftInventory` + `IRebasingClaimToken` like Weighted/Orbital gold (fungible hook LP). |
| **v1.0** | 2026-08-12 | Initial plan aligned to PRD **LOCKED v0.4**. Hook-accepted deposit units. Exact-out Phase 0 spike. Prop-remove only on burn/redeem. Per-route FD + all-legs + `min S_spot_k`. Residual sell order address-ascending then DETF last. Quote = Weighted view chain. Shared NFT extend in Phase 0. |

---

## 11. Approval

| Role | Sign-off |
|------|----------|
| Product | **PRD LOCKED v0.4** (2026-08-12) |
| Protocol / implementor | Pending (this plan stamp) |

**Status:** Plan **v1.0** ready for implementor stamp. Coding gated on hook hermetic green + Phase 0 shared-package extend + exact-out spike.
