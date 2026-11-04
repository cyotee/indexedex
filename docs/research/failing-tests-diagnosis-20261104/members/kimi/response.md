# Identity

- Member: kimi
- Profile: research
- Phase: initial independent response
- Role: council-member
- Requested model and reasoning: kimi-coding/k3.1-pro:high, global route
- Runtime identity exposed by Native: not exposed
- Peers read before submission: no

# Question and targets

The question is the cause of each of the 20 failures supplied in `docs/research/failing-tests-diagnosis-20261104/brief.md:80-92`, with shared causes grouped and source observation distinguished from inference. The targets are the 10 named test files and the production or test helpers their assertions and failure messages implicate. This is static diagnosis of supplied runtime, not a fresh test run.

# Evidence

## 1. `test_D89_ownerDepositSingle_atMin_whileUnlocked`

**Source observation.** The test transfers ownership before it encodes the `depositSingle` call, then supplies `block.timestamp + 1 hours` as the deadline (`test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_OwnerDuringLock.t.sol:191-216`, `:227-237`). The current deposit path checks that supplied deadline and permits the owner at minimum liquidity (`contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookDepositCommon.sol:225-235`, `:254-256`, `:686-700`). Its nested SE settlement uses the then-current `block.timestamp`, not the earlier ownership-transfer timestamp (`contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookDepositCommon.sol:287-315`).

**Inference.** The immediate supplied-runtime cause was an expired deadline in the code that actually executed, but the current call chain does not supply an expired value. The bare `DeadlineExpired()` does not identify which nested call reverted. A different runtime, or runtime state not represented by the current call chain, is required to explain the supplied failure; assigning it to the ownership-transfer warp would contradict the test's later deadline encoding.

## 2-4. `invariant_APEX_accounting`, `test_APEX_deterministicLifecycle`, and `test_APEX_loopAccruedFiveCycleRegression`

**Source observation.** All three reach the same `maintain` helper. It warps forward by 3601 seconds, successfully calls `rebalance`, then expects a second call to revert with `RebalanceTooSoon(block.timestamp + 1 hours)` (`test/foundry/spec/protocol/lending/aave/cross-version/invariant/AaveCrossVersionLoop_Invariant.t.sol:243-280`, `:314-337`). Current production computes `nextAllowed` from stored `lastRebalanceTimestamp` and writes `block.timestamp` back to that field after every successful rebalance (`contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopRebalanceTarget.sol:72-90`; `contracts/protocols/lending/aave/cross-version/LoopPositionRepo.sol:79-85`).

**Inference.** Interpreting the supplied `RebalanceTooSoon(7202) != RebalanceTooSoon(3601)` as expected-versus-actual, the executed second call computed 3601 from a stale stored timestamp of 1 rather than from the first successful call at 3602. Thus the immediate runtime failure was failure to persist or read the first rebalance timestamp. Current source explicitly persists it, so the supplied result is inconsistent with the current implementation rather than evidence of a present missing setter. The three tests share this helper-level cause, not three independent accounting defects.

## 5. `test_setUp_linksV4SpokeDespiteNamesakeArtifact`

**Source observation.** The assertion compares the linked library's runtime codehash against the V4 artifact and separately rejects equality with V3 (`test/foundry/spec/protocol/lending/aave/cross-version/invariant/AaveCrossVersionLoop_Invariant.t.sol:114-137`). The fixture loads `SpokeInstance` through `ArtifactCreationCode` (`contracts/test/bases/TestBase_AaveCrossVersionLoopV4Market.sol:77-90`). That linker derives each library identity from its full source path and contract name, deploys by the hash of that identity, and patches its references (`contracts/utils/foundry/ArtifactCreationCode.sol:87-112`). It also documents that an occupied CREATE3 identity is reused without a code-equivalence check (`contracts/utils/foundry/ArtifactCreationCode.sol:40-44`). Spoke's source returns the address of its imported V4 `LiquidationLogic` (`lib/crane/contracts/protocols/lending/aave/v4/spoke/Spoke.sol:21`, `:639-642`).

**Inference.** The immediate failure was that the address returned at runtime did not contain the V4 runtime bytecode expected by the test. The current source-qualified link path is specifically intended to prevent a V3/V4 basename substitution, so the message alone does not establish that substitution in the current code. A wrong pre-linked artifact, an already occupied identity, or different runtime bytecode remains possible; the supplied hash mismatch cannot distinguish them.

## 6. `test_notify_while_totalSupply_zero_empty_period_not_credited`

