# D1_firstBond

## One-line story
First bond with pairToken takes Uni V4 CP DETF live; bond NFT holds hook LP principal.

## Setup
- Bond amount: 100 ether pairToken
- Lock: TestBase DEFAULT_MIN_LOCK

## Result
PASS: isReserveLive=true after bond; tokenId>0; shares>0.

## Commands
```bash
forge script scripts/foundry/research/uniswapV4/detf/standardExchangeCpSingle/Script_D1_FirstBond.s.sol:Script_D1_FirstBond -vv
```
