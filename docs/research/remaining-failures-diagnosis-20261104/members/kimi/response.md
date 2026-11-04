# Identity

- Member: kimi
- Profile: research
- Phase: initial independent response
- Role: council-member
- Model and reasoning: kimi-coding/k3.1-pro:high, global route
- Runtime identity exposed by Native: not exposed
- Peers read before submission: no

# Question and targets

The question is the root cause of each of the 18 remaining failures supplied in `docs/research/remaining-failures-diagnosis-20261104/brief.md:78-94`, grouped by shared cause, and whether the previous report's stale-timestamp and observation-gap account holds (`docs/research/failing-tests-diagnosis-20261104/REPORT.md:42-65`). The targets are the named tests, the production and test helpers on their execution paths, and the existing compiled artifacts for those tests. This is static diagnosis of supplied runtime, not a fresh test run.

# Evidence

## A. The current Solar artifacts supply the mechanism missing from the previous report

**Source observation.** Forge-std warns that `block.timestamp` is assumed constant across a transaction and can be optimized out after `vm.warp`; it exposes `vm.getBlockTimestamp()` for that case (`lib/crane/lib/forge-std/src/Vm.sol:683-687`). The default profile enables the optimizer and disables `via_ir` (`foundry.toml:34-37`). The inspected artifacts identify compiler `0.8.38+commit.e7a91fc7.solar.0.3.0-dev`, with optimization enabled, in their metadata (`out/TokenStaking.t.sol/TokenStaking_Test.json:1`; `out/AaveCrossVersionLoop_Invariant.t.sol/AaveCrossVersionLoop_Invariant.json:1`; `out/UniswapV4SingleStandardExchangeBufferConstantProductHook_OwnerDuringLock.t.sol/UniswapV4SingleStandardExchangeBufferConstantProductHook_OwnerDuringLock_Test.json:1`; `out/FundedStakingSequence.t.sol/FundedStakingSequenceTest.json:1`; `out/RebasingClaimTokenDFPkg_Deploy.t.sol/RebasingClaimTokenDFPkg_Deploy_Test.json:1`; `out/V4ReserveLiquidity.t.sol/CpPublicReserveLiquidityTest.json:1`; `out/UniswapV4Detf_Quad_MorphoBlueSe.t.sol/UniswapV4Detf_Quad_MorphoBlueSe.json:1`; `out/UniswapV4Detf_Quad_Univ3Se.t.sol/UniswapV4Detf_Quad_Univ3Se.json:1`). I compared each artifact's metadata Keccak-256 with the current source file; all matched. I also checked all eight reserve-variant artifacts against the same current `V4ReserveLiquidity.t.sol` hash; all matched.

I decoded each artifact's deployed bytecode and source map. The relevant observations below are therefore observations of current Solar output, not guesses from revert numbers. A source-mapped `TIMESTAMP` at one expression and its absence at a later expression are stated separately from the inference that the later expression reuses the earlier value.

**Inference.** The artifacts support selective common-subexpression reuse of a test's earlier `block.timestamp` across `vm.warp`. They do not support a uniform rule that every function loses every later read. This distinction resolves the previous report's passing-sibling objection without assuming a production clock change.

## B. Test 1: `test_D89_ownerDepositSingle_atMin_whileUnlocked`

**Source observation.** The test uses a deadline before ownership transfer at line 195, transfers ownership through `_transferHookOwner`, and encodes another `block.timestamp + 1 hours` deadline at line 212 (`test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_OwnerDuringLock.t.sol:191-216`). The transfer helper warps by the ownership buffer plus one second at line 231 (`test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_OwnerDuringLock.t.sol:227-236`), and the package configures that buffer as one day (`contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookDFPkg.sol:349`). `_depositSingle` checks the caller-supplied deadline before its other work (`contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookDepositCommon.sol:686-700`); `_requireDeadline` reverts `DeadlineExpired()` when current time exceeds it (`contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookDepositCommon.sol:254-256`). In the current artifact, the test body has 175 source-mapped instructions but no source-mapped `TIMESTAMP` for either line 195 or line 212, while the warp expression at line 231 has `TIMESTAMP` instructions at PCs 18439 and 18441 (`out/UniswapV4SingleStandardExchangeBufferConstantProductHook_OwnerDuringLock.t.sol/UniswapV4SingleStandardExchangeBufferConstantProductHook_OwnerDuringLock_Test.json:1`).

