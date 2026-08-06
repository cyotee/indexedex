# Implementation & Test Plan: Uniswap V4 Standard Exchange Weighted Buffer Hook

**PRD (product law SoT):** [`UNISWAP_V4_STANDARD_EXCHANGE_WEIGHTED_BUFFER_HOOK_PRD.md`](./UNISWAP_V4_STANDARD_EXCHANGE_WEIGHTED_BUFFER_HOOK_PRD.md) (**Draft v0.6 — product law, plan-ready**)  
**This plan (implementor SoT once accepted):** greenfield package under `standardExchange/weighted/` — **no** existing scaffold.  
**Package:** `contracts/hooks/uniswap/v4/standardExchange/weighted/`  
**Date:** 2026-08-05  
**Status:** **Canonical plan — aligned to PRD v0.6**. Ready for implementor stamp, then code. **No production code in this doc-only pass.**

**Authority**

| Layer | Role |
|-------|------|
| **PRD v0.6** | Product law (D1–D78, D42b, O1–O12, P1–P6, Q7–Q28, §0–§11). **PRD wins** on conflict |
| **This plan** | Implementor SoT for phases, file map, helpers, dual-scale algebra, tests, deploy wiring, Phase 0 D42a audit |
| Raw Weighted monomorph | Curve / doors / partial book / join-exit / dual-channel fees **behavioral** reference only — **do not subclass**; **do not** copy monomorph CREATE3 factory law |
| Dual SE Buffer CP | Buffer / unwrap / claim-in / buffer-last **process** reference — adapt 2-leg CP → **n-leg weighted** |
| SE Orbital Buffer | Multi-leg optional SE slots / diamond package / SE funding / vault discovery **shape** reference — curve is **weighted**, not sphere; this product **requires ≥1 SE** |
| Hook diamond factory | Deploy / salt / flags / immutability — factory PRD + `indexedex-uniswap-v4-hook-packages` skill |
| Crane WeightedMath / BasePoolMath | Math peers only (wrap; do not re-derive) |

**Read order for implementors**

1. PRD §0 terminology (**native vs rated**, **dual scale Q25**, **live book Q26**, buffer-last) + §1.1 user story  
2. PRD §2.4 allowed divergence + §3 locked tables (esp. D20–D50, D42a/b, Q19–Q28)  
3. PRD §4.3 dual domains, §4.4–§4.9 swaps / LP / partial / settle  
4. PRD §5 surface (D55a names), §6 deploy, §7–§8 testing + DoD  
5. **This plan** §1–§11 (scope, files, helpers, phases, tests)  
6. Skill `indexedex-uniswap-v4-hook-packages` for registry → hook factory path  

**Process rule:** If this plan and PRD disagree, **PRD wins** and this plan must be patched. Do not reopen PRD-locked decisions without a PRD revision. After each phase: `forge build` green and that phase’s tests green before the next.

**Conversation locks (v0.2–v0.6) — implementor card**

| Lock | Value |
|------|--------|
| Product name | `UniswapV4StandardExchangeWeightedBufferHook` (D1) |
| Deploy | **Hook diamond package only** — registry `deployHookVault` + shared hook factory CREATE2 mine (D69). **Not** monomorph CREATE3 product factory |
| \(n\) | **2–8** fixed at deploy; hermetic **must** cover \(\{2,3,4,8\}\) (Q17) |
| SEs | Optional per leg; **≥1 required**; non-zero SEs **pairwise distinct** (D7a–D7b) |
| Rate providers | Optional **only** on SE legs; **swap valuation only**; fail-closed (D8, D22, O5) |
| LP domain | **Inventory only** — face \| **live** SE shares; **no** claim/RP in join/exit/`kLast` (Q7, Q26) |
| Swap domain | **Rated** balances: face / `seBal×rate` / claim → **pair-token** scale (Q25) |
| Dual scale | `invScale` (face \| share decimals) ≠ `ratedScale` (always pair-token decimals) (Q25) |
| Live book | Buffered leg = `IERC20(SE).balanceOf(hook)`; donations dilute (Q26) |
| One-token | Balancer **single-asset only**; aliases `depositSingle`/`withdrawSingle`; **no** multi-leg rebalance (Q8, Q28) |
| Join exact-BPT-out | **`joinSingleAssetExactOut` required** (Q27 / D42b / Weighted peer) |
| Exit exact-token-out | Phase 0: ship **only if** Crane closed-form (D42a / Q21); else **omit from v1** |
| Fees | Dual-channel: `dexSwapFeeOfVault` trading residual; `usageFeeOfVault` growth mint (D57–D62) |
| Swap buffer | Buffer **full gross** amountIn; curve uses fee-net (Q16 / D57a) |
| LP pull | `transferFrom` if allowance else Permit2 **AllowanceTransfer only** — no SignatureTransfer / no `permit2Data` (Q24) |
| MultiAssetLiquidity | **New** `IStandardExchangeMultiAssetLiquidity` = hook liquidity ABI **1:1** (Q19) |
| PM + feeOracle | **Factory immutables only** (Q11) |
| Doors | postDeploy all \(\binom{n}{2}\) + permissionless `ensurePairPools` (Q15) |
| PRODUCT_ID | `"UniswapV4StandardExchangeWeightedBufferHook"` (Q13) |
| LP symbol prefix | **`SEWGT`** (Q14); symbol ≤32, name ≤64 |
| Forks | **Ethereum + Base + Robinhood (4663)** all required, equal priority (Q18) |
| Test SE | Production ERC-4626 **wrapper** SE(s) + mintable tokens; matrix 1 SE / all SE / mixed + RP on/off |
| Integration tests | Prefer full production stack; no mock SUT hook / SE / manager / registry / factory / fee oracle / PM |

---

## 0. Starting state

| Item | Status |
|------|--------|
| PRD v0.6 | Present at package path |
| Hook / DFPkg / FactoryService / interface Solidity | **None** — greenfield |
| Tests / TestBase | **None** (TestBase will be package-adjacent) |
| Raw Weighted monomorph | Peer under `…/hooks/uniswap/v4/weighted/` — curve/LP/partial **behavioral** reference only |
| SE Orbital Buffer diamond | Peer under `…/standardExchange/orbital/` — gold **deploy shape** + multi-SE process |
| Dual SE BCP | Peer under `…/standardExchange/dual/` — buffer-last / claim helpers pattern |
| Hook diamond factory | Present under `contracts/hooks/uniswap/v4/factory/` — **required** production path |
| ERC-4626 wrapper SE | Exists at `contracts/vaults/standard/erc4626/` — Phase 0 verify/deploy |
| `IStandardExchangeMultiAssetLiquidity` | **Does not exist yet** — author under `contracts/interfaces/` (or co-located package interfaces) in Phase A |

