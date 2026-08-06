# D0_inert

## One-line story
Uni V4 Single SE CP DETF deploys Policy inert against SE Buffer CP hook; mint blocked; defaults 1.05/0.95.

## Setup
- DETF: UniswapV4SingleStandardExchangeDETF (Policy)
- Reserve host: Single SE Buffer CP Hook + ERC-4626 wrapper SE
- Gold TestBase production path

## Result
PASS: isReserveLive=false; isMintingAllowed=false; mint reverts; thresholds 1.05/0.95.

## Caveats
- Hermetic; not Balancer Single SE re-run

## Commands
```bash
forge script scripts/foundry/research/uniswapV4/detf/standardExchangeCpSingle/Script_D0_Inert.s.sol:Script_D0_Inert -vv
```
