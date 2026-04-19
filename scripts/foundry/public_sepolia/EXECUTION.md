# Public Sepolia Execution Guide

This directory contains the three-stage deployment flow for the public Sepolia demo spanning Ethereum Sepolia and Base Sepolia.

Do not use `scripts/foundry/sepolia/deploy_sepolia.sh` for this flow. That script is the older single-chain Sepolia demo path and does not create Base wrappers or bridge balances to Base Sepolia.

## Stages

1. Ethereum Sepolia core deployment with Protocol DETF deferred
2. Base Sepolia wrapper creation and L1 to L2 token bridging
3. Base Sepolia core deployment with Protocol DETF deferred
4. Superchain bridge infrastructure deployment on both chains
5. Protocol DETF deployment on both chains
6. Superchain bridge configuration on both chains

## Default Output Directories

- Ethereum artifacts: `deployments/public_sepolia/ethereum`
- Base artifacts: `deployments/public_sepolia/base`
- Shared bridge artifacts: `deployments/public_sepolia/shared`
- Frontend export: `frontend/app/addresses/public_sepolia`

## RPC Defaults

- Ethereum Sepolia: `sepolia_alchemy`
- Base Sepolia: `base_sepolia_alchemy`

## Signer Assumption

The commands below assume a consistent broadcast sender address.

Set `SENDER` to the address that should own and operate the deployed graph, and make sure the actual Forge broadcast sender matches it.

How Forge authenticates that sender depends on your setup:

- Manual signer flow: use whatever signer configuration is already working for you. In this mode you may only need `--sender ...`.
- Local RPC impersonation flow: if you impersonate an address on a local Anvil or SuperSim RPC with `anvil_impersonateAccount`, use `--sender ... --unlocked`.

Example:

```bash
export DEPLOYER_ADDRESS=0xYourAddress
```

The same address should be funded on both Ethereum Sepolia and Base Sepolia.

## Recommended: Run The Wrapper Script

This script runs the full flow and pauses at the two manual verification checkpoints.

```bash
DEPLOYER_ADDRESS=0xYourAddress \
scripts/foundry/public_sepolia/deploy_public_sepolia.sh --broadcast
```

If you have already verified the intermediate wrapper and balance state and want to suppress the pauses:

```bash
DEPLOYER_ADDRESS=0xYourAddress \
PUBLIC_SEPOLIA_SKIP_CHECKPOINTS=1 \
scripts/foundry/public_sepolia/deploy_public_sepolia.sh --broadcast
```

## Manual Execution

Use this when you want to run each phase explicitly.

Note: both `Script_DeployAll` invocations now require `REMOTE_OUT_DIR` to point at the opposite chain's deployment directory because Stage 16 reads the peer relayer from that location.

### Stage 1: Ethereum Sepolia Core Deployment

This deploys the L1 side of the public Sepolia stack through Stage 15 and writes the source token addresses used by later bridge steps. Protocol DETF Stage 16 is deferred until bridge infrastructure exists on both chains.

```bash
SENDER=0xYourAddress \
NETWORK_PROFILE=ethereum_sepolia \
OUT_DIR_OVERRIDE=deployments/public_sepolia/ethereum \
REMOTE_OUT_DIR=deployments/public_sepolia/base \
PUBLIC_SEPOLIA_SKIP_STAGE16=true \
forge script scripts/foundry/public_sepolia/ethereum/Script_DeployAll.s.sol:Script_DeployAll \
  --rpc-url sepolia_alchemy \
  --broadcast \
  --sender 0xYourAddress \
  --unlocked \
  --slow
```

Outputs written here:

- `deployments/public_sepolia/ethereum/*.json`

### Stage 2A: Create Base Sepolia Wrapper Tokens

This creates the Optimism mintable ERC20 wrappers on Base Sepolia for `TTA`, `TTB`, `TTC`, `DemoWETH`, and `RICH`.

```bash
SENDER=0xYourAddress \
PUBLIC_SEPOLIA_ETHEREUM_OUT_DIR=deployments/public_sepolia/ethereum \
PUBLIC_SEPOLIA_BASE_OUT_DIR=deployments/public_sepolia/base \
PUBLIC_SEPOLIA_SHARED_OUT_DIR=deployments/public_sepolia/shared \
forge script scripts/foundry/public_sepolia/base/Script_05_CreateBridgeTokens.s.sol:Script_05_CreateBridgeTokens \
  --rpc-url base_sepolia_alchemy \
  --broadcast \
  --sender 0xYourAddress \
  --unlocked \
  --slow
```

