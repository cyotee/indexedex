# UniV4SingleStandardExchangeDETF — Implementation & Testing Plan

**Status:** READY FOR IMPLEMENTATION  
**PRD:** [`UniV4SingleStandardExchangeDETF_PRD.md`](./UniV4SingleStandardExchangeDETF_PRD.md) (v0.19)  
**Date:** 2026-08-01  
**Plan revision:** 0.3 (product clarifications 2026-08-01)

This plan is normative for implementation. Product law stays in the PRD; this document locks implementation defaults and supersedes the PRD only where §0.3 explicitly revises a prior plan non-goal (natural expansion). PRD v0.19 + §0.2 + §0.3 are the implementer checklist.

---

## 0. Locked product decisions

### 0.1 Initial session

| # | Decision |
|---|----------|
| 1 | Rebasing token mint (direct deposit + bond sell) = SE-style pro-rata of **ZapOut-to-pair** contribution; protocol compound mints **0** rebasing tokens |
| 2 | Rebasing package = **one Diamond DFPkg** (rebasing ERC-20 **is** the LP manager) |
| 3 | Bond sell: NFT **withdraws** both dual-salt positions fully and **sends pair + DETF** to rebasing; rebasing deposits into standard wings and mints rebasing tokens to user (**not** PoolManager position ownership transfer / migrate) |
| 4 | Reuse Uni V4 SE **libs/repos** under `contracts/protocols/dexes/uniswap/v4/` (not SE DFPkg as claim) |
| 5 | Rebasing wing defaults match SE hardcodes: `centerWidthMultiplier = 2`, `activeLiquidityBps = 1000`; same deploy-time `widthMultiplier` as bonds |
| 6 | **Per DETF instance:** postDeploy deploys/wires instance-specific bond NFT + rebasing packages |
| 7 | **Tests:** Backing SE = **Uniswap V4 Standard Exchange** only (not Camelot/Aerodrome). Hermetic PoolManager from Crane Uni V4; **Robinhood mainnet fork** for production PoolManager / SE parity |
| 8 | This plan is **colocated** with the PRD under `…/standardExchange/single/` |

### 0.2 Clarification lock (2026-08-01)

| # | Decision |
|---|----------|
| 9 | **TWAP source:** app-level **DETF listing-oracle ring** + permissionless `pokeListingOracle()`; V4 core has no observation ring; hooks stay `address(0)`. PRD v0.19 wording matches. |
| 10 | **Protocol id 0:** reward **ledger weight only** (no dual OOR). Weight is **not** invented at deploy — see §0.3. |
| 11 | **User bond `effectiveShares`:** `pairDeposited * lockBonus` only; DETF leg does **not** add reward weight. |
| 12 | **Child auth:** bond NFT + rebasing use **Ownable (or operable); owner = DETF diamond** for privileged absorb/donate. DETF diamond may renounce *its* admin surface; children still recognize DETF address as owner. |
| 13 | **Child deploy path:** **pure Crane** CREATE3 + `diamondPackageFactory` / DFPkg — **not** vault-registry packages. DETF DFPkg still uses IndexedEx manager registry. |
| 14 | **Lock terms:** fee oracle min floor / max clamp + bonus (`DETFBondNFTMathLib` spirit). |
| 15 | **First rebasing deposit:** **mirror Uni V4 SE** first-share / inflation-guard math. |
| 16 | **Redeem overshoot:** pay **obligation only**; redeposit residual DETF + excess pair into wings. |
| 17 | **First listing in-range L:** **permissionless** (external LP / bond / rebasing); no protocol bootstrap LP for live or option B. |
| 18 | **Mandatory poke** on: **every** primary mint (**including first**), bond-open, close, sell, **compound**, and any DETF-orchestrated listing swap. Order: **poke then act**. |
| 19 | **Robinhood PoolManager:** pin via `ROBINHOOD_MAIN.UNISWAP_V4_POOL_MANAGER` (`0x8366a39CC670B4001A1121B8F6A443A643e40951`) in `lib/crane/contracts/constants/networks/ROBINHOOD_MAIN.sol`. |
| 20 | **Implementation scope:** all plan phases (0–8). |

### 0.3 Product clarifications (2026-08-01, post-plan review) — LOCKED

#### Glossary (plain language)

| Term | Meaning |
|------|---------|
| **Rebasing token** | ERC-20 issued by the rebasing package (historically also called “claim shares”). Redeemable for **`pairToken` only**. |
| **ZapOut-to-pair** | Valuation: full exit of managed LP converted entirely to `pairToken` (accounting ruler; redeem execution may still use the ladder). |
| **Contribution** | Δ ZapOut-to-pair caused by a deposit or bond-sell intake; sizes rebasing token mint. |
| **Bond original shares / principal** | Pair amount at bond open used for reward weight (`effectiveShares = principal × lockBonus` for users). |
| **Protocol id 0** | Protocol’s bond-ledger position: reward weight only (no dual OOR); principal credited on bond sell. |

| # | Decision |
|---|----------|
| 21 | **Glossary:** “Rebasing token” = the rebasing package ERC-20 (plan historically said “claim shares”). Same asset. |
| 22 | **ZapOut-to-pair:** full-exit valuation of managed LP to `pairToken` only (ruler for mint/redeem obligation). **Contribution** = Δ ZapOut-to-pair from an intake. |
| 23 | **Protocol id 0 principal (option B):** starts at **zero** (not a bug). Credits **only on bond sell** — bond’s pair principal / original shares at open move onto id 0 as ledger weight (Balancer sell-to-protocol spirit; **no** dual OOR). **Direct rebasing deposits do not** grow id 0. Never invent principal at deploy. |
| 24 | **Bond sell path:** pay pending rewards → withdraw both OOR fully → pair+DETF tokens into rebasing wings → mint **rebasing tokens to user** from contribution → credit id 0 principal → retire user NFT. Rebasing holds the **underlying liquidity**; user holds **rebasing tokens**. |
| 25 | **Inventory seigniorage routing:** inventory DETF slice → bond vault reward pool **if** total bond ledger weight &gt; 0; **else entire inventory slice → `feeTo()`** (no stranded free DETF on an empty ledger). |
| 26 | **Protocol never holds rebasing tokens.** Compound = pure **donateDetf** into rebasing (0 mint to protocol). Intentional. |
| 27 | **Primary burn dilution:** fair-share uses **full ERC-20 `totalSupply`** (includes DETF in bond OOR + rebasing). **Desired.** |
| 28 | **Burn fees:** take **usage fee only on burn** (fee oracle). Burn is **not** sized by R/synthetic; no mint-style boost/inventory split on burn. |
| 29 | **Rebasing ticks:** on every deposit / redeem / absorb / donate, **always re-derive** center/wing ticks from current `slot0` (SE rebalance spirit). |
| 30 | **Empty book bonds:** bond-open allowed with **zero** in-range listing L; option B stays false until in-range L + TWAP window + pokes. |
| 31 | **Mint split:** copy production Balancer peer half-incentive path **exactly** (`DETFUsageFeeLib` + afterFee × incentive/2 inventory). |
| 32 | **DETF decimals:** diamond ERC-20 is **always 18**. Adjust R vs `pairToken.decimals()` only on the pair side. |
| 33 | **Oracle write gate:** append/update ring **only if `block.number > lastObservationBlock`** (same-block no-op). Not timestamp-only min-1s. |
| 34 | **DFPkg name:** **`UniswapV4SingleStandardExchangeDETFDFPkg`** (typed manager helper mirrors this name). |
| 35 | **No `TwapNotReady` error.** Mint/bond always fall back to creation rate when option B unusable. |
| 36 | **Natural expansion (IN SCOPE — revises earlier non-goal):** while **live + `thresholdMode == Policy` + synthetic mint-allowed** (`synthetic > mintThreshold`), mint free DETF **without external capital** via `DETFNaturalExpansionLib` spirit; deploy-time rate/caps on **`PkgArgs` → resolve → storage** (not fee oracle). Distribute like inventory seigniorage: → bond reward ledger if weight &gt; 0, else → **`feeTo()`**. **Open never expands.** |
| 37 | **Robinhood fork fixtures:** open **new** listing / Backing pools with **mintable test tokens** against production PoolManager (do not require pre-existing mainnet DETF pools). |
| 38 | **Tests:** production packages only end-to-end; implement in §11/§12 order; wire full packages for integration — **no empty stub SUTs**. |

