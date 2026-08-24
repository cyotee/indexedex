# Down To Finance (DTF)

| Field | Value |
|-------|--------|
| **Package** | `@indexedex/app-dtf` |
| **Vercel project** | `dtfinance` |
| **Project ID** | `prj_C2isVxdLcM7hTwg3v55drxe5wZKT` |
| **Production URL** | https://downto.finance |
| **App host** | https://app.downto.finance (`/` redirects to `/explore`) |
| **Root Directory** | `frontend/apps/dtf` |
| **Git repo** | https://github.com/cyotee/indexedex (connected) |

## Local

```bash
cd frontend
npm install
npm run dev:dtf   # :3002
```

**Default chain:** Robinhood **4663** (Anvil RH fork). Artifacts: `@indexedex/protocol` → `addresses/chain/4663/`.

```bash
# Env overrides
NEXT_PUBLIC_DEFAULT_CHAIN_ID=4663
NEXT_PUBLIC_DEFAULT_DEPLOYMENT_ENVIRONMENT=anvil_robinhood_main
NEXT_PUBLIC_LOCAL_RPC_URL=http://127.0.0.1:8545
```

## E2E (connected wallet + live txs)

See `e2e/README.md` and skill **`indexedex-ui-tx-testing`**.

```bash
cd frontend
npm run build -w @indexedex/app-dtf
npm run test:e2e:install -w @indexedex/app-dtf
npm run test:e2e:dtf          # shell / IA
# with Anvil 4663 running (fee_detf or main stack):
npm run test:e2e:dtf:live     # bond + deposit live paths
```

## Deploy

Git pushes to the connected branch trigger builds when `frontend/apps/dtf`, `frontend/packages/protocol`, or workspace root change (`vercel-ignore-build.sh dtf`).

**Hosts:** `downto.finance` is the marketing landing. `app.downto.finance` is the product (Explore, Create, wallet). Middleware redirects `app.downto.finance/` to `/explore` and sends other apex paths to the app host. Localhost and `*.vercel.app` stay single-origin.

Set `NEXT_PUBLIC_APP_ORIGIN=https://app.downto.finance` on the Vercel **production** environment so landing CTAs leave the apex. Leave it unset locally.

Settings (already applied on the Vercel project):

- Framework: Next.js  
- Install: `cd ../.. && npm install`  
- Build: `cd ../.. && npm run build -w @indexedex/app-dtf`  
- Root: `frontend/apps/dtf`
