# Identity

- Member: astra.
- Profile: research.
- Phase: initial independent response.
- Role: council-member.
- Model: chatgpt-subscription/gpt-6-astra:high.
- The role and model above are the requested assignment. Independently exposed runtime model, account route, reasoning setting, execution mode, and ancestry: not exposed.
- Native task identity: not exposed as an identity field to this response.
- Run: failing-tests-diagnosis-20261104.
- Peers read before submission: no.

# Question and targets

What caused each of the 20 failures in `docs/research/failing-tests-diagnosis-20261104/brief.md`? Group shared causes, distinguish source observations from inference, and diagnose without implementation or a fresh test run.

All 20 cases are named individually in Conclusions. The assigned target set spans nine test files: the owner-during-lock hook suite; the Aave cross-version invariant suite; TokenStaking; the coordinator-router ledger/rescue suite; FundedStakingSequence; MultiWeightedFundedStaking; RebasingClaimToken deployment; V4ReserveLiquidity; and the two Quad production-SE suites. Counting the last two separately makes ten physical test files.

# Evidence

**Supplied evidence.** The failure messages and the count of 27,290 other successful tests come from the brief's Supplied runtime section. They are not results obtained in this investigation. The brief also supplies an earlier observation of initial timestamp 1; that value is used conditionally when explaining the reported numeric errors, not asserted as a new measurement.

**Source observation.** The local cheatcode interface explicitly warns that `block.timestamp` can be optimized as transaction-constant across `vm.warp`, and directs callers to `getBlockTimestamp()` instead. This is unusually direct local evidence for the dominant shared explanation: `lib/crane/lib/forge-std/src/Vm.sol:683-687`. The interface declares `warp` as setting the timestamp at `lib/crane/lib/forge-std/src/Vm.sol:2402-2403`.

**Source observation.** The current V4 liquidation artifact was read as JSON, not executed. It identifies compiler version `0.8.38+commit.e7a91fc7.solar.0.3.0-dev`, starts its runtime with `0x5f3560e01c`, and declares `deployedBytecode.immutableReferences.library_deploy_address = [{start:120,length:20}]`. The 20 runtime bytes at that offset are zero in the artifact. Its compilation target is the V4 liquidation source. All these fields are on the single physical line `out/LiquidationLogicAaveV4.sol/LiquidationLogic.json:1`.

**Source observation.** The current Spoke artifact's creation-bytecode link references name `lib/crane/contracts/protocols/lending/aave/v4/spoke/libraries/LiquidationLogicAaveV4.sol`, with `LiquidationLogic` references at byte offsets 4779, 7219, and 7286. Its compilation target is the V4 Spoke instance: `out/SpokeInstance.sol/SpokeInstance.json:1`.

The ordinary file tool could not display those oversized single-line artifacts. They were subsequently read through the resident kernel's `read` helper and parsed in memory. No artifacts were generated or modified.

Detailed source locators for each diagnosis follow in Conclusions. Reading was targeted to the failing functions, their fixture setup, and the production/helper paths necessary to explain their failures; this was not a whole-repository audit.

# Assumptions

1. The supplied failures correspond closely enough to the current source tree for source tracing to be meaningful. Neither a commit-pinned snapshot nor complete failure traces were supplied.
2. The current artifacts are useful evidence of the runtime-layout assumption in the Aave hash test. Their identity with the artifacts used in the reported run is unverified.
3. The timestamp explanation is an inference about the compiled tests, supported by the local cheatcode warning and the failure values. I did not inspect every compiled test's instruction sequence or reproduce the failures.
4. A missing event after a deliberately reverted outer call is not, by itself, evidence that reentrancy was accepted. The router case has a narrower evidentiary limit than the other groups.

# Coverage

| Group | Supplied cases | Coverage and confidence |
| --- | --- | --- |
| Test-side timestamp reuse across warps | 1-4, 6, 8, 10-20: 17 tests | Relevant tests and production clock consumers examined. Strong shared inference; not reproduced. |
| Library-runtime fingerprint normalization | 5: one test | Test helper, linker, Spoke reference, and current artifact fields examined. Concrete normalization mismatch; historical deployed bytes unavailable. |
| Reentrancy observation through a reverting outer call | 7: one test | Test, hostile token, guard, router validation/funding, and adapter examined. Harness failure mode identified; exact runtime cause remains qualified. |
| Rated proportional-exit preview mismatch | 9: one test | Test, shared assertions, DETF preview/execution, prepay router, Balancer proportional math and scaling examined. Concrete formula mismatch; exact one-wei operands unavailable. |