**Source observation.** The test notifies for seven days with zero supply, warps one day, stakes, checks that the empty day was not credited, then expects approximately 100e18 after the next day (`test/foundry/spec/protocols/staking/token/TokenStaking.t.sol:287-320`; the seven-day duration is also asserted at `:298`). Current `stake` calls `_updateReward` before increasing supply (`contracts/protocols/staking/token/TokenStakingTarget.sol:149-160`). `_updateReward` advances `lastUpdateTime` only to the applicable reward time, while `rewardPerToken` returns the stored value during zero supply and subsequently accrues from that updated timestamp (`contracts/protocols/staking/token/TokenStakingTarget.sol:108-130`, `:399-405`).

**Inference.** The supplied zero after the second day means the runtime did not preserve and then accrue the post-stake day as this sequence requires. Possible mechanisms include an incorrect `lastUpdateTime` or per-user checkpoint in the executed code; the message does not distinguish them. Current source contains the required zero-supply checkpoint ordering, so a unique current-code cause cannot be assigned.

## 7. `test_T31_reentrancyDuringPullIsLocked`

**Source observation.** The hostile token emits `SawIsLocked` only if its nested `queryExactIn` both executes and reverts with `IsLocked`; the outer test catches every outer error and then searches logs (`test/foundry/spec/routers/balancerV3-uniswapV4/BalancerV3UniswapV4CoordinatorRouter_LedgerAndRescue.t.sol:100-143`, `:225-267`). Current outer swap and nested query both carry the same `nonReentrant` modifier, and the pull occurs inside the outer locked function (`contracts/routers/balancerV3-uniswapV4/targets/BalancerV3UniswapV4CoordinatorRouterExactInTarget.sol:37-48`, `:62-76`; `contracts/routers/balancerV3-uniswapV4/targets/BalancerV3UniswapV4CoordinatorRouterQueryTarget.sol:28-34`). The modifier rejects a locked call before executing its body (`lib/crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol:20-28`).

**Inference.** Absence of the event has two materially different possible causes: the nested query succeeded because a lock was absent in the executed runtime, or the outer call reverted before the hostile `transferFrom` callback and the test swallowed that earlier error. The supplied message cannot choose between them. Current source has both locks, so it does not support a present missing-lock diagnosis; a trace of the swallowed outer revert is necessary for a unique cause.

## 8. `test_twoBondEscrowsCloseWithoutRetiringEachOthersFraction`

**Source observation.** After two half-lock claims of bond `a`, the test expects `ownerOf(a_) == address(0)` while bond `b` remains unchanged (`test/foundry/spec/vaults/detf/common/claimToken/FundedStakingSequence.t.sol:132-148`). Current claim math makes the full principal vested at maturity (`contracts/vaults/detf/common/core/DETFFundedStakingMath.sol:85-108`). Current retirement requires both full principal repayment and a residual `stakingGons` smaller than the current gons-per-unit divisor, then retires that fraction and burns the NFT (`contracts/vaults/detf/common/bondNft/DETFFundedBondTarget.sol:163-198`).

**Inference.** Because the supplied owner remains after the mature claim, the executed runtime either did not mark the principal fully claimed or retained at least one whole native unit of residual gons and failed the retirement predicate. Current claim-and-debit logic is intended to leave only the sub-native fraction, so the supplied owner result is not reproduced by that logic. The other bond's unchanged fraction is not the failing part of the supplied assertion.

## 9. `test_primaryBurnUsesOwnedLpAndPreservesExternalLiquidity`

**Source observation.** The helper previews the burn, passes that exact quote as `minimum_`, and execution reverts if `received_ < minimum_` (`contracts/test/bases/FundedPrimaryRouteAssertions.sol:115-140`; `contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfExchangeOutTarget.sol:13-31`). The test deliberately deploys with `rated_ = true` (`test/foundry/spec/vaults/detf/common/claimToken/MultiWeightedFundedStaking.t.sol:262-273`); rated deployment creates rate providers and registers those pool tokens as `WITH_RATE` (`contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfDFPkg.sol:378-385`, `:453-459`). However, `_previewBptUnwind` computes `rawShareBalance * lp / bptSupply` directly (`contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfCommon.sol:444-451`). Actual Balancer execution computes the exit over `balancesLiveScaled18` and then converts the result back to raw units with `toRawUndoRateRoundDown` (`lib/crane/contracts/external/balancer/v3/vault/contracts/Vault.sol:833-838`, `:910-921`).

**Inference.** This is a current-source preview/execution mismatch. The preview omits the rate-aware scaled-18 and raw-conversion rounding path used by the actual rated pool, so it can quote one wei more than execution delivers; using that over-quote as the exact minimum produces the supplied `MinAmountNotMet`. The one-wei direction and the rated fixture make this the best-supported source-level diagnosis among the 20.

## 10. `test_halfwayClaimPaysFundedStakingAndFullClaimRetiresBond`

