# Implementation & Test Plan: Uniswap V4 Standard Exchange Quad Stable Buffer Hook

**PRD (product law SoT):** [`UNISWAP_V4_STANDARD_EXCHANGE_QUAD_STABLE_BUFFER_HOOK_PRD.md`](./UNISWAP_V4_STANDARD_EXCHANGE_QUAD_STABLE_BUFFER_HOOK_PRD.md) (**LOCKED v0.2**)  
**This plan (implementor SoT):** greenfield package under `standardExchange/stable/quad/` — **no** existing scaffold (PRD only).  
**Package:** `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/`  
**Date:** 2026-08-07  
**Status:** **Canonical plan — aligned to PRD LOCKED v0.2**. Ready for implementor stamp, then code. **No production code in this doc-only pass.**

**Authority**

| Layer | Role |
|-------|------|
| **PRD LOCKED v0.2** | Product law (D1–D81, O1–O13, Q1–Q9, §0–§13). **PRD wins** on conflict |
| **This plan** | Implementor SoT for phases, file map, helpers, dual-domain algebra, Phase 0 closed-form audit, tests, deploy wiring |
| Raw Quad StableSwap | Curve / \(A\) / \(n=4\) / six doors / getD/getY / geoMean first mint / witness-tolerant solver **behavioral** reference — **do not subclass**; **do not** copy monomorph CREATE3 factory law; **do not** inherit deploy-time pips fee-on-output or raw-only inventory |
| SE Weighted Buffer | Inventory LP domain / dual WAD scales / single-asset aliases / MultiAssetLiquidity / ≥1 SE / gross buffer / dual-channel fees / taxable single-asset via `dexSwapFeeOfVault` **accounting** reference — **do not subclass**; curve is **StableSwap**, not weighted |
| SE Orbital Buffer | Multi-leg SE slots / diamond package / buffer-last / SE funding / vault discovery **shape** reference — **do not subclass**; curve is **StableSwap**, not sphere |
| Dual SE Buffer CP | Buffer / unwrap / claim-in / buffer-last **process** peer only |
| Hook diamond factory | Deploy / salt / flags / immutability — factory PRD + `indexedex-uniswap-v4-hook-packages` skill |

**Read order for implementors**

1. PRD §0 terminology (**native vs rated**, dual scale, buffer-last, Q7–Q9 pins) + §1.1 user story  
2. PRD §3 locked tables (D20–D59b, D57–D57b, Q1–Q9) + §13 LOCK  
3. PRD §4.3 dual domains, §4.4 StableSwap swaps, §4.5 LP, §4.6 SE surfaces  
4. PRD §5 deploy, §6 events, §7 security, §8 DoD, §9 plan-only opens (I1–I7)  
5. **This plan** §1–§11 (scope, files, helpers, phases, tests)  
6. Skill `indexedex-uniswap-v4-hook-packages` for registry → hook factory path  

**Process rule:** If this plan and PRD disagree, **PRD wins** and this plan must be patched. Do not reopen PRD-locked decisions without a PRD revision. After each phase: `forge build` green and that phase’s tests green before the next.

**Implementor card (LOCKED v0.2)**

| Lock | Value |
|------|--------|
| Product name | `UniswapV4StandardExchangeCurveQuadStableBufferHook` (D1) |
| Deploy | **Hook diamond package only** — registry `deployHookVault` + shared hook factory CREATE2 mine (D71). **Not** monomorph CREATE3 product factory |
| Assets | **Exactly four** pool tokens; strict address ascending; decimals **[6, 18]** (D4, D9) |
| SEs | Optional per leg; **≥1 required**; non-zero SEs **pairwise distinct** (D5–D5b, Q1) |
| Rate providers | Optional **only** on SE legs; **swap (rated) valuation only**; fail-closed (D6–D6a, Q2, O5) |
| Amp | Deploy-time immutable `baseAmp`; `A' = baseAmp * AMP_PRECISION` with **`AMP_PRECISION = 100`**; `0 < baseAmp < MAX_AMP` (**`MAX_AMP = 1_000_000`**); no ramp (D7) |
| LP domain | **Native inventory only** — live face \| live SE shares; **no** claim/RP in join/exit/`kLast` (Q3, D23) |
| Swap domain | **Rated** balances: face / `seBal×rate` / claim → **pair-token** scale (D22, D23a) |
| Dual scale | `invScale` (face \| share decimals) ≠ `ratedScale` (always pair-token decimals) (D23a) |
| Live book | Raw leg = `token.balanceOf(hook)`; buffered leg = `IERC20(SE).balanceOf(hook)`; donations dilute (D21) |
| One-token | Stable **single-asset only**; aliases `depositSingle`/`withdrawSingle`; **no** multi-leg rebalance (Q4, D43) |
| Single-asset tax | Taxable portion = live **`dexSwapFeeOfVault`** (Q9, D41a, D59b) |
| Growth | **`usageFeeOfVault` + inventory `kLast`** on LP add/remove only (D61–D64) |
| Phase 0 paths | `joinSingleAssetExactOut` / `exitSingleAssetExactTokenOut` / `joinUnbalanced`: **ship iff closed-form**; else selectors present + **`InvalidRoute`** (Q8, D57b) |
| MultiAssetLiquidity | **Full shared** `IStandardExchangeMultiAssetLiquidity` cut; unsupported → **`InvalidRoute`** (Q8) |
| Zero-witness | **Defensive solver only** — not a required product matrix row (Q7, D49, D72) |
| First mint | **All four** legs > 0; inventory `geoMean4 − MINIMUM_LIQUIDITY` (D44) |
| Swap buffer | Buffer **full gross** amountIn; curve uses fee-net (D59a) |
| LP pull | `transferFrom` if allowance else Permit2 **AllowanceTransfer only** — no SignatureTransfer / no `permit2Data` (D47) |
| PM + feeOracle | **Factory immutables only** (D8) |
| Doors | postDeploy all **6** pairs + permissionless `ensurePairPools` (D75–D75a) |
| PRODUCT_ID | `"UniswapV4StandardExchangeCurveQuadStableBufferHook"` (D73) |
| LP symbol prefix | **`SEQS`** (D46); symbol ≤32, name ≤64 |
| Forks | **Ethereum + Base + Robinhood (4663)** all required, equal priority (D79) |
| Test SE | Production ERC-4626 **wrapper** SE(s) + mintable tokens; matrix 1–4 SE + RP on/off (D78) |
| Integration tests | Prefer full production stack; no mock SUT hook / SE / manager / registry / factory / fee oracle / PM |

---

## 0. Starting state

| Item | Status |
|------|--------|
| PRD LOCKED v0.2 | Present at package path |
| Hook / DFPkg / FactoryService / interface Solidity | **None** — greenfield |
| Tests / TestBase | **None** (TestBase will be package-adjacent) |
| Raw Quad StableSwap | Peer under `…/hooks/uniswap/v4/stable/quad/` — StableSwap math / six doors / geoMean **behavioral** reference only |
| SE Weighted Buffer diamond | Peer under `…/standardExchange/weighted/` — gold **accounting** + MultiAssetLiquidity + dual scale |
| SE Orbital Buffer diamond | Peer under `…/standardExchange/orbital/` — gold **deploy shape** + multi-SE process |
| Dual SE BCP | Peer under `…/standardExchange/dual/` — buffer-last / claim helpers pattern |
| Hook diamond factory | Present under `contracts/hooks/uniswap/v4/factory/` — **required** production path |
| ERC-4626 wrapper SE | Exists at `contracts/vaults/standard/erc4626/` — Phase 0 verify/deploy |
| `IStandardExchangeMultiAssetLiquidity` | **Already exists** at `contracts/interfaces/IStandardExchangeMultiAssetLiquidity.sol` — implement **full cut**; do **not** redefine a second interface |

