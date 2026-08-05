# Implementation & Test Plan: Uniswap V4 Dual Standard Exchange Buffer Constant Product Hook

> **Deploy path superseded.** Instance deploy is now the **hook diamond package** path.  
> Implementors for package/factory work:  
> [`UNISWAP_V4_DUAL_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_HOOK_FACTORY_IMPLEMENTATION_AND_TEST_PLAN.md`](./UNISWAP_V4_DUAL_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_HOOK_FACTORY_IMPLEMENTATION_AND_TEST_PLAN.md)  
> Refactor PRD: [`UNISWAP_V4_DUAL_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_HOOK_FACTORY_REFACTOR_PRD.md`](./UNISWAP_V4_DUAL_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_HOOK_FACTORY_REFACTOR_PRD.md)  
> CREATE3 monomorph / HookMiner sections below are **historical** only.

**PRD (product law SoT):** [`UNISWAP_V4_DUAL_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_PRD.md`](./UNISWAP_V4_DUAL_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_PRD.md) (**v3.12** — deploy superseded by hook-factory refactor)  
**This plan:** monomorph-era phases; **do not** implement CREATE3 instance deploy from here.  
**Package:** `contracts/hooks/uniswap/v4/standardExchange/dual/`  
**Date:** 2026-08-03 (deploy supersession 2026-08-05)  
**Status:** **Partially superseded** — product math still informative; **deploy/package path = hook-factory plan**.

**Authority**

| Layer | Role |
|-------|------|
| PRD v3.12 | Product law (D1–D83, O1–O12, C tables, §4–§7, §9, §11, §17) |
| **This plan** | Implementor source of truth for phases, file rename, scaffold fix path, tests |
| Existing `dual/*.sol` | Non-authoritative scaffold (D56) — rewrite/rename in place allowed |
| Peer ConstProdUtils / single buffer hook | Formula + settle pattern-copy only |

**Read order for implementors**

1. PRD §0 terminology + §1.1 user story + §16 summary  
2. PRD §17 algorithm card  
3. **This plan** §1–§4 (scope, gaps, rename, phases)  
4. PRD §4.2 / §7 for normative detail when implementing a phase  

---

## 0. Why the prior plan was wrong

The draft `UNISWAP_V4_DUAL_BUFFER_PRICING_HOOK_IMPLEMENTATION_AND_TEST_PLAN.md` targeted **pre-v3.6 / v3.3-era** law and is **non-authoritative**. Material conflicts with PRD v3.12:

| Prior plan said | PRD v3.12 requires |
|-----------------|--------------------|
| Product name `UniswapV4DualBufferPricingHook` | **D1** `UniswapV4DualStandardExchangeBufferConstantProductHook` |
| Salt `uv4-dual-buffer-pricing-hook-`; LP `DBH-` | **D37** `uv4-dual-se-buffer-constant-product-hook-`; **O4** `DSEBCP-` |
| Fee-less CP + fee-less zap | **D29** 0.3% (`feePercent=300`, `feeDenominator=100_000`) on swaps **and** zap internal swap; ConstProdUtils `_saleQuote` / `_purchaseQuote` / `_swapDepositSaleAmt` |
| No protocol growth fee / `kLast` / feeOracle | **D57** + **D5** feeOracle ctor; wad `kLast` (**D63**); generic `ownerFeeShare` (**D62**); pre-buffer k on deposits (**D72**) |
| Multi-pool “discouraged” | **D69** hard-revert second `beforeInitialize` |
| Zap when “live” only | **D79** zap-eligible = live **and** `totalSupply > MINIMUM_LIQUIDITY` |
| Raw amountIn into CP | **D78** claim-in composition (CP on SE buffer claim delta) |
| Permit2 optional packing / witness OK | **§7.3** normative packing; **no witness**; dual batch **pool currency index order** |
| Permit2 may be ctor arg + salt | **C18** well-known only; **not** ctor arg; **not** salt |
| Hermetic only DoD | **D64** Base + Robinhood **4663** forks; **D74** deploy-if-missing |
| No ERC-4626 Phase 0 ownership | **D60 / D66** dual plan owns Phase 0 |
| Events optional | **§7.5** Deposit / DepositSingle / Withdraw / **ZapSwap** required |
| `isExpectedHook` on hook surface optional | **D80** factory/internal only — **not** §7.1 hook ABI |
| No nonReentrant | **D58** all liquidity entrypoints `nonReentrant` |
| Fee views optional | **D68 / §7.1** fee views + `kLast()` + trading fee constants + full ERC-20 **required** |

**Process rule:** implement from **this** plan + PRD v3.12 only. If this plan and PRD disagree, **PRD wins** and this plan must be patched.

