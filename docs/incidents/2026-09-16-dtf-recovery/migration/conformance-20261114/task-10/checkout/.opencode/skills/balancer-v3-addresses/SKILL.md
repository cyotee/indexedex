---
name: balancer-v3-addresses
description: "Resolve Balancer V3 Vault and Router addresses from current IndexedEx deployment artifacts and verified chain identity."
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

# Balancer V3 addresses

## Resolve the active deployment

1. Read `indexedex-networks-addresses` and `indexedex-registry-discovery`.
2. Select the exact network/deployment artifact for the task and confirm its chain ID.
3. Distinguish protocol Vault, protocol Router and IndexedEx Standard Exchange Router.
4. Check deployed code and ABI/version before using the address.
5. If a required address is absent, report the missing artifact; never substitute an old testnet address or a remembered mainnet deployment.

The archive contained Base Sepolia router addresses. They are not promoted to a
current address table: this checkout's artifacts and registry own those values.

```bash
cast chain-id --rpc-url "$ETH_RPC_URL"
cast codesize "$ROUTER" --rpc-url "$ETH_RPC_URL"
```
