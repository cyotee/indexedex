### Analysis of Compound (Comet / Compound III) for Leveraged LP Vault

Compound III, codenamed **Comet**, is the current and latest version of the Compound protocol as of January 2026. No Compound V4 has launched yet (only early governance discussions and a January 2026 roadmap proposal exist). Comet has been live since 2022-2023, with deployments across Ethereum, Polygon, Arbitrum, Base, Optimism, Scroll, Mantle, and others. It manages significant TVL (~$650M+ in some reports) and focuses on efficiency/security.

#### Key Mechanics Relevant to Our Vault
- **Base Asset Model**: Each Comet market has **one primary borrowable "base asset"** (e.g., USDC on Ethereum, USDbC on Base, WETH on some chains). Users borrow **only** the base asset.
- **Supply/Collateral**: Multiple assets can be supplied as collateral (e.g., WETH, wstETH, cbBTC, UNI, WBTC) or the base itself (to earn yield without borrowing).
- **Borrowing**: Strictly the base asset against collateral. No borrowing of collateral assets.
- **Tokenization**: Suppliers receive yield-bearing cTokens (or equivalents via proxies).
- **Rates**: Dynamic utilization-based, plus protocol rewards (COMP).
- **Risk/Liquidation**: "Absorb" mechanism + health factor (borrow capacity vs collateral value, with liquidation factors per asset).
- **Leverage**: Possible via supply collateral → borrow base → recycle (e.g., into more collateral or strategies).

#### Concerns Comparison to Aave
- **Similar Concerns**:
  - Liquidation risk (health factor drops on price/volatility moves).
  - Impermanent loss in LP.
  - Rate fluctuations (utilization-driven borrow/supply APY).
  - Oracle reliance (Compound uses its own price feeds).
  - Carry trade potential (supply yield on collateral/base vs borrow cost).
- **Solutions Translate Well**: Conservative health thresholds, permissionless rebalance (delever on low health, lever up on room), oracle-safe pricing, atomic single-iteration loops.
- **Key Differences/Limitations**:
  - **No Symmetric Borrowing**: Cannot dynamically switch borrow direction or borrow both assets. Borrowing fixed to base → no rate-flip switching for optimal carry.
  - **Asymmetric**: Leverage flows one way (borrow base against paired collateral).
  - **Market Fragmentation**: Each deployment has specific base + collateral list → vault instances limited to compatible pairs (e.g., USDC-base with WETH collateral for USDC/WETH pool).
  - **Less Cross-Asset Flexibility**: Reduced carry opportunities vs Aave's multi-borrow.

#### Applicability of Our Design
Yes, we can apply the **core concept** (single-iteration leverage to amplify constant product LP + supply yield), but **not the full symmetric dynamic version**. The vault must be **asymmetric with fixed direction**:
- Configure per compatible market: "collateralAsset" (supplied heavily) + "baseAsset" (borrowed).
- Flow: Supply collateralAsset → borrow baseAsset → withdraw/supply baseAsset → add balanced to LP.
- Residual: Heavy in collateralAsset yield + baseAsset buffer.
- Rebalance: Lever/delever only in the fixed direction; harvest fees to reduce debt.

This works well for high-volume stable-volatile pairs (e.g., USDC/WETH, USDC/cbBTC) on USDC-base markets. Yields from COMP rewards can boost. Not ideal for volatile-volatile or stable-stable without a matching base.

The design is simpler than Aave (no direction evaluation/switching), but safe and effective.

# Product Requirements Document (PRD): Leveraged Constant Product LP Vault on Compound Comet (III)

## 1. Overview

### Product Name
LeveragedLPVaultComet (deployable per market/pair)

### Purpose
Create a reusable ERC-20 share-issuing vault amplifying constant product AMM pool fees via single-iteration leverage on **Compound Comet**. Supply a collateral asset, borrow the market's base asset, recycle into larger balanced LP position. Earn amplified DEX fees + supply yield on residual collateral/base - borrow costs + potential COMP rewards.

