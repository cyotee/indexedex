**Purpose**

This document is a handoff prompt for redesigning the IndexedEx SuperSim local deployment flow so it simulates the public Sepolia deployment environments instead of wrapping the existing `anvil_base_main` and `anvil_sepolia` scripts.

The primary end goal is a local Ethereum Sepolia fork plus Base Sepolia fork under SuperSim where:

- Ethereum-only infrastructure is deployed only on Ethereum.
- Base-only infrastructure is deployed only on Base.
- Shared protocol pieces are deployed independently per chain against that chain's real forked dependencies.
- Cross-chain bridge wiring is bootstrapped after both chain-local stacks exist.
- Frontend artifacts are exported from these SuperSim deployments directly, not by pretending the environment is just another Anvil profile.
- Frontend address bundles, tokenlists, contractlists, and a generated typed frontend registry are exported per environment and per chain, then selected from the connected wallet chain plus an explicit developer-facing environment toggle instead of hardcoded filename families.
- The local SuperSim stage graph matches the public Sepolia deployment stage graph closely enough that local validation is a real rehearsal for public Sepolia deployment.

This is primarily a deployment-architecture task, not a bridge-logic task.

Mainnet is out of scope for the first implementation. Mainnet requirements are included only as reference context for how the Sepolia-focused design should eventually relate to production, but the scripts to build now are Sepolia and Base Sepolia scripts first.

**Problem Statement**

The current SuperSim wrapper at `scripts/foundry/supersim/deploy_mainnet_bridge_ui.sh` is not a true environment setup. It currently:

- calls the old `anvil_sepolia` deployment wrapper for the Ethereum side,
- calls the old `anvil_base_main` deployment wrapper for the Base side,
- inherits stage assumptions and output formats from those local-development scripts,
- writes frontend outputs into the `anvil_base_main` artifact bucket,
- and therefore does not model the natural split between Ethereum and Base production environments.

That is the wrong abstraction.

Examples of the mismatch:

- Aerodrome is Base-specific and should not be part of Ethereum deployment planning.
- Ethereum-side deployment should not inherit Anvil/Sepolia staging assumptions.
- Frontend exports should not be published under `frontend/app/addresses/anvil_base_main` for a SuperSim Sepolia-fork environment.
- A production-like SuperSim stack should have its own deployment manifests, chain-local stage scripts, and exported frontend artifact family.
- The local simulation should mirror public Sepolia deployment assumptions rather than mainnet-only assumptions.
- Ethereum Sepolia requires special handling for Uniswap V2 because the public Uniswap V2 Sepolia instance uses a different WETH9 than the Ethereum Sepolia Balancer V3 deployment used by IndexedEx.

**High-Level Objective**

Design and implement a new SuperSim deployment flow that treats Ethereum and Base as separate chain environments with separate deployment plans, while still being easy to run locally and aligned with the public Sepolia deployment plan.

Required result:

1. One command boots or reuses SuperSim with Ethereum Sepolia + Base Sepolia forks.
2. Ethereum deployment runs through Ethereum-specific SuperSim scripts only.
3. Base deployment runs through Base-specific SuperSim scripts only.
4. Chain-local dependencies match Sepolia deployment reality:
  - Ethereum uses Ethereum Sepolia constants and Ethereum-specific protocol integrations.
  - Base uses Base Sepolia constants and Base-specific protocol integrations such as Aerodrome where applicable.
5. The local SuperSim Sepolia scripts and the public Sepolia deployment scripts share the same chain-local architecture and dependency assumptions.
6. Ethereum Sepolia deployment includes a local deployment of the Uniswap V2 stack used by IndexedEx.
7. That self-deployed Ethereum Sepolia Uniswap V2 stack must use the same WETH9 address as the Ethereum Sepolia Balancer V3 deployment used by IndexedEx.
8. This is required specifically because the public Ethereum Sepolia Uniswap V2 instance uses a different WETH9 than the Balancer V3 side of the Sepolia deployment, which breaks the cross-dex demonstration if we rely on the public deployment.
9. Mainnet behavior may be retained in design notes as background context only; it is not part of the first implementation scope.
10. The deployment plan must include test tokens, test pools, and test vaults needed for the cross-dex demonstration.
11. Uniswap V2 pools and Uniswap V2-backed vaults used by the demo must be deployed on the Ethereum fork.
12. Aerodrome pools and Aerodrome-backed vaults used by the demo must be deployed on the Base fork.
13. Balancer V3 pools containing the relevant test tokens and vaults must be deployed on the same fork as those test tokens and vaults.
14. Cross-chain bridge infrastructure is deployed only after both chain-local deployments complete.
15. For Sepolia SuperSim local deployments, the flow must preserve the current behavior of sweeping the Anvil-provided ETH into the deployer address.
16. Frontend artifacts are exported into a dedicated SuperSim environment namespace.
17. The primary deployment orchestration must be implemented as a single top-level Foundry entrypoint.
18. That single top-level Foundry entrypoint may orchestrate multiple deployment phases or subordinate Foundry scripts.
19. This single Foundry orchestration path must be usable for deployment gas estimation.
20. The resulting local UI can talk to SuperSim Ethereum and SuperSim Base without relying on legacy `anvil_*` naming.
21. UI address resolution, tokenlists, contractlists, and menu contents must load from the active wallet chain rather than from hardcoded `sepolia` or `anvil_base_main` filename assumptions.
22. The frontend migration plan must cover how deployment output becomes UI-consumable artifacts for both local SuperSim Sepolia rehearsal and public Sepolia deployments.
23. The frontend must expose a visible developer-facing environment toggle to switch between `sepolia` and `supersim_sepolia` while still using wallet `chainId` as the source of chain role selection.
24. The frontend registry file should be generated into the frontend in the correct location and used as the runtime source of truth for `{ environment, chainId } -> artifact bundle` resolution.
25. Wagmi may still be used for ABI-driven typed hooks, but environment-specific address selection should happen in the frontend runtime registry layer rather than in wagmi deployment mappings.

