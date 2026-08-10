# Scope partition — Test Coverage Audit Stage 1

| Field | Value |
|-------|--------|
| RUN_DATE | 2026-08-09 |
| MODE | **full** (pilot exit green 2026-08-09; OBJECTIVE authorized full) |
| REPORT_ROOT | `docs/testing/coverage-audit` |
| PRD | `docs/testing/TEST_COVERAGE_AUDIT_PRD.md` |
| Execute plan | `docs/testing/TEST_COVERAGE_AUDIT_EXECUTE_PLAN.md` |
| ALCHEMY_KEY | present (env) |
| Locks cited | L-TCA-1…8 |

## Excluded paths (default)

- `frontend/**`, `broadcast/**`, `out/**`, `cache/**`
- Pure marketing docs
- Deep vendored `lib/**` upstream (except Crane test patterns / SUT call-ins)
- Godot / game skills noise

## Pilot areas (MODE=pilot) — mandatory first (L-TCA-1)

| Area ID | Production allowlist | Test allowlist (primary) | OUT_FILE | Focus |
|---------|----------------------|--------------------------|----------|--------|
| `T-basic-protocol-commons` | `contracts/vaults/basic/**`, secure-transfer / common vault libs used by SE/DETF (e.g. `BasicVaultCommon.sol` and call sites as **reference**), protocol claim/NFT **transfer** helpers under `contracts/vaults/**` commons as applicable | `test/**` negatives touching pretransfer/secure transfer; `docs/NEGATIVE_TEST_COVERAGE_REPORT.md` as seed | `areas/T-basic-protocol-commons.md` | **PAT-I-ABS epicenter**; K sync; shared CODE WP draft |
| `T-detf-multi-vault` | Multi-vault-weighted DETF under `contracts/vaults/detf/**/multi-vault-weighted/**` | `test/**/multi-vault-weighted/**` incl. `adversarial/` | `areas/T-detf-multi-vault.md` | Gold baseline; theater; I/J/K presence or explicit defer |
| `T-se-aerodrome-camelot-univ2` | Aerodrome + Camelot + Uni V2 SE vault packages under `contracts/protocols/dexes/{aerodrome,camelot,uniswap/v2}/**` | Matching SE TestBases + `test/**` for those protocols + `test/**/standard-exchange/adversarial/**` | `areas/T-se-aerodrome-camelot-univ2.md` | Routes, pretransfer, I1–I3, J |

## Full areas (MODE=full) — after pilot exit

| Area ID | Production allowlist | Test roots | OUT_FILE | Wave |
|---------|----------------------|------------|----------|------|
| `T-detf-single-se` | Single SE DETF packages under `contracts/vaults/detf/**/standardExchange/single/**` (+ Uni V4 SE DETF peers as owned) | `test/**/standardExchange/single/**` | `areas/T-detf-single-se.md` | F1 |
| `T-detf-composed-stable` | Composed stable + mixed buffer DETF | `test/**/stable/**`, `mixedBuffer/**` | `areas/T-detf-composed-stable.md` | F1 |
| `T-detf-single-vault-seigniorage` | SingleVault + Seigniorage DETF (if present) or nearest bond/NFT seigniorage surfaces | matching tests | `areas/T-detf-single-vault-seigniorage.md` | F1 |
| `T-detf-dual-liquidity` | DualLiquidity cross-version | fork + hermetic dual-liquidity paths | `areas/T-detf-dual-liquidity.md` | F1 |
| `T-se-univ4-aave-balancer` | Uni V4 SE, Aave Stata SE, Balancer SE/routers | matching | `areas/T-se-univ4-aave-balancer.md` | F2 |
| `T-hooks-v4` | `contracts/hooks/**` | hook tests | `areas/T-hooks-v4.md` | F2 |
| `T-manager-fee-registry` | `contracts/manager/**`, fee, oracles, vault registry | matching | `areas/T-manager-fee-registry.md` | F2 |
| `T-routers-permit2` | `contracts/routers/**` + Permit2 paths | matching | `areas/T-routers-permit2.md` | F2 |

**Optional (not required for DoD):** `T-slipstream-buffer`, `T-research-contracts`.

## Ownership rules

- Shared commons (`BasicVaultCommon`, secure pull) owned by `T-basic-protocol-commons`; other areas **reference** only.
- Tests may be cited across areas; production SUT package owns the area.
- Pilot area reports are **reused** in full aggregate (re-open only if inventory finds missing products).

## Parallelism

| Phase | Concurrent agents |
|-------|-------------------|
| Pilot | 3 |
| Full F1 | up to 4 |
| Full F2 | up to 4 |
