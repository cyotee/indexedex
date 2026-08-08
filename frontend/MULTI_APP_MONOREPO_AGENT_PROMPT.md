# Agent prompt — multi-app monorepo (copy all below the line)

Copy everything from the horizontal rule to the end of the file into a **new agent session**.  
That agent should create its own worktree, implement the plan, rebase onto `main`, and **fast-forward** `main` for a linear history.

---

You are an implementation agent for the IndexedEx monorepo.

## Mission

Implement the frontend multi-app monorepo migration end-to-end:

1. Create an isolated git worktree + branch.
2. Execute the implementation plan (PR1 → PR4).
3. Rebase onto latest `main`.
4. Fast-forward `main` to your branch and push so `origin/main` has a **clean linear history** (no merge commits).
5. Clean up the worktree when done (or leave clear instructions if cleanup is blocked).

## Authoritative docs (read in full before editing)

| Doc | Role |
|-----|------|
| `frontend/MULTI_APP_MONOREPO_PRD.md` | Product/architecture law (wins on design) |
| `frontend/MULTI_APP_MONOREPO_IMPLEMENTATION_PLAN.md` | Execution checklist + **git/land procedure** (wins on process) |

Also skim `frontend/ROADMAP.md` for frontend context. Do **not** treat root `PROGRESS.md` as the frontend roadmap.

## Locked decisions (do not re-open)

- **npm** workspaces under `frontend/`.
- Shared package: **`@indexedex/protocol` only** (addresses, ABIs, chains, registry/tokenlist, swap/permit helpers). No shared UI package in v1.
- **`apps/indexedex`** + **`apps/pachira`**; Pachira starts as a **full clone** of the current app.
- **Site = app immediately** — no `NEXT_PUBLIC_DEFAULT_BRAND` / brand toggle as the product model.
- **E2E Option A** — Playwright for **IndexedEx only** during migration.
- Do **not** redesign Pachira content in this task.
- Do **not** take on unrelated Solidity/hook/compliance work.

Stable production URLs (preserve intent after Vercel root change):

- https://indexedex.vercel.app  
- https://pachirav2.vercel.app  

## Step A — Create worktree (do this first)

From the monorepo root of whatever checkout you started in:

```bash
cd "$(git rev-parse --show-toplevel)"
git fetch origin
git checkout main
git pull --ff-only origin main

./scripts/wt-create.sh frontend/multi-app-monorepo
```

Default worktree path:

```text
$(git rev-parse --show-toplevel)-wt/frontend/multi-app-monorepo
```

```bash
cd "$(git rev-parse --show-toplevel)-wt/frontend/multi-app-monorepo"
# ALL further work happens here
git status -sb
test -f frontend/MULTI_APP_MONOREPO_PRD.md
```

Fallback if `wt-create.sh` fails: `git worktree add -b frontend/multi-app-monorepo <path> origin/main` then `./scripts/wt-post-create.sh <path>`.

**Never edit files in the original main checkout for this feature.** Use only the worktree path.

## Step B — Implement (linear commits on the feature branch)

Work only on branch `frontend/multi-app-monorepo`. Follow phases in `MULTI_APP_MONOREPO_IMPLEMENTATION_PLAN.md`:

| Phase | Outcome |
|-------|---------|
| **PR1** | npm workspaces; `@indexedex/protocol` stub; root scripts |
| **PR2** | Protocol extract; generators retargeted; single app still builds |
| **PR3** | `apps/indexedex` + full-clone `apps/pachira`; site=app; e2e IndexedEx only |
| **PR4** | Vercel roots `frontend/apps/indexedex` and `frontend/apps/pachira`; ignore-build; docs/env |

After each phase: keep the tree buildable; commit with a clear conventional message.

Verify before landing (after PR3+ scripts exist):

```bash
cd frontend
npm install
npm run build:indexedex
npm run build:pachira
# IndexedEx e2e Option A if previously expected / fix breakages from moves
```

## Step C — Rebase onto main (before land)

```bash
# still on frontend/multi-app-monorepo in the worktree
git fetch origin
git rebase origin/main
# resolve conflicts; re-run builds
```

If the feature branch was already pushed, update remote with:

```bash
git push --force-with-lease origin frontend/multi-app-monorepo
```

**Never force-push `main`.**

## Step D — Fast-forward main (linear history)

```bash
git checkout main
git pull --ff-only origin main
git merge --ff-only frontend/multi-app-monorepo
git push origin main
```

If `--ff-only` fails: go back to the feature branch, `git rebase origin/main` again, re-verify builds, retry. **Do not** `git merge` without `--ff-only` unless the human operator explicitly overrides.

Optional backup before deleting the feature branch:

```bash
git push -u origin frontend/multi-app-monorepo
```

## Step E — Cleanup

```bash
cd "$(git rev-parse --show-toplevel)"   # primary repo if different
# From primary monorepo root:
./scripts/wt-remove.sh frontend/multi-app-monorepo
# optional:
git push origin --delete frontend/multi-app-monorepo
```

If you cannot remove the worktree or push, report exact paths and remaining commands for the operator.

## Step F — Final report to the human

Include:

1. Worktree path used  
2. Final commit SHAs on `main` (range landed)  
3. How to run both apps locally  
4. Vercel settings applied or still needed (Root Directory, ignore command, env)  
5. Anything deferred (Pachira content, dual e2e, etc.)

## Anti-patterns

- Merge commits onto `main`
- Force-pushing `main`
- Editing the non-worktree checkout for this feature
- Reintroducing dual-brand env site selection
- Duplicating address/ABI trees per app
- Scope creep into contract/hook PRDs
- “Improving” product UX while only moving structure

## Start now

1. Create the worktree (`Step A`).  
2. Read both docs fully.  
3. Execute PR1.  
4. Continue through PR4, rebase, fast-forward `main`, cleanup, report.
