# Base Sepolia Public Deployment Plan

## Goal

Deploy the IndexedEx demo architecture to Base Sepolia using real bridged ERC20 wrappers created through the Optimism mintable ERC20 factory, while keeping Ethereum Sepolia as the L1 source of truth for token issuance and bridge initiation.

This flow is intentionally split into manual-checkpoint phases:

1. Deploy and export L1 source tokens plus L2 bridge-token wrappers.
2. Bridge working balances from Ethereum Sepolia to Base Sepolia.
3. Deploy the Base Sepolia demo architecture using the bridged tokens.

## Core Requirements

- Ethereum Sepolia remains the source chain for DemoWETH, RICH, and the mintable test tokens.
- Base Sepolia uses Optimism mintable ERC20 wrapper contracts created by the official factory.
- Base Sepolia bridge-token names and symbols must include a visible suffix so the wrapped demo assets are distinguishable from their L1 source tokens.
- The deployer manually verifies wrapper creation on Base Sepolia before bridging balances.
- The deployer manually verifies bridge completion before Base Sepolia architecture deployment.
- The Base Sepolia demo uses:
  - bridged DemoWETH for the Base Protocol DETF `wethToken` role
  - bridged RICH for the Base Protocol DETF `richToken` role
  - Base Sepolia canonical WETH where the broader environment expects canonical WETH
  - a full locally deployed Balancer V3 protocol stack on Base Sepolia
  - the same Sepolia-style Uniswap V2, Aerodrome V1, pool, vault, and DETF architecture replicated on Base Sepolia, but backed by bridged tokens

This final direction explicitly overrides the earlier idea of omitting Uniswap V2 from the Base Sepolia deployment.

## Existing Repo Anchors

### Ethereum public Sepolia flow

- `scripts/foundry/public_sepolia/ethereum/Script_DeployAll.s.sol`
- `scripts/foundry/public_sepolia/ethereum/Script_16_DeployProtocolDETF.s.sol`

### Base public Sepolia flow

- `scripts/foundry/public_sepolia/base/Script_DeployAll.s.sol`
- `scripts/foundry/public_sepolia/base/Script_16_DeployProtocolDETF.s.sol`

### Local Base patterns to mirror selectively

- `scripts/foundry/anvil_base_main/Script_05_DeployTestTokens.s.sol`
- `scripts/foundry/anvil_base_main/Script_06_DeployPools.s.sol`
- `scripts/foundry/anvil_base_main/Script_10_DepositBaseLiquidity.s.sol`
- `scripts/foundry/anvil_base_main/Script_16_DeployProtocolDETF.s.sol`

### Existing Superchain bridge-related utilities

- `scripts/foundry/supersim/Script_24_DeploySuperchainBridgeInfra.s.sol`
- `scripts/foundry/supersim/Script_25_ConfigureProtocolDetfBridge.s.sol`
- `scripts/foundry/supersim/Script_26_TestProtocolDetfReserveBridge.s.sol`

These are useful as structural references for manifests, chain-role separation, and bridge config flow, but this Base Sepolia deployment plan is not the same as the local SuperSim flow.

## Proposed Three-Phase Implementation

### Phase 1: L1 token bootstrap plus L2 wrapper creation

#### Objective

Produce all token contracts and manifests required before any live bridge deposits occur.

#### Ethereum Sepolia deliverables

Extend the existing Ethereum Sepolia token deployment stage so it is the canonical source of truth for:

- `testTokenA`
- `testTokenB`
- `testTokenC`
- `demoWeth`
- `richToken`
- `erc20MinterFacade`

The token semantics should remain:

- `testTokenA/B/C`: mintable via `ERC20MintBurnOwnableOperableDFPkg`
- `demoWeth`: mintable via `ERC20MintBurnOwnableOperableDFPkg`
- `richToken`: fixed-supply via `ERC20PermitDFPkg`

The Ethereum stage should also mint working balances to the deployer so the assets are ready for later bridging.

The wrapper metadata policy is:

- L2 bridge-token names must include a visible suffix.
- L2 bridge-token symbols must include a visible suffix.
- The exact suffix format should be applied consistently across bridged `TTA`, `TTB`, `TTC`, `DemoWETH`, and `RICH`.

