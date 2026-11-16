# Implementation & Test Plan: Uniswap V4 Single Standard Exchange Buffer Constant Product Hook

**PRD (product law SoT):** [`UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_PRD.md`](./UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_PRD.md) (**v1.3 draft / conversation-locked**)  
**This plan (implementor SoT once accepted):** greenfield package under `constantProduct/single/` — **no** existing scaffold to rename.  
**Package:** `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/`  
**Date:** 2026-08-04  
**Status:** **Canonical plan — aligned to PRD v1.3** (vault/SE compatibility + deploy flexibility). Ready for implementor stamp, then code. **No production code in this doc-only pass.**

**Authority**

| Layer | Role |
|-------|------|
| PRD v1.3 | Product law (D1–D87, O1–O16, §0–§11, §4.2 / §4.6, §7 / §7.6) |
| **This plan** | Implementor source of truth for phases, file map, helpers, tests, deploy Option A/B |
| Dual CP package | Pattern-copy for LP / fees / Permit2 / FactoryService / TestBase shape — **DoD good enough; do not subclass** |
| Single wrapper package | Pattern-copy for settle / beforeSwap delta — **do not subclass** |
| Peer ConstProdUtils | Formula SoT |
| Crane diamond factory | Pattern for Option B; **must not** use package-in-salt; may need Hook Diamond Factory generalization |

**Read order for implementors**

1. PRD §0 terminology (**virtual pair reserve**, **buffer-last**) + §1 fee intent + §1.2 asymmetry  
2. PRD §4.1–§4.6 (reserves, swaps, zap-in, **zap-out quote-before-buffer**) + §7 (surface / Permit2 / fees)  
3. **This plan** §1–§5 (scope, files, helpers, phases)  
4. Dual sources only as secondary pattern reference — **PRD v1.2 wins**  

**Process rule:** If this plan and PRD disagree, **PRD wins** and this plan must be patched.

**Conversation locks (v1.2) — implementor card**

| Lock | Value |
|------|--------|
| Product fees | Uni V2-like: **D19 swap fee** + **D57 growth fee** only |
| SE fees | **Orthogonal** — trust SE preview==exec (D73); D78 still required |
| Hermetic/fork SE | **Only** ERC-4626 **Wrapper** SE — no multi-SE matrix |
| Phase 0 | **Thin verify/deploy** of existing wrapper SE — not “build ERC-4626” / not dual Phase 0 |
| Pair-side book | **Virtual pair reserve** = SE claim (`seClaimSupply`) — not free pair balance |
| Sequencing | **Quote first → buffer last → mint LP / update kLast** (O13) |
| Pool order | `currency0` = **lower address**; public `currency0()`/`currency1()` required |
| Dust | Uni V2 **MINIMUM_LIQUIDITY** locked to `address(0)` |
| Permit2 | In **Target** unless size forces externalization |
| Errors | Implementor invents names |
| TestBase | **Package-adjacent** |
| Adversarial DoD | Reentrancy + donation + feeTo non-receivable + SE revert mid-zap |
| Forks | May deploy mintable tokens + wrapper SE |
| Size | Real CREATE3 / runtime limits |
| Vault/SE compat | **Required:** `IStandardExchangeIn`/`Out` + `IBasicVault` + `IStandardVault` (§7.6); LP APIs not collapsed |
| SE In/Out | Direct book swap raw↔pair (same math as V4 swap); **not** LP mint/burn; no PoolManager |
| Deploy shape | Option A monomorph **or** Option B Hook Diamond (salt **without** package; mine V4 flags) |

---

## 0. Starting state

| Item | Status |
|------|--------|
| PRD v1.2 | Present at package path (conversation locks applied) |
| Hook / FactoryService / interface Solidity | **None** — greenfield |
| Tests / TestBase | **None** (TestBase will be package-adjacent) |
| Dual CP scaffold | Peer under `…/standardExchange/dual/` — pattern-copy OK; **no dual Phase 0 gate** |
| Single wrapper | Peer under `…/standardExchange/single/` — settle pattern only |
| ERC-4626 **wrapper** SE | Exists at `contracts/vaults/standard/erc4626/` — **thin Phase 0:** deployable in TestBase with preview==exec |

**Do not** start from dual sources by copy-paste without remapping:

- Dual uses **two SE claims**; this package uses **raw face × one virtual pair reserve (SE claim)**.  
- Dual has **no** `withdrawSingle`; this package **requires** zap-out (§4.6) with **quote-before-buffer**.  
- SE fees are **orthogonal** (D70S demoted) — do not invent SE exit fees for DoD.  
- Dual salt/binding = two legs; this package = `(se, pairToken, rawToken)`.

---

## 1. Scope (v1 DoD)

Implement production-first package **`UniswapV4SingleStandardExchangeBufferConstantProductHook`**:

1. Bind **one** SE + **pairToken** + **rawToken** + **PoolManager** + **feeOracle** (ctor immutables). Permit2 = Uniswap well-known constant.  
2. V4 pool currencies = address sort of raw vs pair (**lowest = currency0**); public `currency0()`/`currency1()`; pool fee **0**; mid/depth from **raw face × virtual pair reserve (SE claim)**.  
3. **Constant product** like Uni V2 on effective reserves with **0.3% trading fee retained** (D19) + **protocol growth fee** (D57); **claim-in/out vs virtual pair reserve** (D78); face raw on raw side.  
4. Buffer pair→SE on deposit / swap-in / zap pair-in (**buffer-last O13**); unwrap SE→pair on withdraw / swap-out / zap residual.  
5. Hold **rawToken** as free ERC-20 inventory (never buffer raw into SE). Free pair is **not** the book.  
6. Single fungible **ERC-20 LP** on the mined hook (decimals **18**); **MINIMUM_LIQUIDITY** locked dust.  
7. **deposit** (proportional, clamp+refund) + **depositSingle** (zap-in when zap-eligible).  
8. **withdraw** (pro-rata raw + SE shares → unwrap pair) + **withdrawSingle** (zap-out: quote residual **before** buffer; 100% residual sell).  
9. Funding: ERC-20 `transferFrom` **and** Permit2 SignatureTransfer **and** AllowanceTransfer on **deposits only** (Permit2 in Target unless size).  
10. Slippage: `minLpAmount` / `minAmount0`/`minAmount1` / `minAmountOut` + `deadline` on liquidity.  
11. Protocol growth fee (D57): `kLast` wad product post-buffer; mint protocol LP to `address(feeTo)` on mint/burn when fee-on.  
12. One V4 pool per hook instance (D69).  
13. Deploy: existing `create3Factory` + `HookMinerCreate3` + FactoryService (not vault registry; not DFPkg diamond).  
14. **Phase 0 (thin):** ERC-4626 **wrapper** SE deployable in TestBase with preview==exec (D60/D66).  
15. **Adversarial DoD:** reentrancy, donation, feeTo non-receivable, SE revert mid-zap (O16).  
16. Size within real CREATE3/runtime limits.  
17. **Vault/SE compatibility (D84–D87):** implement `IStandardExchangeIn`, `IStandardExchangeOut`, `IBasicVault`, `IStandardVault` per PRD §7.6.  
18. **Deploy Option A or B** (PRD §2.4) — product surface identical; plan Phase A′ chooses.

