# Coordinator draft

## Draft identity

- Draft ID: draft-failing-tests-diagnosis-20261104-r1
- Path: docs/research/failing-tests-diagnosis-20261104/coordinator/draft.md
- Run ID: failing-tests-diagnosis-20261104
- Status: pending advisory review. This file is not the final.
- Fingerprint: not computed
- Sources: members/astra/response.md, members/grok/response.md, members/minimax/response.md, members/kimi/response.md. Coordinator re-read the locators named in Evidence checked by the coordinator.

## Participation

- Council kind: full
- Requested members: astra, grok, minimax, kimi
- Substantive initial responses: astra, grok, minimax, kimi
- Missing initial responses: none
- Result label: full
- Coordinator mode: invoking-agent
- Coordinator is an independent vote: no

## Question

What caused each of the 20 failing tests named in the brief? Group shared causes. Separate source observation from inference. Do not authorize an edit.

## Proposed text

The 20 supplied failures are not 20 independent production regressions. Nine groups cover them. Four groups are a shared test-clock pattern. The other five are separate. This draft does not authorize implementation.

The supplied messages are supplied runtime. No member re-ran forge. The coordinator did not re-run forge. A fit to those messages is not a green suite.

### Group 1. Stale `block.timestamp` across `vm.warp` in one function

Tests: 1, 2, 3, 4, 6, 8, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20.

Source observation. `lib/crane/lib/forge-std/src/Vm.sol:683-687` says to use `getBlockTimestamp()` instead of `block.timestamp` with `vm.warp`, because the compiler treats `block.timestamp` as constant across a transaction and can reuse one read. `foundry.toml` sets `optimizer = true` and `via_ir = false`. The failing run that produced these messages was a Solar run. No response established whether Solar performs that reuse. That compiler gap stays open.

Inference. Where a test reads `block.timestamp` before a warp and again after it in the same function, a reused read makes the later warp or deadline use the earlier instant. Production contracts, entered in another call, read the warped timestamp. The numbers below match that split. They do not match a missing production setter, a weakened cooldown, or eight reserve-math defects. Grok and Kimi are right that a fresh read after each warp would not produce these numbers. The draft does not adopt that source-order reading as the cause, because it does not fit the supplied numbers, and because the local cheatcode documents the reuse hazard. It also does not treat the hazard as proved for Solar.

**Tests 2, 3, and 4.** `maintain` warps by `1 hours + 1`, rebalances, then expects `RebalanceTooSoon(block.timestamp + 1 hours)` (`AaveCrossVersionLoop_Invariant.t.sol:320-335`). Production sets `nextAllowed = lastRebalanceTimestamp + 1 hours` and stores `block.timestamp` after success (`AaveCrossVersionLoopRebalanceTarget.sol:29-34`, `:70-91`). At timestamp 1, the warp target is 3602. A reused expectation is 3601. Production's next allowed time is 7202. A revert whose argument is 3601 cannot be the reverting call at timestamp 3602, because 3602 is not less than 3601. The consistent reading of the supplied pair is actual 7202 and expected 3601. MiniMax's "anchor one warp behind" has that direction reversed. Kimi's observation that current source persists the timestamp is compatible with storing 3602. All three tests share this helper. They are not three accounting defects.

**Test 1.** The test reads `block.timestamp + 1 hours` for the withdrawal, then `_transferHookOwner` warps by the buffer plus one second, then the deposit encodes `block.timestamp + 1 hours` again (`OwnerDuringLock.t.sol:191-214`, `:227-236`). The hook package initializes the buffer to 1 day (`UniswapV4SingleStandardExchangeBufferConstantProductHookDFPkg.sol:349`). `_requireDeadline` reverts zero-argument `DeadlineExpired()` when `block.timestamp > deadline` (`UniswapV4SingleStandardExchangeBufferConstantProductHookDepositCommon.sol:254-256`). A reused deposit deadline is about 23 hours stale after that warp. The supplied error has no argument, which matches this hook error and not the one-argument error in tests 19 and 20. A nested settlement that passes the runtime timestamp would not trip `>`. The draft does not adopt an unidentified nested deadline.

