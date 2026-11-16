# Product Requirements Document (PRD): Aave V3 Leveraged Vault Suite

## 1. Overview

### Product Name
AaveLeveragedVault (generic ERC-20 share-issuing vaults for Aave V3)

### Purpose
Develop a suite of leveraged vaults on **Aave V3** (primary; compatible with V4 where possible) to amplify yields through safe single-iteration looping. Focus on:
- **LP Amplification**: Leverage constant product pools (Uniswap V2-style) for fee revenue + Aave supply yield.
- **Carry Trade**: Pure lending loops for rate differential arbitrage.

Vaults use Aave's multi-asset borrow/supply for dynamic direction where beneficial (e.g., borrow volatile against stable collateral for positive carry).

All vaults implement custom zap interfaces (`IStandardExchangeIn` / `IStandardExchangeOut`) for flexible entry/exit (underlying assets, aTokens, LP tokens).

Subsequent PRDs will cover other protocols (Euler, Morpho, etc.).

### Key Goals
- Safe 2-4x leverage (configurable, conservative).
- High liquidity targets: Core Aave reserves (WETH, USDC, DAI, LSTs like wstETH).
- Embedded management: Permissionless `rebalance()` with conditionals.
- Atomic operations via Aave flash loans.
- Diamond proxy compatible.

### Implementation Source-of-Truth (Repo)
This PRD is validated against the Aave V3 code shipped in our submodules:
- Aave V3 Horizon interfaces live under `indexedex/lib/daosys/lib/crane/lib/aave-v3-horizon/src/contracts/interfaces/`
  - `IPool.sol` (core Pool interface)
  - `IPoolDataProvider.sol` (convenient getters: caps/config/token addrs)
  - `IPoolAddressesProvider.sol` (resolve oracle/data provider)
  - `IAaveOracle.sol` / `IPriceOracleGetter.sol` (prices + base currency unit)
  - `IFlashLoanSimpleReceiver.sol` / `IFlashLoanReceiver.sol` (flash loan receiver interfaces)

Related in-repo docs (may overlap / become canonical later):
- `indexedex/prds/Leveraged_Constant_Product_Vaults_AaveV3.md`

## 2. Target Vault Types

1. **LP Amplification Vault** (Primary):
   - Pair: Configurable constant product (e.g., WETH/USDC).
   - Flow: Supply base (e.g., USDC) → borrow paired (WETH) → withdraw base → balanced add LP.
   - Dynamic: Prefer direction with positive carry.

2. **Carry Trade Vault**:
   - Assets: Two reserves (e.g., USDC/WETH).
   - Recursive: Supply A → borrow B → supply B → borrow A (limited iterations).

## 3. Deployment Configuration
- `address aavePool` (V3 Pool address).
- (Recommended) `address aaveAddressesProvider` (V3 PoolAddressesProvider; lets us resolve oracle/data provider defensively).
- (Recommended) `address aavePoolDataProvider` (V3 PoolDataProvider; required for caps/config queries).
- `address ammRouter` / `ammPair` (for LP vaults).
- `address baseAsset`, `pairedAsset`.
- `uint8 eModeCategory` (0 if none).
- Thresholds: targetHF (1.5e18), low/high, maxDeviation (3e16), minCarry.

## 4. Core Formulas & Aave Function Calls
All stateful lending actions are via `IPool`. For configuration/caps/token-address queries, prefer `IPoolDataProvider`.
Use Aave oracle (`IAaveOracle` / `IPriceOracleGetter`) for pricing in the Pool’s base currency.

### 4.1 Key Data Queries
- **Reserve Rates/Indices/Token Addresses**: `pool.getReserveData(asset)` → returns `DataTypes.ReserveDataLegacy` including:
  - `liquidityIndex`, `variableBorrowIndex` (ray, 1e27)
  - `currentLiquidityRate`, `currentVariableBorrowRate` (ray, 1e27)
  - `aTokenAddress`, `variableDebtTokenAddress` and other operational fields
  - **Note:** collateral params (LTV/LT/LB/decimals/reserveFactor/caps) are *bit-packed* in `configuration` and are not returned as expanded fields.
- **Reserve Collateral Configuration** (expanded fields): `poolDataProvider.getReserveConfigurationData(asset)` → returns:
  - `decimals`, `ltv`, `liquidationThreshold`, `liquidationBonus`, `reserveFactor`
  - enable flags: `usageAsCollateralEnabled`, `borrowingEnabled`, `stableBorrowRateEnabled`, `isActive`, `isFrozen`
  - Units: `ltv` and `liquidationThreshold` are bps (0..10000).
- **Reserve Caps**: `poolDataProvider.getReserveCaps(asset)` → returns `(borrowCap, supplyCap)`.
  - Units: caps are in **whole tokens** (per `DataTypes.ReserveConfigurationMap`), so multiply by `10**decimals` to compare to raw ERC-20 amounts.
