"""Complete prepared Stata test consolidation; canonical Solidity stays frozen."""
from pathlib import Path
from datetime import datetime, timezone
import difflib, hashlib, json, re

art = Path(__file__).resolve().parent
root = art.parent.parent
record_path = art / 'stata-hermetic-followups-prepared.json'
record = json.loads(record_path.read_text())
assert record['status'] == 'PREPARED_NOT_APPLIED'
assert not record.get('consolidation_completed'), 'Preserve the prepared revision.'
real = 'test/foundry/spec/protocol/lending/aave/v3.6/decimals/AaveV3StataStandardExchange_Real_Decimals.sol'
row = next(row for row in record['changes'] if row['path'] == real)
draft = root / row['draft']
s = draft.read_text()
s = s.replace('import {IERC20}', '''import {PullRewardsTransferStrategy, ITransferStrategyBase} from
    "@crane/contracts/protocols/lending/aave/v3.6/rewards/transfer-strategies/PullRewardsTransferStrategy.sol";
import {RewardsDataTypes} from "@crane/contracts/protocols/lending/aave/v3.6/rewards/libraries/RewardsDataTypes.sol";
import {AggregatorInterface} from "@crane/contracts/protocols/oracles/chainlink/AggregatorInterface.sol";
import {MockAggregator} from "@crane/contracts/protocols/lending/aave/v3.6/utils/mocks/oracle/CLAggregators/MockAggregator.sol";
import {IERC20}''', 1)
start = s.index('    /// @dev Rewards: real Crane Stata hermetic')
s = s[:start] + '''    /// @notice Reward forwarding uses an actually funded Aave emission campaign.
    function test_Real_RewardsForwarded() public {
        PullRewardsTransferStrategy strategy = new PullRewardsTransferStrategy(
            report.rewardsControllerProxy, EMISSION_ADMIN, EMISSION_ADMIN
        );
        vm.prank(poolAdmin);
        contracts.emissionManager.setEmissionAdmin(rewardToken, EMISSION_ADMIN);
        RewardsDataTypes.RewardsConfigInput[] memory config = new RewardsDataTypes.RewardsConfigInput[](1);
        config[0] = RewardsDataTypes.RewardsConfigInput(
            uint88(1 ether), 0, uint32(block.timestamp + 2 hours), aToken, rewardToken,
            ITransferStrategyBase(address(strategy)), AggregatorInterface(address(new MockAggregator(int256(1e8))))
        );
        vm.prank(EMISSION_ADMIN);
        contracts.emissionManager.configureAssets(config);
        deal(rewardToken, EMISSION_ADMIN, 7200 ether, true);
        vm.prank(EMISSION_ADMIN);
        IERC20(rewardToken).approve(address(strategy), 7200 ether);

        _assertFundedMintFee(_u(10), 0);
        vm.warp(block.timestamp + 60);
        uint256 expected = stataTokenV2.getClaimableRewards(realVault, rewardToken);
        assertGt(expected, 0, "funded reward accrued");
        address collector = address(indexedexManager.feeTo());
        uint256 beforeReward = IERC20(rewardToken).balanceOf(collector);
        _assertFundedMintFee(_u(1), 0);
        assertEq(IERC20(rewardToken).balanceOf(collector) - beforeReward, expected, "actual reward forwarded");
        assertEq(stataTokenV2.getClaimableRewards(realVault, rewardToken), 0, "no second reward claim");
        assertEq(IERC20(rewardToken).balanceOf(realVault), 0, "no stranded SE rewards");
    }

    /// @notice Registry deployment reuses the deterministic instance and its configured receipt.
    function test_Real_MarkerAndDeployment() public {
        assertEq(IAaveV3StataStandardVault(realVault).stataToken(), realStata);
        assertEq(_deployStataVault(realStata), realVault, "deterministic registered instance");
        assertGt(realVault.code.length, 0, "deployed proxy");
    }

    /// @notice Preserve the former mocked receipt-pretransfer fuzz case with actual Stata custody.
    function testFuzz_Real_StataToSE_Pretransferred(uint256 amount) public {
        amount = bound(amount, _u(1), _u(100));
        uint256 receipt = _acquireStata(address(this), amount);
        uint256 expected = IStandardExchangeIn(realVault).previewExchangeIn(IERC20(realStata), receipt, IERC20(realVault));
        IERC20(realStata).transfer(realVault, receipt);
        uint256 out = IStandardExchangeIn(realVault).exchangeIn(
            IERC20(realStata), receipt, IERC20(realVault), expected, address(this), true, _deadline()
        );
        assertEq(out, expected, "prepaid receipt quote/execution");
        assertEq(IERC20(realStata).balanceOf(realVault), receipt, "actual prepaid custody");
        assertEq(IERC20(realVault).balanceOf(address(this)), out, "received SE shares");
    }

    /// @notice Preserve direct base-to-Stata fuzzing without a fake post-call mint.
    function testFuzz_Real_BaseToStata(uint256 amount) public {
        amount = bound(amount, _u(1), _u(100));
        _fundUnderlying(amount, address(this));
        IERC20(realBase).approve(realVault, amount);
        uint256 expected = stataTokenV2.previewDeposit(amount);
        uint256 beforeReceipt = IERC20(realStata).balanceOf(address(this));
        assertEq(IStandardExchangeIn(realVault).previewExchangeIn(IERC20(realBase), amount, IERC20(realStata)), expected);
        uint256 out = IStandardExchangeIn(realVault).exchangeIn(
            IERC20(realBase), amount, IERC20(realStata), expected, address(this), false, _deadline()
        );
        assertEq(out, expected);
        assertEq(IERC20(realStata).balanceOf(address(this)) - beforeReceipt, out);
        assertEq(IERC20(realVault).totalSupply(), 0, "direct route mints no SE shares");
    }
}
'''
draft.write_text(s)
row['after_sha256'] = hashlib.sha256(s.encode()).hexdigest()
row['declared_tests_after'] = re.findall(r'\bfunction\s+(test\w+)\s*\(', s)