---

## 1. Scope (v1 DoD)

Implement production-first package **`UniswapV4DualStandardExchangeBufferConstantProductHook`**:

1. Bind two SE vaults + two pair tokens + **PoolManager** + **feeOracle** (ctor immutables). Permit2 = Uniswap well-known constant.  
2. V4 pool currencies = bound pair tokens (address-sorted); pool fee **0**; product mid/depth from **SE claims**.  
3. **Constant product on claims** with **0.3% trading fee retained in reserves** (D29); **claim-in SE composition** (D78).  
4. Buffer pair→SE on deposit / swap-in / zap; unwrap SE→pair on withdraw / swap-out / zap out.  
5. Single fungible **ERC-20 LP** on the mined hook (decimals **18**).  
6. **deposit** (proportional dual-asset, clamp+refund) + **depositSingle** (internal zap when **zap-eligible**).  
7. **withdraw** pro-rata **SE share balances** (not claim-weighted) → unwrap both.  
8. Funding: ERC-20 `transferFrom` **and** Permit2 SignatureTransfer **and** AllowanceTransfer.  
9. Slippage: `minLpAmount` / `minAmount0`/`minAmount1` + `deadline` on liquidity.  
10. Protocol growth fee (D57): `kLast` wad product; mint protocol LP to `address(feeTo)` on mint/burn when fee-on.  
11. One V4 pool per hook instance (D69).  
12. Deploy: existing `create3Factory` + `HookMinerCreate3` + FactoryService (not vault registry; not DFPkg diamond).  

**Out of scope (v1):** Facet/DFPkg for hook; CL / native `modifyLiquidity`; InitPrice / one-sided book; single-asset **positions**; FoT/rebasing pair tokens; multi-pool inventory; hook Permit2 for swaps; yield exclusion from D57; product cap on protocol fee WAD; binary-search as primary swap/zap law; native ETH currency.

**Peer patterns (copy, do not inherit):**  
`contracts/hooks/uniswap/v4/standardExchange/UniswapV4BufferAndPricingHook*.sol` (settle / FactoryService / mine).  
**Math SoT:** `lib/crane/contracts/utils/math/ConstProdUtils.sol`.

---

## 2. File map (target)

```text
contracts/hooks/uniswap/v4/standardExchange/dual/
  UNISWAP_V4_DUAL_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_PRD.md
  UNISWAP_V4_DUAL_STANDARD_EXCHANGE_BUFFER_CONSTANT_PRODUCT_HOOK_IMPLEMENTATION_AND_TEST_PLAN.md  # this file

  interfaces/
    IUniswapV4DualStandardExchangeBufferConstantProductHook.sol

  UniswapV4DualStandardExchangeBufferConstantProductHookRepo.sol
  UniswapV4DualStandardExchangeBufferConstantProductHookCommon.sol
  UniswapV4DualStandardExchangeBufferConstantProductHookMath.sol   # thin wrappers / optional; prefer ConstProdUtils
  UniswapV4DualStandardExchangeBufferConstantProductHookTarget.sol
  UniswapV4DualStandardExchangeBufferConstantProductHook.sol
  UniswapV4DualStandardExchangeBufferConstantProductHook_FactoryService.sol
```

**Tests (canonical names):**

```text
test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/
  TestBase_UniswapV4DualStandardExchangeBufferConstantProductHook.sol   # preferred location: package-adjacent or contracts/test/bases/
  UniswapV4DualSEBCPHook_Deploy.t.sol
  UniswapV4DualSEBCPHook_Deposit.t.sol
  UniswapV4DualSEBCPHook_Zap.t.sol
  UniswapV4DualSEBCPHook_Swap.t.sol
  UniswapV4DualSEBCPHook_Withdraw.t.sol
  UniswapV4DualSEBCPHook_Fees.t.sol          # D29 + D57 + D72 + D61
  UniswapV4DualSEBCPHook_Permit2.t.sol
  UniswapV4DualSEBCPHook_Yield.t.sol         # yield → mid + D57 (D67)
  UniswapV4DualSEBCPHook_AmountOrder.t.sol   # ctor leg ≠ pool sort
  UniswapV4DualSEBCPHook_Reentrancy.t.sol

test/foundry/fork/base_main/hooks/uniswap/v4/standardExchange/dual/
  UniswapV4DualSEBCPHook_Base.t.sol

test/foundry/fork/robinhood_4663/hooks/uniswap/v4/standardExchange/dual/   # or repo’s RH fork path convention
  UniswapV4DualSEBCPHook_Robinhood.t.sol
```

