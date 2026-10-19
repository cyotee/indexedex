---
name: foundry-script-ops
description: "Prepare and simulate multi-step Forge scripts using IndexedEx artifact, deployment and transaction-authorization rules."
---

## IndexedEx integration (2026-10-19)

Read the repository `CLAUDE.md` and the relevant Crane/IndexedEx skill before
using this topic. Current product law, registry/CREATE3 deployment, production-first
tests, build-before-test ordering and configured Foundry profiles override generic
examples. This archive-derived guide does not authorize broadcasts, dependency
installs, new product integrations or restoration of retired protocol families.
Use current deployment artifacts and the pinned frontend/tool versions; archived
addresses and API samples are not live verification. Resolve topic names through
`scripts/codex-skill-catalog.json` when they are grouped behind routers.

# Foundry script ops (agent multi-step)

## When to use

- Approve + spend in one broadcast session
- Multi-contract sequences that must share the same signer/nonce flow
- Reproducible agent ops checked into a small Foundry project

Prefer **`cast call` / `cast send`** for single-step ops (see `cast-commands`).

## Minimal script pattern

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

contract AgentOp is Script {
    function run() external {
        uint256 pk = vm.envUint("PRIVATE_KEY");
        address token = vm.envAddress("TOKEN");
        address spender = vm.envAddress("SPENDER");
        uint256 amount = vm.envUint("AMOUNT");

        vm.startBroadcast(pk);
        IERC20(token).approve(spender, amount);
        // next calls...
        vm.stopBroadcast();
    }
}
```

A broadcast sequence can contain separate transactions; it is not an atomic
multi-call. A later failure does not roll back earlier included transactions.
Use the current IndexedEx launch scripts and artifact-first helpers when changing
production deployment flows; this small example does not replace them.

## Commands

```bash
# dry run (no broadcast)
forge script script/AgentOp.s.sol:AgentOp --rpc-url "$ETH_RPC_URL" -vvvv

# broadcast after user confirmation
forge script script/AgentOp.s.sol:AgentOp \
  --rpc-url "$ETH_RPC_URL" \
  --broadcast \
  -vvvv
```

## Safety

1. Run **without** `--broadcast` first; review traces.
2. Apply `foundry-agent-safety` checklist before broadcasting.
3. Pass addresses via env, not hardcoded mainnet keys or secrets in source.
4. Verify with `cast call` / balances after broadcast.

## Relation to cast

| Step | Tool |
|------|------|
| Single view | `cast call` |
| Single tx | `cast send` |
| Multi-step sequence | `forge script --broadcast` |