Outputs written here:

- `deployments/public_sepolia/base/05_bridge_tokens.json`
- `deployments/public_sepolia/shared/bridge_token_manifest.json`

Manual checkpoint after Stage 2A:

1. Verify each wrapper exists on Base Sepolia.
2. Verify names use ` (Base Sepolia)`.
3. Verify symbols use `.base`.

### Stage 2B: Bridge Required Token Balances To Base Sepolia

This bridges the required balances from Ethereum Sepolia to the Base Sepolia wrappers.

```bash
SENDER=0xYourAddress \
PUBLIC_SEPOLIA_ETHEREUM_OUT_DIR=deployments/public_sepolia/ethereum \
PUBLIC_SEPOLIA_SHARED_OUT_DIR=deployments/public_sepolia/shared \
forge script scripts/foundry/public_sepolia/ethereum/Script_17_BridgeTokensToBase.s.sol:Script_17_BridgeTokensToBase \
  --rpc-url sepolia_alchemy \
  --broadcast \
  --sender 0xYourAddress \
  --unlocked \
  --slow
```

Outputs written here:

- `deployments/public_sepolia/shared/bridge_execution_plan.json`

Manual checkpoint after Stage 2B:

1. Verify the bridged balances arrived on Base Sepolia.
2. Verify the recipient is the deployer address.
3. Verify `DemoWETH.base` and `RICH.base` balances are present before running the Base deployment.

### Stage 3: Base Sepolia Core Deployment

This deploys the Base Sepolia side of the mirrored environment through Stage 15, using bridged test tokens rather than local minting. Protocol DETF Stage 16 is deferred until bridge infrastructure exists on both chains.

```bash
SENDER=0xYourAddress \
NETWORK_PROFILE=base_sepolia \
OUT_DIR_OVERRIDE=deployments/public_sepolia/base \
REMOTE_OUT_DIR=deployments/public_sepolia/ethereum \
PUBLIC_SEPOLIA_SKIP_STAGE16=true \
forge script scripts/foundry/public_sepolia/base/Script_DeployAll.s.sol:Script_DeployAll \
  --rpc-url base_sepolia_alchemy \
  --broadcast \
  --sender 0xYourAddress \
  --unlocked \
  --slow
```

Outputs written here:

- `deployments/public_sepolia/base/*.json`

### Stage 4A: Deploy Superchain Bridge Infrastructure On Ethereum

```bash
SENDER=0xYourAddress \
OUT_DIR_OVERRIDE=deployments/public_sepolia/ethereum \
forge script scripts/foundry/supersim/Script_24_DeploySuperchainBridgeInfra.s.sol:Script_24_DeploySuperchainBridgeInfra \
  --rpc-url sepolia_alchemy \
  --broadcast \
  --sender 0xYourAddress \
  --unlocked \
  --slow
```

### Stage 4B: Deploy Superchain Bridge Infrastructure On Base

```bash
SENDER=0xYourAddress \
OUT_DIR_OVERRIDE=deployments/public_sepolia/base \
forge script scripts/foundry/supersim/Script_24_DeploySuperchainBridgeInfra.s.sol:Script_24_DeploySuperchainBridgeInfra \
  --rpc-url base_sepolia_alchemy \
  --broadcast \
  --sender 0xYourAddress \
  --unlocked \
  --slow
```

Outputs written here:

- `deployments/public_sepolia/ethereum/24_superchain_bridge.json`
- `deployments/public_sepolia/base/24_superchain_bridge.json`

### Stage 5A: Deploy Protocol DETF On Ethereum

```bash
SENDER=0xYourAddress \
NETWORK_PROFILE=ethereum_sepolia \
OUT_DIR_OVERRIDE=deployments/public_sepolia/ethereum \
REMOTE_OUT_DIR=deployments/public_sepolia/base \
forge script scripts/foundry/public_sepolia/ethereum/Script_16_DeployProtocolDETF.s.sol:Script_16_DeployProtocolDETF \
  --rpc-url sepolia_alchemy \
  --broadcast \
  --sender 0xYourAddress \
  --unlocked \
  --slow
```

