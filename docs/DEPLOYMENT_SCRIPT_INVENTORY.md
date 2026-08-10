# Deployment Script Inventory

## Scope

This file inventories what the current deployment-oriented Foundry scripts under `scripts/foundry/` deploy or orchestrate.

It is intentionally grouped by environment so review can focus on the active deployment surfaces instead of treating every historical or local helper script as part of one pipeline.

Notes:

- `contracts/script/IndexedexScript.sol` is a deprecated compatibility shim and does not deploy anything.
- Script names still use legacy `ProtocolDETF` naming in several places. This inventory preserves the current on-disk names.
- Some Sepolia entrypoints are currently reserved stubs and explicitly revert instead of deploying.

## Deployment Surface Summary

### Active staged deployment families

- `scripts/foundry/anvil_base_main/`: full Base-mainnet-fork local deployment pipeline.
- `scripts/foundry/anvil_robinhood_main/`: Robinhood-mainnet-fork (Anvil **chain id 4663**) Uni V3/V4 SE + hook + inert DETF pipeline. Entry: `scripts/shell/anvil_robinhood_main.sh` → `deploy_all.sh`.
- `scripts/foundry/anvil_sepolia/`: Sepolia-fork local deployment pipeline.
- `scripts/foundry/public_sepolia/`: current public testnet deployment entrypoints for Ethereum Sepolia and Base Sepolia.
- `scripts/foundry/supersim/`: coordinated two-chain local Superchain deployment plus bridge bootstrap.

### Standalone or specialized deployment scripts

- `scripts/foundry/base_main/Script_BaseMain_DeployIndexedex.s.sol`: Base mainnet core stack deploy.
- `scripts/foundry/ethereum_main/Script_DeployRichToken.s.sol`: Ethereum mainnet RICH token deploy.

### Legacy or local scaffolding

- `scripts/foundry/local/`: older local demo and Sepolia bootstrap scripts.
- `scripts/foundry/local/segmented/`: segmented local environment bring-up scripts.

### Shared helper scripts

- `scripts/foundry/shared/SingleVaultDetfUniswapV4LiquiditySeeder.sol`: utility contract for seeding Uniswap V4 liquidity; not an environment entrypoint.

## Environment Inventory

### `anvil_robinhood_main/`

Anvil fork of **Robinhood Chain mainnet** at **chain id 4663**. Uses `ROBINHOOD_MAIN` Uni V3/V4/Permit2 pins (never redeploys RH cores). Deploys Crane foundation, IndexedEx manager, TT0–TT7, V3/V4 SE vaults, rate providers, hook packages (CP / Orbital / Weighted / Single SE Buffer), DETF packages, and **inert** demos (no `.bond(`). Exports `frontend/packages/protocol/src/addresses/chain/4663/`.

| Script | What it deploys or does |
| --- | --- |
| `Script_00_Preflight.s.sol` | Asserts chain 4663 + RH pin bytecode; writes `00_preflight.json`. |
| `Script_01_DeployCraneFoundation.s.sol` | CREATE3 + diamond package factory + shared facets. |
| `Script_02_DeployIndexedexCore.s.sol` | FeeCollector + IndexedexManager. |
| `Script_03_DeployHookFactory.s.sol` | Uni V4 hook diamond package factory; sets on manager. |
| `Script_04_DeployTestTokens.s.sol` | TT0–TT7 mintable; mints 1e12 units to deployer + UI wallet. |
| `Script_05_DeployUniV3PoolsAndSeed.s.sol` | Uni V3 pool graph + NPM liquidity on RH factory. |
| `Script_06_DeployUniV4PoolsAndSeed.s.sol` | Uni V4 SE underlying pools + seeder on RH PoolManager. |
| `Script_07_DeployUniV3StandardExchange.s.sol` | Uni V3 SE DFPkg + vault instances. |
| `Script_08_DeployUniV4StandardExchange.s.sol` | Uni V4 SE DFPkg + vault instances. |
| `Script_09_DeployRateProviders.s.sol` | SE rate providers for buffered legs. |
| `Script_10_DeployHookPackages.s.sol` | CP / Orbital / Weighted / Single SE Buffer hook DFPkgs. |
| `Script_11_DeployDetfChildren.s.sol` | Bond NFT + rebasing claim DFPkgs; default bond terms. |
| `Script_12_DeployDetfPackages.s.sol` | CP / Orbital / Weighted DETF DFPkgs. |
| `Script_13_DeployInertDemos.s.sol` | Weighted buffer n=8, single SE buffers, 6 inert DETFs (no bond). |
| `Script_14_ExportFrontendArtifacts.s.sol` | Writes `chain/4663` platform + tokenlists. |
| `deploy_all.sh` | Orchestrator (`all`, `foundation`, `assets`, `pools`, `se`, `packages`, `demos`, `export`, `stageNN`). |