---

## 1. Goals & non-goals

### Goals (v1)

1. Ship `UniV4SingleStandardExchangeDETF` as a true DETF family: diamond **is** DETF ERC-20; Backing SE shares = inventory only; Uni V4 listing pool = mark + bond/rebasing LP home.
2. Ship shared packages under:
   - `contracts/vaults/detf/protocols/dexes/uniswap/v4/common/nft/`
   - `contracts/vaults/detf/protocols/dexes/uniswap/v4/common/rebasing/`
3. Production-first tests: real CREATE3/registry deploy; Crane Uni V4 hermetic + Robinhood fork; **no SUT mocks**.
4. **Natural expansion** under Policy when synthetic is above mint threshold (bond rewards or `feeTo()`).

### Non-goals (v1)

- Uni V4 SE DFPkg as rebasing reserve  
- Same-address Backing SE and rebasing manager  
- Balancer-style **BPT** protocol compound (this family donates free DETF into rebasing LP instead)  
- Protocol-held rebasing tokens on compound  
- Partial bond close  
- Listing-pool hooks (`hooks != address(0)`)  
- Max-impact / tick-walk seigniorage sizing  
- Multi-vault composition  
- Camelot / Aerodrome / non–Uni-V4 Backing SE matrix (any `IStandardExchange` remains product-legal; **test matrix is Uni V4 SE only**)  
- Natural expansion under **Open** mode
---

## 2. Architecture overview

```
                    ┌─────────────────────────────────────┐
                    │  UniV4SingleStandardExchangeDETF     │
                    │  (diamond = detfToken ERC-20)         │
                    │  owns: backingVaultShare inventory   │
                    └──────────────┬──────────────────────┘
           primary mint/burn       │ postDeploy wires
                                   │
     ┌─────────────────────────────┼─────────────────────────────┐
     │                             │                             │
     v                             v                             v
┌──────────────┐         ┌──────────────────┐         ┌─────────────────────┐
│ Backing SE   │         │ Bond NFT package │         │ Rebasing package     │
│ Uni V4 SE    │         │ (per-instance)   │         │ (per-instance DFPkg) │
│ vault shares │         │ dual OOR salts   │         │ rebasing ERC-20 +    │
│ inventory    │         │ reward ledger    │         │ managed center/wings │
└──────────────┘         └────────┬─────────┘         └──────────┬──────────┘
                                  │ withdraw pair+DETF            │
                                  │ + id 0 principal on sell      │
                                  └──────────────► deposit wings ─┘
                                                  │ mint rebasing tokens → user
                                                  v
                         ┌────────────────────────────────────────┐
                         │ Listing pool (DETF ↔ pairToken)         │
                         │ PoolManager; hooks = address(0)         │
                         │ TWAP source + external LPs + bond/rebasing L │
                         └────────────────────────────────────────┘
```

### Ownership (runtime)

| Asset | Owner |
|-------|--------|
| Backing SE shares | DETF diamond |
| Open bond dual OOR positions | Bond NFT package (PoolManager owner = NFT package; salts per tokenId) |
| Managed listing LP | Rebasing package (center + lower + upper wing salts) |
| User post-sell claim | **Rebasing tokens** (ERC-20) held by user |
| Protocol reward weight (NFT id 0) | Bond vault ledger only after bond sell (no dual OOR); compound **donates** free DETF into rebasing (0 rebasing mint to protocol) |

### Opacity

- DETF production talks to: `IStandardExchange*`, share ERC-20, PoolManager/StateLibrary, bond NFT package APIs, rebasing package APIs, fee oracle.
- **Do not** subclass `UniswapV4StandardExchangeDFPkg` for claim.
- **Do** import/reuse: `UniswapV4PositionRepo`, `UniswapV4PoolKeyAwareRepo`, `UniswapV4PoolManagerAwareRepo`, `UniswapV4QuoteService` / Crane `UniswapV4ZapQuoter`, `TickMath`, `StateLibrary`, `LiquidityAmounts`, etc.

---

## 3. Package layout & file inventory

### 3.1 DETF family — `…/standardExchange/single/`

| File | Role |
|------|------|
| `IUniswapV4SingleStandardExchangeDETF.sol` (or interface sections in targets) | Public surface: info, mint/burn, bond, compound, expansion, threshold getters |
| `UniswapV4SingleStandardExchangeDETFRepo.sol` | Instance storage: backing SE, pairToken, poolKey/poolId, creation sqrtPrice, thresholds, mode, widthMultiplier, twapSeconds, bondNft, rebasing, live flag, observation ring refs, expansion params |
| `UniswapV4SingleStandardExchangeDETFCommon.sol` | Shared: R quote, synthetic, option B, mint split, inventory custody, gates, expansion hook, feeTo fallback |
| `UniswapV4SingleStandardExchangeDETFExchangeInTarget.sol` + Facet | Primary mint routes |
| `UniswapV4SingleStandardExchangeDETFExchangeOutTarget.sol` + Facet (if out is separate) | Primary burn routes (usage fee only) |
| `UniswapV4SingleStandardExchangeDETFExchangeInQueryTarget.sol` + Facet | Previews |
| `UniswapV4SingleStandardExchangeDETFBondingTarget.sol` + Facet | open / maturity close / sell / claimRewards |
| `UniswapV4SingleStandardExchangeDETFInfoTarget.sol` + Facet | `isReserveLive`, thresholds, synthetic, pool, pairToken, backing SE, etc. |
| `UniswapV4SingleStandardExchangeDETFDFPkg.sol` | DFPkg: `PkgInit`/`PkgArgs` **on interface**; postDeploy pool init + cardinality + bond/rebasing deploy |
| `UniswapV4SingleStandardExchangeDETF_*_FactoryService.sol` | Facet + pkg factory helpers (CREATE3 facets; DETF registry deployPkg; children pure Crane) |
| `TestBase_UniswapV4SingleStandardExchangeDETF.sol` | Gold hermetic TestBase |
| `UniV4SingleStandardExchangeDETF_PRD.md` | Product law |
| This plan | Implementation + test law |

