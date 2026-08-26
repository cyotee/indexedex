---
name: indexedex-ui-tx-testing
description: >-
  Runs IndexedEx/DTF frontend transactions through the UI with Playwright
  injected wallets (not MetaMask) and verifies on-chain effects. Use when the
  user asks to "test UI txs", "e2e bond", "live swap UI", "Playwright staking",
  "verify deposit through UI", "DTF e2e", "Robinhood Anvil UI", "click through
  money path", or after frontend money-path changes. DO NOT use for Foundry
  contract tests (crane-testing / indexedex-testing) or pure copy/IA smoke without txs.
license: MIT
---

# IndexedEx UI transaction testing

Prove the **Next app builds and submits correct txs** by driving the real UI with an **injected EIP-1193 wallet**, then asserting **RPC balances / receipts** — not click-only.

## When / when not

| Use | Skip |
|-----|------|
| After deposit / swap / staking / approval wiring changes | Solidity unit/fork tests only |
| Robinhood Anvil (4663) + DTF launch verification | Pixel/visual QA without chain |
| Fee DETF bond/mint paths on `/staking` | Deploying stacks *as part of* a pure UI PR (prefer operator-provided RPC) |

## Default target (DTF / Robinhood)

| Item | Value |
|------|--------|
| App | `frontend/apps/dtf` (`@indexedex/app-dtf`) |
| Port | **3002** |
| Chain id | **4663** |
| RPC | `http://127.0.0.1:8545` |
| Wallet | Anvil **#0** (e2e inject); scripts fund **#1** as human UI wallet |
| Artifacts | `frontend/packages/protocol/src/addresses/chain/4663/` |

Do not look for `frontend/apps/indexedex`. That app was removed. DTF is the only Next app.

## Quick start

```bash
# 0) Repo root — operator stack already up (pick ONE family; do not merge)
# Fee DETF / staking (CHIR live after first bond):
bash scripts/shell/anvil_robinhood_fee_detf.sh all --restart-anvil
# OR lab multi DETF/SE (inert until UI bond):
# bash scripts/shell/anvil_robinhood_main.sh all --restart-anvil

cast chain-id --rpc-url http://127.0.0.1:8545   # must be 4663

# 1) Frontend
cd frontend
npm install
npm run build -w @indexedex/app-dtf
npm run test:e2e:install -w @indexedex/app-dtf

# 2) Shell + IA (no live txs required)
npm run test:e2e -w @indexedex/app-dtf

# 3) Live money paths (bond / deposit when stack allows)
npm run test:e2e:live -w @indexedex/app-dtf
```

Reuse a running DTF dev server:

```bash
npm run dev:dtf
E2E_SKIP_WEBSERVER=1 npm run test:e2e:live -w @indexedex/app-dtf
```

## Navigation (read on demand)

| Need | Open |
|------|------|
| Env vars, suite map, pass criteria | [references/dtf-e2e-runbook.md](references/dtf-e2e-runbook.md) |
| Manual click checklist (bond / swap / deposit) | [references/manual-tx-journeys.md](references/manual-tx-journeys.md) |
| Stack + wallet setup (RH Anvil) | [references/stacks-and-wallets.md](references/stacks-and-wallets.md) |
| Product route matrix (historical full plan) | `frontend/UI_FULL_FUNCTIONALITY_TEST_PLAN.md` |
| RH agent runbook | `docs/ANVIL_ROBINHOOD_UI_AGENT_RUNBOOK.md` |

## Hard rules

1. **No MetaMask automation** — use Playwright inject (`e2e/wallet/injectWallet.ts`).
2. **Pass = on-chain effect** — balance delta, NFT mint, or receipt via RPC; not “button enabled.”
3. **Query vs execute** — deposit query **8-tuple** / execute **10-tuple**; never spread execute into query.
4. **Approvals** — multi-leg uses **split** Permit2 + router CTAs (`swap-approve-*`, ActionCta gates).
5. **List-driven addresses** — read `chain/<id>/` tokenlists + `platform.json`; do not hardcode vaults.
6. **Two Anvil families** — `fee_detf` (CHIR live) vs `main` (inert demos). Last export wins for `chain/4663/`.
7. **Do not invent APY/USD** in assertions or UI checks.

## Key files

| Path | Role |
|------|------|
| `frontend/apps/dtf/e2e/` | DTF Playwright suite (RH default) |
| `frontend/apps/dtf/e2e/staking-bond-live.spec.ts` | Bond WETH via `/staking` |
| `frontend/apps/dtf/e2e/swap-routes-live.spec.ts` | Live swap/deposit when stack supports |
| `frontend/apps/dtf/playwright.config.ts` | Port 3002 + RH env |
| `frontend/packages/protocol/` | Shared addresses / tokenlists |
| `frontend/packages/protocol/src/addresses/chain/4663/` | RH artifacts |

## Agent verification loop

```text
1. Confirm RPC + chain id (cast)
2. Confirm artifacts exist for that chain
3. npm run test:e2e (shell/IA)
4. npm run test:e2e:live (bond/deposit) — skip-only is OK if stack missing; document blocker
5. Optional: browser MCP walk /staking?detf=<chir> for manual confirm
6. Fix UI → re-run live suite → only then claim money-path done
```

## See also

- `skill:indexedex-ui-refactor` — env / artifacts / wagmi transports  
- `skill:indexedex-product-voice` — copy only  
- `skill:ethskills-qa` — general dApp ship checklist  
- Deploy stacks: `scripts/foundry/anvil_robinhood_fee_detf/`, `anvil_robinhood_main/`
