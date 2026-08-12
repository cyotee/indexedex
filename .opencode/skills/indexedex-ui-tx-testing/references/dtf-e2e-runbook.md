# DTF e2e runbook

## Contents

- Commands
- Environment
- Spec map
- Pass / fail criteria
- Common failures

## Commands

From `frontend/`:

```bash
npm run test:e2e -w @indexedex/app-dtf           # all non-tagged + live (live skips without RPC)
npm run test:e2e:live -w @indexedex/app-dtf      # *live*.spec.ts only
npm run test:e2e:install -w @indexedex/app-dtf   # playwright chromium
```

Single file:

```bash
cd apps/dtf
npx playwright test e2e/staking-bond-live.spec.ts
```

## Environment

| Variable | Default | Meaning |
|----------|---------|---------|
| `E2E_CHAIN_ID` | `4663` | Injected wallet chain + `indexedex:selected-network` |
| `E2E_RPC_URL` | `http://127.0.0.1:8545` | Node for sign + `cast`-style asserts |
| `E2E_PORT` | `3002` | Next listen port |
| `E2E_SKIP_WEBSERVER` | — | `1` = attach to existing server |
| `E2E_BASE_URL` | `http://127.0.0.1:3002` | Override |
| `NEXT_PUBLIC_DEFAULT_DEPLOYMENT_ENVIRONMENT` | `anvil_robinhood_main` (webServer) | Artifact registry key |
| `NEXT_PUBLIC_DEFAULT_CHAIN_ID` | `4663` | DTF app default network |

Artifacts are loaded from:

`frontend/packages/protocol/src/addresses/chain/<E2E_CHAIN_ID>/`

## Spec map

| Spec | Needs RPC | Proves |
|------|-----------|--------|
| `connected-wallet.spec.ts` | Optional | Inject + Connect UI |
| `shell-routes.spec.ts` | No | Routes / redirects |
| `wave2-fee-detf.spec.ts` | No* | Fee list IA, Earn exclude, staking chrome |
| `deposit-panel.spec.ts` | No* | Earn deposit gates |
| `staking-bond-live.spec.ts` | **Yes** | Bond rate asset via UI → balance/NFT/status |
| `swap-routes-live.spec.ts` | **Yes** | Swap deposit / Earn deposit when lists+router allow |

\*Uses committed tokenlists; empty list → skip.

## Pass / fail criteria (live)

**Pass** if any:

1. Relevant ERC-20 balance changes in the expected direction (viem `balanceOf`)
2. Bond NFT `balanceOf` increases
3. UI shows confirmed hash **and** `waitForTransactionReceipt` succeeds (helpers)

**Fail** if:

- Submit enabled, click returns, balances unchanged, no receipt, and no intentional skip
- Wrong chain (wallet vs data chain mismatch) and UI still claims success

**Skip** (not fail) if:

- RPC down, chain id mismatch, empty tokenlist, DETF not live (`isReserveLive === false`), router missing for SE deposit path

## Common failures

| Symptom | Fix |
|---------|-----|
| Connect never shows address | Inject runs before load; clear `dtf-wagmi*` localStorage in `prepareLocalChain` |
| UI Sepolia addresses | Set `indexedex:selected-network` to `4663`; DTF default chain env |
| Bond reverts min lock | Increase lock days in UI / test (`staking-bond-lock-days`) |
| Bond reverts not live | Run fee_detf stage 11 or bond first on main lab gentle DETF |
| Swap submit never enables | Missing `balancerV3StandardExchangeRouter` on RH fee_detf — expected skip |
| Stale contracts after Anvil restart | Re-export stage + refresh `chain/4663` |