**Naming note:** Prefer **`UniswapV4…`** full protocol word in type/file names (decision §0.3 #34). Short locals (`detf_`, `seVault_`) remain fine.

### 3.2 Bond NFT — `…/common/nft/`

Behavioral peer: `detf/common/bondNft/DETFNFTVault*` (reward ledger, lock math), **new** Uni V4 position custody.

| File | Role |
|------|------|
| `IUniV4DetfBondNftDFPkg.sol` / package | PkgInit / PkgArgs on interface |
| `UniV4DetfBondNftRepo.sol` | tokenId → ticks, salts, pair principal, lock, reward debt; PoolManager + PoolKey |
| `UniV4DetfBondNftTarget.sol` + Facet | mint bond, open dual OOR, claimRewards, maturity withdraw, sell-withdraw (send tokens to rebasing), credit protocol id 0 principal on sell |
| `UniV4DetfBondNftDFPkg.sol` | Deploy per DETF; owner = DETF; **pure Crane only** |
| `UniV4DetfBondNft_FactoryService.sol` | CREATE3 + `diamondPackageFactory` — **not** vault registry |
| `TestBase_UniV4DetfBondNft.sol` | Optional; prefer full integration via DETF TestBase |

**Salts (LOCKED):**

```solidity
saltPair = keccak256(abi.encode(tokenId, pairToken));
saltDetf = keccak256(abi.encode(tokenId, detfToken));
```

**Position owner:** bond NFT package address (PoolManager `modifyLiquidity` owner).

### 3.3 Rebasing claim — `…/common/rebasing/`

One diamond: claim ERC-20 + managed LP.

| File | Role |
|------|------|
| `IUniV4DetfRebasingClaimDFPkg.sol` | PkgInit / PkgArgs |
| `UniV4DetfRebasingClaimRepo.sol` | poolKey, widthMultiplier, wing state (reuse PositionRepo patterns), total assets accounting |
| `UniV4DetfRebasingClaimCommon.sol` | deposit, ZapOut-to-pair, redeem ladder, consolidate from token intake; **always re-derive ticks** on deposit/redeem/absorb/donate |
| `UniV4DetfRebasingClaimDepositTarget.sol` + Facet | deposit pair or DETF → rebasing tokens |
| `UniV4DetfRebasingClaimRedeemTarget.sol` + Facet | burn rebasing tokens → pair only via ladder |
| `UniV4DetfRebasingClaimQueryTarget.sol` + Facet | previews, ZapOut-to-pair, obligation |
| `UniV4DetfRebasingClaimDFPkg.sol` | Deploy per DETF; owner/operator = DETF for absorb path; **pure Crane only** |
| `*_FactoryService.sol` | CREATE3 + `diamondPackageFactory` — **not** vault registry |
| `TestBase_UniV4DetfRebasingClaim.sol` | Optional; prefer full integration via DETF TestBase |

### 3.4 Shared pricing / TWAP lib (family or common)

| File | Role |
|------|------|
| `UniV4DetfListingOracleLib.sol` (preferred under `…/uniswap/v4/common/` or family) | Option B, TWAP, synthetic, pair→DETF R, observation ring |

**Do not** put Balancer-only libs in this family. Reuse shared DETF libs:

- `DETFThresholdPolicy`, `DETFUsageFeeLib`, `DETFMintSplitLib`, `DETFBondNFTMathLib`, `DETFBondLifecycleLib` (adapt sell path), `DETFSafeTransferLib`, **`DETFNaturalExpansionLib`** (Policy expansion)

---

## 4. Interfaces & PkgArgs

### 4.1 DETF `PkgArgs` (draft → implement)

```text
name, symbol                   // DETF ERC-20; decimals fixed 18
standardExchangeVault          // Backing SE (IStandardExchange / proxy)
pairToken                      // must ∈ Backing SE.tokens()
poolManager                    // IPoolManager
poolFee, tickSpacing           // listing pool
hooks                          // must be address(0); revert if non-zero
sqrtPriceX96                   // creation exchange rate (required)
twapSeconds                    // store 1800; v1 no override product path
mintThreshold, burnThreshold   // 0 → policy defaults
thresholdMode                  // Policy | Open
widthMultiplier                // ≥ 1; bond OOR + rebasing wings
// Natural expansion (deploy-time only; not fee oracle) — peer DETFNaturalExpansionLib fields:
//   expansionRate / catch-up caps as on Balancer true DETF PkgArgs
// optional: name/symbol for bond NFT + rebasing ERC-20
```

**Removed:** any `uniswapV4StandardExchangeVault` as rebasing package arg.

### 4.2 Deploy validation (postDeploy / processArgs)

1. `pairToken ∈ backing.tokens()` — else revert.  
2. `pairToken != detfToken`; Backing SE must not list DETF as a vault token (if detectable via `tokens()`).  
3. `hooks == address(0)`.  
4. `sqrtPriceX96 != 0` and within `TickMath` bounds.  
5. `widthMultiplier >= 1`.  
6. Threshold mode + pair via `DETFThresholdPolicy`.  
7. Sort currencies for `PoolKey` (currency0 < currency1).  
8. `initialize` listing pool; **bootstrap observation capacity** (see §6).  
9. Deploy bond NFT package (owner = DETF, rewardToken = DETF).  
10. Deploy rebasing package (listing PoolKey, widthMultiplier, pairToken, detfToken, owner = DETF for privileged absorb).  
11. Wire fee oracle / vault registry as peer DETFs.  
12. Instance **unowned/immutable** after deploy (no diamondCut owner surface).

### 4.3 Public DETF surface (minimum)

| Area | Functions (names indicative) |
|------|------------------------------|
| Info | `pairToken()`, `backingStandardExchangeVault()`, `listingPoolKey()` / `poolId()`, `creationSqrtPriceX96()`, `twapSeconds()`, `widthMultiplier()`, `isReserveLive()`, `thresholdMode()`, `mintThreshold()`, `burnThreshold()`, `syntheticPrice()`, `isMintingAllowed()`, `isBurningAllowed()`, `isMarketMarkUsable()` |
| Oracle | `pokeListingOracle()` (permissionless); ring capacity / readiness getters as needed |
| Mint/burn | Standard Exchange In/Out style exact-in + preview; `UnsupportedRoute` for bad tokens; burn takes **usage fee only** |
| Bond | `openBond`, `closeBond` (maturity full), `sellBond`, `claimRewards`, `acceptedBondTokens()` → `[pairToken]` |
| Compound | `compoundProtocolRewards()` (mandatory poke first) |
| Expansion | Policy-only natural expansion on touch points (peer spirit); Open never expands |
| Bond NFT / rebasing addrs | getters for wired packages |

---

## 5. Pricing, fixed-point, synthetic (LOCKED defaults)

### 5.1 Exchange rate R (pair → DETF)

**Direction (product):** always size mint/bond-open as **pairToken notional → DETF**.

**Encoding:** Uni V4 `sqrtPriceX96` is price of currency1 in terms of currency0 (Q64.96), token order sorted by address.

```text
// price1per0 = (sqrtPriceX96 / 2^96)^2
// If pairToken == currency0 and detfToken == currency1:
//   R_pair_to_detf = detf per 1 pair = price1per0 * 10^(decDetf - decPair)  (decimal adjust)
// If pairToken == currency1 and detfToken == currency0:
//   R_pair_to_detf = 1 / price1per0 * decimal adjust
```

Implement helpers:

- `_pricePairPerDetf(sqrtPriceX96) → wad` (optional)  
- `_priceDetfPerPair(sqrtPriceX96) → wad` (**mint uses this**)  
- Use **WAD (1e18)** intermediate; `mulDiv` only; document decimal handling with `IERC20Metadata.decimals()`.

**Mint size (gross before fee):**

```text
boostedPair = pairNotional * (1e18 + seigniorageIncentive) / 1e18   // boost on pair notional first
grossDetf   = boostedPair * R_detf_per_pair / 1e18                 // or mulDiv
// then usage fee + mint split (peer spirit)
```

Peer split pattern — **copy production Balancer peer exactly** (Single SE / MultiVaultWeighted):

```text
afterFee = gross * (1e18 - usageFee) / 1e18
feeToDetf = gross - afterFee
inventoryDetf = afterFee * (seigniorageIncentive / 2) / 1e18   // half-incentive
userDetf = afterFee - inventoryDetf
```

**Inventory routing (§0.3 #25):**

```text
if bondLedgerTotalWeight > 0:
  mint inventoryDetf → bond NFT vault (reward pool)
else:
  mint inventoryDetf → feeTo()
```

Do not invent a third split.

### 5.2 Option B & synthetic

```text
B = poolInitialized
  && twapReady(1800s)          // observation ring has ≥1800s span
  && activeInRangeLiquidity > 0  // StateLibrary.getLiquidity(poolId) > 0

R_mint = B ? R(TWAP) : R(creationSqrtPriceX96)

synthetic = B ? (P_twap / P_creation) * 1e18 : 1e18
// P in same pair↔DETF space as creation encoding; use detf-per-pair or pair-per-detf consistently
// Prefer: both P as detf-per-pair WAD so synthetic > 1e18 means DETF richer vs creation
```

**Gates (when live):**

| Mode | Mint / bond-open DETF mint | Burn |
|------|----------------------------|------|
| Policy | synthetic > mintThreshold | synthetic < burnThreshold |
| Open | always pass | always pass |
| First primary mint (bootstrap live) | **ungated** both modes | N/A |

Deadband: equality → neither mint nor burn.

### 5.3 Primary mint settlement

| `tokenIn` | Inventory | `pairTokenNotional` |
|-----------|-----------|---------------------|
| `pairToken` | `BackingSE.exchangeIn(pair → share)` onto DETF | `amountIn` |
| Backing vault share | pull shares onto DETF | SE **preview** exact-in `share → pairToken` for `amountIn` |
| Other token ∈ `BackingSE.tokens()` | `exchangeIn(token → share)` onto DETF | SE **preview** `token → pairToken` for `amountIn` |
| Else | revert `UnsupportedRoute` | — |

Then quote DETF from pair notional; mint split; user free DETF (primary path).

**Every primary mint (including first):** `pokeListingOracle()` **then** mint logic.

**Live:** first successful primary mint that increases DETF-held backing share inventory **and** listing pool already initialized in postDeploy.

**DETF ERC-20 decimals:** always **18**.

### 5.4 Primary burn

```text
// 1) Apply usage fee on DETF burned (fee oracle) — fee slice to feeTo as free DETF or peer burn pattern
// 2) Pre-burn total supply (full ERC-20 supply, includes DETF in bond OOR + rebasing)
sharesOut = detfNetForBurn * IERC20(share).balanceOf(detf) / totalSupply
```

- `tokenOut == share` → transfer shares  
- `tokenOut ∈ BackingSE.tokens()` → redeem via SE  
- else `UnsupportedRoute`  
- zero inventory / zero `sharesOut` → revert  
- **No** R/synthetic in payout size  
- **Usage fee only** on burn — no seigniorage boost / inventory mint split on burn  
- Dilution from DETF held in bond OOR / rebasing is **intentional**

### 5.5 Natural expansion (LOCKED — §0.3 #36)

Wire `DETFNaturalExpansionLib` peer path:

| Gate | Rule |
|------|------|
| Live | required |
| `thresholdMode` | **Policy only** — Open **never** expands |
| Synthetic | mint-allowed: `synthetic > mintThreshold` (“above peg”) |
| Capital | none — free DETF mint |

**Distribution (same as inventory seigniorage):**

```text
if bondLedgerTotalWeight > 0:
  mint expansion DETF → bond NFT vault reward pool (same pie as inventory)
else:
  mint expansion DETF → feeTo()
```

Deploy-time rate / catch-up caps from **`PkgArgs` → resolve → instance storage** only. No fee-oracle override. No post-deploy setter. Lazy on touch points peers use + keep reward debt consistent.

---

## 6. TWAP / observation ring (critical design)

### 6.1 V4 reality (aligned with PRD v0.19)

Uniswap **V4 PoolManager core does not store a V3-style observation ring** (Crane port confirms: no `observe` / cardinality on `StateLibrary` / `Pool` slot0 packing). Listing hooks remain **`address(0)`** (LOCKED).

**v1 resolution (PRD + plan LOCKED):**

Maintain an **application-level listing-oracle observation ring** on the DETF (or shared listing-oracle lib storage on DETF diamond):

| Field | Meaning |
|-------|---------|
| `observations[i] = (blockTimestamp, tickCumulative or tick)` | Ring buffer |
| `cardinality` / `index` | Bootstrap capacity at deploy |
| `initialized` | After pool init |

### 6.2 Writing observations

1. **postDeploy:** init pool; allocate ring with capacity `CARDINALITY` (see §6.4); write first observation at current tick + `lastObservationBlock = block.number`.  
2. **Permissionless `pokeListingOracle()`** (or `recordObservation()`): anyone may call; reads `slot0.tick` from PoolManager; **write only if `block.number > lastObservationBlock`** (same-block no-op).  
3. **Mandatory poke then act** at start of: **every** primary mint (**including first**), bond-open, bond close/sell, **`compoundProtocolRewards` / lazy compound**, natural-expansion touch points as needed, and any DETF-orchestrated listing swap.  
4. External LPs/swaps do **not** auto-update the ring — callers (or keepers/tests) poke so option B can become true. Document this in NatSpec.  
5. First in-range listing L is **permissionless** (no protocol bootstrap LP).

This satisfies: no listing-pool hook; TWAP-like 1800s average; creation-rate fallback until ready.

### 6.3 TWAP computation

Geometric mean via tick cumulative (V3 spirit):

```text
// Store tickCumulative at each write: tickCumulative += tick * Δt
// TWAP tick over [t-1800, t]:
//   (tickCumulative_now - tickCumulative_then) / 1800
// Convert tick → sqrtPriceX96 → R via TickMath
```

`twapReady`: oldest sample in window is ≥ `twapSeconds` before now **and** ring has ≥2 points spanning that window.

### 6.4 Cardinality bootstrap (LOCKED number)

| Param | Value | Rationale |
|-------|-------|-----------|
| `twapSeconds` | **1800** | PRD |
| Target samples over window | ~1 sample / 60s worst-case sparse pokes | gas vs fidelity |
| **`CARDINALITY`** | **32** | Covers 1800s at ~56s/sample; headroom for dense pokes; cheap SSTORE ring |

postDeploy: set `observationCardinality = 32` (grow if first write needs it). No PoolManager cardinality call (N/A on V4 core).

### 6.5 Tests for oracle

- t=0: B false; R = creation; synthetic = 1e18  
- poke + warp 10 min + in-range L: still B false (window incomplete)  
- poke + warp ≥1800 + L>0: B true; R = TWAP; synthetic moves with trades  
- Open mode ignores synthetic gates when live  

---

## 7. Bond lifecycle (implementation)

### 7.1 Open

1. Require **live**.  
2. **`pokeListingOracle()` first.**  
3. Policy mint gate on synthetic if Policy (Open: skip).  
4. Pull `pairToken` from user.  
5. Quote/mint DETF from pair notional + typical modifiers.  
6. feeTo free DETF; inventory DETF → bond vault if weight &gt; 0 else **feeTo()**; **user net DETF** held for DETF wing.  
7. Mint bond NFT `tokenId` to user.  
8. Derive pool-determined OOR ranges from current tick + `widthMultiplier` (same outer half-width as Uni V4 SE; **no center** on bond).  
9. Open pair-side OOR: single-sided pair; salt `keccak256(abi.encode(tokenId, pairToken))`.  
10. Open DETF-side OOR: single-sided DETF (user net); salt `keccak256(abi.encode(tokenId, detfToken))`.  
11. `effectiveShares = pairDeposited * lockBonus` via `DETFBondNFTMathLib` (**fee oracle** min floor / max clamp). DETF leg does **not** add weight.  
12. Ranges **fixed** for bond life (no rebalance while open).  
13. **Empty book OK:** in-range listing L may be zero; option B stays false until depth + TWAP window.
### 7.2 claimRewards

While open: free DETF from inventory ledger (peer `rewardPerShares`).

### 7.3 Maturity close (full only)

1. Require unlock time.  
2. Pay pending rewards.  
3. Withdraw **both** positions fully (NFT package unlocks PoolManager).  
4. **Burn all DETF** recovered (either leg).  
5. Send **all pairToken** to user.  
6. Retire NFT; stop accrual.

### 7.4 Sell → rebasing (full only)

1. **`pokeListingOracle()` first.**  
2. Pay pending rewards to user.  
3. Withdraw both positions fully into NFT package (or DETF orchestrator).  
4. Transfer **all pairToken + all DETF** to **rebasing package** (`absorbBondProceeds`).  
5. Rebasing: **re-derive ticks**, SE-style deposit of received balances into **standard center/wings**; compute ZapOut-to-pair **contribution**; mint **rebasing tokens**:

```text
// pre = ZapOutToPair(fullReserve) before deposit
// contribution = ZapOutToPair after deposit - pre
// if rebasingTotalSupply == 0: tokens = mirror Uni V4 SE first-share / inflation-guard policy
// else: tokens = contribution * rebasingTotalSupply / preZapOut
```

6. **Rebasing tokens → user.**  
7. **Credit protocol id 0** on the bond reward ledger with the sold bond’s **pair principal / original shares at open** (no dual OOR; no invented amount — only real principal from that bond). Match peer sell-to-protocol accounting spirit for weight units.  
8. Retire user bond NFT; user stops accruing on that id.  

**Not** PoolManager position ownership transfer.

**Direct rebasing deposit** (anyone): mint rebasing tokens to depositor only — **does not** grow id 0.

### 7.5 Protocol id 0 + compound

- Id 0: **ledger weight only** (no dual OOR). Principal **only after bond sell** (§0.3 #23); starts at 0.  
- Inventory seigniorage and natural expansion credit the bond vault when total weight &gt; 0 (including id 0 and open user bonds); else **`feeTo()`**.  
- `compoundProtocolRewards()` + lazy on reward-updating touches: **mandatory `pokeListingOracle()` first**; transfer pending free DETF for id 0 into rebasing **as DETF deposit** (`donateDetf`); **mint 0 rebasing tokens to protocol** (pure donation — intentional).  
- Lazy failure: best-effort; never fail user mint/bond solely because compound reverts.
---

## 8. Rebasing package (implementation)

### 8.1 Strategy (reuse SE)

From `UniswapV4PositionRepo` / `_deriveManagedTicks`:

- `widthMultiplier` from deploy  
- `centerWidthMultiplier = 2`  
- `activeLiquidityBps = 1000`  
- Positions: Center, LowerWing, UpperWing with fixed salts (package-level, not per-user)

Deposit workflow: behavioral copy of Uni V4 SE single-sided / dual deposit into wings (import helpers from SE common where possible without subclassing vault). **Always re-derive** center/wing ticks from current `slot0` on deposit, redeem residual redeposit, absorb, and donate.

### 8.2 Rebasing token mint formulas (LOCKED)

| Path | Formula |
|------|---------|
| Direct deposit pair or DETF | SE-style mint from **ZapOut-to-pair contribution** after wing placement → tokens to **depositor**; **id 0 unchanged** |
| Bond sell intake | Same after receiving tokens and depositing → tokens to **bond seller**; **id 0 principal credited** on bond ledger |
| Protocol donation | Deposit DETF; **rebasingTokensMinted = 0** |

**First depositor:** **mirror Uni V4 SE share mint math** exactly (virtual offset / min seed / inflation guards as implemented on Uni V4 SE deposit).

### 8.3 Obligation (LOCKED)

```text
obligationPair = rebasingTokensBurned * ZapOutToPair(fullManagedReserve) / totalRebasingSupply
```

`ZapOutToPair` = full exit of managed L to pair (quote: pro-rata burn all three positions + swap residual DETF → pair at market). Use Crane `UniswapV4ZapQuoter` / SE `_quoteZapOutAmount` spirit.

### 8.4 Redeem ladder (LOCKED)

Given `obligationPair` and `minOut`:

1. Withdraw from **pair wing** (pool-determined lower or upper that is pair-sided at open/current strategy) until obligation met or wing exhausted for this redeem.  
2. Else **center**.  
3. Else **DETF wing**.  
4. Else **swap exact DETF → pair** for shortfall only.  
5. Transfer `obligationPair` pair to recipient (`minOut` check) — **pay obligation only**.  
6. **Redeposit all residual DETF** and **all excess pair** (overshoot beyond obligation) into wings. Never send DETF to redeemer.

**Any wing may return both tokens:** pair counts to obligation; DETF never to redeemer.

**Sizing algorithm (deterministic):**

- Prefer **exact obligation** via iterative or closed-form pro-rata pulls when possible.  
- For each wing step: compute pair obtainable from burning L on that wing only (including both tokens if in-range); burn min L such that cumulative pair ≥ remaining obligation, or burn all remaining wing L for this path.  
- Document ≤ few-wei dust if pool math forces; tests allow `assertApproxEqAbs` only when documented.

### 8.5 Privileged DETF APIs on rebasing

```text
// onlyOwner where owner = DETF diamond (Ownable/operable); not vault-registry
function absorbBondProceeds(uint256 pairAmount, uint256 detfAmount, address rebasingRecipient)
  external returns (uint256 rebasingTokensMinted);
function donateDetf(uint256 detfAmount) external; // compound: deposit, no mint
```

---

## 9. Deploy path (Crane + registry)

1. Facets: `create3Factory.deploy*Facet()` via family `*_FactoryService`.  
2. Bond NFT DFPkg + Rebasing DFPkg: **pure Crane** path — CREATE3 facets + `diamondPackageFactory.deploy` / CREATE3 package deploy. **Not** vault-registry `deployPkg` (children are not Standard Exchange vaults; **not** discovered as vault packages).  
3. DETF DFPkg: `indexedexManager.deployUniswapV4SingleStandardExchangeDETFDFPkg(pkgInit)` (typed helper; **registry path**).  
4. Instance: `detfPkg.deployVault(args)` / registry `deployVault` — **never** raw `new` for facets/DFPkgs.  
5. postDeploy: pool init, listing-oracle ring (cardinality 32, first observation), deploy child bond + rebasing instances with **owner = DETF diamond**, wire storage, renounce DETF instance ownership as peers do (children retain DETF as Ownable owner).  
6. DETF ERC-20 decimals fixed **18** at init.
---

## 10. Testing plan

### 10.1 Principles

- Production-first: real DFPkgs, manager, fee oracle, Uni V4 SE as Backing SE, Crane Uni V4 contracts.  
- **No mocks of SUT** (DETF, facets, DFPkgs, bond NFT, rebasing, manager, registry, fee oracle, attached SE).  
- **No empty stub packages as integration SUT** — implement production-ready packages in plan order, then wire full integration tests.  
- Mintable ERC20 only for funding where needed; reentrancy hostile ERC20 only in adversarial suite.  
- Preview == execution on closed-form routes (exact where possible).
### 10.2 Gold TestBases

#### A. Hermetic — `TestBase_UniswapV4SingleStandardExchangeDETF`

**Chain:**

```text
CraneTest
  → IndexedexTest
  → TestBase_VaultComponents
  → TestBase_UniswapV4StandardExchange   // PoolManager + Uni V4 SE DFPkg
  → TestBase_UniswapV4SingleStandardExchangeDETF
```

**Setup:**

1. Deploy Crane `PoolManager` (as existing Uni V4 SE TestBase: production code from `@crane/.../uniswap/v4`).  
2. Deploy two mintable ERC20s (or use fixture tokens) as Backing SE pool legs; init a **Backing** Uni V4 pool + Uni V4 SE vault (`widthMultiplier` fixture).  
3. Seed Backing SE liquidity / shares.  
4. Choose `pairToken` = one of Backing SE `tokens()`.  
5. Deploy DETF family facets + `UniswapV4SingleStandardExchangeDETFDFPkg` via registry; deploy DETF instance with listing `sqrtPriceX96`, `poolFee`, `tickSpacing`, thresholds, `widthMultiplier`, expansion params.  
6. Assert postDeploy: listing pool init, hooks=0, bond NFT + rebasing wired (pure Crane children), oracle ring capacity 32, decimals 18.

**Do not** use Camelot/Aerodrome TestBases for this family.

#### B. Robinhood mainnet fork — `TestBase_UniswapV4SingleStandardExchangeDETF_RobinhoodFork`

**Location:**  
`test/foundry/fork/robinhood_main/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/single/`

**Setup:**

1. `vm.createSelectFork(rpc)` with `foundry.toml` `robinhood_mainnet` (chain **4663**).  
2. Use **pinned** production Uni V4 `PoolManager` from `ROBINHOOD_MAIN.UNISWAP_V4_POOL_MANAGER` (`0x8366a39CC670B4001A1121B8F6A443A643e40951`); Permit2 / periphery from same library as needed. Verify `extcodesize` in TestBase setup.  
3. Deploy IndexedEx stack (CREATE3/manager) **on the fork** against live PoolManager.  
4. Deploy **new** Backing Uni V4 pool + SE vault with **mintable test tokens** on production PoolManager.  
5. Deploy **new** DETF listing pool (test DETF + pairToken) on production PoolManager.  
6. Same lifecycle suites as hermetic where gas/RPC allow.

**Standard practice note:** hermetic proves package logic against Crane Uni V4 port; fork proves integration against **production** V4 singleton on Robinhood using fresh pools/tokens.

### 10.3 Spec suites (hermetic) — required coverage

Map 1:1 to PRD testing expectations.

| ID | Suite / file (indicative) | Assertions |
|----|---------------------------|------------|
| T01 | Deploy / validation | `pairToken ∉ tokens` reverts; non-zero hooks reverts; inert deploy; packages distinct addresses; children not registry vaults; DETF decimals 18 |
| T02 | First primary mint → live | poke then mint; share or SE token in; inventory on DETF; live=true; synthetically ungated; no listing depth required; inventory → feeTo if no bond weight |
| T03 | Mint routes | `tokenIn=pair`, `tokenIn=share`, other SE token; pair notional rules; preview==execution; fee/incentive order (boost on pair before R); peer half-incentive exact |
| T04 | Burn | usage fee only; fair-share pre-burn full totalSupply; tokenOut share + SE token; empty inventory reverts; **not** synthetic-sized; dilution with bonded DETF intentional |
| T05 | Option B / TWAP | creation path; after poke+warp+in-range L → TWAP path; synthetic formula; Policy gates; Open never gates; bond-open gated under Policy; same-block poke no-op |
| T06 | Quote opacity | never uses vault share as R in-asset |
| T07 | Bond open | empty book OK; dual OOR; pool-determined wings; salts; effectiveShares = pair × lock bonus; claimRewards free DETF |
| T08 | Maturity close | full only; burn all DETF; pair only to user; no partial close surface |
| T09 | Sell → rebasing | withdraw → tokens to rebasing → wings → rebasing tokens to user; **id 0 principal &gt; 0**; NFT retired; no further user bond rewards |
| T10 | Rebasing deposit | anyone deposits pair or DETF; rebasing tokens; same listing pool; **id 0 unchanged** on direct deposit; ticks re-derived |
| T11 | Redeem ladder | obligation = pro-rata ZapOut-to-pair; pair→center→DETF wing→sell just enough; pair only out; residual DETF redeposited; both-token wing handling |
| T12 | Topology | Backing SE ≠ rebasing; Uni V4 SE DFPkg not rebasing package; hooks=0; external LP unrestricted (modifyLiquidity from EOA) |
| T13 | Protocol compound | after sell so id 0 weighted; pure donation; rebasing supply unchanged; ZapOut-per-share ↑; lazy best-effort + public compound |
| T14 | Threshold modes | Policy deadband; Open ungated when live; first mint ungated both |
| T15 | Price movement | drive mark via listing swaps + pokes so both mint-allowed and burn-allowed under **default** thresholds |
| T16 | Natural expansion | Policy + synthetic above mint threshold expands → bond rewards if weight &gt; 0 else feeTo; Open never expands; no capital required |

### 10.4 Fork suites (Robinhood) — required

| ID | Focus |
|----|--------|
| F01 | Deploy DETF + Backing Uni V4 SE against live PoolManager; **new pools + mintable test tokens** |
| F02 | First mint → live; mint/burn smoke (usage fee on burn) |
| F03 | Bond open + sell → rebasing tokens + id 0 principal on production pool math |
| F04 | Redeem ladder against production swap/liquidity |
| F05 | External LP + poke oracle + TWAP path after warp (fork time cheatcodes) |

### 10.5 Adversarial (phase after green path)

Follow `indexedex-adversarial-testing` + `crane-adversarial-testing`:

- Reentrancy on mint/bond/redeem (hostile ERC20 as share or pair) → `IsLocked`  
- Donation of pair/DETF to rebasing or DETF (share inflation / claim dilution)  
- Bond double-close / sell after close  
- Redeem more shares than balance  
- Oracle poke griefing (spam) — gas DoS bounds  
- UnsupportedRoute fuzz  

### 10.6 Invariants (optional stretch)

Handler over: mint, burn, bond open/close/sell, claim deposit/redeem, poke, compound, external swap.

Candidates:

- DETF backing share balance ≥ 0 and burn fair-share conserves inventory  
- Rebasing: sum user claim claims ≤ totalSupply; obligation monontonic in ZapOut  
- Never send DETF to claim redeemer  
- Listing hooks remain zero  

---

## 11. Implementation phases

### Phase 0 — Scaffold & interfaces (0.5–1 d)

- [ ] Directory skeleton under `single/`, `common/nft/`, `common/rebasing/`  
- [ ] Interfaces + facets/repos/DFPkgs with `PkgInit`/`PkgArgs` on interfaces (`UniswapV4SingleStandardExchangeDETFDFPkg`)  
- [ ] FactoryService skeletons (DETF registry; children pure Crane)  
- [ ] Wire foundry project compiles (bodies filled in later phases — not used as integration SUT until production-ready)

### Phase 1 — Listing oracle + pricing lib (1–2 d)

- [ ] Observation ring (cardinality 32); write iff `block.number > last`  
- [ ] `pokeListingOracle`, TWAP, option B, synthetic  
- [ ] pair→DETF R fixed-point unit tests (pure / hermetic pool); 18-dec DETF  
- [ ] Creation-rate path tests  

### Phase 2 — Rebasing package (2–3 d)

- [ ] DFPkg deploy (pure Crane); center/wings using PositionRepo + SE deposit spirit; always re-derive ticks  
- [ ] Direct deposit pair/DETF + rebasing token mint formula  
- [ ] ZapOut-to-pair quote  
- [ ] Redeem ladder + residual DETF redeposit  
- [ ] `absorbBondProceeds` / `donateDetf`  
- [ ] Production package tests (+ PoolManager hermetic)

### Phase 3 — Bond NFT package (2 d)

- [ ] Dual OOR open with salts  
- [ ] Reward ledger (peer DETFNFTVault spirit)  
- [ ] Maturity withdraw + burn path helpers  
- [ ] Sell withdraw → token push to rebasing  
- [ ] Protocol id 0 principal credit on sell only  

### Phase 4 — DETF core mint/burn/live/expansion (2–3 d)

- [ ] Repo + Common + Exchange In/Out/Query  
- [ ] Inventory settlement via Backing Uni V4 SE  
- [ ] Mint split (peer exact) + inventory → feeTo if no weight  
- [ ] Burn usage fee only + fair-share full totalSupply  
- [ ] Threshold Policy/Open  
- [ ] Natural expansion (`DETFNaturalExpansionLib`) + PkgArgs  
- [ ] First mint → live (poke then mint)  
- [ ] DFPkg postDeploy: pool init, oracle, deploy children  

### Phase 5 — DETF bonding + compound (1–2 d)

- [ ] Bond open/close/sell orchestration (id 0 on sell)  
- [ ] claimRewards  
- [ ] compoundProtocolRewards + lazy hooks  

### Phase 6 — Gold TestBase + hermetic suite (2–3 d)

- [ ] `TestBase_UniswapV4SingleStandardExchangeDETF`  
- [ ] T01–T16 green  

### Phase 7 — Robinhood fork suite (1–2 d)

- [ ] Fork TestBase + address constants; new pools + test tokens  
- [ ] F01–F05  

### Phase 8 — Adversarial + polish (1–2 d)

- [ ] Adversarial catalog tests  
- [ ] NatSpec, factory services, size check  
- [ ] PRD status note / optional LOCK stamp  

**Rough total:** ~12–18 engineer-days depending on SE deposit reuse depth.
---

## 12. Implementation order within packages (build sequence)

```text
1. UniV4DetfListingOracleLib (+ tests)
2. UniV4DetfRebasingClaim* (deposit → zap quote → redeem ladder → donate/absorb)
3. UniV4DetfBondNft* (positions + rewards + withdraw + id 0 on sell)
4. UniswapV4SingleStandardExchangeDETF* Common (R, synthetic, gates, inventory/feeTo, expansion)
5. ExchangeIn/Out + Info
6. Bonding + compound
7. UniswapV4SingleStandardExchangeDETFDFPkg postDeploy wiring
8. FactoryService + DETF registry registration (children pure Crane)
9. TestBase hermetic → specs (T01–T16) → fork
```
---

## 13. Code reuse map

| Need | Reuse from |
|------|------------|
| Wing ticks / widthMultiplier | `UniswapV4PositionRepo` |
| PoolKey / PoolManager storage patterns | `UniswapV4PoolKeyAwareRepo`, `UniswapV4PoolManagerAwareRepo` |
| ZapOut quote | Crane `UniswapV4ZapQuoter` + SE `_quoteZapOutAmount` patterns |
| Unlock / modifyLiquidity | SE Common unlock pattern (copy/adapt into rebasing + bond packages) |
| Thresholds | `DETFThresholdPolicy` |
| Mint fee split | `DETFUsageFeeLib` + peer half-incentive inventory (**exact** production constants) |
| Natural expansion | `DETFNaturalExpansionLib` + PkgArgs rate/caps |
| Lock bonus | `DETFBondNFTMathLib` |
| Bond reward ledger spirit | `DETFNFTVault*` (adapt; new package, not subclass Balancer LP token assumptions) |
| Rebasing token mint inflation guards | Uni V4 SE deposit share math |

**Forbidden:** subclass `UniswapV4StandardExchangeDFPkg` as rebasing; import Balancer reserve packages into this family; vault-registry deploy for bond/rebasing children.

---

## 14. Error catalog (minimum)

| Error | When |
|-------|------|
| `PairTokenNotInBackingTokens` | deploy |
| `HooksNotAllowed` | deploy hooks ≠ 0 |
| `InvalidCreationPrice` | bad sqrtPrice |
| `NotLive` / `AlreadyLive` | gates |
| `MintNotAllowed` / `BurnNotAllowed` | Policy synthetic |
| `UnsupportedRoute` | bad tokenIn/Out |
| `EmptyInventory` | burn with 0 shares |
| `BondNotMature` | early close |
| `PartialCloseNotSupported` | if any partial API attempted |
| `InvalidBondToken` | bond tokenIn ≠ pair |
| `SlippageExceeded` / `MinOut` | mint/burn/redeem/bond |

**Do not emit `TwapNotReady`.** Creation-rate fallback is always available when option B is unusable.

---

## 15. NatSpec & docs

- Role names only (`pairToken`, `backingStandardExchangeVault`, `detfToken`, `rebasingClaimToken` / rebasing token, …) — no brand tickers.  
- Document listing-oracle ring + `pokeListingOracle` (V4 core has no observation ring; hooks=0; write iff new block).  
- Document **poke then act** on every mint (including first), bond, close, sell, compound.  
- Document maturity burn-all-DETF vs sell withdraw-to-rebasing (tokens, not position migrate).  
- Document id 0: ledger-only; principal from **bond sell only**; pair-only user `effectiveShares`.  
- Document inventory + expansion → bond rewards or **`feeTo()`** when no weight.  
- Document natural expansion Policy-only; Open never expands.  
- AsciiDoc include-tags only if peer packages use them; otherwise NatSpec sufficient.

---

## 16. Exit criteria (definition of done)

1. PRD **v0.19** + plan **§0.3** behaviors implemented; no reopened locked decisions without PRD/plan bump.  
2. Hermetic **T01–T16** pass.  
3. Robinhood fork F01–F05 pass against production PoolManager (`ROBINHOOD_MAIN`) with **new pools + test tokens**.  
4. No SUT mocks; CREATE3 for facets; DETF via registry; bond/rebasing via pure Crane.  
5. `forge build` clean for new packages; sizes acceptable.  
6. Backing SE and rebasing are distinct; rebasing is not Uni V4 SE vault.  
7. Protocol compound: donation only (rebasing supply unchanged on compound); poke on compound.  
8. Natural expansion: Policy above peg → bond rewards or feeTo; Open never expands.  
9. Optional: mark PRD **LOCKED** after product owner stamp.

---

## 17. Open implementation notes (non-blocking)

| Topic | Plan default |
|-------|----------------|
| V4 core lacks observations | App-level ring + permissionless poke (§6) — **LOCKED** / PRD v0.19 |
| Oracle write cadence | **`block.number > lastObservationBlock` only** |
| Robinhood PoolManager address | **Pinned:** `ROBINHOOD_MAIN.UNISWAP_V4_POOL_MANAGER` |
| Robinhood fixtures | **New pools + mintable test tokens** |
| First rebasing deposit seed | **Mirror Uni V4 SE** first-share policy |
| Excess pair on redeem overshoot | User gets **obligation only**; excess pair + residual DETF redeposited |
| Lazy compound touch list | mint, bond open, claimRewards, sell, close, **compound** — best-effort; **poke first** |
| Child Ownable | owner = DETF diamond for `absorbBondProceeds` / `donateDetf` |
| Protocol id 0 weight | Ledger only; principal **on bond sell**; never invented at deploy |
| Inventory / expansion if no weight | **`feeTo()`** |
| DFPkg name | `UniswapV4SingleStandardExchangeDETFDFPkg` |
| DETF decimals | **18 always** |
| Natural expansion | **In scope** (§5.5 / §0.3 #36) |

---

## 18. Revision history

| Ver | Date | Notes |
|-----|------|-------|
| 0.1 | 2026-08-01 | Initial plan from PRD v0.18 + product decisions (claim mint, rebasing shape A, withdraw-to-rebasing, lib reuse A, SE wing defaults, per-instance deploy, Uni V4 SE + Robinhood fork tests, colocated) |
| 0.2 | 2026-08-01 | Align with PRD v0.19: app-level TWAP + poke on compound; id 0 ledger-only; pair-only effectiveShares; child Ownable→DETF; pure Crane children; fee-oracle lock; mirror SE first claim; obligation-only redeem; permissionless first L; `ROBINHOOD_MAIN` pin; full-phase scope |
| 0.3 | 2026-08-01 | Post-review locks §0.3: id 0 principal on bond sell only; inventory/expansion → feeTo if no weight; natural expansion **in scope** (Policy); burn usage fee only; full totalSupply burn dilution; always re-derive rebasing ticks; poke-then-mint including first; oracle per-block; DFPkg name `UniswapV4SingleStandardExchangeDETFDFPkg`; no `TwapNotReady`; decimals 18; Robinhood new pools+test tokens; T16; production-only integration tests |