**Inference.** The ownership warp uses the then-current timestamp, but the deposit deadline is the reused pre-warp value. Under the supplied timestamp-1 context, that deadline is 3601 after a roughly one-day warp, so the hook's current-time check produces the supplied bare `DeadlineExpired()`. The root cause is the optimized test's stale deadline, not the owner-at-minimum liquidity branch.

## C. Tests 2-4: the three Aave failures

**Source observation.** The handler calls the host's `maintain` from `_additionalActions` (`test/foundry/spec/protocol/lending/aave/cross-version/invariant/AaveCrossVersionLoop_Invariant.t.sol:64-70`). The three supplied entry points are at lines 251-253, 272-279, and 282-289. `maintain` warps by 3601 seconds at line 328, successfully rebalances at line 332, and then expects `RebalanceTooSoon(block.timestamp + 1 hours)` at lines 337-342 (`test/foundry/spec/protocol/lending/aave/cross-version/invariant/AaveCrossVersionLoop_Invariant.t.sol:322-345`). Production calculates `nextAllowed` from stored `lastRebalanceTimestamp` and stores the successful call's current timestamp (`contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopRebalanceTarget.sol:72-90`; `contracts/protocols/lending/aave/cross-version/LoopPositionRepo.sol:79-85`). The interval is one hour (`contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopRebalanceTarget.sol:30`). The artifact retains `TIMESTAMP` at line 328, PCs 3353 and 3355, but has no source-mapped `TIMESTAMP` for the expected-revert expression at line 339 (`out/AaveCrossVersionLoop_Invariant.t.sol/AaveCrossVersionLoop_Invariant.json:1`).

**Inference.** At timestamp 1, the warp sets time to 3602 and the first successful rebalance stores 3602. The second production call therefore computes 7202. The test's expected argument reuses timestamp 1 and computes 3601. This produces the supplied pair without assuming which side Foundry prints first: the 3601 value is identified by the test's own `expectRevert` expression. All three tests share this one stale expectation; production's stored timestamp is not stale.

## D. Test 5: `test_notify_while_totalSupply_zero_empty_period_not_credited`

**Source observation.** The test notifies 700e18, warps one day at line 312, stakes, verifies zero earnings for the empty day, then warps another day at line 319 and expects about 100e18 at line 320 (`test/foundry/spec/protocols/staking/token/TokenStaking.t.sol:306-320`). `stake` updates rewards before increasing supply (`contracts/protocols/staking/token/TokenStakingTarget.sol:149-160`). `_updateReward` advances `lastUpdateTime` to the applicable reward time, and `rewardPerToken` leaves the stored value unchanged while supply is zero (`contracts/protocols/staking/token/TokenStakingTarget.sol:108-130`, `:399-405`). Notification sets the rate and period finish (`contracts/protocols/staking/token/TokenStakingTarget.sol:209-226`). The artifact retains `TIMESTAMP` at the first warp, PCs 20161 and 20163, but has no source-mapped `TIMESTAMP` at the second warp (`out/TokenStaking.t.sol/TokenStaking_Test.json:1`).

The sibling `test_second_notify_during_period_extends` has source-level reads after its warp at lines 298 and 302 (`test/foundry/spec/protocols/staking/token/TokenStaking.t.sol:289-304`). Its artifact retains all three relevant reads: line 297 at PCs 19664/19666, line 298 at PCs 19591/19595, and line 302 at PCs 19434/19436 (`out/TokenStaking.t.sol/TokenStaking_Test.json:1`).

**Inference.** The second warp reuses timestamp 1 and therefore targets the same timestamp as the first warp. Time does not advance after staking, so `earned` remains zero and the supplied 0-versus-100e18 assertion follows. The sibling's retained reads demonstrate that Solar's reuse is function-selective, answering the previous report's counterexample rather than contradicting it.

## E. Test 6: `test_T31_reentrancyDuringPullIsLocked`