**Non-Negotiable Constraints**

- Do not reuse `scripts/foundry/anvil_base_main/deploy_all.sh` as the Base deployment entrypoint for the final design.
- Do not reuse `scripts/foundry/anvil_sepolia/deploy_sepolia.sh` as the Ethereum deployment entrypoint for the final design.
- Do not model Ethereum deployment as a renamed Sepolia environment.
- Do not publish SuperSim frontend outputs into `frontend/app/addresses/anvil_base_main`.
- Do not assume the same stage list or same dependency mix on Ethereum and Base.
- Do not assume public Ethereum Sepolia Uniswap V2 can be used unchanged for this demo environment.
- Do not couple IndexedEx Ethereum Sepolia deployment to a Uniswap V2 deployment that uses a different WETH9 than the Balancer V3 side of the same chain-local environment.
- Do not expand first-pass implementation scope to include mainnet deployment automation.
- Do not deploy Ethereum-specific demo pools or vaults on the Base fork.
- Do not deploy Base-specific demo pools or vaults on the Ethereum fork.
- Do not deploy Balancer V3 demo pools on a fork that does not also contain the underlying test tokens and vaults those pools are meant to compose.
- Do not drop the existing local funding ergonomics where Anvil-provided ETH is consolidated to the deployer during local Sepolia rehearsal flows.
- Do not make shell scripts the only orchestration path for the new deployment system.
- Do not require a shell-only workflow for obtaining deployment gas estimates.
- Do not keep the current frontend artifact model where `frontend/app/lib/addressArtifacts.ts` hardcodes only `sepolia` and `anvil_base_main` bundles.
- Do not keep mapping Base chain IDs onto the Anvil artifact family as a long-term solution.
- Do not keep tokenlist or contractlist selection dependent on filename suffix dispatch like `sepolia-*.tokenlist.json` and `anvil_base_main-*.tokenlist.json`.
- Do not leave wagmi deployment generation wired only to the legacy committed address buckets if the new deployment families become the source of truth.
- Do not make runtime environment selection depend on guessing wallet RPC URLs.
- Do not rely on wagmi deployment mappings alone when multiple environments share the same chain IDs.
- Keep CREATE3 / package / factory deployment rules intact. No `new` in production deployment scripts.
- Preserve the natural split between chain-specific integrations:
  - Base-only integrations stay Base-only.
  - Ethereum-only integrations stay Ethereum-only.
- Ensure local SuperSim Sepolia scripts and public Sepolia deployment scripts are designed as siblings, not as unrelated one-offs.
- Prefer shared helpers only where they are truly chain-agnostic, such as JSON IO, env parsing, stage logging, and frontend export utilities.

**Current State To Replace**

The existing wrapper and helpers worth inspecting before changing anything:

- `scripts/foundry/supersim/deploy_mainnet_bridge_ui.sh`
- `scripts/foundry/supersim/Script_24_DeploySuperchainBridgeInfra.s.sol`
- `scripts/foundry/supersim/Script_25_ConfigureProtocolDetfBridge.s.sol`
- `scripts/foundry/anvil_base_main/deploy_all.sh`
- `scripts/foundry/anvil_base_main/DeploymentBase.sol`
- `scripts/foundry/anvil_sepolia/deploy_sepolia.sh`
- `scripts/foundry/anvil_sepolia/DeploymentBase.sol`
- `scripts/foundry/base_main/Script_BaseMain_DeployIndexedex.s.sol`
- `scripts/foundry/ethereum_main/Script_DeployRichToken.s.sol`
- `frontend/app/lib/addressArtifacts.ts`
- `frontend/app/lib/tokenlists.ts`
- `frontend/app/lib/contractlists.ts`
- `frontend/wagmi.config.ts`

You should treat the current SuperSim wrapper as an interim compatibility layer to replace, not a foundation to preserve.

You should also treat the current public testnet deployment flow as incomplete for the Sepolia cross-dex demonstration until it explicitly handles the Ethereum Sepolia Uniswap V2 + Balancer V3 WETH9 mismatch.

You should also treat the current frontend artifact system as intentionally transitional. Right now:

- `frontend/app/lib/addressArtifacts.ts` imports only two artifact families: `sepolia` and `anvil_base_main`.
- `resolveArtifactsChainId(...)` currently collapses Base and localhost-style development chains into the Anvil artifact family.
- `frontend/wagmi.config.ts` imports only the legacy committed deployment JSON and maps Base hooks to the foundry/anvil deployment addresses.
- `frontend/app/lib/tokenlists.ts` loads chain data through `getAddressArtifacts(chainId)`.
- `frontend/app/lib/contractlists.ts` resolves UI option sources by matching hardcoded filename suffixes.
- the current frontend does not yet have a visible environment toggle that distinguishes public Sepolia from local SuperSim Sepolia while preserving the same chain IDs.

That entire model needs to be upgraded so deployment artifacts are selected by environment plus connected-wallet chain, not by pretending multiple environments are the same artifact bucket.

**Design Target**

Build a SuperSim environment with three layers:

Orchestration requirement:

- The deployment plan must have a single Foundry entrypoint for the full environment, either by implementing the whole flow in one script or by using one top-level Foundry script as the orchestrator over multiple phases or subordinate Foundry scripts.
- Shell wrappers may still exist for convenience, environment bootstrapping, or operator ergonomics, but they must be secondary to the Foundry orchestration path.
- The Foundry orchestration path must make deployment gas estimation practical even if the top-level Foundry entrypoint orchestrates multiple phases.

Layer 1: SuperSim lifecycle

- Start or reuse SuperSim Sepolia forks.
- Verify L1 and L2 RPC readiness.
- Keep logs and PIDs under a dedicated SuperSim directory.
- Preserve the local funding flow that sweeps the Anvil-provided ETH into the deployer address for local Sepolia SuperSim runs.
- Treat the Ethereum Sepolia fork and the Base Sepolia fork as separate Anvil-backed local chains, each with its own funded dev wallets and therefore its own local sweep-to-deployer behavior.

