# D2_policyDeadband

## One-line story
Post first-bond mint not allowed; mint reverts; warp yields no natural expansion.

## Setup
- DETF: Single SE Policy
- SE: Uni V2 WETH/USDC hermetic

## Status
- d2Status: deadband_or_burn_side
- syntheticPrice (wei): 624999999999996735

## Caveats
- N/A is acceptable per campaign PRD; D3/D4 prove gates under real Uni trades

## Commands
```bash
FOUNDRY_PROFILE=default forge script \
  scripts/foundry/research/detf/singleSe/Script_D2_PolicyDeadband.s.sol:Script_D2_PolicyDeadband -vv
```
