# DTF application

DTF serves the full IndexedEx application on the existing DTF domains. The landing page adds a closable announcement explaining that both domains serve the same protocol and will remain available for the foreseeable future.

The notice links to indexedex.com in the current tab and @Indexedex on X in a new tab. The close button, Escape, and “Continue using DTF” advance to the temporary $DTF staking overlay. Close staking to reveal the landing page. Every landing-page visit and reload starts with the domain notice, followed by staking when dismissed. No saved dismissal skips this sequence. Internal application links stay on the current domain. No domain redirect or automatic navigation is configured.

`app` and `public` are relative symlinks to the canonical source in `../indexedex`. Edit that source to update both deployments. DTF's Next configuration sets `NEXT_PUBLIC_SITE_DEPLOYMENT=dtf`; IndexedEx sets `indexedex`. This is fixed per application build, not a wallet/network setting.

From `frontend/`:

```bash
npm run dev:dtf       # http://localhost:3003
npm run build:dtf
npm run test:e2e:dtf  # Uses the production build on port 3013
```

The dev command runs from the canonical IndexedEx directory with its own `.next-dtf` cache because Next 14’s dev route watcher does not follow the directory symlink. Both local dev servers therefore use `apps/indexedex/.env.local`; Vercel builds use each project’s environment settings.

Use the same wallet/network configuration as IndexedEx; see [wallet setup](../indexedex/WALLET_CONNECTION.md). Vercel project `dtfinance` keeps Root Directory `frontend/apps/dtf`. See [deployment settings](../../SITE_DEPLOYMENT.md).