The explicit wrapper suffix convention for this plan is:

- name suffix: ` (Base Sepolia)`
- symbol suffix: `.base`

Examples:

- `Test Token A` -> `Test Token A (Base Sepolia)`
- `TTA` -> `TTA.base`
- `DemoWETH` -> `DemoWETH (Base Sepolia)`
- `DemoWETH` symbol -> `DemoWETH.base`
- `RICH` -> `RICH (Base Sepolia)`
- `RICH` symbol -> `RICH.base`

#### Base Sepolia deliverables

Add a new Base Sepolia stage that creates Optimism mintable L2 wrappers for each L1 token via the Base Sepolia Optimism mintable factory.

Expected wrapper set:

- bridged `TTA`
- bridged `TTB`
- bridged `TTC`
- bridged `DemoWETH`
- bridged `RICH`

#### New artifacts

Create a shared manifest file describing the L1 to L2 token mapping. Suggested contents:

- L1 token address
- L2 bridge token address
- asset name
- asset symbol
- source chain ID
- destination chain ID
- L1 standard bridge address
- L2 mintable factory address

Suggested filenames:

- Ethereum artifact: `07_test_tokens.json`
- Base artifact: new bridge-token artifact such as `05_bridge_tokens.json`
- Shared artifact: `deployments/public_sepolia/shared/bridge_token_manifest.json`

#### Manual checkpoint

Before phase 2, manually verify on Base Sepolia Etherscan that the wrapper contracts exist and match the intended L1 remote tokens.

### Phase 2: L1-to-L2 bridge execution

#### Objective

Move the balances required for the Base Sepolia demo from Ethereum Sepolia to Base Sepolia.

#### New Ethereum Sepolia bridge script

Add a dedicated bridge-execution script that:

- reads the shared bridge token manifest
- approves the L1 standard bridge for each source token
- deposits token balances from Ethereum Sepolia to Base Sepolia
- exports the intended bridge amounts and tx metadata

#### Bridge amounts

Bridge:

- derived working balances for `TTA`
- derived working balances for `TTB`
- derived working balances for `TTC`
- derived working balances for `DemoWETH`
- half of the remaining `RICH` supply

The bridge script should derive the token amounts from downstream Base Sepolia liquidity and deployment requirements rather than relying on manually duplicated bridge constants.

The final derived amount table should still be exported explicitly so the bridge plan remains deterministic and auditable.

#### New artifact

Create a bridge execution artifact such as `deployments/public_sepolia/shared/bridge_execution_plan.json` containing:

- token symbol
- L1 token address
- L2 token address
- amount bridged
- recipient
- tx hash if broadcast

#### Manual checkpoint

Before phase 3, manually verify on Base Sepolia that the deployer received the bridged balances for each wrapper token.

### Phase 3: Base Sepolia architecture deployment using bridged assets

#### Objective

Deploy the full Base Sepolia demo environment using the same architecture as the Ethereum Sepolia deployment, but sourced from bridged L2 wrapper tokens instead of native locally deployed demo ERC20s.

#### Required refactor

The current Base public Sepolia scaffold still follows the local Base deployment shape. That is the main mismatch to fix.

Specifically:

- the current Base public flow imports `anvil_base_main` token deployment assumptions
- local liquidity stages assume direct `mint()` access on test tokens
- the current Base public DETF stage still deploys a fresh local `RICH`
- the current Base public flow does not yet mirror the full Sepolia exchange and vault topology

On real Base Sepolia, those assumptions are wrong for bridged tokens.

#### Base token handling changes

Replace the local token deployment stage in the Base public flow with a token-loader stage that reads the L2 bridged token addresses from the manifest instead of deploying new tokens.

That Base stage should export a familiar token artifact shape so later stages can stay close to the local Base script API.

The Base public flow should not deploy local substitute ERC20s for the bridge-backed demo assets.

#### Base liquidity changes

Fork or replace any Base public liquidity stage that currently does this:

- mint tokens directly to the deployer
- rely on owner/operator mint permissions on the token contract

Instead, those stages must:

- consume only the deployer balances that arrived via bridging
- approve routers/vaults only
- seed liquidity from existing balances

The current direction is to replicate the same Sepolia architecture on Base Sepolia, not to reduce or substitute it with an Aerodrome-only graph.

