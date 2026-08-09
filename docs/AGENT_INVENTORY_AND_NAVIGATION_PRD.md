# Product Requirements Document (PRD)

## Title

**Agent Inventory & Navigation Refresh** — make IndexedEx (+ Crane) structure discoverable so new agents can find the right code, skills, and law without re-exploring from scratch

## Status

| Field | Value |
|-------|--------|
| **Status** | **LOCKED** — product decisions §0.5–§0.7; execution via implementation plan |
| **Execute plan** | [`docs/AGENT_INVENTORY_AND_NAVIGATION_IMPLEMENTATION_PLAN.md`](./AGENT_INVENTORY_AND_NAVIGATION_IMPLEMENTATION_PLAN.md) — parallel subagents, Crane push then IndexedEx PR |
| **Kind** | Documentation / agent-ops PRD (Cartographer re-index + deep maps + inventories + skill implementation + multi-harness routers + Crane submodule commits); **not** on-chain product features |
| **Follow-on** | **Execute** the implementation plan (not re-decide this PRD) |
| **Primary consumers** | Grok / Claude / OpenCode agents; human maintainers who refresh maps after large merges |
| **Primary surfaces** | All harness entrypoints (`Claude.md` / `CLAUDE.md`, root `AGENTS.md` if present, Grok/OpenCode entry docs), `docs/agent/INDEXEDEX_AGENT_LAW.md`, **primary** `docs/CODEBASE_MAP.md`, Crane submodule maps + capability inventory (canonical in Crane), skill trees + missing/stale skills (unlimited-within-reason), Cartographer graphs under IndexedEx + Crane |
| **Hard constraints** | Progressive disclosure on **always-on routers** only (still lean); deep maps/inventories expected; production law non-negotiables stay in agent law / family PRDs; Crane skills SoT under `lib/crane/.claude/skills/`; no product-brand names in DETF agent copy |
| **Out of band** | No Solidity behavior changes for product features; skill/doc/map/graph work only unless a skill needs a tiny test fixture (prefer docs/skills only) |

---

## 0. Intent

### 0.1 Problem

New agents land in a large monorepo (IndexedEx + nested Crane submodule + many protocol skill families) and cannot answer, quickly:

1. **What exists** under `contracts/`, `test/`, `frontend/`, `scripts/`, `docs/`, `research/`, `lib/`?
2. **What Crane already provides** (factories, TestBases, protocol ports, utilities) vs what IndexedEx owns?
3. **Which skill / agent / PRD** to open for a given task?
4. **What is stale** among existing maps and skill catalogs?

Today’s artifacts partially answer this but are incomplete or dated for agent use:

| Artifact | Current role | Gap for agents |
|----------|--------------|----------------|
| `Claude.md` | Lean always-on **router** | Skill/task table is high-level; no content inventory |
| `docs/agent/INDEXEDEX_AGENT_LAW.md` | Full product + engineering law | Directory notes exist but are not a maintained inventory of packages/families |
| `docs/CODEBASE_MAP.md` | Cartographer-oriented map (`last_mapped` ~2026-06-21) | Likely stale vs current trees; not optimized as **agent findability** (skills, deploy paths, TestBases, DETF families) |
| `lib/crane/AGENTS.md` + Crane map/docs | Crane navigation | IndexedEx agents are not reliably pointed at a **Crane capability inventory** (what services/ports/TestBases exist) |
| `.claude/skills/`, `.grok/skills/`, Crane skills | Task procedures | No authoritative **skill catalog index** (what each skill covers, when not to use it, mirror rules) |
| Protocol skill families (Aave, Aerodrome, Balancer, Morpho, Olympus, …) | Domain knowledge | Hard to know which are Crane-synced, IndexedEx-local, or parent-workspace (Bankr) |

Without a deliberate inventory refresh, agents re-grep the tree every session, mis-route to wrong packages, reinvent Crane utilities, or update the wrong skill mirror.

### 0.2 Goals

1. **Install Cartographer so `cartographer` is on `PATH`** and usable from any working directory (not only via Bun + marketplace path).
2. **Re-index with Cartographer** both the IndexedEx monorepo and the Crane submodule (fresh `.cartographer/` graphs; `verify --fresh` green or documented residual).
3. Produce **deep, practical inventories and maps** of what exists in IndexedEx and Crane (package **and** major agent-relevant modules — not only top-level folders; still avoid useless every-file dumps of trivial leaves).
4. Make **`docs/CODEBASE_MAP.md` the primary human/agent architecture map** (full rewrite from current trees + Cartographer output), with thinner indexes pointing into it where useful.
5. Produce a **canonical Crane capability inventory inside the Crane submodule**, commit/push to Crane remote, and **bump the IndexedEx `lib/crane` gitlink**.
6. Produce an **agent navigation index**: task → skill / agent identity / PRD / law section / map section / code root.
7. **Update all harness entrypoints** so every agent surface points at the same discovery stack (still lean always-on text).
8. **Catalog skills and implement missing/stale skills unlimited-within-reason** (prioritize by agent failure impact; no hard cap of 5, but no unbounded full-site skill crawls without cause).
9. Define **freshness rules** and shape work for setup → Cartographer re-index → **parallel survey subagents** → merge → skill implementation → Crane push / gitlink → verify.

### 0.3 Non-goals

