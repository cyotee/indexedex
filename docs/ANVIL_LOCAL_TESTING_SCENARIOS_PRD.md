# Anvil Local Testing Scenarios PRD

## Goal

Restructure the deployment scripts so local testing is fast, staged, resumable, and scenario-driven.

The target outcome is a local deployment system that supports:

- a reusable single-chain Anvil foundation for protocol and package bring-up
- scenario overlays that deploy only the fixtures needed for a given test graph
- a dual-chain SuperSim scenario for Single Vault DETF bridge testing across Ethereum Sepolia and Base Sepolia forks

This PRD is specifically for **new local testing scripts**, not for mainnet or public testnet release orchestration.

## Problem Statement

The repo currently has useful staged deployment surfaces, but they are optimized around environment bring-up rather than scenario-first local testing.

Current limitations:

- the active staged flows are environment-centric, not scenario-centric
- local testing fixtures are distributed across `anvil_base_main`, `anvil_sepolia`, `supersim`, and older `local/` scripts
- there is no single canonical local foundation that can be reused across multiple scenario graphs
- Uniswap V4 and Slipstream contract surfaces exist, but they are not yet integrated into the current script layer as first-class local deployment stages
- SuperSim bridge deployment exists, but it is currently coupled to the legacy `ProtocolDETF` naming path rather than a clean local testing scenario model

## Primary User Stories

### User Story 1

As a developer, I want to run a single local command that deploys the shared foundation needed for DEX and vault testing on Anvil so I do not have to repeatedly redeploy factories, core protocol pieces, and common packages.

### User Story 2

As a developer, I want to deploy Scenario 1, Scenario 2, or Scenario 3 on top of an already deployed local foundation so that I can test a specific graph without paying the cost of a full environment bring-up each time.

### User Story 3

As a developer, I want Scenario 4 to fork Ethereum Sepolia and Base Sepolia into a local SuperSim environment and deploy a bridgeable Single Vault DETF stack so that I can test bridge flows end-to-end locally.

### User Story 4

As a developer, I want every stage and scenario to emit deterministic JSON artifacts so I can resume, inspect, diff, and feed those addresses into tests or UI tooling.

## Scope

### In Scope

- new Foundry script organization for local Anvil testing
- a reusable foundation stage set for local testing
- scenario-specific overlay scripts for the listed scenarios
- a dual-chain SuperSim scenario profile for bridge testing
- JSON manifest output for foundations and scenarios
- shell wrappers that orchestrate local runs while delegating onchain logic to direct `forge script` execution

### Out of Scope

- public testnet deployment refactors beyond what can be reused structurally
- mainnet deployment refactors
- changing protocol contract behavior beyond what is required to support script wiring
- deleting older scripts immediately; this PRD is about introducing the new local testing path first

## Required Foundations

The following items are the requested local testing foundation.

### Crane and Indexedex foundation

- CREATE3 Factory and supporting components
- Diamond Package Factory
- commonly used components, including ERC20 permit packages and facets
- Indexedex core protocol components, including the Vault Registry

### Protocol foundation

- Uniswap V2 protocol
- Uniswap V4 protocol
- Aerodrome protocol
- Slipstream protocol
- Balancer V3 Vault
- Balancer V3 Weighted Pool Factory and supporting components
- Balancer V3 Stable Pool Factory and supporting components
- Balancer V3 Constant Product Pool package and supporting components

### Vault/package foundation

- Uniswap V2 Standard Exchange vault package
- Uniswap V4 Standard Exchange vault package
- Aerodrome Standard Exchange vault package
- Slipstream Standard Exchange vault package

## Foundation Strategy

The foundation should be split into two layers so local testing stays fast.

### Layer A: Core foundation

This layer is always deployed for local testing.

- CREATE3 Factory
- Diamond Package Factory
- shared facets and common packages
- Indexedex core
- test WETH and test token package support
- Balancer V3 Vault and the Balancer pool factory/component surfaces needed by the scenarios
- Uniswap V2 protocol core
- Uniswap V2 Standard Exchange package

### Layer B: Extended protocol foundation

This layer is modular and can be toggled on, but should still be scripted as part of the local testing system.