#### Base Protocol DETF changes

Refactor the Base public DETF stage so it:

- reads bridged `DemoWETH`
- reads bridged `RICH`
- uses bridged `DemoWETH` as the DETF `wethToken`
- uses bridged `RICH` as the DETF `richToken`
- does not deploy a fresh local `RICH`
- does not rely on direct token minting for initial funding

Canonical Base Sepolia WETH should still remain bound in the wider Base environment where canonical WETH is expected outside the DETF demo token-role override.

## Base Sepolia DEX Infrastructure Policy

Base Sepolia should not assume canonical external Balancer V3 addresses are already available for this deployment.

Instead:

- deploy the required Balancer V3 infrastructure from our in-repo Crane contracts under `lib/daosys/lib/crane/contracts/protocols/dexes/balancer/v3`
- reuse the same Sepolia-style DEX and vault deployment graph for Uniswap V2 and Aerodrome V1 that is already present in `scripts/foundry/sepolia`
- use repository tests as the reference source for any required Balancer V3 component deployment ordering and supporting contracts

This means the Base Sepolia public flow should be structured as a bridge-aware mirror of the Sepolia environment deployment, with the additional responsibility of deploying a full Balancer V3 protocol stack locally on Base Sepolia.

That mirrored Base Sepolia environment includes:

- locally deployed Uniswap V2 infrastructure
- locally deployed Aerodrome V1 infrastructure
- locally deployed Balancer V3 core infrastructure
- the same pool, vault, liquidity, rate-provider, and DETF stages used by the Sepolia environment
- bridged tokens substituted in place of locally minted demo ERC20 assets

## Detailed Balancer V3 Deployment Plan

The Balancer V3 portion should not be treated as a single opaque step. It should be implemented as a dedicated Base Sepolia core-infrastructure stage modeled on the existing local Base reference script:

- `scripts/foundry/supersim/base/Script_03B_DeployBalancerV3Core.s.sol`

The package composition and deployment ordering should also follow the Balancer package test bases and package contracts:

- `lib/daosys/lib/crane/contracts/protocols/dexes/balancer/v3/router/diamond/TestBase_BalancerV3Router.sol`
- `lib/daosys/lib/crane/contracts/protocols/dexes/balancer/v3/vault/diamond/BalancerV3VaultDFPkg.sol`
- `lib/daosys/lib/crane/contracts/protocols/dexes/balancer/v3/router/diamond/BalancerV3RouterDFPkg.sol`
- `contracts/protocols/dexes/balancer/v3/routers/TestBase_BalancerV3StandardExchangeRouter.sol`

That script already gives the expected component ordering, artifact shape, and minimal core contract set for a usable local Balancer V3 deployment.

### Balancer stage objective

Produce a full self-hosted Balancer V3 core stack on Base Sepolia that downstream IndexedEx scripts can bind to exactly as they currently bind to canonical Balancer deployments on Ethereum Sepolia.

### Balancer core components to deploy

The Base Sepolia Balancer V3 core stage should deploy and export at least:

- Balancer authorizer
- Balancer protocol fee controller
- Balancer vault admin
- Balancer vault extension
- Balancer vault
- Balancer router
- Balancer batch router
- Balancer buffer router
- Balancer composite liquidity router

The current local reference script collapses several of these roles onto the same deployed vault or router instance. That is acceptable for the first public Base Sepolia pass as long as the exported artifact shape remains explicit and stable.

### Balancer deployment order

The intended sequence is:

1. Load `create3Factory` and `diamondPackageFactory` from the earlier core deployment stages.
2. Bind Base Sepolia canonical `WETH9` and `Permit2`.
3. Deploy Balancer vault facets via CREATE3.
4. Deploy `BalancerV3VaultDFPkg` via CREATE3.
5. Deploy the Balancer authorizer.
6. Deploy the Balancer vault instance from the vault package.
7. Deploy Balancer router facets via CREATE3.
8. Deploy `BalancerV3RouterDFPkg` via CREATE3.
9. Deploy the Balancer router instance bound to the newly deployed vault, Base Sepolia WETH, and Permit2.
10. Export all Balancer core addresses to a dedicated artifact.

