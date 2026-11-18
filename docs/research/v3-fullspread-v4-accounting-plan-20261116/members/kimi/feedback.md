# Identity

- Member: `kimi`
- Profile: research
- Phase: advisory review
- Requested role: `council-member`
- Requested model: `kimi-coding/k3.1-pro:high`, global route
- Actual Native runtime identity and session ID: not exposed
- Task ID: not exposed; none invented
- Owned artifact: `docs/research/v3-fullspread-v4-accounting-plan-20261116/members/kimi/feedback.md`

# Draft under review

- Draft ID: `draft-v3-fullspread-v4-accounting-plan-20261116-r1`
- Path: `docs/research/v3-fullspread-v4-accounting-plan-20261116/coordinator/draft.md`
- Coordinator-supplied SHA-256: `f8265634984958df9eb1e22716527ae6be06c7b5505ab571ddbe1fa0d2026314`; not recomputed

# Disposition

requested-changes

The draft accurately preserves the locked genesis, accounting, late-import, NFT-burn, new-facet, new-vault-only, and removed-yield-surface decisions. It also accurately records my execution-return widening as a plan choice rather than a PRD mandate. The corrections below address concrete route ambiguities and missing test coverage; they do not reopen the owner locks.

# Concerns

| Draft section | Concrete execution defect or ambiguity | Advised correction |
| --- | --- | --- |
| Step 1, “Booked balances and the floor write,” tests | The assertion that “a direct transfer … is not a later caller's credit” is too absolute and conflicts with Step 4's implementation of V3-ACC-10. A direct transfer must not become reserves or automatic share credit, but an eligible later one-token pretransfer explicitly processes that call's unbooked credit. As written, an author could make all pretransfers unusable and still believe this test requires that result. | Scope the assertion to reserves and automatic/redeemable share credit. Add a paired assertion that a later declared one-token pretransfer may use only its available unbooked credit under V3-ACC-10, while an unrelated route cannot treat that balance as reserve-backed credit. |
| Step 4, “One-token routes, funding, exits, and pass-through,” V3-ACC-19 | The two-word preview description assigns word one only to “net shares, the exit receipt, or zero.” It omits the underlying-to-underlying pass-through case defined in the same step. A literal implementation could return zero for a valid pass-through preview even though execution pays a swap output and `minAmountOut` binds that output. | State explicitly that pass-through preview word one is the planned swap output and word two is the unspent-input refund; reserve the zero first word for a failed or unsupported plan. Add preview/execution equality coverage for a successful pass-through as well as the existing exit-receipt check. |
| Step 2 tests and the Requirement check row for V3-ACC-20 | The draft states post-mint dilution, but its listed tests only check that accrued fees are excluded from a new depositor's share credit. They do not prove that subsequent fee and booked claims use the enlarged post-mint supply, including the 1,000 floor. An implementation using pre-mint supply for later claims, or excluding the floor from claim supply, could pass the named tests while violating V3-ACC-20. The Requirement check's reference to Step 9 does not supply that assertion. | Add a later-mint-then-exit test that independently calculates old-holder fee and booked claims from enlarged post-mint supply, explicitly includes the genesis floor, and checks both the reduced per-share claim and the unchanged absolute booked remainder. Reference that test directly in the V3-ACC-20 requirement row. |
| Steps 2, 9, and 10, sizing tests and gas coverage | Step 2 permits a quote to cross ticks, but no named test or measured route crosses initialized dust ticks. A quoter with an undocumented step cap or a route that only works on an empty tick path could pass the listed happy-path tests yet fail the required fixed 49% entry or opposing-claim exit on a valid pool. | Add entry and opposing-exit cases across adjacent initialized dust ticks, proving fully spent quotes and identical preview/execution sizing without a quote step cap. Include a cold tick-crossing money route and its preview in the gas measurements rather than measuring only a trivial tick path. |
| Step 10, “Gas,” preview list | The retained fail-closed `previewExchangeOut` selector is omitted from the preview measurements even though Step 5 keeps it in the package and Step 10 applies the 5,000,000 ceiling to “each preview.” This leaves one supported preview outside the stated gas gate and drops a measurement my initial plan explicitly included. | Add cold `previewExchangeOut` at no more than 5,000,000 gas, with no warming call. Its zero result and absence of a vault-error revert remain behavior assertions; the gas assertion is additional. |

# What was not adopted from others

- The draft does not require my proposed widening of `importPosition` itself to `(sharesOut, refund0, refund1)`. It requires the PRD-mandated preview widening and actual refunds to `recipient`, and labels execution-return widening a plan choice. I do not request reopening that choice.
- The draft uses a different internal file and test decomposition from my initial response. Those differences are plan choices and are not concerns except where they produce the coverage gaps named above.
- I did not read other members' original responses or feedback in this pass. I make no independent claim about their omissions beyond the draft's own disagreement summary.

# Limits

This advisory reviewed only the named draft, my initial response, and the locked PRD. It did not re-read production code, run tests or builds, recompute the supplied hash, or inspect peer artifacts. This feedback neither replaces the draft nor authorizes implementation. No further review round is requested.
