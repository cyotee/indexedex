# Member response

## Identity

- Run ID: failing-tests-diagnosis-20261104
- Member label: grok
- Profile: research
- Phase: initial independent response
- Owned path: docs/research/failing-tests-diagnosis-20261104/members/grok/response.md
- Requested role: council-member
- Requested model and reasoning: xai/grok-4.7:xhigh
- Actual role, model, reasoning, task ID, and session ID: not exposed
- Fresh or continued: fresh
- Peers read before submission: no

## Question and targets

- Question: What caused each of the 20 failing tests listed in the brief? Group failures that share one cause. Separate source observation from inference. Do not propose an implemented edit.
- Required targets: the 20 failing tests named in the brief's Supplied runtime, and the production or test code each failure message points at.
- Optional context: the full-spread exchangeIn tuple migration and the FS-HOOK-04 record. Not used. No failure below is attributed to those documents.
- Admitted read scope: the brief, the named test files, and the contracts and helpers those tests call. Public query: not used.

This response does not authorize implementation.

## Evidence

| Item | Source | Class | What was observed |
| --- | --- | --- | --- |
| Supplied failures | brief, Supplied runtime | supplied runtime | Twenty named failures and the note that Foundry's default timestamp in this repo has been observed as 1. That timestamp is not treated as proof for a test whose own code does not set it. |
| Owner-lock deposit | `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_OwnerDuringLock.t.sol:191-214`, `:222-238` | source observation | `test_D89_ownerDepositSingle_atMin_whileUnlocked` withdraws to minimum liquidity, transfers ownership (which warps by the ownership buffer plus 1), then calls `depositSingle` from a PoolManager unlock callback with deadline `block.timestamp + 1 hours` computed after that warp. |
| Hook deadline and zap | `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookDepositCommon.sol:238-255`, `:686-690`, `:287-297` | source observation | `_requireDeadline` reverts zero-argument `DeadlineExpired()` when `block.timestamp > deadline`. Owner may pass the zap gate at `MINIMUM_LIQUIDITY`. `_depositSingle` checks the caller deadline first. `_bufferPair` then calls the standard exchange with deadline `block.timestamp`, not the caller's deadline. |
| Deposit entry | `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookDepositSingleTarget.sol:64-71` | source observation | The external `depositSingle` pulls, then calls `_depositSingle`. It does not warp. |
| Rebalance gate | `contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopRebalanceTarget.sol:24-28`, `:64-66`, `:90` | source observation | `rebalance` reverts `RebalanceTooSoon(lastRebalanceTimestamp + 1 hours)` when `block.timestamp` is below that sum, and on success stores `block.timestamp`. |
| Rebalance expectation | `test/foundry/spec/protocol/lending/aave/cross-version/invariant/AaveCrossVersionLoop_Invariant.t.sol:315-335` | source observation | `maintain` warps by `1 hours + 1`, calls `rebalance`, then expects the next `rebalance` to revert `RebalanceTooSoon(block.timestamp + 1 hours)`. |
| Rebalance deploy | `contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoop_Component_FactoryService.sol:44-47` | source observation | The rebalance facet is deployed from the `out/` artifact, not from `type().creationCode`. The artifact file is newer than `AaveCrossVersionLoopRebalanceTarget.sol`. |
| Liquidation link | `lib/crane/contracts/protocols/lending/aave/v4/spoke/Spoke.sol:640-641`; `out/SpokeInstance.sol/SpokeInstance.json` bytecode link references | source observation | `getLiquidationLogic` returns `address(LiquidationLogic)`. The SpokeInstance artifact's only liquidation link is `LiquidationLogicAaveV4.sol:LiquidationLogic`. |
| Hash reconstruction | invariant test `:115-148`; `out/LiquidationLogicAaveV4.sol/LiquidationLogic.json` | source observation | The test patches a leading `PUSH20` (`0x73`) and otherwise hashes `deployedBytecode.object`. That artifact does not start with `0x73`. It has one immutable, `library_deploy_address`, 20 zero bytes at byte offset 120. |
| Staking notify | `contracts/protocols/staking/token/TokenStakingTarget.sol:116-123`, `:149-157`, `:209-224`, `:399-404`; test `:306-320` | source observation | Notify with zero supply still sets `rewardRate` and a future `periodFinish`. `rewardPerToken` does not accrue while `totalSupply == 0`. `stake` calls `_updateReward` before increasing supply, so the empty interval is dropped from the index. The test then expects about `100e18` after one more day. The supplied comparison is `0 !~= 100e18`. |
| Coordinator lock | `contracts/routers/balancerV3-uniswapV4/targets/BalancerV3UniswapV4CoordinatorRouterExactInTarget.sol:37-46`, `:64-76`; `...QueryTarget.sol:28-30`; `lib/crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol:21-28`; `ReentrancyLockRepo.sol:32-36`, `:88-96` | source observation | `swapExactInWithPermit` and `queryExactIn` both use `nonReentrant` on the same transient slot. The pull is `permitWitnessTransferFrom`, which is what would call the hostile token's `transferFrom`. The hostile token emits `SawIsLocked` only if that nested revert selector is `IsLocked()`. |
| Bond retire | `contracts/vaults/detf/common/bondNft/DETFFundedBondTarget.sol:157-188`; `DETFFundedBondRepo.sol:53`; `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol:85`, `:110` | source observation | A bond starts at `block.timestamp`. `_retireIfPaid` burns only when claimed principal equals principal and remaining staking gons are strictly below one unit of `gonsPerUnit`. `detfUser` is `address(0xD37F)`. |
| Halfway claim test | `test/foundry/spec/vaults/detf/common/claimToken/RebasingClaimTokenDFPkg_Deploy.t.sol:176-194` | source observation | After a warp of `DEFAULT_MIN_LOCK / 2`, the first unmessaged equality is `paidPrincipal_ == principal_ / 2`. Later unmessaged equalities compare staking and DETF balances to `paidPrincipal_ + reward_`. |
| Vesting math | `contracts/vaults/detf/common/core/DETFFundedStakingMath.sol:97-114` | source observation | Elapsed time at or before `startTimestamp` vests zero principal. Otherwise principal vests linearly, and rewards are staking value minus remaining principal. |
| Primary burn | `contracts/test/bases/FundedPrimaryRouteAssertions.sol:115-136`; `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfTarget.sol:389-393`, `:418-439` | source observation | The test previews, then calls `exchangeIn` with that quote as the minimum. Preview sizes LP against `totalSupply + pendingExpansion`. Execution realizes expansion, then sizes LP against `totalSupply` only, and reverts `MinAmountNotMet(minAmountOut_, amountOut_)` at line 439 if the paid amount is below the minimum. |
| Expansion epoch | `contracts/vaults/detf/common/core/DETFEpochNaturalExpansionLib.sol:11`, `:33-46`, `:50-56`; `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol:314-327`, `:349-375` | source observation | Epoch length is 8 hours. Pending expansion is zero unless the reserve is live, at least one epoch has completed, supply is non-zero, and the highest synthetic price is strictly above both `1e18` and the mint threshold. Realization advances `lastExpansionTimestamp` by completed epochs only. |
| Expansion test | `test/foundry/spec/vaults/detf/common/claimToken/V4ReserveLiquidity.t.sol:124-134`, `:181-214`, `:250-274`, `:743-906` | source observation | One behavior test is inherited by all eight named contracts. It sets `mintThreshold` to `2e18` and the closure rate to `1e18`, funds yield, warps 25 hours, and requires pending expansion above zero. The supplied failure is the second of those checks: `later epochs have funded expansion: 0 <= 0`. The intervening fallback exchange asserts that the swap consumes pending expansion and increases DETF supply by that amount. `simulateYield` adds assets once; it does not accrue with time. |
| Mature-close deadline | `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Quad_ProdSe.sol:404-433`; `TestBase_UniswapV4Detf.sol:427-467`; `UniswapV4DetfCommon.sol:63-65`; `contracts/vaults/detf/common/claimToken/StakedDETFTarget.sol:30`, `:197` | source observation | Both quad tests only call `_assertClaimAfterMatureClose`. That helper passes `block.timestamp + 1 hours` into DETF `exchangeIn`, then `_assertFundedMatureClaim` warps to `startTimestamp + vestingDuration` before claim and unstake. The one-argument error is `DeadlineExpired(uint256 deadline)`, thrown when `block.timestamp > deadline`, and the argument is the deadline that failed. Morpho Blue's own error at `MorphoBlueStandardExchangeCommon.sol:58` has no argument. |
| 3601 and 7202 | supplied comparison plus the constants above | inference | `1 + 3600 = 3601`. `1 + 3600 + 1 + 3600 = 7202`. Those equal a genesis timestamp of 1 plus one hour, and that same instant plus the maintain warp (`1 hours + 1`) plus another hour. This uses the coordinator-supplied timestamp only as arithmetic, not as a measured start time. |