**Delete or leave unreferenced after rename:** all `UniswapV4DualBufferPricingHook*` sources (D56). Do not keep dual product names in tree.

---

## 3. Scaffold audit (current code vs PRD v3.12)

**As of plan write:** tree still holds premature scaffold under legacy names. Bodies largely stubbed; economics incomplete. Treat as **rewrite substrate**, not partial ship.

### 3.1 Files present (legacy)

| File | Role today |
|------|------------|
| `interfaces/IUniswapV4DualBufferPricingHook.sol` | Partial §7.1; missing fee/kLast/permit2 views; has Permit2 fns + min/deadline in interface **only** |
| `UniswapV4DualBufferPricingHook.sol` | Ctor **no feeOracle**; public deposit/withdraw **without** min/deadline; ERC-20 surface partial |
| `…Common.sol` | SE buffer/unwrap helpers usable; **no** currency0/1 views; **no** pool-order claims; LP meta `DBH-`; decimals stored **ctor-leg** not pool-order |
| `…Math.sol` | **Fee-less** CP + wrong/heuristic zap split — **must replace** with ConstProdUtils D29/O1a |
| `…Repo.sol` | ERC-20 + decimals0/1 only; **no** `kLast`, **no** one-pool flag, **no** reentrancy lock |
| `…Target.sol` | Hooks partial; `beforeInitialize` **no** one-pool guard; `beforeSwap` / deposit / withdraw **NotImplemented**; swap previews fee-less + **wrong leg mapping** (uses claimSupply0/1 as if pool order) |
| `…_FactoryService.sol` | Mine flags OK; salt **no feeOracle**; namespace wrong; `isExpectedHook` OK as factory helper (keep factory-only) |

### 3.2 Gap matrix (implementor checklist)

| ID | PRD requirement | Scaffold status | Action |
|----|-----------------|-----------------|--------|
| G1 | D1 rename all types/files | Legacy names | Full rename (see §4) |
| G2 | D5 feeOracle ctor immutable | Missing | Add to ctor + Common + FactoryService + salt |
| G3 | D37 / O4 salt + LP prefix | Wrong | `uv4-dual-se-buffer-constant-product-hook-` / `DSEBCP-` |
| G4 | O6/C1 currency0/1 + pool-order claims | Missing / broken | Implement map; never use ctor-leg claims for CP |
| G5 | D29 0.3% CP | Fee-less Math | ConstProdUtils `_saleQuote`/`_purchaseQuote` with 300/100_000 |
| G6 | D78 claim-in composition | Absent | Two-step buffer claim delta; never raw amountIn into CP under SE fees |
| G7 | O1a fee-aware zap split | Wrong formula | `_swapDepositSaleAmt(..., 300, 100_000)` on wad claims |
| G8 | D79 zap-eligible | Live-only stub | Require `totalSupply > MINIMUM_LIQUIDITY` |
| G9 | D57/D61–D63/D67/D72 protocol fee | Absent | Repo `kLast`; mint to feeTo; pre-buffer k; previews simulate dilution |
| G10 | D58 nonReentrant | Absent | Repo lock; all liquidity + Permit2 entrypoints |
| G11 | D69 one pool | Absent | Repo flag / PoolId; second init reverts |
| G12 | D47 min/deadline on liquidity | Interface only; impl missing | Wire on all deposit/withdraw paths |
| G13 | D45–D46 / §7.3 Permit2 | Interface only | Implement packing; well-known address; no witness |
| G14 | D68 / §7.1 fee views + kLast + tradingFee* | Missing | Add getters; ERC-20 already partial |
| G15 | §7.5 events incl. ZapSwap | Missing | Emit per PRD |
| G16 | O9 zap no PoolManager | Not implemented | SE helpers only + ZapSwap |
| G17 | D71 residual refund msg.sender | Missing | After liquidity ops |
| G18 | C33 withdraw SE pro-rata | Stub | `seOut = bal * lp / supply` pre-burn post-protocol-mint |
| G19 | D76 subsequent mint if supply > 0 | N/A | No geometric re-bootstrap after dust residual |
| G20 | D80 isExpectedHook not on hook ABI | Factory only (OK) | Keep off interface |
| G21 | Prefer pretransfer buffer | approve path only | Prefer pretransfer + `pretransferred=true` (PRD §4.5) |
| G22 | Tests / TestBase / forks | None | §8 |
| G23 | Phase 0 ERC-4626 SE routes | Package exists; completeness unverified | §5 Phase 0 |

### 3.3 What is worth keeping (pattern only)

