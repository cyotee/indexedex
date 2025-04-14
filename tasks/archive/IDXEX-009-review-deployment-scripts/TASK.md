# Task IDXEX-009: Review Deployment Scripts (Factories -> Core -> Packages -> Vaults)

**Repo:** IndexedEx
**Status:** In Progress (Review Complete; Implementation Workstreams Defined)
**Created:** 2026-01-12
**Type:** Code Review
**Dependencies:** None
**Worktree:** N/A (review task)

---

## Description

Code review of deployment scripts. Focus on idempotent staged scripts, deterministic salt usage, JSON state persistence, and correct per-chain configuration.

---

## Required Reading (Directive)

Before implementing or reviewing deployment scripts in this repo:

- Read `AGENTS.md` at the repo root.
- Follow the repo’s CREATE3 / factory deployment rules (no direct `new` deployments for production contracts).

This task’s requirements assume the agent/script follows those conventions.

---

## Deployment Script Requirements (Design)

This section captures the concrete requirements for the “local dev full deployment” Foundry script so this task can be used as an implementation reference.

### Target Environment

- **Node:** Local Anvil instance forking **Base Mainnet**.
- **Fork RPC URL:** Provided in `foundry.toml`.
- **Protocol addresses:** Use the canonical constants in `BASE_MAIN.sol` (e.g., WETH9, Balancer V3 vault/router, Aerodrome router/factory, Uniswap router, etc.).
- **Chain ID:** When Anvil forks a chain, it may report the **forked chain’s chainId** (e.g., forking Base can report `8453`).
  - Do not assume Anvil always uses `31337`.
  - The forked state must contain Base mainnet contracts at their real addresses.

Determinism note (important):
- This task’s “deterministic” requirement means **repeatable and idempotent within the same environment/config** (same chain state + same factory addresses + same salt derivation rules).
- When deploying to testnets/mainnet you will likely use different deployment wallets/infra, and resulting addresses may differ; treat every network as its own address space and export artifacts per chain.

### Output for Frontend

- The deployment script must write chain-specific JSON outputs intended for the UI.
- **Output directory (committed):** `frontend/app/addresses/`.
- **Preferred folder convention (internal systems):** chainId-keyed folders so the UI can load artifacts directly from the connected wallet’s `chainId`.
  - However, chainId alone is not sufficient when multiple environments share the same chainId (e.g., Base mainnet **vs** Anvil forking Base, both reporting `8453`).
  - Therefore, use a **(chainId, context)** folder scheme:
    - `frontend/app/addresses/<chainId>/<context>/...`
    - Where `context` is one of the exact, supported values:
      - `mainnet` (live production chain)
      - `testnet` (live test chain)
      - `anvil_fork` (local Anvil instance forking a live chain; may share chainId with the forked chain)
  - The UI should select `context` from RPC characteristics (e.g., `http://127.0.0.1` => `anvil_fork`) or an explicit env/config override.
- **Optional human-friendly alias (dev ergonomics):** `frontend/app/addresses/anvil_base_main/` can exist as a duplicate export of the same data if desired.
- Output JSON must contain:
  - Core deployment addresses (at minimum: `craneFactory`, `craneDiamondFactory`, `feeCollector`, `indexedexManager`, `vaultRegistry`, `vaultFeeOracle`, `permit2`, `weth9`)
	- All package addresses (see “Package List”)
  - Sample deployed instances per package (recorded in JSON state and exported via derived contractlists/tokenlists; see “Instances / Fixtures”)
  - These `base_deployments.json` files are the primary input to our pipeline: **deployment JSONs are digested into contractlist/tokenlist artifacts**.
  - `base_deployments.json` should include all keys required by the UI, for the **current** chain/environment.
    - Sepolia’s `frontend/app/addresses/sepolia/base_deployments.json` is a **naming reference**, not a hard contract for this Anvil Base-fork workflow.
    - For this task, the authoritative contract is: the Anvil Base-fork deploy script exports a stable set of keys, and the UI is updated (separately) to load the correct folder by chainId/env.

### `base_deployments.json` Key Mapping (Authoritative)

This is the explicit “contract” between the deploy script and the UI: for each key in `frontend/app/addresses/*/base_deployments.json`, this mapping defines what the value *must* be.

Do not invent new key names.
- Prefer reusing existing key names from Sepolia when they match semantics.
- If Anvil Base-fork needs additional keys, add them here (as the authoritative mapping) and ensure the frontend resolver accepts them (or ignores unknown keys safely).

