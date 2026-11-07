# Astra advisory feedback

## Identity

- Member: astra.
- Profile: research.
- Phase: advisory review.
- Requested role: council-member.
- Requested model: `chatgpt-subscription/gpt-6-astra:high`.
- Actual runtime model, reasoning setting, provider/account route, and task identity: not exposed.

## Draft under review

- Draft ID: `draft-se-fullspread-remediation-plan-20261106-r1`.
- Path: `docs/research/se-fullspread-remediation-plan-20261106/coordinator/draft.md`.
- Draft SHA-256: `b2738a3b21c993f0e13153cdf7aefa4e27cd113f318f75c3d0adf54d3de74fba`, coordinator-supplied; not recomputed.
- Specification fingerprint stated by the draft: `4f1f3204088b39e038a17154d79594be262921a231c6a01eeb33a7ee0373e8f3`.
- Read coverage: the complete supplied draft, sections 1-12.

## Disposition

requested-changes

The draft accurately preserves the central product choices from my proposal: the fixed 49% rule, boundary dust ownership, collapsed-candidate handling, first-deposit exception, four-part exit receipt, six infrastructure checks, retained fixture accommodations, weighted two-leg override, and excluded migration work. It does not restore a removed sizing method.

The compression omits load-bearing execution, package, measurement, and completion instructions. Those omissions allow materially different implementations without changing any product choice. The corrections below are advice for the coordinator, not edits to the draft.

## Concerns

| ID | Draft section | Why two readers could diverge | Requested change |
| --- | --- | --- | --- |
| A1 | Sections 4, 6, and 10: actual exit receipt and execution minimum | Section 4 assigns `Execution.exchangeIn` the failed-plan error mapping, while section 6 describes the four-part sum without saying how execution obtains actual proceeds or when it checks the minimum. One implementer could retain a quoted `plan.amountOut`, compare the minimum before execution, and treat a successful projected full spend as sufficient. Another could verify actual consumption and the settled receipt before burning. Both could claim to implement the present wording. The exit test likewise states the arithmetic without requiring equality to the actual recipient balance increase. This omits the load-bearing distinction in F2. | State that execution determines the actual complete recipient receipt after the actions, enforces `minAmountOut` on that receipt before burning, and returns and pays the same amount. Require actual full consumption of the opposing claim, including a minimum-zero incomplete-exit negative. Name the current execution/action-result functions responsible for carrying or reconciling that evidence. Add assertions for the recipient balance increase, exact receipt and one-above-receipt minimum cases, both requested tokens, staying-holder inventory, and rollback on locked and borrowed execution. Do not claim that a historical quote-versus-pool mismatch was observed. |
| A2 | Section 8: gas routes, files, and measurement boundary | The draft delegates standalone coverage to an unnamed money or maintenance file, composed coverage to an external section, and preview coverage to an unnamed quote file. A reader can measure one convenient route per topology or a warm/no-op maintenance branch; another can enumerate all named row files and measure productive whole transactions. The draft neither lists the separate weighted three-leg and Balancer five-leg rows nor defines how the composed transaction boundary differs from the standalone body. This loses the concrete route/file ledger required for F11. | Name `Money.t.sol`, `QuotesAndRate.t.sol`, and `BufferHookIntegration.t.sol`, with their full family test root, and enumerate the nine exact section 12 row paths: single, constant-product single, dual, orbital, weighted two-leg, weighted three-leg, Curve quad, Balancer two-leg, and Balancer five-leg. Give each its own measurement identity and preserve its prescribed supported direction/target/index cases. State that productive maintenance is measured, setup is outside the cold standalone body, no preceding preview warms the call, and composed measurement includes the whole outer transaction and settlement. Record gas, ceiling, route, file, and coldness method. Use the inclusive ceilings already specified. An oversized or rejected route must remain unresolved or blocked, not substitute for a successful measurement. |
| A3 | Sections 7 and 10: FS-A01 through FS-A04 coverage | Section 7 invokes the complete acceptance IDs but follows them with a much narrower enumeration: a selector cut, a binding-hash change, the six address rejects, and a slot check. Section 10 includes only the six-address reject. One implementer could regard that enumeration as exhaustive and test one changed binding; another could import the full package acceptance requirements, including all bindings and initialization/context negatives. The present traceability row would label either implementation F9 coverage. | Make the package checklist explicit: the full installed/proxy selector manifest and factory/temporary-hook treatment; a hash change for each facet, library entry, and infrastructure binding; zero and nonzero code-empty cases for all six addresses; the remaining invalid-component, linked-binding, pool-key, initialization, and `processArgs` caller/account negatives; and inequality against both actual comparison-family namespaces. Map these assertions to `Package.t.sol` in section 10. Retain permit/domain and required absent-surface coverage without adding any `exchangeRate` test. |
| A4 | Section 7: weighted two-leg `setUp` | The draft says the override calls the “parent `setUp`.” The row inherits a behavior contract as well as the relevant TestBase relationship. A reader could use `super.setUp()` and invoke behavior setup; another could call the weighted TestBase explicitly. The closed instruction is the latter followed by `_initializeWeighted(2)`, not an unspecified parent call. | Name `TestBase_UniswapV4StandardExchangeWeightedBufferHook.setUp()` explicitly, followed by `_initializeWeighted(2)`. Preserve the separately named three-leg setup and add a configuration assertion that distinguishes the two counts. This clarifies the accepted setup rather than reopening it. |
| A5 | Section 12: remediation completion and blockers | “Every section 10 row is true” does not cover the section 8 gas requirements, the complete FS-A01-A04 package obligations, or the fixture and weighted setup checks. An implementer could stop with all ten listed tests true while F6-F9 or F11 remains unverified. The alternative stop condition mentions only a named function needing a new product choice; it does not cover an oversized route, a prescribed hook bind rejection, or an inability to obtain a valid cold measurement. | Make successful completion conjunctive across the production requirements, package/fixture assertions, all scoped functional rows, and every named gas measurement, with recorded build/test evidence. Name concrete blocker classes for build failure, unconstructible public-harness state, gas excess or invalid measurement, required integration rejection, and an out-of-scope dependency. Require completion of independent work and a precise affected-row report without claiming overall closure. Keep the preview migration and unresolved list explicitly unclosed. |

## What was not adopted from others

No peer responses or feedback were read, so I make no attribution about another member's recommendations. This comparison uses the supplied draft and the context of my own initial contribution.

The draft need not adopt my proposed internal result shape or every implementation detail. It does need an unambiguous actual-receipt guarantee, complete package assertions, an enumerated gas ledger, and completion conditions that include those obligations. Existing conforming code should remain in place.

## Limits

Only the supplied draft was read for this advisory pass. I did not reopen the remediation PRD, family documents, source code, initial response, or peer artifacts. No fingerprint was computed. No tests, builds, installs, Git operations, implementation, or sub-agents were run.

This feedback does not authorize implementation and does not replace the draft. It requests corrections by draft section; it does not demand another review round.
