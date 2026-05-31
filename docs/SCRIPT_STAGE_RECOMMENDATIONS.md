# Script Stage Recommendations

## Goal

Reorganize the script surface so there is one canonical staged deployment model, with environment-specific overrides layered on top of it instead of each environment redefining its own stage meanings.

The current repo already has a real stage pipeline, but it is spread across:

- numbered Foundry stages under multiple environment directories
- environment-specific `Script_DeployAll` wrappers
- shell wrappers that duplicate stage ordering and output conventions
- legacy `local/` and `local/segmented/` bootstrap scripts that predate the newer staged pipeline

This document recommends how to organize those scripts into clear stages and how to separate active deployment entrypoints from historical/demo scaffolding.

## Current Problems

### 1. The stage model exists, but not canonically

The repo already behaves like a staged deployment system:

- `anvil_base_main/deploy_all.sh` runs stages `01` through `23` in order.
- `anvil_sepolia/deploy_sepolia.sh` does the same with a slightly different DEX/core mix.
- `public_sepolia/*/Script_DeployAll.s.sol` selectively reuses those same stages.
- `supersim/*/Script_DeployAll.s.sol` also reuses the same stage family plus bridge stages `24` through `26`.

The issue is that the canonical stage meanings are implicit, not formally defined in one place.

### 2. Environment overrides are mixed into stage numbering ad hoc

Examples:

- Base-style environments use `Script_04_DeployDEXPackages.s.sol`, while Sepolia-style environments use `Script_04_DeployDEXPackages_BalancerV3.s.sol` plus `Script_05_DeployUniswapV2.s.sol`.
- `public_sepolia/ethereum/` uses `Script_04_NonWethUniV2PoolsAndVaults.s.sol` and `Script_05_NonWethBalancerPools.s.sol`, which are not conceptually the same kind of stage as the base canonical `04` and `05` files.
- `supersim/base/` introduces `03A`, `03B`, and `03C` to stand up chain-local protocol cores, but those are really a sub-phase of environment core setup, not a separate numbering scheme.

That makes it harder to answer simple questions like “what is Stage 4?” or “which stages are core platform versus environment overrides?”

### 3. Shell wrappers duplicate orchestration logic

The shell wrappers are currently carrying ordering, artifact naming, cleanup, and environment-setup policy.

That is useful, but the cost is duplication:

- `anvil_base_main/deploy_all.sh`
- `anvil_sepolia/deploy_sepolia.sh`
- `supersim/deploy_mainnet_bridge_ui.sh`
- `scripts/shell/*.sh`

These wrappers should remain, but they should target a stable canonical stage model rather than re-encoding deployment structure themselves.

### 4. Legacy and active scripts live side by side

The current `scripts/foundry/` root contains four different script generations:

- active staged deployment families
- standalone mainnet deployers
- cross-chain bridge orchestration
- older `local/` and `local/segmented/` prototype/bootstrap flows

This increases search noise and makes it unclear which scripts are authoritative.

### 5. Legacy DETF naming still leaks into current stage names

The deployment surface still uses names like:

- `Script_16_DeployProtocolDETF.s.sol`
- `Script_25_ConfigureProtocolDetfBridge.s.sol`

Those names no longer describe the current vault-family direction clearly, even where the code is still functional.

## Recommended Canonical Stage Model

The stage model should be formalized around deployment phases rather than around one environment's current filenames.

### Recommended phases

| Phase | Canonical purpose |
| --- | --- |
| `00` | Preflight and wallet preparation |
| `01` | Factory infrastructure |
| `02` | Shared facets and reusable primitives |
| `03` | Core Indexedex platform proxies and registries |
| `04` | Environment protocol cores |
| `05` | DEX/vault packages |
| `06` | Tokens and base assets |
| `07` | Base pools |
| `08` | Strategy vaults |
| `09` | Base liquidity seeding |
| `10` | Rate providers |
| `11` | Nested or vault-token pools |
| `12` | Nested liquidity seeding |
| `13` | ERC4626 and auxiliary vault wrappers |
| `14` | DETF family deployment |
| `15` | Optional market extensions |
| `20` | Cross-chain bridge infrastructure |
| `21` | Cross-chain bridge configuration |
| `22` | Cross-chain validation/testing |
| `90` | Artifact export |
| `99` | Cleanup and balance sweep |

This gives every environment the same phase language even when a phase is skipped or replaced.

## Recommended Stage Semantics

