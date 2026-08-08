# PRD: Multi-app frontend monorepo (shared protocol package)

| Field | Value |
|-------|--------|
| **Status** | **LOCKED for implementation** (product decisions fixed 2026-08-08) |
| **Working directory** | `frontend/` (repo root for git is still IndexedEx monorepo root) |
| **Audience** | Implementation agents in an **isolated git worktree** (parallel to other agents) |
| **Related** | [README.md](./README.md), [ROADMAP.md](./ROADMAP.md), Vercel projects `indexedex` + `pachira` |
| **Implementation plan** | [MULTI_APP_MONOREPO_IMPLEMENTATION_PLAN.md](./MULTI_APP_MONOREPO_IMPLEMENTATION_PLAN.md) |
| **Copy-paste agent prompt** | [MULTI_APP_MONOREPO_AGENT_PROMPT.md](./MULTI_APP_MONOREPO_AGENT_PROMPT.md) |

**Cold-start:** Read this entire PRD before editing. For execution order, worktree creation, rebase, and fast-forward land onto `main`, follow the **implementation plan** and/or the **agent prompt**. Do not re-open dual-brand env skinning as the long-term model. Do not invent a second contract/address stack per site.

---

## 1. Problem

IndexedEx needs **multiple public sites** that:

- Integrate with the **same** on-chain packages (registry, SE vaults, DETFs, routers, Permit2).
- Differ in **theme**, **copy/content**, and potentially **routes/pages** over time.
- Deploy independently to Vercel (`indexedex.vercel.app` vs `pachirav2.vercel.app`).

**Today (pre-migration):** one Next.js app under `frontend/` with deploy-time brand via `NEXT_PUBLIC_DEFAULT_BRAND` / CSS `data-theme`. That is enough for paint + name, **not** for diverging page sets and site-specific product surfaces.

---

## 2. Goal

Migrate `frontend/` to:

1. **npm workspaces** monorepo under `frontend/`.
2. **Shared protocol package** `@indexedex/protocol` — addresses, ABIs, chains, registry/tokenlist plumbing, low-level swap/permit helpers.
3. **Two Next apps** (full clone to start):
   - `apps/indexedex` — IndexedEx product site (blue theme).
   - `apps/pachira` — Pachira product site (green theme).
4. **Site = app immediately** — no runtime brand toggle; no `NEXT_PUBLIC_DEFAULT_BRAND` / `NEXT_PUBLIC_BRAND_LOCKED` as the product model.
5. **E2E Option A** — keep Playwright working for **one** app (IndexedEx) during migration; do not dual-URL the suite yet.

Success = both apps build locally, protocol is single-sourced, both Vercel projects deploy from new root directories with stable public URLs unchanged in intent.

---

## 3. Non-goals (v1 of this PRD)

- Extracting a shared `@indexedex/ui` design system (only if both apps share real components later).
- Diverging Pachira page content in the same PR as the split (clone first; content diffs are follow-up work).
- New Solidity / registry / deploy scripts.
- Separate git repositories per site.
- Dual e2e against both base URLs (Option B) — deferred.
- Custom domains beyond existing Vercel aliases.
- CMS / headless content platform.

---

## 4. Locked product / architecture decisions

| # | Decision | Choice |
|---|----------|--------|
| D1 | Package manager | **npm workspaces** (existing lockfile lineage) |
| D2 | Shared layer v1 | **Protocol package only** (`@indexedex/protocol`) |
| D3 | Pachira starting point | **Full clone** of the current app, then refine content later |
| D4 | Brand model | **Site = app immediately** — drop dual-brand switcher / env brand as product law |
| D5 | E2E | **Option A** — app-local / single-app (IndexedEx) during migration |
| D6 | PR strategy | **Stacked PRs** (scaffold → protocol extract → dual apps → Vercel/docs) |
| D7 | Contracts | **Never** duplicate address artifacts or ABIs per app |

---

## 5. Target directory layout

