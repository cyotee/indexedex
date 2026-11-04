# Member response — failing-tests-diagnosis-20261104

## Identity

| Field | Value |
| --- | --- |
| Member | minimax |
| Profile | research |
| Phase | initial independent response |
| Requested role | council-member |
| Requested model | minimax/MiniMax-M3 |
| Reasoning setting | adaptive thinking — admitted by the brief; not a selectable depth |
| Runtime identity (task id / conversation id / model self-report) | not exposed |

I did not read any peer response, any other member's file, the coordinator draft, the
run record, or the final report. I read only the brief, the ten named test files,
and the production/test code those files point at.

## Question and targets

Question (from `docs/research/failing-tests-diagnosis-20261104/brief.md`): what caused each of the 20
failing tests listed under "Supplied runtime", grouping failures that share one cause, separating
source observation from inference, without proposing an implemented edit.

Targets: the 20 named tests, plus the production or test code each failure message points at.
Admitted read scope was the named test files, the contracts and helpers they call, and the brief.

Method actually used: static reading only. No `forge`, no `forge test`, no `forge script`, no Git
operation, no install, no deploy, no sub-agent, no file outside the admitted scope other than the
listed production/test files. Every line citation below is a path plus a line number in the working
tree I read.

Evidence convention used throughout:

- **Observation** — something the cited source states, or arithmetic performed on values the cited
  source defines.
- **Inference** — my explanation of the cited observation, not itself stated in the source.

## Evidence

### E1 — CP single-SE hook, owner `depositSingle` during an open PoolManager unlock

Test: `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_OwnerDuringLock.t.sol:191-215`.

- Observation: the harness enters the PoolManager with `pm.unlock(...)` (`:28-30`) and calls the
  hook through `unlockCallback` → `target.call(data)` (`:32-46`).
- Observation: the encoded call is `IHook.depositSingle.selector` with
  `(address(pairToken), 50 ether, address(harness), uint256(0), block.timestamp + 1 hours)` (`:204-213`).
- Observation: the interface declares
  `depositSingle(address tokenIn, uint256 amountIn, address to, uint256 minLpAmount, uint256 deadline)`
  (`contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHook.sol:107`),
  and the production entry point has the same five parameters
  (`contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookDepositSingleTarget.sol:64-73`).
  `abi.encodeWithSelector` therefore decodes into the production parameters exactly as written.
- Observation: the production path is `PullLib.pullErc20Single` → `_depositSingle`
  (`...HookDepositSingleTarget.sol:71-72`), and `_depositSingle`
  (`contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookDepositCommon.sol:686-704`)
  calls `_requireDeadline(deadline)` at `:690`, which is
  `if (block.timestamp > deadline) revert DeadlineExpired();` (`:254-256`).
- Observation: the deadline the test supplies is computed at `:212` in the same block as the call,
  so it is `block.timestamp + 3600` and cannot be expired at `:690`.
- Observation: the same no-argument `DeadlineExpired()` is declared in five files of this family:
  `...HookDepositCommon.sol:77` (raised `:255`), `...HookWithdrawTarget.sol:81` (raised `:240`),
  `...HookTarget.sol:85` (raised `:241`), `...HookSeTarget.sol:77` (raised `:331`),
  `...HookWithdrawalLib.sol:17` (raised `:29`).
- Observation: the only deadline-bearing nested call I could find that is *not* the `depositSingle`
  argument is `Withdrawal.withdrawFrom(..., deadline)`
  (`...HookWithdrawalLib.sol:26-29`), which is reached from the withdrawal and redeem paths
  (`...HookInExecutionBase.sol:44-48`, `...HookDepositSingleTarget.sol:42-46`), not from the
  deposit path.
- Inference: the reported `DeadlineExpired()` was not raised against the deadline the test passes;
  it was raised by a nested call that carries a different deadline argument. Because five
  identical error declarations exist, the raising frame cannot be named from source alone.

### E2 — Aave cross-version loop, anti-churn rebalance rejection (tests 2, 3, 4)

Test: `test/foundry/spec/protocol/lending/aave/cross-version/invariant/AaveCrossVersionLoop_Invariant.t.sol`.

- Observation: `maintain()` warps the clock by `block.timestamp + 1 hours + 1` (`:320`), calls
  `rebalance()` once (`:324`), then asserts the next `rebalance()` reverts with
  `abi.encodeWithSelector(RebalanceTooSoon.selector, block.timestamp + 1 hours)` (`:329-333`) and
  calls `rebalance()` again (`:334`).
- Observation: the production error argument is the *last successful rebalance* plus the cooldown,
  not the current time:
  `uint256 nextAllowed = LoopPositionRepo._lastRebalanceTimestamp() + MIN_REBALANCE_INTERVAL;`
  (`contracts/protocols/lending/aave/cross-version/AaveCrossVersionLoopRebalanceTarget.sol:73-74`),
  with `MIN_REBALANCE_INTERVAL = 1 hours` (`:29`) and
  `LoopPositionRepo._setLastRebalanceTimestamp(block.timestamp)` on success (`:90`).
- Observation: the getter and setter read and write the same field of the same slot
  (`contracts/protocols/lending/aave/cross-version/LoopPositionRepo.sol:17-18, 33, 79-85`).
