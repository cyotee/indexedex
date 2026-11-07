# Final implementation gate review

## Goal and authority

Execute all 20 implementation/testing and four final tasks in
`docs/research/se-fullspread-remediation-plan-20261106/IMPLEMENTATION_AND_TEST_PLAN.md`.
The requirements source is the FullSpread PRD named there.

The user's subsequent explicit clarification supersedes the earlier
strict interpretation: initialization requires every required leg,
funded with either pair tokens or SE shares, not both; ongoing
single-leg caller-funded deposits must remain supported. Paid
preparation uses rates only for trades, followed by component-based
issuance against the post-trade book. Do not reopen the resolved
funding-model question or treat the old rejection-only implementation
as accepted behavior.

No commits, deployment, registry migration, destructive Git, provider
semantic change, fabricated projection, weakened gas limit or skipped
positive is authorized. Preserve the dirty starting workspace.

## Review scope

All seven hook families, shared membership/receipt/component helpers,
FullSpread fixtures and acceptance tests, DETF adapters and residual
cleanup, Native SY facades and their direct consumers. The path map is
in the plan. `00-execution-baseline.md` records the already-dirty starting
tree; a diff against HEAD includes pre-existing work and is context,
not proof that every hunk was authored in this task.

This is an uncommitted implementation review, not a PR or branch review.
Read the current working tree without modifying it. Read-only Git
diff/history inspection is allowed with the git-master skill; no tests,
builds or artifact writers may race the parent's serialized validation.

The latest integration addition is documented in
`45-native-component-route.md`. Its shared interface is
`contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol`.
Implementations are in Curve JoinCore/ClaimLib, Weighted LiquidityLib
and Orbital Common/ExitQuoteLib with deployed facet/package metadata.
DETF Common offers mixed native custody before consolidation. The
independent `DetfResidualAssertions.sol` keeps all previous checks and
also rejects a joinable mixed-native remainder.

## Real-surface QA already performed by the parent

All paths below are under this evidence directory. Tests deploy real
registered package/facet proxies and execute their public routes.

| Row | Scenario | Observed evidence |
|---|---|---|
| 1 | Seven-family accounting, FullSpread acceptance, consumers and default compatibility | `49-final-default.log`: 28,401 pass, one stale selector-manifest assertion fails; no money-path failure. That exact assertion is repaired and its complete suite passes in `50-surface-control.log`. The clean full rerun is in progress as `50-default-regression.log`. |
| 2 | Four formerly failing gas-limited burn/close paths | All pass in `46-native-components-integration.log` and `49-final-default.log` with their original 30,000,000-gas forwarded call limits. Whole test gas includes setup/other calls and is not the transaction measurement. |
| 3 | Native mixed-component quote/execution, post-paid ownership, actual receipts/refunds, fee split, live-only and input validation | Family controls in receipt 46; corrected Curve error selector/metadata and weighted independent target-floor witness pass in receipts 47/48. `48-weighted-native-refund-control.log`: 66/66. |
| 4 | Exact installed selectors, interface IDs, immutable package deployment | Receipt 46 package/IFacet/Surface tests; `50-surface-control.log` closes the stale adversarial selector-list control, retaining exact counts and uniqueness. |
| 5 | Pretransfer rejection, ownership, reentrancy, disabled-vault paths, raw/SY boundaries | Relevant real-proxy suites pass in `49-final-default.log`; no negative was skipped or converted into a blanket rejection of valid single-input routes. |
| 6 | Gas/capability limits for nine FullSpread configurations | Passing named cold composed-route measurements in `49-final-default.log`; original 5m preview/12m transaction ceilings. No setup gas substitution or same-backing-pool safety claim. |
| 7 | Production artifact build and size | `49-final-build.log`: exit 0. All 77 affected non-harness product table entries fit. `49-size-classification.md` explains the global size command's visible exit 1 on 13 test/vendor artifacts, unchanged from receipt 19, without claiming a pristine pre-task baseline. |

A pending clean default rerun is not yet a passing receipt. The parent
will supply its completion result before final handoff. The older
failed diagnostic/strict-interpretation receipts remain historical;
do not treat them as current success evidence.

## Requested result

Review goal completeness, native ownership and fee invariants, actual
conversion receipts, guards, disabled handling, selector metadata,
caller/ambient separation, integration and scope. Cite concrete
violations, not alternative-design preferences. No implementation or
document edits. Return APPROVE or REJECT with evidence and any exact
fix required. The parent owns final evidence publication and all fixes.
