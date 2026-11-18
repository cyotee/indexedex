# DTF connected-wallet + live TX e2e

Playwright suite for **`@indexedex/app-indexedex`** (port **3002**).

Injected EIP-1193 wallet (Anvil key) — **not** MetaMask. Default chain: **4663** (Robinhood Anvil fork).

## Prerequisites

1. Install the workspace dependencies (from `frontend/`). The default runner builds
   and starts the production app with the same environment before running tests.
2. Chromium: `npm run test:e2e:install -w @indexedex/app-indexedex`
3. **For live TX specs:** Anvil already running with matching artifacts:
   - An operator-provided RPC with chain ID **4663**, matching the exported deployments
   - Artifacts under `frontend/packages/protocol/src/addresses/chain/4663/`

Agents: follow skill **`indexedex-ui-tx-testing`** and `frontend/ROADMAP.md`.
Do not start Anvil or deploy contracts to supply missing fixtures. Missing RPCs,
markets, or listed vaults must be reported; an address artifact does not prove
that the corresponding contract is available.

## Run

```bash
cd frontend

# IndexedEx production build + browser tests (no RPC required for most)
npm run test:e2e -w @indexedex/app-indexedex

# Live txs only (needs Anvil)
npm run test:e2e:live -w @indexedex/app-indexedex

# Build + check both site deployment modes, sequentially (shared .next)
npm run test:e2e:deployment
npm run test:e2e:dtf

# Reuse an explicitly configured local IndexedEx dev server
NEXT_PUBLIC_DEFAULT_CHAIN_ID=4663 \
NEXT_PUBLIC_DEFAULT_DEPLOYMENT_ENVIRONMENT=anvil_robinhood_main \
NEXT_PUBLIC_LOCAL_RPC_URL=http://127.0.0.1:8545 npm run dev:indexedex
# In another terminal:
E2E_SKIP_WEBSERVER=1 npm run test:e2e
```

Next.js freezes `NEXT_PUBLIC_*` variables during `next build`. Setting them only
on `next start` cannot change the browser's wallet networks, RPC, or domain notice.
The default browser runner supplies the local chain/RPC settings to both build
and start, with `NEXT_PUBLIC_SITE_DEPLOYMENT=indexedex`. The deployment runner
likewise builds with `E2E_SITE_DEPLOYMENT` (`indexedex` by default, or `dtf`).
Neither runner reuses an unverified existing server. Run these commands
sequentially: they all write the app's shared `.next` directory.

`E2E_SKIP_WEBSERVER=1` and `E2E_WEB_SERVER_CMD` are explicit opt-outs from the
default build/start contract. An existing server or custom command must use the
same build-time environment as the test target. DTF's separate dev command runs
on port **3003** and includes its domain announcement; the general suite targets
IndexedEx, while the deployment suite checks both notice modes.

## Env

| Variable | Default | Role |
|----------|---------|------|
| `E2E_CHAIN_ID` | `4663` | Injected wallet + selected network |
| `E2E_RPC_URL` | `http://127.0.0.1:8545` | JSON-RPC for inject + balance asserts |
| `E2E_PORT` | `3002` | App port |
| `E2E_SKIP_WEBSERVER` | unset | Set `1` to use existing `dev`/`start` |
| `E2E_BASE_URL` | `http://127.0.0.1:$PORT` | Override base URL |
| `E2E_WEB_SERVER_CMD` | build then start | Custom server command; caller owns its build-time environment |
| `E2E_SITE_DEPLOYMENT` | `indexedex` | Deployment suite only: `indexedex` or `dtf` |

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
