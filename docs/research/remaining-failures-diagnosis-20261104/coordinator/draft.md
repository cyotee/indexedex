# Coordinator draft

## Draft identity

- Draft ID: draft-remaining-failures-diagnosis-20261104-r1
- Path: docs/research/remaining-failures-diagnosis-20261104/coordinator/draft.md
- Run ID: remaining-failures-diagnosis-20261104
- Status: pending advisory review. This file is not the final.
- Fingerprint: not computed
- Sources: members/astra/response.md, members/grok/response.md, members/minimax/response.md, members/kimi/response.md. The coordinator re-read the previous report and checked compiled bytecode at the sites named in Evidence.

## Participation

- Council kind: full
- Requested members: astra, grok, minimax, kimi
- Substantive initial responses: astra, grok, minimax, kimi
- Missing initial responses: none
- Result label: full
- Coordinator mode: invoking-agent
- Coordinator is an independent vote: no

## Question

What is the root cause of each of the 18 still-failing tests? Does the previous report's account hold?

## Proposed text

The previous report holds, with one correction of scope. Seventeen failures are one cause. The reentrancy failure is a separate observation gap. This draft does not authorize an edit.

The previous report said the seventeen clock-shaped messages fit a stale test timestamp, and that Solar reuse was not proved because a sibling test re-reads `block.timestamp` after `vm.warp` and was not in the failure list. That sibling still discriminates. It does not defeat the clock account. It defeats a uniform fold and a Foundry runtime that leaves every calling frame stale.

### Group 1. The compiled test reuses a timestamp expression across `vm.warp`

Tests: 1, 2, 3, 4, 5, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18.

Source observation. `Vm.sol:683-687` warns that a compiler may treat `block.timestamp` as constant across `vm.warp`. The current Solar artifacts are `0.8.38` solar `0.3.0-dev`, optimizer enabled. The coordinator read these deployed-bytecode windows:

- `out/TokenStaking.t.sol/TokenStaking_Test.json` at `0x4ebd`: `PUSH3 0x015180; TIMESTAMP; ADD`. That is one day added to the timestamp. The second warp path at `0x654` does not repeat `TIMESTAMP`.
- `out/AaveCrossVersionLoop_Invariant.t.sol/AaveCrossVersionLoop_Invariant.json` at `0xd16`: `PUSH2 0x0e10; TIMESTAMP; ADD`, then `DUP1` at `0xd22` and `PUSH1 0x01; ADD`. The later expectation stores `DUP5` at `0x626a`, then `PUSH4 0xf28dceb3`. It does not re-read `TIMESTAMP`.
- `out/V4ReserveLiquidity.t.sol/CpPublicReserveLiquidityTest.json` computes `PUSH3 0x015f90; TIMESTAMP; ADD` at `0x617`. The second warp-call window `0x6c80` through `0x6d80` contains no `TIMESTAMP`.
- `out/UniswapV4SingleStandardExchangeBufferConstantProductHook_OwnerDuringLock.t.sol/...Test.json` computes `PUSH2 0x0e10; TIMESTAMP; ADD` at `0x4b3f`. The deposit-encoding window `0x4e50` through `0x4ec0` contains no `TIMESTAMP`.
- `out/UniswapV4Detf_Quad_MorphoBlueSe.t.sol/UniswapV4Detf_Quad_MorphoBlueSe.json` has `PUSH2 0x0e10; TIMESTAMP; ADD` at `0x5e19`. The post-maturity stake window `0x7b00` through `0x7b80` contains no `TIMESTAMP`.

Inference. Where the post-warp expression repeats a pre-warp expression, or contains that expression, the compiled test reuses the earlier sum. A bare later `block.timestamp`, or a different offset such as `block.timestamp + 7 days`, is not that pattern. The passing sibling `test_second_notify_during_period_extends` uses the second shape. If `vm.warp` left the calling frame stale, that sibling would fail. It is not in the failure list. The reuse is therefore in the compiled test, not in the cheatcode runtime, and it is not a fold of every `TIMESTAMP` opcode.

