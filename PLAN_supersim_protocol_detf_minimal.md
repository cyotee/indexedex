# Plan: Minimal SuperSim Protocol DETF + Bridge Deployment

## Goal

Reduce the local SuperSim Sepolia workflow so it deploys only the pieces required to:

1. deploy the Ethereum-side Protocol DETF,
2. deploy the Base-side Protocol DETF,
3. deploy and configure the Superchain bridge infrastructure those DETFs require, and
4. export enough frontend artifacts to test the bridge-related UI flows.

The immediate objective is not to preserve the full local rehearsal graph. The immediate objective is to make the local SuperSim environment small enough to stay alive and reliable while we validate Protocol DETF bridging.

The current implementation direction is now fixed by the clarified requirements:

- replace the current wrapper default behavior rather than adding a new default wrapper,
- keep reserve bridge smoke tests in the default flow,
- export only the minimal Protocol DETF and bridge-related artifact surface, and
- keep only the minimum Base-side infrastructure required for Protocol DETF bridging.

## Problem Statement

The current wrapper at [scripts/foundry/supersim/deploy_mainnet_bridge_ui.sh](/Users/cyotee/Development/github-cyotee/indexedex/scripts/foundry/supersim/deploy_mainnet_bridge_ui.sh) deploys a large mixed environment:

- Ethereum full chain-local graph,
- Base full chain-local graph,
- extra pool families,
- extra vault families,
- extra WETH/TTC stages,
- full tokenlist exports,
- bridge infrastructure,
- bridge configuration,
- reserve bridge smoke tests.

Recent runs show the local Base child Anvil aborting under this load, which tears down the entire SuperSim process tree and leaves both RPCs unavailable. That makes the local environment unsuitable for focused bridge testing even when the Protocol DETF pieces themselves are largely working.

## Desired End State

Create a slim SuperSim deployment flow with these properties:

- One command starts or reuses local SuperSim forks for Ethereum Sepolia and Base Sepolia.
- Ethereum deploys only the contracts required for Ethereum Protocol DETF bridging.
- Base deploys only the contracts required for Base Protocol DETF bridging.
- Superchain bridge infra is deployed on both sides.
- Protocol DETF bridge configuration is applied on both sides.
- Frontend address artifacts are exported for the reduced environment.
- Optional reserve-bridge smoke tests remain available, but they must not be on the critical path for bringing up the local UI.

## Scope

### Keep

- SuperSim lifecycle management in the wrapper.
- ETH sweep into the chosen deployer address.
- Ethereum Protocol DETF deployment path.
- Base Protocol DETF deployment path.
- Superchain bridge infra deployment:
  - [scripts/foundry/supersim/Script_24_DeploySuperchainBridgeInfra.s.sol](/Users/cyotee/Development/github-cyotee/indexedex/scripts/foundry/supersim/Script_24_DeploySuperchainBridgeInfra.s.sol)
- Superchain bridge configuration:
  - [scripts/foundry/supersim/Script_25_ConfigureProtocolDetfBridge.s.sol](/Users/cyotee/Development/github-cyotee/indexedex/scripts/foundry/supersim/Script_25_ConfigureProtocolDetfBridge.s.sol)
- Frontend artifact export under `frontend/app/addresses/supersim_sepolia`.
- Reserve bridge smoke tests in the default flow.

### Remove From The Default Local Flow

- Non-Protocol-DETF pool families.
- Non-Protocol-DETF strategy vault families.
- WETH/TTC-specific stages.
- broad tokenlist generation that assumes the full graph exists.
- full `Script_DeployAll` chain graphs.

### Not In Scope For This Reduction

- restoring a full public-Sepolia-like local rehearsal graph,
- preserving every current tokenlist family,
- validating every DEX/vault integration in local SuperSim,
- optimizing the public Sepolia deployment flow.

## Proposed Architecture

### 1. Replace Default Wrapper Targets With Minimal Chain-Local Entrypoints

Keep the full `Script_DeployAll` entrypoints available, but change the default wrapper to target minimal chain-local entrypoints.

Suggested new scripts:

- `scripts/foundry/supersim/ethereum/Script_DeployProtocolDetfMinimal.s.sol`
- `scripts/foundry/supersim/base/Script_DeployProtocolDetfMinimal.s.sol`

These minimal entrypoints should replace the current full graph dispatch with the smallest dependency graph that still allows Stage 16 Protocol DETF deployment to succeed.

### 2. Treat Stage 16 As The Target, Not The Starting Point

The minimal flow should be built backward from Protocol DETF requirements, not forward from the legacy full deployment sequence.

For each chain, identify the exact prerequisites that Stage 16 actually consumes:

- factories,
- shared facets,
- core proxies,
- any DEX packages or core components the Protocol DETF depends on,
- required test tokens,
- required underlying pools and vaults,
- Stage 15 seigniorage dependencies if Stage 16 consumes them.

