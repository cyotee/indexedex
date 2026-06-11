# Deployment Script Inventory — Detailed Per-Stage Contract Listing

Date: 2026-06-04
Companion to: `docs/DEPLOYMENT_SCRIPT_INVENTORY.md` (high-level) and `docs/DEPLOYMENT_READINESS_REPORT.md` (state-of-readiness).

Scope: every script that is reachable from the **public Sepolia wrapper** (`scripts/foundry/public_sepolia/deploy_public_sepolia.sh`) plus the **anvil_base_main / anvil_sepolia / supersim stage libraries** they pull from. For each stage we list the concrete deployed contracts, the output JSON filename and the artifact keys, the upstream input artifacts it reads, and the on-chain effects beyond raw deploy.

Notation:

- "**Out**:" — file name written under `_outDir()` (set by `OUT_DIR_OVERRIDE`).
- "**Keys**:" — top-level JSON keys written to that file.
- "**Reads**:" — files from `_outDir()` it consumes.
- "**Effects**:" — side-effects beyond writing files (mints, approvals, registrations).

## 1. Cross-cutting infrastructure

These pieces are shared by every stage in the public Sepolia path.

### 1.1 DeploymentBase scaffolding

- `scripts/foundry/anvil_sepolia/DeploymentBase.sol` (used by Ethereum Sepolia path)
  - Loads `SENDER`, `OWNER`, `PRIVATE_KEY` env vars; defaults `owner = deployer = tx.origin`.
  - Reads `NETWORK_PROFILE` env (`ethereum_sepolia` default; switches Permit2/WETH/Balancer constants for `ethereum_main`).
  - Binds `PERMIT2`, `WETH9`, `BALANCER_V3_VAULT`, `BALANCER_V3_ROUTER` from `ETHEREUM_SEPOLIA` Crane network constants (WETH9 specifically uses `BALANCER_V3_WETH9` for cross-DEX consistency).
  - Validates that the chain is Sepolia by checking the Permit2/WETH/Balancer Vault bytecode is non-empty.
  - JSON read/write helpers all path through `_outDir()`, which defaults to `deployments/anvil_sepolia` but is always overridden by the wrapper.

- `scripts/foundry/anvil_base_main/DeploymentBase.sol` (used by Base Sepolia path)
  - Same shape as above but tailored to Base.
  - `NETWORK_PROFILE=base_sepolia` switches all protocol bindings to `BASE_SEPOLIA` Crane network constants; default is Base mainnet.
  - Adds rebinding of Uniswap V2, Aerodrome, Balancer V3 Vault/Router via `_boundXxx()` helpers that prefer artifact-resolved addresses when `03a_uniswap_v2_core.json` / `03b_balancer_v3_core.json` / `03c_aerodrome_core.json` are present (this is what lets the SuperSim/Base Sepolia path swap in locally-deployed protocol cores instead of mainnet ones).

- `scripts/foundry/public_sepolia/DeploymentBase.sol` and `scripts/foundry/public_sepolia/base/DeploymentBase.sol` extend the anvil bases and require `OUT_DIR_OVERRIDE` to be set.

- `scripts/foundry/public_sepolia/shared/SharedDeploymentBase.sol` reads `PUBLIC_SEPOLIA_ETHEREUM_OUT_DIR` / `PUBLIC_SEPOLIA_BASE_OUT_DIR` / `PUBLIC_SEPOLIA_SHARED_OUT_DIR` so cross-chain steps can address each chain's artifacts.

- `scripts/foundry/supersim/SuperSimManifestLib.sol` provides the same shape for SuperSim outputs under `deployments/supersim_sepolia/` with `SUPERSIM_*_OUT_DIR` overrides.

### 1.2 Bridge token planning

`scripts/foundry/public_sepolia/shared/BridgeTokenPlanning.sol` defines the L1↔L2 token plan:

- L1 chain id `11155111` (Ethereum Sepolia), L2 chain id `84532` (Base Sepolia).
- Bridge min gas limit `200_000`.
- L2 wrapper naming: `name ++ " (Base Sepolia)"`, `symbol ++ ".base"`.
- Per-token bridge amounts (computed from Stage 10 pool seeding, Stage 13 vault-token pool seeding, and Stage 16 Protocol DETF seeding):
  - TTA, TTB, TTC ≈ `6 × 10 000e18 + 4 × 10 000e18 + 2 × (assorted seeding constants)` (~hundreds of thousands of tokens).
  - DemoWETH = `INITIAL_PROTOCOL_WETH_DEPOSIT` (10 ether).
  - RICH bridge amount derived from Stage 16 RICH deposit + RICHIR bond bootstrap.

## 2. Ethereum Sepolia — `public_sepolia/ethereum/Script_DeployAll.s.sol`

Top-level orchestrator. Sets `OUT_DIR_OVERRIDE` and `NETWORK_PROFILE=ethereum_sepolia` in `vm.setEnv` then runs the stages below in this exact order. Stage 16 is gated by `PUBLIC_SEPOLIA_SKIP_STAGE16` (wrapper sets it `true` for the first pass, then runs `Script_16_DeployProtocolDETF` separately after Stage 24 bridge infra exists).

Stage source files come from `anvil_sepolia/` except the two non-WETH overrides and Stage 16, which live in `public_sepolia/ethereum/`.