Shell entry: `scripts/shell/anvil_robinhood_main.sh`. Artifacts: `deployments/anvil_robinhood_main/`.

### `anvil_base_main/`

This is the most complete staged pipeline in the repo. It deploys the full local Base-mainnet-fork stack, including factories, shared facets, Indexedex core proxies, DEX packages, pools, strategy vaults, DETFs, WETH/TTC extensions, rate providers, and Balancer nested liquidity pools.

| Script | What it deploys or does |
| --- | --- |
| `Script_00_DebugSender.s.sol` | Diagnostic only. Logs script sender/origin behavior. |
| `Script_00_SweepEthToDev0.s.sol` | Utility only. Sweeps sender ETH to the dev wallet. |
| `Script_01_DeployFactories.s.sol` | Crane deployment infrastructure: `Create3Factory` and `DiamondPackageCallBackFactory`. |
| `Script_02_DeploySharedFacets.s.sol` | Shared reusable facets and packages used across Indexedex vaults and proxies, including ERC20, ERC2612, ERC5267, ERC4626, ownership, and diamond/introspection pieces. |
| `Script_03_DeployCoreProxies.s.sol` | Core platform proxies: Fee Collector and Indexedex Manager. |
| `Script_04_DeployDEXPackages.s.sol` | DEX-related packages: Uniswap V2 standard exchange, Aerodrome standard exchange, Camelot V2 standard exchange, Balancer V3 standard exchange router, standard exchange rate provider, and Balancer constant-product pool packages. |
| `Script_05_DeployTestTokens.s.sol` | Test ERC20 tokens `TTA`, `TTB`, and `TTC`. |
| `Script_06_DeployPools.s.sol` | Base trading pools for the test token triad. |
| `Script_07_DeployStrategyVaults.s.sol` | Standard exchange strategy vaults for the stage-6 pools. |
| `Script_08_DeployAerodromeStrategyVaults.s.sol` | Aerodrome-specific strategy vaults. |
| `Script_09_DeployBalancerConstProdPools.s.sol` | Balancer V3 constant-product pools for the test token pairs. |
| `Script_10_DepositBaseLiquidity.s.sol` | Seeds initial liquidity into the base pools. |
| `Script_11_DeployStandardExchangeRateProviders.s.sol` | Standard exchange rate-provider vaults/proxies. |
| `Script_12_DeployBalancerConstProdVaultTokenPools.s.sol` | Balancer pools pairing vault shares with underlying tokens. |
| `Script_13_SeedBalancerVaultTokenPoolLiquidity.s.sol` | Seeds the stage-12 Balancer vault-token pools. |
| `Script_14_DeployERC4626PermitVaults.s.sol` | ERC4626 permit-enabled vaults over the test tokens. |
| `Script_14_ExportTokenlists.s.sol` | Export only. Writes tokenlist artifacts. |
| `Script_15_DeploySeigniorageDETFS.s.sol` | Seigniorage DETF package/proxy deployment for the strategy-vault surface. |
| `Script_16_DeployProtocolDETF.s.sol` | Single-vault DETF deployment path using the legacy protocol-named stage. |
| `Script_17_DeployWethTtcPools.s.sol` | WETH/TTC pools across supported DEX surfaces. |
| `Script_18_DeployWethTtcVaults.s.sol` | Standard exchange vaults for the WETH/TTC pools. |
| `Script_19_SeedWethTtcBaseLiquidity.s.sol` | Seeds WETH/TTC base liquidity. |
| `Script_20_DeployWethTtcRateProvidersAndBalancerVaultTokenPools.s.sol` | WETH/TTC rate providers plus Balancer vault-token pools for that pair. |
| `Script_21_SeedWethTtcBalancerVaultTokenPoolLiquidity.s.sol` | Seeds WETH/TTC Balancer vault-token pools. |
| `Script_22_DeployWethTtcVaultVaultPool.s.sol` | Balancer vault-vault pool containing WETH/TTC vault shares. |
| `Script_23_SeedWethTtcVaultVaultPoolLiquidity.s.sol` | Seeds the vault-vault pool. |
| `Script_99_SweepBalancesToDeployer.s.sol` | Cleanup utility. Sweeps balances to the deployer address. |
| `Script_ExportTokenlists.s.sol` | Export only. Writes merged/segmented frontend tokenlists. |
| `deploy_all.sh` | Shell orchestrator that runs the numbered stages in sequence and exports frontend-facing artifacts. |