- Observation: the two reported numbers, 7202 and 3601, differ by exactly 3601 s, which is exactly
  the warp step at `:320`. 3601 = 1 + 3600 (anchor 1, the pre-warp timestamp) and
  7202 = 3602 + 3600 (anchor 3602, the post-warp timestamp).
- Observation: the test's expectation is `block.timestamp + 1 hour`, i.e. anchored on the current
  block. The production's expectation is anchored on `lastRebalanceTimestamp`. The two coincide only
  when the previous successful rebalance happened in the current block.
- Inference: the anchor actually read by the second `rebalance()` was one warp-step behind the
  `block.timestamp` the test used. Because the setter (`:90`) and getter (`:79-81`) share one
  field, the only way to observe that gap is that the anchor written by the successful rebalance
  at `:324` was not the value read at `:334`. Whether that is a rolled-back write, a different
  vault instance, or an anchor that was already at a different value needs a trace of the two
  `rebalance()` calls.
- Observation: the same mismatch aborts all three named tests, because
  `test_APEX_deterministicLifecycle` (`:274-281`) and
  `test_APEX_loopAccruedFiveCycleRegression` (`:264-272`) both end in `afterInvariant()` (`:248-262`),
  and `invariant_APEX_accounting` (`:243-246`) is itself invoked from `afterInvariant()` (`:262`).

### E3 — Aave cross-version loop, V4 spoke liquidation-library link (test 5)

Test: `test/foundry/spec/protocol/lending/aave/cross-version/invariant/AaveCrossVersionLoop_Invariant.t.sol:115-125`.

- Observation: the failing comparison is `assertEq(linkedHash, _artifactRuntimeHash(_V4_LIQUIDATION_ARTIFACT, linked), ...)`
  at `:121`.
- Observation: the spoke binds the V4 library by source import —
  `import {LiquidationLogic} from "@crane/contracts/protocols/lending/aave/v4/spoke/libraries/LiquidationLogicAaveV4.sol";`
  (`lib/crane/contracts/protocols/lending/aave/v4/spoke/Spoke.sol:21`) — and
  `getLiquidationLogic()` returns `address(LiquidationLogic)` (`:640-642`).
- Observation: `_artifactRuntimeHash` (`:132-142`) reads `.deployedBytecode.object` from the
  artifact JSON and overwrites the twenty bytes following the **first** `0x73` (PUSH20) opcode
  with the linked address (`:136-141`). A library runtime normally carries more than one PUSH20
  (its own address plus any immutable address constants), so the patch is applied to an arbitrary
  PUSH20 rather than provably to the library's own address slot.
- Observation: `_artifactPath` (`:144-167`) resolves the artifact to
  `out/<file>/<name>.json`, i.e. it depends on the build output tree being present and current.
- Observation: the brief's second message, "two bytecode hashes differ", does not occur in
  `contracts/`, `test/` or `lib/crane/contracts/` (searched); it is not a repository assertion
  message, and I could not localize it.
- Inference: the assert at `:121` compares a reconstructed hash with the on-chain `codehash`. The
  reconstruction heuristic at `:136-141` can produce a mismatch even when the linked library is the
  correct V4 one, and the source import at `Spoke.sol:21` shows it is the V4 library. The failing
  assertion is therefore consistent with a test-side artifact-reconstruction/stale-`out/` problem
  rather than with the spoke linking the V3 namesake. The discriminating check is to compare
  `linked.codehash` with `keccak256(<artifact .deployedBytecode.object>)` and with the same value
  rebuilt after `forge build`.

### E4 — Token staking, reward notified while `totalSupply == 0` (test 6)

Test: `test/foundry/spec/protocols/staking/token/TokenStaking.t.sol:306-321`; the failing
assertion is the last one, `assertApproxEqAbs(staking.earned(stakerA), 100e18, 1e5)` at `:320`,
with actual 0.

- Observation: `earned()` is `balanceOf[account] * (rewardPerToken() - userRewardPerTokenPaid[account]) / WAD + rewards[account]`
  (`contracts/protocols/staking/token/TokenStakingTarget.sol:126-131`).
- Observation: `rewardPerToken()` returns `rewardPerTokenStored` unchanged when
  `layoutStruct.totalSupply == 0` (`:116-124`, early return `:118-120`); otherwise it adds
  `(lastTimeRewardApplicable() - lastUpdateTime) * rewardRate * WAD / totalSupply` (`:121-123`).
- Observation: `stake()` runs `_updateReward` (`:155`) **before** `totalSupply += amount` (`:156`)
  and `balanceOf[msg.sender] += amount` (`:157`).
- Observation: `notifyRewardAmount` sets `rewardRate = reward / rewardsDuration` when
  `block.timestamp >= periodFinish` (`:217-218`), then `lastUpdateTime = block.timestamp` (`:224`)
  and `periodFinish = block.timestamp + rewardsDuration` (`:225`); `reward == 0` reverts
  (`:212-214`).
- Observation: `rewardsDuration` is `7 days` in the test base
  (`contracts/protocols/staking/token/TestBase_TokenStaking.sol:106`).