### Stage 01 — `Script_01_DeployFactories`

Source: `anvil_sepolia/Script_01_DeployFactories.s.sol`

- Deploys via `InitDevService.initEnv(owner)`:
  - `Create3FactoryProxy` (Crane CREATE3 factory diamond)
  - `DiamondPackageCallBackFactory` (Crane Diamond Package factory)
- **Out:** `01_factories.json`
- **Keys:** `create3Factory`, `diamondPackageFactory`, `owner`, `deployer`

### Stage 02 — `Script_02_DeploySharedFacets`

Source: `anvil_sepolia/Script_02_DeploySharedFacets.s.sol`

Deploys reusable facets via the CREATE3 factory:

- `ERC20Facet`
- `ERC2612Facet`
- `ERCC5267Facet` (typo preserved in Crane API)
- `ERC4626Facet`
- `ERC4626BasedBasicVaultFacet`
- `ERC4626StandardVaultFacet`
- `MultiStepOwnableFacet`
- `OperableFacet`
- `DiamondCutFacet`

**Out:** `02_shared_facets.json`

### Stage 03 — `Script_03_DeployCoreProxies`

Source: `anvil_sepolia/Script_03_DeployCoreProxies.s.sol`

Deploys core platform proxies:

- `FeeCollector` (Diamond)
  - Facets: `FeeCollectorManagerFacet`, `FeeCollectorSingleTokenPushFacet`
  - Built via `FeeCollectorDFPkg`
- `IndexedexManager` (Diamond)
  - Facets: `VaultFeeOracleQueryFacet`, `VaultFeeOracleManagerFacet`, `OperableFacet`, `VaultRegistryDeploymentFacet`, `VaultRegistryVaultManagerFacet`, `VaultRegistryVaultPackageManagerFacet`, `VaultRegistryVaultPackageQueryFacet`, `VaultRegistryVaultQueryFacet`
  - Built via `IndexedexManagerDFPkg`

**Out:** `03_core_proxies.json`
**Keys:** include `feeCollector`, `indexedexManager`, and the individual facet addresses.

### Stage 04 — `Script_04_DeployDEXPackages_BalancerV3`

Source: `anvil_sepolia/Script_04_DeployDEXPackages_BalancerV3.s.sol`

Sepolia-flavoured Balancer V3 DEX package deployment:

- `BalancerV3StandardExchangeRouterDFPkg` package
  - Wraps facets: `SenderGuardFacet`, `ExactInQueryFacet`, `ExactInSwapFacet`, `ExactOutQueryFacet`, `ExactOutSwapFacet`, `BatchRouterExactInFacet`, `BatchRouterExactOutFacet`, `PrepayFacet`, `PrepayHooksFacet`, `Permit2WitnessFacet`
- `BalancerV3StandardExchangeRouter` proxy (a diamond built from the package above)
- `StandardExchangeRateProviderDFPkg` package + `StandardExchangeRateProviderFacet`
- `BalancerV3ConstantProductPoolDFPkg` package + facets:
  - `BalancerV3VaultAwareFacet`, `MultiAssetBasicVaultFacet`, `MultiAssetStandardVaultFacet`, `BalancerV3PoolTokenFacet`, `BalancerV3AuthenticationFacet`, `BalancerV3ConstantProductPoolFacet`, `DefaultPoolInfoFacet`, `StandardSwapFeePercentageBoundsFacet`, `UnbalancedLiquidityInvariantRatioBoundsFacet`

**Out:** `04_balancer_v3.json`
**Reads:** Sepolia Balancer V3 Vault + Router addresses bound by the base contract.

### Stage 05 — `Script_05_DeployUniswapV2`

Source: `anvil_sepolia/Script_05_DeployUniswapV2.s.sol`

Sepolia ships its own Uniswap V2 stack so Sepolia WETH does not have to match the upstream public Uniswap V2 router:

- `UniV2Factory(owner)` (raw contract `new`)
- `UniV2Router02(factory, weth)` (raw contract `new`, uses Balancer's WETH9 for consistency)
- `UniswapV2StandardExchangeDFPkg` package wrapping:
  - `UniswapV2StandardExchangeInFacet`
  - `UniswapV2StandardExchangeOutFacet`

**Out:** `05_uniswap_v2.json`

### Stage 07 — `Script_07_DeployTestTokens`

Source: `anvil_sepolia/Script_07_DeployTestTokens.s.sol`

Mints the canonical Sepolia demo token set:

- `TTA` — `Test Token A`, 18 decimals, mintable via `ERC20MintBurnOwnableOperableDFPkg`
- `TTB` — `Test Token B`, 18 decimals
- `TTC` — `Test Token C`, 18 decimals
- `DemoWETH` — `DemoWETH`, 18 decimals, mintable via the same DFPkg
- `RICH` — fixed-supply 1 000 000 000 × 1e18 via `ERC20PermitDFPkg`
- `ERC20MinterFacade` (Diamond facade that wraps minting authority for the four mintable tokens)
  - Stage explicitly calls `IOperable.setOperatorFor(IERC20MintBurn.mint.selector, erc20MinterFacade, true)` on TTA/TTB/TTC/DemoWETH so the facade can mint on demand for liquidity seeding stages.

**Out:** `07_test_tokens.json`
**Keys:** `testTokenA`, `testTokenB`, `testTokenC`, `demoWeth`, `richToken`, `erc20MinterFacade`

### Public-Sepolia Ethereum override — `Script_04_NonWethUniV2PoolsAndVaults`

Source: `public_sepolia/ethereum/Script_04_NonWethUniV2PoolsAndVaults.s.sol` (overrides the anvil stages 8 + 9 for the Sepolia public path; emits the same filenames so downstream stages can read them transparently).

- `abPool`, `acPool`, `bcPool` — Uniswap V2 pools for (TTA,TTB), (TTA,TTC), (TTB,TTC) via the Sepolia-local UniV2 factory
- `abVault`, `acVault`, `bcVault` — standard-exchange ERC4626 vaults over those pools via `UniswapV2StandardExchangeDFPkg.deployVault(pool)`

**Out:** `08_pools.json`, `09_strategy_vaults.json`

### Public-Sepolia Ethereum override — `Script_05_NonWethBalancerPools`

Source: `public_sepolia/ethereum/Script_05_NonWethBalancerPools.s.sol`

- `StandardExchangeRateProvider` rate-providers for the UniV2 pool/vault pairs (`uniAbRpA`, `uniAbRpB`, `uniAcRpA`, `uniAcRpC`, `uniBcRpB`, `uniBcRpC`).
- Token-only Balancer V3 constant-product pools: `balancerAbPool`, `balancerAcPool`, `balancerBcPool` (cfg: two `TokenConfig`s, no rate providers).
- Vault-token Balancer V3 const-prod pools (Vault token + matching underlying with a rate provider):
  - `balUniAbWithA`, `balUniAbWithB`
  - `balUniAcWithA`, `balUniAcWithC`
  - `balUniBcWithB`, `balUniBcWithC`

**Out:** `11_standard_exchange_rate_providers.json`, `12_balancer_const_prod_vault_token_pools.json`

### Stage 14 — `Script_14_DeployERC4626PermitVaults`

Source: `anvil_sepolia/Script_14_DeployERC4626PermitVaults.s.sol`

- `erc4626VaultTTA`, `erc4626VaultTTB`, `erc4626VaultTTC` — `ERC4626PermitDFPkg` standalone vaults over each test token.
- **Out:** `14_erc4626_permit_vaults.json`

### Stage 15 — `Script_15_DeploySeigniorageDETFS`

Source: `anvil_sepolia/Script_15_DeploySeigniorageDETFS.s.sol`

- `SeigniorageDETFExchangeInFacet`, `SeigniorageDETFExchangeOutFacet`, `SeigniorageDETFUnderwritingFacet`, `SeigniorageNFTVaultFacet`.
- `SeigniorageNFTVaultDFPkg` package + materialised NFT vault.
- `SeigniorageDETFDFPkg` package + Seigniorage DETF vault deployed via `vaultRegistry.deployVault(...)`.
- **Out:** `15_seigniorage_detfs.json`

### Stage 16 — `Script_16_DeployProtocolDETF` (Ethereum override)

Source: `public_sepolia/ethereum/Script_16_DeployProtocolDETF.s.sol` (extends `anvil_sepolia/Script_16_DeployProtocolDETF`).

Deploys the **Ethereum-side Protocol DETF graph**:

- `ProtocolNFTVaultDFPkg` package + Protocol NFT Vault
- `RICHIRDFPkg` package + `RICHIR` debt token
- `UniswapV4StandardExchangeDFPkg` package + WETH/RICH Uniswap V4 standard-exchange vault
- `SingleVaultDetfDFPkg` package + `protocolDetf` (single-vault DETF, aka CHIR)
- `chirWethVault` — the WETH-side Uniswap V4 vault associated with the CHIR DETF
- `ProtocolDETFSuperchainBridgeRepo` — repo facet read by Script_25 when wiring the cross-chain DETF bridge

It also seeds the initial WETH/RICH Uniswap V4 liquidity via `SingleVaultDetfUniswapV4LiquiditySeeder` (deposit constants `INITIAL_DEMO_WETH_DEPOSIT = 10e18`, `INITIAL_RICH_DEPOSIT = 10e18`, fee 3000, tick spacing 60, width multiplier 60).

- **Out:** `16_protocol_detf.json`
- **Reads:** `01_factories.json`, `03_core_proxies.json`, `07_test_tokens.json`, `15_seigniorage_detfs.json`, plus Stage 24 bridge infra (`24_superchain_bridge.json`) when present.

### Tokenlist export — `Script_ExportTokenlists`

Source: `public_sepolia/ethereum/Script_ExportTokenlists.s.sol`

Writes per-DEX tokenlist files:

- `public_sepolia-tokens.tokenlist.json`
- `public_sepolia-uniV2pool.tokenlist.json`
- `public_sepolia-aerodrome-pools.tokenlist.json` (empty on Ethereum Sepolia — no Aerodrome there)
- `public_sepolia-balancerv3-pools.tokenlist.json`
- `public_sepolia-balancerv3-constprod-pools.tokenlist.json`
- `public_sepolia-balancerv3-vault-token-pools.tokenlist.json`
- `public_sepolia-strategy-vaults.tokenlist.json`
- `public_sepolia-aerodrome-strategy-vaults.tokenlist.json` (empty)
- `public_sepolia-erc4626.tokenlist.json`
- `public_sepolia-seigniorage-detfs.tokenlist.json`
- `public_sepolia-protocol-detf.tokenlist.json`

## 3. Cross-chain bridging (between Ethereum core deploy and Base core deploy)

### 3.1 `public_sepolia/base/Script_05_CreateBridgeTokens`

Source: `public_sepolia/base/Script_05_CreateBridgeTokens.s.sol`

On **Base Sepolia**:

- Calls `BASE_SEPOLIA.OPTIMISM_MINTABLE_ERC20_FACTORY.createOptimismMintableERC20(remoteToken, name, symbol)` for each L1 token, applying `BridgeTokenPlanning` suffixes.
- Produces L2 wrappers for `TTA.base`, `TTB.base`, `TTC.base`, `DemoWETH.base`, `RICH.base`.

**Out:**

- `${baseOutDir}/05_bridge_tokens.json` — keys: `testTokenA`, `testTokenB`, `testTokenC`, `demoWeth`, `richToken` (each pointing at the L2 wrapper address).
- `${sharedOutDir}/bridge_token_manifest.json` — manifest used by the bridging script to map L1 source → L2 wrapper.

This is the Base-side prerequisite for the Stage 17 L1→L2 bridge call below.

### 3.2 `public_sepolia/ethereum/Script_17_BridgeTokensToBase`

Source: `public_sepolia/ethereum/Script_17_BridgeTokensToBase.s.sol`

On **Ethereum Sepolia**:

- Loads `07_test_tokens.json` and the shared `bridge_token_manifest.json`.
- For TTA/TTB/TTC/DemoWETH: mints via `IERC20MinterFacade` (mint into deployer), approves the L1 Standard Bridge `0xfd0Bf71F60660E2f608ed56e1659C450eB113120`, and calls `IStandardBridge.bridgeERC20To(...)` to send the planned `bridgeAmountTokenX()` amount to the deployer on Base.
- For RICH: transfers the fixed-supply token (no mint).
- Writes `${sharedOutDir}/bridge_execution_plan.json` capturing what was sent so the local SuperSim helper `finalize_bridge_tokens_on_base.sh` can replay the L2 finalize side if the local Anvil fork crashes.

## 4. Base Sepolia — `public_sepolia/base/Script_DeployAll.s.sol`

Top-level orchestrator. Sets `OUT_DIR_OVERRIDE` and `NETWORK_PROFILE=base_sepolia`, then runs the stages below in order. Stage 16 again gated by `PUBLIC_SEPOLIA_SKIP_STAGE16`.

Stage source files come from `anvil_base_main/` for the canonical stages, `supersim/base/` for the protocol cores (since Base Sepolia does not have mainnet UniV2 / Balancer V3 / Aerodrome deployed at the same addresses), and `public_sepolia/base/` for the bridged-token / Protocol DETF specialisations.

### Stage 01 — `Script_01_DeployFactories`

Source: `anvil_base_main/Script_01_DeployFactories.s.sol`

- Same shape as the Ethereum side: `Create3FactoryProxy` and `DiamondPackageCallBackFactory` via `InitDevService.initEnv(owner)`.
- **Out:** `01_factories.json`

### Stage 02 — `Script_02_DeploySharedFacets`

Source: `anvil_base_main/Script_02_DeploySharedFacets.s.sol`

Shared facets — same set as Ethereum Sepolia.

**Out:** `02_shared_facets.json`

### Stage 03 — `Script_03_DeployCoreProxies`

Source: `anvil_base_main/Script_03_DeployCoreProxies.s.sol`

- `FeeCollector` Diamond + facets (`FeeCollectorManagerFacet`, `FeeCollectorSingleTokenPushFacet`).
- `IndexedexManager` Diamond + facets (`VaultFeeOracleQueryFacet`, `VaultFeeOracleManagerFacet`, `OperableFacet`, `VaultRegistryDeploymentFacet`, `VaultRegistryVaultManagerFacet`, `VaultRegistryVaultPackageManagerFacet`, `VaultRegistryVaultPackageQueryFacet`, `VaultRegistryVaultQueryFacet`).
- **Out:** `03_core_proxies.json`

### Stage 03A — `Script_03A_DeployUniswapV2Core`

Source: `supersim/base/Script_03A_DeployUniswapV2Core.s.sol`

- `UniV2Factory(owner)` (raw `new`)
- `UniV2Router02(factory, weth)` (raw `new`, uses Base Sepolia WETH9)
- **Out:** `03a_uniswap_v2_core.json`
- **Keys:** `uniswapV2Factory`, `uniswapV2Router`, `weth`

Subsequent stages will see this artifact and rebind `uniswapV2Factory` / `uniswapV2Router` via `anvil_base_main/DeploymentBase._boundUniswapV2*()`.

### Stage 03B — `Script_03B_DeployBalancerV3Core`

Source: `supersim/base/Script_03B_DeployBalancerV3Core.s.sol`

Deploys a local Balancer V3 protocol core, since Base Sepolia does not have one at the expected mainnet address:

- `BalancerV3Authorizer` (raw `new` via Crane factory service `_deployCreate3`)
- `BalancerV3ProtocolFeeController` — currently set to `address(0)` in this script (placeholder; pool factories that rely on it will still function for the demo path)
- `BalancerV3Vault` — built by deploying every Balancer V3 vault facet (`VaultMainTransientFacet`, `VaultSwapFacet`, `VaultLiquidityFacet`, `VaultBufferFacet`, `VaultPoolTokenFacet`, `VaultQueryFacet`, `VaultRegistrationFacet`, `VaultAdminFacet`, `VaultRecoveryFacet`) and assembling the diamond via the Balancer V3 Vault package
- `BalancerV3VaultAdmin` and `BalancerV3VaultExtension` are aliased to the Vault address (they are facets of the same Vault diamond in this build).
- `BalancerV3Router`, `BalancerV3BatchRouter`, `BalancerV3BufferRouter`, `BalancerV3CompositeLiquidityRouter` — built from the Balancer V3 router package by deploying `RouterSwapFacet`, `RouterAddLiquidityFacet`, `RouterRemoveLiquidityFacet`, `RouterInitializeFacet`, `RouterCommonFacet`, `BatchSwapFacet`, `BufferRouterFacet`, `CompositeLiquidityERC4626Facet`, `CompositeLiquidityNestedFacet`
- **Out:** `03b_balancer_v3_core.json`
- **Keys:** `balancerV3Authorizer`, `balancerV3ProtocolFeeController`, `balancerV3VaultAdmin`, `balancerV3VaultExtension`, `balancerV3Vault`, `balancerV3Router`, `balancerV3BatchRouter`, `balancerV3BufferRouter`, `balancerV3CompositeLiquidityRouter`

### Stage 03C — `Script_03C_DeployAerodromeCore`

Source: `supersim/base/Script_03C_DeployAerodromeCore.s.sol`

- `AerodromePool` implementation
- `AerodromePoolFactory(implementation)`
- `AerodromeFactoryRegistry(... approves the pool factory ...)`
- `AerodromeRouter(factoryRegistry, weth, ...)`
- **Out:** `03c_aerodrome_core.json`
- **Keys:** `aerodromePoolImplementation`, `aerodromeFactory`, `aerodromeFactoryRegistry`, `aerodromeRouter`

### Stage 04 — `Script_04_DeployDEXPackages`

Source: `anvil_base_main/Script_04_DeployDEXPackages.s.sol`

Single combined package deploy for Base:

- `UniswapV2StandardExchangeDFPkg` (`uniV2Pkg`)
- `AerodromeStandardExchangeDFPkg` (`aerodromePkg`)
- `CamelotV2StandardExchangeDFPkg` (`camelotPkg`)
  - Note: Camelot is not used by the public Sepolia path, but the package is still deployed for parity with the Base mainnet path.
- `BalancerV3StandardExchangeRouterDFPkg` (`balRouterPkg`) + `BalancerV3StandardExchangeRouter` materialised instance (`balRouter`)
- `StandardExchangeRateProviderDFPkg` (`rateProviderPkg`)
- `BalancerV3ConstantProductPoolDFPkg` (`balancerV3ConstProdPoolPkg`)
- **Out:** `04_dex_packages.json`

### Stage 05 — `Script_05_DeployTestTokens` (Base override)

Source: `public_sepolia/base/Script_05_DeployTestTokens.s.sol`

Reads the **bridge wrapper addresses** from `05_bridge_tokens.json` (written by `Script_05_CreateBridgeTokens` earlier in the wrapper). Validates each wrapper has code, then writes a slim manifest under the canonical Stage-5 filename so downstream stages can read tokens by the same key.

- **Out:** `05_test_tokens.json`
- **Keys:** `testTokenA`, `testTokenB`, `testTokenC`, `demoWeth`, `richToken`
- **Reads:** `05_bridge_tokens.json`

In particular this is **not** the same as the anvil_base_main Stage 5 (which would mint local TTA/TTB/TTC).

### Stage 06 — `Script_06_DeployPools`

Source: `anvil_base_main/Script_06_DeployPools.s.sol`

- `abPool` (UniV2 TTA/TTB), `acPool` (UniV2 TTA/TTC), `bcPool` (UniV2 TTB/TTC)
- `aeroAbPool`, `aeroAcPool`, `aeroBcPool` — Aerodrome volatile (non-stable) pools for the same pairs via `aerodromePoolFactory.createPool(tokenA, tokenB, false)`
- **Out:** `06_pools.json`

### Stage 07 — `Script_07_DeployStrategyVaults`

Source: `anvil_base_main/Script_07_DeployStrategyVaults.s.sol`

- `abVault`, `acVault`, `bcVault` — UniV2 standard-exchange vaults wrapping the corresponding Stage 06 UniV2 pools.
- **Out:** `07_strategy_vaults.json`

### Stage 08 — `Script_08_DeployAerodromeStrategyVaults`

Source: `anvil_base_main/Script_08_DeployAerodromeStrategyVaults.s.sol`

- `aeroAbVault`, `aeroAcVault`, `aeroBcVault` — Aerodrome standard-exchange vaults wrapping the Stage 06 Aerodrome pools.
- **Out:** `08_aerodrome_strategy_vaults.json`

### Stage 09 — `Script_09_DeployBalancerConstProdPools`

Source: `anvil_base_main/Script_09_DeployBalancerConstProdPools.s.sol`

- `balAbPool`, `balAcPool`, `balBcPool` — Balancer V3 constant-product pools for (TTA,TTB), (TTA,TTC), (TTB,TTC) deployed via the `BalancerV3ConstantProductPoolDFPkg.deployVault(cfg, address(0))` flow.
- **Out:** `09_balancer_const_prod_pools.json`

### Stage 10 — `Script_10_DepositBaseLiquidity` (Base override)

Source: `public_sepolia/base/Script_10_DepositBaseLiquidity.s.sol`

Approves and seeds initial liquidity into every Stage 6/9 pool. On the Base Sepolia path the tokens come from the bridged wrappers (no minting on Base), so the deployer must already hold the bridged balance from `Script_17_BridgeTokensToBase`.

- Effects:
  - Approves Uniswap V2 router, Aerodrome router, Balancer V3 Vault, and Permit2 for TTA/TTB/TTC.
  - Calls Permit2 `approve(token, balancerV3Router, max, maxExpiry)` so the Balancer router can pull tokens under Permit2.
  - Adds liquidity into all nine pools using `INITIAL_LIQUIDITY = 10_000e18` per side (with `UNBALANCED_RATIO_B / _C` for the unbalanced seeding paths).
- **Out:** `10_base_liquidity.json`

### Stage 11 — `Script_11_DeployStandardExchangeRateProviders`

Source: `anvil_base_main/Script_11_DeployStandardExchangeRateProviders.s.sol`

Deploys a `StandardExchangeRateProvider` Diamond for every (vault, peer token) combination used in Stage 12 vault-token pools:

- UniV2: `uniAbRpA`, `uniAbRpB`, `uniAcRpA`, `uniAcRpC`, `uniBcRpB`, `uniBcRpC`
- Aerodrome: `aeroAbRpA`, `aeroAbRpB`, `aeroAcRpA`, `aeroAcRpC`, `aeroBcRpB`, `aeroBcRpC`
- **Out:** `11_standard_exchange_rate_providers.json`

### Stage 12 — `Script_12_DeployBalancerConstProdVaultTokenPools`

Source: `anvil_base_main/Script_12_DeployBalancerConstProdVaultTokenPools.s.sol`

Deploys Balancer V3 const-product pools pairing **vault shares with underlying tokens**:

- UniV2 vault + TTA/TTB/TTC: `balUniAbWithA`, `balUniAbWithB`, `balUniAcWithA`, `balUniAcWithC`, `balUniBcWithB`, `balUniBcWithC`
- Aerodrome vault + TTA/TTB/TTC: `balAeroAbWithA`, `balAeroAbWithB`, `balAeroAcWithA`, `balAeroAcWithC`, `balAeroBcWithB`, `balAeroBcWithC`

Each pool is two `TokenConfig`s: one for the underlying token with `TokenType.STANDARD`, one for the vault token with `TokenType.WITH_RATE` plus the matching rate provider.

- **Out:** `12_balancer_const_prod_vault_token_pools.json`

### Stage 13 — `Script_13_SeedBalancerVaultTokenPoolLiquidity` (Base override)

Source: `public_sepolia/base/Script_13_SeedBalancerVaultTokenPoolLiquidity.s.sol`

Seeds every Stage 12 vault-token pool, using `INITIAL_UNDERLYING = 10_000e18` per side and `VAULT_ASSET_DEPOSIT = 30_000e18` for the per-vault asset side. Requires the deployer to hold bridged TTA/TTB/TTC and to have vault shares minted from prior steps.

- **Out:** `13_balancer_vault_token_pool_liquidity.json`

### Stage 14 — `Script_14_DeployERC4626PermitVaults`

Source: `anvil_base_main/Script_14_DeployERC4626PermitVaults.s.sol`

- `erc4626VaultTTA`, `erc4626VaultTTB`, `erc4626VaultTTC` — ERC4626Permit vaults over each test token.
- **Out:** `14_erc4626_permit_vaults.json`

### Stage 15 — `Script_15_DeploySeigniorageDETFS`

Source: `anvil_base_main/Script_15_DeploySeigniorageDETFS.s.sol`

Same Seigniorage DETF package set as the Ethereum Sepolia stage but registering Base-side pools and vaults.

- **Out:** `15_seigniorage_detfs.json`

### Stage 16 — `Script_16_DeployProtocolDETF` (Base override)

Source: `public_sepolia/base/Script_16_DeployProtocolDETF.s.sol`

Deploys the **Base-side Protocol DETF graph**, deliberately omitting the WETH funding step (the Ethereum side owns that):

- `ProtocolNFTVaultDFPkg` package + Protocol NFT Vault
- `RICHIRDFPkg` package + RICHIR debt token
- `SingleVaultDetfDFPkg` package + `protocolDetf` (CHIR)
- `reservePool` — the reserve pool referenced by the Protocol DETF for the Base chain
- **Out:** `16_protocol_detf.json`
- **Reads:** Stage 24 bridge infra (`24_superchain_bridge.json`) when present.

### Tokenlist export — `Script_ExportTokenlists` (Base override)

Source: `public_sepolia/base/Script_ExportTokenlists.s.sol`

Writes the Base-side equivalents of the Ethereum tokenlist files, including the Aerodrome lists which actually populate on Base.

## 5. Superchain bridge bootstrap (after both core deploys)

These three scripts live under `scripts/foundry/supersim/` but are reused verbatim by the public Sepolia wrapper after both chains have core deployments and bridged balances.

### 5.1 `Script_24_DeploySuperchainBridgeInfra`

Source: `scripts/foundry/supersim/Script_24_DeploySuperchainBridgeInfra.s.sol`

Per chain, deploys the Superchain bridge support diamonds:

- `SuperChainBridgeTokenRegistry` — built from `SuperChainBridgeTokenRegistryFacet` + `SuperChainBridgeTokenRegistryDFPkg`
- `ApprovedMessageSenderRegistry` — built from `ApprovedMessageSenderRegistryFacet` + `ApprovedMessageSenderRegistryDFPkg`
- `TokenTransferRelayer` — built from `TokenTransferRelayerFacet` + `TokenTransferRelayerDFPkg`, bound to the local `ApprovedMessageSenderRegistry`
- **Out:** `24_superchain_bridge.json`
- **Keys:** `bridgeTokenRegistry`, `approvedMessageSenderRegistry`, `tokenTransferRelayer`

Must be run **once per chain** (Ethereum Sepolia and Base Sepolia) and write to the chain-specific output directory.

### 5.2 `Script_25_ConfigureProtocolDetfBridge`

Source: `scripts/foundry/supersim/Script_25_ConfigureProtocolDetfBridge.s.sol`

On each chain, configures the local bridge graph to point at the peer chain (`REMOTE_OUT_DIR` env var tells the script where to read the peer's `24_superchain_bridge.json` and `16_protocol_detf.json`):

- `bridgeTokenRegistry.setRemoteToken(localRichir, remoteRichir, peerChainId)`
- `bridgeTokenRegistry.setRemoteToken(localProtocolDetf, remoteProtocolDetf, peerChainId)`
- `approvedRegistry.approveSender(localProtocolDetf, remoteProtocolDetf)` — authorises the peer DETF to send cross-chain messages to this DETF.
- **Out:** `25_superchain_bridge_config.json`
- **Keys:** `bridgeTokenRegistry`, `approvedMessageSenderRegistry`, `localRelayer`, `peerRelayer`, `protocolDetf`, `peerProtocolDetf`

Must be run **once per chain**.

### 5.3 `Script_26_TestProtocolDetfReserveBridge`

Source: `scripts/foundry/supersim/Script_26_TestProtocolDetfReserveBridge.s.sol`

Exercise-only script. It does not deploy contracts; it bootstraps RICHIR from RICH on the source chain, then runs a reserve-bridge transaction through the configured DETF + relayer + bridge registry path, simulates the L2-side relay, and verifies post-bridge balances. Writes a per-run bridge test manifest.

This stage is included in the SuperSim wrapper but the public Sepolia wrapper currently does not run it on real Sepolia.

## 6. Cross-references — every artifact and what produces it

Per chain, expected files inside `$PUBLIC_SEPOLIA_<CHAIN>_OUT_DIR` after a clean wrapper run:

| File | Producer | Chains |
| --- | --- | --- |
| `01_factories.json` | `Script_01_DeployFactories` | both |
| `02_shared_facets.json` | `Script_02_DeploySharedFacets` | both |
| `03_core_proxies.json` | `Script_03_DeployCoreProxies` | both |
| `03a_uniswap_v2_core.json` | `supersim/base/Script_03A_DeployUniswapV2Core` | Base only |
| `03b_balancer_v3_core.json` | `supersim/base/Script_03B_DeployBalancerV3Core` | Base only |
| `03c_aerodrome_core.json` | `supersim/base/Script_03C_DeployAerodromeCore` | Base only |
| `04_balancer_v3.json` | `anvil_sepolia/Script_04_DeployDEXPackages_BalancerV3` | Ethereum |
| `04_dex_packages.json` | `anvil_base_main/Script_04_DeployDEXPackages` | Base |
| `05_uniswap_v2.json` | `anvil_sepolia/Script_05_DeployUniswapV2` | Ethereum |
| `05_bridge_tokens.json` | `public_sepolia/base/Script_05_CreateBridgeTokens` | Base |
| `05_test_tokens.json` | `public_sepolia/base/Script_05_DeployTestTokens` (Base) | Base |
| `07_test_tokens.json` | `anvil_sepolia/Script_07_DeployTestTokens` | Ethereum |
| `06_pools.json` | `anvil_base_main/Script_06_DeployPools` | Base |
| `07_strategy_vaults.json` | `anvil_base_main/Script_07_DeployStrategyVaults` | Base |
| `08_pools.json` | `public_sepolia/ethereum/Script_04_NonWethUniV2PoolsAndVaults` | Ethereum |
| `08_aerodrome_strategy_vaults.json` | `anvil_base_main/Script_08_DeployAerodromeStrategyVaults` | Base |
| `09_strategy_vaults.json` | `public_sepolia/ethereum/Script_04_NonWethUniV2PoolsAndVaults` | Ethereum |
| `09_balancer_const_prod_pools.json` | `anvil_base_main/Script_09_DeployBalancerConstProdPools` | Base |
| `10_base_liquidity.json` | `public_sepolia/base/Script_10_DepositBaseLiquidity` | Base |
| `11_standard_exchange_rate_providers.json` | Ethereum: `public_sepolia/ethereum/Script_05_NonWethBalancerPools`; Base: `anvil_base_main/Script_11_*` | both |
| `12_balancer_const_prod_vault_token_pools.json` | Ethereum: `public_sepolia/ethereum/Script_05_NonWethBalancerPools`; Base: `anvil_base_main/Script_12_*` | both |
| `13_balancer_vault_token_pool_liquidity.json` | `public_sepolia/base/Script_13_SeedBalancerVaultTokenPoolLiquidity` | Base |
| `14_erc4626_permit_vaults.json` | `Script_14_DeployERC4626PermitVaults` | both |
| `15_seigniorage_detfs.json` | `Script_15_DeploySeigniorageDETFS` | both |
| `16_protocol_detf.json` | `public_sepolia/{ethereum,base}/Script_16_DeployProtocolDETF` | both |
| `24_superchain_bridge.json` | `supersim/Script_24_DeploySuperchainBridgeInfra` | both |
| `25_superchain_bridge_config.json` | `supersim/Script_25_ConfigureProtocolDetfBridge` | both |
| `deployment_summary.json` | wrapper python merger | both |
| `public_sepolia-*.tokenlist.json` | `Script_ExportTokenlists` | both |

And in `$PUBLIC_SEPOLIA_SHARED_OUT_DIR`:

| File | Producer |
| --- | --- |
| `bridge_token_manifest.json` | `Script_05_CreateBridgeTokens` |
| `bridge_execution_plan.json` | `Script_17_BridgeTokensToBase` |

## 7. WETH/TTC extension (anvil_base_main only — not in public Sepolia path today)

For completeness, `anvil_base_main/` defines Stages 17 → 23 that extend the demo with WETH/TTC pools, vaults, rate providers, vault-token pools, and a vault-vault pool. The public Sepolia wrapper does **not** run these. They are listed here so future enablement is grounded in concrete addresses, not guesswork:

- Stage 17 `Script_17_DeployWethTtcPools` — UniV2 WETH/TTC pool (`uniWethcPool`), Aerodrome WETH/TTC pool (`aeroWethcPool`), Balancer V3 const-prod WETH/TTC pool (`balancerWethcPool`). **Out:** `17_weth_ttc_pools.json`.
- Stage 18 `Script_18_DeployWethTtcVaults` — `uniWethcVault`, `aeroWethcVault`. **Out:** `18_weth_ttc_vaults.json`.
- Stage 19 `Script_19_SeedWethTtcBaseLiquidity` — seeds Stage 17 pools. **Out:** `19_weth_ttc_base_liquidity.json`.
- Stage 20 `Script_20_DeployWethTtcRateProvidersAndBalancerVaultTokenPools` — WETH/TTC rate providers and corresponding Balancer vault-token pools (`balUniWethcWithWeth`, `balUniWethcWithC`, `balAeroWethcWithWeth`, `balAeroWethcWithC`). **Out:** `20_weth_ttc_balancer_vault_token_pools.json`.
- Stage 21 `Script_21_SeedWethTtcBalancerVaultTokenPoolLiquidity` — seeds Stage 20 pools. **Out:** `21_weth_ttc_balancer_vault_token_pool_liquidity.json`.
- Stage 22 `Script_22_DeployWethTtcVaultVaultPool` — Balancer V3 vault-vault pools (`balancerAbVaultVaultPool`, `balancerAcVaultVaultPool`, `balancerBcVaultVaultPool`, `balancerWethcVaultVaultPool`) plus the matching rate providers. **Out:** `22_weth_ttc_vault_vault_pool.json`.
- Stage 23 `Script_23_SeedWethTtcVaultVaultPoolLiquidity` — seeds Stage 22 pools. **Out:** `23_weth_ttc_vault_vault_pool_liquidity.json`.

## 8. Standalone scripts that ship with this tree but are not in the public Sepolia path

- `scripts/foundry/base_main/Script_BaseMain_DeployIndexedex.s.sol` — Base mainnet core stack: ownership/diamond facets, FeeCollector, IndexedexManager, operator config, Aerodrome standard exchange package, Balancer V3 standard exchange router package, Balancer router proxy. Assumes Crane factories already exist on Base mainnet.
- `scripts/foundry/ethereum_main/Script_DeployRichToken.s.sol` — mainnet `RICH` token. Initialises local Crane factories, deploys ERC20/ERC2612/ERC5267 facets, deploys `ERC20PermitDFPkg`, deploys the `RICH` token proxy/instance. Writes JSON deployment artifacts.
- `scripts/foundry/anvil_sepolia/deploy_sepolia.sh` — single-chain Sepolia demo (Stages 01–15). Skips Protocol DETF and WETH/TTC stages. **Not** part of the cross-chain public Sepolia flow.
- `scripts/foundry/anvil_base_main/deploy_all.sh` — full local Base mainnet fork pipeline (Stages 01–23) for local development against a Base fork.
- `scripts/foundry/supersim/deploy_mainnet_bridge_ui.sh` — local two-chain SuperSim pipeline. Drives the same stage library against forked Sepolia + Base Sepolia, including Stage 24/25/26 bridge bootstrap. Used for local rehearsal of the public Sepolia path (see `EXECUTION.md`).
- `scripts/foundry/sepolia/`, `scripts/foundry/local/`, `scripts/foundry/local/segmented/`, `scripts/foundry/local_testing/` — legacy or reserved. `sepolia/Script_DeploySepoliaEnvironment.s.sol` and `sepolia/{ethereum,base}/Script_DeployAll.s.sol` explicitly `revert("... reserved for the second implementation pass.")` and are not used.
