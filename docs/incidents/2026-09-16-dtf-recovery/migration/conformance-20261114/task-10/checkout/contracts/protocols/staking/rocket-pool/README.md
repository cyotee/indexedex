# Rocket Pool rETH Standard Exchange Vault

Production-first IndexedEx Standard Exchange for Rocket Pool liquid staking.

## Product (PRD locks)

- **Yield / `IERC4626.asset()`:** rETH  
- **Liquid sleeve:** WETH (default **20%** liquid via fee oracle)  
- **Surfaces:** `IStandardExchangeIn` + `IStandardExchangeOut` and native Pendle `IStandardizedYield` (no native ETH)  
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

Instance arguments are exactly `(rETH, weth, depositPool, rocketStorage)`. All four addresses are required. Deployment validates that RocketStorage binds the supplied rETH and deposit pool; legacy three-address payloads are rejected. The registry also supplies the live protocol settings used by composed-route projections.

The [funded DETF/SY release plan](../../../vaults/detf/DETF_FUNDED_STAKING_AND_SY_IMPLEMENTATION_AND_TEST_PLAN.md) governs the additive SY surface and current validation. Seven actual-protocol projection cases pass at each of Ethereum blocks 24,000,000 (deposit pool v3) and 25,934,585 (v4); final repository acceptance is tracked in that plan.

## Tests

```bash
forge build
forge test --match-path 'test/foundry/spec/protocol/staking/rocket-pool/**' -vv

FOUNDRY_PROFILE=fork forge test \
  --match-path 'test/foundry/fork/eth_main/vaults/staking/rocket-pool/**' -vv
```