**Do not** start by forking monomorph raw-quad sources into this package:

| Raw Quad monomorph | This package |
|--------------------|--------------|
| Raw ERC-20 inventory only | Raw **and/or** live SE shares per leg; **≥1 SE** |
| Optional pair-token RP on any leg scales swap+LP | RP **SE legs only**, **swaps only**; LP on inventory |
| Deploy-time pips fee-on-output | Live oracle dual-channel + input residual |
| Multi-leg zap-in | **Single-asset aliases only** |
| CREATE3 monomorph / hook-factory refactor path | Hook diamond + registry `deployHookVault` |
| No SE In/Out product surface | SE In/Out **+** MultiAssetLiquidity **required** |
| Single contract wire | Facets + Targets + Repo; cut shared ERC20/vault facets |

**Do not** subclass Weighted/Orbital/Dual/Single SE BCP types either — fresh codepath; pure libs OK (StableSwap Newton may pattern-copy raw-quad Math; dual-scale / buffer-last pattern-copy weighted/orbital ClaimLib).

---

## 1. Scope (v1 DoD)

Implement production-first package **`UniswapV4StandardExchangeCurveQuadStableBufferHook`**:

1. Bind **exactly four** ERC-20s + optional `standardExchange[4]` + optional `rateProvider[4]` + immutable `baseAmp`; `poolManager` + `feeOracle` from **factory immutables**. Permit2 = Uniswap well-known constant (not binding arg).  
2. **≥1** non-zero SE; non-zero SEs pairwise distinct; RP only where SE set; tokens address-ascending, decimals [6,18].  
3. Per leg: live raw face inventory **or** live SE shares as book. Pool currencies = the four tokens only — **never** SE share addresses.  
4. **StableSwap** (\(n=4\), amp \(A\)) on **rated** balances for swaps; **inventory-domain** algebra for LP / first-mint geo-mean / `kLast` (dual scale D23a).  
5. **All six** \(\binom{4}{2}\) Uni V4 pair doors, `hooks = this`, `fee = DYNAMIC_FEE_FLAG`, `tickSpacing = 1`.  
6. Buffer pool→SE on add / swap-in; unwrap SE→pool on remove / swap-out — **buffer-last** (D29).  
7. Fungible **ERC-20 LP** on the mined hook proxy (decimals **18**); EIP-2612 via shared facets; prefix **`SEQS`**.  
8. Proportional join/exit + single-asset aliases; Phase 0 exact-out / unbalanced **iff** closed-form else **`InvalidRoute`**. **No multi-leg rebalance.**  
9. **`IStandardExchangeIn` / `Out`** (swap-only, rated book, internal settle) + **full shared** **`IStandardExchangeMultiAssetLiquidity`**.  
10. Swaps via **`beforeSwap` + `beforeSwapReturnDelta`**; pattern-copy settle — **no** BaseHook / DeltaResolver inheritance.  
11. Trading residual = live `dexSwapFeeOfVault` (gross buffer on SE in); single-asset taxable = same channel; growth = Uni V2–style inventory product measure + `usageFeeOfVault`.  
12. Deploy: facets CREATE3 + DFPkg via registry; instances via `deployHookVault` + hook factory; **postDeploy inits all six doors**; **`ensurePairPools`**.  
13. Vault discovery: `IBasicVault` + `IStandardVault`; `reserveOfToken` = face \| **live SE shares** (not claim, not rated).  
14. Hermetic SE count matrix 1–4 + RP on/off; adversarial suite; forks Ethereum + Base + RH 4663.  
15. Size within real CREATE2/runtime limits; split facets/libs as needed without dropping D57a surface.

**Out of scope (v1):** Zero-SE mode (use raw Quad); multi-leg force-buy/sell rebalance; pair-token RP on raw legs; amp ramp; native ETH currency; FoT/rebasing pool tokens; binary-search as primary product law; monomorph CREATE3 product factory; subclassing quad/weighted/orbital/dual/single contracts; auto-deploy SE/RP; owner/pause on instance; treating V4 `sqrtPriceX96` as product mid; DETF coupling / shared DETF TestBases; SignatureTransfer on LP joins or canonical SE In/Out; same SE on two legs; multi-SE per token; intentional partial-book product modes; constructing zero-witness books as a required hermetic matrix row.

**Peer patterns (copy, do not inherit):**

| Peer | Copy what |
|------|-----------|
| SE Weighted / Orbital DFPkg + facets | Hook package shape, `deployVault` → `deployHookVault`, shared ERC20/vault facet cuts, FactoryService, postDeploy doors, MultiAssetLiquidity facade |
| Raw Quad Math | Classic Curve `getD` / `getY` (n=4), `AMP_PRECISION`, Newton 255 iters, `geometricMean4`, post-state priceability |
| Weighted dual scale + taxable single-asset | invScale/ratedScale, single-asset tax via `dexSwapFeeOfVault`, live book, growth predicate |
| Dual / Orbital ClaimLib / buffer-last | Claim-in composition, SE buffer/unwrap tight bounds, dust refund, gross buffer |
| Dual / Orbital settle | `beforeSwap` take / settle / `BeforeSwapDelta` discipline |
| Hook factory skill | Salt without package; flags; immutability; postDeploy |

---

## 2. File map (target)

```text
contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/
  UNISWAP_V4_STANDARD_EXCHANGE_QUAD_STABLE_BUFFER_HOOK_PRD.md
  UNISWAP_V4_STANDARD_EXCHANGE_QUAD_STABLE_BUFFER_HOOK_IMPLEMENTATION_AND_TEST_PLAN.md  # this file

  interfaces/
    IUniswapV4StandardExchangeCurveQuadStableBufferHook.sol
      // product surface + documents In/Out + MultiAssetLiquidity + vault discovery
    IUniswapV4StandardExchangeCurveQuadStableBufferHookPackage.sol
      // IUniswapV4HookDiamondPackage + IStandardVaultPkg + PkgInit/PkgArgs

  UniswapV4StandardExchangeCurveQuadStableBufferHookDFPkg.sol
  UniswapV4StandardExchangeCurveQuadStableBufferHook_FactoryService.sol
  UniswapV4StandardExchangeCurveQuadStableBufferHookRepo.sol
  UniswapV4StandardExchangeCurveQuadStableBufferHookMath.sol       # pure: dual scale, StableSwap getD/getY, geoMean4, growth, join/exit helpers
  UniswapV4StandardExchangeCurveQuadStableBufferHookClaimLib.sol  # SE claim + rate + buffer/unwrap (external)
  UniswapV4StandardExchangeCurveQuadStableBufferHookPullLib.sol   # optional: transferFrom / Permit2 AllowanceTransfer
  UniswapV4StandardExchangeCurveQuadStableBufferHookPairPoolLib.sol  # optional: six-door key builders / ensure helpers
  UniswapV4StandardExchangeCurveQuadStableBufferHookTarget.sol    # shared book/guards (or split Targets)
  UniswapV4StandardExchangeCurveQuadStableBufferHookLiquidityTarget.sol
  UniswapV4StandardExchangeCurveQuadStableBufferHookSeTarget.sol  # SE In/Out + MultiAssetLiquidity facade
  UniswapV4StandardExchangeCurveQuadStableBufferHookHooksTarget.sol

  facets/
    UniswapV4StandardExchangeCurveQuadStableBufferHookLiquidityFacet.sol
    UniswapV4StandardExchangeCurveQuadStableBufferHookSeFacet.sol
    UniswapV4StandardExchangeCurveQuadStableBufferHookHooksFacet.sol

  TestBase_UniswapV4StandardExchangeCurveQuadStableBufferHook.sol
```

