# Implementation plan: Multi-app frontend monorepo

> **Historical.** `apps/indexedex` and `apps/pachira` were removed. The only Next app is `frontend/apps/dtf`. Do not execute this plan.

| Field | Value |
|-------|--------|
| **Status** | **Superseded** (DTF-only) |
| **Normative product law** | [MULTI_APP_MONOREPO_PRD.md](./MULTI_APP_MONOREPO_PRD.md) |
| **Agent prompt (copy-paste)** | [MULTI_APP_MONOREPO_AGENT_PROMPT.md](./MULTI_APP_MONOREPO_AGENT_PROMPT.md) |
| **Branch** | `frontend/multi-app-monorepo` |
| **Integration** | Rebase onto `main`, then **fast-forward** `main` (linear history; no merge commits) |

This plan is the **execution checklist**. If anything conflicts with the PRD, the **PRD wins** on product/architecture; this file wins on **git/worktree/land procedure**.

---

## 0. Preconditions

- Repo: IndexedEx monorepo (`cyotee/indexedex`).
- Start from latest `origin/main` (includes `frontend/MULTI_APP_MONOREPO_PRD.md`).
- Node/npm available; Foundry not required for frontend-only work.
- Do **not** edit unrelated Solidity/hook trees unless a path conflict forces a trivial fix.
- Do **not** redesign Pachira content in this program (clone only).

---

## 1. Git / worktree procedure (mandatory)

### 1.1 Create worktree and branch

From the **primary** checkout (or any clean clone of the monorepo root):

```bash
cd "$(git rev-parse --show-toplevel)"
git fetch origin
git checkout main
git pull --ff-only origin main

# Submodule-aware worktree (preferred)
./scripts/wt-create.sh frontend/multi-app-monorepo
```

Worktree path (default script layout):

```text
<repo-parent>/indexedex-wt/frontend/multi-app-monorepo
# or: $(git rev-parse --show-toplevel)-wt/frontend/multi-app-monorepo
```

```bash
cd "<WORKTREE_PATH>"
# Confirm branch and PRD
git status -sb
test -f frontend/MULTI_APP_MONOREPO_PRD.md
```

If `wt-create.sh` fails:

```bash
git fetch origin
git worktree add -b frontend/multi-app-monorepo \
  "$(git rev-parse --show-toplevel)-wt/frontend/multi-app-monorepo" \
  origin/main
./scripts/wt-post-create.sh "$(git rev-parse --show-toplevel)-wt/frontend/multi-app-monorepo"
cd "$(git rev-parse --show-toplevel)-wt/frontend/multi-app-monorepo"
```

**All subsequent implementation commands run with cwd = worktree path.**

### 1.2 While implementing

- Commit **only** on `frontend/multi-app-monorepo`.
- Prefer small, linear commits (see phases below).
- Periodically (especially before landing):

```bash
git fetch origin
git rebase origin/main
# resolve conflicts; re-run frontend builds
```

### 1.3 Land on `main` with linear history (mandatory)

Do **not** open a merge commit. Prefer:

```bash
# In worktree, on frontend/multi-app-monorepo
git fetch origin
git rebase origin/main
# Verify builds (see §3 DoD)
npm --prefix frontend install
npm --prefix frontend run build:indexedex   # after scripts exist
npm --prefix frontend run build:pachira

# Push feature branch (optional, for backup / review)
git push -u origin frontend/multi-app-monorepo
# If branch was already pushed and rebased: git push --force-with-lease origin frontend/multi-app-monorepo

# Fast-forward main to the feature tip
git checkout main
git pull --ff-only origin main
git merge --ff-only frontend/multi-app-monorepo
git push origin main
```

If `merge --ff-only` fails, **rebase again** onto latest `origin/main` and retry — do not create a merge commit unless the operator explicitly overrides.

### 1.4 Cleanup (after successful push of main)

```bash
# From primary repo root
./scripts/wt-remove.sh frontend/multi-app-monorepo
# or: git worktree remove <path> && git branch -d frontend/multi-app-monorepo
```

Optional: delete remote feature branch after land:

```bash
git push origin --delete frontend/multi-app-monorepo
```

---

## 2. Locked decisions (do not re-litigate)

| ID | Decision |
|----|----------|
| D1 | **npm** workspaces under `frontend/` |
| D2 | Shared **`@indexedex/protocol`** only (no shared UI package in v1) |
| D3 | **Pachira = full clone** of current app at cutover |
| D4 | **Site = app** immediately (no `NEXT_PUBLIC_DEFAULT_BRAND` product model) |
| D5 | **E2E Option A** — Playwright for IndexedEx only during migration |
| D6 | Stacked phases PR1→PR4; keep tree buildable after each |
| D7 | Never duplicate addresses/ABIs per app |

Stable production URLs (must still work after Vercel root change):

- IndexedEx: https://indexedex.vercel.app  
- Pachira: https://pachirav2.vercel.app  

---

## 3. Target layout

```text
frontend/
  package.json                 # workspaces: apps/*, packages/*
  apps/
    indexedex/                 # Next app — IndexedEx
    pachira/                   # Next app — Pachira (full clone)
  packages/
    protocol/                  # @indexedex/protocol
  scripts/                     # generators; outputs → packages/protocol
  e2e/                         # Option A: IndexedEx only (root or under apps/indexedex)
```