- Completing the inventory inside this PRD (requirements only).
- **Executing** Cartographer re-index, PATH install, surveys, or skill authoring as part of authoring this PRD.
- Rewriting family product PRDs or DETF product law (except fixing **broken links** / **wrong paths** discovered during inventory).
- Bulk re-authoring **every** protocol skill from full upstream docs sites without a ranked gap needing it (`docs-skill-scribe` remains the tool when a gap warrants a full site campaign).
- Installing Bankr / parent-workspace skills into IndexedEx skill trees.
- Changing on-chain product behavior, CI profiles, or deploy orchestration as a goal of this program.
- Godot / game-engine / accelerator skills (explicitly out of monorepo skill scope).
- Barring packages from extension — **no package is extension-forbidden** by this program (legacy may still be labeled for honesty, but not “do not extend” as policy).

### 0.4 Success definition

After the implementation plan is executed (not this PRD alone):

| Criterion | Pass bar |
|-----------|----------|
| **Cartographer on PATH** | Installer script in repo; after running it, `command -v cartographer` succeeds; `--help` works from any cwd |
| **Fresh graphs committed** | IndexedEx and Crane each have re-indexed **and committed** `.cartographer/` artifacts; `cartographer verify --fresh` passes (or residuals explicitly justified); Crane graph is on the **pushed** Crane commit |
| **Findability** | A cold-start agent, given only a harness entrypoint, can open the primary map + navigation index and answer “where is X?” for every inventory category in §2 |
| **Primary map** | `docs/CODEBASE_MAP.md` is rewritten against current trees (+ Cartographer) and is the authoritative structure narrative |
| **Crane awareness** | Canonical Crane capability inventory lives **in Crane**; pushed to Crane remote; IndexedEx `lib/crane` gitlink bumped to that commit |
| **Skill routing + gaps** | Catalog complete; missing/stale skills implemented **unlimited-within-reason** (ranked; residual debt only if blocked, with owner note) |
| **Harness parity** | Claude / Grok / OpenCode (and root `AGENTS.md` if present) entrypoints agree on discovery links |
| **Staleness** | Maps/inventories carry `last_reviewed` (date + optional git SHA); always-on routers stay lean |
| **No law regression** | Non-negotiables (CREATE3, registry deploy, production-first tests, DETF role names, no `via_ir`) unchanged and still linked |
| **Plan-ready** | Work packages in §4 support PATH/setup, re-index, subagent survey, skill track, Crane push + gitlink |

### 0.5 Locked product decisions (2026-08-09)

| Decision | Choice | Implication |
|----------|--------|-------------|
| **Inventory depth** | **Deep as practical** | Catalog packages **and** major modules (e.g. DETF mint/burn surfaces, claim/bond areas, hook package roles). Prefer structured depth over one-line folders-only. Still skip trivial leaf noise. |
| **Crane inventory home** | **Canonical in Crane submodule** | Author/update under `lib/crane/`. |
| **Crane contribution path** | **Commit + push to Crane, bump IndexedEx gitlink** | Crane remote receives inventory/map commits; IndexedEx records new submodule SHA. Dirty-only Crane worktrees are **not** done. |
| **CODEBASE_MAP role** | **Full rewrite as primary map** | `docs/CODEBASE_MAP.md` is the main structure doc. Other inventories/indexes **point into** it rather than fork a second full tree story. |
| **Skill work** | **Catalog + implement missing/stale skills** | Rank by agent impact; **implement unlimited-within-reason** (no fixed top-5 cap). Prefer focused skills over full-site crawls unless the gap requires it. |
| **Skill budget** | **Unlimited-within-reason** | Complete the ranked gap list that materially improves agent routing; stop only for true blockers (missing product law, out-of-scope Godot/Bankr, etc.), not an arbitrary count. |
| **Harness patches** | **All harness entrypoints** | Keep discovery links in sync across Claude, Grok, OpenCode, and root `AGENTS.md` when present (`Claude.md` / `CLAUDE.md` naming included). |
| **Cartographer** | **Required** | Re-index **IndexedEx** and **Crane**; use graph output to inform (not replace) human-readable maps. |
| **Cartographer install** | **Repo script + `~/bin` wrapper → `PATH`** | Exact paths and behavior locked in **§0.7**. |
| **Cartographer artifacts in git** | **Commit graphs in IndexedEx and Crane** | Commit full `.cartographer/` trees (including `graph.sqlite`) in **both** repos. **No Git LFS** for this program (see §0.7). |
| **Skill completion gate** | **Implementer-driven until §5 cold-start passes** | Rank gaps, implement unlimited-within-reason; **no** mandatory human checkpoint before WP-H. Verification agent/human runs acceptance probes. |
| **PR / delivery shape** | **Crane push first, then IndexedEx PR** | Exact branch names and order locked in **§0.7**. |
| **Extension policy** | **No packages barred** | Do not mark packages “do not extend” as program policy. Legacy/historical paths may be labeled for accuracy; extension remains allowed. |

### 0.7 Executor-locked operations (minimize implementer judgment)

These are **normative**. The implementation plan restates them; it does **not** re-open them. Executors follow this section when anything is ambiguous.

#### 0.7.1 Why the last three “ops” questions mattered (elaborated)