**Shared SE interface (existing — cut into diamond):**

```text
contracts/interfaces/IStandardExchangeMultiAssetLiquidity.sol
  // Full interface cut (PRD Q8). Unsupported methods → InvalidRoute (exec + preview).
```

**Shared facets cut into proxy (mandatory — skill law):**

| Cut | Source |
|-----|--------|
| `ERC20Facet` + `ERC5267Facet` + `ERC2612Facet` | ERC20PermitDFPkg parity — LP = proxy |
| `MultiAssetBasicVaultFacet` + `MultiAssetStandardVaultFacet` | vaultTokens / reserveOfToken / vaultConfig / vaultTypes |
| Product facets only | hooks + book + join/exit + one-token aliases + SE In/Out + MultiAssetLiquidity + buffer |

**FORBIDDEN**

- `new` SUT facets/DFPkg/hook instances  
- Monomorph CREATE3 product factory for this package  
- Vault factory salt / `deployVault` path that skips hook factory (wrong flags)  
- Package/facet addresses in `packageSalt`  
- Live `diamondCut` after postDeploy  
- Solidity inheritance of Crane/OZ `BaseHook`, `BaseTokenWrapperHook`, `DeltaResolver`  
- Short production type names (`SEQSHook`, `QuadSEBHook`, …)  
- Multi-leg rebalance “zap split” helpers  
- Conflating invScale and ratedScale  
- Dropping MultiAssetLiquidity selectors when Phase 0 OMITs behavior  

**Tests (canonical names):**

```text
test/foundry/spec/hooks/uniswap/v4/standardExchange/stable/quad/curve/
  UniswapV4StandardExchangeCurveQuadStableBufferHook_Deploy.t.sol
  UniswapV4StandardExchangeCurveQuadStableBufferHook_Binding.t.sol        # 4 tokens, ≥1 SE, distinct SE, RP rules, amp bounds
  UniswapV4StandardExchangeCurveQuadStableBufferHook_Scale.t.sol          # dual inv/rated scale; mixed 6/18 decimals
  UniswapV4StandardExchangeCurveQuadStableBufferHook_Liquidity.t.sol      # first mint geoMean / prop join/exit / floors
  UniswapV4StandardExchangeCurveQuadStableBufferHook_SingleAsset.t.sol    # depositSingle / withdrawSingle + taxable fee
  UniswapV4StandardExchangeCurveQuadStableBufferHook_InvalidRoute.t.sol   # Phase-0-omitted selectors revert InvalidRoute
  UniswapV4StandardExchangeCurveQuadStableBufferHook_Swap.t.sol           # 6 doors × directed pairs; gross buffer; rated book
  UniswapV4StandardExchangeCurveQuadStableBufferHook_SeExchange.t.sol     # IStandardExchangeIn/Out
  UniswapV4StandardExchangeCurveQuadStableBufferHook_MultiAssetLiq.t.sol  # full shared interface + facade
  UniswapV4StandardExchangeCurveQuadStableBufferHook_Buffer.t.sol         # buffer-last, dust, claim≠raw
  UniswapV4StandardExchangeCurveQuadStableBufferHook_RateProvider.t.sol   # RP on/off, fail-closed, swap-only
  UniswapV4StandardExchangeCurveQuadStableBufferHook_Fees.t.sol           # dual-channel trading + growth + single-asset tax
  UniswapV4StandardExchangeCurveQuadStableBufferHook_Preview.t.sol        # bit-exact previews
  UniswapV4StandardExchangeCurveQuadStableBufferHook_Permit2.t.sol        # LP + SE AllowanceTransfer paths
  UniswapV4StandardExchangeCurveQuadStableBufferHook_VaultViews.t.sol     # IBasicVault + IStandardVault; reserveOfToken=shares
  UniswapV4StandardExchangeCurveQuadStableBufferHook_EnsureDoors.t.sol    # ensurePairPools
  UniswapV4StandardExchangeCurveQuadStableBufferHook_MathWitness.t.sol    # optional pure-Math zero-witness (I7)
  UniswapV4StandardExchangeCurveQuadStableBufferHook_ExactOut.t.sol       # ONLY if Phase 0 SHIPs exact-out variants
  UniswapV4StandardExchangeCurveQuadStableBufferHook_Unbalanced.t.sol     # ONLY if Phase 0 SHIPs joinUnbalanced
  UniswapV4StandardExchangeCurveQuadStableBufferHook_Adversarial.t.sol    # O11 suite
  UniswapV4StandardExchangeCurveQuadStableBufferHook_SeMatrix.t.sol       # 1/2/3/4 SE configs

test/foundry/fork/eth_main/hooks/uniswap/v4/standardExchange/stable/quad/curve/
  UniswapV4StandardExchangeCurveQuadStableBufferHook_Ethereum.t.sol

test/foundry/fork/base_main/hooks/uniswap/v4/standardExchange/stable/quad/curve/
  UniswapV4StandardExchangeCurveQuadStableBufferHook_Base.t.sol

test/foundry/fork/robinhood_4663/hooks/uniswap/v4/standardExchange/stable/quad/curve/
  UniswapV4StandardExchangeCurveQuadStableBufferHook_Robinhood.t.sol
```

Prefer **`FOUNDRY_PROFILE=hook_factory`** (or repo equivalent) for this tree when factory/registry stack requires it. Default profile remains hermetic `test/foundry/spec/**`.

---

## 3. Asymmetry implementor card (do not forget)