- Observation: arithmetic on those definitions. Notify at t = 1 with 700e18 over 604800 s gives
  `rewardRate = 700e18 / 604800`. The stake at t = 86401 leaves `rewardPerTokenStored = 0` (the
  supply was still 0 inside `_updateReward`) and `lastUpdateTime = 86401`. At t = 172801 the
  accrual term is `86400 * rewardRate * 1e18 / 100e18`, giving `rewardPerToken() = 1e18` and
  `earned = 100e18 * 1e18 / 1e18 = 100e18` — exactly the expected value at `:320`.
- Inference: the observed 0 therefore cannot come from `rewardRate == 0`: `rewardRate` is
  `reward / rewardsDuration` with `reward != 0` (else `AmountZero`, `:212-214`) and
  `rewardsDuration == 7 days`, so a zero rate is impossible without a revert, and no revert was
  observed. The only remaining producer of 0 is the early return at `:118-120`, i.e.
  `TokenStakingRepo.totalSupply == 0` at the assertion, or an empty accrual window because
  `lastUpdateTime` already equals the assertion timestamp. Equivalently: the 100e18 stake did not
  enter the staking package's accounting, or the second `vm.warp` at `TokenStaking.t.sol:319`
  did not advance the clock past the stake at `:313-315`. A trace of `rewardRate()`,
  `TokenStakingRepo.totalSupply` and `lastUpdateTime()` immediately after the stake settles it.

### E5 — Balancer V3 / Uniswap V4 coordinator router, reentrancy during pull (test 7)

Test: `test/foundry/spec/routers/balancerV3-uniswapV4/BalancerV3UniswapV4CoordinatorRouter_LedgerAndRescue.t.sol:99-141`.

- Observation: the hostile token re-enters `queryExactIn` inside `transferFrom` and emits
  `SawIsLocked()` only if the nested call reverted with `IReentrancyLock.IsLocked.selector`
  (`:237-256`, selector test `:249-252`, emit `:252`).
- Observation: `queryExactIn` is `nonReentrant`
  (`contracts/routers/balancerV3-uniswapV4/targets/BalancerV3UniswapV4CoordinatorRouterQueryTarget.sol:28-32`)
  and `swapExactInWithPermit` is `nonReentrant`
  (`.../BalancerV3UniswapV4CoordinatorRouterExactInTarget.sol:37-41`); the coordinator inherits
  `ReentrancyLockModifiers` (`contracts/routers/balancerV3-uniswapV4/common/BalancerV3UniswapV4CoordinatorRouterCommon.sol:22`).
- Observation: the lock is transient storage keyed by
  `ReentrancyLockRepo.STORAGE_SLOT` (`lib/crane/contracts/access/reentrancy/ReentrancyLockRepo.sol:30-31`),
  set by `_lock` (`:62-64`) and guarded by `_onlyUnlocked`, which throws `IReentrancyLock.IsLocked`
  (`:89-95`). Both facets of the same diamond share that slot.
- Observation: the test records logs (`:128`), swallows the outer failure with
  `try … catch {}` (`:130`) and reads them back (`:131`), asserting the `SawIsLocked()` topic
  (`:132-140`). The test's own comment at `:127` states "Outer call reverts (fake child),
  rolling back token storage — observe via event logs."
- Observation: the registered step router is `address(0xBEEF)` (`:116-117`), which has no code, so
  the router dispatch cannot produce a decodable return value and the outer call reverts.
- Inference: the nested `queryExactIn` does revert with `IsLocked`, so `SawIsLocked()` is emitted
  — but the emission happens inside the coordinator's call frame, which then reverts. The
  `SawIsLocked` topic is therefore absent from `vm.getRecordedLogs()` and `:140` fails. The one
  unverified assumption here is Foundry's `recordLogs` retention semantics for a reverted frame;
  the test's own comment at `:127` assumes the logs survive.

### E6 — Funded bond escrows: two bonds closing independently (test 8)

Test: `test/foundry/spec/vaults/detf/common/claimToken/FundedStakingSequence.t.sol:132-150`.

- Observation: `detfUser` is `address(0xD37F)`
  (`contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol:110`), so the
  reported actual `0xd37f` is the bond's current holder and the failing comparison is a
  "not retired" comparison: `assertEq(bonds_.ownerOf(a_), address(0))` at `:143` (or `:147` for
  bond `b_`).
- Observation: the claim path is `DETFFundedBondTarget._claim`
  (`contracts/vaults/detf/common/bondNft/DETFFundedBondTarget.sol:163-189`): it accumulates
  `position_.claimedPrincipal += principal_` (`:181`), debits
  `position_.stakingGons -= StakingMath._toGons(principal_ + rewards_, k_)` (`:180, 182`),
  transfers the sDETF (`:184`) and calls `_retireIfPaid` (`:185`).
- Observation: `_retireIfPaid` burns the NFT only when
  `position_.claimedPrincipal == position_.principal && position_.stakingGons < k_` (`:193`), with
  `ERC721Repo._burn(tokenId_)` at `:198`.