No peer response, other member file, council draft, or prior council conclusion was used. No forge, Git, install, deployment, wallet, or sub-agent operation was performed. No project code was edited. A go-to-definition request timed out; bounded source searches resolved the relevant helper instead.

# Conclusions

## Shared cause A: test-side time reads are reused across `vm.warp` (17 tests)

**Source observation.** These tests combine intra-call `vm.warp` changes with later `block.timestamp` expressions. That combination is specifically warned against by the local cheatcode API: `lib/crane/lib/forge-std/src/Vm.sol:683-687`.

**Inference.** A pre-warp timestamp reused in the caller explains both kinds of failure in this group: a later relative warp targets the same instant again, or a later deadline/expected error argument is computed from the old instant. The production contract, entered in another call, then uses the changed timestamp. This is a test-clock diagnosis, not evidence that the production cooldown, vesting, or deadline checks should be weakened. The individual source chains below distinguish that inference from observed code.

### Case 1: owner deposit after ownership-transfer time travel

**Test:** `UniswapV4SingleStandardExchangeBufferConstantProductHook_OwnerDuringLock_Test.test_D89_ownerDepositSingle_atMin_whileUnlocked`.

**Source observation.** The test uses `block.timestamp + 1 hours` for withdrawal, calls `_transferHookOwner`, then encodes the same deadline expression for the harness's `depositSingle` call. The transfer helper warps by the ownership buffer plus one second: `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_OwnerDuringLock.t.sol:191-214`, `:227-236`. The harness forwards the calldata and bubbles the hook revert: the same file, `:28-41`.

**Source observation.** The deposit target passes the supplied deadline to `_depositSingle`; that function checks it before its zap logic. `_requireDeadline` rejects `block.timestamp > deadline`: `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookDepositSingleTarget.sol:64-72`; `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookDepositCommon.sol:254-256`, `:686-699`.

**Inference.** The post-transfer encoded deadline is stale relative to the time advanced by the ownership handover. That explains `DeadlineExpired()` before the intended unlocked owner-deposit behavior is exercised. The matching source pattern and cheatcode warning support timestamp reuse; the brief does not include the actual encoded deadline or the warp target for this call.

### Cases 2-4: one shared stale cooldown expectation

**Tests in `AaveCrossVersionLoop_Invariant`:**

2. `invariant_APEX_accounting`.
3. `test_APEX_deterministicLifecycle`.
4. `test_APEX_loopAccruedFiveCycleRegression`.

**Source observation.** All three exercise the accounting handler. Its additional action invokes `host.maintain()`, and the base handler schedules that action on every fourth cycle: `test/foundry/spec/protocol/lending/aave/cross-version/invariant/AaveCrossVersionLoop_Invariant.t.sol:61-70`, `:244-261`, `:264-279`; `test/foundry/spec/vaults/standard/exchange/invariant/StandardExchangeAccountingHandler.sol:50-75`.

**Source observation.** `maintain()` advances time by one hour plus one second, successfully rebalances, then expects a second rebalance to revert with `RebalanceTooSoon(block.timestamp + 1 hours)`: `test/foundry/spec/protocol/lending/aave/cross-version/invariant/AaveCrossVersionLoop_Invariant.t.sol:314-336`. Production computes `nextAllowed = lastRebalanceTimestamp + MIN_REBALANCE_INTERVAL`, uses a one-hour interval, and stores the timestamp after a successful rebalance: `contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopRebalanceTarget.sol:29-34`, `:70-91`.

**Inference.** Starting conditionally at timestamp 1, the warp reaches 3602 and production's next permitted time is 7202. Reusing the caller's old timestamp gives an expected value of 3601. This reproduces the supplied numeric discrepancy arithmetically without changing the cooldown law. The invariant's reported failure is therefore consistent with the handler's exact-revert assertion aborting a campaign, rather than the accounting predicate independently discovering a balance discrepancy. All three names share this maintenance helper and cause.

### Case 6: the second reward day is not advanced

**Test:** `TokenStaking_Test.test_notify_while_totalSupply_zero_empty_period_not_credited`.

**Source observation.** The test notifies 700e18, warps by one day, stakes 100e18 and checks zero earned, then repeats `vm.warp(block.timestamp + 1 days)` before expecting roughly 100e18: `test/foundry/spec/protocols/staking/token/TokenStaking.t.sol:306-320`. The fixture sets the reward duration to seven days: `contracts/protocols/staking/token/TestBase_TokenStaking.sol:102-110`.

