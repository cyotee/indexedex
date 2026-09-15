# Next.js 16 upgrade

Branch: `upgrade/nextjs-16`, based on the shared-root release `aca16198`.
Versions checked against npm stable tags on 2026-09-14:

| Package | Version |
| --- | --- |
| Next.js / eslint-config-next | 16.3.5 |
| React / React DOM / React types | 19.3.0 |
| TanStack React Query | 5.102.8 |
| ESLint | 9.39.5 |

Next.js requires Node 20.9+ and TypeScript 5.1+. Use Node 22.13+ for the full
current toolchain; verification uses Node 22.23.1 and Vercel uses Node 24.
TypeScript remains 5.4.5. ESLint 9 is retained for the supported peer range of
`eslint-plugin-react`; moving to ESLint 10 is a separate compatibility update.

## Migration choices

- Earn and Insights address wrappers, research pages/metadata, and the `/you`
  redirect await Promise-based route props. Eight regression tests cover forwarding,
  content selection, missing content, and preservation of repeated query values.
- `outputFileTracingRoot` is a stable top-level Next setting. It still points to
  the repository root for Vercel packaging.
- Build and dev scripts explicitly use `--webpack`. The custom wallet SDK alias
  is preserved; Turbopack and React Compiler are not enabled as part of this update.
- ESLint uses flat config and its own CLI. The build script explicitly runs lint
  before Next builds. Core hooks rules remain enforced; new compiler-readiness rules
  (`set-state-in-effect`, `preserve-manual-memoization`, `refs`, `purity`) report
  warnings rather than forcing unrelated transaction-state rewrites into this upgrade.
- React Query is updated because the previous 5.45.1 release only declared React 18
  support. RainbowKit 2.2.11 and Wagmi 2.19.5 retain their versions and the existing
  RainbowKit patch still applies.
- Workspace-root React runtime/type pins and overrides prevent npm from retaining
  React 18 for hoisted wallet/Next dependencies while installing React 19 locally.
  The Hooks linter's `zod-validation-error` is pinned to compatible 4.0.2 because
  its accepted 3.5.4 release does not export the `/v4` subpath the linter imports.
- Type checking runs `next typegen` first. Next's automatic JSX runtime is enabled.
  Generated development types live under `.next-indexedex/dev/types` and
  `.next-dtf/dev/types`; development cache isolation is retained.
- `allowedDevOrigins` explicitly allows the local Playwright host `127.0.0.1`;
  no wildcard or remote origins are added to the development allowlist.
- Vitest uses automatic JSX transformation for route-wrapper tests and four workers
  to avoid exhausting resources alongside framework builds.

## Verification

From `frontend/`, run sequential production variants (both write `.next`):

```bash
npm ci
npm run check -w @indexedex/app-indexedex
npm run typecheck -w @indexedex/protocol
npm run build:indexedex
npm run test:e2e:deployment
npm run build:dtf
npm run test:e2e:dtf
```

The deployment browser suite covers desktop/mobile domain notice behavior,
research route rendering/metadata, a missing research slug, the portfolio alias's
query preservation, and opening the wallet dialog without signing transactions.

Both dev instances can run concurrently with `npm run dev:indexedex` (3002) and
`npm run dev:dtf` (3003). No production deployment, contract deployment, or chain
transaction is part of the upgrade verification. See [SITE_DEPLOYMENT.md](SITE_DEPLOYMENT.md)
before a separately authorized publication.

Version-matched framework docs are installed in `node_modules/next/dist/docs/`.
Official migration guide: https://nextjs.org/docs/app/guides/upgrading/version-16
