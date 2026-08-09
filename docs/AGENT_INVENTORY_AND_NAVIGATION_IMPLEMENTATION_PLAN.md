# Agent Inventory & Navigation — Implementation Plan

> **For the executor (orchestrator agent):** This plan implements [`docs/AGENT_INVENTORY_AND_NAVIGATION_PRD.md`](./AGENT_INVENTORY_AND_NAVIGATION_PRD.md). Product/ops law is **already locked** in PRD §0.5–§0.7. **Do not re-decide paths, tools, or deliverable names.** Your job is to **orchestrate subagents aggressively**, merge their outputs, ship Crane then IndexedEx, and pass §5 acceptance.

| Field | Value |
|-------|--------|
| **Status** | **READY TO EXECUTE** |
| **PRD** | [`docs/AGENT_INVENTORY_AND_NAVIGATION_PRD.md`](./AGENT_INVENTORY_AND_NAVIGATION_PRD.md) — normative |
| **Repo root** | IndexedEx workspace (`lib/indexedex`) |
| **Crane** | Git submodule `lib/crane` → remote `origin` (e.g. `cyotee/crane`) |
| **Branches** | Crane + IndexedEx: `docs/agent-inventory-navigation` |
| **Kind** | Docs / agent-ops / graphs / skills only — **no** Solidity product changes |
| **Subagent policy** | **Launch as many subagents as appropriate** to finish quickly. No artificial cap. Parallelize every read-only survey and every independent write that does not conflict on the same file. |

---

## 0. Intent & success

### 0.1 Intent

Make IndexedEx + Crane discoverable for cold-start agents:

1. `cartographer` on `PATH` via repo installer  
2. Fresh **committed** graphs for IndexedEx and Crane  
3. Full rewrite of primary maps + required indexes  
4. Crane-canonical inventory **pushed**; IndexedEx gitlink bumped  
5. All harness entrypoints updated (lean)  
6. Skills cataloged; missing/stale skills implemented unlimited-within-reason  

### 0.2 Success

PRD §5 acceptance checklist all checked. Especially:

- `command -v cartographer` works from `/tmp`
- Both `cartographer verify --root … --out … --fresh` pass
- Crane SHA on **remote**; IndexedEx gitlink matches
- Cold-start probes answerable from harness → map → navigation  

### 0.3 Hard forbids (fail the task if violated)

| Forbidden | Required instead |
|-----------|------------------|
| Inventing deliverable paths | PRD §0.7.4 only |
| Git LFS | Plain git |
| Solidity product / test behavior changes | Docs, skills, graphs, harnesses only |
| Leaving Crane inventory dirty-only | Push Crane, then pin |
| Auto-editing shell rc | Print PATH instructions |
| Product brands in DETF copy | Role names only |
| “Do not extend” package bans | Historical labels OK only |
| Re-opening PRD decisions | Follow §0.7 |

---

## 1. Orchestration model

### 1.1 Roles

| Role | Who | Duties |
|------|-----|--------|
| **Orchestrator** | Parent agent | Create branches; run WP-0/0b (or one setup subagent); **spawn many survey/write subagents in parallel**; merge notes into final docs; Crane commit/push; IndexedEx commits + PR; run WP-I verification |
| **Survey subagents** | N parallel, **read-only** | Tree + Cartographer notes for assigned slices; write only to **their** scratch note paths |
| **Author subagents** | N parallel where write sets disjoint | Draft map/inventory/skill sections into assigned files |
| **Skill subagents** | N parallel | One skill (or small skill family) each after backlog exists |
| **Verifier subagent** | 1 at end (or continuous) | §5 checklist + path/link checks |

### 1.2 Subagent policy (speed-first)

**This plan supersedes PRD §0.7.9’s ≤16 agent budget.**

1. **Default: parallelize.** If two tasks do not write the same file, run them as concurrent subagents.
2. **No fixed maximum.** Launch as many as the runtime allows when slices are independent.
3. **Scratch isolation:** every survey agent writes **only** under  
   `docs/agent/_inventory_scratch/<agent_id>.md`  
   (create dir; delete or leave scratch at end — orchestrator may keep until WP-I then delete).