- Uniswap V4 protocol core and Standard Exchange package
- Aerodrome protocol core and Standard Exchange package
- Slipstream protocol core and Standard Exchange package
- Balancer V3 Weighted Pool and Stable Pool supporting surfaces not required by a minimal scenario

Rationale:

- Scenarios 1 through 3 do not require every listed foundation item on day one.
- The user still wants those protocols in the local testing system.
- A two-layer foundation allows us to preserve that requirement without making every local run unnecessarily heavy.

## Scenario Definitions

### Scenario 1

Deploy:

- Uniswap V2 vault of Test Token A and Test Token B
- Uniswap V2 vault of Test Token B and WETH

Interpretation:

- this scenario requires local test token deployment, local WETH, Uniswap V2 protocol core, and the Uniswap V2 Standard Exchange vault package
- this is the minimal single-chain scenario and should be the fastest path

Expected outputs:

- Test Token A address
- Test Token B address
- local WETH address
- UniV2 pool A/B
- UniV2 pool B/WETH
- Standard Exchange vault for A/B
- Standard Exchange vault for B/WETH

### Scenario 2

Deploy:

- Balancer V3 Constant Product Pool with Test Token B and the Uniswap V2 Vault of Test Token A and Test Token B, where the vault leg is configured with the Standard Exchange Rate Provider targeting Test Token B
- Balancer V3 Constant Product Pool with Test Token B and the Uniswap V2 Vault of Test Token B and WETH, where the vault leg is configured with the Standard Exchange Rate Provider targeting Test Token B

Interpretation:

- Scenario 2 depends on Scenario 1 outputs
- it adds the Standard Exchange Rate Provider instances and Balancer V3 constant-product pool layer

Expected outputs:

- rate provider for UniV2 A/B vault targeting Test Token B
- rate provider for UniV2 B/WETH vault targeting Test Token B
- Balancer constant-product pool: Test Token B + UniV2 A/B vault token
- Balancer constant-product pool: Test Token B + UniV2 B/WETH vault token

### Scenario 3

Deploy:

- Balancer V3 Constant Product Pool containing WETH and a Single Vault DETF of RICH and WETH

Interpretation:

- deploy a Single Vault DETF instance whose underlying graph is RICH/WETH
- deploy or reuse the reserve-side components needed for the Single Vault DETF
- deploy a Balancer constant-product pool pairing WETH with the Single Vault DETF token

Expected outputs:

- local RICH token
- WETH/RICH exchange vault or reserve support graph required by Single Vault DETF
- Single Vault DETF instance for RICH/WETH
- Balancer constant-product pool containing WETH and the DETF token

### Scenario 4

Deploy:

- fork both Ethereum Sepolia and Base Sepolia testnets
- Superchain SuperSim bridging of a Single Vault DETF of RICH and WETH

Interpretation:

- this is not a single-chain Anvil scenario; it is a dedicated dual-chain local profile
- it reuses the direct per-chain orchestration pattern already established for SuperSim
- it should use a Single Vault DETF bridge path instead of relying on older environment naming as the conceptual model

Expected outputs:

- local Ethereum Sepolia fork deployment manifests
- local Base Sepolia fork deployment manifests
- bridge infrastructure manifests
- bridge configuration manifests
- reserve bridge validation outputs for the Single Vault DETF scenario

## Proposed Script Architecture

### Top-level model

Introduce two local testing profiles:

- `anvil_local_single_chain`
- `supersim_local_dual_chain`

These profiles should compose a shared stage library rather than reimplement deployment logic.

### Proposed directory shape

```text
scripts/foundry/
  local_testing/
    stages/
      01_foundation_crane/
      02_foundation_indexedex_core/
      03_foundation_protocols_base/
      04_foundation_protocols_extended/
      05_foundation_packages/
      06_foundation_assets/
      10_scenario_1/
      11_scenario_2/
      12_scenario_3/
      20_dual_chain_foundation/
      21_dual_chain_bridge/
      22_dual_chain_validation/
      90_export/
    profiles/
      anvil_single/
      supersim_dual/
```

This can later be merged into a broader repo-wide stage taxonomy, but for this PRD the focus is local testing usability.

## Proposed Stage Plan

### Stage 01: Crane foundation

Deploy:

- CREATE3 Factory
- Diamond Package Factory
- shared access and ownership components
- common ERC20 and permit-oriented facets/packages needed by later stages

Outputs:

- `01_crane_foundation.json`

### Stage 02: Indexedex core foundation

Deploy:

- Vault Registry deployment and query surfaces
- Fee oracle surfaces if required by packages used in scenarios
- any additional Indexedex core proxies required by the exchange vault packages

Outputs:

- `02_indexedex_core.json`

### Stage 03: Base protocol foundation

Deploy the minimum protocol surfaces needed by Scenarios 1 through 3:

- local WETH
- Uniswap V2 core
- Balancer V3 Vault
- Balancer V3 Weighted Pool Factory and components needed by the Single Vault DETF graph
- Balancer V3 Constant Product Pool package and components

Outputs:

- `03_protocols_base.json`

### Stage 04: Extended protocol foundation

Deploy the additional requested protocol surfaces for future local testing:

- Uniswap V4 core and local dependencies
- Slipstream core and local dependencies
- Aerodrome core and local dependencies
- Balancer V3 Stable Pool Factory and extended components as needed

Important note:

- the repo contains Uniswap V4 and Slipstream contract surfaces, but the current script layer does not yet wire them as first-class local foundation stages
- this stage is therefore real new work, not just script relocation

Outputs:

- `04_protocols_extended.json`

### Stage 05: Foundation packages

Deploy reusable vault and package surfaces:

- Uniswap V2 Standard Exchange vault package
- Uniswap V4 Standard Exchange vault package
- Aerodrome Standard Exchange vault package
- Slipstream Standard Exchange vault package
- Standard Exchange Rate Provider package if scenario logic depends on it
- shared DETF helper packages required by Scenario 3 and Scenario 4

Outputs:

- `05_foundation_packages.json`

### Stage 06: Foundation assets

Deploy reusable local test assets:

- Test Token A
- Test Token B
- any additional fixture token required by later local scenarios
- local RICH token fixture for the Single Vault DETF scenarios

Outputs:

- `06_foundation_assets.json`

## Scenario overlay stages

### Stage 10: Scenario 1 overlay

Deploy only the graph needed for Scenario 1:

- UniV2 pools A/B and B/WETH
- Standard Exchange vault A/B
- Standard Exchange vault B/WETH

Outputs:

- `10_scenario_1.json`

### Stage 11: Scenario 2 overlay

Deploy only the graph needed for Scenario 2:

- Standard Exchange Rate Providers for Scenario 1 vaults targeting Test Token B
- Balancer constant-product pool with Test Token B and the UniV2 A/B vault token
- Balancer constant-product pool with Test Token B and the UniV2 B/WETH vault token

Outputs:

- `11_scenario_2.json`

### Stage 12: Scenario 3 overlay

Deploy only the graph needed for Scenario 3:

- Single Vault DETF for RICH/WETH
- any reserve-side vault/package dependencies not already deployed in foundation
- Balancer constant-product pool containing WETH and the Single Vault DETF token

Outputs:

- `12_scenario_3.json`

## Dual-chain stages for Scenario 4

### Stage 20: Dual-chain foundation

Responsibilities:

- fork Ethereum Sepolia and Base Sepolia into local SuperSim
- prepare sender/broadcast identity using the current shell orchestration best practices
- deploy per-chain foundation and the Single Vault DETF graph needed for bridge testing

Outputs:

- `deployments/local_testing/supersim/ethereum/*`
- `deployments/local_testing/supersim/base/*`

### Stage 21: Dual-chain bridge setup

Deploy and configure:

- bridge infrastructure
- remote token registry links
- bridge relayer wiring
- Single Vault DETF bridge configuration

Outputs:

- `21_bridge_infra_ethereum.json`
- `21_bridge_infra_base.json`
- `21_bridge_config_ethereum.json`
- `21_bridge_config_base.json`

### Stage 22: Dual-chain validation

Run:

- reserve bridge validation for the Single Vault DETF
- any local bridge smoke checks needed to confirm scenario readiness

Outputs:

- `22_bridge_validation_ethereum.json`
- `22_bridge_validation_base.json`

### Stage 90: Export

Export:

- deployment summary
- frontend/testing manifests
- merged scenario manifest for test harness consumption