**Do not** start by forking monomorph weighted sources into this package:

| Raw Weighted monomorph | This package |
|------------------------|--------------|
| Raw ERC-20 inventory only | Raw **and/or** live SE shares per leg; **≥1 SE** |
| Optional RP on **any** leg scales **all** algebra | RP **SE legs only**, **swaps only**; LP on inventory |
| CREATE3 monomorph factory | Hook diamond + registry `deployHookVault` |
| No SE In/Out product surface | SE In/Out **+** MultiAssetLiquidity **required** |
| Single contract wire | Facets + Targets + Repo; cut shared ERC20/vault facets |

**Do not** subclass Dual/Orbital/Single SE BCP types either — fresh codepath; pure libs OK.

---

## 1. Scope (v1 DoD)

Implement production-first package **`UniswapV4StandardExchangeWeightedBufferHook`**:

1. Bind **\(n \in [2,8]\)** ERC-20s + weights + optional `standardExchange[n]` + optional `rateProvider[n]`; `poolManager` + `feeOracle` from **factory immutables**. Permit2 = Uniswap well-known constant (not binding arg).  
2. **≥1** non-zero SE; non-zero SEs pairwise distinct; RP only where SE set; tokens address-ascending, decimals [6,18].  
3. Per leg: raw face inventory **or** live SE shares as book. Pool currencies = the \(n\) tokens only — **never** SE share addresses.  
4. **Balancer WeightedMath** on **rated** balances for swaps; **inventory-domain** WeightedMath / BasePoolMath-equivalent for LP / \(V_{inv}\) / `kLast` (dual scale Q25).  
5. **All** \(\binom{n}{2}\) Uni V4 pair doors, `hooks = this`, `fee = DYNAMIC_FEE_FLAG`, `tickSpacing = 1`.  
6. Buffer pool→SE on add / swap-in; unwrap SE→pool on remove / swap-out — **buffer-last** (D29).  
7. Fungible **ERC-20 LP** on the mined hook proxy (decimals **18**); EIP-2612 via shared facets; prefix **`SEWGT`**.  
8. Full weighted join/exit surface (D38–D39) + single-asset aliases; **`joinSingleAssetExactOut` required** (D42b); **`withdrawSingleExactOut` iff D42a**. **No multi-leg rebalance.**  
9. **`IStandardExchangeIn` / `Out`** (swap-only, rated book, internal settle) + **`IStandardExchangeMultiAssetLiquidity`** = hook liquidity ABI 1:1.  
10. Swaps via **`beforeSwap` + `beforeSwapReturnDelta`**; pattern-copy settle — **no** BaseHook / DeltaResolver inheritance.  
11. Trading residual = live `dexSwapFeeOfVault` (gross buffer on SE in); growth = Uni V2–style inventory \(V_{inv}\) + dual mode from `usageFeeOfVault`.  
12. Deploy: facets CREATE3 + DFPkg via registry; instances via `deployHookVault` + hook factory; **postDeploy inits all doors**; **`ensurePairPools`**.  
13. Vault discovery: `IBasicVault` + `IStandardVault`; `reserveOfToken` = face \| **live SE shares** (not claim, not rated).  
14. Hermetic \(n\in\{2,3,4,8\}\) + SE/RP matrix; adversarial suite; forks Ethereum + Base + RH 4663.  
15. Size within real CREATE2/runtime limits; split facets/libs as needed without dropping D55a surface.

**Out of scope (v1):** Zero-SE mode; multi-leg force-buy/sell rebalance; LBP; Morpho buffering; native ETH currency; FoT/rebasing pool tokens; binary-search as primary product law; monomorph CREATE3 product factory; subclassing weighted/dual/orbital/single contracts; auto-deploy SE/RP; owner/pause on instance; treating V4 `sqrtPriceX96` as product mid; DETF coupling / shared DETF TestBases; rate provider on raw legs; SignatureTransfer on LP joins or canonical SE In/Out; same SE on two legs; multi-SE per token; package-owned global token↔SE registry.

**Peer patterns (copy, do not inherit):**

| Peer | Copy what |
|------|-----------|
| SE Orbital DFPkg + facets | Hook package shape, `deployVault` → `deployHookVault`, shared ERC20/vault facet cuts, FactoryService, postDeploy doors |
| Raw Weighted Math / LP / partial | WeightedMath swaps, full join/exit, partial dual-mode, growth algebra, ratio caps |
| Dual / Single ClaimLib / buffer-last | Claim-in composition, SE buffer/unwrap tight bounds, dust refund, gross buffer |
| Dual / Orbital settle | `beforeSwap` take / settle / `BeforeSwapDelta` discipline |
| Hook factory skill | Salt without package; flags; immutability; postDeploy |

---

## 2. File map (target)

```text
contracts/hooks/uniswap/v4/standardExchange/weighted/
  UNISWAP_V4_STANDARD_EXCHANGE_WEIGHTED_BUFFER_HOOK_PRD.md
  UNISWAP_V4_STANDARD_EXCHANGE_WEIGHTED_BUFFER_HOOK_IMPLEMENTATION_AND_TEST_PLAN.md  # this file

  interfaces/
    IUniswapV4StandardExchangeWeightedBufferHook.sol
      // product surface + documents In/Out + MultiAssetLiquidity + vault discovery
    IUniswapV4StandardExchangeWeightedBufferHookPackage.sol
      // IUniswapV4HookDiamondPackage + IStandardVaultPkg + PkgInit/PkgArgs

  UniswapV4StandardExchangeWeightedBufferHookDFPkg.sol
  UniswapV4StandardExchangeWeightedBufferHook_FactoryService.sol
  UniswapV4StandardExchangeWeightedBufferHookRepo.sol
  UniswapV4StandardExchangeWeightedBufferHookMath.sol       # pure: dual scale, WeightedMath wrap, growth, join/exit helpers
  UniswapV4StandardExchangeWeightedBufferHookClaimLib.sol  # SE claim + rate + buffer/unwrap (external)
  UniswapV4StandardExchangeWeightedBufferHookPullLib.sol   # optional: transferFrom / Permit2 AllowanceTransfer
  UniswapV4StandardExchangeWeightedBufferHookTarget.sol    # shared book/guards (or split Targets)
  UniswapV4StandardExchangeWeightedBufferHookLiquidityTarget.sol
  UniswapV4StandardExchangeWeightedBufferHookSeTarget.sol  # SE In/Out + MultiAssetLiquidity facade
  UniswapV4StandardExchangeWeightedBufferHookHooksTarget.sol

  facets/
    UniswapV4StandardExchangeWeightedBufferHookLiquidityFacet.sol
    UniswapV4StandardExchangeWeightedBufferHookSeFacet.sol
    UniswapV4StandardExchangeWeightedBufferHookHooksFacet.sol
```