## Detailed Package-Based Deployment Instructions

The Base Sepolia Balancer V3 infrastructure should be deployed in three layers:

1. deploy Balancer core facets
2. deploy Balancer core packages
3. use those packages to deploy Balancer core infrastructure instances

This section describes each layer in the order it should be implemented.

### Layer 1: deploy Balancer vault facets

Deploy the vault facets first via CREATE3-backed facet deployment helpers or equivalent deterministic deployments.

Required vault facets:

- `VaultTransientFacet`
- `VaultSwapFacet`
- `VaultLiquidityFacet`
- `VaultBufferFacet`
- `VaultPoolTokenFacet`
- `VaultQueryFacet`
- `VaultRegistrationFacet`
- `VaultAdminFacet`
- `VaultRecoveryFacet`

The local Base reference script deploys these facets individually and then passes them into the vault package init struct.

The intended deployment pattern is:

1. derive a deterministic salt from the facet type name
2. deploy each facet via the CREATE3 factory
3. retain each deployed facet address for package construction

Representative pattern:

```solidity
IFacet vaultSwapFacet = _deployFacet(type(VaultSwapFacet).creationCode, type(VaultSwapFacet).name);
```

The plan should continue using deterministic CREATE3 deployment rather than `new` for the package-facing production script flow.

### Layer 2: deploy the Balancer vault package

Once the vault facets exist, assemble `IBalancerV3VaultDFPkg.PkgInit` with exactly these fields:

- `vaultTransientFacet`
- `vaultSwapFacet`
- `vaultLiquidityFacet`
- `vaultBufferFacet`
- `vaultPoolTokenFacet`
- `vaultQueryFacet`
- `vaultRegistrationFacet`
- `vaultAdminFacet`
- `vaultRecoveryFacet`
- `diamondFactory`

Then deploy `BalancerV3VaultDFPkg` via `create3Factory.deployPackageWithArgs(...)`.

Representative shape:

```solidity
vaultPkg = IBalancerV3VaultDFPkg(
  address(
    create3Factory.deployPackageWithArgs(
      type(BalancerV3VaultDFPkg).creationCode,
      abi.encode(
        IBalancerV3VaultDFPkg.PkgInit({
          vaultTransientFacet: vaultTransientFacet,
          vaultSwapFacet: vaultSwapFacet,
          vaultLiquidityFacet: vaultLiquidityFacet,
          vaultBufferFacet: vaultBufferFacet,
          vaultPoolTokenFacet: vaultPoolTokenFacet,
          vaultQueryFacet: vaultQueryFacet,
          vaultRegistrationFacet: vaultRegistrationFacet,
          vaultAdminFacet: vaultAdminFacet,
          vaultRecoveryFacet: vaultRecoveryFacet,
          diamondFactory: diamondPackageFactory
        })
      ),
      _salt(type(BalancerV3VaultDFPkg).name)
    )
  )
);
```

### Layer 3: use the vault package to deploy the vault instance

After the vault package is deployed, use the package itself to deploy the Balancer vault instance.

Call:

- `vaultPkg.deployVault(...)`

Required runtime args:

- `minimumTradeAmount`
- `minimumWrapAmount`
- `pauseWindowDuration`
- `bufferPeriodDuration`
- `authorizer`
- `protocolFeeController`

Representative shape:

```solidity
balancerVault = vaultPkg.deployVault(
  MIN_TRADE_AMOUNT,
  MIN_WRAP_AMOUNT,
  PAUSE_WINDOW_DURATION,
  BUFFER_PERIOD_DURATION,
  IAuthorizer(balancerAuthorizer),
  IProtocolFeeController(address(0))
);
```

For the first Base Sepolia pass, `protocolFeeController` may remain `address(0)` if we intentionally mirror the current local Base implementation.

### Layer 4: deploy Balancer router facets

Deploy the router facets after the vault exists, because router package init must be wired to the final vault address at router deployment time.

Required router facets:

- `RouterSwapFacet`
- `RouterAddLiquidityFacet`
- `RouterRemoveLiquidityFacet`
- `RouterInitializeFacet`
- `RouterCommonFacet`
- `BatchSwapFacet`
- `BufferRouterFacet`
- `CompositeLiquidityERC4626Facet`
- `CompositeLiquidityNestedFacet`