**Out of scope (v1):** Collapsing LP into SE In/Out only; CL / native `modifyLiquidity`; InitPrice / one-sided book; FoT/rebasing pool tokens; multi-pool inventory; hook Permit2 for swaps or LP burn; product cap on protocol fee WAD; binary-search as primary swap/zap law; native ETH currency; max-impact guards on zap-out (D34a); DETF package; subclass dual/wrapper; multi-SE test matrix; inventing SE exit fees for DoD; vault-registry deployPkg for the hook instance; post-deploy diamondCut on live hooks (if Option B).

**Peer patterns (copy, do not inherit):**

| Peer | Copy what |
|------|-----------|
| Dual CP `…/standardExchange/dual/` | LP mint/burn, D57/kLast, Permit2 packing, FactoryService mine loop, TestBase shape, events |
| Single wrapper `…/standardExchange/single/` | `beforeSwap` take/settle / `BeforeSwapDelta` discipline |
| `ConstProdUtils` | `_saleQuote`, `_purchaseQuote`, `_swapDepositSaleAmt`, `_calculateProtocolFee` |

---

## 2. File map (target)

### 2.1 Option A — monomorph (baseline)

```text
contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/
  UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_PRD.md
  UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_IMPLEMENTATION_AND_TEST_PLAN.md  # this file

  interfaces/
    IUniswapV4SingleStandardExchangeBufferConstantProductHook.sol
      // extends / documents: IStandardExchangeIn, IStandardExchangeOut,
      // IBasicVault, IStandardVault + product LP/hook surface

  UniswapV4SingleStandardExchangeBufferConstantProductHookRepo.sol
  UniswapV4SingleStandardExchangeBufferConstantProductHookCommon.sol
  UniswapV4SingleStandardExchangeBufferConstantProductHookMath.sol      # optional
  UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol  # optional
  UniswapV4SingleStandardExchangeBufferConstantProductHookTarget.sol    # LP + SE In/Out + vault views + hooks
  UniswapV4SingleStandardExchangeBufferConstantProductHook.sol          # mined entry
  UniswapV4SingleStandardExchangeBufferConstantProductHook_FactoryService.sol
```

### 2.2 Option B — Hook Diamond (size / reuse preferred when factory ready)

```text
# Shared infra (may live under crane or contracts/hooks/uniswap/v4/factory/)
  UniswapV4HookDiamondFactory.sol   # or generalized DiamondPackageCallBackFactory:
                                    #   - salt WITHOUT package address
                                    #   - mine / accept premined salt for V4 flags
                                    #   - CREATE2/CREATE3 proxy at flag address

# This package
  interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHook.sol
  *HookRepo.sol / *HookCommon.sol / *HookMath|ClaimLib.sol
  facets/  (or targets used as facets)
    ...HooksFacet / ...LiquidityFacet / ...SeExchangeFacet / ...VaultViewsFacet / ...LpErc20Facet
  *HookDFPkg.sol   # facet cuts + initAccount only — NOT in deploy salt
  *Hook_FactoryService.sol  # deploy via Hook Diamond Factory + mine flags
```

**Forbidden:** vault-registry `deployPkg` as the hook instance path; package address **in** salt; post-deploy upgrade of live hook instances (v1).

**Note:** Option B **cannot** wire generic ERC-4626 SE In/Out facet *logic* for this product — only the **selectors**/interface. CP + virtual pair + buffer-last must live in package-specific facet code.

**Tests (canonical names):**

```text
# Package-adjacent TestBase (LOCKED)
contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/
  TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook.sol

test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/
  UniswapV4SingleStandardExchangeBufferConstantProductHook_Deploy.t.sol
  UniswapV4SingleStandardExchangeBufferConstantProductHook_Deposit.t.sol
  UniswapV4SingleStandardExchangeBufferConstantProductHook_ZapIn.t.sol
  UniswapV4SingleStandardExchangeBufferConstantProductHook_Withdraw.t.sol
  UniswapV4SingleStandardExchangeBufferConstantProductHook_ZapOut.t.sol      # withdrawSingle — package differentiator
  UniswapV4SingleStandardExchangeBufferConstantProductHook_Swap.t.sol
  UniswapV4SingleStandardExchangeBufferConstantProductHook_SeExchange.t.sol  # IStandardExchangeIn/Out vs book previews
  UniswapV4SingleStandardExchangeBufferConstantProductHook_VaultViews.t.sol  # IBasicVault + IStandardVault + ERC165
  UniswapV4SingleStandardExchangeBufferConstantProductHook_Fees.t.sol        # D19 + D57 + D72 + D61
  UniswapV4SingleStandardExchangeBufferConstantProductHook_Permit2.t.sol
  UniswapV4SingleStandardExchangeBufferConstantProductHook_Yield.t.sol       # yield → virtual pair mid + D57 (D67)
  UniswapV4SingleStandardExchangeBufferConstantProductHook_AmountOrder.t.sol # currency0 = lower address; ctor order ≠ sort
  UniswapV4SingleStandardExchangeBufferConstantProductHook_Adversarial.t.sol # reentrancy + donation + feeTo + SE mid-zap revert

test/foundry/fork/base_main/hooks/uniswap/v4/standardExchange/constantProduct/single/
  UniswapV4SingleStandardExchangeBufferConstantProductHook_Base.t.sol

test/foundry/fork/robinhood_4663/hooks/uniswap/v4/standardExchange/constantProduct/single/
  UniswapV4SingleStandardExchangeBufferConstantProductHook_Robinhood.t.sol
```

