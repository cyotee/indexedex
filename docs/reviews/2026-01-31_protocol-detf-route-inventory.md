# Protocol DETF Route Inventory

**Date:** 2026-01-31
**Purpose:** Inventory all token routes and identify refactoring opportunities to standardize on IStandardExchangeIn/IStandardExchangeOut interfaces.

## Token Types

| Token | Symbol | Type | Purpose |
|-------|--------|------|---------|
| Wrapped Ether | WETH | ERC20 | Primary deposit/withdrawal token |
| Protocol DETF | CHIR | Mintable ERC20 | The DETF token itself |
| Reward Token | RICH | Static ERC20 | Reward/governance token |
| Redemption Token | RICHIR | Rebasing ERC20 | Redeemable for WETH backing |
| Bond NFT | NFT | ERC721 | Locked LP positions |
| Reserve Pool LP | BPT | Balancer V3 LP | 80/20 weighted pool shares |

## Route Inventory

### A. Routes Using IStandardExchangeIn

| Route | Input | Output | Function | File | Status |
|-------|-------|--------|----------|------|--------|
| Mint | WETH | CHIR | `exchangeIn(WETH, *, CHIR, ...)` | ExchangeInTarget:271-322 | Conforming |
| Redeem | CHIR | WETH | `exchangeIn(CHIR, *, WETH, ...)` | ExchangeInTarget:652-681 | Conforming |
| Sell RICH | RICH | CHIR | `exchangeIn(RICH, *, CHIR, ...)` | ExchangeInTarget:328-377 | Conforming |
| Redeem RICHIR | RICHIR | WETH | `exchangeIn(RICHIR, *, WETH, ...)` | ExchangeInTarget:401-430 | Conforming |

### B. Routes Using IStandardExchangeOut

| Route | Input | Output | Function | File | Status |
|-------|-------|--------|----------|------|--------|
| Mint Exact | WETH | CHIR | `exchangeOut(WETH, *, CHIR, ...)` | ExchangeOutTarget:194-242 | Conforming |
| Buy RICH | CHIR | RICH | `exchangeOut(CHIR, *, RICH, ...)` | ExchangeOutTarget:247-278 | Conforming |

### C. Routes NOT Using Standard Exchange Interfaces

| Route | Input | Output | Current Function | File | Refactor Target |
|-------|-------|--------|------------------|------|-----------------|
| Bond WETH | WETH | NFT | `bondWithWeth()` | BondingTarget:463-511 | `exchangeIn(WETH, *, NFT, ...)` |
| Bond RICH | RICH | NFT | `bondWithRich()` | BondingTarget:514-562 | `exchangeIn(RICH, *, NFT, ...)` |
| Sell NFT | NFT | RICHIR | `sellNFT(tokenId, recipient)` | BondingTarget:609-627 | Special case (see notes) |
| RICH to RICHIR | RICH | RICHIR | `richToRichir()` | BondingTarget:630-683 | `exchangeIn(RICH, *, RICHIR, ...)` |
| Capture Seigniorage | CHIR | BPT | `captureSeigniorage()` | BondingTarget:569-606 | Internal only |
| Donate | WETH/CHIR | BPT/burn | `donate(token, amount)` | BondingTarget:743-794 | Keep as-is |
| Claim Liquidity | BPT | WETH | `claimLiquidity()` | BondingTarget:321-363 | Callback only |

### D. Missing Routes (Not Implemented)

| Route | Input | Output | Use Case | Priority |
|-------|-------|--------|----------|----------|
| Buy RICH | WETH | RICH | Direct WETH→RICH purchase | Medium |
| Sell RICH | RICH | WETH | Direct RICH→WETH sale | Medium |
| Mint RICHIR | WETH | RICHIR | Direct WETH→RICHIR (skip NFT) | High |
| RICHIR to CHIR | RICHIR | CHIR | Alternative redemption | Low |
| RICHIR to RICH | RICHIR | RICH | Alternative redemption | Low |
| ExactOut: CHIR→WETH | CHIR | WETH | Exact WETH output redemption | Medium |
| ExactOut: RICH→CHIR | RICH | CHIR | Exact CHIR output | Low |
| ExactOut: RICHIR→WETH | RICHIR | WETH | Exact WETH redemption | Medium |

## Route Matrix

```
             TO:
FROM:     WETH    CHIR    RICH    RICHIR    NFT
─────────────────────────────────────────────────
WETH       -      In/Out   -        -       Bond*
CHIR      In       -      Out       -        -
RICH       -      In       -       In*      Bond*
RICHIR    In       -       -        -        -
NFT        -       -       -       In*       -

Legend:
  In    = IStandardExchangeIn implemented
  Out   = IStandardExchangeOut implemented
  In*   = Custom function (needs refactor)
  Bond* = bondWithX function (needs refactor)
  -     = Not implemented
```

## Analysis

### Routes Already Conforming (6 total)
1. WETH → CHIR (exchangeIn)
2. WETH → CHIR exact (exchangeOut)
3. CHIR → WETH (exchangeIn)
4. RICH → CHIR (exchangeIn)
5. CHIR → RICH exact (exchangeOut)
6. RICHIR → WETH (exchangeIn)

### Routes Needing Refactor (4 total)
1. **bondWithWeth** → `exchangeIn(WETH, *, NFT, ...)`
2. **bondWithRich** → `exchangeIn(RICH, *, NFT, ...)`
3. **richToRichir** → `exchangeIn(RICH, *, RICHIR, ...)`
4. **sellNFT** → Special handling (NFT is ERC721, not ERC20)