```text
frontend/
  package.json                 # workspaces root: "apps/*", "packages/*"
  package-lock.json
  apps/
    indexedex/                 # Next 14 app — IndexedEx site
      package.json             # name: @indexedex/app-indexedex (or similar)
      app/                     # App Router (moved from current frontend/app)
      public/
      next.config.js
      tsconfig.json
      vercel.json              # optional app-local; root ignore may live at frontend/
      ...
    pachira/                   # Next 14 app — Pachira site (full clone of indexedex at cutover)
      package.json             # name: @indexedex/app-pachira
      app/
      public/
      ...
  packages/
    protocol/                  # @indexedex/protocol
      package.json
      src/                     # or flat package root — pick one style and stick to it
        addresses/             # moved from app/addresses (+ generated artifacts)
        ...                    # addressArtifacts, ABIs, registry, chains, swap builders, permit2, etc.
      # tokenlist aggregator OUTPUT paths must target this package
  scripts/                     # keep generator scripts; retarget outputs to packages/protocol
  e2e/                         # Option A: keep/move with indexedex app OR root but only run vs indexedex
  # after migration, top-level app/ is GONE (or temporary re-export only during a transition PR)
```

**Import rule after extract:**

- Apps import protocol as `@indexedex/protocol` / `@indexedex/protocol/...`.
- Apps must **not** deep-import each other’s `app/` trees.
- Protocol must **not** import from `apps/*` (no Next, no React pages).

---

## 6. What goes in `@indexedex/protocol` (v1)

### Move in (first extract)

From current `frontend/app/lib` and related (adjust names as tree evolves):

| Area | Examples (current paths) |
|------|---------------------------|
| Address artifacts | `app/addresses/**`, `addressArtifacts.ts`, `chainPlatformOverrides.generated.ts` |
| Tokenlists / compose | `tokenlistCompose.ts`, `tokenlistRegistry*.ts`, contractlists |
| Chains / network | `runtimeChains.ts`, `networkSelection.tsx` (core), `browserChain.ts`, `connectorChain.ts` |
| On-chain helpers | `onchain.ts`, registry helpers under `lib/registry/**` |
| Swap / Permit2 | `swapBuilders.ts`, `swapAbis.ts`, `permit2-*.ts`, `swap/**` as pure helpers |
| ABIs used by multiple surfaces | `protocolDetfAbi.ts`, staking ABIs if shared |
| Deployment env types | `deploymentEnvironment.tsx` core types/constants (UI chrome can stay in app) |

### Keep in each app (v1)

| Area | Why |
|------|-----|
| Pages / routes under `app/` | Site-specific IA and content |
| Layout, Header, Footer | Will diverge; clone then edit |
| Theme / `globals.css` | Per-site visual identity |
| Brand chrome | Site = app; no cross-site toggle |
| Menu config / feature flags | Per-site nav |
| Research MDX / landing copy | Per-site content |
| Wagmi `providers.tsx` shell | May thin-wrap protocol chain config; OK to live in app |
| Vitest for UI | Per-app |
| Playwright (IndexedEx) | Option A |

### Explicitly out of protocol package

- React page components  
- CSS themes  
- “Pachira vs IndexedEx” runtime switch  
- Next.js `app/` router files  

---

## 7. Site identity (post-migration)

| App | Theme | Public production URL (stable) | Vercel project |
|-----|--------|---------------------------------|----------------|
| `apps/indexedex` | IndexedEx blue (`data-theme="indexedex"` or app-local equivalent) | https://indexedex.vercel.app | `indexedex` (`prj_xi5Wakze0sikmYifsx1AHO7Bqyzz`) |
| `apps/pachira` | Pachira green (`data-theme="pachira"`) | https://pachirav2.vercel.app | `pachira` (`prj_GtumEDCqsIPhrNkjndIdV55FR1wh`) |

**Remove as product surface:**

- Navbar brand/theme toggle (already removed on main; do not reintroduce).
- `NEXT_PUBLIC_DEFAULT_BRAND` / `NEXT_PUBLIC_BRAND_LOCKED` as the way to choose a site.
- Shared localStorage key for theme switching across sites.

**Hardcode (or app-local constant) per app:**