| Topic | Raw Quad Stable | SE Weighted Buffer | SE Orbital Buffer | **This package** |
|-------|-----------------|--------------------|-------------------|------------------|
| Assets | 4 raw | \(n\in[2,8]\); ≥1 SE | 3 legs; 0–3 SE | **4; ≥1 SE** |
| AMM | StableSwap on rate-scaled raw | Weighted: rated swaps / inventory LP | Sphere on effective | **StableSwap: rated swaps / inventory LP** |
| V4 doors | 6 | \(\binom{n}{2}\) | 3 | **6** |
| Inventory SoT | Repo raw | face \| live SE shares | raw and/or SE | **live face \| live SE shares** |
| Free pair on SE leg | N/A | Not book — dust ≤10 | Not book | **Not book — dust ≤ 10 refund** |
| Rate provider | Optional any token | Optional SE only; swaps only | Optional SE legs | **Optional SE only; swaps only** |
| One-token entry | Multi-leg zap-in | Single-asset join alias | Multi-leg zap-in | **Single-asset join alias only** |
| One-token exit | Peer zap | Single-asset exit aliases | No zap-out | **Single-asset exit aliases** |
| SE In/Out | No | Yes + MultiAssetLiquidity | Yes | **Yes + full MultiAssetLiquidity** |
| Unsupported MAL | N/A | Peer | N/A | **`InvalidRoute`** |
| Deploy | CREATE3 / factory refactor | Hook diamond | Hook diamond | **Hook diamond** |
| Pool fee key | Deploy pips | `DYNAMIC_FEE_FLAG` | `DYNAMIC_FEE_FLAG` | **`DYNAMIC_FEE_FLAG` only** |
| Swap fee | Fee-on-output pips | Input residual `dexSwapFee` | Input residual | **Input residual `dexSwapFee`** |
| Single-asset tax | N/A (zap) | `dexSwapFee` taxable | N/A | **`dexSwapFee` taxable** |
| Growth measure | Peer | Inventory \(V_{inv}\) | Effective sphere \(k\) | **Inventory product / geo measure (I1 freeze)** |
| LP prefix | Peer | `SEWGT` | `SEORB-` | **`SEQS`** |
| PRODUCT_ID | monomorph | weighted full name | orbital full name | **`UniswapV4StandardExchangeCurveQuadStableBufferHook`** |
| Zero-witness | Allowed product-wise | Partial book modes | Peer | **Defensive solver only** |
| Zero SE | Yes (product itself) | Forbidden | Allowed | **Forbidden — use raw Quad** |

---

## 4. Normative helpers (implement early)

### 4.1 Dual scale + native / rated domains (PRD §4.3 / D21–D23a)

```text
// TWO maps — never one conflated baseScale[i]
// invScale[i]   = 10^(36 - invDecimals[i])
//   raw:  invDecimals = pair-token.decimals()
//   SE:   invDecimals = IERC20(SE).decimals()     // SHARE token
// ratedScale[i] = 10^(36 - pairDecimals[i])
//   always pair-token.decimals() for leg i
// Fail if decimals ∉ [6,18] or decimals() reverts

// --- NATIVE inventory (LP, kLast, floors, reserveOfToken) — LIVE BOOK ---
for i in 0..3:
  if SE[i] == 0:
      native[i] = token_i.balanceOf(hook)              // LIVE; donations dilute
  else:
      native_shares[i] = IERC20(SE[i]).balanceOf(hook) // LIVE; donations dilute
      claim[i] = previewExchangeIn(SE, seBal, token)   // views / unwrap sizing only

invWad[i] = floor(native_amount_i * invScale[i] / 1e18)
// first mint: shares = geometricMean4(invWad) - MINIMUM_LIQUIDITY
// kLast: inventory-domain product/geo measure of four invWad (I1 freezes exact root)

// --- RATED (swaps + SE swap paths only) ---
for i in 0..3:
  if SE[i] == 0:
      pairUnits = token_i.balanceOf(hook)              // live face
  else if RP[i] != 0:
      rate = getRate()                                 // fail-closed; pair-token per share
      pairUnits = native_shares[i] * rate / 1e18
  else:
      pairUnits = claim[i]                             // SE claim (pair-token units)
  rated[i] = floor(pairUnits * ratedScale[i] / 1e18)   // ALWAYS pair-token scale
// Free pair token on buffered legs is NOT inventory and NOT rated book
// Witness rated legs may be 0 for solver robustness only (Q7)
```

**Views (O1–O2):** `nativeReserve(i)`, `nativeReserves()`, `ratedBalance(i)`, `ratedBalances()`, `seClaim(i)`, `seBalance(i)`, `standardExchange(i)`, `rateProvider(i)`, `isBuffered(i)`, `baseAmp()`, `getCurrentAmp()`, `reserveOfToken(token)`.

**Never:** free pair `balanceOf(hook)` as book when buffered; multiply RP × claim; put claim/RP into LP algebra; scale rated pairUnits with share decimals.

### 4.2 Buffer-last sequencing (D29 / O6 / O10)

```text
1) Quote / size ALL amounts on PRE-BUFFER snapshot (inventory and/or rated as path requires)
2) Pull natives / execute non-buffer inventory moves (unwrap outs, raw credits)
3) Buffer SE legs LAST in BINDING INDEX ORDER for used amounts > 0
4) Re-read LIVE inventory; mint/burn LP / set kLast from POST-BUFFER inventory
// Forbidden: re-solve StableSwap mid-flight after buffer
```

### 4.3 Share / claim composition for swaps (D28 / D28a / D59a)

```text
// Buffered tokenIn (exact-in example)
// 1) Take FULL gross amountIn (pair token)
// 2) Map gross amountIn → SE shares via buffer preview (claim-in)
// 3) Map fee-net amountIn (gross * (1e18 - dexSwapFee) / 1e18 floor) → rated inflow
//    via rate (if RP) or claim delta (if no RP)
// 4) StableSwap getY on rated book with fee-net rated inflow
// 5) Map rated out → native out (descale + SE unwrap invert if buffered)
// 6) Buffer FULL gross amountIn last (inventory gets residual via gross shares)
// Exact-out: ceil gross-up of input fee; buffer that gross input; invert SE as needed

// If required SE exact-out / invert unsupported → FULL TX REVERT (D28a)
// Shared composition: V4 doors + SE In/Out (NO multi-leg internal rebalance paths)
// Post-swap: trade-leg native > 0 AND trade-leg rated > 0; post-state getD on rated converges (D33–D34)
// Witness rated legs may be 0 (defensive) — do not require all four rated > 0 for swap gates (D72)
```

### 4.4 StableSwap math (pure Math — pattern-copy raw-quad, adapt domains)

**Behavioral peer:** raw `UniswapV4CurveQuadStableSwapHookMath` classic Curve form (not StableSwapNG, not Balancer StableMath unless Phase 0 finds a superior closed-form single-asset peer).

```text
N_TOKENS = 4
AMP_PRECISION = 100
A' = baseAmp * AMP_PRECISION          // getCurrentAmp()
Ann = A' * N_TOKENS
MAX_NR_ITERS = 255
convergence: |Δ| ≤ 1 else revert

// Inputs x_i = ratedWad_i (swaps)
// getD(xp[4], A') → D
// getY(i, j, x_i_new, xp, A', D) → y_j_new
// Fee residual: INPUT residual via dexSwapFeeOfVault (NOT raw-quad fee-on-output pips)
```

Swap formula uses **all four** rated balances (trade legs + two witnesses). **Do not** drop witnesses from the invariant.

Trading fee: live `dexSwapFeeOfVault`; 0 OK; require `< 1e18`. Map WAD → pips + `OVERRIDE_FEE_FLAG` (informational; **no double-haircut**).

### 4.5 Inventory LP algebra (PRD §4.5 / D36–D49)

Work in **invWad** (face \| live shares). User edge always **pair tokens** + buffer-last / unwrap.