**Source observation.** The same expected value, 475000000000, can occur at the halfway principal assertion, the recipient staking-balance assertion, or the final remaining-principal assertion (`test/foundry/spec/vaults/detf/common/claimToken/RebasingClaimTokenDFPkg_Deploy.t.sol:176-195`). Current math pays half at halfway and the remainder at maturity (`contracts/vaults/detf/common/core/DETFFundedStakingMath.sol:85-108`). Current bond claiming transfers the sum of principal and rewards to the recipient (`contracts/vaults/detf/common/bondNft/DETFFundedBondTarget.sol:163-187`), and current staking transfer moves the corresponding gons to that recipient (`contracts/vaults/detf/common/claimToken/DETFFundedStakingRepo.sol:150-164`).

**Inference.** The supplied `0 != 475000000000` has no assertion locator, so it does not prove whether the runtime returned zero principal, failed to credit the recipient, or returned zero on the final claim. Those are different causes. Each corresponding current path contains behavior inconsistent with a zero result; a trace or exact assertion line is required rather than selecting one arbitrarily.

## 11-18. Eight `test_standardFallbackSettlesFundedCatchupBeforeBothDirections` variants

**Source observation.** The shared test funds premium, warps 25 hours, consumes the first due expansion through a fallback exchange, funds and warps again, then requires `pendingExpansionDetf() > 0` for later epochs (`test/foundry/spec/vaults/detf/common/claimToken/V4ReserveLiquidity.t.sol:124-136`). The funding helper checks that its actual lead-leg price clears the mint threshold (`test/foundry/spec/vaults/detf/common/claimToken/V4ReserveLiquidity.t.sol:181-222`). Current pending quotes return zero when no epoch completed, supply is zero, price does not exceed both peg and threshold, or the computed amount is dust (`contracts/vaults/detf/common/core/DETFEpochNaturalExpansionLib.sol:33-48`; `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol:308-325`, `:371-375`). Current realization advances the anchor by all completed eight-hour boundaries, not directly to `block.timestamp` (`contracts/vaults/detf/common/core/DETFEpochNaturalExpansionLib.sol:50-63`).

**Inference.** The shared immediate failure is a zero pending quote at the second assertion, but the message alone does not distinguish an over-advanced runtime anchor from price/dust ineligibility. Current boundary arithmetic leaves the post-settlement remainder intact and should permit later epochs after another 25-hour warp. All eight variants therefore share one helper/runtime mismatch, not eight independent reserve-math causes. The affected classes are `CpPublicReserveLiquidityTest`, `CpReserveLiquidityTest`, `CurveQuadPublicReserveLiquidityTest`, `CurveQuadReserveLiquidityTest`, `OrbitalPublicReserveLiquidityTest`, `OrbitalReserveLiquidityTest`, `WeightedPublicReserveLiquidityTest`, and `WeightedReserveLiquidityTest`, as enumerated in `docs/research/failing-tests-diagnosis-20261104/brief.md:90`.

## 19-20. Two `test_claimAfterMatureClose_matchesProjection` variants

**Source observation.** Both leaf tests delegate to the same helper (`test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Quad_MorphoBlueSe.t.sol:84-87`; `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Quad_Univ3Se.t.sol:84-87`). The helper uses fresh `block.timestamp + 1 hours` deadlines for the initial mint and burn (`contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Quad_ProdSe.sol:404-415`). The mature-claim helper warps to maturity, and the later unstake again computes a fresh deadline after that warp (`contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol:427-451`, `:462-469`).

**Inference.** `DeadlineExpired(3601)` is consistent with reuse of an initial one-hour deadline after the maturity warp under the coordinator-supplied timestamp-1 context, but the current helper recomputes later deadlines and does not reuse 3601. Both variants therefore share an expired-deadline runtime path that is not present in the current helper chain. The supplied error alone cannot identify which nested call retained the old value.

# Assumptions

- The 20 messages are treated strictly as supplied runtime from `docs/research/failing-tests-diagnosis-20261104/brief.md:76-94`; no successful local reproduction is assumed.
- The timestamp-1 convention is coordinator-supplied context, used only to interpret numeric values such as 3601 and 7202, not treated as independently proven for any test.
- Where current source contradicts the supplied result, I infer a runtime/source discrepancy or missing runtime evidence. I do not infer a particular stale commit, because no Git history or execution trace was admitted.
- For the Aave mismatch, I use Foundry's expected-versus-actual reading stated explicitly as an interpretation; reversing that ordering would change the inferred stored-timestamp direction.

# Coverage

