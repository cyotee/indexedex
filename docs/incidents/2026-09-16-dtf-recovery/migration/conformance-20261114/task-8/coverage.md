# Task 8 adversarial fixtures and invariant evidence

All paths below use the exact M/T/K/E/P expansions in `preflight.json`.
This is task 8 evidence, not task 9 documentation or a full-plan completion claim.

The final required happy command is the first line of `happy-5.log`: 17 passed,
zero failed/skipped, exit 0. `hostile-rollback.log` records the same hostile and
surface proxies: 13 passed, zero failed/skipped, exit 0. `fork-4.log` records
17 pinned-source cases, zero failed/skipped, exit 0. `inherited.log` records
17 retained administration/core cases, zero failed/skipped, exit 0.
The helper prints its expanded `forge build --use solar` before its
`forge test --use solar`; raw output and earlier failed attempts remain here.

`effective-invariant-config.json` records seed `0x8`, 16 runs and depth 8.
Every final invariant reports 128 calls and zero reverted handler calls.
The repository's `fail_on_revert=false` does not substitute for that observed
zero, the independent ledger assertions, or the positive witnesses.
`action-counts.json` contains the actual emitted counters, including zero
claims separately from successful claims.

## Mechanism and shared fixture

The old native handler used one book and one quote array for both current
predictions and every loaded recipient. That cannot represent retained A
credit after setting B. The handler now retains each recipient's configured
book and credit while the existing quote array tracks current predictions.
Its independent funded-staking ledger and immutable issuance records remain.
Set, reload, issue, activation and stale-book actions update successful-action
counters only after the corresponding real operation.

The new `M/TestBase_UniswapV4DetfMigration_Adversarial.sol` owns the common
CREATE3 deployment of the external hostile currency, callback arming, and
before/after custody, allowance, donation inventory, credit, issuance, pricing,
supply, actual funding, staking state/gons, next-NFT ownership and proxy cuts.
Both `MigrationHostileContributionTest` and `MigrationOwnerBondCallbacksTest`
use that deployment and the shared rollback assertions. The external actor
stays in its existing test file and is loaded through the artifact helper;
there is no substitute parent, child, manager, registry, fee oracle or SUT subclass.
Unset pricing is observed by the getter's exact success/error bytes, not a
fabricated empty book.

## Native and hostile test sensitivity

Each row states the observable regression the real-proxy test catches.
All rows are retained security/lifecycle contracts, not source-text checks.
Existing assertions were preserved. The short-receipt case was renamed to
`test_L2_FoT_forbidden` to match the configured-token policy; its original exact
error and balance assertions remain.

| Suite / case | Observable failure caught / independent observation |
| --- | --- |
| Hostile / `test_L2_FoT_forbidden` | A configured short-delivery token leaves partial custody or donation credit. Exact `TransferDeltaInsufficient(1 ether, 1 ether - 1)` and the full shared rollback snapshot. |
| Hostile / `test_tokenCallbackCannotBorrowLockedParentChildSynchronization` | A token callback claims a mature bond through the locked parent. Exact `NotAuthorized(bonds)`; principal/gons stay unchanged, then the same actual holder claims successfully outside the callback. |
| Hostile / `test_N1_unauthorizedPricingCallbackCannotMutateBookOrCredit` | A payment token changes the pricing book mid-flow. Exact `NotOwner(pairB)` and byte-identical book/configuration with unchanged supply/gons. |
| Hostile / `test_sourceSpoofingPreservesEveryRollbackDomain` | An unrelated token impersonates the fixed weighted SY source. Exact chain/source error, absent entitlement and unchanged shared custody/credit/funding/cuts. |
| Hostile / `test_failedSecondChildFundingRollsBackWholeBatch` | The first actual funded issuance survives the second actual receiver failure. Exact `ERC721InvalidReceiver(bonds)` and snapshots for both recipients and both next NFT IDs. |
| Hostile / `test_A0_K1_donationBeforeFirstIssuanceNeverCreditsNextWallet` | Pre-supply inventory grants a subsequent wallet free credit or issuance beyond its configured original. Independent supply/principal/backing/gon deltas equal the configured credit only; configuration itself mints nothing. |
| Owner callbacks / `test_contractOwnerPaymentCallbacksCannotPublishOrBypassAndShortReceiptRollsBack` | A paid-owner callback activates, buys twice, acquires through another route, releases rewards, or leaks failed-payment state. Nested errors are exact; short receipt rolls back the complete shared snapshot. The valid purchase then succeeds. |
| Owner callbacks / `test_I1_I2_I3_bookedAndUnbookedPretransferCannotPurchase` | Seven ether of booked inventory, zero/short/exact/reused prepayment, or old unbooked inventory buys owner rights or is refunded. All pretransfers reject exactly; a fresh pull pays exactly one ether, refunds zero to the wallet and preserves the exact seven-ether donation book and prior custody floor. |
| Surface / `test_allPackageCutsReachRealProxyAndFitEip170` | A declared selector routes to a missing/different facet, an implementation exceeds EIP-170, or child initialization remains exposed. Uses actual package cuts, facet behavior and live loupe. |
| Surface / `test_adminDeclarationMatchesInterfaceAndCannotBeRestored` | Interface selectors are omitted or any removable selector survives activation. Facet behavior is checked against interface-derived controls; every removed live-proxy call returns the exact `NoTargetFor(selector)`. Reinitialization/package restoration remain rejected. |
| Surface / `test_ordinaryRegistryPackageCannotAcquireMigrationAuthority` | Migration authority leaks into a separately deployed ordinary registry package or deployment mutates the Migration book. Real ordinary package, real separate hook/children, absent routes and exact setter `NoTargetFor`, with unchanged Migration state. |
| Surface / `test_realTokenUriNumericCliffBoundaries` | Compensation metadata presents linear principal release. Exact actual creation, duration and cliff-minus-one/exact/plus-one values are parsed from the live token URI. |
| Surface / `test_wrongCustodyCallerCannotUseStaleIndexOrCreateBacking` | An arbitrary caller uses child synchronization/index arguments to manufacture backing. Every real child entry rejects authorization; gons and funding remain zero. |
| Native / `invariant_nativeLedgerAndPermanentLifecycle` | Set B rewrites A, explicit reload alters immutable A issuance, stale A loads on B, a cut is restored, or custody/funding/supply diverge. Per-row provenance and the independent integer staking ledger are checked after every action. |
| Native / `test_successfulWitnessCliffAndActivationSequence` | Principal exits one second before its own cliff, Stage 1 pays rewards, or activation/repeat administration loses permanence. Exact real claims and errors across the clock and cut. |
| Native / `test_allPositionsFreshCliffsAndLaterPaidGrowth` | A later issue inherits an earlier clock or later paid funding escapes the ledger. Every actual position transfers/claims at its own boundaries; later paid bonds and rewards must be positive. |
| Active / `invariant_laterFundingAndAllPositionClaims` | Postactivation activity changes removed authority, old provenance, role accrual or funded principal solvency. Mandatory paid/reward witnesses and every-position ledger checks remain active. |

