# Research report

## Question

- Run ID: remaining-failures-diagnosis-20261104
- Question: What is the root cause of each of the 18 still-failing tests, and does the previous report's account hold?
- Profile: research
- Council kind: full
- Result label: full

## Authorization and scope

- Authorization source: explicit council directive
- Authorizing task or role: the user asked the council to diagnose the remaining failures and to double-check the earlier report
- Admitted read scope: the named tests, the code they call, the previous report, and each member's own previous response
- Inherited permissions: accepted. They are not extra authority and not a sandbox.
- Implementation authority: none. This report does not authorize edits, tests, installs, deployment, or Git.

## Participation

| Participant | Role | Requested model | Task ID | Status |
| --- | --- | --- | --- | --- |
| Coordinator | invoking-agent | current invoking session model | not exposed | report written |
| astra | council-member | chatgpt-subscription/gpt-6-astra:high | st_01a1a67c | initial and feedback settled |
| grok | council-member | xai/grok-4.7:xhigh | st_01a1a67d | initial and feedback settled |
| minimax | council-member | minimax/MiniMax-M3, adaptive thinking | st_01a1a67e | initial and feedback settled |
| kimi | council-member | kimi-coding/k3.1-pro:high, global route | st_01a1a67f | initial and feedback settled |

- Missing initial responses: none
- Missing feedback: none
- Feedback dispositions: astra requested-changes, grok requested-changes, minimax support-with-reservations, kimi support-with-reservations

## Conclusions

The previous report's numeric account holds. Seventeen failures are one cause in the compiled tests. The reentrancy failure is the same observation gap as before. This report does not authorize a fix.

The previous report said those seventeen messages fit a stale test timestamp, and that a uniform compiler fold was not proved because a sibling re-reads `block.timestamp` after `vm.warp` and was not in the failure list. That limit still holds. The sibling does not defeat the clock account. It shows the reuse is not every `block.timestamp` read, and it is not a Foundry runtime that leaves every calling frame stale. That runtime alternative is this run's discriminator. The previous report did not state it as its own open alternative.

The current Solar artifacts show the mechanism. They are the workspace artifacts, not a traced copy of the supplied failing run. The workspace was not an atomic snapshot. The bytecode below is current-tree evidence, not a replay of that run.

### Seventeen tests reuse a timestamp expression across `vm.warp`

Where a later expression repeats an earlier `block.timestamp + duration`, or contains that expression, the compiled test reuses the earlier sum. A later bare `block.timestamp`, or a different offset such as `block.timestamp + 7 days`, is a different expression. The passing sibling `test_second_notify_during_period_extends` is the second shape. If the cheatcode left the calling frame stale, that sibling would fail. It is not in the failure list.

A following `TIMESTAMP; DUP2; LT` after `TIMESTAMP; ADD` is the overflow guard on that add, not a second deadline. The coordinator saw that shape at the Aave site `0xd16` and the expansion site `0x617`.

Checked windows, current artifacts only:

- Staking, `out/TokenStaking.t.sol/TokenStaking_Test.json` at `0x4ebd`: `PUSH3 0x015180; TIMESTAMP; ADD`. That is one day. The second warp path at `0x654` does not repeat `TIMESTAMP`.
- Rebalance, `out/AaveCrossVersionLoop_Invariant.t.sol/AaveCrossVersionLoop_Invariant.json` at `0xd16`: `PUSH2 0x0e10; TIMESTAMP; ADD`, then `DUP1` at `0xd22` and add one. The expectation stores `DUP5` at `0x626a` under selector `0xf28dceb3`. It does not re-read the clock.
- Expansion, only `out/V4ReserveLiquidity.t.sol/CpPublicReserveLiquidityTest.json` was disassembled by the coordinator. At `0x617` it computes `PUSH3 0x015f90; TIMESTAMP; ADD`. The other seven contracts share the source body. They were not separately disassembled here. Kimi reported checking those artifacts. That is member coverage, not a coordinator recheck.
- Owner deposit, `out/UniswapV4SingleStandardExchangeBufferConstantProductHook_OwnerDuringLock.t.sol/UniswapV4SingleStandardExchangeBufferConstantProductHook_OwnerDuringLock_Test.json` at `0x4b3f`: `PUSH2 0x0e10; TIMESTAMP; ADD`. The encoding window `0x4e50` through `0x4ec0` has no `TIMESTAMP`. Absence of an opcode is weaker than the rebalance `DUP5`.
- Mature close, only `out/UniswapV4Detf_Quad_MorphoBlueSe.t.sol/UniswapV4Detf_Quad_MorphoBlueSe.json` was disassembled by the coordinator. `PUSH2 0x0e10; TIMESTAMP; ADD` is at `0x5e19`. Univ3 was not separately disassembled by the coordinator. Astra and Kimi reported checking that artifact. The two tests share the helper.

