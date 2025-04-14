---
name: indexedex-script-orchestration
description: Indexedex shell and forge deployment orchestration best practices. Use when editing deploy_mainnet_bridge_ui.sh, wiring direct forge script execution, passing SENDER or OUT_DIR_OVERRIDE, handling local supersim signers, or stabilizing long broadcast runs for the Sepolia plus Base Sepolia rehearsal.
---

# Indexedex Script Orchestration

This skill captures the scripting patterns that proved necessary for the repo's Sepolia plus Base Sepolia SuperSim rehearsal.

## Use This Skill For

- editing `scripts/foundry/supersim/deploy_mainnet_bridge_ui.sh`
- refactoring shell wrappers around `forge script`
- debugging sender, signer, or broadcast issues on local SuperSim forks
- passing deployment output directories and network profiles into Solidity scripts
- stabilizing long chain-local deployment runs

## Shell Rules

- Use `#!/usr/bin/env bash`, not `/bin/sh`.
- Use `set -euo pipefail`.
- Keep helper functions small and single-purpose.
- Prefer arrays for command construction so quoting stays correct.
- Redact API keys or provider secrets from any logged RPC URL.
- Validate and create required output directories before broadcasting.

## Wrapper Responsibilities

The top-level shell wrapper should own orchestration. In this repo that means:

1. resolve upstream RPCs from Foundry aliases when explicit env vars are absent
2. derive the shared fork height from Crane network constants
3. start or reuse SuperSim fork mode
4. wait for both local RPC endpoints
5. prepare the broadcast identity
6. sweep ETH to the deployer on both forks
7. run direct per-chain `forge script` commands
8. deploy bridge infra and bridge config
9. export frontend artifacts

Avoid pushing this orchestration into one large Solidity script.

## Prefer Direct Per-Chain Forge Scripts

Use shell-driven direct invocations such as:

- `scripts/foundry/supersim/ethereum/Script_DeployAll.s.sol:Script_DeployAll`
- `scripts/foundry/supersim/base/Script_DeployAll.s.sol:Script_DeployAll`
- `scripts/foundry/supersim/Script_24_DeploySuperchainBridgeInfra.s.sol:Script_24_DeploySuperchainBridgeInfra`
- `scripts/foundry/supersim/Script_25_ConfigureProtocolDetfBridge.s.sol:Script_25_ConfigureProtocolDetfBridge`

This is more debuggable and less fragile than a top-level script that nests many script contracts.

## Solidity Script Configuration Rules

Deployment scripts should accept configuration from the shell wrapper instead of inferring too much from `tx.origin`.

Recommended environment contract:

- `SENDER` for the desired deployer address
- `PRIVATE_KEY` only when key-backed broadcast is required
- `OUT_DIR_OVERRIDE` for per-run manifest directories
- `NETWORK_PROFILE` for address binding mode
- `REMOTE_OUT_DIR` for cross-chain bridge config
- `SUPERSIM_ETHEREUM_RPC_URL` and `SUPERSIM_BASE_RPC_URL` when scripts need both endpoints

In Solidity, load deployer config in this order:

1. `SENDER` if present and nonzero
2. fallback to `tx.origin`
3. if `PRIVATE_KEY` is present, derive deployer from that key

## Sender and Signer Rules

- `--sender` selects the sender address.
- `vm.startBroadcast(address)` still needs a signer that the RPC can use.
- On local forked RPCs with `--unlocked`, default dev accounts are directly signable.
- Non-default addresses are not automatically signable just because they were funded.
- If the local RPC supports Anvil impersonation, use `anvil_impersonateAccount` before broadcasting from a non-default deployer.

This distinction was critical in the recent SuperSim deployment work.

## Broadcast Stability Rules

- Forward `-v` through `-vvvvv` from the wrapper into `forge script`.
- Use `--slow` for long broadcast runs to serialize sends.
- Expect long deploy phases to appear quiet while Foundry simulates and broadcasts.
- Treat mempool drops, upstream `429` responses, and flaky late broadcast failures as sequencing pressure first, not necessarily contract logic bugs.

If a long deploy still flakes after `--slow`, split the sequence rather than hiding the problem behind more abstraction.

## Base Sepolia Rehearsal Rules

For the local Base Sepolia rehearsal:

- do not assume every upstream dependency already exists
- deploy local Uniswap V2, Balancer V3, and Aerodrome dependencies when needed
- deploy Balancer V3 using Crane packages and deterministic factory flows
- keep protocol address overrides in JSON manifests read by `scripts/foundry/anvil_base_main/DeploymentBase.sol`
- keep shared WETH assumptions consistent across Balancer, Aerodrome, and Uniswap wiring

## Logging Rules

- Emit short progress logs before each major script run.
- Log the active RPC, network profile, and output directory.
- Redact upstream provider secrets.
- Keep final post-deploy balance sweeping separate from the deployment workflow.

## Anti-Patterns

- `/bin/sh` wrapper that uses Bash-only syntax
- relying only on `tx.origin` when shell orchestration already knows the intended sender
- assuming sender selection implies signer availability
- one opaque top-level Solidity wrapper that hides the failing stage
- hardcoding Base Sepolia protocol addresses when the rehearsal intentionally deploys local replacements

## Source Files

- `scripts/foundry/supersim/deploy_mainnet_bridge_ui.sh`
- `scripts/foundry/anvil_sepolia/DeploymentBase.sol`
- `scripts/foundry/anvil_base_main/DeploymentBase.sol`
- `scripts/foundry/supersim/Script_24_DeploySuperchainBridgeInfra.s.sol`
- `scripts/foundry/supersim/Script_25_ConfigureProtocolDetfBridge.s.sol`