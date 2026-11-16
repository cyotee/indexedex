# Theme → Crane / IndexedEx catalog map

**Contents**

- Multi-label theme table
- Boundary rules (no double-count)
- IndexedEx SE / DETF applicability
- Priority reminder

Paths below are relative to monorepo root under `lib/DeFiHackLabs/`.

## Multi-label theme table

| Real-world theme (HackLabs / academy) | Catalog IDs | Typical hermetic pass |
|---------------------------------------|-------------|------------------------|
| First deposit / empty vault residual drain | **A0**, A1 | Dead shares / init gate; first minter cannot claim unaccounted inventory |
| Donation without mint; share inflation | **A1–A3**, **K1** | No free product mint; next depositor not credited prior donation |
| Spot / oracle / NAV manipulation | **B1**, **B3**, **L3** | No free lunch or bounded seigniorage + safety invariants |
| Pair skim / untracked surplus | **L1** | Books match balances; no free extract of surplus |
| Surplus-refund / residual reclaim (`balance − floor` to caller) | **E6**, **L1**, **F5** | Refund ≤ this-call overpay / tracked credit; no free protocol inventory |
| Permissionless structural op that settles inventory (migrate/resize/reclaim) | **F5**, **L1** | Auth-gated or cannot refund untracked surplus |
| Internal books vs actual balance for extract/migrate | **K**, **E** | Consistent books; no silent free extract |
| Fee-on-transfer / deflationary pair | **L2**, **I4** | Credit ≤ actualIn; NAV not phantom-inflated |
| Burn-from-pair / reserve skew as price | **L3**, **B** | Spot path gated by deadband / policy |
| Reentrancy (single / cross-fn / cross-contract) | **C1–C3** | Nested `IsLocked` (or equivalent) |
| Claim / NFT authority abuse | **D2–D6** | No principal without claim; no double redeem |
| Round-trip / residual / deadline | **E1**, **E5**, **H2–H3** | Residual free inventory 0; atomic fail |
| Access control / leftover initialize | **F2–F3** | EOA cannot cut/mint privileged paths |
| Nested composition | **G1** | Outer does not brick inner |
| Arbitrary call forwarder + allowance | **M1**, **M3** | No user `target+data` with held allowances |
| Unvalidated swap / multicall target | **M2** | Allowlist + measured amountOut |
| Quote–settle TOCTOU / malicious pre-issue hook | **N1**, **N2** | Mid-flow unit change cannot inflate credit |
| Broken permit / ecrecover / replay | **O1–O3**, **I5** | Invalid/zero/replay reverts |
| Trust-flag `pretransferred` free mint | **I1–I3** | No credit without measured delta |
| Missing facet / proxy selectors | **J1–J3** | Target → facetFuncs → cuts → loupe → proxy call |
| Reward self-deal / recycle | **D**, product-specific | No permissionless self-funded reward drain |
| Bridge / proof / AA (4337, 7702) | Often out of SE/DETF core | Document defer if not on product surface |

## Boundary rules (do not renumber A–K)

| Pair | Distinction |
|------|-------------|
| **A** vs **A0** | Silent donation vs residual assets at zero supply |
| **A** vs **I** | Assets arrived without claim vs caller *claims* transfer |
| **K** vs **L** | Internal snapshot/books vs external AMM pair balance≠reserve |
| **B** vs **L3** | Economic skew under mint/burn gates vs desynced reserve used as oracle |
| **C** vs **N** | Reentrancy into locked entry vs TOCTOU without same-lock nested call |
| **F** vs **M** | Product access control vs middleware/call-forwarding with allowances |
| **I5** vs **O** | Delivered amount vs signature validity/domain/replay |
| **E6** vs **L1** | Product refund math (caller overpay) vs untracked surplus extract (any reclaim/skim) |
| **F5** vs **L1** | Missing auth on structural settle vs the surplus extract itself |

## IndexedEx SE / DETF applicability

| ID | Standard Exchange | Multi-vault / Single SE DETF | Notes |
|----|-------------------|------------------------------|-------|
| A0 | **P0** | **P0** | Residual inventory before live / zero shares |
| A1, A3 | P0 | P0 | Donate shares / BPT |
| B1, B3 | N/A or weak | P0 if priced | Synthetic thresholds |
| C* | P0 deposit/withdraw | P0 mint/bond/redeem | Hostile share as leg when product accepts |
| D* | weak | P0 claim/NFT | DETF sell→claim |
| E1, E5, H* | P0 | P0 | Conservation + atomic fail |
| I1–I3 | **P0** if pretransfer | **P0** if pretransfer | Mandatory when flag exists |
| J1–J3 | **P0** every Facet/DFPkg | **P0** | Surface completeness |
| K1 | P0 | P0 | Donation then deposit |
| L1–L3 | P0 if prices from pair / holds LP | P0 if AMM-priced mint/burn | FoT = P0 only if claimed support |
| M* | P0 if router/helper | P0 if helpers | Often N/A on pure vault diamond |
| N* | rare | P0 if multi-step + hooks | Bond/issue with callbacks |
| O* | P0 if permit | P0 if Permit2/sig | Else defer NatSpec |

## Priority reminder

Ship gate details: Crane `crane-adversarial-testing` + `references/implementation-test-dod.md`.

Hermetic templates: `hermetic-test-templates.md`. Curated citations: `curated-incidents.md`.
