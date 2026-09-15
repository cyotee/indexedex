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

<!-- BEGIN:nextjs-agent-rules -->

# This is NOT the Next.js you know

This version has breaking changes — APIs, conventions, and file structure may all differ from your training data. Read the relevant guide in `node_modules/next/dist/docs/` (resolved from this file's directory; in monorepos the `next` package may not be visible from the repo root) before writing any code. Heed deprecation notices.

This block is written and re-added by `next dev` — verify at `node_modules/next/dist/server/lib/generate-agent-files.js`. Removing it from a diff only re-creates the uncommitted change; committing it with your work keeps the tree clean.

<!-- END:nextjs-agent-rules -->
