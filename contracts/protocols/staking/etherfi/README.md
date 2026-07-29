# ether.fi weETH Standard Exchange

Production-first IndexedEx Standard Exchange vault for ether.fi liquid restaking.

## Docs

- [PRD](./ETHERFI_WEETH_STANDARD_EXCHANGE_VAULT_PRD.md)
- [Implementation & test plan](./ETHERFI_WEETH_STANDARD_EXCHANGE_IMPLEMENTATION_AND_TEST_PLAN.md)

## Mainnet addresses (verified via LiquidityPool getters)

| Role | Address |
|------|---------|
| eETH | `0x35fA164735182de50811E8e2E824cFb9B6118ac2` |
| weETH | `0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee` |
| LiquidityPool | `0x308861A430be4cce5502d0A12724771Fc6DaF216` |
| WithdrawRequestNFT | `0x7d5706f6ef3F89B3951E23e557CDFBC3239D4E2c` |
| EtherFiRedemptionManager | `0xDadEf1fFBFeaAB4f68A9fD181395F68b4e4E7Ae0` |
| WETH | chain canonical (`0xC02a…cC2` on mainnet) |

## Product defaults

- `asset()` / locked yield: **weETH**
- Liquid sleeve: **WETH**, default policy **20%** (`0.20e18`)
- SE surfaces: `exchangeIn` / `exchangeOut` only (**no** `exchangeInEth`)
- WETH pay: sleeve → optional `RedemptionManager.redeemWeEth` (ETH → wrap) → `InsufficientLiquidReserve`
- WETH→SE mint: split to target liquid %; stake overage same tx
- Async queue: **rebalance-only** (never on user In/Out)

## Deploy

CREATE3 facets via `EtherFiWeETH_Component_FactoryService`; DFPkg via IndexedEx vault registry (`deployPkg` / `deployVault`). Never `new` SUT facets/DFPkg.

## Tests

```bash
# Hermetic
forge test --match-path 'test/foundry/spec/protocol/staking/etherfi/**' -vv

# Mainnet fork (FK6 live redeem is a hard ship gate)
forge test --fork-url $ETH_RPC_URL \
  --match-path 'test/foundry/fork/eth_main/vaults/staking/etherfi/**' -vv
```