| Topic | What was at stake | Locked answer | Rationale |
|-------|-------------------|---------------|-----------|
| **A. Cartographer wrapper source** | Whether `cartographer` on PATH is a **global npm package**, a **vendored copy of the CLI in-repo**, or a **thin wrapper** that calls the already-installed Claude marketplace package via Bun. Affects install size, update story, and whether agents depend on `~/.claude/plugins/...`. | **Thin wrapper → marketplace CLI via Bun** | Smoke test already proved that path works. Avoid vendoring a second copy of Cartographer into IndexedEx. Avoid requiring a separate global npm publish. Bun is already available on the authoring machine. |
| **B. Map file splitting** | A “deep as practical” rewrite can produce a multi-thousand-line `CODEBASE_MAP.md`. Executors might invent ad-hoc split schemes, bury the primary entrypoint, or keep an unreadable monolith. | **Single primary file until >2000 lines; then split under fixed paths** | Keeps `docs/CODEBASE_MAP.md` as the stable entrypoint; splits are mechanical, not creative. |
| **C. Git LFS for `graph.sqlite`** | Current graph is ~7.5MB. LFS adds clone/setup complexity for every contributor and CI. Plain git is simpler until size is truly painful. | **Plain git only; no LFS in this program** | User required graphs **committed**. 7.5MB is acceptable. Revisit LFS only in a **future** program if a single artifact exceeds **50MB**. Executor must **not** introduce LFS. |

#### 0.7.2 Cartographer PATH install (exact)

| Item | Locked value |
|------|----------------|
| Installer path (IndexedEx) | `scripts/install-cartographer.sh` |
| Wrapper install location | `$HOME/bin/cartographer` (create `$HOME/bin` if missing) |
| PATH expectation | Installer **prints** instructions to add `export PATH="$HOME/bin:$PATH"` if needed. **Do not** auto-edit shell rc files. |
| CLI implementation | Wrapper (bash) must `exec bun run --cwd "$CARTOGRAPHER_MARKETPLACE" src/cli/index.ts "$@"` |
| Marketplace root discovery | In order: (1) env `CARTOGRAPHER_MARKETPLACE` if set; (2) `$HOME/.claude/plugins/marketplaces/cartographer-marketplace` if it exists; (3) fail with install instructions (do not silently download unrelated forks) |
| Prerequisites check | Script fails fast if `bun` missing or marketplace dir missing |
| Also install on Crane? | **No separate Crane installer.** One IndexedEx script is enough; Crane docs **link** to `../../scripts/install-cartographer.sh` from IndexedEx consumer context, and Crane `AGENTS.md` says “install via consuming repo or marketplace path.” |
| Acceptance | After install: `command -v cartographer`, `cartographer --help` from `/tmp` or any non-repo cwd |

#### 0.7.3 Cartographer re-index commands (exact)

Run from a shell where `cartographer` is on `PATH` (after WP-0).

**IndexedEx** (repo root = IndexedEx root):

```bash
cartographer index --root . --out .cartographer --force
cartographer verify --root . --out .cartographer --fresh
cartographer view --out .cartographer
```

**Crane** (from IndexedEx root, or `cd lib/crane`):

```bash
cartographer index --root lib/crane --out lib/crane/.cartographer --force
cartographer verify --root lib/crane --out lib/crane/.cartographer --fresh
cartographer view --out lib/crane/.cartographer
```

| Item | Locked value |
|------|----------------|
| Flags | Always `--force` on the inventory-program re-index (no “maybe incremental”) |
| `verify --fresh` | **Must pass**. If it fails, fix ignore patterns / re-run index — do **not** ship “incompatible” graphs. Only allowed residual: document in map metadata if CLI reports non-error warnings. |
| Commit set | Entire `.cartographer/` directory including `graph.sqlite`, `manifest.json`, `schema/`, generated map stubs Cartographer writes under `.cartographer/`, and empty dirs it expects (`briefs/`, `audits/`, `reports/`, `exports/`) if the CLI creates them |
| Git LFS | **Forbidden** for this program |
| `.gitignore` | **Remove** any ignore rules that would exclude `.cartographer/` or `graph.sqlite` in IndexedEx or Crane if present; ensure graphs are trackable |

#### 0.7.4 Map / inventory filenames (exact — no “plan chooses”)

**IndexedEx (all required):**

| Path | Role |
|------|------|
| `docs/CODEBASE_MAP.md` | **Primary** deep map (full rewrite) |
| `docs/agent/AGENT_NAVIGATION_INDEX.md` | Task → skill / law / map section / path |
| `docs/agent/INDEXEDEX_CONTENT_INVENTORY.md` | **Required** thin package index (path, purpose, PRD, test root, owner) — even if map is deep |
| `docs/agent/SKILL_CATALOG.md` | **Required** separate skill catalog (not only a section inside navigation) |
| `docs/agent/SKILL_GAP_BACKLOG.md` | Ranked gaps + blocked-only deferrals after WP-H |

**If `docs/CODEBASE_MAP.md` exceeds 2000 lines** after rewrite:

| Path | Role |
|------|------|
| `docs/CODEBASE_MAP.md` | Stays the **entrypoint**: overview, mermaid/system diagram, TOC linking to parts, metadata |
| `docs/agent/maps/01-platform.md` | manager, registries, oracles, fee, constants, interfaces |
| `docs/agent/maps/02-vaults-detf.md` | vaults + DETF families |
| `docs/agent/maps/03-hooks-protocols.md` | hooks + IndexedEx protocols adapters |
| `docs/agent/maps/04-tests-scripts-frontend.md` | tests, scripts, frontend, research, docs layout |
| `docs/agent/maps/05-libs-crane-pointer.md` | `lib/*` summary + pointer to Crane canonical docs |

Do **not** invent alternate split layouts. If a part is still huge, add `02b-…` only under the same directory, numbered.

**Crane (all required, inside submodule):**

| Path | Role |
|------|------|
| `lib/crane/docs/CODEBASE_MAP.md` | **Primary** Crane deep map (full refresh) |
| `lib/crane/docs/agent/CRANE_CAPABILITY_INVENTORY.md` | **Required** capability inventory (framework, ports, TestBases, skills, profiles) |
| `lib/crane/docs/agent/AGENT_NAVIGATION_INDEX.md` | Optional but **preferred** short Crane-local task router; if omitted, Crane `AGENTS.md` tables must cover the same |

