# IndexedEx and DTF deployments

Owner decision, 2026-09-14: one Next.js application root, two independent Vercel projects. Both domains serve the full application for the foreseeable future. DTF adds a closable landing-page domain/X announcement; no automatic navigation or domain redirect is configured.

## One source and a build-time setting

Both projects build `frontend/apps/indexedex` (`@indexedex/app-indexedex`). The former `apps/dtf` package and source symlinks are removed. Routes, assets, providers and `@indexedex/protocol` are shared without copies.

`NEXT_PUBLIC_SITE_DEPLOYMENT=indexedex` disables the domain notice; `dtf` enables it. Unset defaults to `indexedex`; any other value fails the build. The value is compiled into the application, not selected by hostname or wallet network. Changing it requires a new build; changing only the environment of `next start` cannot switch an existing build.

The notice appears only on DTF's landing page. Close, Escape and Continue reveal the landing page; each new visit/reload shows the notice again. The IndexedEx link opens in the current tab and X in a new tab. Other routes remain directly accessible and internal navigation stays on the current domain. The temporary staking overlay has already been removed following migration; this change does not restore it.

## Required Vercel settings

| Setting | IndexedEx | DTF |
|---------|-----------|-----|
| Existing project | `indexedex` | `dtfinance` |
| Project ID | `prj_lWXZSeaIe9SOk6q7P30rHXxV2X30` | `prj_C2isVxdLcM7hTwg3v55drxe5wZKT` |
| Root Directory | `frontend/apps/indexedex` | `frontend/apps/indexedex` |
| Framework | Next.js | Next.js |
| Install Command | `cd ../.. && npm install` | Same |
| Build Command | `cd ../.. && npm run build -w @indexedex/app-indexedex` | Same |
| Output Directory | Next.js default (`.next`) | Same |
| Ignored Build Step | `bash ../../scripts/vercel-ignore-build.sh` | Same |
| `NEXT_PUBLIC_SITE_DEPLOYMENT` | `indexedex` | `dtf` |
| Domains | `indexedex.com` | Existing DTF domains, including `downto.finance` and `app.downto.finance` |

Set the variable for **Production and Preview**, plus Development when using pulled project environments. Enable access to files outside the Root Directory for shared protocol/workspace dependencies. The checked-in `vercel.json` applies to both projects. Do not use the workspace-level `npm run build` in Vercel: that deliberately builds both variants sequentially for local validation. Each Vercel project must build only its own variant using the command above.

Keep the intended network, deployment artifacts and wallet settings consistent. `NEXT_PUBLIC_APP_ORIGIN` is unused. No domain reassignment is needed; the projects remain separate and independently releasable.

## Dashboard migration and rollout

These are required operator changes, not settings automatically applied by editing the repository:

1. Compare both projects' environment settings and save their current Root Directory/build overrides for rollback.
2. Set the deployment variable in each project and remove the obsolete `INDEXEDEX_DTF_DEV` setting if present.
3. Change DTF's Root Directory from `frontend/apps/dtf` to `frontend/apps/indexedex`. Align both projects' commands with the table and remove conflicting dashboard overrides.
4. Create previews from this UI branch in both projects. Force a fresh build when changing only environment settings (an ignored-build check may otherwise skip an unchanged commit).
5. Verify `/`, `/explore` and `/staking` on both previews. DTF alone must show the notice; verify close/Continue/Escape, repeat visits and both external links. Verify wallet connection without sending transactions.
6. Only after preview approval, release the same revision through both production projects. Preserve each project's domains without redirects.

Rollback uses each project's previous deployment. If reverting source to a revision with the DTF shell, restore DTF's old Root Directory/build settings before rebuilding that revision. The repository-root `.vercel` link belongs to DTF; do not infer the target project from a local link when publishing. Production publication requires explicit owner authorization and never authorizes contract transactions.

## Local verification

From `frontend/`, run in separate terminals:

```bash
npm run dev:indexedex  # http://localhost:3002, notice off
npm run dev:dtf        # http://localhost:3003, notice on
```

Both use `apps/indexedex/.env.local`; the scripts override only the deployment setting. Development output is isolated in `.next-indexedex` and `.next-dtf`. Scripts do not kill arbitrary port listeners; stop the relevant old server before starting a replacement. No Anvil restart or contract deployment is required.

Production verification is sequential because local production builds use `.next`:

```bash
npm run build:indexedex
npm run test:e2e:deployment  # starts production server on 3012
npm run build:dtf
npm run test:e2e:dtf         # starts production server on 3013
```

To verify existing dev instances instead:

```bash
E2E_BASE_URL=http://127.0.0.1:3002 npm run test:e2e:deployment
E2E_BASE_URL=http://127.0.0.1:3003 npm run test:e2e:dtf
```

The deployment suite covers desktop and mobile. The standard app suite remains under `npm run test:e2e` and excludes these variant-specific tests. Run `npm run test:deployment -w @indexedex/app-indexedex` for configuration defaults, invalid settings and output isolation.