**Test 6.** Both day warps are in `test_notify_while_totalSupply_zero_empty_period_not_credited` (`TokenStaking.t.sol:306-320`). The immediate `earned == 0` is a different assertion and is not the supplied failure. The supplied failure is `0 !~= 100e18` after the second warp. A reused second warp adds no day, so earned stays 0. The empty-supply skip explains the first zero. It does not, by itself, explain a zero after a real further day. Grok and Kimi are right about that formula. The draft adopts the reused second warp as the fit, not a permanent loss of reward eligibility.

**Tests 8 and 10.** Each function warps by `DEFAULT_MIN_LOCK / 2`, claims, then warps by the same expression again (`FundedStakingSequence.t.sol:132-149`; `RebasingClaimTokenDFPkg_Deploy.t.sol:176-195`). The lock is 30 days. A reused second warp leaves the bond at half maturity. Test 8 then requires `ownerOf(a_) == address(0)` and the supplied owner is `0xd37f`, which is `detfUser` (`TestBase_UniswapV4Detf.sol:110`). Half vesting does not satisfy `_retireIfPaid`. Test 10's supplied `0 != 475000000000` is half of a 950e9 principal. The message has no assertion string. The fit is the later remaining-principal check if the first claim paid half and the second paid 0. The first-claim check could print the same pair if the first warp also did not advance. That line was not isolated. A sub-unit gons residue, MiniMax's other sub-mechanism, is not required if the second warp did not advance, and is not excluded if time did reach maturity.

**Tests 11 through 18.** The shared body warps 25 hours, requires pending expansion, exchanges, funds again, and warps 25 hours again (`V4ReserveLiquidity.t.sol:124-135`). The supplied failure is the second check, `later epochs have funded expansion: 0 <= 0`. The first check has a different message, so it passed. Realization advances `lastExpansionTimestamp` by completed 8-hour boundaries only (`DETFEpochNaturalExpansionLib.sol:33-57`). Three boundaries consume 24 hours and leave one hour, so a no-op second warp leaves `epochs_ == 0`. All eight contracts inherit that body. They are not eight reserve-math failures. A price-gate difference between `_leadSyntheticPrice` and `_highestSyntheticPrice` can also return zero if the second warp did advance. That alternative is preserved. It is not required to explain a no-op second warp.

**Tests 19 and 20.** Both call `_assertClaimAfterMatureClose`. That function uses `block.timestamp + 1 hours` before `_assertFundedMatureClaim`, which warps to maturity, and uses `block.timestamp + 1 hours` again after that call returns (`TestBase_UniswapV4Detf_Quad_ProdSe.sol:404-429`; `TestBase_UniswapV4Detf.sol:427-434`). `DeadlineExpired(3601)` is timestamp 1 plus one hour, checked after a 30-day warp. The pre-warp calls cannot fail that error at timestamp 1. The post-return stake in the same function can. The unstake helper is a separate function and would re-read unless inlined. The exact frame was not traced. Both products share the helper. They are not two SE deadline defects. Morpho Blue's own `DeadlineExpired()` has no argument, so this is not that error.

### Group 2. Unpatched library immutable, not a proved V3 link

Test: 5, `test_setUp_linksV4SpokeDespiteNamesakeArtifact`.

Source observation. The assertion hashes deployed code against an artifact runtime and patches 20 bytes only when byte 0 is `0x73` (`AaveCrossVersionLoop_Invariant.t.sol:121-141`). The coordinator read `out/LiquidationLogicAaveV4.sol/LiquidationLogic.json`. Its deployed bytecode prefix is `0x5f3560e01c8063`. Its `library_deploy_address` immutable starts at offset 120 and is 20 bytes. The patch branch does not run. Deployment fills that immutable. The expected hash leaves it zero.

Inference. Unequal hashes do not establish a V3 link. The assertion text overstates the comparison. Kimi's occupied CREATE3 identity remains possible and is not required. MiniMax is right that the phrase "two bytecode hashes differ" is not a source string. The brief combined that paraphrase with the custom message on the hash equality at line 121. The failure stays on that equality.

### Group 3. The reentrancy assertion cannot see the outcome it claims

Test: 7, `test_T31_reentrancyDuringPullIsLocked`.

