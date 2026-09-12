"""Resolve the remaining source-declaration changes to current tests/decisions."""
from pathlib import Path
from datetime import datetime, timezone
import json
import re

art = Path(__file__).resolve().parent
root = art.parent.parent
inventory = json.loads((art / 'current-test-consolidation.json').read_text())
index = {}
for path in (root / 'test/foundry').rglob('*.sol'):
    for number, line in enumerate(path.read_text().splitlines(), 1):
        match = re.search(r'\bfunction\s+((?:test|invariant)\w*)\s*\(', line)
        if match:
            index.setdefault(match[1], []).append({'source': str(path.relative_to(root)), 'line': number})

groups = [
    ('UniswapV3StandardExchange_FullRangeBook_Decimals.sol', 'D57-D59 replace single-token activation and unchanged narrow imports with two-token activation, subsequent single-token deposits and real full-range conversion in every retained decimal leaf.', ['test_FR5_bothTokensActivateThenSingleTokenDepositsRemainAvailable', 'test_FR6_importedNftConvertedToFullRange']),
    ('UniswapV4StandardExchange_FullRangeBook_Decimals.sol', 'D57-D59 replace single-token activation and unchanged narrow imports. The real funded PositionManager fixture now proves narrow-position removal, full-range principal and earned-fee conservation, and native SY redemption in every retained decimal leaf.', ['test_FR5_bothTokensActivateThenSingleTokenDepositsRemainAvailable', 'test_FR6_importConvertsRealNftToFullRangeIncludingEarnedFees']),
    ('UniswapV3StandardExchange_FullRangeBook.t.sol', 'D57-D59 require full-range import conversion and two-token activation; funded sleeve rounding replaces invalid one-sided initialization.', ['test_FR5_bothTokensActivateThenSingleTokenDepositsRemainAvailable', 'test_FR6_importedNftConvertedToFullRange', 'testFuzz_fundedSleeveWithdrawalRounding']),
    ('UniswapV4StandardExchangeBalancerQuadStableBufferHook_StagedInit.t.sol', 'Native SY interface and separated production facet cuts replace the old hardcoded interface/cut counts. Staged deployment remains tested.', ['test_facetInterfaces_twelveProductionIds', 'test_productionFacetCuts_eightAdds']),
    ('RebasingClaimTokenDFPkg_Deploy.t.sol', 'Funded nine-decimal child deployment replaces LP-valued/unfunded minting. Deterministic deployment, custom/default metadata and funded first-bond custody remain tested.', ['test_customMetadataPreserved', 'test_deployTokenDefaultMetadataAndDeterminism', 'test_deployedNativeUnitsAndEmptyFundedLedger', 'test_legacyUnfundedMintSelectorAbsent', 'test_firstBondFundsPrincipalInAdditionToLiquidity']),
    ('DETFEpochNaturalExpansionLib.t.sol', 'Fixed eight-hour first-bond boundaries replace configurable epochs/Open mode and caps. Zero eligibility consumes boundaries without issuing rewards.', ['test_fixedEpochAndRetainedRateDefault', 'test_inertDoesNotStartClock', 'test_hour25Settles24AndPreservesNextBoundary', 'test_sevenDaysIncludesAll21EpochsWithoutCompounding', 'test_zeroEligibilityStillConsumesAllCompletedBoundaries', 'test_zeroTimestampCanBeFirstBondAnchor']),
    ('DETFMintSplit_Alignment.t.sol', 'Independent purchased U and liquidity G replace the assumption U equals G; the equal-input vector preserves the original split.', ['test_bond_independentPurchasedAllocationAndLiquidity', 'test_bond_equalQuotesPreserveExistingSplit']),
    ('UniswapV4DetfBondNFTVaultDFPkg_Deploy.t.sol', 'Funded child deployment and actual protocol LP custody replace virtual id-0 LP entitlements; direct externally owned LP donation is tested across four bindings and both policies.', ['test_deployedFundedChildHasActualReserveAndParentBinding', 'test_firstBondActivatesCustodyAndFundsActualStakingEscrow', 'test_externallyOwnedLpDonationTransfersWholePositionWithoutStakingIssuance']),
    ('RedeemD15PolicyBase', 'Stake redemption is funded 1:1 and independent of reserve price gating; the existing policy fixtures retain the standard-route assertion.', ['test_D22_claimUngated']),
    ('RedeemD15', 'D32 retires pending LP redemption/rejoin and residual swaps from sDETF exits. Four common funded unstake tests are inherited by the retained concrete host/native-unit fixtures.', ['test_D15_partialThenFullUnstakeUsesOnlyFundedBacking', 'test_D15_unstakeDoesNotRequireProtocolLpInventory', 'test_D15_unstakePreservesOtherBondPrincipalAndGons', 'test_D15_unstakeSettlesAllDueFundedExpansionFirst']),
    ('ClaimOpenBase', 'Linear vesting replaces maturity-only selling; rewards remain claimable while locked and all payouts are funded sDETF.', ['test_claimRewards_whileLocked', 'test_postMaturity_claimPaysFundedStaking', 'test_preMaturity_principalVestsLinearly']),
    ('UniswapV4Detf_Close', 'Owner-approved mature-close retirement replaces basket liquidation with funded claims followed by optional standard unstaking. Holder/operator/recipient and prior-inventory controls remain.', ['test_T7_12_matureClaimAndUnstakePreserveReserveLp', 'test_E6_fundedClaim_doesNotPayPriorSettlementInventory', 'test_fundedClaim_currentHolderCanChooseRecipient', 'test_fundedClaim_rejectsFormerHolder', 'test_fundedClaim_rejectsUnrelatedCaller']),
    ('UniswapV4Detf_Deploy', 'Owner-approved removal of closeRouteMode/closeRoutes retires obsolete close-array validation; malformed legacy deployment payloads now fail canonical decoding.', ['test_deploymentRejectsNoncanonicalPayload']),
    ('UniswapV4Detf_IoTables', 'Owner-approved close-route removal preserves protocol LP on funded claims. The former FoT test contained only return; it was a product-law placeholder, not exercised coverage. Existing short-delivery/trust-flag regressions remain.', ['test_T7_11_fundedClaim_retainsProtocolLp', 'test_T_NEST_2_nestedShort_hostRevertsTransferDeltaInsufficient', 'test_I2_mint_pretransferred_claimedGtDelta_reverts']),
    ('UniswapV4Detf_Quad.t.sol', 'Quad basket close is replaced by funded claims that retain the entire reserve, including all distinct legs.', ['test_T8_3_fundedClaim_retainsWholeReserve']),
    ('_Policy.t.sol', 'Redundant concrete overrides are removed; the same policy tests now run through the inherited common base and real host setup. New shared tests verify actual supply-neutral fallback and catch-up ordering.', ['test_policy_mint_blocked_in_deadband_then_allowed_after_push', 'test_policy_burn_allowed_when_synthetic_below_burnThreshold', 'test_D31_3_policyBurn_realizesThenGates', 'test_standardMintAndBurnFallbackMatchActualSwapWithoutIssuance', 'test_standardFallbackSettlesFundedCatchupBeforeBothDirections']),
    ('ReserveDonationBase', 'DN3 now transfers actual external LP across all four reserves and both policies. DN15 conversion invariance is superseded by fixed principal and funded stake conservation in DN1; no bond LP conversion remains.', ['test_externallyOwnedLpDonationTransfersWholePositionWithoutStakingIssuance', 'test_DN1_donate_pair_Ogt0_unassignedLp']),
    ('ERC4626StandardExchange_TransitionQuote.t.sol', 'Supported canonical virtual-balance projection replaces capability rejection, preserving existing ERC4626 composition without a deployment allowlist.', ['test_transitionCapability_projectsCanonicalVirtualUnderlying']),
]