4. **Final docs** are written by merge authors (or orchestrator) from scratch notes — avoid 10 agents editing `CODEBASE_MAP.md` at once.
5. **Crane vs IndexedEx:** Crane authors may work in `lib/crane/**` while IndexedEx authors work outside `lib/crane/**` **in parallel**, after graphs exist.
6. Prefer `explore` / read-only capability for surveys; `general-purpose` or write-capable for authors.
7. Each subagent prompt must include: **PRD path**, **this plan path**, **allowlist paths**, **forbids**, **done definition**.

### 1.3 Recommended fan-out shape (minimum; expand if slow)

```
Phase 0 (serial):     Setup (PATH + dual re-index)          → 1 agent
Phase 1 (parallel):   Surveys — see §3 slice table          → 8–20 agents
Phase 2 (parallel):   Draft authors (disjoint files)        → 6–12 agents
Phase 3 (serial gate): Orchestrator merge pass + consistency
Phase 4 (serial):     Crane commit + push
Phase 5 (parallel):   IndexedEx harness + catalog polish    → 2–4 agents
Phase 6 (parallel):   Skill implementers (one per gap)      → N = backlog size
Phase 7 (serial):     Verifier + PR packaging
```

If a phase is bottlenecked, **split slices further** and spawn more survey/author agents rather than waiting on one mega-agent.

### 1.4 Branches (exact)

```bash
# Crane (inside submodule)
cd lib/crane
git checkout -B docs/agent-inventory-navigation
# … work …
git push -u origin docs/agent-inventory-navigation
# ensure SHA is on remote (merge to default if required by remote policy)

# IndexedEx
cd ../..   # repo root
git checkout -B docs/agent-inventory-navigation
# after Crane remote SHA known:
git add lib/crane   # gitlink
# … maps, skills, harnesses, .cartographer, installer …
```

---

## 2. Phase 0 — Setup (serial)

**Owner:** orchestrator or single `setup` subagent.  
**Do not** start surveys until both graphs verify fresh.

### 2.1 WP-0 — Cartographer on PATH

Create `scripts/install-cartographer.sh` per PRD §0.7.2:

- Installs `$HOME/bin/cartographer`
- Wrapper: `exec bun run --cwd "$CARTOGRAPHER_MARKETPLACE" src/cli/index.ts "$@"`
- Discovery order: `CARTOGRAPHER_MARKETPLACE` → `~/.claude/plugins/marketplaces/cartographer-marketplace`
- Fail if `bun` or marketplace missing
- Print PATH hint; **do not** edit shell rc

```bash
chmod +x scripts/install-cartographer.sh
./scripts/install-cartographer.sh
export PATH="$HOME/bin:$PATH"
command -v cartographer
cartographer --help
# from non-repo cwd:
( cd /tmp && cartographer --help )
```

Ensure marketplace has deps once:

```bash
( cd "${CARTOGRAPHER_MARKETPLACE:-$HOME/.claude/plugins/marketplaces/cartographer-marketplace}" && bun install )
```

### 2.2 WP-0b — Re-index both repos

Remove gitignore rules that block `.cartographer/` / `graph.sqlite` if any (IndexedEx + Crane).

```bash
export PATH="$HOME/bin:$PATH"

# IndexedEx
cartographer index --root . --out .cartographer --force
cartographer verify --root . --out .cartographer --fresh
cartographer view --out .cartographer

# Crane
cartographer index --root lib/crane --out lib/crane/.cartographer --force
cartographer verify --root lib/crane --out lib/crane/.cartographer --fresh
cartographer view --out lib/crane/.cartographer
```

**Gate:** both `verify --fresh` exit 0. If not, fix ignores / re-run — do not proceed.

Optional: spawn **two** subagents after installer exists — one indexes IndexedEx, one indexes Crane — then orchestrator checks both verifications.

---

## 3. Phase 1 — Parallel surveys (read-only, many subagents)

**Create:** `docs/agent/_inventory_scratch/`

Each agent outputs a single markdown note with:

- Assigned slice id  
- Table rows: `path | purpose | owner (IndexedEx/Crane/external) | PRD if any | test root if any | skill if any | notes`  
- Empty/orphan/historical flags (**not** “do not extend”)  
- Cartographer commands used (`view` / `brief` / `preflight` as useful)  
- Open questions for orchestrator only if path missing on disk  

### 3.1 Survey slice table (spawn **one subagent per row**; split further if a row is huge)