**Source observation.** With zero total stake, `rewardPerToken()` returns the stored value. Staking updates rewards before increasing supply. `_updateReward` sets `lastUpdateTime` to the applicable timestamp; subsequent earnings depend on elapsed time beyond that timestamp: `contracts/protocols/staking/token/TokenStakingTarget.sol:110-130`, `:149-159`, `:399-405`. Reward notification establishes the rate and period rather than disabling emission on zero supply: the same file, `:209-226`.

**Inference.** If the two relative warps evaluate from the same cached timestamp, the second warp repeats day one. No time elapses after stake creation, so earned remains zero. That explains `0 !~= 100e18`; the source does not support diagnosing this as permanent loss of future reward eligibility merely because notification occurred at zero supply.

### Cases 8 and 10: the second half-period repeats the first half-period

**Case 8 test:** `FundedStakingSequenceTest.test_twoBondEscrowsCloseWithoutRetiringEachOthersFraction`.

**Source observation.** After opening two bonds, the test warps by half the lock, claims bond A, then repeats the same relative half-lock warp, claims A again, and requires its owner to be zero: `test/foundry/spec/vaults/detf/common/claimToken/FundedStakingSequence.t.sol:132-149`. The setup had already advanced through an earlier bond's full lock: the same file, `:18-34`.

**Case 10 test:** `RebasingClaimTokenDFPkg_Deploy_Test.test_halfwayClaimPaysFundedStakingAndFullClaimRetiresBond`.

**Source observation.** This test similarly uses two `vm.warp(block.timestamp + DEFAULT_MIN_LOCK / 2)` calls, with principal claims and an unstake between them. It expects half the principal at the first claim and the remaining half at the second: `test/foundry/spec/vaults/detf/common/claimToken/RebasingClaimTokenDFPkg_Deploy.t.sol:176-195`. The fixture's lock is 30 days: `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol:85-86`.

**Source observation.** Vesting is computed from elapsed time since the stored start, and principal due is vested principal minus already claimed principal: `contracts/vaults/detf/common/core/DETFFundedStakingMath.sol:97-116`. Claim execution uses the current timestamp and increments `claimedPrincipal`; retirement requires all principal paid and less than one unit's gons remaining: `contracts/vaults/detf/common/bondNft/DETFFundedBondTarget.sol:163-199`.

**Inference.** A repeated half-period target leaves both tests at half maturity, not full maturity. For case 8, bond A correctly remains owned, matching the supplied nonzero owner `0xd37f` rather than zero. For case 10, a second claim at the same timestamp pays no additional principal; that matches `0 != 475000000000` if the mismatch is the remaining-half assertion at line 194. The brief does not supply a trace to distinguish that assertion from the first-half assertion at line 183, so the exact failing assertion is inferred, not observed. Neither message establishes cross-bond fraction retirement or a staking-escrow funding defect.

### Cases 11-18: eight bindings repeat the first 25-hour target

**Source observation.** The common test funds a premium, warps 25 hours, checks and settles expansion through a fallback trade, then funds again and repeats `vm.warp(block.timestamp + 25 hours)`. The reported assertion is the second pending-expansion check, labeled `later epochs have funded expansion`: `test/foundry/spec/vaults/detf/common/claimToken/V4ReserveLiquidity.t.sol:124-135`. Funding itself checks that the synthetic price exceeds the configured threshold: the same file, `:181-211`. The intermediate successful exchange is required to consume pending expansion: the same file, `:252-279`.

**Source observation.** Production requires at least one completed eight-hour interval since `lastExpansionTimestamp`. Realization advances that timestamp by the completed intervals; merely adding fresh yield does not make an incomplete interval payable: `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol:314-325`, `:349-375`; `contracts/vaults/detf/common/core/DETFEpochNaturalExpansionLib.sol:11`, `:33-57`.

**Inference.** If both warps target the original time plus 25 hours, the first settlement consumes three eight-hour intervals and leaves one hour. The second warp adds no time. Fresh yield clears the price gate, but there is still no completed new interval, so pending expansion remains zero. That explains why the same assertion fails across all four reserve families and both liquidity policies without requiring eight separate reserve-math failures.

Every affected test is listed here; all inherit the common body at `V4ReserveLiquidity.t.sol:124-135`:

| Case | Complete test identity | Binding locator |
| --- | --- | --- |
| 11 | `CpPublicReserveLiquidityTest.test_standardFallbackSettlesFundedCatchupBeforeBothDirections` | `test/foundry/spec/vaults/detf/common/claimToken/V4ReserveLiquidity.t.sol:743`, `:839-854` |
| 12 | `CpReserveLiquidityTest.test_standardFallbackSettlesFundedCatchupBeforeBothDirections` | `test/foundry/spec/vaults/detf/common/claimToken/V4ReserveLiquidity.t.sol:743`, `:839-846` |
| 13 | `CurveQuadPublicReserveLiquidityTest.test_standardFallbackSettlesFundedCatchupBeforeBothDirections` | `test/foundry/spec/vaults/detf/common/claimToken/V4ReserveLiquidity.t.sol:895-911` |
| 14 | `CurveQuadReserveLiquidityTest.test_standardFallbackSettlesFundedCatchupBeforeBothDirections` | `test/foundry/spec/vaults/detf/common/claimToken/V4ReserveLiquidity.t.sol:895-903` |
| 15 | `OrbitalPublicReserveLiquidityTest.test_standardFallbackSettlesFundedCatchupBeforeBothDirections` | `test/foundry/spec/vaults/detf/common/claimToken/V4ReserveLiquidity.t.sol:876-891` |
| 16 | `OrbitalReserveLiquidityTest.test_standardFallbackSettlesFundedCatchupBeforeBothDirections` | `test/foundry/spec/vaults/detf/common/claimToken/V4ReserveLiquidity.t.sol:876-884` |
| 17 | `WeightedPublicReserveLiquidityTest.test_standardFallbackSettlesFundedCatchupBeforeBothDirections` | `test/foundry/spec/vaults/detf/common/claimToken/V4ReserveLiquidity.t.sol:857-872` |
| 18 | `WeightedReserveLiquidityTest.test_standardFallbackSettlesFundedCatchupBeforeBothDirections` | `test/foundry/spec/vaults/detf/common/claimToken/V4ReserveLiquidity.t.sol:857-865` |

### Cases 19-20: a pre-maturity deadline survives the maturity warp

**Tests:**

19. `UniswapV4Detf_Quad_MorphoBlueSe.test_claimAfterMatureClose_matchesProjection`, at `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Quad_MorphoBlueSe.t.sol:85-86`.
20. `UniswapV4Detf_Quad_Univ3Se.test_claimAfterMatureClose_matchesProjection`, at `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Quad_Univ3Se.t.sol:85-86`.

**Source observation.** Both call `_assertClaimAfterMatureClose`. That helper performs operations with one-hour deadlines, calls `_assertFundedMatureClaim`, and later stakes again with another `block.timestamp + 1 hours` deadline: `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Quad_ProdSe.sol:404-429`.

**Source observation.** `_assertFundedMatureClaim` reads the timestamp, warps to the bond's stored maturity, claims, and invokes `_assertFundedUnstake`; the unstake also computes `block.timestamp + 1 hours`: `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol:427-452`, `:462-469`. The staking target rejects an expired deadline with the supplied deadline encoded in `DeadlineExpired(uint256)`: `contracts/vaults/detf/common/claimToken/StakedDETFTarget.sol:147-153`, `:194-198`.

**Inference.** Reusing an initial timestamp of 1 produces deadline 3601 even after advancing to a 30-day bond maturity. This precisely fits the supplied `DeadlineExpired(3601)` and explains the shared failure across Morpho and Uni V3 fixtures. Without a trace, I cannot select between the unstake inside the mature-claim helper and the later staking call as the first expired call; both are exposed source locations. The evidence points to their shared test clock rather than independent defects in the two underlying SE implementations.

## Cause B: runtime-hash helper assumes the wrong library-address layout (case 5)

**Test:** `AaveCrossVersionLoop_Invariant.test_setUp_linksV4SpokeDespiteNamesakeArtifact`.

**Source observation.** The assertion compares the deployed library's code hash with an artifact-runtime hash. Its normalizer patches an embedded library address only when runtime byte zero is `0x73` (`PUSH20`), and then only at offsets 1-20: `test/foundry/spec/protocol/lending/aave/cross-version/invariant/AaveCrossVersionLoop_Invariant.t.sol:114-141`.

**Source observation.** The current artifact instead begins with `0x5f`, and its library deployment-address immutable is at offset 120, length 20. Thus this helper's normalization branch does not run for that runtime. The compiler identity, immutable-reference field, bytecode prefix, and zero placeholder are directly visible at `out/LiquidationLogicAaveV4.sol/LiquidationLogic.json:1`.

