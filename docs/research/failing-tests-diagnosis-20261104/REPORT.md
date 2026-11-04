# Research report

## Question

- Run ID: failing-tests-diagnosis-20261104
- Question: What caused each of the 20 failing tests named in the brief?
- Profile: research
- Council kind: full
- Result label: full

## Authorization and scope

- Authorization source: explicit council directive
- Authorizing task or role: the user asked to have the council diagnose these failures
- Admitted read scope: the named tests, the code they call, and the brief
- Inherited permissions: accepted. They are not extra authority and not a sandbox.
- Implementation authority: none. This report does not authorize edits, tests, installs, deployment, or Git.

## Participation

| Participant | Role | Requested model and reasoning | Actual model and reasoning | Task ID | Fresh or continued | Status | Identity source |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Coordinator | invoking-agent | current invoking session model | not exposed | not exposed | continued | draft and resolution written | Native did not expose a coordinator task ID |
| astra | council-member | chatgpt-subscription/gpt-6-astra:high | gpt-6-astra, high | st_01a1a63b | continued for feedback | initial and feedback settled | Native completion |
| grok | council-member | xai/grok-4.7:xhigh | grok-4.7, xhigh | st_01a1a63c | continued for feedback | initial and feedback settled | Native completion |
| minimax | council-member | minimax/MiniMax-M3, adaptive thinking | MiniMax-M3, adaptive | st_01a1a63d | continued for feedback | initial and feedback settled | Native completion |
| kimi | council-member | kimi-coding/k3.1-pro:high, global route | k3.1-pro, high | st_01a1a63e | continued for feedback | initial and feedback settled | Native completion |

- Coordinator mode: invoking-agent
- Actual mode equals requested mode: yes
- Missing initial responses: none
- Missing feedback: none

## Conclusions

The 20 supplied failures are four groups. Three have a current-source cause. Seventeen share a numeric pattern whose mechanism is not proved. This report does not authorize a fix.

### Tests 5. The hash check does not reconstruct the deployed library

`test_setUp_linksV4SpokeDespiteNamesakeArtifact` patches an artifact runtime only when byte 0 is `0x73`. The current `out/LiquidationLogicAaveV4.sol/LiquidationLogic.json` starts with `0x5f` and keeps `library_deploy_address` as 20 bytes at offset 120. Deployment fills that immutable. The expected hash leaves it zero. Unequal hashes do not show a V3 link. Whether this artifact is the one from the failing run was not proved. An occupied CREATE3 identity remains possible and is not required.

### Test 7. A missing `SawIsLocked` log does not prove a missing lock

The outer swap and `queryExactIn` use the same transient lock. A nested query that runs reverts `IsLocked`. The test catches every outer error and then looks for the event. Validation does not decode step data. The permit pull runs before the route. Empty step data is a guaranteed revert if the route is reached, and that decode happens before the call to `0xBEEF`. It does not by itself stop the pull. The supplied message does not say whether `transferFrom` ran, whether the nested selector was `IsLocked`, or whether Foundry kept a log from the reverted call. The failure is an observation gap. It is not evidence of a second lock.

### Test 9. The rated preview can quote one wei over the exit

The test deploys with rates on and passes the preview as the minimum. Preview divides a raw pool balance by BPT supply. Execution removes liquidity through the fixture vault. That vault's proportional exit converts scaled balances back with `toRawUndoRateRoundDown`. After expansion is minted, preview supply and execution supply use the same denominator. The remaining gap is that rounding. The external-liquidity check is after the revert, so it was not reached. The one wei was not calculated from the run's balances.

Two other accounts of this test are withdrawn. The burn does not go through `UniswapV4DetfTarget`. The preview does add pending expansion, and execution mints it before sizing without that add.

### Tests 1, 2, 3, 4, 6, 8, 10, and 11 through 20. The numbers fit a stale test timestamp. That reuse is not proved

These seventeen messages match one split: the test expression uses an earlier `block.timestamp`, and the production call uses the warped time.