#### Externals (Base mainnet addresses on the Anvil fork)

These keys must always point at the canonical on-chain contracts from `BASE_MAIN.sol` (even if the local Anvil fork reports `31337` or the forked chainId like `8453`):

| Key | Must map to | Source on Anvil Base-main fork |
| --- | --- | --- |
| `permit2` | Permit2 singleton | `BASE_MAIN.PERMIT2` |
| `weth9` | Base WETH9 | `BASE_MAIN.WETH9` |
| `uniswapV2Factory` | Uniswap V2 factory | `BASE_MAIN.UNISWAP_V2_FACTORY` |
| `uniswapV2Router` | Uniswap V2 router | `BASE_MAIN.UNISWAP_V2_ROUTER` |
| `balancerV3Vault` | Balancer V3 Vault | `BASE_MAIN.BALANCER_V3_VAULT` |
| `balancerV3Router` | Balancer V3 Router | `BASE_MAIN.BALANCER_V3_ROUTER` |
| `balancerV3BatchRouter` | Balancer V3 Batch Router | `BASE_MAIN.BALANCER_V3_BATCH_ROUTER` |
| `balancerV3BufferRouter` | Balancer V3 Buffer Router | `BASE_MAIN.BALANCER_V3_BUFFER_ROUTER` |

#### Factories (Deployed by `InitDevService.initEnv()`)

These keys must point to the actual factory contracts deployed/returned by Crane init:

| Key | Must map to | Notes |
| --- | --- | --- |
| `craneFactory` | Create3Factory | This is the `ICreate3Factory` instance used for all CREATE3 deployments |
| `craneDiamondFactory` | DiamondPackageCallBackFactory | This is the `IDiamondPackageCallBackFactory` used to deploy proxies from packages |

#### Facets (Logic Contracts; NOT proxies)

These keys must point to the facet contracts (logic), deployed via CREATE3.

| Key | Must map to | Notes |
| --- | --- | --- |
| `ownableFacet` | MultiStepOwnable facet (Crane access facet) | Logic facet address used in multiple packages |
| `operableFacet` | Operable facet (Crane access facet) | Logic facet address |
| `versionFacet` | Version facet | Logic facet address |
| `erc20PermitFacet` | ERC20 permit facet | Logic facet address |
| `wethAwareFacet` | WETH-aware facet | Logic facet address |
| `permit2AwareFacet` | Permit2-aware facet | Logic facet address |
| `uniswapV2AwareFacet` | UniswapV2-aware facet | Logic facet address |
| `balancerV3VaultAwareFacet` | Balancer V3 Vault-aware facet | Logic facet address |
| `balancerV3AuthenticationFacet` | Balancer auth facet | Logic facet address |
| `betterBalancerV3PoolTokenFacet` | Better pool token facet | Logic facet address |
| `defaultPoolInfoFacet` | Default pool info facet | Logic facet address |
| `standardSwapFeePercentageBoundsFacet` | Swap-fee bounds facet | Logic facet address |
| `standardUnbalancedLiquidityInvariantRatioBoundsFacet` | Liquidity invariant bounds facet | Logic facet address |
| `standardVaultFacet` | Standard vault facet | Logic facet address |
| `constantProductStrategyVaultFacet` | Constant-product strategy vault facet | Logic facet address |
| `vaultRegistryDeploymentFacet` | VaultRegistry deployment facet | Logic facet address |
| `vaultRegistryQueryFacet` | VaultRegistry query facet | Logic facet address |
| `vaultFeeOracleQueryFacet` | VaultFeeOracle query facet | Logic facet address |
| `vaultFeeOracleManagerFacet` | VaultFeeOracle manager facet | Logic facet address |
| `uniswapV2StandardExchangeInFacet` | UniswapV2 standard exchange (in) facet | Logic facet address |
| `uniswapV2StandardExchangeOutFacet` | UniswapV2 standard exchange (out) facet | Logic facet address |
| `balancerV3ConstantProductPoolFacet` | Balancer V3 constant-product pool facet | Logic facet address |
| `balancerV3StandardExchangeExactInBatchRouterFacet` | Balancer V3 batch (exact-in) facet | Logic facet address |
| `balancerV3StandardExchangeExactOutBatchRouterFacet` | Balancer V3 batch (exact-out) facet | Logic facet address |

#### Packages / DFPkgs (Contracts; NOT proxies)

These keys must point to *package* contracts (IDiamondFactoryPackage-style). These are deployed via CREATE3 and later used to deploy proxies.

