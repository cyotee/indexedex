---
name: foundry-agent-safety
description: "Check chain, signer, addresses, simulation, authorization and receipts before live Cast or Forge transaction operations."
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

# Foundry agent safety

## When to use

- Before live-chain writes or changes outside an already authorized isolated test
- Before any mainnet or funded-wallet transaction
- When a prior cast/forge command reverted

## Mandatory checklist

1. **Chain** — `cast chain-id` matches the intended network (document expected id).
2. **RPC** — `ETH_RPC_URL` or `--rpc-url` points at the correct endpoint (not a surprise public mainnet when testing).
3. **Identity** — `cast wallet address --private-key $PRIVATE_KEY` (or keystore) is the intended agent wallet. Never echo the key.
4. **Balances** — native + token balances cover amount + gas.
5. **Addresses** — every contract address comes from a skill address table, deployment artifact, or on-chain registry query — never invented.
6. **Dry-run** — prefer `cast call` / `cast estimate` before `cast send`.
7. **Authorization** — for live/funded writes, confirm the existing request covers the chain, recipient, function and amounts. Ask only for missing authorization. Authorized hermetic/local tests do not require repeated transaction approvals.
8. **Size** — first live txs should be small; scale after success.
9. **Receipt** — after send, `cast receipt $TX` and re-read state; do not assume success from a hash alone.
10. **No blind gas bumps** — on revert, decode error (`cast 4byte`, receipt logs) before retrying.

## Fork rehearsal

Prefer Anvil fork before mainnet writes:

```bash
anvil --fork-url "$ETH_RPC_URL" --port 8545
export ETH_RPC_URL=http://127.0.0.1:8545
# use Anvil default keys only on the fork
```

See skill `anvil-node` for forking details.

## Secrets

- Use env vars: `PRIVATE_KEY`, `ETH_RPC_URL` — never paste keys into skill files or commits.
- Prefer `cast wallet` keystore / `--account` when available.
- Do not log full `.env` files.

## Confirmation summary template

```text
CHAIN_ID: <id> (<name>)
FROM: <address>
TO: <contract>
FN: <signature>
ARGS: <human readable>
VALUE: <eth or 0>
TOKEN_AMOUNTS: <...>
EST_GAS: <from cast estimate if available>
USER_OK?: waiting
```

Only broadcast within the explicitly authorized scope. Installing or reading this skill grants no transaction authorization.