- Observation: `k_` is the current `gonsPerUnit` read at claim time (`:175`).
- Observation: the vest arithmetic is `DETFFundedStakingMath._claim`
  (`contracts/vaults/detf/common/core/DETFFundedStakingMath.sol:97-119`):
  `elapsed_ = timestamp_ - position_.startTimestamp` (`:103`), `vestedPrincipal` (`:104-106`),
  `principalDue = vestedPrincipal - claimedPrincipal` (`:111`), and
  `rewardsDue = stakingValue_ - principalRemaining` where `stakingValue_ = _toAmount(position_.stakingGons, gonsPerUnit_)`
  floors the gons (`:112, 116-118`).
- Observation: the bond position is opened with `startTimestamp: block.timestamp`
  (`contracts/vaults/detf/common/bondNft/DETFFundedBondRepo.sol:51-54`).
- Observation: the test claims bond `a_` at half maturity (`:136-138`) and again at full maturity
  (`:140-142`), so two claims cover the whole principal by `:111`.
- Inference: the first half of the retire condition is therefore met by construction, and the gate
  that withheld the burn is the residue test `position_.stakingGons < k_` (`:192`). The residue left
  after the final debit is the sub-unit remainder measured against the index at the *earlier*
  claim, while the comparison uses the *later* (smaller) `gonsPerUnit` — so a remainder that was
  sub-unit at the first claim can be ≥ `k_` at the last claim. The competing gate, which I cannot
  exclude from source alone, is that the halfway claim paid no principal (vesting elapsed 0),
  leaving `claimedPrincipal < position_.principal`. A trace of `positionOf(id_)` after the two
  claims separates them.

### E7 — Funded bond claim at the halfway point (test 10)

Test: `test/foundry/spec/vaults/detf/common/claimToken/RebasingClaimTokenDFPkg_Deploy.t.sol:176-196`.

- Observation: the failing value is 475000000000. The bond principal for a 1000e9 bond at the
  fixture's seigniorage is 950e9, so 475000000000 is exactly `principal_ / 2`, the expected
  halfway principal.
- Observation: three assertions could carry that expectation: `assertEq(paidPrincipal_, principal_ / 2)`
  at `:183`, `assertEq(_staking().balanceOf(detfUser), paidPrincipal_ + reward_)` at `:184`, and
  `assertEq(bond_.positionOf(id_).claimedPrincipal, paidPrincipal_)` at `:185`. The reported actual
  is 0, so the failing one is whichever of the three read 0.
- Observation: the claim transfers `principal_ + rewards_` of the rebasing claim token to the
  recipient (`DETFFundedBondTarget.sol:184`) and the vesting input is
  `DETFFundedStakingMath._claim` (`:96-119`) with `elapsed_ = timestamp_ - position_.startTimestamp`
  (`:103`).
- Observation: the test warps `DEFAULT_MIN_LOCK / 2` after the bond opens (`:180`), with
  `DEFAULT_MIN_LOCK = 30 days` (`TestBase_UniswapV4Detf.sol:85`) and `startTimestamp = block.timestamp`
  at open (`DETFFundedBondRepo.sol:53`), so `elapsed_` is a quarter of the vesting term and
  `principalDue` should be `principal_ / 2` by `:104-106` and `:111`.
- Inference: an actual of 0 means the halfway claim produced no principal and/or credited no
  balance — either the vest computation saw `elapsed_ == 0` or `claimedPrincipal == vestedPrincipal`
  (`DETFFundedStakingMath.sol:103, 111`), or the claim's payout (`:186`) did not appear in the
  rebasing token's `balanceOf` for the recipient. This is the same claim/retirement machinery that
  withheld the burn in E6, and it is the shared candidate cause for tests 8 and 10.

### E8 — Weighted multi-vault DETF, primary burn against owned LP (test 9)

Test: `test/foundry/spec/vaults/detf/common/claimToken/MultiWeightedFundedStaking.t.sol:262-274`,
driving `_assertOwnedLpBurn`
(`contracts/test/bases/FundedPrimaryRouteAssertions.sol:115-135`).

- Observation: the helper computes `expectedLp_ = c_.amount * before_.lp / before_.supply` (`:123`),
  previews `quote_` (`:124`) and then executes
  `exchange_.exchangeIn(IERC20(c_.detf), c_.amount, c_.payment, quote_, c_.payer, false, block.timestamp)`
  (`:139`), after which it reconciles the LP burn against the recorded logs (`:127`).
- Observation: the production entry is
  `MultiVaultWeightedDetfExchangeInTarget._exchangeIn`
  (`contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfExchangeInTarget.sol:28-68`):
  `_requireActive(deadline_, amount_)` (`:37`), `_updateExpansionMintOnRewards()` (`:43`), the
  DETF → payment leg `_burnHeldDetf(...)` (`:59`, implemented in
  `contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfExchangeOutTarget.sol:13`),
  and the slippage gate
  `if (received_ < minimum_) revert IStandardExchangeErrors.MinAmountNotMet(minimum_, received_);` (`:66`).
- Observation: the preview is `MultiVaultWeightedDetfExchangeQueryTarget.previewExchangeIn`, a
  `public view` function
  (`contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfExchangeQueryTarget.sol:23`),
  and therefore cannot realize a pending expansion, whereas the execution does so at `:43` before
  sizing the burn at `:59`.
- Observation: the error `MinAmountNotMet(uint256,uint256)` is declared in
  `lib/crane/contracts/interfaces/IStandardExchangeErrors.sol:18`.