### Stage 5B: Deploy Protocol DETF On Base

```bash
SENDER=0xYourAddress \
NETWORK_PROFILE=base_sepolia \
OUT_DIR_OVERRIDE=deployments/public_sepolia/base \
REMOTE_OUT_DIR=deployments/public_sepolia/ethereum \
forge script scripts/foundry/public_sepolia/base/Script_16_DeployProtocolDETF.s.sol:Script_16_DeployProtocolDETF \
  --rpc-url base_sepolia_alchemy \
  --broadcast \
  --sender 0xYourAddress \
  --unlocked \
  --slow
```

Outputs written here:

- `deployments/public_sepolia/ethereum/16_protocol_detf.json`
- `deployments/public_sepolia/base/16_protocol_detf.json`

### Stage 6A: Configure Protocol DETF Bridge On Ethereum

```bash
SENDER=0xYourAddress \
OUT_DIR_OVERRIDE=deployments/public_sepolia/ethereum \
REMOTE_OUT_DIR=deployments/public_sepolia/base \
forge script scripts/foundry/supersim/Script_25_ConfigureProtocolDetfBridge.s.sol:Script_25_ConfigureProtocolDetfBridge \
  --rpc-url sepolia_alchemy \
  --broadcast \
  --sender 0xYourAddress \
  --unlocked \
  --slow
```

### Stage 6B: Configure Protocol DETF Bridge On Base

```bash
SENDER=0xYourAddress \
OUT_DIR_OVERRIDE=deployments/public_sepolia/base \
REMOTE_OUT_DIR=deployments/public_sepolia/ethereum \
forge script scripts/foundry/supersim/Script_25_ConfigureProtocolDetfBridge.s.sol:Script_25_ConfigureProtocolDetfBridge \
  --rpc-url base_sepolia_alchemy \
  --broadcast \
  --sender 0xYourAddress \
  --unlocked \
  --slow
```

## Frontend Export

The wrapper script handles frontend export automatically.

If you run the stages manually, export artifacts with:

```bash
python3 scripts/foundry/supersim/export_frontend_artifacts.py \
  deployments/public_sepolia/ethereum \
  frontend/app/addresses/public_sepolia/ethereum \
  11155111

python3 scripts/foundry/supersim/export_frontend_artifacts.py \
  deployments/public_sepolia/base \
  frontend/app/addresses/public_sepolia/base \
  84532
```

## SuperSim Testing

The commands above are for real Ethereum Sepolia and real Base Sepolia.

If you want to test the new public Sepolia deployment scripts locally against forked Sepolia and Base Sepolia nodes, use SuperSim only to provide the forked chain state.

Do not use `scripts/foundry/supersim/deploy_mainnet_bridge_ui.sh` for this purpose. That script runs a separate SuperSim-specific deployment flow and would mix in deployments that are not part of the new public Sepolia script path.

### What To Use For Local Testing

- Use `supersim fork` to start local Sepolia and Base Sepolia forks.
- Then run the new scripts in `scripts/foundry/public_sepolia` against those local RPCs.

### Start SuperSim With Forked Sepolia And Base Sepolia State

Use fork mode with Sepolia as the L1 network and Base as the L2 chain:

```bash
SUPERSIM_RPC_URL_SEPOLIA="https://eth-sepolia.g.alchemy.com/v2/${ALCHEMY_KEY}" \
SUPERSIM_RPC_URL_BASE="https://base-sepolia.g.alchemy.com/v2/${ALCHEMY_KEY}" \
supersim fork \
  --network=sepolia \
  --chains=base \
  --l1.fork.height=10597210 \
  --l1.port=8545 \
  --l2.starting.port=9545 \
  --admin.port=8420 \
  --l1.host=127.0.0.1 \
  --l2.host=127.0.0.1 \
  --logs.directory=deployments/supersim_sepolia/runtime \
  --interop.autorelay
```

What this gives you locally:

- Ethereum Sepolia fork RPC: `http://127.0.0.1:8545`
- Base Sepolia fork RPC: `http://127.0.0.1:9545`