These are the same facets used both by:

- the router package test base in Crane
- the Base Sepolia local Balancer core deployment reference

### Layer 5: deploy the Balancer router package

Assemble `IBalancerV3RouterDFPkg.PkgInit` with exactly these fields:

- `routerSwapFacet`
- `routerAddLiquidityFacet`
- `routerRemoveLiquidityFacet`
- `routerInitializeFacet`
- `routerCommonFacet`
- `batchSwapFacet`
- `bufferRouterFacet`
- `compositeLiquidityERC4626Facet`
- `compositeLiquidityNestedFacet`
- `diamondFactory`

Then deploy `BalancerV3RouterDFPkg` via `create3Factory.deployPackageWithArgs(...)`.

Representative shape:

```solidity
routerPkg = IBalancerV3RouterDFPkg(
  address(
    create3Factory.deployPackageWithArgs(
      type(BalancerV3RouterDFPkg).creationCode,
      abi.encode(
        IBalancerV3RouterDFPkg.PkgInit({
          routerSwapFacet: routerSwapFacet,
          routerAddLiquidityFacet: routerAddLiquidityFacet,
          routerRemoveLiquidityFacet: routerRemoveLiquidityFacet,
          routerInitializeFacet: routerInitializeFacet,
          routerCommonFacet: routerCommonFacet,
          batchSwapFacet: batchSwapFacet,
          bufferRouterFacet: bufferRouterFacet,
          compositeLiquidityERC4626Facet: compositeLiquidityERC4626Facet,
          compositeLiquidityNestedFacet: compositeLiquidityNestedFacet,
          diamondFactory: diamondPackageFactory
        })
      ),
      _salt(type(BalancerV3RouterDFPkg).name)
    )
  )
);
```

### Layer 6: use the router package to deploy the router instance

After the router package is deployed, use the package itself to deploy the Balancer router instance.

Call:

- `routerPkg.deployRouter(vault, weth, permit2, routerVersion)`

Required runtime args:

- the deployed Balancer vault instance
- Base Sepolia canonical WETH
- Base Sepolia Permit2
- router version string

Representative shape:

```solidity
balancerRouter = routerPkg.deployRouter(
  IVault(payable(balancerVault)),
  IWETH(BASE_SEPOLIA.WETH9),
  IPermit2(BASE_SEPOLIA.PERMIT2),
  ROUTER_VERSION
);
```

### Layer 7: export the deployed Balancer infrastructure

After the vault and router are deployed, export the Balancer core infrastructure addresses in a stable artifact contract shape.

Required keys:

- `balancerV3Authorizer`
- `balancerV3ProtocolFeeController`
- `balancerV3VaultAdmin`
- `balancerV3VaultExtension`
- `balancerV3Vault`
- `balancerV3Router`
- `balancerV3BatchRouter`
- `balancerV3BufferRouter`
- `balancerV3CompositeLiquidityRouter`

Even if several of those keys resolve to the same deployed address in the first pass, the artifact should still include all keys explicitly.

### How IndexedEx packages then build on the Balancer core

Once the Balancer core infrastructure is deployed, the subsequent IndexedEx Balancer package stage should mirror the Sepolia package deployment flow, except it should bind to the newly deployed local Balancer core addresses rather than canonical network constants.

That stage should deploy:

- `SenderGuardFacet`
- `BalancerV3StandardExchangeRouter` integration facets:
  - exact-in query
  - exact-in swap
  - exact-out query
  - exact-out swap
  - batch exact-in
  - batch exact-out
  - prepay
  - prepay hooks
  - permit2 witness
- `StandardExchangeRateProvider` package
- `BalancerV3ConstantProductPoolStandardVaultPkg`

The reference for this IndexedEx-side Balancer package composition is:

- `scripts/foundry/sepolia/Script_04_DeployDEXPackages_BalancerV3.s.sol`
- `contracts/protocols/dexes/balancer/v3/routers/TestBase_BalancerV3StandardExchangeRouter.sol`

### Summary of package-based Balancer deployment steps