Layer 2: Chain-local deployments

- Ethereum deployment pipeline
  - deploy only Ethereum-relevant contracts and packages,
  - consume Ethereum Sepolia canonical dependencies from the Ethereum fork except where Sepolia-specific incompatibilities require local deployment,
  - explicitly deploy the Uniswap V2 contracts needed by IndexedEx on Ethereum Sepolia so they share the correct WETH9 address with the Balancer V3 side used by IndexedEx on that chain,
  - deploy Ethereum-side test tokens needed for the Sepolia demo,
  - deploy Uniswap V2 pools for the Ethereum-side demo tokens,
  - deploy Ethereum-side vaults backed by those Uniswap V2 pools,
  - deploy Balancer V3 pools on Ethereum for the Ethereum-side test tokens and vaults that belong on that fork,
  - produce Ethereum-specific deployment outputs under a dedicated SuperSim Ethereum directory.

- Base deployment pipeline
  - deploy only Base-relevant contracts and packages,
  - consume Base Sepolia canonical dependencies from the Base fork,
  - deploy Base-side test tokens needed for the Sepolia demo, where those tokens are the Base bridge-token counterparts of the Ethereum-side test tokens,
  - deploy Aerodrome pools for the Base-side demo tokens,
  - deploy Base-side vaults backed by those Aerodrome pools,
  - deploy Balancer V3 pools on Base for the Base-side test tokens and vaults that belong on that fork,
  - produce Base-specific deployment outputs under a dedicated SuperSim Base directory.

Layer 3: Cross-chain bootstrapping

- deploy Superchain bridge helper contracts on each fork,
- register remote token mappings,
- approve aliased senders,
- initialize DETF bridge config on both sides,
- export frontend-ready artifacts for both chains.

**Required Architecture Changes**

1. Create dedicated SuperSim deployment families

Introduce a dedicated deployment namespace for this environment, for example:

- `deployments/supersim_sepolia/ethereum/`
- `deployments/supersim_sepolia/base/`
- `deployments/supersim_sepolia/shared/`

or an equivalent structure that clearly separates chain-local outputs.

Do not keep using:

- `deployments/supersim_ethereum_main`
- `deployments/supersim_base_main`

if those remain little more than redirected `anvil_*` outputs.

2. Introduce chain-specific SuperSim stage runners

Create two new local SuperSim chain deployment flows that are first-class citizens:

- one for Ethereum-on-SuperSim
- one for Base-on-SuperSim

Possible internal shape:

- `scripts/foundry/supersim/ethereum/Script_DeployAll.s.sol`
- `scripts/foundry/supersim/base/Script_DeployAll.s.sol`

and corresponding Solidity stage scripts or deployment bases beneath those folders.

These should not be thin wrappers around the Anvil scripts. They should own their own stage order and dependency assumptions.

Above them, require a single Foundry orchestration script for the whole environment, for example:

- `scripts/foundry/supersim/Script_DeploySepoliaEnvironment.s.sol`

That top-level Foundry script may call into the Ethereum-side and Base-side deployment scripts or libraries, then run the shared post-deploy bridge bootstrap.

In parallel, define or update sibling public Sepolia deployment entrypoints that share the same chain split and dependency model.

3. Split chain-local deployment bases

Create dedicated SuperSim deployment base contracts or helpers for each chain, for example:

- `scripts/foundry/supersim/ethereum/DeploymentBase.sol`
- `scripts/foundry/supersim/base/DeploymentBase.sol`

They should:

- read/write to SuperSim chain-local output directories,
- bind the correct chain-specific canonical addresses,
- expose only the dependencies relevant for that chain,
- avoid leaking Base-specific integrations into Ethereum or vice versa.

4. Make stage composition production-like

Expected deployment split:

Ethereum chain should include only what Ethereum production would actually have, such as:

- shared factory/core infra,
- Ethereum RICH token and Ethereum DETF stack,
- Ethereum-side test tokens,
- Uniswap V2-related integrations used by the Ethereum DETF,
- a self-deployed Ethereum Sepolia Uniswap V2 stack wired to the same WETH9 address as the Balancer V3 side used by IndexedEx for Sepolia cross-dex behavior,
- Ethereum-side Uniswap V2 pools,
- Ethereum-side vaults backed by those Uniswap V2 pools,
- Ethereum-side Balancer V3 pools for Ethereum-side test tokens and vaults,
- Ethereum-side bridge infra bootstrap.

Base chain should include only what Base production would actually have, such as:

- shared factory/core infra for that chain,
- Base DETF stack,
- Base-side test tokens,
- Aerodrome-related integrations,
- Base-side Aerodrome pools,
- Base-side vaults backed by those Aerodrome pools,
- Balancer-related pieces that exist on Base,
- Base-side Balancer V3 pools for Base-side test tokens and vaults,
- Base-side bridge infra bootstrap.

Do not mirror all Ethereum steps onto Base or all Base steps onto Ethereum just to keep stage numbering symmetrical.

5. Separate frontend artifact export from Anvil conventions

Create a dedicated frontend artifact family for SuperSim, for example:

- `frontend/app/addresses/supersim_sepolia/ethereum_deployments.json`
- `frontend/app/addresses/supersim_sepolia/base_deployments.json`

and any tokenlist or manifest files the UI needs beside them.

Update frontend resolution so the SuperSim environment is selected deliberately, not by pretending Base mainnet local artifacts are `anvil_base_main`.

This may require changes in:

- `frontend/app/lib/addressArtifacts.ts`
- `frontend/app/lib/tokenlists.ts`
- `frontend/app/lib/contractlists.ts`
- `frontend/wagmi.config.ts`
- any frontend environment or network selection code that currently assumes only `anvil_base_main` and `sepolia` style buckets.

Preferred frontend migration shape:

- Export one chain-local artifact bundle per environment and chain.
- Add a generated typed registry or index module that maps `{ environment, chainId }` to the correct deployment bundle, tokenlists, and contractlists.
- Make `addressArtifacts.ts` resolve an artifact bundle from explicit environment-plus-chain metadata rather than a two-family chain ID collapse.
- Keep filename details behind that registry so `tokenlists.ts` and `contractlists.ts` consume logical bundle properties instead of matching suffix strings.
- Make connected-wallet chain selection the runtime source of truth for which addresses and menus the UI loads.
- Make a visible developer-facing environment toggle the runtime source of truth for `sepolia` versus `supersim_sepolia` bundle selection.
- Keep wagmi for generated ABI-driven hooks if useful, but move environment-specific address selection into the frontend registry/runtime resolver layer.

The local SuperSim environment and the public Sepolia environment should therefore be two distinct frontend artifact families that share the same logical shape.

6. Keep bridge bootstrap as a separate post-deploy phase

The bridge setup scripts are still useful conceptually, but they should consume the new chain-local manifests rather than the old redirected Anvil output layout.

If helpful, keep or replace:

- `Script_24_DeploySuperchainBridgeInfra.s.sol`
- `Script_25_ConfigureProtocolDetfBridge.s.sol`

but make them read from the new SuperSim deployment structure and explicit chain manifests.

**Implementation Plan**

Step 1: Audit and document the chain split

- Explicitly list which deployment stages are Ethereum-only, Base-only, and shared.
- Identify where the current `anvil_*` scripts incorrectly assume both chains share the same stage graph.
- Identify every place where frontend export still assumes `anvil_base_main` naming.
- Identify exactly which Ethereum Sepolia dependencies can be used canonically and which must be self-deployed for IndexedEx compatibility.
- Document the WETH9 mismatch between public Ethereum Sepolia Uniswap V2 and the Balancer V3 side used by IndexedEx on Ethereum Sepolia, and encode that as an explicit design driver.
- Enumerate which test tokens, pools, and vaults belong on Ethereum versus Base for the demo.
- Enumerate which Balancer V3 pools belong on Ethereum and which belong on Base based on the location of their underlying test tokens and vaults.

Step 2: Create dedicated SuperSim deployment directories and manifest conventions

- Define the output directory layout.
- Define canonical manifest filenames for chain-local outputs.
- Define where bridge bootstrap scripts will read local and remote manifests from.
- Define how the local Sepolia SuperSim flows preserve the current ETH sweep-to-deployer behavior and where that runs in the stage order.
- Define the frontend export layout and a canonical registry format that the UI can import without filename-specific branching.
- Define how local SuperSim Sepolia and public Sepolia deployments produce the same logical artifact schema even if they live under different environment namespaces.
- Ensure the chain-local manifests include both addresses from our own deployment and all required external dependency addresses consumed from the fork.

Step 3: Create Ethereum-specific SuperSim deployment flow

- Add or adapt Ethereum-specific Foundry deployment scripts under a SuperSim Ethereum folder.
- Ensure the flow uses Ethereum Sepolia chain constants and only Ethereum-relevant protocol integrations.
- Ensure the flow includes self-deployment of the Ethereum Sepolia Uniswap V2 contracts required by IndexedEx.
- Ensure those contracts are configured against the same Ethereum Sepolia WETH9 address used by the Balancer V3 side of the demo.
- Ensure the flow deploys the Ethereum-side demo test tokens.
- Ensure the flow deploys the Ethereum-side Uniswap V2 pools and the vaults that depend on them.
- Ensure the flow deploys the Ethereum-side Balancer V3 pools that contain Ethereum-side test tokens and vaults.
- Ensure the local Sepolia SuperSim Ethereum flow preserves the existing ETH sweep-to-deployer behavior.
- Ensure outputs land only in the SuperSim Ethereum manifest directory.

Step 4: Create Base-specific SuperSim deployment flow

- Add or adapt Base-specific Foundry deployment scripts under a SuperSim Base folder.
- Ensure the flow uses Base Sepolia chain constants and Base-specific integrations such as Aerodrome.
- Ensure the flow deploys the Base-side demo test tokens as the Base bridge-token counterparts of the Ethereum-side test tokens.
- Ensure the flow deploys the Base-side Aerodrome pools and the vaults that depend on them.
- Ensure the flow deploys the Base-side Balancer V3 pools that contain Base-side test tokens and vaults.
- Ensure the local Sepolia SuperSim Base flow preserves the existing ETH sweep-to-deployer behavior.
- Ensure outputs land only in the SuperSim Base manifest directory.

Step 4.5: Align public Sepolia deployment flows with the same chain split

- Define the public Sepolia deployment entrypoints and output structure so they mirror the local SuperSim Sepolia architecture.
- Do not allow the public Sepolia deployment plan to diverge from the local rehearsal plan on the Ethereum/Base split or the Ethereum Sepolia Uniswap V2 requirement.
- Concrete public Sepolia deployment implementation may follow in a second pass after local SuperSim is working.

Step 5: Replace the wrapper orchestration

- Add a single top-level Foundry orchestration script that runs the full Sepolia SuperSim environment deployment.
- That Foundry orchestration script may call into Ethereum-side and Base-side deployment scripts or shared deployment libraries across multiple phases.
- If `scripts/foundry/supersim/deploy_mainnet_bridge_ui.sh` remains, reduce it to a convenience wrapper around the Foundry orchestration path plus SuperSim process management only.
- Keep SuperSim lifecycle management in the shell layer only where Foundry cannot reasonably own process startup.
- Keep bridge post-configuration inside the Foundry orchestration path or in Foundry scripts it invokes.
- Ensure the deployment can be simulated or estimated through the single Foundry orchestration path even when that path orchestrates multiple phases.

Step 6: Export dedicated frontend artifacts

- Write chain-local deployment JSON to a new SuperSim frontend namespace.
- Export any tokenlists or pool manifests the UI needs from the new SuperSim stage outputs.
- Export contractlists or other UI metadata in the same chain-local namespace where appropriate.
- Generate a typed frontend registry/index file in the correct frontend location that maps environment plus chain ID to the exported addresses, tokenlists, and contractlists.
- Update frontend artifact resolution to support the new namespace directly.
- Ensure the migration plan covers both local SuperSim Sepolia outputs and public Sepolia outputs, not just one environment.