| Slice ID | Allowlist (read) | Focus |
|----------|------------------|--------|
| `S-platform` | `contracts/manager`, `contracts/registries`, `contracts/oracles`, `contracts/fee`, `contracts/constants`, `contracts/interfaces` | Platform core |
| `S-vaults-basic` | `contracts/vaults/` excluding `detf/` if separable | Basic / multi-asset / SE vault packages |
| `S-detf-common` | `contracts/vaults/detf/common`, shared DETF docs `docs/detf/`, `DETF_*PRD` at detf root | Shared DETF law pointers |
| `S-detf-balancer` | `contracts/vaults/detf/**/balancer/**` | Balancer DETF families |
| `S-detf-univ4` | `contracts/vaults/detf/**/uniswap/**` | Uni V4 DETF families |
| `S-detf-other` | Remaining `contracts/vaults/detf/**` | Other families / cross-version |
| `S-hooks` | `contracts/hooks/**` | Hook packages + deploy notes |
| `S-protocols-ix` | `contracts/protocols/**` (IndexedEx product adapters) | Non-Crane protocol adapters |
| `S-routers` | `contracts/routers/**` | Routers / periphery |
| `S-tests` | `test/**` (and `contracts/**/test` if any) | TestBase hierarchy, hermetic vs fork |
| `S-scripts` | `scripts/**` | Deploy/orchestration catalog |
| `S-frontend` | `frontend/**` | Routes, env/registry, `frontend/ROADMAP.md` |
| `S-research-docs` | `research/**`, `docs/**` (not rewriting yet) | Campaign PRDs, doc layout |
| `S-libs` | `lib/**` except deep Crane body (pointer-level + bankr note) | Lib map; Bankr parent-only |
| `S-crane-core` | `lib/crane/contracts/{access,factories,proxies,proxy,introspection,tokens,utils,interfaces}` | Crane framework core |
| `S-crane-protocols` | `lib/crane/contracts/protocols/**`, `lib/crane/contracts/external/**` | Ports + external vendors |
| `S-crane-test` | `lib/crane/test/**`, `lib/crane/contracts/test/**` | CraneTest, profiles |
| `S-crane-skills` | `lib/crane/.claude/skills/**`, `lib/crane/AGENTS.md`, `lib/crane/CLAUDE.md` | Crane skills + agents |
| `S-skills-ix` | `.claude/skills/**`, `.grok/skills/**`, `.opencode/skills/**`, `scripts/sync-crane-skills.sh`, `scripts/sync-bankr-skills.sh` | Skill catalog inputs + gaps |
| `S-cartographer-meta` | `.cartographer/**`, `lib/crane/.cartographer/**` | Totals, root path, how to regen |

**Expand rule:** If any slice note would exceed ~400 lines of rows, orchestrator **splits** that slice (e.g. `S-detf-balancer-a/b`) and respawns — do not serialize.

### 3.2 Survey subagent prompt template

```text
You are a READ-ONLY survey subagent for IndexedEx agent inventory.

PRD (law): docs/AGENT_INVENTORY_AND_NAVIGATION_PRD.md §0.7 and §2
Plan: docs/AGENT_INVENTORY_AND_NAVIGATION_IMPLEMENTATION_PLAN.md

Slice ID: <ID>
Read allowlist: <paths>
Write allowlist: docs/agent/_inventory_scratch/<ID>.md  ONLY

Tasks:
1. List packages/modules under allowlist (deep as practical; skip trivial leaf noise).
2. For each: path, one-line purpose, owner, PRD path if co-located, test root if known, related skill if known.
3. Use cartographer brief/preflight/view when helpful (cartographer must be on PATH).
4. Flag historical/empty dirs; never say "do not extend".
5. DETF role names only (rateAsset, pairToken, …).
6. Do not edit any other files. Do not invent paths — verify with list_dir/read.

Done: scratch file written; every path exists; no product code changes.
```

---

## 4. Phase 2 — Parallel draft authors (disjoint writes)

After Phase 1 notes exist, spawn authors. **Write sets must not overlap.**