---

## 3. Asymmetry implementor card (do not forget)

| Topic | Dual | This package |
|-------|------|--------------|
| Inventory | SE₀ shares + SE₁ shares | **rawToken balance** + **SE shares** |
| Effective \(x,y\) | claim₀, claim₁ | **raw face**, **virtual pair reserve** (SE claim), pool-ordered |
| Free pair | N/A as book | **Not the book** — refund dust only |
| Buffer | Both pair tokens | **pairToken only**; **buffer-last** (O13) |
| Raw path | N/A | Face amounts; no claim-in |
| Pair path | Claim-in both legs | Claim-in / claim-out vs **virtual pair reserve** only (D78) |
| Withdraw | Pro-rata both SE → unwrap both | Pro-rata raw + SE → unwrap pair only |
| Zap-out | Not in dual v1 | **Required** — quote residual **pre-buffer**; sell **100%** residual (PRD §4.6) |
| SE fee DoD | Buffer routes (dual D70) | **Orthogonal** — product = D19+D57; test SE = ERC-4626 wrapper only |
| Binding | se0,t0,se1,t1 | se, pairToken, rawToken |
| currency0 | dual pool tokens sorted | **lower address** of raw vs pair |
| LP prefix | `DSEBCP-` | `SSEBCP-` |
| Salt namespace | `uv4-dual-se-buffer-constant-product-hook-` | `uv4-single-se-buffer-constant-product-hook-` |

---

## 4. Normative helpers (implement early)

### 4.1 Effective reserves — raw face × **virtual pair reserve**

```text
// PRD §4.1 — INTENTIONAL INVENTORY
seBal   = IERC20(SE).balanceOf(hook)                 // SE shares
rawBal  = IERC20(rawToken).balanceOf(hook)           // raw face reserve

// VIRTUAL PAIR RESERVE (only pair-side CP reserve — D15)
// Free pairToken.balanceOf(hook) is NOT the book (D71)
virtualPairReserve = seClaim
  = previewExchangeIn(SE, seBal, pairToken)          // fee-inclusive SoT (D73)

// currency0 = lower address(raw, pair); currency1 = higher
if currency0 == rawToken:
    x, y = rawBal, virtualPairReserve
else:
    x, y = virtualPairReserve, rawBal

xN = toWad(x, decimals(currency0))
yN = toWad(y, decimals(currency1))
kProduct = xN * yN

live        = x > 0 && y > 0
zapEligible = live && totalSupply > MINIMUM_LIQUIDITY   // D79; Uni V2 locked dust
```

**Views:** `rawReserve()`, `seClaimSupply()` (= virtual pair reserve), `reserveCurrency0/1()`, `currency0()`/`currency1()`.

**Never cache** mid/k as product pricing state except Repo `kLast`. Re-read when next step needs post-inventory state (O11). **Do not** re-quote CP mid-flight after buffer (O13).

### 4.0 Buffer-last sequencing (O13) — all paths that buffer pair

```text
1) Quote all CP / residual / zap-split amounts on PRE-BUFFER book
   (raw face × virtual pair reserve)
2) Execute non-buffer moves (pull raw, unwrap SE→pair, pays) as needed
3) Buffer pairToken → SE  // FINAL SE inventory step that lands virtual reserve
4) Mint user LP (if path mints) and/or set kLast from POST-BUFFER effective reserves
```

Buffering must **not** reprice an already-solved swap/zap residual.

### 4.2 Claim-in / claim-out (D78) — pair side only

```text
// Buffer claim-in for raw pair amountIn (NEVER treat shares as claim)
sharesOutPreview = previewExchangeIn(pairToken, amountInRaw, SE)
claimIn = previewExchangeIn(SE, sharesOutPreview, pairToken)
// Forbidden: claimIn := amountInRaw when usage fee > 0 without SE preview
// Forbidden: claimIn := sharesOutPreview (unit mismatch)

// Invert buffer for exact-out: raw amountIn such that claimIn_preview >= requiredClaimIn (ceil)
// Prefer closed-form if SE provides; else bounded invert keeping preview==exec within MAX_DUST_WEI=10
// Pure unbounded binary search as primary product law forbidden if closed form exists

// Unwrap claim-out / share math for swap-out and zap residual:
// Prefer exchangeOut(SE→pair) with fee-inclusive preview for exact pair out
// Withdraw pro-rata: exchangeIn(SE→pair) on seOut shares
```

### 4.3 ConstProdUtils wiring

| Op | Function | Args |
|----|----------|------|
| Exact-in CP | `_saleQuote` | amountIn = **claimIn** (pair side) or **raw face** (raw side); reserves wad; fee 300/100_000 |
| Exact-out CP | `_purchaseQuote` | amountOut; reserves; 300/100_000 → required in (ceil) |
| Zap-in split | `_swapDepositSaleAmt` | amountIn & saleReserve same units (prefer wad); 300/100_000 |
| Protocol LP | `_calculateProtocolFee` **generic** | totalSupply, newK, kLast, ownerFeeShare |
| ownerFeeShare | `dexFeeWad * 100_000 / 1e18` floor | **no product max** (D82) |
| kLast | `xN * yN` wad product | overflow accepted (D83) |

### 4.4 SE I/O matrix (PRD §4.5)

| Path | Call |
|------|------|
| Buffer pair → SE | `exchangeIn(pair → SE)`; minOut = tight fee-inclusive preview |
| Unwrap SE → pair (pro-rata withdraw / zap realize) | `exchangeIn(SE → pair)` of seOut shares |
| Unwrap SE → pair (swap-out / zap residual) | `exchangeOut(SE → pair)` peer as dual/wrapper settle |