**Source observation.** The hostile route deliberately has empty step data (`test/foundry/spec/routers/balancerV3-uniswapV4/BalancerV3UniswapV4CoordinatorRouter_LedgerAndRescue.t.sol:100-121`). The test records logs, catches every outer error without decoding it, and asserts that a `SawIsLocked` log exists (`test/foundry/spec/routers/balancerV3-uniswapV4/BalancerV3UniswapV4CoordinatorRouter_LedgerAndRescue.t.sol:127-140`). The token emits that event only after `transferFrom` runs, the nested call returns at least four bytes, and the selector equals `IsLocked` (`test/foundry/spec/routers/balancerV3-uniswapV4/BalancerV3UniswapV4CoordinatorRouter_LedgerAndRescue.t.sol:237-255`). The outer swap is `nonReentrant` and performs `_pullPermit` before `_executeRoute` (`contracts/routers/balancerV3-uniswapV4/targets/BalancerV3UniswapV4CoordinatorRouterExactInTarget.sol:37-48`). The nested query uses the same modifier (`contracts/routers/balancerV3-uniswapV4/targets/BalancerV3UniswapV4CoordinatorRouterQueryTarget.sol:28-34`). The modifier checks one shared transient slot and rejects a locked call before its body (`lib/crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol:20-28`; `lib/crane/contracts/access/reentrancy/ReentrancyLockRepo.sol:30-90`). If the pull and callback complete, execution later reaches the adapter, whose empty-data ABI decode precedes the child router call (`contracts/routers/balancerV3-uniswapV4/adapters/StockBalancerV3RouterAdapter.sol:18-24`; `contracts/routers/balancerV3-uniswapV4/targets/BalancerV3UniswapV4CoordinatorRouterExactInTarget.sol:102-119`).

**Inference.** The current lock source would produce `IsLocked` if the nested query is reached, but the supplied missing-log message does not prove that the token callback ran or that Foundry retained a log from the later-reverted outer call. An earlier outer failure and discarded reverted-call logs remain distinguishable only with runtime evidence that the test deliberately catches and discards. The defensible root cause at the test level is therefore its observation gap: it converts absence of a particular recorded event into a lock assertion without preserving callback reachability or the outer revert. The message is not evidence of a production missing-lock defect.

## F. Test 7: `test_twoBondEscrowsCloseWithoutRetiringEachOthersFraction`

**Source observation.** The test warps half the lock at line 136, claims bond `a`, warps another half at line 140, claims again, and expects the NFT owner to be zero (`test/foundry/spec/vaults/detf/common/claimToken/FundedStakingSequence.t.sol:132-147`). Claiming uses current production time to calculate principal due and increases `claimedPrincipal` by that amount (`contracts/vaults/detf/common/bondNft/DETFFundedBondTarget.sol:163-187`). Retirement requires fully claimed principal and only sub-unit residual gons (`contracts/vaults/detf/common/bondNft/DETFFundedBondTarget.sol:190-199`). The vesting calculation pays the full principal only once elapsed time reaches the vesting duration (`contracts/vaults/detf/common/core/DETFFundedStakingMath.sol:85-108`). The artifact retains `TIMESTAMP` at the first warp, PCs 1570 and 1572, and has no source-mapped `TIMESTAMP` at the second (`out/FundedStakingSequence.t.sol/FundedStakingSequenceTest.json:1`).

**Inference.** The second warp repeats the first warp's target rather than reaching maturity. The second claim therefore pays no remaining principal and does not satisfy the retirement predicate, leaving the supplied nonzero owner. Bond `b` is not implicated by the failing owner assertion. This is the same selective second-warp reuse as test 5.

## G. Test 8: `test_halfwayClaimPaysFundedStakingAndFullClaimRetiresBond`

**Source observation.** The test warps half the lock at line 180 and successfully claims half, then warps another half at line 191 and expects the second claim to return `principal_ - paidPrincipal_` at line 194 (`test/foundry/spec/vaults/detf/common/claimToken/RebasingClaimTokenDFPkg_Deploy.t.sol:176-195`). Current vesting math computes `principalDue` as vested principal minus already claimed principal (`contracts/vaults/detf/common/core/DETFFundedStakingMath.sol:85-108`). The artifact retains `TIMESTAMP` at the first warp, PCs 2908 and 2910, and has no source-mapped `TIMESTAMP` at the second (`out/RebasingClaimTokenDFPkg_Deploy.t.sol/RebasingClaimTokenDFPkg_Deploy_Test.json:1`). The intervening unstake and its deadline are at lines 187-190, so the supplied assertion failure—not a deadline revert—also tells us execution passed that operation.