Anything not required by Stage 16 should be excluded from the minimal flow.

### 3. Separate “Required For DETF” From “Nice To Have For Local Rehearsal”

The current full flows bundle together:

- core infrastructure required for Protocol DETF,
- additional liquidity and vault families,
- extra demonstration assets and tokenlists.

The minimal plan should explicitly classify scripts into:

- `required` for Protocol DETF bridge testing,
- `optional` for broader local product coverage,
- `excluded` from the minimal workflow.

### 4. Keep Reserve Bridge Testing In Default Flow

The current wrapper runs both:

- [scripts/foundry/supersim/Script_26_TestProtocolDetfReserveBridge.s.sol](/Users/cyotee/Development/github-cyotee/indexedex/scripts/foundry/supersim/Script_26_TestProtocolDetfReserveBridge.s.sol)

before frontend artifact export.

That ordering can stay, but the important change is that the deployment work preceding the smoke tests must be reduced.

Recommended behavior:

- deploy minimal Ethereum side,
- deploy minimal Base side,
- deploy bridge infra,
- configure bridge,
- run reserve bridge smoke tests,
- export frontend artifacts.

## Candidate Dependency Cuts

### Ethereum Minimal Dependency Map

Current full entrypoint:

- [scripts/foundry/supersim/ethereum/Script_DeployAll.s.sol](/Users/cyotee/Development/github-cyotee/indexedex/scripts/foundry/supersim/ethereum/Script_DeployAll.s.sol)

Current sequence includes:

- factories,
- shared facets,
- core proxies,
- Balancer V3 DEX packages,
- Uniswap V2 deployment,
- test tokens,
- extra Uni V2 pools/vaults,
- extra Balancer pools,
- ERC4626 permit vaults,
- seigniorage DETFs,
- Protocol DETF,
- tokenlist export.

Confirmed Stage 16 manifest reads:

- `01_factories.json`
- `02_shared_facets.json`
- `03_core_proxies.json`
- `04_balancer_v3.json`
- `05_uniswap_v2.json`
- optional `15_seigniorage_detfs.json` for `weightedPool8020Factory`

Current chosen minimal chain flow:

- Stage 01 factories
- Stage 02 shared facets
- Stage 03 core proxies
- Stage 04 Balancer V3 integration packages
- Stage 05 Uniswap V2 core plus package
- Stage 16 Protocol DETF

Not required by Stage 16 and removed from the default local path:

- test-token stage,
- Uni V2 pool and strategy vault staging,
- Balancer pool staging,
- ERC4626 permit vault staging,
- Stage 15 seigniorage DETFs,
- tokenlist export.

### Base Minimal Dependency Map

Current full entrypoint:

- [scripts/foundry/supersim/base/Script_DeployAll.s.sol](/Users/cyotee/Development/github-cyotee/indexedex/scripts/foundry/supersim/base/Script_DeployAll.s.sol)

Current sequence includes:

- factories,
- shared facets,
- core proxies,
- Uniswap V2 core,
- Balancer V3 core,
- Aerodrome core,
- DEX packages,
- test tokens,
- pool families,
- strategy vault families,
- Aerodrome strategy vault families,
- Balancer const-prod pool families,
- base liquidity seeding,
- standard exchange rate providers,
- additional Balancer vault-token pool stages,
- ERC4626 permit vaults,
- seigniorage DETFs,
- Protocol DETF,
- WETH/TTC stages,
- tokenlist export.

Confirmed Stage 16 manifest reads:

- `01_factories.json`
- `02_shared_facets.json`
- `03_core_proxies.json`
- `04_dex_packages.json`
- previously hard-required `15_seigniorage_detfs.json` only for `weightedPool8020Factory`

Current chosen minimal chain flow:

- Stage 01 factories
- Stage 02 shared facets
- Stage 03 core proxies
- Stage 03A Uniswap V2 core
- Stage 03B Balancer V3 core
- Stage 03C Aerodrome core
- Stage 04 DEX packages
- Stage 16 Protocol DETF

Implementation note:

- Base Stage 16 should no longer require the full Stage 15 seigniorage deployment just to recover `weightedPool8020Factory`.
- Instead, Stage 16 should reuse the Stage 15 manifest when it exists and otherwise deploy the weighted pool factory directly.

Not required by Stage 16 and removed from the default local path:

- test-token stage,
- all pool-family stages,
- all strategy-vault-family stages,
- liquidity-seeding stages,
- exchange rate-provider follow-on stages beyond Stage 04,
- ERC4626 permit vault staging,
- full Stage 15 seigniorage DETF deployment,
- WETH/TTC stages,
- tokenlist export.

## Implementation Plan

### Phase 1: Dependency Census

For Ethereum and Base Stage 16, enumerate the exact upstream contract addresses and manifest files consumed during `Script_16_DeployProtocolDETF`.

Deliverable:

- a per-chain dependency map listing:
  - required prior stages,
  - manifest keys consumed,
  - scripts that can be removed.

