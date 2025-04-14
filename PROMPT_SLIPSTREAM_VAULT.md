# Slipstream Standard Exchange Vault Implementation

## Audience

New coding agent continuing work in this repo.

## Why This Plan Exists

IndexedEx currently supports Standard Exchange Vaults for:
- Uniswap V2
- Camelot V2
- Aerodrome V1 (stable/volatile pools)

Missing: Slipstream (Aerodrome's Concentrated Liquidity protocol)

This plan creates the missing Slipstream integration following existing patterns.

## Goal

Design, implement, and test a Standard Exchange Vault for the Slipstream (Aerodrome CL) protocol.

## Current Status / Remediation Context

This repository already contains a partial Slipstream implementation, but the current code does **not** satisfy this prompt yet.

Verified current state:
- `forge build` passes.
- The current Slipstream-specific tests pass, but they are shallow (`IFacet` selector tests and a placeholder route test).
- The implementation still contains simplified / placeholder logic where this prompt requires production share-accounting behavior.

### Verified Gaps To Remediate

- `ConstProdUtils._depositQuote(...)` is **not** currently used for Route 3 share minting.
- `ConstProdUtils._withdrawQuote(...)` is **not** currently used for Route 4 entitlement-first withdrawal accounting.
- `SlipstreamZapQuoter` is imported in the exchange-in target but is not actually used to compute the single-token zap contribution described below.
- `SlipstreamStandardExchangeDFPkg.sol` currently wires only **6 facets** and is missing `MultiAssetStandardVaultFacet`.
- `initAccount(...)` / package initialization is effectively incomplete for vault pool/strategy setup.
- Current Route 4 logic is a simplified proportional burn path, not the entitlement-first burn-then-settle path required here.
- Required explicit error coverage and custom error surface are not yet complete.
- Public zero-valued reserve-view behavior is documented here, but the current implementation/tests do not yet prove it correctly.
- The expected comprehensive integration test file is still missing; the current route test is only placeholder coverage.

### Remediation Checklist (Must Be Completed Before This Prompt Is Considered Done)

- [ ] Replace all simplified Route 3 share minting logic with canonical reserve snapshot + post-swap basket contribution + `ConstProdUtils._depositQuote(...)`.
- [ ] Replace all simplified Route 4 withdrawal logic with entitlement-first accounting based on `ConstProdUtils._withdrawQuote(...)`.
- [ ] Wire `SlipstreamZapQuoter` into Route 3 preview and execution sizing.
- [ ] Use `SlipstreamQuoter` / bounded same-pool settlement logic for Route 4 settlement swaps.
- [ ] Add `MultiAssetStandardVaultFacet` to the DFPkg facet bundle so the package contains the required 7 facets.
- [ ] Implement full vault/package initialization for pool, factory, and strategy-derived managed positions.
- [ ] Define and use explicit custom errors for invalid configuration, insufficient shares, entitlement overflow, slippage failure, deadline failure, and unsatisfied settlement bounds.
- [ ] Implement or expose zero-valued public reserve views while keeping internal canonical reserve accounting separate.
- [ ] Replace placeholder Slipstream route tests with substantive integration tests covering Routes 3 and 4.
- [ ] Add invariant and edge-case tests for bootstrap, rounding, dust exclusion, preview/execution consistency, entitlement caps, and repositioning safety.

## Background Research

### What is Slipstream?

- **Concentrated Liquidity (CL)** DEX by Aerodrome
- Similar to Uniswap V3 but with gauge integration
- Available on Base network
- Uses tick-based positions instead of simple LP tokens

### Key Differences from V2 AMMs

| Aspect | V2 AMMs (Uniswap/Camelot/Aerodrome V1) | Slipstream (CL) |
|--------|----------------------------------------|-----------------|
| Reserve Type | Single LP token (ERC20) | Position (tickLower, tickUpper, liquidity) |
| Liquidity | Uniform across all prices | Concentrated in price ranges |
| Token | `IUniswapV2Pair` / `ICamelotPair` / `IPool` | `ICLPool` with position key |
| Fees | Trading fees in LP token | Trading fees + gauge emissions |

### Core Interfaces (already in Crane)

- `ICLPool` - Pool operations (mint, burn, swap, collect)
- `ICLFactory` - Pool creation and discovery

### Math Libraries to Use (EXISTING - DO NOT REIMPLEMENT)

**Use these existing libraries:**
- `SlipstreamUtils.sol` - CL swap math, liquidity calculations
- `SlipstreamQuoter.sol` - Quote helpers
- `SlipstreamZapQuoter.sol` - Zap quote helpers

Location: `lib/daosys/lib/crane/contracts/utils/math/`

### Reference Implementations to Follow

1. `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeDFPkg.sol`
2. `contracts/protocols/dexes/camelot/v2/CamelotV2StandardExchangeDFPkg.sol`
3. `contracts/protocols/dexes/aerodrome/v1/AerodromeStandardExchangeDFPkg.sol`

### Key Technical Challenge

Unlike V2 AMMs, Slipstream **does not have an ERC20 LP token**. The vault's reserve state is a **set of liquidity positions** (not a single tokenized LP balance), each defined by:
- Pool address
- tickLower (lower price bound)
- tickUpper (upper price bound)
- liquidity (amount of liquidity)

For this strategy, the vault must support multiple managed positions, with at least one out-of-range position per token side.

## Implementation Plan

### Phase 1: Awareness Repos (Crane)

Create storage libraries for dependency injection.

**Files to create:**
- `contracts/protocols/dexes/aerodrome/slipstream/SlipstreamPoolAwareRepo.sol`
- `contracts/protocols/dexes/aerodrome/slipstream/SlipstreamFactoryAwareRepo.sol`

**Pattern:** Follow `AerodromeRouterAwareRepo.sol` structure

```
Storage struct with:
- Pool address
- Factory address
- Position key set (owner, tickLower, tickUpper)
```

### Phase 2: Vault Storage Repository

**File to create:**
- `contracts/vaults/slipstream/SlipstreamVaultRepo.sol`

**Pattern:** Follow `ConstProdReserveVaultRepo.sol`

**Storage:**
- Pool address
- Managed position declarations (at least one per token side)
- Position keys and per-position liquidity
- Last known pool state

#### Position Tracking Struct Design

The vault manages multiple CL positions. Use the following struct and tracking pattern:

```solidity
// Position represents a single Slipstream liquidity position owned by the vault
struct Position {
    int24 tickLower;
    int24 tickUpper;
    uint128 liquidity;
}

// PositionKey identifies a unique position: keccak256(owner, tickLower, tickUpper)
bytes32 constant POSITION_SLOT = keccak256("slipstream.vault.positions");

struct Storage {
    // Active managed positions (at least 2: one token0-side, one token1-side)
    Position[MAX_POSITIONS] positions;
    uint8 positionCount;
    
    // Strategy configuration
    uint24 widthMultiplier;
    uint24 token0SideOffsetMultiplier;
    uint24 token1SideOffsetMultiplier;
    
    // Last known pool state for cache invalidation
    uint160 lastSqrtPriceX96;
    int24 lastTick;
    uint32 lastTimestamp;
}
```

**Position Set Management:**

```solidity
// Add a new position
function _addPosition(int24 tickLower_, int24 tickUpper_, uint128 liquidity_) internal {
    require(positionCount < MAX_POSITIONS, "Too many positions");
    positions[positionCount++] = Position(tickLower_, tickUpper_, liquidity_);
}

// Find position index by ticks
function _findPositionIndex(int24 tickLower_, int24 tickUpper_) internal view returns (int8 index) {
    for (uint8 i = 0; i < positionCount; i++) {
        if (positions[i].tickLower == tickLower_ && positions[i].tickUpper == tickUpper_) {
            return int8(uint8(i));
        }
    }
    return -1;
}

// Update position liquidity
function _updatePositionLiquidity(uint8 index, uint128 newLiquidity) internal {
    positions[index].liquidity = newLiquidity;
}
```

**MAX_POSITIONS** should be set to a reasonable maximum (e.g., 8) to bound loop operations.

### Phase 3: Common Logic

**File to create:**
- `contracts/protocols/dexes/aerodrome/slipstream/SlipstreamStandardExchangeCommon.sol`

**Pattern:** Follow `AerodromeStandardExchangeCommon.sol`

**Functions:**
- `_loadPoolState()` - Load current pool reserves and liquidity
- `_calculatePositionValue()` - Calculate LP position value in underlying tokens
- `_calculateVaultFees()` - Protocol fee calculation
- `_mintPosition()` - Add liquidity to pool
- `_burnPosition()` - Remove liquidity from pool

### Phase 4: Exchange In Facet/Target

**Files to create:**
- `contracts/protocols/dexes/aerodrome/slipstream/SlipstreamStandardExchangeInFacet.sol`
- `contracts/protocols/dexes/aerodrome/slipstream/SlipstreamStandardExchangeInTarget.sol`

**Pattern:** Follow `UniswapV2StandardExchangeInTarget.sol`

**Interface:** `IStandardExchangeIn`
- `previewExchangeIn(tokenIn, amountIn, tokenOut)`
- `exchangeIn(tokenIn, amountIn, tokenOut, minAmountOut, recipient, pretransferred, deadline)`

**Supported Routes:**
1. **Passthrough Swap**: token0 ↔ token1
2. **Zap In Vault Deposit**: token0/token1 → reposition if needed → swap through same Slipstream pool → mint vault shares

### Phase 5: Exchange Out Facet/Target

**Files to create:**
- `contracts/protocols/dexes/aerodrome/slipstream/SlipstreamStandardExchangeOutFacet.sol`
- `contracts/protocols/dexes/aerodrome/slipstream/SlipstreamStandardExchangeOutTarget.sol`

**Pattern:** Follow `UniswapV2StandardExchangeOutTarget.sol`

**Interface:** `IStandardExchangeOut`
- `previewExchangeOut(tokenIn, tokenOut, amountOut)`
- `exchangeOut(tokenIn, maxAmountIn, tokenOut, amountOut, recipient, pretransferred, deadline)`

**Supported Routes:**
1. **Passthrough Swap**: token0 ↔ token1
2. **Zap Out Vault Withdrawal**: burn vault shares → withdraw/reposition liquidity → settle through same Slipstream pool → token0/token1

### Phase 6: Diamond Factory Package

**File to create:**
- `contracts/protocols/dexes/aerodrome/slipstream/SlipstreamStandardExchangeDFPkg.sol`

**Pattern:** Follow `AerodromeStandardExchangeDFPkg.sol`

**Key Functions:**
```solidity
struct SlipstreamStrategyConfig {
    uint24 widthMultiplier;
    uint24 token0SideOffsetMultiplier;
    uint24 token1SideOffsetMultiplier;
}

function deployVault(
    ICLPool pool,
    SlipstreamStrategyConfig memory strategyConfig
) external returns (address vault);

function deployVault(
    ICLPool pool,
    SlipstreamStrategyConfig memory strategyConfig,
    IERC20 tokenIn,
    uint256 amountIn,
    address recipient
) external returns (address vault);
```

If implementation convenience requires passing explicit managed position declarations instead of only multipliers, those declarations must still be derived from and validated against the same fixed strategy configuration.

**Facet Bundle (7 facets - NO ERC4626):**
Since Slipstream has no LP token, this vault uses MultiAsset facets instead of ERC4626.

1. ERC20Facet
2. ERC5267Facet
3. ERC2612Facet
4. **MultiAssetBasicVaultFacet** (replaces ERC4626BasicVaultFacet)
5. **MultiAssetStandardVaultFacet** (replaces ERC4626StandardVaultFacet)
6. SlipstreamStandardExchangeInFacet
7. SlipstreamStandardExchangeOutFacet

**Note:** This vault uses MultiAsset facets for interface compatibility, but because Slipstream positions are not tokenized reserve assets, public reserve view methods remain zero-valued.
- `reserveOfToken(token)` and `reserves()` are expected to return `0` for this vault.
- Internal share accounting must still use the vault's canonical economic reserve basis; the zero-valued public reserve views must not be reused as accounting inputs.

### Phase 7: Testing

**Files to create:**
- `contracts/protocols/dexes/aerodrome/slipstream/test/bases/TestBase_SlipstreamStandardExchange.sol`
- `test/foundry/spec/protocol/dexes/aerodrome/slipstream/SlipstreamStandardExchangeInFacet_IFacet_Test.t.sol`
- `test/foundry/spec/protocol/dexes/aerodrome/slipstream/SlipstreamStandardExchangeOutFacet_IFacet_Test.t.sol`
- `test/foundry/spec/protocol/dexes/aerodrome/slipstream/SlipstreamStandardExchange_Test.t.sol`

**Pattern:** Follow existing test structure

**Additional required tests:**
- Burned-share reserve entitlement: `_withdrawQuote` split matches expected pro-rata share of vault-owned reserves.
- Economic safety: no profitable immediate deposit -> withdraw round-trip (within tolerated dust) under configured slippage/rounding/reposition workflow.
- Reserve-definition consistency: deposit/withdraw/preview paths use the same internal canonical reserve basis when computing share entitlement.
- Bootstrap behavior: first mint path using `_depositQuote` is deterministic and enforces minimum initial deposit constraints.
- Rounding boundary tests: tiny/large mint-burn cases preserve accounting invariants and dust/refund behavior.
- Entitlement cap invariant: single-token withdrawal output does not exceed user's apportioned entitlement budget beyond configured slippage tolerance.
- Preview/execution consistency under declared snapshot timing policy.
- Explicit error-path coverage for all required custom errors.
- Settlement conversion safety: single-token settlement swap never consumes more than the entitled opposing reserve.
- Public reserve view behavior: `reserveOfToken(token)` and `reserves()` return zero while internal share accounting still uses canonical economic reserves.
- Temporary idle handling: intermediate burn/remint/swap steps may create loose balances, but leftover dust is excluded from canonical reserves until redeployed as liquidity.
- Repositioning safety: inventory normalization remains swapless and does not itself move market price.

### On-Chain vs Off-Chain Optimization Policy (Required)

Choose one mode and keep it consistent in code/tests:
- **On-chain bounded search:** binary search runs on-chain with strict bounds.
- **Off-chain quote + on-chain verification:** candidate burn/swap quoted off-chain, enforced on-chain with guard rails.

Default recommendation: start with on-chain bounded search for determinism, then migrate to off-chain quote + on-chain verification if gas profiling requires it.

## Design Decisions

### Decision 1: Multi-Position Vault Model

**Chosen:** Vault manages multiple Slipstream positions.

**Rationale:**
- Strategy requires at least one out-of-range position per token side.
- Avoids forcing all reserve state into a single tick band.
- Better aligns with single-token user IO while preserving proportional share accounting.
- Enables controlled repositioning between side-specific position buckets.

### Decision 2: No Staking in Initial Version

**Chosen:** Vault will support staked positions, but staking integration is deferred until after core business logic is implemented and tested.

**Rationale:**
- Deliver and validate core swap/deposit/withdraw/share-accounting logic first.
- Reduce integration risk by introducing gauge/staking logic after core behavior is test-stable.
- Keep rollout phased: core business logic first, staking support immediately after.

### Decision 3: Tick Range Strategy

**Approach:** Accept tick parameters at deployment for managed position declarations

Define strategy in `tickSpacing` multipliers (not absolute raw ticks) so each vault instance keeps a consistent relative placement policy across pools.

**Parameters:**
- strategy configuration determines managed position declarations at runtime
- At least one declared position for each token-side out-of-range posture
- All ticks must align to tickSpacing
- All ticks must be within MIN_TICK/MAX_TICK

**Tick-Spacing Multiplier Configuration (Required):**
- `widthMultiplier`: position width in units of `tickSpacing`
- `token0SideOffsetMultiplier`: distance above current aligned tick for token0-side out-of-range anchor
- `token1SideOffsetMultiplier`: distance below current aligned tick for token1-side out-of-range anchor

`token0SideOffsetMultiplier`, `token1SideOffsetMultiplier`, and `widthMultiplier` must all be `>= 1`.

**Runtime Tick Derivation (Required):**
- Read `tickSpacing` from `ICLPool.tickSpacing()`.
- Compute aligned base tick with floor behavior for signed ticks:
    - `baseTick = floor(currentTick / tickSpacing) * tickSpacing`
- Token0-side (fully token0 / above market):
    - `tickLower0 = baseTick + token0SideOffsetMultiplier * tickSpacing`
    - `tickUpper0 = tickLower0 + widthMultiplier * tickSpacing`
    - Enforce `currentTick < tickLower0`
- Token1-side (fully token1 / below market):
    - `tickUpper1 = baseTick - token1SideOffsetMultiplier * tickSpacing`
    - `tickLower1 = tickUpper1 - widthMultiplier * tickSpacing`
    - Enforce `currentTick >= tickUpper1`
- Clamp all derived ticks to protocol bounds and revalidate tick order.

This makes vault behavior portable and deterministic: strategy is expressed as relative market geometry rather than chain/pool-specific absolute ticks.

### Decision 4: Vault Position Strategy - Always Outside Range

**Approach:** Vault maintains liquidity in out-of-range side-specific positions (multi-position set)

**Rationale:**
- Single-sided exposure per side while preserving proportional share accounting at vault level
- Maximum swap fee capture when price crosses range
- Simpler user experience - deposits are always single-sided
- Repositioning: During exchange workflows, normalize in-range state into configured side-specific out-of-range positions without discretionary price-moving swaps

**Position Behavior:**
- Token0-side out-of-range positions hold token0-dominant exposure
- Token1-side out-of-range positions hold token1-dominant exposure
- Any temporary in-range exposure must be normalized back to configured side-specific out-of-range positions
- Repositioning is operational maintenance, not strategy rebalancing: it must not introduce a separate price-moving swap.
- Repositioning is integrated with `exchangeIn` / `exchangeOut` and with vault fee minting.

#### Repositioning Trigger (Required)

**Trigger Condition:** Repositioning occurs when a managed position becomes **double-sided / in-range**.

A position is in-range (double-sided) when:
```
currentTick >= position.tickLower AND currentTick < position.tickUpper
```

**Detection Logic:**
```solidity
function _isPositionInRange(int24 currentTick, Position storage pos) internal view returns (bool) {
    return currentTick >= pos.tickLower && currentTick < pos.tickUpper;
}

function _repositioningRequired() internal view returns (bool) {
    (, int24 currentTick, , , , ) = pool.slot0();
    for (uint8 i = 0; i < positionCount; i++) {
        if (_isPositionInRange(currentTick, positions[i])) {
            return true;
        }
    }
    return false;
}
```

**Repositioning Flow:**
1. Collect fees from the in-range position (automatic on burn)
2. Burn the in-range position completely
3. Use the reclaimed tokens + any new deposits to create new out-of-range positions
4. The new positions should be:
   - Token0-side: `tickLower0 = baseTick + token0SideOffsetMultiplier * tickSpacing`, `tickUpper0 = tickLower0 + widthMultiplier * tickSpacing`
   - Token1-side: `tickUpper1 = baseTick - token1SideOffsetMultiplier * tickSpacing`, `tickLower1 = tickUpper1 - widthMultiplier * tickSpacing`

**Fee Collection During Repositioning:**
When a position is burned (as part of repositioning), the vault automatically collects:
- Unclaimed trading fees via the pool's `collect()` callback
- These collected fees become part of the reclaimed tokens
- Protocol fees are then minted as shares before the remaining tokens are redeployed into new positions

This is the ONLY time fees are collected - not through a separate mechanism, but implicitly during the burn step of repositioning.

### Decision 5: ZapIn/ZapOut Processing

**Approach:** ZapIn and ZapOut are processed through exchangeIn/exchangeOut

**Rationale:**
- exchangeIn: User specifies amountIn (paying in) - handles deposits, swaps
- exchangeOut: User specifies amountOut (receiving out) - handles withdrawals, swaps
- Deposit path must convert single-token input into a proportional basket contribution before share minting.
- Withdraw path must realize a proportional basket entitlement first, then swap only as needed to settle into requested `tokenOut`.
- Any settlement swap must execute through the same Slipstream pool used by the vault's underlying positions.

### Decision 6: Supported Routes

The vault exposes only the `IStandardExchangeIn` and `IStandardExchangeOut` route surface. Dual-token deposits and proportional in-kind withdrawals are out of scope.

## Routes

### Route 1: Pass-Through Swap (exchangeIn)
- **tokenIn**: token0 OR token1
- **tokenOut**: token1 OR token0
- **Behavior**: Swap tokenIn for tokenOut through the underlying pool
- **Pre-condition**: None
- **Post-condition**: No change to vault position

### Route 2: Pass-Through Swap (exchangeOut)
- **tokenIn**: token0 OR token1
- **tokenOut**: token1 OR token0
- **Behavior**: Swap tokenIn for tokenOut through the underlying pool (exact output)
- **Pre-condition**: None
- **Post-condition**: No change to vault position

### Route 3: ZapIn Deposit (exchangeIn)
- **tokenIn**: token0 OR token1 (single token deposit)
- **tokenOut**: vault (receiving shares)
- **Behavior**: 
        1. If protocol fees need to be realized, collect uncollected fees and mint protocol fee shares first using the Aerodrome-vault fee pattern.
        2. Snapshot canonical pre-deposit reserves.
        3. Compute the single-token conversion needed to turn user input into a proportional basket contribution using `SlipstreamZapQuoter.quoteZapInSingleCore`.
        4. Execute the required swap through the same Slipstream pool so the user's contribution becomes `(amount0Deposit, amount1Deposit)` in the vault's canonical reserve proportions.
        5. Calculate shares to mint using `ConstProdUtils._depositQuote` with:
      - `lpTotalSupply` = total vault shares before mint
      - `lpReserveA` = canonical vault reserve of token0 before applying the user's new contribution
      - `lpReserveB` = canonical vault reserve of token1 before applying the user's new contribution
      - `amountADeposit` = actual token0 contribution after swap
      - `amountBDeposit` = actual token1 contribution after swap
        6. Mint shares to recipient.
        7. If an existing managed position is in-range / double-sided, withdraw that position and reposition the resulting tokens together with the user's newly created deposit basket back into the configured outside-range posture, without a discretionary price-moving swap.
        8. Any leftover remainder after best-effort deposit is treated as dust and is not part of canonical reserves until later redeployed as liquidity.
- **Pre-condition**: Vault may have in-range liquidity that needs repositioning after share minting
- **Post-condition**: User receives vault shares, vault has updated position

**Route 3 Required Invariants:**
- Single-token deposit must be converted into a proportional basket contribution before calling `_depositQuote(...)`.
- Share minting must be based on canonical pre-deposit reserves and actual post-swap deposit amounts, never on raw `amountIn` alone.
- Any normalization of existing vault inventory must be swapless and must not itself move market price.
- If a managed position is currently double-sided / in-range, Route 3 may withdraw and redeploy it only after share mint calculation has been fixed from the pre-deposit reserve snapshot and the user's post-swap deposit basket.
- End-of-operation vault state should be best-effort deployed into Slipstream positions; any undeployed remainder is dust and excluded from canonical reserves until redeposited.

#### Route 3 Reference Pseudocode (Required)

```solidity
// Inputs: tokenIn, amountIn, minAmountOut, recipient, deadline
// Output: sharesOut

// 0) Pull funds / validate route
actualAmountIn = pullTokenIn(tokenIn, amountIn, pretransferred);

// 1) Realize protocol fees first if needed
if (feeCollectionRequired()) {
    collectManagedPositionFees();
    mintProtocolFeeShares();
}

// 2) Snapshot canonical pre-deposit reserves for share accounting
(reserveABefore, reserveBBefore) = canonicalReserves();
(totalSharesBefore) = totalSupply();

// 3) Quote and execute single-pool conversion into proportional basket contribution
(swapAmountIn, amountADeposit, amountBDeposit) = quoteZapInSingleCore(tokenIn, actualAmountIn, ...);
executeSettlementSwapThroughVaultPool(tokenIn, swapAmountIn, ...);

// 4) Calculate shares from actual post-swap deposit legs
sharesOut = _depositQuote(
    totalSharesBefore,
    reserveABefore,
    reserveBBefore,
    amountADeposit,
    amountBDeposit
);

// 5) Enforce slippage on shares, mint shares, then deploy contributed basket
require(sharesOut >= minAmountOut, SlippageGuardFailure(...));
mintShares(recipient, sharesOut);

// 6) If an existing managed position is double-sided / in-range, withdraw it,
//    then reposition the combined inventory (withdrawn tokens + new deposit basket)
//    back into the configured outside-range posture without a price-moving swap.
if (repositioningRequired()) {
    (reclaimed0, reclaimed1) = withdrawInRangeManagedPosition(...);
}
deployBestEffortIntoManagedPositions(
    amountADeposit + reclaimed0,
    amountBDeposit + reclaimed1,
    ...
);

// 7) Any undeployed remainder is dust, not canonical reserve
return sharesOut;
```

### Route 4: Proportional Withdraw Then Settle (exchangeOut)
- **tokenIn**: vault shares (burned)
- **tokenOut**: token0 OR token1 (single-token withdrawal)
- **Behavior**:
    1. Solve for the actual share amount to burn, `sharesBurned`, bounded by `maxAmountIn`, then compute the user's pro-rata reserve entitlement from those burned shares using `_withdrawQuote`:
            - `ownedLPAmount = sharesBurned`
            - `lpTotalSupply = total vault shares`
            - `totalReserveA = total vault-owned reserve of token0`
            - `totalReserveB = total vault-owned reserve of token1`
            - `(ownedReserveA, ownedReserveB) = _withdrawQuote(...)`
    2. Treat `(ownedReserveA, ownedReserveB)` as the user's proportional basket entitlement. This entitlement is fixed before any settlement swap.
    3. If repositioning/fee collection is required, collect uncollected fees, mint protocol fee shares first, and normalize in-range positions before satisfying the withdrawal.
    4. Realize that entitlement from the underlying Slipstream positions by withdrawing/burning the required liquidity, drawing first from the position associated with the requested `tokenOut`.
    5. Map the entitlement into direct side plus opposing side relative to requested `tokenOut`.
    6. If the user requests single-token settlement, swap from the entitled opposing reserve into `tokenOut` through the same Slipstream pool under bounded quote/slippage rules.
    7. Execute burn + settlement swap with hard protections (`maxBurnLiquidity`, `minAmountOut`, `sqrtPriceLimitX96`, `deadline`) and ensure final output is bounded by entitlement + configured slippage rules.
    8. Return any dust/refund and finalize share burn/accounting.
- **Pre-condition**: User has sufficient shares.
- **Post-condition**: User receives requested single token with minimal liquidity burn.

**Route 4 Required Invariants:**
- Withdrawal must always be entitlement-first: burn shares into a proportional basket claim before any token-specific settlement.
- Any settlement swap into requested `tokenOut` may consume only the user's entitled opposing reserve.
- Single-token withdrawal output must never exceed the user's proportional basket entitlement converted under bounded execution rules.
- Liquidity realization order must prefer the position associated with requested `tokenOut` before consuming the opposing-side position.

#### Route 4 Reference Pseudocode (Required)

```solidity
// Inputs: maxAmountIn (max shares to burn), tokenOut, amountOut, recipient, deadline, bounds
// Output: sharesBurned

// 0) Burn input shares only after any required fee-mint/reposition state is settled
if (repositioningRequired()) {
    collectManagedPositionFees();
    mintProtocolFeeShares();
    repositionToOutsideRanges();
}

// 1) Solve the exact-output burn requirement and bound it by maxAmountIn
sharesBurned = solveSharesForExactOutput(amountOut, tokenOut, maxAmountIn, ...);

// 2) Entitlement split from burned shares
(ownedReserveA, ownedReserveB) = _withdrawQuote(sharesBurned, totalShares, totalReserveA, totalReserveB);

// 3) Map direct/opposing reserves for requested tokenOut
directOut = tokenOut == tokenA ? ownedReserveA : ownedReserveB;
opposingEntitlement = tokenOut == tokenA ? ownedReserveB : ownedReserveA;

// 4) Realize entitlement basket from underlying liquidity, preferring the position associated with tokenOut
(realized0, realized1) = withdrawUnderlyingForEntitlement(ownedReserveA, ownedReserveB, ...);

// 5) Map direct and opposing balances for requested tokenOut
directOut = tokenOut == tokenA ? realized0 : realized1;
opposingEntitlement = tokenOut == tokenA ? realized1 : realized0;

// 6) If needed, swap only from entitled opposing reserve into requested tokenOut
settlementOut = quoteAndSwapWithinEntitlement(opposingEntitlement, tokenOut, amountOut, deadline, ...);

// 7) Final payout must be bounded by realized entitlement and settlement guards
```

### Required Execution Ordering (Normative)

Route 3 ordering:
1. Pull user funds.
2. Collect uncollected fees and mint protocol fee shares first if fee realization is required.
3. Snapshot canonical internal reserves.
4. Execute the user settlement swap through the same Slipstream pool to form the proportional deposit basket.
5. Compute and mint user shares from the pre-deposit reserve snapshot and actual post-swap deposit legs.
6. If an existing managed position is in-range / double-sided, withdraw it.
7. Reposition the combined inventory (withdrawn tokens plus user deposit basket) back to the configured outside-range posture without a discretionary price-moving swap.
8. Treat any remainder as dust excluded from canonical reserves until redeployed.

Route 4 ordering:
1. Detect whether any managed position is in-range or otherwise needs maintenance.
2. Collect uncollected fees from affected positions.
3. Mint protocol fee shares before any user-facing burn/settlement work.
4. Reposition liquidity back to the configured outside-range posture without a discretionary price-moving swap if needed for orderly withdrawal.
5. Snapshot canonical internal reserves.
6. Solve user share burn accounting.
7. Execute final best-effort liquidity withdrawal.
8. Execute the user settlement swap through the same Slipstream pool if the route requires one.
9. Treat any remainder as dust excluded from canonical reserves until redeployed.

[Additional routes to be documented as they are described]

## Technical Implementation Details

### Position Key Calculation

```solidity
bytes32 positionKey = keccak256(abi.encode(
    address(this),  // owner
    tickLower,
    tickUpper
));
```

### Liquidity Value Calculation

`_quoteAmountsForLiquidity` calculates the value of a **single position** in terms of token0 and token1. It does NOT aggregate across positions - it calculates the value of one position's liquidity at the current pool price.

**For a single position:**
```solidity
// Use SlipstreamUtils
(uint256 amount0, uint256 amount1) = SlipstreamUtils._quoteAmountsForLiquidity(
    sqrtPriceX96,
    tickLower,
    tickUpper,
    liquidity
);
// Returns: how much token0 and token1 this position is worth at current price
```

**For the vault's total reserve (all positions):**
You must SUM the values across ALL managed positions:

```solidity
function _totalVaultReserves() internal view returns (uint256 reserve0, uint256 reserve1) {
    (, int24 currentTick, , , , ) = pool.slot0();
    uint160 sqrtPriceX96 = TickMath.getSqrtRatioAtTick(currentTick);
    
    for (uint8 i = 0; i < positionCount; i++) {
        Position storage pos = positions[i];
        (uint256 pos0, uint256 pos1) = SlipstreamUtils._quoteAmountsForLiquidity(
            sqrtPriceX96,
            pos.tickLower,
            pos.tickUpper,
            pos.liquidity
        );
        reserve0 += pos0;
        reserve1 += pos1;
    }
}
```

**Key insight:** `_quoteAmountsForLiquidity` gives you the value of ONE position. The vault's total reserve is the sum of all position values. This is used for:
- Share minting (deposit quotes)
- Share burning (withdraw quotes)
- Preview functions

### Reserve Due for Burned Vault Shares

To calculate the portion of vault-owned underlying reserve due to a user burning vault shares, use
`ConstProdUtils._withdrawQuote(...)` as the pro-rata reserve split helper.

Inputs:
- `ownedLPAmount = sharesBurned` (actual vault shares burned for the withdrawal)
- `lpTotalSupply = total vault shares`
- `totalReserveA = total vault-owned reserve of token0`
- `totalReserveB = total vault-owned reserve of token1`

Call:

```solidity
(uint256 ownedReserveA, uint256 ownedReserveB) = ConstProdUtils._withdrawQuote(
    ownedLPAmount,
    lpTotalSupply,
    totalReserveA,
    totalReserveB
);
```

Interpretation:
- `ownedReserveA` and `ownedReserveB` are the user's proportional basket entitlement before any token-specific settlement.
- Final single-token output is then solved by first realizing that proportional entitlement from underlying liquidity and then swapping only as needed to settle into requested `tokenOut`.

### Canonical Reserve Basis (Required)

All share-mint, share-burn, and preview logic must use the same reserve basis.

Define:
- `positionReserve0`, `positionReserve1`: derived from current position state using `SlipstreamUtils._quoteAmountsForLiquidity(...)`.
- `uncollectedFeeReserve0`, `uncollectedFeeReserve1`: fees claimable from managed positions and treated as part of vault economics before protocol fee minting.
- `idleDust0`, `idleDust1`: undeployed token balances remaining after best-effort liquidity operations. These balances are not part of canonical reserves until later redeployed as liquidity.

Required reserve inputs for share apportioning:
- `totalReserveA = positionReserveA + uncollectedFeeReserveA`
- `totalReserveB = positionReserveB + uncollectedFeeReserveB`

Required fee-handling policy:
- Uncollected fees are part of canonical reserves.
- When positions are repositioned, fees must be collected first.
- Vault protocol fee shares must be minted before any other deposit/withdraw settlement work, following the Aerodrome vault fee pattern.
- Any collected remainder that cannot be redeployed in the same operation is dust, not canonical reserve.

### Reserve Snapshot Timing (Required)

To keep preview and execution deterministic:
- Deposit preview snapshot: before swap and before mint, using current active-liquidity value plus uncollected fees.
- Deposit execution snapshot: after any required fee collection / protocol-fee minting / repositioning, after swap, and before share mint.
- Withdraw preview snapshot: before burn and before swap, using current active-liquidity value plus uncollected fees.
- Withdraw execution snapshot: after any required fee collection / protocol-fee minting / repositioning, after burn, after swap, and after refunds/dust handling.

Any reserve-dependent share calculation must explicitly use one of these snapshots and tests must validate consistency.

### Share Accounting Policy (Required)

This vault uses proportional two-token reserve accounting (constant-product style share apportioning), not ERC4626-style single-asset accounting.

Required behavior:
- Mint path (Route 3): single-token input must be swapped into a proportional basket contribution first, then use `_depositQuote(...)` with canonical pre-deposit reserves and actual post-swap deposit amounts.
- Burn path (Route 4): use `_withdrawQuote(...)` for pro-rata basket entitlement first, realize that entitlement from underlying liquidity, then perform only the settlement swap needed to deliver requested `tokenOut`.
- Define explicit rounding direction and dust/refund handling for both mint and burn paths.
- Define bootstrap / first-liquidity constraints for `_depositQuote` (`lpTotalSupply == 0`) and enforce minimum initial deposit thresholds.
- Internal accounting reserves and public `reserveOfToken()` / `reserves()` views are intentionally different for this vault; tests must enforce that public reserve views stay zero while share accounting uses the canonical internal reserve basis.

### Bootstrap Policy (Required)

For `lpTotalSupply == 0`:
- Route 3 must still perform the single-token-to-basket conversion first.
- Both resulting deposit legs must be non-zero before minting initial shares.
- Initial shares must be exactly the output of `ConstProdUtils._depositQuote(...)` using zero pre-deposit supply/reserves; do not layer an alternate bootstrap formula around it.
- If the post-swap contribution is too small to produce a valid initial two-sided deposit, revert with an explicit bootstrap/insufficient-initial-liquidity style error.

### Rounding Direction Defaults (Required)

Unless the called helper already fixes the behavior more strictly, implementation should follow these defaults:
- Route 3 share minting rounds down in favor of the vault.
- Route 4 reserve entitlement from `_withdrawQuote(...)` is treated as rounded down entitlement.
- Any exact-output calculation for required share burn or liquidity burn rounds up against the caller.
- Preview functions must use the same rounding directions as execution-path quote logic.

### Rounding Policy (Required)

Define once and enforce everywhere:
- Minting shares from deposit: explicit rounding direction for `sharesOut`.
- Burning shares to entitlement: expected rounding behavior from `_withdrawQuote` outputs.
- Deficit satisfaction check: `directOut + swapOut >= requiredOut` with explicit tolerated dust threshold.
- Dust/refund policy: best-effort deploy/settle, return what the route returns, and exclude undeployed dust from canonical reserves until later deposited as liquidity.

### Error Surface (Required)

Define and use explicit errors for:
- Invalid tick/range params
- Insufficient shares
- Entitlement exceeded
- Deficit not satisfiable within `maxBurnLiquidity`
- Slippage guard failure (`minAmountOut`/`maxAmountIn`)
- Deadline exceeded
- Quote, settlement, or liquidity-realization failure when requested output cannot be satisfied within configured execution bounds

### ERC4626 Integration (NOT USED)

This vault does NOT use ERC4626. Instead it uses MultiAsset vaults:
- `MultiAssetBasicVaultFacet.sol`
- `MultiAssetStandardVaultFacet.sol`

This vault must instead keep internal reserve accounting separate from public reserve view methods. Public reserve view methods remain zero-valued even though internal share accounting tracks underlying position economics.

## Operational Defaults

- Repositioning is not discretionary rebalancing. It is maintenance that restores the configured outside-range posture during `exchangeIn` / `exchangeOut` flows without introducing a separate price-moving swap.
- Settlement conversion for deposits and withdrawals must use the same Slipstream pool that backs the vault positions.
- Uncollected fees belong to canonical reserves until collected. When a workflow requires repositioning, collect fees first, mint protocol fee shares first, then continue with user settlement.
- Dual-token deposit routes and proportional in-kind withdrawal routes are not supported. The public route surface is only `IStandardExchangeIn` and `IStandardExchangeOut`.
- Public `reserveOfToken()` / `reserves()` methods return zero for this vault because Slipstream liquidity is not represented as reserve ERC20 balances. Do not use these methods for internal accounting.
- Dust is whatever undeployed remainder remains after best-effort liquidity sizing and settlement. No exact universal threshold is required.
- Withdrawal liquidity realization should prefer the position associated with the requested output token before drawing from the opposing-side position.

## Non-Negotiable Constraints

- **No `new` keyword** - All deployments via CREATE3 factory
- **Follow existing code patterns** - Match structure of V2 vaults exactly
- **Test inheritance** - Use TestBase classes
- **Storage pattern** - Use Repo pattern for all storage
- **Use `SlipstreamZapQuoter` / `SlipstreamQuoter` for swap and liquidity sizing**
- **Use `ConstProdUtils._depositQuote` and `ConstProdUtils._withdrawQuote` consistently for proportional share mint/burn accounting**
- **Use a consistent internal reserve basis (`active position value + uncollected fees`, excluding undeployed dust) across mint, burn, and preview logic**

## File Structure

```
contracts/
├── protocols/dexes/aerodrome/slipstream/
│   ├── SlipstreamStandardExchangeDFPkg.sol
│   ├── SlipstreamStandardExchangeCommon.sol
│   ├── SlipstreamStandardExchangeInFacet.sol
│   ├── SlipstreamStandardExchangeInTarget.sol
│   ├── SlipstreamStandardExchangeOutFacet.sol
│   ├── SlipstreamStandardExchangeOutTarget.sol
│   ├── SlipstreamPoolAwareRepo.sol
│   ├── SlipstreamFactoryAwareRepo.sol
│   └── test/bases/
│       └── TestBase_SlipstreamStandardExchange.sol
└── vaults/
    └── slipstream/
        └── SlipstreamVaultRepo.sol

test/foundry/spec/protocol/dexes/aerodrome/slipstream/
    ├── SlipstreamStandardExchangeInFacet_IFacet_Test.t.sol
    ├── SlipstreamStandardExchangeOutFacet_IFacet_Test.t.sol
    └── SlipstreamStandardExchange_Test.t.sol
```

## Dependencies

### Crane (already exists)
- `ICLPool`
- `ICLFactory`
- `SlipstreamUtils`
- `SlipstreamQuoter`
- `SlipstreamZapQuoter`

### IndexedEx (already exists)
- `StandardVaultRepo`
- `VaultFeeOracleQueryAwareRepo`
- `Permit2AwareRepo`
- `MultiAssetBasicVaultFacet`
- `MultiAssetStandardVaultFacet`
- Standard interfaces: `IStandardExchangeIn`, `IStandardExchangeOut`, `IStandardVault`

## Verification Commands

```bash
# Build
forge build

# Run all Slipstream tests
forge test --match-path "test/foundry/spec/protocols/dexes/aerodrome/slipstream/*"

# Run specific test
forge test --match-test testSlipstreamExchangeIn

# Run with verbose output
forge test -vvv
```

## Concrete Remediation Patch Plan (Per File)

Use this section as the authoritative patch checklist for bringing the current partial implementation up to the requirements in this prompt.

### 1. `contracts/protocols/dexes/aerodrome/slipstream/SlipstreamStandardExchangeDFPkg.sol`

**Current issue:** The package bundle is incomplete and initialization is effectively a stub.

**Required patch plan:**
- Add `MultiAssetStandardVaultFacet` to `PkgInit` and immutable storage.
- Expand `facetCuts()` from 6 to 7 facet cuts.
- Keep the bundle order explicit and aligned with this prompt:
  1. ERC20Facet
  2. ERC5267Facet
  3. ERC2612Facet
  4. MultiAssetBasicVaultFacet
  5. MultiAssetStandardVaultFacet
  6. SlipstreamStandardExchangeInFacet
  7. SlipstreamStandardExchangeOutFacet
- Implement `initAccount(bytes memory pkgArgs)` so it decodes pool + strategy config and initializes:
  - `SlipstreamPoolAwareRepo`
  - `SlipstreamFactoryAwareRepo`
  - `SlipstreamVaultRepo`
  - any required vault fee / permit2 / multi-asset dependencies already used by sibling DFPkgs
- Ensure vault declaration and interface exposure remain aligned with `IStandardExchangeIn` + `IStandardExchangeOut`.
- If current helper/base-package patterns require a target-based `processArgs` or similar initialization hook, follow the Aerodrome V1 / Camelot V2 pattern exactly instead of improvising a new package lifecycle.

**Verification:**
- `forge build`
- `forge test --match-contract SlipstreamStandardExchangeInFacet_IFacet_Test -vvv`
- `forge test --match-contract SlipstreamStandardExchangeOutFacet_IFacet_Test -vvv`

### 2. `contracts/vaults/slipstream/SlipstreamVaultRepo.sol`

**Current issue:** Storage primitives exist, but this file must become the single source of truth for strategy-derived managed positions and cached pool state.

**Required patch plan:**
- Verify and harden `StrategyConfig` validation:
  - multipliers must be `>= 1`
  - derived ticks must align to `tickSpacing`
  - derived ticks must remain within protocol bounds
  - token0-side position must be strictly above current tick
  - token1-side position must be at/below current tick per the rules in this prompt
- Add explicit custom errors for invalid width/offset/tick derivation instead of generic revert strings.
- Ensure initialization derives the two required side-specific out-of-range positions from current pool state, not from arbitrary raw ticks.
- Keep helper methods for:
  - finding positions
  - updating liquidity
  - iterating active positions
  - determining whether any managed position is in range
- Store only canonical managed-position state here; do **not** mix public reserve-view semantics into repo accounting.

**Verification:**
- unit/integration tests that assert derived positions satisfy the token0-side / token1-side posture constraints

### 3. `contracts/protocols/dexes/aerodrome/slipstream/SlipstreamStandardExchangeCommon.sol`

**Current issue:** This file contains simplified placeholder math/comments and currently mixes useful helpers with incomplete logic.

**Required patch plan:**
- Keep only shared helpers here; remove or replace any placeholder quote logic used as a substitute for the required route math.
- Preserve `_totalVaultReserves()` as the canonical position-value aggregation helper, but ensure canonical reserves are defined as:
  - active position value
  - plus uncollected fee value
  - excluding undeployed dust
- If uncollected-fee accounting needs explicit helper functions, add them here so both preview and execution paths call the same logic.
- If public `reserveOfToken()` / `reserves()` live outside this file (likely in multi-asset facets), document via comments here that those views must never be reused for internal share accounting.
- Remove placeholder `_getPoolReserves()` / `_estimatePoolLiquidity()` style logic or convert it into private/internal helpers that cannot be accidentally used for final accounting.
- Centralize same-pool settlement quoting helpers here if both targets need them.

**Verification:**
- tests that compare canonical reserve snapshots used by preview vs execution
- diagnostics should have no leftover unused placeholder locals/params

### 4. `contracts/protocols/dexes/aerodrome/slipstream/SlipstreamStandardExchangeInTarget.sol`

**Current issue:** Route 3 is still simplified and does not use the required zap-quote and `_depositQuote(...)` flow.

**Required patch plan:**
- For Route 1 (passthrough swap), preserve the existing direct swap path if it is already correct.
- For Route 3 (single-token deposit to shares):
  1. Pull actual input funds.
  2. If needed, collect fees and mint protocol fee shares **before** user reserve accounting.
  3. Snapshot canonical pre-deposit reserves and total share supply.
  4. Use `SlipstreamZapQuoter.quoteZapInSingleCore(...)` (or a thin wrapper over it) to determine:
     - swap amount
     - resulting token0/token1 deposit legs
     - dust / unused amounts
  5. Execute the settlement swap through the same Slipstream pool.
  6. Calculate `sharesOut` using `ConstProdUtils._depositQuote(...)` with:
     - `lpTotalSupply = totalSharesBefore`
     - `lpReserveA/B = canonical reserves before deposit`
     - `amountADeposit/BDeposit = actual post-swap contribution legs`
  7. Enforce `minAmountOut` against `sharesOut`.
  8. Mint shares.
  9. If repositioning is required, withdraw in-range managed positions and redeploy combined inventory without a discretionary price-moving swap.
  10. Treat undeployed remainder as dust excluded from canonical reserves.
- Replace current simplified value-based minting (`valueAdded * totalShares / totalValue`) with the `_depositQuote(...)` flow above.
- Replace placeholder comments about “actual implementation would use SlipstreamZapQuoter” with real helper integration.
- Add explicit custom errors for:
  - invalid route
  - deadline expired
  - invalid zap quote / zero basket legs
  - bootstrap insufficient liquidity
  - slippage guard failure

**Tests required for this file:**
- bootstrap first mint
- second mint using canonical pre-deposit reserves
- preview vs execution consistency
- single-token deposit converted into proportional basket before `_depositQuote(...)`
- slippage failure
- deadline failure
- reposition-required path
- dust excluded from canonical reserves

### 5. `contracts/protocols/dexes/aerodrome/slipstream/SlipstreamStandardExchangeOutTarget.sol`

**Current issue:** Route 4 is implemented as a simplified proportional burn/removal path instead of the required entitlement-first withdrawal flow.

**Required patch plan:**
- For Route 2 (passthrough exact-output swap), preserve the existing direct path if it is correct.
- For Route 4 (shares -> single token):
  1. Perform any required fee collection / protocol fee mint / maintenance repositioning first.
  2. Snapshot canonical internal reserves.
  3. Solve the actual share burn requirement bounded by `maxAmountIn`.
  4. Use `ConstProdUtils._withdrawQuote(...)` to compute `(ownedReserveA, ownedReserveB)` entitlement from burned shares.
  5. Realize that entitlement from underlying positions, preferring the position associated with `tokenOut` first.
  6. Execute only the bounded settlement swap required to convert the entitled opposing reserve into `tokenOut` through the same Slipstream pool.
  7. Enforce `maxAmountIn`, `amountOut`, price-limit, and deadline protections.
  8. Refund dust / remainder per policy.
- Replace the current simplified logic that directly computes `expectedAmount = reserve * shares / totalShares` and burns proportional liquidity without the `_withdrawQuote(...)` entitlement layer.
- Ensure the final output cannot exceed the user’s entitlement budget plus configured slippage tolerance.
- Add explicit custom errors for:
  - insufficient shares
  - entitlement exceeded
  - settlement deficit unsatisfied within bounds
  - slippage failure
  - deadline failure

**Tests required for this file:**
- entitlement-first accounting proof
- requested-token-side preference in liquidity realization
- single-token settlement bounded by entitled opposing reserve
- preview vs execution consistency
- exact-output share-burn solve behavior
- slippage / deadline / insufficient-share errors

### 6. `contracts/protocols/dexes/aerodrome/slipstream/SlipstreamStandardExchangeInFacet.sol`
### 7. `contracts/protocols/dexes/aerodrome/slipstream/SlipstreamStandardExchangeOutFacet.sol`

**Current issue:** likely thin wrappers only.

**Required patch plan:**
- Keep these files thin.
- Ensure selectors, interface IDs, and target delegation remain stable after target changes.
- Do not place route math here.

**Verification:**
- existing `IFacet` tests must still pass unchanged or with only selector/interface expectation updates if truly required.

### 8. `contracts/protocols/dexes/aerodrome/slipstream/SlipstreamPoolAwareRepo.sol`
### 9. `contracts/protocols/dexes/aerodrome/slipstream/SlipstreamFactoryAwareRepo.sol`

**Current issue:** these appear present and mostly fine.

**Required patch plan:**
- Confirm initialization is actually invoked from the DFPkg / account-init lifecycle.
- Keep these repos minimal; do not add route/accounting logic here.
- If helpful, add assertions or explicit comments that these repos are required to be initialized exactly once during vault deployment.

### 10. `contracts/protocols/dexes/aerodrome/slipstream/test/bases/TestBase_SlipstreamStandardExchange.sol`

**Current issue:** exists, but test scaffolding is not yet supporting the required deep route/invariant coverage.

**Required patch plan:**
- Expand setup to support:
  - deterministic mock or fork-backed Slipstream pool state
  - deployment of the full 7-facet package
  - strategy-config initialization
  - helpers for seeding pool liquidity, moving price into/out of range, and triggering reposition paths
- Provide reusable helpers for:
  - Route 3 deposits
  - Route 4 withdrawals
  - canonical reserve snapshots
  - public reserve zero-view assertions

### 11. `test/foundry/spec/protocols/dexes/aerodrome/slipstream/SlipstreamStandardExchangeInFacet_IFacet_Test.t.sol`
### 12. `test/foundry/spec/protocols/dexes/aerodrome/slipstream/SlipstreamStandardExchangeOutFacet_IFacet_Test.t.sol`

**Current issue:** these are fine as interface tests, but they are not enough on their own.

**Required patch plan:**
- Keep these tests.
- Update only if facet function/interface exposure changes.
- Do not treat these as business-logic coverage.

### 13. `test/foundry/spec/protocols/dexes/aerodrome/slipstream/SlipstreamStandardExchange_Test.t.sol`

**Current issue:** this file is missing and must be created.

**Required patch plan:**
- Create this as the main integration / invariant suite.
- Either delete or subsume the current placeholder `SlipstreamStandardExchangeRoutes_Test.t.sol`; do not leave the placeholder route test as the only route coverage.
- Cover at minimum:
  - Route 1 passthrough exact-input swap
  - Route 2 passthrough exact-output swap
  - Route 3 zap-in deposit preview vs execution
  - Route 4 entitlement-first withdraw preview vs execution
  - bootstrap policy
  - rounding boundaries (tiny/large cases)
  - dust exclusion from canonical reserves
  - reserve-definition consistency
  - public reserve views remain zero
  - entitlement cap invariant
  - no profitable immediate deposit -> withdraw round trip beyond tolerated dust
  - repositioning safety / no discretionary price-moving swap in maintenance step
  - explicit custom-error paths

### 14. `test/foundry/spec/protocols/dexes/aerodrome/slipstream/SlipstreamStandardExchangeRoutes_Test.t.sol`

**Current issue:** current file is placeholder coverage only.

**Required patch plan:**
- Either remove this file and replace it with the real integration suite above, or rewrite it so it becomes a substantive route harness rather than a placeholder boolean test file.
- At minimum, eliminate trivial assertions like `assertTrue(true)` and tests that do not call real contract behavior.

## Implementation Order (Recommended)

1. Fix DFPkg facet bundle + initialization.
2. Harden `SlipstreamVaultRepo` strategy derivation and validation.
3. Refactor `SlipstreamStandardExchangeCommon.sol` so canonical reserve accounting helpers are authoritative.
4. Implement Route 3 correctly in `SlipstreamStandardExchangeInTarget.sol`.
5. Implement Route 4 correctly in `SlipstreamStandardExchangeOutTarget.sol`.
6. Expand test base.
7. Add the missing integration suite and replace placeholder route coverage.
8. Run full verification.

## Definition of Done For Remediation

Do not treat this prompt as complete until **all** of the following are true:
- `forge build` passes.
- Slipstream `IFacet` tests pass.
- New Slipstream integration tests pass.
- No placeholder/simplified route math remains in the Slipstream targets for Routes 3 and 4.
- Route 3 uses `SlipstreamZapQuoter` + `ConstProdUtils._depositQuote(...)`.
- Route 4 uses entitlement-first `ConstProdUtils._withdrawQuote(...)` before any settlement swap.
- DFPkg contains the full 7-facet bundle including `MultiAssetStandardVaultFacet`.
- Public reserve views remain zero while internal canonical reserve accounting is used consistently in preview and execution.
- Full `forge test -vv` remains green.

## Acceptance Criteria

- [ ] Awareness repos compile and follow pattern
- [ ] Vault storage repo compiles
- [ ] Common logic compiles
- [ ] ExchangeIn facet/target compiles and implements IStandardExchangeIn
- [ ] ExchangeOut facet/target compiles and implements IStandardExchangeOut
- [ ] DFPkg deploys correctly
- [ ] IFacet tests pass
- [ ] Integration tests pass
- [ ] Full test suite remains green
- [ ] Route 3/Route 4 preview and execute paths are consistent with documented snapshot and rounding policy
- [ ] Route 4 cannot over-withdraw beyond apportioned entitlement budget outside configured slippage tolerance
- [ ] Route 3 swaps single-token deposits into proportional basket contributions before `_depositQuote(...)`
- [ ] Route 4 always computes proportional entitlement before any settlement swap into `tokenOut`
- [ ] Settlement swaps execute through the same Slipstream pool used by vault positions
- [ ] Public reserve views remain zero while internal share accounting uses canonical economic reserves
- [ ] Any undeployed remainder is treated as dust and excluded from canonical reserves until later deposited as liquidity

## Out of Scope

- Staking/gauge integration (v2)
- Cross-chain deployment