mock_path = 'test/foundry/spec/protocol/lending/aave/v3.6/AaveV3StataStandardExchange.t.sol'
before = (root / mock_path).read_text()
retired = re.findall(r'\bfunction\s+(test\w+)\s*\(', before)
mapping = {
 'test_MarkerInterface':'test_Real_MarkerAndDeployment',
 'test_DeploymentPaths':'test_Real_MarkerAndDeployment',
 'test_Route_BaseToSE':'test_Real_Route_BaseToSE_PreviewMatches',
 'test_Route_StataToSE':'test_Real_Route_StataToSE',
 'test_FeeOnAndOff':'test_Real_FeeOnAndOff',
 'test_RewardsForwarded':'test_Real_RewardsForwarded',
 'test_AllRoutesSmoke':'test_Real_Route_BaseToSE_PreviewMatches',
 'test_FeeApplicationAndMarker':'test_Real_FeeApplicationAndMarker',
 'test_RewardCollectionTrigger':'test_Real_RewardsForwarded',
 'test_Route_SEToStata':'test_Real_Route_SEToStata_PreviewMatches',
 'test_Route_SEToBase':'test_Real_Route_SEToBase_PreviewMatches',
 'test_Route_BaseToStata':'test_Real_Route_BaseToStata',
 'test_Route_BaseToStata_Pretransferred':'test_Real_Route_BaseToStata_Pretransferred',
 'test_Route_BaseToStata_Pretransferred_bookedInventory_reverts':'test_Real_Route_BaseToStata_Pretransferred_bookedInventory_reverts',
 'test_Route_ATokenToStata':'test_Real_Route_ATokenToStata',
 'test_Route_ATokenToSE':'test_Real_Route_ATokenToSE',
 'test_Route_SEToStata_Pretransferred':'testFuzz_Real_SEToStata_Pretransferred',
 'test_Route_SEToBase_Pretransferred':'test_Real_Route_SEToBase_Pretransferred',
 'test_Route_SEToAToken':'test_Real_Route_SEToAToken',
 'testFuzz_Route_BaseToSE':'testFuzz_Real_BaseToSE',
 'testFuzz_Route_StataToSE_Pretransferred':'testFuzz_Real_StataToSE_Pretransferred',
 'testFuzz_Route_BaseToStata':'testFuzz_Real_BaseToStata',
 'testFuzz_Route_SEToStata':'testFuzz_Real_SEToStata',
 'testFuzz_FeeApplication':'testFuzz_Real_FeeOnBaseToSE',
}
assert set(mapping) == set(retired)
assert set(mapping.values()).issubset(row['declared_tests_after'])
text = '''// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

// The former mocked product fixture is consolidated into actual Crane Stata
// coverage in AaveV3StataStandardExchange_Real.t.sol and its 6/9-decimal leaves.
// All 24 retired declarations are mapped in
// implementation-artifacts/detf-funded-staking/stata-test-consolidation.json.
// This source intentionally declares no duplicate executable suite.
'''
dest = art / 'stata-hermetic-followup-drafts' / (Path(mock_path).name + '.txt')
assert not dest.exists()
dest.write_text(text)
record['changes'].append(dict(path=mock_path,draft=str(dest.relative_to(root)),
    reason='Retire the duplicate mocked product suite after mapping every declaration to actual-protocol coverage; preserve this navigation pointer.',
    before_sha256=hashlib.sha256(before.encode()).hexdigest(),after_sha256=hashlib.sha256(text.encode()).hexdigest(),
    declared_tests_before=retired,declared_tests_after=[]))