Create `lib/crane/docs/agent/` if missing. **Do not** merge inventory solely into the map — keep **both** map + capability inventory (mirrors IndexedEx).

**IndexedEx links to Crane** (exact link targets):

- `lib/crane/docs/CODEBASE_MAP.md`
- `lib/crane/docs/agent/CRANE_CAPABILITY_INVENTORY.md`
- `lib/crane/AGENTS.md`

#### 0.7.5 Harness entrypoints (exact files)

| File | Action |
|------|--------|
| `Claude.md` | **SoT** for IndexedEx always-on router content |
| `CLAUDE.md` | **Must be byte-identical** to `Claude.md` after edits (copy SoT → both paths) |
| `docs/agent/INDEXEDEX_AGENT_LAW.md` | Add **Discovery** subsection with links to map, navigation, skill catalog, Crane inventory, Cartographer install |
| Root `AGENTS.md` | Create **only if** it already exists; if missing, **do not** create a third router — `Claude.md` is enough |
| `.grok/` entry | If a root agent instruction file exists under `.grok/` for session bootstrap, update discovery links; otherwise ensure `.grok/skills/` mirrors stay in sync via existing skill mirror rules only |
| `.opencode/` entry | Same rule as Grok: update only if an always-on instruction file exists; always mirror IndexedEx-local skills when authoring |

Discovery block to add (substance, not exact prose) must include links to:

1. `docs/CODEBASE_MAP.md`  
2. `docs/agent/AGENT_NAVIGATION_INDEX.md`  
3. `docs/agent/INDEXEDEX_CONTENT_INVENTORY.md`  
4. `docs/agent/SKILL_CATALOG.md`  
5. `lib/crane/docs/agent/CRANE_CAPABILITY_INVENTORY.md`  
6. `scripts/install-cartographer.sh`  

Always-on files stay **lean** (links + non-negotiables only).

#### 0.7.6 Branch / push / PR shape (exact)

| Step | Locked action |
|------|----------------|
| 1 | Crane branch name: `docs/agent-inventory-navigation` |
| 2 | On Crane: commit map + capability inventory + `.cartographer/` + `AGENTS.md`/`CLAUDE.md` pointer edits |
| 3 | **Push** Crane branch to submodule remote (`origin` of `lib/crane`); open Crane PR **or** merge to Crane default branch per remote norms — **SHA that IndexedEx pins must be on the remote** |
| 4 | IndexedEx branch name: `docs/agent-inventory-navigation` |
| 5 | IndexedEx commit(s): gitlink bump + maps/indexes/skills/harnesses/installer + IndexedEx `.cartographer/` |
| 6 | Open **one** IndexedEx PR from that branch (skills may be multiple commits on the same branch; not a separate required PR unless size forces a follow-up — prefer **one PR**) |

Never leave IndexedEx `main` (or the integration branch) pointing at a Crane SHA that exists only locally.

#### 0.7.7 Skill ranking & stop rules (exact)

| Item | Locked value |
|------|----------------|
| Ranking file | `docs/agent/SKILL_GAP_BACKLOG.md` |
| Priority order | (1) Broken/missing deploy or test routing for IndexedEx SUT, (2) Crane capability discovery gaps, (3) DETF/SE/hook package routing, (4) protocol family architecture/ops gaps that agents hit weekly, (5) nice-to-have |
| Implement | All P0 and P1 gaps; continue through P2 while cold-start skill probes fail |
| Stop | When §5 skill-related cold-start probes pass **and** no P0/P1 remain, **or** remaining items are **Blocked** with written reason |
| Blocked reasons allowed | Missing product law PRD; dependency outside monorepo; Bankr/Godot/out-of-scope; requires multi-day upstream docs crawl **and** is P2+ (schedule in backlog, do not block ship) |
| SoT for new skills | Crane framework skills → `lib/crane/.claude/skills/` then `./scripts/sync-crane-skills.sh`; IndexedEx-only → `.claude/skills/<name>/` then mirror to `.grok/skills/` and `.opencode/skills/` |
| Skill authoring style | Progressive disclosure (`skill-authoring` / Crane skill norms); lean `SKILL.md` + `references/` as needed |

#### 0.7.8 Metadata (exact)

Front-matter or top-of-file block on every map/inventory/catalog:

```yaml
last_reviewed: YYYY-MM-DD
git_sha: <short SHA of repo containing the file>
scope: indexedex | crane | skills | navigation
method: cartographer+survey
```

`git_sha` is **required** (not optional) at delivery time.

#### 0.7.9 Subagent fan-out

**Superseded for count by the implementation plan:** launch **as many subagents as appropriate** for speed. No artificial maximum.

| Phase | Guidance |
|-------|----------|
| WP-0 + WP-0b | Serial setup (or 2 parallel indexers after PATH works) |
| Surveys | **One agent per slice** (plan §3); split further if slices are large |
| Authors | Parallel on **disjoint write sets**; single merge for shared finals |
| Skills | **One agent per backlog item** when possible |
| Verify | 1 verifier at end |

Write-set isolation and scratch-dir rules live in the implementation plan.

#### 0.7.10 Explicit non-decisions (executor must not invent)