- Repo storage-slot layout pattern (extend, rename slot string).  
- CREATE3 mine loop structure in FactoryService.  
- SE `_buffer` / `_unwrap` / `_unwrapExactOut` shape (fix to pretransfer + fee-inclusive tight bounds + D78 claim helpers).  
- Minimal ERC-20 mint/burn/transfer shape.  
- Hook permissions bitmask (already matches C30).  

**Do not keep:** fee-less math, ctor-leg-as-pool-order assumptions, wrong metadata prefix, missing feeOracle.

---

## 4. Scaffold conformance path (rename + rewrite instructions)

**Goal:** make `dual/` match PRD without treating legacy names as product. Prefer **rename files then rewrite bodies** over parallel packages.

### 4.0 Process rules

1. **Do not** implement from the retired plan file.  
2. **Do not** ship hybrid names (`DualBufferPricing` public API).  
3. After each phase: `forge build` green; relevant tests green before next phase.  
4. Production-first: no mock SUT (hook, SE under test, manager, Permit2, fee oracle, PoolManager).  

### 4.1 Phase R — Rename (mechanical)

1. Rename files/types to §2 map (D1).  
2. Update all imports / FactoryService `type(...).creationCode` / interface refs.  
3. Repo storage slot string → e.g. `"indexedex.hooks.uv4.dual.se.buffer.constant.product.storage"`.  
4. Replace any remaining `DBH-` / `uv4-dual-buffer-pricing-hook-` / PRD path comments.  
5. Delete old filenames once new ones compile.  
6. Leave a one-line note in git commit: scaffold rename to D1; bodies still incomplete until phases below.

### 4.2 Phase R fix list (must land with rename or Phase A)

| Location | Change |
|----------|--------|
| Ctor | `(poolManager, feeOracle, se0, token0, se1, token1)`; reject zero feeOracle (and zero others) |
| Common immutables | Store `_feeOracle`; expose `feeOracle()` |
| Common | `currency0()` / `currency1()` = address sort of pair tokens; map currency → (se, token) |
| Common | `claimSupplyCurrency0/1` for CP; keep ctor-leg `claimSupply0/1` for views |
| Common | `_decimalsCurrency0/1` for wad of **pool-order** legs (fix ctor-leg decimals0/1 or dual-store) |
| Common | `_buildLpMetadata` uses **pool currency** symbols + prefix **`DSEBCP-`** |
| Common | `permit2()` returns well-known `0x000000000022D473030F116dDEE9F6B43aC78BA3` (constant) |
| Math | Delete fee-less `getAmountOut`/`getAmountIn`/`optimalZapSwapAmount` as product SoT; wrap or call ConstProdUtils |
| Repo | Add `kLast`, `initialized` / `poolId`, `reentrancyStatus` (or equivalent) |
| FactoryService | `DEFAULT_SALT_NAMESPACE = "uv4-dual-se-buffer-constant-product-hook-"`; salt includes **feeOracle**; `deployHook(..., feeOracle, ...)`; `isExpectedHook` also checks feeOracle; **not** on hook interface |
| Interface | Match PRD §7.1 exactly (fee views, kLast, tradingFee*, Permit2 names, previews) |
| Hook public API | deposit/depositSingle/withdraw with **min + deadline**; all Permit2 variants; events |

### 4.3 Normative helpers to implement early (shared by all paths)

```text
// Claim (D15 / D73)
claim_i = previewExchangeIn(SE_i, balanceOf(hook), pairToken_i)  // fee-inclusive SE SoT

// Buffer claim-in for amountInRaw (D78) — NEVER treat shares as claim
sharesOutPreview = previewExchangeIn(pairToken, amountInRaw, SE)
claimIn = previewExchangeIn(SE, sharesOutPreview, pairToken)
// If SE offers peer closed-form claim delta, bit-identical OK.
// Forbidden: claimIn := amountInRaw when usage fee > 0 without SE preview.
// Forbidden: claimIn := sharesOutPreview (unit mismatch vs claim reserves).

// Invert buffer for exact-out (D78): raw amountIn such that claimIn_preview >= requiredClaimIn (ceil).
// Prefer closed-form if SE provides; else bounded invert that keeps previewSwapExactOut == execution within MAX_DUST_WEI=10.
// Pure unbounded binary search as primary product law is forbidden if closed form exists.

// Pool-order map
currency0 = min(token0,token1); currency1 = max(...)
seFor(currency) / tokenFor(currency) from binding

// Live / zap-eligible
live = claimCurrency0 > 0 && claimCurrency1 > 0
zapEligible = live && totalSupply > MINIMUM_LIQUIDITY   // D79
```

### 4.4 ConstProdUtils wiring (normative)

