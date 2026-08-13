# Security Audit specialist — S-spec-detf

| Field | Value |
|-------|--------|
| Date / SHA / status | 2026-08-13 · `1e0d7c48` · **COMPLETE** |
| Inputs (area reports read) | `A-commons-pull`, `A-detf-multi-vault`, `A-detf-single-se`, `A-se-amm-v2`; partition; `docs/agent/INDEXEDEX_AGENT_LAW.md` DETF; `docs/detf/DETF_Protocol_Compound_And_Supply_Expansion_PRD.md` (spot); family bonding targets + `DETFBondLifecycleLib.sol` |
| Skill | Trail of Bits spec-to-code-compliance; corpus = family PRDs + `docs/detf/*` + INDEXEDEX_AGENT_LAW DETF |

## 1. Cross-cut thesis (≤10 lines)

Agent law is **implemented in shared libs**, not re-copied per family: `DETFBondLifecycleLib._sellPositionToDetfNft` reverts `BondNotMature` when `block.timestamp < unlockTime` — sell→claim is DETF-wide mature-only. Thresholds live in `DETFThresholdPolicy` from `PkgArgs` (not fee oracle). MultiVault + Single SE reports show **no** leftover `diamondCut`/owner on instances (L-SEC-11). Spec drift that *is* CODE is **disable-gated families** (`_requireNotDisabled` on Uni V4 extra + DualLiquidity): law says no admin pause on the diamond; those families re-import manager disable — already `SEC-CROPS-001`. Compound/expansion “must” statements were not fully IR’d line-by-line; no extra undocumented money path found in bonding libs. **No new Critical spec CODE.**

## 2. Findings (same §7.3 schema)

### 2.1 [SEC-SPEC-001] Disable-gated DETF contradicts “no admin pause”

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-SPEC-001` |
| **Title** | Align disable-gated families with unowned/no-pause law or document exception |
| **Severity** | **High** |
| **Class** | **OWNED_ELSEWHERE** |
| **Confidence** | static-high |
| **Catalog IDs** | F, D |
| **Pattern IDs** | PAT-SPEC-DRIFT, PAT-CROPS-ADMIN |
| **EVM-audit domain** | access-control |
| **CROPS pillar** | C + S |
| **Incident theme** | admin pause |
| **Products** | Uni V4 weighted/orbital/quad DETFs (`_requireNotDisabled` on BondingTarget); DualLiquidity; Single SE (S-crops listed) |
| **Blast radius** | disable-gated DETF family |
| **Attacker** | ADM |
| **Attack scenario** | Same as `SEC-CROPS-001`: `setVaultAddressDisabled` freezes bond/claim/exit. |
| **Preconditions** | Manager owner |
| **Impact** | Walkaway fail |
| **Evidence** | `UniswapV4StandardExchangeWeightedDETFBondingTarget.sol:46`; Orbital/Quad same; law: INDEXEDEX_AGENT_LAW “no admin pause surface” |
| **Recommended CODE** | Strip `_requireNotDisabled` from live money paths **or** `NEEDS_OWNER` explicit exception |
| **Recommended TEST** | `test_CROPS_disabled_still_allows_mature_exit` |
| **Anti-theater** | Call redeemClaim/closeBondMature while disabled |
| **Suggested WP-ID** | — |
| **Link TCA / prior** | `SEC-CROPS-001` / `WP-SEC-CROPS-001` |
| **Depends / parallel** | — |

### 2.2 [SEC-SPEC-002] Mature-only sell→claim is implemented (non-finding as CODE)

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-SPEC-002` |
| **Title** | Shared lifecycle enforces BondNotMature |
| **Severity** | **Info** |
| **Class** | **ACCEPTED_RISK** / clean |
| **Confidence** | confirmed |
| **Catalog IDs** | D |
| **Pattern IDs** | PAT-SPEC-DRIFT (checked, absent) |
| **EVM-audit domain** | erc721 |
| **Products** | All families calling `_sellPositionToDetfNft` |
| **Blast radius** | shared lib |
| **Evidence** | `DETFBondLifecycleLib.sol` ~70–73 |
| **Suggested WP-ID** | none |
| **Link TCA / prior** | none |
| **Depends / parallel** | n/a |

## 3. Products implicated (blast)

All true DETFs via `DETFBondLifecycleLib`. Disable-gated subset: Uni V4 extra + DualLiquidity + any Single SE that still calls `_requireNotDisabled`. MultiVault: no disable (pilot).

## 4. Recommended epic WPs (Wave 0 style)

None new. Use `WP-SEC-CROPS-001`. Optional Wave 3 docs WP: document disable as product exception if owner keeps it.

## 5. Explicit non-findings (checked, clean)

- Sell→claim before maturity: **blocked** in shared lib.
- Thresholds from fee oracle: **not** observed; `DETFThresholdPolicy` + PkgArgs.
- Unowned MultiVault / Single SE diamonds: **no** DiamondCut facet (area reports).
- Extra undocumented `exchangeOut` on Balancer Single SE: Out Target is burn helper only (area).
- Compound lib is orchestrated, not a public skim (`DETFProtocolCompoundLib` comments).

## 6. Commands / checklists walked

```text
read INDEXEDEX_AGENT_LAW.md DETF (unowned, thresholds, mature sell)
read DETFBondLifecycleLib.sol _sellPositionToDetfNft
rg _requireNotDisabled *BondingTarget.sol
rg unlockTime DETFBondLifecycleLib.sol
spot docs/detf/ compound PRD headings (not full IR)
# Spec-compliance-checker agent not spawned; static IR of must/never locks only
```