The numbers do not depend on which side Foundry prints first. At timestamp 1, the rebalance warp target is 3602. Production's next allowed time is 7202. The retained expectation is 3601. A revert argument of 3601 cannot be the call at 3602, because 3602 is not less than 3601. The staking failure is exact zero against `100e18`, which a no-op second day produces. The bond owner stays `0xd37f`. The halfway pair is `0 != 475000000000`. The eight expansion checks fail the later-epoch assertion at 0 after the first check passed. Both mature-close tests revert `DeadlineExpired(3601)` after a warp to maturity. Test 1 reverts zero-argument `DeadlineExpired()` after a one-day ownership warp. None of these require a production cooldown, vesting, or deadline change.

The optimizer pass that performs the reuse is not named.

### The reentrancy failure is still an observation gap

`test_T31_reentrancyDuringPullIsLocked` catches every outer error and then looks for `SawIsLocked`. The outer swap and the nested query share one lock, so a query that runs reverts `IsLocked`. The pull is before the route. Empty step data reverts later. That was already the previous gap. This run did not trace the swallowed error, and it did not trace whether the running Forge keeps a log from a reverted frame. Astra reported an upstream Foundry implementation that truncates recorded logs on a failed frame. The coordinator did not re-read that upstream file, so that finding stays a member report, not a closed cause. The missing event still does not prove a missing lock.

### Named tests

| # | Test | Previous account | This report |
| --- | --- | --- | --- |
| 1 | `test_D89_ownerDepositSingle_atMin_whileUnlocked` | stale timestamp fit | holds; current artifact reuses the hour sum. Opcode absence after the transfer is weaker than a retained `DUP` |
| 2 | `invariant_APEX_accounting` | stale timestamp fit | holds; retained `DUP5` expectation is 3601; production next time is 7202 |
| 3 | `test_APEX_deterministicLifecycle` | same helper | holds |
| 4 | `test_APEX_loopAccruedFiveCycleRegression` | same helper | holds |
| 5 | `test_notify_while_totalSupply_zero_empty_period_not_credited` | stale timestamp fit | holds; second day sum is the first sum |
| 6 | `test_T31_reentrancyDuringPullIsLocked` | observation gap | holds; not closed |
| 7 | `test_twoBondEscrowsCloseWithoutRetiringEachOthersFraction` | stale timestamp fit | holds by the shared source pattern. That artifact was not disassembled by the coordinator |
| 8 | `test_halfwayClaimPaysFundedStakingAndFullClaimRetiresBond` | stale timestamp fit | holds by the shared source pattern. That artifact was not disassembled by the coordinator |
| 9 | `CpPublicReserveLiquidityTest.test_standardFallbackSettlesFundedCatchupBeforeBothDirections` | stale timestamp fit | holds; coordinator saw the 25-hour sum |
| 10 | `CpReserveLiquidityTest` same test | same | holds by shared source. Not separately disassembled here |
| 11 | `CurveQuadPublicReserveLiquidityTest` same test | same | holds by shared source. Not separately disassembled here |
| 12 | `CurveQuadReserveLiquidityTest` same test | same | holds by shared source. Not separately disassembled here |
| 13 | `OrbitalPublicReserveLiquidityTest` same test | same | holds by shared source. Not separately disassembled here |
| 14 | `OrbitalReserveLiquidityTest` same test | same | holds by shared source. Not separately disassembled here |
| 15 | `WeightedPublicReserveLiquidityTest` same test | same | holds by shared source. Not separately disassembled here |
| 16 | `WeightedReserveLiquidityTest` same test | same | holds by shared source. Not separately disassembled here |
| 17 | Morpho `test_claimAfterMatureClose_matchesProjection` | stale timestamp fit | holds; coordinator saw the hour sum. The post-maturity window's lack of `TIMESTAMP` is weaker than a retained `DUP` |
| 18 | Univ3 `test_claimAfterMatureClose_matchesProjection` | same helper | holds by shared helper. Coordinator did not disassemble that artifact. Astra and Kimi reported that they did |

