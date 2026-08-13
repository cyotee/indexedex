# Methodology notes — Stage 1 MODE=full (extends pilot)

| Field | Value |
|-------|--------|
| Date | 2026-08-13 |
| Git SHA | `1e0d7c48` (`1e0d7c48eff8a883837996ae700426ac5397924b`) |
| Mode | **full** (pilot notes below remain historical) |
| ALCHEMY_KEY | present (not required unless a new Critical needs fork proof) |
| via_ir | not used / never recommended |
| Inventory | `docs/agent/INDEXEDEX_CONTENT_INVENTORY.md` + `find contracts -name '*DFPkg*'` + `contracts/` tree |
| Split | `A-se-v3-v4-lending` split into `A-se-univ3`, `A-se-univ4`, `A-se-aave`, `A-se-morpho-erc4626`, `A-se-lst`; hooks split SE-buffer vs swap+factory; extra Uni V4 DETFs + DETF commons + Slipstream + Balancer V3 pools as own areas |
| Research | `research/**` has zero `.sol` — F2b N/A |
| Archive | thin pilot aggregate/backlog → `docs/security/audit/archive/2026-08-13/` |
| SEC-COMMON-001 SHA | HEAD still `1e0d7c48` — repro folder remains valid; no re-run required unless HEAD moves |

---

# Methodology notes — Stage 1 MODE=pilot (historical)

| Field | Value |
|-------|--------|
| Date | 2026-08-13 |
| Git SHA | `1e0d7c48` |
| Mode | pilot |
| ALCHEMY_KEY | present (not required for hermetic PAT-I-ABS re-check) |
| via_ir | not used |

## Commands (orchestrator O1)

`rg --type sol` is unavailable in this environment; used `rg --glob '*.sol'`.

Signals recorded (pilot-relevant):

- `pretransferred` still widespread; commons + MultiVault + many SE/DETF clones.
- `ISecurePullErrors.TransferDeltaInsufficient` is the shared short-delivery error.
- `BasicVaultCommon._secureTokenTransfer` at this SHA uses **durable reserve-delta** (`U = B - R`; credit `claimed` iff `claimed <= U`). This is **not** the 2026-08-09 absolute-balance PAT-I-ABS body.
- MultiVault `_pullToken` also reverts `TransferDeltaInsufficient` on short surplus (see `MultiVaultWeightedDetfCommon.sol` ~468–479).
- Catalog-named tests `test_I1_*` / `test_I2_*` / `test_I3_*` exist under claim-token and other suites; area agents must list what exists for **their** SUT.

## Coverage-audit collision map (seed, not truth)

Pilot areas must mark OWNED_ELSEWHERE when the same production touch-set is already a coverage WP:

| Coverage WP | Area | Touch-set |
|-------------|------|-----------|
| WP-I-COMMON-001 / TCA-COMMON-001 | A-commons-pull | `BasicVaultCommon.sol`, Aerodrome override |
| WP-I-COMMON-002 / TCA-COMMON-002/003 | A-commons-pull | I1–I3 unit suite |
| WP-I-DETF-MV-001 / TCA-DETF-MV-001/002 | A-detf-multi-vault | MultiVault `_pullToken` / burn |
| WP-I-DETF-MV-002 | A-detf-multi-vault | MultiVault I1–I3 tests |
| WP-J-DETF-MV-001 / TCA-DETF-MV-004 | A-detf-multi-vault | J1–J3 |
| WP-K-DETF-MV-001 | A-detf-multi-vault | K1 |
| WP-I-SE-AC-001 / TCA-SE-AC-002/003 | A-se-amm-v2 | SE I1–I3 tests |
| WP-J-SE-AC-001 | A-se-amm-v2 | SE J |
| WP-ADV-SE-AC-001 | A-se-amm-v2 | SE adversarial expand |
| WP-H-CAM-001 | A-se-amm-v2 | Camelot H |
| WP-E5-AERO-001 | A-se-amm-v2 | Aerodrome deadline |

Gap-closure commits on `main` (historical; **re-verify** at `1e0d7c48`): `bbe501e` claimed WP-I-COMMON-001/002 closed; later commits claimed MultiVault I/J/K closed. Agents must read **current** source, not treat those claims as residual-risk 5 without evidence.

## Stale runtime proof

`docs/testing/coverage-audit/repro/TCA-COMMON-001/` is dated **2026-08-09** and records the **pre-fix** theater test `test_secureTokenTransfer_pretransferred_returnsAmount` PASS. That log does **not** prove the current tree. Orchestrator re-checks at SHA `1e0d7c48` (see `repro/SEC-COMMON-001/` and/or PILOT_EXIT).