- **User Account Data**: `pool.getUserAccountData(vaultAddress)` → returns:
  - `totalCollateralBase`, `totalDebtBase`, `availableBorrowsBase`, `currentLiquidationThreshold`, `ltv`, `healthFactor`.
  - Units:
    - `ltv` and `currentLiquidationThreshold` are bps (0..10000)
    - `healthFactor` is returned as a wad-like fixed point (treat as 1e18)
    - `*_Base` values are denominated in the oracle base currency unit (`IAaveOracle.BASE_CURRENCY_UNIT()`; 1e8 for USD markets).
- **EMode**: Activate via `pool.setUserEMode(categoryId)` for higher LTV.
  - `pool.getUserEMode(vaultAddress)` returns the current category.

### 4.2 Health Factor & Leverage Calc
- Current HF = `healthFactor` from `getUserAccountData` (treat as 1e18).
- Projected HF after action:
  - Compute in **base currency** using the Aave oracle unit (`IAaveOracle.BASE_CURRENCY_UNIT()`).
  - New collateral value = currentCollateralBase + addedBase - withdrawnBase.
  - New debt value = currentDebtBase + borrowedBase - repaidBase.
  - Use liquidation threshold in bps (0..10000). A simplified projected HF is:
    - $HF \approx \dfrac{\text{newCollateralBase} \cdot \text{liqThresholdBps}}{\text{newDebtBase} \cdot 10^4}$
  - Practical note: `getUserAccountData` already provides *current* weighted `ltv` and `currentLiquidationThreshold` across enabled collaterals.
- Safe Borrow Amount:
  - Prefer using `availableBorrowsBase` from `getUserAccountData` as the starting point (already accounts for LTV).
  - Convert desired borrow amount (token units) → base currency using the oracle price; then ensure it fits:
    - `borrowValueBase <= availableBorrowsBase * safetyBps / 1e4`
  - Then cap by reserve caps:
    - Borrow cap: `poolDataProvider.getReserveCaps(borrowAsset).borrowCap * 10**decimals`
    - Supply cap (if your flow increases supply of an asset): `poolDataProvider.getReserveCaps(supplyAsset).supplyCap * 10**decimals`
  - Additionally gate all actions on `healthFactor >= targetHF` *after* projected changes.

### 4.3 Net Carry Projection
- For direction (borrow paired):
  - Buffer proportion ≈ remaining after withdraw (~1 / leverage).
  - Carry = (bufferProp * baseSupplyRate) - pairedBorrowRate.
- Rates from `pool.getReserveData` or `poolDataProvider.getReserveData` are **ray (1e27)**.
  - Treat `currentLiquidityRate` / `currentVariableBorrowRate` as APR-like rates in ray.
  - If converting to APY, compound over seconds (not blocks):
    - $APY \approx (1 + APR/\text{SECONDS\_PER\_YEAR})^{\text{SECONDS\_PER\_YEAR}} - 1$
  - Implementation should not rely on on-chain exponentiation for decisioning; instead use simple linear comparisons of ray rates (APR) with conservative buffers.

### 4.4 Total Assets
- Prefer token balance queries for “current” amounts:
  - aToken balance: `IERC20(aTokenAddress).balanceOf(vault)`
  - variable debt: `IERC20(variableDebtTokenAddress).balanceOf(vault)`
  - Use `poolDataProvider.getReserveTokensAddresses(asset)` to resolve `aTokenAddress` and `variableDebtTokenAddress`.
  - Only use index-scaled math if intentionally working with scaled balances.
- LP value: Reserves * oracle prices.
- Net = collateral + LP - debt (base currency).

## 5. Token Routes & Flows

### 5.1 exchangeIn (Deposit/Zap)
- Pull tokenIn.
- `pool.supply(asset, amount, onBehalfOf=vault, referralCode=0)`.
  - Ensure approvals to `aavePool` are set before calling supply/repay.
  - If required for a given reserve, call `pool.setUserUseReserveAsCollateral(asset, true)`.
- Auto-lever (flash loan if recursive):
  - `pool.borrow(borrowAsset, amount, interestRateMode=2, referralCode=0, onBehalfOf=vault)`.
  - If the strategy requires withdrawing supplied collateral, use `pool.withdraw(collateralAsset, amount, to=vault)` and re-check projected HF before/after.
  - addLiquidity balanced (for LP vault).
- Mint shares ∝ value added.

### 5.2 exchangeOut (Withdraw)
- Burn shares.
- Pro-rata remove LP (if applicable).
- `pool.repay(debtAsset, amount, interestRateMode=2, onBehalfOf=vault)`; use `type(uint256).max` to repay all variable debt.
- `pool.withdraw(collateralAsset, amount, to=recipient)`; use `type(uint256).max` to withdraw all aToken balance.