Prefer **pretransfer** + `pretransferred=true` when SE supports it. SE deadline = `block.timestamp` when required. User liquidity `deadline` is separate.

### 4.5 First vs subsequent mint

```text
// After optional D57 protocol mint step:
if totalSupply == 0:
  lp = sqrt(xN * yN) - MINIMUM_LIQUIDITY
  require lp > 0  // equiv: sqrt >= MINIMUM_LIQUIDITY
  mint MINIMUM_LIQUIDITY to address(0)
  mint lp to `to`
else:
  // including MINIMUM_LIQUIDITY-only residual (D76)
  lp = min(dxN/xN, dyN/yN) * totalSupply   // post-protocol-mint supply
  // never geometric re-bootstrap
```

### 4.6 Zap-out core (PRD §4.6) — implement as shared library path

```text
require zapEligible (D79)
require tokenOut == rawToken || tokenOut == pairToken

// 1) D57 protocol mint if fee-on (before burn) — D72
// 2) S = totalSupply; rawUser = rawBal * lp / S; seUser = seBal * lp / S
// 3) burn lp
// 4) pairUser = unwrap(seUser)   // realize user SE slice to free pair
// 5) remaining book PRE-BUFFER:
//      rawRemain = rawBal - rawUser
//      seRemain  = seBal - seUser
//      seClaimRem = virtualPairReserve(seRemain)   // quote basis

// 6) QUOTE residual sell ONCE on pre-buffer remaining book (O13) — no mid-step re-quote
if tokenOut == pairToken:
  // sell 100% rawUser against remaining book (exact-in raw→pair, D19+D78)
  pairFromSwap = saleQuote(rawUser, rawRemain, seClaimRem, 300, 100_000)
  execute: unwrap claimOut from seRemain → pair; amountOut = pairUser + pairFromSwap
else:
  // sell 100% pairUser against remaining book (exact-in pair→raw, claim-in)
  claimIn = preview_buffer_pair_to_claim(pairUser)
  rawFromSwap = saleQuote(claimIn, seClaimRem, rawRemain, 300, 100_000)
  // EXECUTE: pay rawFromSwap first; BUFFER pairUser LAST (O13)
  amountOut = rawUser + rawFromSwap

require amountOut >= minAmountOut
emit ZapSwap(...); emit WithdrawSingle(...)
refund free pair dust to msg.sender (D71)
update kLast post-op when fee-on
// Uni V2 locked dust + minAmountOut (D34a) — no max-impact guard
```

**Internal swaps (zap-in and zap-out):** SE helpers only — **no** PoolManager unlock (O4). Emit **ZapSwap** (D77).

### 4.7 Algorithm pointers (PRD sections)

| Path | PRD |
|------|-----|
| Effective reserves | §4.1 |
| Public swap exact-in/out | §4.2.1–§4.2.4 |
| Proportional deposit | §4.3 |
| Zap-in | §4.4 |
| SE I/O | §4.5 |
| Zap-out | §4.6 (+ invariants §4.6.5) |
| Proportional withdraw | §4.7 |
| Previews | §4.8 |
| Protocol fee timing | §7.4 / D72 |
| Permit2 packing | §7.3 |

---

## 5. Implementation phases

### Phase 0 — ERC-4626 **wrapper** SE thin gate (D60 / D66) **[hook TestBase gate only]**

**Not** “implement an ERC-4626 vault.” **Not** dual Phase 0 ownership. **Not** invent SE exit fees.

1. Confirm existing `contracts/vaults/standard/erc4626/` **wrapper SE** deploys via production path (manager/registry as peers do).  
2. Confirm closed-form **pairToken ↔ SE** buffer and unwrap (exact-in + exact-out) work.  
3. Confirm `previewExchangeIn` / `previewExchangeOut` **preview == execution** (D73). Dilution on share-mint is expected; trust SE SoT.  
4. Hook tests deploy **only** this production ERC-4626 wrapper SE wrapping mintable **pairToken** — **no multi-SE matrix**.  

**Exit criteria:** Package-adjacent TestBase can deploy real ERC-4626 wrapper SE, buffer pair→SE and unwrap SE→pair both directions with preview fidelity.

---

### Phase A′ — Deploy architecture choice

1. Default **Option A** monomorph unless Hook Diamond Factory is available / size forces Option B.  
2. If Option B: implement or consume **Uniswap V4 Hook Diamond Factory** (Crane-level OK):  
   - salt = binding + mineNonce **only** (no package address in salt)  
   - mine until address flags match D54  
   - accept premined salt  
   - postDeploy removes upgrade path for v1  
3. Document choice in TestBase comments.

### Phase A — Skeleton (compile + bindings)

1. Create §2 file map for chosen option.  
2. Interface = PRD §7.1 + **§7.6** (SE In/Out, BasicVault, StandardVault) + LP/hook surface.  
3. Bindings: `(poolManager, feeOracle, standardExchange, pairToken, rawToken)`.  
4. Validation D6: non-zero; `rawToken ≠ pairToken`; `pairToken ∈ SE.vaultTokens()`; `rawToken ≠ address(SE)`.  
5. Common: `currency0` = **lower address**(raw, pair), `currency1` = higher; map currency → raw or SE-leg; decimals for wad.  
6. LP metadata: prefix **`SSEBCP-`** + pool currency symbols (D40).  
7. `permit2()` constant well-known address.  
8. Repo: ERC-20 balances/allowances/totalSupply; `kLast`; one-pool flag / PoolId; reentrancy; vaultFeeTypeIds/contentsId if needed.  
9. Hook permissions bitmask D54; disabled callbacks revert; `beforeAddLiquidity` always reverts.  
10. `beforeInitialize`: currencies match + fee=0 + **set one-pool flag**; second success path reverts (D69).  
11. FactoryService: salt namespace + binding + mineNonce; mine flags D54; idempotent; `isExpectedHook` factory-only (D80). Option B: no package in salt.  
12. `forge build` green.

---

### Phase B — Reserves + Math + SE I/O