The canonical fork height used by the repo network constants is `10400000` for both Sepolia and Base Sepolia.

Notes:

1. Use the same upstream RPC providers you would use for Sepolia and Base Sepolia.
2. If you already have something listening on `8545` or `9545`, either stop it first or change the SuperSim ports and use those port values in the deployment commands below.
3. Prefer a clean SuperSim instance for each end-to-end test pass so wrapper creation and bridge state are deterministic.

### Run The New Public Sepolia Scripts Against The Local SuperSim RPCs

Once SuperSim is running, test the new scripts by pointing them at the local fork RPCs instead of the public RPC aliases.

If you want to use RPC-level impersonation on the local SuperSim forks, impersonate the same wallet address on both local RPCs before using `--sender ... --unlocked`.

Example:

```bash
export DEPLOYER_ADDRESS=0xF71ea560c6465727efFe07Cfb4e1a05B40520Dd7

cast rpc anvil_impersonateAccount "$DEPLOYER_ADDRESS" --rpc-url http://127.0.0.1:8545
cast rpc anvil_impersonateAccount "$DEPLOYER_ADDRESS" --rpc-url http://127.0.0.1:9545

cast rpc anvil_setBalance "$DEPLOYER_ADDRESS" 0x3635C9ADC5DEA00000 --rpc-url http://127.0.0.1:8545
cast rpc anvil_setBalance "$DEPLOYER_ADDRESS" 0x3635C9ADC5DEA00000 --rpc-url http://127.0.0.1:9545
```

Why matching the sender is required:

1. The scripts use `SENDER` to decide who should own and operate the deployed factory graph.
2. `vm.startBroadcast()` uses the actual Forge broadcast sender.
3. If `SENDER` and the actual Forge broadcast sender do not match, ownership is assigned to one address while transactions are sent from another, which causes reverts like `NotOperator(...)`.

You can run the all-in-one wrapper, but override its RPCs to hit the local forks and use separate output directories so you do not mix local test artifacts with real public deployment artifacts.

```bash
DEPLOYER_ADDRESS=0xF71ea560c6465727efFe07Cfb4e1a05B40520Dd7 \
ETHEREUM_SEPOLIA_RPC_URL=http://127.0.0.1:8545 \
BASE_SEPOLIA_RPC_URL=http://127.0.0.1:9545 \
PUBLIC_SEPOLIA_ETHEREUM_OUT_DIR=deployments/public_sepolia_supersim/ethereum \
PUBLIC_SEPOLIA_BASE_OUT_DIR=deployments/public_sepolia_supersim/base \
PUBLIC_SEPOLIA_SHARED_OUT_DIR=deployments/public_sepolia_supersim/shared \
PUBLIC_SEPOLIA_FRONTEND_ARTIFACTS_DIR=frontend/app/addresses/supersim_sepolia \
scripts/foundry/public_sepolia/deploy_public_sepolia.sh --broadcast
```

This local wrapper flow overwrites the canonical local UI bundle in `frontend/app/addresses/supersim_sepolia`. In the frontend environment toggle, select `supersim_sepolia` when testing the locally exported artifacts.

That is the closest local test of the new scripts themselves.

### Manual Multi-Stage Test Against SuperSim

If you want to step through the new scripts manually, use the same stages as the public-network flow but point them at the local fork RPCs and write to separate local test directories.

Important: in every command below, keep `SENDER` and `--sender` the same address.

Stage 1:

```bash
SENDER=0xF71ea560c6465727efFe07Cfb4e1a05B40520Dd7 \
NETWORK_PROFILE=ethereum_sepolia \
OUT_DIR_OVERRIDE=deployments/public_sepolia_supersim/ethereum \
REMOTE_OUT_DIR=deployments/public_sepolia_supersim/base \
PUBLIC_SEPOLIA_SKIP_STAGE16=true \
forge script scripts/foundry/public_sepolia/ethereum/Script_DeployAll.s.sol:Script_DeployAll \
  --rpc-url http://127.0.0.1:8545 \
  --broadcast \
  --sender 0xF71ea560c6465727efFe07Cfb4e1a05B40520Dd7 \
  --slow
```

Stage 2A:

```bash
SENDER=0xF71ea560c6465727efFe07Cfb4e1a05B40520Dd7 \
PUBLIC_SEPOLIA_ETHEREUM_OUT_DIR=deployments/public_sepolia_supersim/ethereum \
PUBLIC_SEPOLIA_BASE_OUT_DIR=deployments/public_sepolia_supersim/base \
PUBLIC_SEPOLIA_SHARED_OUT_DIR=deployments/public_sepolia_supersim/shared \
forge script scripts/foundry/public_sepolia/base/Script_05_CreateBridgeTokens.s.sol:Script_05_CreateBridgeTokens \
  --rpc-url http://127.0.0.1:9545 \
  --broadcast \
  --sender 0xF71ea560c6465727efFe07Cfb4e1a05B40520Dd7 \
  --slow
```

Stage 2B:

```bash
SENDER=0xF71ea560c6465727efFe07Cfb4e1a05B40520Dd7 \
PUBLIC_SEPOLIA_ETHEREUM_OUT_DIR=deployments/public_sepolia_supersim/ethereum \
PUBLIC_SEPOLIA_SHARED_OUT_DIR=deployments/public_sepolia_supersim/shared \
forge script scripts/foundry/public_sepolia/ethereum/Script_17_BridgeTokensToBase.s.sol:Script_17_BridgeTokensToBase \
  --rpc-url http://127.0.0.1:8545 \
  --broadcast \
  --sender 0xF71ea560c6465727efFe07Cfb4e1a05B40520Dd7 \
  --slow
```

Local SuperSim fallback after Stage 2B:

If the Base fork crashes while processing the L1 deposit path, run this helper before Stage 3. It replays the Base-side `relayMessage(finalizeBridgeERC20(...))` calls from the artifacts written by Stage 2B so the later Base deployment stages can proceed.

```bash
ETHEREUM_RPC_URL=http://127.0.0.1:8545 \
BASE_RPC_URL=http://127.0.0.1:9545 \
BRIDGE_PLAN_FILE=deployments/public_sepolia_supersim/shared/bridge_execution_plan.json \
BRIDGE_MANIFEST_FILE=deployments/public_sepolia_supersim/shared/bridge_token_manifest.json \
scripts/foundry/public_sepolia/finalize_bridge_tokens_on_base.sh
```

This helper is local-only. It does not fix the upstream Anvil deposit crash; it simulates the L2 finalization path so Stage 3 can use the bridged balances.

Stage 3:

```bash
SENDER=0xF71ea560c6465727efFe07Cfb4e1a05B40520Dd7 \
NETWORK_PROFILE=base_sepolia \
OUT_DIR_OVERRIDE=deployments/public_sepolia_supersim/base \
REMOTE_OUT_DIR=deployments/public_sepolia_supersim/ethereum \
PUBLIC_SEPOLIA_SKIP_STAGE16=true \
forge script scripts/foundry/public_sepolia/base/Script_DeployAll.s.sol:Script_DeployAll \
  --rpc-url http://127.0.0.1:9545 \
  --broadcast \
  --sender 0xF71ea560c6465727efFe07Cfb4e1a05B40520Dd7 \
  --slow
```

Stage 4A:

```bash
SENDER=0xF71ea560c6465727efFe07Cfb4e1a05B40520Dd7 \
OUT_DIR_OVERRIDE=deployments/public_sepolia_supersim/ethereum \
forge script scripts/foundry/supersim/Script_24_DeploySuperchainBridgeInfra.s.sol:Script_24_DeploySuperchainBridgeInfra \
  --rpc-url http://127.0.0.1:8545 \
  --broadcast \
  --sender 0xF71ea560c6465727efFe07Cfb4e1a05B40520Dd7 \
  --slow
```

Stage 4B:

```bash
SENDER=0xF71ea560c6465727efFe07Cfb4e1a05B40520Dd7 \
OUT_DIR_OVERRIDE=deployments/public_sepolia_supersim/base \
forge script scripts/foundry/supersim/Script_24_DeploySuperchainBridgeInfra.s.sol:Script_24_DeploySuperchainBridgeInfra \
  --rpc-url http://127.0.0.1:9545 \
  --broadcast \
  --sender 0xF71ea560c6465727efFe07Cfb4e1a05B40520Dd7 \
  --slow
```

