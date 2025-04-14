
# Product Requirements Document (PRD) 2: Viable Looping Relationships for Leveraged Minting Vaults

## Research Summary (As of January 15, 2026)
Based on current DeFi ecosystem (DefiLlama TVL leaders: Aave ~$15B+, Morpho ~$5B+, Spark/Maker ~$4B+, Compound Comet, Euler v2; Stables: DAI ~$5B, crvUSD ~$2B+, GHO ~$1B+, LUSD ~$800M, USDe synthetic ~$3B+):

Top lending protocols supporting stable supply + volatile borrow:
- Aave V3/V4: Multi-asset, high LTV on ETH/LSTs against stables.
- Morpho Blue: Optimized rates, vault-specific.
- Spark (Maker subDAO): DAI-focused lending.
- Euler v2: Modular, composable.
- Compound Comet: Base asset model (limited symmetry).

Top minting stables/CDPs:
- DAI (MakerDAO): ETH/stETH/RWA vaults, 130-170% ratios, DSR yield.
- crvUSD (Curve LLAMMA): Soft liq, ETH/crETH collateral.
- GHO (Aave): Facilitated mint against Aave supplies.
- LUSD (Liquity): 110% min, ETH troves, redemption mechanic.
- USDe (Ethena): Delta-hedged synthetic (less direct mint loop).
- mkUSD (Prisma): LST overcollateralized.

Existing/popular loops: DAI mint + Aave/Morpho borrow ETH remains classic (historical 3-5x leverage). crvUSD + Morpho growing. GHO internal on Aave.

## Viable Relationships (Ranked by Feasibility/Safety/TVL)
These combinations support safe recursive looping vaults (composite LTV ~50-70% effective for conservatism).

1. **High Viability: MakerDAO DAI + Aave V3/V4**
   - Collateral: WETH/stETH/LSTs.
   - Mint DAI → supply DAI on Aave → borrow ETH → back to Maker.
   - Carry: DSR + Aave supply APY vs stability fee + borrow.
   - Max safe leverage: 4-6x.
   - Risks: Maker governance fees, Aave HF.
   - Why top: Proven, high liquidity, DSR boost.

2. **High: MakerDAO DAI + Morpho Blue**
   - Similar flow, optimized rates via Morpho vaults.
   - Better carry potential.
   - Integrations common.

3. **High: Curve crvUSD + Morpho/Aave**
   - Mint crvUSD with ETH → supply → borrow ETH.
   - Soft liq (LLAMMA) reduces penalty risk.
   - Growing TVL.

4. **Medium-High: Liquity LUSD + Aave/Morpho**
   - Mint LUSD (110% ratio) → supply → borrow ETH.
   - Redemption arb keeps peg tight.
   - Lower leverage (strict ratio).

5. **Medium: Aave GHO + Internal Aave Looping**
   - Mint GHO against supplies → borrow more collateral internally.
   - Facilitators enable.
   - Less cross-protocol but efficient.

6. **Medium: Frax FRAX/frxETH + FraxLend/External**
   - Mint/redeem paths with ETH → lend FRAX → borrow.
   - Hybrid mechanics.

7. **Low-Medium: Ethena USDe + External Lending**
   - More staking (sUSDe) than direct mint loop; hedged borrow possible but complex/risky.

## Non-Viable or Low Priority
- Pure synthetic without CDP (e.g., older algo remnants).
- Low TVL/emerging (monitor for growth).

## Next Steps
These relationships enable specific vault PRDs:
- PRD for Maker DAI + Aave (primary).
- PRD for crvUSD + Morpho.
- Etc.

Prioritize high-viability for initial implementation (conservative params, flash loan atomicity, peg/HF monitoring).