1. `rawReserve()`, `seClaimSupply()` (**virtual pair reserve**), `currency0/1()`, `reserveCurrency0/1()`, `isLive()`, `isZapEligible()`.  
2. ConstProdUtils-backed exact-in/out helpers with D19 (300/100_000).  
3. `preview_buffer_pair_to_claim` / invert helpers vs virtual reserve (D78 / O14).  
4. `_bufferPair` prefer pretransfer; tight minOut — used **last** on buffer paths (O13).  
5. `_unwrapSeShares` / `_unwrapExactPairOut` per §4.5.  
6. User deadline vs SE `block.timestamp` helpers.  
7. Unit tests optional for pure math; integration preferred.

---

### Phase C — Proportional deposit / withdraw (ERC-20 path)

1. `nonReentrant` on all liquidity entrypoints (D58).  
2. `deposit`: pull both pool-order amounts; minLpAmount + deadline.  
3. D57 protocol mint **pre-intake** when fee-on (D72); first mint no protocol mint while `kLast==0`.  
4. First mint: hold raw; **buffer pair last**; geometric on post-buffer reserves; MINIMUM_LIQUIDITY → `address(0)` (locked dust).  
5. Subsequent: clamp to ratio; refund excess to **msg.sender** (not `to`); intake raw; **buffer pair last**; ratio mint (D76).  
6. Re-read **after buffer** before mint / `kLast` (O11/O13) — not mid-swap re-quote.  
7. `withdraw`: D57 then pro-rata raw + SE shares; transfer raw; unwrap pair; minAmount0/1 + deadline.  
8. Residual free **pair** → refund msg.sender (D71); raw intentional inventory stays.  
9. Events `Deposit` (with used0/used1 per PRD §7.5) / `Withdraw`.  
10. Previews include fee-on dilution (D61); preview == execution within dust.

---

### Phase D — Swaps (V4) + SE In/Out compatibility

1. Shared book swap core used by **both** V4 `beforeSwap` and `IStandardExchangeIn`/`Out` (same D19+D78+O13).  
2. V4 path: take → quote pre-buffer → buffer/raw → unwrap/pay → settle + `BeforeSwapDelta`.  
3. SE path: pull/pretransfer → same quote/execute → pay `recipient`; **no PoolManager** (D85).  
4. Exact-in / exact-out both directions per PRD §4.2.1–§4.2.4.  
5. `previewSwapExactIn/Out` and `previewExchangeIn/Out` match for same route (within dust).  
6. Reject SE share / unsupported tokens as SE routes.  
7. Live required; insufficient reserve → full revert.  
8. Hermetic pool init: fee=0, tickSpacing=60, 1:1 mid plumbing. Deposit may precede init (D59).  
9. **Do not** implement LP mint/burn inside `exchangeIn`/`exchangeOut`.

---

### Phase E — Zap-in (`depositSingle`)

1. Gate **D79** (not merely live).  
2. D57 pre-zap product (D72).  
3. O1a split via `_swapDepositSaleAmt(..., 300, 100_000)` on correct sale reserve (raw or **virtual pair** side).  
4. Internal swap quoted pre-buffer (D78 / face-raw); **no PoolManager** (O4); emit **ZapSwap**.  
5. Proportional add remainder + proceeds; **buffer pair last** (O13); subsequent mint on post-buffer reserves.  
6. Clamp/refund residual after SE drift (O1a).  
7. `previewDepositSingle` + **strict SE-aware `previewZapSplit`** (D65).  
8. Event `DepositSingle.amountIn` = **full pull** (D81).  

---

### Phase F — Zap-out (`withdrawSingle`) **[package differentiator]**

1. Gate **D79**.  
2. Implement PRD §4.6 + plan §4.6 exactly (shared helpers with Phase D internal swap).  
3. **Quote residual once on pre-buffer remaining book**; **buffer last** when residual path buffers pair (O13).  
4. 100% residual sell only — **no** optimal multi-step, **no** max-impact (D34a); Uni V2 locked dust backstop.  
5. `minAmountOut` + deadline; natural CP/SE revert if thin book.  
6. Events `WithdrawSingle` + `ZapSwap`; `kLast` post-op.  
7. `previewWithdrawSingle` simulates D57 + full residual path; preview == exec (D73).  
8. Post-op invariants PRD §4.6.5 (free pair ≤ dust; no stranded user raw; remaining LPs solvent).  
9. Tests: both `tokenOut` directions; MIN residual reverts; last-LP severe impact / revert; preview fidelity.

---

### Phase G — Protocol fee + fee views + vault discovery polish

1. Wire oracle `dexSwapFeeAndFeeToOfVault(address(this))` — growth WAD **not** trading fee.  
2. `kLast` updates post-op; fee-off → `kLast=0`.  
3. Yield growth fee-eligible (D67).  
4. Public views: feeOracle, tradingFeePercent/Denominator, dexSwapFeeAndFeeTo (or split), kLast.  
5. feeTo mint failure reverts whole op (D75).  
6. Fee-on previews for deposit / depositSingle / withdraw / **withdrawSingle** (D61).  
7. **IBasicVault:** vaultTokens / reserveOfToken / reserves per D86 (pair reserve = virtual).  
8. **IStandardVault:** vaultFeeTypeIds / contentsId / vaultTypes / vaultConfig per D87.  
9. ERC165 `supportsInterface` for SE In/Out + Basic + Standard + product ids.

---

### Phase H — Permit2

1. Constant well-known Permit2; **no** ctor/salt.  
2. Implement PRD §7.3 packing **in Target** (externalize only if size forces — O15).  
3. Shared `_deposit` / `_depositSingle` cores after pull.  
4. **No** Permit2 on withdraw / withdrawSingle.  
5. Tests: all four deposit styles + wrong order / bad sig / expired / insufficient allowance.

---

### Phase I — TestBase + hermetic suite

1. Package-adjacent `TestBase_…`: `CraneTest` → `IndexedexTest` → vault components / ERC-4626 **wrapper** SE deploy → this FactoryService + V4 PM.  
2. Mintable raw + pair ERC-20s; **only** one production ERC-4626 wrapper SE on pair.  
3. Real Permit2 at well-known address (deploy bytecode if needed).  
4. Fee oracle: non-zero dex growth fee + receivable feeTo; fee-off path; non-receivable feeTo adversarial.  
5. SE integration under actual wrapper SE fee model (dilution OK); preview==exec.  
6. Full §8.2 matrix green (incl. adversarial O16).