| Key | Must map to | Notes |
| --- | --- | --- |
| `erc20MintBurnPkg` | `ERC20MintBurnOwnableOperableDFPkg` | Used for local test tokens |
| `feeCollectorDFPkg` | FeeCollector package | Package used to deploy the `feeCollector` proxy |
| `indexedexManagerDFPkg` | IndexedexManager package | Package used to deploy the `indexedexManager` proxy |
| `erc4626DFPkg` | ERC4626 package | Package contract address |
| `erc4626RateProviderFacetDFPkg` | ERC4626 rate-provider facet package | Package contract address |
| `vaultRegistryDFPkg` | VaultRegistry package | Package used to deploy the `vaultRegistry` proxy |
| `vaultFeeOracleDFPkg` | VaultFeeOracle package | Package used to deploy the `vaultFeeOracle` proxy |
| `uniswapV2StandardStrategyVaultPkg` | UniswapV2 strategy vault package | Package used to deploy vault proxies (fixtures) |
| `balancerV3ConstantProductPoolStandardVaultPkg` | Balancer V3 const-prod vault package | Package used to deploy vault proxies (fixtures) |
| `balancerV3StandardExchangeRouterDFPkg` | Balancer V3 router package | Package used to deploy the `balancerV3StandardExchangeRouter` proxy |
| `balancerV3StandardExchangeBatchRouterDFPkg` | Balancer V3 batch router package | Package used to deploy the `balancerV3StandardExchangeBatchRouter` proxy |
| `strategyVaultRateProviderFacetDFPkg` | Strategy vault rate-provider facet package | **Key name in Sepolia export**; ensure the anvil exporter uses this exact key even if the internal symbol name differs |
| `standardExchangeSingleVaultSeigniorageDETFDFPkg` | Seigniorage DETF package | Package contract address |

#### Proxy Instances (Deployed *from* a Package)

These keys must point to the deployed Diamond proxy addresses produced by calling the package’s deploy flow (via the diamond factory / manager). These are NOT facet addresses and NOT the package addresses.

| Key | Must map to | How it is deployed |
| --- | --- | --- |
| `feeCollector` | FeeCollector proxy address | Deployed via `feeCollectorDFPkg` (proxy deployed by diamond factory / manager flow) |
| `indexedexManager` | IndexedexManager proxy address | Deployed via `indexedexManagerDFPkg` (proxy deployed by diamond factory / manager flow) |
| `vaultRegistry` | VaultRegistry proxy address | Deployed via `vaultRegistryDFPkg` (proxy deployed by diamond factory / manager flow) |
| `vaultFeeOracle` | VaultFeeOracle proxy address | Deployed via `vaultFeeOracleDFPkg` (proxy deployed by diamond factory / manager flow) |
| `balancerV3StandardExchangeRouter` | Balancer V3 standard exchange router proxy address | Deployed via `balancerV3StandardExchangeRouterDFPkg` (proxy deployed by diamond factory) |
| `balancerV3StandardExchangeBatchRouter` | Balancer V3 batch router proxy address | Deployed via `balancerV3StandardExchangeBatchRouterDFPkg` (proxy deployed by diamond factory) |

#### Script-Deployed Helper Contracts (Non-package)

These keys are neither externals nor DFPkg proxies; they’re helper deployments intended for local dev.

| Key | Must map to | Notes |
| --- | --- | --- |
| `erc20MinterFacade` | `IERC20MinterFacade` implementation | Deployed directly by the script as a helper for minting during dev |

Important chain-note:
- For Anvil Base-main fork outputs, externals must reflect **Base mainnet** addresses from `BASE_MAIN.sol`.

### Frontend Artifact Format (Make This Match Existing UI Expectations)

The UI should load artifacts primarily by chainId, but must also support a context discriminator for forked/local environments that share the same chainId as a live network.

To make the Anvil Base-fork workflow “drop in”, the deployment script should export **the same file shapes** as the existing artifacts, into a chainId+context folder:
- Preferred: `frontend/app/addresses/<chainId>/anvil_fork/`
  - Example (if Anvil reports Base chainId): `frontend/app/addresses/8453/anvil_fork/`
  - Example (if Anvil uses 31337): `frontend/app/addresses/31337/anvil_fork/`
- Optional human-friendly alias: `frontend/app/addresses/anvil_base_main/` (duplicate contents)

