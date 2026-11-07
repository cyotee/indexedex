# Advisory review - draft-fs-failure-causes-20261105-r1

## Identity

- Member: minimax
- Phase: advisory review
- Requested role: council-member
- Requested model: minimax/MiniMax-M3
- Adaptive thinking: requested; not exposed (the task tool exposes no separate thinking control)
- Runtime identity: not exposed
- Task ID: not exposed
- Peers read before submission: no (peer responses and peer feedback were not opened)
- Fresh or continued: continued

## Draft under review

- Draft ID: draft-fs-failure-causes-20261105-r1
- Path: docs/research/fs-failure-causes-20261105/coordinator/draft.md
- Fingerprint: 26c3a0f02241d084d81ed8ccdc3953d49c5d720b21888b546041a953d1c05e7e (coordinator-supplied; not recomputed here)
- File opened: yes, and the draft's own fingerprint line matches the coordinator-supplied value

Review basis: the draft text plus the production and test source I read for my initial response. No test, script or deployment was run, and no peer file was read.

What I confirm in the draft:

- The causal structure matches my initial response: one vault-side plan, five hook-side rejection sites that consume that plan's zero, and two dual-fixture causes that do not use it (`Proposed text` opening paragraph).
- The hook-site mapping matches the code I read: constant product drops the zero buffer quote and then cannot mint LP (`contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookDepositCommon.sol:287-293`, `.../UniswapV4SingleStandardExchangeBufferConstantProductHookDepositCommon.sol:519-526`); the single wrapper reverts on the zero wrap preview (`contracts/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleStandardExchangeBufferHookTarget.sol:195-205`); Balancer quad, Balancer quad 5, Curve quad and the two-leg weighted row reject a zero first-mint inventory delta (`contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityCore.sol:79-91`, `contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookJoinCore.sol:111-123`, `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookJoinCore.sol:223-246`); the three-leg weighted row clears the weaker count gate and reverts in the buffer commit (`.../UniswapV4StandardExchangeWeightedBufferHookJoinCore.sol:231-236`, `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookTarget.sol:525-540`); orbital reaches a zero effective reserve and reverts `NotLive` in the liveness check (`contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookClaimLib.sol:227-233`).
- The dual stale-route reading in section 4 is consistent with the source and closes the gap I left open. `_bindDual`'s catch branch sets `hook = address(0)` and returns before the deploy, before `_bindProductPoolKey()`, and before the approvals to the hook and to the router (`test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:277-300`), while the gas test calls `_seed` and `_swapExactIn` with no identity guard (`.../UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:421-426`). The only source of the literal `allowance` in this fixture is the plain ERC-20 stub's `transferFrom` (`contracts/test/stubs/MintableERC20Decimals.sol:56-60`, `contracts/test/stubs/SimpleMintableERC20.sol:10-12`, `test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol:180-184`).
- The Native attribution is sound even though the bundle call is not traced. The bundle assertion is the first `assertGt` in that test and the one-sided assertion the second (`test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/Native.t.sol:71-77`), and the bundle path cannot silently return zero shares: its zero-liquidity case sets `failed` (`contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultPlanner.sol:230-245`), which execution turns into `MinLiquidityNotMet` (`.../UniswapV4FullSpreadStandardExchangeVaultExecution.sol:113`) rather than a zero result.

## Disposition

support-with-reservations

The draft's grouping is the one my source reading supports, and it keeps the hook surfaces separate where the code paths differ while refusing to promote one `_size` predicate to a proved cause. Three statements need qualification before the draft is read as settled: the coordinator's removed-instrumentation runtime is used as support for a specific predicate without showing that it is compatible with the current exit ordering, the dual `allowance` failure is attributed to a specific call that the draft itself says was not traced, and the bind-failure list implies a test that does not exist.

## Concerns