- Document title, logo asset, `data-theme` / `data-brand` in that app’s `layout.tsx`.
- Optional: `NEXT_PUBLIC_SITE=indexedex|pachira` for analytics only — **not** for loading the other site’s theme.

---

## 8. Implementation plan (stacked PRs)

Agents should implement in order. Each PR must leave `main` (or the worktree branch) **buildable**.

### PR1 — Workspace scaffold (no product behavior change)

1. Convert `frontend/package.json` to **npm workspaces** root (`apps/*`, `packages/*`).
2. Create `packages/protocol` with a minimal public export (e.g. `package name` + `export const PROTOCOL_PACKAGE = true`).
3. Create stub Next apps **or** hold apps until PR3 — preferred: create workspace dirs + root scripts early.
4. Root scripts (examples):
   - `npm run dev:indexedex` / `dev:pachira`
   - `npm run build:indexedex` / `build:pachira`
   - `npm run check` → typecheck/test workspaces as appropriate
5. Document how to `npm install` from `frontend/`.

**DoD PR1:** `npm install` works; protocol package resolves from a workspace consumer; no broken production path if apps not moved yet (acceptable: still single legacy tree until PR2/3 if scaffold-only).

### PR2 — Extract `@indexedex/protocol`

1. Move protocol modules + `addresses/**` + generated artifacts into `packages/protocol`.
2. Update **tokenlist aggregator** output paths (`scripts/node` or whatever currently writes into `app/lib` / `app/addresses`) to write into the package.
3. Rewrite imports in the **still-single** Next app (legacy `frontend/app` or early `apps/indexedex`) to `@indexedex/protocol`.
4. Move pure unit tests that cover protocol into the package (or keep vitest at root with package include).
5. Ensure `npm run build` / `typecheck` / unit tests pass for the consumer app.

**DoD PR2:** One working Next app; **all** address/ABI/registry/swap-builder access goes through `@indexedex/protocol`; no duplicate address trees left under the app.

### PR3 — Dual apps + site=app

1. Move current Next application into `apps/indexedex`.
2. **Full clone** → `apps/pachira` (same routes/components initially).
3. IndexedEx app: fixed IndexedEx theme/name/logo; strip any residual dual-brand API.
4. Pachira app: fixed Pachira theme/name/logo; same.
5. Wire workspace dependencies: both apps depend on `@indexedex/protocol`.
6. Ports: IndexedEx default `3000`, Pachira default `3001` (or document `scripts/next.mjs --port`).
7. E2E **Option A:** Playwright runs against **IndexedEx** only (move `e2e/` under `apps/indexedex` or keep root with `baseURL` pointing at indexedex dev server). Do **not** require a green dual-site matrix.

**DoD PR3:**

```bash
cd frontend
npm install
npm run build:indexedex
npm run build:pachira
npm run dev:indexedex   # smoke
npm run dev:pachira     # smoke
```

Both apps load; themes differ; no brand toggle; same protocol package.

### PR4 — Vercel + docs

1. Set Vercel **Root Directory**:
   - `indexedex` project → `frontend/apps/indexedex`
   - `pachira` project → `frontend/apps/pachira`
2. Update ignored build step so monorepo changes rebuild only when that app or `packages/protocol` (or shared root config) changes. Suggested logic:
   - Skip if no changes under `frontend/apps/<name>/**`, `frontend/packages/protocol/**`, and relevant root workspace files.
3. Env vars:
   - Remove reliance on `NEXT_PUBLIC_DEFAULT_BRAND` for site selection.
   - Keep other shared flags as needed (`NEXT_PUBLIC_SHOW_DEBUG`, RPC URLs, etc.) per project.
4. Confirm stable aliases still serve production:
   - https://indexedex.vercel.app  
   - https://pachirav2.vercel.app  
5. Update `frontend/README.md`, this PRD status, and [ROADMAP.md](./ROADMAP.md) pointer.
6. Update `.env.example` files **per app**.

**DoD PR4:** Push that touches only docs does not need a perfect deploy; a push that touches an app or protocol produces the correct project deploy; public URLs above remain the shareable production URLs.

---

## 9. Vercel reference (current, pre- and post-migration)