| Path | Law |
|------|-----|
| First mint | **All four > 0** after buffer preview. `shares = geometricMean4(invWad) − 1000`; MIN → `address(0)`; no protocol mint while `kLast==0`; post-state rated `getD` converges |
| Proportional join/exit | Classic min-ratio on inventory units; exit floors D48 |
| Single-asset exact-in | `joinSingleAssetExactIn` / alias `depositSingle`; full book only; taxable D41a |
| Single-asset exact-BPT-in exit | `exitSingleAssetExactBptIn` / alias `withdrawSingle`; taxable D41a |
| Single-asset exact-LP-out join | **Iff Phase 0 SHIP** else `InvalidRoute` |
| Single-asset exact-token-out exit | **Iff Phase 0 SHIP** else `InvalidRoute` |
| Unbalanced multi | **Iff Phase 0 SHIP** else `InvalidRoute` |
| Full-book exit floors | All **four** native reserves remain \(> 0\) (D48) |
| Recipients | Mint LP to `to`; refunds → `msg.sender`; burn `msg.sender` LP; pay tokens to `to` |

**First mint geo-mean (plan freeze — peer raw-quad Math):**

```text
// Pairwise sqrt to reduce overflow (raw-quad geometricMean4 peer)
// invWad amounts are POST-BUFFER inventory WAD (face or share units)
function geometricMean4(a,b,c,d):
  if any zero → 0 (first mint must revert zero path)
  ab = sqrt(a * b); cd = sqrt(c * d); return sqrt(ab * cd)
shares = geometricMean4(invWad) - MINIMUM_LIQUIDITY
require shares > 0
```

**Taxable single-asset × buffer-last (D41a / Weighted peer):**

```text
// Single-asset join preview & exec:
// 1) Protocol growth mint if fee-on (inventory kLast)
// 2) Snapshot LIVE invWad (pre-intake)
// 3) Map user pair-token amount → intended inventory delta via SE buffer preview
//    (share units for SE legs; face for raw) WITHOUT mutating book yet
// 4) Stable/Balancer single-asset join math on working inventory balances
//    taxable portion fee = dexSwapFeeOfVault (mulUp peer Weighted Math)
// 5) Pull pair tokens; buffer-last if SE; credit raw faces
// 6) Mint LP to `to`; set kLast from post LIVE invWad; refund free SE-leg pair dust
// Previews must use the same map order and fee oracle / SE preview reads
```

**Stable single-asset formula source (Phase 0 / Phase B pin):** prefer Balancer StablePool / StableMath single-token join/exit closed forms if they admit bit-exact inventory-domain application; else derive from StableSwap invariant with documented rounding. **Never** binary-search.

### 4.6 Protocol growth (D61–D65 / D24 / I1)

```text
feeWad = usageFeeOfVault(this)   // NOT dexSwapFee
ownerFeeShare = feeWad * 100_000 / 1e18
feeOn = feeTo != 0 && feeWad != 0 && feeWad < 1e18 && ownerFeeShare != 0

// Full book only for growth (D63):
// Plan freezes I1 bit-exact form. Default freeze candidate (implementor may pick one and lock in revision log):
//   k = geometricMean4(invWad0..3)   // same geoMean as first mint domain
//   OR k = product of four invWad with 4th-root for rootK comparison
// Uni V2-style protocol mint: mint to feeTo from pre-intake growth of k
// Timing: mint from pre-intake k on add; mint before user burn on remove
// Swaps: no protocol mint; no kLast update
// LP previews simulate dilution when fee-on
// SE yield that only changes claim (not share balance) does NOT move k
// v1 does not mint growth from partial-book modes (operational paths avoid partial book)
```

**I1 freeze rule:** choose **one** form in Phase B; document in revision log with numeric fixture; do not change without plan stamp.

### 4.7 SE I/O + MultiAssetLiquidity (D30, D53–D58, Q8)

| Path | Call |
|------|------|
| Buffer token → SE | `exchangeIn(token → SE)`; minOut = tight fee-inclusive preview |
| Unwrap SE → token | `exchangeIn(SE → token)` or `exchangeOut` when exact-out required; else **full revert** (D28a) |
| SE In/Out swaps | Canonical In/Out; rated StableSwap book; internal settle; **never** mint/burn LP |
| MultiAssetLiquidity | Thin facade → same Target as hook liquidity; **full shared interface** |

**Unsupported selectors (D57b):**

```text
// Always present on diamond:
joinUnbalanced, joinSingleAssetExactOut, exitSingleAssetExactTokenOut,
withdrawSingleExactOut, matching preview*
// Behavior if Phase 0 OMIT: revert InvalidRoute() on exec AND preview
// Behavior if Phase 0 SHIP: bit-exact preview == execution
```

**SE In/Out funding (D55):** if `!pretransferred`: transferFrom if allowance else Permit2 AllowanceTransfer.  
**LP funding (D47):** same pull law; **no** SignatureTransfer / no `permit2Data` on join ABI.

### 4.8 Hook permissions (D74)

```text
BEFORE_INITIALIZE
| BEFORE_ADD_LIQUIDITY
| BEFORE_REMOVE_LIQUIDITY
| BEFORE_SWAP
| BEFORE_SWAP_RETURNS_DELTA
| BEFORE_DONATE
```

Mask against `Hooks.ALL_HOOK_MASK` in factory (I4). CL add/remove and donate always revert. `beforeInitialize`: factory-door rules only (D68).

### 4.9 Events (PRD §6)

| Event | Normative fields |
|-------|------------------|
| Join / Exit (MultiAsset same) | `sender`, `to`, `shares`, `int256[4] deltas` (binding order, pair-token edge), `protocolSharesMinted` |
| `DepositSingle` | `sender`, `to`, `token`, `amountIn`, `shares`, `protocolSharesMinted` |
| `WithdrawSingle` | `sender`, `to`, `token`, `amountOut`, `shares`, `protocolSharesMinted` |
| `WithdrawSingleExactOut` | iff Phase 0 SHIP |
| `ProtocolFeeMinted` | `feeTo`, `shares` |
| `EnsurePairPools` / PairPoolsEnsured | `hook`, `doorsEnsured` |
| HookDeployed | package/factory peer |

**No** product-level `Swap` event (V4 / PoolManager logs suffice).

### 4.10 Algorithm pointers (PRD sections)

| Path | PRD |
|------|-----|
| Dual scale / native vs rated | §4.3, D21–D23a |
| StableSwap swaps + gross buffer | §4.4, D59a |
| LP first mint / prop / single-asset | §4.5, D41a, Q9 |
| SE surfaces | §4.6, Q8 |
| Fees | D59–D65, D59b |
| Deploy | §5 |
| Events / security / DoD | §6–§8 |
| Plan-only opens | §9 I1–I7 |

---

## 5. Implementation phases

### Phase 0 — Closed-form audit + ERC-4626 wrapper SE **[plan + TestBase]**

#### 0a. Closed-form single-asset / unbalanced audit (I2 / I3 / D41 / D42a)

1. Audit **raw-quad Math**, Crane vendored **StableMath** / Balancer StablePool peers, and Weighted single-asset peers for closed-form:
   - single-asset **exact-LP-out join** (`joinSingleAssetExactOut`)  
   - single-asset **exact-token-out exit** (`exitSingleAssetExactTokenOut` / `withdrawSingleExactOut`)  
   - **unbalanced multi-asset** join (and exit if peer has it)  
2. Record outcome in this plan’s revision log:  
   - **SHIP:** function names + rounding notes + bit-exact preview requirement  
   - **OMIT:** keep selectors; **`InvalidRoute`** on exec + preview; omit from behavioral DoD suites (except InvalidRoute suite)  
