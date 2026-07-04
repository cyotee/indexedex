# Local Testing Scripts

This directory contains the staged local deployment flow for Indexedex development.

The current implementation targets a single local Anvil chain and is organized so you can:

- bring up a reusable foundation once
- layer scenario-specific fixtures on top of it
- resume from JSON artifacts instead of redeploying everything
- drive the flow through a thin Bash wrapper while keeping onchain logic in Foundry scripts

## Current Scope

Validated today:

- Stage 01: Crane foundation
- Stage 02: Indexedex core
- Stage 03: base protocol surface
- Stage 05: foundation packages
- Stage 06: foundation assets
- Stage 10: Scenario 1 overlay
- Stage 11: Scenario 2 overlay
- Stage 12: Scenario 3 overlay

Not yet implemented in this staged flow:

- dual-chain SuperSim profile for Scenario 4
- extended protocol foundation for Uniswap V4, Aerodrome, and Slipstream

## Directory Layout

```text
scripts/
  foundry/
    local_testing/
      anvil_single/
        Script_01_DeployCraneFoundation.s.sol
        Script_02_DeployIndexedexCore.s.sol
        Script_03_DeployBaseProtocols.s.sol
        Script_05_DeployFoundationPackages.s.sol
        Script_06_DeployFoundationAssets.s.sol
        Script_10_DeployScenario1Overlay.s.sol
        Script_11_DeployScenario2Overlay.s.sol
        Script_12_DeployScenario3Overlay.s.sol
      supersim/
        LocalTestingSuperSimBase.sol
        Script_21_DeployBridgeInfra.s.sol
        Script_22_ConfigureSingleVaultDetfBridge.s.sol
        Script_23_ValidateSingleVaultDetfBridge.s.sol
        ethereum/
          Script_20_DeployFoundation.s.sol
        base/
          Script_20_DeployFoundation.s.sol
      shared/
        LocalTestingDeploymentBase.sol
  shell/
    local_testing.sh
    local_testing_supersim.sh
```

## Wrapper Usage

Use the Bash wrapper as the primary entrypoint:

```bash
DEV_ADDRESS=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
  bash scripts/shell/local_testing.sh foundation
```

Common commands:

```bash
# Start fresh and deploy the shared base
DEV_ADDRESS=<anvil-account> bash scripts/shell/local_testing.sh --restart-anvil foundation

# Deploy package layer only
DEV_ADDRESS=<anvil-account> bash scripts/shell/local_testing.sh packages

# Deploy reusable local assets
DEV_ADDRESS=<anvil-account> bash scripts/shell/local_testing.sh assets

# Deploy Scenario 1 on top of the current foundation
DEV_ADDRESS=<anvil-account> bash scripts/shell/local_testing.sh scenario1

# Deploy Scenario 2 on top of Scenario 1 outputs
DEV_ADDRESS=<anvil-account> bash scripts/shell/local_testing.sh scenario2

# Deploy Scenario 3 on top of the current single-chain foundation
DEV_ADDRESS=<anvil-account> bash scripts/shell/local_testing.sh scenario3

# Run an individual stage
DEV_ADDRESS=<anvil-account> bash scripts/shell/local_testing.sh stage10 -vv

# Stop the local Anvil process managed by the wrapper
bash scripts/shell/local_testing.sh --kill-anvil
```

SuperSim dual-chain flow:

```bash
# Run the full Scenario 4 dual-chain flow
DEV_ADDRESS=<supersim-account> bash scripts/shell/local_testing_supersim.sh scenario4

# Run only the dual-chain foundation stage
DEV_ADDRESS=<supersim-account> bash scripts/shell/local_testing_supersim.sh foundation

# Run only the bridge configuration stage
DEV_ADDRESS=<supersim-account> bash scripts/shell/local_testing_supersim.sh configure

# Stop the local SuperSim process managed by the wrapper
bash scripts/shell/local_testing_supersim.sh --kill-supersim
```

## Environment

Supported environment variables:

- `DEV_ADDRESS` or `SENDER`: unlocked sender passed to `forge script --sender`
- `LOCAL_TESTING_DEPLOYER_ADDRESS`: optional override for the deployer used by scripts
- `LOCAL_TESTING_OWNER`: optional override for ownership initialization; defaults to deployer
- `RPC_URL`: defaults to `http://127.0.0.1:8545`
- `ANVIL_HOST`: defaults to `127.0.0.1`
- `ANVIL_PORT`: defaults to `8545`
- `ANVIL_CHAIN_ID`: defaults to `11155111` (Sepolia). Set to `31337` for a pure local devnet.
- `FOUNDRY_FORK_RPC_ALIAS`: defaults to `ethereum_sepolia_alchemy`. The wrapper resolves this alias from `foundry.toml [rpc_endpoints]` (with environment variable substitution) to pick the fork URL. Set to an empty string to disable forking.
- `ANVIL_FORK_URL`: explicit upstream RPC for the Anvil fork. When set, overrides the alias lookup.
- `ANVIL_FORK_BLOCK_NUMBER`: optional fork block pin
- `SKIP_TOKENLIST_BUILD`: set to `1` to skip the post-deploy Token List aggregator
- `OUT_DIR_OVERRIDE`: defaults to `deployments/local_testing/anvil_single`
- `NETWORK_PROFILE`: defaults to `local_testing`
- `ANVIL_LOG_DIR`: defaults to `deployments/local_testing/runtime`

Notes:

- The wrapper intentionally derives `DEPLOYER_ADDRESS` and `OWNER` from the local-testing-specific variables so ambient shell exports do not poison local runs.
- Broadcast runs use `--slow --unlocked --sender` to avoid nonce and receipt issues during serialized local deployment.

## Stage Model

### Foundation

`foundation` runs the shared base only:

- `01`: deploy Crane foundation surfaces
- `02`: deploy Indexedex core
- `03`: deploy local protocol base surfaces

This is the cheapest reusable bring-up for local testing.

### Packages

`packages` or `stage05` deploys reusable package surfaces:

- Uniswap V2 Standard Exchange package
- Standard Exchange Rate Provider package
- Balancer V3 constant-product pool package

### Assets

`assets` or `stage06` deploys reusable tokens and fixtures:

- Test Token A
- Test Token B
- Test Token C
- ERC20 minter facade
- local RICH token package and token instance

### Scenario 1

`scenario1` currently runs:

- `05`: foundation packages
- `06`: foundation assets
- `10`: Scenario 1 overlay

Scenario 1 deploys:

- Uniswap V2 TTA/TTB pool and vault
- Uniswap V2 TTB/WETH pool and vault

Expected manifest: `10_scenario_1.json`

### Scenario 2

`scenario2` currently runs:

- `05`: foundation packages
- `06`: foundation assets
- `10`: Scenario 1 overlay
- `11`: Scenario 2 overlay

Scenario 2 deploys:

- rate provider for the UniV2 TTA/TTB vault targeting TTB
- rate provider for the UniV2 TTB/WETH vault targeting TTB
- Balancer pool pairing TTB with the UniV2 TTA/TTB vault token
- Balancer pool pairing TTB with the UniV2 TTB/WETH vault token

Expected manifest: `11_scenario_2.json`

### Scenario 3

`scenario3` currently runs:

- `05`: foundation packages
- `06`: foundation assets
- `12`: Scenario 3 overlay

Scenario 3 deploys the **Single Vault DETF** from
`contracts/vaults/detf/composed/single` (not the older standardExchange/single DETF):

- local `WeightedPool8020Factory`
- Uniswap V4 PoolManager + WETH/RICH liquidity seed for the DETF reserve path
- Single Vault DETF instance (CHIR) for the RICH/WETH graph
- Protocol NFT Vault and RICHIR dependencies for that DETF
- outer Balancer constant-product pool pairing WETH with the Single Vault DETF token

Expected manifest: `12_scenario_3.json`

UI wiring for the Staking page:

- Stage 12 writes a `fragments/vaults/protocolDetf/protocolDetf.json` fragment
  (symbol `CHIR`) and stage JSON keys `protocolDetf`, `richToken`, `richirToken`, etc.
- The shell wrapper merges stage JSONs into
  `frontend/app/addresses/chain/<chainId>/platform.json` and runs the tokenlist
  aggregator so `protocol-detfs.tokenlist.json` includes CHIR.
- Staking resolves CHIR from that token list, with `platform.protocolDetf` as a
  fallback when the list is temporarily empty.

Prerequisite: run `foundation` (stages 01–03) once before `scenario3`.

### Scenario 4

Use `scripts/shell/local_testing_supersim.sh` for the dual-chain SuperSim profile.

Stage model:

- `20`: per-chain foundation plus Single Vault DETF graph on Ethereum and Base local SuperSim forks
- `21`: bridge infrastructure on both forks
- `22`: Single Vault DETF bridge configuration on both forks
- `23`: reserve bridge validation on both forks

Expected directories:

- `deployments/local_testing/supersim/ethereum/`
- `deployments/local_testing/supersim/base/`
- `deployments/local_testing/supersim/shared/`

## Artifacts

Artifacts are written to:

```text
deployments/local_testing/anvil_single/
```

Current files:

- `01_crane_foundation.json`
- `02_indexedex_core.json`
- `03_protocols_base.json`
- `05_foundation_packages.json`
- `06_foundation_assets.json`
- `10_scenario_1.json`
- `11_scenario_2.json`
- `12_scenario_3.json`

SuperSim files are written to:

```text
deployments/local_testing/supersim/
```

Representative outputs:

- `ethereum/20_foundation.json`
- `base/20_foundation.json`
- `shared/21_bridge_infra_ethereum.json`
- `shared/21_bridge_infra_base.json`
- `shared/22_bridge_config_ethereum.json`
- `shared/22_bridge_config_base.json`
- `shared/23_bridge_validation_ethereum.json`
- `shared/23_bridge_validation_base.json`

Each file is intended to be resumable input for later stages. If a required artifact is missing, the dependent stage will fail fast with a targeted message.

## Direct Foundry Execution

You can also invoke the Foundry scripts directly:

```bash
cd /Users/cyotee/Development/github-cyotee/indexedex
SENDER=<anvil-account> \
OWNER=<owner-address> \
OUT_DIR_OVERRIDE=deployments/local_testing/anvil_single \
NETWORK_PROFILE=local_testing \
forge script scripts/foundry/local_testing/anvil_single/Script_05_DeployFoundationPackages.s.sol \
  --rpc-url http://127.0.0.1:8545 \
  --broadcast --slow --unlocked --sender <anvil-account>
```

Prefer the wrapper for routine use so Anvil lifecycle and env isolation stay consistent.

## Known Follow-Up Work

- add Scenario 3 staged deployment
- validate and harden the new SuperSim dual-chain profile for Scenario 4 against a live local SuperSim run
- add documentation for consuming the generated manifests from tests or UI tooling
- optionally add a CI smoke target for `foundation`, `scenario1`, and `scenario2`