| Author ID | Writes (exclusive) | Inputs |
|-----------|-------------------|--------|
| `A-map-platform` | Scratch or section file `docs/agent/_inventory_scratch/draft_map_platform.md` | S-platform, S-routers |
| `A-map-vaults` | `…/draft_map_vaults.md` | S-vaults-basic, S-detf-* |
| `A-map-hooks-proto` | `…/draft_map_hooks_proto.md` | S-hooks, S-protocols-ix |
| `A-map-tests-fe` | `…/draft_map_tests_fe.md` | S-tests, S-scripts, S-frontend, S-research-docs, S-libs |
| `A-content-inventory` | `docs/agent/INDEXEDEX_CONTENT_INVENTORY.md` | All S-* (IndexedEx) |
| `A-nav-index` | `docs/agent/AGENT_NAVIGATION_INDEX.md` | All S-*; PRD Appendix A seed |
| `A-skill-catalog` | `docs/agent/SKILL_CATALOG.md` | S-skills-ix, S-crane-skills |
| `A-skill-backlog` | `docs/agent/SKILL_GAP_BACKLOG.md` | S-skills-ix + missing routing |
| `A-crane-map` | `lib/crane/docs/CODEBASE_MAP.md` | S-crane-* |
| `A-crane-cap` | `lib/crane/docs/agent/CRANE_CAPABILITY_INVENTORY.md` | S-crane-* |
| `A-crane-nav` | `lib/crane/docs/agent/AGENT_NAVIGATION_INDEX.md` (preferred) | S-crane-skills |
| `A-installer-docs` | Ensure installer exists; short usage blurb for harnesses (scratch OK) | WP-0 |

**Then orchestrator (or one `A-map-merge` agent)** builds:

- `docs/CODEBASE_MAP.md` from draft_map_*  
- Apply **>2000 line split** per PRD §0.7.4 if needed (fixed part paths only)  
- Metadata blocks on every final file (`last_reviewed`, `git_sha`, `scope`, `method: cartographer+survey`)

### 4.1 Author prompt template

```text
You are a documentation author subagent for IndexedEx/Crane inventory.

PRD: docs/AGENT_INVENTORY_AND_NAVIGATION_PRD.md (§0.7.4 filenames, §6 quality bar)
Plan: docs/AGENT_INVENTORY_AND_NAVIGATION_IMPLEMENTATION_PLAN.md

Write allowlist: <exact files>
Read: docs/agent/_inventory_scratch/*.md for your inputs; cartographer view OK.

Rules:
- Deep as practical; paths over prose; progressive disclosure.
- Link family PRDs / agent law — do not restate DETF product law.
- DETF role names only.
- No Solidity changes.
- Include YAML metadata header per PRD §0.7.8 (git_sha can be placeholder PENDING_SHA if unknown).

Done: allowlist files complete; no writes outside allowlist.
```

---

## 5. Phase 3 — Orchestrator merge & consistency (serial)

1. Read all drafts; ensure every §0.7.4 IndexedEx + Crane required file exists.  
2. Cross-link: navigation → map sections; content inventory → PRDs; skill catalog → SoT paths.  
3. Crane `AGENTS.md` / `CLAUDE.md`: lean discovery pointers only.  
4. Replace `PENDING_SHA` metadata after commits.  
5. Confirm no “do not extend” policy language.  
6. Delete or retain scratch dir (prefer delete before final PR if noisy).  

---

## 6. Phase 4 — Crane push (serial gate)

```bash
cd lib/crane
git checkout -B docs/agent-inventory-navigation
git status
# add: docs/CODEBASE_MAP.md, docs/agent/**, .cartographer/**, AGENTS.md, CLAUDE.md, .gitignore fixes
git add -A
git commit -m "docs: agent capability inventory, codebase map, cartographer graph"
git push -u origin docs/agent-inventory-navigation
git rev-parse HEAD   # record CRANE_SHA — must be on remote
```

If remote requires PR merge to default branch before consumers pin: open/merge Crane PR, then set `CRANE_SHA` to the merged commit on default branch.

**Gate:** `git ls-remote origin <CRANE_SHA>` (or default branch contains it).

---

## 7. Phase 5 — IndexedEx harnesses + gitlink (parallel where safe)

| Agent | Writes |
|-------|--------|
| `H-claude` | `Claude.md` then copy **byte-identical** to `CLAUDE.md` |
| `H-law` | `docs/agent/INDEXEDEX_AGENT_LAW.md` Discovery subsection |
| `H-gitlink` | Orchestrator only: `git add lib/crane` at `CRANE_SHA` |
| `H-ix-graph` | Ensure IndexedEx `.cartographer/` staged |