**Shared SE interface (new — Phase A):**

```text
contracts/interfaces/IStandardExchangeMultiAssetLiquidity.sol
  // Normative name locked (P1 / D55). Selectors/args = hook liquidity surface 1:1 (Q19).
  // May live co-located under package interfaces/ if monorepo prefers package-local first;
  // if so, plan exit still requires a single canonical import path documented in DFPkg.
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
- Short production type names (`SEWGTHook`, `WgtSEBHook`, …)  
- Multi-leg rebalance “zap split” helpers  
- Conflating invScale and ratedScale  

**Tests (canonical names):**

```text
# Package-adjacent TestBase
contracts/hooks/uniswap/v4/standardExchange/weighted/
  TestBase_UniswapV4StandardExchangeWeightedBufferHook.sol

test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/
  UniswapV4StandardExchangeWeightedBufferHook_Deploy.t.sol
  UniswapV4StandardExchangeWeightedBufferHook_Binding.t.sol       # n, weights, ≥1 SE, distinct SE, RP rules
  UniswapV4StandardExchangeWeightedBufferHook_Scale.t.sol         # dual inv/rated scale; mixed 6/18 decimals
  UniswapV4StandardExchangeWeightedBufferHook_Liquidity.t.sol     # first / prop / unbalanced / joinExactBptOut
  UniswapV4StandardExchangeWeightedBufferHook_SingleAsset.t.sol   # depositSingle / withdrawSingle / joinSingleAssetExactOut
  UniswapV4StandardExchangeWeightedBufferHook_Partial.t.sol       # partial seed / restricted / floor order
  UniswapV4StandardExchangeWeightedBufferHook_Swap.t.sol          # doors, exact-in/out, gross buffer, rated book
  UniswapV4StandardExchangeWeightedBufferHook_SeExchange.t.sol    # IStandardExchangeIn/Out
  UniswapV4StandardExchangeWeightedBufferHook_MultiAssetLiq.t.sol # MultiAssetLiquidity == hook 1:1
  UniswapV4StandardExchangeWeightedBufferHook_Buffer.t.sol        # buffer-last, dust, claim≠raw
  UniswapV4StandardExchangeWeightedBufferHook_RateProvider.t.sol  # RP on/off, fail-closed, swap-only
  UniswapV4StandardExchangeWeightedBufferHook_Fees.t.sol          # dual-channel trading + growth
  UniswapV4StandardExchangeWeightedBufferHook_Preview.t.sol       # bit-exact previews
  UniswapV4StandardExchangeWeightedBufferHook_Permit2.t.sol       # LP + SE AllowanceTransfer paths
  UniswapV4StandardExchangeWeightedBufferHook_VaultViews.t.sol    # IBasicVault + IStandardVault; reserveOfToken=shares
  UniswapV4StandardExchangeWeightedBufferHook_EnsureDoors.t.sol   # ensurePairPools
  UniswapV4StandardExchangeWeightedBufferHook_ExactOutExit.t.sol  # ONLY if D42a ships
  UniswapV4StandardExchangeWeightedBufferHook_Adversarial.t.sol   # O11 suite
  UniswapV4StandardExchangeWeightedBufferHook_N8.t.sol            # n=8 smoke / door count (may be heavy)

test/foundry/fork/eth_main/hooks/uniswap/v4/standardExchange/weighted/
  UniswapV4StandardExchangeWeightedBufferHook_Ethereum.t.sol

test/foundry/fork/base_main/hooks/uniswap/v4/standardExchange/weighted/
  UniswapV4StandardExchangeWeightedBufferHook_Base.t.sol

test/foundry/fork/robinhood_4663/hooks/uniswap/v4/standardExchange/weighted/
  UniswapV4StandardExchangeWeightedBufferHook_Robinhood.t.sol
```

Prefer **`FOUNDRY_PROFILE=hook_factory`** (or repo equivalent) for this tree when factory/registry stack requires it.

---

## 3. Asymmetry implementor card (do not forget)

| Topic | Raw Weighted | Dual SE BCP | SE Orbital Buffer | **This package** |
|-------|--------------|-------------|-------------------|------------------|
| Assets | \(n\in[2,8]\) raw | 2 SE claims | 3 legs; 0–3 SE | **\(n\in[2,8]\); ≥1 SE** |
| AMM | Weighted on rate-scaled raw | CP | Sphere on effective | **Weighted: rated swaps / inventory LP** |
| V4 doors | \(\binom{n}{2}\) | 1 | 3 | **\(\binom{n}{2}\)** |
| Inventory SoT | Repo raw | SE shares | raw and/or SE | **face and/or live SE shares** |
| Free pair on SE leg | N/A | Not book | Not book | **Not book — dust ≤ 10 refund** |
| Rate provider | Optional any token; LP+swap | None typical | Optional SE legs | **Optional SE only; swaps only** |
| One-token entry | Single-asset join | Multi-leg zap | Multi-leg zap-in | **Single-asset join alias only** |
| One-token exit | Single-asset exit | Peer | No zap-out | **Single-asset exit aliases** |
| SE In/Out | No | Yes | Yes | **Yes + MultiAssetLiquidity** |
| Deploy | CREATE3 monomorph | Hook diamond | Hook diamond | **Hook diamond** |
| Pool fee key | `DYNAMIC_FEE_FLAG` | Peer | `DYNAMIC_FEE_FLAG` | **`DYNAMIC_FEE_FLAG` only** |
| Growth measure | Rate-scaled \(V\) | Peer | Effective sphere \(k\) | **Inventory \(V_{inv}\) (face\|shares)** |
| LP prefix | `WGT-` | Dual peer | `SEORB-` | **`SEWGT`** |
| PRODUCT_ID | monomorph salt | Dual peer | orbital PRODUCT_ID | **`UniswapV4StandardExchangeWeightedBufferHook`** |
| Distinct SE | N/A | 2 SEs | Non-zero distinct | **Non-zero pairwise distinct** |
| Zero SE | Yes (product itself) | No | Allowed | **Forbidden — use raw Weighted** |

---

## 4. Normative helpers (implement early)

### 4.1 Dual scale + native / rated domains (PRD §4.3 / Q25 / Q26)

```text
// TWO maps — never one conflated baseScale[i]
// invScale[i]   = 10^(36 - invDecimals[i])
//   raw:  invDecimals = pair-token.decimals()
//   SE:   invDecimals = IERC20(SE).decimals()     // SHARE token
// ratedScale[i] = 10^(36 - pairDecimals[i])
//   always pair-token.decimals() for leg i
// Fail if decimals ∉ [6,18] or decimals() reverts