---

### Phase J — Forks (D64 / D74)

1. Base mainnet fork: prefer live PM + Permit2 + fee oracle; else deploy production-equivalent on fork.  
2. Robinhood Chain **4663** fork: same rule.  
3. **May deploy** mintable raw/pair + ERC-4626 wrapper SE on fork.  
4. Smoke: deposit → swap → withdraw; include at least one zap-in and one zap-out.

---

### Phase K — Polish

1. NatSpec: LP vs SE shares; **virtual pair reserve**; amount0 = currency0 (lower address); raw vs pair asymmetry; buffer-last; dexSwapFee naming; zap-out impact via previews.  
2. `forge build --sizes` against **real CREATE3/runtime limits**.  
3. Size mitigations if needed (ClaimLib / Math / Permit2 externalization) without dropping §7.1.  
4. Confirm no `isExpectedHook` on hook ABI.  
5. Confirm no DETF imports in production sources.

---

## 6. Locked constants (implementor card)

| Item | Value | PRD |
|------|--------|-----|
| Product name | `UniswapV4SingleStandardExchangeBufferConstantProductHook` | D1 |
| MINIMUM_LIQUIDITY | `1000` → `address(0)` | D25 |
| Trading fee | `feePercent=300`, `feeDenominator=100_000` (0.3%) | D19 |
| Pool fee | `0` | D8 |
| Normalize | O3 `toWad` | D39 / O3 |
| Missing decimals | 18 | D39 |
| LP decimals | 18 | D23 |
| LP symbol prefix | `SSEBCP-{c0}-{c1}` | D40 |
| Salt namespace default | `uv4-single-se-buffer-constant-product-hook-` | D52 |
| Permit2 | `0x000000000022D473030F116dDEE9F6B43aC78BA3` | §7.3 |
| MAX_DUST_WEI | 10 | D47 |
| Hook flags | BEFORE_INITIALIZE \| BEFORE_ADD_LIQUIDITY \| BEFORE_SWAP \| BEFORE_SWAP_RETURNS_DELTA | D54 |
| Pool init tests | tickSpacing=60, 1:1 sqrtPrice | D58P |
| kLast | wad product `xN*yN` | D63 |
| ownerFeeShare | `dexFeeWad * 100_000 / 1e18` floor; no max | D62 / D82 |
| Repo slot (suggested) | `indexedex.hooks.uv4.single.se.buffer.constant.product.storage` | plan |

---

## 7. FactoryService (normative)

```solidity
function deployHook(
    ICreate3FactoryProxy create3Factory,
    IPoolManager poolManager,
    IVaultFeeOracleQuery feeOracle,
    address standardExchange,
    address pairToken,
    address rawToken,
    string memory saltNamespace  // empty → DEFAULT
) internal returns (address hook);
```

- Salt: `hash(namespace, poolManager, feeOracle, se, pairToken, rawToken, mineNonce)` — **no** Permit2.  
- Idempotent: expected binding at predicted address → return existing; wrong code → revert.  
- `isExpectedHook`: poolManager + feeOracle + se + pairToken + rawToken — **factory/internal only** (D80).  

Ctor: `(poolManager, feeOracle, standardExchange, pairToken, rawToken)`.

---

## 8. Testing plan

### 8.1 Rules

- Production-first (IndexedEx AGENTS.md / indexedex-testing / crane-testing).  
- **No** mock hook / SE SUT / fee oracle / PoolManager / Permit2.  
- **Only** real ERC-4626 **wrapper** SE wrapping pairToken (D60/D63T) — no multi-SE matrix.  
- Mintable ERC-20s for raw + pair OK (non-SUT harness); forks may deploy same.  
- Hermetic **and** Base + Robinhood 4663 forks (D64/D74).  
- **No** DETF package dependency for merge.  
- Package-adjacent TestBase.

### 8.2 Minimum DoD matrix