| Do not | Instead |
|--------|---------|
| Rename deliverable files | Use §0.7.4 paths only |
| Skip `INDEXEDEX_CONTENT_INVENTORY.md` or `SKILL_CATALOG.md` | Both required |
| Merge Crane inventory into map only | Both Crane files required |
| Use Git LFS | Plain git |
| Install cartographer only via docs, no script | Script is required |
| Put wrapper in `/usr/local/bin` by default | `$HOME/bin` only (no sudo) |
| Vendor Cartographer sources into IndexedEx | Wrapper → marketplace |
| Mark packages do-not-extend | Forbidden as policy |
| Change Solidity product code | Docs/skills/graphs only |
| Pin unpushed Crane | Push first |

### 0.6 Cartographer smoke-test baseline (context only; not execution)

As of the PRD clarification session (smoke test only):

| Observation | Detail |
|-------------|--------|
| CLI not on `PATH` | `cartographer` missing globally |
| Runnable via marketplace | `~/.claude/plugins/marketplaces/cartographer-marketplace` + Bun |
| IndexedEx `.cartographer/` | Exists but **stale** (generated ~2026-06-21; old root path; large `verify --fresh` drift) |
| Compatibility | Missing `briefs/`, `audits/`, `reports/`, `exports/` under current CLI expectations |

Implementation **must** fix PATH + re-index; this PRD does **not** perform that work.

---

## 1. Sources of truth & supersession

| Document | Role after this program |
|----------|-------------------------|
| **This PRD** | Normative requirements for inventory + agent navigation refresh |
| **Implementation plan** (TBD, next artifact) | Execution order, subagent prompts, acceptance checks |
| `Claude.md` | Always-on **router only** — links to inventories; no large trees |
| `docs/agent/INDEXEDEX_AGENT_LAW.md` | Product/engineering **law**; may gain a short “open inventory here” pointer; must not become a second full map |
| `docs/CODEBASE_MAP.md` | **Primary** architecture + deep directory/capability map (full rewrite) |
| New inventory / navigation docs (§3) | Findability indexes into the primary map + task routing |
| `lib/crane/AGENTS.md` + Crane skills + Crane map/inventory | Crane-local SoT inside submodule; **committed and pushed**; IndexedEx gitlink points at it |
| Family `*_PRD.md` / `docs/detf/*` | Product law for packages — inventory only **points**, does not restate |
| Cartographer graphs | **Required** machine indexes at IndexedEx `.cartographer/` and Crane `.cartographer/` (or Crane-equivalent out path); must not **contradict** human maps—reconcile conflicts in favor of live tree + product law |

**Supersession rule:** For “where does this package live / which skill to load,” **new inventory + navigation index win** over stale prose in old map sections. For DETF mint/burn/bond/claim/compound behavior, **family PRD + agent law win**. For Crane framework patterns, **Crane skills + `lib/crane/AGENTS.md` win**.

---

## 2. Inventory scope (what must be cataloged)

Inventories are **capability-oriented**. Prefer one line per package/module with: path, one-sentence purpose, owner (IndexedEx vs Crane), primary interfaces/entrypoints if obvious, related skill/PRD, test root if known.

### 2.1 IndexedEx monorepo (required)

| Area | Minimum inventory content |
|------|---------------------------|
| **Platform core** | `contracts/manager`, `registries`, `oracles`, `fee`, `constants`, shared `interfaces` |
| **Vaults** | Basic / multi-asset / ERC-4626-style packages; Standard Exchange lineages; DETF families by path with family name + PRD pointer |
| **Hooks** | Uniswap V4 (and any other) hook packages; registry/deploy path notes |
| **Protocol adapters (IndexedEx-owned)** | Paths under `contracts/protocols/**` that are product vaults/adapters (not Crane ports) |
| **Routers / periphery** | User-facing routers, prepaid/batch where present |
| **Tests** | Gold TestBase hierarchy roots; hermetic vs fork conventions; major `test/` mirrors of contracts |
| **Scripts / deploy** | Staged scripts, env conventions at **catalog** level (link orchestration skill if any) |
| **Frontend** | App roots, env/address registry concepts; point to `frontend/ROADMAP.md` for product roadmap |
| **Research** | `research/scenarios/**` campaign PRDs — list only, not methodology |
| **Docs** | Top-level `docs/` map: agent, detf, reviews, historical PRDs |
| **Libs** | `lib/crane` (submodule), other vendored libs agents should not re-port; Bankr note (parent workspace only) |

### 2.2 Crane submodule `lib/crane/` (required)

| Area | Minimum inventory content |
|------|---------------------------|
| **Framework core** | Diamond / facet / target / repo patterns; factories CREATE3; access (ownable/operable); introspection |
| **Tokens & vaults** | ERC20/721/4626 packages agents may reuse |
| **Utilities** | Math, sets, ConstProd-style helpers, crypto/EIP-712 as exposed |
| **Protocol ports present in Crane** | Each major port under Crane `contracts/protocols` / `contracts/external` with **one-line status** (ported, TestBase name, FOUNDRY_PROFILE if any) |
| **Testing stack** | `CraneTest`, InitDev/InitBc services, Behavior libraries pattern, adversarial skill |
| **Crane skills catalog** | Name → purpose → when to load; note sync into IndexedEx mirrors |
| **Agent identities** | `crane-porter`, `docs-skill-scribe`, others under Crane `.claude/agents/` |

### 2.3 Skills & agent instruction surfaces (required)

| Surface | Inventory content |
|---------|-------------------|
| **IndexedEx-local skills** | Under `.claude/skills/` that are **not** pure Crane mirrors; mirror policy to `.grok/` / `.opencode/` |
| **Crane-synced skills** | List expected after `./scripts/sync-crane-skills.sh` |
| **Protocol skill families** | Grouped (Aave, Aerodrome, Balancer, Uniswap, Morpho, Olympus, Permit2, …) with “architecture vs operations” distinction |
| **Explicit exclusions** | Bankr location; Godot/accelerator; parent-only catalogs |
| **Grok/Claude agent types** | Project-defined subagents/agents if declared in repo config |