---

## 4. Phased implementation

Each phase ends with a commit (or small set of commits). Message style: conventional, complete sentences.

### Phase PR1 — Workspace scaffold

**Goal:** npm workspaces exist; protocol package stub; no production break if still on transitional layout.

1. Convert `frontend/package.json` to workspaces root (`apps/*`, `packages/*`).
2. Create `packages/protocol` (`name`: `@indexedex/protocol`) with a minimal export.
3. Create workspace package stubs for apps if useful, or defer app dirs to PR3 (prefer creating empty app package.json shells).
4. Root scripts (names may match PRD):
   - `dev:indexedex` / `dev:pachira`
   - `build:indexedex` / `build:pachira`
   - `check` / typecheck as appropriate
5. `npm install` from `frontend/` succeeds.

**Verify:**

```bash
cd frontend && npm install
node -e "require('@indexedex/protocol')"  # or package exports smoke
```

**Commit example:** `chore(frontend): scaffold npm workspaces and protocol package stub`

---

### Phase PR2 — Extract `@indexedex/protocol`

**Goal:** Single Next consumer still works; all protocol/address access via package.

1. Move into `packages/protocol`:
   - `app/addresses/**` (and generated artifacts)
   - addressArtifacts, chain overrides, tokenlist registry/compose
   - runtime chains, network selection **core**, registry helpers
   - swap builders, permit2 helpers, shared ABIs
2. Retarget tokenlist / artifact **generators** so outputs land in the package.
3. Rewrite consumer imports to `@indexedex/protocol` / subpaths.
4. Move pure unit tests with the code where practical.
5. Ensure **no** leftover duplicate address tree under the app.

**Verify:**

```bash
cd frontend && npm install
# single app still buildable (legacy path or early apps/indexedex)
npm run build          # or build:indexedex once renamed
npm test               # / vitest for protocol + app
```

**Commit example:** `refactor(frontend): extract @indexedex/protocol package`

---

### Phase PR3 — Dual apps + site=app

**Goal:** Two apps; fixed site identity; full Pachira clone.

1. Move working Next app → `apps/indexedex`.
2. Full clone → `apps/pachira`.
3. IndexedEx: hardcode IndexedEx theme/name/logo; remove dual-brand product API.
4. Pachira: hardcode Pachira theme/name/logo.
5. Both depend on `@indexedex/protocol`.
6. Dev ports: IndexedEx `3000`, Pachira `3001` (document if using `scripts/next.mjs --port`).
7. E2E Option A: suite runs against **IndexedEx only**.

**Verify:**

```bash
cd frontend && npm install
npm run build:indexedex
npm run build:pachira
# smoke: npm run dev:indexedex & npm run dev:pachira
# e2e: IndexedEx only
```

**Commit example:** `feat(frontend): split indexedex and pachira Next apps`

---

### Phase PR4 — Vercel + docs

**Goal:** Deploy roots correct; docs match reality.

1. Vercel project `indexedex`: Root Directory = `frontend/apps/indexedex`.
2. Vercel project `pachira`: Root Directory = `frontend/apps/pachira`.
3. Update ignore-build to skip when neither that app nor `packages/protocol` (nor relevant workspace root files) changed.
4. Drop product dependency on `NEXT_PUBLIC_DEFAULT_BRAND` for site selection; keep other envs as needed.
5. Update `frontend/README.md`, PRD status, ROADMAP pointer if needed, per-app `.env.example`.
6. Confirm stable URLs still alias production (CLI or document operator steps).

**Vercel project IDs (reference):**

| Project | ID |
|---------|-----|
| indexedex | `prj_xi5Wakze0sikmYifsx1AHO7Bqyzz` |
| pachira | `prj_GtumEDCqsIPhrNkjndIdV55FR1wh` |

**Commit example:** `chore(frontend): point Vercel roots at multi-app monorepo`

---

## 5. Definition of done (program)

- [x] Work executed only in worktree branch `frontend/multi-app-monorepo` until land.
- [x] `frontend/` npm workspaces: `apps/indexedex`, `apps/pachira`, `packages/protocol`.
- [x] Protocol single-sourced; no dual address trees.
- [x] Site=app; no brand toggle product surface.
- [x] `build:indexedex` and `build:pachira` succeed.
- [x] IndexedEx e2e runnable (Option A).
- [ ] Branch rebased onto latest `origin/main`.
- [ ] `main` **fast-forwarded** to feature tip and pushed (`origin/main` linear).
- [ ] Worktree removed (or documented for operator).
- [ ] PRD status → Shipped / Implemented with date.

---

## 6. Out of scope (follow-ups)

- Pachira-specific content/page divergence.
- Shared `@indexedex/ui`.
- Dual-URL e2e matrix.
- Custom domains beyond existing aliases.

---

## 7. Operator notes

- Prefer `./scripts/wt-create.sh` / `wt-remove.sh` (nested `lib/crane` submodules).
- If the agent cannot push to GitHub or change Vercel, it must still leave a linear local branch and a clear checklist for the operator.
- Never force-push `main`. Force-with-lease only the **feature** branch after rebase if it was already published.