3. Required v1 regardless of audit: `joinProportional`, `exitProportional`, `joinSingleAssetExactIn` / `depositSingle`, `exitSingleAssetExactBptIn` / `withdrawSingle`.  
4. **Never** binary-search.

**Exit 0a:** Written SHIP/OMIT table for exact-LP-out join, exact-token-out exit, unbalanced multi.

#### 0b. ERC-4626 wrapper SE thin gate

1. Confirm production ERC-4626 wrapper SE deploys via manager/registry path.  
2. Confirm closed-form **token ↔ SE** buffer and unwrap (exact-in + exact-out as needed) with **preview == execution**.  
3. Confirm ability to deploy **multiple distinct** wrapper SEs for 1–4 SE matrix rows.  
4. Confirm rate provider peer (production SE rate provider package or static `IRateProvider` implementing real interface) for RP rows — **not** a mock of the hook SUT.

**Exit 0b:** Package-adjacent TestBase can deploy 1–4 real wrapper SEs + mintable tokens + optional RP; buffer/unwrap both directions with preview fidelity.

---

### Phase A — Package skeleton + diamond deploy path

1. Create §2 file map (interfaces, Repo, empty Targets/Facets, DFPkg, FactoryService).  
2. **Interface:** PRD product surface + In/Out + MultiAssetLiquidity (import shared) + vault discovery; `PkgInit` / `PkgArgs` **on interface** (Crane rule).  
3. **PkgArgs binding (normative):**  
   `(tokens[4], standardExchanges[4], rateProviders[4], baseAmp)`  
   PM + feeOracle from factory immutables. Permit2 **not** in args. `mineNonce` at deploy call.  
4. **Validation (init / processArgs):**  
   - tokens non-zero, pairwise distinct, strict address ascending; decimals [6,18]  
   - ≥1 SE; SE zero **or** `token_i ∈ SE.vaultTokens()`, `token_i != SE`; non-zero SEs pairwise distinct  
   - RP non-zero **only if** SE non-zero  
   - `0 < baseAmp < MAX_AMP`  
5. **DFPkg:**  
   - `PRODUCT_ID = "UniswapV4StandardExchangeCurveQuadStableBufferHook"`  
   - `requiredHookFlags()` = §4.8 mask  
   - `packageSalt` = PRODUCT_ID + binding fields (**tokens, SEs, RPs, baseAmp**) + factory-scope identity — **no** package/facet addresses; **no** PM/oracle in salt if factory-immutable (D73)  
   - `deployVault(args, mineNonce)` → `registry.deployHookVault`  
   - **`postDeploy`:** initialize **all six** pair doors (address-sorted currencies, `DYNAMIC_FEE_FLAG`, `TICK_SPACING=1`, `sqrtPriceX96` at tick 0)  
   - `ensurePairPools(hook)` path (permissionless repair)  
   - `diamondConfig` **without** live `diamondCut`  
   - Cut shared ERC20Permit + MultiAsset vault facets + product facets  
6. **initAccount:** ERC20Repo + EIP712Repo + product Repo binding + LP name/symbol `SEQS-…` (D46 caps + address-fragment fallback).  
7. **FactoryService:** CREATE3 facets; `deploy*DFPkg` via manager; mine helpers for flags.  
8. Hook callback stubs; reentrancy lock in Repo; disabled CL + donate reverts.  

**Exit:** `forge build` green; TestBase deploys package via registry + hook factory; all six doors initialized; flags correct; binding views return args; `totalSupply == 0`.

---

### Phase B — Math + ClaimLib (dual scale / StableSwap / composition)

1. Pure `…Math.sol`:  
   - `invScale` / `ratedScale` / `toInvWad` / `toRatedWad` / descale helpers  
   - StableSwap `getD` / `getY` (n=4) + exact-in/out quote helpers with **input residual** fee (not fee-on-output pips)  
   - `geometricMean4` for first mint  
   - growth protocol LP algebra (I1 freeze)  
   - join/exit helpers on inventory domain (proportional + single-asset exact-in/out per Phase 0)  
   - optional pure-Math zero-witness vectors (I7)  
   - **no** SE/RP external calls; **no** multi-leg rebalance split  
2. `…ClaimLib.sol`:  
   - live SE balance read  
   - claim preview  
   - buffer claim-in / unwrap claim-out  
   - invert helpers; **revert whole op** on missing exact-out (D28a)  
   - fail-closed RP `getRate`  
3. Common Target helpers: decimals cache, index maps, pair door key builders, fee oracle reads.  
4. Wire `nativeReserve*` / `ratedBalance*` / `seClaim` / `seBalance` / `reserveOfToken` views (live book).  

**Exit:** Views compile; dual-scale unit vectors exercised via hook views/previews; smoke zero book; I1 form stamped in revision log.

**Required numeric fixtures (document in Math tests or Preview suite):**

| FIX | Intent |
|-----|--------|
| FIX-SCALE-6-18 | Raw USDC-like 6d + SE share 18d inventory geo-mean first mint |
| FIX-RATED-RP | SE leg with RP: rated uses pair-token scale of `seBal×rate`, not share decimals |
| FIX-RATED-CLAIM | SE leg no RP: rated from claim; LP invWad from share balance unchanged when claim moves alone |
| FIX-DONATE-SE | Extra SE shares to hook dilute subsequent join share mint |
| FIX-GEOMEAN | Four-leg inventory geo-mean − MIN bit-exact vs preview |
| FIX-WITNESS-0 | Pure Math: getD/getY with one/two witness rated = 0 still converges or reverts consistently (defensive) |

---

### Phase C — Full-book LP (join / exit) — no swap / no one-token yet

1. Global nonReentrant on liquidity mutators.  
2. First mint all four: buffer-last; `shares = geoMean4(invWad) − MIN`.  
3. Proportional join/exit; exit floors D48; dust refund on buffered free pair.  
4. Protocol growth mint timing on add/remove; previews simulate dilution.  
5. Pull: transferFrom if allowance else Permit2 AllowanceTransfer (D47).  
6. Events §6.  
7. Reject multi-asset LP when any native leg is zero (defensive).  

**Exit:** Hermetic first mint + prop join/exit; preview==exec; growth path smoke; dead MIN to `address(0)`.

---

### Phase D — One-token aliases (`depositSingle` / `withdrawSingle`)

1. `depositSingle` ≡ `joinSingleAssetExactIn` (full book only); taxable = `dexSwapFeeOfVault`.  
2. `withdrawSingle` ≡ `exitSingleAssetExactBptIn`; taxable portion same channel.  
3. Wire Phase 0 SHIP exact-out / exact-LP-out if any; else stubs → `InvalidRoute`.  
4. No multi-leg rebalance paths anywhere.  

**Exit:** Single-asset suite green; tax residual in inventory; MultiAssetLiquidity aliases match hook (thin facade may complete in Phase F).

---

### Phase E — V4 swaps (all six doors) + dynamic fee

1. `beforeSwap` / `beforeSwapReturnDelta` pattern-copy settle.  
2. Rated book composition + fee-net curve + gross buffer (D59a).  
3. Exact-in and exact-out both directions per directed pair; post floors D33; post-state priceability D34.  
4. Fee override pips; no double-haircut.  
5. RP fail-closed on rated paths.  
6. Trade-leg native+rated > 0; witnesses may be zero in solver only.  

