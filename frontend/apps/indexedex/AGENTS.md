# Shared frontend application

Read the repository's [CLAUDE.md](../../../CLAUDE.md) and
[frontend roadmap](../../ROADMAP.md) before changing this app.

Next.js is pinned to 16.3.5. Version-matched documentation is bundled at
`../../node_modules/next/dist/docs/` from this directory (npm workspace hoisting).
Read its upgrade/API guides when changing framework configuration or route APIs.

- Route `params` and `searchParams` are promises; await them in server wrappers.
- Both Vercel projects build this root. Preserve the build-time deployment flag.
- Use the package scripts: Webpack preserves the wallet SDK browser-entry alias.
- `npm run typecheck` generates route types; `npm run build` includes ESLint because
  Next.js no longer runs lint during builds.
- See [upgrade notes](../../NEXTJS_UPGRADE.md) for dependency alignment and checks.