Use these Sepolia files as the schema reference:
- `frontend/app/addresses/sepolia/base_deployments.json`
- `frontend/app/addresses/sepolia/sepolia-factories.contractlist.json`
- `frontend/app/addresses/sepolia/sepolia-tokens.tokenlist.json`
- `frontend/app/addresses/sepolia/sepolia-uniV2pool.tokenlist.json`
- `frontend/app/addresses/sepolia/sepolia-balancerv3-pools.tokenlist.json`

Recommended Anvil Base-fork filenames (mirror the pattern), under the chainId+context folder:
- `frontend/app/addresses/<chainId>/anvil_fork/base_deployments.json`
- `frontend/app/addresses/<chainId>/anvil_fork/factories.contractlist.json`
- `frontend/app/addresses/<chainId>/anvil_fork/tokens.tokenlist.json`
- `frontend/app/addresses/<chainId>/anvil_fork/uniV2pool.tokenlist.json`
- `frontend/app/addresses/<chainId>/anvil_fork/balancerv3-pools.tokenlist.json`

If also exporting the optional alias folder, mirror the same filenames there:
- `frontend/app/addresses/anvil_base_main/base_deployments.json`
- `frontend/app/addresses/anvil_base_main/factories.contractlist.json`
- `frontend/app/addresses/anvil_base_main/tokens.tokenlist.json`
- `frontend/app/addresses/anvil_base_main/uniV2pool.tokenlist.json`
- `frontend/app/addresses/anvil_base_main/balancerv3-pools.tokenlist.json`

Important: the current UI code in `frontend/app/lib/tokenlists.ts` and `frontend/app/lib/contractlists.ts` is hardwired to Sepolia filenames/mappings.

Preferred resolution:
- Update the frontend to select the folder by `chainId` (e.g., `31337/`, `8453/`, etc.) and load the standardized filenames listed above.

Artifact generation flow:
- The deployment script writes `base_deployments.json` under `frontend/app/addresses/<chainId>/<context>/`.
- A follow-on step digests that deployment JSON into the contractlists/tokenlists the UI consumes.

Temporary fallback (not recommended):
- Mirror exports into `frontend/app/addresses/anvil_base_main/` (alias folder) until the frontend selects by `(chainId, context)`.


### Script Properties

- **Idempotent:** Re-running must not redeploy unexpectedly; it must skip or reuse already-deployed components.
- **Deterministic:** Salts derived consistently (prefer type name hashing per repo convention) so reruns are stable.
  - Do not assume Anvil-exported addresses will match testnet/mainnet exports.
- **Staged:** Decompose into clearly separated stages (factories/core → packages → instances → export artifacts), each independently runnable.
- **No direct `new` deployments** for production components. Use factory helpers / deployment facets / package services.

### JSON State for Idempotency (Recommended)

Use a chain-specific state file (separate from UI artifacts) so reruns can skip work:
- Recommended location: `scripts/foundry/anvil_base_main/state/anvil_base_main.state.json`

Recommended idempotency rule of thumb:
- If a stored address is non-zero AND `extcodesize(address) > 0`, treat it as deployed.
- If the address is stored but has no code (e.g. chain reset), re-deploy and overwrite.


### Minimal “How to Run” (For the Next Session)

1) Start Anvil fork (Base mainnet fork):
- `anvil --fork-url <BASE_RPC_URL>`
  - If you explicitly set `--chain-id`, ensure the artifact path uses that chainId.
2) Run the Anvil Base-main deploy script:
- `forge script scripts/foundry/anvil_base_main/Script_AnvilBaseMain_DeployAll.s.sol --rpc-url http://127.0.0.1:8545 --broadcast -vvv`
3) Verify outputs exist under:
- `frontend/app/addresses/<chainId>/anvil_fork/`
- (optional alias) `frontend/app/addresses/anvil_base_main/`


---

## Implementation Workstreams (Parallelizable)

This task is intentionally written so multiple agents can implement in parallel with minimal overlap. The recommended coordination contract is:

- All work targets **only** `scripts/foundry/anvil_base_main/Script_AnvilBaseMain_DeployAll.s.sol` and adjacent helper files under `scripts/foundry/anvil_base_main/`.
- All stages must be **idempotent** via the state file at `scripts/foundry/anvil_base_main/state/anvil_base_main.state.json`.
- Artifact export must produce deterministic filenames under `frontend/app/addresses/<chainId>/anvil_fork/` (and optionally mirror to `frontend/app/addresses/anvil_base_main/`).

### Workstream A — Stage + State Framework

Goal: make the script safely re-runnable, with clean stage boundaries.