## Evidence

| Item | Source | Class |
| --- | --- | --- |
| Eighteen failure messages and 27292 successes | user rerun | supplied runtime |
| Previous numeric account | docs/research/failing-tests-diagnosis-20261104/REPORT.md | prior council text, re-checked against source and artifacts |
| Timestamp warning | `lib/crane/lib/forge-std/src/Vm.sol:683-687` | source observation |
| Rebalance warp and expectation | `AaveCrossVersionLoop_Invariant.t.sol:320-335`; production comparison `AaveCrossVersionLoopRebalanceTarget.sol:73-74` and store at `:90` | source observation |
| Rebalance bytecode | current Aave invariant artifact at `0xd16`, `0xd22`, `0x626a` | current artifact, not proved identical to the failing run |
| Staking bytecode | current `TokenStaking_Test` artifact at `0x4ebd` | current artifact |
| Expansion bytecode | current `CpPublicReserveLiquidityTest` artifact at `0x617` only | current artifact |
| Deposit bytecode | current owner-during-lock artifact at `0x4b3f` | current artifact |
| Morpho mature-close bytecode | current Morpho quad artifact at `0x5e19` | current artifact |

## Coverage

| Target | Status |
| --- | --- |
| Tests 1-18 | examined. Each is named above |
| Previous report | examined. Numeric account holds. Uniform-fold limit holds |
| Univ3 artifact and seven expansion artifacts | not rechecked by the coordinator. Member reports exist |
| Tests 7 and 8 artifacts | not disassembled by the coordinator |
| Optimizer pass name | not examined |
| Test 6 swallowed error | not traced |

## Disagreement and missing responses

- No member rejected the grouping.
- Dissent carried: Astra's request to treat upstream log truncation as a closed observer failure. The report records it as a member report. The coordinator did not re-read that file.
- Missing responses treated as approval: no

## Advisory review

- Draft ID: draft-remaining-failures-diagnosis-20261104-r1
- Draft path: docs/research/remaining-failures-diagnosis-20261104/coordinator/draft.md
- Resolution path: docs/research/remaining-failures-diagnosis-20261104/coordinator/resolution.md
- Post-review wording changes: artifact-to-run qualification, eight named expansion contracts, bytecode scope limited to windows the coordinator opened, print order not used, "narrowed" removed from test 6, previous-report attribution corrected
- Those changes are member-approved: no

## Recommendations

- Do not patch production cooldown, vesting, or deadline code for these seventeen. The values match reused test expressions.
- Do not treat the current artifacts as a trace of the supplied run.
- Do not add a second router lock for test 6. The shared lock is already there.

## Limitations

- No forge run. The sibling pass is inferred from its absence in the failure list.
- Current artifacts may differ from the failing run's artifacts.
- The optimizer pass is not named.
- Test 6 was not traced.
- Live files can change. This report is not an atomic snapshot.

## Publication

- Publication state: published
- Final path: docs/research/remaining-failures-diagnosis-20261104/REPORT.md
- Git actions: none
- This report does not authorize implementation.
