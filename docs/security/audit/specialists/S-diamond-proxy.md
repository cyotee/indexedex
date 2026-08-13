# Security Audit specialist — S-diamond-proxy

| Field | Value |
|-------|--------|
| Date / SHA / status | 2026-08-13 · `1e0d7c48` · **COMPLETE** |
| Inputs | `A-detf-multi-vault`, `A-detf-single-se`, `A-manager-fee-registry` (in-flight), `A-hooks-v4-*`, `A-routers-permit2`, crane-architecture J bar |
| Skill | ethskills-audit proxies + catalog J + storage slots |

## 1. Cross-cut thesis (≤10 lines)

Crane factory **base cuts** for DETF packages are ERC165 + Loupe + ERC8109 + post-hook — **not** DiamondCut/Ownable. MultiVault and Single SE area reports confirm **no leftover cut/owner** on instances (L-SEC-11 clean). Manager **is** supposed to keep `diamondCut` (upgradeable platform). J ship-gate is **uneven**: gold on MultiVault/Single SE/Coordinator/many hooks; **G** on LST, ERC4626, Loop, Slipstream, swap-only hooks. Slot collision: family repos use distinct `keccak256` / ERC-7201 strings (Single SE vs Uni V4 CP cited). **No Critical leftover-cut on DETF.** Highs are TEST J **or** coverage-owned.

## 2. Findings

### 2.1 [SEC-SPEC-030] J gaps on LST / ERC4626 / Loop / Slipstream

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-SPEC-030` |
| **Title** | Finish J1–J3 on remaining SE diamonds |
| **Severity** | **High** |
| **Class** | **TEST** |
| **Confidence** | static-medium |
| **Catalog IDs** | J1–J3 |
| **Pattern IDs** | PAT-J-OMIT, PAT-THEATER-FACET |
| **EVM-audit domain** | proxies |
| **CROPS pillar** | n/a |
| **Incident theme** | missing selector |
| **Products** | LST trio; ERC4626 SE; Aave Loop; Slipstream |
| **Blast radius** | those DFPkgs |
| **Attacker** | n/a (TEST) unless OMIT found |
| **Attack scenario** | Target API not in facetFuncs → proxy has no function |
| **Preconditions** | n/a |
| **Impact** | silent missing money API |
| **Evidence** | area reports SEC-SE-LST-002, SEC-SE-4626-002, SEC-SE-AAVE-003, SEC-SE-SLIP-003 |
| **Recommended TEST** | fold into those WPs |
| **Anti-theater** | J3 **proxy** after registry deploy |
| **Suggested WP-ID** | existing per-area J WPs |
| **Link TCA / prior** | `WP-J-SE-UAB-001` for Loop/UniV4/Aave Stata |
| **Depends / parallel** | parallel per package |

### 2.2 [SEC-SPEC-031] Manager leftover cut is intended

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-SPEC-031` |
| **Title** | Manager diamondCut is platform, not DETF |
| **Severity** | **Info** |
| **Class** | **ACCEPTED_RISK** |
| **Confidence** | confirmed |
| **Catalog IDs** | F |
| **Pattern IDs** | PAT-CROPS-ADMIN |
| **EVM-audit domain** | access-control |
| **CROPS pillar** | S |
| **Products** | IndexedexManager |
| **Evidence** | `IndexedexManagerDFPkg.sol` diamondCutFacet; S-crops-trust |
| **Suggested WP-ID** | none |
| **Link TCA / prior** | `WP-J-MGR-002` |
| **Depends / parallel** | n/a |

## 3. Products implicated (blast)

All diamonds. DETF instances: clean. Manager: owned. SE leftovers: TEST.

## 4. Recommended epic WPs (Wave 0 style)

No Wave-0 J CODE. Wave 1 TEST per package (already stubbed).

## 5. Explicit non-findings (checked, clean)

- MultiVault / Single SE: no DiamondCut facet.
- Hook factory: immutable instances (coverage).
- Distinct repo slot strings on Balancer Single SE vs Uni V4 CP (area).
- Coordinator J1–J3 present.

## 6. Commands / checklists walked

```text
J bar: Target ⊆ facetFuncs ⊆ cuts ⊆ loupe ⊆ PROXY
PAT-SLOT: unique repo strings
read A-detf-single-se leftover-admin notes
rg diamondCut contracts/manager
```