// --- NATIVE inventory (LP, kLast, floors) — LIVE BOOK ---
for i in 0..n-1:
  if SE[i] == 0:
      native[i] = live face inventory of token_i     // donations dilute
  else:
      native_shares[i] = IERC20(SE[i]).balanceOf(hook) // LIVE; donations dilute
      claim[i] = previewExchangeIn(SE, seBal, token) // views / unwrap sizing only

invWad[i] = floor(native_amount_i * invScale[i] / 1e18)
// V_inv = WeightedMath.computeInvariantDown(weights, invWad)  // mixed face|share WAD intentional

// --- RATED (swaps + SE swap paths only) ---
for i in 0..n-1:
  if SE[i] == 0:
      pairUnits = native[i]                          // face
  else if RP[i] != 0:
      rate = getRate()                               // fail-closed; pair-token per share
      pairUnits = native_shares[i] * rate / 1e18
  else:
      pairUnits = claim[i]                           // SE claim (pair-token units)
  rated[i] = floor(pairUnits * ratedScale[i] / 1e18) // ALWAYS pair-token scale
```

**Views (O1–O2):** `nativeReserve(i)`, `nativeReserves()`, `ratedBalance(i)`, `ratedBalances()`, `seClaim(i)`, `seBalance(i)`, `standardExchange(i)`, `rateProvider(i)`, `isBuffered(i)`, `reserveOfToken(token)`.

**Never:** free pair `balanceOf(hook)` as book when buffered; multiply RP × claim; put claim/RP into LP algebra; scale rated pairUnits with share decimals.

### 4.2 Buffer-last sequencing (D29 / O6 / O10)

```text
1) Quote / size ALL amounts on PRE-BUFFER snapshot (inventory and/or rated as path requires)
2) Pull natives / execute non-buffer inventory moves (unwrap outs, raw credits)
3) Buffer SE legs LAST in BINDING INDEX ORDER for used amounts > 0
4) Re-read LIVE inventory; mint/burn LP / set kLast from POST-BUFFER inventory
// Forbidden: re-solve WeightedMath mid-flight after buffer
```

### 4.3 Share / claim composition for swaps (D28 / D28a / D57a / Q16)

```text
// Buffered tokenIn (exact-in example)
// 1) Take FULL gross amountIn (pair token)
// 2) sharesIn = preview_buffer(token → SE) of gross amountIn
// 3) ratedInflowGross = map shares → pairUnits (rate or claim delta) → ratedScale
// 4) amountInNet_rated = ratedInflowGross - floor(ratedInflowGross * feeWad / 1e18)
// 5) WeightedMath.computeOutGivenExactIn on rated book with net
// 6) Map rated out → native out (descale + SE unwrap invert if buffered)
// 7) Buffer FULL gross amountIn last (inventory gets residual via gross shares)
// Exact-out: ceil gross-up of input fee; buffer that gross input

// If required SE exact-out / invert unsupported → FULL TX REVERT (D28a)
// Shared composition: V4 doors + SE In/Out (NO multi-leg internal rebalance paths)
```

### 4.4 Weighted swap math (pure Math — wrap Crane)

**Do not re-derive.** Call Crane `WeightedMath`:

- `computeOutGivenExactIn` / `computeInGivenExactOut`  
- Caps: `_MAX_IN_RATIO` / `_MAX_OUT_RATIO` = **30e16** of **rated** trade-leg balances  

Swap formula uses **only** the two trade legs’ **rated** balances and global \(w_{in}, w_{out}\) (no renormalization of other legs).

Trading fee: live `dexSwapFeeOfVault`; Balancer **input** residual; 0 OK; require `< 1e18`. Map WAD → pips + `OVERRIDE_FEE_FLAG` (informational; **no double-haircut**).

### 4.5 Inventory LP algebra (PRD §4.6 / Weighted peer)

Work in **invWad** (face \| live shares). User edge always **pair tokens** + buffer-last / unwrap.

| Path | Law |
|------|-----|
| First mint | Preferred all \(n>0\); partial ≥2 for \(n\ge3\); \(n=2\) both required. `shares = V_inv − 1000`; MIN → `address(0)`; no protocol mint while `kLast==0` |
| Proportional join/exit | Peer Weighted / Balancer proportional on inventory; exit floors D48 |
| Unbalanced join | Taxable + invariant ratio caps (~300% / ~70%) on inventory domain |
| Single-asset exact-in | `joinSingleAssetExactIn` / alias `depositSingle`; full book only |
| Single-asset exact-BPT-out join | **`joinSingleAssetExactOut` required** (D42b) |
| Single-asset exact-BPT-in exit | `exitSingleAssetExactBptIn` / alias `withdrawSingle` |
| Single-asset exact-token-out exit | **Iff D42a** ships after Phase 0 |
| Full-book exit floors | All \(n\) native reserves remain \(> 0\) (D48) — cannot zero a leg via full-book exit |
| Recipients | Mint LP to `to`; refunds → `msg.sender`; burn `msg.sender` LP; pay tokens to `to` (Q12) |

**Taxable join × buffer-last process (plan pin):**

```text
// Single-asset / unbalanced join preview & exec:
// 1) Protocol growth mint if fee-on (inventory kLast)
// 2) Snapshot LIVE invWad (pre-intake)
// 3) Map user pair-token maxes → intended inventory deltas via SE buffer previews
//    (work in share units for SE legs; face for raw) WITHOUT mutating book yet
// 4) Balancer taxable join math on working inventory balances → shares / used
// 5) Pull pair tokens for used; buffer-last SE legs; credit raw faces
// 6) Mint LP to `to`; set kLast from post LIVE invWad; refund free SE-leg pair dust
// Previews must use the same map order and fee oracle / SE preview reads
```

### 4.6 Partial book (PRD §4.7 / Q22 / Weighted §4.7)

Behavioral peer: raw Weighted partial dual-mode, on **inventory** legs:

- Modes: `FullProduct` vs `PartialInterim`  
- Interim product on positive inventory legs with renormalized weights  
- First mint \(n\ge3\): ≥2 positive legs; floor order **binding-index ascending** (Q22)  
- Single-asset aliases **forbidden** while partial  
- Full unbalanced only when full book  
- Cross-mode: no protocol mint from incompatible `kLastMode`  

Plan freezes bit-exact FixedPoint ordering only; **does not** change PRD ordering law.

### 4.7 Protocol growth (D59–D63 / D24 / D61)

```text
feeWad = usageFeeOfVault(this)   // NOT dexSwapFee
ownerFeeShare = feeWad * 100_000 / 1e18
feeOn = feeTo != 0 && feeWad != 0 && feeWad < 1e18 && ownerFeeShare != 0