### Phase 2: Add Minimal Chain-Local Deploy Scripts

Create dedicated minimal deploy entrypoints for Ethereum and Base that run only the required stages from Phase 1.

Deliverable:

- minimal chain-local scripts for Ethereum and Base.

### Phase 3: Change The Existing Wrapper Default

The existing wrapper should:

- start or reuse Supersim,
- wait for RPCs,
- sweep ETH to the deployer,
- run minimal Ethereum deployment,
- run minimal Base deployment,
- deploy bridge infra,
- configure bridge,
- run bridge smoke tests,
- export frontend artifacts.

### Phase 4: Reduce Export Surface

Export only the frontend artifacts needed for Protocol DETF and bridge-related UI testing.

Because the minimal chain entrypoints no longer emit broad pool, vault, or tokenlist manifests, the existing exporter can remain in place while still producing a reduced frontend surface.

Deliverable:

- a reduced export set under:
  - `frontend/app/addresses/supersim_sepolia/ethereum`
  - `frontend/app/addresses/supersim_sepolia/base`

### Phase 5: Promote The Minimal Flow

Once the reduced flow is stable, decide whether the existing `deploy_mainnet_bridge_ui.sh` should:

- remain the full rehearsal flow, with the minimal script as a faster alternative, or
- be replaced by the minimal script for day-to-day local UI/bridge work.

## Validation Criteria

The minimal environment is successful when all of the following are true:

1. SuperSim remains alive after deployment completes.
2. `http://127.0.0.1:8545` responds after the wrapper exits.
3. `http://127.0.0.1:9545` responds after the wrapper exits.
4. Ethereum Protocol DETF manifest exists and is complete.
5. Base Protocol DETF manifest exists and is complete.
6. Bridge infra manifests exist on both sides.
7. Bridge configuration manifests exist on both sides.
8. Frontend artifact export completes.
9. The UI can load `supersim_sepolia` artifacts for both chain roles.
10. Optional bridge smoke tests can be run separately without being required for environment bring-up.

## Risks

### Hidden Stage 16 Dependencies

Stage 16 may implicitly depend on outputs currently produced by scripts that look unrelated. That is why the dependency census must happen before aggressively cutting stages.

### Bridge Quote Requirements

Even if Protocol DETF deploys, `previewBridgeRichir()` and `bridgeRichir()` may still require more liquidity or more seeded upstream state than the smallest deploy graph first suggests.

### Tokenlist Assumptions

Existing export tooling may assume full tokenlist families exist. The export phase may need a reduced mode instead of simply omitting files.

### Base-Side Infra Coupling

Base still has the highest risk of hidden coupling because the current full graph bundles Aerodrome, Balancer, and Uniswap setup together. The minimal Base plan must be validated independently rather than inferred from Ethereum.

## Recommended First Change Set

Implement the smallest possible first pass:

1. add this planning document,
2. create minimal Ethereum and Base `Script_DeployProtocolDetfMinimal` entrypoints,
3. create `deploy_protocol_detf_bridge_minimal.sh`,
4. move bridge smoke tests behind an explicit flag,
5. keep the current large wrapper unchanged until the minimal flow is proven stable.

## Files Expected To Change In The Follow-Up Implementation

- [scripts/foundry/supersim/deploy_mainnet_bridge_ui.sh](/Users/cyotee/Development/github-cyotee/indexedex/scripts/foundry/supersim/deploy_mainnet_bridge_ui.sh)
- `scripts/foundry/supersim/deploy_protocol_detf_bridge_minimal.sh`
- `scripts/foundry/supersim/ethereum/Script_DeployProtocolDetfMinimal.s.sol`
- `scripts/foundry/supersim/base/Script_DeployProtocolDetfMinimal.s.sol`
- [scripts/foundry/supersim/Script_24_DeploySuperchainBridgeInfra.s.sol](/Users/cyotee/Development/github-cyotee/indexedex/scripts/foundry/supersim/Script_24_DeploySuperchainBridgeInfra.s.sol)
- [scripts/foundry/supersim/Script_25_ConfigureProtocolDetfBridge.s.sol](/Users/cyotee/Development/github-cyotee/indexedex/scripts/foundry/supersim/Script_25_ConfigureProtocolDetfBridge.s.sol)
- [scripts/foundry/supersim/Script_26_TestProtocolDetfReserveBridge.s.sol](/Users/cyotee/Development/github-cyotee/indexedex/scripts/foundry/supersim/Script_26_TestProtocolDetfReserveBridge.s.sol)
- [scripts/foundry/supersim/export_frontend_artifacts.py](/Users/cyotee/Development/github-cyotee/indexedex/scripts/foundry/supersim/export_frontend_artifacts.py)

## Decision

For local SuperSim bridge work, optimize for a small stable environment first. Reintroduce broader pool, vault, and tokenlist coverage only after the minimal Protocol DETF plus bridge stack is reliable.