## Assumptions

- Foundry's `assertApproxEqAbs(left, right)` comparison `0 !~= 100e18` means the left value, `earned`, was 0. Foundry's `assertEq` address failure `address 0xd37f != address(0)` means `ownerOf` returned `address(0xD37F)`.
- Foundry's `expectRevert` mismatch is reported as actual revert data, then expected revert data. That order is required for the rebalance numbers to be consistent with the revert predicate. It was not re-checked against this machine's Foundry binary.
- `475000000000` is half of `950e9`. That matches `principal_ / 2` if principal is `950e9`. The seigniorage percentage that would produce `950e9` from `1000e9` was not read.
- None other. Missing traces are stated as limits, not filled by assumption.

## Coverage

| Target | Required or optional | Status | Reason |
| --- | --- | --- | --- |
| 1. `test_D89_ownerDepositSingle_atMin_whileUnlocked` | required | examined | Test, harness, deposit entry, deadline check, and zap buffer call read. |
| 2. `invariant_APEX_accounting` | required | examined | Same `maintain` path as the two unit tests. |
| 3. `test_APEX_deterministicLifecycle` | required | examined | Calls `handler.cycle`, which calls `maintain`. |
| 4. `test_APEX_loopAccruedFiveCycleRegression` | required | examined | Same `maintain` path. |
| 5. `test_setUp_linksV4SpokeDespiteNamesakeArtifact` | required | examined | Test reconstruction, Spoke link, and both liquidation artifacts read. |
| 6. `test_notify_while_totalSupply_zero_empty_period_not_credited` | required | examined | Test and `TokenStakingTarget` notify, stake, and index read. |
| 7. `test_T31_reentrancyDuringPullIsLocked` | required | examined | Test, hostile token, both router entries, and the shared lock read. |
| 8. `test_twoBondEscrowsCloseWithoutRetiringEachOthersFraction` | required | examined | Test, claim, retire gate, and `detfUser` address read. |
| 9. `test_primaryBurnUsesOwnedLpAndPreservesExternalLiquidity` | required | examined | Assertion helper and burn preview/execution read. |
| 10. `test_halfwayClaimPaysFundedStakingAndFullClaimRetiresBond` | required | examined | Test and vesting math read. Which unmessaged equality fired is not in the supplied message. |
| 11-18. `test_standardFallbackSettlesFundedCatchupBeforeBothDirections` on the eight reserve-liquidity contracts | required | examined | Shared behavior and all eight inheriting contracts read. |
| 19. Morpho Blue `test_claimAfterMatureClose_matchesProjection` | required | examined | Test delegates to the shared helper. |
| 20. UniV3 `test_claimAfterMatureClose_matchesProjection` | required | examined | Same helper. |
| Full-spread exchangeIn tuple migration and FS-HOOK-04 | optional | not examined | Not required to read the named checks. Not used as a cause. |