## Proposed Commands

The new script system should support commands at two levels.

### Single-chain foundation and scenarios

- foundation only
- foundation + Scenario 1
- foundation + Scenario 1 + Scenario 2
- foundation + Scenario 3

Example command shape:

```bash
scripts/shell/local_testing.sh foundation
scripts/shell/local_testing.sh scenario1
scripts/shell/local_testing.sh scenario2
scripts/shell/local_testing.sh scenario3
```

### Dual-chain SuperSim scenario

Example command shape:

```bash
scripts/shell/local_testing_supersim.sh scenario4
```

Important orchestration rule:

- the shell wrapper should own simulator start/stop, fork selection, sender prep, output directory handling, and direct per-chain `forge script` execution
- onchain deployment logic should remain inside focused Solidity stages

## State and Artifacts

Every stage must be resumable and must write JSON manifests.

Required properties:

- stable filenames by stage
- explicit chain id in output
- addresses for deployed contracts and packages
- enough metadata to let a later scenario stage consume earlier foundation outputs without rediscovering addresses

Recommended root output directories:

- `deployments/local_testing/anvil_single/`
- `deployments/local_testing/supersim/ethereum/`
- `deployments/local_testing/supersim/base/`
- `deployments/local_testing/shared/`

## Acceptance Criteria

### Foundation acceptance

- a developer can deploy the local single-chain foundation without deploying any scenario overlay
- all foundation outputs are written to deterministic JSON files
- rerunning a completed stage either skips safely or validates state cleanly

### Scenario 1 acceptance

- one command produces the two requested UniV2 vaults
- the resulting manifest contains both pools and both vaults

### Scenario 2 acceptance

- one command on top of Scenario 1 produces both requested Balancer constant-product pools
- both pools use the Standard Exchange Rate Provider targeting Test Token B for the vault legs

### Scenario 3 acceptance

- one command produces a Single Vault DETF for RICH/WETH and a Balancer constant-product pool pairing WETH with the DETF token

### Scenario 4 acceptance

- one command starts or reuses local SuperSim forks for Ethereum Sepolia and Base Sepolia
- per-chain Single Vault DETF deployments complete
- bridge infra and bridge config complete
- a local bridge validation pass executes successfully

## Implementation Phases

### Phase 1: Introduce local testing foundation stages

- add new stage directories and output conventions
- implement Crane, Indexedex core, base protocol, package, and asset foundation stages

### Phase 2: Implement Scenario 1 and Scenario 2 overlays

- use UniV2 and Balancer constant-product surfaces as the first validating path
- ensure scenario stages consume foundation manifests instead of redeploying shared dependencies

### Phase 3: Implement Scenario 3 overlay

- wire the Single Vault DETF local deployment path into the new local testing profile
- add the WETH + DETF pool overlay

### Phase 4: Implement extended protocol foundation

- add script wiring for Uniswap V4 and Slipstream foundations
- add Aerodrome extended local foundation if not already fully reusable from existing stages

### Phase 5: Implement Scenario 4 dual-chain profile

- reuse the current SuperSim shell orchestration rules
- keep direct per-chain `forge script` invocation
- adapt the bridge flow to the new local testing output structure

## Concrete Implementation Plan

The implementation should produce a small set of focused Foundry scripts that can be orchestrated by thin Bash wrappers.

The design rule is:

- Bash owns process orchestration, environment setup, and stage ordering
- Foundry scripts own deterministic onchain deployment and JSON output

### Deliverable 1: Shared local testing script base

Add a shared Solidity base layer for the new local testing scripts.

Proposed files:

- `scripts/foundry/local_testing/shared/LocalTestingDeploymentBase.sol`
- `scripts/foundry/local_testing/shared/LocalTestingManifestLib.sol`
- `scripts/foundry/local_testing/shared/LocalTestingEnvLib.sol`

Responsibilities:

- resolve `OUT_DIR_OVERRIDE` and chain-aware output paths
- expose helpers for reading prior stage manifests
- expose helpers for skipping completed stages when artifacts already exist
- standardize chain id, deployer, and environment metadata output
- provide stage-level `writeDeploymentJson` and `readDeploymentJson` helpers

Implementation note:

- this should follow the existing `DeploymentBase.sol` pattern already used in the repo, but be scoped to local testing and scenario overlays rather than one environment family

### Deliverable 2: Single-chain foundation stages

Add the new single-chain stage scripts under a dedicated local testing folder.

Proposed files:

- `scripts/foundry/local_testing/anvil_single/Script_01_DeployCraneFoundation.s.sol`
- `scripts/foundry/local_testing/anvil_single/Script_02_DeployIndexedexCore.s.sol`
- `scripts/foundry/local_testing/anvil_single/Script_03_DeployBaseProtocols.s.sol`
- `scripts/foundry/local_testing/anvil_single/Script_04_DeployExtendedProtocols.s.sol`
- `scripts/foundry/local_testing/anvil_single/Script_05_DeployFoundationPackages.s.sol`
- `scripts/foundry/local_testing/anvil_single/Script_06_DeployFoundationAssets.s.sol`

Required behavior:

- each script reads the outputs of prior stages instead of recomputing addresses
- each script writes one deterministic JSON artifact
- each script can be run directly with `forge script`
- each script uses CREATE3 and existing factory-service flows, never direct ad hoc deployment patterns

### Deliverable 3: Scenario overlay stages

Add scenario-specific Foundry scripts that assume foundation outputs already exist.

Proposed files:

- `scripts/foundry/local_testing/anvil_single/Script_10_DeployScenario1.s.sol`
- `scripts/foundry/local_testing/anvil_single/Script_11_DeployScenario2.s.sol`
- `scripts/foundry/local_testing/anvil_single/Script_12_DeployScenario3.s.sol`

Responsibilities:

- Scenario 1: deploy the two requested UniV2 pools and Standard Exchange vaults
- Scenario 2: deploy the two Standard Exchange Rate Providers and the two Balancer constant-product pools
- Scenario 3: deploy the Single Vault DETF graph and the Balancer WETH plus DETF pool

Dependency rule:

- Scenario 2 consumes Scenario 1 outputs
- Scenario 3 consumes foundation outputs, but should not depend on Scenario 1 or Scenario 2 unless a shared fixture is explicitly reused

### Deliverable 4: Dual-chain SuperSim stages

Add focused per-chain and bridge-specific Foundry scripts for Scenario 4.

Proposed files:

- `scripts/foundry/local_testing/supersim/ethereum/Script_20_DeployFoundation.s.sol`
- `scripts/foundry/local_testing/supersim/base/Script_20_DeployFoundation.s.sol`
- `scripts/foundry/local_testing/supersim/Script_21_DeployBridgeInfra.s.sol`
- `scripts/foundry/local_testing/supersim/Script_22_ConfigureSingleVaultDetfBridge.s.sol`
- `scripts/foundry/local_testing/supersim/Script_23_ValidateSingleVaultDetfBridge.s.sol`

Responsibilities:

- per-chain stage 20 scripts deploy the minimum foundation and Single Vault DETF graph needed for bridging
- stage 21 deploys bridge infrastructure on both local forks
- stage 22 configures remote relationships using both chains' manifest outputs
- stage 23 executes reserve bridge smoke tests and writes validation outputs

Implementation note:

- this should reuse the current direct per-chain SuperSim orchestration pattern rather than introducing one monolithic top-level Solidity script

### Deliverable 5: Bash wrappers

Add thin Bash wrappers that only orchestrate local processes and stage ordering.

Proposed files:

- `scripts/shell/local_testing.sh`
- `scripts/shell/local_testing_supersim.sh`

#### `local_testing.sh` responsibilities

- start or reuse a single Anvil instance
- optionally restart or kill the instance
- validate sender and deployer env vars
- create output directories
- run the requested local foundation and scenario stages in order
- pass through verbosity flags and `--resume` or `--force` style behavior

#### `local_testing_supersim.sh` responsibilities

- start or reuse the local SuperSim environment
- resolve upstream RPC aliases when needed
- prepare deployer funding and sender identity
- call the new per-chain stage scripts directly
- call the bridge infra, config, and validation scripts directly
- export merged frontend and testing artifacts at the end

Shell rules:

- use `#!/usr/bin/env bash`
- use `set -euo pipefail`
- prefer arrays for `forge script` command construction
- keep process control and RPC startup logic in the shell wrapper, not Solidity