| Op | Function | Args |
|----|----------|------|
| Exact-in CP | `_saleQuote` | amountIn := **claimIn** (wad if decimals differ), reserves wad, feePercent=300, feeDenominator=100_000 |
| Exact-out CP | `_purchaseQuote` | amountOut, reserves, 300, 100_000 → required **claimIn** (ceil peer) |
| Zap split | `_swapDepositSaleAmt` | amountIn & saleReserve **same units** (prefer wad then floor to raw), 300, 100_000 |
| Protocol LP | `_calculateProtocolFee` **generic** | totalSupply, newK, kLast, ownerFeeShare |
| ownerFeeShare | `dexFeeWad * 100_000 / 1e18` floor | **no product max** (D82) |
| kLast | `xN * yN` wad product | overflow accepted (D83) |

Trading fee constants exposed as views or immutables: `300` / `100_000` (D59).

### 4.5 Liquidity / swap algorithm pointers (do not re-derive)

Copy PRD §17 verbatim into implementation comments if useful; implement against:

- Deposit: PRD §5.1 + §17.1  
- DepositSingle: PRD §5.2 + §17.2 (D79, D78, D77 ZapSwap)  
- Withdraw: PRD §5.3 + §17.3  
- Swap: PRD §4.2.1 + §6 + §17.4  
- D57 timing: PRD §7.4 + D72  

**First mint:** only when `totalSupply == 0` (after any no-op fee step). Geometric `sqrt(xN*yN) - MINIMUM_LIQUIDITY`; mint `MINIMUM_LIQUIDITY` to `address(0)`.  
**Any `totalSupply > 0`:** subsequent mint ratio clamp only (D76) — including MINIMUM_LIQUIDITY-only residual.

---

## 5. Implementation phases

### Phase 0 — ERC-4626 SE prerequisite (D60 / D66) **[owns dual DoD gate]**

**Ownership:** this dual-hook workstream. Do not assume green without verification.

1. Inventory `contracts/vaults/standard/erc4626/` against single-hook §6.0 / closed-form **pair token ↔ SE** buffer and unwrap.  
2. Confirm `previewExchangeIn` / `previewExchangeOut` are **fee-inclusive** and **preview == execution** (D73).  
3. Confirm buffer/share-mint routes can take **non-zero usage fee** for DoD (D70). Exit/unwrap fee-less OK.  
4. Finish any gaps in ERC-4626 SE package **before** dual hermetic DoD is declared green.  
5. Dual tests deploy **two** production ERC-4626 SE vaults wrapping test tokens (distinct pair tokens); `se0 != se1`.  

**Exit criteria:** dual TestBase can deploy two real ERC-4626 SEs and buffer/unwrap both directions with preview fidelity.

### Phase A — Skeleton (compile + bindings)

1. Complete Phase R rename + §4.2 ctor/feeOracle/currency map/Repo fields.  
2. Interface = PRD §7.1 (including fee/kLast/tradingFee/permit2).  
3. Hook permissions + disabled callbacks revert; `beforeAddLiquidity` always reverts.  
4. `beforeInitialize`: pair match + fee=0 + **set one-pool flag** (first success); second call reverts (D69).  
5. FactoryService salt material: `namespace + poolManager + feeOracle + seLo + tLo + seHi + tHi + mineNonce` (C28).  
6. Ctor validation D5–D7; LP metadata O4.  
7. `forge build` green.

### Phase B — Claims + Math + SE I/O

1. Claims ctor-leg + currency-order; re-read every quote (no cached k/mid product state except `kLast`).  
2. ConstProdUtils-backed quote helpers with D29.  
3. `preview_buffer_pair_to_claim` / invert helpers (D78).  
4. `_buffer` prefer pretransfer; tight minOut = fee-inclusive preview.  
5. Withdraw unwrap via `exchangeIn(SE→pair)`; swap-out via `exchangeOut` (PRD §4.5).  
6. Deadline helpers: user `deadline` vs SE `block.timestamp`.  

### Phase C — Proportional deposit / withdraw (ERC-20 path)

1. `nonReentrant` on all liquidity entrypoints (D58).  
2. `deposit` with minLpAmount + deadline; pull `transferFrom`; pool-order amounts.  
3. D57 protocol mint **pre-buffer** when fee-on (D72); first mint no protocol mint while `kLast==0`.  
4. First vs subsequent mint (O1 / D76 / O5).  
5. Clamp + refund excess to **msg.sender** (not `to`).  
6. Re-preview claims after buffer before mint (O11/C37).  
7. `withdraw` D57 then pro-rata SE shares then unwrap; minAmount0/1 + deadline.  
8. Residual free pair tokens → refund msg.sender (D71).  
9. Events Deposit / Withdraw.  
10. Previews include fee-on dilution (D61); preview == execution within dust.