Source observation. The test registers router `0xBEEF`, catches every outer error, and requires `SawIsLocked` in `vm.getRecordedLogs()` (`BalancerV3UniswapV4CoordinatorRouter_LedgerAndRescue.t.sol:98-140`). The hostile token emits that event only if the nested query reverts with the `IsLocked` selector. Both the outer swap and `queryExactIn` use the same `nonReentrant` modifier. The outer call is expected to revert because `0xBEEF` has no code.

Inference. The absent event does not prove a missing shared lock. The swallowed outer error does not say whether `transferFrom` ran, whether the nested selector differed, or whether Foundry kept a log from the reverted call. MiniMax's statement that the event was emitted and then discarded is stronger than the supplied message. The draft does not adopt it.

### Group 4. Rated preview unwind can quote one wei over execution

Test: 9, `test_primaryBurnUsesOwnedLpAndPreservesExternalLiquidity`.

Source observation. The helper passes the preview quote as `minAmountOut` (`FundedPrimaryRouteAssertions.sol:124-139`). The deploy flag is `rated_ = true` (`MultiWeightedFundedStaking.t.sol:262-273`). Preview sizes LP with pending expansion included, then divides raw pool balance by BPT supply (`MultiVaultWeightedDetfExchangeQueryTarget.sol:23-32`; `MultiVaultWeightedDetfCommon.sol:202-205`, `:444-449`). Execution calls `_updateExpansionMintOnRewards` before `_burnHeldDetf`, and that burn sizes LP with `preview_ = false` (`MultiVaultWeightedDetfExchangeInTarget.sol:43-59`; `MultiVaultWeightedDetfExchangeOutTarget.sol:13-31`). The expansion mint increases DETF supply and does not change protocol reserve LP (`MultiVaultWeightedDetfCommon.sol:221-239`). Balancer proportional removal converts scaled balances back with `toRawUndoRateRoundDown` (`lib/crane/contracts/external/balancer/v3/vault/contracts/Vault.sol:833-838`, `:910-921`).

Inference. After a matching expansion mint, preview supply and execution supply describe the same denominator. The remaining current-source gap is raw division versus rated round-down. That can be one wei. The external-LP assertion is after `exchangeIn`, so it was not reached. Grok's pending-versus-totalSupply account cites `UniswapV4DetfTarget`, which this test does not execute. MiniMax's "preview cannot realize expansion" misses the `preview_ = true` add. Neither is adopted. The one-wei difference was not numerically reproduced.

### Named tests

| # | Test | Group |
| --- | --- | --- |
| 1 | `test_D89_ownerDepositSingle_atMin_whileUnlocked` | 1 |
| 2 | `invariant_APEX_accounting` | 1 |
| 3 | `test_APEX_deterministicLifecycle` | 1 |
| 4 | `test_APEX_loopAccruedFiveCycleRegression` | 1 |
| 5 | `test_setUp_linksV4SpokeDespiteNamesakeArtifact` | 2 |
| 6 | `test_notify_while_totalSupply_zero_empty_period_not_credited` | 1 |
| 7 | `test_T31_reentrancyDuringPullIsLocked` | 3 |
| 8 | `test_twoBondEscrowsCloseWithoutRetiringEachOthersFraction` | 1 |
| 9 | `test_primaryBurnUsesOwnedLpAndPreservesExternalLiquidity` | 4 |
| 10 | `test_halfwayClaimPaysFundedStakingAndFullClaimRetiresBond` | 1 |
| 11 | `CpPublicReserveLiquidityTest.test_standardFallbackSettlesFundedCatchupBeforeBothDirections` | 1 |
| 12 | `CpReserveLiquidityTest.test_standardFallbackSettlesFundedCatchupBeforeBothDirections` | 1 |
| 13 | `CurveQuadPublicReserveLiquidityTest.test_standardFallbackSettlesFundedCatchupBeforeBothDirections` | 1 |
| 14 | `CurveQuadReserveLiquidityTest.test_standardFallbackSettlesFundedCatchupBeforeBothDirections` | 1 |
| 15 | `OrbitalPublicReserveLiquidityTest.test_standardFallbackSettlesFundedCatchupBeforeBothDirections` | 1 |
| 16 | `OrbitalReserveLiquidityTest.test_standardFallbackSettlesFundedCatchupBeforeBothDirections` | 1 |
| 17 | `WeightedPublicReserveLiquidityTest.test_standardFallbackSettlesFundedCatchupBeforeBothDirections` | 1 |
| 18 | `WeightedReserveLiquidityTest.test_standardFallbackSettlesFundedCatchupBeforeBothDirections` | 1 |
| 19 | `UniswapV4Detf_Quad_MorphoBlueSe.test_claimAfterMatureClose_matchesProjection` | 1 |
| 20 | `UniswapV4Detf_Quad_Univ3Se.test_claimAfterMatureClose_matchesProjection` | 1 |

