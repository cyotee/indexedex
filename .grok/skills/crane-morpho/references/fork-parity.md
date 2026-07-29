# Morpho fork parity

## Contents

- Matching-market design
- Live bind
- Assertions

## Matching-market (required pattern)

On pinned fork:

1. Bind live `IMorpho(NETWORK.MORPHO)`  
2. Deploy local `Morpho(owner)` + local `AdaptiveCurveIrm(localMorpho)`  
3. Shared `OracleMock` + mintable ERC-20s  
4. Pick an LLTV already enabled on live Morpho  
5. `createMarket` on **both** with same loan/coll/oracle/lltv (IRM addresses differ)  
6. Same supply / collateral / borrow / warp / repay / withdraw sequence  
7. Exact equality: market aggregates (except lastUpdate if you choose), positions, Morpho balances  

Files:

- `test/foundry/fork/ethereum_main/morpho/MorphoBluePortedMarketParity_Fork.t.sol`
- `test/foundry/fork/base_main/morpho/MorphoBluePortedMarketParity_Fork.t.sol`

## Live market views

`MorphoBlueLiveMarket_Fork` binds known market ids when present; soft-skips if id missing at fork block. Prefer parity tests as the hard gate.

## RPC

`morpho_port` profile RPC endpoints use `ALCHEMY_KEY` / `INFURA_KEY` for ethereum_mainnet_alchemy and base_mainnet_alchemy.