### Phase D — Swaps (V4)

1. Pattern-copy take → buffer → unwrap → settle + `BeforeSwapDelta` (C34).  
2. Exact-in / exact-out both directions with **D78 + D29**.  
3. `previewSwapExactIn/Out` same composition; **must** match under non-zero SE buffer fees.  
4. Live required; insufficient claim → full revert.  
5. Hermetic pool init: fee=0, tickSpacing=60, 1:1 mid (C6). Deposit may precede init (C13).

### Phase E — Single-asset zap

1. Gate **D79** (not merely live).  
2. D57 pre-zap/pre-buffer; O1a split; D78 internal swap via SE only (O9).  
3. Emit **ZapSwap** (D77).  
4. Proportional add + clamp/refund; mint subsequent formula.  
5. `previewDepositSingle` + **strict SE-aware `previewZapSplit`** (D65).  
6. Event `DepositSingle.amountIn` = **full pull** (D81).  

### Phase F — Protocol fee + fee views polish

1. Wire oracle `dexSwapFeeAndFeeToOfVault(address(this))` — growth WAD **not** trading fee.  
2. `kLast` updates post-op; fee-off → `kLast=0`.  
3. Yield growth fee-eligible (D67) — no special-case skip.  
4. Public views: feeOracle, tradingFeePercent/Denominator, dexSwapFee, feeTo (or combined), kLast.  
5. feeTo mint failure reverts whole op (D75) — no best-effort skip.

### Phase G — Permit2

1. Constant well-known Permit2; **no** ctor/salt.  
2. Implement §7.3 packing exactly (batch dual pool-order; single token; allowance paths).  
3. Shared `_deposit` / `_depositSingle` cores after pull.  
4. Tests R2–R5 + wrong order / bad sig / expired / insufficient allowance.

### Phase H — TestBase + hermetic suite

1. `CraneTest` → `IndexedexTest` → vault components / ERC-4626 SE TestBase → dual FactoryService deploy + V4 PM.  
2. Real Permit2 at well-known address (deploy bytecode if needed).  
3. Fee oracle with non-zero dex growth fee + receivable feeTo for fee-on tests; fee-off path tests.  
4. Non-zero SE **buffer-route** usage fees (D70).  
5. Full §8.2 matrix.

### Phase I — Forks (D64 / D74)

1. Base mainnet fork: prefer live PM + Permit2 + fee oracle; else deploy production-equivalent on fork.  
2. Robinhood Chain **4663** fork: same rule.  
3. Smoke: dual ERC-4626 SE → deposit → swap → withdraw with fees on.  

### Phase J — Polish

1. NatSpec: LP vs SE shares; amount0 = currency0; dexSwapFee naming callout.  
2. `forge build --sizes`.  
3. Size mitigations if needed (library externalization) without dropping required surface.  
4. Confirm no `isExpectedHook` on hook ABI.  

---

## 6. Locked constants (implementor card)

| Item | Value | PRD |
|------|--------|-----|
| Product name | `UniswapV4DualStandardExchangeBufferConstantProductHook` | D1 |
| MINIMUM_LIQUIDITY | `1000` → `address(0)` | O5 |
| Trading fee | `feePercent=300`, `feeDenominator=100_000` (0.3%) | D29 |
| Pool fee | `0` | D9 |
| Normalize | O3 `toWad` | O3 |
| Missing decimals | 18 | D50 |
| LP decimals | 18 | O10 |
| LP symbol prefix | `DSEBCP-{c0}-{c1}` | O4 |
| Salt namespace default | `uv4-dual-se-buffer-constant-product-hook-` | D37 |
| Permit2 | `0x000000000022D473030F116dDEE9F6B43aC78BA3` | C18 |
| MAX_DUST_WEI | 10 | C20 |
| Hook flags | BEFORE_INITIALIZE \| BEFORE_ADD_LIQUIDITY \| BEFORE_SWAP \| BEFORE_SWAP_RETURNS_DELTA | C30 |
| Pool init tests | tickSpacing=60, 1:1 sqrtPrice | C6 |
| kLast | wad product `xN*yN` | D63 |
| ownerFeeShare | `dexFeeWad * 100_000 / 1e18` floor; no max | D62, D82 |

---

## 7. FactoryService (normative)

```solidity
function deployHook(
    ICreate3FactoryProxy create3Factory,
    IPoolManager poolManager,
    IVaultFeeOracleQuery feeOracle,
    address se0,
    address token0,
    address se1,
    address token1,
    string memory saltNamespace
) internal returns (address hook);
```