| ID | Case | PRD |
|----|------|-----|
| Ph0 | ERC-4626 wrapper SE deployable; pair↔SE routes; preview==exec | D60/D66/D73 |
| D1 | Deploy rejects zero / pair∉vaultTokens / raw==pair / raw==SE / zero feeOracle | D5–D6 |
| D2 | Mine flags match permissions | D54 |
| D3 | Idempotent redeploy same binding (+ feeOracle) | D55 |
| D4 | Salt namespace / LP prefix (`SSEBCP` / `uv4-single-se-…`) | D52/D40 |
| I1 | beforeInitialize wrong pair / non-zero fee reverts | D58P |
| I2 | **Second initialize reverts** | D69 |
| I3 | beforeAddLiquidity reverts | D9 |
| I4 | Init plumbing; deposit without prior init OK | D59 |
| A1–A2 | `currency0` = lower address; amount0 = currency0 when ctor order ≠ sort | O8/D7 |
| VR1 | CP/mid uses `seClaimSupply` (virtual pair), **not** free pair balance | D15/§4.1 |
| P1 | First proportional deposit; MIN liq to address(0) locked; live | D26/D25 |
| P2 | First mint reverts if geometric &lt; MINIMUM_LIQUIDITY | D26 |
| P3 | Subsequent clamp+refund to msg.sender; buffer-last; preview==exec | D28/O13 |
| P4 | amount0==0 or amount1==0 reverts on deposit | §4.3 |
| P5 | minLpAmount / deadline reverts | D36 |
| P6 | After full user exit (only MIN): next deposit uses **subsequent** mint | D76 |
| Zi1 | depositSingle both directions when zap-eligible | D29 |
| Zi2 | previewZapSplit strict == exec (SE-aware D78) | D65/D78 |
| Zi3 | depositSingle reverts empty book | D79 |
| Zi4 | depositSingle reverts when only MINIMUM_LIQUIDITY residual | D79 |
| Zi5 | ZapSwap + DepositSingle full pull amountIn; buffer-last | D77/D81/O13 |
| Zi6 | minLp / deadline on depositSingle | D36 |
| Zo1 | withdrawSingle both tokenOut when zap-eligible | D33 |
| Zo2 | previewWithdrawSingle == exec; residual quote pre-buffer | D45/O13 |
| Zo3 | withdrawSingle reverts empty / MIN residual | D79 |
| Zo4 | 100% residual sold; ZapSwap + WithdrawSingle; buffer last when pair residual sold | D34/D77/O13 |
| Zo5 | Thin book: minAmountOut fail or natural CP revert; locked dust backstop | D34a/D25 |
| Zo6 | Post-zap free pair ≤ dust; no stranded user raw | §4.6.5 |
| Zo7 | minAmountOut / deadline on withdrawSingle | D36 |
| S1–S2 | V4 swap exact-in/out both ways; preview==exec; D78 vs virtual pair | D78/D19/D73 |
| S3 | insufficient reserve reverts | §4.2 |
| S4 | mid from effective reserves not sqrtPrice | D58P |
| S5 | LPs benefit from volume (fee retention) | D19 |
| SE1 | `exchangeIn` both raw↔pair directions; preview==exec | D84/D85/§7.6 |
| SE2 | `exchangeOut` both directions; preview==exec | D84/D85 |
| SE3 | SE In/Out preview matches V4 swap preview for same amounts | §7.6.2 |
| SE4 | SE share / bad tokens → UnsupportedRoute | §7.6.2 |
| SE5 | SE In/Out does **not** mint/burn LP | D85 |
| BV1 | vaultTokens = [currency0, currency1]; reserves pool-order | D86 |
| BV2 | reserveOfToken(pair) = seClaimSupply (virtual), not free pair | D86/D15 |
| SV1 | vaultTypes includes SE In/Out + Basic + Standard ids | D87 |
| SV2 | supportsInterface true for required ids | §7.6.5 |
| W1–W2 | proportional withdraw raw + unwrap pair; pool-order; min/deadline | D32/O5/O6 |
| F1 | SE integration preview==exec under wrapper SE model | D73 |
| F2 | Protocol growth fee-on: mint to feeTo; kLast wad updates post-buffer | D57/O13 |
| F3 | Fee-off: no protocol mint; kLast=0 | D57 |
| F4 | D72: deposit does not tax own capital as growth in same op | D72 |
| F5 | Fee-on preview==exec deposit/single/withdraw/withdrawSingle | D61 |
| F6 | Mixed decimals: wad kLast + CP correct | D63 |
| Y1 | Yield moves virtual pair reserve / mid without swap | D18 |
| Y2 | Yield → next mint/burn mints protocol LP | D67 |
| R1–R5 | ERC-20 + Permit2 all four deposit styles | §7.3 |
| R6 | Permit2 bad sig / wrong batch order / expired / low allowance | §7.3 |
| N1 | Nested reenter deposit/withdraw/withdrawSingle reverts | D58 |
| N2 | Donation of raw or SE shares dilutes LPs (accepted) | D49 |
| N3 | Non-receivable feeTo: protocol mint reverts whole liquidity op | D75 |
| N4 | SE revert mid-zap: full tx reverts; no partial inventory | O16 |
| E1 | Required surface: currency0/1, fee views, kLast, tradingFee*, ERC-20 | D68 |
| E2 | Events Deposit/DepositSingle/Withdraw/WithdrawSingle/ZapSwap | §7.5 |
| FK1 | Base fork smoke deposit→swap→withdraw (+ zap smoke); may deploy tokens/SE | D64/D74 |
| FK2 | Robinhood 4663 fork smoke same | D64/D74 |

### 8.3 Commands

```bash
forge build
forge build --sizes

# Hermetic suite
forge test --match-path 'test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/*' -vv

# Forks (use repo profiles / RPC env as established for Base + 4663)
forge test --match-path 'test/foundry/fork/**/hooks/uniswap/v4/standardExchange/constantProduct/single/*' -vv
```

---

## 9. Risks & mitigations

| Risk | Mitigation |
|------|------------|
| Contract size (hook + ERC-20 + SE + Permit2 + fees + zap-out) | ClaimLib/Math; ConstProdUtils; `--sizes` vs real CREATE3/runtime limits; externalize Permit2 only if needed (O15) |
| Agent treats package as dual (two SE claims) | §3 asymmetry card; raw face × virtual pair; A1/A2 + VR1 |
| Agent uses free pair balance as CP reserve | D15 / VR1 tests; `seClaimSupply` only |
| Agent uses face pair amountIn in CP under SE dilution | D78 helpers + wrapper SE dilution in hermetic tests |
| Agent re-quotes CP after buffer mid-path | O13 buffer-last; Zo2/Zi5/S* sequencing |
| Agent treats SE shares as claimIn | Two-step preview only; unit mismatch test |
| Zap-out leaves stranded raw/pair | §4.6.5 invariants + Zo6 tests |
| Zap-out “optimizes” residual sell | Ban partial residual; D34a tests Zo4/Zo5 |
| fee-less zap / wrong split | ConstProdUtils O1a only |
| Multi-pool shared inventory | D69 hard flag |
| Zap after dust residual | D79 gate + Zi4/Zo3; Uni V2 locked dust |
| Protocol mint non-receivable feeTo | D75 + N3 adversarial |
| SE revert mid-zap partial state | N4 adversarial; nonReentrant |
| kLast overflow | Accepted D83; document scale limit |
| Permit2 packing drift | §7.3 byte-level tests |
| Over-building ERC-4626 Phase 0 | Thin verify only — do not invent exit fees or multi-SE matrix |
| Copy dual TestBase without remapping legs | Package-adjacent TestBase; single wrapper SE + raw/pair mintables |
| DETF creep | No DETF imports; independent TestBase (D62) |
| Greenfield incomplete ship | Do not merge until §10 DoD |

---

## 10. Definition of done

