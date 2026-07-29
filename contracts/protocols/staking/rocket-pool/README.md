# Rocket Pool rETH Standard Exchange Vault

Production-first IndexedEx Standard Exchange for Rocket Pool liquid staking.

## Product (PRD locks)

- **Yield / `IERC4626.asset()`:** rETH  
- **Liquid sleeve:** WETH (default **20%** liquid via fee oracle)  
- **Surfaces:** `IStandardExchangeIn` + `IStandardExchangeOut` (no native ETH)  
- **WETH→SE:** best-effort stake overage (capacity-capped); mint succeeds when deposit pool full  
- **WETH→rETH:** hard capacity gate  
- **WETH pay:** sleeve → optional `rETH.burn` → `InsufficientLiquidReserve`  
- **Rebalance:** permissionless stake excess / burn deficit; no-ops when gated; **no** async queue  

See:

- [`ROCKET_POOL_RETH_STANDARD_EXCHANGE_VAULT_PRD.md`](./ROCKET_POOL_RETH_STANDARD_EXCHANGE_VAULT_PRD.md)
- [`ROCKET_POOL_RETH_STANDARD_EXCHANGE_IMPLEMENTATION_AND_TEST_PLAN.md`](./ROCKET_POOL_RETH_STANDARD_EXCHANGE_IMPLEMENTATION_AND_TEST_PLAN.md)

## Mainnet addresses

| Contract | Address |
|----------|---------|
| rETH | `0xae78736Cd615f374D3085123A210448E74Fc6393` |
| RocketStorage | `0x1d8f8f00cfa6758d7bE78336684788Fb0ee0Fa46` |
| RocketDepositPool | Resolve via storage key `rocketDepositPool` |
| WETH | chain canonical |

## Deploy path

CREATE3 facets + **vault registry** DFPkg (`indexedexManager.deployRocketPoolRETHStandardExchangeDFPkg`). Never `new` SUT facets/DFPkg.

## Tests

```bash
forge test --match-path 'test/foundry/spec/protocol/staking/rocket-pool/**' -vv

forge test --fork-url $ETH_RPC_URL \
  --match-path 'test/foundry/fork/eth_main/vaults/staking/rocket-pool/**' -vv
```