- Salt: C28 (include feeOracle; exclude Permit2).  
- Idempotent: expected binding at predicted address → return existing; wrong code → revert.  
- `isExpectedHook`: poolManager + feeOracle + both legs order-insensitive — **factory/internal only** (D80).  

Ctor: `(poolManager, feeOracle, se0, token0, se1, token1)`.

---

## 8. Testing plan

### 8.1 Rules

- Production-first (IndexedEx AGENTS.md / indexedex-testing).  
- **No** mock hook / SE SUT / fee oracle / PoolManager / Permit2.  
- Two real ERC-4626 SE vaults (D60).  
- Hermetic **and** Base + Robinhood 4663 forks (D64/D74).  

### 8.2 Minimum DoD matrix

| ID | Case | PRD |
|----|------|-----|
| Ph0 | ERC-4626 SE routes complete; fee-inclusive previews | D60/D66/D73 |
| D1 | Deploy rejects zero / token∉vaultTokens / se0==se1 / zero feeOracle | D5–D7 |
| D2 | Mine flags match permissions | C30 |
| D3 | Idempotent redeploy same binding (+ feeOracle) | C29 |
| D4 | Salt/namespace/LP prefix correct (DSEBCP / uv4-dual-se-…) | D37/O4 |
| I1 | beforeInitialize wrong pair / non-zero fee reverts | D35 |
| I2 | **Second initialize reverts** | D69 |
| I3 | beforeAddLiquidity reverts | D10 |
| I4 | Init C6 convention; deposit without prior init OK | C6/C13 |
| A1–A2 | amount0 = currency0 when ctor order ≠ sort | C1/D48 |
| P1 | First dual deposit; min liq to address(0); claims live | O1/O5 |
| P2 | First mint reverts if geometric &lt; MINIMUM_LIQUIDITY | O1 |
| P3 | Subsequent clamp+refund to msg.sender; preview==exec | D19/D45 |
| P4 | amount0==0 or amount1==0 reverts on deposit | §5.1 |
| P5 | minLpAmount / deadline reverts | D47 |
| P6 | After full user exit (only MINIMUM_LIQUIDITY): next deposit uses **subsequent** mint | D76/C36 |
| Z1 | depositSingle both directions when zap-eligible | D20 |
| Z2 | previewZapSplit strict == exec under SE buffer fees | D65/D70/D78 |
| Z3 | depositSingle reverts empty book | D79 |
| Z4 | depositSingle reverts when only MINIMUM_LIQUIDITY residual | D79 |
| Z5 | ZapSwap event; DepositSingle full pull amountIn | D77/D81 |
| Z6 | minLp / deadline on depositSingle | D47 |
| S1–S2 | swap exact-in/out both ways; preview==exec under SE fees (claim-in) | D78/D29 |
| S3 | insufficient out claim reverts | §6 |
| S4 | mid from claims not sqrtPrice | C6 |
| S5 | LPs benefit from volume (k/claim growth vs fee-less counterfactual) | D29 |
| W1–W2 | withdraw unwrap both; pool-order; min/deadline; SE pro-rata | C33 |
| F1 | Non-zero SE buffer usage fees; preview==exec | D70/D73 |
| F2 | Protocol growth fee-on: mint to feeTo; kLast wad updates | D57 |
| F3 | Fee-off: no protocol mint; kLast=0 | D57 |
| F4 | D72: deposit does not tax own capital as growth in same op | D72 |
| F5 | Fee-on preview==exec deposit/single/withdraw | D61 |
| F6 | Mixed decimals: wad kLast + CP correct | D63 |
| Y1 | Yield moves claim/mid | D17 |
| Y2 | Yield → next mint/burn mints protocol LP | D67 |
| R1–R5 | ERC-20 + Permit2 all four deposit styles | §7.3 |
| R6 | Permit2 bad sig / wrong batch order / expired / low allowance | §7.3 |
| N1 | Nested reenter deposit/withdraw reverts | D58 |
| E1 | Required surface: fee views, kLast, tradingFee*, ERC-20 metadata | D68 |
| E2 | Events Deposit/DepositSingle/Withdraw/ZapSwap | §7.5 |
| FK1 | Base fork smoke deposit→swap→withdraw fees on | D64/D74 |
| FK2 | Robinhood 4663 fork smoke same | D64/D74 |

### 8.3 Commands

```bash
forge build
forge build --sizes

# Hermetic dual suite
forge test --match-path 'test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/*' -vv

# Forks (use repo profiles / RPC env as established for Base + 4663)
forge test --match-path 'test/foundry/fork/**/hooks/uniswap/v4/standardExchange/dual/*' -vv
```