Step 6.5: Make frontend loading chain-aware

- Refactor `frontend/app/lib/addressArtifacts.ts` so it resolves bundles from the connected wallet chain and the selected environment, instead of hardcoding only `sepolia` and `anvil_base_main`.
- Add a visible developer-facing environment toggle so the app can explicitly switch between `sepolia` and `supersim_sepolia` while preserving the same chain IDs.
- Refactor `frontend/app/lib/tokenlists.ts` so it reads tokenlists from the resolved bundle object rather than inferring behavior from legacy filenames.
- Refactor `frontend/app/lib/contractlists.ts` so UI options and labels come from logical manifest entries, not suffix checks against `sepolia-*` or `anvil_base_main-*` filenames.
- Update `frontend/wagmi.config.ts` so a single generated `app/generated.ts` can still be used for ABI-driven typed hooks, while environment-specific address selection moves into the frontend registry/runtime resolver layer.
- Review UI pages that already use `useChainId` and make their menus/content load the correct chain-local data set for the active wallet chain.
- Remove or update hardcoded UI copy that references legacy files such as `anvil_base_main-*.tokenlist.json`.

Step 7: Validate the environment end-to-end

- Confirm both chain-local deployments succeed independently.
- Confirm bridge infra deploy/config scripts read the new manifests correctly.
- Confirm the frontend can resolve both Ethereum and Base SuperSim deployments.
- Confirm a local bridge flow can be tested from the UI without manual artifact copying.
- Confirm the frontend shows Ethereum-side menus and assets when the wallet is on the Ethereum environment, and Base-side menus and assets when the wallet is on the Base environment.

**Recommended File Layout**

This exact naming is flexible, but the structure should be explicit and chain-local:

- `scripts/foundry/supersim/deploy_mainnet_bridge_ui.sh`
- `scripts/foundry/supersim/Script_DeploySepoliaEnvironment.s.sol`
- `scripts/foundry/supersim/ethereum/Script_DeployAll.s.sol`
- `scripts/foundry/supersim/ethereum/DeploymentBase.sol`
- `scripts/foundry/supersim/ethereum/Script_01_...s.sol`
- `scripts/foundry/supersim/ethereum/Script_02_...s.sol`
- `scripts/foundry/supersim/base/Script_DeployAll.s.sol`
- `scripts/foundry/supersim/base/DeploymentBase.sol`
- `scripts/foundry/supersim/base/Script_01_...s.sol`
- `scripts/foundry/supersim/base/Script_02_...s.sol`
- `scripts/foundry/supersim/shared/Script_DeploySuperchainBridgeInfra.s.sol`
- `scripts/foundry/supersim/shared/Script_ConfigureProtocolDetfBridge.s.sol`

The key requirement is not the folder names themselves. The key requirement is that Ethereum and Base flows are first-class and no longer delegated to legacy Anvil wrappers.

**Concrete File-By-File Execution Plan**

Use this section as the implementation order of operations. Each file listed below should either be created, refactored, or explicitly left in compatibility mode with a short reason.

1. SuperSim entrypoint and process wrapper

- `scripts/foundry/supersim/Script_DeploySepoliaEnvironment.s.sol`
  - Create this as the single top-level Foundry entrypoint.
  - Make it orchestrate the full environment in order: Ethereum chain-local deploy, Base chain-local deploy, shared bridge bootstrap, frontend export.
  - Make it the canonical path for simulation and deployment gas estimation.
- `scripts/foundry/supersim/deploy_mainnet_bridge_ui.sh`
  - Keep only as an operator convenience wrapper if still needed.
  - Remove legacy deployment responsibility from it.
  - Limit it to: starting or reusing SuperSim, exporting env vars, invoking the single top-level Foundry entrypoint, and optionally launching the frontend.
  - Stop calling `scripts/foundry/anvil_sepolia/deploy_sepolia.sh` and `scripts/foundry/anvil_base_main/deploy_all.sh` as primary deployment paths.

2. Shared SuperSim deployment helpers

- `scripts/foundry/supersim/DeploymentBase.sol`
  - Create a shared base only for chain-agnostic concerns.
  - Move shared JSON IO, output directory helpers, stage logging, frontend export helpers, and common environment parsing here.
  - Do not put chain-specific addresses or protocol assumptions here.
- `scripts/foundry/supersim/SuperSimManifestLib.sol`
  - Create a manifest helper library if the shared base becomes too large.
  - Centralize manifest paths, read/write helpers, and typed structs for local outputs.
  - Use it from both chain-local deployers and bridge bootstrap scripts.

3. Ethereum SuperSim deployment flow

- `scripts/foundry/supersim/ethereum/DeploymentBase.sol`
  - Create as the Ethereum-specific deployment base.
  - Bind Ethereum Sepolia constants, Ethereum-side canonical dependencies, output directories, and ETH sweep behavior for the local Ethereum fork.
- `scripts/foundry/supersim/ethereum/Script_DeployAll.s.sol`
  - Create as the Ethereum chain-local orchestrator.
  - Compose the Ethereum-only stages in the correct order and write a complete Ethereum manifest.
- `scripts/foundry/supersim/ethereum/Script_01_CoreInfra.s.sol`
  - Create or equivalent.
  - Deploy chain-local Crane/core/manager/registry infrastructure required on Ethereum.
- `scripts/foundry/supersim/ethereum/Script_02_UniswapV2.s.sol`
  - Create or equivalent.
  - Self-deploy the Ethereum Sepolia Uniswap V2 stack used by IndexedEx.
  - Ensure the deployment uses the same `WETH9` address as the Ethereum Sepolia Balancer V3 side required by the demo.
- `scripts/foundry/supersim/ethereum/Script_03_TestTokens.s.sol`
  - Create or equivalent.
  - Deploy or configure the Ethereum-side test tokens needed for the demo.
