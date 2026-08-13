# SEC-COMMON-001 — PAT-I-ABS re-check at SHA 1e0d7c48

## Historical finding (TCA-COMMON-001, 2026-08-09)

`BasicVaultCommon._secureTokenTransfer` when `pretransferred=true` used absolute `balanceOf >= amount` and returned the **claimed** amount. Runtime **confirmed** on that tree: theater test `test_secureTokenTransfer_pretransferred_returnsAmount` PASSed while crediting inventory.

Source: `docs/testing/coverage-audit/repro/TCA-COMMON-001/{notes.md,COMMANDS.md,forge.log}`

## Re-check at current HEAD

| Check | Result at `1e0d7c48` |
|-------|----------------------|
| Git SHA | `1e0d7c48` / `1e0d7c48eff8a883837996ae700426ac5397924b` |
| Static CODE | **Closed in helper.** Reserve-delta: `U = B - R`; `claimed > U` → `TransferDeltaInsufficient(claimed, U)`; else credit `claimed`. See `BasicVaultCommon.sol` L75–100. |
| Historical forge.log | **Stale.** Describes pre-fix theater PASS. |
| Current tests | `test_I1_*`, `test_I2_*`, `test_I3_*` in `BasicVaultCommon_TrustFlags.t.sol`; `test_I1_bookedInventory_pretransferred_revertsDelta0` and migrated `test_secureTokenTransfer_pretransferred_returnsAmount` now **expect revert** (I1). |
| Coverage ownership | `TCA-COMMON-001` / `WP-I-COMMON-001` / `WP-I-COMMON-002` — class **OWNED_ELSEWHERE** for Stage 2 `sec_fix_*`. |
| Hermetic forge (this SHA) | **9/9 PASS** — I1/I2/I3 + migrated theater-named test (now expects `TransferDeltaInsufficient`). See `forge.log`. |
| Outcome label | **not reproducible** as a live Critical CODE on this SHA (exploit **blocked**; I1 green). Historical confirmation remains valid for the 2026-08-09 tree. |

## Forge

```text
SHA: 1e0d7c48
Command: forge test --match-path 'test/foundry/spec/vaults/basic/**' --match-test 'test_I1_|test_I2_|test_I3_|test_secureTokenTransfer_pretransferred' -vv
Result: 9 passed; 0 failed (compilation skipped; warm cache)
```

Pass here means **I1 reverts on booked inventory with no inbound transfer** — not free credit.

## Implication for pilot

Do **not** open a new Critical CODE WP on `BasicVaultCommon.sol`. Link OWNED_ELSEWHERE. Residual risk on this helper is TEST/THEATER leftovers or clone-site drift (area agents).
