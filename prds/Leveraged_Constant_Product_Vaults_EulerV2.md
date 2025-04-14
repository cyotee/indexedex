### Analysis of Euler Finance (v2) for Leveraged LP Vault

Euler Finance's current and latest version as of January 2026 is **Euler v2**, launched in September 2024 and actively evolving (e.g., integrations like EulerSwap, deployments on Base/Ethereum, TVL surges to ~$671M reported in early 2025 posts, ongoing product expansions). No v3 has launched yet; v2 is the mature modular platform post the 2023 v1 hack recovery.

#### Key Mechanics Relevant to Our Vault
- **Modular Vault Architecture**: Permissionless creation of custom lending vaults (ERC-4626 compliant often).
- **Ethereum Vault Connector (EVC)**: Core innovation—allows batched, composable operations across vaults (e.g., supply to one, borrow from another, use as collateral in a third—all atomically).
- **Lending/Borrowing**: Supply assets to vaults → earn yield; borrow against collateral (flexible LTV per vault config). Supports wide assets, isolated risk per vault.
- **Leverage**: Native recursive/composable leveraging via EVC batches (e.g., borrow → supply borrowed → borrow more).
- **Risk Management**: Isolated vaults, vault-to-vault LTV, soft liquidations (gradual, no fixed penalties).
- **Rates**: Dynamic, vault-specific (utilization + governor-set params).
- **Other**: High capital efficiency, permissionless market creation.

#### Concerns Comparison to Aave/Compound
- **Similar Concerns**:
  - Liquidation risk (mitigated by soft mechanism).
  - Impermanent loss in LP.
  - Rate/carry fluctuations.
  - Oracle reliance.
- **Enhanced Mitigations**: Soft liquidations reduce penalty pain; isolation limits contagion; EVC enables safer atomic loops.
- **Key Differences/Advantages**:
  - **Full Symmetry & Dynamics**: No fixed base—borrow any supported asset against any collateral (via vault configs/EVC). Dynamic direction switching seamless.
  - **Higher Leverage Potential**: True recursive looping possible atomically (beyond our single-iteration).
  - **Modularity**: Our vault can interact with existing vaults or be deployed as a custom Euler vault.
- **Minor New Concerns**: EVC batch complexity (reentrancy/oracle timing risks); vault governor changes.

#### Applicability of Our Design
Yes, the **full symmetric dynamic version** applies **even better** than on Aave—Euler v2's EVC and modularity make it ideal for our strategy. We can:
- Dynamically lend both assets (supply to vaults).
- Borrow the optimal one (or transition).
- Use EVC for atomic leverage loops (single or multi-iteration).
- Embed rebalance with advanced conditionals.

This enables higher safe leverage, better carry optimization, and composability.

# Product Requirements Document (PRD): Leveraged Constant Product LP Vault on Euler v2

## 1. Overview

### Product Name
LeveragedLPVaultEuler (generic, deployable per pair/vault set)

### Purpose
Reusable ERC-20 share-issuing vault amplifying constant product AMM fees via leverage on **Euler v2**. Dynamically supply both underlying assets to Euler vaults, borrow the optimal one via EVC, recycle into balanced LP. Earn amplified fees + supply yield - borrow costs.

Implements custom zap interfaces (`IStandardExchangeIn` / `IStandardExchangeOut`) for entry/exit via asset0/asset1, LP token, or Euler vault shares (e.g., eTokens).

### Key Goals
- Maximize DEX fee exposure + Euler yield with v2 modularity.
- Permissionless `rebalance()` with EVC batches.
- Full symmetric dynamic borrow direction.
- Generic across pairs/Euler vaults.

### Scope
- Interact with existing Euler vaults + EVC (no custom vault creation needed; optional for optimization).
- Single/multi-iteration leverage via EVC.
- Target high-efficiency pairs (e.g., ETH/USDC).

## 2. Core Concepts & Terminology

- **asset0** and **asset1**: Pair underlyings.
- **lpToken**: AMM pair.
- **eToken0** / **eToken1**: Euler vault shares for supplies.
- **dToken0** / **dToken1**: Debt representations.
- **EVC**: Ethereum Vault Connector for atomic batches.
- **Borrow Direction**: Dynamic (optimal via rates/LTV).
- **Net Carry**: Supply yield - borrow cost (vault-specific).
- **Health/LTV**: Per-vault + cross-vault.
- **Price Deviation**: Max 3% vs Euler oracles.

Use **Euler oracles only**.

## 3. Interfaces Implemented

- `IStandardExchangeIn` / `IStandardExchangeOut`.
- ERC-20 shares.
- Supported: asset0, asset1, lpToken, eToken0, eToken1 → shares.

Additional: `rebalance()`, views for direction/EVC state.

## 4. Deployment Configuration

- `address evc`
- `address vault0` (Euler vault for asset0)
- `address vault1` (Euler vault for asset1)
- `address ammRouter`
- `address ammPair`
- `address asset0`, `address asset1`
- `uint256 targetHealth` (higher possible via soft liqs)
- `uint256 lowHealthThreshold`
- `uint256 highHealthThreshold`
- `uint256 maxPriceDeviation`
- `uint256 minNetCarry`
- `bool allowRecursive` (multi-iteration option)

## 5. Core Calculations

### 5.1 Value Accounting
- LP value (oracle).
- Supplies: Scaled eToken balances.
- Debt: dToken or query.
- `totalAssets()`: LP + supplies - debt.

### 5.2 Optimal Borrow Direction
Query vault rates/LTV:

```pseudocode
carryBorrow0 = (buffer1 * vault1.supplyAPY) - vault0.borrowAPY
carryBorrow1 = (buffer0 * vault0.supplyAPY) - vault1.borrowAPY
Select highest ≥ minNetCarry
```

### 5.3 Safe Leverage
- Use cross-vault LTV/health via EVC.
- Optional recursive calc for multi-iteration.

## 6. Token Routes & Flows

Use EVC batches for atomicity.

### 6.1 exchangeIn Paths
1. **asset0/asset1**: Deposit to respective vault → eToken → auto-lever (EVC batch: borrow favored → deposit borrowed → withdraw supply-favored → add LP).
2. **lpToken**: Hold → auto-lever.
3. **eToken0/eToken1**: Transfer → auto-lever.

### 6.2 exchangeOut Paths
EVC batches for delever:
1. **asset0/asset1**: Remove LP → repay debt → redeem eTokens → deliver.
2. **lpToken**: Pro-rata.

### 6.3 rebalance()
EVC-batched:
1. Query health, rates, deviation.
2. Branches:
   - Defensive: Low health → remove LP → repay → deposit excess.
   - Switch: Carry flip → partial remove → repay old → borrow new → re-add.
   - Lever Up: High health + good carry → recursive borrow/deposit/withdraw/add LP.
   - Harvest: Cycle LP → reduce debt.

## 7. Safety & Risks

- EVC atomicity + oracle checks.
- Soft liqs reduce penalties.
- Risks: Similar + EVC batch failures (use non-reentrant).
- Benefits: Higher efficiency, recursive leverage.

## 8. Task Breakdown

Phase 1: Setup (3-4 days) — EVC/vault integrations.  
Phase 2: Calculations (4 days) — Direction/LTV.  
Phase 3-4: Exchange paths with EVC (8-10 days).  
Phase 5: Rebalance/recursive (4-5 days).  
Phase 6: Testing (7-10 days) — Fork Euler deployments.

Total: 4-6 weeks.

Euler v2's modularity makes this the strongest fit yet—potentially highest yields/safety.