**Inference.** The second warp is a no-op. The second claim's vested amount is still only the already claimed half, so `remaining_` is zero while the assertion expects the other half, 475000000000 in the supplied run. This identifies the failing assertion at line 194 and removes the previous ambiguity among the three equal-valued assertions.

## H. Tests 9-16: all eight reserve-liquidity variants

**Source observation.** The shared test funds expansion, warps 25 hours at line 129, consumes due expansion through a fallback exchange, funds again, warps another 25 hours at line 133, and requires later pending expansion at line 134 (`test/foundry/spec/vaults/detf/common/claimToken/V4ReserveLiquidity.t.sol:124-135`). Pending expansion requires a completed eight-hour epoch and an eligible price (`contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol:308-325`, `:371-375`; `contracts/vaults/detf/common/core/DETFEpochNaturalExpansionLib.sol:33-48`). Realization advances the anchor by all completed eight-hour boundaries, not directly to current time (`contracts/vaults/detf/common/core/DETFEpochNaturalExpansionLib.sol:50-58`). Every one of the eight current artifacts retains `TIMESTAMP` at line 129 and has no source-mapped `TIMESTAMP` at line 133 (`out/V4ReserveLiquidity.t.sol/CpPublicReserveLiquidityTest.json:1`; `out/V4ReserveLiquidity.t.sol/CpReserveLiquidityTest.json:1`; `out/V4ReserveLiquidity.t.sol/CurveQuadPublicReserveLiquidityTest.json:1`; `out/V4ReserveLiquidity.t.sol/CurveQuadReserveLiquidityTest.json:1`; `out/V4ReserveLiquidity.t.sol/OrbitalPublicReserveLiquidityTest.json:1`; `out/V4ReserveLiquidity.t.sol/OrbitalReserveLiquidityTest.json:1`; `out/V4ReserveLiquidity.t.sol/WeightedPublicReserveLiquidityTest.json:1`; `out/V4ReserveLiquidity.t.sol/WeightedReserveLiquidityTest.json:1`). The eight classes are declared at `test/foundry/spec/vaults/detf/common/claimToken/V4ReserveLiquidity.t.sol:743`, `:849`, `:857`, `:868`, `:876`, `:887`, `:895`, and `:906`.

**Inference.** The first 25-hour warp completes three epochs and leaves one hour after the realized boundary. The second warp repeats the first target, so no later epoch completes and `pendingExpansionDetf()` returns zero despite the new funding. All eight variants fail for this same test-clock reason, not because of their different reserve bindings.

## I. Tests 17-18: both `test_claimAfterMatureClose_matchesProjection` variants

**Source observation.** Both leaf tests call `_assertClaimAfterMatureClose` (`test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Quad_MorphoBlueSe.t.sol:84-87`; `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Quad_Univ3Se.t.sol:84-87`). The shared outer helper computes pre-maturity deadlines at lines 408 and 412, calls the mature-claim helper, and computes a new stake deadline at line 425 (`contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Quad_ProdSe.sol:404-429`). The inner helper warps to maturity at line 434 and its separate unstake helper computes a deadline at line 467 (`contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol:427-467`). Staked-DEFT exchange rejects a deadline earlier than current time (`contracts/vaults/detf/common/claimToken/StakedDETFTarget.sol:193-198`). Both artifacts have 509 mapped instructions in the outer-helper region but no source-mapped `TIMESTAMP` at lines 408, 412, or 425; both retain `TIMESTAMP` in the separate inner-unstake function at line 467 (Morpho PCs 34751/34753, Univ3 PCs 38049/38051) (`out/UniswapV4Detf_Quad_MorphoBlueSe.t.sol/UniswapV4Detf_Quad_MorphoBlueSe.json:1`; `out/UniswapV4Detf_Quad_Univ3Se.t.sol/UniswapV4Detf_Quad_Univ3Se.json:1`).