### Routes to Keep As-Is (3 total)
1. **captureSeigniorage** - Protocol-only, no external token flow
2. **donate** - One-way donation, no output token
3. **claimLiquidity** - Callback from NFT vault, not user-initiated

## Special Considerations

### NFT Routes (ERC721)

The `sellNFT` function takes an NFT (ERC721) as input, which doesn't fit the `IERC20 tokenIn` parameter of IStandardExchangeIn. Options:

1. **Keep separate function** - NFTs are fundamentally different from fungible tokens
2. **Create IStandardExchangeInNFT** - New interface for NFT→ERC20 routes
3. **Wrap in adapter** - ERC721 adapter that presents NFT as fungible position

**Recommendation:** Keep `sellNFT()` as a separate function since NFTs require `tokenId` parameter. The Standard Exchange interfaces are designed for fungible token routing.

### Bond Routes (WETH/RICH → NFT)

The `bondWithWeth` and `bondWithRich` functions output an NFT, which doesn't fit `IERC20 tokenOut`. However, they also return `uint256 shares` (the BPT amount). Options:

1. **Keep separate** - NFT output is non-fungible
2. **Add lockDuration parameter** - Would need new struct or overload
3. **Return shares via exchangeIn** - Treat BPT as the "tokenOut" and mint NFT as side effect

**Recommendation:** These could potentially return BPT amount via `exchangeIn` with NFT minting as internal detail, but the `lockDuration` parameter is essential and not part of the Standard Exchange interface.

### RICH → RICHIR Route

The `richToRichir()` function is a good candidate for refactoring to `exchangeIn(RICH, *, RICHIR, ...)`:
- Both tokens are ERC20
- No additional parameters beyond standard (deadline, minAmountOut handled)
- Currently implemented in BondingTarget, would move to ExchangeInTarget

## Refactoring Plan

### Phase 1: Add Missing ExchangeIn Routes

Add to `ProtocolDETFExchangeInTarget`:

1. **RICH → RICHIR** (move from richToRichir)
   - Already implemented, just wire into exchangeIn dispatch
   - Keep `richToRichir()` as convenience wrapper

2. **WETH → RICHIR** (new)
   - Multi-hop: WETH → vault → unbalanced BPT → protocol NFT → RICHIR
   - Similar to richToRichir but with WETH input

3. **WETH → RICH** (new)
   - Multi-hop: WETH → CHIR/WETH vault → CHIR → RICH/CHIR vault → RICH

4. **RICH → WETH** (new)
   - Multi-hop: RICH → RICH/CHIR vault → CHIR → CHIR/WETH vault → WETH

### Phase 2: Add Missing ExchangeOut Routes

Add to `ProtocolDETFExchangeOutTarget`:

1. **CHIR → WETH exact** (new)
   - Exact WETH output redemption

2. **RICHIR → WETH exact** (new)
   - Exact WETH redemption amount

3. **WETH → RICH exact** (new)
   - Buy exact RICH amount with WETH

4. **RICH → CHIR exact** (new)
   - Sell RICH for exact CHIR amount

### Phase 3: Evaluate Bond Routes

Evaluate whether bond routes can be adapted:

1. **Option A:** Keep `bondWithWeth`/`bondWithRich` as protocol-specific
   - Pro: Clear semantics, lockDuration parameter
   - Con: Not composable with Standard Exchange routers

2. **Option B:** Add `exchangeIn(WETH/RICH, *, BPT, ...)` that returns BPT
   - Pro: Composable
   - Con: Loses NFT semantics, need separate NFT claim

3. **Option C:** Add new interface `IStandardBond`
   - Pro: Purpose-built for bonding semantics
   - Con: Adds interface complexity

**Recommendation:** Keep bond routes separate (Option A) since they involve time-locked positions.

## Implementation Priority

| Priority | Route | Reason |
|----------|-------|--------|
| P0 | RICH → RICHIR via exchangeIn | Already implemented, just needs wiring |
| P1 | WETH → RICHIR | High user demand, completes the RICHIR on-ramp |
| P2 | WETH → RICH | Enables direct RICH purchase |
| P2 | RICH → WETH | Enables direct RICH sale |
| P3 | ExactOut variants | Lower priority, exactIn covers most use cases |

## Interface Compliance Checklist

For each new route, ensure:

- [ ] `previewExchangeIn` / `previewExchangeOut` returns accurate estimate
- [ ] Deadline validation: `if (block.timestamp > deadline) revert DeadlineExceeded(...)`
- [ ] Slippage validation: `if (amountOut < minAmountOut) revert MinAmountNotMet(...)`
- [ ] Reentrancy protection via `lock` modifier
- [ ] `pretransferred` flag support for gas optimization
- [ ] Proper token detection via `_isXToken()` helpers
- [ ] Emits appropriate events

## Files to Modify

1. `contracts/vaults/protocol/ProtocolDETFExchangeInTarget.sol`
   - Add new route dispatches in `exchangeIn()` and `previewExchangeIn()`
   - Add `_executeRichToRichir()` (port from BondingTarget)
   - Add `_executeWethToRichir()`
   - Add `_executeWethToRich()`
   - Add `_executeRichToWeth()`

2. `contracts/vaults/protocol/ProtocolDETFExchangeOutTarget.sol`
   - Add new route dispatches in `exchangeOut()` and `previewExchangeOut()`
   - Add exact-out variants

3. `contracts/interfaces/IProtocolDETF.sol`
   - Update supported routes documentation

4. `test/foundry/spec/vaults/protocol/ProtocolDETF_Routes.t.sol`
   - Add tests for all new routes
