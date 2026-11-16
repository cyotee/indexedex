### Feasibility Analysis for Cross-Protocol Leveraged Carry Vault

Yes, modifying our previous leveraged LP vault design to a **pure cross-protocol carry vault** (no constant product AMM/LP involvement) is **highly feasible technically**, but with **increased complexity, risks, and design adjustments**. The core elements—rate differential detection, dynamic borrow direction evaluation, conditional branching (lever up/delever/switch), zap interfaces, and permissionless rebalance—translate directly and even fit better here, as the strategy is a classic DeFi carry trade amplified by recursive/cross looping.

#### Why It's Feasible
- **Protocol Support**: Many lending protocols (Aave V3/V4, Compound Comet, Euler v2, Morpho Blue) allow supplying one asset as collateral to borrow another. Cross-protocol recursion is possible on the same chain (e.g., borrow from Aave → supply to Compound → borrow back from Compound → supply to Aave).
- **Existing Patterns**: Similar to single-protocol looping vaults (e.g., Yearn stETH looper on Aave, Morpho optimizers) but extended cross-protocol for rate arbitrage. Tools like flash loans or atomic composability (Euler EVC, Morpho oracles) make loops safer.
- **Rate Diff Opportunities**: Persistent diffs exist due to utilization imbalances, rewards (e.g., COMP vs Aave incentives), or risk pricing—vault can detect and exploit.
- **No IL Risk**: Pure positive carry focus (supply yield > borrow cost across loop) → cleaner yields than LP strategies.

#### Key Concerns & Modifications Needed
- **Similar Concerns (from previous designs)**:
  - Liquidation risk (multiplied across protocols—cascade if one HF drops).
  - Rate/carry fluctuations (faster arbitrage cross-protocol).
  - Oracle discrepancies (must align or use conservative min).
- **Solutions Apply**: Conservative HF targets, deviation checks, defensive delever branching.
- **New/Heightened Concerns**:
  - **Cross-Protocol Risks**: Different liquidation mechanics, governance changes, oracle feeds → potential mismatch liquidations.
  - **Atomicity/Gas**: Recursive loops non-atomic without flash loans/EVC → risk of partial execution.
  - **Capital Efficiency**: Lower than single-protocol (transfer costs, slippage).
  - **Arbitrage Competition**: Diffs close quickly → vault needs fast rebalance triggers.
  - **Protocol Compatibility**: Limited to overlapping assets (e.g., USDC/WETH on Aave + Compound).
- **Required Design Changes**:
  - No LP holdings/math → replace with cross-protocol position tracking.
  - Fixed two protocols + two assets at deployment.
  - Use flash loans (e.g., Aave/ Balancer) for atomic entry/rebalance loops.
  - Enhanced direction eval (cross-protocol projected carry).
  - Higher conservatism (lower target leverage, multi-HF monitoring).

Overall Feasibility: **8/10** — Great for opportunistic carry on mismatched rates, but riskier than single-protocol or LP versions. Best on protocols with composability (Euler + Aave) or unifiers (Morpho Blue markets). Single-protocol variant easier first step.

# Product Requirements Document (PRD): Cross-Protocol Leveraged Carry Vault

## 1. Overview

### Product Name
CrossProtocolCarryVault (deployable per protocol pair + asset pair)

### Purpose
Reusable ERC-20 share-issuing vault for leveraged carry trades across two lending protocols. Supply one asset on Protocol1 → borrow the counterpart → supply on Protocol2 → borrow back → re-supply on Protocol1 (recursive cross-loop). Dynamically detect rate differentials to optimize net carry (supply yield - borrow cost across loop).

No AMM/LP exposure—pure lending yield amplification.

Implements custom zap interfaces (`IStandardExchangeIn` / `IStandardExchangeOut`) for entry/exit via asset0/asset1 or protocol-specific tokens (aTokens/cTokens/eTokens).

### Key Goals
- Exploit cross-protocol rate diffs for positive carry.
- Safe recursive leveraging with atomic flash loan/EVC support.
- Dynamic direction + conditional branching.
- Generic for compatible protocol/asset pairs.