**Inference.** The outer helper reuses its pre-warp timestamp for the stake at line 425. With initial timestamp 1, that deadline is 3601; after the maturity warp it is expired, producing the supplied `DeadlineExpired(3601)`. The separate inner unstake re-reads time, which explains why the failure localizes to the outer stake rather than every later deadline. Both product variants share this exact helper-level cause.

# Assumptions

- The 18 messages and the timestamp-1 convention are supplied runtime/context from `docs/research/remaining-failures-diagnosis-20261104/brief.md:78-94`; I did not reproduce them.
- Existing `out/` artifacts are current-tree evidence. Their source hashes match the files read, but no artifact was proved byte-for-byte to be the one executed by the supplied failing run.
- I interpret source-mapped opcode retention together with the supplied numeric outcomes. I do not assume that every unmapped or generated-code instruction is a timestamp read, or that optimization is uniform across functions.
- For the Aave pair, I identify 3601 as the expected argument from the test's own `expectRevert` expression rather than relying on Foundry's comparison-word ordering.
- T31 is not assigned a unique runtime mechanism beyond what the admitted source establishes.

# Coverage

| Numbers | Test or shared variant | Status |
| --- | --- | --- |
| 1 | `test_D89_ownerDepositSingle_atMin_whileUnlocked` | Diagnosed in Evidence B |
| 2 | `invariant_APEX_accounting` | Shared Aave cause in Evidence C |
| 3 | `test_APEX_deterministicLifecycle` | Shared Aave cause in Evidence C |
| 4 | `test_APEX_loopAccruedFiveCycleRegression` | Shared Aave cause in Evidence C |
| 5 | `test_notify_while_totalSupply_zero_empty_period_not_credited` | Diagnosed in Evidence D |
| 6 | `test_T31_reentrancyDuringPullIsLocked` | Observation gap in Evidence E |
| 7 | `test_twoBondEscrowsCloseWithoutRetiringEachOthersFraction` | Diagnosed in Evidence F |
| 8 | `test_halfwayClaimPaysFundedStakingAndFullClaimRetiresBond` | Diagnosed in Evidence G |
| 9 | `CpPublicReserveLiquidityTest.test_standardFallbackSettlesFundedCatchupBeforeBothDirections` | Shared cause in Evidence H |
| 10 | `CpReserveLiquidityTest.test_standardFallbackSettlesFundedCatchupBeforeBothDirections` | Shared cause in Evidence H |
| 11 | `CurveQuadPublicReserveLiquidityTest.test_standardFallbackSettlesFundedCatchupBeforeBothDirections` | Shared cause in Evidence H |
| 12 | `CurveQuadReserveLiquidityTest.test_standardFallbackSettlesFundedCatchupBeforeBothDirections` | Shared cause in Evidence H |
| 13 | `OrbitalPublicReserveLiquidityTest.test_standardFallbackSettlesFundedCatchupBeforeBothDirections` | Shared cause in Evidence H |
| 14 | `OrbitalReserveLiquidityTest.test_standardFallbackSettlesFundedCatchupBeforeBothDirections` | Shared cause in Evidence H |
| 15 | `WeightedPublicReserveLiquidityTest.test_standardFallbackSettlesFundedCatchupBeforeBothDirections` | Shared cause in Evidence H |
| 16 | `WeightedReserveLiquidityTest.test_standardFallbackSettlesFundedCatchupBeforeBothDirections` | Shared cause in Evidence H |
| 17 | MorphoBlue `test_claimAfterMatureClose_matchesProjection` | Shared mature-close cause in Evidence I |
| 18 | Univ3 `test_claimAfterMatureClose_matchesProjection` | Shared mature-close cause in Evidence I |

# Conclusions

The previous report's account holds for all 18 tests (`docs/research/failing-tests-diagnosis-20261104/REPORT.md:42-65`). Its caution that compiler reuse was unproved was accurate for that report. The current exact-source Solar artifacts now provide direct opcode/source-map support for selective timestamp reuse, while still not substituting for a trace of the supplied run.