## Conclusions

Agreement is not available. Peers were not read. These are causes read from the current tree, not an agreed council finding, and not an edit.

### A. Rebalance expectation and stored anchor do not disagree in the current function

Tests: `invariant_APEX_accounting`, `test_APEX_deterministicLifecycle`, `test_APEX_loopAccruedFiveCycleRegression`.

Source observation. `rebalance` computes `nextAllowed = lastRebalanceTimestamp + 1 hours` and reverts `RebalanceTooSoon(nextAllowed)` when `block.timestamp < nextAllowed`. A successful call then stores `block.timestamp` (`AaveCrossVersionLoopRebalanceTarget.sol:64-66`, `:90`). `maintain` warps by `1 hours + 1`, calls `rebalance`, and then expects the next revert argument to be `block.timestamp + 1 hours` (`AaveCrossVersionLoop_Invariant.t.sol:320-335`). At one timestamp those two expressions are the same value.

The supplied comparison is `RebalanceTooSoon(7202) != RebalanceTooSoon(3601)`. The revert predicate makes only one of those readings possible. If the call reverted, `block.timestamp` was below the stored `nextAllowed`. If the test's expected argument was `block.timestamp + 1 hours`, an expected `7202` means the expectation was computed at timestamp `3602`, and an actual `3601` would not revert at that timestamp. The consistent reading is actual `7202` and expected `3601`: the stored anchor was `3602`, and the expectation was computed at timestamp `1`.

