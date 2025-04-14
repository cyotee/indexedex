# Product Requirements Document (PRD) 1: Research Task for Identifying Lending Protocols, Minting Stablecoins, and Looping Routes

## Objective
Assign an agent (or research process) to comprehensively map the DeFi ecosystem for lending protocols and stablecoins with minting/CDP mechanisms. The goal is to identify viable **recursive looping routes** for a leveraged vault: Deposit collateral → mint stable → lend stable → borrow collateral → repeat (up to configurable LTVs per side).

This research will feed into a follow-up PRD listing viable combinations for specific vault implementations.

## Scope
- Focus on Ethereum mainnet and major L2s (Arbitrum, Base, Optimism) as of January 2026.
- Lending protocols: Those supporting supply of stables and borrow of volatile collateral (e.g., WETH, LSTs).
- Stablecoins: Overcollateralized/hybrid with user-mintable mechanisms (CDPs, vaults, soft-liq systems). Exclude pure fiat-backed (USDC/USDT) or failed pure algo (UST-style).
- Looping Viability Criteria:
  - Minting side: Deposit asset X (e.g., WETH/stETH) → mint stable Y, with configurable ratio (>100% collateralization).
  - Lending side: Supply Y → borrow X (high LTV, low borrow cost).
  - Composite leverage safe (e.g., 3-6x max).
  - Positive carry potential (lending APY + savings > stability fee/borrow cost).
  - Active TVL (> $100M preferred), low depeg risk.
  - Atomic/composable preferred (flash loans/EVC support).

## Research Tasks

1. **Map Lending Protocols** (Top 10-15 by TVL)
   - Sources: DefiLlama (lending section), Dune Analytics dashboards, protocol docs.
   - Data per protocol: Name, version, chains, TVL, key mechanics (e.g., isolated pools, rewards), major assets (supply stables like DAI/USDC, borrow volatiles like WETH).
   - Highlight: Support for borrowing ETH/LSTs against stables.

2. **Map Minting Stablecoins/CDPs**
   - Sources: DefiLlama stablecoins, protocol sites (Maker, Curve, Liquity, Frax, Aave GHO, Ethena, Prisma).
   - Data per stable: Name, protocol, TVL/mcap, minting mechanics, collateral types, ratios/fees, yield features (e.g., DSR, staking).
   - Filter: Active minting paths with volatile collateral.

3. **Identify Looping Routes**
   - Cross-reference: For each minting stable Y + collateral X, check if major lending protocols allow supply Y → borrow X.
   - Evaluate: Current rates (stability fee vs borrow APY), historical carry, depeg risk, liquidation mechanics.
   - Sources: DeFi forums (Reddit r/defi, Discord), Medium/Yearn-style analyses, on-chain data (Dune queries for vault usage).
   - Rank viability: High (classic DAI loops), Medium (emerging), Low (high risk/depeg).

4. **Risk & Trends Assessment**
   - Note governance risks, reward changes, integrations (e.g., Morpho optimizers).
   - Search for existing vaults/strategies (e.g., Yearn, Sommelier, Instadapp).

## Deliverables
- Spreadsheet/matrix: Columns for minting protocol/stable, lending protocol, collateral asset, stable, estimated max safe leverage, carry potential, risks.
- Summary report: Top 5-10 viable routes, with rationale.

## Timeline
- 3-5 days for data collection.
- 2 days for cross-analysis and ranking.