| # | Draft section | Concern | Why two readers could diverge | Requested change (advice, not an edit) |
| --- | --- | --- | --- | --- |
| 1 | `Proposed text` section 1, the paragraph "The rejecting predicate inside `_size` is not agreed", read with `Evidence gaps` bullet 2 | The draft says the coordinator-supplied `SizeReject(1, 99845250072044401495, 99845250072044401494, ...)` "supports Kimi and Astra for that preview". Under the cited ordering, the `applied < n` exit is only reachable when the floored gross-up is not greater than the input, because `gross_ == 0 || gross_ > amount_` is tested before the swap is projected (`contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UniswapV4FullSpreadStandardExchangeVaultPlanner.sol:207-217`). The measured `n` grosses up to 100145687133444735702 (`.../UniswapV4FullSpreadStandardExchangeVaultMath.sol:172-176`), which exceeds both a 1 ether and a 100 ether input, so the measured numbers are only reachable at the kind-1 exit for an input of roughly 100.15 ether or more. The magnitude of `n` is also about 100x what the planner's own formulas yield for a 1 ether input, and it scales with the input amount rather than with active liquidity. | State the input amount the temporary revert measured and show the gross-versus-amount comparison for that input, or state that the measurement was taken on a different tree state and therefore is not comparable with the current `_size` ordering, and keep the predicate in the `Preserved disagreements` table instead of using it as support. |
| 2 | `Proposed text` section 4, "Dual composed gas reverts `allowance` on a stale route after a rejected bind" | The body attributes the failure to the swap path - "`_swapExactIn` swaps the current `poolKey` through `swapRouter`" - and the section title names one route, while the last sentence concedes that the exact unpaid pull was not traced. In the rejected-bind branch the `dual` interface is never reassigned, because that assignment sits after the deploy (`test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:286-291`), so `_seed` runs against the stale base hook and the router pull in `_swapExactIn` runs against the stale product key (`test/foundry/spec/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualSEBCPHook_SeMatrixBehavior.sol:192-213`). Either the stale deposit or the router pull can be the one that meets an unapproved token, and the approvals that would have covered both are skipped (`.../UniswapV4DualSEBCPHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol:293-300`). | Say that the stale route covers both the stale `dual` deposit and the stale-`poolKey` router pull, and that the failing pull is whichever of the two meets a token whose approval was skipped, rather than naming the swap call as the failing one; keep the unpaid-pull gap in the `Evidence gaps` list. |
| 3 | `Proposed text` section 1, the bullet list of direct causes, read with the `Coverage adopted from responses` row "Constant-product matrix and BufferHookIntegration" | The bullet says the zero face quote is the direct cause of "`SE quotes the face: 0 <= 0` on the constant-product, single-buffer, and BufferHookIntegration bind tests", which reads as three bind tests. BufferHookIntegration declares no bind test of its own - it extends the constant-product row and adds five other tests (`test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/BufferHookIntegration.t.sol:28-114`) - and the failing assertion lives in the shared constant-product behavior (`test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrixBehavior.sol:209-222`). | Name the bind failures as the constant-product bind test and the single-buffer bind test, and note that BufferHookIntegration inherits the constant-product bind test, so the brief's separate mention of it is the same assertion rather than an additional failing test; adjust the coverage row to match. |

## What was not adopted from others

- I did not adopt Kimi and Astra's `applied = n - 1` predicate as established for the current code. My own evaluation of the cited formulas still points at different exits for the two directions (`.../UniswapV4FullSpreadStandardExchangeVaultPlanner.sol:199-211`), and concern 1 asks that the coordinator runtime be reconciled with the exit ordering before it is used as support.
- I did not adopt the coordinator's removed-instrumentation measurement as a statement about the current `_size`, for the reason in concern 1.
- I did not adopt Grok's non-isolation of the exit as a conclusion; citing the reject exits is a description of the code, and the draft's own framing depends on a predicate that remains open.
- I did not adopt the draft's implied count of three separate bind failures; BufferHookIntegration has no bind test of its own (concern 3).
- I did adopt the draft's stale-route reading of the dual `allowance` failure, which supersedes the unresolved spender in my initial response, subject to concern 2.

## Limits

- I reviewed only `docs/research/fs-failure-causes-20261105/coordinator/draft.md` and the source I read for my initial response. I did not open any peer response or peer feedback, so peer positions are known only as the draft characterises them.
- I did not recompute the fingerprint; the value in the draft is recorded as coordinator-supplied provenance and the file was opened successfully.
- No test, script or deployment was run. The numeric comparison in concern 1 is a hand evaluation of the cited integer formulas, not a runtime measurement, and it is offered as an ordering check on the coordinator's numbers rather than as a new observation.
- The source tree was live during this review; every line reference above is to the checkout as read while writing this feedback.
- This feedback is advisory. It does not authorize an implementation, a haircut, a search or a code edit, and it does not replace the draft.