The native invariant's final terminal witness reports two pricing replacements,
one explicit replacement configuration, one additional independent issuance,
one activation, two exact stale-book rejections and a positive reward claim
paying 122,238 native units. The active invariant reports two additional
independent issuances in total, three later paid bonds and two positive reward
claims paying 366,748 units. These are executed transactions, not coverage
claims inferred from handler selectors. The paid owner-first prerequisite is
also checked from its actual nonzero token ID.

## Pinned-source sensitivity and retained examples

| Suite / case | Observable failure caught / independent observation |
| --- | --- |
| Legacy invariant / `invariant_originalCreditCustodyFundingAndStagedRecovery` | Both whole-NFT models or ordinary SY lose original-credit conservation, custody, fresh funded bonds or staged recovery reconciliation. Before activation, both real NFT configurations are set/reloaded across books while economic original IDs, custody, supply and gons remain stable. |
| Legacy invariant / `test_threeUnitsPay333Then334Then334OnActualProxy` | Partial surrender discards or overpays residue. Three genuinely transferred legacy SY units are configured for exactly 1,001 native credit on a distinct real registry proxy; actual funded bond principals are exactly 333/334/334 and terminal units/credit are zero. The quote-search chooses only a synthetic test input; no source units or SUT storage are manufactured. |
| Legacy invariant / `test_terminalCreditAndCompleteRecoveryWitness` | Terminal surrender or staged recovery silently leaves credit/inventory unreconciled. The independent remaining/delivered ledger and fixed destination are asserted. |
| Legacy invariant / `test_laterSurrenderOwnCliffAndEveryPositionClaim` | A later surrendered bond backdates its cliff or a holder transfer bypasses it. Actual new start times and every funded position's claims are checked at minus-one/exact/plus-one boundaries. |
| Source units / `invariant_exactOriginalUnitsCustodyAndFreshEscrow` | Any one of the ten configured source-unit domains never surrenders, never reaches failed-child funding, double-credits a wrapper or loses its exact unit/custody/gon ledger. Each domain must have positive surrender and rollback counters. |
| Source units / `test_allUnitsTerminalOrRetainedResidueAndLaterOwnCliffs` | Terminal fungible credit is lost, nonrepresentable receipt residue is confiscated, or any later source bond has the wrong clock. Exact terminal/retained residue and every actual bond are checked. |
| Legacy sources / `test_burnedNonexistentReservedAndZeroCreditRejectWithoutCustody` | Invalid/empty/reserved/reward-only source positions commit custody or credit. |
| Legacy sources / `test_claimBeforeSurrenderRaceUsesLiveFractionAndRejectsStaleMinimum` | A claim/surrender race credits stale principal or survives a stale minimum failure. |
| Legacy sources / `test_earlierAccountingSharesAreNeitherEffectiveWeightNorPhysicalLp` | Earlier accounting units are confused with effective reward weight or physical LP. |
| Legacy sources / `test_earlierRewardsAndHolderTransferPreserveOriginalSharesAndDisabledHarvest` | Rewards/transfers change original units or enable a disabled recovery route. |
| Legacy sources / `test_inconsistentOriginalUnitsRejectBothSourcesWithoutChangingRealPositions` | An inconsistent full original is accepted for either NFT model. |
| Legacy sources / `test_missingApprovalRollsBackPretransferAcceptanceForBothSources` | Failed actual custody leaves acceptance/credit consumed. |
| Legacy sources / `test_rewardOnlyWeightedAndBurnedEarlierEarnNoCredit` | Rewards alone or burned positions manufacture compensation. |
| Legacy sources / `test_sameIdInTwoCollectionsIncludesStillLockedEarlierPrincipal` | Numeric token IDs collide across collections or locked earlier principal is omitted. |
| Legacy sources / `test_transferredWeightedHolderMustReturnToPurchaserBeforeSurrender` | An asset holder inherits another wallet's configured credit. |
| Legacy sources / `test_weightedPartialUsesWholeRemainingPrincipalAndFrozenOriginalQuote` | Partial remaining principal is nonlinearly requoted instead of receiving its full-original proportional credit. |
| Legacy sources / `test_wrongCurrentHolderCannotUseRecordedPurchaserEntitlement` | The recorded purchaser surrenders an NFT it does not control. |