Discovery links **must** include (PRD §0.7.5):

1. `docs/CODEBASE_MAP.md`  
2. `docs/agent/AGENT_NAVIGATION_INDEX.md`  
3. `docs/agent/INDEXEDEX_CONTENT_INVENTORY.md`  
4. `docs/agent/SKILL_CATALOG.md`  
5. `lib/crane/docs/agent/CRANE_CAPABILITY_INVENTORY.md`  
6. `scripts/install-cartographer.sh`  

Keep always-on files **lean**.

---

## 8. Phase 6 — Skills (maximum parallel)

1. Finalize `docs/agent/SKILL_GAP_BACKLOG.md` with P0/P1/P2 per PRD §0.7.7.  
2. **Spawn one subagent per P0/P1 item** (and P2 while cold-start skill probes fail).  
3. SoT rules:  
   - Crane skills → `lib/crane/.claude/skills/<name>/` then from IndexedEx: `./scripts/sync-crane-skills.sh`  
   - IndexedEx-only → `.claude/skills/<name>/` then mirror to `.grok/skills/` and `.opencode/skills/`  
4. If a gap needs Crane skill changes **after** Crane was already pushed: either  
   - (preferred) second Crane commit + push + gitlink bump, or  
   - implement IndexedEx-local skill that points at Crane patterns without forking framework law  

### 8.1 Skill subagent prompt template

```text
You implement ONE skill gap for IndexedEx agent inventory.

PRD §0.7.7, skill-authoring progressive disclosure.
Backlog item: <ID> <title>
Priority: P0|P1|P2
SoT path: <exact directory>
Mirror: <commands or none>

Write only your skill tree (+ mirrors if IndexedEx-local).
Do not change product Solidity.
Update docs/agent/SKILL_CATALOG.md row for this skill only if you can do so without clobbering others;
otherwise report the row for orchestrator merge.

Done: SKILL.md exists; description triggers accurate; references as needed; sync/mirror done.
```

**Stop when:** §5 skill-related cold-start probes pass and no open P0/P1 (PRD §0.7.7).

---

## 9. Phase 7 — Verification (WP-I) + PR

### 9.1 Verifier subagent checklist

Run and record results in `docs/agent/_inventory_scratch/VERIFY.md` (or final summary):

```bash
export PATH="$HOME/bin:$PATH"
command -v cartographer
( cd /tmp && cartographer --help )

cartographer verify --root . --out .cartographer --fresh
cartographer verify --root lib/crane --out lib/crane/.cartographer --fresh

test -f docs/CODEBASE_MAP.md
test -f docs/agent/AGENT_NAVIGATION_INDEX.md
test -f docs/agent/INDEXEDEX_CONTENT_INVENTORY.md
test -f docs/agent/SKILL_CATALOG.md
test -f docs/agent/SKILL_GAP_BACKLOG.md
test -f scripts/install-cartographer.sh
test -f lib/crane/docs/CODEBASE_MAP.md
test -f lib/crane/docs/agent/CRANE_CAPABILITY_INVENTORY.md
diff -q Claude.md CLAUDE.md

# gitlink on remote
git -C lib/crane rev-parse HEAD
git ls-remote "$(git -C lib/crane remote get-url origin)" | head
```

Cold-start probes (answer from docs only; no repo grep required for the *reader*, verifier may check links resolve):

1. Vault registry deploy path?  
2. Crane skill for CREATE3 DFPkg?  
3. Morpho/Olympus port status location in Crane?  
4. Single SE DETF family PRD location?  
5. Bankr skills in this repo’s skill tree? (must be **no** / parent only)  
6. How to run cartographer from any directory?  

### 9.2 IndexedEx commit & PR

```bash
git checkout -B docs/agent-inventory-navigation
git add scripts/install-cartographer.sh .cartographer docs/ Claude.md CLAUDE.md \
  docs/agent lib/crane .claude/skills .grok/skills .opencode/skills
# include gitignore fixes, skill mirrors, etc.
git commit -m "docs: agent inventory, navigation, cartographer graphs, skill catalog"
# push and open ONE PR to main
```

Prefer **one** IndexedEx PR; multiple commits on the branch are fine.

---

## 10. File checklist (exact)

### 10.1 Create / overwrite