// Full book: k = V_inv = prod invWad_i^w_i ; rootK = V_inv (literal)
// Partial: interim product on positive inventory legs; rootK = k_interim
// protocolLp peer Weighted / ConstProdUtils (FEE_DENOMINATOR = 100_000)
// Timing: mint from pre-intake k on add; mint before user burn on remove
// Swaps: no protocol mint; no kLast update
// LP previews simulate dilution when fee-on
// SE yield that only changes claim (not share balance) does NOT move V_inv
```

### 4.8 SE I/O + MultiAssetLiquidity (D30, D51–D56)

| Path | Call |
|------|------|
| Buffer token → SE | `exchangeIn(token → SE)`; minOut = tight fee-inclusive preview |
| Unwrap SE → token | `exchangeIn(SE → token)` or `exchangeOut` when exact-out required; else **full revert** (D28a) |
| SE In/Out swaps | Canonical In/Out; rated book; internal settle; **never** mint/burn LP |
| MultiAssetLiquidity | Thin facade → same Target as hook liquidity (Q19) |

**SE In/Out funding (D53):** if `!pretransferred`: transferFrom if allowance else Permit2 AllowanceTransfer.  
**LP funding (Q24):** same pull law; **no** SignatureTransfer / no `permit2Data` on join ABI.

### 4.9 Hook permissions (D71)

```text
BEFORE_INITIALIZE
| BEFORE_ADD_LIQUIDITY
| BEFORE_REMOVE_LIQUIDITY
| BEFORE_SWAP
| BEFORE_SWAP_RETURNS_DELTA
| BEFORE_DONATE
```

Mask against `Hooks.ALL_HOOK_MASK` in factory. CL add/remove and donate always revert. `beforeInitialize`: factory-door rules only (D66).

### 4.10 Events (D72b / Q23)

| Event | Normative fields |
|-------|------------------|
| Join / Exit (MultiAsset same) | `sender`, `to`, `shares`, `int256[] deltas` (binding order, pair-token edge), `protocolSharesMinted` |
| `DepositSingle` | `sender`, `to`, `token`, `amountIn`, `shares`, `protocolSharesMinted` |
| `WithdrawSingle` | `sender`, `to`, `token`, `amountOut`, `shares`, `protocolSharesMinted` |
| `WithdrawSingleExactOut` | iff D42a: `sender`, `to`, `token`, `amountOut`, `sharesBurned`, `protocolSharesMinted` |
| `ProtocolFeeMinted` | `feeTo`, `shares` |
| `EnsurePairPools` / PairPoolsEnsured | `hook`, `doorsEnsured` |
| HookDeployed | package/factory peer |

**No** product-level `Swap` event (V4 / PoolManager logs suffice).

### 4.11 Algorithm pointers (PRD sections)

| Path | PRD |
|------|-----|
| Dual scale / native vs rated | §4.3, Q25–Q26 |
| Weighted swaps + gross buffer | §4.4, D57a, Q16 |
| Fees | §4.5 |
| Full-book LP + single-asset | §4.6, D42b |
| Partial book | §4.7, Q22 |
| SE surfaces | §4.8 |
| V4 settle | §4.9 |
| Surface / events | §5 |
| Deploy | §6 |
| Testing / DoD | §7–§8 |

---

## 5. Implementation phases

### Phase 0 — Dual gate: D42a audit + ERC-4626 wrapper SE **[plan + TestBase]**

#### 0a. Closed-form exit exact-token-out audit (Q21 / D42a)

1. Audit Crane vendored `WeightedMath` / `BasePoolMath` (and Balancer WeightedPool peers if needed) for **closed-form single-token exact-out exit** (exact token out → BPT in).  
2. Record outcome in this plan’s revision log + a one-line checklist row:  
   - **SHIP:** function names + rounding notes + bit-exact preview requirement  
   - **OMIT:** omit `exitSingleAssetExactTokenOut` / `withdrawSingleExactOut` from v1 DoD and tests  
3. **Does not** affect `joinSingleAssetExactOut` (required — D42b).  
4. **Never** binary-search.

**Exit 0a:** Written SHIP or OMIT decision with Crane symbol references.

#### 0b. ERC-4626 wrapper SE thin gate

1. Confirm production ERC-4626 wrapper SE deploys via manager/registry path.  
2. Confirm closed-form **token ↔ SE** buffer and unwrap (exact-in + exact-out as needed) with **preview == execution**.  
3. Confirm ability to deploy **multiple distinct** wrapper SEs for multi-SE matrix rows.  
4. Confirm rate provider peer (production SE rate provider package or static `IRateProvider` implementing real interface) for RP rows — **not** a mock of the hook SUT.

**Exit 0b:** Package-adjacent TestBase can deploy 1–n real wrapper SEs + mintable tokens + optional RP; buffer/unwrap both directions with preview fidelity.

---

### Phase A — Package skeleton + diamond deploy path

1. Create §2 file map (interfaces, Repo, empty Targets/Facets, DFPkg, FactoryService).  
2. Author **`IStandardExchangeMultiAssetLiquidity`** (canonical path documented).  
3. **Interface:** PRD §5.3 surface + In/Out + MultiAssetLiquidity + vault discovery; `PkgInit` / `PkgArgs` **on interface** (Crane rule).  
4. **PkgArgs binding (illustrative):**  
   `(n, tokens[n], weights[n], standardExchange[n], rateProvider[n])`  
   PM + feeOracle from factory immutables (Q11). Permit2 **not** in args.  
5. **Validation (init / processArgs):**  
   - \(n\in[2,8]\); tokens non-zero, pairwise distinct, strict address ascending; decimals [6,18]  
   - weights: each \(\ge 1e16\); sum \(= 1e18\) exactly  
   - ≥1 SE; SE zero **or** `token_i ∈ SE.vaultTokens()`, `token_i != SE`; non-zero SEs pairwise distinct  
   - RP non-zero **only if** SE non-zero  
6. **DFPkg:**  
   - `PRODUCT_ID = "UniswapV4StandardExchangeWeightedBufferHook"` (string / hash per factory peer)  
   - `requiredHookFlags()` = §4.9 mask  
   - `packageSalt` = PRODUCT_ID + binding fields (**n, tokens, weights, SEs, RPs**) + factory-scope identity — **no** package/facet addresses; **no** PM/oracle in salt if factory-immutable (D70)  
   - `deployVault(args, mineNonce)` → `registry.deployHookVault`  
   - **`postDeploy`:** initialize **all** \(\binom{n}{2}\) pair doors (address-sorted currencies, `DYNAMIC_FEE_FLAG`, `TICK_SPACING=1`, `sqrtPriceX96` at tick 0)  
   - `ensurePairPools(hook)` path (permissionless repair)  
   - `diamondConfig` **without** live `diamondCut`  
   - Cut shared ERC20Permit + MultiAsset vault facets + product facets  
7. **initAccount:** ERC20Repo + EIP712Repo + product Repo binding + LP name/symbol `SEWGT-…` (Q14 caps + address-fragment fallback).  
8. **FactoryService:** CREATE3 facets; `deploy*DFPkg` via manager; mine helpers for flags.  
9. Hook callback stubs; reentrancy lock in Repo; disabled CL + donate reverts.  

**Exit:** `forge build` green; TestBase deploys package via registry + hook factory; all doors initialized for a chosen \(n\); flags correct; binding views return args; `totalSupply == 0`.

---

### Phase B — Math + ClaimLib (dual scale / composition)

1. Pure `…Math.sol`:  
   - `invScale` / `ratedScale` / `toInvWad` / `toRatedWad` / descale helpers  
   - WeightedMath wrappers (swap + invariant)  
   - growth protocol LP algebra  
   - join/exit helpers on inventory domain (proportional, unbalanced, single-asset exact-in, exact-BPT-out join)  
   - partial interim product helpers  
   - **no** SE/RP external calls; **no** multi-leg rebalance split  
2. `…ClaimLib.sol`:  
   - live SE balance read  
   - claim preview  
   - buffer claim-in / unwrap claim-out  
   - invert helpers; **revert whole op** on missing exact-out (D28a)  
   - fail-closed RP `getRate`  
3. Common Target helpers: decimals cache, index maps, pair door key builders, fee oracle reads.  
4. Wire `nativeReserve*` / `ratedBalance*` / `seClaim` / `seBalance` / `reserveOfToken` views (live book).  

**Exit:** Views compile; dual-scale unit vectors exercised via hook views/previews; smoke zero book.

**Required numeric fixtures (document in Math tests or Preview suite):**

| FIX | Intent |
|-----|--------|
| FIX-SCALE-6-18 | Raw USDC-like 6d + SE share 18d inventory \(V_{inv}\) first mint |
| FIX-RATED-RP | SE leg with RP: rated uses pair-token scale of `seBal×rate`, not share decimals |
| FIX-RATED-CLAIM | SE leg no RP: rated from claim; LP invWad from share balance unchanged when claim moves alone |
| FIX-DONATE-SE | Extra SE shares to hook dilute subsequent join share mint (Q26) |

---

### Phase C — Full-book LP (join / exit) — no swap / no one-token yet

1. Global nonReentrant on liquidity mutators.  
2. First mint full book: all \(n>0\); buffer-last; `shares = V_inv − MIN`.  
3. Proportional join/exit; unbalanced join; **`joinSingleAssetExactOut`** (D42b).  
4. Exit floors D48; dust refund on buffered free pair.  
5. Protocol growth mint timing on add/remove; previews simulate dilution.  
6. Pull: transferFrom if allowance else Permit2 AllowanceTransfer (Q24).  
7. Events D72b.  

**Exit:** Hermetic first mint + prop join/exit + exact-BPT-out join for \(n=2\) and \(n=3\); preview==exec; growth path smoke.

---

### Phase D — Partial book

1. Partial first mint (\(n\ge3\), ≥2 legs); binding-index floor order (Q22).  
2. Restricted joins while partial; single-asset aliases **revert**.  
3. Seed zeros → transition to full book; cross-mode `kLast`.  
4. Reject full-book exit that would zero a leg.  

**Exit:** Partial suite green for \(n=3,4\); \(n=2\) rejects partial first mint.

---

### Phase E — One-token aliases (`depositSingle` / `withdrawSingle`)

1. `depositSingle` ≡ `joinSingleAssetExactIn` (full book only).  
2. `withdrawSingle` ≡ `exitSingleAssetExactBptIn`.  
3. If Phase 0a SHIP: wire `withdrawSingleExactOut` + previews; else omit selectors from interface DoD.  
4. No multi-leg rebalance paths anywhere.  

**Exit:** Single-asset suite green; MultiAssetLiquidity aliases match hook (thin facade may land in Phase G).

---

### Phase F — V4 swaps (all doors) + dynamic fee

1. `beforeSwap` / `beforeSwapReturnDelta` pattern-copy settle.  
2. Rated book composition + fee-net curve + gross buffer (Q16).  
3. Exact-in and exact-out both directions per directed pair; ratio caps; post floors D33.  
4. Fee override pips; no double-haircut.  
5. RP fail-closed on rated paths.  

**Exit:** Swap suite for \(n=2\) (1 door) and \(n=3\) (3 doors); rated ±RP; gross buffer inventory check.

---

### Phase G — SE In/Out + MultiAssetLiquidity facade

1. Canonical `exchangeIn` / `exchangeOut` (and previews) — swap-only, internal settle, rated book.  
2. Funding D53; reject SE share addresses / unbound tokens / same in-out.  
3. `IStandardExchangeMultiAssetLiquidity` thin facade: **identical** names/args/returns to hook liquidity (Q19).  
4. Shared Target implementation — no duplicated math.  

**Exit:** SeExchange + MultiAssetLiq suites green; 1:1 selector parity test (or ABI equality helper).

---

### Phase H — Fees hardening + vault discovery + ensurePairPools

1. Dual-channel fee matrix (trading residual stays in input inventory; growth mint to live `feeTo`).  
2. Vault views: `vaultTokens`, `reserveOfToken` = shares on SE legs, etc.  
3. `ensurePairPools` idempotent; event fields.  
4. LP metadata caps / fallback.  

**Exit:** Fees + VaultViews + EnsureDoors green.

---

### Phase I — Hermetic matrix complete (\(n\in\{2,3,4,8\}\) + SE/RP configs)

1. Config rows:  
   - (a) 1 SE + raw rest  
   - (b) all legs SE  
   - (c) mixed  
   - (d) RP zero/non-zero on SE legs  
2. \(n=2,3,4\) full functional coverage; \(n=8\) **required** at least: deploy + all 28 doors + first mint + one swap door + one join/exit (N8 suite may be smoke-heavy).  
3. Preview bit-exact suite across paths.  
4. Adversarial O11: reentrancy (LP↔swap↔SE), donation dilution (raw + SE shares), `feeTo` non-receivable, SE revert mid-buffer, RP fail-closed, partial drain attempts, distinct-SE / zero-SE rejects, full-book zero-leg exit.  

**Exit:** All hermetic DoD rows green under production-first rules.

---

### Phase J — Forks (Q18)

1. Ethereum mainnet fork  
2. Base mainnet fork  
3. Robinhood 4663 fork  

Each: production PM/Permit2/fee oracle when present; deploy-if-missing production-equivalent stack; mintable tokens + wrapper SE OK; smoke deploy + door init + first mint + swap + single-asset join.

**Exit:** Three fork suites green, equal priority.

---

### Phase K — Polish

1. NatSpec + Crane code-style; no `console.log` in production sources.  
2. Size check (`forge build --sizes`); split facets/libs if needed without dropping surface.  
3. Update this plan revision log with D42a SHIP/OMIT final stamp and any bit-exact pins.  
4. Confirm PRD §8 checklist can be checked.  

**Exit:** Package ready for review / merge.

---

## 6. Locked constants (implementor card)

| Constant | Value |
|----------|--------|
| `MIN_WEIGHT` | `1e16` (1%) |
| Weight sum | `1e18` exactly |
| `MINIMUM_LIQUIDITY` | `1000` → `address(0)` |
| `MAX_DUST_WEI` | `10` |
| Swap ratio caps | 30% of rated trade-leg balances |
| Invariant ratio caps | ~300% max growth / ~70% min shrink (Balancer peer) |
| `TICK_SPACING` | `1` |
| Pool fee key | `DYNAMIC_FEE_FLAG` only |
| LP decimals | `18` |
| LP symbol prefix | `SEWGT` |
| Symbol / name caps | 32 / 64 |
| `PRODUCT_ID` | `"UniswapV4StandardExchangeWeightedBufferHook"` |
| Permit2 | `0x000000000022D473030F116dDEE9F6B43aC78BA3` |
| Fee denominator (growth) | `100_000` |
| Decimals band | `[6, 18]` |
| \(n\) range | `[2, 8]` |
| Hermetic \(n\) | `{2, 3, 4, 8}` |

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
       → postDeploy: init all binom(n,2) doors + register vault
5. Permissionless ensurePairPools(hook) repairs missing doors only
```