### `anvil_sepolia/`

This is the Sepolia-fork variant of the staged pipeline. It follows the same pattern as `anvil_base_main`, but the DEX mix is slimmer and the Sepolia path splits some package deployment differently.

| Script | What it deploys or does |
| --- | --- |
| `Script_00_SweepEthToDev0.s.sol` | Utility only. Sweeps ETH to the dev wallet. |
| `Script_01_DeployFactories.s.sol` | Crane factory infrastructure. |
| `Script_02_DeploySharedFacets.s.sol` | Shared facets and foundational packages. |
| `Script_03_DeployCoreProxies.s.sol` | Fee Collector and Indexedex Manager proxies. |
| `Script_04_DeployDEXPackages_BalancerV3.s.sol` | Balancer V3-oriented DEX package deployment for the Sepolia path. |
| `Script_05_DeployUniswapV2.s.sol` | Uniswap V2 package/core deployment used by the Sepolia flow. |
| `Script_06_DeployAerodrome.s.sol` | Aerodrome-specific stage in the Sepolia family. This appears to be a compatibility or placeholder step rather than a normal public-Aerodrome deployment surface. |
| `Script_07_DeployTestTokens.s.sol` | Test ERC20 tokens. |
| `Script_08_DeployPools.s.sol` | Trading pools for the Sepolia token set. |
| `Script_09_DeployStrategyVaults.s.sol` | Strategy vaults for the stage-8 pools. |
| `Script_10_DepositBaseLiquidity.s.sol` | Seeds initial liquidity. |
| `Script_11_DeployStandardExchangeRateProviders.s.sol` | Standard exchange rate-provider deployment. |
| `Script_12_DeployBalancerConstProdVaultTokenPools.s.sol` | Balancer vault-token pool deployment. |
| `Script_13_SeedBalancerVaultTokenPoolLiquidity.s.sol` | Seeds stage-12 pools. |
| `Script_14_DeployERC4626PermitVaults.s.sol` | ERC4626 permit vaults. |
| `Script_15_DeploySeigniorageDETFS.s.sol` | Seigniorage DETF deployment. |
| `Script_16_DeployProtocolDETF.s.sol` | Legacy protocol-named single-vault DETF stage. |
| `Script_17_DeployWethTtcPools.s.sol` | WETH/TTC pool expansion. |
| `Script_18_DeployWethTtcVaults.s.sol` | WETH/TTC vault deployment. |
| `Script_19_SeedWethTtcBaseLiquidity.s.sol` | Seeds WETH/TTC liquidity. |
| `Script_20_DeployWethTtcRateProvidersAndBalancerVaultTokenPools.s.sol` | WETH/TTC rate providers and vault-token pools. |
| `Script_21_SeedWethTtcBalancerVaultTokenPoolLiquidity.s.sol` | Seeds WETH/TTC vault-token pools. |
| `Script_22_DeployWethTtcVaultVaultPool.s.sol` | WETH/TTC vault-vault pool deployment. |
| `Script_23_SeedWethTtcVaultVaultPoolLiquidity.s.sol` | Seeds the stage-22 pool. |
| `Script_ExportTokenlists.s.sol` | Export only. Writes tokenlists. |
| `deploy_sepolia.sh` | Shell orchestrator for the numbered Sepolia-fork stages. |