**Source observation.** The fixture loads Spoke creation code through `ArtifactCreationCode`, which constructs source-qualified library identities from artifact link references and patches them with the deployed CREATE3 library address: `contracts/test/bases/TestBase_AaveCrossVersionLoopV4Market.sol:72-91`; `contracts/utils/foundry/ArtifactCreationCode.sol:91-109`. The artifact names the V4 source, and Spoke's getter returns the imported V4 library address: `out/SpokeInstance.sol/SpokeInstance.json:1`; `lib/crane/contracts/protocols/lending/aave/v4/spoke/Spoke.sol:21`, `:639-641`.

**Inference.** The test hashes an unpatched deployment-address placeholder while comparing it with deployed code containing a real address. With the observed artifact layout, that is a concrete false-mismatch mechanism. The message `Spoke linked a non-V4 liquidation library` overstates what its assertion establishes: unequal hashes do not demonstrate a V3 link when the expected hash was normalized incorrectly. The current link references support V4 linkage, not basename confusion. A stale or different historical artifact remains unexcluded because the failed deployment's bytes were not supplied.

## Cause C: a reverting reentrancy probe has no reliable outcome assertion (case 7; qualified)

**Test:** `BalancerV3UniswapV4CoordinatorRouter_LedgerAndRescue_Test.test_T31_reentrancyDuringPullIsLocked`.

**Source observation.** The test registers a fake router at `0xBEEF`, supplies empty step data, catches every outer-call error without inspecting it, and then requires a `SawIsLocked` event in recorded logs. Its own comment says the outer call reverts and token storage rolls back: `test/foundry/spec/routers/balancerV3-uniswapV4/BalancerV3UniswapV4CoordinatorRouter_LedgerAndRescue.t.sol:98-140`.

**Source observation.** The hostile token calls the nested query during `transferFrom` and emits `SawIsLocked` only if that call returns the expected error selector: the same file, `:227-252`. The outer swap enters `nonReentrant` before validation and Permit2 pull, and executes the route afterward: `contracts/routers/balancerV3-uniswapV4/targets/BalancerV3UniswapV4CoordinatorRouterExactInTarget.sol:37-48`, `:67-79`. The query enters the same modifier before its own validation: `contracts/routers/balancerV3-uniswapV4/targets/BalancerV3UniswapV4CoordinatorRouterQueryTarget.sol:28-34`. That modifier checks and sets the same transient lock; the guard reverts with `IsLocked`: `lib/crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol:21-29`; `lib/crane/contracts/access/reentrancy/ReentrancyLockRepo.sol:30-31`, `:62-64`, `:83-98`.

**Source observation.** The route validator checks approval and basic parameters but does not decode the adapter data. The later StockBalancer adapter unconditionally ABI-decodes that data as a six-field tuple: `contracts/routers/balancerV3-uniswapV4/common/BalancerV3UniswapV4CoordinatorRouterCommon.sol:44-68`; `contracts/routers/balancerV3-uniswapV4/adapters/StockBalancerV3RouterAdapter.sol:12-24`. Empty step data therefore supplies an explicit later failure path even if the pull and nested lock check work.

**Inference.** The likely issue is the test's observation strategy: it attempts to prove a successful lock rejection using an event inside an outer operation deliberately made to revert. The source guard is present on both entries, so the absent recorded event is not evidence of a missing shared lock. However, the supplied assertion alone cannot distinguish discarded reverted-call logs from an earlier outer failure before token callback, or a different nested error. Since the test swallows the outer error, the brief loses that information at `...LedgerAndRescue.t.sol:130`.

**Unverified.** Whether this Foundry runtime retained or discarded the inner event, and whether the hostile callback was reached in the failed run. The local interface documents transaction-log recording, but not reverted-subcall retention: `lib/crane/lib/forge-std/src/Vm.sol:722-726`, `:764-765`. I therefore classify this case as a qualified harness diagnosis, not a proved Foundry regression or production reentrancy failure. A trace or the discarded outer error would be required to name the exact runtime stopping point.

## Cause D: raw proportional preview skips execution's rate-rounding path (case 9)

**Test:** `MultiWeightedFundedStakingTest.test_primaryBurnUsesOwnedLpAndPreservesExternalLiquidity`.