Acceptance criteria:
- A chain-specific JSON state file is read and written.
- Each stage checks the state, checks `extcodesize(address)`, and skips work when already deployed.
- Stages are independently runnable (e.g., via a `--sig` selector, an env var stage selector, or separate script entrypoints).
- The stage framework logs a concise “what was skipped vs deployed” summary.

### Workstream B — Factories + Core (Platform)

Scope:
- Create3Factory / DiamondPackageCallBackFactory wiring
- Fee Collector
- IndexedexManager + required platform packages/facets (VaultRegistry, VaultFeeOracle)
- Required permissions (manager/operator) for subsequent deployments

Acceptance criteria:
- After this stage, the manager can successfully deploy packages and vaults.
- State file contains all core addresses.
- `base_deployments.json` includes (at minimum): `craneFactory`, `craneDiamondFactory`, `feeCollector`, `indexedexManager`, `vaultRegistry`, `vaultFeeOracle`, `permit2`, `weth9`, plus the standard access facets the UI expects (e.g., `ownableFacet`, `operableFacet`, `versionFacet`) where applicable.

### Workstream C — Deploy All Required Packages

Scope: deploy every package in “Package List (Must Deploy)”.

Acceptance criteria:
- Each package address is written to state and exported to `base_deployments.json`.
- Any “best-effort” package (Camelot) records a structured reason for skip in the state file (and prints a log).

### Workstream D — Fixtures (Instances + Local Pools)

Goal: produce at least one usable instance per package, without relying on unknown pre-existing Base pools.

Recommended fixture strategy (preferred because it is deterministic and self-contained):
- Deploy 2–3 local test ERC20s via `ERC20MintBurnOwnableOperableDFPkg`.
- Create local pools against Base’s canonical routers/factories where feasible:
  - Uniswap V2: create a pair for (testTokenA, testTokenB) via Base’s Uniswap V2 factory/router and seed initial liquidity.
  - Aerodrome: let the package create a pool (it calls `getPool()` then `createPool()` if missing).
  - Balancer V3 constant-product: follow the pattern in the existing Sepolia local scripts (pool creation via Balancer’s vault/router APIs), but parameterize it for Base fork (external addresses from `BASE_MAIN.sol`).

Acceptance criteria:
- State includes at least one deployed instance address per required package category (DEX/Seigniorage/Protocol).
- Tokenlists exported for the UI include the newly deployed test ERC20s.

### Workstream E — UI Artifact Export + Validation

Goal: produce drop-in frontend artifacts and prevent silent schema drift.

Acceptance criteria:
- Script writes the full set of files under `frontend/app/addresses/<chainId>/anvil_fork/` (see “Frontend Artifact Format”).
- `base_deployments.json` includes at least the keys listed in “`base_deployments.json` Key Mapping (Authoritative)”.
- Exporter includes `permit2`, `weth9`, and other externals sourced from `BASE_MAIN.sol`.

### Workstream F — Runbook + Sanity Checks

Goal: make it easy to validate correctness and debug failures.

Acceptance criteria:
- Task doc (or `PROGRESS.md`) includes a minimal validation checklist:
  - confirm forked contracts exist at `BASE_MAIN.sol` addresses
  - confirm script rerun does not redeploy
  - confirm UI artifacts exist and have non-zero addresses
  - confirm at least one fixture vault supports a basic read call


---

## Package List (Must Deploy)

Deploy *all* packages listed below on the Base-mainnet-fork Anvil chain.

### Core / Platform

- `IndexedexManagerDFPkg`
- Vault Registry facets/packages as required by the manager deployment flow
- Vault Fee Oracle facets/packages as required by the manager deployment flow

### DEX / Exchange

- `UniswapV2StandardExchangeDFPkg`
- `CamelotV2StandardExchangeDFPkg` (best-effort on Base fork; skip only if missing required externals, and record the reason in logs + state)
- `AerodromeStandardExchangeDFPkg`
- `BalancerV3StandardExchangeRouterDFPkg`
- `BalancerV3ConstantProductPoolStandardVaultPkg`
- `StandardExchangeRateProviderDFPkg`

### Seigniorage

- `SeigniorageDETFDFPkg`
- `SeigniorageNFTVaultDFPkg`

### Protocol

- `ProtocolDETFDFPkg`
- `ProtocolNFTVaultDFPkg`
- `RICHIRDFPkg`

### Test Tokens (Local Dev)

- `ERC20MintBurnOwnableOperableDFPkg` (required for deploying local test ERC20s used by sample instances)