### `00` Preflight

Keep this in shell or task wrappers, not Solidity, unless a specific onchain prep step is needed.

Responsibilities:

- start or validate local forks/simulators
- clear stale artifacts
- validate chain id and deployment output dirs
- sweep dev ETH if needed
- configure impersonation or sender setup

Examples today:

- `anvil_base_main/Script_00_SweepEthToDev0.s.sol`
- `anvil_sepolia/Script_00_SweepEthToDev0.s.sol`
- Anvil/SuperSim shell-level cleanup and startup logic

Recommendation:

- treat these as preflight helpers, not part of the canonical contract-deployment stage list
- keep helper scripts named clearly as `Preflight_*` or `Utility_*` instead of stage numbers where possible

### `01` Factory Infrastructure

Canonical meaning:

- deploy `Create3Factory`
- deploy `DiamondPackageCallBackFactory`

Recommendation:

- every staged environment should either implement or explicitly reuse one canonical `01` stage
- this stage should always emit the same artifact schema, e.g. `01_factories.json`

### `02` Shared Facets

Canonical meaning:

- deploy shared ERC20, ERC4626, ownership, operability, introspection, and other reusable primitives

Recommendation:

- define this as the repo-wide “shared primitive surface” stage
- keep environment-specific deltas out of this stage unless chain-specific dependencies require it

### `03` Core Indexedex Platform

Canonical meaning:

- deploy Fee Collector
- deploy Indexedex Manager
- deploy registry/oracle proxies that form the platform spine

Recommendation:

- make this the single stage for Indexedex-owned platform proxies and registries
- move environment-owned protocol core bring-up out of `03` subletters conceptually and into Phase `04`

### `04` Environment Protocol Cores

Canonical meaning:

- deploy or bind to chain-specific protocol cores required before package deployment

This is where the current `03A/03B/03C` style logic really belongs.

Examples:

- Uniswap V2 core on Base SuperSim
- Balancer V3 core on Base SuperSim
- Aerodrome core on Base SuperSim
- Sepolia-specific “use existing Balancer / deploy local Uniswap / deploy local Aerodrome” setup

Recommendation:

- collapse `03A/03B/03C` into an explicit Phase `04` family
- use named sub-stages like `04_uniswap_v2_core`, `04_balancer_v3_core`, `04_aerodrome_core`
- keep the phase number stable even if one environment skips some sub-stages

### `05` DEX/Vault Packages

Canonical meaning:

- deploy exchange, router, rate-provider, and pool/vault packages that depend on factory + shared facet availability

Recommendation:

- make this phase package-centric only
- do not overload it with pool deployment or environment-specific pool topology

### `06` Tokens and Base Assets

Canonical meaning:

- deploy test tokens, wrapped test tokens, or chain-local bridge wrappers needed for later stages

Recommendation:

- move all token-only provisioning here, including bridge token creation for public testnets
- keep this phase asset-centric, not pool-centric

### `07` Base Pools

Canonical meaning:

- deploy initial trading pools or reserve pools over the stage-06 asset set

Recommendation:

- separate pool deployment from vault deployment everywhere
- environments that only deploy non-WETH pools should still use Phase `07`, not a custom `04` stage name

### `08` Strategy Vaults

Canonical meaning:

- deploy strategy vaults against the stage-07 pools

Recommendation:

- include protocol-specific variants here as sub-stages if necessary
- avoid environment names in the filename unless the vault behavior itself differs materially

### `09` Base Liquidity Seeding

Canonical meaning:

- seed liquidity into the base pool and vault surface

Recommendation:

- put all initial liquidity seeding here unless it is specifically about nested pools

### `10` Rate Providers

Canonical meaning:

- deploy rate providers for the strategy vault surface

Recommendation:

- keep this stage narrow and deterministic

### `11` Nested or Vault-Token Pools

Canonical meaning:

- deploy Balancer vault-token pools, vault-vault pools, or other second-layer liquidity structures

Recommendation:

- treat nested pools as their own phase, separate from base pool deployment

### `12` Nested Liquidity Seeding

Canonical meaning:

- seed the pools from Phase `11`

Recommendation:

- keep these seed steps distinct from deployment steps for resumability and debugging

### `13` ERC4626 and Auxiliary Vault Wrappers

Canonical meaning:

- deploy ERC4626 permit vaults or similar wrappers that are not part of the core DEX strategy graph

Recommendation:

- move auxiliary vault wrappers out of the middle of pool stages and keep them grouped here

### `14` DETF Family Deployment

Canonical meaning:

- deploy the DETF families built on top of the platform and liquidity graph

Recommendation:

- split into named sub-stages under one phase:
  - `14A_seigniorage_detf`
  - `14B_single_vault_detf`
  - future stable/composed-stable DETF family
- stop using `ProtocolDETF` in the stage label unless that exact family still exists intentionally

### `15` Optional Market Extensions

Canonical meaning:

- deploy optional market expansions like WETH/TTC extensions or future specialized environments

Recommendation:

- collapse the current `17` through `23` WETH/TTC branch into one extension phase with sub-stages
- that will make the main pipeline easier to read and the extension easier to disable

### `20` - `22` Cross-Chain Bridge Stages

Canonical meaning:

- `20`: bridge infrastructure
- `21`: bridge configuration
- `22`: bridge validation

Recommendation:

- preserve the current `24`, `25`, `26` logic, but renumber or alias it into a cross-chain phase family
- avoid using a DETF-family-specific name in the generic stage title unless the bridge is truly tied to one vault family

### `90` Export

Canonical meaning:

- tokenlist export
- frontend address artifact export
- deployment summary generation

Recommendation:

- standardize all artifact export into one final export phase
- keep frontend sync as shell orchestration, but call a canonical export stage set

### `99` Cleanup

Canonical meaning:

- sweep balances
- stop background infra if requested
- final cleanup

Recommendation:

- keep cleanup optional and isolated

## Recommended Directory Organization

### 1. Keep active staged deployments separate from legacy scripts

Recommended high-level split:

```text
scripts/
  foundry/
    stages/
    profiles/
    bridge/
    mainnet/
    legacy/
    shared/
  shell/
```

### 2. Move to a `stages/` plus `profiles/` model

Recommended structure:

```text
scripts/foundry/
  stages/
    01_factories/
    02_shared_facets/
    03_core_platform/
    04_protocol_cores/
    05_packages/
    06_assets/
    07_pools/
    08_strategy_vaults/
    09_base_liquidity/
    10_rate_providers/
    11_nested_pools/
    12_nested_liquidity/
    13_aux_vaults/
    14_detf/
    15_extensions/
    20_bridge_infra/
    21_bridge_config/
    22_bridge_validation/
    90_export/
    99_cleanup/
  profiles/
    anvil_base_main/
    anvil_sepolia/
    public_sepolia/
    supersim/
    base_main/
    ethereum_main/
  legacy/
    local/
    local_segmented/
    demo/
```

Rationale:

- `stages/` holds the canonical phase implementations or shared implementations.
- `profiles/` holds orchestration entrypoints and environment overrides.
- `legacy/` holds scripts that are still useful references but are no longer the main deployment surface.

### 3. Make profile entrypoints very thin

Each profile should ideally expose only:

- `DeployAll`
- optional `DeployMinimal`
- optional `Export`
- optional profile-specific preflight wrappers

Those files should mostly:

- set env/profile names
- select the correct implementation for each phase
- call the canonical stages in order

They should not contain large amounts of deployment business logic.

## Recommended Script Grouping by Authority

### Canonical implementation layer

These should be treated as the authoritative deployment units:

- factory deployment stages
- shared facet stages
- core platform stages
- package stages
- DETF deployment stages
- bridge stages

Recommendation:

- keep each stage focused on one deployment responsibility
- keep output artifact naming stable by phase

### Profile orchestration layer

These should be thin wrappers that compose the stages:

- `anvil_base_main/deploy_all.sh`
- `anvil_sepolia/deploy_sepolia.sh`
- `public_sepolia/*/Script_DeployAll.s.sol`
- `supersim/*/Script_DeployAll.s.sol`

Recommendation:

- make these wrappers declarative and short
- do not let them become the only place where stage meaning is documented

### Legacy reference layer

These should be explicitly marked as non-canonical:

- `scripts/foundry/local/`
- `scripts/foundry/local/segmented/`
- `Demo_*`
- older `Sepolia_*` one-off scripts

Recommendation:

- move them under `scripts/foundry/legacy/`
- add a short README explaining they are historical scaffolding and not the main deployment entrypoints

## Concrete Recommendations by Current Script Family

### `anvil_base_main/`

Recommendation:

- keep as the reference profile for the full single-chain staged pipeline
- use it as the source of truth for canonical phase names
- rename the WETH/TTC branch into Phase `15` sub-stages rather than leaving it as `17` through `23`