### 2.4 Explicitly optional / lower priority

- Line-by-line ABI or selector tables (unless needed for a skill gap).
- Every historical PRD under `docs/archive` (list “archive exists” only).
- Exhaustive frontend component props; **do** include app routes + major modules (deep-as-practical applies here too).
- Full research figure/script inventories (campaign PRD paths + scenario dirs enough unless a skill gap needs more).

### 2.5 Extension / legacy labeling

- **No package is barred from extension** by this program.
- Inventory **may** label paths as historical, incomplete, experimental, or superseded for agent honesty.
- Such labels **must not** be phrased as “do not extend” / “forbidden to build on” unless a separate product law document already says so (this PRD does not create that ban).

---

## 3. Deliverable artifacts

Filenames and roles are **fixed in §0.7.4**. The implementation plan must not rename them.

### 3.1 IndexedEx (required)

| Artifact | Purpose |
|----------|---------|
| `docs/CODEBASE_MAP.md` | Primary deep map (full rewrite); split only per §0.7.4 if >2000 lines |
| `docs/agent/AGENT_NAVIGATION_INDEX.md` | Task → skill / law / map section / path |
| `docs/agent/INDEXEDEX_CONTENT_INVENTORY.md` | Thin package index (**required**) |
| `docs/agent/SKILL_CATALOG.md` | Full skill catalog (**required**) |
| `docs/agent/SKILL_GAP_BACKLOG.md` | Ranked gaps + blocked deferrals |
| `scripts/install-cartographer.sh` | PATH installer |
| `.cartographer/**` | Committed fresh graph |

### 3.2 Crane (required, pushed)

| Artifact | Purpose |
|----------|---------|
| `lib/crane/docs/CODEBASE_MAP.md` | Primary Crane deep map |
| `lib/crane/docs/agent/CRANE_CAPABILITY_INVENTORY.md` | Crane capability inventory |
| `lib/crane/AGENTS.md` / `lib/crane/CLAUDE.md` | Lean discovery pointers |
| `lib/crane/.cartographer/**` | Committed fresh graph |
| IndexedEx `lib/crane` gitlink | Points at **pushed** Crane SHA |

### 3.3 Harness patches

Per **§0.7.5** (`Claude.md` SoT, `CLAUDE.md` identical copy, agent law Discovery subsection, conditional Grok/OpenCode).

### 3.4 Skills

Per **§0.7.7** (catalog + unlimited-within-reason implementation + backlog).

### 3.5 Metadata

Per **§0.7.8** (`git_sha` required).

---

## 4. Work packages (for the implementation plan / subagents)

These packages are **requirements for planning**, not execution steps completed by this PRD.

### WP-0 — Cartographer on PATH (setup)

- Implement exactly **§0.7.2** (`scripts/install-cartographer.sh` → `$HOME/bin/cartographer` → marketplace via Bun).
- Acceptance: `command -v cartographer` && `cartographer --help` from a non-repo cwd.

### WP-0b — Cartographer re-index (IndexedEx + Crane)

- Run exactly **§0.7.3** commands (`--force`, both roots, `verify --fresh` must pass).
- **Commit** both `.cartographer/` trees (no LFS).
- Use graph outputs as **inputs** to map authors — prose maps remain primary.

### WP-A — IndexedEx contracts & tests survey (read-only)

- Walk `contracts/**` and primary `test/**` roots (tree + Cartographer as aid).
- Emit structured notes: path, purpose, DETF/SE/hook/manager/registry classification, PRD if co-located.
- Flag empty/orphan/historical dirs (**not** as extension-barred).

### WP-B — Crane submodule survey (read-only)

- Walk `lib/crane/contracts/**`, Crane skills, `AGENTS.md`, TestBase roots, protocol ports (+ Crane Cartographer graph).
- Emit capability list: pattern libraries, ports, FOUNDRY profiles, skills.
- Do **not** treat Crane as something to re-vendor into IndexedEx.

### WP-C — Skills & agent surfaces survey (read-only)

- Diff conceptual sets: `lib/crane/.claude/skills/` vs IndexedEx `.claude/skills/` vs `.grok/skills/`.
- Catalog IndexedEx-local skills and protocol families.
- Record exclusions (Bankr parent-only, Godot) and sync scripts.
- Produce ranked backlog file **`docs/agent/SKILL_GAP_BACKLOG.md`** per §0.7.7 for WP-H.

### WP-D — Docs/research/frontend/scripts catalog (read-only)

- Inventory non-contract product surfaces for agent routing (deep-as-practical for major modules).

### WP-E — Merge & author primary map + indexes (write, IndexedEx)

- **Full rewrite** of `docs/CODEBASE_MAP.md` from WP-A/D notes + Cartographer; apply §0.7.4 split rule if >2000 lines.
- Author **required** `AGENT_NAVIGATION_INDEX.md`, `INDEXEDEX_CONTENT_INVENTORY.md`, `SKILL_CATALOG.md`.
- Point to Cartographer usage (`scripts/install-cartographer.sh`, re-index commands).

### WP-F — Crane-canonical map/inventory + push (write, Crane submodule)

- Write exact files in §0.7.4 Crane table.
- Patch Crane always-on routers (`AGENTS.md` / `CLAUDE.md`) with discovery pointers.
- Include committed Crane `.cartographer/` from WP-0b.
- Branch/push/gitlink order exactly **§0.7.6**.

### WP-G — Patch all harness entrypoints (write, IndexedEx)