1. Deploy vault facets.
2. Build `IBalancerV3VaultDFPkg.PkgInit`.
3. Deploy `BalancerV3VaultDFPkg`.
4. Deploy Balancer authorizer.
5. Call `vaultPkg.deployVault(...)`.
6. Deploy router facets.
7. Build `IBalancerV3RouterDFPkg.PkgInit`.
8. Deploy `BalancerV3RouterDFPkg`.
9. Call `routerPkg.deployRouter(...)`.
10. Export Balancer core artifact.
11. Deploy IndexedEx Balancer integration packages against that local Balancer core.

### Balancer vault package details

The vault package should be built from the facet set already used in the local Base reference:

- `VaultTransientFacet`
- `VaultSwapFacet`
- `VaultLiquidityFacet`
- `VaultBufferFacet`
- `VaultPoolTokenFacet`
- `VaultQueryFacet`
- `VaultRegistrationFacet`
- `VaultAdminFacet`
- `VaultRecoveryFacet`

All of these should be deployed via CREATE3-factory facet helpers or equivalent deterministic deployment helpers.

### Balancer router package details

The router package should be built from the facet set already used in the local Base reference:

- `RouterSwapFacet`
- `RouterAddLiquidityFacet`
- `RouterRemoveLiquidityFacet`
- `RouterInitializeFacet`
- `RouterCommonFacet`
- `BatchSwapFacet`
- `BufferRouterFacet`
- `CompositeLiquidityERC4626Facet`
- `CompositeLiquidityNestedFacet`

The resulting router deployment should be exported under the same logical keys used by downstream scripts so later stages do not need Balancer-specific branching.

### Balancer artifact contract

Write the core deployment output to a dedicated file such as:

- `03b_balancer_v3_core.json`

The artifact should include:

- `balancerV3Authorizer`
- `balancerV3ProtocolFeeController`
- `balancerV3VaultAdmin`
- `balancerV3VaultExtension`
- `balancerV3Vault`
- `balancerV3Router`
- `balancerV3BatchRouter`
- `balancerV3BufferRouter`
- `balancerV3CompositeLiquidityRouter`

### How downstream stages consume Balancer

Once the Base Sepolia Balancer core artifact exists, later Base public stages should consume it the same way the local Base scripts consume their `03b` output:

- pool package deployment stages bind to the local Balancer vault and router
- Balancer const-prod pool deployment stages create pools against the deployed local vault
- liquidity seeding stages initialize those pools using bridged token balances
- rate-provider and Protocol DETF stages reference the local Balancer core addresses rather than canonical network constants

### Balancer pool and package follow-on stages

After core deployment, the Base public flow should continue through the same Balancer-related IndexedEx stages already present in the Sepolia or local Base stacks:

- deploy Balancer standard exchange router integration package
- deploy standard exchange rate provider package
- deploy Balancer constant-product pool standard vault package
- deploy Balancer const-prod pools
- deploy Balancer const-prod vault-token pools
- seed Balancer vault-token pool liquidity

The difference on Base Sepolia is not the IndexedEx Balancer package graph. The difference is only that those stages must point at the newly deployed local Balancer core contracts and use bridged tokens as liquidity assets.

### Reference files for implementation

Primary script reference:

- `scripts/foundry/supersim/base/Script_03B_DeployBalancerV3Core.s.sol`

Primary IndexedEx Balancer integration reference:

- `scripts/foundry/sepolia/Script_04_DeployDEXPackages_BalancerV3.s.sol`

Supporting package and facet deployment references:

- `contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouter_FactoryService.sol`
- `contracts/protocols/dexes/balancer/v3/pools/constProd/BalancerV3ConstantProductPool_FactoryService.sol`

### Initial implementation constraint

For the first Base Sepolia public pass, it is acceptable to follow the existing local Base Balancer model where:

- `balancerV3ProtocolFeeController` is exported as zero address if fee control is intentionally stubbed
- `balancerV3VaultAdmin` and `balancerV3VaultExtension` are represented by the vault deployment itself
- `balancerV3BatchRouter`, `balancerV3BufferRouter`, and `balancerV3CompositeLiquidityRouter` resolve to the same router instance if the router package is intentionally unified

That still satisfies the requirement to deploy and demonstrate a complete Balancer V3 stack inside our environment, while keeping the public Base Sepolia rollout implementable with the code paths we already have.

## Recommended Script Layout