Pure ConstProdUtils unit grids are **optional** (PRD §9). Prefer pool-attached integration proof.

---

## 9. Risks & mitigations

| Risk | Mitigation |
|------|------------|
| Contract size (hook + ERC-20 + dual SE + Permit2 + fees) | Shared libs; ConstProdUtils; `--sizes`; externalize pure helpers if needed without dropping §7.1 |
| Agent uses raw amountIn in CP under SE fees | D78 helpers + mandatory non-zero SE fee tests |
| Agent treats shares as claimIn | Two-step preview only; unit mismatch test |
| fee-less zap / wrong split | ConstProdUtils O1a only; ban custom fee-less root |
| Multi-pool shared inventory | D69 hard flag |
| Zap after dust residual | D79 gate + test Z4 |
| Protocol mint non-receivable feeTo | Document D75; tests use receivable feeTo |
| kLast overflow | Accepted D83; document integrator scale limit |
| Permit2 packing drift | §7.3 byte-level tests |
| ERC-4626 incomplete | Phase 0 gate dual DoD |
| Scaffold partial ship | Do not merge until §10 DoD; rename early to avoid API freeze on legacy names |
| Claim supply0 vs currency0 confusion | NatSpec + A1/A2 tests; CP only on currency claims |

---

## 10. Definition of done

1. PRD **D1–D83**, **O1–O12**, and planning C locks needed for product surface implemented (or waived in PRD revision log only).  
2. This plan’s phases 0–I green; scaffold legacy names **gone**.  
3. Interface + implementation match PRD **§7.1**; events **§7.5**; Permit2 **§7.3**; protocol fee **§7.4**.  
4. Dual fee model: D29 + D57 (yield-eligible, pre-buffer deposits, no product fee cap).  
5. Claim-in swaps/zap (D78); zap-eligible (D79); one-pool (D69); nonReentrant (D58).  
6. FactoryService: feeOracle in salt; isExpectedHook factory-only.  
7. Phase 0 ERC-4626 complete for dual legs (D60/D66/D73).  
8. Hermetic §8.2 + Base fork + Robinhood 4663 fork green (D64/D74).  
9. `forge build --sizes` acceptable for CREATE3 product.  
10. NatSpec + integrator notes: deploy → (optional init) → dual bootstrap → LP → swap → withdraw; zap impact via previews.  

---

## 11. Explicit non-actions for coding agents

Do **not**:

- Implement from `UNISWAP_V4_DUAL_BUFFER_PRICING_HOOK_IMPLEMENTATION_AND_TEST_PLAN.md` (retired).  
- Ship fee-less CP or fee-less zap.  
- Leave `UniswapV4DualBufferPricingHook*` as the public product name.  
- Put `isExpectedHook` on the hook interface.  
- Put Permit2 in ctor/salt.  
- Use binary search as primary zap/swap split law.  
- Invent InitPrice / one-sided book / multi-pool DoD.  
- Tax deposit capital as D57 growth in the same op (post-buffer-only k).  
- Treat `previewZapSplit` as disclosure-only.  
- Special-case yield out of D57.  
- Invent exit SE usage fee solely for dual DoD.  
- Cap protocol fee WAD in product code.  
- Skip protocol mint on feeTo failure (must revert).  
- Geometric re-bootstrap while `totalSupply > 0`.  
- Zap when only MINIMUM_LIQUIDITY residual.  

---

## 12. Revision log (this plan)

| Date | Change |
|------|--------|
| 2026-08-02 | (retired) Initial plan for pre-v3.6 PRD under DualBufferPricing names. |
| 2026-08-03 | (retired) Sync attempts to PRD v3.3 — still fee-less / incomplete dual-fee / wrong names. |
| 2026-08-03 | **Canonical rewrite from PRD v3.12:** full D1–D83 scope; scaffold gap matrix; rename + conformance path; Phase 0 ERC-4626; claim-in; zap-eligible; D57/kLast; forks Base+4663; Permit2 §7.3; events ZapSwap; implementor SoT. Stale plan file reduced to redirect. |

---

## 13. Summary for coding agents

```text
SoT product: PRD v3.12
SoT implement: THIS plan
Name: UniswapV4DualStandardExchangeBufferConstantProductHook
First: rename scaffold + feeOracle + currency map + kill fee-less math
Then: Phase 0 ERC-4626 → deposit/withdraw → swaps D78 → zap D79 → fees D57 → Permit2 → tests → forks
Never: raw-amountIn CP under SE fees; zap on dust residual; multi-pool; legacy DualBufferPricing ship
```
