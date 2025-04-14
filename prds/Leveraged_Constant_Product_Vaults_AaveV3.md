# Product Requirements Document (PRD): Leveraged Constant Product LP Vault on Aave V3

## 1. Overview

### Product Name
LeveragedLPVault (generic, deployable per pair)

### Purpose
Create a reusable, ERC-20 share-issuing vault that amplifies trading fee revenue from a constant product AMM pool (Uniswap V2-style) by using single-iteration leverage via Aave V3 lending/borrowing. The vault dynamically lends **both** underlying assets of the pool as collateral while borrowing **one** (the currently optimal) to enlarge the LP position. This achieves:
- Amplified DEX fees proportional to leveraged LP size.
- Supply yield on residual collateral buffers (both assets).
- Net positive or neutral carry when possible.
- Safe, atomic operations without recursive cross-looping risks.

The vault implements custom zap-style interfaces (`IStandardExchangeIn` / `IStandardExchangeOut`) for flexible entry/exit using any of: underlying asset0, underlying asset1, LP token, or either aToken.

### Key Goals
- Maximize safe exposure to DEX volume fees + Aave supply yield.
- Minimize keeper dependency via permissionless `rebalance()` and embedded conditional logic.
- Symmetric treatment of the two assets: dynamically select borrow direction based on real-time rates/carry.
- Generic: One codebase, configured per pair/chain at deployment.

### Scope
- Vanilla Aave V3 + constant product pool (no custom whitelisting needed).
- Single-iteration leverage per action (higher via repeated permissionless calls).
- No external incentives/rewards assumed.

## 2. Core Concepts & Terminology

- **asset0** and **asset1**: The two underlying tokens of the constant product pair (immutable, configured at deployment; order arbitrary, e.g., sorted by address).
- **lpToken**: The Uniswap V2-style pair contract token.
- **aToken0** / **aToken1**: Aave yield-bearing tokens for asset0/asset1.
- **debtToken0** / **debtToken1**: Aave variable debt tokens.
- **Borrow Direction**: At any time, the vault primarily borrows one asset (the "borrow-favored") while keeping residual collateral heavier in the other (the "supply-favored").
- **Net Carry**: (Weighted supply APY on collateral buffers) - (borrow APY on debt). Target ≥ 0 when leveraging up.
- **Health Factor (HF)**: Aave's user account HF. Target range: 1.4–1.6 typical.
- **Price Deviation**: |pool price - Aave oracle price| / oracle price. Max tolerated: 3%.

All values/prices use **Aave oracles only** for safety (avoid pool manipulation).

## 3. Interfaces Implemented

The vault **must** implement:
- `IStandardExchangeIn`: tokenIn → vault shares (deposits/zaps).
- `IStandardExchangeOut`: vault shares → tokenOut (withdraws/zaps).
- ERC-20 for shares (with name/symbol reflecting pair, e.g., "Lev-ETH-DAI").

Supported paths (others revert with Exchange*NotAvailable):
- In: asset0, asset1, lpToken, aToken0, aToken1 → shares
- Out: asset0, asset1, lpToken, aToken0, aToken1 → shares

Additional public functions:
- `rebalance()`: Permissionless, gas-bounty optional.
- View: `totalAssets()` (net value in asset0 terms), previews, currentDirection(), etc.

## 4. Deployment Configuration (Immutable Constructor Params)

- `address aavePool`
- `address ammRouter` (for add/removeLiquidity)
- `address ammPair` (lpToken + getReserves)
- `address asset0`, `address asset1`
- `uint8 eModeCategory` (0 if none)
- `uint256 targetHF` (e.g., 1.5e18)
- `uint256 lowHFThreshold` (e.g., 1.3e18)
- `uint256 highHFThreshold` (e.g., 1.7e18)
- `uint256 maxPriceDeviation` (e.g., 3e16 = 3%)
- `uint256 minNetCarry` (e.g., 0 or small positive, in APY basis points scaled)

## 5. Core Calculations

### 5.1 Value Accounting
- LP value = (vault lpBalance * (reserve0 + reserve1 * oraclePrice1To0)) / totalSupply
- Total collateral value = aToken0 balance * oraclePrice0 + aToken1 balance * oraclePrice1To0 (normalized to asset0)
- Total debt value = debtToken0 balance * oraclePrice0 + debtToken1 balance * oraclePrice1To0
- `totalAssets()` = LP value + collateral value - debt value

Shares minted/burned ∝ net value added/removed.

### 5.2 Optimal Borrow Direction Evaluation
Run on every major action/rebalance:

```pseudocode
function evaluateBestDirection() returns (Direction: BORROW_0 or BORROW_1 or NONE)
    rates0 = getReserveData(asset0)  // supplyAPY, borrowAPY, LTV, liqThreshold
    rates1 = getReserveData(asset1)

    // Projected net carry if borrow asset0 (supply-favored = asset1)
    carryIfBorrow0 = (projectedBuffer1Proportion * rates1.supplyAPY) - rates0.borrowAPY

    // Projected if borrow asset1 (supply-favored = asset0)
    carryIfBorrow1 = (projectedBuffer0Proportion * rates0.supplyAPY) - rates1.borrowAPY

    // Projected buffer proportions assume balanced add after borrow/withdraw
    // Approx: after leverage, ~ (1 / leverage) in supply-favored, 0 in borrow-favored

    if max(carryIfBorrow0, carryIfBorrow1) < minNetCarry:
        return NONE  // Do not lever
    else:
        return the direction with higher projected carry
```