The supplied numbers are what that reuse produces. At timestamp 1, the rebalance warp target is 3602. Production then allows the next call at 7202. The retained expectation is 3601. The supplied line is `Error != expected error: RebalanceTooSoon(7202) != RebalanceTooSoon(3601)`. A revert argument of 3601 cannot be the reverting call at 3602. The staking failure is exact zero against `100e18`, which is what a no-op second day warp yields. The bond owner stays `0xd37f`. The halfway pair is `0 != 475000000000`. The eight expansion checks fail the later-epoch assertion at 0 after the first check passed. Both mature-close tests revert `DeadlineExpired(3601)` after a warp to maturity. Test 1 reverts zero-argument `DeadlineExpired()` after a one-day ownership warp. None of these require a production cooldown, vesting, or deadline change.

The previous report's numeric account holds. Its open alternative, that Foundry itself left the frame stale, does not. Its refusal to call uniform compiler reuse proved was right. The surviving mechanism is expression reuse in the compiled test.

### Group 2. The missing lock event is still an observation gap

Test: 6, `test_T31_reentrancyDuringPullIsLocked`.

The outer swap and the nested query share one transient lock. A nested query that runs reverts `IsLocked`. The test catches every outer error and then looks for `SawIsLocked`. The pull is before the route. Empty step data reverts later. That does not say whether `transferFrom` ran, whether the nested selector was `IsLocked`, or whether Foundry kept a log from the reverted call. The previous account holds. The gap is narrowed, not closed. No member traced the swallowed error.

### Named tests

| # | Test | Previous account | This draft |
| --- | --- | --- | --- |
| 1 | `test_D89_ownerDepositSingle_atMin_whileUnlocked` | stale timestamp fit | holds; expression reuse |
| 2 | `invariant_APEX_accounting` | stale timestamp fit | holds; retained `DUP5` expectation |
| 3 | `test_APEX_deterministicLifecycle` | same helper | holds |
| 4 | `test_APEX_loopAccruedFiveCycleRegression` | same helper | holds |
| 5 | `test_notify_while_totalSupply_zero_empty_period_not_credited` | stale timestamp fit | holds; second day warp reuses the first sum |
| 6 | `test_T31_reentrancyDuringPullIsLocked` | observation gap | holds; not closed |
| 7 | `test_twoBondEscrowsCloseWithoutRetiringEachOthersFraction` | stale timestamp fit | holds; second half-lock warp is a no-op |
| 8 | `test_halfwayClaimPaysFundedStakingAndFullClaimRetiresBond` | stale timestamp fit | holds; second claim sees the first instant |
| 9-16 | eight `test_standardFallbackSettlesFundedCatchupBeforeBothDirections` | stale timestamp fit | holds; shared body, second 25-hour warp does not re-read |
| 17 | Morpho `test_claimAfterMatureClose_matchesProjection` | stale timestamp fit | holds; post-maturity stake window has no `TIMESTAMP` |
| 18 | Univ3 `test_claimAfterMatureClose_matchesProjection` | same helper | holds |

The two tests fixed after the previous report are not in this list. Their absence is supplied runtime.

## Preserved disagreements

| Topic | Positions | This draft |
| --- | --- | --- |
| Whether the previous account holds | Astra, Grok, MiniMax, and Kimi say the numeric account holds. MiniMax adds that the sibling excludes a Foundry runtime stale frame. | Adopted. |
| Optimizer pass name | MiniMax says the pass was not named. Astra and Kimi cite artifact program counters. | The bytecode windows above are adopted. No optimizer pass is named. |
| Test 6 | All four leave callback reach or log retention untraced. | Not closed. |

## Evidence gaps

- No forge trace. The sibling pass is inferred from its absence in the supplied failure list.
- The optimizer pass that reuses the expression is not named.
- Test 6's swallowed error was not recovered.
- Univ3 mature-close bytecode was not separately disassembled. It shares the helper with the Morpho artifact that was checked.

## Coverage adopted from responses

| Target | Status | Adopted from |
| --- | --- | --- |
| Tests 1, 2-4, 5, 7-18 | examined | all four, plus coordinator bytecode windows |
| Test 6 | examined | all four; gap kept |
| Previous report | examined | holds, with the scope correction above |

## Limits

- This draft does not authorize implementation.
- Original response files were read and are preserved.
- No project code, configuration, or Git action is authorized.
