# Failing-test triage — 2026-10-09

Current status (2026-10-10): all 1,505 in-scope original failures pass; 17 Balancer DETF cases remain deferred. Additional funding fixes passed 3,738 tests. R23 has 30 unresolved BPT-rate tests. See [the handoff](ERRORS_HANDOFF_2026-10-10.md). The inventory below preserves the initial triage.

## Scope and evidence

Source: [ERRORS.log](../../ERRORS.log), **1,522 failing tests, 316 suites, 288 test files**; the log also reports 33,098 successes. The inventory below accounts for every failure exactly once, including two multiline invariant replay failures. Counts represent failing test instances, not independently proven bugs.

This is a **planning report only**. No production or test code was changed, and no builds, test reruns, or full traces were performed for this report. Diagnosis is limited to the supplied log, representative source paths, shared test helpers, and existing product instructions. “High confidence” means source/log evidence supports the stated classification; it does not mean all variants have been reproduced. Grouping a cascade is provisional until first-failure traces agree.

The working tree is already dirty. Source inspected at HEAD `5709cb3507a9df72b11ec476d27b79ef88696c3a` plus local changes; the log does not identify its generating commit, command, artifact state, fuzz seed, or run date. Do not assume the current working tree exactly matches the logged run. Log SHA-256: `eee9ca37b2e651ca797ceecf8e142b56e3373967b96fee12cc4ebd5172d7b95a`.

The immediately preceding legacy V4 repair run covered `test/foundry/spec/protocol/dexes/uniswap/v4` only. Most failures here are in hooks, DETFs, FullSpread, and native-SY suites outside that directory. Its 1,107 passing tests therefore do not conflict with this broader error list.

## Resolution order: easiest to most uncertain

### Owner clarifications after initial triage

These decisions supersede contrary provisional recommendations below. No production
or test fixes have been made as part of this report.

- **Rate providers quote the entire share supply**, then normalize that valuation
  for the published rate. R05 is now a production sampling-policy mismatch to
  investigate and correct, rather than a direction to rewrite tests around the
  existing half-supply / supply-minus-one sampling restriction.
- **Undeployable deposit dust is retained locally and receives shares.** A zero
  underlying-protocol output must not automatically mean zero vault shares for a
  funded deposit. Withdrawals of a locally held token consume local balances first.
  Distinguish an unexecutable underlying investment from an unsupported public route.
- **Deploy the entire eligible reserve when possible.** Retention is for input that
  cannot yet be deposited, until accumulation allows a later sweep, or for an
  explicitly designed liquidity sleeve. Available capacity is still a bound rather
  than proof that a specific rounded investment can consume it fully.
- **Balancer-hosted DETFs are deferred** pending a separate refactor to the V4 DETF
  design. Keep their failures in this historical inventory, but exclude them from
  the current resolution queue (15 preview cases within R02 and both R16 cases).
  This does not defer Balancer SE pools or rate providers.
- **Alignment remains a diagnosis question.** `AlignmentNotAchievable` is emitted
  when the underlying FullSpread SE composition plan is invalid. Its causes may
  include integer rounding, price-impact restrictions, placement constraints or a
  planner work limit. The existing per-leg alignment check already uses 9,999/10,000;
  it is not an exact-equality requirement. The log alone does not establish which
  constraint rejected each R19 case, nor prove that a valid plan is impossible.

The revised diagnosis must test whether rejected small investments can instead be
credited as locally held deposits under these rules, while preserving fair share
issuance and all explicitly designed sleeve and execution protections. No new
rounding tolerance or economic exception has been authorized.

Effort is relative: **Small** = local fixture/assertion work; **Medium** = bounded behavior change or targeted integration investigation; **Large/research** = architectural work, a broad cascade, or unresolved numerical policy. It excludes this repository's potentially long compilation time. Entries of similar effort may be tackled together. This is an effort order, not a severity order: R09/R10 deserve early security attention, R17 blocks deployment, and R18 deserves an early diagnostic trace because it dominates the failure count.

