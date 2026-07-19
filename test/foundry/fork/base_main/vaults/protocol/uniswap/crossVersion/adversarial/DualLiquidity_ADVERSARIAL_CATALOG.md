# DualLiquidity — Adversarial Catalog Map (Wave 2A)

## Status

**IMPLEMENTED (P0 via catalog + fill)** — existing fork security suites + `adversarial/Adversarial_DualLiquidity_Catalog.t.sol`.

## ID map

| ID | Location |
|----|----------|
| A3-class | `*_ShareInflation.t.sol` |
| C reentrancy | `*_Reentrancy.t.sol`, `*_ReentrancyRedeem.t.sol` |
| E residual | `*_Residual.t.sol` |
| F immutability | `*_Immutability.t.sol` |
| B rate | `*_RateExtremes.t.sol` |
| Guards | `*_Guards.t.sol` |
| H3 / F1 fill | `adversarial/Adversarial_DualLiquidity_Catalog.t.sol` |

## Run

```bash
forge test --match-path 'test/foundry/fork/base_main/vaults/protocol/uniswap/crossVersion/adversarial/**'
forge test --match-path 'test/foundry/fork/base_main/vaults/protocol/uniswap/crossVersion/**'
```
