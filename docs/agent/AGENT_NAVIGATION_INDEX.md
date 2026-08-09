---
last_reviewed: 2026-08-09
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
| Deploy vault or DETF package | `indexedex-testing` (deploy path) | Agent law deploy section | `contracts/manager`, `contracts/registries/vault` — `indexedexManager.deploy*DFPkg` / registry, then package `deployVault` |
| Write hermetic Foundry tests | `crane-testing` → `indexedex-testing` | Agent law testing matrix | `contracts/test/IndexedexTest.sol`, package `TestBase_*`, `test/foundry/` |
| Adversarial / donation / reentrancy | `crane-adversarial-testing`, `indexedex-adversarial-testing` | Agent law | DETF/SE package tests co-located or under `test/foundry/` |
| DETF mint/burn/bond/claim/compound | Family PRD + agent law § DETF | `docs/detf/*` shared programs | `contracts/vaults/detf/**` — role names only |
| Single SE DETF (Balancer V3) | Family package docs | Agent law | `contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/` |
| Single SE DETF (Uni V4) | Co-located PRD | `UniV4SingleStandardExchangeDETF_PRD.md` | `contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/single/` |
| Uni V4 Single SE CP DETF | Co-located PRD | `UniswapV4SingleStandardExchangeDETF_PRD.md` | `…/uniswap/v4/standardExchange/constantProduct/single/` |
| Multi-vault weighted DETF | Package TestBase / agent law | — | `contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/` |
| Uni V4 hook diamond package | `indexedex-uniswap-v4-hook-packages` | Hook PRDs under `contracts/hooks/uniswap/v4/**` | Package → Vault Registry → hook factory; `contracts/hooks/uniswap/v4/factory/` |
| Standard Exchange vault (ERC-4626) | `indexedex-testing` | — | `contracts/vaults/standard/erc4626/` |
| Protocol port into Crane | agent `crane-porter` + `crane-porting` + `crane-porting-verification` | Crane porting section | `lib/crane/contracts/external`, `lib/crane/contracts/protocols` |
| Morpho port status / integration | `crane-morpho`, `morpho-architecture` | Crane capability inventory | `lib/crane/contracts/protocols/lending/morpho/` |
| Olympus port status / integration | `crane-olympus`, `olympus-architecture` | Crane capability inventory | Crane tokens/stable olympus area + skills; see Crane inventory |
| Fee oracle / fee collector | — | Agent law platform | `contracts/oracles/fee`, `contracts/fee/collector` |
| Frontend product / redesign | `indexedex-ui-refactor` (env/registry) | `frontend/ROADMAP.md` | `frontend/apps/**` |
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