## Execution Order

### Single-chain execution order

1. Start or validate local Anvil.
2. Run `Script_01_DeployCraneFoundation.s.sol`.
3. Run `Script_02_DeployIndexedexCore.s.sol`.
4. Run `Script_03_DeployBaseProtocols.s.sol`.
5. Optionally run `Script_04_DeployExtendedProtocols.s.sol`.
6. Run `Script_05_DeployFoundationPackages.s.sol`.
7. Run `Script_06_DeployFoundationAssets.s.sol`.
8. Run one or more scenario overlay scripts.
9. Export merged manifests for tests and frontend consumers.

### Dual-chain execution order

1. Start or validate local SuperSim forks.
2. Prepare deployer funding on both forks.
3. Run Ethereum `Script_20_DeployFoundation.s.sol`.
4. Run Base `Script_20_DeployFoundation.s.sol`.
5. Run `Script_21_DeployBridgeInfra.s.sol`.
6. Run `Script_22_ConfigureSingleVaultDetfBridge.s.sol`.
7. Run `Script_23_ValidateSingleVaultDetfBridge.s.sol`.
8. Export merged per-chain manifests.

## Validation Plan

Each implementation milestone should have a cheap validation pass.

### Milestone 1 validation

- `forge build`
- run the new foundation scripts in dry-run mode against local Anvil
- verify all expected JSON artifacts are written

### Milestone 2 validation

- deploy Scenario 1 only
- run focused tests or smoke checks against the two UniV2 vaults

### Milestone 3 validation

- deploy Scenario 2 on top of Scenario 1
- validate that both Balancer pools use the expected Standard Exchange Rate Providers

### Milestone 4 validation

- deploy Scenario 3
- run focused Single Vault DETF mint-preview and pool wiring checks

### Milestone 5 validation

- deploy the dual-chain Scenario 4 profile
- run the bridge validation stage and confirm both chain manifests are complete

## Recommended Build Order

Implement in this order so each step unlocks the next with minimal wasted work.

1. Shared local testing base libraries.
2. Single-chain foundation stages `01` through `06`.
3. Bash wrapper for single-chain local execution.
4. Scenario 1 stage.
5. Scenario 2 stage.
6. Scenario 3 stage.
7. Extended protocol stage `04` for Uniswap V4, Slipstream, and Aerodrome expansion.
8. Dual-chain SuperSim wrapper and stages `20` through `23`.

## Definition of Done

The implementation is done when:

- the repo has reusable Foundry stage scripts for foundation and scenarios
- Bash wrappers can start local Anvil or SuperSim and execute those stages deterministically
- each stage writes deterministic JSON output and can consume earlier stage manifests
- Scenario 1, Scenario 2, Scenario 3, and Scenario 4 can each be launched by a small wrapper command without manual stage-by-stage editing
- the new local testing flow becomes the preferred development path for local scenario bring-up

## Open Questions to Resolve During Implementation

### 1. Always-on versus optional extended foundation

The user listed Uniswap V4 and Slipstream as required foundation. The implementation should confirm whether:

- those protocols must deploy on every single-chain local run, or
- they can live in an opt-in extended foundation stage while still being part of the supported local testing system

### 2. Single Vault DETF fixture token naming

Scenario 3 and Scenario 4 refer to a Single Vault DETF of `RICH` and `WETH`.

Implementation should standardize:

- local `RICH` fixture token deployment location
- whether the DETF token itself is exported under the `SingleVaultDetf` name, `CHIR`, or another canonical local fixture alias

### 3. Scenario composability

Implementation should decide whether:

- Scenario 2 hard-depends on Scenario 1 outputs, or
- Scenario 2 can bootstrap Scenario 1 implicitly when missing

Recommended default:

- Scenario 2 depends on Scenario 1 artifacts and invokes Scenario 1 only when explicitly requested by the wrapper

## Recommendation

Implement the new local testing script system as a **foundation plus scenario overlay** model.

That gives the repo:

- faster single-chain iteration for local DEX and vault testing
- a reusable local dependency graph across multiple tests
- a clean path for the bridge-specific dual-chain case
- room to add Uniswap V4 and Slipstream script wiring without entangling them with unrelated scenarios