- Inference: the previewed payment and the executed payment are computed against different DETF
  total supplies, because the execution realizes the pending expansion that the view cannot. A
  one-wei shortfall in `received_` then trips the gate at `:66`. The discriminating read is
  `_updateExpansionMintOnRewards()`
  (`contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetfCommon.sol:221`):
  whether it minted between the preview at `:126` and the execution at `:135`.

### E9 — V4 DETF reserve liquidity: second epoch expansion (tests 11-18)

Test: `test/foundry/spec/vaults/detf/common/claimToken/V4ReserveLiquidity.t.sol:124-137`, in the
shared behavior contract, instantiated by `CpReserveLiquidityTest`,
`CpPublicReserveLiquidityTest`, `WeightedReserveLiquidityTest`,
`WeightedPublicReserveLiquidityTest`, `OrbitalReserveLiquidityTest`,
`OrbitalPublicReserveLiquidityTest`, `CurveQuadReserveLiquidityTest` and
`CurveQuadPublicReserveLiquidityTest` (the file's lower half; the `Public*` variants differ only
in `_policy()` returning false).

- Observation: the failing assertion is `:134`,
  `assertGt(subject_.pendingExpansionDetf(), 0, "later epochs have funded expansion")`, while the
  first, identical assertion at `:130` passed.
- Observation: the pending amount is
  `UniswapV4DetfCommon._pendingExpansionDetf()`
  (`contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol:314-326`), which
  requires `_hasCompletedExpansionEpoch` (`:373-376`) and then calls
  `DETFEpochNaturalExpansionLib.previewPendingExpansionMint`
  (`contracts/vaults/detf/common/core/DETFEpochNaturalExpansionLib.sol:33-46`), whose zero
  conditions are: not live, `nowTimestamp <= lastExpansionTimestamp`, `totalDetfSupply == 0`,
  `spotSyntheticPrice <= 1e18`, `spotSyntheticPrice <= mintThreshold`, `epochs_ == 0`, and
  `mint_ <= 1` (`:34-45`), with `EPOCH = 8 hours` (`:11`).
- Observation: the accrual price input is `_highestSyntheticPrice()` (`:319`, defined `:330-347`),
  the maximum over every hook pair token, priced with `s.creationOfPair[pairs_[i_]]` (`:343`).
- Observation: the test's funding probe `_fundExpansionPremium` (`:181-214`) clears the gate
  using `_leadSyntheticPrice` (`:216-236`), whose own doc comment states it "follows the first
  sorted leg, which need not be the payment leg used by these fallback assertions" and which
  builds `creationPairPerDetfWad` from the `creationPairPerDetfWad()` array rather than from the
  `creationOfPair` mapping.
- Observation: the first expansion was consumed by the intervening `_assertFallbackExchange`
  (`:126-128`, helper `:252`), whose settlement calls `_realizeExpansionIfNeeded()`
  (`UniswapV4DetfCommon.sol:349-369`), advancing `lastExpansionTimestamp` to the last completed
  epoch boundary (`:362-363`).
- Observation: the expansion fallback uses `mintThreshold = 2e18` and
  `expansionClosureRatePerYearWad = 1e18` (`V4ReserveLiquidity.t.sol:75`, in `_fallbackArgs`
  at `:68`).
- Inference: after the second funding and the second 25-hour warp the accrual is 0, so one of the
  zero-conditions holds. The 25-hour warp spans three 8-hour epochs, so `epochs_ == 0` is unlikely
  unless `lastExpansionTimestamp` was advanced past the warp point. The leading candidate is the
  price condition `spotSyntheticPrice <= mintThreshold`, because the probe that clears the gate
  and the price the accrual uses are computed over different legs and different creation-rate
  sources. All eight named tests fail at the same line of the same behavior contract, so the eight
  failures are one cause instantiated per hook family.

### E10 — Prod-SE quad DETF: claim after mature close (tests 19, 20)

Tests: `test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Quad_MorphoBlueSe.t.sol:85-87`
and `.../UniswapV4Detf_Quad_Univ3Se.t.sol:85-87`, both delegating to
`_assertClaimAfterMatureClose()`
(`contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Quad_ProdSe.sol:404-433`).

- Observation: the helper captures `block.timestamp + 1 hours` as the deadline for its first two
  `exchangeIn` calls (`:408` and `:412`) and then calls `_assertFundedMatureClaim` (`:415`), which
  warps the clock forward to the bond maturity
  (`contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol:433-434`;
  `DEFAULT_MIN_LOCK = 30 days` at `:85`). At a start timestamp of 1, the captured deadlines are
  3601.
- Observation: `DeadlineExpired(uint256)` has exactly two producers in this family:
  `UniswapV4DetfRepo.DeadlineExpired(uint256)`
  (`contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfRepo.sol:23`), raised by
  `UniswapV4DetfCommon._requireActive`
  (`contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol:63-66`), reached
  from `UniswapV4DetfTarget.sol:208, 268, 346, 412, 421`; and
  `StakedDETFTarget.DeadlineExpired(uint256)`
  (`contracts/vaults/detf/common/claimToken/StakedDETFTarget.sol:30`), raised by
  `StakedDETFTarget._exchange` (`:194-197`).