### `public_sepolia/ethereum/`

This is the implemented public Ethereum Sepolia entrypoint family. It reuses the anvil-style stage scripts, but swaps in narrower non-WETH pool deployment stages and optionally skips the legacy protocol-named DETF stage.

| Script | What it deploys or does |
| --- | --- |
| `Script_04_NonWethUniV2PoolsAndVaults.s.sol` | Uniswap V2 pools and matching vaults for non-WETH token pairs. |
| `Script_05_NonWethBalancerPools.s.sol` | Balancer pools for the non-WETH token pairs. |
| `Script_16_DeployProtocolDETF.s.sol` | Legacy protocol-named DETF stage for the Ethereum Sepolia public deployment path. |
| `Script_17_BridgeTokensToBase.s.sol` | Bridge action only. Sends the public Sepolia token set to Base Sepolia. |
| `Script_ExportTokenlists.s.sol` | Export only. Writes tokenlists for the Ethereum Sepolia side. |
| `Script_DeployAll.s.sol` | Solidity orchestrator. Runs factories, shared facets, core proxies, Balancer/UniV2 package setup, test tokens, non-WETH pool/vault stages, ERC4626 vaults, seigniorage DETFs, optional stage 16, and tokenlist export. |

### `public_sepolia/base/`

This is the implemented public Base Sepolia entrypoint family. It extends the staged deployment with Base-only protocol core bring-up and bridge-token creation.

| Script | What it deploys or does |
| --- | --- |
| `Script_05_CreateBridgeTokens.s.sol` | L2 bridge token wrappers or equivalents used by the Base Sepolia side. |
| `Script_05_DeployTestTokens.s.sol` | Base-side test or wrapped token deployment for the public testnet path. |
| `Script_10_DepositBaseLiquidity.s.sol` | Base-side liquidity seeding stage. |
| `Script_13_SeedBalancerVaultTokenPoolLiquidity.s.sol` | Base-side vault-token pool seeding override. |
| `Script_16_DeployProtocolDETF.s.sol` | Legacy protocol-named DETF stage for the Base Sepolia path. This variant is intended to deploy packages without the mainnet-style funding step. |
| `Script_ExportTokenlists.s.sol` | Export only. Writes Base Sepolia tokenlists. |
| `Script_DeployAll.s.sol` | Solidity orchestrator. Runs factories, shared facets, core proxies, Base-side Uniswap V2/Balancer/Aerodrome core stages, DEX packages, test tokens, pools, strategy vaults, Aerodrome vaults, Balancer pools, liquidity seeding, rate providers, ERC4626 vaults, seigniorage DETFs, optional stage 16, and tokenlist export. |

### `supersim/ethereum/`

This is the Ethereum-side deployment surface for the local two-chain SuperSim environment.

| Script | What it deploys or does |
| --- | --- |
| `Script_04_UniV2PoolsAndVaults.s.sol` | Ethereum-side Uniswap V2 pools and their vaults for the SuperSim flow. |
| `Script_05_BalancerPools.s.sol` | Ethereum-side Balancer pools for the SuperSim flow. |
| `Script_DeployProtocolDetfMinimal.s.sol` | Minimal bootstrap for the legacy protocol-named DETF path: factories, shared facets, core proxies, Balancer package stage, and stage 16 only. |
| `Script_ExportTokenlists.s.sol` | Export only. Writes Ethereum-side SuperSim tokenlists. |
| `Script_DeployAll.s.sol` | Ethereum-side orchestrator. Runs factories, shared facets, core proxies, Balancer package setup, Uniswap V2 package setup, test tokens, Ethereum-specific UniV2/Balancer pool stages, ERC4626 permit vaults, seigniorage DETFs, stage 16, tokenlist export, and chain-manifest export. |