| Number | Test | Root cause and assessment of previous account |
| --- | --- | --- |
| 1 | `test_D89_ownerDepositSingle_atMin_whileUnlocked` | Solar reuses the pre-ownership-warp timestamp for the deposit deadline; the hook correctly rejects the expired value. Previous stale-deadline account holds. |
| 2 | `invariant_APEX_accounting` | Shared `maintain` expectation reuses timestamp 1 and expects 3601 while production correctly returns 7202 after the first rebalance at 3602. Previous account holds. |
| 3 | `test_APEX_deterministicLifecycle` | Same shared Aave stale expected-revert argument. Previous account holds. |
| 4 | `test_APEX_loopAccruedFiveCycleRegression` | Same shared Aave stale expected-revert argument. Previous account holds. |
| 5 | `test_notify_while_totalSupply_zero_empty_period_not_credited` | The second one-day warp reuses the first target, so no post-stake reward time accrues. Previous account holds; the passing sibling is selective-retention evidence, not a counterexample. |
| 6 | `test_T31_reentrancyDuringPullIsLocked` | The test lacks evidence that the callback emitted a retained log and discards the outer error. Current source has the shared lock. Previous observation-gap account holds; a unique missing-log runtime mechanism remains unproved. |
| 7 | `test_twoBondEscrowsCloseWithoutRetiringEachOthersFraction` | The second half-lock warp is a no-op, leaving principal incompletely claimed and the NFT unretired. Previous account holds. |
| 8 | `test_halfwayClaimPaysFundedStakingAndFullClaimRetiresBond` | The second half-lock warp is a no-op, so the final claim returns zero at line 194 instead of the remaining 475000000000. Previous account holds and the assertion is now localized. |
| 9 | `CpPublicReserveLiquidityTest.test_standardFallbackSettlesFundedCatchupBeforeBothDirections` | Repeated first 25-hour warp target leaves no later completed epoch. Previous account holds. |
| 10 | `CpReserveLiquidityTest.test_standardFallbackSettlesFundedCatchupBeforeBothDirections` | Same no-op second warp and zero later pending expansion. Previous account holds. |
| 11 | `CurveQuadPublicReserveLiquidityTest.test_standardFallbackSettlesFundedCatchupBeforeBothDirections` | Same no-op second warp and zero later pending expansion. Previous account holds. |
| 12 | `CurveQuadReserveLiquidityTest.test_standardFallbackSettlesFundedCatchupBeforeBothDirections` | Same no-op second warp and zero later pending expansion. Previous account holds. |
| 13 | `OrbitalPublicReserveLiquidityTest.test_standardFallbackSettlesFundedCatchupBeforeBothDirections` | Same no-op second warp and zero later pending expansion. Previous account holds. |
| 14 | `OrbitalReserveLiquidityTest.test_standardFallbackSettlesFundedCatchupBeforeBothDirections` | Same no-op second warp and zero later pending expansion. Previous account holds. |
| 15 | `WeightedPublicReserveLiquidityTest.test_standardFallbackSettlesFundedCatchupBeforeBothDirections` | Same no-op second warp and zero later pending expansion. Previous account holds. |
| 16 | `WeightedReserveLiquidityTest.test_standardFallbackSettlesFundedCatchupBeforeBothDirections` | Same no-op second warp and zero later pending expansion. Previous account holds. |
| 17 | MorphoBlue `test_claimAfterMatureClose_matchesProjection` | The outer helper reuses its initial one-hour deadline for the post-maturity stake, yielding `DeadlineExpired(3601)`. Previous account holds. |
| 18 | Univ3 `test_claimAfterMatureClose_matchesProjection` | Same shared outer-helper stale deadline. Previous account holds. |

Thus 17 tests share one root family—selective Solar reuse of a test-side `block.timestamp` across `vm.warp`—with three manifestations: expired deadlines (1, 17, 18), a stale expected revert (2-4), and no-op second warps (5, 7-16). Test 6 is the separate T31 observation gap. This response does not authorize implementation.

# Limits

I did not run Forge, Git, installs, deploys, or sub-agents, and did not read peer responses or other members' files. I did not edit project code. The only project artifact written is this response. Existing artifacts were decoded statically; no failing test was rerun and no execution trace was obtained. Source maps and matching source hashes strongly support the compiler mechanism in the current tree, but they do not prove which artifact the supplied run executed. T31 still needs the swallowed outer error and log-retention evidence before choosing between an early revert and a discarded event.
