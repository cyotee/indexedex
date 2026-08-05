# CLAUDE.md

Read **[AGENTS.md](./Agents.md)** in this repo (same content as `Agents.md` / `AGENTS.md` depending on filesystem case).

## Must internalize for this monorepo

1. **Crane first:** `lib/crane/AGENTS.md` + canonical skills under `lib/crane/.claude/skills/` (`crane-deployment`, `crane-architecture`, `crane-testing`).
2. **IndexedEx deploy:** CREATE3 facets; vault/DETF DFPkgs via **manager vault registry** (never `new` facets/DFPkgs; never mock SUT vaults/manager/registry).
3. **Production-first tests:** real packages + gold TestBases; see `.claude/skills/indexedex-testing/` and AGENTS.md testing sections.
4. **DETF common expectations:** AGENTS.md section **“DETF families — common expectations”** — role names only, immutable unowned instances, inert→live via first bond, synthetic mint/burn gates, vault-share routes, bond NFT + rebasing claim, **sell→claim only after bond maturity** (new DETF-wide standard), preview==execution, price-shift under default thresholds, `InvalidRoute` for non-closed-form routes. Do not re-explain or invent alternate product rules; family PRDs under `contracts/vaults/detf/**` override only when explicit.

## Protocol porting into Crane

When porting/vendoring external DeFi protocols into Crane (`lib/crane`):

1. Skills (also linked from this repo’s `.claude/skills/`): **`crane-porting`**, **`crane-porting-verification`**.
2. Agent identity: **`crane-porter`** (`.claude/agents/crane-porter.md` → Crane).
3. Rule of thumb: faithful protocol domain under `contracts/external/` / `protocols/`; shared OZ/Solady under `contracts/external/`; no new private `dependencies/openzeppelin*` trees; tests required (hermetic + fork when possible).

## Documentation → skills

1. Skills: **`docs-to-skills`**, **`skill-authoring`** (symlinked from Crane).
2. Agent: **`docs-skill-scribe`**.
3. Always inventory and process the full docs graph; emit compartmentalized skill families (lean SKILL.md + `references/`), not one mega-file.

Canonical sources live in `lib/crane/.claude/skills/` and `lib/crane/.claude/agents/`.

If `PROGRESS.md` exists, read it for cross-session context before starting work.
**Frontend redesign:** start at [`frontend/ROADMAP.md`](./frontend/ROADMAP.md) (root `PROGRESS.md` may only point there).
