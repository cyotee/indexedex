---
last_reviewed: 2026-08-09
git_sha: 4494c30
scope: indexedex
method: cartographer+survey
---

# IndexedEx Content Inventory

Thin package/module index: **path · purpose · owner · PRD · test root**. Deep narrative lives in [`docs/CODEBASE_MAP.md`](../CODEBASE_MAP.md). Crane details: [`lib/crane/docs/agent/CRANE_CAPABILITY_INVENTORY.md`](../../lib/crane/docs/agent/CRANE_CAPABILITY_INVENTORY.md).

Cartographer (2026-08-09): IndexedEx graph ~5408 files / 7264 nodes under `.cartographer/`.

---

## Platform

| path | purpose | owner | PRD | test root |
|------|---------|-------|-----|-----------|
| `contracts/manager/` | IndexedexManager DFPkg + FactoryService | IndexedEx | — | via `IndexedexTest` / manager specs |
| `contracts/registries/vault/` | Vault registry: package register, deploy, query, disable | IndexedEx | — | registry / manager tests under `test/foundry/` |
| `contracts/oracles/fee/` | Vault fee oracle facets | IndexedEx | — | fee oracle tests |
| `contracts/fee/collector/` | Fee collector DFPkg + facets | IndexedEx | — | fee collector tests |
| `contracts/constants/` | IndexedEx constants | IndexedEx | — | — |
| `contracts/interfaces/` | Shared interfaces (+ proxies, detf) | IndexedEx | — | — |

## Vaults (non-DETF)

| path | purpose | owner | PRD | test root |
|------|---------|-------|-----|-----------|
| `contracts/vaults/basic/` | Basic vault packages | IndexedEx | — | vault TestBases / `test/foundry/` |
| `contracts/vaults/standard/erc4626/` | ERC-4626 Standard Exchange DFPkg | IndexedEx | related SE PRDs under protocols | `contracts/test/bases/TestBase_ERC4626StandardExchange.sol` |
| `contracts/vaults/slipstream/` | Slipstream-related vault support | IndexedEx | — | — |
| `contracts/vaults/*VaultComponent*` | Shared vault component factories/repos | IndexedEx | — | `TestBase_VaultComponents` |

## DETF — shared

| path | purpose | owner | PRD | test root |
|------|---------|-------|-----|-----------|
| `contracts/vaults/detf/common/core/` | Shared DETF core | IndexedEx | agent law + `docs/detf/` | package TestBases |
| `contracts/vaults/detf/common/claimToken/` | Rebasing claim token DFPkg | IndexedEx | — | co-located |
| `contracts/vaults/detf/common/bondNft/` | Bond NFT vault DFPkg | IndexedEx | — | co-located |
| `contracts/vaults/detf/common/inventory/` | DETF inventory helpers | IndexedEx | — | — |
| `contracts/vaults/detf/common/factory/` | Shared DETF factory / NFT factory | IndexedEx | — | — |
| `docs/detf/` | Cross-family compound, expansion, process docs | IndexedEx | `DETF_Protocol_Compound_And_Supply_Expansion_PRD.md`, Olympus flywheel PRD | — |
| `contracts/vaults/detf/DETF_DIRECTORY_REORGANIZATION_PRD.md` | Directory layout law | IndexedEx | self | — |

## DETF — Balancer V3 families

| path | purpose | owner | PRD | test root |
|------|---------|-------|-----|-----------|
| `…/balancer/v3/standardExchange/single/` | Single Standard Exchange DETF | IndexedEx | (package docs) | `TestBase_SingleStandardExchangeDETF.sol` |
| `…/balancer/v3/multi-vault-weighted/` | Multi-vault weighted DETF | IndexedEx | — | `TestBase_MultiVaultWeightedDetf.sol` |
| `…/balancer/v3/mixedBuffer/` | Mixed buffer multi-vault stable DETF | IndexedEx | — | `TestBase_MixedBufferMultiVaultStableDetf.sol` |
| `…/balancer/v3/stable/common/` | Composed stable common DETF | IndexedEx | — | `TestBase_ComposedStableCommonDetf*.sol` |
| `…/balancer/v3/uniswap/v4/crossVersion/v2/` | Dual-liquidity linked cross-version | IndexedEx | `docs/detf/balancer/v3/uniswap/v4/crossVersion/v2/*` | package |

## DETF — Uniswap V4 families

| path | purpose | owner | PRD | test root |
|------|---------|-------|-----|-----------|
| `…/uniswap/v4/standardExchange/single/` | Uni V4 Single SE DETF | IndexedEx | `UniV4SingleStandardExchangeDETF_PRD.md` | `TestBase_UniswapV4SingleStandardExchangeDETF.sol` |
| `…/uniswap/v4/standardExchange/constantProduct/single/` | Uni V4 Single SE CP DETF | IndexedEx | `UniswapV4SingleStandardExchangeDETF_PRD.md` | package |
| `…/uniswap/v4/standardExchange/weighted/` | Uni V4 SE weighted DETF | IndexedEx | `UniswapV4StandardExchangeWeightedDETF_PRD.md` | package |
| `…/uniswap/v4/standardExchange/orbital/` | Uni V4 SE orbital DETF | IndexedEx | `UniswapV4StandardExchangeOrbitalDETF_PRD.md` | package |
| `…/uniswap/v4/common/{nft,rebasing}/` | Uni V4 DETF bond NFT + claim packages | IndexedEx | — | package |