- `scripts/foundry/supersim/ethereum/Script_04_UniV2PoolsAndVaults.s.sol`
  - Create or equivalent.
  - Deploy the Ethereum-side Uniswap V2 pools and the vaults backed by them.
- `scripts/foundry/supersim/ethereum/Script_05_BalancerPools.s.sol`
  - Create or equivalent.
  - Deploy the Ethereum-side Balancer V3 pools whose underlying assets live on Ethereum.

4. Base SuperSim deployment flow

- `scripts/foundry/supersim/base/DeploymentBase.sol`
  - Create as the Base-specific deployment base.
  - Bind Base Sepolia constants, Base-side canonical dependencies, output directories, and ETH sweep behavior for the local Base fork.
- `scripts/foundry/supersim/base/Script_DeployAll.s.sol`
  - Create as the Base chain-local orchestrator.
  - Compose the Base-only stages in the correct order and write a complete Base manifest.
- `scripts/foundry/supersim/base/Script_01_CoreInfra.s.sol`
  - Create or equivalent.
  - Deploy chain-local Crane/core/manager/registry infrastructure required on Base.
- `scripts/foundry/supersim/base/Script_02_TestTokens.s.sol`
  - Create or equivalent.
  - Deploy or configure the Base-side test tokens needed for the demo.
- `scripts/foundry/supersim/base/Script_03_AerodromePoolsAndVaults.s.sol`
  - Create or equivalent.
  - Deploy the Base-side Aerodrome pools and the vaults backed by them.
- `scripts/foundry/supersim/base/Script_04_BalancerPools.s.sol`
  - Create or equivalent.
  - Deploy the Base-side Balancer V3 pools whose underlying assets live on Base.

5. Bridge bootstrap and post-deploy wiring

- `scripts/foundry/supersim/Script_24_DeploySuperchainBridgeInfra.s.sol`
  - Refactor to stop reading legacy redirected Anvil outputs.
  - Make it consume the new Ethereum and Base manifests produced by the chain-local SuperSim deployers.
  - Restrict it to bridge helper deployment and shared post-deploy addresses that require both sides to exist.
- `scripts/foundry/supersim/Script_25_ConfigureProtocolDetfBridge.s.sol`
  - Refactor to read from the same new manifests.
  - Make it configure token mappings, approved senders, peer DETFs, and relay configuration only after both chain-local deploys succeed.
- `scripts/foundry/supersim/shared/Script_DeploySuperchainBridgeInfra.s.sol`
  - Create this only if splitting bridge deployment into a new `shared/` folder makes the ownership cleaner.
  - If this is created, migrate behavior out of the existing root-level script and leave the old path as a thin compatibility shim or delete it.
- `scripts/foundry/supersim/shared/Script_ConfigureProtocolDetfBridge.s.sol`
  - Same guidance as above for the configuration phase.

6. Public Sepolia sibling entrypoints

- `scripts/foundry/sepolia/ethereum/Script_DeployAll.s.sol`
  - Define now, implement in the second pass after local SuperSim unless needed sooner.
  - Ensure it also self-deploys the required Uniswap V2 stack.
- `scripts/foundry/sepolia/base/Script_DeployAll.s.sol`
  - Define now, implement in the second pass after local SuperSim unless needed sooner.
- `scripts/foundry/sepolia/Script_DeploySepoliaEnvironment.s.sol`
  - Define now, implement in the second pass after local SuperSim unless needed sooner.
  - Keep its internal architecture parallel to the local SuperSim orchestration path.

7. Deployment output directories and manifest files

- `deployments/supersim_sepolia/ethereum/`
  - Create as the canonical Ethereum local rehearsal output directory.
  - Store platform addresses, factory addresses, tokenlists, contractlists, and any chain-local metadata here.
- `deployments/supersim_sepolia/base/`
  - Create as the canonical Base local rehearsal output directory.
- `deployments/supersim_sepolia/shared/`
  - Create for bridge/bootstrap outputs that depend on both chain manifests.
- `deployments/sepolia/ethereum/`
  - Create or normalize as the public Ethereum Sepolia output directory with the same logical schema.
- `deployments/sepolia/base/`
  - Create or normalize as the public Base Sepolia output directory with the same logical schema.

8. Frontend artifact export targets

- `frontend/app/addresses/supersim_sepolia/ethereum/`
  - Create as the local Ethereum frontend artifact namespace.
  - Export the Ethereum deployment JSON, tokenlists, and contractlists here.
- `frontend/app/addresses/supersim_sepolia/base/`
  - Create as the local Base frontend artifact namespace.
- `frontend/app/addresses/sepolia/ethereum/`
  - Create or normalize as the public Ethereum Sepolia frontend artifact namespace if the repo is currently flattening everything into one `sepolia/` bucket.
- `frontend/app/addresses/sepolia/base/`
  - Create or normalize as the public Base Sepolia frontend artifact namespace.
- `frontend/app/addresses/index.ts`
  - Create a generated typed registry barrel that maps environment plus chain to logical bundle imports.
  - Use this as the only direct import surface for frontend runtime resolution.

9. Frontend address and artifact resolution

- `frontend/app/lib/addressArtifacts.ts`
  - Refactor away from hardcoded imports of only `sepolia` and `anvil_base_main`.
  - Replace `resolveArtifactsChainId(...)` with a resolver that understands both selected environment and connected wallet chain.
  - Make it return a logical bundle object from the new registry instead of branching on filename families.
- `frontend/app/lib/tokenlists.ts`
  - Refactor to depend on the resolved bundle fields instead of inferred file suffixes.
  - Keep all token getters chain-aware, but make them environment-aware through the new resolver.
- `frontend/app/lib/contractlists.ts`
  - Refactor to stop matching `sepolia-*` and `anvil_base_main-*` suffixes.
  - Read option and label sources from logical bundle entries or explicit registry metadata.
- `frontend/wagmi.config.ts`
  - Refactor so a single generated `app/generated.ts` remains available for agents and developers.
  - Stop treating wagmi deployment mappings as the source of environment-specific addresses when multiple environments share the same chain IDs.
  - Stop defaulting Base hook addresses to the foundry/anvil bundle once real Base-specific bundles exist.

