---
name: defi-incident-patterns
description: >-
  Maps real DeFiHackLabs incident patterns to Crane/IndexedEx adversarial catalog
  IDs and secure-development checklists. Use when the user asks about "DeFiHackLabs",
  "historical DeFi hacks", "incident-driven security", "what hacks teach us",
  "secure vault checklist", "oracle manipulation patterns", "skim attack",
  "first deposit inflation", "arbitrary call allowance drain", "TOCTOU issuance",
  "surplus refund", "balance minus floor", "permissionless reclaim", "structural resize",
  or wants to improve adversarial tests from past exploits. Do not use as a guide
  to run profitable mainnet exploits; for writing hermetic abuse tests prefer
  crane-adversarial-testing and indexedex-adversarial-testing.
license: MIT
---

# DeFi incident patterns → secure build & adversarial tests

Turn **historical DeFi loss themes** (SunWeb3Sec DeFiHackLabs corpus) into catalog IDs, secure-dev checks, and **hermetic production-first** abuse tests.

## Hard boundary

| This skill does | This skill does **not** |
|-----------------|-------------------------|
| Map root causes → Crane catalog **A–K + A0 + L/M/N/O** | Make profitable fork PoCs the definition of done |
| Cite curated paths under `lib/DeFiHackLabs` for study | Compile or run HackLabs into IndexedEx `forge test` |
| Drive secure-dev checklists while writing facets/vaults/routers | Instruct offensive use against live/unowned systems |
| Point agents to hermetic adversarial templates | Replace `crane-adversarial-testing` method law |

**Pass criteria for tests remain:** exploit **blocked** on production SUT, or intentional economic risk with hard safety invariants. Never greenwash with `assertGt(attackerProfit, 0)` as security coverage.

## When to load which skill

| Need | Skill |
|------|--------|
| Write/scaffold adversarial Foundry suites (method, harnesses, ship gate) | `crane-adversarial-testing` |
| DETF / SE / registry product mapping | `indexedex-adversarial-testing` |
| “What did real hacks look like?” / theme → ID / secure checklist | **this skill** |
| Production-first TestBase / no mock SUT | `crane-testing` + `indexedex-testing` |

## Corpus (reference only)

```bash
git submodule update --init lib/DeFiHackLabs
```

- Path: `lib/DeFiHackLabs/` (Foundry fork PoCs under `src/test/YYYY-MM/*_exp.sol`, lessons under `academy/`)
- **Not** an IndexedEx compile dependency; do not add to `foundry.toml` remappings for product tests
- Full curated index: `references/curated-incidents.md` (≥25 verified paths)

## Theme → catalog (summary)

| Theme | Catalog | IndexedEx note |
|-------|---------|----------------|
| Empty vault / first deposit drain | **A0**, A | SE/DETF residual inventory; dead shares / init gate |
| Donation / share inflation | **A**, **K** | Idle SE shares / BPT; no free mint |
| Spot / oracle manip | **B**, **L3** | Mint/burn gates; Aerodrome skew |
| Pair skim / FoT / reserve desync | **L1**, **L2** | FoT underlyings; LP books |
| Surplus-refund / public reclaim (`balance − floor`) | **E6**, **L1**, **F5** | Residual-return, migrate+reclaim, resize-with-refund |
| Reentrancy | **C** | Hostile share; `IsLocked` |
| Arbitrary call + allowance | **M1–M3** | Helpers/routers; Permit2 spenders |
| Quote–settle TOCTOU | **N1–N2** | Multi-step bond/issue if callbacks |
| Broken permit / replay | **O1–O3**, **I5** | Permit2 / EIP-712 paths |
| Trust-flag free mint | **I1–I3** | `pretransferred` (mandatory P0) |
| Missing diamond selectors | **J1–J3** | Facet/DFPkg surface |

Full map: `references/theme-to-catalog.md`. Do **not** renumber A–K.

## Agent workflow

```
1. Identify surface: vault | AMM-priced | router/helper | signature | diamond
2. Map to A–O IDs (theme-to-catalog + crane catalog)
3. Write hermetic tests on production path (CREATE3 / registry DFPkg)
4. Optional: read one curated HackLabs POC for intuition only
5. Ship gate: crane references/implementation-test-dod.md
```

## Navigation

| File | Use |
|------|-----|
| `references/theme-to-catalog.md` | Full multi-label theme → ID + boundaries |
| `references/curated-incidents.md` | ≥25 on-disk paths + root cause + relevance |
| `references/secure-dev-checklist.md` | While writing facets / vaults / routers |
| `references/hermetic-test-templates.md` | NatSpec + `test_<ID>_…` stubs |
| `references/surplus-refund-structural-ops.md` | Cross-VM surplus-refund / public reclaim → E6/L1/F5 |

## Constraints

1. Production-first SUT — no mock vault/manager/registry
2. Credit only observed balance deltas (catalog **I**)
3. DETF role names only on IndexedEx surfaces (`rateAsset`, `pairToken`, …)
4. Deferred IDs need suite NatSpec reasons, not silent omission
5. Wave 4 suite code is optional; skills alone do not replace missing P0 tests

## See also

- `skill:crane-adversarial-testing` — canonical catalog + harnesses + DoD
- `skill:indexedex-adversarial-testing` — SE/DETF applicability
- `skill:crane-testing`, `skill:crane-access`, `skill:indexedex-testing`
- Plan: `docs/agent/DEFI_HACKLABS_SKILLS_IMPLEMENTATION_PLAN.md`
