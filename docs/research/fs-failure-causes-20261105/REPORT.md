# Research report

## Question

- Run ID: fs-failure-causes-20261105
- Question: What distinct causes produce the supplied IndexedEx full-spread test failures?
- Profile: research
- Council kind: full
- Result label: full

## Authorization and scope

- Authorization source: explicit council directive
- Authorizing task or role: the user's request to have the council diagnose these test failures
- Admitted read scope: the IndexedEx repository, read-only except owned council artifacts
- Inherited permissions: accepted. They are not extra authority and not a sandbox.
- Implementation authority: none. This report does not authorize edits, tests, installs, deployment, or Git.

## Participation

| Participant | Role | Requested model and reasoning | Actual model and reasoning | Task ID | Fresh or continued | Status | Identity source |
| --- | --- | --- | --- | --- | --- | --- | --- |
| coordinator | invoking agent | invoking session model | not exposed | not exposed | continued | draft and final written | not a vote |
| astra | council-member | chatgpt-subscription/gpt-6-astra:high | not exposed | st_01a1ac60 | fresh, then continued for feedback | initial and feedback settled | task spawn |
| grok | council-member | xai/grok-4.7:xhigh | not exposed | st_01a1ac61 | fresh, then continued for feedback | initial and feedback settled | task spawn |
| minimax | council-member | minimax/MiniMax-M3 | not exposed | st_01a1ac62 | fresh, then continued for feedback | initial and feedback settled | task spawn |
| kimi | council-member | kimi-coding/k3.1-pro:high, global route | not exposed | st_01a1ac63 | fresh, then continued for feedback | initial and feedback settled | task spawn |

- Coordinator mode: invoking-agent
- Actual mode equals requested mode: yes
- Missing initial responses: none
- Missing feedback: none

## Conclusions

The failures are not one story. They are one vault plan, five hook-side surfaces of that plan, and two dual-fixture causes that never reach the plan.