- Observation: the DETF forwards the caller's deadline unchanged into the rebasing claim token
  (`UniswapV4DetfTarget.sol:356` and `:368-369`) and into the host standard exchange
  (`UniswapV4DetfCommon.sol:428`), so a deadline captured before the maturity warp is compared
  against the post-warp clock.
- Inference: the rejected value 3601 is `block.timestamp + 1 hours` captured at the pre-warp
  timestamp 1, and the check that rejected it ran after `vm.warp(maturity_)` had advanced the
  clock past 3601. The discriminating read is which of the two producers above fired; both are
  reachable from the helper's `exchangeIn` calls (`:407-413`, `:424-426`) and from the unstake
  helper (`TestBase_UniswapV4Detf.sol:467`). The two named tests are the same helper over the same
  base, so they are one cause.

## Assumptions

1. Foundry's default `block.timestamp` is 1 in this repo. The brief supplies this as
   coordinator-supplied context; I use it only to name the numeric values (3601, 7202, 475000000000)
   and I say so wherever it is load-bearing.
2. The brief's "actual != expected" rendering of a failure. The numeric pairs I use (3601 vs 7202)
   are self-consistent under either reading, because one of the two values must come from the
   production anchor and the other from the test's `block.timestamp` anchor.
3. The failing assertion in each file is the one whose expected value matches the reported
   number. For test 10 three assertions could carry 475000000000, and I have not narrowed it.
4. The runtime messages quoted in the brief are accurate descriptions of the failing assertions.
   I did not re-run the suite, so I did not verify that the reported message belongs to the
   assertion I identify in each case.
5. For test 7, that Foundry's `vm.recordLogs` does not retain logs emitted inside a frame that
   later reverts. I did not verify this against Foundry's documented behaviour.
6. The eight V4ReserveLiquidity variants named in the brief are the eight contracts in
   `V4ReserveLiquidity.t.sol` that inherit the shared behavior; I matched them by name.

## Coverage

| # | Test | File | Diagnosis status |
| --- | --- | --- | --- |
| 1 | `test_D89_ownerDepositSingle_atMin_whileUnlocked` | `.../hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_OwnerDuringLock.t.sol:191` | Cause narrowed to a nested deadline; raising frame not localized (E1) |
| 2 | `invariant_APEX_accounting` | `.../aave/cross-version/invariant/AaveCrossVersionLoop_Invariant.t.sol:243` | Anchor mismatch between test and production (E2) |
| 3 | `test_APEX_deterministicLifecycle` | same file `:274` | Same cause as #2 (E2) |
| 4 | `test_APEX_loopAccruedFiveCycleRegression` | same file `:264` | Same cause as #2 (E2) |
| 5 | `test_setUp_linksV4SpokeDespiteNamesakeArtifact` | same file `:115` | Test-side artifact hash reconstruction (E3) |
| 6 | `test_notify_while_totalSupply_zero_empty_period_not_credited` | `.../protocols/staking/token/TokenStaking.t.sol:306` | Accrual base/window, two live candidates (E4) |
| 7 | `test_T31_reentrancyDuringPullIsLocked` | `.../routers/balancerV3-uniswapV4/BalancerV3UniswapV4CoordinatorRouter_LedgerAndRescue.t.sol:99` | Emission inside a reverted frame (E5) |
| 8 | `test_twoBondEscrowsCloseWithoutRetiringEachOthersFraction` | `.../detf/common/claimToken/FundedStakingSequence.t.sol:132` | Bond retire gate not met (E6) |
| 9 | `test_primaryBurnUsesOwnedLpAndPreservesExternalLiquidity` | `.../detf/common/claimToken/MultiWeightedFundedStaking.t.sol:262` | Preview/execution supply basis differs by 1 wei (E8) |
| 10 | `test_halfwayClaimPaysFundedStakingAndFullClaimRetiresBond` | `.../detf/common/claimToken/RebasingClaimTokenDFPkg_Deploy.t.sol:176` | Halfway claim produced no principal/credit (E7) |
| 11-18 | `test_standardFallbackSettlesFundedCatchupBeforeBothDirections` (8 contracts) | `.../detf/common/claimToken/V4ReserveLiquidity.t.sol:124` | Second-epoch accrual is zero (E9) |
| 19 | `test_claimAfterMatureClose_matchesProjection` | `.../detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Quad_MorphoBlueSe.t.sol:85` | Stale deadline vs post-warp clock (E10) |
| 20 | `test_claimAfterMatureClose_matchesProjection` | `.../detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Quad_Univ3Se.t.sol:85` | Same cause as #19 (E10) |

