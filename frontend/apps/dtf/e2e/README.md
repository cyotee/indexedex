# DTF connected-wallet + live TX e2e

Playwright suite for **`@indexedex/app-dtf`** (port **3002**).

Injected EIP-1193 wallet (Anvil key) — **not** MetaMask. Default chain: **4663** (Robinhood Anvil fork).

## Prerequisites

1. **Build once:** `npm run build -w @indexedex/app-dtf` (from `frontend/`)
2. Chromium: `npm run test:e2e:install -w @indexedex/app-dtf`
3. **For live TX specs:** Anvil already running with matching artifacts:
   - Fee DETF / staking: `bash scripts/shell/anvil_robinhood_fee_detf.sh all --restart-anvil`
   - Lab multi-vault: `bash scripts/shell/anvil_robinhood_main.sh all --restart-anvil`
   - `cast chain-id --rpc-url http://127.0.0.1:8545` → **4663**
   - Artifacts under `frontend/packages/protocol/src/addresses/chain/4663/`

Agents: follow skill **`indexedex-ui-tx-testing`**.

## Run

```bash
cd frontend

# Shell / IA smoke (no RPC required for most)
npm run test:e2e -w @indexedex/app-dtf

# Live txs only (needs Anvil)
npm run test:e2e:live -w @indexedex/app-dtf

# Reuse already-running DTF dev server
npm run dev:dtf   # :3002
E2E_SKIP_WEBSERVER=1 npm run test:e2e -w @indexedex/app-dtf
```

## Env

| Variable | Default | Role |
|----------|---------|------|
| `E2E_CHAIN_ID` | `4663` | Injected wallet + selected network |
| `E2E_RPC_URL` | `http://127.0.0.1:8545` | JSON-RPC for inject + balance asserts |
| `E2E_PORT` | `3002` | App port |
| `E2E_SKIP_WEBSERVER` | unset | Set `1` to use existing `dev`/`start` |
| `E2E_BASE_URL` | `http://127.0.0.1:$PORT` | Override base URL |

## Layout

| Path | Role |
|------|------|
| `wallet/injectWallet.ts` | EIP-1193 bridge |
| `wallet/fixture.ts` | `walletPage` fixture |
| `helpers/chainArtifacts.ts` | Reads `packages/protocol/.../chain/<id>` |
| `helpers/connect.ts` | Network prep + connect |
| `helpers/rpc.ts` | Balances, WETH wrap, `isReserveLive` |
| `staking-bond-live.spec.ts` | **Bond WETH via `/staking`** |
| `swap-routes-live.spec.ts` | Deposit/swap when stack supports |
| `wave2-fee-detf.spec.ts` | Fee DETF IA (Earn exclude, redirect) |

## Assert rule

A live TX test **passes** only when at least one holds:

1. Token balance moved as expected (RPC), or  
2. Bond NFT balance increased, or  
3. UI status shows confirmed hash **and** RPC receipt succeeds

Do not treat “button click without revert” alone as success.