10. UI pages that currently leak legacy artifact assumptions

- `frontend/app/detf/DetfPageClient.tsx`
  - Remove hardcoded references to legacy artifact filenames in empty-state or fallback copy.
  - Make the empty state refer to the logical environment export process instead.
- `frontend/app/create/page.tsx`
  - Review all contractlist and tokenlist usage and ensure menu contents follow the active wallet chain.
- `frontend/app/portfolio/page.tsx`
  - Review all resolved addresses and lists so the displayed assets match the connected chain.
- `frontend/app/providers.tsx`
  - Add or wire the visible developer-facing environment toggle if this is the right provider layer for app-wide environment selection.
- Any page under `frontend/app/` using `useChainId()` or `getAddressArtifacts(...)`
  - Audit and update so chain-specific menus and actions are driven by the resolved environment-plus-chain bundle.

11. Compatibility cleanup of legacy artifact buckets

- `frontend/app/addresses/anvil_base_main/`
  - Leave temporarily only if a compatibility window is needed.
  - Mark it clearly as legacy and stop making new SuperSim exports target it.
- `frontend/app/addresses/anvil_sepolia/`
  - Audit whether it is still needed.
  - Either migrate it into the new environment model or mark it as legacy-only.
- `scripts/foundry/anvil_base_main/deploy_all.sh`
  - Do not delete unless safe, but stop treating it as part of the new SuperSim architecture.
- `scripts/foundry/anvil_sepolia/deploy_sepolia.sh`
  - Same guidance as above.

12. Validation and diagnostics

- `scripts/foundry/supersim/Script_ValidateEnvironment.s.sol`
  - Create if a dedicated validation script is useful.
  - Verify manifests exist, peer addresses are wired, and required frontend exports are present.
- `frontend/package.json`
  - Update scripts only if needed to regenerate the new registry or wagmi outputs.
  - Keep `npx wagmi generate` or equivalent wired into the updated artifact layout.

**Frontend Requirements**

The frontend portion of this redesign must support a dedicated SuperSim environment.

Required behavior:

- Ethereum SuperSim artifacts are resolved as Ethereum chain data.
- Base SuperSim artifacts are resolved as Base chain data.
- The UI can point at:
  - `http://127.0.0.1:8545` for Ethereum SuperSim,
  - `http://127.0.0.1:9545` for Base SuperSim.
- Frontend address and tokenlist resolution must not depend on `anvil_base_main` filenames for this environment.
- Frontend contractlist and menu resolution must not depend on `sepolia-*` versus `anvil_base_main-*` suffix branching.
- The connected wallet chain must determine which chain-local address bundle, tokenlists, and contractlists are loaded.
- The frontend must support both local SuperSim Sepolia artifacts and public Sepolia artifacts through the same logical registry shape.
- A visible developer-facing environment toggle must determine whether the UI is using `sepolia` or `supersim_sepolia`.
- Wagmi-generated contract hooks may still be used for typing and ABI ergonomics, but deployment addresses must come from the correct environment-and-chain bundle at runtime.
- Ethereum-only menus should show Ethereum-relevant assets and actions when the wallet is on Ethereum.
- Base-only menus should show Base-relevant assets and actions when the wallet is on Base.
- Shared screens should remain chain-aware without requiring manual artifact switching or file copying.

If needed, introduce a new environment name such as `supersim_sepolia` and route all frontend exports through that namespace.

Recommended frontend implementation direction:

- Keep committed frontend artifacts under environment namespaces such as `frontend/app/addresses/sepolia/...` and `frontend/app/addresses/supersim_sepolia/...`.
- Under each environment namespace, keep chain-local files separate for Ethereum and Base.
- Add a generated typed registry layer that exposes logical fields like `platform`, `factories`, `tokens`, `erc4626`, `protocolDetf`, `seigniorageDetfs`, `strategyVaults`, `uniV2Pools`, `aerodromePools`, and `balancerPools` for a resolved environment-plus-chain bundle.
- Make `tokenlists.ts` and `contractlists.ts` depend on those logical fields, not on literal filenames.
- Make page-level menu content use the resolved bundle plus `useChainId()` and the developer-facing environment toggle instead of embedding environment-specific filenames in page copy or fallback logic.
- Keep `app/generated.ts` as a single generated wagmi output if helpful, but treat the frontend registry as the address source of truth.

**Testing and Validation Plan**

At minimum validate:

1. Orchestration validation

- the single top-level Foundry deployment script compiles and runs as the primary orchestration path,
- gas estimation is possible through that single Foundry entrypoint even when it orchestrates multiple phases,
- if shell wrappers remain, they parse cleanly and only provide secondary convenience around the Foundry orchestration path,
- env var validation is explicit,
- missing required RPC env vars fail fast.

2. Build validation

- new Foundry scripts compile,
- legacy scripts are not broken by shared helper extraction.

3. Deployment validation

- Ethereum SuperSim deploy flow completes on L1 fork without Base-only assumptions,
- Ethereum SuperSim deploy flow self-deploys the required Uniswap V2 stack on Ethereum Sepolia,
- that deployed Uniswap V2 stack uses the same WETH9 address as the Balancer V3 side used by IndexedEx on Ethereum Sepolia,
- Ethereum SuperSim deploy flow also deploys the intended Ethereum-side test tokens, Uniswap V2 pools, vaults, and Balancer V3 pools,
- Ethereum SuperSim deploy flow preserves the existing ETH sweep-to-deployer behavior for local runs,
- Base SuperSim deploy flow completes on L2 fork without Ethereum-only assumptions.
- Base SuperSim deploy flow also deploys the intended Base-side test tokens, Aerodrome pools, vaults, and Balancer V3 pools.
- Base SuperSim deploy flow preserves the existing ETH sweep-to-deployer behavior for local runs.

3.5. Public Sepolia validation

