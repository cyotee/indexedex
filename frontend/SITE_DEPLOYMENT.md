# IndexedEx and DTF deployments

Owner decision, 2026-09-12: serve the full application on both domains for the foreseeable future. DTF shows a closable landing-page announcement explaining that both domains serve the same protocol. Visitors can continue on DTF or open IndexedEx. This supersedes the standalone announcement and configurable redirect-page proposals.

The IndexedEx link opens in the current tab; the @Indexedex X link opens in a new tab. No automatic or domain-level redirect is configured. Closing with the close button, Escape, or “Continue using DTF” advances to the temporary $DTF staking overlay for that visit. Closing the staking overlay then reveals the landing page. Every landing-page visit and reload starts with the domain notice again, even if an older version saved a dismissal. Other app routes remain directly available. IndexedEx shows only the temporary $DTF staking form. DTF mounts that form only after the domain notice is dismissed, so only one overlay is active at a time. The form reads the actual staking phase; it does not announce migration completion before it happens. RainbowKit remains usable while the staking dialog temporarily releases its modal focus.

## Shared source

`frontend/apps/indexedex` is the canonical application. `frontend/apps/dtf/app` and `public` are relative symlinks to that source. Both projects build the same routes, wallet providers, shared protocol package, and assets. DTF imports the shared Next configuration and sets its deployment identity to `dtf`; IndexedEx sets `indexedex`. The notice is selected at build time. Do not copy or independently maintain product pages in DTF.

## Vercel configuration

| Setting | IndexedEx | DTF |
|---------|-----------|-----|
| Existing project | `indexedex` | `dtfinance` |
| Project ID | `prj_lWXZSeaIe9SOk6q7P30rHXxV2X30` | `prj_C2isVxdLcM7hTwg3v55drxe5wZKT` |
| Root Directory | `frontend/apps/indexedex` | `frontend/apps/dtf` |
| Framework | Next.js | Next.js |
| Install Command | `cd ../.. && npm install` | `cd ../.. && npm install` |
| Build Command | `cd ../.. && npm run build -w @indexedex/app-indexedex` | `cd ../.. && npm run build -w @indexedex/app-dtf` |
| Ignored Build Step | `bash ../../scripts/vercel-ignore-build.sh indexedex` | `bash ../../scripts/vercel-ignore-build.sh dtf` |
| Domains | `indexedex.com` | Existing DTF domains, including `downto.finance` and `app.downto.finance` |

Enable access to files outside each Root Directory for the shared source, assets and npm workspace. Output tracing is rooted at the repository root so Vercel resolves each app and its shared runtime dependencies correctly. Preserve symlinks when checking out the repository. Use each app's checked-in `vercel.json` without conflicting project overrides. Changes to the shared IndexedEx source or protocol package trigger builds for both projects.

## Publishing

Both projects deploy from `main`. IndexedEx must use the IndexedEx Root Directory and build command above; using `apps/dtf` would show the DTF domain notice on IndexedEx.

Configure the same intended network and deployment artifacts for both projects. Keep wallet settings (including any future WalletConnect project ID) consistent. `NEXT_PUBLIC_APP_ORIGIN` is unused; application links remain on the current host. Do not override `NEXT_PUBLIC_SITE_DEPLOYMENT` in the dashboard; each app's Next configuration sets it.

Preview both builds before publishing: `/`, `/explore` and `/staking` should work on both domains, and the domain announcement should appear only on DTF's landing page. Check close/continue/Escape and the two external links. Keep DTF domains serving `dtfinance` directly, without domain redirects.

The repository-root `.vercel` link belongs to DTF; do not use it to deploy IndexedEx. Publishing these frontends does not deploy contracts or perform the staking migration.

## Local review

From `frontend/`, `npm run dev` starts IndexedEx on port 3002 and `npm run dev:dtf` starts DTF on port 3003. Both local dev commands load `apps/indexedex/.env.local`. DTF dev runs directly from the canonical source (Next 14’s route watcher cannot follow the app-directory symlink), with `INDEXEDEX_DTF_DEV=true` selecting its notice and separate `.next-dtf` cache. This flag is local to the dev command; do not set it on Vercel. Production builds use each app directory and its project environment settings. No contract deployment or Anvil restart is part of this UI change.
