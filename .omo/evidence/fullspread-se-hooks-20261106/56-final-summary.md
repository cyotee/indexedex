# FullSpread SE-hook implementation - final result

Date: 2026-11-07. Requested implementation and verification complete.
No project commit, deployment, live upgrade or registry migration.

## Final gates

- Plain Solar build: exit 0, `54-final-build.log`.
- Full default suite: **2,660 suites, 28,411 passed, zero failed/skipped,
  exit 0**, `54-final-default.log` and `54-final-gates.log`.
- All **77 affected product artifacts** fit runtime 24,576 and initcode
  49,152 bytes. Largest runtime: 21,570 bytes.
- Global `forge build --use solar --sizes` remains **exit 1** on the same
  13 classified test/vendor artifacts. Exact sizes, source classes and
  baseline limits are in `49-size-classification.md`; this is not a
  green whole-repository size claim.
- Independent gate blockers are closed. Final scoped delta verdict:
  **APPROVE**, high confidence, `55-final-delta-gate-review.md`.

Commands use the installed nightly Foundry with `--use solar`, and
tests use `--isolate -vv` under the existing default profile. No gas or
size ceiling was raised. `57-source-identity.json` records current
HEAD, tool versions and 333 scoped source/config fingerprints, while
`00-execution-baseline.md` records the already-dirty starting tree.
Fingerprints identify current files, not authorship of every old hunk.

## Delivered behavior

The seven hook families use valid pair membership and implicit SE-share
processing without an `asset()` dependency. The six LP families maintain
separate actual native component books and caller-owned conversion
receipts/refunds. Acceptance uses the common native mint limit and ceil
contributions; withdrawals use floor component claims. Backed gross LP
splits into depositor net and protocol LP, without growth issuance. H1
remains a conversion hop, not an LP product.

The user's clarification is preserved: every required genesis leg accepts
pair tokens **or** SE shares. Acquired/preowned shares fund the actual
five-percent redemption and retained-share seed; the locked floor remains
separate. Ongoing single-leg deposits use caller-funded paid preparation
and then component-based acceptance against the resulting book.

DETF bootstrap, mint/bond/donation/burn, Native SY and direct consumers
retain their required positive paths. Three separately advertised live
native-component hook routes let DETF reuse mixed refunds without
repeated SE consolidation. All four formerly failing burn/close calls
now pass their unchanged 30,000,000-gas forwarded limits. These additions
do not change the DETF public funding API or old join semantics.

The gate review found sequential views reusing live SE state after
simulated conversions. Dual, Orbital and Balancer now carry unknown-state
flags through dependent reads, including Balancer's allocation-to-remaining
book alias. Unsupported sequential views reject explicitly; ordinary
one-conversion component quotes and tested actual execution remain
positive. The two review/fix stages and real-proxy controls are recorded
in `51-review-remediation.md`, receipts 51/53 and the final gate report.

## Matrix, original failures and acceptance

All **36 original failing identities** match exact PASS methods in the
final receipt. All **48 acceptance IDs** remain distinct: **42 active
rows / 103 named controls matched to PASS**, five withdrawn rows and one
reporting boundary. No withdrawn requirement is restored as a passing
test. Broader assertions in the full suites supplement this named index.

Nine standalone FullSpread configurations contribute **179 passes**;
nine inherited configurations contribute **194**, for **373 subset
cases** within the default total, not additional tests to add to it.

| Standalone configuration | Passes | Primary cold transaction gas |
|---|---:|---:|
| balancer-quad | 18 | 873,097 |
| curve-quad | 20 | 939,109 |
| dual | 26 | 1,080,835 |
| orbital | 21 | 1,202,215 |
| single-cp | 22 | 821,133 |
| single-noncp | 16 | 647,308 |
| weighted | 18 | 856,219 |
| weighted N3 | 19 | 978,027 |
| balancer-quad N5 | 19 | 1,070,128 |

All **36 cold composed routes** pass the unchanged **5,000,000 preview /
12,000,000 transaction** ceilings. Final maxima are **556,371 preview**
and **1,448,998 transaction gas**. Both provider targets and mint/redemption
directions execute; setup is excluded. Whole test gas is not substituted
for one measured call.

Only the affected current V4 audit records and R10.3 additions were
refreshed. Parsed preservation checks confirm all **196 non-V4 rows**,
including **seven V3 rows**, all **107 other acceptance items**, historical
finding records and the historical independentReview object are unchanged.
Matrix totals reconcile: **205 rows; 197 COMPATIBLE, seven DEPRECATED,
one INCOMPATIBLE, zero BLOCKED**. The complete machine-readable records
are under `docs/audits/apex-2026-09-17-evidence/`.

## Explicit limits

Direct FullSpread inverse operations remain unavailable. Sequential views
that require unavailable projection fail closed. A requested share-only
exit does not silently become mixed output when its conversion refunds
input or a disabled mint is prohibited. Disjoint-backing success is not
a same-backing-pool sequential safety claim. No FullSpread provider or
projection interface was fabricated. See `17-capabilities.md`.

The global test/vendor size exceptions remain unresolved outside the
delivered product-size result. No pristine pre-task size baseline is
claimed. JSON parsing and preservation checks pass; JSON LSP could not
run because Biome is not installed. Compiler warnings remain visible.

Final plan verification: `F1-compliance.md`, `F2-review.md`,
`F3-runtime.md`, `F4-fidelity.md`. Earlier rejected experiments,
failed gates and pre-clarification reports are historical evidence, not
current blockers or release passes.