- Sync discovery links across Claude/Grok/OpenCode/AGENTS + agent law discovery subsection.
- Include Cartographer + primary map + Crane inventory links.
- Always-on stays lean.

### WP-H — Implement missing/stale skills (write; unlimited-within-reason)

- Work the ranked gap list by impact until **§5 cold-start checklist** would pass for skill routing.
- **No mandatory human checkpoint** before starting skill authoring (implementer ranks and executes).
- Author at correct SoT; run Crane skill sync / local mirrors.
- Full-site `docs-skill-scribe` only when a ranked gap requires it; otherwise focused skills.
- Defer only with explicit blocker notes.

### WP-I — Acceptance pass

- §5 checklist including PATH, both re-indexes, Crane push + gitlink, harness parity, skills.
- Link checker; path existence; no product-law regressions.

**Parallelism intent:** WP-0 → WP-0b → WP-A–D parallel → WP-E and WP-F (Crane write/push coordinated) → WP-G → WP-H (may overlap late WP-E once gaps known) → WP-I.

---

## 5. Acceptance checklist (implementation done bar)

A reviewer (human or verification agent) must confirm:

1. [ ] Installer script exists; `cartographer` is on `PATH` after running it (`command -v cartographer`; `cartographer --help` from any cwd).
2. [ ] IndexedEx re-indexed; `.cartographer/` **committed**; `cartographer verify` / `verify --fresh` acceptable.
3. [ ] Crane re-indexed; `.cartographer/` **committed and pushed** with Crane; verify/fresh acceptable.
4. [ ] `docs/CODEBASE_MAP.md` is a **full rewrite**, deep-as-practical, with current trees and `last_mapped` metadata — **primary map**.
5. [ ] Crane-canonical capability inventory/map exists **inside `lib/crane/`**, **pushed** to Crane remote; IndexedEx **gitlink bumped** to that commit.
6. [ ] `docs/agent/AGENT_NAVIGATION_INDEX.md` maps major task classes → skills / law / map sections / paths.
7. [ ] All harness entrypoints (Claude, Grok, OpenCode, root `AGENTS.md` if any) share the discovery stack without full tree paste.
8. [ ] Agent law has a discovery pointer; non-negotiables intact.
9. [ ] Skill catalog lists SoT paths + mirror/sync rules; Bankr/Godot exclusions preserved.
10. [ ] Ranked missing/stale skills implemented **unlimited-within-reason**; only blocked gaps remain, with reasons.
11. [ ] No packages labeled extension-forbidden solely by this program.
12. [ ] Metadata `last_reviewed` / `last_mapped` present on maps/inventories.
13. [ ] Cold-start probes (examples):
    - “Where is vault registry deploy path documented?”
    - “What Crane skill covers CREATE3 DFPkg deploy?”
    - “Where in Crane is Morpho / Olympus port status listed?”
    - “Where are Single SE DETF family PRDs?”
    - “Are Bankr skills in this repo’s skill tree?”
    - “How do I run `cartographer` from any directory?”

---

## 6. Quality bar for inventory writing

| Rule | Detail |
|------|--------|
| **Progressive disclosure** | Summaries first; deep trees only where density requires a subsection |
| **Paths over prose** | Prefer `contracts/...` paths agents can open |
| **Roles** | Mark IndexedEx product vs Crane framework vs vendored external |
| **Link law, don’t restate it** | DETF thresholds/compound → PRDs; deploy non-negotiables → agent law |
| **Role names only** | DETF inventory uses `rateAsset` / `pairToken` / etc., never product brands |
| **No fake completeness** | Prefer “not surveyed” / “legacy?” over inventing packages |
| **Stable anchors** | Use clear `##` headings so navigation index can deep-link |

---

## 7. Freshness & maintenance (post-delivery)

| Trigger | Action |
|---------|--------|
| New DETF family / vault package / hook package lands | Update content inventory + navigation row + CODEBASE_MAP directory stub |
| Crane submodule bump | Re-run WP-B delta; refresh Crane capability inventory + skill sync note |
| New IndexedEx-local skill | Author under `.claude/skills/`, mirror, add catalog row |
| Cartographer re-index | **Required** after structural package adds/moves when maps are refreshed; `cartographer` must remain on `PATH`; reconcile prose maps with graph if they diverge |

**Owner expectation:** inventories are **agent infrastructure**. Large feature PRs that add packages should include a one-line inventory update the same way they update tests.

---

## 8. Risks & mitigations

| Risk | Mitigation |
|------|------------|
| Inventories rot like the June 2026 map | Metadata + maintenance triggers + required Cartographer re-index on structural refresh |
| `Claude.md` bloat | Hard size rule: links + tables only |
| Crane changes left unpushed | Done bar requires **push + gitlink bump** |
| Cartographer not on PATH | WP-0 mandatory; acceptance checks `command -v cartographer` |
| Stale graph used as truth | Re-index both repos before map authoring; `verify --fresh` |
| Subagents invent packages | Survey is tree walk + graph aid; merge agent verifies paths exist |
| Duplicate maps | CODEBASE_MAP = primary narrative; indexes point into it; navigation = task router |
| Skill work expands forever | Unlimited-**within-reason**: rank by agent impact; stop when routing gaps are closed or **blocked**; no full-site crawls without ranked need |
| Graph blobs bloat git | Accepted: graphs **committed** without LFS; re-index/recommit on map refresh; LFS only in a **future** program if artifact >50MB |
| Unpushed Crane pin | **§0.7.6**: Crane push → then IndexedEx gitlink PR |
| Executor invents paths/tools | **§0.7** non-decisions table |

---