- Tests 2, 3, and 4 expect `RebalanceTooSoon(3601)` and get `RebalanceTooSoon(7202)`. At timestamp 1, `maintain` warps to 3602. Production then allows the next rebalance at 7202. A revert argument of 3601 cannot be that call, because 3602 is not less than 3601. The expectation was computed at timestamp 1.
- Test 1 reverts zero-argument `DeadlineExpired()` after an ownership transfer that warps one day. The deposit deadline expression sits after that warp in source order. A reused read is about 23 hours stale. The hook rejects that supplied deadline. A nested call that passes the runtime timestamp would not.
- Test 6 expects about `100e18` after a second one-day warp and gets 0. The first `earned == 0` is a different assertion. A reused second warp adds no day.
- Tests 8 and 10 warp half the lock, claim, and warp half the lock again. Test 8 still sees owner `0xd37f`, which is `detfUser`. Half vesting does not burn the bond. Under the same hypothesis, test 10's first claim pays half of 950e9 and the second pays 0, so the failing check is `assertEq(remaining_, principal_ - paidPrincipal_)` at `RebasingClaimTokenDFPkg_Deploy.t.sol:194`. The supplied message does not name that line. A sub-unit gons residue does not explain either result: retirement consumes that residue once principal is fully claimed.
- Tests 11 through 18 fail the second pending-expansion check at 0. The first check passed. A no-op second 25-hour warp leaves one hour after three 8-hour boundaries, so no new epoch is payable. All eight contracts share that body. A difference in getter names, lead price versus highest price, does not by itself make the highest price fail a gate the lead price cleared.
- Tests 19 and 20 revert `DeadlineExpired(3601)` after a warp to 30-day maturity. That value is timestamp 1 plus one hour. The pre-warp calls cannot fail it at timestamp 1. The stake after `_assertFundedMatureClaim` returns is in the same function and can. Both products share that helper.

`Vm.sol:683-687` documents this reuse for a compiler that treats `block.timestamp` as constant across a transaction. `foundry.toml` enables the optimizer and forbids `via_ir`. No response established that Solar, the compiler of the supplied run, performs that reuse.

The same staking file contains `test_second_notify_during_period_extends`. It warps, then reads `block.timestamp` again for `leftover_` and for the later assertions. It is not in the 20 failures. The user said 27290 other tests succeeded. If that sibling ran and passed, a uniform fold did not happen in that function: a cached timestamp would make `periodFinish` and `rewardRate` miss. No one identified a trigger that folds the failing functions and spares this one.

Source order, if each `block.timestamp` is re-read, does not produce these seventeen messages. A production cooldown, vesting, or deadline change is not required to describe them, and none was found that produces these exact values. The cause of the seventeen is therefore not closed. The stale-timestamp reading is the only numeric fit. It is not a demonstrated compiler fact for this run.

## Evidence

| Item | Source | Class | Used for |
| --- | --- | --- | --- |
| Twenty failure messages and the 27290 success count | brief Supplied runtime, from the user | supplied runtime | what failed, and that the sibling staking test was not listed |
| Timestamp reuse warning | `lib/crane/lib/forge-std/src/Vm.sol:683-687` | source observation | documented solc hazard, not Solar proof |
| Optimizer on, via_ir off | `foundry.toml` | source observation | compiler settings, not the failing compiler's behavior |
| Failing run used Solar | implementation session that produced the messages | coordinator-supplied | context only. Not a member observation and not a run log |
| Rebalance comparison and store | `AaveCrossVersionLoopRebalanceTarget.sol:73-74`, `:90` | source observation | 7202 versus 3601 |
| maintain warp and expectation | `AaveCrossVersionLoop_Invariant.t.sol:320-335` | source observation | shared helper for tests 2-4 |
| One-day ownership buffer | `UniswapV4SingleStandardExchangeBufferConstantProductHookDFPkg.sol:349` | source observation | test 1 staleness if the read is reused |
| Zero-argument deadline check | `UniswapV4SingleStandardExchangeBufferConstantProductHookDepositCommon.sol:254-256` | source observation | test 1 error shape |
| Artifact prefix and immutable | `out/LiquidationLogicAaveV4.sol/LiquidationLogic.json` | source observation | test 5. Current tree, not proved to be the failing build |
| Hash helper patch branch | `AaveCrossVersionLoop_Invariant.t.sol:121-141` | source observation | patch runs only for `0x73` |
| Shared router lock and call order | `BalancerV3UniswapV4CoordinatorRouterExactInTarget.sol:37-48`; `BalancerV3UniswapV4CoordinatorRouterCommon.sol:44-68`; `StockBalancerV3RouterAdapter.sol:18-24` | source observation | test 7. Pull before route. Empty decode before the child call |
| Preview raw division and execution round-down | `MultiVaultWeightedDetfCommon.sol:202-205`, `:444-449`; `VaultLiquidityFacet.sol:372-377`, `:444` | source observation | test 9. One wei not calculated |
| Sibling warp then re-read | `TokenStaking.t.sol:289-304` | source observation | counterexample to uniform reuse |
| Expansion epoch math | `V4ReserveLiquidity.t.sol:124-135`; `DETFEpochNaturalExpansionLib.sol:33-57` | source observation | tests 11-18 |
| Mature-close helper | `TestBase_UniswapV4Detf_Quad_ProdSe.sol:404-429` | source observation | tests 19-20 |