1. PRD **v1.3** product law for this package implemented (or waived only via PRD revision).  
2. This plan’s phases 0–K green; package at D2 path with §2 file map (Option A or B).  
3. Interface + implementation match PRD **§7.1** + **§7.6**; events **§7.5**; Permit2 **§7.3**; protocol fee **§7.4**.  
4. Uni V2-like fees: D19 trading + D57 growth. SE fees orthogonal.  
5. Effective book = **raw face × virtual pair reserve**; free pair not the book.  
6. D78; buffer-last (O13); D79; D69; D58.  
7. **Zap-out** §4.6 + D34a + Uni V2 locked dust + invariants §4.6.5.  
8. Factory: binding in salt; **no package in salt** if Option B; isExpectedHook factory-only.  
9. Phase 0 thin: ERC-4626 wrapper SE only.  
10. Hermetic §8.2 (incl. SE1–SE5, BV*, SV*, adversarial) + forks green.  
11. Size within real CREATE3/runtime limits (libs and/or Option B).  
12. NatSpec: virtual reserve; SE In/Out vs LP APIs; buffer-last; deploy shape.  
13. No DETF package required to merge.  
14. Proportional + zap APIs present — not collapsed into SE In/Out.

---

## 11. Explicit non-actions for coding agents

Do **not**:

- Subclass dual or single-wrapper contracts.  
- Treat SE shares as a pool currency.  
- Treat **free pairToken balance** as the pair-side CP reserve (use **virtual pair reserve** / SE claim only).  
- Buffer `rawToken` into any SE.  
- Re-quote CP mid-path **after** buffer (O13).  
- Ship fee-less CP or fee-less zap internal swaps (D19 always on swap/zap internal legs).  
- Put `isExpectedHook` on the hook interface.  
- Put Permit2 in ctor/salt.  
- Use binary search as primary zap/swap split law.  
- Invent InitPrice / one-sided book / multi-pool DoD.  
- Invent SE exit fees or multi-SE fee matrix for DoD (D70S demoted).  
- “Build ERC-4626 product” as Phase 0 — thin verify/deploy only.  
- Tax deposit capital as D57 growth in the same op (post-intake-only k).  
- Treat `previewZapSplit` / `previewWithdrawSingle` as disclosure-only.  
- Special-case yield out of D57.  
- Cap protocol fee WAD in product code.  
- Skip protocol mint on feeTo failure (must revert).  
- Geometric re-bootstrap while `totalSupply > 0`.  
- Zap-in or zap-out when only MINIMUM_LIQUIDITY residual.  
- Partial residual sell or max-impact guards on zap-out (D34a).  
- Require DETF packages for hermetic DoD.  
- Mock the hook / SE SUT / manager / fee oracle / PoolManager / Permit2.  
- Collapse proportional/zap LP into `exchangeIn`/`exchangeOut` only.  
- Put DFPkg address in deploy salt (Option B).  
- Reuse generic ERC-4626 SE facet **logic** for book swaps (selectors only).  
- Post-deploy diamondCut on live hooks (v1).  
- Use vault-registry `deployPkg` as the hook instance path.

---

## 12. Suggested coding order (single agent or handoff)

```text
0. Phase 0 thin: ERC-4626 wrapper SE verify/deploy in TestBase
0b. Phase A′ deploy Option A vs B (Hook Diamond Factory if size/reuse)
1. Phase A skeleton + FactoryService + interface (currency0/1 + §7.6)
2. Phase B reserves (virtual pair) / math / SE I/O / buffer-last helpers
3. Phase C proportional deposit/withdraw + hermetic smoke
4. Phase D V4 swaps + SE In/Out shared core
5. Phase E zap-in (buffer-last)
6. Phase F zap-out          # quote pre-buffer; buffer last; product differentiator
7. Phase G protocol fee + IBasicVault/IStandardVault/ERC165
8. Phase H Permit2 (Target / LP facets)
9. Phase I full hermetic matrix + SE/vault + adversarial
10. Phase J forks (may deploy tokens/SE)
11. Phase K sizes/NatSpec (flip to Option B if size fails)
```

---

## 13. Revision log (this plan)

| Date | Change |
|------|--------|
| 2026-08-04 | **Initial plan from PRD v1.1:** greenfield single SE + raw CP; Phase 0 ERC-4626 hard gate; D70S both-direction SE fees; claim-in pair side; zap-in + **zap-out** phases; dual pattern-copy without subclass; Base+4663 forks; Permit2 §7.3; DoD matrix Zo*; implementor SoT. |
| 2026-08-04 | **v1.2 conversation locks:** Uni V2 product fees only; SE fees orthogonal (D70S demoted); **virtual pair reserve** explicit; **buffer-last / quote-before-buffer** (O13); thin Phase 0 ERC-4626 **wrapper** SE only; no multi-SE matrix; no dual Phase 0 gate; `currency0`/`currency1`; Uni V2 locked dust; adversarial DoD; package-adjacent TestBase; Permit2 in Target; forks may deploy tokens/SE; real size limits. |
| 2026-08-04 | **v1.3 vault/SE + deploy flex:** IStandardExchangeIn/Out + IBasicVault + IStandardVault required; SE = direct book swap not LP; Option A monomorph vs Option B Hook Diamond (salt without package, premined V4 flags); shared swap core Phase D; tests SE*/BV*/SV*. |

---

## 14. Summary for coding agents

```text
SoT product: PRD v1.3
SoT implement: THIS plan
Name: UniswapV4SingleStandardExchangeBufferConstantProductHook
Path: contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/
Shape: Option A CREATE3 monomorph OR Option B Hook Diamond (no package in salt)
Reserves: raw face × VIRTUAL PAIR RESERVE (SE claim) — not free pair
Fees: Uni V2-like 0.3% swap (D19) + protocol kLast growth (D57); SE fees orthogonal
Compat: IStandardExchangeIn/Out (book swap) + IBasicVault + IStandardVault
LP APIs: deposit / depositSingle / withdraw / withdrawSingle remain first-class
currency0: lower address(raw, pair)
Sequencing: quote first → buffer pair last → mint LP / kLast
Zap-out: quote residual pre-buffer → sell 100% → buffer last if needed
Test SE: ONLY ERC-4626 wrapper SE
Never: free-pair-as-book; collapse LP into exchangeIn; package-in-salt;
       mid-path re-quote after buffer; buffer rawToken; mock SUT
```