consolidation = {'status':'PREPARED_NOT_APPLIED','rows':[],'runtime_validation_passed':False}
for change in record['changes']:
    removed = set(change['declared_tests_before']) - set(change['declared_tests_after'])
    for name in sorted(removed):
        if change['path'] == mock_path:
            target, replacement = real, mapping[name]
        elif '/adversarial/' in change['path']:
            target = 'test/foundry/spec/protocol/lending/aave/v3.6/decimals/Adversarial_AaveV3StataSE_SecurePull_Decimals.sol'
            replacement = name.removesuffix('Delta0') if name.endswith('Delta0') else name
        else:
            target = real
            replacement = 'test_Real_RewardsForwarded' if name == 'test_Real_RewardsForwarded_NA' else name
        target_change = next(row for row in record['changes'] if row['path'] == target)
        assert replacement in target_change['declared_tests_after'], (name,replacement)
        consolidation['rows'].append(dict(source=change['path'],retired=name,replacement_source=target,replacement_function=replacement))
(art / 'stata-test-consolidation.json').write_text(json.dumps(consolidation,indent=2)+'\n')
record['consolidation_completed'] = True
record['prepared_updated_at_utc'] = datetime.now(timezone.utc).isoformat()
record['remaining'] = ['Review/typecheck prepared fixtures; run actual affected Stata and native SY tests after the full active sequence exits.',
    'Resolve remaining actual repository failures and refresh final build/test, acceptance and deployment evidence.']
record['consolidation_record'] = 'stata-test-consolidation.json'
record_path.write_text(json.dumps(record,indent=2)+'\n')
patch = []
for change in record['changes']:
    before = (root/change['path']).read_text()
    assert hashlib.sha256(before.encode()).hexdigest() == change['before_sha256']
    after = (root/change['draft']).read_text()
    patch.extend(difflib.unified_diff(before.splitlines(True),after.splitlines(True),fromfile=change['path'],tofile=change['path']))
(art/'stata-hermetic-followups.patch').write_text(''.join(patch))
print(json.dumps({'draft_sources':len(record['changes']),'mapped_retired_declarations':len(consolidation['rows']),
    'common_real_cases':len(row['declared_tests_after']),'canonical_sources_changed':0,'validation_passed':False}))