| Project | Project ID (org `cyotees-projects`) | Stable production URL |
|---------|--------------------------------------|------------------------|
| `indexedex` | `prj_xi5Wakze0sikmYifsx1AHO7Bqyzz` | https://indexedex.vercel.app |
| `pachira` | `prj_GtumEDCqsIPhrNkjndIdV55FR1wh` | https://pachirav2.vercel.app |

Git: `cyotee/indexedex`, production branch `main`.

**Note:** `pachira.vercel.app` is **taken** by another project; use `pachirav2.vercel.app`.

Pre-migration Root Directory is `frontend`. Post-migration must be `frontend/apps/<site>`.

---

## 10. E2E Option A (detail)

| Policy | Detail |
|--------|--------|
| During migration | One suite, one target app (**IndexedEx**) |
| Commands | Prefer `npm run test:e2e -w apps/indexedex` (or root script that starts indexedex only) |
| Pachira | No requirement to pass Playwright until content divergence work begins |
| Later (out of scope) | Optional shared critical-path suite with `BASE_URL` matrix |

---

## 11. Testing requirements

| Layer | Requirement |
|-------|-------------|
| Protocol package | Unit tests for pure helpers moved with the code |
| Each app | `next build` succeeds |
| IndexedEx | Existing vitest suite still runs (paths updated) |
| IndexedEx e2e | Smoke or full suite as previously expected for one app — fix breakage from moves |
| Hermetic Foundry | **Out of scope** of this PRD (Solidity CI unchanged) |
| Fork RPC | Do not introduce CI that hits Alchemy for frontend |

**Frontend deploy rule from ROADMAP:** product agents normally must not run forge deploys. This PRD **allows** Vercel project setting updates and production alias verification for the multi-app cutover only.

---

## 12. Risks and mitigations

| Risk | Mitigation |
|------|------------|
| Import churn breaks build | PR2 completes with single app green before PR3 clone |
| Tokenlist generator writes old paths | Update generator + regenerate in same PR as extract |
| Vercel root wrong → empty deploy | Change one project at a time; verify URL |
| Premature shared UI package | Forbidden in v1 |
| Parallel agents conflict | This work runs in its **own worktree/branch**; do not edit unrelated contracts packages in the same branch without need |
| Dual-brand env left half-alive | PR3 removes product use of `NEXT_PUBLIC_DEFAULT_BRAND` |

---

## 13. Worktree / agent operating rules

1. Create an isolated branch/worktree for this PRD (e.g. `frontend/multi-app-monorepo`).
2. Do not block or rewrite parallel agents’ contract/hook work unless a path conflict is unavoidable.
3. Prefer small commits: scaffold → extract → split → vercel/docs.
4. Do not “improve” Earn/Swap product behavior while moving files unless required to compile.
5. After cutover, Pachira content/theme refinement is a **separate** PRD/tasks list.

---

## 14. Definition of done (whole program)

- [ ] `frontend/` is npm workspaces with `apps/indexedex`, `apps/pachira`, `packages/protocol`.
- [ ] `@indexedex/protocol` owns addresses/ABIs/registry/chain/swap-builder sources; apps consume it.
- [ ] No dual-brand runtime toggle; each app has fixed site identity.
- [ ] `npm run build:indexedex` and `npm run build:pachira` succeed.
- [ ] IndexedEx e2e (Option A) still runnable.
- [ ] Vercel roots point at the two apps; production URLs:
  - https://indexedex.vercel.app  
  - https://pachirav2.vercel.app  
- [ ] README + this PRD status updated to **Shipped** (or **Implemented** with date).

---

## 15. Follow-up work (explicitly after this PRD)

- Pachira-only pages, landing, research, nav diffs.
- Optional `@indexedex/ui` if duplication hurts.
- Optional dual-URL e2e matrix (Option B).
- Per-app CI path filters.

---

## 16. Status log

| Date | Note |
|------|------|
| 2026-08-08 | PRD written; decisions D1–D7 locked; ready for parallel worktree implementation |

**Implementing agent:** set status to **In progress** when starting PR1; **Shipped** when §14 is complete.
