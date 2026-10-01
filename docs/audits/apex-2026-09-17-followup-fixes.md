# APEX remediation follow-up fixes

This records the local corrections requested during the independent completion review.
The existing working-tree remediation is preserved. No commits, deployments or live
transactions are part of this work.

## Implementation

- Morpho exact-input and exact-output deposits price shares against backing before
  the credited pretransfer. Exact-output excludes the bounded input budget, including
  the amount refunded.
- FullSpread V3 and V4 exact-output mint uses the same pre-deposit pricing basis for
  pull funding and atomic pretransfer funding.
- Orbital, dual constant-product and single constant-product hooks distinguish raw,
  identity and non-identity buffered custody when computing local credit. Native
  custody books remain separate from rate-adjusted valuation. This supersedes the
  implementation heuristic in plan D50; D15's bounded credit/refund policy remains.
- Weighted and both quad hook invariant campaigns check actual join/exit token and
  share deltas. ERC-4626 and Aave loop campaigns execute nonzero exits. Unexpected
  failures fail the campaigns; setup cannot satisfy their campaign success counters.
- Historical inventory tests use positive declared credit with no delivery, inspect
  both token legs and retain unavailable/rejected classifications. They record facet
  runtime hashes and installed selectors rather than relying on proxy code hashes.
- The size checker includes newly introduced deployment artifacts and supports fresh
  source, artifact and log manifests while preserving historical evidence.
- The negative-test scanner recognizes multiline empty expectations and ignores
  comments and string literals. The matrix generator requires all ten controls,
  every source-declared matrix suite, and passing named incompatibility controls.
  Stale F8/F9 classifications are reconciled with the implemented D61/D62 changes.

## Validation

The pre-change build passed. A fresh pre-change full hermetic run passed **34,812
tests across 3,041 suites**. The first follow-up build and full hermetic run passed
**34,836 tests across 3,044 suites**, with no failures or skips. Production-source
and artifact hashes were unchanged before and after the run. The expanded size
check covers **571 artifacts**, with none missing or oversized. The complete matrix
contains **195 compatible, one incompatible and seven deprecated rows**.

These results are recorded under
[`apex-2026-09-17-evidence/followup-review`](apex-2026-09-17-evidence/followup-review):
`release-build.log`, `release-hermetic.log`, `identity-before-release.json`,
`identity-after-release.json`, `selector-size-after-release.json` and
`phase1-hook-se-matrix.json`. This is an intermediate verified snapshot. Additional
staking/DETF corrections and expanded stateful campaigns are undergoing validation;
the first follow-up run does not certify those later changes.

The same seven new pricing assertions fail against the saved pre-fix accounting
sources, while six inherited controls pass. Nine hook regressions fail against
the separately identified reconstructed pre-fix hook sources. Their source copies,
hashes and rebuilt-artifact logs are preserved in `accounting-red*` and `hook-red/`.
The historical read-only fork passes six tests at the pinned block and reproduces
the primary reported instance; its sanitized log is `historical.log`.

Tests added for prepaid pricing compare the same-state pull operation, the prior
preview, actual minted shares and exact refund. Hook tests cover funded buffered
input at and above the rated reserve, plus raw and identity custody at non-unit
rates. Existing route tests remain enabled.

## Second follow-up integration

Applied staking SE pricing corrections across Lido, EtherFi and Rocket Pool, including
Lido native-unit inverse rounding and wrapping preview parity. Applied bounded-credit
refund corrections to MixedBuffer, MultiVaultWeighted and Composed DETF exact-output
routes. Public selectors are unchanged by these corrections.

Replaced unqualified negative expectations with exact errors, corrected setup so the
intended checks execute, and retained funded controls. The hook subset passes all
25 corrected instances across 20 suites. Integrated stronger campaigns for the seven
hooks, six Balancer buffer packages, standalone Balancer pool actions, both FullSpread
versions, staking/Morpho and the three constant-product exchanges.

Independent isolated validation is retained in `followup-review/`: seven hook
campaigns, seven buffer/standalone campaigns, two FullSpread campaigns, four
staking/Morpho campaigns and three constant-product campaigns each pass 256 runs
at depth 64 with zero outer reverts. Each group also passes its deterministic
lifecycles. Source manifests identify the exact validated files. All seven new
DETF refund regressions pass after failing against the preserved original sources.

The custody campaign passes 256 runs at depth 64 with zero outer reverts. The five
DETF campaigns also pass that configuration, with 81,920 total calls. Their stronger
fixtures exercise real reserve-pool trades, funded rewards and the supported SY
routes. The integrated strict-negative gate passes 939 tests across 279 suites.

The final native staking corrections pass all 88 Lido and 100 EtherFi family tests,
including their stateful campaigns and four targeted fuzz properties at 10,000 or
more cases each. These use actual share conversions and measured native delivery.
The ERC-4626 correction passes all 151 family tests, including the saved nineteen-call
sequence, four direct pricing regressions and its 256-by-64 campaign. The identical
five new regressions fail against the preserved original targets. The Stata and
standalone Balancer supplements pass their isolated campaigns.

The latest integrated matrix/regression run passed 2,189 tests and found one inherited
UniV4 DETF test whose replacement fixture had exhausted its user's funding and
allowance during bootstrap. The fixture now restores the base test's funding and
approvals; the inherited assertion is unchanged. Aave Loop's saved five-call
regression passes after native debt-budget correction. Its full family passes 314
tests across 102 suites, including the strict 256-by-64 campaign with zero outer
reverts. Both FullSpread campaigns explicitly pin 256 runs and depth 64 in their
test configuration.

The intermediate snapshots above are superseded for release purposes by the final verification below.

## Final integrated verification

The local remediation plan is complete. The fresh build passes, and the final hermetic run passes **34,909 tests across 3,053 suites**, with zero failures or skips. All **37 targeted fuzz tests** pass at 10,000 or more cases each with seed `0x20260917`. All **33 canonical stateful campaigns** pass 256 runs at depth 64, with **540,672 calls** and zero outer reverts; their deterministic lifecycles also pass.

The full matrix has **195 compatible, one incompatible and seven deprecated rows**, with all required controls executed. The final size/selector check covers **571 artifacts**, with none missing or oversized; existing selector differences remain classified under the recorded owner rulings. Source and runtime hashes are identical before and after the release tests. The strict negative-expectation scan and whitespace checks pass; the evidence tooling has 15 passing unit tests.

The final commands, counts, source/runtime identities and log hashes are linked from [`independent-completion.json`](apex-2026-09-17-evidence/followup-review/independent-completion.json). The 108-criterion acceptance ledger, finding matrix and campaign inventory now reference this release. The six passing historical fork tests remain separate evidence at block 64025200. Changes are local and uncommitted; no deployment, migration or live transaction was performed.
