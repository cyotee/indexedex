# Morpho Vault V2 + Uniswap V4 Composition Diagram

**Date:** 2026-08-02  
**Status:** Design sketch (not a PRD)  
**Audience:** IndexedEx engineering  
**Related:**

- Strategy research: [`2026-08-02-morpho-uniswap-lending-mm-strategies.md`](./2026-08-02-morpho-uniswap-lending-mm-strategies.md)
- Generic ERC-4626 SE: `contracts/vaults/standard/erc4626/`
- Uni V4 wrapper base: `lib/crane/contracts/protocols/dexes/uniswap/v4/hooks/public/base/BaseTokenWrapperHook.sol`
- Rate template: `.../hooks/public/WstETHHook.sol` (dynamic exchange rate in `beforeSwap`)
- Morpho V2: `lib/crane/contracts/external/morpho/vault-v2/VaultV2.sol`
- RH Morpho constants: `lib/crane/contracts/constants/networks/ROBINHOOD_MAIN.sol`

---

## 1. Goal (simple composition)

Compose:

1. **Morpho Vault V2** — permissionless ERC-4626 that lends the loan token into Blue markets (via adapters).
2. **Uniswap V4 pool + hook** — swaps **loan token ↔ Morpho vault shares** at the **Morpho exchange rate** (not a CL spot book for that pair).

Interest earned on Morpho must appear in the **hook’s pricing** via Morpho `previewDeposit` / `previewRedeem` / `convertToAssets`, not via SE share-balance math alone.

Optional third layer: **IndexedEx ERC4626 SE** wraps Morpho vault shares for registry / fees / DETF legs — **not** the rate source for the hook.

---

## 2. Recommended stack (one page)

```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                           USER / ROUTER / APP                                │
│         swap loanToken ↔ morphoShares   |   deposit/redeem Morpho            │
└───────────────────────────────┬─────────────────────────────┬───────────────┘
                                │                             │
                Uniswap V4 path │                             │ direct ERC-4626
                                ▼                             ▼
┌───────────────────────────────────────────┐   ┌─────────────────────────────┐
│         UNISWAP V4 POOL MANAGER           │   │     MORPHO VAULT V2          │
│  PoolKey:                                 │   │  asset() = loanToken        │
│    currency0/1 = loanToken, morphoShares  │   │  shares = Morpho vault ERC20│
│    fee = 0  (wrapper pool)                │   │                             │
│    hooks = MorphoWrapperHook              │   │  adapters → Blue markets    │
│    tickSpacing / hooks bits per miner     │   │  totalAssets / convertTo*   │
└───────────────────┬───────────────────────┘   │    INCLUDE INTEREST         │
                    │ beforeSwap                └──────────────▲──────────────┘
                    │ BeforeSwapDelta                          │
                    ▼                                          │
┌───────────────────────────────────────────┐                  │
│       MORPHO WRAPPER HOOK                 │                  │
│  (extends BaseTokenWrapperHook)           │                  │
│                                           │                  │
│  wrapZeroForOne = f(token order)          │                  │
│                                           │                  │
│  _deposit(loanIn):                        │  deposit/redeem  │
│    take loanToken from PM                 ├──────────────────┘
│    Morpho.deposit(loanIn, PM or hook)     │
│    settle morphoShares                    │
│                                           │
│  _withdraw(sharesIn):                     │
│    take morphoShares                      │
│    Morpho.redeem(shares, …)               │
│    settle loanToken                       │
│                                           │
│  RATE (pricing):                          │
│    previewDeposit / previewRedeem         │
│    = Morpho convertTo*  (interest-aware)  │
│    Template: WstETHHook rate helpers      │
└───────────────────────────────────────────┘
                    │
                    │ optional (IndexedEx surface only)
                    ▼
┌───────────────────────────────────────────┐
│  ERC4626 STANDARD EXCHANGE (optional)     │
│  contracts/vaults/standard/erc4626/       │
│                                           │
│  SE.asset() = Morpho vault (shares)       │
│  vaultTokens = [morphoVault, loanToken]   │
│                                           │
│  DO NOT use SE alone as hook rate oracle  │
│  Interest in loanToken needs Morpho:      │
│    loanOut = Morpho.convertToAssets(      │
│                 SE→morphoShares out)      │
└───────────────────────────────────────────┘
```