Also factor current debt (prefer continuing current direction to avoid transition costs).

### 5.3 Safe Leverage Amount
For a targetHF:

```pseudocode
currentCollateralValue, currentDebtValue, currentHF = getUserAccountData()

// Effective LTV for direction (use eMode if active)
effectiveLTV = borrowFavored ? ratesBorrow.LTV : weighted avg

maxAdditionalBorrowValue = (currentCollateralValue * effectiveLTV) - currentDebtValue

safeAdditionalBorrowValue = maxAdditionalBorrowValue * (targetHF / currentHF adjustment)

cap by supply/borrow caps, price deviation check
```

## 6. Token Routes & Flows

### 6.1 exchangeIn Paths (tokenIn → shares)

All paths:
- Pull if !pretransferred
- Add value
- Evaluate best direction
- If conditions good (HF room, carry ≥ min, deviation ≤ max): auto-lever in optimal direction
- Mint shares ∝ value added
- Return shares minted

Specific routes:

1. **tokenIn = asset0 or asset1**
   - Supply full amount to Aave → aTokenX
   - Auto-lever:
     - Borrow safe amount of borrow-favored
     - Withdraw equal-value (oracle) of supply-favored
     - addLiquidity balanced → LP

2. **tokenIn = lpToken**
   - Hold LP directly
   - Auto-lever if room (same as above, using existing collateral)

3. **tokenIn = aToken0 or aToken1**
   - Transfer aToken to vault
   - Auto-lever if room

### 6.2 exchangeOut Paths (shares → tokenOut)

All paths:
- Burn shares ∝ exact tokenOut requested
- Deliver exact amountOut (preview calculates required shares)

Specific routes:

1. **tokenOut = asset0 or asset1**
   - Remove proportional LP → get both assets
   - Repay all debt in the over-repaid side
   - Supply excess to Aave temporarily
   - Withdraw requested asset from Aave
   - Deliver (may include small other side if imbalanced)

2. **tokenOut = lpToken**
   - Transfer proportional LP directly (no delever)

3. **tokenOut = aToken0 or aToken1**
   - Delever sufficiently: remove LP → repay debt → withdraw underlying → re-supply to get requested aToken
   - Deliver aToken

### 6.3 rebalance() (Permissionless)

1. Evaluate state:
   - Current HF
   - Price deviation
   - Best direction + projected carry
   - Current vs best direction

2. Conditional branches (in priority order):

   a. **Defensive (HF < lowHFThreshold OR deviation > maxPriceDeviation OR rates unstable)**
      - Remove partial/full LP balanced
      - Repay max possible debt (both if present)
      - Supply excess assets to Aave (both sides → lend both)

   b. **Direction Switch Needed (projected carry flip > threshold)**
      - Remove partial LP
      - Repay old debt fully
      - Borrow new favored
      - Withdraw supply-favored
      - Re-add balanced to LP

   c. **Lever Up (HF > highHFThreshold AND best carry ≥ minNetCarry AND deviation OK)**
      - Borrow additional favored
      - Withdraw equal supply-favored
      - addLiquidity balanced

   d. **Harvest/Neutral**
      - Small LP remove/re-add to realize fees
      - Use realized tokens to reduce debt or add balanced (prefer reducing debt if carry negative)

3. Activate eMode if configured.

## 7. Safety & Risks

- All actions atomic, bounded by Aave caps/oracles.
- Reentrancy guards.
- Slippage/deadline checks.
- Pause/emergency withdraw by governance.
- Risks: IL, liquidation on volatility, rate spikes, oracle failure.

## 8. Task Breakdown for Implementation

### Phase 1: Setup & Basics (2-3 days)
1. Scaffold vault contract with constructor storing params.
2. Implement ERC-20 shares.
3. Add Aave/AMM interactions (supply, borrow, repay, withdraw, add/removeLiquidity).
4. Implement totalAssets() using oracle pricing.

### Phase 2: Core Calculations (3-4 days)
5. Implement oracle-safe value functions.
6. Implement evaluateBestDirection() with carry projection.
7. Implement safe leverage calculator.

### Phase 3: ExchangeIn Paths (4-5 days)
8. Implement previewExchangeIn + exchangeIn for each supported tokenIn.
9. Add auto-lever logic post-deposit.

### Phase 4: ExchangeOut Paths (4-5 days)
10. Implement previewExchangeOut + exchangeOut for each tokenOut.
11. Handle exact delivery + excess refunds.

### Phase 5: Rebalance & Conditionals (4-6 days)
12. Implement full rebalance() with all branches.
13. Add eMode activation.
14. Optional gas bounty for rebalancer.

### Phase 6: Testing & Polish (5-7 days)
15. Unit tests for all paths/branches.
16. Fork tests on mainnet data (rates, oracles).
17. Security review checklist (reentrancy, oracle reliance).
18. Documentation/events.

Total estimated: 4-6 weeks for a senior Solidity dev.

This PRD is self-contained—review for clarity/completeness, then proceed to implementation tasks.