### Package Deployment Components (Handoff Notes)
Use factory services and package init structs; do not deploy with `new`.

**Core / Platform**
- Fee Collector: use [contracts/fee/collector/FeeCollectorFactoryService.sol](contracts/fee/collector/FeeCollectorFactoryService.sol)
- Manager (registry + oracle facets): use [contracts/manager/IndexedexManagerFactoryService.sol](contracts/manager/IndexedexManagerFactoryService.sol)
- Manager must be set as operator on Create3 factory prior to package/vault deployments.

**DEX / Exchange**
- Uniswap V2: use [contracts/protocols/dexes/uniswap/v2/UniswapV2_Component_FactoryService.sol](contracts/protocols/dexes/uniswap/v2/UniswapV2_Component_FactoryService.sol)
- Aerodrome: use [contracts/protocols/dexes/aerodrome/v1/Aerodrome_Component_FactoryService.sol](contracts/protocols/dexes/aerodrome/v1/Aerodrome_Component_FactoryService.sol)
- Camelot V2: use [contracts/protocols/dexes/camelot/v2/CamelotV2_Component_FactoryService.sol](contracts/protocols/dexes/camelot/v2/CamelotV2_Component_FactoryService.sol)
- Balancer V3 router: use [contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouter_FactoryService.sol](contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouter_FactoryService.sol)

**Balancer V3 Constant-Product Vault + Rate Provider**
- Constant-product vault package: [contracts/protocols/dexes/balancer/v3/pools/constProd/BalancerV3ConstantProductPoolStandardVaultPkg.sol](contracts/protocols/dexes/balancer/v3/pools/constProd/BalancerV3ConstantProductPoolStandardVaultPkg.sol)
- Rate provider package: [contracts/protocols/dexes/balancer/v3/rateProviders/StandardExchangeRateProviderDFPkg.sol](contracts/protocols/dexes/balancer/v3/rateProviders/StandardExchangeRateProviderDFPkg.sol)

**Seigniorage**
- DETF package: [contracts/vaults/seigniorage/SeigniorageDETFDFPkg.sol](contracts/vaults/seigniorage/SeigniorageDETFDFPkg.sol)
- NFT vault package: [contracts/vaults/seigniorage/SeigniorageNFTVaultDFPkg.sol](contracts/vaults/seigniorage/SeigniorageNFTVaultDFPkg.sol)
- Prefer the component factory service when wiring init structs + deployment salts:
  - [contracts/vaults/seigniorage/Seigniorage_Component_FactoryService.sol](contracts/vaults/seigniorage/Seigniorage_Component_FactoryService.sol)
- Common vault component deploy helpers live at:
  - [contracts/vaults/VaultComponentFactoryService.sol](contracts/vaults/VaultComponentFactoryService.sol)

**Protocol**
- Protocol packages + init structs:
  - [contracts/vaults/protocol/ProtocolDETFDFPkg.sol](contracts/vaults/protocol/ProtocolDETFDFPkg.sol)
  - [contracts/vaults/protocol/ProtocolNFTVaultDFPkg.sol](contracts/vaults/protocol/ProtocolNFTVaultDFPkg.sol)
  - [contracts/vaults/protocol/RICHIRDFPkg.sol](contracts/vaults/protocol/RICHIRDFPkg.sol)
- Factory services for Protocol deployment (preferred):
  - [contracts/vaults/protocol/Protocol_Component_FactoryService.sol](contracts/vaults/protocol/Protocol_Component_FactoryService.sol)
  - [contracts/vaults/protocol/ProtocolDETF_Pkg_FactoryService.sol](contracts/vaults/protocol/ProtocolDETF_Pkg_FactoryService.sol)

**Test Tokens**
- Use [lib/daosys/lib/crane/contracts/tokens/ERC20/ERC20MintBurnOwnableOperableDFPkg.sol](lib/daosys/lib/crane/contracts/tokens/ERC20/ERC20MintBurnOwnableOperableDFPkg.sol).
- Ensure init struct fields match the current package interface (`diamondFactory`, `mutiStepOwnableFacet`, and `optionalSalt`).

---

## Instances / Fixtures (Must Deploy)

Deploy representative instances so the UI has working contracts to read from and transact with:

- At least **one** deployed vault instance from each DEX package:
	- UniswapV2 vault instance
	- CamelotV2 vault instance
	- Aerodrome vault instance
	- BalancerV3 constant-product pool vault instance
- At least **one** deployed Seigniorage instance:
	- SeigniorageDETF instance
	- SeigniorageNFTVault instance (as appropriate to its deploy flow)
