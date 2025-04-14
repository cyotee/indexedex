# Product Requirements Document (PRD): Leveraged Constant Product LP Vault on Aave V4

## 1. Overview

### Product Name
LeveragedLPVaultV4 (generic, deployable per pair)

### Purpose
Build a reusable ERC-20 share-issuing vault that amplifies trading fee revenue from a constant product AMM pool (Uniswap V2-style) using single-iteration leverage on **Aave V4**. The vault dynamically supplies both underlying pool assets as collateral while borrowing the current optimal one to enlarge the LP position. This delivers:
- Amplified DEX fees from leveraged LP size.
- Supply yield on residual collateral (both assets, via V4's improved tokenization).
- Optimized net carry via V4's Risk Premiums and unified liquidity.
- Safe, atomic operations with modular Spoke interactions.

The vault implements custom zap interfaces (`IStandardExchangeIn` / `IStandardExchangeOut`) for entry/exit via underlying asset0/asset1, LP token, or V4 supply shares (ERC-4626-style).

### Key Goals
- Maximize safe DEX fee exposure + Aave supply yield in V4's unified liquidity environment.
- Reduce keeper needs with permissionless `rebalance()` and embedded conditionals.
- Symmetric asset handling: Dynamically select borrow direction based on real-time Risk Premiums, rates, and carry.
- Generic codebase, configured per pair/chain/Spoke.

### Scope
- Aave V4 Hub-and-Spoke architecture (primary interactions via a configured Core/Pooled Spoke).
- Single-iteration leverage (higher via repeated calls).
- No custom Spoke deployment needed.

**Note on V4 Status (January 2026)**: Aave V4 is in early launch phase post-roadmap (Dec 2025), with public testnet/code available. Features like Hub-and-Spoke, unified liquidity, and Risk Premiums are live or imminent. Reference latest docs (aave.com/docs/aave-v4) and GitHub (aave/aave-v4) for ABIs.

## 2. Core Concepts & Terminology

- **asset0** and **asset1**: Underlying tokens of the constant product pair (immutable, deployment-configured).
- **lpToken**: AMM pair token.
- **supplyShare0** / **supplyShare1**: V4 ERC-4626-style shares for supplied assets (replaces aTokens).
- **debtToken0** / **debtToken1**: Variable debt tokens.
- **Liquidity Hub**: Central consolidated liquidity/accounting.
- **Spoke**: User-facing modular market (vault uses one primary Spoke for position management).
- **Risk Premiums**: V4 borrowing rates based on collateral quality (enhances carry predictability).
- **Borrow Direction**: Primarily borrow one asset while residual collateral heavier in the other.
- **Net Carry**: Weighted supply yield minus borrow cost (factoring Risk Premiums).
- **Health Factor (HF)**: Per-Spoke user HF.
- **Price Deviation**: |pool price - Aave oracle price| / oracle price (max 3%).

Use **Aave V4 oracles only** for values/safety.

## 3. Interfaces Implemented

Same as V3 version:
- `IStandardExchangeIn` / `IStandardExchangeOut`.
- ERC-20 shares.
- Supported paths: asset0, asset1, lpToken, supplyShare0, supplyShare1 → shares (in); reverse for out.

Additional: `rebalance()`, views for direction/Spoke state.

## 4. Deployment Configuration (Immutable Constructor Params)

- `address liquidityHub` (if direct interaction needed)
- `address primarySpoke` (Core/Pooled Spoke for main position)
- `address ammRouter`
- `address ammPair`
- `address asset0`, `address asset1`
- `uint256 targetHF` (e.g., 1.5e18; potentially higher due to unified liquidity)
- `uint256 lowHFThreshold` (1.3e18)
- `uint256 highHFThreshold` (1.7e18)
- `uint256 maxPriceDeviation` (3e16)
- `uint256 minNetCarry` (in basis points)

Optional: Secondary Spoke addresses for advanced migration.

## 5. Core Calculations

### 5.1 Value Accounting
- LP value: Same (oracle-priced).
- Collateral value: supplyShare balances scaled via Spoke exchange rates, normalized to asset0.
- Debt value: debtToken balances (oracle-priced).
- `totalAssets()`: LP + collateral - debt.

### 5.2 Optimal Borrow Direction
Enhanced with Risk Premiums:

```pseudocode
function evaluateBestDirection() returns (BORROW_0 or BORROW_1 or NONE)
    // Query Spoke for rates, Risk Premiums, projected borrow APY per direction
    projectedBorrowAPY0 = baseUtilizationRate + riskPremiumIfCollateral1
    projectedBorrowAPY1 = baseUtilizationRate + riskPremiumIfCollateral0

    carryIfBorrow0 = (buffer1Proportion * supplyAPY1) - projectedBorrowAPY0
    carryIfBorrow1 = (buffer0Proportion * supplyAPY0) - projectedBorrowAPY1

    Select highest carry ≥ minNetCarry
```

Factor current debt/Spoke caps.

### 5.3 Safe Leverage Amount
- Use Spoke-specific LTV/risk params.
- Adjust for unified liquidity (higher effective caps possible).

## 6. Token Routes & Flows

### 6.1 exchangeIn Paths
All via primary Spoke:
1. **asset0/asset1**: Supply to Spoke → receive supplyShares → auto-lever (borrow favored via Spoke → withdraw supply-favored → add balanced LP).
2. **lpToken**: Hold → auto-lever.
3. **supplyShare0/supplyShare1**: Transfer to vault (updates Spoke position) → auto-lever.

Previews simulate Spoke rates/Risk Premiums.

### 6.2 exchangeOut Paths
Via Spoke:
1. **asset0/asset1**: Remove LP → repay debt → redeem supplyShares → deliver underlying.
2. **lpToken**: Pro-rata transfer.
3. **supplyShare0/supplyShare1**: Delever → redeem to requested shares.

### 6.3 rebalance()
1. Query Spoke state (HF, rates via Risk Premiums, deviation).
2. Branches (priority):
   a. **Defensive**: HF low / deviation high → remove LP → repay debt → supply excess via Spoke.
   b. **Direction Switch**: Carry flip → partial remove → repay old → borrow new → re-add balanced.
   c. **Lever Up**: HF high + good carry → borrow additional → withdraw → add LP.
   d. **Harvest**: Cycle small LP → reduce debt or balance.

Opportunity: If multiple Spokes configured, migrate for better Risk Premiums.

## 7. Safety & Risks

- Atomic Spoke actions + oracle bounds.
- Reentrancy guards, deadline/slippage.
- Emergency pause/governance withdraw.
- Risks: Same as V3 (IL, liquidation, rate spikes) + Spoke-specific isolation events.
- Benefits: Unified liquidity → reduced fragmentation, better rates; Risk Premiums → more stable carry.

## 8. Task Breakdown

### Phase 1: Research & Setup (3-5 days)
1. Review latest V4 docs/GitHub for Spoke ABIs, supplyShare (ERC-4626) interfaces.
2. Scaffold vault with Spoke/Hub integrations.

### Phase 2: Core Calculations (4-5 days)
3. Implement Spoke queries (rates, Risk Premiums, scaled balances).
4. Update direction evaluator with Risk Premiums.
5. Leverage calculator for Spoke params.

### Phase 3: ExchangeIn Paths (5-6 days)
6. Implement deposits via Spoke supply/mint.
7. Auto-lever post-deposit.

### Phase 4: ExchangeOut Paths (5-6 days)
8. Implement redeems/withdraws via Spoke.

### Phase 5: Rebalance & Advanced (5-7 days)
9. Full conditional rebalance with Spoke routing.
10. Optional multi-Spoke migration logic.

### Phase 6: Testing & Polish (7-10 days)
11. Unit/fork tests on V4 testnet/mainnet forks.
12. Security audit prep (focus on Spoke interactions).

Total: 5-8 weeks (senior dev), longer if V4 still evolving.

This PRD adapts the proven V3 design to V4's Hub-and-Spoke strengths for better efficiency and modularity. Review against latest Aave V4 specs before implementation.