No full-spread exchange-in tuple migration and no FS-HOOK-04 record is required for these paths.

## Preserved disagreements

| Topic | Positions | Not resolved in this draft |
| --- | --- | --- |
| Stale timestamp versus source order | Astra groups 17 tests as timestamp reuse. Grok and Kimi say the current expressions, read in order, do not produce the supplied numbers. MiniMax splits several of those tests into production gates. | Whether Solar reused `block.timestamp`. The numeric fit is adopted. The compiler fact is not proved. |
| Rebalance direction | Grok: actual 7202, expected 3601, anchor 3602. MiniMax: production anchor one warp behind. Kimi: executed code failed to persist timestamp 3602. | Print order was not re-run. The revert constraint rejects a 3601 revert argument at timestamp 3602. |
| Expansion zero | Astra: no-op second warp. Grok and MiniMax: price gate, `_highestSyntheticPrice` versus `_leadSyntheticPrice`, after catch-up. | Price gate remains possible if the second warp advanced. |
| Test 10 assertion | Astra: later remaining-half check. MiniMax: halfway principal was 0, or a gons residue. Kimi: line not isolated. | Supplied message has no assertion string. |
| Test 9 mechanism | Astra and Kimi: rated raw versus scaled unwind. Grok: V4 pending-expansion denominator. MiniMax: preview does not realize expansion. | V4 path and the unrealized-preview reading are not adopted. The one wei was not reproduced. |
| Test 7 event | MiniMax: event emitted, then lost with the revert. Astra, Grok, Kimi: callback may not have run. | No trace. Discarded-log reading is not adopted. |
| Test 1 frame | Astra: stale supplied deadline. Grok, Kimi, MiniMax: encoded deadline is after the warp and should not be expired. | Source order is after the warp. Reuse is the adopted fit, not a proved Solar fact. |

## Evidence gaps

- No forge trace. Supplied revert text was not reproduced.
- Solar's treatment of `block.timestamp` across `vm.warp` was not established.
- Test 10's failing assertion line was not in the supplied message.
- Test 7's swallowed outer error was not recovered.
- Test 9's balances, rate, and BPT operands were not supplied, so the one wei was not calculated.
- Optional full-spread migration and FS-HOOK-04 context were not used as causes.

## Coverage adopted from responses

| Target | Status | Adopted from | Conflict or gap |
| --- | --- | --- | --- |
| Tests 1, 6, 8, 11-20 clock | examined | Astra's grouping, with Grok and Kimi's source-order objection preserved | Solar reuse unverified |
| Tests 2-4 | examined | Grok's 7202/3601 arithmetic; Astra's shared helper | MiniMax direction not adopted |
| Test 5 | examined | Astra, Grok, Kimi; coordinator read the artifact prefix and immutable offset | CREATE3 reuse unexcluded |
| Test 7 | examined | Astra, Grok, Kimi qualified observation | MiniMax discarded-log certainty not adopted |
| Test 9 | examined | Astra and Kimi rated unwind; coordinator read the multi-weighted preview and execution | Grok's V4 locator not this test |
| Test 10 | partial | Astra's half-maturity fit | Failing line not isolated |

## Limits

- Static, extracted, supplied-runtime, and unverified claims stay distinguished.
- This draft does not claim permission confinement.
- Original response files were read and are preserved.
- No project code, configuration, or Git action is authorized by this draft.
- This draft does not authorize implementation.