Implements custom zap interfaces (`IStandardExchangeIn` / `IStandardExchangeOut`) for entry/exit via collateralAsset, baseAsset, LP token, or cToken equivalents.

### Key Goals
- Safe LP fee amplification + Compound yield in Comet markets.
- Minimal keeper via permissionless `rebalance()`.
- Fixed-direction leverage tuned to Comet's base model.
- Generic per compatible market (one codebase).

### Scope
- Vanilla Comet proxies (no extensions needed).
- Single-iteration leverage.
- Target pairs: e.g., WETH/USDC on USDC-base Ethereum market.

## 2. Core Concepts & Terminology

- **baseAsset**: Market's borrowable asset (e.g., USDC; immutable per deployment).
- **collateralAsset**: Primary supplied collateral (e.g., WETH).
- **lpToken**: AMM pair token.
- **cBase** / **cCollateral**: Yield-bearing tokens/proxies for supplies.
- **Borrow Direction**: Fixed (borrow baseAsset against collateralAsset).
- **Net Carry**: Supply APY on residuals - base borrow APY (+ COMP if claimed).
- **Health/Absorb**: Comet's borrow capacity vs collateral (liquidation if under).
- **Price Deviation**: Max 3% vs Compound oracles.

Use **Compound price feeds only** for safety.

## 3. Interfaces Implemented

- `IStandardExchangeIn` / `IStandardExchangeOut`.
- ERC-20 shares.
- Supported: collateralAsset, baseAsset, lpToken, cCollateral, cBase → shares (in/out).

Additional: `rebalance()`, views for health/state.

## 4. Deployment Configuration

- `address cometProxy` (market instance, e.g., cUSDCv3)
- `address ammRouter`
- `address ammPair`
- `address baseAsset`, `address collateralAsset`
- `uint256 targetHealth` (e.g., 1.4–1.6; Comet uses factor scaling)
- `uint256 lowHealthThreshold`
- `uint256 highHealthThreshold`
- `uint256 maxPriceDeviation`

## 5. Core Calculations

### 5.1 Value Accounting
- LP value (oracle-priced).
- Collateral value: Scaled balances via Comet.
- Borrow value: Base debt.
- `totalAssets()`: LP + supplies - borrow.

### 5.2 Safe Leverage Amount
- Query Comet `getBorrowCapacity` / health.
- Max borrow = capacity - current.
- Safe = adjusted for targetHealth + caps.

No direction eval (fixed).

## 6. Token Routes & Flows

### 6.1 exchangeIn Paths
Via Comet proxy:
1. **collateralAsset**: Supply as collateral → auto-lever (borrow base → supply/withdraw base → add LP).
2. **baseAsset**: Supply base → reduce debt or auto-lever.
3. **lpToken**: Hold → auto-lever.
4. **cCollateral/cBase**: Transfer → auto-lever.

### 6.2 exchangeOut Paths
1. **baseAsset/collateralAsset**: Remove LP → repay borrow → withdraw supplies → deliver.
2. **lpToken**: Pro-rata transfer.

### 6.3 rebalance()
1. Query health, deviation, rates.
2. Branches:
   - Defensive: Low health/deviation → remove LP → repay → supply excess.
   - Lever Up: High health + room → borrow more base → supply/withdraw → add LP.
   - Harvest: Cycle LP → reduce debt or balance (+ claim COMP if integrated).

## 7. Safety & Risks

- Atomic Comet actions + oracle checks.
- Similar to Aave (IL, liquidation, rates) but fixed direction reduces carry flips.
- Benefits: COMP rewards, efficient markets.

## 8. Task Breakdown

Phase 1: Setup (2-3 days) — Comet integrations.  
Phase 2: Calculations (3 days) — Health/leverage.  
Phase 3-4: Exchange paths (7-10 days).  
Phase 5: Rebalance (3-4 days).  
Phase 6: Testing (5-7 days) — Fork Comet markets.

Total: 3-5 weeks.

This adapts our design effectively to Comet's constraints for solid yields in supported markets. For symmetric needs, Aave remains superior.