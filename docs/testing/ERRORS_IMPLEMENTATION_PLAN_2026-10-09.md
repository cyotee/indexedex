# Confirmed-error implementation plan — 2026-10-09

This plan implements the first bounded pass from [the diagnosis](ERRORS_DIAGNOSIS_2026-10-09.md). A confirmed symptom is insufficient: a task enters this pass only when its intended behavior and a concrete corrective change are established. Existing unrelated workspace changes are preserved. No Balancer-hosted DETF changes are included.

## Locked behavior

- Whole-supply rate valuation remains the intended policy; sampled pricing is not restored to make consumers pass.
- Undeployable deposits retain an attributed claim, receive representable shares, and use local balances first on same-token withdrawals. Eligible reserves are fully deployed unless a documented sleeve applies.
- Fee-on-transfer inputs are rejected. Permit2 narrowing cannot change the amount credited.
- Zero previews and execution failures are tested separately. Guard, custody, rollback, and exact quote/execution assertions remain meaningful.
- Owner follow-up: reject deposits below one vault share or one native BPT with an explicit minimum-deposit error. Reject genuinely unattainable alignment at the current price and amount; preserve feasible plans and exact quote/execution parity.

## Implementation sequence

| Step | Groups / scope | Concrete change | Acceptance evidence | Status |
|---|---|---|---|---|
| 1 | R09, R10 | Check Permit2's uint160 bound before transfer; require exact received balance delta on all affected funding branches; share a local implementation within each existing component | Existing positive controls pass; oversized Permit2 calls and taxed direct/Permit2/reward inputs reject with specific errors and unchanged books/custody | Complete: fixed and validated |
| 2 | R11 | Return every owner share whose redemption fits cash; compute the greatest executable share cap using the actual floor conversion when cash constrains it | Full-payable-balance recurrence passes; constrained cap and next-share boundary validated | Complete: fixed and validated |
| 3 | R08 | Validate funded/pretransferred share credit before calculating a payout against exhausted custody | Second redemption reports exact insufficient-credit error and cannot alter balances or supply | Complete: fixed and validated |
| 4 | R12 | Project the treasury accrual and index used by Aave supply-cap validation; calculate executable headroom with the protocol's rounding | Non-unit-index cap recurrence passes; cap overflow retained locally under the existing vault policy; boundary/next-unit checks | Complete: fixed and validated |
| 5 | R01 | Replace EOA impersonation in positive internal-balance SY tests with the existing atomic contract caller; preserve prior-share inventory tests | All 25 mapped cases pass; dedicated EOA and unfunded-credit negatives remain intact | Complete: fixed and validated |
| 6 | R02 active; R03 non-rate preview cases | Assert zero or the intended price on the affected previews; preserve malformed exact-output preview reverts, exact execution failures, and no-assets-taken checks | All 14 active R02 cases and diagnosed route-funding preview cases pass | Complete: fixed and validated |
| 7 | R06 | Assert selector membership in the owning extension and installed proxy, using existing facet behavior helpers | Facet API recurrence passes without duplicate selector installation | Complete: fixed and validated |
| 8 | R13, R14 | Use actual fixture capacity/sleeve semantics and a real funded dust transfer followed by the normal Camelot reserve sync; reconcile caller debit, deployment, booked remainder, and shares | Three partial-consumption cases and Camelot unrelated-token isolation pass with non-vacuous controls | Complete: fixed and validated |
| 9 | Validation and diagnosis reconciliation | Run every mapped case for the changed shared behavior, plus focused regressions for production changes; record exact results and remaining failures | Each closed item links to validation evidence; mixed groups are only partially closed | Complete: evidence reconciled |

Use `scripts/forge-artifacts.py test` with every edited production source and selected test roots so concrete runtime artifacts are rebuilt before tests. Keep the default profile, source paths, optimizer, and non-viaIR settings. Do not delete caches. Diagnostic low invariant counts from the prior investigation are not release-validation settings.

## Change locations and implementation details

### Exact funding: R09 / R10

Edit the weighted SE pull library and its inline target caller, raw weighted liquidity target/common funding, and `TokenStakingTarget._pullStakingToken`. Inspect their caller guards and preserve existing direct-versus-Permit2 routing. Validate observed receipt on both branches; do not introduce fee-on-transfer support. Reuse existing range/error conventions. Convert the two diagnostic Permit2 tests from observing inflated books to expecting the exact rejection and proving rollback. Check the identified Curve Quad and Orbital narrowing variants before deciding whether the same correction applies; do not claim them fixed from a source search alone.

### Limits and credit: R08 / R11 / R12

Edit the existing rebasing vault common implementation, Morpho ERC4626 target, and cross-version Aave executor. For Morpho, avoid a floor/floor round trip and avoid an unconditional ceil that advertises too much liquidity. For Aave, port no new external implementation: mirror the pinned local protocol's next-state treasury/index calculation and exact cap units. If further inspection disproves the diagnosed formula or exposes an unspecified policy, leave that item open and record the evidence rather than inserting a haircut.

### Test contracts: R01 / R02 / R03 / R06

Prefer shared TestBases/behavior helpers so inherited variants receive the same correction. Use `AtomicPretransferCaller` for the contract-only positive path, including the restricted-caller case. Do not relax caller authorization to match a fixture. Keep Balancer DETF files unchanged. For R03, separate the route-funding preview expectations from the rate-context test that depends on R05; do not close the entire group when only the route expectations pass.

