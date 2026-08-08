# CLAUDE.md — IndexedEx agent router

Lean, always-on instructions for agents in this monorepo. **Full product law** (DETF families, compound/expansion, thresholds, testing matrix, directory maps) lives in progressive-disclosure docs and skills — open those when the task needs them, do not paste them into every turn.

| Need | Open |
|------|------|
| Full IndexedEx agent law (ex-`AGENTS.md`) | [`docs/agent/INDEXEDEX_AGENT_LAW.md`](docs/agent/INDEXEDEX_AGENT_LAW.md) |
| Frontend redesign / active UI work | [`frontend/ROADMAP.md`](frontend/ROADMAP.md) (not root `PROGRESS.md`) |
| Crane framework | `lib/crane/AGENTS.md` + skills under `lib/crane/.claude/skills/` |
| Family product law | Co-located `*_PRD.md` / impl plans next to the package |

Root `PROGRESS.md` is **historical only** (Permit2 notes). Do not treat it as current roadmap.

---

## Non-negotiables (always apply)

1. **Crane first** for diamonds, CREATE3, DFPkgs, TestBases: `crane-deployment`, `crane-architecture`, `crane-testing` (canonical under `lib/crane/.claude/skills/`).
2. **Never `new` facets/DFPkgs.** Facets via CREATE3 / FactoryService; vault & DETF packages via **IndexedEx manager vault registry** (`indexedexManager.deploy*DFPkg` / registry path).
3. **Production-first tests.** No mocks of SUT (vaults, DETF, manager, registry, fee oracle, facets, DFPkgs). Prefer gold TestBases: `CraneTest` → `IndexedexTest` → protocol TestBase.
4. **DETF role names only** (never product brands like RICH/RICHIR):

   | Role | Name |
   |------|------|
   | Rate / settlement asset | `rateAsset` |
   | Other vault token(s) | `pairToken` |
   | Underlying SE | `underlyingVault` / `standardExchangeVault` |
   | SE vault share | `vaultShare` |
   | DETF share (diamond) | `detfToken` / `address(this)` |
   | Reserve BPT | `reservePool` / `reserveBpt` |
   | Claim token | `rebasingClaimToken` |

   Use `weth`/`WETH` only in truly WETH-specific code. Full DETF law: [`docs/agent/INDEXEDEX_AGENT_LAW.md`](docs/agent/INDEXEDEX_AGENT_LAW.md) § DETF families + family PRDs under `contracts/vaults/detf/**`.

5. **DETF instances** are immutable/unowned after deploy. Inert until first bond / family bootstrap. Mint/burn thresholds from `PkgArgs` → storage (`DETFThresholdPolicy`); fees via fee oracle. Sell→claim only after bond maturity (DETF-wide).
6. **Foundry profiles:** hermetic = default `forge test`; fork = `FOUNDRY_PROFILE=fork`. No package-specific profiles. **`via_ir` forbidden.**

---

## Skill routing (load on demand)

| Task | Skills / agents (prefer Crane path when listed) |
|------|--------------------------------------------------|
| Deploy / DFPkg / CREATE3 | `crane-deployment`, `crane-architecture` |
| Tests / TestBases | `crane-testing`, `indexedex-testing` |
| Adversarial / abuse | `crane-adversarial-testing`, `indexedex-adversarial-testing` |
| Uni V4 hook packages | `indexedex-uniswap-v4-hook-packages` |
| Protocol port into Crane | agent `crane-porter` + `crane-porting` + `crane-porting-verification` |
| Docs → skills | agent `docs-skill-scribe` + `docs-to-skills` / `skill-authoring` |
| DETF product detail | Family PRD + [`docs/agent/INDEXEDEX_AGENT_LAW.md`](docs/agent/INDEXEDEX_AGENT_LAW.md) + `docs/detf/*` shared programs |
| UI product copy | `indexedex-product-voice` |

**Skill source of truth:** Crane skills under `lib/crane/.claude/skills/` — refresh mirrors with `./scripts/sync-crane-skills.sh`. IndexedEx-local skills: author under `.claude/skills/<name>/`, mirror to `.grok/skills/` and `.opencode/skills/`.

**Bankr / Base-agent catalogs** are **not** installed into this repo’s skill trees. They live under the parent workspace (`projects-defi`) via `./scripts/sync-bankr-skills.sh`. Do not re-copy them here.

**Out of scope skills for this monorepo:** do not invoke Godot / game-engine skills (`godot`, `godot-development`, `accelerator-usage`, boardgame plugins) even if they appear in the global skill list.

---

## Deploy path reminder

- Facets: CREATE3 + `*FactoryService` / `create3Factory`.
- Vault/DETF DFPkgs: `vm.prank(owner); indexedexManager.deploy*DFPkg(...)` then package `deployVault` / registry — never bypass with `diamondPackageFactory.deploy` for registered vault packages.
- `PkgInit` / `PkgArgs` on the **interface**, not the contract.

---

## When to open the full law file

Open [`docs/agent/INDEXEDEX_AGENT_LAW.md`](docs/agent/INDEXEDEX_AGENT_LAW.md) before substantial work on:

- Any DETF family (mint/burn, bond/claim, compound, expansion, thresholds, routes)
- New vault packages or registry wiring
- Adversarial or lifecycle test plans that must match product gates

Otherwise stay on this router + the specific skill/PRD for the task.
