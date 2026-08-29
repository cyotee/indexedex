---
last_reviewed: 2026-08-13
git_sha: 4494c30
scope: navigation
method: cartographer+survey
---

# Agent Navigation Index

**Cold-start router:** task → skill / law / map section / code root. Always-on harnesses stay lean and point here.

| Need first | Open |
|------------|------|
| Full structure | [`docs/CODEBASE_MAP.md`](../CODEBASE_MAP.md) |
| Package index | [`docs/agent/INDEXEDEX_CONTENT_INVENTORY.md`](./INDEXEDEX_CONTENT_INVENTORY.md) |
| Skills | [`docs/agent/SKILL_CATALOG.md`](./SKILL_CATALOG.md) |
| Product/engineering law | [`docs/agent/INDEXEDEX_AGENT_LAW.md`](./INDEXEDEX_AGENT_LAW.md) |
| Crane capabilities | [`lib/crane/docs/agent/CRANE_CAPABILITY_INVENTORY.md`](../../lib/crane/docs/agent/CRANE_CAPABILITY_INVENTORY.md) |
| Crane map | [`lib/crane/docs/CODEBASE_MAP.md`](../../lib/crane/docs/CODEBASE_MAP.md) |
| Cartographer on PATH | [`scripts/install-cartographer.sh`](../../scripts/install-cartographer.sh) |

---

## Task → destination

| Task | Skill / agent | Law / PRD | Map / path |
|------|---------------|-----------|------------|
| CREATE3 facet / DFPkg / FactoryService | `crane-deployment`, `crane-architecture` | Crane `AGENTS.md` | `lib/crane/contracts/factories`, `lib/crane/contracts/proxies` |
| Foundry launch scripts / Anvil / 4663 gas quote | `indexedex-launch-scripts` | 46630 rewrite PRD + plan; 4663 `anvil_robinhood_main` README | `scripts/foundry/anvil_robinhood_testnet/`, `scripts/foundry/anvil_robinhood_main/` |
| 46630 `platform.json` / tokenlists / UI export | `indexedex-launch-scripts` → `references/frontend-export.md` | Phase 09 writer | `frontend/packages/protocol/src/addresses/chain/46630/`, `addressArtifacts.ts` |
| Deploy vault or DETF package | `indexedex-testing` (deploy path) | Agent law deploy section | `contracts/manager`, `contracts/registries/vault` — `indexedexManager.deploy*DFPkg` / registry, then package `deployVault` |
| Write hermetic Foundry tests | `crane-testing` → `indexedex-testing` | Agent law testing matrix | `contracts/test/IndexedexTest.sol`, package `TestBase_*`, `test/foundry/` |
| Adversarial / donation / reentrancy | `crane-adversarial-testing`, `indexedex-adversarial-testing` (catalog A–K + A0/L/M/N/O) | Agent law | DETF/SE package tests co-located or under `test/foundry/` |
| DeFiHackLabs / incident-driven security | `defi-incident-patterns` | `docs/agent/DEFI_HACKLABS_SKILLS_IMPLEMENTATION_PLAN.md` | `lib/DeFiHackLabs` (submodule; reference only) |
| Test coverage audit (reports only) | `docs/testing/TEST_COVERAGE_AUDIT_PRD.md` | skills DoD + catalog A–K | Outputs under `docs/testing/coverage-audit/`; feeds gap-closure implementation plan |
| Security audit (reports only) | `docs/security/SECURITY_AUDIT_PRD.md` + `SECURITY_AUDIT_EXECUTE_PLAN.md` | adversarial A–K+A0/L/M/N/O, ethskills-audit/CROPS, sharp-edges, spec-compliance, incident-patterns | Outputs under `docs/security/audit/`; Stage 2 prompt `docs/security/PROMPT_SECURITY_AUDIT_REMEDIATION_PRD.md` → `sec_fix_*` remediations. Complements coverage-audit (`TCA-*`/`gap_cover_*`); do not double-own the same files |
| Weird tokens (FoT / rebase / decimals / pause) | Do **not** re-ask — **LOCKED** | Agent law § Token policy | FoT and rebasing underlyings forbidden; non-18 decimals allowed (scale to 18); pause accepted; no allowlist |
| DETF mint/burn/bond/claim/compound | Family PRD + agent law § DETF | `docs/detf/*` shared programs | `contracts/vaults/detf/**` — role names only |
| Uni V4 DETF I/O routing + hook ABI | `crane-deployment`, `indexedex-testing`, `indexedex-uniswap-v4-hook-packages` | [`DETF_INSTANCE_IO_ROUTING_PRD.md`](../../contracts/vaults/detf/DETF_INSTANCE_IO_ROUTING_PRD.md) §16; [`DETF_INSTANCE_IO_ROUTING_IMPLEMENTATION_AND_TEST_PLAN.md`](../../contracts/vaults/detf/DETF_INSTANCE_IO_ROUTING_IMPLEMENTATION_AND_TEST_PLAN.md); stages [`DETF_INSTANCE_IO_ROUTING_PROGRAM.md`](../../contracts/vaults/detf/DETF_INSTANCE_IO_ROUTING_PROGRAM.md) | `contracts/hooks/uniswap/v4/interfaces/`, `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/`, `…/bondNft/` |
| Single SE DETF (Balancer V3) | Family package docs | Agent law | `contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/` |
| Uni V4 DETF (unified) | I/O routing §16 + deprecation coverage PRD | [`UNIFIED_DETF_DEPRECATION_TEST_COVERAGE_PRD.md`](../../contracts/vaults/detf/UNIFIED_DETF_DEPRECATION_TEST_COVERAGE_PRD.md) | `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/` (`UniswapV4DetfDFPkg`). Bind CP / Orbital / Weighted / Quad **hooks** |
| Multi-vault weighted DETF | Package TestBase / agent law | — | `contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/` |
| Uni V4 hook diamond package | `indexedex-uniswap-v4-hook-packages` | Hook PRDs under `contracts/hooks/uniswap/v4/**` | Package → Vault Registry → hook factory; `contracts/hooks/uniswap/v4/factory/` |
| Standard Exchange vault (ERC-4626) | `indexedex-testing` | — | `contracts/vaults/standard/erc4626/` |
| Protocol port into Crane | agent `crane-porter` + `crane-porting` + `crane-porting-verification` | Crane porting section | `lib/crane/contracts/external`, `lib/crane/contracts/protocols` |
| Morpho port status / integration | `crane-morpho`, `morpho-architecture` | Crane capability inventory | `lib/crane/contracts/protocols/lending/morpho/` |
| Olympus port status / integration | `crane-olympus`, `olympus-architecture` | Crane capability inventory | Crane tokens/stable olympus area + skills; see Crane inventory |
| Fee oracle / fee collector | — | Agent law platform | `contracts/oracles/fee`, `contracts/fee/collector` |
| Uni V4 multi-pool TWAP oracle (poke, Morpho adapters) | — | [`UNISWAP_V4_MULTI_POOL_TWAP_ORACLE_PRD.md`](../../contracts/oracles/uniswap/v4/twap/UNISWAP_V4_MULTI_POOL_TWAP_ORACLE_PRD.md) | `contracts/oracles/uniswap/v4/twap/` — DFPkg; diamond **instance per `PkgArgs.poolManager`**; **not** a V4 hook or vault |
| Frontend product / redesign | `indexedex-ui-refactor` (env/registry) | `frontend/ROADMAP.md` | `frontend/apps/dtf` (the only Next app) |
| Frontend live TX / UI e2e (DTF, RH 4663) | `indexedex-ui-tx-testing` | `frontend/apps/dtf/e2e/README.md` | `frontend/apps/dtf/e2e/**` |
| UI product copy | `indexedex-product-voice` | — | frontend copy surfaces |
| Docs site → skills | agent `docs-skill-scribe` + `docs-to-skills` | `skill-authoring` | skill trees under Crane or IX SoT |
| Cartographer re-index / graph | Installer + CLI | This index | `.cartographer/`, `lib/crane/.cartographer/` |
| Bankr / Base-agent skills | **Do not install here** | Claude.md Bankr note | Parent `projects-defi` via `./scripts/sync-bankr-skills.sh` |