### Fixture accounting: R13 / R14

Distinguish full capacity closure, partial executable capacity, and intentional liquidity sleeves. The expected local book change must be independently explained by the fixture's actual consumption, not simply copied from the value returned by the SUT. For Camelot, first demonstrate a nonzero booked remainder from an actual supported operation, then prove an unrelated-token call cannot consume it. If that scenario cannot be constructed without changing intended product behavior, defer that specific fixture instead of deleting its positive prerequisite.

## First-pass research queue (historical)

| Group | What is known | What remains before safe implementation |
|---|---|---|
| R03 rate context / R05 | Sampled rates violate the settled full-supply policy | Select and validate canonical whole-book valuation for vaults that forbid physical full exit, including wrapper/projected-state rounding; then update all dependent rate expectations |
| R04 / R15 | Underlying dust deposits revert; panic matching also differs | Resolve retained-claim accounting for native BPT routes and deposits below one vault-share unit; matcher-only repairs would preserve the wrong economic behavior |
| R07 / R20 | Arbitrary native dust bounds make fixtures stale and skip positively quoted balances | Prove actual residual executability and construct a genuine retention/retry boundary before replacing the cutoff or fixture |
| R17 | Seven runtime components exceed the deployment limit | Review a concrete selector/library partition and delegate/storage/guard effects; a generic instruction to split code is not an implementation design |
| R18 | CP residuals enter an unsupported one-sided proportional join; Orbital dust can quote SE shares but zero hook LP | Validate the alternate complete route and its post-join residual/accounting behavior before changing fallback orchestration; classify remaining family variants |
| R19 | Orbital rounds feasible offered amounts into zero-quote consumed amounts, then executes | Develop and validate consumed-amount/LP planning that preserves protections and budget bounds across native-unit discontinuities |
| R21 / R22 | Coverage failures and positive controls are blocked by residual cleanup | Resolve the production dependencies before claiming security/invariant tests exercise their intended behavior; then make campaign coverage deliberate |
| R02 Balancer DETFs / R16 | Deferred design | Owner-requested Balancer DETF refactor; excluded here |

This boundary does not reopen settled owner decisions or label known production defects acceptable. It separates changes with a concrete local correction from changes whose safe implementation still needs design or execution evidence.

## Completion and report updates

A group is **fixed and validated** only after the relevant original failures and regression checks pass against refreshed artifacts. Source changes without passing validation are **implemented, unverified**. A representative pass alone does not close inherited variants. Preserve the original diagnostic evidence and append status/evidence to the diagnosis; do not rewrite the historical failures as though they never occurred. List newly exposed failures separately and carry them into the next research pass.

## Production validation completed

The final production run passed **95 tests across 13 suites**, including all eight original R08–R12 failures. The first run caught a missed inline SE join pull; routing it through the checked library resolved the remaining failure. Added checks cover taxed raw weighted direct/allowance/signature funding with untaxed controls and rollback, Morpho's constrained redemption boundary, and Aave's exact supply-cap boundary.

Moving signed-batch funding to the existing weighted pull library keeps the raw weighted liquidity facet at **23,971 bytes** (limit 24,576); the library is **3,727 bytes**. Proxy selectors and storage layouts are unchanged. This does not close R17's separate oversized components. Curve Quad and Orbital cast variants remain open caller-limit investigations.

Commands and logs: `.scratch/errors-fixes-2026-10-09/production-final-command.json` and `production-final.log`. The test-correction batch and focused refinements now validate all 48 targeted test-assumption failures. The 13-case refinement run passed all eight inactive-LP variants and both FullSpread families; the final Camelot rerun closes the remaining fixture case.

## Completed first pass

All **56 selected original failures** are fixed and validated. The latest results cover **165 distinct tests across 53 suites**, all passing. The final source/evidence review preserves the existing unrelated workspace changes. No full-repository test pass or resolution of the explicitly deferred groups is claimed.

See [the updated diagnosis](ERRORS_DIAGNOSIS_2026-10-09.md) for per-group closure and the remaining research queue, and [the implementation evidence](ERRORS_IMPLEMENTATION_EVIDENCE_2026-10-09.json) for test identities, commands, source hashes, and the intermediate failures that led to refinements.

## Second pass — authorized owner decisions

Owner follow-up on 2026-10-09 resolves the previously open minimum-deposit and alignment policies. Sub-share and sub-BPT deposits must revert atomically with an informative minimum error. Genuinely unattainable alignment must revert with the alignment error. Ordinary underlying deployment dust still stays attributed and local when the outer vault can issue shares. Balancer-hosted DETFs remain excluded.

Sequence: (1) preflight complete residual routes and select supported join modes, validating shared witnesses before wider variants; (2) whole-supply rate valuation in live/projected/wrapper contexts; (3) explicit minimum boundaries and feasible Orbital consumed-amount planning; (4) runtime partitioning and invariant/security controls; (5) reconcile original identities against passing refreshed-artifact tests. Unexpected failures remain recorded rather than hidden through catch-all handling or weakened assertions.

Status: all 1,505 in-scope original failures passed broad validation; 17 Balancer DETF cases remain deferred. Newly exposed R23 (30 tests) remains unresolved. Additional funding fixes are complete: all ten regressions and 3,738 affected tests pass; all 37 measured runtime components fit EIP-170. Current checklist: [handoff](ERRORS_HANDOFF_2026-10-10.md). Evidence is under `.scratch/errors-second-pass-2026-10-09/`.