The final source-unit invariant reports two successful surrenders for every
one of ten source domains, at least one late funding rollback each, 120 competing
enrollment rejections, eight successful recovery stages and one whole recovery
batch rollback. The legacy invariant reports two funded receiver callbacks,
one late funding rollback and five successful recovery stages. No source
category was waived. Claimed-SY operator witness pin mismatch remains the
separate recorded task 7 follow-up; no pin or operator source was edited here.

`inherited.log` additionally retains all seven administration and ten core
cases, including separately quoted multiple originals, immutable delivered
issuance on replacement, duplicate-original exclusion, whole-batch failure,
current/pending/former ownership, owner NFT callback activation rejection,
no reward backdating and independent reserve self-leg accounting.
The independent native ledger continues to check fee/creator accrued gons,
their Stage 1 payout prohibition and proper Stage 2 release.

## Catalog applicability

| Catalog | Witness or concrete boundary |
| --- | --- |
| A0 / K1 | Pre-supply donation test, exact no-mint-on-load, old-inventory owner-purchase floor and native donation/trade/provider actions. |
| I1-I3 | Real contract owner's zero/short/exact/reused pretransfer against seven ether of booked inventory. The Stage 1 purchase deliberately hard-rejects public pretransfer; this is not the EOA-bytecode guard or an invented success path. |
| J1-J3 | Interface-derived facet behavior, actual package/live loupe and callable post-cut errors; separate ordinary registry deployment. |
| E6 | Migration donation/bootstrap and the tested owner purchase accept exact input, not caller-selected max-minus-used refunds. The classic fat-max recipe has no argument on those entries. The actual shared residual-sweep risk is nevertheless exercised: prior booked and unbooked custody cannot go to the buyer, and retained rounding residue is bounded by actual current payment. |
| N1 / activation reentrancy | Token callback unauthorized pricing edit, locked cross-child claim, owner payment callback and retained owner NFT callback cases. |
| Source spoof / wrapper duplicate / claim race | Exact source rejection, all-domain competing enrollment, independent-history exclusion and real `claimBeforeSurrenderRace` fork. |
| Whole batch failure | Actual second-child receiver failure and each source's late funding/recovery batch rollback. |
| L2 | Configured hostile short-transfer underlying fails; no fee-on-transfer success policy was introduced. |
| M1-M3 | No new product entry forwards arbitrary target/calldata or grants caller-selected allowances. External hostile actor payloads are test actors, not a product forwarding feature. Recovery targets remain fixed by typed stage. |
| O | No signature route was added or changed. Existing permit surfaces and their tests remain; this task makes no new signature-coverage claim. |

## Boundaries and attempts

`adversarial-probes.json` records rejection of misleading success banners,
nonzero/missing exits, zero issuance, zero activation, zero selected cases and
stale source bindings; it also records artifact refresh and protected-file
comparisons. All final runs were subscribed to completion when started.
None was cancelled or killed for silence. Flaky execution, cancellation,
interruptions and external untrusted instruction text were not introduced.

Earlier failures are retained and diagnosed there: unset-pricing observation,
an invalid exact-zero V3 residue assumption, missing credentials in a non-login
process, and deterministic reuse of an already activated proxy. The residue
case now uses a distinct owner in the real package salt. No SUT was patched.
Production mutation testing was excluded by the explicit no-SUT-edit boundary.

Forge lint warnings remain unsuppressed in the raw logs, including bounded
external-call loops, ERC20 return values, casts and test ghost-state updates.
Solidity LSP errors and scoped `git diff --check` are zero. Existing Forge
automatic submodule initialization attempts fail because Crane already exists;
the existing dependency remains and no dependency was installed.
No full-repository final-tree verification is claimed here; that remains task 13.