Inference. `3602` is timestamp `1` plus the maintain warp. `7202` is that anchor plus another hour. `3601` is timestamp `1` plus one hour. The current `maintain` computes the expectation after the warp and after the successful rebalance, with no warp back between those lines. That function, as read, does not create this mismatch. The rebalance facet is loaded from `out/`, but that artifact is newer than the target source, so a stale artifact is not supported by the file times. I did not re-run the test. If the supplied trace is from this tree, the disagreement is not in the two expressions above.

### B. The liquidation hash check does not reconstruct the deployed library

Test: `test_setUp_linksV4SpokeDespiteNamesakeArtifact`.

Source observation. Spoke returns `address(LiquidationLogic)` (`Spoke.sol:640-641`). The SpokeInstance artifact links only `lib/crane/contracts/protocols/lending/aave/v4/spoke/libraries/LiquidationLogicAaveV4.sol:LiquidationLogic`. The V4 and V3 artifacts are separate files, `out/LiquidationLogicAaveV4.sol/LiquidationLogic.json` and `out/LiquidationLogicAaveV3.sol/LiquidationLogic.json`, with different deployed-bytecode prefixes and lengths.

The test hashes `deployedBytecode.object` after patching 20 bytes only when byte 0 is `0x73` (`AaveCrossVersionLoop_Invariant.t.sol:136-148`). The V4 artifact starts with `0x5f3560e0`, not `0x73`. Its immutable `library_deploy_address` is 20 zero bytes at offset 120. Deployment fills that immutable. The test's hash leaves it zero. The comparison therefore fails even when the linked library is the V4 artifact the Spoke link references.

Inference. The assertion text says the Spoke linked a non-V4 library. The artifact link and the reconstruction bug are sufficient to fail the first equality against the correct V4 library. The supplied message does not include the second equality, so this response does not claim the linked code matched the V3 artifact.

### C. Zero-supply notify drops the empty interval, and the later zero is not that drop

Test: `test_notify_while_totalSupply_zero_empty_period_not_credited`.

Source observation. `notifyRewardAmount` does not branch on `totalSupply`. It sets `rewardRate = reward / rewardsDuration`, `lastUpdateTime = block.timestamp`, and `periodFinish = block.timestamp + rewardsDuration` (`TokenStakingTarget.sol:209-224`). `rewardPerToken` returns the stored index unchanged while supply is zero (`:116-119`). `stake` calls `_updateReward` before it increases supply (`:155-157`). That update sets `lastUpdateTime` to the stake time and does not accrue the empty day (`:399-404`). The test's immediate `earned == 0` matches that skip.

The test then warps one day and expects about `100e18`, which is `700e18` over 7 days paid to the only staker. The supplied result is `0`. The formula after stake still has a non-zero rate and a live period, so one further day should not be zero. The empty-interval skip explains the immediate zero. It does not, by itself, explain the later zero. No second implementation of `earned` was found in this target.