| Path |
|------|
| `scripts/install-cartographer.sh` |
| `.cartographer/**` (fresh) |
| `docs/CODEBASE_MAP.md` |
| `docs/agent/AGENT_NAVIGATION_INDEX.md` |
| `docs/agent/INDEXEDEX_CONTENT_INVENTORY.md` |
| `docs/agent/SKILL_CATALOG.md` |
| `docs/agent/SKILL_GAP_BACKLOG.md` |
| `docs/agent/maps/0N-*.md` | only if split rule triggers |
| `lib/crane/docs/CODEBASE_MAP.md` |
| `lib/crane/docs/agent/CRANE_CAPABILITY_INVENTORY.md` |
| `lib/crane/docs/agent/AGENT_NAVIGATION_INDEX.md` | preferred |
| `lib/crane/.cartographer/**` (fresh) |
| New/updated skills under correct SoT + mirrors |

### 10.2 Patch

| Path |
|------|
| `Claude.md` + identical `CLAUDE.md` |
| `docs/agent/INDEXEDEX_AGENT_LAW.md` |
| `lib/crane/AGENTS.md`, `lib/crane/CLAUDE.md` |
| `.gitignore` / `lib/crane/.gitignore` if they ignore graphs |
| IndexedEx `lib/crane` gitlink |

### 10.3 Do not create

| Path | Why |
|------|-----|
| Root `AGENTS.md` | Only if already present (it is not required) |
| Git LFS config for graphs | Forbidden |
| Vendored Cartographer sources | Wrapper only |

---

## 11. Merge conflicts & write-set rules

| Conflict risk | Rule |
|---------------|------|
| Many agents → one map file | Use draft scratches + single merge agent |
| Skill catalog rows | One agent owns final `SKILL_CATALOG.md` merge after skill workers |
| Crane push vs IndexedEx | Never gitlink unpushed SHA |
| Parallel skill mirrors | Each skill agent mirrors **only its** skill directory |
| `sync-crane-skills.sh` | Run once after batch of Crane skill updates, or per skill if safe |

---

## 12. Orchestrator execution algorithm (copy this)

```
1. Read PRD §0.5–0.7 fully. Do not improvise paths.
2. Branch IndexedEx docs/agent-inventory-navigation (local).
3. WP-0 install cartographer; prove PATH from /tmp.
4. WP-0b re-index both; prove verify --fresh both.
5. mkdir docs/agent/_inventory_scratch
6. SPAWN all survey slices S-* in parallel (add more if needed).
7. WAIT all surveys.
8. SPAWN all draft authors A-* with disjoint writes in parallel.
9. WAIT authors; RUN map merge; apply 2000-line split if needed.
10. Crane branch docs/agent-inventory-navigation; commit; PUSH; record CRANE_SHA.
11. SPAWN harness patchers; set gitlink to CRANE_SHA.
12. Rank SKILL_GAP_BACKLOG; SPAWN one skill agent per open P0/P1 (+ P2 as needed).
13. If Crane skills changed again → push Crane again → bump gitlink.
14. SPAWN verifier; fix any failures with targeted agents (not full restart).
15. Commit IndexedEx; push branch; open one PR.
16. Report PR URLs + CRANE_SHA + checklist.
```

**Speed dial:** whenever waiting on one large survey/author, **split the allowlist and spawn replacements** rather than extending a single agent’s scope.

---

## 13. Relationship to PRD

| Topic | Authority |
|-------|-----------|
| Product/ops decisions, filenames, commands | **PRD** |
| Subagent count | **This plan** — unlimited as appropriate (supersedes PRD §0.7.9 cap) |
| Delivery order Crane→IndexedEx | PRD §0.7.6 + this plan Phase 4–5 |
| Acceptance | PRD §5 + this plan §9 |

---

## 14. Document control

| Field | Value |
|-------|--------|
| **Location** | `docs/AGENT_INVENTORY_AND_NAVIGATION_IMPLEMENTATION_PLAN.md` |
| **PRD** | `docs/AGENT_INVENTORY_AND_NAVIGATION_PRD.md` |
| **Authoring date** | 2026-08-09 |
| **Executor start command** | “Execute `docs/AGENT_INVENTORY_AND_NAVIGATION_IMPLEMENTATION_PLAN.md` using parallel subagents.” |