### `anvil_sepolia/`

Recommendation:

- keep as the reference profile for single-chain Sepolia behavior
- move “deploy local Aerodrome” and “use existing Balancer” semantics into clearly named Phase `04` environment core scripts
- stop overloading Stage `04` and `05` with different meanings relative to Base

### `public_sepolia/`

Recommendation:

- keep these as profile overrides, not as a separate conceptual stage family
- rename `NonWeth*` scripts into pool-phase override names under the canonical pool phase
- keep `CreateBridgeTokens` in the asset phase

### `supersim/`

Recommendation:

- treat this as a multi-profile orchestrator layer on top of the same canonical phases
- move `Script_24`, `25`, and `26` under a dedicated bridge stage area
- keep the shell wrapper for simulator lifecycle, but reduce profile-specific deployment logic embedded in shell where possible

### `base_main/` and `ethereum_main/`

Recommendation:

- keep as standalone production deployment entrypoints
- move under `scripts/foundry/mainnet/`
- document them as targeted production deployers, not part of the generic staged dev pipeline

### `local/` and `local/segmented/`

Recommendation:

- move under `scripts/foundry/legacy/`
- do not delete until any unique setup logic has either been ported or declared intentionally obsolete
- preserve `local_segments.sh` only if it is still useful for manual bring-up or debugging

## Naming Recommendations

### 1. Prefer phase names over environment names in filenames

Good:

- `Stage_07_Pools_NonWeth.s.sol`
- `Stage_04_ProtocolCores_Aerodrome.s.sol`

Less good:

- `Script_05_NonWethBalancerPools.s.sol`

Because the latter mixes environment-specific policy with what is really just a pool-deployment override.

### 2. Remove stale family names from generic stage files

Examples to revisit:

- `DeployProtocolDETF`
- `ConfigureProtocolDetfBridge`

Recommendation:

- rename once the intended active family naming is settled
- until then, isolate those names to profile wrappers rather than canonical stage files

### 3. Standardize artifact names by phase

Every stage should emit predictable artifact names, such as:

- `01_factories.json`
- `02_shared_facets.json`
- `03_core_platform.json`
- `07_pools.json`
- `14_single_vault_detf.json`
- `20_bridge_infra.json`

Avoid artifact names that depend on the exact historical script filename.

## Recommended Migration Order

### Phase 1: Documentation and naming map

- define the canonical phase table in docs
- map every current active script to one canonical phase
- mark `legacy/` candidates

### Phase 2: Directory normalization

- create the new `stages/`, `profiles/`, `bridge/`, `mainnet/`, and `legacy/` directories
- move files without changing logic yet
- add alias wrappers if needed to avoid breaking callers immediately

### Phase 3: Orchestrator thinning

- reduce `Script_DeployAll` files to profile/env wiring and stage calls
- reduce shell wrappers to preflight, invocation, and export/cleanup

### Phase 4: Naming cleanup

- rename stale `ProtocolDETF` stage labels where appropriate
- rename environment-specific override files to fit the canonical phase taxonomy

### Phase 5: Legacy isolation

- move old `local/` and demo flows into `legacy/`
- add a short README for what remains supported versus historical

## Proposed “Supported” Entry Points

After reorganization, the supported entrypoints should be explicit and few.

Recommended supported entrypoints:

- single-chain local Base profile
- single-chain local Sepolia profile
- public Sepolia Ethereum profile
- public Sepolia Base profile
- SuperSim Ethereum profile
- SuperSim Base profile
- Base mainnet standalone deploy
- Ethereum mainnet standalone deploy

Everything else should either be:

- a reusable stage implementation
- a thin profile wrapper
- or explicitly marked legacy

## Recommended Output File Set

Each supported profile should write a predictable minimum set:

- `chain_manifest.json`
- one JSON per canonical phase that ran
- `deployment_summary.json`
- tokenlist exports where applicable
- frontend export artifacts where applicable

This keeps resumability, troubleshooting, and cross-profile automation simple.

## Bottom Line

The repo does not need a brand-new deployment architecture. It already has one.

What it needs is:

- one canonical phase taxonomy
- thinner profile wrappers
- a hard separation between active staged deployment code and legacy/local scaffolding
- removal of stale family naming from generic stage files

If you adopt that structure, the deployment system becomes easier to reason about, easier to resume, easier to automate, and much less noisy to review.