### D. The nested query is on the shared lock; the missing event is not a second lock

Test: `test_T31_reentrancyDuringPullIsLocked`.

Source observation. `swapExactInWithPermit` takes the transient lock, then pulls through `permitWitnessTransferFrom` (`BalancerV3UniswapV4CoordinatorRouterExactInTarget.sol:37-46`, `:64-76`). The hostile token reenters `queryExactIn` from `transferFrom` and emits `SawIsLocked` only when the revert selector is `IsLocked()` (`BalancerV3UniswapV4CoordinatorRouter_LedgerAndRescue.t.sol:244-253`). `queryExactIn` uses the same `nonReentrant` modifier and the same transient slot (`QueryTarget.sol:28-30`, `ReentrancyLockRepo.sol:32-36`). A nested query during that pull should revert `IsLocked()` before its body runs.

The assertion failed because that event was not in `vm.getRecordedLogs()` after the outer call. The outer call is expected to revert: the child router is `address(0xBEEF)`. Inference. The lock sharing the test describes is present. The missing event means one of three things this read cannot separate: the permit pull never called `transferFrom`, the nested revert selector was not the raw `IsLocked()` selector, or the log cheatcode did not keep an event from the reverted outer call. The witness type string in the test concatenates to the coordinator's `_WITNESS_TYPE_STRING`; no mismatch was observed there. `_hash` on bytes is `keccak256`.

### E. Full claim does not burn the bond, and the halfway test stops on a zero against 475e9

Tests: `test_twoBondEscrowsCloseWithoutRetiringEachOthersFraction`, `test_halfwayClaimPaysFundedStakingAndFullClaimRetiresBond`.

Source observation. `detfUser` is `address(0xD37F)` (`TestBase_UniswapV4Detf.sol:110`). The two-bond test's failing equality is `ownerOf(a_) == address(0)` (`FundedStakingSequence.t.sol:143`). The supplied address `0xd37f` is that user. `_retireIfPaid` burns only when `claimedPrincipal == principal` and `stakingGons < gonsPerUnit` (`DETFFundedBondTarget.sol:180-188`). The burn was not taken. Vesting uses `block.timestamp` against `startTimestamp`, which is set to `block.timestamp` at open (`DETFFundedBondRepo.sol:53`, `DETFFundedStakingMath.sol:103-111`). Two warps of `DEFAULT_MIN_LOCK / 2` sum to `DEFAULT_MIN_LOCK` (`30 days`, an even number of seconds).

The halfway test's first unmessaged equality is `paidPrincipal_ == principal_ / 2` (`RebasingClaimTokenDFPkg_Deploy.t.sol:183`). `475000000000` is `475e9`. Inference. That is half of `950e9`. If this first equality is the one that failed, vested principal at the halfway timestamp was 0 while `principal_ / 2` was `475e9`. If that equality passed, a later unmessaged equality compared a zero balance to `paidPrincipal_ + reward_`. The supplied message has no custom string, so the file does not identify the line. Both tests fail in claim settlement, but they are not the same observation: one proves the NFT was not burned, the other proves a zero stood where `475e9` was required.

### F. Primary burn pays one wei under the preview used as the minimum

Test: `test_primaryBurnUsesOwnedLpAndPreservesExternalLiquidity`.

Source observation. The helper previews `exchangeIn` and passes that quote as `minAmountOut` (`FundedPrimaryRouteAssertions.sol:125-131`). Preview, when the burn gate is open, sizes LP with `totalSupply + pendingExpansion` (`UniswapV4DetfTarget.sol:389-391`). Execution calls `_realizeExpansionIfNeeded`, then sizes LP with `totalSupply` only, and reverts `MinAmountNotMet(minAmountOut_, amountOut_)` if the paid amount is short (`:428-439`). The supplied failure is that minimum miss, off by 1 wei.

Inference. The preview adds pending expansion to the denominator so it can match post-realization supply. A one-wei miss is a rounding difference between that preview and the exit that `_payBurnOut` actually performs, not a wrong-pool or wrong-owner burn. The external-LP assertion is after the `exchangeIn` call, so it was not reached.