fork_moves = {row['source']: row for row in json.loads((art / 'misplaced-fork-test-inventory.json').read_text())['rows']}
position_migrations = {row['source']: row for row in json.loads(
    (art / 'position-fixture-case-migration-map.json').read_text())['rows']}
explicit_migrations = {}
for record_name in ('stata-test-consolidation.json', 'balancer-se-smoke-consolidation-map.json',
                    'source-presence-consolidation-map.json', 'orbital-donation-consolidation-map.json'):
    payload = json.loads((art / record_name).read_text())
    for row in payload.get('rows', payload.get('retirements', [])):
        source = row.get('source', row.get('old_source'))
        retired = row.get('retired_local_overrides', [row.get('retired', row.get('old_function'))])
        replacement_source = row.get('replacement_source', row.get('current_source'))
        replacement_functions = row.get('replacement_functions', row.get('current_inherited_tests',
            [row.get('replacement_function')]))
        assert source and replacement_source and all(retired) and all(replacement_functions), row
        anchors = []
        for name in replacement_functions:
            locations = [location for location in index.get(name, []) if location['source'] == replacement_source]
            assert locations, (record_name, replacement_source, name)
            anchors.append({'function': name, 'locations': locations})
        for name in retired:
            explicit_migrations.setdefault(source, {})[name] = {
                'record': record_name, 'current_test_anchors': anchors,
                'disposition': row.get('reason', row.get('behavior',
                    'Retain the route, fee, custody or rewards assertion on the actual production fixture.')),
            }