### 7.2 Salt law (D70 / Q13)

```text
packageSalt = hash(PRODUCT_ID, n, tokens, weights, standardExchanges, rateProviders
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

Peer SE Orbital / Single SE BCP FactoryService:

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

### 8.2 Hermetic DoD matrix

| ID | Case | Required |
|----|------|----------|
| H1 | Deploy inert; ≥1 SE; all doors; flags | Yes |
| H2 | Zero-SE / non-distinct SE / RP-without-SE / bad weights / bad decimals reject | Yes |
| H3 | First mint inventory \(V−MIN\); dead MIN | Yes |
| H4 | Partial book seed + restricted paths + floor order | Yes (\(n\ge3\)) |
| H5 | Full join/exit matrix incl. `joinSingleAssetExactOut` | Yes |
| H6 | `depositSingle` / `withdrawSingle` aliases; no multi-leg rebalance | Yes |
| H7 | Swaps rated ±RP; gross buffer; exact-in/out | Yes |
| H8 | SE In/Out swap-only; preview==exec | Yes |
| H9 | MultiAssetLiquidity ABI 1:1 + shared behavior | Yes |
| H10 | `reserveOfToken` = live SE shares; claim/rated separate | Yes |
| H11 | Protocol growth mint + preview dilution | Yes |
| H12 | Rate fail-closed | Yes |
| H13 | `ensurePairPools` | Yes |
| H14 | Dual scale fixtures (FIX-*) | Yes |
| H15 | Donation dilution SE shares | Yes |
| H16 | \(n\in\{2,3,4,8\}\) | Yes (n=8 may smoke) |
| H17 | Adversarial O11 | Yes |
| H18 | `withdrawSingleExactOut` | **Iff D42a SHIP** |

### 8.3 Fork matrix

| Chain | Path | Priority |
|-------|------|----------|
| Ethereum | `test/foundry/fork/eth_main/...` | Equal |
| Base | `test/foundry/fork/base_main/...` | Equal |
| Robinhood 4663 | `test/foundry/fork/robinhood_4663/...` | Equal |

### 8.4 Commands (illustrative)

```bash
forge build
forge test --match-path test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/ -vv
# optional profile when factory stack requires:
# FOUNDRY_PROFILE=hook_factory forge test --match-path ...
forge test --match-path test/foundry/fork/base_main/hooks/uniswap/v4/standardExchange/weighted/
forge test --match-path test/foundry/fork/eth_main/hooks/uniswap/v4/standardExchange/weighted/
forge test --match-path test/foundry/fork/robinhood_4663/hooks/uniswap/v4/standardExchange/weighted/
forge build --sizes
```

---

## 9. Storage sketch (Repo)

Informative — plan freezes layout; adjust if diamond storage packing requires:

```text
// Binding (set-once)
uint8 n
address[8] tokens          // or dynamic length packed; max 8
uint256[8] weights
address[8] standardExchange
address[8] rateProvider
// decimals caches: pairDecimals[i], invDecimals[i] (share or face)

