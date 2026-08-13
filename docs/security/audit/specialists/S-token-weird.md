# Security Audit specialist — S-token-weird

| Field | Value |
|-------|--------|
| Date / SHA / status | 2026-08-13 · `1e0d7c48` · **COMPLETE** |
| Inputs | Area reports: commons, SE AMM v2, LST, ERC4626, Aave, hooks SE; coverage token notes |
| Skill | ethskills-audit erc20/erc4626 + token-integration |

## 1. Cross-cut thesis (≤10 lines)

IndexedEx money helpers **mostly credit observed delta** (commons reserve-delta, ERC4626 `_securePull`, LST same-tx delta, hook `_securePull`). That is FoT-safe on `!pretransferred` paths. Residual weird-token risk is **configuration**: PkgArgs that accept raw rebasing stETH, FoT pair tokens, 6-decimal stables, or pause/blacklist USDC as `rateAsset`. LST packages wrap **wstETH / weETH / rETH** (non-rebasing faces) — good. Aave Stata is ERC4626 static aToken — good. No new Critical. Highs are **TEST/NEEDS_OWNER** plus existing E6 (refund ignores token semantics).

## 2. Findings

### 2.1 [SEC-SPEC-010] FoT / rebase / 6-dec / pause not locked in PkgArgs

| Field | Value |
|-------|--------|
| **FINDING_ID** | `SEC-SPEC-010` |
| **Title** | Document or reject weird underlyings in PkgArgs |
| **Severity** | **High** |
| **Class** | **NEEDS_OWNER** |
| **Confidence** | static-medium |
| **Catalog IDs** | L2, I4 |
| **Pattern IDs** | PAT-L-SKIM, PAT-SHARP-FLAG |
| **EVM-audit domain** | erc20 |
| **CROPS pillar** | n/a |
| **Incident theme** | FoT / rebase donation |
| **Products** | All SE/DETF that take arbitrary IERC20 in PkgArgs |
| **Blast radius** | CFG deployer |
| **Attacker** | **CFG** / **HOS** |
| **Attack scenario** | 1. Deployer sets FoT or rebasing token as pair/rateAsset. 2. `!pretransferred` credits delta (OK). 3. `pretransferred` + books that assume 1:1 face break L2. 4. Pause/blacklist freezes exit (CROPS). |
| **Preconditions** | Hostile or paused token allowed at deploy |
| **Impact** | Accounting desync or freeze — not unprivileged extract on official LST/Aave faces |
| **Evidence** | LST helpers assume official wrap tokens; no PkgArgs allowlist found in this hunt |
| **Recommended CODE** | Allowlist decimals=18 + non-rebasing **or** document forbidden set |
| **Recommended TEST** | `test_L2_FoT_credits_actualIn` if FoT allowed; else `test_L2_FoT_forbidden` |
| **Anti-theater** | Real FoT mock as configured token, not mock SUT |
| **Suggested WP-ID** | `WP-SEC-TOKEN-001` |
| **Link TCA / prior** | none |
| **Depends / parallel** | Wave 3 |

### 2.2 Medium [SEC-SPEC-011]

Missing-return ERC20: Crane `BetterSafeERC20` used on most pulls — **F**. USDT-class: Medium TEST if any route uses raw `transfer`.

## 3. Products implicated (blast)

SE AMM v2, LST, Aave Stata, ERC4626/Morpho, Uni V3/V4 SE, hooks (pair tokens), DETF legs.

## 4. Recommended epic WPs (Wave 0 style)

`WP-SEC-TOKEN-001` — Wave 3 NEEDS_OWNER: freeze weird-token policy + one L2 test per family that claims FoT support.

## 5. Explicit non-findings (checked, clean)

- Official wstETH/weETH/rETH / Stata / aToken: no rebase-on-balanceOf face.
- ERC4626 pull FoT-safe on pull path.
- Commons token pull reserve-delta.

## 6. Commands / checklists walked

```text
erc20/erc4626 hunt list: FoT, rebase, missing return, 6/8 dec, blacklist/pause
read LST _securePull; ERC4626 _securePull; Aave Stata In
# no dedicated FoT suite found (L2 G / N/A)
```