Read for this response: the ten named test files; `UniswapV4SingleStandardExchangeBufferConstantProductHookDepositSingleTarget.sol`,
`...HookDepositCommon.sol`, `...HookInExecutionBase.sol`, `...HookWithdrawalLib.sol`, the CP single
hook interface; `AaveCrossVersionLoopRebalanceTarget.sol`, `LoopPositionRepo.sol`,
`lib/crane/.../aave/v4/spoke/Spoke.sol`; `TokenStakingTarget.sol`, `TestBase_TokenStaking.sol`;
`BalancerV3UniswapV4CoordinatorRouter{QueryTarget,ExactInTarget,Common}.sol`,
`lib/crane/.../access/reentrancy/ReentrancyLockRepo.sol`; `DETFFundedBondTarget.sol`,
`DETFFundedBondRepo.sol`, `DETFFundedStakingMath.sol`; `MultiVaultWeightedDetfExchangeInTarget.sol`,
`...ExchangeOutTarget.sol`, `...ExchangeQueryTarget.sol`, `FundedPrimaryRouteAssertions.sol`;
`UniswapV4DetfCommon.sol`, `UniswapV4DetfTarget.sol`, `UniswapV4DetfRepo.sol`,
`DETFEpochNaturalExpansionLib.sol`, `StakedDETFTarget.sol`, `TestBase_UniswapV4Detf.sol`,
`TestBase_UniswapV4Detf_Quad_ProdSe.sol`; `lib/crane/.../interfaces/IStandardExchangeIn.sol`,
`IStandardExchangeErrors.sol`.

Not read: peer responses, other members' files, the coordinator draft, RUN.md, any report.

## Conclusions

Nine shared causes cover the 20 failures. Nothing below authorizes implementation, and no edit is
proposed.

**Cause A — Bond claim / retirement gate in the funded bond path. Tests 8 and 10.**
`#10 test_halfwayClaimPaysFundedStakingAndFullClaimRetiresBond`
(`RebasingClaimTokenDFPkg_Deploy.t.sol:176`) and
`#8 test_twoBondEscrowsCloseWithoutRetiringEachOthersFraction`
(`FundedStakingSequence.t.sol:132`).
Both failures sit in `DETFFundedBondTarget._claim` (`DETFFundedBondTarget.sol:161-189`) and
`_retireIfPaid` (`:190-199`), whose burn condition `position_.claimedPrincipal == position_.principal && position_.stakingGons < k_`
(`:193`) was not satisfied: test 10 observed a halfway principal of 0 where 475000000000 was
expected, and test 8 observed the bond still owned by `0xD37F` (`TestBase_UniswapV4Detf.sol:110`)
where `address(0)` was expected. The vest arithmetic that produces the expected 475000000000 is
`DETFFundedStakingMath._claim` (`DETFFundedStakingMath.sol:96-119`), and the residue that gates
the burn is compared against `k_` at claim time (`:175`, `:193`). Two live sub-mechanisms, in E6
and E7: a vest that sees zero elapsed, and a sub-unit gons residue measured against a later,
smaller index. One trace of `positionOf(id_)` after the claims separates them.

**Cause B — Deadline captured before a clock warp, checked after it. Tests 19 and 20.**
`#19 test_claimAfterMatureClose_matchesProjection`
(`UniswapV4Detf_Quad_MorphoBlueSe.t.sol:85`) and
`#20 test_claimAfterMatureClose_matchesProjection`
(`UniswapV4Detf_Quad_Univ3Se.t.sol:85`).
Both run `_assertClaimAfterMatureClose()`
(`TestBase_UniswapV4Detf_Quad_ProdSe.sol:404-433`), which captures `block.timestamp + 1 hours`
(3601 at timestamp 1) at `:408` and `:412` and then warps the chain forward 30 days inside
`_assertFundedMatureClaim` (`TestBase_UniswapV4Detf.sol:433-434`). The DETF forwards that
captured deadline unchanged into the rebasing claim token
(`UniswapV4DetfTarget.sol:356`, `:368-369`) and the host SE (`UniswapV4DetfCommon.sol:428`), and
the check that rejected it is either `UniswapV4DetfCommon._requireActive` (`:63-66`) or
`StakedDETFTarget._exchange` (`StakedDETFTarget.sol:194-197`). The two tests are the same helper
over the same base and are one cause.

**Cause C — Second-epoch natural expansion accrues zero. Tests 11 through 18.**
`test_standardFallbackSettlesFundedCatchupBeforeBothDirections` in
`CpPublicReserveLiquidityTest`, `CpReserveLiquidityTest`,
`CurveQuadPublicReserveLiquidityTest`, `CurveQuadReserveLiquidityTest`,
`OrbitalPublicReserveLiquidityTest`, `OrbitalReserveLiquidityTest`,
`WeightedPublicReserveLiquidityTest` and `WeightedReserveLiquidityTest`
(`V4ReserveLiquidity.t.sol:124-137`, failing assertion at `:134`).
All eight fail at the same assertion of the same behavior contract. The pending amount comes from
`UniswapV4DetfCommon._pendingExpansionDetf()` (`:314-326`) →
`DETFEpochNaturalExpansionLib.previewPendingExpansionMint` (`:33-46`), whose zero-conditions
(`:34-45`) are not met for the second epoch although the first epoch funded fine. The leading
candidate is the price condition, because the accrual prices with `_highestSyntheticPrice()`
(`:319`, `:330-347`) while the test's funding probe clears the gate with `_leadSyntheticPrice`
(`:188-209`), which follows a different leg and a different creation-rate source. One cause, eight
instantiations.