- At least **one** deployed Protocol instance:
	- ProtocolDETF instance
	- ProtocolNFTVault instance
	- RICHIR instance
- Deploy **2–3 test ERC20s** via `ERC20MintBurnOwnableOperableDFPkg` and include them in the exported tokenlist for the UI.

---

## Review Focus (Updated)

In addition to the original checklist, explicitly verify:

- Base-mainnet fork assumptions are correct (addresses come from `BASE_MAIN.sol`).
- Script exports UI-ready artifacts into `frontend/app/addresses/` and the UI can import them.
- Protocol DETF package and instance deployment is included and succeeds.

Idempotent staged scripts, deterministic salt usage, JSON state persistence, and correct per-chain configuration.

## Primary Risks

- Non-idempotent scripts that redeploy unexpectedly
- Incorrect salt derivation producing non-deterministic addresses
- Missing Foundry fs permissions or unsafe file IO
- Fixture creation that depends on missing/paused externals (handle via best-effort + structured skip)

## Review Checklist

### Script Structure
- [ ] Scripts are staged and independently runnable
- [ ] Each stage reads JSON state
- [ ] Each stage skips already-complete work

### Deterministic Deployment
- [x] Salts are derived from type names (or consistent repo convention)
- [x] Salt derivation is consistent across all scripts

### JSON State Management
- [ ] JSON write/read usage is safe
- [x] JSON is chain-specific (writes to `frontend/app/addresses/anvil_base_main/`)

### Per-Network Package Selection
Matches plan:
- [ ] Base mainnet fork: deploy all packages listed in "Package List"
- [x] Addresses/externals sourced from `BASE_MAIN.sol`
- [x] Camelot is deployed on local fork only if the package itself does not require missing external Base contracts

### Deployment Patterns
- [x] Scripts deploy via factory helpers
- [ ] No `new` keyword usage (legacy local scripts still non-compliant)

### Output
- [x] A "full deployment" run produces a complete summary of addresses (base_deployments.json)

## Files to Review

**Primary:**
- `scripts/foundry/`
- `contracts/script/`

**Configuration:**
- `foundry.toml` (fs permissions)
- Any JSON state files

## Completion Criteria

- [ ] All checklist items verified
- [ ] Deployment script requirements above are implemented and verified on Anvil Base-mainnet fork
- [x] Review findings preserved in [tasks/IDXEX-009-review-deployment-scripts/PROGRESS.md](tasks/IDXEX-009-review-deployment-scripts/PROGRESS.md)
- [ ] No Blocker or High severity issues remain unfixed (2 High issues resolved, 2 Blockers remain)

---

## Review Findings (2026-01-21, updated)

This repo has three deployment-script “families” under `scripts/foundry/`, and none of them matches the full IDXEX-009 requirements for an **Anvil (Base mainnet fork) full staged deployment** that exports UI-ready artifacts.

### Current Script Inventory

- `scripts/foundry/anvil_base_main/Script_AnvilBaseMain_DeployAll.s.sol`
  - Purpose: Anvil Base-main fork deployment for UI/dev.
  - Binds Base mainnet addresses from `BASE_MAIN.sol` and currently writes UI artifacts to `frontend/app/addresses/anvil_base_main/` (should be updated to write to `frontend/app/addresses/<chainId>/anvil_fork/`, with optional alias mirroring).
  - Missing required packages, fixtures, and staged/idempotent JSON state handling.
  - Contains a compile-breaking test token deployment block (see Findings).

- `scripts/foundry/base_main/Script_BaseMain_DeployIndexedex.s.sol`
  - Purpose: deploy a subset of IndexedEx to **Base mainnet** (chain id `8453`).
  - Uses CREATE3 factory + factory service libs (good), but is not an Anvil-fork “full deployment” script.
- `scripts/foundry/local/**` (including `scripts/foundry/local/segmented/*`)
  - Purpose: legacy/local + Sepolia-oriented scripts that generate JSON outputs for older frontend flows.
  - These scripts reference `contracts/crane/...` and `contracts/indexedex/...` import paths that do **not** exist under current `contracts/` (likely stale / pre-refactor). Expect compile/runtime issues unless those paths are provided elsewhere.

### Checklist Results (Against IDXEX-009 Requirements)

#### Script Structure / Staging

- [ ] Staged and independently runnable (partial)
  - The `local/segmented/Local_00..Local_14` naming suggests staging, but it’s not targeting Base-fork Anvil and appears stale.
  - The Base mainnet script is monolithic (single stage).
