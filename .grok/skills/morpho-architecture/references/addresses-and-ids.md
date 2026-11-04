# Morpho addresses and market ids

## Contents

- Network constants in Crane
- Canonical ETH/Base Blue address
- Market id computation
- Fork tips

## Crane network constants

Import from chain-specific modules:

```solidity
import {ETHEREUM_MAIN} from "@crane/contracts/constants/networks/ETHEREUM_MAIN.sol";
import {BASE_MAIN} from "@crane/contracts/constants/networks/BASE_MAIN.sol";

IMorpho morpho = IMorpho(ETHEREUM_MAIN.MORPHO);
address irm = ETHEREUM_MAIN.MORPHO_ADAPTIVE_CURVE_IRM;
address factory = ETHEREUM_MAIN.MORPHO_METAMORPHO_FACTORY_V1_1;
address bundler = ETHEREUM_MAIN.MORPHO_BUNDLER3;
```

Also seeded on: OP, Arb, Sepolia/Base Sepolia, Robinhood, BC (MockMorpho bind-only).

## Canonical Blue singleton

On many chains Morpho Blue uses CREATE2 vanity:

`0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb` (ETH + Base)

IRM / factory addresses **differ by chain** — always use network constants.

## Market id

```solidity
import {MarketParamsLib} from "@crane/contracts/external/morpho/blue/libraries/MarketParamsLib.sol";
using MarketParamsLib for MarketParams;

Id id = marketParams.id();
// == Id.wrap(keccak256(abi.encode(marketParams)))
```

There is **no on-chain market enumeration**. Off-chain indexers or known ids are required to discover live markets.

## Fork tips

- Pin `DEFAULT_FORK_BLOCK` from the same network constants file.
- Parity tests: deploy **local** Morpho + AdaptiveCurveIRM; create matching markets (shared tokens/oracle/lltv; different IRM addresses).
- Assert exact market aggregates, positions, and Morpho token balances after identical ops.
