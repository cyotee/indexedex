# Bundler3 notes

## Contents

- Call struct
- Empty bundle
- Adapters
- Live vs local

## Call struct

```solidity
struct Call {
    address to;
    bytes data;
    uint256 value;
    bool skipRevert;
    bytes32 callbackHash; // reenter bundle hash when needed
}
```

`multicall` requires `bundle.length > 0` or reverts `EmptyBundle()`.

## Adapters (vendored)

| Adapter | Use |
|---------|-----|
| `GeneralAdapter1` | Morpho supply/borrow/withdraw + Permit2 helpers |
| `EthereumGeneralAdapter1` | ETH/wstETH specifics |
| `ERC20WrapperAdapter` | Wrapper tokens |
| `ParaswapAdapter` | Swaps (optional) |

Migration adapters under upstream were **not** vendored in Crane first merge.

## Permit2

GeneralAdapter1 imports Crane Permit2:

`@crane/contracts/protocols/utils/permit2/{SafeCast160,Permit2Lib}.sol`

## Smoke test

`test/foundry/spec/protocols/lending/morpho/blue/unit/MorphoBlueVaultBundlerSmoke.t.sol`