Stage 5A:

```bash
SENDER=0xF71ea560c6465727efFe07Cfb4e1a05B40520Dd7 \
NETWORK_PROFILE=ethereum_sepolia \
OUT_DIR_OVERRIDE=deployments/public_sepolia_supersim/ethereum \
REMOTE_OUT_DIR=deployments/public_sepolia_supersim/base \
forge script scripts/foundry/public_sepolia/ethereum/Script_16_DeployProtocolDETF.s.sol:Script_16_DeployProtocolDETF \
  --rpc-url http://127.0.0.1:8545 \
  --broadcast \
  --sender 0xF71ea560c6465727efFe07Cfb4e1a05B40520Dd7 \
  --slow
```

Stage 5B:

```bash
SENDER=0xF71ea560c6465727efFe07Cfb4e1a05B40520Dd7 \
NETWORK_PROFILE=base_sepolia \
OUT_DIR_OVERRIDE=deployments/public_sepolia_supersim/base \
REMOTE_OUT_DIR=deployments/public_sepolia_supersim/ethereum \
forge script scripts/foundry/public_sepolia/base/Script_16_DeployProtocolDETF.s.sol:Script_16_DeployProtocolDETF \
  --rpc-url http://127.0.0.1:9545 \
  --broadcast \
  --sender 0xF71ea560c6465727efFe07Cfb4e1a05B40520Dd7 \
  --slow
```

Stage 6A:

```bash
SENDER=0xF71ea560c6465727efFe07Cfb4e1a05B40520Dd7 \
OUT_DIR_OVERRIDE=deployments/public_sepolia_supersim/ethereum \
REMOTE_OUT_DIR=deployments/public_sepolia_supersim/base \
forge script scripts/foundry/supersim/Script_25_ConfigureProtocolDetfBridge.s.sol:Script_25_ConfigureProtocolDetfBridge \
  --rpc-url http://127.0.0.1:8545 \
  --broadcast \
  --sender 0xF71ea560c6465727efFe07Cfb4e1a05B40520Dd7 \
  --slow
```

Stage 6B:

```bash
SENDER=0xF71ea560c6465727efFe07Cfb4e1a05B40520Dd7 \
OUT_DIR_OVERRIDE=deployments/public_sepolia_supersim/base \
REMOTE_OUT_DIR=deployments/public_sepolia_supersim/ethereum \
forge script scripts/foundry/supersim/Script_25_ConfigureProtocolDetfBridge.s.sol:Script_25_ConfigureProtocolDetfBridge \
  --rpc-url http://127.0.0.1:9545 \
  --broadcast \
  --sender 0xF71ea560c6465727efFe07Cfb4e1a05B40520Dd7 \
  --slow
```

### Why This Works

The new scripts are still the same `public_sepolia` scripts. SuperSim is only supplying local RPC endpoints with forked Sepolia and Base Sepolia chain state behind them.

That means you are testing the new scripts, not the older SuperSim deployment wrappers.

### Important Distinction

Do not use `scripts/foundry/supersim/deploy_mainnet_bridge_ui.sh` when your goal is to validate the new public Sepolia scripts themselves. That wrapper executes a different deployment path.

For local forked-node testing of the new work, start SuperSim manually with forked Sepolia/Base state, then run the scripts under `scripts/foundry/public_sepolia` against `http://127.0.0.1:8545` and `http://127.0.0.1:9545`.

### Local UI Environment

For local public Sepolia testing, the frontend should use the `public_sepolia_supersim` deployment environment.

- Exported frontend artifacts live under `frontend/app/addresses/public_sepolia_supersim`.
- The wrapper script infers the frontend filename prefix from that directory name.
- If you export artifacts manually, use the same target directory so the UI can load the updated bundle.

## Resulting Flow Summary

1. Run Ethereum Sepolia core deploy with Protocol DETF deferred.
2. Create Base wrappers.
3. Verify wrappers.
4. Bridge balances.
5. Verify bridged balances.
6. Run Base Sepolia core deploy with Protocol DETF deferred.
7. Deploy Superchain bridge infrastructure on both chains.
8. Deploy Protocol DETF on both chains.
9. Configure the Protocol DETF bridge on both chains.
10. Export frontend artifacts if running stages manually.