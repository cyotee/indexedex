# IndexedEx

The main application at [indexedex.com](https://indexedex.com). This preserves the former DTF product app, including staking, RainbowKit wallet connections, Explore, Create and research.

From `frontend/`:

```bash
npm run dev:indexedex       # http://localhost:3002
npm run dev:dtf             # http://localhost:3003, same app with domain notice
npm run build:indexedex
npm run build:dtf
npm test
npm run test:e2e:indexedex
npm run test:e2e:dtf        # after build:dtf; desktop + mobile notice checks
```

Wallet settings: [WALLET_CONNECTION.md](WALLET_CONNECTION.md). Staking migration UI: [STAKING_MIGRATION_UI.md](STAKING_MIGRATION_UI.md). Browser tests: [e2e/README.md](e2e/README.md).

The shared protocol package provides the existing addresses, ABIs and chain configuration. Moving the app does not deploy contracts or change deployment artifacts.

Both Vercel projects (`indexedex` and `dtfinance`) use Root Directory `frontend/apps/indexedex` and build workspace `@indexedex/app-indexedex`. Set `NEXT_PUBLIC_SITE_DEPLOYMENT=indexedex` or `dtf` respectively in each project's Production and Preview environments. This build-time setting controls only the DTF domain notice, not wallet networks or application branding. Invalid values fail configuration; unset defaults to IndexedEx. See [SITE_DEPLOYMENT.md](../../SITE_DEPLOYMENT.md) for the dashboard migration checklist.

Local development uses `.next-indexedex` and `.next-dtf`, so both variants can run concurrently using the same `.env.local`. Scripts set the variant explicitly. Production builds share `.next` locally: build and test one variant before building the other. Vercel builds are isolated. Restart dev servers or rebuild production after changing the setting; changing it only on `next start` does not switch a compiled application's notice.