**Cause D — Anti-churn rebalance anchor. Tests 2, 3 and 4.**
`#2 invariant_APEX_accounting` (`AaveCrossVersionLoop_Invariant.t.sol:243`),
`#3 test_APEX_deterministicLifecycle` (`:274`) and
`#4 test_APEX_loopAccruedFiveCycleRegression` (`:264`).
The production rejects with `lastRebalanceTimestamp + 1 hour`
(`AaveCrossVersionLoopRebalanceTarget.sol:73-74`) while the test asserts
`block.timestamp + 1 hour` (`AaveCrossVersionLoop_Invariant.t.sol:331`); the reported values
differ by exactly the warp step at `:320`, i.e. the production's anchor was one warp behind the
test's. Tests 3 and 4 fail only because they end in `afterInvariant()` (`:248-262`), which calls
the same invariant. One cause.

**Cause E — Test-side artifact hash reconstruction. Test 5.**
`test_setUp_linksV4SpokeDespiteNamesakeArtifact` (`AaveCrossVersionLoop_Invariant.t.sol:115`).
The spoke links the V4 library by import (`lib/crane/.../v4/spoke/Spoke.sol:21`, getter `:640-642`);
the failing comparison at `:121` is against a hash reconstructed by patching the first `PUSH20` of
the artifact runtime (`:132-143`), which is not provably the library's own address slot. The
"two bytecode hashes differ" message in the brief does not occur anywhere in the repository and is
not localized.

**Cause F — Preview and execution compute the burn against different DETF supplies. Test 9.**
`test_primaryBurnUsesOwnedLpAndPreservesExternalLiquidity` (`MultiWeightedFundedStaking.t.sol:262`).
The view preview (`MultiVaultWeightedDetfExchangeQueryTarget.sol:23`) cannot realize the pending
expansion that the execution realizes at
`MultiVaultWeightedDetfExchangeInTarget.sol:43` before sizing the burn at `:59`; the one-wei
shortfall then trips `MinAmountNotMet(minimum_, received_)` at `:66`.

**Cause G — Event emitted inside a frame that later reverts. Test 7.**
`test_T31_reentrancyDuringPullIsLocked`
(`BalancerV3UniswapV4CoordinatorRouter_LedgerAndRescue.t.sol:99`).
The nested `queryExactIn` does revert with `IsLocked` — both facets share
`ReentrancyLockRepo`'s transient slot — so `SawIsLocked()` is emitted
(`:237-256`), but the outer call then reverts because the registered step router `0xBEEF` has no
code (`:116-117`, and the test's own comment at `:127`), and the topic is absent from
`vm.getRecordedLogs()` (`:131`).

**Cause H — Deposit-path deadline. Test 1.**
`test_D89_ownerDepositSingle_atMin_whileUnlocked`
(`UniswapV4SingleStandardExchangeBufferConstantProductHook_OwnerDuringLock.t.sol:191`).
The deadline the test passes cannot be expired at the call site, so the `DeadlineExpired()` came
from a nested call carrying a different deadline; the family declares that identical error in five
files (`...HookDepositCommon.sol:77`, `...HookWithdrawTarget.sol:81`, `...HookTarget.sol:85`,
`...HookSeTarget.sol:77`, `...HookWithdrawalLib.sol:17`). The raising frame is not localized.

**Cause I — Staking reward accrual base. Test 6.**
`test_notify_while_totalSupply_zero_empty_period_not_credited` (`TokenStaking.t.sol:306`).
`rewardRate` cannot be zero without a revert (`TokenStakingTarget.sol:212-214`, `:218`), so the
observed 0 must come from the `totalSupply == 0` early return in `rewardPerToken()` (`:118-120`)
or from an empty accrual window, i.e. the staked 100e18 is not accruing.

Counts: 2 (A) + 2 (B) + 8 (C) + 3 (D) + 1 (E) + 1 (F) + 1 (G) + 1 (H) + 1 (I) = 20.

## Limits

1. I did not execute anything. Every statement above is either a citation of the working tree or
   arithmetic over cited definitions. Nothing here is a reproduced run.
2. Three diagnoses are narrowed but not localized: test 1 (which of five identical
   `DeadlineExpired()` declarations fired), test 5 (which code path produced "two bytecode hashes
   differ"), and test 10 (which of the three assertions at `:183`/`:184`/`:185` carried 475000000000).
3. Two diagnoses have two live sub-mechanisms that I could not discriminate without execution:
   cause A (vest elapsed zero vs residue against a later index) and cause I (zero staking supply
   vs zero accrual window).
4. Cause C is localized to a set of zero-conditions, not to a single one; the price condition is
   my leading candidate, not a demonstrated fact.
5. Cause G rests on Foundry's `recordLogs` retention across a reverted frame, which I did not
   verify against Foundry's documentation.
6. The numeric identifications 3601, 3602, 7202 and 475000000000 assume Foundry's default
   `block.timestamp` of 1, which the brief supplies as coordinator context rather than as
   something I verified.
7. The brief's "27290 other tests succeeded" is supplied runtime; I did not re-run the suite and
   make no claim about the rest of the suite.
8. I read only the admitted scope. Where a shared helper lived outside the named test files
   (`TestBase_*`, `contracts/test/bases/*`), I read it because the named test calls it.
9. This response is research. It does not authorize implementation, does not replace the original
   brief, and does not open a further round.
