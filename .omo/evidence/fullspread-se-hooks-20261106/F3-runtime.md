# F3 - Real proxy execution and release gates

Date: 2026-11-07. Disposition: requested runtime verification complete.

| Gate | Final result | Receipt |
|---|---|---|
| Plain Solar build | Exit 0 | `54-final-build.log` |
| Full default tests | 2,660 suites; 28,411 passed; zero failed/skipped; exit 0 | `54-final-default.log`, `54-final-gates.log` |
| Affected product sizes | All 77 entries fit runtime/initcode limits; largest runtime 21,570 bytes | `54-final-sizes.log`, `49-size-classification.md` |
| Global size command | Exit 1 on 13 classified test/vendor artifacts; unchanged sizes, not a pristine baseline claim | `49-size-classification.md` |
| Final review delta | APPROVE; prior blocker closed | `55-final-delta-gate-review.md` |

All nine FullSpread configurations execute both member-face mint and
redemption routes through actual registered proxies. All 36 isolated
cold composed routes pass the unchanged 5,000,000 preview and 12,000,000
transaction ceilings. Final maxima are 556,371 and 1,448,998 respectively;
setup is excluded. The four formerly failing DETF burn/close calls pass
their unchanged 30,000,000-gas forwarded limits. Whole test gas is not
misrepresented as one call's gas.

Reentrancy, funding, ownership, disablement, minima and rollback controls
remain executed negatives alongside required positives. Final metadata
controls cover both native selectors on deployed facets and preserve exact
role counts and uniqueness. Temporary uncapped diagnostics and failed
optimization experiments were removed from source, not presented as
release passes.

Solidity diagnostics on final edited source/tests are clean. Audit JSON
syntax and preservation checks pass through the parser. Biome is not
installed, so JSON LSP was unavailable; it was not installed or claimed
clean. Compiler warnings remain visible in the build receipts.

This is local verification of fresh instances. No deployment, live upgrade
or registry migration was performed or authorized.
