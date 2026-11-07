# Clarified initial and ongoing liquidity repair

The user clarified that initial liquidity supplies every required leg,
using either SE shares or pairToken for each SE-backed leg, not both
internal components. Ongoing single-leg deposits must remain supported.
The earlier prohibition on paid cross-leg preparation was the agent's
overinterpretation, not an owner lock. See the superseding section in
`13-preintake-decision.md`.

Tasks 7-12 and 13 are reopened. Earlier green receipts remain historical
proof of their source state, not acceptance of the rejected interpretation.
No new complete-basket DETF public API is being introduced.

## CP first implementation and runtime observation

`ClaimLib` now prices a paid preparatory trade using the existing CP curve
and swap fee. Raw input purchases a share/local basket in kind; pair/share
input buys raw inventory and retains the sold native asset in the pool.
The remaining caller contribution is accepted against the post-trade
component book. LP minting still uses common native-component fractions,
not provider-valued issuance.

`23-cp-paid-single-input.log` compiles and executes the unchanged DETF mint,
donation and dust suites. Two tests pass and three fail. The formerly
zero-LP mint/donation paths now reach their positive issuance/custody
assertions; the remaining failures are retained pair amounts of
147810844, 101361130 and 12386785 native units respectively.
These residual failures remain open; they were not waived or rewritten
to declare success.

Follow-up `23-cp-detf-and-dust-contract.log` passes all 37 selected cases
across 32 suites, including the original positive DETF mint/donation
assertions. R19 explicitly permits residuals that cannot join; the test
helper now requires both single-input and unbalanced join previews to be
zero and the retained balance to equal its booked reserve. No arbitrary
dust tolerance or successful-money-path expected revert was introduced.
The matrix's nine genuine dust-error regressions were fixed by rejecting
an input that cannot buy a raw native unit before attempting an unnecessary
SE conversion; their existing rejection selectors and custody assertions
were retained.

CP pair-funded genesis now acquires actual SE shares, then redeems five
percent and accounts for actual local proceeds and conversion refunds.
Sequential genesis previews use an existing supported transition quote;
an unavailable projection is not fabricated.
`23-cp-clarified-genesis-exactnet.log` passes both new genesis and exact-net
controls, zero failures/skips.

## Shared acceptance updates

The shared component behavior now requires positive pair-funded genesis
with actual mint/burn/receipt assertions and positive bounded exact-net
funding through paid preparation. These replace only the now-superseded
blanket rejection expectations. Gross/fee/net and budget checks remain.

## Other family tracks

All five other families have source-ready handoffs. Parent inspected their
paid-trade/acceptance boundaries and all 12 production-file LSP checks
reported no errors. CP's stale positive test expectations were also
restored, including an independent post-trade native ownership oracle.
Native SY consumers again require actual positive single-leg deposits and
exact-net joins; successful execution is not replaced by rejection.

`23-clarified-family-integration.log` is running with all seven family
directories, FullSpread regressions and five native SY consumer files.
No child ran a build, test or artifact writer. No handoff is counted as a
runtime pass.

No deployment, migration, destructive Git operation or commit was performed.