**Exit:** Swap suite covers all six doors (12 directed pairs); ±RP configs; gross buffer inventory check.

---

### Phase F — SE In/Out + MultiAssetLiquidity facade

1. Canonical `exchangeIn` / `exchangeOut` (and previews) — swap-only, internal settle, rated StableSwap book.  
2. Funding D55; reject SE share addresses / unbound tokens / same in-out.  
3. `IStandardExchangeMultiAssetLiquidity` thin facade: **full shared interface**; required paths bit-exact; unsupported → **`InvalidRoute`**.  
4. Shared Target implementation — no duplicated math.  
5. InvalidRoute suite for OMIT paths.  

**Exit:** SeExchange + MultiAssetLiq + InvalidRoute suites green.

---

### Phase G — Fees hardening + vault discovery + ensurePairPools

1. Dual-channel fee matrix (trading residual + single-asset tax stay in inventory; growth mint to live `feeTo`).  
2. Vault views: `vaultTokens`, `reserveOfToken` = shares on SE legs, etc.  
3. `ensurePairPools` idempotent; event fields.  
4. LP metadata caps / fallback.  

**Exit:** Fees + VaultViews + EnsureDoors green.

---

### Phase H — Hermetic matrix complete (SE 1–4 + RP)

1. Config rows (D78):  
   - (a) **1 SE** + three raw  
   - (b) **2 SE**  
   - (c) **3 SE**  
   - (d) **4 SE** all buffered  
   - (e) RP zero/non-zero on ≥1 buffered config  
2. Amp bounds; zero-SE / non-distinct SE / RP-without-SE reject.  
3. Preview bit-exact suite across paths.  
4. Adversarial O11: reentrancy (LP↔swap↔SE), donation dilution (raw + SE shares), `feeTo` non-receivable, SE revert mid-buffer, RP fail-closed, full-book zero-leg exit, distinct-SE / zero-SE rejects, amp bounds, unsupported MultiAssetLiquidity → `InvalidRoute`.  

**Exit:** All hermetic DoD rows green under production-first rules. **Not required:** construct native partial-book product states.

---

### Phase I — Forks (D79)

1. Ethereum mainnet fork  
2. Base mainnet fork  
3. Robinhood 4663 fork  

Each: production PM/Permit2/fee oracle when present; deploy-if-missing production-equivalent stack; mintable tokens + wrapper SE OK; smoke deploy + six doors + first mint + swap + single-asset join.

**Exit:** Three fork suites green, equal priority.

---

### Phase J — Polish

1. NatSpec + Crane code-style; no `console.log` in production sources.  
2. Size check (`forge build --sizes`); split facets/libs if needed without dropping surface.  
3. Update this plan revision log with Phase 0 SHIP/OMIT final stamp, I1 `kLast` form, and any bit-exact pins.  
4. Confirm PRD §8 checklist can be checked.  

**Exit:** Package ready for review / merge.

---

## 6. Locked constants (implementor card)

| Constant | Value |
|----------|--------|
| `N_TOKENS` | `4` |
| `AMP_PRECISION` | `100` |
| `MAX_AMP` | `1_000_000` |
| `baseAmp` bounds | `0 < baseAmp < MAX_AMP` |
| Newton max iters | `255` |
| Newton convergence | `\|Δ\| ≤ 1` |
| `MINIMUM_LIQUIDITY` | `1000` → `address(0)` |
| `MAX_DUST_WEI` | `10` |
| `TICK_SPACING` | `1` |
| Pool fee key | `DYNAMIC_FEE_FLAG` only |
| Pair doors | `6` |
| LP decimals | `18` |
| LP symbol prefix | `SEQS` |
| Symbol / name caps | 32 / 64 |
| `PRODUCT_ID` | `"UniswapV4StandardExchangeCurveQuadStableBufferHook"` |
| Permit2 | `0x000000000022D473030F116dDEE9F6B43aC78BA3` |
| Fee denominator (growth) | `100_000` |
| Decimals band | `[6, 18]` |
| Unsupported liquidity error | `InvalidRoute` |

---

## 7. Deploy architecture (normative)

### 7.1 Path

```text
1. Owner/operator: setHookDiamondPackageFactory(hookFactory) once
2. registry.deployPkg(hookPkg initCode, pkgInit, salt)   // CREATE3 package
3. Off-chain mine mineNonce so CREATE2 address has requiredHookFlags
4. HookPackage.deployVault(pkgArgs, mineNonce)
     → registry.deployHookVault(pkg, abi.encode(args), mineNonce)
       → hookFactory.deployWithMineNonce(...)
       → postDeploy: init all 6 doors + register vault
5. Permissionless ensurePairPools(hook) repairs missing doors only
```

### 7.2 Salt law (D73)

```text
packageSalt = hash(PRODUCT_ID, tokens[4], standardExchanges[4], rateProviders[4], baseAmp
                   [, factory-scope identity per factory PRD])
// NO package address, facet addresses, or (if factory-immutable) PM/oracle
finalSalt = keccak256(abi.encode(packageSalt, mineNonce))
```

### 7.3 postDeploy pool keys

For every unordered pair \((i,j)\) with \(i < j\) in binding order:

```text
currency0 = min(tokens[i], tokens[j])  // address sort
currency1 = max(tokens[i], tokens[j])
fee = DYNAMIC_FEE_FLAG
tickSpacing = 1
hooks = this
sqrtPriceX96 = TickMath.getSqrtPriceAtTick(0)  // plumbing only
```

### 7.4 FactoryService sketch

Peer SE Weighted / Orbital FactoryService:

- `deploy*Facet` via `create3Factory`  
- `deploy*DFPkg` via `indexedexManager` (owner/operator)  
- Off-chain mine helpers for required flags  
- Typed deploy helpers for tests  

---

## 8. Testing plan

### 8.1 Rules

1. **No mocks of SUT** — hook diamond, facets, DFPkg, manager, registry, fee oracle, bound SE vaults, PoolManager.  
2. Real Uni V4 PoolManager (Crane port / hermetic).  
3. Real Vault Fee Oracle with **defaults** set (dex swap fee + usage fee + feeTo).  
4. Real SE legs (ERC-4626 Wrapper SE and/or production ports).  
5. Package-adjacent TestBase: `CraneTest` → `IndexedexTest` → vault components → hook factory registry path → this package.  
6. Mintable ERC-20 + reentrancy hostile ERC-20 **only** as non-SUT harnesses where needed.  
7. Prefer full production deploy path for every suite.  
8. Zero-witness product construction is **not** a required integration row (Q7); optional pure-Math suite only.

### 8.2 Hermetic DoD matrix