---

## 3. Token / address map

| Symbol | What it is | Example (RH narrative) |
|--------|------------|-------------------------|
| `loanToken` | Morpho vault `asset()` | USDG, USDC, WETH |
| `morphoVault` | Morpho Vault V2 instance (not factory) | Curated or self-created vault |
| `morphoShares` | ERC-20 shares of `morphoVault` | Same address as vault |
| `MorphoWrapperHook` | V4 hook (CREATE2 mined flags) | New contract |
| `PoolManager` | Uni V4 singleton | Chain deployment |
| `SE` (optional) | IndexedEx ERC4626 SE diamond | `deployVault(morphoVault)` |
| `Morpho Blue` | Lending markets under adapters | `ROBINHOOD_MAIN.MORPHO` |

```text
loanToken ──deposit──► morphoVault ──shares──► holder / PoolManager / SE
                ▲
                │ interest (borrower demand on Blue)
                │ revalues convertToAssets(shares)
                │ does NOT mint extra shares to holders
```

---

## 4. Swap flows (hook-driven rate)

Wrapper pools **block normal CL liquidity** (`LiquidityNotAllowed`). All swap size is set by the hook’s `BeforeSwapDelta` (same as WETH/wstETH hooks).

### 4.1 Exact-in: loanToken → morphoShares (wrap / lend)

```text
User swap exact-in loanToken
        │
        ▼
PoolManager.swap ──beforeSwap──► Hook
        │                          │
        │                          ├─ inputAmount = amountSpecified
        │                          ├─ Morpho.previewDeposit(input)  ← rate (interest-aware)
        │                          ├─ take loanToken from PM
        │                          ├─ Morpho.deposit → morphoShares
        │                          └─ settle morphoShares to PM
        │
        ▼
User receives morphoShares ≈ previewDeposit(loanIn)
```

### 4.2 Exact-in: morphoShares → loanToken (unwrap / withdraw)

```text
User swap exact-in morphoShares
        │
        ▼
Hook: Morpho.previewRedeem(shares)  ← rate includes accrued interest
      Morpho.redeem(shares) → loanToken
User receives loanToken (subject to Morpho liquidity / queues)
```

### 4.3 Pricing invariant (must hold)

```text
hook_rate(shares → loan)  ==  Morpho.previewRedeem(shares)   (± fees / rounding)
hook_rate(loan → shares)  ==  Morpho.previewDeposit(loan)    (± fees / rounding)

// WRONG for interest capture:
hook_rate based only on SE.balanceOf(morphoVault) / SE.totalSupply
// That revalues SE dilution, not Morpho APR.
```

---

## 5. Interest capture diagram

```text
Time ──────────────────────────────────────────────────────────────────►

Morpho Blue interest accrues
        │
        ▼
morphoVault.totalAssets() ↑
morphoVault.convertToAssets(1 share) ↑
balanceOf(holder) in shares  ──unchanged──►

┌──────────────────────┐     ┌──────────────────────┐
│  PRICE FROM MORPHO   │ YES │  PRICE FROM SE ONLY  │
│  convertToAssets /   │     │  Morpho share count  │
│  previewRedeem       │     │  on SE               │
│                      │     │                      │
│  Hook sees higher    │     │  Hook / SE share     │
│  loan per share ✓    │     │  price flat ✗        │
└──────────────────────┘     └──────────────────────┘

Redeem path (either direct Morpho or SE → Morpho.redeem):
  shares out → loanToken out  ↑ with interest ✓
```

---

## 6. Optional SE layer (when to add)

```text
                    ┌─────────────┐
                    │  End user   │
                    └──────┬──────┘
           wants IndexedEx SE / DETF leg?
                    │
         ┌──────────┴──────────┐
         NO                    YES
         │                     │
         ▼                     ▼
   Hold morphoShares     deployVault(morphoVault)
   or swap via V4        SE.asset = morphoVault
         │                     │
         │                     │ still price loan NAV as:
         │                     │ Morpho.convertToAssets(
         │                     │   SE_morpho_shares)
         ▼                     ▼
   Hook rate = Morpho     SE is share wrapper only
```