No private source was sent to a public search.

## Coverage

| Target | Required or optional | Status | Reason |
| --- | --- | --- | --- |
| Tests 1-20 | required | examined | Each is named in Conclusions |
| Production or test code the messages point at | required | examined | Locators in Evidence |
| Full-spread exchange-in migration | optional | not examined as a cause | No failure path required it |
| FS-HOOK-04 record | optional | not examined as a cause | No failure path required it |
| Solar timestamp behavior | required to close tests 1, 2-4, 6, 8, 10, 11-20 | not examined | No response established it. Not re-run |

## Disagreement and missing responses

- Disagreement: Astra and Grok treat the stale-timestamp fit as the synthesis, with Solar reuse unproved. MiniMax and Kimi require that fit to stay a hypothesis because reuse is not shown, and MiniMax adds the passing sibling. The report keeps the fit and does not call it proved.
- Dissent carried into this report: MiniMax's request to call test 7 a log-retention failure only. The report does not. Callback reach was not traced.
- Withdrawn, not left open: MiniMax's wrong-PUSH20 account of test 5, MiniMax's unrealized-preview account of test 9, and Grok's V4 denominator for test 9.
- Missing responses treated as approval: no
- Feedback used as a missing initial response: no

## Advisory review

- Draft ID: draft-failing-tests-diagnosis-20261104-r1
- Draft path: docs/research/failing-tests-diagnosis-20261104/coordinator/draft.md
- Resolution path: docs/research/failing-tests-diagnosis-20261104/coordinator/resolution.md
- Feedback dispositions: astra requested-changes, grok support-with-reservations, minimax requested-changes, kimi support-with-reservations
- Post-review wording changes: group count, Group 1 retitled as unproved, sibling counterexample, citation corrections, router order, diamond round-down line, withdrawn mechanisms
- Those changes are member-approved: no

## Recommendations

- Do not treat these 20 as one production regression, and do not treat the seventeen clock-fit messages as a proved compiler bug until a trace shows the reused read or shows that Solar did not reuse it.
- A trace of test 7's swallowed error would separate a missed pull from a discarded log. This report does not authorize that trace.

## Limitations

- No forge run. Supplied revert text was not reproduced.
- The sibling test is inferred to have passed because it was not in the failure list and the user reported 27290 successes. That inference is not a re-run.
- The current liquidation artifact may differ from the failing run's artifact.
- Test 9's one wei was not calculated.
- Live files can change. This report is not an atomic snapshot.
- Inherited permissions are not confinement evidence.

## Publication

- Publication state: published
- Final path or chat-only statement: docs/research/failing-tests-diagnosis-20261104/REPORT.md
- Cooperative update: none
- Unrelated edits preserved: yes
- Model work repeated for publication: no
- Git actions: none
- Artifacts retained until explicit deletion: yes