---

## Deploy path (canonical)

1. **Facets:** CREATE3 + `*FactoryService` / `create3Factory` (Crane).
2. **Vault / DETF DFPkgs:** `vm.prank(owner); indexedexManager.deploy*DFPkg(...)` then package `deployVault` / vault registry — never bypass with bare `diamondPackageFactory.deploy` for registered vault packages.
3. **`PkgInit` / `PkgArgs`:** on the **interface**, not the implementation contract.
4. **Hooks (V4 diamond packages):** package → Vault Registry → hook factory (`deployHookVault` path); skill `indexedex-uniswap-v4-hook-packages`.

---

## DETF role names (never product brands)

| Role | Name |
|------|------|
| Rate / settlement asset | `rateAsset` |
| Other vault token(s) | `pairToken` |
| Underlying SE | `underlyingVault` / `standardExchangeVault` |
| SE vault share | `vaultShare` |
| DETF share (diamond) | `detfToken` / `address(this)` |
| Reserve BPT | `reservePool` / `reserveBpt` |
| Claim token | `rebasingClaimToken` |

---

## Cartographer (any directory)

```bash
./scripts/install-cartographer.sh
export PATH="$HOME/bin:$PATH"
command -v cartographer
# from any cwd after install:
cartographer --help
# re-index IndexedEx (from repo root):
cartographer index --root . --out .cartographer --force
cartographer verify --root . --out .cartographer --fresh
# Crane submodule:
cartographer index --root lib/crane --out lib/crane/.cartographer --force
cartographer verify --root lib/crane --out lib/crane/.cartographer --fresh
```

---

## Foundry profiles

| Profile | Use |
|---------|-----|
| default | Hermetic `forge test` |
| `FOUNDRY_PROFILE=fork` | Fork tests |
| Crane port profiles | e.g. `morpho_port`, `olympus_port` (see Crane skills) |

**`via_ir` forbidden.** No package-specific IndexedEx forge profiles.