- public Ethereum Sepolia deployment flow deploys the required Uniswap V2 stack,
- public Ethereum Sepolia deployment flow also deploys the intended Ethereum-side test tokens, pools, vaults, and Balancer V3 pools,
- public Base Sepolia deployment flow remains chain-correct,
- public Base Sepolia deployment flow also deploys the intended Base-side test tokens, pools, vaults, and Balancer V3 pools,
- the public Sepolia architecture matches the local SuperSim rehearsal architecture.

Note:
- concrete public Sepolia deployment validation may land in the second implementation pass, but the architecture and output schema must be defined now so the local SuperSim implementation does not diverge.

4. Bootstrap validation

- bridge infra deployment completes on both chains,
- DETF bridge config completes in both directions,
- resulting manifests contain the addresses the frontend needs.

5. UI validation

- frontend resolves the SuperSim artifact family,
- frontend can connect to both local RPCs,
- wagmi-generated hooks point to the correct addresses for the active environment and chain,
- tokenlists and contractlists load from the resolved bundle instead of legacy suffix matching,
- Ethereum-connected wallets see Ethereum-side DETFs, pools, vaults, and actions,
- Base-connected wallets see Base-side DETFs, pools, vaults, and actions,
- bridge UI can exercise the local Ethereum <-> Base flow.

**Acceptance Criteria**

- `deploy_mainnet_bridge_ui.sh` no longer calls the legacy `anvil_base_main` or `anvil_sepolia` deployment wrappers as its primary chain deployment mechanism.
- There are first-class SuperSim deployment flows for Ethereum and Base.
- Ethereum deployment does not assume Aerodrome exists.
- Base deployment can still use Base-specific integrations such as Aerodrome.
- The primary local simulation target is Ethereum Sepolia plus Base Sepolia under SuperSim.
- Mainnet deployment automation is explicitly out of scope for the first implementation.
- Ethereum Sepolia deployment includes a self-deployed Uniswap V2 stack for IndexedEx.
- That Ethereum Sepolia Uniswap V2 stack is intentionally required because public Ethereum Sepolia Uniswap V2 uses a different WETH9 than the Balancer V3 side used by IndexedEx on Sepolia.
- Ethereum Sepolia deployment also includes the Ethereum-side demo test tokens, Uniswap V2 pools, Uniswap-backed vaults, and Ethereum-side Balancer V3 pools.
- Base Sepolia deployment also includes the Base-side demo test tokens, Aerodrome pools, Aerodrome-backed vaults, and Base-side Balancer V3 pools.
- Balancer V3 pools are deployed on the fork that contains the test tokens and vaults they are meant to compose.
- Local Sepolia SuperSim deployments preserve the current behavior of sweeping Anvil-provided ETH to the deployer address.
- Public Sepolia deployment scripts and local SuperSim Sepolia scripts share the same chain-local architecture.
- Chain-local outputs are separated and clearly named.
- Frontend artifacts are exported into a dedicated SuperSim namespace.
- Frontend artifact resolution no longer depends on collapsing multiple chains into `anvil_base_main`.
- Tokenlists, contractlists, and the generated frontend registry are organized in a way the UI can select by environment plus connected wallet chain.
- The app exposes a visible developer-facing environment toggle for `sepolia` versus `supersim_sepolia`.
- `app/generated.ts` may remain a single wagmi output, but environment-specific addresses are resolved from the frontend registry at runtime.
- UI menu contents change correctly with the connected wallet chain.
- Bridge bootstrap consumes the new manifests and succeeds after both chain-local deployments finish.
- The full environment can be orchestrated through a single top-level Foundry deployment script even when it internally coordinates multiple phases or subordinate Foundry deployment scripts.
- That Foundry deployment path is suitable for obtaining deployment gas estimates.
- The local UI can test bridge flows against the production-shaped SuperSim environment.

**What Not To Do**

- Do not keep the current architecture and merely rename a few directories.
- Do not continue routing SuperSim through `anvil_sepolia` for Ethereum.
- Do not continue routing SuperSim through `anvil_base_main` for Base.
- Do not hardcode frontend export paths to `anvil_base_main` for this environment.
- Do not leave `frontend/app/lib/addressArtifacts.ts` as a two-family switch that maps Base or localhost chains onto Anvil artifacts.
- Do not leave `frontend/app/lib/contractlists.ts` and `frontend/app/lib/tokenlists.ts` dependent on legacy filename suffix matching for environment selection.
- Do not keep `frontend/wagmi.config.ts` mapping Base deployments to the foundry/anvil address bundle once chain-local SuperSim and Sepolia bundles exist.
- Do not require wagmi deployment mappings to solve environment selection when the same chain IDs exist in both `sepolia` and `supersim_sepolia`.
- Do not create fake symmetry where both chains deploy identical protocol integrations.
- Do not rely on the public Ethereum Sepolia Uniswap V2 deployment if it preserves the WETH9 mismatch with the Balancer V3 side used by IndexedEx on Sepolia.

**Suggested Initial Search Commands**

```bash
rg "anvil_base_main|anvil_sepolia|supersim|FRONTEND_ARTIFACTS_DIR|OUT_DIR_OVERRIDE" scripts/foundry frontend
rg "AERODROME|UNISWAP_V2|BASE_SEPOLIA|ETHEREUM_SEPOLIA|WETH9|BALANCER_V3" scripts/foundry/supersim scripts/foundry/base_main scripts/foundry/ethereum_main scripts/foundry/sepolia
rg "anvil_base_main" frontend/app frontend/wagmi.config.ts scripts/foundry
rg "addressArtifacts|tokenlists|contractlists|useChainId|anvil_base_main-|sepolia-" frontend/app frontend/wagmi.config.ts
```

**Execution Notes**

- Prefer creating a small shared SuperSim helper layer rather than adding more branching into the old Anvil scripts.
- Keep stage numbering local to each chain flow if that makes the architecture cleaner.
- Favor explicitness over DRY if a shared abstraction would blur chain-specific assumptions.
- When in doubt, preserve the deployment mental model: local SuperSim Sepolia is a rehearsal for public Ethereum Sepolia and Base Sepolia, not a special one-off environment.
