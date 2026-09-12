"""Resolve named acceptance tests to current sources without asserting run success."""
from collections import defaultdict
import json
from pathlib import Path
import re

artifacts = Path(__file__).resolve().parent
root = artifacts.parent.parent
names = {
    'A1': ['test_bindingHasNativeNineDecimalChildren', 'test_stakingPackageRejectsNonNineDecimalBacking'],
    'A2': ['testFuzz_fundedRebaseConservation', 'testFuzz_paidRewardsAndStakeChangesKeepEveryUnitFunded'],
    'A3': ['test_reserveTradingCannotReduceFundedPrincipalAndFullExitRetiresOnlyOwnFraction', 'test_emptyAndUnfundedRebasePreserveIndex'],
    'A4': ['test_bindingFirstBondFundsPrincipalSeparatelyFromOwnedLP', 'test_bindingFirstBondPaymentPreviewMatchesEveryWalletDebit'],
    'A5': ['test_bond_independentPurchasedAllocationAndLiquidity', 'test_bond_equalQuotesPreserveExistingSplit'],
    'A6': ['test_linearVestingFloorsAndFinalUnit', 'test_bindingHalfwayPrincipalUnstakesWithoutLPWithdrawal'],
    'A7': ['test_halfwayPrincipalAndRewardClaims', 'test_rewardOnlyClaimIsImmediateAndDoesNotUnlockPrincipal'],
    'A8': ['test_twoBondEscrowsCloseWithoutRetiringEachOthersFraction', 'test_ownerOperatorAndTransferPreserveRemainingVesting'],
    'A9': ['test_FC_fundedTwoWavesMatchIndependentFloors', 'test_bindingRewardsClaimWhilePrincipalRemainsLocked'],
    'A10': ['test_standardMintAndBurnFallbackMatchActualSwapWithoutIssuance', 'test_standardFallbackSettlesFundedCatchupBeforeBothDirections'],
    'A11': ['test_seShareFallbackComposesActualRedemptionAndSwap', 'test_customProtocolShareFallbackComposesActualConversionAndSwap', 'test_customDonationQuoteIncludesWrappingBeforeReserveJoin'],
    'A12': ['test_stakingSYDepositAndRedemptionMatchPreviews', 'test_syInternalBalanceRedemptionConsumesOnlyTransferredSY'],
    'A13': ['test_liveMint_U_is_Gross_userAndPot', 'test_d2_topUpDeltas_workedExample', 'test_lpBondValuesDistinctNonDetfLegsAndRetainsWholeInventory'],
    'A14': ['test_allocationWorkedExample', 'test_FC_fundedTwoWavesMatchIndependentFloors', 'test_FC_noNewFundingCannotRepeatStandingPayout'],
    'A15': ['test_FC_fullExitAndFeeToRotationPreserveStandingIncome', 'test_standingRecipientsReceiveNewExpansionAfterAllStakeUnstakes'],
    'A16': ['test_T1_openingZero_storesAsCreation_firstBondGAtPeg', 'test_T2_openingUsesG_creationViewUnchanged', 'test_bindingFirstBondPaymentPreviewMatchesEveryWalletDebit'],
    'A17': ['test_standardFallbackSettlesFundedCatchupBeforeBothDirections', 'test_FC_fundedTwoWavesMatchIndependentFloors'],
    'A18': ['test_bindingHalfwayPrincipalUnstakesWithoutLPWithdrawal', 'test_D25_fundedPrincipalAndRewardsPayOnlyStaking'],
    'A19': ['test_rawSYWrapsAndRedeemsExactDETFWithoutStaking', 'test_syAddressesMetadataAndDirectionalDiscovery'],
    'A20': ['test_bindingPositionShareInputsRedeemThroughEveryNativeSyOutput', 'test_stakingSYDepositAndRedemptionMatchPreviews', 'test_syDepositSlippageRollsBackInputAndBacking'],
    'A21': ['test_staticSyRateUsesFundedIndex', 'test_stakingSYOwnsStaticBalancesAcrossNewBondRewards'],
    'A22': ['test_boundaryStakeParticipationAndLateEntryOrdering'],
    'A23': ['test_standingWeightsOnlyDistributeWholePot', 'test_standingRecipientsReceiveNewExpansionAfterAllStakeUnstakes'],
    'A24': ['test_hour25Settles24AndPreservesNextBoundary', 'test_lpBondSettlesExpansionBeforeTakingPayment'],
    'A25': ['test_FC_fundedTwoWavesMatchIndependentFloors', 'test_lpBondSettlesExpansionBeforeTakingPayment'],
    'A26': ['test_standardMintAndBurnFallbackMatchActualSwapWithoutIssuance'],
    'A27': ['test_sevenDaysIncludesAll21EpochsWithoutCompounding', 'test_weekHasNoOneDayOrSupplyRelativeCap'],
    'A28': ['test_J2_retiredClaimSelectorsAreAbsent', 'test_bindingRetiredLpClaimProjectionSelectorsAreAbsent'],
    'A29': ['test_syDepositSlippageRollsBackInputAndBacking', 'test_pretransferredNeverCreditsHeldStakingOrBacking', 'test_exactOutputNativeLimitsAfterFundedRebase'],
    'A30': ['test_J2_retiredLpAndEffectiveShareSelectorsCannotBeCalled'],
    'A31': ['test_halfwayArtworkAndExactJSONUseFundedClaims', 'test_newPartialRewardOnlyAndFullyVestedStates'],
    'A32': ['test_nameIsEscapedIndependentlyForJSONAndSVG', 'test_rolesHaveNoInventedVestingOrPrincipal', 'test_exportRepresentativeRendererArtifacts'],
    'A34': ['test_FR1_centerTicksFullRange_noWings', 'test_FR1_centerTicksFullRange_wingsUnused', 'test_FR6_importedNftConvertedToFullRange', 'test_FR6_importConvertsRealNftToFullRangeIncludingEarnedFees'],
    'A35': ['test_nativeSYMetadataAndWholeBookRate', 'test_nativeSYMetadataRateAndFacetSize', 'test_accruedFees_blockedDepositMatchesIdlePreview', 'testFuzz_fundedSleeveWithdrawalRounding', 'testFuzz_singleDeposit_roundTripPreservesIncumbentValue', 'testFuzz_transitionSequence_fundedPool'],
    'A36': ['test_FR5_bothTokensActivateThenSingleTokenDepositsRemainAvailable', 'test_FR5_firstActivationRequiresBothTokens', 'test_importRejectsUnfundedSideAndRollsBackNftTransfer', 'test_nativeSYPreservesFundedSleeveOperationsDuringPoolLock', 'test_nativeSYUsesFundedSleeveDuringManagerSession'],
    'A37': ['test_reservePolicyMatchesHookAndRetainsDetfOwnership', 'test_directLiquidityOperationsFollowDeploymentPolicy', 'test_deploymentRejectsPolicyMismatchWithActualHook', 'test_publicReserveSwapsRemainAvailableInBothPolicies'],
    'A38': ['test_lpBondValuesDistinctNonDetfLegsAndRetainsWholeInventory', 'test_lpBondCannotClaimProtocolOrAnotherWalletsLp'],
    'A39': ['test_lpBondSettlesExpansionBeforeTakingPayment', 'test_lpCannotReplaceFirstBondActivation'],
    'A40': ['test_externallyOwnedLpDonationTransfersWholePositionWithoutStakingIssuance', 'test_lpBondCannotClaimProtocolOrAnotherWalletsLp'],
    'A41': ['test_currentCollectorRedeemsActualFeeLpWithOwnerAuthorization', 'test_feeCollectorRotationChangesRestrictedRemovalAuthority', 'test_internalSYRedemptionUsesCurrentCollectorAfterRotation'],
}
wanted = {name for group in names.values() for name in group}
index = defaultdict(list)
for directory in ['test/foundry/spec/vaults/detf/common', 'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4',
                  'test/foundry/spec/protocol/dexes/uniswap/v3', 'test/foundry/spec/protocol/dexes/uniswap/v4',
                  'test/foundry/spec/vaults/standard/sy']:
    for path in (root / directory).rglob('*.sol'):
        for number, line in enumerate(path.read_text().splitlines(), 1):
            match = re.search(r'\bfunction\s+(test\w+)\s*\(', line)
            if match and match[1] in wanted:
                index[match[1]].append({'source': str(path.relative_to(root)), 'line': number, 'function': match[1]})

pending = {'test_boundaryStakeParticipationAndLateEntryOrdering'}
missing = wanted - index.keys()
assert missing <= pending, f'Unresolved test names: {sorted(missing - pending)}'
report = {
    'status': 'Current source anchors only; execution status remains in acceptance-progress.json and complete run logs.',
    'note': 'These are review entry points, not an exhaustive proof of every subclause. Native SE package inventory and storage/selector records supplement them. Named legacy IDs retain their migrated assertions.',
    'rows': [
        {'criterion': criterion, 'tests': [anchor for name in group for anchor in index[name]],
         'prepared_tests': [name for name in group if name in missing]}
        for criterion, group in names.items()
    ],
    'separate_evidence': {
        'A33': 'Excluded under D60',
        'A34_A35_A36': 'Named hermetic anchors require additional V3/V4 native-SY package matrices, current-se-package-inventory.json and all eight pinned V3 fork cases; source anchors alone do not close these requirements.',
        'A42': 'slipstream-deferral-verification.json; preserve completed work and evidence',
    },
}
(artifacts / 'acceptance-test-anchors.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps({'criteria_with_named_tests': len(names), 'distinct_names': len(wanted), 'prepared_not_applied': sorted(missing)}))
