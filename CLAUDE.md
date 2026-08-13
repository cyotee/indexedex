# CLAUDE.md — IndexedEx agent router

Lean, always-on instructions for agents in this monorepo. **Full product law** (DETF families, compound/expansion, thresholds, testing matrix, directory maps) lives in progressive-disclosure docs and skills — open those when the task needs them, do not paste them into every turn.

| Need | Open |
|------|------|
| Full IndexedEx agent law (ex-`AGENTS.md`) | [`docs/agent/INDEXEDEX_AGENT_LAW.md`](docs/agent/INDEXEDEX_AGENT_LAW.md) |
| Primary codebase map | [`docs/CODEBASE_MAP.md`](docs/CODEBASE_MAP.md) |
| Task navigation index | [`docs/agent/AGENT_NAVIGATION_INDEX.md`](docs/agent/AGENT_NAVIGATION_INDEX.md) |
| Content inventory (packages) | [`docs/agent/INDEXEDEX_CONTENT_INVENTORY.md`](docs/agent/INDEXEDEX_CONTENT_INVENTORY.md) |
| Skill catalog | [`docs/agent/SKILL_CATALOG.md`](docs/agent/SKILL_CATALOG.md) |
| Crane capability inventory | [`lib/crane/docs/agent/CRANE_CAPABILITY_INVENTORY.md`](lib/crane/docs/agent/CRANE_CAPABILITY_INVENTORY.md) |
| Cartographer install (PATH) | [`scripts/install-cartographer.sh`](scripts/install-cartographer.sh) |
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
7. **Forge patience (non-negotiable).** Monorepo solc / `forge` cold or near-cold compiles commonly take **20–40+ minutes** with little or no useful output while a single process holds high CPU/RAM. That is **normal, not a hang**. **Wait for process exit** (success **or** a real compiler/test error). **Never kill** `forge` / `solc` out of impatience or “no progress lines” — a mid-run kill discards all elapsed compile time and forces a full or near-full rebuild (pure loss). If a tool requires a timeout, set it to **hours** (e.g. 2–4h) for first compile in a worktree, not 10–20 minutes. Prefer one long-running command and completion notification over busy-polling and aborting.
8. **Worktree compile seed (non-negotiable).** Before the **first** `forge build` / `forge test` / `forge` compile in a **new or empty** git worktree, seed Foundry artifacts from a **warm** checkout (primary repo or last green worktree). Copy the directories named by this repo’s `foundry.toml` — today **`cache_path = 'cache_forge'`** and **`out = 'out'`** (read `foundry.toml` if renamed; do **not** invent a default `cache/` path). Example:

   ```bash
   # REPO = warm checkout; WT = new worktree root
   rsync -a "${REPO}/cache_forge/" "${WT}/cache_forge/"   # or: cp -a
   rsync -a "${REPO}/out/" "${WT}/out/"
   # Prefer: avoid nested crane reinstall thrash
   rm -rf "${WT}/lib/crane" && ln -s "${REPO}/lib/crane" "${WT}/lib/crane"
   ```

   After a **green** forge in a worktree, copy updated `cache_forge/` + `out/` **back** to the warm seed so the next worktree benefits. Seeded cache only skips **unchanged** units — CODE edits still recompile those packages (expected, still far cheaper than cold monorepo compile). **Do not** delete `out/` or `cache_forge/` “to be safe” mid-program.

---

## Skill routing (load on demand)

| Task | Skills / agents (prefer Crane path when listed) |
|------|--------------------------------------------------|
| Deploy / DFPkg / CREATE3 | `crane-deployment`, `crane-architecture` |
| Tests / TestBases | `crane-testing`, `indexedex-testing` (LR-7 + proxy surface matrix + trust-flag negatives) |
| Adversarial / abuse | `crane-adversarial-testing`, `indexedex-adversarial-testing` (catalog A–K + **A0/L/M/N/O**; I=pretransfer claim, J=facet/proxy surface; ship gate: `implementation-test-dod.md`) |
| Incident-driven security / DeFiHackLabs | `defi-incident-patterns` (maps `lib/DeFiHackLabs` themes → catalog IDs + secure-dev checklist; **reference only** — hermetic production-first tests remain the bar) |
| Test coverage audit / gap reports | [`docs/testing/TEST_COVERAGE_AUDIT_PRD.md`](docs/testing/TEST_COVERAGE_AUDIT_PRD.md) + [`TEST_COVERAGE_AUDIT_EXECUTE_PLAN.md`](docs/testing/TEST_COVERAGE_AUDIT_EXECUTE_PLAN.md) → Stage 1 reports; then gap-closure impl plan |
| Security audit / parallel remediation planning | [`docs/security/SECURITY_AUDIT_PRD.md`](docs/security/SECURITY_AUDIT_PRD.md) + [`SECURITY_AUDIT_EXECUTE_PLAN.md`](docs/security/SECURITY_AUDIT_EXECUTE_PLAN.md) → Stage 1 reports under `docs/security/audit/`; then [`PROMPT_SECURITY_AUDIT_REMEDIATION_PRD.md`](docs/security/PROMPT_SECURITY_AUDIT_REMEDIATION_PRD.md) for the Stage 2 remediation PRD. Complements coverage-audit (do not compete on the same touch-set; `sec_fix_*` vs `gap_cover_*`) |
| Uni V4 hook packages | `indexedex-uniswap-v4-hook-packages` |
| Protocol port into Crane | agent `crane-porter` + `crane-porting` + `crane-porting-verification` |
| Docs → skills | agent `docs-skill-scribe` + `docs-to-skills` / `skill-authoring` |
| DETF product detail | Family PRD + [`docs/agent/INDEXEDEX_AGENT_LAW.md`](docs/agent/INDEXEDEX_AGENT_LAW.md) + `docs/detf/*` shared programs |
| UI product copy | `indexedex-product-voice` |
| UI money-path / live TX e2e (DTF, RH Anvil) | `indexedex-ui-tx-testing` |

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
