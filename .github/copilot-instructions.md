# Copilot instructions for IndexedEx

Before working in this monorepo, read and follow [CLAUDE.md](../CLAUDE.md),
the shared agent router. Follow its non-negotiables and open its task-specific
skills, product law, PRDs, and navigation documents on demand.

Before code changes, read [ASSISTANT_RULES.md](ASSISTANT_RULES.md) and its
coding, deployment, and testing documents. Use the current paths and workflows
in `CLAUDE.md` when older examples differ.

- Crane lives in `lib/crane/`; `@crane/` maps to `lib/crane/` in `remappings.txt`.
- Use CREATE3 / FactoryServices for facets and the IndexedEx manager vault
  registry for registered vault/DETF packages.
- Use production-first TestBases and follow the shared router's mock policy.
- After production contract edits, run `forge build` before `forge test` or
  `forge script`, because FactoryServices read creation bytecode from `out/`.
- Follow the router's Foundry compile patience and worktree cache-seeding rules.
- Both frontend deployments build `frontend/apps/indexedex`; `NEXT_PUBLIC_SITE_DEPLOYMENT=dtf` enables the landing notice. There is no separate DTF app package; use `frontend/ROADMAP.md`.

Canonical skill locations and refresh instructions are in
[docs/agent/SKILL_CATALOG.md](../docs/agent/SKILL_CATALOG.md).