### `supersim/base/`

This is the Base-side deployment surface for the local two-chain SuperSim environment.

| Script | What it deploys or does |
| --- | --- |
| `Script_03A_DeployUniswapV2Core.s.sol` | Base-side Uniswap V2 core deployment. |
| `Script_03B_DeployBalancerV3Core.s.sol` | Base-side Balancer V3 core deployment. |
| `Script_03C_DeployAerodromeCore.s.sol` | Base-side Aerodrome core deployment. |
| `Script_17_WethTtcPoolsAndVaults.s.sol` | Combined WETH/TTC pool and vault bring-up for the Base SuperSim path. |
| `Script_18_WethTtcBalancerPools.s.sol` | Base-side Balancer WETH/TTC extension stage. |
| `Script_DeployProtocolDetfMinimal.s.sol` | Minimal bootstrap for the legacy protocol-named DETF path: factories, shared facets, core proxies, DEX packages, and stage 16 only. |
| `Script_ExportTokenlists.s.sol` | Export only. Writes Base-side SuperSim tokenlists. |
| `Script_DeployAll.s.sol` | Base-side orchestrator. Runs the full Base-family stage set, including protocol cores, pools, strategy vaults, Aerodrome vaults, Balancer pools, liquidity seeding, ERC4626 vaults, seigniorage DETFs, stage 16, WETH/TTC stages, tokenlist export, and chain-manifest export. |

### `supersim/` bridge bootstrap scripts

These are cross-environment setup scripts that complement the two per-chain `Script_DeployAll` entrypoints.

| Script | What it deploys or does |
| --- | --- |
| `Script_24_DeploySuperchainBridgeInfra.s.sol` | Deploys Superchain bridge support infrastructure: `SuperChainBridgeTokenRegistry`, `ApprovedMessageSenderRegistry`, and `TokenTransferRelayer`. |
| `Script_25_ConfigureProtocolDetfBridge.s.sol` | Configures the bridge by linking local and remote DETF/token addresses in the bridge registries and approving senders. |
| `Script_26_TestProtocolDetfReserveBridge.s.sol` | Reserve-bridge test script. Exercises the configured bridge path rather than deploying new contracts. |
| `deploy_mainnet_bridge_ui.sh` | Shell orchestrator that runs the two chain deploys, bridge infra deploy, bridge configuration, reserve-bridge test, and frontend artifact export. |

### `sepolia/`

This directory currently contains mixed status entrypoints.

| Script | What it deploys or does |
| --- | --- |
| `Script_00_DeploySepoliaDemo.s.sol` | Older single-chain orchestrator that runs stages 01-15 plus tokenlist export. It does not include the protocol-named stage 16. |
| `Script_01_DeployFactories.s.sol` through `Script_15_DeploySeigniorageDETFS.s.sol` | Single-chain Sepolia deployment stages analogous to the anvil-sepolia family. |
| `Script_DeploySepoliaEnvironment.s.sol` | Reserved stub. Explicitly reverts and does not deploy anything in the current repo state. |
| `ethereum/Script_DeployAll.s.sol` | Reserved stub. Explicitly reverts and does not deploy anything in the current repo state. |
| `base/Script_DeployAll.s.sol` | Reserved stub. Explicitly reverts and does not deploy anything in the current repo state. |
| `Script_ExportTokenlists.s.sol` | Export only. Writes Sepolia tokenlists. |

## Standalone Mainnet Scripts

### `base_main/`

| Script | What it deploys or does |
| --- | --- |
| `Script_BaseMain_DeployIndexedex.s.sol` | Deploys the core Base mainnet Indexedex stack on top of pre-existing Crane factories. Specifically deploys core ownership/diamond facets, Fee Collector, Indexedex Manager, operator configuration, Aerodrome standard exchange package, Balancer V3 standard exchange router package, and Balancer router proxy. It intentionally does not deploy the Crane factories themselves. |

### `ethereum_main/`