| Group ID | Group | Failures | Provisional responsibility | Effort | Confidence |
|---|---|---:|---|---|---|
| R01 | [Native SY internal redemption uses an EOA fixture](#r01) | 25 | Test implementation | Small | High |
| R02 | [Unsupported or inactive previews return zero, but tests expect a revert](#r02) | 29 | Test assumptions | Small | High for inspected representatives |
| R06 | [Selector coverage test assumes previews live on the execution facet](#r06) | 1 | Test implementation | Small | High |
| R03 | [FullSpread preview assertions still conflate pricing with settlement availability](#r03) | 7 | Test assumptions; verify later execution assertions | Small–medium | High for the first failing preview checks |
| R04 | [Panic expectations lose the revert payload and hook wrapper](#r04) | 12 | Test implementation; underlying dust behavior remains to be checked | Small–medium | High for the encoding mismatch |
| R05 | [Rate-provider tests assume the former sampling size](#r05) | 8 | Likely test assumptions; sampling policy confirmation | Small–medium | High for sample mismatch; medium for final disposition |
| R07 | [Residual reproducer no longer reaches its intended boundary](#r07) | 1 | Test fixture | Small–medium | High |
| R08 | [Consumed-credit rejection occurs at a different validation layer](#r08) | 1 | Unresolved error-precedence contract | Small–medium | Medium |
| R09 | [Permit2 uint160 truncation books an undelivered amount](#r09) | 2 | Production defect indicated by source and regression | Medium; security priority | High |
| R10 | [Token staking accepts taxed delivery while crediting the requested amount](#r10) | 3 | Production defect indicated by source and regression | Medium; security priority | High |
| R11 | [Morpho maxRedeem understates a proven payable balance](#r11) | 1 | Likely production boundary defect | Medium | High for observed under-advertising |
| R13 | [Partial-investment tests assume capacity is fully consumed](#r13) | 3 | Test assumption or production investment behavior | Medium | Medium |
| R14 | [Camelot caller-separation fixture never creates the unpaired book](#r14) | 1 | Test fixture likely; production separation not exercised | Medium | Medium–high |
| R12 | [Aave capacity boundary diverges at a non-unit liquidity index](#r12) | 1 | Likely production rounding/cap mismatch; trace required | Medium–large | Medium |
| R15 | [One-unit AMM dust previews and execution do not share rejection behavior](#r15) | 3 | Unresolved preview/execution contract or fixture assumption | Medium–large | Medium |
| R16 | [Composed-stable execution errors differ from expected route/liveness errors](#r16) | 2 | Unresolved validation order and fixture state; scope hold | Medium–large | Medium |
| R17 | [Deployed runtime exceeds EIP-170](#r17) | 16 | Production packaging/deployability defect | Large; release blocker | High for logged sizes |
| R18 | [DETF funded lifecycle ZeroAmount cascade](#r18) | 1,389 | Likely shared production/integration failure; exact cause unproven | Large uncertainty; highest diagnostic leverage | High for clustering; low for a single root cause |
| R19 | [Orbital low-decimal alignment cannot find an executable result](#r19) | 10 | Unresolved solver feasibility/rounding or fixture boundary | Large/research | Medium for common scope |
| R20 | [Later-bond residual remains large enough to mint LP](#r20) | 2 | Production residual handling or stale economic assertion | Large/research | Medium |
| R21 | [Invariant replay fails before useful invariant evidence](#r21) | 2 | Unresolved handler/setup or production failure | Research after prerequisite repair | Low on underlying cause |
| R22 | [Reentrancy test fails its unlocked positive control](#r22) | 3 | Blocked security test; likely shared setup dependency | Research after funded-path diagnosis | High that the guard itself has not been tested |

## Suggested work sequence

1. **Establish a reproducible baseline.** Record source revision/local diff and compiler profile, then refresh runtime artifacts before the first targeted replay. Keep the supplied log and invariant sequences intact.
2. **Take the mechanical test groups first:** R01–R07, while keeping execution negatives, accounting identities, and independent expected values. Discuss the sampling policy and Balancer scope before dependent changes.
3. **Investigate R18 early with three representative traces**, even though complete resolution has high uncertainty. Split it by first reverting frame before assigning a large implementation batch. R22 and the DETF half of R21 may be blocked by it.
4. **Address bounded production defects:** R09/R10, followed by R11/R12 once their boundary calculations are confirmed. Treat R08 and R13–R16 as diagnosis/decision work until evidence assigns ownership.
5. **Deduplicate and reduce oversized components in R17.** Recheck selector installation, caller identity, reentrancy and actual deployment size after each split or reuse change.
6. **Resolve solver/residual semantics and replay invariants:** R19–R22. R20 must preserve economically meaningful residual accounting; do not hide it behind a generic dust tolerance.
7. After each common fix, run one representative, then its inherited/decimal variants, then the affected family suite. Regenerate the remaining failure inventory; fixing the first error may reveal later failures in the same tests.

For future production changes, use the repository's [artifact build workflow](ARTIFACT_BUILDS.md), e.g. `python3 scripts/forge-artifacts.py test <changed-source.sol> --test-root <representative-test-or-family> -- -vvv`. Do not run that placeholder command literally. Keep configured source/test roots and the normal profile; do not enable viaIR or delete the warm cache.

## Items requiring discussion or a targeted trace

These are not requests to reconsider already-settled rules. Contract-only pretransfer, fee-on-transfer rejection, funded-only staking, the runtime size limit, and separation of price from settlement remain established requirements.

| Item | Tests/groups | What needs to be settled |
|---|---|---|
| Q1 — Rate sampling | R05, with probe assumptions in R03 | **Resolved:** quote the entire share supply. Current restricted-sample behavior must be investigated as a production mismatch. |
| Q2 — Zero-quote dust execution | R04/R15 | **Resolved for supported deposits:** credit shares for retained, undeployable input; sweep when deployable. Distinguish underlying zero output from the vault share quote. Withdraw local output tokens first. |
| Q3 — Residual investment | R13/R14/R20; R07 fixture | **Resolved:** deploy all eligible reserves when possible; retain only uninvestable dust or an explicitly designed sleeve. Diagnose executable capacity and retry behavior. |
| Q4 — Validation error precedence | R08 and R16 | Are the named credit/route/liveness errors part of the required API, or is another early rejection acceptable? In the composed-stable case, first verify the fixture is actually uninitialized. |
| Q5 — Infeasible alignment | R19 | **Needs diagnosis:** identify why the FullSpread SE planner rejects the deposit. Existing alignment already has a tolerance; distinguish rounding infeasibility from impact/placement/work-limit rejection or a missed valid plan. Apply the clarified local-dust policy where appropriate. |
| Q6 — Balancer DETF scope | Balancer DETF subset of R02; R16 | **Resolved:** ignore Balancer-hosted DETFs for now; a separate refactor will align their design with V4 DETFs. Balancer SE pools and providers remain in scope. |
| Q7 — Shared failure location | R18, R21, R22 | The log does not identify which production `ZeroAmount` site or handler revert fired. This is an evidence gap, not yet a product-policy question. Capture representative traces before debating intended outcomes. |

## Group findings

<a id="r01"></a>

### R01 — Native SY internal redemption uses an EOA fixture

**25 failures · Test implementation · Small · confidence: High.**

All 25 failures occur in internal-balance redemption tests. The shared `NativeStandardYieldTarget.redeem` explicitly calls `LocalCreditLib.requirePretransferCaller(msg.sender)` when `internalBalance_` is true. A representative Balancer test calls it using `vm.prank(makeAddr("pool-sy-router"))`: that address has no code. This conflicts with the established contract-only prepaid/internal-balance policy.

**Next resolution:** use the existing integrating-contract fixture for the positive internal-balance flow, preserving exact requested-share consumption and all remaining-inventory assertions. Keep separate EOA and constructor-time rejection cases. Do not remove the production guard to make these tests pass. Check family-specific caller/collector authorization independently.

Source anchors: [NativeStandardYieldTarget.sol](../../contracts/vaults/standard/sy/NativeStandardYieldTarget.sol), [AtomicPretransferCaller.sol](../../contracts/test/stubs/AtomicPretransferCaller.sol), [BalancerPoolNativeSY.t.sol](../../test/foundry/spec/vaults/standard/sy/BalancerPoolNativeSY.t.sol).

Representative log entries: [UniswapV4StandardExchangeOrbitalBufferHook_SeBufferAbi::test_nativeSYInternalBalanceLimitsAndPriorInventory](../../ERRORS.log#L3), [RebasingClaimTokenDFPkg_Deploy_Test::test_nativeSYUsesStandardRoutesAndPreservesUnredeemedInternalShares](../../ERRORS.log#L101), [AaveStataNativeSYTest::test_stataInternalBalanceConsumesOnlyRequestedShares](../../ERRORS.log#L2081).

<a id="r02"></a>

### R02 — Unsupported or inactive previews return zero, but tests expect a revert

**29 failures · Test assumptions · Small · confidence: High for inspected representatives.**

Subgroups: 11 unsupported exact-output Balancer DETF cases, 8 reserve-LP first-activation cases, 6 virtual-buffer SY cases, and 4 composed-stable preview cases. These tests stop at a preview assertion before reaching their later execution checks. `previewBond` explicitly returns a zero tuple for reserve-LP payment before activation; native SY returns zero for unsupported preview tokens; the inspected composed-stable preview also returns zero for invalid routes or an inactive reserve.

**Next resolution:** assert the intended zero result and independently retain execution rejection, unchanged balances, and activation-state checks. Zero is a quote sentinel, not permission to execute an unsupported operation. Balancer-hosted DETF changes also need the scope discussion below: D60 excludes functional work in that family.

Source anchors: [NativeStandardYieldTarget.sol](../../contracts/vaults/standard/sy/NativeStandardYieldTarget.sol), [UniswapV4DetfQueryTarget.sol](../../contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfQueryTarget.sol), [V4ReserveLiquidity.t.sol](../../test/foundry/spec/vaults/detf/common/claimToken/V4ReserveLiquidity.t.sol), [BalancerPoolNativeSY.t.sol](../../test/foundry/spec/vaults/standard/sy/BalancerPoolNativeSY.t.sol).

Representative log entries: [CpPublicReserveLiquidityTest::test_lpCannotReplaceFirstBondActivation](../../ERRORS.log#L128), [CpReserveLiquidityTest::test_lpCannotReplaceFirstBondActivation](../../ERRORS.log#L141), [CurveQuadPublicReserveLiquidityTest::test_lpCannotReplaceFirstBondActivation](../../ERRORS.log#L144).

<a id="r03"></a>

### R03 — FullSpread preview assertions still conflate pricing with settlement availability

**7 failures · Test assumptions; verify later execution assertions · Small–medium · confidence: High for the first failing preview checks.**

Three rate-context tests expect an unfunded live preview to revert for insufficient local reserves. Four route-funding tests expect blocked direct-swap or malformed-vector previews to revert. Their shared bases place those preview checks ahead of execution checks. This is inconsistent with the owner-confirmed separation of quoting from settlement and the new zero-return behavior for unavailable preview routes.

**Next resolution:** test the correct quantity or zero sentinel for each route; retain explicit execution rejection when the manager cannot be used, local cover is insufficient, a vector is malformed, or the second prepaid leg is missing. Do not assume subsequent checks pass merely because the first stale expectation is removed. Use the current rate-provider probe size rather than the old whole-supply probe assumption.

Source anchors: [TestBase_UniswapV4FullSpreadRateContext.sol](../../contracts/test/bases/TestBase_UniswapV4FullSpreadRateContext.sol), [TestBase_UniswapV4FullSpreadG3RouteFunding.sol](../../contracts/test/bases/TestBase_UniswapV4FullSpreadG3RouteFunding.sol).

Representative log entries: [UniswapV4FullSpreadHooklessStandardExchangeVaultRateProviderContextParityTest::test_shortLocalCoverCannotShrinkOnlyLiveRateProbe](../../ERRORS.log#L2040), [UniswapV4FullSpreadHooklessStandardExchangeVaultRateProviderDecimalContextTest::test_shortLocalCoverCannotShrinkOnlyLiveRateProbe](../../ERRORS.log#L2043), [HooklessRouteFundingClosureTest::test_blockedDirectExactInputRejectsBothDirections](../../ERRORS.log#L2046).

<a id="r04"></a>

### R04 — Panic expectations lose the revert payload and hook wrapper

**12 failures · Test implementation; underlying dust behavior remains to be checked · Small–medium · confidence: High for the encoding mismatch.**

Twelve Balancer-backed matrix failures arise in `_roundingToZeroControl`: six single-hook and six weighted-hook variants. The test takes `bytes4(previewRet)` and supplies only that selector as its expectation. The actual failure is a complete arithmetic-panic payload; the PoolManager route additionally wraps it in `WrappedError`. `NH{q` is the display of the panic selector bytes, not a distinct contract error.

**Next resolution:** compare the appropriate complete panic or nested wrapped payload, and verify rollback. Separately decide whether this dust request should be rejected with a deliberate error instead of panicking. Correcting the matcher alone establishes neither acceptable dust behavior nor quote/execution parity.

Source anchors: [UniswapV4SingleSEBufferHook_SeMatrixBehavior.sol](../../test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_SeMatrixBehavior.sol), [UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol](../../test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol).

Representative log entries: [UniswapV4SingleSEBufferHook_SeMatrix_CommonBufferMultiVaultStablePool::test_row_partialConsumption_bookedNotRefunded](../../ERRORS.log#L13), [UniswapV4SingleSEBufferHook_SeMatrix_CommonBufferMultiVaultWeightedPool::test_row_partialConsumption_bookedNotRefunded](../../ERRORS.log#L16), [UniswapV4SingleSEBufferHook_SeMatrix_MixedBufferMultiVaultStablePool::test_row_partialConsumption_bookedNotRefunded](../../ERRORS.log#L19).

<a id="r05"></a>

### R05 — Rate-provider tests assume the former sampling size

**8 failures · Likely test assumptions; sampling policy confirmation · Small–medium · confidence: High for sample mismatch; medium for final disposition.**

Seven D48 failures in the direct/wrapped providers plus one custody-provider rounding failure share a sampling-policy change. `_redeemableSample` avoids total supply: it uses one whole token only when strictly below supply, otherwise half the book. Scale-up is capped at `supply - 1`. Several fixtures expect an initial full-supply sample, a recovery exactly at total supply, or fixed call counts built from those amounts. A constant fixture reply scaled from a half-size sample explains the observed 4e18 versus 2e18 results. The custody test compares the normalized sampled rate with `previewRedeem(1e28)`, a whole-supply exit; the one-unit difference is consistent with two different floor operations.

**Next resolution:** confirm the no-whole-supply probe policy, then derive expected attempts, normalization, and rounding from that policy. Keep an independent reference and live/projected parity checks; do not replace exact assertions with broad tolerances. If the policy is not intended for these vaults, change production instead.

Source anchors: [StandardExchangeRateProviderFacet.sol](../../contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol), [WrappedStandardExchangeRateProviderTarget.sol](../../contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/wrapped/WrappedStandardExchangeRateProviderTarget.sol), [MorphoBlueStandardExchange_RateProvider.t.sol](../../test/foundry/spec/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueStandardExchange_RateProvider.t.sol), [FeeAccrualCustodyScript.t.sol](../../test/foundry/spec/protocols/staking/token/FeeAccrualCustodyScript.t.sol).

Representative log entries: [WrappedStandardExchangeRateProvider_Test::test_recurrence_D48_wrappedExhaustionAttemptsClampAtSupply](../../ERRORS.log#L70), [WrappedStandardExchangeRateProvider_Test::test_recurrence_D48_wrappedScaleUpRecoveryAmounts](../../ERRORS.log#L71), [FeeAccrualCustodyScript::test_custodyProvider_normalizesWholeSharesAndTracksDonations](../../ERRORS.log#L80).

<a id="r06"></a>

### R06 — Selector coverage test assumes previews live on the execution facet

**1 failures · Test implementation · Small · confidence: High.**

`test_J1_facetFuncs_coversTargetApi` expects `previewExchangeIn` in `ERC4626StandardExchangeInFacet`. The source intentionally declares it in `ERC4626StandardExchangeInFacetExt`. The test is checking the former facet partition rather than the current package surface.

**Next resolution:** compare each facet against its actual assigned API and independently verify the union on the installed proxy with the loupe and real calls. A selector missing from the deployed proxy would still be a production defect; moving it to another facet is not itself one.

Source anchors: [ERC4626StandardExchangeInFacet.sol](../../contracts/vaults/standard/erc4626/ERC4626StandardExchangeInFacet.sol), [ERC4626StandardExchangeInFacetExt.sol](../../contracts/vaults/standard/erc4626/ERC4626StandardExchangeInFacetExt.sol), [ERC4626StandardExchange_Adversarial.t.sol](../../test/foundry/spec/vaults/standard/erc4626/adversarial/ERC4626StandardExchange_Adversarial.t.sol).

Representative log entries: [ERC4626StandardExchange_Adversarial::test_J1_facetFuncs_coversTargetApi](../../ERRORS.log#L2024).

<a id="r07"></a>

### R07 — Residual reproducer no longer reaches its intended boundary

**1 failures · Test fixture · Small–medium · confidence: High.**

The H6 residual test fails at its setup witness: it requires retained input greater than 10 native units, but the current two-bond sequence leaves 6. The actual retention, booking, and retry assertions have not run.

**Next resolution:** construct a deterministic production sequence that independently proves a residual above the boundary and the intended unsupported/rejected investment condition. Keep the boundary witness; lowering it to 6 would test a different scenario. Recheck the test's older assumptions about idle exact-output support.

Source anchors: [UniswapV4Detf_Cp_Univ4Se_ProductLaw_H6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Cp_Univ4Se_ProductLaw_H6.t.sol).

Representative log entries: [UniswapV4Detf_Cp_Univ4Se_ProductLaw_H6::test_alignmentResidualRetainedBookedAndRetried](../../ERRORS.log#L1357).

<a id="r08"></a>

### R08 — Consumed-credit rejection occurs at a different validation layer

**1 failures · Unresolved error-precedence contract · Small–medium · confidence: Medium.**

The rebasing-vault recurrence consumes every self-held share, then repeats the same redemption. It expects `TransferDeltaInsufficient(shares, 0)` but receives `NumericDomainExceeded`. The unwanted second payout is rejected, but the observed selector does not prove whether credit validation is correctly ordered before arithmetic on an empty book.

**Next resolution:** inspect one trace to identify the first domain check. If the public error contract requires the credit error, reorder production validation; otherwise document the valid rejection and update the selector assertion while preserving all no-second-payment and no-new-supply checks. Do not change the assertion until that choice is made.

Source anchors: [RebasingAwareERC4626_APEX_Recurrence.t.sol](../../test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_APEX_Recurrence.t.sol), [RebasingAwareERC4626Common.sol](../../contracts/protocols/staking/rebasingVault/RebasingAwareERC4626Common.sol).

Representative log entries: [RebasingAwareERC4626_APEX_Recurrence::test_RECURRENCE_B03_secondRedemptionCannotReuseConsumedCredit](../../ERRORS.log#L77).

<a id="r09"></a>

### R09 — Permit2 uint160 truncation books an undelivered amount

**2 failures · Production defect indicated by source and regression · Medium; security priority · confidence: High.**

Two independent weighted-hook recurrence tests add `2**160` to a normal requested amount. The logged booked reserve is 1461501637330902918203684832816283019655932542976 while actual delivery is 100e18. The inspected pull paths explicitly cast the requested uint256 to uint160 before Permit2 transfer, while higher-level accounting can retain the larger amount.

**Next resolution:** enforce the Permit2 numeric domain before transfer and bind credit/booked reserves to actual delivery in both raw-weighted and SE-weighted paths, including allowance-batch branches. Preserve the ordinary funded control and require atomic rejection or otherwise proven exact delivery at the boundary. This group should receive early security attention even though the table is sorted primarily by effort.

Source anchors: [UniswapV4StandardExchangeWeightedBufferHookPullLib.sol](../../contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookPullLib.sol), [UniswapV4WeightedSwapHookLiquidityTarget.sol](../../contracts/hooks/uniswap/v4/weighted/UniswapV4WeightedSwapHookLiquidityTarget.sol), [UniswapV4StandardExchangeWeightedBufferHook_Permit2Recurrence.t.sol](../../test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_Permit2Recurrence.t.sol).

Representative log entries: [UniswapV4StandardExchangeWeightedBufferHook_Permit2Recurrence::test_recurrence_SeWeightedPermit2BooksOnlyDeliveredRawAmounts](../../ERRORS.log#L34), [UniswapV4WeightedSwapHook_Recurrence::test_recurrence_RawWeightedPermit2BooksOnlyDeliveredAmounts](../../ERRORS.log#L67).

<a id="r10"></a>

### R10 — Token staking accepts taxed delivery while crediting the requested amount

**3 failures · Production defect indicated by source and regression · Medium; security priority · confidence: High.**

Three failures cover direct staking, Permit2 staking, and reward funding. The tests establish an untaxed positive control and then introduce a 10% transfer tax. `TokenStakingTarget._pullStakingToken` transfers without checking the received balance delta; stake accounting and reward-rate arithmetic use the requested amount. The repository explicitly forbids fee-on-transfer underlyings.

**Next resolution:** reject non-exact delivery across both funding mechanisms before the transaction can leave any credited stake or reward liability. Preserve the exact expected short-delivery error and full rollback assertions. This is not an authorization to add fee-on-transfer support.

Source anchors: [TokenStakingTarget.sol](../../contracts/protocols/staking/token/TokenStakingTarget.sol), [TokenStaking_APEX_Recurrence.t.sol](../../test/foundry/spec/protocols/staking/token/TokenStaking_APEX_Recurrence.t.sol).

Representative log entries: [TokenStaking_APEX_Recurrence::test_RECURRENCE_tokenStaking_FoTForbiddenDirect](../../ERRORS.log#L86), [TokenStaking_APEX_Recurrence::test_RECURRENCE_tokenStaking_FoTForbiddenPermit2](../../ERRORS.log#L87), [TokenStaking_APEX_Recurrence::test_RECURRENCE_tokenStaking_FoTForbiddenRewards](../../ERRORS.log#L88).

<a id="r11"></a>

### R11 — Morpho maxRedeem understates a proven payable balance

**1 failures · Likely production boundary defect · Medium · confidence: High for observed under-advertising.**

The regression first redeems the complete user balance successfully and verifies the exact payout, then fails because `maxRedeem` advertised one fewer share. Unlike the separate rate-provider sampler, this API is reporting a withdrawal limit.

**Next resolution:** inspect the capacity/inverse-rounding calculation and include usable local backing when determining the maximum. Prove the full advertised amount executes and the next unit does not exceed the owner's balance or available liquidity. Do not blindly apply the rate-provider `supply - 1` policy to this limit.

Source anchors: [MorphoBlueERC4626Target.sol](../../contracts/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueERC4626Target.sol), [MorphoBlueStandardExchange_APEX_Recurrence.t.sol](../../test/foundry/spec/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueStandardExchange_APEX_Recurrence.t.sol).

Representative log entries: [MorphoBlueStandardExchange_APEX_Recurrence::test_RECURRENCE_morphoMaxRedeem_fullPayableBalance](../../ERRORS.log#L2027).

<a id="r12"></a>

### R12 — Aave capacity boundary diverges at a non-unit liquidity index

**1 failures · Likely production rounding/cap mismatch; trace required · Medium–large · confidence: Medium.**

The test creates real elapsed interest, verifies the liquidity index exceeds one ray, sets a supply cap, and deposits at the boundary. The unexpected `SupplyCapExceeded()` suggests disagreement between the adapter's available-capacity calculation and the ported pool's cap validation under accrued interest and rounding.

**Next resolution:** trace the proposed supply amount, scaled supply, accrued treasury amount, index, and pool-side rounding at the rejecting call. Determine whether capacity is overstated or the fixture misidentifies the feasible boundary. Preserve the test's principal/share accounting and any intended local retention of uninvestable input.

Source anchors: [AaveCrossVersionLoop_APEX_Recurrence.t.sol](../../test/foundry/spec/protocol/lending/aave/cross-version/AaveCrossVersionLoop_APEX_Recurrence.t.sol).

Representative log entries: [AaveCrossVersionLoop_APEX_Recurrence::test_RECURRENCE_DX01_nonUnitLiquidityIndex_capBoundary](../../ERRORS.log#L74).

<a id="r13"></a>

### R13 — Partial-investment tests assume capacity is fully consumed

**3 failures · Test assumption or production investment behavior · Medium · confidence: Medium.**

Three weighted-hook rows (weETH, wstETH, and V3 FullSpread) assert `bookedIncrease == usedFace - allow`. A configured allowance/capacity is an upper bound; that identity additionally assumes actual investment consumes all of it. The two liquid-staking results differ by exactly the configured 10-token capacity, suggesting no investment at that step. The V3 row differs by a smaller amount.

**Next resolution:** measure real dependency consumption and both before/after booked balances. Establish whether sleeve-only behavior, deposit thresholds, existing inventory, or a missed investment is responsible. Then enforce `caller delivery = actual consumed input + attributable retained input` using the family policy. Do not simply change expected values to the current result.

Source anchors: [UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol](../../test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol), [SeMatrixFixture.sol](../../test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol).

Representative log entries: [UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_EtherFiWeETHStandardExchange::test_row_partialConsumption_bookedNotRefunded](../../ERRORS.log#L46), [UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_LidoWstETHStandardExchange::test_row_partialConsumption_bookedNotRefunded](../../ERRORS.log#L49), [UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV3FullSpreadStandardExchangeVault::test_row_partialConsumption_bookedNotRefunded](../../ERRORS.log#L64).

<a id="r14"></a>

### R14 — Camelot caller-separation fixture never creates the unpaired book

**1 failures · Test fixture likely; production separation not exercised · Medium · confidence: Medium–high.**

The weighted Camelot case fails at `assertGt(reservedFace, 0)` before the other-token caller-separation operation. Its setup leaves zero unpaired input, so the intended attack condition is absent.

**Next resolution:** construct and prove a real unpaired reserve through the family-supported flow, then keep the subsequent no-cross-caller-credit checks. Investigate whether changed automatic investing consumed the setup amount before deciding that production is wrong.

Source anchors: [UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol](../../test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol).

Representative log entries: [UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_CamelotV2StandardExchange::test_row_ammCallerFundSeparation](../../ERRORS.log#L37).

<a id="r15"></a>

### R15 — One-unit AMM dust previews and execution do not share rejection behavior

**3 failures · Unresolved preview/execution contract or fixture assumption · Medium–large · confidence: Medium.**

Three single-hook rows hit the shared no-partial-case dust branch: Aerodrome, Camelot V2, and Uniswap V2. The Camelot nested error decodes to `CamelotPair: INSUFFICIENT_OUTPUT_AMOUNT`; Uniswap V2 reports `UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT`. Aerodrome supplies nested selector `0x42301c23`, which was not identified in this bounded review. The helper assumes a successful preview permits execution even if the preview is zero.

**Next resolution:** establish the intended zero-quote execution contract. If zero is an unsupported/unexecutable sentinel, a preview of zero need not authorize taking the user's dust. If the product promises a booked dust deposit, the rejecting execution is a defect. Trace only one representative per AMM family and retain exact rollback/custody checks.

Source anchors: [UniswapV4SingleSEBufferHook_SeMatrixBehavior.sol](../../test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_SeMatrixBehavior.sol).

Representative log entries: [UniswapV4SingleSEBufferHook_SeMatrix_AerodromeStandardExchange::test_row_partialConsumption_bookedNotRefunded](../../ERRORS.log#L7), [UniswapV4SingleSEBufferHook_SeMatrix_CamelotV2StandardExchange::test_row_partialConsumption_bookedNotRefunded](../../ERRORS.log#L10), [UniswapV4SingleSEBufferHook_SeMatrix_UniswapV2StandardExchange::test_row_partialConsumption_bookedNotRefunded](../../ERRORS.log#L31).

<a id="r16"></a>

### R16 — Composed-stable execution errors differ from expected route/liveness errors

**2 failures · Unresolved validation order and fixture state; scope hold · Medium–large · confidence: Medium.**

Two execution failures remain after separating out stale preview expectations: unsupported output returns `ExchangeOutNotAvailable` rather than `InvalidRoute`; the supposedly uninitialized reserve reaches `MaxOutRatio` rather than `ReservePoolNotInitialized`. The first may be a public-error rename; the second may be an already-initialized fixture or a missing production liveness gate.

**Next resolution:** verify actual reserve state before the call, then trace the first rejecting layer. Retain execution rejection and rollback. Discuss D60's exclusion of Balancer-hosted DETF functional changes before authorizing production work here.

Source anchors: [ComposedStableCommonDetfExchangeOutQueryFacet.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfExchangeOutQueryFacet.t.sol), [DETF_ALIGNMENT_PRD.md](../../contracts/vaults/detf/DETF_ALIGNMENT_PRD.md).

Representative log entries: [ComposedStableCommonDetfExchangeOutQueryFacet_Test::test_exchangeOut_revertsForUnsupportedTokenOut](../../ERRORS.log#L202), [ComposedStableCommonDetfExchangeOutQueryFacet_Test::test_exchangeOut_revertsWhenReservePoolUninitialized](../../ERRORS.log#L203).

<a id="r17"></a>

### R17 — Deployed runtime exceeds EIP-170

**16 failures · Production packaging/deployability defect · Large; release blocker · confidence: High for logged sizes.**

Sixteen failures are repeated witnesses for several oversized components, not sixteen independent size bugs. Logged families: Orbital SE facet 28,000 bytes (3 witnesses); CurveQuad liquidity facet 28,288 (2); Balancer stable hook 26,624 (1); Aerodrome 30,531 (2); V3 FullSpread query component 31,843 (2); V4 Hookless 30,646 (2); V4 Pons 30,615 (4). The limit asserted by all is 24,576 bytes.

**Next resolution:** rebuild current runtime artifacts, map each anonymous size assertion to its exact facet/delegate, and deduplicate by deployed bytecode. Reuse existing delegates or facet partitions before designing new ones; preserve selectors, guards, caller identity, and SY routing. Validate every installed component after refactoring. Never relax the size assertion or increase the deployment limit to green these tests. Current source/artifact freshness remains to be checked against the supplied log.

Source anchors: [V4FundedBindings.t.sol](../../test/foundry/spec/vaults/detf/common/claimToken/V4FundedBindings.t.sol), [ARTIFACT_BUILDS.md](../../docs/testing/ARTIFACT_BUILDS.md).

Representative log entries: [UniswapV4StandardExchangeOrbitalBufferHook_SeBufferAbi::test_nativeSYMetadataAndInstalledFacetSizes](../../ERRORS.log#L4), [CurveQuadFundedBindingTest::test_bindingHookComponentsFitAndSelectorsAreInstalled](../../ERRORS.log#L108), [OrbitalFundedBindingTest::test_bindingHookComponentsFitAndSelectorsAreInstalled](../../ERRORS.log#L111).

<a id="r18"></a>

### R18 — DETF funded lifecycle ZeroAmount cascade

**1,389 failures · Likely shared production/integration failure; exact cause unproven · Large uncertainty; highest diagnostic leverage · confidence: High for clustering; low for a single root cause.**

This group contains 1,387 direct `ZeroAmount()` failures plus 2 custom-donation cases that expected `MinAmountNotMet` but received `ZeroAmount`. Of the direct failures, 1,357 are in the V4 DETF family tree, 22 are in `V4ReserveLiquidity`, and 8 are in funded-claim/bond or token-staking integration suites. Repeated failures span closes, claims, donations, funded rewards, mint/burn policy, later bonds, and production SE/decimal variants.

Source inspection shows representative tests perform an initial/later bond or common funded setup before their named assertions. Several production components define the same error: DETF active-amount checks, zero principal at bond creation, staking exchange, funded reward input, and reserve/donation exits. Therefore the log cannot identify the reverting component, and equal selectors do not establish one root cause. In particular `_fundStakingRewards` already skips amount zero: a blanket claim that it simply calls `fundRewards(0)` is not supported.

**Next resolution:** trace a small base funded sequence first, then one failing CP reserve-liquidity case and one production-SE decimal variant. Record the first failed call, exact input/output, and whether setup or the actual test action fails. Partition by that first failing frame. Restore intended funded setup before interpreting hundreds of downstream assertions; preserve funded-only principal/rewards, entitlement and no-donation-capture invariants. Do not add arbitrary larger inputs or expect `ZeroAmount` in all these tests.

The small-primary-burn and first-payable-boundary cases remain within this queue but may be independent zero-rounding defects; do not automatically close them when ordinary bonding is repaired.

Source anchors: [UniswapV4DetfCommon.sol](../../contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol), [UniswapV4DetfTarget.sol](../../contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfTarget.sol), [DETFFundedBondTarget.sol](../../contracts/vaults/detf/common/bondNft/DETFFundedBondTarget.sol), [StakedDETFTarget.sol](../../contracts/vaults/detf/common/claimToken/StakedDETFTarget.sol), [FundedStakingSequence.t.sol](../../test/foundry/spec/vaults/detf/common/claimToken/FundedStakingSequence.t.sol), [V4ReserveLiquidity.t.sol](../../test/foundry/spec/vaults/detf/common/claimToken/V4ReserveLiquidity.t.sol).

Representative log entries: [TokenStakingMigrationScript::test_e2e_stake_dtf_migrate_chunks_withdraw_claim](../../ERRORS.log#L83), [TokenStaking_PonsUv4Detf::test_e2e_stake_dtf_migrate_chunks_withdraw_claim](../../ERRORS.log#L91), [DETFNFTVaultDFPkg_Deploy_Test::test_feeRoleTransferSettlesOldBoundaryThenPaysNewOwnerOnLaterMint](../../ERRORS.log#L94).

<a id="r19"></a>

### R19 — Orbital low-decimal alignment cannot find an executable result

**10 failures · Unresolved solver feasibility/rounding or fixture boundary · Large/research · confidence: Medium for common scope.**

Ten failures concentrate in Orbital DETFs over Morpho-mix and V4 SE dependencies. They affect donation, second-donation, self-leg donation, and a burn-policy case, often with 6-decimal tokens. The error is a solver/feasibility rejection, not the funded lifecycle's `ZeroAmount` symptom.

**Next resolution:** reproduce one case per dependency and measure search bounds, attainable native outputs, rounding steps, ratio target and any residual. Distinguish a truly infeasible target from a search that skips a feasible discrete solution. Confirm the intended action when exact alignment is unattainable before changing either assertions or tolerances.

Source anchors: [DETF_ALIGNMENT_PRD.md](../../contracts/vaults/detf/DETF_ALIGNMENT_PRD.md).

Representative log entries: [UniswapV4Detf_Orbital_MorphoMix_ProductLaw_B_ALL6::test_DN21_d2_afterDonate](../../ERRORS.log#L1608), [UniswapV4Detf_Orbital_MorphoMix_ProductLaw_B_P6_R18::test_DN21_d2_afterDonate](../../ERRORS.log#L1625), [UniswapV4Detf_Orbital_MorphoMix_ProductLaw_B_P6_R9::test_DN21_d2_afterDonate](../../ERRORS.log#L1630).

<a id="r20"></a>

### R20 — Later-bond residual remains large enough to mint LP

**2 failures · Production residual handling or stale economic assertion · Large/research · confidence: Medium.**

Two CP DETF/V3 SE decimal cases assert that remaining dust cannot mint hook LP, but the independent quote returns 780744733934 or 699389631011 LP units. The assertion concerns whether a subsequent investment is worthwhile/executable, not a one-wei balance tolerance.

**Next resolution:** distinguish a quote from an executable join after all rate, rounding and context restrictions. If executable, inspect missing residual investment/booking; if deliberately retained, document the governing policy and assert retry/custody behavior instead. Resolve the intended residual policy with the owner before weakening the zero-LP assertion.

Source anchors: [UniswapV4Detf_Cp_Univ3Se_ProductLaw_P6_R18.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Cp_Univ3Se_ProductLaw_P6_R18.t.sol), [UniswapV4Detf_Cp_Univ3Se_ProductLaw_P6_R9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Cp_Univ3Se_ProductLaw_P6_R9.t.sol).

Representative log entries: [UniswapV4Detf_Cp_Univ3Se_ProductLaw_P6_R18::test_T7_10_laterBond_joinUnbalanced_unboostedG](../../ERRORS.log#L1307), [UniswapV4Detf_Cp_Univ3Se_ProductLaw_P6_R9::test_T7_10_laterBond_joinUnbalanced_unboostedG](../../ERRORS.log#L1312).

<a id="r21"></a>

### R21 — Invariant replay fails before useful invariant evidence

**2 failures · Unresolved handler/setup or production failure · Research after prerequisite repair · confidence: Low on underlying cause.**

Two failures have multiline replay records, not normal `[FAIL] test...` lines. The DETF `invariant_accounting` shrinks to one `cycle(uint256,uint256)` call; the Wings witness shrinks to one `rebalance()` call. Both show one revert. Neither supplied record identifies the inner revert or proves an accounting/custody invariant violation.

**Next resolution:** preserve and replay the exact supplied sender/calldata/arguments, locate the handler failure, and check whether its action witness was actually reached. The DETF replay may depend on R18; Wings requires a separate trace. Do not delete cached counterexamples or suppress handler reverts merely to get a green invariant run.

Source anchors: [UniswapV4Detf_Invariant.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/invariant/UniswapV4Detf_Invariant.t.sol), [ApexRecurrenceInvariantWitness.t.sol](../../test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/ApexRecurrenceInvariantWitness.t.sol).

Representative log entries: [UniswapV4Detf_Invariant::invariant_accounting](../../ERRORS.log#L798), [WingsApexRecurrenceInvariantWitnessTest::invariant_review_actionWitnessesAndCustody](../../ERRORS.log#L2075).

<a id="r22"></a>

### R22 — Reentrancy test fails its unlocked positive control

**3 failures · Blocked security test; likely shared setup dependency · Research after funded-path diagnosis · confidence: High that the guard itself has not been tested.**

Three tests fail the assertion `funded callback succeeds outside the lock`. This is the positive control used to establish that the callback is otherwise viable, before concluding that the locked call is rejected by the reentrancy guard. It is not evidence that reentrancy was accepted.

**Next resolution:** inspect the unlocked control's revert and establish its funding/route prerequisites, cross-checking R18. Then retain both a successful unlocked control and the exact expected locked rejection. Do not remove the positive control or accept an arbitrary revert as proof that the guard works.

Source anchors: [Adversarial_Reentrancy.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/adversarial/Adversarial_Reentrancy.t.sol), [Adversarial_Reentrancy_Decimals.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/adversarial/Adversarial_Reentrancy_Decimals.sol).

Representative log entries: [Adversarial_Reentrancy::test_reentrancy_mint_hitsIsLocked](../../ERRORS.log#L308), [Adversarial_Reentrancy_P18_R6_DexUniV4Det::test_reentrancy_mint_hitsIsLocked](../../ERRORS.log#L792), [Adversarial_Reentrancy_P18_R9_DexUniV4Det::test_reentrancy_mint_hitsIsLocked](../../ERRORS.log#L795).

## Complete failure inventory

Each failure appears once below under its primary group. Entries link to the source test file and the precise failure line in the supplied log; inherited tests may be implemented in a shared base. The group findings identify shared helpers where inspected. A group membership is a work-queue assignment, not proof of a common first reverting frame.

### Inventory R01 — 25 failures

**UniswapV4StandardExchangeOrbitalBufferHook_SeBufferAbi** — [UniswapV4StandardExchangeOrbitalBufferHook_SeBufferAbi.t.sol](../../test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeBufferAbi.t.sol) (1 failure).

- [L3](../../ERRORS.log#L3) `test_nativeSYInternalBalanceLimitsAndPriorInventory()`

**RebasingClaimTokenDFPkg_Deploy_Test** — [RebasingClaimTokenDFPkg_Deploy.t.sol](../../test/foundry/spec/vaults/detf/common/claimToken/RebasingClaimTokenDFPkg_Deploy.t.sol) (1 failure).

- [L101](../../ERRORS.log#L101) `test_nativeSYUsesStandardRoutesAndPreservesUnredeemedInternalShares()`

**AaveStataNativeSYTest** — [AaveStataNativeSY.t.sol](../../test/foundry/spec/vaults/standard/sy/AaveStataNativeSY.t.sol) (1 failure).

- [L2081](../../ERRORS.log#L2081) `test_stataInternalBalanceConsumesOnlyRequestedShares()`

**BalancerCommonStablePoolNativeSYTest** — [BalancerPoolNativeSY.t.sol](../../test/foundry/spec/vaults/standard/sy/BalancerPoolNativeSY.t.sol) (1 failure).

- [L2084](../../ERRORS.log#L2084) `test_poolSYInternalBalanceConsumesOnlyRequestedShares()`

**BalancerCommonWeightedPoolNativeSYTest** — [BalancerPoolNativeSY.t.sol](../../test/foundry/spec/vaults/standard/sy/BalancerPoolNativeSY.t.sol) (1 failure).

- [L2088](../../ERRORS.log#L2088) `test_poolSYInternalBalanceConsumesOnlyRequestedShares()`

**BalancerConstantProductPoolNativeSYTest** — [BalancerPoolNativeSY.t.sol](../../test/foundry/spec/vaults/standard/sy/BalancerPoolNativeSY.t.sol) (1 failure).

- [L2092](../../ERRORS.log#L2092) `test_poolSYInternalBalanceConsumesOnlyRequestedShares()`

**BalancerCpBufferPoolNativeSYTest** — [BalancerPoolNativeSY.t.sol](../../test/foundry/spec/vaults/standard/sy/BalancerPoolNativeSY.t.sol) (1 failure).

- [L2095](../../ERRORS.log#L2095) `test_poolSYInternalBalanceConsumesOnlyRequestedShares()`

**BalancerMixedLegPoolNativeSYTest** — [BalancerPoolNativeSY.t.sol](../../test/foundry/spec/vaults/standard/sy/BalancerPoolNativeSY.t.sol) (1 failure).

- [L2099](../../ERRORS.log#L2099) `test_poolSYInternalBalanceConsumesOnlyRequestedShares()`

**BalancerMixedStablePoolNativeSYTest** — [BalancerPoolNativeSY.t.sol](../../test/foundry/spec/vaults/standard/sy/BalancerPoolNativeSY.t.sol) (1 failure).

- [L2103](../../ERRORS.log#L2103) `test_poolSYInternalBalanceConsumesOnlyRequestedShares()`

**BalancerMultiPairPoolNativeSYTest** — [BalancerPoolNativeSY.t.sol](../../test/foundry/spec/vaults/standard/sy/BalancerPoolNativeSY.t.sol) (1 failure).

- [L2107](../../ERRORS.log#L2107) `test_poolSYInternalBalanceConsumesOnlyRequestedShares()`

**BalancerStableBufferHookNativeSYTest** — [BalancerStableBufferHookNativeSY.t.sol](../../test/foundry/spec/vaults/standard/sy/BalancerStableBufferHookNativeSY.t.sol) (1 failure).

- [L2111](../../ERRORS.log#L2111) `test_balancerStableSYInternalSharesBurnOnlyRequestedAmountAndPaySeShares()`

**AerodromeNativeSYTest** — [ConstantProductNativeSY.t.sol](../../test/foundry/spec/vaults/standard/sy/ConstantProductNativeSY.t.sol) (1 failure).

- [L2117](../../ERRORS.log#L2117) `test_nativePartialInternalRedemptionPreservesOtherHeldShares()`

**CamelotV2NativeSYTest** — [ConstantProductNativeSY.t.sol](../../test/foundry/spec/vaults/standard/sy/ConstantProductNativeSY.t.sol) (1 failure).

- [L2120](../../ERRORS.log#L2120) `test_nativePartialInternalRedemptionPreservesOtherHeldShares()`

**UniswapV2NativeSYTest** — [ConstantProductNativeSY.t.sol](../../test/foundry/spec/vaults/standard/sy/ConstantProductNativeSY.t.sol) (1 failure).

- [L2123](../../ERRORS.log#L2123) `test_nativePartialInternalRedemptionPreservesOtherHeldShares()`

**CurveQuadBufferHookNativeSYTest** — [CurveQuadBufferHookNativeSY.t.sol](../../test/foundry/spec/vaults/standard/sy/CurveQuadBufferHookNativeSY.t.sol) (1 failure).

- [L2126](../../ERRORS.log#L2126) `test_curveQuadSYInternalSharesBurnOnlyRequestedAmountAndPaySeShares()`

**CurveQuadBufferHookRestrictedSYTest** — [CurveQuadBufferHookNativeSY.t.sol](../../test/foundry/spec/vaults/standard/sy/CurveQuadBufferHookNativeSY.t.sol) (1 failure).

- [L2130](../../ERRORS.log#L2130) `test_restrictedSYInternalRedemptionPreservesCallerAndClearsAuthorization()`

**DualBufferHookLiquidityRegressionTest** — [DualBufferHookNativeSY.t.sol](../../test/foundry/spec/vaults/standard/sy/DualBufferHookNativeSY.t.sol) (1 failure).

- [L2133](../../ERRORS.log#L2133) `test_dualNativeSYInternalRedemptionAndLimits()`

**EtherFiNativeSYTest** — [LiquidStakingNativeSY.t.sol](../../test/foundry/spec/vaults/standard/sy/LiquidStakingNativeSY.t.sol) (1 failure).

- [L2136](../../ERRORS.log#L2136) `test_liquidStakingInternalRedemptionKeepsUnburnedShares()`

**LidoNativeSYTest** — [LiquidStakingNativeSY.t.sol](../../test/foundry/spec/vaults/standard/sy/LiquidStakingNativeSY.t.sol) (1 failure).

- [L2139](../../ERRORS.log#L2139) `test_liquidStakingInternalRedemptionKeepsUnburnedShares()`

**RocketPoolNativeSYTest** — [LiquidStakingNativeSY.t.sol](../../test/foundry/spec/vaults/standard/sy/LiquidStakingNativeSY.t.sol) (1 failure).

- [L2142](../../ERRORS.log#L2142) `test_liquidStakingInternalRedemptionKeepsUnburnedShares()`

**MorphoBlueNativeSYTest** — [MorphoBlueNativeSY.t.sol](../../test/foundry/spec/vaults/standard/sy/MorphoBlueNativeSY.t.sol) (1 failure).

- [L2145](../../ERRORS.log#L2145) `test_morphoSYInternalRedemptionPreservesRemainingProxyShares()`

**SingleConstantProductHookNativeSYTest** — [SingleConstantProductHookNativeSY.t.sol](../../test/foundry/spec/vaults/standard/sy/SingleConstantProductHookNativeSY.t.sol) (1 failure).

- [L2148](../../ERRORS.log#L2148) `test_hookSYInternalRedemptionBurnsOnlyRequestedShares()`

**SingleConstantProductHookRestrictedSYTest** — [SingleConstantProductHookNativeSY.t.sol](../../test/foundry/spec/vaults/standard/sy/SingleConstantProductHookNativeSY.t.sol) (1 failure).

- [L2151](../../ERRORS.log#L2151) `test_restrictedSYInternalRedemptionPreservesCallerAndClearsAuthorization()`

**WeightedBufferHookNativeSYTest** — [WeightedBufferHookNativeSY.t.sol](../../test/foundry/spec/vaults/standard/sy/WeightedBufferHookNativeSY.t.sol) (1 failure).

- [L2157](../../ERRORS.log#L2157) `test_weightedSYInternalSharesBurnOnlyRequestedAmountAndPaySeShares()`

**WeightedBufferHookRestrictedSYTest** — [WeightedBufferHookNativeSY.t.sol](../../test/foundry/spec/vaults/standard/sy/WeightedBufferHookNativeSY.t.sol) (1 failure).

- [L2160](../../ERRORS.log#L2160) `test_restrictedSYInternalRedemptionPreservesCallerAndClearsAuthorization()`

### Inventory R02 — 29 failures

**CpPublicReserveLiquidityTest** — [V4ReserveLiquidity.t.sol](../../test/foundry/spec/vaults/detf/common/claimToken/V4ReserveLiquidity.t.sol) (1 failure).

- [L128](../../ERRORS.log#L128) `test_lpCannotReplaceFirstBondActivation()`

**CpReserveLiquidityTest** — [V4ReserveLiquidity.t.sol](../../test/foundry/spec/vaults/detf/common/claimToken/V4ReserveLiquidity.t.sol) (1 failure).

- [L141](../../ERRORS.log#L141) `test_lpCannotReplaceFirstBondActivation()`

**CurveQuadPublicReserveLiquidityTest** — [V4ReserveLiquidity.t.sol](../../test/foundry/spec/vaults/detf/common/claimToken/V4ReserveLiquidity.t.sol) (1 failure).

- [L144](../../ERRORS.log#L144) `test_lpCannotReplaceFirstBondActivation()`

**CurveQuadReserveLiquidityTest** — [V4ReserveLiquidity.t.sol](../../test/foundry/spec/vaults/detf/common/claimToken/V4ReserveLiquidity.t.sol) (1 failure).

- [L147](../../ERRORS.log#L147) `test_lpCannotReplaceFirstBondActivation()`

**OrbitalPublicReserveLiquidityTest** — [V4ReserveLiquidity.t.sol](../../test/foundry/spec/vaults/detf/common/claimToken/V4ReserveLiquidity.t.sol) (1 failure).

- [L152](../../ERRORS.log#L152) `test_lpCannotReplaceFirstBondActivation()`

**OrbitalReserveLiquidityTest** — [V4ReserveLiquidity.t.sol](../../test/foundry/spec/vaults/detf/common/claimToken/V4ReserveLiquidity.t.sol) (1 failure).

- [L157](../../ERRORS.log#L157) `test_lpCannotReplaceFirstBondActivation()`

**WeightedPublicReserveLiquidityTest** — [V4ReserveLiquidity.t.sol](../../test/foundry/spec/vaults/detf/common/claimToken/V4ReserveLiquidity.t.sol) (1 failure).

- [L160](../../ERRORS.log#L160) `test_lpCannotReplaceFirstBondActivation()`

**WeightedReserveLiquidityTest** — [V4ReserveLiquidity.t.sol](../../test/foundry/spec/vaults/detf/common/claimToken/V4ReserveLiquidity.t.sol) (1 failure).

- [L163](../../ERRORS.log#L163) `test_lpCannotReplaceFirstBondActivation()`

**MixedBufferMultiVaultStableDetf_Routes_Test** — [MixedBufferMultiVaultStableDetf_Routes.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/MixedBufferMultiVaultStableDetf_Routes.t.sol) (1 failure).

- [L166](../../ERRORS.log#L166) `test_exactOut_InvalidRoute()`

**MixedBufferMultiVaultStableDetf_Routes_NativeMatrix** — [MixedBufferMultiVaultStableDetf_Routes_NativeMatrix.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/decimals/MixedBufferMultiVaultStableDetf_Routes_NativeMatrix.t.sol) (1 failure).

- [L169](../../ERRORS.log#L169) `test_exactOut_InvalidRoute()`

**MultiVaultWeightedDetf_MintBurn_Test** — [MultiVaultWeightedDetf_MintBurn.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/MultiVaultWeightedDetf_MintBurn.t.sol) (1 failure).

- [L172](../../ERRORS.log#L172) `test_invalidRoute_exactOut()`

**MultiVaultWeightedDetf_MintBurn_B_ALL6** — [MultiVaultWeightedDetf_MintBurn_B_ALL6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/decimals/MultiVaultWeightedDetf_MintBurn_B_ALL6.t.sol) (1 failure).

- [L175](../../ERRORS.log#L175) `test_invalidRoute_exactOut()`

**MultiVaultWeightedDetf_MintBurn_B_ALL9** — [MultiVaultWeightedDetf_MintBurn_B_ALL9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/decimals/MultiVaultWeightedDetf_MintBurn_B_ALL9.t.sol) (1 failure).

- [L178](../../ERRORS.log#L178) `test_invalidRoute_exactOut()`

**MultiVaultWeightedDetf_MintBurn_B_P18_R6** — [MultiVaultWeightedDetf_MintBurn_B_P18_R6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/decimals/MultiVaultWeightedDetf_MintBurn_B_P18_R6.t.sol) (1 failure).

- [L181](../../ERRORS.log#L181) `test_invalidRoute_exactOut()`

**MultiVaultWeightedDetf_MintBurn_B_P18_R9** — [MultiVaultWeightedDetf_MintBurn_B_P18_R9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/decimals/MultiVaultWeightedDetf_MintBurn_B_P18_R9.t.sol) (1 failure).

- [L184](../../ERRORS.log#L184) `test_invalidRoute_exactOut()`

**MultiVaultWeightedDetf_MintBurn_B_P6_R18** — [MultiVaultWeightedDetf_MintBurn_B_P6_R18.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/decimals/MultiVaultWeightedDetf_MintBurn_B_P6_R18.t.sol) (1 failure).

- [L187](../../ERRORS.log#L187) `test_invalidRoute_exactOut()`

**MultiVaultWeightedDetf_MintBurn_B_P6_R9** — [MultiVaultWeightedDetf_MintBurn_B_P6_R9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/decimals/MultiVaultWeightedDetf_MintBurn_B_P6_R9.t.sol) (1 failure).

- [L190](../../ERRORS.log#L190) `test_invalidRoute_exactOut()`

**MultiVaultWeightedDetf_MintBurn_B_P9_R18** — [MultiVaultWeightedDetf_MintBurn_B_P9_R18.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/decimals/MultiVaultWeightedDetf_MintBurn_B_P9_R18.t.sol) (1 failure).

- [L193](../../ERRORS.log#L193) `test_invalidRoute_exactOut()`

**MultiVaultWeightedDetf_MintBurn_B_P9_R6** — [MultiVaultWeightedDetf_MintBurn_B_P9_R6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/decimals/MultiVaultWeightedDetf_MintBurn_B_P9_R6.t.sol) (1 failure).

- [L196](../../ERRORS.log#L196) `test_invalidRoute_exactOut()`

**ComposedStableCommonDetfExchangeIn_Test** — [ComposedStableCommonDetfExchangeIn.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfExchangeIn.t.sol) (1 failure).

- [L199](../../ERRORS.log#L199) `test_previewExchangeIn_revertsWhenReservePoolUninitialized()`

**ComposedStableCommonDetfExchangeOutQueryFacet_Test** — [ComposedStableCommonDetfExchangeOutQueryFacet.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfExchangeOutQueryFacet.t.sol) (3 failures).

- [L204](../../ERRORS.log#L204) `test_previewExchangeOut_revertsForUnsupportedTokenIn()`
- [L205](../../ERRORS.log#L205) `test_previewExchangeOut_revertsForUnsupportedTokenOut()`
- [L206](../../ERRORS.log#L206) `test_previewExchangeOut_revertsWhenReservePoolUninitialized()`

**BalancerCommonStablePoolNativeSYTest** — [BalancerPoolNativeSY.t.sol](../../test/foundry/spec/vaults/standard/sy/BalancerPoolNativeSY.t.sol) (1 failure).

- [L2085](../../ERRORS.log#L2085) `test_poolSYVirtualBuffersAreRejectedBeforeAnyAssetIsTaken()`

**BalancerCommonWeightedPoolNativeSYTest** — [BalancerPoolNativeSY.t.sol](../../test/foundry/spec/vaults/standard/sy/BalancerPoolNativeSY.t.sol) (1 failure).

- [L2089](../../ERRORS.log#L2089) `test_poolSYVirtualBuffersAreRejectedBeforeAnyAssetIsTaken()`

**BalancerCpBufferPoolNativeSYTest** — [BalancerPoolNativeSY.t.sol](../../test/foundry/spec/vaults/standard/sy/BalancerPoolNativeSY.t.sol) (1 failure).

- [L2096](../../ERRORS.log#L2096) `test_poolSYVirtualBuffersAreRejectedBeforeAnyAssetIsTaken()`

**BalancerMixedLegPoolNativeSYTest** — [BalancerPoolNativeSY.t.sol](../../test/foundry/spec/vaults/standard/sy/BalancerPoolNativeSY.t.sol) (1 failure).

- [L2100](../../ERRORS.log#L2100) `test_poolSYVirtualBuffersAreRejectedBeforeAnyAssetIsTaken()`

**BalancerMixedStablePoolNativeSYTest** — [BalancerPoolNativeSY.t.sol](../../test/foundry/spec/vaults/standard/sy/BalancerPoolNativeSY.t.sol) (1 failure).

- [L2104](../../ERRORS.log#L2104) `test_poolSYVirtualBuffersAreRejectedBeforeAnyAssetIsTaken()`

**BalancerMultiPairPoolNativeSYTest** — [BalancerPoolNativeSY.t.sol](../../test/foundry/spec/vaults/standard/sy/BalancerPoolNativeSY.t.sol) (1 failure).

- [L2108](../../ERRORS.log#L2108) `test_poolSYVirtualBuffersAreRejectedBeforeAnyAssetIsTaken()`

### Inventory R03 — 7 failures

**UniswapV4FullSpreadHooklessStandardExchangeVaultRateProviderContextParityTest** — [RateProviderContextParity.t.sol](../../test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/RateProviderContextParity.t.sol) (1 failure).

- [L2040](../../ERRORS.log#L2040) `test_shortLocalCoverCannotShrinkOnlyLiveRateProbe()`

**UniswapV4FullSpreadHooklessStandardExchangeVaultRateProviderDecimalContextTest** — [RateProviderContextParity.t.sol](../../test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/RateProviderContextParity.t.sol) (1 failure).

- [L2043](../../ERRORS.log#L2043) `test_shortLocalCoverCannotShrinkOnlyLiveRateProbe()`

**HooklessRouteFundingClosureTest** — [RouteFundingClosure.t.sol](../../test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/RouteFundingClosure.t.sol) (2 failures).

- [L2046](../../ERRORS.log#L2046) `test_blockedDirectExactInputRejectsBothDirections()`
- [L2047](../../ERRORS.log#L2047) `test_multiMalformedVectorsAndMissingSecondCredit()`

**UniswapV4FullSpreadPonsFamilyHookRateProviderContextParityTest** — [RateProviderContextParity.t.sol](../../test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/RateProviderContextParity.t.sol) (1 failure).

- [L2056](../../ERRORS.log#L2056) `test_shortLocalCoverCannotShrinkOnlyLiveRateProbe()`

**PonsRouteFundingClosureTest** — [RouteFundingClosure.t.sol](../../test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/RouteFundingClosure.t.sol) (2 failures).

- [L2059](../../ERRORS.log#L2059) `test_blockedDirectExactInputRejectsBothDirections()`
- [L2060](../../ERRORS.log#L2060) `test_multiMalformedVectorsAndMissingSecondCredit()`

### Inventory R04 — 12 failures

**UniswapV4SingleSEBufferHook_SeMatrix_CommonBufferMultiVaultStablePool** — [UniswapV4SingleSEBufferHook_SeMatrix_CommonBufferMultiVaultStablePool.t.sol](../../test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_SeMatrix_CommonBufferMultiVaultStablePool.t.sol) (1 failure).

- [L13](../../ERRORS.log#L13) `test_row_partialConsumption_bookedNotRefunded()`

**UniswapV4SingleSEBufferHook_SeMatrix_CommonBufferMultiVaultWeightedPool** — [UniswapV4SingleSEBufferHook_SeMatrix_CommonBufferMultiVaultWeightedPool.t.sol](../../test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_SeMatrix_CommonBufferMultiVaultWeightedPool.t.sol) (1 failure).

- [L16](../../ERRORS.log#L16) `test_row_partialConsumption_bookedNotRefunded()`

**UniswapV4SingleSEBufferHook_SeMatrix_MixedBufferMultiVaultStablePool** — [UniswapV4SingleSEBufferHook_SeMatrix_MixedBufferMultiVaultStablePool.t.sol](../../test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_SeMatrix_MixedBufferMultiVaultStablePool.t.sol) (1 failure).

- [L19](../../ERRORS.log#L19) `test_row_partialConsumption_bookedNotRefunded()`

**UniswapV4SingleSEBufferHook_SeMatrix_MixedLegWeightedBufferPool** — [UniswapV4SingleSEBufferHook_SeMatrix_MixedLegWeightedBufferPool.t.sol](../../test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_SeMatrix_MixedLegWeightedBufferPool.t.sol) (1 failure).

- [L22](../../ERRORS.log#L22) `test_row_partialConsumption_bookedNotRefunded()`

**UniswapV4SingleSEBufferHook_SeMatrix_MultiPairStandardExchangeBufferPool** — [UniswapV4SingleSEBufferHook_SeMatrix_MultiPairStandardExchangeBufferPool.t.sol](../../test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_SeMatrix_MultiPairStandardExchangeBufferPool.t.sol) (1 failure).

- [L25](../../ERRORS.log#L25) `test_row_partialConsumption_bookedNotRefunded()`

**UniswapV4SingleSEBufferHook_SeMatrix_StandardExchangeBufferPool** — [UniswapV4SingleSEBufferHook_SeMatrix_StandardExchangeBufferPool.t.sol](../../test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_SeMatrix_StandardExchangeBufferPool.t.sol) (1 failure).

- [L28](../../ERRORS.log#L28) `test_row_partialConsumption_bookedNotRefunded()`

**UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_CommonBufferMultiVaultStablePool** — [UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_CommonBufferMultiVaultStablePool.t.sol](../../test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_CommonBufferMultiVaultStablePool.t.sol) (1 failure).

- [L40](../../ERRORS.log#L40) `test_row_partialConsumption_bookedNotRefunded()`

**UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_CommonBufferMultiVaultWeightedPool** — [UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_CommonBufferMultiVaultWeightedPool.t.sol](../../test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_CommonBufferMultiVaultWeightedPool.t.sol) (1 failure).

- [L43](../../ERRORS.log#L43) `test_row_partialConsumption_bookedNotRefunded()`

**UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_MixedBufferMultiVaultStablePool** — [UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_MixedBufferMultiVaultStablePool.t.sol](../../test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_MixedBufferMultiVaultStablePool.t.sol) (1 failure).

- [L52](../../ERRORS.log#L52) `test_row_partialConsumption_bookedNotRefunded()`

**UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_MixedLegWeightedBufferPool** — [UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_MixedLegWeightedBufferPool.t.sol](../../test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_MixedLegWeightedBufferPool.t.sol) (1 failure).

- [L55](../../ERRORS.log#L55) `test_row_partialConsumption_bookedNotRefunded()`

**UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_MultiPairStandardExchangeBufferPool** — [UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_MultiPairStandardExchangeBufferPool.t.sol](../../test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_MultiPairStandardExchangeBufferPool.t.sol) (1 failure).

- [L58](../../ERRORS.log#L58) `test_row_partialConsumption_bookedNotRefunded()`

**UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_StandardExchangeBufferPool** — [UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_StandardExchangeBufferPool.t.sol](../../test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_StandardExchangeBufferPool.t.sol) (1 failure).

- [L61](../../ERRORS.log#L61) `test_row_partialConsumption_bookedNotRefunded()`

### Inventory R05 — 8 failures

**WrappedStandardExchangeRateProvider_Test** — [WrappedStandardExchangeRateProvider.t.sol](../../test/foundry/spec/protocol/dexes/balancer/v3/WrappedStandardExchangeRateProvider.t.sol) (2 failures).

- [L70](../../ERRORS.log#L70) `test_recurrence_D48_wrappedExhaustionAttemptsClampAtSupply()`
- [L71](../../ERRORS.log#L71) `test_recurrence_D48_wrappedScaleUpRecoveryAmounts()`

**FeeAccrualCustodyScript** — [FeeAccrualCustodyScript.t.sol](../../test/foundry/spec/protocols/staking/token/FeeAccrualCustodyScript.t.sol) (1 failure).

- [L80](../../ERRORS.log#L80) `test_custodyProvider_normalizesWholeSharesAndTracksDonations()`

**MorphoBlueStandardExchange_RateProvider** — [MorphoBlueStandardExchange_RateProvider.t.sol](../../test/foundry/spec/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueStandardExchange_RateProvider.t.sol) (5 failures).

- [L2030](../../ERRORS.log#L2030) `test_APEX_D48_quoteRate_nonemptyState_usesQuoteAssets()`
- [L2031](../../ERRORS.log#L2031) `test_recurrence_D48_failureExhaustsExactlyEighteenHalvings()`
- [L2032](../../ERRORS.log#L2032) `test_recurrence_D48_halvingAmountsAndRecovery()`
- [L2033](../../ERRORS.log#L2033) `test_recurrence_D48_unrelatedProjectionUsesLiveContext()`
- [L2034](../../ERRORS.log#L2034) `test_recurrence_D48_zeroQuoteScalesUpAndRecovers()`

### Inventory R06 — 1 failures

**ERC4626StandardExchange_Adversarial** — [ERC4626StandardExchange_Adversarial.t.sol](../../test/foundry/spec/vaults/standard/erc4626/adversarial/ERC4626StandardExchange_Adversarial.t.sol) (1 failure).

- [L2024](../../ERRORS.log#L2024) `test_J1_facetFuncs_coversTargetApi()`

### Inventory R07 — 1 failures

**UniswapV4Detf_Cp_Univ4Se_ProductLaw_H6** — [UniswapV4Detf_Cp_Univ4Se_ProductLaw_H6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Cp_Univ4Se_ProductLaw_H6.t.sol) (1 failure).

- [L1357](../../ERRORS.log#L1357) `test_alignmentResidualRetainedBookedAndRetried()`

### Inventory R08 — 1 failures

**RebasingAwareERC4626_APEX_Recurrence** — [RebasingAwareERC4626_APEX_Recurrence.t.sol](../../test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_APEX_Recurrence.t.sol) (1 failure).

- [L77](../../ERRORS.log#L77) `test_RECURRENCE_B03_secondRedemptionCannotReuseConsumedCredit()`

### Inventory R09 — 2 failures

**UniswapV4StandardExchangeWeightedBufferHook_Permit2Recurrence** — [UniswapV4StandardExchangeWeightedBufferHook_Permit2Recurrence.t.sol](../../test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_Permit2Recurrence.t.sol) (1 failure).

- [L34](../../ERRORS.log#L34) `test_recurrence_SeWeightedPermit2BooksOnlyDeliveredRawAmounts()`

**UniswapV4WeightedSwapHook_Recurrence** — [UniswapV4WeightedSwapHook_Recurrence.t.sol](../../test/foundry/spec/hooks/uniswap/v4/weighted/UniswapV4WeightedSwapHook_Recurrence.t.sol) (1 failure).

- [L67](../../ERRORS.log#L67) `test_recurrence_RawWeightedPermit2BooksOnlyDeliveredAmounts()`

### Inventory R10 — 3 failures

**TokenStaking_APEX_Recurrence** — [TokenStaking_APEX_Recurrence.t.sol](../../test/foundry/spec/protocols/staking/token/TokenStaking_APEX_Recurrence.t.sol) (3 failures).

- [L86](../../ERRORS.log#L86) `test_RECURRENCE_tokenStaking_FoTForbiddenDirect()`
- [L87](../../ERRORS.log#L87) `test_RECURRENCE_tokenStaking_FoTForbiddenPermit2()`
- [L88](../../ERRORS.log#L88) `test_RECURRENCE_tokenStaking_FoTForbiddenRewards()`

### Inventory R11 — 1 failures

**MorphoBlueStandardExchange_APEX_Recurrence** — [MorphoBlueStandardExchange_APEX_Recurrence.t.sol](../../test/foundry/spec/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueStandardExchange_APEX_Recurrence.t.sol) (1 failure).

- [L2027](../../ERRORS.log#L2027) `test_RECURRENCE_morphoMaxRedeem_fullPayableBalance()`

### Inventory R12 — 1 failures

**AaveCrossVersionLoop_APEX_Recurrence** — [AaveCrossVersionLoop_APEX_Recurrence.t.sol](../../test/foundry/spec/protocol/lending/aave/cross-version/AaveCrossVersionLoop_APEX_Recurrence.t.sol) (1 failure).

- [L74](../../ERRORS.log#L74) `test_RECURRENCE_DX01_nonUnitLiquidityIndex_capBoundary()`

### Inventory R13 — 3 failures

**UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_EtherFiWeETHStandardExchange** — [UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_EtherFiWeETHStandardExchange.t.sol](../../test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_EtherFiWeETHStandardExchange.t.sol) (1 failure).

- [L46](../../ERRORS.log#L46) `test_row_partialConsumption_bookedNotRefunded()`

**UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_LidoWstETHStandardExchange** — [UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_LidoWstETHStandardExchange.t.sol](../../test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_LidoWstETHStandardExchange.t.sol) (1 failure).

- [L49](../../ERRORS.log#L49) `test_row_partialConsumption_bookedNotRefunded()`

**UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV3FullSpreadStandardExchangeVault** — [UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV3FullSpreadStandardExchangeVault.t.sol](../../test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV3FullSpreadStandardExchangeVault.t.sol) (1 failure).

- [L64](../../ERRORS.log#L64) `test_row_partialConsumption_bookedNotRefunded()`

### Inventory R14 — 1 failures

**UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_CamelotV2StandardExchange** — [UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_CamelotV2StandardExchange.t.sol](../../test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_CamelotV2StandardExchange.t.sol) (1 failure).

- [L37](../../ERRORS.log#L37) `test_row_ammCallerFundSeparation()`

### Inventory R15 — 3 failures

**UniswapV4SingleSEBufferHook_SeMatrix_AerodromeStandardExchange** — [UniswapV4SingleSEBufferHook_SeMatrix_AerodromeStandardExchange.t.sol](../../test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_SeMatrix_AerodromeStandardExchange.t.sol) (1 failure).

- [L7](../../ERRORS.log#L7) `test_row_partialConsumption_bookedNotRefunded()`

**UniswapV4SingleSEBufferHook_SeMatrix_CamelotV2StandardExchange** — [UniswapV4SingleSEBufferHook_SeMatrix_CamelotV2StandardExchange.t.sol](../../test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_SeMatrix_CamelotV2StandardExchange.t.sol) (1 failure).

- [L10](../../ERRORS.log#L10) `test_row_partialConsumption_bookedNotRefunded()`

**UniswapV4SingleSEBufferHook_SeMatrix_UniswapV2StandardExchange** — [UniswapV4SingleSEBufferHook_SeMatrix_UniswapV2StandardExchange.t.sol](../../test/foundry/spec/hooks/uniswap/v4/standardExchange/single/UniswapV4SingleSEBufferHook_SeMatrix_UniswapV2StandardExchange.t.sol) (1 failure).

- [L31](../../ERRORS.log#L31) `test_row_partialConsumption_bookedNotRefunded()`

### Inventory R16 — 2 failures

**ComposedStableCommonDetfExchangeOutQueryFacet_Test** — [ComposedStableCommonDetfExchangeOutQueryFacet.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfExchangeOutQueryFacet.t.sol) (2 failures).

- [L202](../../ERRORS.log#L202) `test_exchangeOut_revertsForUnsupportedTokenOut()`
- [L203](../../ERRORS.log#L203) `test_exchangeOut_revertsWhenReservePoolUninitialized()`

### Inventory R17 — 16 failures

**UniswapV4StandardExchangeOrbitalBufferHook_SeBufferAbi** — [UniswapV4StandardExchangeOrbitalBufferHook_SeBufferAbi.t.sol](../../test/foundry/spec/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHook_SeBufferAbi.t.sol) (1 failure).

- [L4](../../ERRORS.log#L4) `test_nativeSYMetadataAndInstalledFacetSizes()`

**CurveQuadFundedBindingTest** — [V4FundedBindings.t.sol](../../test/foundry/spec/vaults/detf/common/claimToken/V4FundedBindings.t.sol) (1 failure).

- [L108](../../ERRORS.log#L108) `test_bindingHookComponentsFitAndSelectorsAreInstalled()`

**OrbitalFundedBindingTest** — [V4FundedBindings.t.sol](../../test/foundry/spec/vaults/detf/common/claimToken/V4FundedBindings.t.sol) (1 failure).

- [L111](../../ERRORS.log#L111) `test_bindingHookComponentsFitAndSelectorsAreInstalled()`

**OrbitalV4PositionFundedBindingTest** — [V4FundedBindings.t.sol](../../test/foundry/spec/vaults/detf/common/claimToken/V4FundedBindings.t.sol) (1 failure).

- [L114](../../ERRORS.log#L114) `test_bindingHookComponentsFitAndSelectorsAreInstalled()`

**UniswapV3FullSpreadStandardExchangeVault_NativeSYTest** — [UniswapV3FullSpreadStandardExchangeVault_NativeSY.t.sol](../../test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/sy/UniswapV3FullSpreadStandardExchangeVault_NativeSY.t.sol) (1 failure).

- [L2037](../../ERRORS.log#L2037) `test_installedQueryFacetsFitRuntimeLimit()`

**HooklessRuntimeAndWorkTest** — [RuntimeAndWork.t.sol](../../test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/RuntimeAndWork.t.sol) (1 failure).

- [L2050](../../ERRORS.log#L2050) `test_allDeployedFacetsDelegatesAndPackageFitEIP170()`

**HooklessTightTickRuntimeAndWorkTest** — [RuntimeAndWork.t.sol](../../test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/RuntimeAndWork.t.sol) (1 failure).

- [L2053](../../ERRORS.log#L2053) `test_allDeployedFacetsDelegatesAndPackageFitEIP170()`

**UniswapV4FullSpreadPonsFamilyHookHighFeeRuntimeAndWorkTest** — [RuntimeAndWork.t.sol](../../test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/RuntimeAndWork.t.sol) (1 failure).

- [L2063](../../ERRORS.log#L2063) `test_allDeployedFacetsDelegatesAndPackageFitEIP170()`

**UniswapV4FullSpreadPonsFamilyHookHighFeeTightTickRuntimeAndWorkTest** — [RuntimeAndWork.t.sol](../../test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/RuntimeAndWork.t.sol) (1 failure).

- [L2066](../../ERRORS.log#L2066) `test_allDeployedFacetsDelegatesAndPackageFitEIP170()`

**UniswapV4FullSpreadPonsFamilyHookRuntimeAndWorkTest** — [RuntimeAndWork.t.sol](../../test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/RuntimeAndWork.t.sol) (1 failure).

- [L2069](../../ERRORS.log#L2069) `test_allDeployedFacetsDelegatesAndPackageFitEIP170()`

**UniswapV4FullSpreadPonsFamilyHookTightTickRuntimeAndWorkTest** — [RuntimeAndWork.t.sol](../../test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/RuntimeAndWork.t.sol) (1 failure).

- [L2072](../../ERRORS.log#L2072) `test_allDeployedFacetsDelegatesAndPackageFitEIP170()`

**BalancerStableBufferHookNativeSYTest** — [BalancerStableBufferHookNativeSY.t.sol](../../test/foundry/spec/vaults/standard/sy/BalancerStableBufferHookNativeSY.t.sol) (1 failure).

- [L2112](../../ERRORS.log#L2112) `test_balancerStableSYMetadataNativeRateAndAllFacetSelectors()`

**AerodromeNativeSYTest** — [ConstantProductNativeSY.t.sol](../../test/foundry/spec/vaults/standard/sy/ConstantProductNativeSY.t.sol) (2 failures).

- [L2115](../../ERRORS.log#L2115) `test_aeroProjectionSelectorsAndComponentSizes()`
- [L2116](../../ERRORS.log#L2116) `test_nativeLPMetadataAndCompleteSelectors()`

**CurveQuadBufferHookNativeSYTest** — [CurveQuadBufferHookNativeSY.t.sol](../../test/foundry/spec/vaults/standard/sy/CurveQuadBufferHookNativeSY.t.sol) (1 failure).

- [L2127](../../ERRORS.log#L2127) `test_curveQuadSYMetadataNativeRateAndAllFacetSelectors()`

**V3FullRangeNativeSYTest** — [V3FullRangeNativeSY.t.sol](../../test/foundry/spec/vaults/standard/sy/V3FullRangeNativeSY.t.sol) (1 failure).

- [L2154](../../ERRORS.log#L2154) `test_installedQueryFacetsFitRuntimeLimit()`

### Inventory R18 — 1,389 failures

**TokenStakingMigrationScript** — [TokenStakingMigrationScript.t.sol](../../test/foundry/spec/protocols/staking/token/TokenStakingMigrationScript.t.sol) (1 failure).

- [L83](../../ERRORS.log#L83) `test_e2e_stake_dtf_migrate_chunks_withdraw_claim()`

**TokenStaking_PonsUv4Detf** — [TokenStaking_PonsUv4Detf.t.sol](../../test/foundry/spec/protocols/staking/token/TokenStaking_PonsUv4Detf.t.sol) (1 failure).

- [L91](../../ERRORS.log#L91) `test_e2e_stake_dtf_migrate_chunks_withdraw_claim()`

**DETFNFTVaultDFPkg_Deploy_Test** — [DETFNFTVaultDFPkg_Deploy.t.sol](../../test/foundry/spec/vaults/detf/common/bondNft/DETFNFTVaultDFPkg_Deploy.t.sol) (1 failure).

- [L94](../../ERRORS.log#L94) `test_feeRoleTransferSettlesOldBoundaryThenPaysNewOwnerOnLaterMint()`

**FundedStakingSequenceTest** — [FundedStakingSequence.t.sol](../../test/foundry/spec/vaults/detf/common/claimToken/FundedStakingSequence.t.sol) (2 failures).

- [L97](../../ERRORS.log#L97) `testFuzz_paidRewardsAndStakeChangesKeepEveryUnitFunded(uint256)`
- [L98](../../ERRORS.log#L98) `test_twoBondEscrowsCloseWithoutRetiringEachOthersFraction()`

**RebasingClaimTokenDFPkg_Deploy_Test** — [RebasingClaimTokenDFPkg_Deploy.t.sol](../../test/foundry/spec/vaults/detf/common/claimToken/RebasingClaimTokenDFPkg_Deploy.t.sol) (1 failure).

- [L102](../../ERRORS.log#L102) `test_stakingSYOwnsStaticBalancesAcrossNewBondRewards()`

**RebasingClaimToken_Accounting** — [RebasingClaimToken_Accounting.t.sol](../../test/foundry/spec/vaults/detf/common/claimToken/RebasingClaimToken_Accounting.t.sol) (1 failure).

- [L105](../../ERRORS.log#L105) `test_sameBlockFundedRewardsUpdateGonsButUnsolicitedBackingDoesNot()`

**OrbitalV4PositionFundedBindingTest** — [V4FundedBindings.t.sol](../../test/foundry/spec/vaults/detf/common/claimToken/V4FundedBindings.t.sol) (1 failure).

- [L115](../../ERRORS.log#L115) `test_bindingStaticSYReceivesLaterFundedBondRewards()`

**CpPublicReserveLiquidityTest** — [V4ReserveLiquidity.t.sol](../../test/foundry/spec/vaults/detf/common/claimToken/V4ReserveLiquidity.t.sol) (10 failures).

- [L118](../../ERRORS.log#L118) `test_currentCollectorRedeemsActualFeeLpWithOwnerAuthorization()`
- [L119](../../ERRORS.log#L119) `test_customBondQuoteIncludesWrappingBeforeIssuance()`
- [L120](../../ERRORS.log#L120) `test_directLiquidityOperationsFollowDeploymentPolicy()`
- [L121](../../ERRORS.log#L121) `test_externallyOwnedLpDonationTransfersWholePositionWithoutStakingIssuance()`
- [L122](../../ERRORS.log#L122) `test_feeCollectorRotationChangesRestrictedRemovalAuthority()`
- [L123](../../ERRORS.log#L123) `test_internalSYRedemptionUsesCurrentCollectorAfterRotation()`
- [L124](../../ERRORS.log#L124) `test_lidoBufferUsesApprovedPaymentsForFallbackAndFundedBond()`
- [L125](../../ERRORS.log#L125) `test_lpBondCannotClaimProtocolOrAnotherWalletsLp()`
- [L126](../../ERRORS.log#L126) `test_lpBondSettlesExpansionBeforeTakingPayment()`
- [L127](../../ERRORS.log#L127) `test_lpBondValuesDistinctNonDetfLegsAndRetainsWholeInventory()`

**CpReserveLiquidityTest** — [V4ReserveLiquidity.t.sol](../../test/foundry/spec/vaults/detf/common/claimToken/V4ReserveLiquidity.t.sol) (10 failures).

- [L131](../../ERRORS.log#L131) `test_currentCollectorRedeemsActualFeeLpWithOwnerAuthorization()`
- [L132](../../ERRORS.log#L132) `test_customBondQuoteIncludesWrappingBeforeIssuance()`
- [L133](../../ERRORS.log#L133) `test_directLiquidityOperationsFollowDeploymentPolicy()`
- [L134](../../ERRORS.log#L134) `test_externallyOwnedLpDonationTransfersWholePositionWithoutStakingIssuance()`
- [L135](../../ERRORS.log#L135) `test_feeCollectorRotationChangesRestrictedRemovalAuthority()`
- [L136](../../ERRORS.log#L136) `test_internalSYRedemptionUsesCurrentCollectorAfterRotation()`
- [L137](../../ERRORS.log#L137) `test_lidoBufferUsesApprovedPaymentsForFallbackAndFundedBond()`
- [L138](../../ERRORS.log#L138) `test_lpBondCannotClaimProtocolOrAnotherWalletsLp()`
- [L139](../../ERRORS.log#L139) `test_lpBondSettlesExpansionBeforeTakingPayment()`
- [L140](../../ERRORS.log#L140) `test_lpBondValuesDistinctNonDetfLegsAndRetainsWholeInventory()`

**OrbitalPublicReserveLiquidityTest** — [V4ReserveLiquidity.t.sol](../../test/foundry/spec/vaults/detf/common/claimToken/V4ReserveLiquidity.t.sol) (2 failures).

- [L150](../../ERRORS.log#L150) `test_customBondQuoteIncludesWrappingBeforeIssuance()`
- [L151](../../ERRORS.log#L151) `test_customDonationQuoteIncludesWrappingBeforeReserveJoin()`

**OrbitalReserveLiquidityTest** — [V4ReserveLiquidity.t.sol](../../test/foundry/spec/vaults/detf/common/claimToken/V4ReserveLiquidity.t.sol) (2 failures).

- [L155](../../ERRORS.log#L155) `test_customBondQuoteIncludesWrappingBeforeIssuance()`
- [L156](../../ERRORS.log#L156) `test_customDonationQuoteIncludesWrappingBeforeReserveJoin()`

**UniswapV4Detf_Alignment_CloseD25** — [UniswapV4Detf_Alignment_CloseD25.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Alignment_CloseD25.t.sol) (2 failures).

- [L209](../../ERRORS.log#L209) `test_D25_fundedPrincipalAndRewardsPayOnlyStaking()`
- [L210](../../ERRORS.log#L210) `test_D25_standingReceiptsAlreadyFundedBeforeClaim()`

**UniswapV4Detf_Alignment_FeeCreatorClaim** — [UniswapV4Detf_Alignment_FeeCreatorClaim.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Alignment_FeeCreatorClaim.t.sol) (4 failures).

- [L213](../../ERRORS.log#L213) `test_FC_creatorZeroFundsBothRightsToOriginalFeeOwner()`
- [L214](../../ERRORS.log#L214) `test_FC_explicitCreatorReceivesSeparateFundedIncome()`
- [L215](../../ERRORS.log#L215) `test_FC_fullExitAndFeeToRotationPreserveStandingIncome()`
- [L216](../../ERRORS.log#L216) `test_FC_fundedTwoWavesMatchIndependentFloors()`

**UniswapV4Detf_Alignment_RedeemD15** — [UniswapV4Detf_Alignment_RedeemD15.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Alignment_RedeemD15.t.sol) (8 failures).

- [L219](../../ERRORS.log#L219) `test_D15_1_previewEqualsExecute()`
- [L220](../../ERRORS.log#L220) `test_D15_8_nonDetfPayoutForbidden()`
- [L221](../../ERRORS.log#L221) `test_D15_partialThenFullUnstakeUsesOnlyFundedBacking()`
- [L222](../../ERRORS.log#L222) `test_D15_redeem_paysDetf_only()`
- [L223](../../ERRORS.log#L223) `test_D15_unstakeDoesNotRequireProtocolLpInventory()`
- [L224](../../ERRORS.log#L224) `test_D15_unstakePreservesOtherBondPrincipalAndGons()`
- [L225](../../ERRORS.log#L225) `test_D15_unstakeSettlesAllDueFundedExpansionFirst()`
- [L226](../../ERRORS.log#L226) `test_D22_claimUngated()`

**UniswapV4Detf_Claim** — [UniswapV4Detf_Claim.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Claim.t.sol) (3 failures).

- [L229](../../ERRORS.log#L229) `test_claimRewards_whileLocked()`
- [L230](../../ERRORS.log#L230) `test_postMaturity_claimPaysFundedStaking()`
- [L231](../../ERRORS.log#L231) `test_preMaturity_principalVestsLinearly()`

**UniswapV4Detf_Dust** — [UniswapV4Detf_Dust.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Dust.t.sol) (1 failure).

- [L234](../../ERRORS.log#L234) `test_T7_20_sweepDust_joinsPairDust_unassignedLp()`

**UniswapV4Detf_IoTables** — [UniswapV4Detf_IoTables.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_IoTables.t.sol) (1 failure).

- [L237](../../ERRORS.log#L237) `test_T7_10_laterBond_joinUnbalanced_unboostedG()`

**UniswapV4Detf_Orbital_Adversarial_A0Crops** — [UniswapV4Detf_Orbital_Adversarial_A0Crops.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Orbital_Adversarial_A0Crops.t.sol) (2 failures).

- [L240](../../ERRORS.log#L240) `test_A0_donateBeforeFirstBond_cannotFreeMint()`
- [L241](../../ERRORS.log#L241) `test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork()`

**UniswapV4Detf_Orbital_Alignment_FeeCreatorClaim** — [UniswapV4Detf_Orbital_Alignment_FeeCreatorClaim.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Orbital_Alignment_FeeCreatorClaim.t.sol) (1 failure).

- [L244](../../ERRORS.log#L244) `test_FC_fundedTwoWavesMatchIndependentFloors()`

**UniswapV4Detf_Orbital_Alignment_RedeemD15** — [UniswapV4Detf_Orbital_Alignment_RedeemD15.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Orbital_Alignment_RedeemD15.t.sol) (2 failures).

- [L247](../../ERRORS.log#L247) `test_D15_unstakeSettlesAllDueFundedExpansionFirst()`
- [L248](../../ERRORS.log#L248) `test_D22_claimUngated()`

**UniswapV4Detf_Orbital_Claim** — [UniswapV4Detf_Orbital_Claim.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Orbital_Claim.t.sol) (3 failures).

- [L251](../../ERRORS.log#L251) `test_claimRewards_whileLocked()`
- [L252](../../ERRORS.log#L252) `test_postMaturity_claimPaysFundedStaking()`
- [L253](../../ERRORS.log#L253) `test_preMaturity_principalVestsLinearly()`

**UniswapV4Detf_Orbital_IoTables** — [UniswapV4Detf_Orbital_IoTables.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Orbital_IoTables.t.sol) (1 failure).

- [L256](../../ERRORS.log#L256) `test_T7_10_laterBond_joinUnbalanced_unboostedG()`

**UniswapV4Detf_Orbital_Policy** — [UniswapV4Detf_Orbital_Policy.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Orbital_Policy.t.sol) (4 failures).

- [L259](../../ERRORS.log#L259) `test_D31_1_policyMint_realizesThenGates()`
- [L260](../../ERRORS.log#L260) `test_donate_doesNotRealizeExpansion()`
- [L261](../../ERRORS.log#L261) `test_policy_burn_allowed_when_synthetic_below_burnThreshold()`
- [L262](../../ERRORS.log#L262) `test_policy_mint_blocked_in_deadband_then_allowed_after_push()`

**UniswapV4Detf_Orbital_ReserveDonation** — [UniswapV4Detf_Orbital_ReserveDonation.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Orbital_ReserveDonation.t.sol) (17 failures).

- [L265](../../ERRORS.log#L265) `test_DN10_previewEqualsExecute()`
- [L266](../../ERRORS.log#L266) `test_DN11_ownerOnlyLiquidity_donateStillWorks()`
- [L267](../../ERRORS.log#L267) `test_DN12_donate_doesNotRealizeExpansion()`
- [L268](../../ERRORS.log#L268) `test_DN13_burn_afterDonate_usesDonatedLp()`
- [L269](../../ERRORS.log#L269) `test_DN14_closeAfterDonate_userBasketUnchanged()`
- [L270](../../ERRORS.log#L270) `test_DN16_lastClose_thenDonate_nextBondDoesNotCapture()`
- [L271](../../ERRORS.log#L271) `test_DN17_d2_ids12_effectiveShares()`
- [L272](../../ERRORS.log#L272) `test_DN18_disabled_donateReverts_closeWorks()`
- [L273](../../ERRORS.log#L273) `test_DN19_permit2_allowance()`
- [L274](../../ERRORS.log#L274) `test_DN1_donate_pair_Ogt0_unassignedLp()`
- [L275](../../ERRORS.log#L275) `test_DN20_permit2_signature()`
- [L276](../../ERRORS.log#L276) `test_DN21_d2_afterDonate()`
- [L277](../../ERRORS.log#L277) `test_DN22_donate_whilePoolManagerUnlocked()`
- [L278](../../ERRORS.log#L278) `test_DN2_donate_vaultShare()`
- [L279](../../ERRORS.log#L279) `test_DN4_donate_detf_selfLeg_noMint()`
- [L280](../../ERRORS.log#L280) `test_DN6_twoBonders_navRisesTogether()`
- [L281](../../ERRORS.log#L281) `test_DN7_detf_donate_forwardsToNft()`

**UniswapV4Detf_Orbital_OriginalPrincipal** — [UniswapV4Detf_OriginalPrincipal.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_OriginalPrincipal.t.sol) (4 failures).

- [L284](../../ERRORS.log#L284) `test_P1_fundedPrincipalSurvivesDonationAndLaterBond()`
- [L285](../../ERRORS.log#L285) `test_P1_matureClaimRetainsDonatedProtocolLiquidity()`
- [L286](../../ERRORS.log#L286) `test_P1_stakeMinimumRollsBackAllFundedAccounting()`
- [L287](../../ERRORS.log#L287) `test_P1_stakingQuoteIgnoresLpFeesAndUsesFundedIndex()`

**UniswapV4Detf_OriginalPrincipal** — [UniswapV4Detf_OriginalPrincipal.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_OriginalPrincipal.t.sol) (3 failures).

- [L290](../../ERRORS.log#L290) `test_P1_fundedPrincipalSurvivesDonationAndLaterBond()`
- [L291](../../ERRORS.log#L291) `test_P1_matureClaimRetainsDonatedProtocolLiquidity()`
- [L292](../../ERRORS.log#L292) `test_P1_stakingQuoteIgnoresLpFeesAndUsesFundedIndex()`

**UniswapV4Detf_Policy** — [UniswapV4Detf_Policy.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Policy.t.sol) (1 failure).

- [L295](../../ERRORS.log#L295) `test_compound_raises_protocolLp()`

**UniswapV4Detf_ReserveDonation** — [UniswapV4Detf_ReserveDonation.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_ReserveDonation.t.sol) (4 failures).

- [L298](../../ERRORS.log#L298) `test_DN14_closeAfterDonate_userBasketUnchanged()`
- [L299](../../ERRORS.log#L299) `test_DN16_lastClose_thenDonate_nextBondDoesNotCapture()`
- [L300](../../ERRORS.log#L300) `test_DN18_disabled_donateReverts_closeWorks()`
- [L301](../../ERRORS.log#L301) `test_DN6_twoBonders_navRisesTogether()`

**Adversarial_A0Crops** — [Adversarial_A0Crops.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/adversarial/Adversarial_A0Crops.t.sol) (2 failures).

- [L304](../../ERRORS.log#L304) `test_A0_donateBeforeFirstBond_cannotFreeMint()`
- [L305](../../ERRORS.log#L305) `test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork()`

**UniswapV4Detf_Alignment_CloseD25_P18_R6** — [UniswapV4Detf_Alignment_CloseD25_P18_R6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_Alignment_CloseD25_P18_R6.t.sol) (2 failures).

- [L311](../../ERRORS.log#L311) `test_D25_fundedPrincipalAndRewardsPayOnlyStaking()`
- [L312](../../ERRORS.log#L312) `test_D25_standingReceiptsAlreadyFundedBeforeClaim()`

**UniswapV4Detf_Alignment_CloseD25_P18_R9** — [UniswapV4Detf_Alignment_CloseD25_P18_R9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_Alignment_CloseD25_P18_R9.t.sol) (2 failures).

- [L315](../../ERRORS.log#L315) `test_D25_fundedPrincipalAndRewardsPayOnlyStaking()`
- [L316](../../ERRORS.log#L316) `test_D25_standingReceiptsAlreadyFundedBeforeClaim()`

**UniswapV4Detf_Alignment_FeeCreatorClaim_H6** — [UniswapV4Detf_Alignment_FeeCreatorClaim_H6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_Alignment_FeeCreatorClaim_H6.t.sol) (4 failures).

- [L319](../../ERRORS.log#L319) `test_FC_creatorZeroFundsBothRightsToOriginalFeeOwner()`
- [L320](../../ERRORS.log#L320) `test_FC_explicitCreatorReceivesSeparateFundedIncome()`
- [L321](../../ERRORS.log#L321) `test_FC_fullExitAndFeeToRotationPreserveStandingIncome()`
- [L322](../../ERRORS.log#L322) `test_FC_fundedTwoWavesMatchIndependentFloors()`

**UniswapV4Detf_Alignment_FeeCreatorClaim_P18_R6** — [UniswapV4Detf_Alignment_FeeCreatorClaim_P18_R6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_Alignment_FeeCreatorClaim_P18_R6.t.sol) (4 failures).

- [L325](../../ERRORS.log#L325) `test_FC_creatorZeroFundsBothRightsToOriginalFeeOwner()`
- [L326](../../ERRORS.log#L326) `test_FC_explicitCreatorReceivesSeparateFundedIncome()`
- [L327](../../ERRORS.log#L327) `test_FC_fullExitAndFeeToRotationPreserveStandingIncome()`
- [L328](../../ERRORS.log#L328) `test_FC_fundedTwoWavesMatchIndependentFloors()`

**UniswapV4Detf_Alignment_FeeCreatorClaim_P18_R9** — [UniswapV4Detf_Alignment_FeeCreatorClaim_P18_R9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_Alignment_FeeCreatorClaim_P18_R9.t.sol) (4 failures).

- [L331](../../ERRORS.log#L331) `test_FC_creatorZeroFundsBothRightsToOriginalFeeOwner()`
- [L332](../../ERRORS.log#L332) `test_FC_explicitCreatorReceivesSeparateFundedIncome()`
- [L333](../../ERRORS.log#L333) `test_FC_fullExitAndFeeToRotationPreserveStandingIncome()`
- [L334](../../ERRORS.log#L334) `test_FC_fundedTwoWavesMatchIndependentFloors()`

**UniswapV4Detf_Alignment_FeeCreatorClaim_P6_R18** — [UniswapV4Detf_Alignment_FeeCreatorClaim_P6_R18.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_Alignment_FeeCreatorClaim_P6_R18.t.sol) (4 failures).

- [L337](../../ERRORS.log#L337) `test_FC_creatorZeroFundsBothRightsToOriginalFeeOwner()`
- [L338](../../ERRORS.log#L338) `test_FC_explicitCreatorReceivesSeparateFundedIncome()`
- [L339](../../ERRORS.log#L339) `test_FC_fullExitAndFeeToRotationPreserveStandingIncome()`
- [L340](../../ERRORS.log#L340) `test_FC_fundedTwoWavesMatchIndependentFloors()`

**UniswapV4Detf_Alignment_FeeCreatorClaim_P6_R9** — [UniswapV4Detf_Alignment_FeeCreatorClaim_P6_R9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_Alignment_FeeCreatorClaim_P6_R9.t.sol) (4 failures).

- [L343](../../ERRORS.log#L343) `test_FC_creatorZeroFundsBothRightsToOriginalFeeOwner()`
- [L344](../../ERRORS.log#L344) `test_FC_explicitCreatorReceivesSeparateFundedIncome()`
- [L345](../../ERRORS.log#L345) `test_FC_fullExitAndFeeToRotationPreserveStandingIncome()`
- [L346](../../ERRORS.log#L346) `test_FC_fundedTwoWavesMatchIndependentFloors()`

**UniswapV4Detf_Alignment_RedeemD15_P18_R6** — [UniswapV4Detf_Alignment_RedeemD15_P18_R6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_Alignment_RedeemD15_P18_R6.t.sol) (8 failures).

- [L349](../../ERRORS.log#L349) `test_D15_1_previewEqualsExecute()`
- [L350](../../ERRORS.log#L350) `test_D15_8_nonDetfPayoutForbidden()`
- [L351](../../ERRORS.log#L351) `test_D15_partialThenFullUnstakeUsesOnlyFundedBacking()`
- [L352](../../ERRORS.log#L352) `test_D15_redeem_paysDetf_only()`
- [L353](../../ERRORS.log#L353) `test_D15_unstakeDoesNotRequireProtocolLpInventory()`
- [L354](../../ERRORS.log#L354) `test_D15_unstakePreservesOtherBondPrincipalAndGons()`
- [L355](../../ERRORS.log#L355) `test_D15_unstakeSettlesAllDueFundedExpansionFirst()`
- [L356](../../ERRORS.log#L356) `test_D22_claimUngated()`

**UniswapV4Detf_Alignment_RedeemD15_P18_R9** — [UniswapV4Detf_Alignment_RedeemD15_P18_R9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_Alignment_RedeemD15_P18_R9.t.sol) (8 failures).

- [L359](../../ERRORS.log#L359) `test_D15_1_previewEqualsExecute()`
- [L360](../../ERRORS.log#L360) `test_D15_8_nonDetfPayoutForbidden()`
- [L361](../../ERRORS.log#L361) `test_D15_partialThenFullUnstakeUsesOnlyFundedBacking()`
- [L362](../../ERRORS.log#L362) `test_D15_redeem_paysDetf_only()`
- [L363](../../ERRORS.log#L363) `test_D15_unstakeDoesNotRequireProtocolLpInventory()`
- [L364](../../ERRORS.log#L364) `test_D15_unstakePreservesOtherBondPrincipalAndGons()`
- [L365](../../ERRORS.log#L365) `test_D15_unstakeSettlesAllDueFundedExpansionFirst()`
- [L366](../../ERRORS.log#L366) `test_D22_claimUngated()`

**UniswapV4Detf_Burn_H6** — [UniswapV4Detf_Burn_H6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_Burn_H6.t.sol) (2 failures).

- [L369](../../ERRORS.log#L369) `testFuzz_smallPrimaryBurn_payablePartialExit(uint256)`
- [L370](../../ERRORS.log#L370) `test_smallPrimaryBurn_firstPayableBoundary()`

**UniswapV4Detf_Claim_H6** — [UniswapV4Detf_Claim_H6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_Claim_H6.t.sol) (3 failures).

- [L373](../../ERRORS.log#L373) `test_claimRewards_whileLocked()`
- [L374](../../ERRORS.log#L374) `test_postMaturity_claimPaysFundedStaking()`
- [L375](../../ERRORS.log#L375) `test_preMaturity_principalVestsLinearly()`

**UniswapV4Detf_Claim_P18_R6** — [UniswapV4Detf_Claim_P18_R6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_Claim_P18_R6.t.sol) (3 failures).

- [L378](../../ERRORS.log#L378) `test_claimRewards_whileLocked()`
- [L379](../../ERRORS.log#L379) `test_postMaturity_claimPaysFundedStaking()`
- [L380](../../ERRORS.log#L380) `test_preMaturity_principalVestsLinearly()`

**UniswapV4Detf_Claim_P18_R9** — [UniswapV4Detf_Claim_P18_R9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_Claim_P18_R9.t.sol) (3 failures).

- [L383](../../ERRORS.log#L383) `test_claimRewards_whileLocked()`
- [L384](../../ERRORS.log#L384) `test_postMaturity_claimPaysFundedStaking()`
- [L385](../../ERRORS.log#L385) `test_preMaturity_principalVestsLinearly()`

**UniswapV4Detf_Claim_P6_R18** — [UniswapV4Detf_Claim_P6_R18.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_Claim_P6_R18.t.sol) (3 failures).

- [L388](../../ERRORS.log#L388) `test_claimRewards_whileLocked()`
- [L389](../../ERRORS.log#L389) `test_postMaturity_claimPaysFundedStaking()`
- [L390](../../ERRORS.log#L390) `test_preMaturity_principalVestsLinearly()`

**UniswapV4Detf_Claim_P6_R9** — [UniswapV4Detf_Claim_P6_R9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_Claim_P6_R9.t.sol) (3 failures).

- [L393](../../ERRORS.log#L393) `test_claimRewards_whileLocked()`
- [L394](../../ERRORS.log#L394) `test_postMaturity_claimPaysFundedStaking()`
- [L395](../../ERRORS.log#L395) `test_preMaturity_principalVestsLinearly()`

**UniswapV4Detf_Dust_H6** — [UniswapV4Detf_Dust_H6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_Dust_H6.t.sol) (1 failure).

- [L398](../../ERRORS.log#L398) `test_T7_20_sweepDust_joinsPairDust_unassignedLp()`

**UniswapV4Detf_Dust_H9** — [UniswapV4Detf_Dust_H9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_Dust_H9.t.sol) (1 failure).

- [L401](../../ERRORS.log#L401) `test_T7_20_sweepDust_joinsPairDust_unassignedLp()`

**UniswapV4Detf_Dust_P18_R6** — [UniswapV4Detf_Dust_P18_R6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_Dust_P18_R6.t.sol) (1 failure).

- [L404](../../ERRORS.log#L404) `test_T7_20_sweepDust_joinsPairDust_unassignedLp()`

**UniswapV4Detf_Dust_P18_R9** — [UniswapV4Detf_Dust_P18_R9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_Dust_P18_R9.t.sol) (1 failure).

- [L407](../../ERRORS.log#L407) `test_T7_20_sweepDust_joinsPairDust_unassignedLp()`

**UniswapV4Detf_Dust_P6_R18** — [UniswapV4Detf_Dust_P6_R18.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_Dust_P6_R18.t.sol) (1 failure).

- [L410](../../ERRORS.log#L410) `test_T7_20_sweepDust_joinsPairDust_unassignedLp()`

**UniswapV4Detf_Dust_P6_R9** — [UniswapV4Detf_Dust_P6_R9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_Dust_P6_R9.t.sol) (1 failure).

- [L413](../../ERRORS.log#L413) `test_T7_20_sweepDust_joinsPairDust_unassignedLp()`

**UniswapV4Detf_Dust_P9_R18** — [UniswapV4Detf_Dust_P9_R18.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_Dust_P9_R18.t.sol) (1 failure).

- [L416](../../ERRORS.log#L416) `test_T7_20_sweepDust_joinsPairDust_unassignedLp()`

**UniswapV4Detf_Dust_P9_R6** — [UniswapV4Detf_Dust_P9_R6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_Dust_P9_R6.t.sol) (1 failure).

- [L419](../../ERRORS.log#L419) `test_T7_20_sweepDust_joinsPairDust_unassignedLp()`

**UniswapV4Detf_IoTables_H6** — [UniswapV4Detf_IoTables_H6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_IoTables_H6.t.sol) (1 failure).

- [L422](../../ERRORS.log#L422) `test_T7_10_laterBond_joinUnbalanced_unboostedG()`

**UniswapV4Detf_IoTables_P18_R6** — [UniswapV4Detf_IoTables_P18_R6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_IoTables_P18_R6.t.sol) (1 failure).

- [L425](../../ERRORS.log#L425) `test_T7_10_laterBond_joinUnbalanced_unboostedG()`

**UniswapV4Detf_IoTables_P18_R9** — [UniswapV4Detf_IoTables_P18_R9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_IoTables_P18_R9.t.sol) (1 failure).

- [L428](../../ERRORS.log#L428) `test_T7_10_laterBond_joinUnbalanced_unboostedG()`

**UniswapV4Detf_IoTables_P6_R18** — [UniswapV4Detf_IoTables_P6_R18.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_IoTables_P6_R18.t.sol) (1 failure).

- [L431](../../ERRORS.log#L431) `test_T7_10_laterBond_joinUnbalanced_unboostedG()`

**UniswapV4Detf_IoTables_P6_R9** — [UniswapV4Detf_IoTables_P6_R9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_IoTables_P6_R9.t.sol) (1 failure).

- [L434](../../ERRORS.log#L434) `test_T7_10_laterBond_joinUnbalanced_unboostedG()`

**UniswapV4Detf_Orbital_Policy_B_ALL6** — [UniswapV4Detf_Orbital_Policy_B_ALL6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_Orbital_Policy_B_ALL6.t.sol) (3 failures).

- [L437](../../ERRORS.log#L437) `test_D31_1_policyMint_realizesThenGates()`
- [L438](../../ERRORS.log#L438) `test_policy_burn_allowed_when_synthetic_below_burnThreshold()`
- [L439](../../ERRORS.log#L439) `test_policy_mint_blocked_in_deadband_then_allowed_after_push()`

**UniswapV4Detf_Orbital_Policy_B_ALL9** — [UniswapV4Detf_Orbital_Policy_B_ALL9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_Orbital_Policy_B_ALL9.t.sol) (3 failures).

- [L442](../../ERRORS.log#L442) `test_D31_1_policyMint_realizesThenGates()`
- [L443](../../ERRORS.log#L443) `test_policy_burn_allowed_when_synthetic_below_burnThreshold()`
- [L444](../../ERRORS.log#L444) `test_policy_mint_blocked_in_deadband_then_allowed_after_push()`

**UniswapV4Detf_Orbital_Policy_B_P18_R6** — [UniswapV4Detf_Orbital_Policy_B_P18_R6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_Orbital_Policy_B_P18_R6.t.sol) (5 failures).

- [L447](../../ERRORS.log#L447) `test_D22_claimUngated()`
- [L448](../../ERRORS.log#L448) `test_D31_1_policyMint_realizesThenGates()`
- [L449](../../ERRORS.log#L449) `test_FC_fundedTwoWavesMatchIndependentFloors()`
- [L450](../../ERRORS.log#L450) `test_policy_burn_allowed_when_synthetic_below_burnThreshold()`
- [L451](../../ERRORS.log#L451) `test_policy_mint_blocked_in_deadband_then_allowed_after_push()`

**UniswapV4Detf_Orbital_Policy_B_P18_R9** — [UniswapV4Detf_Orbital_Policy_B_P18_R9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_Orbital_Policy_B_P18_R9.t.sol) (5 failures).

- [L454](../../ERRORS.log#L454) `test_D22_claimUngated()`
- [L455](../../ERRORS.log#L455) `test_D31_1_policyMint_realizesThenGates()`
- [L456](../../ERRORS.log#L456) `test_FC_fundedTwoWavesMatchIndependentFloors()`
- [L457](../../ERRORS.log#L457) `test_policy_burn_allowed_when_synthetic_below_burnThreshold()`
- [L458](../../ERRORS.log#L458) `test_policy_mint_blocked_in_deadband_then_allowed_after_push()`

**UniswapV4Detf_Orbital_Policy_B_P6_R18** — [UniswapV4Detf_Orbital_Policy_B_P6_R18.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_Orbital_Policy_B_P6_R18.t.sol) (3 failures).

- [L461](../../ERRORS.log#L461) `test_D31_1_policyMint_realizesThenGates()`
- [L462](../../ERRORS.log#L462) `test_policy_burn_allowed_when_synthetic_below_burnThreshold()`
- [L463](../../ERRORS.log#L463) `test_policy_mint_blocked_in_deadband_then_allowed_after_push()`

**UniswapV4Detf_Orbital_Policy_B_P6_R9** — [UniswapV4Detf_Orbital_Policy_B_P6_R9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_Orbital_Policy_B_P6_R9.t.sol) (3 failures).

- [L466](../../ERRORS.log#L466) `test_D31_1_policyMint_realizesThenGates()`
- [L467](../../ERRORS.log#L467) `test_policy_burn_allowed_when_synthetic_below_burnThreshold()`
- [L468](../../ERRORS.log#L468) `test_policy_mint_blocked_in_deadband_then_allowed_after_push()`

**UniswapV4Detf_Orbital_Policy_B_P9_R18** — [UniswapV4Detf_Orbital_Policy_B_P9_R18.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_Orbital_Policy_B_P9_R18.t.sol) (3 failures).

- [L471](../../ERRORS.log#L471) `test_D31_1_policyMint_realizesThenGates()`
- [L472](../../ERRORS.log#L472) `test_policy_burn_allowed_when_synthetic_below_burnThreshold()`
- [L473](../../ERRORS.log#L473) `test_policy_mint_blocked_in_deadband_then_allowed_after_push()`

**UniswapV4Detf_Orbital_Policy_B_P9_R6** — [UniswapV4Detf_Orbital_Policy_B_P9_R6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_Orbital_Policy_B_P9_R6.t.sol) (3 failures).

- [L476](../../ERRORS.log#L476) `test_D31_1_policyMint_realizesThenGates()`
- [L477](../../ERRORS.log#L477) `test_policy_burn_allowed_when_synthetic_below_burnThreshold()`
- [L478](../../ERRORS.log#L478) `test_policy_mint_blocked_in_deadband_then_allowed_after_push()`

**UniswapV4Detf_Orbital_ProductLaw_B_ALL6** — [UniswapV4Detf_Orbital_ProductLaw_B_ALL6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_Orbital_ProductLaw_B_ALL6.t.sol) (17 failures).

- [L481](../../ERRORS.log#L481) `test_A0_donateBeforeFirstBond_cannotFreeMint()`
- [L482](../../ERRORS.log#L482) `test_DN10_previewEqualsExecute()`
- [L483](../../ERRORS.log#L483) `test_DN11_ownerOnlyLiquidity_donateStillWorks()`
- [L484](../../ERRORS.log#L484) `test_DN12_donate_doesNotRealizeExpansion()`
- [L485](../../ERRORS.log#L485) `test_DN13_burn_afterDonate_usesDonatedLp()`
- [L486](../../ERRORS.log#L486) `test_DN14_closeAfterDonate_userBasketUnchanged()`
- [L487](../../ERRORS.log#L487) `test_DN16_lastClose_thenDonate_nextBondDoesNotCapture()`
- [L488](../../ERRORS.log#L488) `test_DN17_d2_ids12_effectiveShares()`
- [L489](../../ERRORS.log#L489) `test_DN19_permit2_allowance()`
- [L490](../../ERRORS.log#L490) `test_DN1_donate_pair_Ogt0_unassignedLp()`
- [L491](../../ERRORS.log#L491) `test_DN20_permit2_signature()`
- [L492](../../ERRORS.log#L492) `test_DN21_d2_afterDonate()`
- [L493](../../ERRORS.log#L493) `test_DN22_donate_whilePoolManagerUnlocked()`
- [L494](../../ERRORS.log#L494) `test_DN2_donate_vaultShare()`
- [L495](../../ERRORS.log#L495) `test_DN4_donate_detf_selfLeg_noMint()`
- [L496](../../ERRORS.log#L496) `test_DN6_twoBonders_navRisesTogether()`
- [L497](../../ERRORS.log#L497) `test_DN7_detf_donate_forwardsToNft()`

**UniswapV4Detf_Orbital_ProductLaw_B_ALL9** — [UniswapV4Detf_Orbital_ProductLaw_B_ALL9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_Orbital_ProductLaw_B_ALL9.t.sol) (17 failures).

- [L500](../../ERRORS.log#L500) `test_A0_donateBeforeFirstBond_cannotFreeMint()`
- [L501](../../ERRORS.log#L501) `test_DN10_previewEqualsExecute()`
- [L502](../../ERRORS.log#L502) `test_DN11_ownerOnlyLiquidity_donateStillWorks()`
- [L503](../../ERRORS.log#L503) `test_DN12_donate_doesNotRealizeExpansion()`
- [L504](../../ERRORS.log#L504) `test_DN13_burn_afterDonate_usesDonatedLp()`
- [L505](../../ERRORS.log#L505) `test_DN14_closeAfterDonate_userBasketUnchanged()`
- [L506](../../ERRORS.log#L506) `test_DN16_lastClose_thenDonate_nextBondDoesNotCapture()`
- [L507](../../ERRORS.log#L507) `test_DN17_d2_ids12_effectiveShares()`
- [L508](../../ERRORS.log#L508) `test_DN19_permit2_allowance()`
- [L509](../../ERRORS.log#L509) `test_DN1_donate_pair_Ogt0_unassignedLp()`
- [L510](../../ERRORS.log#L510) `test_DN20_permit2_signature()`
- [L511](../../ERRORS.log#L511) `test_DN21_d2_afterDonate()`
- [L512](../../ERRORS.log#L512) `test_DN22_donate_whilePoolManagerUnlocked()`
- [L513](../../ERRORS.log#L513) `test_DN2_donate_vaultShare()`
- [L514](../../ERRORS.log#L514) `test_DN4_donate_detf_selfLeg_noMint()`
- [L515](../../ERRORS.log#L515) `test_DN6_twoBonders_navRisesTogether()`
- [L516](../../ERRORS.log#L516) `test_DN7_detf_donate_forwardsToNft()`

**UniswapV4Detf_Orbital_ProductLaw_B_P18_R6** — [UniswapV4Detf_Orbital_ProductLaw_B_P18_R6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_Orbital_ProductLaw_B_P18_R6.t.sol) (23 failures).

- [L519](../../ERRORS.log#L519) `test_A0_donateBeforeFirstBond_cannotFreeMint()`
- [L520](../../ERRORS.log#L520) `test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork()`
- [L521](../../ERRORS.log#L521) `test_DN10_previewEqualsExecute()`
- [L522](../../ERRORS.log#L522) `test_DN11_ownerOnlyLiquidity_donateStillWorks()`
- [L523](../../ERRORS.log#L523) `test_DN12_donate_doesNotRealizeExpansion()`
- [L524](../../ERRORS.log#L524) `test_DN13_burn_afterDonate_usesDonatedLp()`
- [L525](../../ERRORS.log#L525) `test_DN14_closeAfterDonate_userBasketUnchanged()`
- [L526](../../ERRORS.log#L526) `test_DN16_lastClose_thenDonate_nextBondDoesNotCapture()`
- [L527](../../ERRORS.log#L527) `test_DN17_d2_ids12_effectiveShares()`
- [L528](../../ERRORS.log#L528) `test_DN18_disabled_donateReverts_closeWorks()`
- [L529](../../ERRORS.log#L529) `test_DN19_permit2_allowance()`
- [L530](../../ERRORS.log#L530) `test_DN1_donate_pair_Ogt0_unassignedLp()`
- [L531](../../ERRORS.log#L531) `test_DN20_permit2_signature()`
- [L532](../../ERRORS.log#L532) `test_DN21_d2_afterDonate()`
- [L533](../../ERRORS.log#L533) `test_DN22_donate_whilePoolManagerUnlocked()`
- [L534](../../ERRORS.log#L534) `test_DN2_donate_vaultShare()`
- [L535](../../ERRORS.log#L535) `test_DN4_donate_detf_selfLeg_noMint()`
- [L536](../../ERRORS.log#L536) `test_DN6_twoBonders_navRisesTogether()`
- [L537](../../ERRORS.log#L537) `test_DN7_detf_donate_forwardsToNft()`
- [L538](../../ERRORS.log#L538) `test_T7_10_laterBond_joinUnbalanced_unboostedG()`
- [L539](../../ERRORS.log#L539) `test_claimRewards_whileLocked()`
- [L540](../../ERRORS.log#L540) `test_postMaturity_claimPaysFundedStaking()`
- [L541](../../ERRORS.log#L541) `test_preMaturity_principalVestsLinearly()`

**UniswapV4Detf_Orbital_ProductLaw_B_P18_R9** — [UniswapV4Detf_Orbital_ProductLaw_B_P18_R9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_Orbital_ProductLaw_B_P18_R9.t.sol) (23 failures).

- [L544](../../ERRORS.log#L544) `test_A0_donateBeforeFirstBond_cannotFreeMint()`
- [L545](../../ERRORS.log#L545) `test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork()`
- [L546](../../ERRORS.log#L546) `test_DN10_previewEqualsExecute()`
- [L547](../../ERRORS.log#L547) `test_DN11_ownerOnlyLiquidity_donateStillWorks()`
- [L548](../../ERRORS.log#L548) `test_DN12_donate_doesNotRealizeExpansion()`
- [L549](../../ERRORS.log#L549) `test_DN13_burn_afterDonate_usesDonatedLp()`
- [L550](../../ERRORS.log#L550) `test_DN14_closeAfterDonate_userBasketUnchanged()`
- [L551](../../ERRORS.log#L551) `test_DN16_lastClose_thenDonate_nextBondDoesNotCapture()`
- [L552](../../ERRORS.log#L552) `test_DN17_d2_ids12_effectiveShares()`
- [L553](../../ERRORS.log#L553) `test_DN18_disabled_donateReverts_closeWorks()`
- [L554](../../ERRORS.log#L554) `test_DN19_permit2_allowance()`
- [L555](../../ERRORS.log#L555) `test_DN1_donate_pair_Ogt0_unassignedLp()`
- [L556](../../ERRORS.log#L556) `test_DN20_permit2_signature()`
- [L557](../../ERRORS.log#L557) `test_DN21_d2_afterDonate()`
- [L558](../../ERRORS.log#L558) `test_DN22_donate_whilePoolManagerUnlocked()`
- [L559](../../ERRORS.log#L559) `test_DN2_donate_vaultShare()`
- [L560](../../ERRORS.log#L560) `test_DN4_donate_detf_selfLeg_noMint()`
- [L561](../../ERRORS.log#L561) `test_DN6_twoBonders_navRisesTogether()`
- [L562](../../ERRORS.log#L562) `test_DN7_detf_donate_forwardsToNft()`
- [L563](../../ERRORS.log#L563) `test_T7_10_laterBond_joinUnbalanced_unboostedG()`
- [L564](../../ERRORS.log#L564) `test_claimRewards_whileLocked()`
- [L565](../../ERRORS.log#L565) `test_postMaturity_claimPaysFundedStaking()`
- [L566](../../ERRORS.log#L566) `test_preMaturity_principalVestsLinearly()`

**UniswapV4Detf_Orbital_ProductLaw_B_P6_R18** — [UniswapV4Detf_Orbital_ProductLaw_B_P6_R18.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_Orbital_ProductLaw_B_P6_R18.t.sol) (17 failures).

- [L569](../../ERRORS.log#L569) `test_A0_donateBeforeFirstBond_cannotFreeMint()`
- [L570](../../ERRORS.log#L570) `test_DN10_previewEqualsExecute()`
- [L571](../../ERRORS.log#L571) `test_DN11_ownerOnlyLiquidity_donateStillWorks()`
- [L572](../../ERRORS.log#L572) `test_DN12_donate_doesNotRealizeExpansion()`
- [L573](../../ERRORS.log#L573) `test_DN13_burn_afterDonate_usesDonatedLp()`
- [L574](../../ERRORS.log#L574) `test_DN14_closeAfterDonate_userBasketUnchanged()`
- [L575](../../ERRORS.log#L575) `test_DN16_lastClose_thenDonate_nextBondDoesNotCapture()`
- [L576](../../ERRORS.log#L576) `test_DN17_d2_ids12_effectiveShares()`
- [L577](../../ERRORS.log#L577) `test_DN19_permit2_allowance()`
- [L578](../../ERRORS.log#L578) `test_DN1_donate_pair_Ogt0_unassignedLp()`
- [L579](../../ERRORS.log#L579) `test_DN20_permit2_signature()`
- [L580](../../ERRORS.log#L580) `test_DN21_d2_afterDonate()`
- [L581](../../ERRORS.log#L581) `test_DN22_donate_whilePoolManagerUnlocked()`
- [L582](../../ERRORS.log#L582) `test_DN2_donate_vaultShare()`
- [L583](../../ERRORS.log#L583) `test_DN4_donate_detf_selfLeg_noMint()`
- [L584](../../ERRORS.log#L584) `test_DN6_twoBonders_navRisesTogether()`
- [L585](../../ERRORS.log#L585) `test_DN7_detf_donate_forwardsToNft()`

**UniswapV4Detf_Orbital_ProductLaw_B_P6_R9** — [UniswapV4Detf_Orbital_ProductLaw_B_P6_R9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_Orbital_ProductLaw_B_P6_R9.t.sol) (17 failures).

- [L588](../../ERRORS.log#L588) `test_A0_donateBeforeFirstBond_cannotFreeMint()`
- [L589](../../ERRORS.log#L589) `test_DN10_previewEqualsExecute()`
- [L590](../../ERRORS.log#L590) `test_DN11_ownerOnlyLiquidity_donateStillWorks()`
- [L591](../../ERRORS.log#L591) `test_DN12_donate_doesNotRealizeExpansion()`
- [L592](../../ERRORS.log#L592) `test_DN13_burn_afterDonate_usesDonatedLp()`
- [L593](../../ERRORS.log#L593) `test_DN14_closeAfterDonate_userBasketUnchanged()`
- [L594](../../ERRORS.log#L594) `test_DN16_lastClose_thenDonate_nextBondDoesNotCapture()`
- [L595](../../ERRORS.log#L595) `test_DN17_d2_ids12_effectiveShares()`
- [L596](../../ERRORS.log#L596) `test_DN19_permit2_allowance()`
- [L597](../../ERRORS.log#L597) `test_DN1_donate_pair_Ogt0_unassignedLp()`
- [L598](../../ERRORS.log#L598) `test_DN20_permit2_signature()`
- [L599](../../ERRORS.log#L599) `test_DN21_d2_afterDonate()`
- [L600](../../ERRORS.log#L600) `test_DN22_donate_whilePoolManagerUnlocked()`
- [L601](../../ERRORS.log#L601) `test_DN2_donate_vaultShare()`
- [L602](../../ERRORS.log#L602) `test_DN4_donate_detf_selfLeg_noMint()`
- [L603](../../ERRORS.log#L603) `test_DN6_twoBonders_navRisesTogether()`
- [L604](../../ERRORS.log#L604) `test_DN7_detf_donate_forwardsToNft()`

**UniswapV4Detf_Orbital_ProductLaw_B_P9_R18** — [UniswapV4Detf_Orbital_ProductLaw_B_P9_R18.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_Orbital_ProductLaw_B_P9_R18.t.sol) (17 failures).

- [L607](../../ERRORS.log#L607) `test_A0_donateBeforeFirstBond_cannotFreeMint()`
- [L608](../../ERRORS.log#L608) `test_DN10_previewEqualsExecute()`
- [L609](../../ERRORS.log#L609) `test_DN11_ownerOnlyLiquidity_donateStillWorks()`
- [L610](../../ERRORS.log#L610) `test_DN12_donate_doesNotRealizeExpansion()`
- [L611](../../ERRORS.log#L611) `test_DN13_burn_afterDonate_usesDonatedLp()`
- [L612](../../ERRORS.log#L612) `test_DN14_closeAfterDonate_userBasketUnchanged()`
- [L613](../../ERRORS.log#L613) `test_DN16_lastClose_thenDonate_nextBondDoesNotCapture()`
- [L614](../../ERRORS.log#L614) `test_DN17_d2_ids12_effectiveShares()`
- [L615](../../ERRORS.log#L615) `test_DN19_permit2_allowance()`
- [L616](../../ERRORS.log#L616) `test_DN1_donate_pair_Ogt0_unassignedLp()`
- [L617](../../ERRORS.log#L617) `test_DN20_permit2_signature()`
- [L618](../../ERRORS.log#L618) `test_DN21_d2_afterDonate()`
- [L619](../../ERRORS.log#L619) `test_DN22_donate_whilePoolManagerUnlocked()`
- [L620](../../ERRORS.log#L620) `test_DN2_donate_vaultShare()`
- [L621](../../ERRORS.log#L621) `test_DN4_donate_detf_selfLeg_noMint()`
- [L622](../../ERRORS.log#L622) `test_DN6_twoBonders_navRisesTogether()`
- [L623](../../ERRORS.log#L623) `test_DN7_detf_donate_forwardsToNft()`

**UniswapV4Detf_Orbital_ProductLaw_B_P9_R6** — [UniswapV4Detf_Orbital_ProductLaw_B_P9_R6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_Orbital_ProductLaw_B_P9_R6.t.sol) (17 failures).

- [L626](../../ERRORS.log#L626) `test_A0_donateBeforeFirstBond_cannotFreeMint()`
- [L627](../../ERRORS.log#L627) `test_DN10_previewEqualsExecute()`
- [L628](../../ERRORS.log#L628) `test_DN11_ownerOnlyLiquidity_donateStillWorks()`
- [L629](../../ERRORS.log#L629) `test_DN12_donate_doesNotRealizeExpansion()`
- [L630](../../ERRORS.log#L630) `test_DN13_burn_afterDonate_usesDonatedLp()`
- [L631](../../ERRORS.log#L631) `test_DN14_closeAfterDonate_userBasketUnchanged()`
- [L632](../../ERRORS.log#L632) `test_DN16_lastClose_thenDonate_nextBondDoesNotCapture()`
- [L633](../../ERRORS.log#L633) `test_DN17_d2_ids12_effectiveShares()`
- [L634](../../ERRORS.log#L634) `test_DN19_permit2_allowance()`
- [L635](../../ERRORS.log#L635) `test_DN1_donate_pair_Ogt0_unassignedLp()`
- [L636](../../ERRORS.log#L636) `test_DN20_permit2_signature()`
- [L637](../../ERRORS.log#L637) `test_DN21_d2_afterDonate()`
- [L638](../../ERRORS.log#L638) `test_DN22_donate_whilePoolManagerUnlocked()`
- [L639](../../ERRORS.log#L639) `test_DN2_donate_vaultShare()`
- [L640](../../ERRORS.log#L640) `test_DN4_donate_detf_selfLeg_noMint()`
- [L641](../../ERRORS.log#L641) `test_DN6_twoBonders_navRisesTogether()`
- [L642](../../ERRORS.log#L642) `test_DN7_detf_donate_forwardsToNft()`

**UniswapV4Detf_Policy_H6** — [UniswapV4Detf_Policy_H6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_Policy_H6.t.sol) (1 failure).

- [L645](../../ERRORS.log#L645) `test_compound_raises_protocolLp()`

**UniswapV4Detf_Policy_P18_R6** — [UniswapV4Detf_Policy_P18_R6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_Policy_P18_R6.t.sol) (1 failure).

- [L648](../../ERRORS.log#L648) `test_compound_raises_protocolLp()`

**UniswapV4Detf_Policy_P18_R9** — [UniswapV4Detf_Policy_P18_R9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_Policy_P18_R9.t.sol) (1 failure).

- [L651](../../ERRORS.log#L651) `test_compound_raises_protocolLp()`

**UniswapV4Detf_Policy_P6_R18** — [UniswapV4Detf_Policy_P6_R18.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_Policy_P6_R18.t.sol) (1 failure).

- [L654](../../ERRORS.log#L654) `test_compound_raises_protocolLp()`

**UniswapV4Detf_Policy_P6_R9** — [UniswapV4Detf_Policy_P6_R9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_Policy_P6_R9.t.sol) (1 failure).

- [L657](../../ERRORS.log#L657) `test_compound_raises_protocolLp()`

**UniswapV4Detf_ProductLaw_H6** — [UniswapV4Detf_ProductLaw_H6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_ProductLaw_H6.t.sol) (9 failures).

- [L660](../../ERRORS.log#L660) `test_A0_donateBeforeFirstBond_cannotFreeMint()`
- [L661](../../ERRORS.log#L661) `test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork()`
- [L662](../../ERRORS.log#L662) `test_DN14_closeAfterDonate_userBasketUnchanged()`
- [L663](../../ERRORS.log#L663) `test_DN16_lastClose_thenDonate_nextBondDoesNotCapture()`
- [L664](../../ERRORS.log#L664) `test_DN6_twoBonders_navRisesTogether()`
- [L665](../../ERRORS.log#L665) `test_T7_10_laterBond_joinUnbalanced_unboostedG()`
- [L666](../../ERRORS.log#L666) `test_claimRewards_whileLocked()`
- [L667](../../ERRORS.log#L667) `test_postMaturity_claimPaysFundedStaking()`
- [L668](../../ERRORS.log#L668) `test_preMaturity_principalVestsLinearly()`

**UniswapV4Detf_ProductLaw_H9** — [UniswapV4Detf_ProductLaw_H9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_ProductLaw_H9.t.sol) (1 failure).

- [L671](../../ERRORS.log#L671) `test_A0_donateBeforeFirstBond_cannotFreeMint()`

**UniswapV4Detf_ProductLaw_P18_R6** — [UniswapV4Detf_ProductLaw_P18_R6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_ProductLaw_P18_R6.t.sol) (15 failures).

- [L674](../../ERRORS.log#L674) `test_A0_donateBeforeFirstBond_cannotFreeMint()`
- [L675](../../ERRORS.log#L675) `test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork()`
- [L676](../../ERRORS.log#L676) `test_D15_1_previewEqualsExecute()`
- [L677](../../ERRORS.log#L677) `test_D15_8_nonDetfPayoutForbidden()`
- [L678](../../ERRORS.log#L678) `test_D15_redeem_paysDetf_only()`
- [L679](../../ERRORS.log#L679) `test_D25_fundedPrincipalAndRewardsPayOnlyStaking()`
- [L680](../../ERRORS.log#L680) `test_D25_standingReceiptsAlreadyFundedBeforeClaim()`
- [L681](../../ERRORS.log#L681) `test_DN14_closeAfterDonate_userBasketUnchanged()`
- [L682](../../ERRORS.log#L682) `test_DN16_lastClose_thenDonate_nextBondDoesNotCapture()`
- [L683](../../ERRORS.log#L683) `test_DN18_disabled_donateReverts_closeWorks()`
- [L684](../../ERRORS.log#L684) `test_DN6_twoBonders_navRisesTogether()`
- [L685](../../ERRORS.log#L685) `test_T7_10_laterBond_joinUnbalanced_unboostedG()`
- [L686](../../ERRORS.log#L686) `test_claimRewards_whileLocked()`
- [L687](../../ERRORS.log#L687) `test_postMaturity_claimPaysFundedStaking()`
- [L688](../../ERRORS.log#L688) `test_preMaturity_principalVestsLinearly()`

**UniswapV4Detf_ProductLaw_P18_R9** — [UniswapV4Detf_ProductLaw_P18_R9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_ProductLaw_P18_R9.t.sol) (15 failures).

- [L691](../../ERRORS.log#L691) `test_A0_donateBeforeFirstBond_cannotFreeMint()`
- [L692](../../ERRORS.log#L692) `test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork()`
- [L693](../../ERRORS.log#L693) `test_D15_1_previewEqualsExecute()`
- [L694](../../ERRORS.log#L694) `test_D15_8_nonDetfPayoutForbidden()`
- [L695](../../ERRORS.log#L695) `test_D15_redeem_paysDetf_only()`
- [L696](../../ERRORS.log#L696) `test_D25_fundedPrincipalAndRewardsPayOnlyStaking()`
- [L697](../../ERRORS.log#L697) `test_D25_standingReceiptsAlreadyFundedBeforeClaim()`
- [L698](../../ERRORS.log#L698) `test_DN14_closeAfterDonate_userBasketUnchanged()`
- [L699](../../ERRORS.log#L699) `test_DN16_lastClose_thenDonate_nextBondDoesNotCapture()`
- [L700](../../ERRORS.log#L700) `test_DN18_disabled_donateReverts_closeWorks()`
- [L701](../../ERRORS.log#L701) `test_DN6_twoBonders_navRisesTogether()`
- [L702](../../ERRORS.log#L702) `test_T7_10_laterBond_joinUnbalanced_unboostedG()`
- [L703](../../ERRORS.log#L703) `test_claimRewards_whileLocked()`
- [L704](../../ERRORS.log#L704) `test_postMaturity_claimPaysFundedStaking()`
- [L705](../../ERRORS.log#L705) `test_preMaturity_principalVestsLinearly()`

**UniswapV4Detf_ProductLaw_P6_R18** — [UniswapV4Detf_ProductLaw_P6_R18.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_ProductLaw_P6_R18.t.sol) (9 failures).

- [L708](../../ERRORS.log#L708) `test_A0_donateBeforeFirstBond_cannotFreeMint()`
- [L709](../../ERRORS.log#L709) `test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork()`
- [L710](../../ERRORS.log#L710) `test_DN14_closeAfterDonate_userBasketUnchanged()`
- [L711](../../ERRORS.log#L711) `test_DN16_lastClose_thenDonate_nextBondDoesNotCapture()`
- [L712](../../ERRORS.log#L712) `test_DN6_twoBonders_navRisesTogether()`
- [L713](../../ERRORS.log#L713) `test_T7_10_laterBond_joinUnbalanced_unboostedG()`
- [L714](../../ERRORS.log#L714) `test_claimRewards_whileLocked()`
- [L715](../../ERRORS.log#L715) `test_postMaturity_claimPaysFundedStaking()`
- [L716](../../ERRORS.log#L716) `test_preMaturity_principalVestsLinearly()`

**UniswapV4Detf_ProductLaw_P6_R9** — [UniswapV4Detf_ProductLaw_P6_R9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_ProductLaw_P6_R9.t.sol) (9 failures).

- [L719](../../ERRORS.log#L719) `test_A0_donateBeforeFirstBond_cannotFreeMint()`
- [L720](../../ERRORS.log#L720) `test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork()`
- [L721](../../ERRORS.log#L721) `test_DN14_closeAfterDonate_userBasketUnchanged()`
- [L722](../../ERRORS.log#L722) `test_DN16_lastClose_thenDonate_nextBondDoesNotCapture()`
- [L723](../../ERRORS.log#L723) `test_DN6_twoBonders_navRisesTogether()`
- [L724](../../ERRORS.log#L724) `test_T7_10_laterBond_joinUnbalanced_unboostedG()`
- [L725](../../ERRORS.log#L725) `test_claimRewards_whileLocked()`
- [L726](../../ERRORS.log#L726) `test_postMaturity_claimPaysFundedStaking()`
- [L727](../../ERRORS.log#L727) `test_preMaturity_principalVestsLinearly()`

**UniswapV4Detf_ProductLaw_P9_R18** — [UniswapV4Detf_ProductLaw_P9_R18.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_ProductLaw_P9_R18.t.sol) (1 failure).

- [L730](../../ERRORS.log#L730) `test_A0_donateBeforeFirstBond_cannotFreeMint()`

**UniswapV4Detf_ProductLaw_P9_R6** — [UniswapV4Detf_ProductLaw_P9_R6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_ProductLaw_P9_R6.t.sol) (1 failure).

- [L733](../../ERRORS.log#L733) `test_A0_donateBeforeFirstBond_cannotFreeMint()`

**UniswapV4Detf_ReserveDonation_H6** — [UniswapV4Detf_ReserveDonation_H6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_ReserveDonation_H6.t.sol) (3 failures).

- [L736](../../ERRORS.log#L736) `test_DN14_closeAfterDonate_userBasketUnchanged()`
- [L737](../../ERRORS.log#L737) `test_DN16_lastClose_thenDonate_nextBondDoesNotCapture()`
- [L738](../../ERRORS.log#L738) `test_DN6_twoBonders_navRisesTogether()`

**UniswapV4Detf_ReserveDonation_P18_R6** — [UniswapV4Detf_ReserveDonation_P18_R6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_ReserveDonation_P18_R6.t.sol) (4 failures).

- [L741](../../ERRORS.log#L741) `test_DN14_closeAfterDonate_userBasketUnchanged()`
- [L742](../../ERRORS.log#L742) `test_DN16_lastClose_thenDonate_nextBondDoesNotCapture()`
- [L743](../../ERRORS.log#L743) `test_DN18_disabled_donateReverts_closeWorks()`
- [L744](../../ERRORS.log#L744) `test_DN6_twoBonders_navRisesTogether()`

**UniswapV4Detf_ReserveDonation_P18_R9** — [UniswapV4Detf_ReserveDonation_P18_R9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_ReserveDonation_P18_R9.t.sol) (4 failures).

- [L747](../../ERRORS.log#L747) `test_DN14_closeAfterDonate_userBasketUnchanged()`
- [L748](../../ERRORS.log#L748) `test_DN16_lastClose_thenDonate_nextBondDoesNotCapture()`
- [L749](../../ERRORS.log#L749) `test_DN18_disabled_donateReverts_closeWorks()`
- [L750](../../ERRORS.log#L750) `test_DN6_twoBonders_navRisesTogether()`

**UniswapV4Detf_ReserveDonation_P6_R18** — [UniswapV4Detf_ReserveDonation_P6_R18.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_ReserveDonation_P6_R18.t.sol) (3 failures).

- [L753](../../ERRORS.log#L753) `test_DN14_closeAfterDonate_userBasketUnchanged()`
- [L754](../../ERRORS.log#L754) `test_DN16_lastClose_thenDonate_nextBondDoesNotCapture()`
- [L755](../../ERRORS.log#L755) `test_DN6_twoBonders_navRisesTogether()`

**UniswapV4Detf_ReserveDonation_P6_R9** — [UniswapV4Detf_ReserveDonation_P6_R9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/UniswapV4Detf_ReserveDonation_P6_R9.t.sol) (3 failures).

- [L758](../../ERRORS.log#L758) `test_DN14_closeAfterDonate_userBasketUnchanged()`
- [L759](../../ERRORS.log#L759) `test_DN16_lastClose_thenDonate_nextBondDoesNotCapture()`
- [L760](../../ERRORS.log#L760) `test_DN6_twoBonders_navRisesTogether()`

**Adversarial_A0Crops_H6_DexUniV4Det** — [Adversarial_A0Crops_H6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/adversarial/Adversarial_A0Crops_H6.t.sol) (2 failures).

- [L763](../../ERRORS.log#L763) `test_A0_donateBeforeFirstBond_cannotFreeMint()`
- [L764](../../ERRORS.log#L764) `test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork()`

**Adversarial_A0Crops_H9_DexUniV4Det** — [Adversarial_A0Crops_H9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/adversarial/Adversarial_A0Crops_H9.t.sol) (1 failure).

- [L767](../../ERRORS.log#L767) `test_A0_donateBeforeFirstBond_cannotFreeMint()`

**Adversarial_A0Crops_P18_R6_DexUniV4Det** — [Adversarial_A0Crops_P18_R6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/adversarial/Adversarial_A0Crops_P18_R6.t.sol) (2 failures).

- [L770](../../ERRORS.log#L770) `test_A0_donateBeforeFirstBond_cannotFreeMint()`
- [L771](../../ERRORS.log#L771) `test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork()`

**Adversarial_A0Crops_P18_R9_DexUniV4Det** — [Adversarial_A0Crops_P18_R9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/adversarial/Adversarial_A0Crops_P18_R9.t.sol) (2 failures).

- [L774](../../ERRORS.log#L774) `test_A0_donateBeforeFirstBond_cannotFreeMint()`
- [L775](../../ERRORS.log#L775) `test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork()`

**Adversarial_A0Crops_P6_R18_DexUniV4Det** — [Adversarial_A0Crops_P6_R18.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/adversarial/Adversarial_A0Crops_P6_R18.t.sol) (2 failures).

- [L778](../../ERRORS.log#L778) `test_A0_donateBeforeFirstBond_cannotFreeMint()`
- [L779](../../ERRORS.log#L779) `test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork()`

**Adversarial_A0Crops_P6_R9_DexUniV4Det** — [Adversarial_A0Crops_P6_R9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/adversarial/Adversarial_A0Crops_P6_R9.t.sol) (2 failures).

- [L782](../../ERRORS.log#L782) `test_A0_donateBeforeFirstBond_cannotFreeMint()`
- [L783](../../ERRORS.log#L783) `test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork()`

**Adversarial_A0Crops_P9_R18_DexUniV4Det** — [Adversarial_A0Crops_P9_R18.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/adversarial/Adversarial_A0Crops_P9_R18.t.sol) (1 failure).

- [L786](../../ERRORS.log#L786) `test_A0_donateBeforeFirstBond_cannotFreeMint()`

**Adversarial_A0Crops_P9_R6_DexUniV4Det** — [Adversarial_A0Crops_P9_R6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/adversarial/Adversarial_A0Crops_P9_R6.t.sol) (1 failure).

- [L789](../../ERRORS.log#L789) `test_A0_donateBeforeFirstBond_cannotFreeMint()`

**UniswapV4Detf_Invariant** — [UniswapV4Detf_Invariant.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/invariant/UniswapV4Detf_Invariant.t.sol) (2 failures).

- [L802](../../ERRORS.log#L802) `test_APEX_R13_5_partialRestingCredit_creditsRequestedOnly()`
- [L803](../../ERRORS.log#L803) `test_deterministicLifecycle()`

**UniswapV4Detf_PonsV2Se_Policy** — [UniswapV4Detf_PonsV2Se_Policy.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/pons/UniswapV4Detf_PonsV2Se_Policy.t.sol) (7 failures).

- [L806](../../ERRORS.log#L806) `test_D15_1_previewEqualsExecute()`
- [L807](../../ERRORS.log#L807) `test_D15_8_nonDetfPayoutForbidden()`
- [L808](../../ERRORS.log#L808) `test_D22_claimUngated()`
- [L809](../../ERRORS.log#L809) `test_FC_creatorZeroFundsBothRightsToOriginalFeeOwner()`
- [L810](../../ERRORS.log#L810) `test_FC_explicitCreatorReceivesSeparateFundedIncome()`
- [L811](../../ERRORS.log#L811) `test_FC_fullExitAndFeeToRotationPreserveStandingIncome()`
- [L812](../../ERRORS.log#L812) `test_FC_fundedTwoWavesMatchIndependentFloors()`

**UniswapV4Detf_PonsV2Se_ProductLaw** — [UniswapV4Detf_PonsV2Se_ProductLaw.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/pons/UniswapV4Detf_PonsV2Se_ProductLaw.t.sol) (18 failures).

- [L815](../../ERRORS.log#L815) `test_D15_1_previewEqualsExecute()`
- [L816](../../ERRORS.log#L816) `test_D15_8_nonDetfPayoutForbidden()`
- [L817](../../ERRORS.log#L817) `test_D25_finalClaimRetainsProtocolLiquidity()`
- [L818](../../ERRORS.log#L818) `test_D25_fundedPrincipalAndRewardsPayOnlyStaking()`
- [L819](../../ERRORS.log#L819) `test_D25_reservedRolesCannotClaimPurchasedPrincipal()`
- [L820](../../ERRORS.log#L820) `test_D25_standingReceiptsAlreadyFundedBeforeClaim()`
- [L821](../../ERRORS.log#L821) `test_DN14_closeAfterDonate_userBasketUnchanged()`
- [L822](../../ERRORS.log#L822) `test_DN16_lastClose_thenDonate_nextBondDoesNotCapture()`
- [L823](../../ERRORS.log#L823) `test_DN18_disabled_donateReverts_closeWorks()`
- [L824](../../ERRORS.log#L824) `test_DN6_twoBonders_navRisesTogether()`
- [L825](../../ERRORS.log#L825) `test_FC_creatorZeroFundsBothRightsToOriginalFeeOwner()`
- [L826](../../ERRORS.log#L826) `test_FC_explicitCreatorReceivesSeparateFundedIncome()`
- [L827](../../ERRORS.log#L827) `test_FC_fullExitAndFeeToRotationPreserveStandingIncome()`
- [L828](../../ERRORS.log#L828) `test_FC_fundedTwoWavesMatchIndependentFloors()`
- [L829](../../ERRORS.log#L829) `test_T7_10_laterBond_joinUnbalanced_unboostedG()`
- [L830](../../ERRORS.log#L830) `test_claimRewards_whileLocked()`
- [L831](../../ERRORS.log#L831) `test_issuanceFundsStakingImmediatelyAndSettlementDoesNotJoinLp()`
- [L832](../../ERRORS.log#L832) `test_matureBondPaysFundedStakingAndRetainsLiquidity()`

**UniswapV4Detf_PonsV2Se_Policy_P18_R6** — [UniswapV4Detf_PonsV2Se_Policy_P18_R6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/pons/decimals/UniswapV4Detf_PonsV2Se_Policy_P18_R6.t.sol) (7 failures).

- [L835](../../ERRORS.log#L835) `test_D15_1_previewEqualsExecute()`
- [L836](../../ERRORS.log#L836) `test_D15_8_nonDetfPayoutForbidden()`
- [L837](../../ERRORS.log#L837) `test_D22_claimUngated()`
- [L838](../../ERRORS.log#L838) `test_FC_creatorZeroFundsBothRightsToOriginalFeeOwner()`
- [L839](../../ERRORS.log#L839) `test_FC_explicitCreatorReceivesSeparateFundedIncome()`
- [L840](../../ERRORS.log#L840) `test_FC_fullExitAndFeeToRotationPreserveStandingIncome()`
- [L841](../../ERRORS.log#L841) `test_FC_fundedTwoWavesMatchIndependentFloors()`

**UniswapV4Detf_PonsV2Se_Policy_P18_R9** — [UniswapV4Detf_PonsV2Se_Policy_P18_R9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/pons/decimals/UniswapV4Detf_PonsV2Se_Policy_P18_R9.t.sol) (7 failures).

- [L844](../../ERRORS.log#L844) `test_D15_1_previewEqualsExecute()`
- [L845](../../ERRORS.log#L845) `test_D15_8_nonDetfPayoutForbidden()`
- [L846](../../ERRORS.log#L846) `test_D22_claimUngated()`
- [L847](../../ERRORS.log#L847) `test_FC_creatorZeroFundsBothRightsToOriginalFeeOwner()`
- [L848](../../ERRORS.log#L848) `test_FC_explicitCreatorReceivesSeparateFundedIncome()`
- [L849](../../ERRORS.log#L849) `test_FC_fullExitAndFeeToRotationPreserveStandingIncome()`
- [L850](../../ERRORS.log#L850) `test_FC_fundedTwoWavesMatchIndependentFloors()`

**UniswapV4Detf_PonsV2Se_ProductLaw_P18_R6** — [UniswapV4Detf_PonsV2Se_ProductLaw_P18_R6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/pons/decimals/UniswapV4Detf_PonsV2Se_ProductLaw_P18_R6.t.sol) (18 failures).

- [L853](../../ERRORS.log#L853) `test_D15_1_previewEqualsExecute()`
- [L854](../../ERRORS.log#L854) `test_D15_8_nonDetfPayoutForbidden()`
- [L855](../../ERRORS.log#L855) `test_D25_finalClaimRetainsProtocolLiquidity()`
- [L856](../../ERRORS.log#L856) `test_D25_fundedPrincipalAndRewardsPayOnlyStaking()`
- [L857](../../ERRORS.log#L857) `test_D25_reservedRolesCannotClaimPurchasedPrincipal()`
- [L858](../../ERRORS.log#L858) `test_D25_standingReceiptsAlreadyFundedBeforeClaim()`
- [L859](../../ERRORS.log#L859) `test_DN14_closeAfterDonate_userBasketUnchanged()`
- [L860](../../ERRORS.log#L860) `test_DN16_lastClose_thenDonate_nextBondDoesNotCapture()`
- [L861](../../ERRORS.log#L861) `test_DN18_disabled_donateReverts_closeWorks()`
- [L862](../../ERRORS.log#L862) `test_DN6_twoBonders_navRisesTogether()`
- [L863](../../ERRORS.log#L863) `test_FC_creatorZeroFundsBothRightsToOriginalFeeOwner()`
- [L864](../../ERRORS.log#L864) `test_FC_explicitCreatorReceivesSeparateFundedIncome()`
- [L865](../../ERRORS.log#L865) `test_FC_fullExitAndFeeToRotationPreserveStandingIncome()`
- [L866](../../ERRORS.log#L866) `test_FC_fundedTwoWavesMatchIndependentFloors()`
- [L867](../../ERRORS.log#L867) `test_T7_10_laterBond_joinUnbalanced_unboostedG()`
- [L868](../../ERRORS.log#L868) `test_claimRewards_whileLocked()`
- [L869](../../ERRORS.log#L869) `test_issuanceFundsStakingImmediatelyAndSettlementDoesNotJoinLp()`
- [L870](../../ERRORS.log#L870) `test_matureBondPaysFundedStakingAndRetainsLiquidity()`

**UniswapV4Detf_PonsV2Se_ProductLaw_P18_R9** — [UniswapV4Detf_PonsV2Se_ProductLaw_P18_R9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/pons/decimals/UniswapV4Detf_PonsV2Se_ProductLaw_P18_R9.t.sol) (18 failures).

- [L873](../../ERRORS.log#L873) `test_D15_1_previewEqualsExecute()`
- [L874](../../ERRORS.log#L874) `test_D15_8_nonDetfPayoutForbidden()`
- [L875](../../ERRORS.log#L875) `test_D25_finalClaimRetainsProtocolLiquidity()`
- [L876](../../ERRORS.log#L876) `test_D25_fundedPrincipalAndRewardsPayOnlyStaking()`
- [L877](../../ERRORS.log#L877) `test_D25_reservedRolesCannotClaimPurchasedPrincipal()`
- [L878](../../ERRORS.log#L878) `test_D25_standingReceiptsAlreadyFundedBeforeClaim()`
- [L879](../../ERRORS.log#L879) `test_DN14_closeAfterDonate_userBasketUnchanged()`
- [L880](../../ERRORS.log#L880) `test_DN16_lastClose_thenDonate_nextBondDoesNotCapture()`
- [L881](../../ERRORS.log#L881) `test_DN18_disabled_donateReverts_closeWorks()`
- [L882](../../ERRORS.log#L882) `test_DN6_twoBonders_navRisesTogether()`
- [L883](../../ERRORS.log#L883) `test_FC_creatorZeroFundsBothRightsToOriginalFeeOwner()`
- [L884](../../ERRORS.log#L884) `test_FC_explicitCreatorReceivesSeparateFundedIncome()`
- [L885](../../ERRORS.log#L885) `test_FC_fullExitAndFeeToRotationPreserveStandingIncome()`
- [L886](../../ERRORS.log#L886) `test_FC_fundedTwoWavesMatchIndependentFloors()`
- [L887](../../ERRORS.log#L887) `test_T7_10_laterBond_joinUnbalanced_unboostedG()`
- [L888](../../ERRORS.log#L888) `test_claimRewards_whileLocked()`
- [L889](../../ERRORS.log#L889) `test_issuanceFundsStakingImmediatelyAndSettlementDoesNotJoinLp()`
- [L890](../../ERRORS.log#L890) `test_matureBondPaysFundedStakingAndRetainsLiquidity()`

**UniswapV4Detf_Cp_MorphoBlueSe_Policy** — [UniswapV4Detf_Cp_MorphoBlueSe_Policy.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Cp_MorphoBlueSe_Policy.t.sol) (8 failures).

- [L893](../../ERRORS.log#L893) `test_D15_1_previewEqualsExecute()`
- [L894](../../ERRORS.log#L894) `test_D15_8_nonDetfPayoutForbidden()`
- [L895](../../ERRORS.log#L895) `test_D15_redeem_paysDetf_only()`
- [L896](../../ERRORS.log#L896) `test_D22_claimUngated()`
- [L897](../../ERRORS.log#L897) `test_FC_creatorZeroFundsBothRightsToOriginalFeeOwner()`
- [L898](../../ERRORS.log#L898) `test_FC_explicitCreatorReceivesSeparateFundedIncome()`
- [L899](../../ERRORS.log#L899) `test_FC_fullExitAndFeeToRotationPreserveStandingIncome()`
- [L900](../../ERRORS.log#L900) `test_FC_fundedTwoWavesMatchIndependentFloors()`

**UniswapV4Detf_Cp_MorphoBlueSe_ProductLaw** — [UniswapV4Detf_Cp_MorphoBlueSe_ProductLaw.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Cp_MorphoBlueSe_ProductLaw.t.sol) (16 failures).

- [L903](../../ERRORS.log#L903) `test_A0_donateBeforeFirstBond_cannotFreeMint()`
- [L904](../../ERRORS.log#L904) `test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork()`
- [L905](../../ERRORS.log#L905) `test_D15_1_previewEqualsExecute()`
- [L906](../../ERRORS.log#L906) `test_D15_8_nonDetfPayoutForbidden()`
- [L907](../../ERRORS.log#L907) `test_D15_redeem_paysDetf_only()`
- [L908](../../ERRORS.log#L908) `test_D25_fundedPrincipalAndRewardsPayOnlyStaking()`
- [L909](../../ERRORS.log#L909) `test_D25_standingReceiptsAlreadyFundedBeforeClaim()`
- [L910](../../ERRORS.log#L910) `test_DN14_closeAfterDonate_userBasketUnchanged()`
- [L911](../../ERRORS.log#L911) `test_DN16_lastClose_thenDonate_nextBondDoesNotCapture()`
- [L912](../../ERRORS.log#L912) `test_DN18_disabled_donateReverts_closeWorks()`
- [L913](../../ERRORS.log#L913) `test_DN6_twoBonders_navRisesTogether()`
- [L914](../../ERRORS.log#L914) `test_T7_10_laterBond_joinUnbalanced_unboostedG()`
- [L915](../../ERRORS.log#L915) `test_claimRewards_whileLocked()`
- [L916](../../ERRORS.log#L916) `test_compound_raises_protocolLp()`
- [L917](../../ERRORS.log#L917) `test_postMaturity_claimPaysFundedStaking()`
- [L918](../../ERRORS.log#L918) `test_preMaturity_principalVestsLinearly()`

**UniswapV4Detf_Cp_PonsV1Se_Policy** — [UniswapV4Detf_Cp_PonsV1Se_Policy.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Cp_PonsV1Se_Policy.t.sol) (8 failures).

- [L921](../../ERRORS.log#L921) `test_D15_1_previewEqualsExecute()`
- [L922](../../ERRORS.log#L922) `test_D15_8_nonDetfPayoutForbidden()`
- [L923](../../ERRORS.log#L923) `test_D15_redeem_paysDetf_only()`
- [L924](../../ERRORS.log#L924) `test_D22_claimUngated()`
- [L925](../../ERRORS.log#L925) `test_FC_creatorZeroFundsBothRightsToOriginalFeeOwner()`
- [L926](../../ERRORS.log#L926) `test_FC_explicitCreatorReceivesSeparateFundedIncome()`
- [L927](../../ERRORS.log#L927) `test_FC_fullExitAndFeeToRotationPreserveStandingIncome()`
- [L928](../../ERRORS.log#L928) `test_FC_fundedTwoWavesMatchIndependentFloors()`

**UniswapV4Detf_Cp_PonsV1Se_ProductLaw** — [UniswapV4Detf_Cp_PonsV1Se_ProductLaw.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Cp_PonsV1Se_ProductLaw.t.sol) (16 failures).

- [L931](../../ERRORS.log#L931) `test_A0_donateBeforeFirstBond_cannotFreeMint()`
- [L932](../../ERRORS.log#L932) `test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork()`
- [L933](../../ERRORS.log#L933) `test_D15_1_previewEqualsExecute()`
- [L934](../../ERRORS.log#L934) `test_D15_8_nonDetfPayoutForbidden()`
- [L935](../../ERRORS.log#L935) `test_D15_redeem_paysDetf_only()`
- [L936](../../ERRORS.log#L936) `test_D25_fundedPrincipalAndRewardsPayOnlyStaking()`
- [L937](../../ERRORS.log#L937) `test_D25_standingReceiptsAlreadyFundedBeforeClaim()`
- [L938](../../ERRORS.log#L938) `test_DN14_closeAfterDonate_userBasketUnchanged()`
- [L939](../../ERRORS.log#L939) `test_DN16_lastClose_thenDonate_nextBondDoesNotCapture()`
- [L940](../../ERRORS.log#L940) `test_DN18_disabled_donateReverts_closeWorks()`
- [L941](../../ERRORS.log#L941) `test_DN6_twoBonders_navRisesTogether()`
- [L942](../../ERRORS.log#L942) `test_T7_10_laterBond_joinUnbalanced_unboostedG()`
- [L943](../../ERRORS.log#L943) `test_claimRewards_whileLocked()`
- [L944](../../ERRORS.log#L944) `test_compound_raises_protocolLp()`
- [L945](../../ERRORS.log#L945) `test_postMaturity_claimPaysFundedStaking()`
- [L946](../../ERRORS.log#L946) `test_preMaturity_principalVestsLinearly()`

**UniswapV4Detf_Cp_Univ3Se_Policy** — [UniswapV4Detf_Cp_Univ3Se_Policy.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Cp_Univ3Se_Policy.t.sol) (8 failures).

- [L949](../../ERRORS.log#L949) `test_D15_1_previewEqualsExecute()`
- [L950](../../ERRORS.log#L950) `test_D15_8_nonDetfPayoutForbidden()`
- [L951](../../ERRORS.log#L951) `test_D15_redeem_paysDetf_only()`
- [L952](../../ERRORS.log#L952) `test_D22_claimUngated()`
- [L953](../../ERRORS.log#L953) `test_FC_creatorZeroFundsBothRightsToOriginalFeeOwner()`
- [L954](../../ERRORS.log#L954) `test_FC_explicitCreatorReceivesSeparateFundedIncome()`
- [L955](../../ERRORS.log#L955) `test_FC_fullExitAndFeeToRotationPreserveStandingIncome()`
- [L956](../../ERRORS.log#L956) `test_FC_fundedTwoWavesMatchIndependentFloors()`

**UniswapV4Detf_Cp_Univ3Se_ProductLaw** — [UniswapV4Detf_Cp_Univ3Se_ProductLaw.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Cp_Univ3Se_ProductLaw.t.sol) (16 failures).

- [L959](../../ERRORS.log#L959) `test_A0_donateBeforeFirstBond_cannotFreeMint()`
- [L960](../../ERRORS.log#L960) `test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork()`
- [L961](../../ERRORS.log#L961) `test_D15_1_previewEqualsExecute()`
- [L962](../../ERRORS.log#L962) `test_D15_8_nonDetfPayoutForbidden()`
- [L963](../../ERRORS.log#L963) `test_D15_redeem_paysDetf_only()`
- [L964](../../ERRORS.log#L964) `test_D25_fundedPrincipalAndRewardsPayOnlyStaking()`
- [L965](../../ERRORS.log#L965) `test_D25_standingReceiptsAlreadyFundedBeforeClaim()`
- [L966](../../ERRORS.log#L966) `test_DN14_closeAfterDonate_userBasketUnchanged()`
- [L967](../../ERRORS.log#L967) `test_DN16_lastClose_thenDonate_nextBondDoesNotCapture()`
- [L968](../../ERRORS.log#L968) `test_DN18_disabled_donateReverts_closeWorks()`
- [L969](../../ERRORS.log#L969) `test_DN6_twoBonders_navRisesTogether()`
- [L970](../../ERRORS.log#L970) `test_T7_10_laterBond_joinUnbalanced_unboostedG()`
- [L971](../../ERRORS.log#L971) `test_claimRewards_whileLocked()`
- [L972](../../ERRORS.log#L972) `test_compound_raises_protocolLp()`
- [L973](../../ERRORS.log#L973) `test_postMaturity_claimPaysFundedStaking()`
- [L974](../../ERRORS.log#L974) `test_preMaturity_principalVestsLinearly()`

**UniswapV4Detf_Cp_Univ4Se_Policy** — [UniswapV4Detf_Cp_Univ4Se_Policy.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Cp_Univ4Se_Policy.t.sol) (8 failures).

- [L977](../../ERRORS.log#L977) `test_D15_1_previewEqualsExecute()`
- [L978](../../ERRORS.log#L978) `test_D15_8_nonDetfPayoutForbidden()`
- [L979](../../ERRORS.log#L979) `test_D15_redeem_paysDetf_only()`
- [L980](../../ERRORS.log#L980) `test_D22_claimUngated()`
- [L981](../../ERRORS.log#L981) `test_FC_creatorZeroFundsBothRightsToOriginalFeeOwner()`
- [L982](../../ERRORS.log#L982) `test_FC_explicitCreatorReceivesSeparateFundedIncome()`
- [L983](../../ERRORS.log#L983) `test_FC_fullExitAndFeeToRotationPreserveStandingIncome()`
- [L984](../../ERRORS.log#L984) `test_FC_fundedTwoWavesMatchIndependentFloors()`

**UniswapV4Detf_Cp_Univ4Se_ProductLaw** — [UniswapV4Detf_Cp_Univ4Se_ProductLaw.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Cp_Univ4Se_ProductLaw.t.sol) (16 failures).

- [L987](../../ERRORS.log#L987) `test_A0_donateBeforeFirstBond_cannotFreeMint()`
- [L988](../../ERRORS.log#L988) `test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork()`
- [L989](../../ERRORS.log#L989) `test_D15_1_previewEqualsExecute()`
- [L990](../../ERRORS.log#L990) `test_D15_8_nonDetfPayoutForbidden()`
- [L991](../../ERRORS.log#L991) `test_D15_redeem_paysDetf_only()`
- [L992](../../ERRORS.log#L992) `test_D25_fundedPrincipalAndRewardsPayOnlyStaking()`
- [L993](../../ERRORS.log#L993) `test_D25_standingReceiptsAlreadyFundedBeforeClaim()`
- [L994](../../ERRORS.log#L994) `test_DN14_closeAfterDonate_userBasketUnchanged()`
- [L995](../../ERRORS.log#L995) `test_DN16_lastClose_thenDonate_nextBondDoesNotCapture()`
- [L996](../../ERRORS.log#L996) `test_DN18_disabled_donateReverts_closeWorks()`
- [L997](../../ERRORS.log#L997) `test_DN6_twoBonders_navRisesTogether()`
- [L998](../../ERRORS.log#L998) `test_T7_10_laterBond_joinUnbalanced_unboostedG()`
- [L999](../../ERRORS.log#L999) `test_claimRewards_whileLocked()`
- [L1000](../../ERRORS.log#L1000) `test_compound_raises_protocolLp()`
- [L1001](../../ERRORS.log#L1001) `test_postMaturity_claimPaysFundedStaking()`
- [L1002](../../ERRORS.log#L1002) `test_preMaturity_principalVestsLinearly()`

**UniswapV4Detf_Orbital_MorphoBlueSe_Policy** — [UniswapV4Detf_Orbital_MorphoBlueSe_Policy.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Orbital_MorphoBlueSe_Policy.t.sol) (4 failures).

- [L1005](../../ERRORS.log#L1005) `test_D22_claimUngated()`
- [L1006](../../ERRORS.log#L1006) `test_D31_1_policyMint_realizesThenGates()`
- [L1007](../../ERRORS.log#L1007) `test_policy_burn_allowed_when_synthetic_below_burnThreshold()`
- [L1008](../../ERRORS.log#L1008) `test_policy_mint_blocked_in_deadband_then_allowed_after_push()`

**UniswapV4Detf_Orbital_MorphoBlueSe_ProductLaw** — [UniswapV4Detf_Orbital_MorphoBlueSe_ProductLaw.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Orbital_MorphoBlueSe_ProductLaw.t.sol) (17 failures).

- [L1011](../../ERRORS.log#L1011) `test_DN10_previewEqualsExecute()`
- [L1012](../../ERRORS.log#L1012) `test_DN11_ownerOnlyLiquidity_donateStillWorks()`
- [L1013](../../ERRORS.log#L1013) `test_DN12_donate_doesNotRealizeExpansion()`
- [L1014](../../ERRORS.log#L1014) `test_DN13_burn_afterDonate_usesDonatedLp()`
- [L1015](../../ERRORS.log#L1015) `test_DN14_closeAfterDonate_userBasketUnchanged()`
- [L1016](../../ERRORS.log#L1016) `test_DN16_lastClose_thenDonate_nextBondDoesNotCapture()`
- [L1017](../../ERRORS.log#L1017) `test_DN17_d2_ids12_effectiveShares()`
- [L1018](../../ERRORS.log#L1018) `test_DN18_disabled_donateReverts_closeWorks()`
- [L1019](../../ERRORS.log#L1019) `test_DN19_permit2_allowance()`
- [L1020](../../ERRORS.log#L1020) `test_DN1_donate_pair_Ogt0_unassignedLp()`
- [L1021](../../ERRORS.log#L1021) `test_DN20_permit2_signature()`
- [L1022](../../ERRORS.log#L1022) `test_DN21_d2_afterDonate()`
- [L1023](../../ERRORS.log#L1023) `test_DN22_donate_whilePoolManagerUnlocked()`
- [L1024](../../ERRORS.log#L1024) `test_DN2_donate_vaultShare()`
- [L1025](../../ERRORS.log#L1025) `test_DN4_donate_detf_selfLeg_noMint()`
- [L1026](../../ERRORS.log#L1026) `test_DN6_twoBonders_navRisesTogether()`
- [L1027](../../ERRORS.log#L1027) `test_DN7_detf_donate_forwardsToNft()`

**UniswapV4Detf_Orbital_MorphoMix_Policy** — [UniswapV4Detf_Orbital_MorphoMix_Policy.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Orbital_MorphoMix_Policy.t.sol) (3 failures).

- [L1030](../../ERRORS.log#L1030) `test_D22_claimUngated()`
- [L1031](../../ERRORS.log#L1031) `test_FC_fundedTwoWavesMatchIndependentFloors()`
- [L1032](../../ERRORS.log#L1032) `test_policy_burn_allowed_when_synthetic_below_burnThreshold()`

**UniswapV4Detf_Orbital_MorphoMix_ProductLaw** — [UniswapV4Detf_Orbital_MorphoMix_ProductLaw.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Orbital_MorphoMix_ProductLaw.t.sol) (3 failures).

- [L1035](../../ERRORS.log#L1035) `test_DN16_lastClose_thenDonate_nextBondDoesNotCapture()`
- [L1036](../../ERRORS.log#L1036) `test_DN18_disabled_donateReverts_closeWorks()`
- [L1037](../../ERRORS.log#L1037) `test_DN4_donate_detf_selfLeg_noMint()`

**UniswapV4Detf_Orbital_PonsMix_ProductLaw** — [UniswapV4Detf_Orbital_PonsMix_ProductLaw.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Orbital_PonsMix_ProductLaw.t.sol) (1 failure).

- [L1040](../../ERRORS.log#L1040) `test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork()`

**UniswapV4Detf_Orbital_PonsV1Se_ProductLaw** — [UniswapV4Detf_Orbital_PonsV1Se_ProductLaw.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Orbital_PonsV1Se_ProductLaw.t.sol) (1 failure).

- [L1043](../../ERRORS.log#L1043) `test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork()`

**UniswapV4Detf_Orbital_PonsV2Se_ProductLaw** — [UniswapV4Detf_Orbital_PonsV2Se_ProductLaw.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Orbital_PonsV2Se_ProductLaw.t.sol) (1 failure).

- [L1046](../../ERRORS.log#L1046) `test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork()`

**UniswapV4Detf_Orbital_Univ3Se_Policy** — [UniswapV4Detf_Orbital_Univ3Se_Policy.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Orbital_Univ3Se_Policy.t.sol) (8 failures).

- [L1049](../../ERRORS.log#L1049) `test_D15_1_previewEqualsExecute()`
- [L1050](../../ERRORS.log#L1050) `test_D15_8_nonDetfPayoutForbidden()`
- [L1051](../../ERRORS.log#L1051) `test_D15_redeem_paysDetf_only()`
- [L1052](../../ERRORS.log#L1052) `test_D22_claimUngated()`
- [L1053](../../ERRORS.log#L1053) `test_FC_creatorZeroFundsBothRightsToOriginalFeeOwner()`
- [L1054](../../ERRORS.log#L1054) `test_FC_explicitCreatorReceivesSeparateFundedIncome()`
- [L1055](../../ERRORS.log#L1055) `test_FC_fullExitAndFeeToRotationPreserveStandingIncome()`
- [L1056](../../ERRORS.log#L1056) `test_FC_fundedTwoWavesMatchIndependentFloors()`

**UniswapV4Detf_Orbital_Univ3Se_ProductLaw** — [UniswapV4Detf_Orbital_Univ3Se_ProductLaw.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Orbital_Univ3Se_ProductLaw.t.sol) (15 failures).

- [L1059](../../ERRORS.log#L1059) `test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork()`
- [L1060](../../ERRORS.log#L1060) `test_D15_1_previewEqualsExecute()`
- [L1061](../../ERRORS.log#L1061) `test_D15_8_nonDetfPayoutForbidden()`
- [L1062](../../ERRORS.log#L1062) `test_D15_redeem_paysDetf_only()`
- [L1063](../../ERRORS.log#L1063) `test_D25_fundedPrincipalAndRewardsPayOnlyStaking()`
- [L1064](../../ERRORS.log#L1064) `test_D25_standingReceiptsAlreadyFundedBeforeClaim()`
- [L1065](../../ERRORS.log#L1065) `test_DN14_closeAfterDonate_userBasketUnchanged()`
- [L1066](../../ERRORS.log#L1066) `test_DN16_lastClose_thenDonate_nextBondDoesNotCapture()`
- [L1067](../../ERRORS.log#L1067) `test_DN18_disabled_donateReverts_closeWorks()`
- [L1068](../../ERRORS.log#L1068) `test_DN6_twoBonders_navRisesTogether()`
- [L1069](../../ERRORS.log#L1069) `test_T7_10_laterBond_joinUnbalanced_unboostedG()`
- [L1070](../../ERRORS.log#L1070) `test_claimRewards_whileLocked()`
- [L1071](../../ERRORS.log#L1071) `test_compound_raises_protocolLp()`
- [L1072](../../ERRORS.log#L1072) `test_postMaturity_claimPaysFundedStaking()`
- [L1073](../../ERRORS.log#L1073) `test_preMaturity_principalVestsLinearly()`

**UniswapV4Detf_Orbital_Univ4Se_Policy** — [UniswapV4Detf_Orbital_Univ4Se_Policy.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Orbital_Univ4Se_Policy.t.sol) (8 failures).

- [L1076](../../ERRORS.log#L1076) `test_D15_1_previewEqualsExecute()`
- [L1077](../../ERRORS.log#L1077) `test_D15_8_nonDetfPayoutForbidden()`
- [L1078](../../ERRORS.log#L1078) `test_D15_redeem_paysDetf_only()`
- [L1079](../../ERRORS.log#L1079) `test_D22_claimUngated()`
- [L1080](../../ERRORS.log#L1080) `test_FC_creatorZeroFundsBothRightsToOriginalFeeOwner()`
- [L1081](../../ERRORS.log#L1081) `test_FC_explicitCreatorReceivesSeparateFundedIncome()`
- [L1082](../../ERRORS.log#L1082) `test_FC_fullExitAndFeeToRotationPreserveStandingIncome()`
- [L1083](../../ERRORS.log#L1083) `test_FC_fundedTwoWavesMatchIndependentFloors()`

**UniswapV4Detf_Orbital_Univ4Se_ProductLaw** — [UniswapV4Detf_Orbital_Univ4Se_ProductLaw.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/UniswapV4Detf_Orbital_Univ4Se_ProductLaw.t.sol) (15 failures).

- [L1086](../../ERRORS.log#L1086) `test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork()`
- [L1087](../../ERRORS.log#L1087) `test_D15_1_previewEqualsExecute()`
- [L1088](../../ERRORS.log#L1088) `test_D15_8_nonDetfPayoutForbidden()`
- [L1089](../../ERRORS.log#L1089) `test_D15_redeem_paysDetf_only()`
- [L1090](../../ERRORS.log#L1090) `test_D25_fundedPrincipalAndRewardsPayOnlyStaking()`
- [L1091](../../ERRORS.log#L1091) `test_D25_standingReceiptsAlreadyFundedBeforeClaim()`
- [L1092](../../ERRORS.log#L1092) `test_DN14_closeAfterDonate_userBasketUnchanged()`
- [L1093](../../ERRORS.log#L1093) `test_DN16_lastClose_thenDonate_nextBondDoesNotCapture()`
- [L1094](../../ERRORS.log#L1094) `test_DN18_disabled_donateReverts_closeWorks()`
- [L1095](../../ERRORS.log#L1095) `test_DN6_twoBonders_navRisesTogether()`
- [L1096](../../ERRORS.log#L1096) `test_T7_10_laterBond_joinUnbalanced_unboostedG()`
- [L1097](../../ERRORS.log#L1097) `test_claimRewards_whileLocked()`
- [L1098](../../ERRORS.log#L1098) `test_compound_raises_protocolLp()`
- [L1099](../../ERRORS.log#L1099) `test_postMaturity_claimPaysFundedStaking()`
- [L1100](../../ERRORS.log#L1100) `test_preMaturity_principalVestsLinearly()`

**UniswapV4Detf_Cp_MorphoBlueSe_Policy_U6** — [UniswapV4Detf_Cp_MorphoBlueSe_Policy_U6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Cp_MorphoBlueSe_Policy_U6.t.sol) (4 failures).

- [L1103](../../ERRORS.log#L1103) `test_FC_creatorZeroFundsBothRightsToOriginalFeeOwner()`
- [L1104](../../ERRORS.log#L1104) `test_FC_explicitCreatorReceivesSeparateFundedIncome()`
- [L1105](../../ERRORS.log#L1105) `test_FC_fullExitAndFeeToRotationPreserveStandingIncome()`
- [L1106](../../ERRORS.log#L1106) `test_FC_fundedTwoWavesMatchIndependentFloors()`

**UniswapV4Detf_Cp_MorphoBlueSe_ProductLaw_U6** — [UniswapV4Detf_Cp_MorphoBlueSe_ProductLaw_U6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Cp_MorphoBlueSe_ProductLaw_U6.t.sol) (9 failures).

- [L1109](../../ERRORS.log#L1109) `test_A0_donateBeforeFirstBond_cannotFreeMint()`
- [L1110](../../ERRORS.log#L1110) `test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork()`
- [L1111](../../ERRORS.log#L1111) `test_DN14_closeAfterDonate_userBasketUnchanged()`
- [L1112](../../ERRORS.log#L1112) `test_DN16_lastClose_thenDonate_nextBondDoesNotCapture()`
- [L1113](../../ERRORS.log#L1113) `test_DN6_twoBonders_navRisesTogether()`
- [L1114](../../ERRORS.log#L1114) `test_T7_10_laterBond_joinUnbalanced_unboostedG()`
- [L1115](../../ERRORS.log#L1115) `test_claimRewards_whileLocked()`
- [L1116](../../ERRORS.log#L1116) `test_postMaturity_claimPaysFundedStaking()`
- [L1117](../../ERRORS.log#L1117) `test_preMaturity_principalVestsLinearly()`

**UniswapV4Detf_Cp_MorphoBlueSe_ProductLaw_U9** — [UniswapV4Detf_Cp_MorphoBlueSe_ProductLaw_U9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Cp_MorphoBlueSe_ProductLaw_U9.t.sol) (1 failure).

- [L1120](../../ERRORS.log#L1120) `test_A0_donateBeforeFirstBond_cannotFreeMint()`

**UniswapV4Detf_Cp_PonsV1Se_Policy_P18_R6** — [UniswapV4Detf_Cp_PonsV1Se_Policy_P18_R6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Cp_PonsV1Se_Policy_P18_R6.t.sol) (8 failures).

- [L1123](../../ERRORS.log#L1123) `test_D15_1_previewEqualsExecute()`
- [L1124](../../ERRORS.log#L1124) `test_D15_8_nonDetfPayoutForbidden()`
- [L1125](../../ERRORS.log#L1125) `test_D15_redeem_paysDetf_only()`
- [L1126](../../ERRORS.log#L1126) `test_D22_claimUngated()`
- [L1127](../../ERRORS.log#L1127) `test_FC_creatorZeroFundsBothRightsToOriginalFeeOwner()`
- [L1128](../../ERRORS.log#L1128) `test_FC_explicitCreatorReceivesSeparateFundedIncome()`
- [L1129](../../ERRORS.log#L1129) `test_FC_fullExitAndFeeToRotationPreserveStandingIncome()`
- [L1130](../../ERRORS.log#L1130) `test_FC_fundedTwoWavesMatchIndependentFloors()`

**UniswapV4Detf_Cp_PonsV1Se_Policy_P18_R9** — [UniswapV4Detf_Cp_PonsV1Se_Policy_P18_R9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Cp_PonsV1Se_Policy_P18_R9.t.sol) (8 failures).

- [L1133](../../ERRORS.log#L1133) `test_D15_1_previewEqualsExecute()`
- [L1134](../../ERRORS.log#L1134) `test_D15_8_nonDetfPayoutForbidden()`
- [L1135](../../ERRORS.log#L1135) `test_D15_redeem_paysDetf_only()`
- [L1136](../../ERRORS.log#L1136) `test_D22_claimUngated()`
- [L1137](../../ERRORS.log#L1137) `test_FC_creatorZeroFundsBothRightsToOriginalFeeOwner()`
- [L1138](../../ERRORS.log#L1138) `test_FC_explicitCreatorReceivesSeparateFundedIncome()`
- [L1139](../../ERRORS.log#L1139) `test_FC_fullExitAndFeeToRotationPreserveStandingIncome()`
- [L1140](../../ERRORS.log#L1140) `test_FC_fundedTwoWavesMatchIndependentFloors()`

**UniswapV4Detf_Cp_PonsV1Se_ProductLaw_P18_R6** — [UniswapV4Detf_Cp_PonsV1Se_ProductLaw_P18_R6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Cp_PonsV1Se_ProductLaw_P18_R6.t.sol) (15 failures).

- [L1143](../../ERRORS.log#L1143) `test_A0_donateBeforeFirstBond_cannotFreeMint()`
- [L1144](../../ERRORS.log#L1144) `test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork()`
- [L1145](../../ERRORS.log#L1145) `test_D15_1_previewEqualsExecute()`
- [L1146](../../ERRORS.log#L1146) `test_D15_8_nonDetfPayoutForbidden()`
- [L1147](../../ERRORS.log#L1147) `test_D15_redeem_paysDetf_only()`
- [L1148](../../ERRORS.log#L1148) `test_D25_fundedPrincipalAndRewardsPayOnlyStaking()`
- [L1149](../../ERRORS.log#L1149) `test_D25_standingReceiptsAlreadyFundedBeforeClaim()`
- [L1150](../../ERRORS.log#L1150) `test_DN14_closeAfterDonate_userBasketUnchanged()`
- [L1151](../../ERRORS.log#L1151) `test_DN16_lastClose_thenDonate_nextBondDoesNotCapture()`
- [L1152](../../ERRORS.log#L1152) `test_DN18_disabled_donateReverts_closeWorks()`
- [L1153](../../ERRORS.log#L1153) `test_DN6_twoBonders_navRisesTogether()`
- [L1154](../../ERRORS.log#L1154) `test_T7_10_laterBond_joinUnbalanced_unboostedG()`
- [L1155](../../ERRORS.log#L1155) `test_claimRewards_whileLocked()`
- [L1156](../../ERRORS.log#L1156) `test_postMaturity_claimPaysFundedStaking()`
- [L1157](../../ERRORS.log#L1157) `test_preMaturity_principalVestsLinearly()`

**UniswapV4Detf_Cp_PonsV1Se_ProductLaw_P18_R9** — [UniswapV4Detf_Cp_PonsV1Se_ProductLaw_P18_R9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Cp_PonsV1Se_ProductLaw_P18_R9.t.sol) (15 failures).

- [L1160](../../ERRORS.log#L1160) `test_A0_donateBeforeFirstBond_cannotFreeMint()`
- [L1161](../../ERRORS.log#L1161) `test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork()`
- [L1162](../../ERRORS.log#L1162) `test_D15_1_previewEqualsExecute()`
- [L1163](../../ERRORS.log#L1163) `test_D15_8_nonDetfPayoutForbidden()`
- [L1164](../../ERRORS.log#L1164) `test_D15_redeem_paysDetf_only()`
- [L1165](../../ERRORS.log#L1165) `test_D25_fundedPrincipalAndRewardsPayOnlyStaking()`
- [L1166](../../ERRORS.log#L1166) `test_D25_standingReceiptsAlreadyFundedBeforeClaim()`
- [L1167](../../ERRORS.log#L1167) `test_DN14_closeAfterDonate_userBasketUnchanged()`
- [L1168](../../ERRORS.log#L1168) `test_DN16_lastClose_thenDonate_nextBondDoesNotCapture()`
- [L1169](../../ERRORS.log#L1169) `test_DN18_disabled_donateReverts_closeWorks()`
- [L1170](../../ERRORS.log#L1170) `test_DN6_twoBonders_navRisesTogether()`
- [L1171](../../ERRORS.log#L1171) `test_T7_10_laterBond_joinUnbalanced_unboostedG()`
- [L1172](../../ERRORS.log#L1172) `test_claimRewards_whileLocked()`
- [L1173](../../ERRORS.log#L1173) `test_postMaturity_claimPaysFundedStaking()`
- [L1174](../../ERRORS.log#L1174) `test_preMaturity_principalVestsLinearly()`

**UniswapV4Detf_Cp_Univ3Se_Policy_H6** — [UniswapV4Detf_Cp_Univ3Se_Policy_H6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Cp_Univ3Se_Policy_H6.t.sol) (8 failures).

- [L1177](../../ERRORS.log#L1177) `test_D15_1_previewEqualsExecute()`
- [L1178](../../ERRORS.log#L1178) `test_D15_8_nonDetfPayoutForbidden()`
- [L1179](../../ERRORS.log#L1179) `test_D15_redeem_paysDetf_only()`
- [L1180](../../ERRORS.log#L1180) `test_D22_claimUngated()`
- [L1181](../../ERRORS.log#L1181) `test_FC_creatorZeroFundsBothRightsToOriginalFeeOwner()`
- [L1182](../../ERRORS.log#L1182) `test_FC_explicitCreatorReceivesSeparateFundedIncome()`
- [L1183](../../ERRORS.log#L1183) `test_FC_fullExitAndFeeToRotationPreserveStandingIncome()`
- [L1184](../../ERRORS.log#L1184) `test_FC_fundedTwoWavesMatchIndependentFloors()`

**UniswapV4Detf_Cp_Univ3Se_Policy_H9** — [UniswapV4Detf_Cp_Univ3Se_Policy_H9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Cp_Univ3Se_Policy_H9.t.sol) (8 failures).

- [L1187](../../ERRORS.log#L1187) `test_D15_1_previewEqualsExecute()`
- [L1188](../../ERRORS.log#L1188) `test_D15_8_nonDetfPayoutForbidden()`
- [L1189](../../ERRORS.log#L1189) `test_D15_redeem_paysDetf_only()`
- [L1190](../../ERRORS.log#L1190) `test_D22_claimUngated()`
- [L1191](../../ERRORS.log#L1191) `test_FC_creatorZeroFundsBothRightsToOriginalFeeOwner()`
- [L1192](../../ERRORS.log#L1192) `test_FC_explicitCreatorReceivesSeparateFundedIncome()`
- [L1193](../../ERRORS.log#L1193) `test_FC_fullExitAndFeeToRotationPreserveStandingIncome()`
- [L1194](../../ERRORS.log#L1194) `test_FC_fundedTwoWavesMatchIndependentFloors()`

**UniswapV4Detf_Cp_Univ3Se_Policy_P18_R6** — [UniswapV4Detf_Cp_Univ3Se_Policy_P18_R6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Cp_Univ3Se_Policy_P18_R6.t.sol) (8 failures).

- [L1197](../../ERRORS.log#L1197) `test_D15_1_previewEqualsExecute()`
- [L1198](../../ERRORS.log#L1198) `test_D15_8_nonDetfPayoutForbidden()`
- [L1199](../../ERRORS.log#L1199) `test_D15_redeem_paysDetf_only()`
- [L1200](../../ERRORS.log#L1200) `test_D22_claimUngated()`
- [L1201](../../ERRORS.log#L1201) `test_FC_creatorZeroFundsBothRightsToOriginalFeeOwner()`
- [L1202](../../ERRORS.log#L1202) `test_FC_explicitCreatorReceivesSeparateFundedIncome()`
- [L1203](../../ERRORS.log#L1203) `test_FC_fullExitAndFeeToRotationPreserveStandingIncome()`
- [L1204](../../ERRORS.log#L1204) `test_FC_fundedTwoWavesMatchIndependentFloors()`

**UniswapV4Detf_Cp_Univ3Se_Policy_P18_R9** — [UniswapV4Detf_Cp_Univ3Se_Policy_P18_R9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Cp_Univ3Se_Policy_P18_R9.t.sol) (8 failures).

- [L1207](../../ERRORS.log#L1207) `test_D15_1_previewEqualsExecute()`
- [L1208](../../ERRORS.log#L1208) `test_D15_8_nonDetfPayoutForbidden()`
- [L1209](../../ERRORS.log#L1209) `test_D15_redeem_paysDetf_only()`
- [L1210](../../ERRORS.log#L1210) `test_D22_claimUngated()`
- [L1211](../../ERRORS.log#L1211) `test_FC_creatorZeroFundsBothRightsToOriginalFeeOwner()`
- [L1212](../../ERRORS.log#L1212) `test_FC_explicitCreatorReceivesSeparateFundedIncome()`
- [L1213](../../ERRORS.log#L1213) `test_FC_fullExitAndFeeToRotationPreserveStandingIncome()`
- [L1214](../../ERRORS.log#L1214) `test_FC_fundedTwoWavesMatchIndependentFloors()`

**UniswapV4Detf_Cp_Univ3Se_Policy_P9_R18** — [UniswapV4Detf_Cp_Univ3Se_Policy_P9_R18.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Cp_Univ3Se_Policy_P9_R18.t.sol) (8 failures).

- [L1217](../../ERRORS.log#L1217) `test_D15_1_previewEqualsExecute()`
- [L1218](../../ERRORS.log#L1218) `test_D15_8_nonDetfPayoutForbidden()`
- [L1219](../../ERRORS.log#L1219) `test_D15_redeem_paysDetf_only()`
- [L1220](../../ERRORS.log#L1220) `test_D22_claimUngated()`
- [L1221](../../ERRORS.log#L1221) `test_FC_creatorZeroFundsBothRightsToOriginalFeeOwner()`
- [L1222](../../ERRORS.log#L1222) `test_FC_explicitCreatorReceivesSeparateFundedIncome()`
- [L1223](../../ERRORS.log#L1223) `test_FC_fullExitAndFeeToRotationPreserveStandingIncome()`
- [L1224](../../ERRORS.log#L1224) `test_FC_fundedTwoWavesMatchIndependentFloors()`

**UniswapV4Detf_Cp_Univ3Se_Policy_P9_R6** — [UniswapV4Detf_Cp_Univ3Se_Policy_P9_R6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Cp_Univ3Se_Policy_P9_R6.t.sol) (8 failures).

- [L1227](../../ERRORS.log#L1227) `test_D15_1_previewEqualsExecute()`
- [L1228](../../ERRORS.log#L1228) `test_D15_8_nonDetfPayoutForbidden()`
- [L1229](../../ERRORS.log#L1229) `test_D15_redeem_paysDetf_only()`
- [L1230](../../ERRORS.log#L1230) `test_D22_claimUngated()`
- [L1231](../../ERRORS.log#L1231) `test_FC_creatorZeroFundsBothRightsToOriginalFeeOwner()`
- [L1232](../../ERRORS.log#L1232) `test_FC_explicitCreatorReceivesSeparateFundedIncome()`
- [L1233](../../ERRORS.log#L1233) `test_FC_fullExitAndFeeToRotationPreserveStandingIncome()`
- [L1234](../../ERRORS.log#L1234) `test_FC_fundedTwoWavesMatchIndependentFloors()`

**UniswapV4Detf_Cp_Univ3Se_ProductLaw_H6** — [UniswapV4Detf_Cp_Univ3Se_ProductLaw_H6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Cp_Univ3Se_ProductLaw_H6.t.sol) (15 failures).

- [L1237](../../ERRORS.log#L1237) `test_A0_donateBeforeFirstBond_cannotFreeMint()`
- [L1238](../../ERRORS.log#L1238) `test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork()`
- [L1239](../../ERRORS.log#L1239) `test_D15_1_previewEqualsExecute()`
- [L1240](../../ERRORS.log#L1240) `test_D15_8_nonDetfPayoutForbidden()`
- [L1241](../../ERRORS.log#L1241) `test_D15_redeem_paysDetf_only()`
- [L1242](../../ERRORS.log#L1242) `test_D25_fundedPrincipalAndRewardsPayOnlyStaking()`
- [L1243](../../ERRORS.log#L1243) `test_D25_standingReceiptsAlreadyFundedBeforeClaim()`
- [L1244](../../ERRORS.log#L1244) `test_DN14_closeAfterDonate_userBasketUnchanged()`
- [L1245](../../ERRORS.log#L1245) `test_DN16_lastClose_thenDonate_nextBondDoesNotCapture()`
- [L1246](../../ERRORS.log#L1246) `test_DN18_disabled_donateReverts_closeWorks()`
- [L1247](../../ERRORS.log#L1247) `test_DN6_twoBonders_navRisesTogether()`
- [L1248](../../ERRORS.log#L1248) `test_T7_10_laterBond_joinUnbalanced_unboostedG()`
- [L1249](../../ERRORS.log#L1249) `test_claimRewards_whileLocked()`
- [L1250](../../ERRORS.log#L1250) `test_postMaturity_claimPaysFundedStaking()`
- [L1251](../../ERRORS.log#L1251) `test_preMaturity_principalVestsLinearly()`

**UniswapV4Detf_Cp_Univ3Se_ProductLaw_H9** — [UniswapV4Detf_Cp_Univ3Se_ProductLaw_H9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Cp_Univ3Se_ProductLaw_H9.t.sol) (15 failures).

- [L1254](../../ERRORS.log#L1254) `test_A0_donateBeforeFirstBond_cannotFreeMint()`
- [L1255](../../ERRORS.log#L1255) `test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork()`
- [L1256](../../ERRORS.log#L1256) `test_D15_1_previewEqualsExecute()`
- [L1257](../../ERRORS.log#L1257) `test_D15_8_nonDetfPayoutForbidden()`
- [L1258](../../ERRORS.log#L1258) `test_D15_redeem_paysDetf_only()`
- [L1259](../../ERRORS.log#L1259) `test_D25_fundedPrincipalAndRewardsPayOnlyStaking()`
- [L1260](../../ERRORS.log#L1260) `test_D25_standingReceiptsAlreadyFundedBeforeClaim()`
- [L1261](../../ERRORS.log#L1261) `test_DN14_closeAfterDonate_userBasketUnchanged()`
- [L1262](../../ERRORS.log#L1262) `test_DN16_lastClose_thenDonate_nextBondDoesNotCapture()`
- [L1263](../../ERRORS.log#L1263) `test_DN18_disabled_donateReverts_closeWorks()`
- [L1264](../../ERRORS.log#L1264) `test_DN6_twoBonders_navRisesTogether()`
- [L1265](../../ERRORS.log#L1265) `test_T7_10_laterBond_joinUnbalanced_unboostedG()`
- [L1266](../../ERRORS.log#L1266) `test_claimRewards_whileLocked()`
- [L1267](../../ERRORS.log#L1267) `test_postMaturity_claimPaysFundedStaking()`
- [L1268](../../ERRORS.log#L1268) `test_preMaturity_principalVestsLinearly()`

**UniswapV4Detf_Cp_Univ3Se_ProductLaw_P18_R6** — [UniswapV4Detf_Cp_Univ3Se_ProductLaw_P18_R6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Cp_Univ3Se_ProductLaw_P18_R6.t.sol) (15 failures).

- [L1271](../../ERRORS.log#L1271) `test_A0_donateBeforeFirstBond_cannotFreeMint()`
- [L1272](../../ERRORS.log#L1272) `test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork()`
- [L1273](../../ERRORS.log#L1273) `test_D15_1_previewEqualsExecute()`
- [L1274](../../ERRORS.log#L1274) `test_D15_8_nonDetfPayoutForbidden()`
- [L1275](../../ERRORS.log#L1275) `test_D15_redeem_paysDetf_only()`
- [L1276](../../ERRORS.log#L1276) `test_D25_fundedPrincipalAndRewardsPayOnlyStaking()`
- [L1277](../../ERRORS.log#L1277) `test_D25_standingReceiptsAlreadyFundedBeforeClaim()`
- [L1278](../../ERRORS.log#L1278) `test_DN14_closeAfterDonate_userBasketUnchanged()`
- [L1279](../../ERRORS.log#L1279) `test_DN16_lastClose_thenDonate_nextBondDoesNotCapture()`
- [L1280](../../ERRORS.log#L1280) `test_DN18_disabled_donateReverts_closeWorks()`
- [L1281](../../ERRORS.log#L1281) `test_DN6_twoBonders_navRisesTogether()`
- [L1282](../../ERRORS.log#L1282) `test_T7_10_laterBond_joinUnbalanced_unboostedG()`
- [L1283](../../ERRORS.log#L1283) `test_claimRewards_whileLocked()`
- [L1284](../../ERRORS.log#L1284) `test_postMaturity_claimPaysFundedStaking()`
- [L1285](../../ERRORS.log#L1285) `test_preMaturity_principalVestsLinearly()`

**UniswapV4Detf_Cp_Univ3Se_ProductLaw_P18_R9** — [UniswapV4Detf_Cp_Univ3Se_ProductLaw_P18_R9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Cp_Univ3Se_ProductLaw_P18_R9.t.sol) (15 failures).

- [L1288](../../ERRORS.log#L1288) `test_A0_donateBeforeFirstBond_cannotFreeMint()`
- [L1289](../../ERRORS.log#L1289) `test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork()`
- [L1290](../../ERRORS.log#L1290) `test_D15_1_previewEqualsExecute()`
- [L1291](../../ERRORS.log#L1291) `test_D15_8_nonDetfPayoutForbidden()`
- [L1292](../../ERRORS.log#L1292) `test_D15_redeem_paysDetf_only()`
- [L1293](../../ERRORS.log#L1293) `test_D25_fundedPrincipalAndRewardsPayOnlyStaking()`
- [L1294](../../ERRORS.log#L1294) `test_D25_standingReceiptsAlreadyFundedBeforeClaim()`
- [L1295](../../ERRORS.log#L1295) `test_DN14_closeAfterDonate_userBasketUnchanged()`
- [L1296](../../ERRORS.log#L1296) `test_DN16_lastClose_thenDonate_nextBondDoesNotCapture()`
- [L1297](../../ERRORS.log#L1297) `test_DN18_disabled_donateReverts_closeWorks()`
- [L1298](../../ERRORS.log#L1298) `test_DN6_twoBonders_navRisesTogether()`
- [L1299](../../ERRORS.log#L1299) `test_T7_10_laterBond_joinUnbalanced_unboostedG()`
- [L1300](../../ERRORS.log#L1300) `test_claimRewards_whileLocked()`
- [L1301](../../ERRORS.log#L1301) `test_postMaturity_claimPaysFundedStaking()`
- [L1302](../../ERRORS.log#L1302) `test_preMaturity_principalVestsLinearly()`

**UniswapV4Detf_Cp_Univ3Se_ProductLaw_P6_R18** — [UniswapV4Detf_Cp_Univ3Se_ProductLaw_P6_R18.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Cp_Univ3Se_ProductLaw_P6_R18.t.sol) (2 failures).

- [L1305](../../ERRORS.log#L1305) `test_A0_donateBeforeFirstBond_cannotFreeMint()`
- [L1306](../../ERRORS.log#L1306) `test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork()`

**UniswapV4Detf_Cp_Univ3Se_ProductLaw_P6_R9** — [UniswapV4Detf_Cp_Univ3Se_ProductLaw_P6_R9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Cp_Univ3Se_ProductLaw_P6_R9.t.sol) (2 failures).

- [L1310](../../ERRORS.log#L1310) `test_A0_donateBeforeFirstBond_cannotFreeMint()`
- [L1311](../../ERRORS.log#L1311) `test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork()`

**UniswapV4Detf_Cp_Univ3Se_ProductLaw_P9_R18** — [UniswapV4Detf_Cp_Univ3Se_ProductLaw_P9_R18.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Cp_Univ3Se_ProductLaw_P9_R18.t.sol) (15 failures).

- [L1315](../../ERRORS.log#L1315) `test_A0_donateBeforeFirstBond_cannotFreeMint()`
- [L1316](../../ERRORS.log#L1316) `test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork()`
- [L1317](../../ERRORS.log#L1317) `test_D15_1_previewEqualsExecute()`
- [L1318](../../ERRORS.log#L1318) `test_D15_8_nonDetfPayoutForbidden()`
- [L1319](../../ERRORS.log#L1319) `test_D15_redeem_paysDetf_only()`
- [L1320](../../ERRORS.log#L1320) `test_D25_fundedPrincipalAndRewardsPayOnlyStaking()`
- [L1321](../../ERRORS.log#L1321) `test_D25_standingReceiptsAlreadyFundedBeforeClaim()`
- [L1322](../../ERRORS.log#L1322) `test_DN14_closeAfterDonate_userBasketUnchanged()`
- [L1323](../../ERRORS.log#L1323) `test_DN16_lastClose_thenDonate_nextBondDoesNotCapture()`
- [L1324](../../ERRORS.log#L1324) `test_DN18_disabled_donateReverts_closeWorks()`
- [L1325](../../ERRORS.log#L1325) `test_DN6_twoBonders_navRisesTogether()`
- [L1326](../../ERRORS.log#L1326) `test_T7_10_laterBond_joinUnbalanced_unboostedG()`
- [L1327](../../ERRORS.log#L1327) `test_claimRewards_whileLocked()`
- [L1328](../../ERRORS.log#L1328) `test_postMaturity_claimPaysFundedStaking()`
- [L1329](../../ERRORS.log#L1329) `test_preMaturity_principalVestsLinearly()`

**UniswapV4Detf_Cp_Univ3Se_ProductLaw_P9_R6** — [UniswapV4Detf_Cp_Univ3Se_ProductLaw_P9_R6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Cp_Univ3Se_ProductLaw_P9_R6.t.sol) (15 failures).

- [L1332](../../ERRORS.log#L1332) `test_A0_donateBeforeFirstBond_cannotFreeMint()`
- [L1333](../../ERRORS.log#L1333) `test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork()`
- [L1334](../../ERRORS.log#L1334) `test_D15_1_previewEqualsExecute()`
- [L1335](../../ERRORS.log#L1335) `test_D15_8_nonDetfPayoutForbidden()`
- [L1336](../../ERRORS.log#L1336) `test_D15_redeem_paysDetf_only()`
- [L1337](../../ERRORS.log#L1337) `test_D25_fundedPrincipalAndRewardsPayOnlyStaking()`
- [L1338](../../ERRORS.log#L1338) `test_D25_standingReceiptsAlreadyFundedBeforeClaim()`
- [L1339](../../ERRORS.log#L1339) `test_DN14_closeAfterDonate_userBasketUnchanged()`
- [L1340](../../ERRORS.log#L1340) `test_DN16_lastClose_thenDonate_nextBondDoesNotCapture()`
- [L1341](../../ERRORS.log#L1341) `test_DN18_disabled_donateReverts_closeWorks()`
- [L1342](../../ERRORS.log#L1342) `test_DN6_twoBonders_navRisesTogether()`
- [L1343](../../ERRORS.log#L1343) `test_T7_10_laterBond_joinUnbalanced_unboostedG()`
- [L1344](../../ERRORS.log#L1344) `test_claimRewards_whileLocked()`
- [L1345](../../ERRORS.log#L1345) `test_postMaturity_claimPaysFundedStaking()`
- [L1346](../../ERRORS.log#L1346) `test_preMaturity_principalVestsLinearly()`

**UniswapV4Detf_Cp_Univ4Se_Policy_P18_R9** — [UniswapV4Detf_Cp_Univ4Se_Policy_P18_R9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Cp_Univ4Se_Policy_P18_R9.t.sol) (1 failure).

- [L1349](../../ERRORS.log#L1349) `test_D22_claimUngated()`

**UniswapV4Detf_Cp_Univ4Se_Policy_P9_R18** — [UniswapV4Detf_Cp_Univ4Se_Policy_P9_R18.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Cp_Univ4Se_Policy_P9_R18.t.sol) (1 failure).

- [L1352](../../ERRORS.log#L1352) `test_D22_claimUngated()`

**UniswapV4Detf_Cp_Univ4Se_ProductLaw_H6** — [UniswapV4Detf_Cp_Univ4Se_ProductLaw_H6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Cp_Univ4Se_ProductLaw_H6.t.sol) (2 failures).

- [L1355](../../ERRORS.log#L1355) `test_A0_donateBeforeFirstBond_cannotFreeMint()`
- [L1356](../../ERRORS.log#L1356) `test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork()`

**UniswapV4Detf_Cp_Univ4Se_ProductLaw_H9** — [UniswapV4Detf_Cp_Univ4Se_ProductLaw_H9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Cp_Univ4Se_ProductLaw_H9.t.sol) (2 failures).

- [L1360](../../ERRORS.log#L1360) `test_A0_donateBeforeFirstBond_cannotFreeMint()`
- [L1361](../../ERRORS.log#L1361) `test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork()`

**UniswapV4Detf_Cp_Univ4Se_ProductLaw_P18_R6** — [UniswapV4Detf_Cp_Univ4Se_ProductLaw_P18_R6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Cp_Univ4Se_ProductLaw_P18_R6.t.sol) (3 failures).

- [L1364](../../ERRORS.log#L1364) `test_A0_donateBeforeFirstBond_cannotFreeMint()`
- [L1365](../../ERRORS.log#L1365) `test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork()`
- [L1366](../../ERRORS.log#L1366) `test_T7_10_selectedAlignmentResidual_booked_noIssuance_retry()`

**UniswapV4Detf_Cp_Univ4Se_ProductLaw_P18_R9** — [UniswapV4Detf_Cp_Univ4Se_ProductLaw_P18_R9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Cp_Univ4Se_ProductLaw_P18_R9.t.sol) (7 failures).

- [L1369](../../ERRORS.log#L1369) `test_A0_donateBeforeFirstBond_cannotFreeMint()`
- [L1370](../../ERRORS.log#L1370) `test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork()`
- [L1371](../../ERRORS.log#L1371) `test_DN16_lastClose_thenDonate_nextBondDoesNotCapture()`
- [L1372](../../ERRORS.log#L1372) `test_DN18_disabled_donateReverts_closeWorks()`
- [L1373](../../ERRORS.log#L1373) `test_claimRewards_whileLocked()`
- [L1374](../../ERRORS.log#L1374) `test_postMaturity_claimPaysFundedStaking()`
- [L1375](../../ERRORS.log#L1375) `test_preMaturity_principalVestsLinearly()`

**UniswapV4Detf_Cp_Univ4Se_ProductLaw_P6_R18** — [UniswapV4Detf_Cp_Univ4Se_ProductLaw_P6_R18.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Cp_Univ4Se_ProductLaw_P6_R18.t.sol) (2 failures).

- [L1378](../../ERRORS.log#L1378) `test_A0_donateBeforeFirstBond_cannotFreeMint()`
- [L1379](../../ERRORS.log#L1379) `test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork()`

**UniswapV4Detf_Cp_Univ4Se_ProductLaw_P6_R9** — [UniswapV4Detf_Cp_Univ4Se_ProductLaw_P6_R9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Cp_Univ4Se_ProductLaw_P6_R9.t.sol) (2 failures).

- [L1382](../../ERRORS.log#L1382) `test_A0_donateBeforeFirstBond_cannotFreeMint()`
- [L1383](../../ERRORS.log#L1383) `test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork()`

**UniswapV4Detf_Cp_Univ4Se_ProductLaw_P9_R18** — [UniswapV4Detf_Cp_Univ4Se_ProductLaw_P9_R18.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Cp_Univ4Se_ProductLaw_P9_R18.t.sol) (2 failures).

- [L1386](../../ERRORS.log#L1386) `test_A0_donateBeforeFirstBond_cannotFreeMint()`
- [L1387](../../ERRORS.log#L1387) `test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork()`

**UniswapV4Detf_Cp_Univ4Se_ProductLaw_P9_R6** — [UniswapV4Detf_Cp_Univ4Se_ProductLaw_P9_R6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Cp_Univ4Se_ProductLaw_P9_R6.t.sol) (2 failures).

- [L1390](../../ERRORS.log#L1390) `test_A0_donateBeforeFirstBond_cannotFreeMint()`
- [L1391](../../ERRORS.log#L1391) `test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork()`

**UniswapV4Detf_Orbital_MorphoBlueSe_Policy_B_ALL6** — [UniswapV4Detf_Orbital_MorphoBlueSe_Policy_B_ALL6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_MorphoBlueSe_Policy_B_ALL6.t.sol) (3 failures).

- [L1394](../../ERRORS.log#L1394) `test_D31_1_policyMint_realizesThenGates()`
- [L1395](../../ERRORS.log#L1395) `test_policy_burn_allowed_when_synthetic_below_burnThreshold()`
- [L1396](../../ERRORS.log#L1396) `test_policy_mint_blocked_in_deadband_then_allowed_after_push()`

**UniswapV4Detf_Orbital_MorphoBlueSe_Policy_B_ALL9** — [UniswapV4Detf_Orbital_MorphoBlueSe_Policy_B_ALL9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_MorphoBlueSe_Policy_B_ALL9.t.sol) (3 failures).

- [L1399](../../ERRORS.log#L1399) `test_D31_1_policyMint_realizesThenGates()`
- [L1400](../../ERRORS.log#L1400) `test_policy_burn_allowed_when_synthetic_below_burnThreshold()`
- [L1401](../../ERRORS.log#L1401) `test_policy_mint_blocked_in_deadband_then_allowed_after_push()`

**UniswapV4Detf_Orbital_MorphoBlueSe_Policy_B_P18_R6** — [UniswapV4Detf_Orbital_MorphoBlueSe_Policy_B_P18_R6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_MorphoBlueSe_Policy_B_P18_R6.t.sol) (3 failures).

- [L1404](../../ERRORS.log#L1404) `test_D31_1_policyMint_realizesThenGates()`
- [L1405](../../ERRORS.log#L1405) `test_policy_burn_allowed_when_synthetic_below_burnThreshold()`
- [L1406](../../ERRORS.log#L1406) `test_policy_mint_blocked_in_deadband_then_allowed_after_push()`

**UniswapV4Detf_Orbital_MorphoBlueSe_Policy_B_P18_R9** — [UniswapV4Detf_Orbital_MorphoBlueSe_Policy_B_P18_R9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_MorphoBlueSe_Policy_B_P18_R9.t.sol) (3 failures).

- [L1409](../../ERRORS.log#L1409) `test_D31_1_policyMint_realizesThenGates()`
- [L1410](../../ERRORS.log#L1410) `test_policy_burn_allowed_when_synthetic_below_burnThreshold()`
- [L1411](../../ERRORS.log#L1411) `test_policy_mint_blocked_in_deadband_then_allowed_after_push()`

**UniswapV4Detf_Orbital_MorphoBlueSe_Policy_B_P6_R18** — [UniswapV4Detf_Orbital_MorphoBlueSe_Policy_B_P6_R18.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_MorphoBlueSe_Policy_B_P6_R18.t.sol) (4 failures).

- [L1414](../../ERRORS.log#L1414) `test_D22_claimUngated()`
- [L1415](../../ERRORS.log#L1415) `test_D31_1_policyMint_realizesThenGates()`
- [L1416](../../ERRORS.log#L1416) `test_policy_burn_allowed_when_synthetic_below_burnThreshold()`
- [L1417](../../ERRORS.log#L1417) `test_policy_mint_blocked_in_deadband_then_allowed_after_push()`

**UniswapV4Detf_Orbital_MorphoBlueSe_Policy_B_P6_R9** — [UniswapV4Detf_Orbital_MorphoBlueSe_Policy_B_P6_R9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_MorphoBlueSe_Policy_B_P6_R9.t.sol) (3 failures).

- [L1420](../../ERRORS.log#L1420) `test_D31_1_policyMint_realizesThenGates()`
- [L1421](../../ERRORS.log#L1421) `test_policy_burn_allowed_when_synthetic_below_burnThreshold()`
- [L1422](../../ERRORS.log#L1422) `test_policy_mint_blocked_in_deadband_then_allowed_after_push()`

**UniswapV4Detf_Orbital_MorphoBlueSe_Policy_B_P9_R18** — [UniswapV4Detf_Orbital_MorphoBlueSe_Policy_B_P9_R18.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_MorphoBlueSe_Policy_B_P9_R18.t.sol) (4 failures).

- [L1425](../../ERRORS.log#L1425) `test_D22_claimUngated()`
- [L1426](../../ERRORS.log#L1426) `test_D31_1_policyMint_realizesThenGates()`
- [L1427](../../ERRORS.log#L1427) `test_policy_burn_allowed_when_synthetic_below_burnThreshold()`
- [L1428](../../ERRORS.log#L1428) `test_policy_mint_blocked_in_deadband_then_allowed_after_push()`

**UniswapV4Detf_Orbital_MorphoBlueSe_Policy_B_P9_R6** — [UniswapV4Detf_Orbital_MorphoBlueSe_Policy_B_P9_R6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_MorphoBlueSe_Policy_B_P9_R6.t.sol) (3 failures).

- [L1431](../../ERRORS.log#L1431) `test_D31_1_policyMint_realizesThenGates()`
- [L1432](../../ERRORS.log#L1432) `test_policy_burn_allowed_when_synthetic_below_burnThreshold()`
- [L1433](../../ERRORS.log#L1433) `test_policy_mint_blocked_in_deadband_then_allowed_after_push()`

**UniswapV4Detf_Orbital_MorphoBlueSe_ProductLaw_B_ALL6** — [UniswapV4Detf_Orbital_MorphoBlueSe_ProductLaw_B_ALL6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_MorphoBlueSe_ProductLaw_B_ALL6.t.sol) (16 failures).

- [L1436](../../ERRORS.log#L1436) `test_DN10_previewEqualsExecute()`
- [L1437](../../ERRORS.log#L1437) `test_DN11_ownerOnlyLiquidity_donateStillWorks()`
- [L1438](../../ERRORS.log#L1438) `test_DN12_donate_doesNotRealizeExpansion()`
- [L1439](../../ERRORS.log#L1439) `test_DN13_burn_afterDonate_usesDonatedLp()`
- [L1440](../../ERRORS.log#L1440) `test_DN14_closeAfterDonate_userBasketUnchanged()`
- [L1441](../../ERRORS.log#L1441) `test_DN16_lastClose_thenDonate_nextBondDoesNotCapture()`
- [L1442](../../ERRORS.log#L1442) `test_DN17_d2_ids12_effectiveShares()`
- [L1443](../../ERRORS.log#L1443) `test_DN19_permit2_allowance()`
- [L1444](../../ERRORS.log#L1444) `test_DN1_donate_pair_Ogt0_unassignedLp()`
- [L1445](../../ERRORS.log#L1445) `test_DN20_permit2_signature()`
- [L1446](../../ERRORS.log#L1446) `test_DN21_d2_afterDonate()`
- [L1447](../../ERRORS.log#L1447) `test_DN22_donate_whilePoolManagerUnlocked()`
- [L1448](../../ERRORS.log#L1448) `test_DN2_donate_vaultShare()`
- [L1449](../../ERRORS.log#L1449) `test_DN4_donate_detf_selfLeg_noMint()`
- [L1450](../../ERRORS.log#L1450) `test_DN6_twoBonders_navRisesTogether()`
- [L1451](../../ERRORS.log#L1451) `test_DN7_detf_donate_forwardsToNft()`

**UniswapV4Detf_Orbital_MorphoBlueSe_ProductLaw_B_ALL9** — [UniswapV4Detf_Orbital_MorphoBlueSe_ProductLaw_B_ALL9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_MorphoBlueSe_ProductLaw_B_ALL9.t.sol) (16 failures).

- [L1454](../../ERRORS.log#L1454) `test_DN10_previewEqualsExecute()`
- [L1455](../../ERRORS.log#L1455) `test_DN11_ownerOnlyLiquidity_donateStillWorks()`
- [L1456](../../ERRORS.log#L1456) `test_DN12_donate_doesNotRealizeExpansion()`
- [L1457](../../ERRORS.log#L1457) `test_DN13_burn_afterDonate_usesDonatedLp()`
- [L1458](../../ERRORS.log#L1458) `test_DN14_closeAfterDonate_userBasketUnchanged()`
- [L1459](../../ERRORS.log#L1459) `test_DN16_lastClose_thenDonate_nextBondDoesNotCapture()`
- [L1460](../../ERRORS.log#L1460) `test_DN17_d2_ids12_effectiveShares()`
- [L1461](../../ERRORS.log#L1461) `test_DN19_permit2_allowance()`
- [L1462](../../ERRORS.log#L1462) `test_DN1_donate_pair_Ogt0_unassignedLp()`
- [L1463](../../ERRORS.log#L1463) `test_DN20_permit2_signature()`
- [L1464](../../ERRORS.log#L1464) `test_DN21_d2_afterDonate()`
- [L1465](../../ERRORS.log#L1465) `test_DN22_donate_whilePoolManagerUnlocked()`
- [L1466](../../ERRORS.log#L1466) `test_DN2_donate_vaultShare()`
- [L1467](../../ERRORS.log#L1467) `test_DN4_donate_detf_selfLeg_noMint()`
- [L1468](../../ERRORS.log#L1468) `test_DN6_twoBonders_navRisesTogether()`
- [L1469](../../ERRORS.log#L1469) `test_DN7_detf_donate_forwardsToNft()`

**UniswapV4Detf_Orbital_MorphoBlueSe_ProductLaw_B_P18_R6** — [UniswapV4Detf_Orbital_MorphoBlueSe_ProductLaw_B_P18_R6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_MorphoBlueSe_ProductLaw_B_P18_R6.t.sol) (16 failures).

- [L1472](../../ERRORS.log#L1472) `test_DN10_previewEqualsExecute()`
- [L1473](../../ERRORS.log#L1473) `test_DN11_ownerOnlyLiquidity_donateStillWorks()`
- [L1474](../../ERRORS.log#L1474) `test_DN12_donate_doesNotRealizeExpansion()`
- [L1475](../../ERRORS.log#L1475) `test_DN13_burn_afterDonate_usesDonatedLp()`
- [L1476](../../ERRORS.log#L1476) `test_DN14_closeAfterDonate_userBasketUnchanged()`
- [L1477](../../ERRORS.log#L1477) `test_DN16_lastClose_thenDonate_nextBondDoesNotCapture()`
- [L1478](../../ERRORS.log#L1478) `test_DN17_d2_ids12_effectiveShares()`
- [L1479](../../ERRORS.log#L1479) `test_DN19_permit2_allowance()`
- [L1480](../../ERRORS.log#L1480) `test_DN1_donate_pair_Ogt0_unassignedLp()`
- [L1481](../../ERRORS.log#L1481) `test_DN20_permit2_signature()`
- [L1482](../../ERRORS.log#L1482) `test_DN21_d2_afterDonate()`
- [L1483](../../ERRORS.log#L1483) `test_DN22_donate_whilePoolManagerUnlocked()`
- [L1484](../../ERRORS.log#L1484) `test_DN2_donate_vaultShare()`
- [L1485](../../ERRORS.log#L1485) `test_DN4_donate_detf_selfLeg_noMint()`
- [L1486](../../ERRORS.log#L1486) `test_DN6_twoBonders_navRisesTogether()`
- [L1487](../../ERRORS.log#L1487) `test_DN7_detf_donate_forwardsToNft()`

**UniswapV4Detf_Orbital_MorphoBlueSe_ProductLaw_B_P18_R9** — [UniswapV4Detf_Orbital_MorphoBlueSe_ProductLaw_B_P18_R9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_MorphoBlueSe_ProductLaw_B_P18_R9.t.sol) (16 failures).

- [L1490](../../ERRORS.log#L1490) `test_DN10_previewEqualsExecute()`
- [L1491](../../ERRORS.log#L1491) `test_DN11_ownerOnlyLiquidity_donateStillWorks()`
- [L1492](../../ERRORS.log#L1492) `test_DN12_donate_doesNotRealizeExpansion()`
- [L1493](../../ERRORS.log#L1493) `test_DN13_burn_afterDonate_usesDonatedLp()`
- [L1494](../../ERRORS.log#L1494) `test_DN14_closeAfterDonate_userBasketUnchanged()`
- [L1495](../../ERRORS.log#L1495) `test_DN16_lastClose_thenDonate_nextBondDoesNotCapture()`
- [L1496](../../ERRORS.log#L1496) `test_DN17_d2_ids12_effectiveShares()`
- [L1497](../../ERRORS.log#L1497) `test_DN19_permit2_allowance()`
- [L1498](../../ERRORS.log#L1498) `test_DN1_donate_pair_Ogt0_unassignedLp()`
- [L1499](../../ERRORS.log#L1499) `test_DN20_permit2_signature()`
- [L1500](../../ERRORS.log#L1500) `test_DN21_d2_afterDonate()`
- [L1501](../../ERRORS.log#L1501) `test_DN22_donate_whilePoolManagerUnlocked()`
- [L1502](../../ERRORS.log#L1502) `test_DN2_donate_vaultShare()`
- [L1503](../../ERRORS.log#L1503) `test_DN4_donate_detf_selfLeg_noMint()`
- [L1504](../../ERRORS.log#L1504) `test_DN6_twoBonders_navRisesTogether()`
- [L1505](../../ERRORS.log#L1505) `test_DN7_detf_donate_forwardsToNft()`

**UniswapV4Detf_Orbital_MorphoBlueSe_ProductLaw_B_P6_R18** — [UniswapV4Detf_Orbital_MorphoBlueSe_ProductLaw_B_P6_R18.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_MorphoBlueSe_ProductLaw_B_P6_R18.t.sol) (17 failures).

- [L1508](../../ERRORS.log#L1508) `test_DN10_previewEqualsExecute()`
- [L1509](../../ERRORS.log#L1509) `test_DN11_ownerOnlyLiquidity_donateStillWorks()`
- [L1510](../../ERRORS.log#L1510) `test_DN12_donate_doesNotRealizeExpansion()`
- [L1511](../../ERRORS.log#L1511) `test_DN13_burn_afterDonate_usesDonatedLp()`
- [L1512](../../ERRORS.log#L1512) `test_DN14_closeAfterDonate_userBasketUnchanged()`
- [L1513](../../ERRORS.log#L1513) `test_DN16_lastClose_thenDonate_nextBondDoesNotCapture()`
- [L1514](../../ERRORS.log#L1514) `test_DN17_d2_ids12_effectiveShares()`
- [L1515](../../ERRORS.log#L1515) `test_DN18_disabled_donateReverts_closeWorks()`
- [L1516](../../ERRORS.log#L1516) `test_DN19_permit2_allowance()`
- [L1517](../../ERRORS.log#L1517) `test_DN1_donate_pair_Ogt0_unassignedLp()`
- [L1518](../../ERRORS.log#L1518) `test_DN20_permit2_signature()`
- [L1519](../../ERRORS.log#L1519) `test_DN21_d2_afterDonate()`
- [L1520](../../ERRORS.log#L1520) `test_DN22_donate_whilePoolManagerUnlocked()`
- [L1521](../../ERRORS.log#L1521) `test_DN2_donate_vaultShare()`
- [L1522](../../ERRORS.log#L1522) `test_DN4_donate_detf_selfLeg_noMint()`
- [L1523](../../ERRORS.log#L1523) `test_DN6_twoBonders_navRisesTogether()`
- [L1524](../../ERRORS.log#L1524) `test_DN7_detf_donate_forwardsToNft()`

**UniswapV4Detf_Orbital_MorphoBlueSe_ProductLaw_B_P6_R9** — [UniswapV4Detf_Orbital_MorphoBlueSe_ProductLaw_B_P6_R9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_MorphoBlueSe_ProductLaw_B_P6_R9.t.sol) (16 failures).

- [L1527](../../ERRORS.log#L1527) `test_DN10_previewEqualsExecute()`
- [L1528](../../ERRORS.log#L1528) `test_DN11_ownerOnlyLiquidity_donateStillWorks()`
- [L1529](../../ERRORS.log#L1529) `test_DN12_donate_doesNotRealizeExpansion()`
- [L1530](../../ERRORS.log#L1530) `test_DN13_burn_afterDonate_usesDonatedLp()`
- [L1531](../../ERRORS.log#L1531) `test_DN14_closeAfterDonate_userBasketUnchanged()`
- [L1532](../../ERRORS.log#L1532) `test_DN16_lastClose_thenDonate_nextBondDoesNotCapture()`
- [L1533](../../ERRORS.log#L1533) `test_DN17_d2_ids12_effectiveShares()`
- [L1534](../../ERRORS.log#L1534) `test_DN19_permit2_allowance()`
- [L1535](../../ERRORS.log#L1535) `test_DN1_donate_pair_Ogt0_unassignedLp()`
- [L1536](../../ERRORS.log#L1536) `test_DN20_permit2_signature()`
- [L1537](../../ERRORS.log#L1537) `test_DN21_d2_afterDonate()`
- [L1538](../../ERRORS.log#L1538) `test_DN22_donate_whilePoolManagerUnlocked()`
- [L1539](../../ERRORS.log#L1539) `test_DN2_donate_vaultShare()`
- [L1540](../../ERRORS.log#L1540) `test_DN4_donate_detf_selfLeg_noMint()`
- [L1541](../../ERRORS.log#L1541) `test_DN6_twoBonders_navRisesTogether()`
- [L1542](../../ERRORS.log#L1542) `test_DN7_detf_donate_forwardsToNft()`

**UniswapV4Detf_Orbital_MorphoBlueSe_ProductLaw_B_P9_R18** — [UniswapV4Detf_Orbital_MorphoBlueSe_ProductLaw_B_P9_R18.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_MorphoBlueSe_ProductLaw_B_P9_R18.t.sol) (17 failures).

- [L1545](../../ERRORS.log#L1545) `test_DN10_previewEqualsExecute()`
- [L1546](../../ERRORS.log#L1546) `test_DN11_ownerOnlyLiquidity_donateStillWorks()`
- [L1547](../../ERRORS.log#L1547) `test_DN12_donate_doesNotRealizeExpansion()`
- [L1548](../../ERRORS.log#L1548) `test_DN13_burn_afterDonate_usesDonatedLp()`
- [L1549](../../ERRORS.log#L1549) `test_DN14_closeAfterDonate_userBasketUnchanged()`
- [L1550](../../ERRORS.log#L1550) `test_DN16_lastClose_thenDonate_nextBondDoesNotCapture()`
- [L1551](../../ERRORS.log#L1551) `test_DN17_d2_ids12_effectiveShares()`
- [L1552](../../ERRORS.log#L1552) `test_DN18_disabled_donateReverts_closeWorks()`
- [L1553](../../ERRORS.log#L1553) `test_DN19_permit2_allowance()`
- [L1554](../../ERRORS.log#L1554) `test_DN1_donate_pair_Ogt0_unassignedLp()`
- [L1555](../../ERRORS.log#L1555) `test_DN20_permit2_signature()`
- [L1556](../../ERRORS.log#L1556) `test_DN21_d2_afterDonate()`
- [L1557](../../ERRORS.log#L1557) `test_DN22_donate_whilePoolManagerUnlocked()`
- [L1558](../../ERRORS.log#L1558) `test_DN2_donate_vaultShare()`
- [L1559](../../ERRORS.log#L1559) `test_DN4_donate_detf_selfLeg_noMint()`
- [L1560](../../ERRORS.log#L1560) `test_DN6_twoBonders_navRisesTogether()`
- [L1561](../../ERRORS.log#L1561) `test_DN7_detf_donate_forwardsToNft()`

**UniswapV4Detf_Orbital_MorphoBlueSe_ProductLaw_B_P9_R6** — [UniswapV4Detf_Orbital_MorphoBlueSe_ProductLaw_B_P9_R6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_MorphoBlueSe_ProductLaw_B_P9_R6.t.sol) (16 failures).

- [L1564](../../ERRORS.log#L1564) `test_DN10_previewEqualsExecute()`
- [L1565](../../ERRORS.log#L1565) `test_DN11_ownerOnlyLiquidity_donateStillWorks()`
- [L1566](../../ERRORS.log#L1566) `test_DN12_donate_doesNotRealizeExpansion()`
- [L1567](../../ERRORS.log#L1567) `test_DN13_burn_afterDonate_usesDonatedLp()`
- [L1568](../../ERRORS.log#L1568) `test_DN14_closeAfterDonate_userBasketUnchanged()`
- [L1569](../../ERRORS.log#L1569) `test_DN16_lastClose_thenDonate_nextBondDoesNotCapture()`
- [L1570](../../ERRORS.log#L1570) `test_DN17_d2_ids12_effectiveShares()`
- [L1571](../../ERRORS.log#L1571) `test_DN19_permit2_allowance()`
- [L1572](../../ERRORS.log#L1572) `test_DN1_donate_pair_Ogt0_unassignedLp()`
- [L1573](../../ERRORS.log#L1573) `test_DN20_permit2_signature()`
- [L1574](../../ERRORS.log#L1574) `test_DN21_d2_afterDonate()`
- [L1575](../../ERRORS.log#L1575) `test_DN22_donate_whilePoolManagerUnlocked()`
- [L1576](../../ERRORS.log#L1576) `test_DN2_donate_vaultShare()`
- [L1577](../../ERRORS.log#L1577) `test_DN4_donate_detf_selfLeg_noMint()`
- [L1578](../../ERRORS.log#L1578) `test_DN6_twoBonders_navRisesTogether()`
- [L1579](../../ERRORS.log#L1579) `test_DN7_detf_donate_forwardsToNft()`

**UniswapV4Detf_Orbital_MorphoMix_Policy_B_ALL6** — [UniswapV4Detf_Orbital_MorphoMix_Policy_B_ALL6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_MorphoMix_Policy_B_ALL6.t.sol) (1 failure).

- [L1582](../../ERRORS.log#L1582) `test_policy_burn_allowed_when_synthetic_below_burnThreshold()`

**UniswapV4Detf_Orbital_MorphoMix_Policy_B_ALL9** — [UniswapV4Detf_Orbital_MorphoMix_Policy_B_ALL9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_MorphoMix_Policy_B_ALL9.t.sol) (1 failure).

- [L1585](../../ERRORS.log#L1585) `test_policy_burn_allowed_when_synthetic_below_burnThreshold()`

**UniswapV4Detf_Orbital_MorphoMix_Policy_B_P18_R6** — [UniswapV4Detf_Orbital_MorphoMix_Policy_B_P18_R6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_MorphoMix_Policy_B_P18_R6.t.sol) (1 failure).

- [L1588](../../ERRORS.log#L1588) `test_policy_burn_allowed_when_synthetic_below_burnThreshold()`

**UniswapV4Detf_Orbital_MorphoMix_Policy_B_P18_R9** — [UniswapV4Detf_Orbital_MorphoMix_Policy_B_P18_R9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_MorphoMix_Policy_B_P18_R9.t.sol) (1 failure).

- [L1591](../../ERRORS.log#L1591) `test_policy_burn_allowed_when_synthetic_below_burnThreshold()`

**UniswapV4Detf_Orbital_MorphoMix_Policy_B_P6_R18** — [UniswapV4Detf_Orbital_MorphoMix_Policy_B_P6_R18.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_MorphoMix_Policy_B_P6_R18.t.sol) (2 failures).

- [L1594](../../ERRORS.log#L1594) `test_D22_claimUngated()`
- [L1595](../../ERRORS.log#L1595) `test_policy_burn_allowed_when_synthetic_below_burnThreshold()`

**UniswapV4Detf_Orbital_MorphoMix_Policy_B_P6_R9** — [UniswapV4Detf_Orbital_MorphoMix_Policy_B_P6_R9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_MorphoMix_Policy_B_P6_R9.t.sol) (1 failure).

- [L1598](../../ERRORS.log#L1598) `test_policy_burn_allowed_when_synthetic_below_burnThreshold()`

**UniswapV4Detf_Orbital_MorphoMix_Policy_B_P9_R18** — [UniswapV4Detf_Orbital_MorphoMix_Policy_B_P9_R18.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_MorphoMix_Policy_B_P9_R18.t.sol) (2 failures).

- [L1601](../../ERRORS.log#L1601) `test_D22_claimUngated()`
- [L1602](../../ERRORS.log#L1602) `test_policy_burn_allowed_when_synthetic_below_burnThreshold()`

**UniswapV4Detf_Orbital_MorphoMix_Policy_B_P9_R6** — [UniswapV4Detf_Orbital_MorphoMix_Policy_B_P9_R6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_MorphoMix_Policy_B_P9_R6.t.sol) (1 failure).

- [L1605](../../ERRORS.log#L1605) `test_policy_burn_allowed_when_synthetic_below_burnThreshold()`

**UniswapV4Detf_Orbital_MorphoMix_ProductLaw_B_ALL6** — [UniswapV4Detf_Orbital_MorphoMix_ProductLaw_B_ALL6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_MorphoMix_ProductLaw_B_ALL6.t.sol) (2 failures).

- [L1609](../../ERRORS.log#L1609) `test_DN22_donate_whilePoolManagerUnlocked()`
- [L1610](../../ERRORS.log#L1610) `test_DN4_donate_detf_selfLeg_noMint()`

**UniswapV4Detf_Orbital_MorphoMix_ProductLaw_B_ALL9** — [UniswapV4Detf_Orbital_MorphoMix_ProductLaw_B_ALL9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_MorphoMix_ProductLaw_B_ALL9.t.sol) (2 failures).

- [L1613](../../ERRORS.log#L1613) `test_DN22_donate_whilePoolManagerUnlocked()`
- [L1614](../../ERRORS.log#L1614) `test_DN4_donate_detf_selfLeg_noMint()`

**UniswapV4Detf_Orbital_MorphoMix_ProductLaw_B_P18_R6** — [UniswapV4Detf_Orbital_MorphoMix_ProductLaw_B_P18_R6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_MorphoMix_ProductLaw_B_P18_R6.t.sol) (1 failure).

- [L1617](../../ERRORS.log#L1617) `test_DN4_donate_detf_selfLeg_noMint()`

**UniswapV4Detf_Orbital_MorphoMix_ProductLaw_B_P18_R9** — [UniswapV4Detf_Orbital_MorphoMix_ProductLaw_B_P18_R9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_MorphoMix_ProductLaw_B_P18_R9.t.sol) (1 failure).

- [L1620](../../ERRORS.log#L1620) `test_DN4_donate_detf_selfLeg_noMint()`

**UniswapV4Detf_Orbital_MorphoMix_ProductLaw_B_P6_R18** — [UniswapV4Detf_Orbital_MorphoMix_ProductLaw_B_P6_R18.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_MorphoMix_ProductLaw_B_P6_R18.t.sol) (4 failures).

- [L1623](../../ERRORS.log#L1623) `test_DN16_lastClose_thenDonate_nextBondDoesNotCapture()`
- [L1624](../../ERRORS.log#L1624) `test_DN18_disabled_donateReverts_closeWorks()`
- [L1626](../../ERRORS.log#L1626) `test_DN22_donate_whilePoolManagerUnlocked()`
- [L1627](../../ERRORS.log#L1627) `test_DN4_donate_detf_selfLeg_noMint()`

**UniswapV4Detf_Orbital_MorphoMix_ProductLaw_B_P6_R9** — [UniswapV4Detf_Orbital_MorphoMix_ProductLaw_B_P6_R9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_MorphoMix_ProductLaw_B_P6_R9.t.sol) (2 failures).

- [L1631](../../ERRORS.log#L1631) `test_DN22_donate_whilePoolManagerUnlocked()`
- [L1632](../../ERRORS.log#L1632) `test_DN4_donate_detf_selfLeg_noMint()`

**UniswapV4Detf_Orbital_MorphoMix_ProductLaw_B_P9_R18** — [UniswapV4Detf_Orbital_MorphoMix_ProductLaw_B_P9_R18.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_MorphoMix_ProductLaw_B_P9_R18.t.sol) (4 failures).

- [L1635](../../ERRORS.log#L1635) `test_DN16_lastClose_thenDonate_nextBondDoesNotCapture()`
- [L1636](../../ERRORS.log#L1636) `test_DN18_disabled_donateReverts_closeWorks()`
- [L1637](../../ERRORS.log#L1637) `test_DN22_donate_whilePoolManagerUnlocked()`
- [L1638](../../ERRORS.log#L1638) `test_DN4_donate_detf_selfLeg_noMint()`

**UniswapV4Detf_Orbital_MorphoMix_ProductLaw_B_P9_R6** — [UniswapV4Detf_Orbital_MorphoMix_ProductLaw_B_P9_R6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_MorphoMix_ProductLaw_B_P9_R6.t.sol) (2 failures).

- [L1641](../../ERRORS.log#L1641) `test_DN22_donate_whilePoolManagerUnlocked()`
- [L1642](../../ERRORS.log#L1642) `test_DN4_donate_detf_selfLeg_noMint()`

**UniswapV4Detf_Orbital_PonsMix_ProductLaw_B_P18_R6** — [UniswapV4Detf_Orbital_PonsMix_ProductLaw_B_P18_R6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_PonsMix_ProductLaw_B_P18_R6.t.sol) (1 failure).

- [L1645](../../ERRORS.log#L1645) `test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork()`

**UniswapV4Detf_Orbital_PonsMix_ProductLaw_B_P18_R9** — [UniswapV4Detf_Orbital_PonsMix_ProductLaw_B_P18_R9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_PonsMix_ProductLaw_B_P18_R9.t.sol) (1 failure).

- [L1648](../../ERRORS.log#L1648) `test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork()`

**UniswapV4Detf_Orbital_PonsV1Se_ProductLaw_B_P18_R6** — [UniswapV4Detf_Orbital_PonsV1Se_ProductLaw_B_P18_R6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_PonsV1Se_ProductLaw_B_P18_R6.t.sol) (1 failure).

- [L1651](../../ERRORS.log#L1651) `test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork()`

**UniswapV4Detf_Orbital_PonsV1Se_ProductLaw_B_P18_R9** — [UniswapV4Detf_Orbital_PonsV1Se_ProductLaw_B_P18_R9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_PonsV1Se_ProductLaw_B_P18_R9.t.sol) (1 failure).

- [L1654](../../ERRORS.log#L1654) `test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork()`

**UniswapV4Detf_Orbital_PonsV2Se_ProductLaw_B_P18_R6** — [UniswapV4Detf_Orbital_PonsV2Se_ProductLaw_B_P18_R6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_PonsV2Se_ProductLaw_B_P18_R6.t.sol) (1 failure).

- [L1657](../../ERRORS.log#L1657) `test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork()`

**UniswapV4Detf_Orbital_PonsV2Se_ProductLaw_B_P18_R9** — [UniswapV4Detf_Orbital_PonsV2Se_ProductLaw_B_P18_R9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_PonsV2Se_ProductLaw_B_P18_R9.t.sol) (1 failure).

- [L1660](../../ERRORS.log#L1660) `test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork()`

**UniswapV4Detf_Orbital_Univ3Se_Lifecycle_B_ALL6** — [UniswapV4Detf_Orbital_Univ3Se_Lifecycle_B_ALL6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_Univ3Se_Lifecycle_B_ALL6.t.sol) (1 failure).

- [L1663](../../ERRORS.log#L1663) `test_H_OR_GV3_burn()`

**UniswapV4Detf_Orbital_Univ3Se_Lifecycle_B_ALL9** — [UniswapV4Detf_Orbital_Univ3Se_Lifecycle_B_ALL9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_Univ3Se_Lifecycle_B_ALL9.t.sol) (1 failure).

- [L1666](../../ERRORS.log#L1666) `test_H_OR_GV3_burn()`

**UniswapV4Detf_Orbital_Univ3Se_Lifecycle_B_P6_R18** — [UniswapV4Detf_Orbital_Univ3Se_Lifecycle_B_P6_R18.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_Univ3Se_Lifecycle_B_P6_R18.t.sol) (1 failure).

- [L1669](../../ERRORS.log#L1669) `test_H_OR_GV3_burn()`

**UniswapV4Detf_Orbital_Univ3Se_Lifecycle_B_P6_R9** — [UniswapV4Detf_Orbital_Univ3Se_Lifecycle_B_P6_R9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_Univ3Se_Lifecycle_B_P6_R9.t.sol) (1 failure).

- [L1672](../../ERRORS.log#L1672) `test_H_OR_GV3_burn()`

**UniswapV4Detf_Orbital_Univ3Se_Lifecycle_B_P9_R18** — [UniswapV4Detf_Orbital_Univ3Se_Lifecycle_B_P9_R18.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_Univ3Se_Lifecycle_B_P9_R18.t.sol) (1 failure).

- [L1675](../../ERRORS.log#L1675) `test_H_OR_GV3_burn()`

**UniswapV4Detf_Orbital_Univ3Se_Lifecycle_B_P9_R6** — [UniswapV4Detf_Orbital_Univ3Se_Lifecycle_B_P9_R6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_Univ3Se_Lifecycle_B_P9_R6.t.sol) (1 failure).

- [L1678](../../ERRORS.log#L1678) `test_H_OR_GV3_burn()`

**UniswapV4Detf_Orbital_Univ3Se_Policy_B_ALL6** — [UniswapV4Detf_Orbital_Univ3Se_Policy_B_ALL6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_Univ3Se_Policy_B_ALL6.t.sol) (3 failures).

- [L1681](../../ERRORS.log#L1681) `test_D31_1_policyMint_realizesThenGates()`
- [L1682](../../ERRORS.log#L1682) `test_policy_burn_allowed_when_synthetic_below_burnThreshold()`
- [L1683](../../ERRORS.log#L1683) `test_policy_mint_blocked_in_deadband_then_allowed_after_push()`

**UniswapV4Detf_Orbital_Univ3Se_Policy_B_ALL9** — [UniswapV4Detf_Orbital_Univ3Se_Policy_B_ALL9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_Univ3Se_Policy_B_ALL9.t.sol) (11 failures).

- [L1686](../../ERRORS.log#L1686) `test_D15_1_previewEqualsExecute()`
- [L1687](../../ERRORS.log#L1687) `test_D15_8_nonDetfPayoutForbidden()`
- [L1688](../../ERRORS.log#L1688) `test_D15_redeem_paysDetf_only()`
- [L1689](../../ERRORS.log#L1689) `test_D22_claimUngated()`
- [L1690](../../ERRORS.log#L1690) `test_D31_1_policyMint_realizesThenGates()`
- [L1691](../../ERRORS.log#L1691) `test_FC_creatorZeroFundsBothRightsToOriginalFeeOwner()`
- [L1692](../../ERRORS.log#L1692) `test_FC_explicitCreatorReceivesSeparateFundedIncome()`
- [L1693](../../ERRORS.log#L1693) `test_FC_fullExitAndFeeToRotationPreserveStandingIncome()`
- [L1694](../../ERRORS.log#L1694) `test_FC_fundedTwoWavesMatchIndependentFloors()`
- [L1695](../../ERRORS.log#L1695) `test_policy_burn_allowed_when_synthetic_below_burnThreshold()`
- [L1696](../../ERRORS.log#L1696) `test_policy_mint_blocked_in_deadband_then_allowed_after_push()`

**UniswapV4Detf_Orbital_Univ3Se_Policy_B_P18_R6** — [UniswapV4Detf_Orbital_Univ3Se_Policy_B_P18_R6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_Univ3Se_Policy_B_P18_R6.t.sol) (2 failures).

- [L1699](../../ERRORS.log#L1699) `test_D31_1_policyMint_realizesThenGates()`
- [L1700](../../ERRORS.log#L1700) `test_policy_mint_blocked_in_deadband_then_allowed_after_push()`

**UniswapV4Detf_Orbital_Univ3Se_Policy_B_P18_R9** — [UniswapV4Detf_Orbital_Univ3Se_Policy_B_P18_R9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_Univ3Se_Policy_B_P18_R9.t.sol) (10 failures).

- [L1703](../../ERRORS.log#L1703) `test_D15_1_previewEqualsExecute()`
- [L1704](../../ERRORS.log#L1704) `test_D15_8_nonDetfPayoutForbidden()`
- [L1705](../../ERRORS.log#L1705) `test_D15_redeem_paysDetf_only()`
- [L1706](../../ERRORS.log#L1706) `test_D22_claimUngated()`
- [L1707](../../ERRORS.log#L1707) `test_D31_1_policyMint_realizesThenGates()`
- [L1708](../../ERRORS.log#L1708) `test_FC_creatorZeroFundsBothRightsToOriginalFeeOwner()`
- [L1709](../../ERRORS.log#L1709) `test_FC_explicitCreatorReceivesSeparateFundedIncome()`
- [L1710](../../ERRORS.log#L1710) `test_FC_fullExitAndFeeToRotationPreserveStandingIncome()`
- [L1711](../../ERRORS.log#L1711) `test_FC_fundedTwoWavesMatchIndependentFloors()`
- [L1712](../../ERRORS.log#L1712) `test_policy_mint_blocked_in_deadband_then_allowed_after_push()`

**UniswapV4Detf_Orbital_Univ3Se_Policy_B_P6_R18** — [UniswapV4Detf_Orbital_Univ3Se_Policy_B_P6_R18.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_Univ3Se_Policy_B_P6_R18.t.sol) (9 failures).

- [L1715](../../ERRORS.log#L1715) `test_D15_1_previewEqualsExecute()`
- [L1716](../../ERRORS.log#L1716) `test_D15_8_nonDetfPayoutForbidden()`
- [L1717](../../ERRORS.log#L1717) `test_D15_redeem_paysDetf_only()`
- [L1718](../../ERRORS.log#L1718) `test_D22_claimUngated()`
- [L1719](../../ERRORS.log#L1719) `test_FC_creatorZeroFundsBothRightsToOriginalFeeOwner()`
- [L1720](../../ERRORS.log#L1720) `test_FC_explicitCreatorReceivesSeparateFundedIncome()`
- [L1721](../../ERRORS.log#L1721) `test_FC_fullExitAndFeeToRotationPreserveStandingIncome()`
- [L1722](../../ERRORS.log#L1722) `test_FC_fundedTwoWavesMatchIndependentFloors()`
- [L1723](../../ERRORS.log#L1723) `test_policy_burn_allowed_when_synthetic_below_burnThreshold()`

**UniswapV4Detf_Orbital_Univ3Se_Policy_B_P6_R9** — [UniswapV4Detf_Orbital_Univ3Se_Policy_B_P6_R9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_Univ3Se_Policy_B_P6_R9.t.sol) (11 failures).

- [L1726](../../ERRORS.log#L1726) `test_D15_1_previewEqualsExecute()`
- [L1727](../../ERRORS.log#L1727) `test_D15_8_nonDetfPayoutForbidden()`
- [L1728](../../ERRORS.log#L1728) `test_D15_redeem_paysDetf_only()`
- [L1729](../../ERRORS.log#L1729) `test_D22_claimUngated()`
- [L1730](../../ERRORS.log#L1730) `test_D31_1_policyMint_realizesThenGates()`
- [L1731](../../ERRORS.log#L1731) `test_FC_creatorZeroFundsBothRightsToOriginalFeeOwner()`
- [L1732](../../ERRORS.log#L1732) `test_FC_explicitCreatorReceivesSeparateFundedIncome()`
- [L1733](../../ERRORS.log#L1733) `test_FC_fullExitAndFeeToRotationPreserveStandingIncome()`
- [L1734](../../ERRORS.log#L1734) `test_FC_fundedTwoWavesMatchIndependentFloors()`
- [L1735](../../ERRORS.log#L1735) `test_policy_burn_allowed_when_synthetic_below_burnThreshold()`
- [L1736](../../ERRORS.log#L1736) `test_policy_mint_blocked_in_deadband_then_allowed_after_push()`

**UniswapV4Detf_Orbital_Univ3Se_Policy_B_P9_R18** — [UniswapV4Detf_Orbital_Univ3Se_Policy_B_P9_R18.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_Univ3Se_Policy_B_P9_R18.t.sol) (9 failures).

- [L1739](../../ERRORS.log#L1739) `test_D15_1_previewEqualsExecute()`
- [L1740](../../ERRORS.log#L1740) `test_D15_8_nonDetfPayoutForbidden()`
- [L1741](../../ERRORS.log#L1741) `test_D15_redeem_paysDetf_only()`
- [L1742](../../ERRORS.log#L1742) `test_D22_claimUngated()`
- [L1743](../../ERRORS.log#L1743) `test_FC_creatorZeroFundsBothRightsToOriginalFeeOwner()`
- [L1744](../../ERRORS.log#L1744) `test_FC_explicitCreatorReceivesSeparateFundedIncome()`
- [L1745](../../ERRORS.log#L1745) `test_FC_fullExitAndFeeToRotationPreserveStandingIncome()`
- [L1746](../../ERRORS.log#L1746) `test_FC_fundedTwoWavesMatchIndependentFloors()`
- [L1747](../../ERRORS.log#L1747) `test_policy_burn_allowed_when_synthetic_below_burnThreshold()`

**UniswapV4Detf_Orbital_Univ3Se_Policy_B_P9_R6** — [UniswapV4Detf_Orbital_Univ3Se_Policy_B_P9_R6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_Univ3Se_Policy_B_P9_R6.t.sol) (3 failures).

- [L1750](../../ERRORS.log#L1750) `test_D31_1_policyMint_realizesThenGates()`
- [L1751](../../ERRORS.log#L1751) `test_policy_burn_allowed_when_synthetic_below_burnThreshold()`
- [L1752](../../ERRORS.log#L1752) `test_policy_mint_blocked_in_deadband_then_allowed_after_push()`

**UniswapV4Detf_Orbital_Univ3Se_ProductLaw_B_ALL6** — [UniswapV4Detf_Orbital_Univ3Se_ProductLaw_B_ALL6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_Univ3Se_ProductLaw_B_ALL6.t.sol) (19 failures).

- [L1755](../../ERRORS.log#L1755) `test_A0_donateBeforeFirstBond_cannotFreeMint()`
- [L1756](../../ERRORS.log#L1756) `test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork()`
- [L1757](../../ERRORS.log#L1757) `test_DN10_previewEqualsExecute()`
- [L1758](../../ERRORS.log#L1758) `test_DN11_ownerOnlyLiquidity_donateStillWorks()`
- [L1759](../../ERRORS.log#L1759) `test_DN12_donate_doesNotRealizeExpansion()`
- [L1760](../../ERRORS.log#L1760) `test_DN13_burn_afterDonate_usesDonatedLp()`
- [L1761](../../ERRORS.log#L1761) `test_DN14_closeAfterDonate_userBasketUnchanged()`
- [L1762](../../ERRORS.log#L1762) `test_DN16_lastClose_thenDonate_nextBondDoesNotCapture()`
- [L1763](../../ERRORS.log#L1763) `test_DN17_d2_ids12_effectiveShares()`
- [L1764](../../ERRORS.log#L1764) `test_DN18_disabled_donateReverts_closeWorks()`
- [L1765](../../ERRORS.log#L1765) `test_DN19_permit2_allowance()`
- [L1766](../../ERRORS.log#L1766) `test_DN1_donate_pair_Ogt0_unassignedLp()`
- [L1767](../../ERRORS.log#L1767) `test_DN20_permit2_signature()`
- [L1768](../../ERRORS.log#L1768) `test_DN21_d2_afterDonate()`
- [L1769](../../ERRORS.log#L1769) `test_DN22_donate_whilePoolManagerUnlocked()`
- [L1770](../../ERRORS.log#L1770) `test_DN2_donate_vaultShare()`
- [L1771](../../ERRORS.log#L1771) `test_DN4_donate_detf_selfLeg_noMint()`
- [L1772](../../ERRORS.log#L1772) `test_DN6_twoBonders_navRisesTogether()`
- [L1773](../../ERRORS.log#L1773) `test_DN7_detf_donate_forwardsToNft()`

**UniswapV4Detf_Orbital_Univ3Se_ProductLaw_B_ALL9** — [UniswapV4Detf_Orbital_Univ3Se_ProductLaw_B_ALL9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_Univ3Se_ProductLaw_B_ALL9.t.sol) (28 failures).

- [L1776](../../ERRORS.log#L1776) `test_A0_donateBeforeFirstBond_cannotFreeMint()`
- [L1777](../../ERRORS.log#L1777) `test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork()`
- [L1778](../../ERRORS.log#L1778) `test_D15_1_previewEqualsExecute()`
- [L1779](../../ERRORS.log#L1779) `test_D15_8_nonDetfPayoutForbidden()`
- [L1780](../../ERRORS.log#L1780) `test_D15_redeem_paysDetf_only()`
- [L1781](../../ERRORS.log#L1781) `test_D25_fundedPrincipalAndRewardsPayOnlyStaking()`
- [L1782](../../ERRORS.log#L1782) `test_D25_standingReceiptsAlreadyFundedBeforeClaim()`
- [L1783](../../ERRORS.log#L1783) `test_DN10_previewEqualsExecute()`
- [L1784](../../ERRORS.log#L1784) `test_DN11_ownerOnlyLiquidity_donateStillWorks()`
- [L1785](../../ERRORS.log#L1785) `test_DN12_donate_doesNotRealizeExpansion()`
- [L1786](../../ERRORS.log#L1786) `test_DN13_burn_afterDonate_usesDonatedLp()`
- [L1787](../../ERRORS.log#L1787) `test_DN14_closeAfterDonate_userBasketUnchanged()`
- [L1788](../../ERRORS.log#L1788) `test_DN16_lastClose_thenDonate_nextBondDoesNotCapture()`
- [L1789](../../ERRORS.log#L1789) `test_DN17_d2_ids12_effectiveShares()`
- [L1790](../../ERRORS.log#L1790) `test_DN18_disabled_donateReverts_closeWorks()`
- [L1791](../../ERRORS.log#L1791) `test_DN19_permit2_allowance()`
- [L1792](../../ERRORS.log#L1792) `test_DN1_donate_pair_Ogt0_unassignedLp()`
- [L1793](../../ERRORS.log#L1793) `test_DN20_permit2_signature()`
- [L1794](../../ERRORS.log#L1794) `test_DN21_d2_afterDonate()`
- [L1795](../../ERRORS.log#L1795) `test_DN22_donate_whilePoolManagerUnlocked()`
- [L1796](../../ERRORS.log#L1796) `test_DN2_donate_vaultShare()`
- [L1797](../../ERRORS.log#L1797) `test_DN4_donate_detf_selfLeg_noMint()`
- [L1798](../../ERRORS.log#L1798) `test_DN6_twoBonders_navRisesTogether()`
- [L1799](../../ERRORS.log#L1799) `test_DN7_detf_donate_forwardsToNft()`
- [L1800](../../ERRORS.log#L1800) `test_T7_10_laterBond_joinUnbalanced_unboostedG()`
- [L1801](../../ERRORS.log#L1801) `test_claimRewards_whileLocked()`
- [L1802](../../ERRORS.log#L1802) `test_postMaturity_claimPaysFundedStaking()`
- [L1803](../../ERRORS.log#L1803) `test_preMaturity_principalVestsLinearly()`

**UniswapV4Detf_Orbital_Univ3Se_ProductLaw_B_P18_R6** — [UniswapV4Detf_Orbital_Univ3Se_ProductLaw_B_P18_R6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_Univ3Se_ProductLaw_B_P18_R6.t.sol) (17 failures).

- [L1806](../../ERRORS.log#L1806) `test_A0_donateBeforeFirstBond_cannotFreeMint()`
- [L1807](../../ERRORS.log#L1807) `test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork()`
- [L1808](../../ERRORS.log#L1808) `test_DN10_previewEqualsExecute()`
- [L1809](../../ERRORS.log#L1809) `test_DN11_ownerOnlyLiquidity_donateStillWorks()`
- [L1810](../../ERRORS.log#L1810) `test_DN12_donate_doesNotRealizeExpansion()`
- [L1811](../../ERRORS.log#L1811) `test_DN13_burn_afterDonate_usesDonatedLp()`
- [L1812](../../ERRORS.log#L1812) `test_DN14_closeAfterDonate_userBasketUnchanged()`
- [L1813](../../ERRORS.log#L1813) `test_DN16_lastClose_thenDonate_nextBondDoesNotCapture()`
- [L1814](../../ERRORS.log#L1814) `test_DN17_d2_ids12_effectiveShares()`
- [L1815](../../ERRORS.log#L1815) `test_DN19_permit2_allowance()`
- [L1816](../../ERRORS.log#L1816) `test_DN1_donate_pair_Ogt0_unassignedLp()`
- [L1817](../../ERRORS.log#L1817) `test_DN20_permit2_signature()`
- [L1818](../../ERRORS.log#L1818) `test_DN21_d2_afterDonate()`
- [L1819](../../ERRORS.log#L1819) `test_DN22_donate_whilePoolManagerUnlocked()`
- [L1820](../../ERRORS.log#L1820) `test_DN2_donate_vaultShare()`
- [L1821](../../ERRORS.log#L1821) `test_DN6_twoBonders_navRisesTogether()`
- [L1822](../../ERRORS.log#L1822) `test_DN7_detf_donate_forwardsToNft()`

**UniswapV4Detf_Orbital_Univ3Se_ProductLaw_B_P18_R9** — [UniswapV4Detf_Orbital_Univ3Se_ProductLaw_B_P18_R9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_Univ3Se_ProductLaw_B_P18_R9.t.sol) (27 failures).

- [L1825](../../ERRORS.log#L1825) `test_A0_donateBeforeFirstBond_cannotFreeMint()`
- [L1826](../../ERRORS.log#L1826) `test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork()`
- [L1827](../../ERRORS.log#L1827) `test_D15_1_previewEqualsExecute()`
- [L1828](../../ERRORS.log#L1828) `test_D15_8_nonDetfPayoutForbidden()`
- [L1829](../../ERRORS.log#L1829) `test_D15_redeem_paysDetf_only()`
- [L1830](../../ERRORS.log#L1830) `test_D25_fundedPrincipalAndRewardsPayOnlyStaking()`
- [L1831](../../ERRORS.log#L1831) `test_D25_standingReceiptsAlreadyFundedBeforeClaim()`
- [L1832](../../ERRORS.log#L1832) `test_DN10_previewEqualsExecute()`
- [L1833](../../ERRORS.log#L1833) `test_DN11_ownerOnlyLiquidity_donateStillWorks()`
- [L1834](../../ERRORS.log#L1834) `test_DN12_donate_doesNotRealizeExpansion()`
- [L1835](../../ERRORS.log#L1835) `test_DN13_burn_afterDonate_usesDonatedLp()`
- [L1836](../../ERRORS.log#L1836) `test_DN14_closeAfterDonate_userBasketUnchanged()`
- [L1837](../../ERRORS.log#L1837) `test_DN16_lastClose_thenDonate_nextBondDoesNotCapture()`
- [L1838](../../ERRORS.log#L1838) `test_DN17_d2_ids12_effectiveShares()`
- [L1839](../../ERRORS.log#L1839) `test_DN18_disabled_donateReverts_closeWorks()`
- [L1840](../../ERRORS.log#L1840) `test_DN19_permit2_allowance()`
- [L1841](../../ERRORS.log#L1841) `test_DN1_donate_pair_Ogt0_unassignedLp()`
- [L1842](../../ERRORS.log#L1842) `test_DN20_permit2_signature()`
- [L1843](../../ERRORS.log#L1843) `test_DN21_d2_afterDonate()`
- [L1844](../../ERRORS.log#L1844) `test_DN22_donate_whilePoolManagerUnlocked()`
- [L1845](../../ERRORS.log#L1845) `test_DN2_donate_vaultShare()`
- [L1846](../../ERRORS.log#L1846) `test_DN6_twoBonders_navRisesTogether()`
- [L1847](../../ERRORS.log#L1847) `test_DN7_detf_donate_forwardsToNft()`
- [L1848](../../ERRORS.log#L1848) `test_T7_10_laterBond_joinUnbalanced_unboostedG()`
- [L1849](../../ERRORS.log#L1849) `test_claimRewards_whileLocked()`
- [L1850](../../ERRORS.log#L1850) `test_postMaturity_claimPaysFundedStaking()`
- [L1851](../../ERRORS.log#L1851) `test_preMaturity_principalVestsLinearly()`

**UniswapV4Detf_Orbital_Univ3Se_ProductLaw_B_P6_R18** — [UniswapV4Detf_Orbital_Univ3Se_ProductLaw_B_P6_R18.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_Univ3Se_ProductLaw_B_P6_R18.t.sol) (15 failures).

- [L1854](../../ERRORS.log#L1854) `test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork()`
- [L1855](../../ERRORS.log#L1855) `test_D15_1_previewEqualsExecute()`
- [L1856](../../ERRORS.log#L1856) `test_D15_8_nonDetfPayoutForbidden()`
- [L1857](../../ERRORS.log#L1857) `test_D15_redeem_paysDetf_only()`
- [L1858](../../ERRORS.log#L1858) `test_D25_fundedPrincipalAndRewardsPayOnlyStaking()`
- [L1859](../../ERRORS.log#L1859) `test_D25_standingReceiptsAlreadyFundedBeforeClaim()`
- [L1860](../../ERRORS.log#L1860) `test_DN14_closeAfterDonate_userBasketUnchanged()`
- [L1861](../../ERRORS.log#L1861) `test_DN16_lastClose_thenDonate_nextBondDoesNotCapture()`
- [L1862](../../ERRORS.log#L1862) `test_DN18_disabled_donateReverts_closeWorks()`
- [L1863](../../ERRORS.log#L1863) `test_DN4_donate_detf_selfLeg_noMint()`
- [L1864](../../ERRORS.log#L1864) `test_DN6_twoBonders_navRisesTogether()`
- [L1865](../../ERRORS.log#L1865) `test_T7_10_laterBond_joinUnbalanced_unboostedG()`
- [L1866](../../ERRORS.log#L1866) `test_claimRewards_whileLocked()`
- [L1867](../../ERRORS.log#L1867) `test_postMaturity_claimPaysFundedStaking()`
- [L1868](../../ERRORS.log#L1868) `test_preMaturity_principalVestsLinearly()`

**UniswapV4Detf_Orbital_Univ3Se_ProductLaw_B_P6_R9** — [UniswapV4Detf_Orbital_Univ3Se_ProductLaw_B_P6_R9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_Univ3Se_ProductLaw_B_P6_R9.t.sol) (28 failures).

- [L1871](../../ERRORS.log#L1871) `test_A0_donateBeforeFirstBond_cannotFreeMint()`
- [L1872](../../ERRORS.log#L1872) `test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork()`
- [L1873](../../ERRORS.log#L1873) `test_D15_1_previewEqualsExecute()`
- [L1874](../../ERRORS.log#L1874) `test_D15_8_nonDetfPayoutForbidden()`
- [L1875](../../ERRORS.log#L1875) `test_D15_redeem_paysDetf_only()`
- [L1876](../../ERRORS.log#L1876) `test_D25_fundedPrincipalAndRewardsPayOnlyStaking()`
- [L1877](../../ERRORS.log#L1877) `test_D25_standingReceiptsAlreadyFundedBeforeClaim()`
- [L1878](../../ERRORS.log#L1878) `test_DN10_previewEqualsExecute()`
- [L1879](../../ERRORS.log#L1879) `test_DN11_ownerOnlyLiquidity_donateStillWorks()`
- [L1880](../../ERRORS.log#L1880) `test_DN12_donate_doesNotRealizeExpansion()`
- [L1881](../../ERRORS.log#L1881) `test_DN13_burn_afterDonate_usesDonatedLp()`
- [L1882](../../ERRORS.log#L1882) `test_DN14_closeAfterDonate_userBasketUnchanged()`
- [L1883](../../ERRORS.log#L1883) `test_DN16_lastClose_thenDonate_nextBondDoesNotCapture()`
- [L1884](../../ERRORS.log#L1884) `test_DN17_d2_ids12_effectiveShares()`
- [L1885](../../ERRORS.log#L1885) `test_DN18_disabled_donateReverts_closeWorks()`
- [L1886](../../ERRORS.log#L1886) `test_DN19_permit2_allowance()`
- [L1887](../../ERRORS.log#L1887) `test_DN1_donate_pair_Ogt0_unassignedLp()`
- [L1888](../../ERRORS.log#L1888) `test_DN20_permit2_signature()`
- [L1889](../../ERRORS.log#L1889) `test_DN21_d2_afterDonate()`
- [L1890](../../ERRORS.log#L1890) `test_DN22_donate_whilePoolManagerUnlocked()`
- [L1891](../../ERRORS.log#L1891) `test_DN2_donate_vaultShare()`
- [L1892](../../ERRORS.log#L1892) `test_DN4_donate_detf_selfLeg_noMint()`
- [L1893](../../ERRORS.log#L1893) `test_DN6_twoBonders_navRisesTogether()`
- [L1894](../../ERRORS.log#L1894) `test_DN7_detf_donate_forwardsToNft()`
- [L1895](../../ERRORS.log#L1895) `test_T7_10_laterBond_joinUnbalanced_unboostedG()`
- [L1896](../../ERRORS.log#L1896) `test_claimRewards_whileLocked()`
- [L1897](../../ERRORS.log#L1897) `test_postMaturity_claimPaysFundedStaking()`
- [L1898](../../ERRORS.log#L1898) `test_preMaturity_principalVestsLinearly()`

**UniswapV4Detf_Orbital_Univ3Se_ProductLaw_B_P9_R18** — [UniswapV4Detf_Orbital_Univ3Se_ProductLaw_B_P9_R18.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_Univ3Se_ProductLaw_B_P9_R18.t.sol) (15 failures).

- [L1901](../../ERRORS.log#L1901) `test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork()`
- [L1902](../../ERRORS.log#L1902) `test_D15_1_previewEqualsExecute()`
- [L1903](../../ERRORS.log#L1903) `test_D15_8_nonDetfPayoutForbidden()`
- [L1904](../../ERRORS.log#L1904) `test_D15_redeem_paysDetf_only()`
- [L1905](../../ERRORS.log#L1905) `test_D25_fundedPrincipalAndRewardsPayOnlyStaking()`
- [L1906](../../ERRORS.log#L1906) `test_D25_standingReceiptsAlreadyFundedBeforeClaim()`
- [L1907](../../ERRORS.log#L1907) `test_DN14_closeAfterDonate_userBasketUnchanged()`
- [L1908](../../ERRORS.log#L1908) `test_DN16_lastClose_thenDonate_nextBondDoesNotCapture()`
- [L1909](../../ERRORS.log#L1909) `test_DN18_disabled_donateReverts_closeWorks()`
- [L1910](../../ERRORS.log#L1910) `test_DN4_donate_detf_selfLeg_noMint()`
- [L1911](../../ERRORS.log#L1911) `test_DN6_twoBonders_navRisesTogether()`
- [L1912](../../ERRORS.log#L1912) `test_T7_10_laterBond_joinUnbalanced_unboostedG()`
- [L1913](../../ERRORS.log#L1913) `test_claimRewards_whileLocked()`
- [L1914](../../ERRORS.log#L1914) `test_postMaturity_claimPaysFundedStaking()`
- [L1915](../../ERRORS.log#L1915) `test_preMaturity_principalVestsLinearly()`

**UniswapV4Detf_Orbital_Univ3Se_ProductLaw_B_P9_R6** — [UniswapV4Detf_Orbital_Univ3Se_ProductLaw_B_P9_R6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_Univ3Se_ProductLaw_B_P9_R6.t.sol) (19 failures).

- [L1918](../../ERRORS.log#L1918) `test_A0_donateBeforeFirstBond_cannotFreeMint()`
- [L1919](../../ERRORS.log#L1919) `test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork()`
- [L1920](../../ERRORS.log#L1920) `test_DN10_previewEqualsExecute()`
- [L1921](../../ERRORS.log#L1921) `test_DN11_ownerOnlyLiquidity_donateStillWorks()`
- [L1922](../../ERRORS.log#L1922) `test_DN12_donate_doesNotRealizeExpansion()`
- [L1923](../../ERRORS.log#L1923) `test_DN13_burn_afterDonate_usesDonatedLp()`
- [L1924](../../ERRORS.log#L1924) `test_DN14_closeAfterDonate_userBasketUnchanged()`
- [L1925](../../ERRORS.log#L1925) `test_DN16_lastClose_thenDonate_nextBondDoesNotCapture()`
- [L1926](../../ERRORS.log#L1926) `test_DN17_d2_ids12_effectiveShares()`
- [L1927](../../ERRORS.log#L1927) `test_DN18_disabled_donateReverts_closeWorks()`
- [L1928](../../ERRORS.log#L1928) `test_DN19_permit2_allowance()`
- [L1929](../../ERRORS.log#L1929) `test_DN1_donate_pair_Ogt0_unassignedLp()`
- [L1930](../../ERRORS.log#L1930) `test_DN20_permit2_signature()`
- [L1931](../../ERRORS.log#L1931) `test_DN21_d2_afterDonate()`
- [L1932](../../ERRORS.log#L1932) `test_DN22_donate_whilePoolManagerUnlocked()`
- [L1933](../../ERRORS.log#L1933) `test_DN2_donate_vaultShare()`
- [L1934](../../ERRORS.log#L1934) `test_DN4_donate_detf_selfLeg_noMint()`
- [L1935](../../ERRORS.log#L1935) `test_DN6_twoBonders_navRisesTogether()`
- [L1936](../../ERRORS.log#L1936) `test_DN7_detf_donate_forwardsToNft()`

**UniswapV4Detf_Orbital_Univ4Se_Policy_B_P6_R18** — [UniswapV4Detf_Orbital_Univ4Se_Policy_B_P6_R18.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_Univ4Se_Policy_B_P6_R18.t.sol) (8 failures).

- [L1942](../../ERRORS.log#L1942) `test_D15_1_previewEqualsExecute()`
- [L1943](../../ERRORS.log#L1943) `test_D15_8_nonDetfPayoutForbidden()`
- [L1944](../../ERRORS.log#L1944) `test_D15_redeem_paysDetf_only()`
- [L1945](../../ERRORS.log#L1945) `test_D22_claimUngated()`
- [L1946](../../ERRORS.log#L1946) `test_FC_creatorZeroFundsBothRightsToOriginalFeeOwner()`
- [L1947](../../ERRORS.log#L1947) `test_FC_explicitCreatorReceivesSeparateFundedIncome()`
- [L1948](../../ERRORS.log#L1948) `test_FC_fullExitAndFeeToRotationPreserveStandingIncome()`
- [L1949](../../ERRORS.log#L1949) `test_FC_fundedTwoWavesMatchIndependentFloors()`

**UniswapV4Detf_Orbital_Univ4Se_Policy_B_P9_R18** — [UniswapV4Detf_Orbital_Univ4Se_Policy_B_P9_R18.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_Univ4Se_Policy_B_P9_R18.t.sol) (8 failures).

- [L1952](../../ERRORS.log#L1952) `test_D15_1_previewEqualsExecute()`
- [L1953](../../ERRORS.log#L1953) `test_D15_8_nonDetfPayoutForbidden()`
- [L1954](../../ERRORS.log#L1954) `test_D15_redeem_paysDetf_only()`
- [L1955](../../ERRORS.log#L1955) `test_D22_claimUngated()`
- [L1956](../../ERRORS.log#L1956) `test_FC_creatorZeroFundsBothRightsToOriginalFeeOwner()`
- [L1957](../../ERRORS.log#L1957) `test_FC_explicitCreatorReceivesSeparateFundedIncome()`
- [L1958](../../ERRORS.log#L1958) `test_FC_fullExitAndFeeToRotationPreserveStandingIncome()`
- [L1959](../../ERRORS.log#L1959) `test_FC_fundedTwoWavesMatchIndependentFloors()`

**UniswapV4Detf_Orbital_Univ4Se_ProductLaw_B_ALL6** — [UniswapV4Detf_Orbital_Univ4Se_ProductLaw_B_ALL6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_Univ4Se_ProductLaw_B_ALL6.t.sol) (2 failures).

- [L1962](../../ERRORS.log#L1962) `test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork()`
- [L1964](../../ERRORS.log#L1964) `test_DN22_donate_whilePoolManagerUnlocked()`

**UniswapV4Detf_Orbital_Univ4Se_ProductLaw_B_ALL9** — [UniswapV4Detf_Orbital_Univ4Se_ProductLaw_B_ALL9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_Univ4Se_ProductLaw_B_ALL9.t.sol) (2 failures).

- [L1968](../../ERRORS.log#L1968) `test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork()`
- [L1969](../../ERRORS.log#L1969) `test_DN22_donate_whilePoolManagerUnlocked()`

**UniswapV4Detf_Orbital_Univ4Se_ProductLaw_B_P18_R6** — [UniswapV4Detf_Orbital_Univ4Se_ProductLaw_B_P18_R6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_Univ4Se_ProductLaw_B_P18_R6.t.sol) (1 failure).

- [L1972](../../ERRORS.log#L1972) `test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork()`

**UniswapV4Detf_Orbital_Univ4Se_ProductLaw_B_P18_R9** — [UniswapV4Detf_Orbital_Univ4Se_ProductLaw_B_P18_R9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_Univ4Se_ProductLaw_B_P18_R9.t.sol) (1 failure).

- [L1976](../../ERRORS.log#L1976) `test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork()`

**UniswapV4Detf_Orbital_Univ4Se_ProductLaw_B_P6_R18** — [UniswapV4Detf_Orbital_Univ4Se_ProductLaw_B_P6_R18.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_Univ4Se_ProductLaw_B_P6_R18.t.sol) (15 failures).

- [L1979](../../ERRORS.log#L1979) `test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork()`
- [L1980](../../ERRORS.log#L1980) `test_D15_1_previewEqualsExecute()`
- [L1981](../../ERRORS.log#L1981) `test_D15_8_nonDetfPayoutForbidden()`
- [L1982](../../ERRORS.log#L1982) `test_D15_redeem_paysDetf_only()`
- [L1983](../../ERRORS.log#L1983) `test_D25_fundedPrincipalAndRewardsPayOnlyStaking()`
- [L1984](../../ERRORS.log#L1984) `test_D25_standingReceiptsAlreadyFundedBeforeClaim()`
- [L1985](../../ERRORS.log#L1985) `test_DN14_closeAfterDonate_userBasketUnchanged()`
- [L1986](../../ERRORS.log#L1986) `test_DN16_lastClose_thenDonate_nextBondDoesNotCapture()`
- [L1987](../../ERRORS.log#L1987) `test_DN18_disabled_donateReverts_closeWorks()`
- [L1989](../../ERRORS.log#L1989) `test_DN22_donate_whilePoolManagerUnlocked()`
- [L1990](../../ERRORS.log#L1990) `test_DN6_twoBonders_navRisesTogether()`
- [L1991](../../ERRORS.log#L1991) `test_T7_10_laterBond_joinUnbalanced_unboostedG()`
- [L1992](../../ERRORS.log#L1992) `test_claimRewards_whileLocked()`
- [L1993](../../ERRORS.log#L1993) `test_postMaturity_claimPaysFundedStaking()`
- [L1994](../../ERRORS.log#L1994) `test_preMaturity_principalVestsLinearly()`

**UniswapV4Detf_Orbital_Univ4Se_ProductLaw_B_P6_R9** — [UniswapV4Detf_Orbital_Univ4Se_ProductLaw_B_P6_R9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_Univ4Se_ProductLaw_B_P6_R9.t.sol) (2 failures).

- [L1997](../../ERRORS.log#L1997) `test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork()`
- [L1999](../../ERRORS.log#L1999) `test_DN22_donate_whilePoolManagerUnlocked()`

**UniswapV4Detf_Orbital_Univ4Se_ProductLaw_B_P9_R18** — [UniswapV4Detf_Orbital_Univ4Se_ProductLaw_B_P9_R18.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_Univ4Se_ProductLaw_B_P9_R18.t.sol) (15 failures).

- [L2002](../../ERRORS.log#L2002) `test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork()`
- [L2003](../../ERRORS.log#L2003) `test_D15_1_previewEqualsExecute()`
- [L2004](../../ERRORS.log#L2004) `test_D15_8_nonDetfPayoutForbidden()`
- [L2005](../../ERRORS.log#L2005) `test_D15_redeem_paysDetf_only()`
- [L2006](../../ERRORS.log#L2006) `test_D25_fundedPrincipalAndRewardsPayOnlyStaking()`
- [L2007](../../ERRORS.log#L2007) `test_D25_standingReceiptsAlreadyFundedBeforeClaim()`
- [L2008](../../ERRORS.log#L2008) `test_DN14_closeAfterDonate_userBasketUnchanged()`
- [L2009](../../ERRORS.log#L2009) `test_DN16_lastClose_thenDonate_nextBondDoesNotCapture()`
- [L2010](../../ERRORS.log#L2010) `test_DN18_disabled_donateReverts_closeWorks()`
- [L2011](../../ERRORS.log#L2011) `test_DN22_donate_whilePoolManagerUnlocked()`
- [L2012](../../ERRORS.log#L2012) `test_DN6_twoBonders_navRisesTogether()`
- [L2013](../../ERRORS.log#L2013) `test_T7_10_laterBond_joinUnbalanced_unboostedG()`
- [L2014](../../ERRORS.log#L2014) `test_claimRewards_whileLocked()`
- [L2015](../../ERRORS.log#L2015) `test_postMaturity_claimPaysFundedStaking()`
- [L2016](../../ERRORS.log#L2016) `test_preMaturity_principalVestsLinearly()`

**UniswapV4Detf_Orbital_Univ4Se_ProductLaw_B_P9_R6** — [UniswapV4Detf_Orbital_Univ4Se_ProductLaw_B_P9_R6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_Univ4Se_ProductLaw_B_P9_R6.t.sol) (2 failures).

- [L2019](../../ERRORS.log#L2019) `test_CROPS_disable_inboundGated_matureCloseRedeemBurnWork()`
- [L2020](../../ERRORS.log#L2020) `test_DN22_donate_whilePoolManagerUnlocked()`

### Inventory R19 — 10 failures

**UniswapV4Detf_Orbital_MorphoMix_ProductLaw_B_ALL6** — [UniswapV4Detf_Orbital_MorphoMix_ProductLaw_B_ALL6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_MorphoMix_ProductLaw_B_ALL6.t.sol) (1 failure).

- [L1608](../../ERRORS.log#L1608) `test_DN21_d2_afterDonate()`

**UniswapV4Detf_Orbital_MorphoMix_ProductLaw_B_P6_R18** — [UniswapV4Detf_Orbital_MorphoMix_ProductLaw_B_P6_R18.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_MorphoMix_ProductLaw_B_P6_R18.t.sol) (1 failure).

- [L1625](../../ERRORS.log#L1625) `test_DN21_d2_afterDonate()`

**UniswapV4Detf_Orbital_MorphoMix_ProductLaw_B_P6_R9** — [UniswapV4Detf_Orbital_MorphoMix_ProductLaw_B_P6_R9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_MorphoMix_ProductLaw_B_P6_R9.t.sol) (1 failure).

- [L1630](../../ERRORS.log#L1630) `test_DN21_d2_afterDonate()`

**UniswapV4Detf_Orbital_Univ4Se_Policy_B_ALL6** — [UniswapV4Detf_Orbital_Univ4Se_Policy_B_ALL6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_Univ4Se_Policy_B_ALL6.t.sol) (1 failure).

- [L1939](../../ERRORS.log#L1939) `test_policy_burn_allowed_when_synthetic_below_burnThreshold()`

**UniswapV4Detf_Orbital_Univ4Se_ProductLaw_B_ALL6** — [UniswapV4Detf_Orbital_Univ4Se_ProductLaw_B_ALL6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_Univ4Se_ProductLaw_B_ALL6.t.sol) (2 failures).

- [L1963](../../ERRORS.log#L1963) `test_DN21_d2_afterDonate()`
- [L1965](../../ERRORS.log#L1965) `test_DN4_donate_detf_selfLeg_noMint()`

**UniswapV4Detf_Orbital_Univ4Se_ProductLaw_B_P18_R6** — [UniswapV4Detf_Orbital_Univ4Se_ProductLaw_B_P18_R6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_Univ4Se_ProductLaw_B_P18_R6.t.sol) (1 failure).

- [L1973](../../ERRORS.log#L1973) `test_DN4_donate_detf_selfLeg_noMint()`

**UniswapV4Detf_Orbital_Univ4Se_ProductLaw_B_P6_R18** — [UniswapV4Detf_Orbital_Univ4Se_ProductLaw_B_P6_R18.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_Univ4Se_ProductLaw_B_P6_R18.t.sol) (1 failure).

- [L1988](../../ERRORS.log#L1988) `test_DN21_d2_afterDonate()`

**UniswapV4Detf_Orbital_Univ4Se_ProductLaw_B_P6_R9** — [UniswapV4Detf_Orbital_Univ4Se_ProductLaw_B_P6_R9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_Univ4Se_ProductLaw_B_P6_R9.t.sol) (1 failure).

- [L1998](../../ERRORS.log#L1998) `test_DN21_d2_afterDonate()`

**UniswapV4Detf_Orbital_Univ4Se_ProductLaw_B_P9_R6** — [UniswapV4Detf_Orbital_Univ4Se_ProductLaw_B_P9_R6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Orbital_Univ4Se_ProductLaw_B_P9_R6.t.sol) (1 failure).

- [L2021](../../ERRORS.log#L2021) `test_DN4_donate_detf_selfLeg_noMint()`

### Inventory R20 — 2 failures

**UniswapV4Detf_Cp_Univ3Se_ProductLaw_P6_R18** — [UniswapV4Detf_Cp_Univ3Se_ProductLaw_P6_R18.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Cp_Univ3Se_ProductLaw_P6_R18.t.sol) (1 failure).

- [L1307](../../ERRORS.log#L1307) `test_T7_10_laterBond_joinUnbalanced_unboostedG()`

**UniswapV4Detf_Cp_Univ3Se_ProductLaw_P6_R9** — [UniswapV4Detf_Cp_Univ3Se_ProductLaw_P6_R9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Cp_Univ3Se_ProductLaw_P6_R9.t.sol) (1 failure).

- [L1312](../../ERRORS.log#L1312) `test_T7_10_laterBond_joinUnbalanced_unboostedG()`

### Inventory R21 — 2 failures

**UniswapV4Detf_Invariant** — [UniswapV4Detf_Invariant.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/invariant/UniswapV4Detf_Invariant.t.sol) (1 failure).

- [L798](../../ERRORS.log#L798) `invariant_accounting()`

**WingsApexRecurrenceInvariantWitnessTest** — [ApexRecurrenceInvariantWitness.t.sol](../../test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/ApexRecurrenceInvariantWitness.t.sol) (1 failure).

- [L2075](../../ERRORS.log#L2075) `invariant_review_actionWitnessesAndCustody()`

### Inventory R22 — 3 failures

**Adversarial_Reentrancy** — [Adversarial_Reentrancy.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/adversarial/Adversarial_Reentrancy.t.sol) (1 failure).

- [L308](../../ERRORS.log#L308) `test_reentrancy_mint_hitsIsLocked()`

**Adversarial_Reentrancy_P18_R6_DexUniV4Det** — [Adversarial_Reentrancy_P18_R6.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/adversarial/Adversarial_Reentrancy_P18_R6.t.sol) (1 failure).

- [L792](../../ERRORS.log#L792) `test_reentrancy_mint_hitsIsLocked()`

**Adversarial_Reentrancy_P18_R9_DexUniV4Det** — [Adversarial_Reentrancy_P18_R9.t.sol](../../test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/decimals/adversarial/Adversarial_Reentrancy_P18_R9.t.sol) (1 failure).

- [L795](../../ERRORS.log#L795) `test_reentrancy_mint_hitsIsLocked()`

## Completion checks for this report

- Parsed 1,522 failure records, matching the log footer and the sum of suite-header counts.
- Preserved both multiline invariant replay entries in the inventory.
- Assigned every unique file/contract/test/signature to exactly one primary group; no unclassified entries or duplicates.
- Validated linked source files exist in the inspected working tree.
- Made no production/test edits and performed no runtime diagnosis or test execution in this reporting task.