| ID | Case | Required |
|----|------|----------|
| H1 | Deploy inert; ≥1 SE; all six doors; flags | Yes |
| H2 | Zero-SE / non-distinct SE / RP-without-SE / bad amp / bad decimals / non-ascending tokens reject | Yes |
| H3 | First mint inventory geoMean − MIN; dead MIN; all four legs | Yes |
| H4 | Proportional join/exit; full-book exit floors | Yes |
| H5 | `depositSingle` / `withdrawSingle`; taxable = `dexSwapFee`; no multi-leg rebalance | Yes |
| H6 | Phase-0-omitted selectors → `InvalidRoute` (exec + preview) | Yes |
| H7 | Swaps rated ±RP; gross buffer; exact-in/out; all six doors | Yes |
| H8 | SE In/Out swap-only; preview==exec | Yes |
| H9 | Full MultiAssetLiquidity cut + shared Target behavior | Yes |
| H10 | `reserveOfToken` = live SE shares; claim/rated separate | Yes |
| H11 | Protocol growth mint + preview dilution | Yes |
| H12 | Rate fail-closed | Yes |
| H13 | `ensurePairPools` | Yes |
| H14 | Dual scale fixtures (FIX-*) | Yes |
| H15 | Donation dilution SE shares | Yes |
| H16 | SE matrix 1/2/3/4 + mixed decimals 6/18 | Yes |
| H17 | Adversarial O11 | Yes |
| H18 | Optional pure-Math zero-witness (I7) | Optional |
| H19 | Exact-out / unbalanced behavioral suites | Only if Phase 0 SHIP |

### 8.3 Fork DoD (equal priority)

| ID | Network | Smoke |
|----|---------|-------|
| F1 | Ethereum mainnet | Deploy + 6 doors + first mint + swap + single-asset |
| F2 | Base mainnet | Same |
| F3 | Robinhood 4663 | Same |

### 8.4 Preview fidelity

Every shipped mutator has a matching `preview*` with **bit-exact** equality at the same block (same fee oracle, SE preview, and rate reads). Unsupported MultiAssetLiquidity previews **revert `InvalidRoute`** — do not return optimistic amounts.

---

## 9. Definition of Done (package)

Mirror PRD §8. Package is **done** when:

- [x] Files under `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/` (facets, Repo, Target, Math, DFPkg, FactoryService, interfaces, TestBase).  
- [x] Deploy path: facets CREATE3; instance via `deployHookVault` + shared hook factory; **all six** doors in postDeploy; `ensurePairPools`.  
- [x] Binding: four ascending tokens; ≥1 SE; distinct SEs; RP only on SE legs; immutable `baseAmp`.  
- [x] First mint: all four legs; inventory geo-mean − MIN; buffer-last.  
- [x] Proportional join/exit inventory domain; single-asset aliases (no multi-leg zap); single-asset taxable = **`dexSwapFeeOfVault`**.  
- [x] Swaps: rated StableSwap + witnesses; live dual-channel fees; gross buffer; post-state priceable; solver tolerates zero-rated witnesses (**defensive only**).  
- [x] SE In/Out + **full** MultiAssetLiquidity cut; shipped paths preview == execution; unsupported → **`InvalidRoute`**.  
- [x] `reserveOfToken` = live face \| live SE shares; `ratedBalance` / `seClaim` separate.  
- [x] Protocol growth on LP paths; `PRODUCT_ID` full type name; LP prefix `SEQS`.  
- [x] Hermetic matrix D78 / §8.2; forks Ethereum + Base + 4663 (hermetic ForkSmoke + fork-tree paths; peer pattern).  
- [x] Adversarial O11 green.  
- [x] Phase 0 SHIP/OMIT stamped; I1 `kLast` form stamped.  
- [x] **No** DETF / mock SUT in DoD.

---

## 10. Risk register (implementor awareness)

| Risk | Mitigation |
|------|------------|
| Stack-too-deep on 4-leg + SE composition | Struct packing in Math/Target; split facets; Crane code-style |
| SE invert missing on exact-out paths | D28a full tx revert; test SE wrappers that support both directions |
| Confusing invScale vs ratedScale | Dedicated FIX-SCALE / FIX-RATED tests; NatSpec on every scale helper |
| Growth formula ambiguity (I1) | Freeze one form in Phase B revision log before growth tests |
| Phase 0 closed-form absence | Keep ABI; `InvalidRoute`; do not binary-search |
| Size limits on CREATE2 hook | Split Math/ClaimLib/Targets; measure with `forge build --sizes` early |
| Accidental multi-leg zap reintroduction | Code review gate: no “zap split” helpers; single-asset only |
| Treating zero-witness as product path | Q7: no integration matrix row; Math unit only |

---

## 11. Suggested work order (one-liner)

```text
Phase 0 audit+SE gate → A skeleton/deploy → B Math/ClaimLib → C prop LP
→ D single-asset → E V4 swaps → F SE In/Out + MultiAssetLiquidity
→ G fees/views/doors → H hermetic matrix + adversarial → I forks → J polish
```

---

## 12. Revision log

| Version | Date | Notes |
|---------|------|-------|
| **v1.0** | 2026-08-07 | Initial implementor plan aligned to PRD **LOCKED v0.2**. Dual domains, StableSwap rated swaps, inventory LP, Q7–Q9 pins, full MultiAssetLiquidity + `InvalidRoute`, Phase 0 SHIP/OMIT, SE matrix 1–4, forks ETH/Base/4663. I1 `kLast` form and Phase 0 SHIP/OMIT pending Phase B/0 stamps. |
| **v1.1** | 2026-08-07 | Phase 0 **OMIT** exact-out join / exact-token-out exit / unbalanced (selectors + `InvalidRoute`). I1 **FROZEN** `kLast = geometricMean4(invWad)`. I4 flags frozen. Greenfield package implementation landed under `stable/quad/`. |
| **v1.2** | 2026-08-07 | D21 live raw face for LP dilution; free-pretransfer gate uses intentional `rawReserves` (free = bal − book raw; full face SE); unfunded pretransfer reverts; adversarial pretransfer suite. |

### Phase 0 / I1 stamp table (fill during implementation)

| Item | Status | Notes |
|------|--------|-------|
| `joinSingleAssetExactOut` | **OMIT** | Selectors present; exec + preview → `InvalidRoute`. No closed-form bit-exact peer adopted for dual-scale inventory SE buffer in Phase 0 (raw-quad peer also OMITs). |
| `exitSingleAssetExactTokenOut` / `withdrawSingleExactOut` | **OMIT** | Same as above — `InvalidRoute` on exec + preview. |
| `joinUnbalanced` | **OMIT** | Same as above — `InvalidRoute` on exec + preview. |
| I1 `kLast` root form | **FROZEN** | `k = geometricMean4(invWad0..3)` — same geoMean as first-mint domain (`Math.rootK` / `Math.geometricMean4`). Uni V2-style `protocolLpShares` on inventory k growth. |
| I4 exact flag mask | **FROZEN** | `BEFORE_INITIALIZE \| BEFORE_ADD_LIQUIDITY \| BEFORE_REMOVE_LIQUIDITY \| BEFORE_SWAP \| BEFORE_SWAP_RETURNS_DELTA \| BEFORE_DONATE` (masked by factory to `Hooks.ALL_HOOK_MASK`). |
| Free-pretransfer gate | **FROZEN** | Raw free = `balanceOf − rawReserves` (intentional book only); SE free = full face `balanceOf`; unfunded `pretransferred=true` → `InsufficientPretransfer`. |

---

## 13. Acceptance for plan stamp

This plan is the **implementor SoT** for phases and tests once accepted. Product law remains PRD LOCKED v0.2. Plan patches for bit-exact freezes (I1, Phase 0) do **not** require a PRD revision unless they change product law (ship a previously forbidden path, drop a required path, change fee channel, etc.).