### G. The second funded epoch is quoted as zero after catch-up settlement

Tests, all the same function `test_standardFallbackSettlesFundedCatchupBeforeBothDirections`: `CpPublicReserveLiquidityTest`, `CpReserveLiquidityTest`, `CurveQuadPublicReserveLiquidityTest`, `CurveQuadReserveLiquidityTest`, `OrbitalPublicReserveLiquidityTest`, `OrbitalReserveLiquidityTest`, `WeightedPublicReserveLiquidityTest`, `WeightedReserveLiquidityTest`.

Source observation. All eight contracts inherit `V4ReserveLiquidityBehavior` (`V4ReserveLiquidity.t.sol:743-906`). The test sets the expansion mint threshold to `2e18` and the annual closure rate to `1e18`, funds yield, warps 25 hours, and requires `pendingExpansionDetf() > 0` (`:124-134`, `:57-58`). The supplied failure is the second of those checks, `0 <= 0`. The first check, `real reserve yield funds due epochs`, is a different message, so it passed. The exchange between them asserts that pending expansion is consumed and that DETF supply increases by that pending amount (`:270-273`).

Pending expansion is zero unless the highest synthetic price is strictly above both `1e18` and the mint threshold, supply is non-zero, and at least one 8-hour epoch has completed (`DETFEpochNaturalExpansionLib.sol:33-46`, `UniswapV4DetfCommon.sol:314-327`). Twenty-five hours is three epochs, not zero, unless `lastExpansionTimestamp` was moved to within 8 hours of the second read. Realization moves that timestamp by completed epochs only (`:50-56`, `:362-363`). `simulateYield` adds a fixed asset amount (`SimpleYieldERC4626.sol:187-189`); the warp itself does not add yield.

Inference. The second read is zero because `previewPendingExpansionMint` hit one of those gates after the catch-up mint increased supply. The test's funding assertion uses `_leadSyntheticPrice` before the second warp. Pending uses `_highestSyntheticPrice`. Those are not the same quote. The lead-price assertion does not establish the production price gate at the post-warp read. This is one cause for all eight contracts.

### H. Mature close fails a one-argument deadline of 3601 in the shared helper

Tests: `UniswapV4Detf_Quad_MorphoBlueSe.test_claimAfterMatureClose_matchesProjection`, `UniswapV4Detf_Quad_Univ3Se.test_claimAfterMatureClose_matchesProjection`.

Source observation. Both functions only call `_assertClaimAfterMatureClose` (`UniswapV4Detf_Quad_MorphoBlueSe.t.sol:85-87` and the same lines in the UniV3 file). That helper calls DETF `exchangeIn` with `block.timestamp + 1 hours`, then `_assertFundedMatureClaim`, which warps to `startTimestamp + vestingDuration` before the claim (`TestBase_UniswapV4Detf_Quad_ProdSe.sol:404-416`, `TestBase_UniswapV4Detf.sol:432-434`). `DEFAULT_MIN_LOCK` is 30 days. The one-argument error is thrown by `UniswapV4DetfCommon._requireActive` and `StakedDETFTarget._exchange` when `block.timestamp > deadline`, and the argument is that deadline (`UniswapV4DetfCommon.sol:63-65`, `StakedDETFTarget.sol:197`). Morpho Blue's own `DeadlineExpired()` has no argument, so this failure is not that error.

Inference. `3601` is `1 + 1 hours`. A deadline computed as `block.timestamp + 1 hours` at timestamp 1, and checked after the maturity warp, fails with exactly `DeadlineExpired(3601)`. The helper's own post-warp calls recompute `block.timestamp + 1 hours`. The hook's internal exchange calls pass `block.timestamp` (`DepositCommon.sol:294-297`) or, for the sweep, `block.timestamp + 1` (`UniswapV4DetfCommon.sol:648`). Those would report the then-current time, not 3601, unless they ran at timestamp 3600 or 3601. The shared fact is that both products die in this helper on the one-argument DETF or staking error. The exact call that still held 3601 after the warp was not isolated. No stored user deadline was found.