- [ ] Each stage reads JSON state / [ ] skips already-complete work
  - Anvil Base-main script does not read JSON state; it only writes UI artifacts.
  - Base mainnet script does not read/write state; it always attempts deploy calls.
  - Local segmented scripts do read/write JSON, but (a) appear stale, and (b) not aligned to the required output location/format.

#### Deterministic Deployment / Salt Derivation

- [~] Mostly consistent for CREATE3-based components
  - `scripts/foundry/base_main/Script_BaseMain_DeployIndexedex.s.sol` uses factory service helpers and hashes `type(SenderGuardFacet).name` for at least one facet deployment.
  - However, without explicit “reuse existing” behavior, reruns may revert (common for CREATE3 deployments when the address is already deployed).

#### JSON State Management / Safety

- [~] Foundry fs permissions look OK
  - `foundry.toml` has `fs_permissions = [{ access = "read-write", path = "./"}]`.
- [~] Chain-specific JSON state persistence for Base-fork Anvil partially implemented
  - Anvil Base-main script writes UI artifacts to `frontend/app/addresses/anvil_base_main/`, but does not read JSON state or provide full required fields.

#### Per-Network Package Selection (Base mainnet fork)

- [ ] Base mainnet fork assumptions and config are not implemented end-to-end
  - Anvil script validates fork by checking Base-mainnet code is present at `BASE_MAIN.sol` addresses.
  - Base mainnet script hard-requires `block.chainid == 8453`, so it cannot run on Anvil (expected `31337`).
- [ ] Required package list not deployed
  - Anvil script deploys: FeeCollector, IndexedexManager, Uniswap V2 pkg, Aerodrome pkg, optional Camelot pkg, Balancer V3 Standard Exchange Router pkg, and test tokens.
  - Missing (per task requirements): Balancer constant-product vault pkg, StandardExchangeRateProvider pkg, seigniorage pkgs, protocol pkgs (ProtocolDETF/ProtocolNFTVault/RICHIR), and required fixture instances.

#### Deployment Patterns (No `new`)

- [ ] Violations exist in local scripts
  - `scripts/foundry/local/segmented/Local_04_Uniswap_V2.s.sol` deploys `UniV2Router02` via `new`.
  - Similar `new UniV2Router02(...)` usage exists in `scripts/foundry/local/*Sepolia*_01_Deploy*.s.sol`.
  - For the Base-mainnet-fork UI deployment, Uniswap/Camelot/etc should bind to canonical Base addresses (no `new`).

#### Output / Frontend Integration

- [ ] UI-ready artifacts for Anvil Base fork are incomplete
  - Anvil script writes tokenlists and a minimal factories list but omits required core fields (factory, diamond factory, manager, registry, oracle, fee collector) and instances.

### Notable Risks / Gaps

- Blocker: no single script matches the required environment (Anvil Base fork) + full package set + fixtures + UI exports.
- Blocker: base-mainnet script cannot run on Anvil because of strict `chainid` check.
- High: Anvil script’s test token deploy block mismatches the current `ERC20MintBurnOwnableOperableDFPkg` interface and appears to fail compilation.
- High: local scripts appear stale (imports likely broken) and include `new` deployments that violate the CREATE3-only rule for production components.
- Medium: current scripts do not clearly guarantee idempotency; CREATE3 redeploy attempts typically revert if already deployed.

### Recommendation (To Satisfy IDXEX-009)

- Standardize the existing **Anvil Base-fork UI deployment** script in [scripts/foundry/anvil_base_main/Script_AnvilBaseMain_DeployAll.s.sol](scripts/foundry/anvil_base_main/Script_AnvilBaseMain_DeployAll.s.sol).
- Implement explicit stages:
  - Stage 1: factories/core (Create3Factory / DiamondPackageCallBackFactory / Manager / Registry / Oracle / FeeCollector)
  - Stage 2: deploy all required DFPkgs via `IndexedexManager` flow
  - Stage 3: deploy fixture instances (1 per package + 2-3 test ERC20s)
  - Stage 4: export UI JSON to `frontend/app/addresses/<chainId>/anvil_fork/` (and optionally mirror to `frontend/app/addresses/anvil_base_main/`)
- Ensure idempotency by reading chain-specific JSON state and skipping when values are already set and on-chain code exists at the address.


---

**When complete, output:** `<promise>TASK_COMPLETE</promise>`

**If blocked, output:** `<promise>TASK_BLOCKED: [reason]</promise>`