**Source observation.** The test deploys a two-leg rated reserve, claims burn principal, admits real external liquidity, and passes the preview quote as an exact minimum on the burn: `test/foundry/spec/vaults/detf/common/claimToken/MultiWeightedFundedStaking.t.sol:262-273`; `contracts/test/bases/FundedPrimaryRouteAssertions.sol:115-140`. The `rated_` flag populates rate assets, and the package installs rate providers and `WITH_RATE` token configuration: `contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/TestBase_MultiVaultWeightedDetf.sol:270-281`, `:327-346`; `contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfDFPkg.sol:378-384`, `:451-459`.

**Source observation.** The primary preview computes a BPT slice and calls `_previewBptUnwind`. That function returns a single raw-balance division, `floor(rawBalance * lp / totalBptSupply)`: `contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfExchangeQueryTarget.sol:23-32`; `contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfCommon.sol:202-205`, `:444-449`.

**Source observation.** Execution withdraws the protocol-owned BPT proportionally through the real prepay router, selects the requested share leg, rejoins the others, and rejects if received output is below the preview-derived minimum: `contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfExchangeOutTarget.sol:13-31`; `contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfCommon.sol:349-364`; `contracts/protocols/dexes/balancer/v3/routers/prepay/BalancerV3StandardExchangeRouterPrepayTarget.sol:143-167`; `contracts/protocols/dexes/balancer/v3/routers/prepay/BalancerV3StandardExchangeRouterPrepayHooksTarget.sol:146-166`.

**Source observation.** Balancer removal loads balances with round-down, computes proportional output in live scaled units, and rounds down again when converting back through decimal factors and rates: `lib/crane/contracts/protocols/dexes/balancer/v3/vault/diamond/facets/VaultLiquidityFacet.sol:192-209`, `:372-377`, `:440-447`. The proportional formula and scale/unscale operations are explicit at `lib/crane/contracts/external/balancer/v3/vault/contracts/BasePoolMath.sol:101-106` and `lib/crane/contracts/external/balancer/v3/solidity-utils/contracts/helpers/ScalingHelpers.sol:38-43`, `:74-81`.

**Inference.** The DETF preview removes the intermediate floors imposed by rated execution. In symbolic terms, with raw balance `B`, rate/scale multiplier `r`, BPT slice `L`, and BPT supply `S`, the preview uses `floor(B*L/S)` while the scaled execution can perform `floor(floor(floor(B*r)*L/S)/r)`. These are not generally equal. Losing one native share wei on conversion is consistent with the supplied `MinAmountNotMet` discrepancy. Because the test uses the preview as the minimum, the disagreement becomes a revert before the later external-LP-preservation assertions.

This is a concrete production preview/execution mismatch candidate, not evidence that external LP was spent or that the widened exchange-in tuple was decoded as its refund word: the shared assertion reads the first preview word and the first execution word at `contracts/test/bases/FundedPrimaryRouteAssertions.sol:124-139`. Exact balance, rate, and BPT operands were not supplied, so I have not numerically reproduced the reported one-wei difference.

## Overall assessment

The strongest source-supported grouping is 17 tests affected by the documented intra-test timestamp hazard, one hash-normalization assertion incompatible with the observed library artifact, one rated preview/execution rounding mismatch, and one qualified router-observation failure. These are four cause groups with materially different confidence, not 20 independent production regressions. Their evidence and qualifications are the preceding case-by-case source chains.

No separate exchange-in tuple-migration or FS-HOOK-04 explanation is needed to account for the concrete paths above. This does not rule out unrelated defects; it means neither migration nor that record was adopted as a cause without source evidence.

# Limits

- This response does not authorize implementation.
- No tests were run. The diagnoses do not claim that any proposed change has made the suite green.
- The precise callback/log behavior for case 7 remains unresolved from the supplied assertion and admitted source alone. Its likely harness cause must not be promoted to a confirmed engine or lock defect.
- Timestamp reuse is strongly supported by local API documentation and the error arithmetic, but compiler instruction reuse in the failed test binaries was not independently measured.
- The current artifact establishes case 5's incompatible normalization assumption; it does not prove which immutable bytes were present in the historical failing deployment.
- Case 9's formulas differ, but the complete numerical trace needed to reproduce exactly one wei was not supplied.
- Source and artifact reads were from a live shared workspace, not an atomic snapshot. No Git provenance or runtime build identity was collected.
- Only this member's assigned response file was written. No implementation, configuration, peer artifact, or coordinator artifact was modified.