## Hooks (Uniswap V4)

| path | purpose | owner | PRD | test root |
|------|---------|-------|-----|-----------|
| `contracts/hooks/uniswap/v4/factory/` | Hook diamond package callback factory | IndexedEx | factory PRD | factory tests |
| `…/standardExchange/constantProduct/single/` | Single SE CP buffer hook DFPkg | IndexedEx | co-located hook PRD | package TestBase |
| `…/standardExchange/single/` | Single SE buffer hook | IndexedEx | co-located | package |
| `…/standardExchange/dual/` | Dual SE CP buffer hook | IndexedEx | co-located | package |
| `…/standardExchange/weighted/` | SE weighted buffer hook | IndexedEx | co-located | package |
| `…/standardExchange/orbital/` | SE orbital buffer hook | IndexedEx | co-located | package |
| `…/standardExchange/stable/quad/{curve,balancer}/` | SE quad-stable buffer hooks | IndexedEx | co-located | package |
| `…/stable/quad/{curve,balancer}/` | Quad stable swap hooks | IndexedEx | co-located | package |
| `…/weighted/`, `…/orbital/` | Weighted / orbital swap hooks | IndexedEx | co-located | package |

## Protocols (IndexedEx product adapters)

| path | purpose | owner | PRD | test root |
|------|---------|-------|-----|-----------|
| `contracts/protocols/dexes/balancer/v3/pools/**` | Buffer / multi-vault Balancer pool packages | IndexedEx | co-located pool PRDs | `test/foundry/spec/protocols/dexes/balancer/...` |
| `contracts/protocols/dexes/uniswap/v3/` | Uni V3 SE vault product | IndexedEx | `UNISWAP_V3_STANDARD_EXCHANGE_VAULT_PRD.md` | TestBases under `contracts/test/bases/` |
| `contracts/protocols/dexes/uniswap/v4/` | Uni V4 SE local liquid buffer | IndexedEx | V4 SE PRD | — |
| `contracts/protocols/staking/{lido,etherfi,rocket-pool}/` | LST Standard Exchange vaults | IndexedEx | co-located staking PRDs | `TestBase_*StandardExchange.sol` |
| `contracts/protocols/lending/**` | Lending-related IX adapters (e.g. Aave loops/Stata) | IndexedEx | — | `TestBase_Aave*`, `TestBase_ERC4626MorphoHermetic` |

## Routers

| path | purpose | owner | PRD | test root |
|------|---------|-------|-----|-----------|
| `contracts/routers/balancerV3-uniswapV4/` | Balancer V3 ↔ Uniswap V4 coordinator router | IndexedEx | `BALANCER_V3_UNISWAP_V4_COORDINATOR_ROUTER_PRD.md` | `TestBase_BalancerV3UniswapV4CoordinatorRouter.sol` |

## Tests

| path | purpose | owner | PRD | test root |
|------|---------|-------|-----|-----------|
| `contracts/test/IndexedexTest.sol` | Gold TestBase over CraneTest | IndexedEx | agent law | self |
| `contracts/test/bases/` | Protocol/vault gold TestBases | IndexedEx | — | self |
| `test/foundry/` | Spec / integration / fork layout | IndexedEx | — | self |
| `test/foundry/debug/`, `fork/`, `spec/` | Debug, fork, behavioral specs | IndexedEx | — | self |

## Scripts & frontend

| path | purpose | owner | PRD | test root |
|------|---------|-------|-----|-----------|
| `scripts/install-cartographer.sh` | PATH wrapper for cartographer | IndexedEx | this program PRD | manual verify from `/tmp` |
| `scripts/sync-crane-skills.sh` | Mirror Crane skills into IX trees | IndexedEx | Claude.md | — |
| `scripts/sync-bankr-skills.sh` | Sync Bankr to **parent** workspace only | IndexedEx | Claude.md | — |
| `scripts/foundry/`, `scripts/shell/`, `scripts/node/` | Deploy/orchestration & tooling | IndexedEx | deploy docs | — |
| `frontend/` | Next apps, redesign plans | IndexedEx | `frontend/ROADMAP.md` + multi-app PRDs | UI checklists |
| `frontend/apps/` | App monorepo packages | IndexedEx | multi-app PRD | — |

## Docs & research

| path | purpose | owner | PRD | test root |
|------|---------|-------|-----|-----------|
| `docs/agent/` | Agent law, navigation, inventories | IndexedEx | — | — |
| `docs/detf/` | Shared DETF programs | IndexedEx | compound/expansion PRDs | — |
| `research/scenarios/**` | Campaign / research PRDs | IndexedEx | co-located | — |
| `.cartographer/` | Committed code graph | IndexedEx | — | `cartographer verify --fresh` |

## Libs

| path | purpose | owner | PRD | test root |
|------|---------|-------|-----|-----------|
| `lib/crane/` | Crane framework submodule (canonical inventory inside Crane) | Crane | Crane docs | Crane tests |
| Other `lib/*` | Foundry/deps / vendored (pointer-level) | external | — | — |
| Bankr skill catalogs | **Parent workspace only** — not installed under IndexedEx skill trees | parent | — | — |

---

## Historical labels

Empty or legacy directories may exist; they are **not** extension-forbidden. Prefer active packages listed above for new work.