## 9. Implementation plan requirements (next document)

The follow-on **implementation plan** MUST:

1. **Restate §0.7 as non-negotiable execution law** — plan is a schedule + subagent prompts, not a second place to choose paths/tools.
2. Paste or reference exact WP-0 / WP-0b commands from §0.7.2–§0.7.3.
3. Name **concrete subagent prompts** for WP-A–D using the §0.7.9 fan-out (4 parallel survey agents).
4. Order: **PATH → re-index → surveys → WP-E maps → WP-F Crane push → WP-G harnesses → WP-H skills → WP-I accept**; IndexedEx PR after Crane remote SHA exists (§0.7.6).
5. Checklist of **exact files** from §0.7.4–§0.7.5 to create/edit.
6. Verification commands matching §5 + §0.7 (PATH from `/tmp`, both `verify --fresh`, gitlink = remote Crane SHA, skill mirrors, cold-start probes).
7. Forbid on-chain product code; forbid LFS; forbid inventing deliverable paths.
8. Subagent fan-out per implementation plan (unlimited as appropriate; disjoint write sets).

**Execution authorized** via [`docs/AGENT_INVENTORY_AND_NAVIGATION_IMPLEMENTATION_PLAN.md`](./AGENT_INVENTORY_AND_NAVIGATION_IMPLEMENTATION_PLAN.md).

---

## 10. Open questions — all product/ops decisions resolved

| # | Question | Resolution (locked) |
|---|----------|---------------------|
| 1 | Skill budget | Unlimited-within-reason (§0.7.7) |
| 2 | Crane contribution | Commit + push; bump gitlink (§0.7.6) |
| 3 | Cartographer | Required re-index both repos (§0.7.3) |
| 4 | PATH install | `scripts/install-cartographer.sh` → `$HOME/bin` → marketplace via Bun (§0.7.2) |
| 5 | Graphs in git | Commit both `.cartographer/` trees; **no LFS** (§0.7.1 C, §0.7.3) |
| 6 | Extension bans | None |
| 7 | Skill gate | Implementer until §5 passes (§0.7.7) |
| 8 | PR shape | Crane branch/push first, then IndexedEx PR (§0.7.6) |
| 9 | Wrapper source | Thin wrapper → Claude marketplace Cartographer via Bun — **not** vendored CLI, **not** global npm (§0.7.1 A) |
| 10 | Map split | >2000 lines → fixed `docs/agent/maps/0N-*.md` layout (§0.7.1 B, §0.7.4) |
| 11 | Crane doc shape | **Both** `docs/CODEBASE_MAP.md` and `docs/agent/CRANE_CAPABILITY_INVENTORY.md` (§0.7.4) |
| 12 | IndexedEx indexes | Content inventory + skill catalog **both required** (§0.7.4) |
| 13 | Harness SoT | `Claude.md` SoT; `CLAUDE.md` identical copy (§0.7.5) |

**No residual “defaults OK” items.** Remaining work for the implementation plan is **prompt text, sequencing, and verification commands only**.

---

## 11. Document control

| Field | Value |
|-------|--------|
| **Location** | `docs/AGENT_INVENTORY_AND_NAVIGATION_PRD.md` |
| **Related** | `Claude.md`, `docs/agent/INDEXEDEX_AGENT_LAW.md`, `docs/CODEBASE_MAP.md`, `lib/crane/AGENTS.md` |
| **Next** | Execute [`docs/AGENT_INVENTORY_AND_NAVIGATION_IMPLEMENTATION_PLAN.md`](./AGENT_INVENTORY_AND_NAVIGATION_IMPLEMENTATION_PLAN.md) |
| **Authoring date** | 2026-08-09 |

---

## Appendix A — Suggested navigation index task classes (seed)

Implementation should expand/correct this seed, not treat it as final:

| Task class | Primary skill / law | Inventory section |
|------------|---------------------|-------------------|
| Diamond / facet / DFPkg / CREATE3 | `crane-deployment`, `crane-architecture` | Crane capabilities |
| IndexedEx vault/DETF deploy via registry | `indexedex-testing`, agent law deploy path | Platform core + vaults |
| Production-first tests / TestBases | `crane-testing`, `indexedex-testing` | Tests |
| Adversarial / abuse | `crane-adversarial-testing`, `indexedex-adversarial-testing` | Tests + DETF families |
| Uni V4 hook packages | `indexedex-uniswap-v4-hook-packages` | Hooks |
| Protocol port into Crane | `crane-porter`, `crane-porting`, `crane-porting-verification` | Crane ports |
| Docs → skills | `docs-skill-scribe`, `docs-to-skills` | Skills catalog |
| DETF product behavior | Family PRD + agent law + `docs/detf/*` | DETF families |
| UI product copy | `indexedex-product-voice` | Frontend |
| Morpho / Olympus (Crane) | `crane-morpho` / `crane-olympus` + domain skills | Crane ports |

## Appendix B — Anti-patterns for implementers

- Dumping `find` output into `Claude.md`.
- Copying entire Crane `AGENTS.md` into IndexedEx.
- Claiming skill coverage for packages that only have architecture skills and no IndexedEx TestBase guidance.
- Treating `docs/CODEBASE_MAP.md` `last_mapped: 2026-06-21` as current without Cartographer re-index + re-verify.
- Leaving Crane inventory only in a dirty submodule without **push + gitlink bump**.
- Assuming `cartographer` works without putting it on `PATH`.
- Syncing Bankr skills into this repo.
- Using product brands (RICH/RICHIR/etc.) in inventory text for DETF roles.
- Labeling packages “do not extend” solely because they look legacy.