1. The one-sided face-to-share plan returns zero shares and refunds the whole input. `previewExchangeIn` and `exchangeIn` for a face paid for vault shares go through `Planner.planIn` / `_mintOne` / `_size`. A rejected candidate sets the remainder to the whole input and adds no liquidity. `_shares` then returns without minting, and execution pays the remainder back. Coordinator-rechecked: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultPlanner.sol:196-232`. This is the direct cause of the package `test_oneSidedDepositThenExit` `0 <= 0`, the AlreadyUnlocked `0 <= 0`, the Native `0 <= 0` on the one-sided call, and the `SE quotes the face: 0 <= 0` bind assertions. Native's supplied string does not say which of its two `assertGt` calls failed. The bundle call was not traced.

The rejecting predicate inside `_size` is not agreed, and this report does not pick one for every fixture. Kimi and Astra calculate a nonzero root whose floored gross-up then applies one wei less than `n`, so `quote.applied < n` rejects. MiniMax calculates that token0 leaves because gross exceeds the input, and token1 leaves because the root is zero. Grok cites the exits and does not isolate one. Those exits are ordered: gross above the input returns before the swap is projected, so `applied < n` cannot be the exit for an offer smaller than the gross. A coordinator-supplied temporary revert, since removed, returned `SizeReject(1, 99845250072044401495, 99845250072044401494, ...)`. Those operands are about 99.845 ether. They are not evidence for a 1 ether preview. They remain an incompletely identified one-unit shortfall, not corroboration of any named fixture amount.

2. Hook families surface that zero at different sites. This is not one `beforeSwap` wrap, and it is not five extra vault defects.

- Constant product, including BufferHookIntegration's inherited rows: the buffer treats a zero quote as no exchange. First mint then reverts `InsufficientLpOut` because the pair-side claim is zero. Member-read path: `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookDepositCommon.sol:287-293` and `:519-526`. This includes that family's `test_row_partialConsumption_bookedNotRefunded`. It dies in `_seed` before the residue assertion.
- Single buffer: `beforeSwap` reads the zero wrap quote and reverts `MinAmountNotMet(1, 0)`. PoolManager wraps that as `HookCallFailed`. Member-read path: `contracts/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeBufferHookTarget.sol:195-205`. The supplied partial-consumption failure is a different assertion in the same file: the refund is the whole input, `1000000000000000000 >= 10000000000000000`, not a rounding residue.
- Balancer quad, Balancer quad 5, Curve quad, and two-leg weighted: first-mint inventory validation reverts `ZeroAmount` before buffering. Member-read paths: `contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityCore.sol:79-91`, `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookJoinCore.sol:111-123`, and `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookJoinCore.sol:223-246`.
- Weighted N3: the weaker first-mint count check can pass, then the buffer commit reverts `BufferFailed`. Member-read path: `UniswapV4StandardExchangeWeightedBufferHookJoinCore.sol:231-236` and `UniswapV4StandardExchangeWeightedBufferHookTarget.sol:525-540`. Passage of the count check is inferred from `BufferFailed` rather than `ZeroAmount`. It was not executed.
- Orbital: the supplied error is a wrapped `beforeSwap` / `NotLive`. That the seed accepted a zero quote is an inference from that error, not a traced seed return. Member-read mechanism: initial valuation falls back to the offered face amount when the conversion preview is zero; buffering permits zero returned shares; a later effective-reserve check requires held SE shares. `R == 0` was not observed. Member-read liveness check: `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookClaimLib.sol:227-233`.

3. The other partial-consumption rows, other than constant product, fail the refund predicate of the same zero plan. The single-buffer row observes a full-input refund. The shared helper requires `0 < refund < amount`. Its message alone does not distinguish a full refund from a zero refund. The full-refund reading is source-derived from the planner remainder, not printed by those rows. The helper's face-to-face control swap is a separate pass-through and is not this failure.

4. Dual `test_row_index1` exhausts a bounded address-side search. The helper tries one PairToken record and at most 32 named vaults, then reverts `no PairToken share on the requested side of the face`. `_configureDual(false)` asks for the other side. This runs before bind and before any full-spread preview. Coordinator-rechecked caller: `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:262-267`. Member-read helper: the same file, `:119-141`. This is independent of the zero plan.

5. Dual composed gas reverts `allowance` on a stale route after a rejected bind. The catch in `_bindDual` sets `hook = address(0)` and returns. The approvals that follow that `return` are the success path. They do not run on rejection. Coordinator-rechecked: the same dual file, `:280-286` for the catch and return, and `:288-299` for the unreachable success-path approvals. `test_composedRouteGasFitsCeiling` at `:421-426` calls `_seed` and `_swapExactIn` without `_requireIdentity`. `_swapExactIn` swaps the current `poolKey` through `swapRouter`. Coordinator-rechecked: `test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrixBehavior.sol:204-214`. The literal `allowance` is the mintable token's `transferFrom`. The exact unpaid pull was not traced. MiniMax does not adopt this as identifying the short spender. The stale route is the adopted cause. The unpaid pull stays open.

## Evidence

| Item | Source | Class | Used for |
| --- | --- | --- | --- |
| Failure strings | user message, copied into brief.md | supplied runtime | which tests failed and with which error |
| Planner reject exits | Planner.sol:196-232, coordinator recheck | source observation | zero shares and full remainder |
| Hook rejection sites | member responses, paths above | source observation by members, not all rechecked by the coordinator | the five surfaces |
| Dual bind catch | dual matrix file:280-299, coordinator recheck | source observation | stale route; success approvals not reached |
| SizeReject operands | removed temporary revert, earlier in this session | coordinator-supplied | one-unit shortfall only; not a 1 ether proof |
| Formula evaluations | member responses | inference | the unresolved `_size` predicate |
| Optional plan and remediation PRD | not used | absent | no requirement inferred |

No public query was used. Private excerpts were not sent to a search service.

## Coverage

| Target | Required or optional | Status | Reason |
| --- | --- | --- | --- |
| contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/test/UniswapV4FullSpreadStandardExchangeVault.Package.t.sol | required | examined | zero share word, cause 1 |
| constantProduct single full-spread matrix | required | examined | `InsufficientLpOut` at seed, including its partial-consumption row |
| dual full-spread matrix | required | examined | causes 4 and 5, not the zero plan |
| orbital full-spread matrix | required | examined | `NotLive` surface; seed acceptance inferred |
| single buffer full-spread matrix | required | examined | `MinAmountNotMet(1, 0)` and the observed full refund |
| balancer quad full-spread matrix | required | examined | `ZeroAmount` first-mint surface |
| balancer quad 5 full-spread matrix | required | examined | same `ZeroAmount` surface |
| curve quad full-spread matrix | required | examined | same `ZeroAmount` surface |
| weighted full-spread matrix | required | examined | same `ZeroAmount` surface |
| weighted N3 full-spread matrix | required | examined | `BufferFailed`; count-check passage inferred |
| AlreadyUnlocked.t.sol | required | examined | zero share word, cause 1 |
| BufferHookIntegration.t.sol | required | examined | inherited constant-product surfaces |
| Native.t.sol | required | partially examined | one-sided call is cause 1; which `assertGt` failed is not identified |
| Implementation plan and remediation PRD | optional | not examined as runtime evidence | absence is not a requirement |

## Disagreement and missing responses

- Disagreement: which `_size` exit rejects the plan, and whether the dual `allowance` string identifies the short spender. Both stay open.
- Dissent carried into this report: MiniMax's other-exit calculation and unresolved spender. They are not treated as disproved.
- Missing responses treated as approval: no
- Feedback used as a missing initial response: no

## Advisory review

- Draft ID: draft-fs-failure-causes-20261105-r1
- Draft path: docs/research/fs-failure-causes-20261105/coordinator/draft.md
- Resolution path: docs/research/fs-failure-causes-20261105/coordinator/resolution.md
- Feedback dispositions: astra requested-changes; grok support-with-reservations; minimax support-with-reservations; kimi support
- Post-review wording changes: the five revisions in the resolution, applied only in this report
- Those changes are member-approved: no

## Recommendations

- Do not treat this report as authority to restore a haircut, add a search, or edit the vault.
- A later trace, if one is requested, would have to name the `_size` exit and the unpaid dual pull. That trace is not part of this diagnosis.

## Limitations

- No member re-ran the suite. The failure strings are supplied runtime evidence.
- The `SizeReject` operands are coordinator-supplied and incompletely identified. They are not a 1 ether proof.
- Orbital seed acceptance and weighted N3's first-mint passage are inferences.
- Native's failing `assertGt` is not identified by the supplied string.
- The source tree was live during the responses. Coordinator-rechecked lines are marked. Other lines are member-read.
- Astra, MiniMax, and Kimi feedback turns reported a terminal error after writing substantive feedback files. Those files were used. They were not regenerated.

## Publication

- Publication state: published in the run root and returned in the conversation
- Final path or chat-only statement: docs/research/fs-failure-causes-20261105/REPORT.md
- Cooperative update: none
- Unrelated edits preserved: yes. The reviewed draft was not edited after review.
