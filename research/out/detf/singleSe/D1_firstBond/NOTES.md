# D1_firstBond

## One-line story
First bond of Uni V2 SE shares boots Policy Single SE DETF from inert to live with reserve pool + bond NFT.

## Setup
- DETF: Single SE Policy (default thresholds)
- SE: Uni V2 WETH/USDC hermetic
- Bond LP amount: 1000e18 Uni LP -> SE shares -> bond

## Assertions
- isReserveLive after bond
- reservePool != 0
- bond tokenId != 0
- residual free SE shares on diamond == 0

## Caveats
- Hermetic research; not mainnet APY
- Synthetic at live may sit in deadband or already mint-allowed (see D2)

## Commands
```bash
FOUNDRY_PROFILE=default forge script \
  scripts/foundry/research/detf/singleSe/Script_D1_FirstBond.s.sol:Script_D1_FirstBond -vv
```
