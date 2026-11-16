# Incident themes → Crane catalog (bridge)

**Contents**

- Purpose
- Theme map
- Boundary vs A–K
- Consumer monorepo

## Purpose

Thin map from recurring **real-world DeFi loss themes** to Crane adversarial catalog IDs. Use when threat-modeling; do **not** treat historical fork PoCs as the ship gate.

Pass criteria remain: exploit **blocked** on production SUT, or intentional economic risk with hard safety invariants. Never green tests that only assert attacker profit.

## Theme map

| Real-world theme | Catalog IDs | When it applies |
|------------------|-------------|-----------------|
| First deposit / empty vault drain | **A0**, A1 | Residual assets + zero supply; share inflation |
| Donation / inflation of `totalAssets` | **A**, **K** | Idle transfer without mint path; stale snapshot |
| Spot / oracle manipulation | **B**, **L3** | Mint/burn priced from AMM reserves or spot |
| Pair skim / FoT surplus / reserve desync | **L1**, **L2** | Product holds LP or prices from pair balances |
| Surplus-refund / residual reclaim (`balance − floor` to caller) | **E6**, **L1**, **F5** | Any refund, resize, migrate, or rent-settle path that uses raw balance not caller liability |
| Permissionless structural op that moves inventory | **F5**, **L1** | Public resize/migrate/reclaim without authority when account holds surplus |
| Internal books (`liquidity` field) vs actual balance for transfers | **K**, **E** | Transfer amount from balance not books; books never gate extract |
| Reentrancy | **C** | External call mid value path |
| Unprotected admin / free cut | **F** | diamondCut, init, onlyOwner money paths; value-settling structural ops |
| Arbitrary call + allowance | **M1**, **M3** | Routers/helpers with open approvals |
| Trusted swap target without validation | **M2** | Issuance / exchange helpers |
| Quote vs settle TOCTOU / malicious hook | **N1**, **N2** | Multi-step issue/bond with callbacks |
| Broken permit / ecrecover / replay | **O1–O3**, **I5** | Permit, Permit2, EIP-712 |
| Trust-flag free mint (`pretransferred`) | **I1–I3** | Pull-or-credit flags |
| Missing diamond selectors | **J1–J3** | New Facet / DFPkg |

## Boundary vs A–K

- **A** vs **A0:** donation without mint vs empty-supply residual drain  
- **I** vs **A:** claimed transfer vs silent donation  
- **K** vs **L:** internal snapshot vs external AMM books  
- **B** vs **L3:** economic skew under gates vs desynced reserve oracle trust  
- **C** vs **N:** reentrancy lock vs mid-flow unit change without nested reentry  
- **F** vs **M:** product access vs middleware/call forwarding  

Do **not** renumber A–K.

## Consumer monorepo

In IndexedEx (and similar), full DeFiHackLabs path index + secure-dev checklist live in:

`skill:defi-incident-patterns` (IndexedEx-local; corpus under `lib/DeFiHackLabs` — **reference only**).

Hermetic production-first tests: this skill + consumer `indexedex-adversarial-testing`.