// Factory immutables mirrored on instance if needed for views
address poolManager
address feeOracle

// Intentional raw face cache (optional) — LIVE SE shares always balanceOf
// Prefer re-read live balances for LP/swap (Q26); cache only for gas/events if proven safe

// Growth
uint256 kLast
uint8 kLastMode            // FullProduct | PartialInterim

// LP metadata cache
string name / symbol (or short bytes)

// Reentrancy lock
uint256 lock

// Door bitmap / initialized pair set (optional for ensurePairPools)
```

**Rule:** Do not store rated balances or claim as authoritative book.

---

## 10. Risks & mitigations

| Risk | Mitigation |
|------|------------|
| Mixed face\|share \(V_{inv}\) mis-implemented as claim/RP | Q7/Q25 locks; FIX-SCALE + FIX-RATED-CLAIM; review gate |
| Rated scale uses share decimals | Dual-scale helpers + FIX-RATED-RP |
| Repo cache diverges from live SE balance | Q26: views/algebra re-read `balanceOf`; donations dilute tests |
| Taxable join vs buffer-last preview drift | §4.5 process pin; bit-exact preview suite |
| n=8 gas / suite time | Required doors+smoke; full matrix optional progressive |
| SE missing exact-out invert | D28a full revert; no partial fill |
| RP fail / zero rate | Fail-closed on rated paths only |
| Multi-leg zap reintroduction | Q28; no split helper in Math; code review |
| DETF creep | No DETF imports; independent TestBase (D77) |
| Size blow-up at n=8 | Facet split; pure Math; shared vault/ERC20 facets |
| Double fee haircut on V4 | Residual math SoT; override informational only |
| Factory doors incomplete | postDeploy + ensurePairPools tests |

---

## 11. Definition of done (package)

- [x] PRD v0.6 accepted; this plan accepted  
- [x] Phase 0a D42a **SHIP** recorded (BasePoolMath single-token exact-out exit closed-form)  
- [x] Package implements D1–D78 + D42b + P1–P6 + Q7–Q28 (v1 surface shipped)  
- [x] Deploy: Package → Vault Registry → Hook Diamond Factory; postDeploy doors + `ensurePairPools`  
- [x] `PRODUCT_ID` full type name; LP caps; factory PM+oracle  
- [x] ≥1 SE; distinct SEs; RP optional on SE only  
- [x] Swaps rated + gross buffer; dual scale; live SE book; no multi-leg rebalance  
- [x] `joinSingleAssetExactOut` shipped; MultiAssetLiquidity = hook ABI 1:1; LP pull AllowanceTransfer-only  
- [x] Events D72b; partial floor order Q22  
- [x] Hermetic \(n\in\{2,3,4,8\}\); adversarial O11 (49 green under `FOUNDRY_PROFILE=se_weighted_buffer_hook`)  
- [x] Forks ETH + Base + 4663 — real product smoke via ForkSmoke + fork-tree TestBase smokes (hermetic when RPC unset)  
- [x] Dual-channel fees; no DETF; no production debug logs  
- [x] `forge build` + hermetic + fork suites green (production facets under EIP-170)  

---

## 12. Explicit non-actions for coding agents

1. Do **not** subclass raw Weighted / Dual / Orbital / Single contracts.  
2. Do **not** use monomorph CREATE3 / HookMinerCreate3 as production instance path.  
3. Do **not** put package/facet addresses in salt.  
4. Do **not** implement multi-leg force-buy/sell rebalance.  
5. Do **not** put `getRate` / live claim into LP mint/burn / `kLast`.  
6. Do **not** scale rated pairUnits with SE share decimals.  
7. Do **not** treat free pair dust on buffered legs as book.  
8. Do **not** allow zero-SE deployments.  
9. Do **not** binary-search for exact-out paths.  
10. Do **not** add SignatureTransfer / `permit2Data` on LP joins.  
11. Do **not** merge MultiAssetLiquidity into canonical In/Out swap selectors.  
12. Do **not** add owner/pause/admin or live `diamondCut`.  
13. Do **not** couple to DETF packages or share DETF TestBases.  
14. Do **not** mock SUT hook / SE / manager / registry / fee oracle / PM.  
15. Do **not** leave `console.log` in production sources.  

---

## 13. Suggested coding order (single agent or handoff)

```text
0.  Phase 0a — D42a Crane audit (SHIP/OMIT)
0b. Phase 0b — wrapper SE + RP harness in TestBase
A.  Skeleton + DFPkg + deploy + doors + ensurePairPools stub
B.  Math dual scale + ClaimLib + views
C.  Full-book LP (prop/unbalanced/joinExactBptOut) + growth
D.  Partial book
E.  One-token aliases (+ exact-out exit if SHIP)
F.  V4 swaps all doors
G.  SE In/Out + MultiAssetLiquidity facade
H.  Fees + vault views + ensurePairPools polish
I.  Hermetic matrix n∈{2,3,4,8} + adversarial
J.  Forks ETH + Base + 4663
K.  Polish / sizes / plan stamp
```

---

## 14. Phase 0a checklist (D42a)

| Field | Value |
|-------|--------|
| Audit date | 2026-08-06 |
| Crane symbols reviewed | `BasePoolMath.computeRemoveLiquiditySingleTokenExactOut`, `computeRemoveLiquiditySingleTokenExactIn`, `computeAddLiquiditySingleTokenExactOut`; `WeightedMath.computeOutGivenExactIn` / `computeInGivenExactOut` / `computeInvariantDown|Up` / `computeBalanceOutGivenInvariant` |
| Closed-form exact-token-out exit? | **SHIP** |
| If SHIP: external names | `exitSingleAssetExactTokenOut`, alias `withdrawSingleExactOut`, matching `preview*` |
| If SHIP: rounding notes | BasePoolMath: ROUND_UP currentInvariant, ROUND_DOWN invariantWithFeesApplied for bptAmountIn (protocol-favoring). Product wraps monomorph `singleExitExactOutSharesIn` / BasePoolMath-equivalent on **inventory invWad**; bit-exact preview==exec required. Never binary-search. |
| If OMIT: interfaces exclude selectors | N/A (SHIP) |
| Join exact-BPT-out unaffected | **Required** (`joinSingleAssetExactOut`) regardless of this row |

---

## 15. Revision log (this plan)

| Version | Date | Notes |
|---------|------|-------|
| **v1.0** | 2026-08-05 | Initial canonical plan from PRD **v0.6**. Phases 0–K; dual-scale helpers; live SE book; required `joinSingleAssetExactOut`; Phase 0a D42a SHIP/OMIT; MultiAssetLiquidity 1:1; hermetic \(n\in\{2,3,4,8\}\); forks ETH+Base+4663; FIX-* scale fixtures; no multi-leg rebalance |
| **v1.0.1** | 2026-08-06 | Phase 0a **SHIP**: Crane `BasePoolMath.computeRemoveLiquiditySingleTokenExactOut` closed-form confirmed. Ship `exitSingleAssetExactTokenOut` + `withdrawSingleExactOut` with bit-exact preview. |

---

## 16. Summary for coding agents

Ship a **hook diamond** weighted multi-door book with **≥1 SE buffer**, **inventory-domain LP**, and **rated swap pricing** (dual scale). Mirror raw Weighted join/exit/partial/fees behavior without monomorph factory law. Buffer-last + claim composition from Dual/Orbital process peers. **Only discretionary ship:** exit exact-token-out after Phase 0a. Everything else in PRD v0.6 is locked — implement, test production-first, do not redesign.

**End of plan — UniswapV4StandardExchangeWeightedBufferHook (v1.0)**