| Script | What it deploys or does |
| --- | --- |
| `Script_DeployRichToken.s.sol` | Deploys a mainnet `RICH` token stack: initializes local Crane factories, deploys ERC20/ERC2612/ERC5267 facets, deploys `ERC20PermitDFPkg`, and deploys the `RICH` token proxy/instance. Also writes JSON deployment artifacts. |

## Legacy Local and Demo Scripts

These files appear to be older bootstrap/demo flows and segmented local assembly scripts. They are useful as references but do not represent the newer staged environment pipelines.

### `local/`

| Script family | What it deploys or does |
| --- | --- |
| `Local_Sepolia_01_Deploy.s.sol` | Older monolithic local Sepolia bring-up. It wires WETH, Uniswap V2 router/factory reuse, Permit2, Balancer addresses, Crane factories, shared facets, vault fee oracle, vault registry, Uniswap/Balancer packages, and Indexedex platform pieces, then writes deployment state. |
| `Local_Sepolia_01_Deploy_Factory_Test.s.sol` | Local Sepolia bootstrap variant for factory testing. |
| `Local_Sepolia_02_*` scripts | Test-token and pool bring-up scripts, including WETH variants. |
| `Local_Sepolia_03_Test_ERC4626.s.sol` | ERC4626 local test deployment flow. |
| `Local_Sepolia_04_Test_UniV2Pools.s.sol` | Local Uniswap V2 pool-focused deployment/testing flow. |
| `Sepolia_01_Deploy.s.sol`, `Sepolia_02_Test_Tokens_and_Pools.s.sol` | Older Sepolia-oriented bootstrap/test scripts. |
| `Demo_01_Test_Tokens.s.sol`, `Demo_02_External_Protocols.s.sol` | Demo/prototype deployment helpers. |

### `local/segmented/`

| Script | What it deploys or does |
| --- | --- |
| `Local_00_Init.s.sol` | Local bootstrap/init stage. |
| `Local_01_WETH9.s.sol` | Local WETH setup. |
| `Local_02_Permit2.s.sol` | Local Permit2 setup. |
| `Local_03_Balancer_V3.s.sol` | Local Balancer V3 setup. |
| `Local_04_Uniswap_V2.s.sol` | Local Uniswap V2 setup. |
| `Local_05_Crane_Factories.s.sol` | Local Crane factory deployment/setup. |
| `Local_06_Crane_Access.s.sol` | Local Crane access/ownership component setup. |
| `Local_07_Crane_Components.s.sol` | Local Crane component deployment. |
| `Local_08_Indexedex_Components.s.sol` | Indexedex component deployment slice. |
| `Local_09_Indexedex_Core.s.sol` | Indexedex core deployment slice. |
| `Local_10_Indexedex_Components_2.s.sol` | Additional Indexedex component deployment slice. |
| `Local_11_Indexedex_Platform.s.sol` | Local platform finalization that materializes the Balancer standard exchange routers from previously deployed packages. |
| `Local_12_Demo_Platform.s.sol` | Demo platform assembly stage. |
| `Local_13_Test_Tokens.s.sol` | Local test token setup. |
| `Local_14_Test_ERC4626.s.sol` | Local ERC4626 test setup. |

## Shared Helper Contracts

| File | What it does |
| --- | --- |
| `scripts/foundry/shared/SingleVaultDetfUniswapV4LiquiditySeeder.sol` | Helper contract that adds Uniswap V4 liquidity via `PoolManager.unlock`. It is a liquidity-seeding utility, not a top-level deployment pipeline entrypoint. |

## Current Review Notes

- The most actively maintained deployment surfaces appear to be `anvil_base_main`, `anvil_sepolia`, `public_sepolia`, and `supersim`.
- The `sepolia/base` and `sepolia/ethereum` `Script_DeployAll` entrypoints are present but intentionally disabled.
- Several current deployment entrypoints still expose stage names like `Script_16_DeployProtocolDETF` and bridge scripts like `Script_25_ConfigureProtocolDetfBridge`, even though the protocol-specific contract slice was removed elsewhere in the repo. That naming mismatch is worth reviewing separately.