# Methodology notes — Stage 1 coverage audit

| Field | Value |
|-------|--------|
| RUN_DATE | 2026-08-09 |
| forge / foundry | local workspace |
| ALCHEMY_KEY | present |
| MODE | pilot → full |

## O1 cheap pre-inventory summary

| Signal | Observation (2026-08-09) |
|--------|--------------------------|
| `pretransferred` | **~705** hits across contracts/test; epicenter `BasicVaultCommon._secureTokenTransfer` + SE/DETF/staking call sites |
| `facetFuncs` | Widespread on Facets / DFPkgs (manager, SE Aero/Camelot/UniV2/V4, fee, registry, hooks) |
| `controlFacetFuncs` | Many `*_IFacet.t.sol` declaration tests override control lists |
| MultiVault adversarial | Catalog A–H named tests under `test/.../multi-vault-weighted/adversarial/` (A1–A3, B1/B3, C1–C3, D2–D4, E1/E4/E5, F1–F4, G1, H2–H3) |
| SE adversarial | `test/.../standard-exchange/adversarial/` — Aerodrome + Camelot only (A1, E5, F1, H3, E1); **no Uni V2 adversarial file** |
| `testFuzz_` / `invariant_` | **~272** hits monorepo-wide (many non-money); product L1–L3 still sparse per 2026-07 fuzz report seed |
| `MockStandardExchange` / `vm.mockCall` | **~103** hits — do **not** count mock SUT as money coverage |
| Adversarial dirs | MultiVault, Single SE DETF, ComposedStable, DualLiquidity (fork), SE shared, hooks, balancer pools, staking ports |

## PAT-I-ABS static read (commons)

`contracts/vaults/basic/BasicVaultCommon.sol` `_secureTokenTransfer`:

- `pretransferred=true` → require `balanceOf(this) >= amount` then **`return amountTokenToDeposit`** (absolute claim, not delta).
- `pretransferred=false` → measure `balBefore`, pull, return delta.

NatSpec claims “balance-delta accounting” but pretransfer branch **does not** implement delta. Matches pattern **PAT-I-ABS**.

## Related pull variants

| Path | Behavior sketch |
|------|-----------------|
| `ERC4626Service._secureReserveDeposit` | Delta vs `lastTotalAssets`; strict mismatch revert |
| RocketPool / EtherFi `_securePull` | Pull when !pretransferred; pretransfer checks `actualIn < amountIn` (delta-style partial) |
| Aerodrome SE vault deposit routes | Often `_secureReserveDeposit` for LP reserve |

## Skills bar cited

- `crane-adversarial-testing` A–K + `implementation-test-dod.md`
- `crane-testing` LR-7 surface matrix
- `indexedex-testing` / `indexedex-adversarial-testing`
- Prior seeds: `ADVERSARIAL_VAULT_COVERAGE_GAP_REPORT.md`, `FUZZ_INVARIANT_COVERAGE_GAP_REPORT.md`, `NEGATIVE_TEST_COVERAGE_REPORT.md`