### Ethereum Sepolia

- Keep using `scripts/foundry/public_sepolia/ethereum/Script_DeployAll.s.sol`
- Extend the token stage as needed for bridge preparation
- Add a dedicated bridge-execution script for L1 deposits

### Base Sepolia

- Keep using `scripts/foundry/public_sepolia/base/Script_DeployAll.s.sol`
- Add a bridge-token creation stage early in the Base flow
- Add a bridged-token loader stage that exports token addresses in the format expected by downstream stages
- Mirror the same exchange, pool, vault, and DETF stage layout used by the Sepolia environment scripts
- Deploy local Uniswap V2 infrastructure on Base Sepolia, matching the Sepolia environment topology
- Reuse the same Uniswap V2 and Aerodrome deployment approach already established in `scripts/foundry/sepolia`
- Deploy the full Balancer V3 protocol stack from in-repo contracts because canonical Base Sepolia Balancer V3 addresses are not assumed to exist for this flow
- Replace or fork liquidity stages that assume local mint access
- Replace or fork the DETF stage to use bridged `DemoWETH` and `RICH`

### Shared orchestration

Prefer three shell entrypoints instead of one monolithic deploy script:

1. token bootstrap and wrapper creation
2. bridge execution
3. Base architecture deployment

That preserves the required manual verification gates between phases.

## Interfaces and Constants Needed

### Existing constants already available

- `ETHEREUM_SEPOLIA.BASE_L1_STANDARD_BRIDGE`
- `ETHEREUM_SEPOLIA.BASE_OPTIMISM_MINTABLE_ERC20_FACTORY`
- `BASE_SEPOLIA.L2_STANDARD_BRIDGE`
- `BASE_SEPOLIA.OPTIMISM_MINTABLE_ERC20_FACTORY`

### Interface work

The repo appears to have Optimism mintable factory interfaces in tests, but not yet as a reusable production import in the main contracts or scripts tree.

Implementation should promote a stable interface into a reusable location if needed rather than copying test-local interfaces into multiple scripts.

Important note from prior test work:

- use `createOptimismMintableERC20(address,string,string)`
- do not use `createStandardOptimismMintableERC20(...)` for this flow

## Risks and Constraints

- Bridged L2 tokens are not general-purpose mintable test tokens. Any stage that currently calls `mint()` on the L2 token directly must be replaced.
- The Base public Sepolia scaffold is partially present but still too coupled to the local Base stack.
- Base Sepolia cannot rely on pre-existing Balancer V3 deployments for this plan; that protocol stack must be deployed as part of the flow.
- The Base public flow must be kept aligned with the Sepolia environment stage graph so that downstream artifact naming and UI expectations remain stable.
- The DETF Base deployment must distinguish between:
  - canonical Base WETH for general environment integration
  - bridged DemoWETH for the DETF demo base-token role
- The bridge phase should be deterministic and artifact-driven so reruns do not silently diverge.

## Implementation Order

### Step 1

Implement phase 1 only:

- finalize Ethereum token source deployment outputs
- create Base wrapper tokens through the mintable factory
- export the shared bridge token manifest
- finalize the wrapper naming and symbol suffix convention in code

### Step 2

Implement phase 2:

- bridge working balances from Ethereum Sepolia
- export a bridge execution artifact

### Step 3

Implement phase 3:

- refactor Base public token sourcing to use bridged tokens
- mirror the Sepolia architecture stages on Base Sepolia using bridged tokens as the asset source
- deploy Base Sepolia Uniswap V2 infrastructure so the Base graph matches the Sepolia graph
- deploy the full Base Sepolia Balancer V3 protocol stack from in-repo Crane contracts
- refactor Base liquidity stages to consume bridged balances only
- refactor Base Protocol DETF deployment to use bridged DemoWETH and bridged RICH

## Done Criteria

This plan is complete when:

- wrapper tokens are created on Base Sepolia for all required bridgeable assets
- working balances are bridged from Ethereum Sepolia to Base Sepolia
- Base Sepolia deployment scripts consume the bridged assets rather than deploying local substitutes
- the Base Protocol DETF deploys using bridged DemoWETH and bridged RICH
- all relevant deployment artifacts and tokenlists are exported for later UI use