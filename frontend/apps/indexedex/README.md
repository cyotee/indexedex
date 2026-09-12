# IndexedEx

The main application at [indexedex.com](https://indexedex.com). This preserves the former DTF product app, including staking, RainbowKit wallet connections, Explore, Create and research.

From `frontend/`:

```bash
npm run dev:indexedex       # http://localhost:3002
npm run build:indexedex
npm test
npm run test:e2e:indexedex
```

Wallet settings: [WALLET_CONNECTION.md](WALLET_CONNECTION.md). Staking migration UI: [STAKING_MIGRATION_UI.md](STAKING_MIGRATION_UI.md). Browser tests: [e2e/README.md](e2e/README.md).

The shared protocol package provides the existing addresses, ABIs and chain configuration. Moving the app does not deploy contracts or change deployment artifacts.

Vercel project `indexedex` must use Root Directory `frontend/apps/indexedex` and build workspace `@indexedex/app-indexedex`. See [SITE_DEPLOYMENT.md](../../SITE_DEPLOYMENT.md) before publishing: the remote project previously built from `apps/dtf`.