| Numbers | Test or shared variant | Diagnosis status |
| --- | --- | --- |
| 1 | `test_D89_ownerDepositSingle_atMin_whileUnlocked` | Expired runtime deadline; current arguments do not expire |
| 2 | `invariant_APEX_accounting` | Shared stale-runtime rebalance timestamp |
| 3 | `test_APEX_deterministicLifecycle` | Same as 2 |
| 4 | `test_APEX_loopAccruedFiveCycleRegression` | Same as 2 |
| 5 | `test_setUp_linksV4SpokeDespiteNamesakeArtifact` | Runtime library codehash mismatch; exact wrong-link stage unresolved |
| 6 | `test_notify_while_totalSupply_zero_empty_period_not_credited` | Runtime reward checkpoint failure; current ordering conflicts |
| 7 | `test_T31_reentrancyDuringPullIsLocked` | Missing nested rejection or swallowed earlier outer revert |
| 8 | `test_twoBondEscrowsCloseWithoutRetiringEachOthersFraction` | Runtime retirement predicate did not burn; current dust path conflicts |
| 9 | `test_primaryBurnUsesOwnedLpAndPreservesExternalLiquidity` | Rated Balancer preview omits execution rounding path |
| 10 | `test_halfwayClaimPaysFundedStakingAndFullClaimRetiresBond` | Zero location ambiguous; current claim and transfer paths conflict |
| 11 | `CpPublicReserveLiquidityTest.test_standardFallbackSettlesFundedCatchupBeforeBothDirections` | Shared later-epoch zero quote |
| 12 | `CpReserveLiquidityTest.test_standardFallbackSettlesFundedCatchupBeforeBothDirections` | Same as 11 |
| 13 | `CurveQuadPublicReserveLiquidityTest.test_standardFallbackSettlesFundedCatchupBeforeBothDirections` | Same as 11 |
| 14 | `CurveQuadReserveLiquidityTest.test_standardFallbackSettlesFundedCatchupBeforeBothDirections` | Same as 11 |
| 15 | `OrbitalPublicReserveLiquidityTest.test_standardFallbackSettlesFundedCatchupBeforeBothDirections` | Same as 11 |
| 16 | `OrbitalReserveLiquidityTest.test_standardFallbackSettlesFundedCatchupBeforeBothDirections` | Same as 11 |
| 17 | `WeightedPublicReserveLiquidityTest.test_standardFallbackSettlesFundedCatchupBeforeBothDirections` | Same as 11 |
| 18 | `WeightedReserveLiquidityTest.test_standardFallbackSettlesFundedCatchupBeforeBothDirections` | Same as 11 |
| 19 | MorphoBlue `test_claimAfterMatureClose_matchesProjection` | Shared reused/expired runtime deadline; current helper conflicts |
| 20 | Univ3 `test_claimAfterMatureClose_matchesProjection` | Same as 19 |

# Conclusions

1. **One concrete current-source cause: test 9.** `test_primaryBurnUsesOwnedLpAndPreservesExternalLiquidity` uses a raw proportional preview for a rated Balancer exit, while execution performs scaled-18 math and rate-aware raw conversion. The resulting over-quote is used as an exact minimum, explaining the one-wei `MinAmountNotMet` (`contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfCommon.sol:444-451`; `lib/crane/contracts/external/balancer/v3/vault/contracts/Vault.sol:833-838`, `:915-918`).

2. **Shared immediate mechanisms, but not verifiable current-source causes: the other 19 tests.** Tests 2, 3, and 4 share stale rebalance-timestamp behavior; tests 19 and 20 share a reused expired deadline; tests 11-18 share a later-epoch eligibility/zero-quote failure. Tests 8 and 10 both concern funded-bond payout/retirement but the supplied messages do not establish one common code defect. Tests 1, 5, 6, and 7 have individual immediate mechanisms described in Evidence. In every one of these cases, current source contains control flow that conflicts with the supplied outcome. It would be unsupported to label all 19 a single product bug or to claim a specific stale artifact as fact.

3. **Required evidentiary next step for those 19, not an implementation proposal.** A trace from the exact failing runtime is needed to map each message to the executed facet/library and assertion. In particular, test 7 needs the swallowed outer revert and test 10 needs the exact failing assertion line. Until then, the defensible diagnosis is the per-test immediate mechanism above plus a runtime/current-source mismatch, not an invented edit target.

This response does not authorize implementation.

# Limits

I did not run Forge, Git, installs, deploys, or sub-agents, and did not read peer responses or other members' files. I did not edit project code. The only artifact written is this response. The supplied runtime has no traces, assertion column numbers, deployed addresses beyond the messages, or before/after state dumps. Consequently, the source-level cause is strong for test 9 but the exact historical/runtime cause cannot be uniquely recovered for the other 19 from the admitted evidence.