### I. The unlocked minimum deposit's fresh deadline does not trip the hook check as read

Test: `test_D89_ownerDepositSingle_atMin_whileUnlocked`.

Source observation. The call is `depositSingle` from inside `PoolManager.unlock`, after an ownership-buffer warp, with deadline `block.timestamp + 1 hours` encoded after the warp (`OwnerDuringLock.t.sol:203-214`). The hook reverts zero-argument `DeadlineExpired()` only when `block.timestamp > deadline` (`DepositCommon.sol:254-255`). That check is the first line of `_depositSingle` (`:690`). The zap then calls the standard exchange with deadline `block.timestamp` (`:294-297`), which the same `>` check accepts. The sibling owner swap is documented as internal book settlement so it can run while the PoolManager is unlocked (`SeTarget.sol:786-787`). `depositSingle` has no equivalent comment.

Inference. The supplied error name matches this hook's zero-argument error, not the one-argument DETF or staking error in group H. The deadline in the encoded call is not expired at the start of `depositSingle`. This response does not identify a line in that call that passes an already-expired deadline. Group H is a different error signature and a different warp.

### Named tests

1. `test_D89_ownerDepositSingle_atMin_whileUnlocked` — group I.
2. `invariant_APEX_accounting` — group A.
3. `test_APEX_deterministicLifecycle` — group A.
4. `test_APEX_loopAccruedFiveCycleRegression` — group A.
5. `test_setUp_linksV4SpokeDespiteNamesakeArtifact` — group B.
6. `test_notify_while_totalSupply_zero_empty_period_not_credited` — group C.
7. `test_T31_reentrancyDuringPullIsLocked` — group D.
8. `test_twoBondEscrowsCloseWithoutRetiringEachOthersFraction` — group E.
9. `test_primaryBurnUsesOwnedLpAndPreservesExternalLiquidity` — group F.
10. `test_halfwayClaimPaysFundedStakingAndFullClaimRetiresBond` — group E.
11. `CpPublicReserveLiquidityTest.test_standardFallbackSettlesFundedCatchupBeforeBothDirections` — group G.
12. `CpReserveLiquidityTest.test_standardFallbackSettlesFundedCatchupBeforeBothDirections` — group G.
13. `CurveQuadPublicReserveLiquidityTest.test_standardFallbackSettlesFundedCatchupBeforeBothDirections` — group G.
14. `CurveQuadReserveLiquidityTest.test_standardFallbackSettlesFundedCatchupBeforeBothDirections` — group G.
15. `OrbitalPublicReserveLiquidityTest.test_standardFallbackSettlesFundedCatchupBeforeBothDirections` — group G.
16. `OrbitalReserveLiquidityTest.test_standardFallbackSettlesFundedCatchupBeforeBothDirections` — group G.
17. `WeightedPublicReserveLiquidityTest.test_standardFallbackSettlesFundedCatchupBeforeBothDirections` — group G.
18. `WeightedReserveLiquidityTest.test_standardFallbackSettlesFundedCatchupBeforeBothDirections` — group G.
19. `UniswapV4Detf_Quad_MorphoBlueSe.test_claimAfterMatureClose_matchesProjection` — group H.
20. `UniswapV4Detf_Quad_Univ3Se.test_claimAfterMatureClose_matchesProjection` — group H.

## Limits

- Runtime or extraction proof: no forge run, no trace, no log. Supplied revert text is the user's runtime, not a run by this response. Artifact JSON was read as files on disk; it can change.
- Not examined: peer responses, the draft, the run record, the full-spread exchangeIn migration, and the FS-HOOK-04 record. The call inside group H that still held deadline 3601 was not isolated. The unmessaged equality in the halfway claim was not isolated. The later zero in the staking test was not reproduced from the accrual formula. The unlocked deposit's expired deadline was not found in the encoded call.
- Assignment boundary: this response does not authorize implementation, tests, installs, Git, or edits outside the owned path.
- Permission boundary: inherited parent permissions were accepted for the session. This file does not prove confinement.