record_name = 'obsolete-common-ledger-test-consolidation.json'
for row in json.loads((art / record_name).read_text())['retirements']:
    anchors = []
    for replacement in row['current_test_anchors']:
        locations = [location for location in index.get(replacement['function'], [])
                     if location['source'] == replacement['source']]
        assert locations, (record_name, replacement)
        anchors.append({'function': replacement['function'], 'locations': locations})
    explicit_migrations.setdefault(row['old_source'], {})[row['old_function']] = {
        'record': record_name, 'current_test_anchors': anchors, 'disposition': row['reason'],
    }
rows = []
for old in inventory['rows']:
    if old['scope'] != 'IN_SCOPE_OR_SHARED_DEPENDENCY' or not old['no_longer_declared_here']:
        continue
    path = old['path']
    explicit = explicit_migrations.get(path, {})
    if all(name in explicit for name in old['no_longer_declared_here']):
        rows.append({'path': path, 'retired_declarations': old['no_longer_declared_here'],
                     'disposition': 'Explicit declaration-level mapping; runtime evidence remains separately required.',
                     'declaration_mapping': {name: explicit[name] for name in old['no_longer_declared_here']}})
        continue
    if path in fork_moves:
        destination = fork_moves[path]['proposed_destination']
        assert (root / destination).is_file()
        rows.append({'path': path, 'retired_declarations': old['no_longer_declared_here'],
                     'disposition': 'Identical network-test source retained in the canonical fork profile tree.',
                     'current_sources': [destination], 'record': 'misplaced-fork-test-inventory.json'})
        continue
    migrated = position_migrations.get(path, {}).get('removed_or_renamed_cases', {})
    if all(name in migrated for name in old['no_longer_declared_here']):
        mapping = {name: migrated[name] for name in old['no_longer_declared_here']}
        anchors = []
        for name in sorted(set(mapping.values())):
            locations = [location for location in index[name] if location['source'] == path]
            assert locations, (path, name)
            anchors.append({'function': name, 'locations': locations})
        rows.append({'path': path, 'retired_declarations': old['no_longer_declared_here'],
                     'disposition': 'D57-D59 require both initial assets. Retained positive controls use dual activation or subsequent single inputs; one-token initial previews now reject. Donation protection remains. Equivalent V4 initial execution/preview setups are consolidated into two directional cases without dropping either assertion or decimal leaves.',
                     'declaration_mapping': mapping, 'current_test_anchors': anchors,
                     'record': 'position-fixture-case-migration-map.json'})
        continue
    group = next((group for group in groups if group[0] in Path(path).name), None)
    if group is None:
        continue
    _, reason, tests = group
    anchors = []
    for test in tests:
        assert test in index, test
        anchors.append({'function': test, 'locations': index[test]})
    rows.append({'path': path, 'retired_declarations': old['no_longer_declared_here'],
                 'disposition': reason, 'current_test_anchors': anchors})

report = {'recorded_at_utc': datetime.now(timezone.utc).isoformat(),
          'status': 'REVIEWED_SOURCE_REPLACEMENTS_RUNTIME_VALIDATION_SEPARATE',
          'note': 'This supplements existing consolidation mappings. A source mapping does not prove test execution or speedup. Historical names may remain on migrated tests, whose bodies implement the new requirements. D60/D66 exclusions are unchanged.',
          'approval': 'v4-close-cleanup-owner-approval.json', 'rows': rows}
(art / 'retired-test-anchor-consolidation.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps({'mapped_sources': len(rows), 'retired_declarations': sum(len(row['retired_declarations']) for row in rows)}))
