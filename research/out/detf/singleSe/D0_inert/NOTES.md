# D0_inert

## One-line story
Policy Single SE DETF deploys inert against Uni V2 SE; mint blocked; warp does not enable mint/expansion.

## Setup
- DETF: Single SE Policy (default thresholds)
- SE: Uni V2 WETH/USDC hermetic
- Drive: deploy only + warp

## Assertions
- isReserveLive == false
- isMintingAllowed == false
- mintThreshold/burnThreshold defaults 1.05e18 / 0.95e18
- mint reverts while inert (when SE shares available)

## Caveats
- Hermetic research; not mainnet APY
- Expansion positive path is D8; D0 only checks inert negatives

## Commands
```bash
FOUNDRY_PROFILE=default forge script \
  scripts/foundry/research/detf/singleSe/Script_D0_Inert.s.sol:Script_D0_Inert -vv
```