| Use SE | Skip SE |
|--------|---------|
| Vault registry, fee type, DETF `vaultTokens` | Minimal composition |
| User-facing ixSE share over Morpho | Hook + Morpho only |
| Multi-product standard surface | Fewer contracts |

---

## 7. Hook permissions (BaseTokenWrapperHook pattern)

| Flag | On? | Why |
|------|-----|-----|
| `beforeInitialize` | Yes | Enforce pool = loanToken + morphoShares, fee = 0 |
| `beforeAddLiquidity` | Yes | Revert — no CL LP on wrapper pool |
| `beforeSwap` | Yes | Execute wrap/unwrap |
| `beforeSwapReturnDelta` | Yes | Set amounts (rate) |
| after* / donate | No | Not required for v1 |

Address must be **mined** so hook permission bits match (`HookMiner` / `HookMinerCreate3` in Crane V4 utils).

---

## 8. Contract sketch (logical, not final names)

```text
MorphoV4WrapperHook is BaseTokenWrapperHook
  immutable morphoVault  // IERC4626, asset = loanToken
  wrapperCurrency  = morphoVault
  underlyingCurrency = loanToken

  _deposit(loanAmount):
      take loan; approve morpho; deposit(loan, settleTo); return amounts

  _withdraw(shareAmount):
      take shares; redeem(shares, settleTo, owner); return amounts

  _getWrapInputRequired(sharesWanted):
      return morphoVault.previewMint(sharesWanted)   // or invert previewDeposit

  _getUnwrapInputRequired(loanWanted):
      return morphoVault.previewWithdraw(loanWanted)
```

Deploy order:

```text
1. Morpho Vault V2 exists (createVaultV2 or use curated instance)
2. Adapters + caps configured (otherwise deposit may be useless / empty yield)
3. Mine + deploy MorphoV4WrapperHook(poolManager, morphoVault)
4. initialize V4 pool (loanToken, morphoShares, fee=0, hook)
5. (optional) indexedexManager → ERC4626StandardExchangeDFPkg.deployVault(morphoVault)
```

---

## 9. Risk / ops callouts (diagram margin)

```text
┌─ Morpho liquidity ─┐  redeem may return less than convertToAssets if markets tight
┌─ V2 fees ──────────┐  perf/management fees move share price vs raw Blue interest
┌─ maxRate (V2) ─────┐  interest accrual can be capped per accrueInterestView
┌─ Adapter realAssets┐  gas / DOS if too many adapters on totalAssets paths
┌─ Hook custody ─────┐  deposit receiver must align with PoolManager settle rules
┌─ No CL fees ───────┐  wrapper pool fee=0; yield is Morpho, not swap fees
```

---

## 10. Non-goals for this simple composition

- Uni V3 (no hook model as above).
- Levered LP / Morpho borrow sleeves (S3/S4 in strategy research).
- Using SE `lastTotalAssets` (Morpho share count) as loan-token NAV.
- Putting Morpho Blue market supply shares directly in the pool (not IERC4626).

---

## 11. Next implementation steps (when product locks)

1. Hermetic: `TestBase_MorphoBlue` + Vault V2 create + MarketV1 adapter → deposit loan → assert `convertToAssets` rises after mock interest / borrow usage.  
2. Hook unit tests mirroring `WstETHHook.t.sol` / `WETHHook.t.sol` with Morpho vault as wrapper.  
3. Fork: RH or Base Morpho vault instance + live V4 PoolManager.  
4. Optional SE fork: `TestBase_ERC4626StandardExchange` + `deployVault(morphoVault)` + assert SE→loan uses Morpho redeem interest.  
5. Write PRD only after hook rate tests prove `preview == execution` for wrap/unwrap.

---

## Changelog

| Date | Change |
|------|--------|
| 2026-08-02 | Initial composition diagram: Morpho V2 buffer + V4 wrapper hook + optional SE |