### Scope
- Two configurable protocols (e.g., Aave V3 + Compound Comet).
- Two assets (e.g., USDC + WETH).
- Single/multi-iteration cross-loops via flash loans for atomicity.
- Monitor dual health factors.

## 2. Core Concepts & Terminology

- **asset0** and **asset1**: The two tokens (e.g., USDC stable, WETH volatile).
- **protocol1** and **protocol2**: Configured lending instances (e.g., Aave Pool + Comet proxy).
- **supplyTokenP1_0** etc.: Protocol-specific yield tokens.
- **Borrow Direction**: Dynamic (favor borrowing the lower-cost side).
- **Net Carry**: Projected (supply APY on heavy side P1 + P2) - (borrow APY on debt sides).
- **Dual Health Factor**: Min HF across both protocols.
- **Rate Deviation**: Supply/borrow diffs + oracle alignment check.

Use conservative oracles (min across protocols).

## 3. Interfaces Implemented

- `IStandardExchangeIn` / `IStandardExchangeOut`.
- ERC-20 shares.
- Supported: asset0, asset1, supply tokens from either protocol → shares.

Additional: `rebalance()`, views for direction/dual HF/carry.

## 4. Deployment Configuration

- `address protocol1` (e.g., Aave Pool)
- `address protocol2` (e.g., Comet proxy)
- `address flashLoanProvider` (e.g., Aave/Balancer for atomic loops)
- `address asset0`, `address asset1`
- `uint256 targetDualHF` (conservative, e.g., 1.6e18+)
- `uint256 lowHFThreshold`
- `uint256 highHFThreshold`
- `uint256 maxOracleDeviation`
- `uint256 minNetCarry`

## 5. Core Calculations

### 5.1 Value Accounting
- Supplies/debts queried per protocol (scaled/oracle-priced).
- `totalAssets()`: Net value across both (supplies - debts, normalized).

### 5.2 Optimal Direction
```pseudocode
carryIfFavorP1Supply = (projBufferP1 * P1_supplyAPY_assetHeavy) + (projBufferP2 * P2_supplyAPY) - weighted_borrow_costs
Compare both directions; select highest ≥ minNetCarry
```

### 5.3 Safe Loop Amount
- Calc max borrow per protocol HF/LTV.
- Recursive projection (solve for amplification factor).

## 6. Token Routes & Flows

Use flash loans for atomic recursion.

### 6.1 exchangeIn Paths
1. **asset0/asset1**: Supply to favored protocol → flash loan atomic loop (borrow → supply cross → borrow back → re-supply).
2. **Protocol supply tokens**: Transfer → auto-loop if room.

### 6.2 exchangeOut Paths
Flash loan delever: Repay → withdraw cross → repay → withdraw.

### 6.3 rebalance()
Flash loan batched:
1. Query dual HF, rates, oracles.
2. Branches:
   - Defensive: Low HF/deviation → delever (repay → withdraw).
   - Switch: Carry flip → partial delever → re-loop opposite.
   - Lever Up: High HF + good carry → additional recursive loop.
   - Neutral: Minor adjust for carry.

## 7. Safety & Risks

- Flash loan atomicity + multi-oracle min.
- Dual HF monitoring + conservative thresholds.
- Risks: Cascade liqs, protocol-specific exploits, flash loan fees.
- Benefits: Pure carry (no IL), cross arb.

## 8. Task Breakdown

Phase 1: Setup (3-5 days) — Dual protocol + flash loan integrations.  
Phase 2: Calculations (4-6 days) — Dual HF/carry/recursion math.  
Phase 3-4: Exchange paths with flash (8-12 days).  
Phase 5: Rebalance (5 days).  
Phase 6: Testing (10+ days) — Multi-protocol forks.

Total: 6-9 weeks (higher complexity).

This design captures persistent cross diffs safely—strong evolution from LP version for carry-focused users. Recommend starting with single-protocol proof, then cross.