### 5.3 rebalance() (Flash Loan Batched)
1. Query: `getUserAccountData` + `getReserveData` both assets.
2. Evaluate carry/direction.
3. Branches:
   - Defensive (HF < low || deviation > max): Remove LP → `repay` max → `supply` excess.
   - Lever Up (HF > high + good carry): `borrow` additional → `withdraw` → add LP.
   - Switch/Harvest: Partial actions.

Use Aave `flashLoan` for atomic multi-step.

Notes:
- For single-asset flash loans, prefer `pool.flashLoanSimple(...)` with a receiver implementing `IFlashLoanSimpleReceiver.executeOperation(...)`.
- For multi-asset rebalances, use `pool.flashLoan(...)` with a receiver implementing `IFlashLoanReceiver.executeOperation(...)`.
- Receiver must return `true` and ensure the Pool can pull `amount + premium` (approve inside `executeOperation`).

## 6. Safety
- Flash loans for loops.
- eMode activation if configured.
- Slippage/deadline.
- Emergency pause.

Additional Aave safety gates (implementation requirements):
- Always verify `poolDataProvider.getPaused(asset) == false` and `getReserveConfigurationData(asset).isFrozen == false` for assets you touch.
- Always ensure the reserve has borrowing enabled for any borrow asset.
- Always keep `healthFactor >= 1e18` (hard safety) and `>= targetHF` (strategy safety).

## 7. Task Breakdown (Parallel Assignable)
### Shared (1 agent, 1 week)
1. Diamond base + common utils (oracle adapters, Aave flash loan receiver, risk math helpers).
  - Must follow IndexedEx deployment constraints (no `new`; deterministic deployments via the project factory / CREATE3).

### Aave-Specific (2-3 agents, 4-6 weeks parallel)
- Agent 1: LP Amplification Vault.
  2. Aave wrappers + reserve queries.
  3. Leverage/HF formulas.
  4. Zap paths + auto-lever.
- Agent 2: Carry Trade Vault.
  5. Recursive logic + direction eval.
  6. Rebalance branches.
- Agent 3: Testing.
  7. Unit + Aave fork tests.
  8. Deployment scripts.

Total: 5-7 weeks.

This Aave-focused PRD provides exact function calls/formulas for implementation. Ready for task conversion/assignment!

## 8. Implementation Handoff Checklist (for Agents)

### 8.1 Repo / Architecture Constraints (IndexedEx)
- Do not deploy contracts with `new`. All deployments must follow the repo’s deterministic factory / CREATE3 patterns.
- Prefer the existing Crane/IndexedEx Facet/Target/Repo patterns:
  - Repo for storage
  - Target for implementation
  - Facet for Diamond wiring + IFacet metadata
- Ensure any new vault package is deployed through the IndexedEx manager flow (package → vault instance) and registered in the vault registry.

### 8.2 Aave V3 Integration Checklist
- Use `IPool` for stateful actions: `supply`, `withdraw`, `borrow`, `repay`, `setUserEMode`, `flashLoanSimple` / `flashLoan`.
- Use `IPoolDataProvider` for read-only config/caps/token addresses:
  - `getReserveConfigurationData`
  - `getReserveCaps`
  - `getPaused`
  - `getReserveTokensAddresses`
- Use oracle via `IPoolAddressesProvider.getPriceOracle()` and `IAaveOracle/IPriceOracleGetter`:
  - Respect `BASE_CURRENCY_UNIT()` for “base currency” math.
- Treat Aave rates as ray (1e27) and avoid expensive on-chain APY math.
- Treat `getUserAccountData` outputs as:
  - `ltv` / `currentLiquidationThreshold`: bps (0..10000)
  - `healthFactor`: fixed-point ~1e18
- Caps are returned as “whole tokens” and must be scaled by decimals.
- Prefer `interestRateMode = 2` (variable). Stable mode is deprecated.
- Ensure collateral is enabled when required: `setUserUseReserveAsCollateral(asset, true)`.

### 8.3 Flash Loan Receiver Requirements
- For `flashLoanSimple`: receiver must implement `IFlashLoanSimpleReceiver.executeOperation(asset, amount, premium, initiator, params)`.
- For `flashLoan`: receiver must implement `IFlashLoanReceiver.executeOperation(assets, amounts, premiums, initiator, params)`.
- Receiver must ensure the Pool can pull repayment (`approve(pool, amount + premium)`) before returning.

### 8.4 Testing Requirements
- Add Foundry tests that:
  - validate IFacet metadata (if introducing new facets) using the canonical TestBase_IFacet pattern
  - validate vault accounting (shares, totalAssets, NAV) against Aave token balances + oracle prices
  - validate safety gates (paused/frozen assets, caps, HF thresholds)
- Prefer fork tests for realism, but keep at least one fast unit-style suite with minimal external dependencies.