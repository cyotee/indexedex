"""Replace obsolete LP-principal regressions with a smaller funded four-binding matrix."""
from pathlib import Path
import hashlib,json,re,sys
ROOT=Path(__file__).resolve().parents[2]; ART=Path(__file__).resolve().parent
p=ROOT/'test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_OriginalPrincipal.t.sol'
before=p.read_text(); source=(ART/'pending-v4-original-principal-base.txt').read_text()
source=source.replace('import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";','import {StakedDETFTarget} from "contracts/vaults/detf/common/claimToken/StakedDETFTarget.sol";')
source=source.replace('IStandardExchangeErrors.MinAmountNotMet.selector','StakedDETFTarget.MinimumOutputNotMet.selector')
for family in ('','_Orbital','_Weighted','_Quad'):
 source+='''
contract UniswapV4Detf'''+family+'''_OriginalPrincipal is TestBase_UniswapV4Detf'''+family+''', UniswapV4Detf_OriginalPrincipalBase {
    function _principalDetf() internal view override returns (IUniswapV4Detf) {
        return detfInfo;
    }

    function _principalEnableProtocolFees() internal override {
        vm.prank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setUsageFeeOfVault(detfInfo.hook(), 2e15);
    }

    function _principalMatureClaim(uint256 id_) internal override {
        _assertFundedMatureClaim(detf, id_, BONDER);
    }
'''
 if family=='':source+='''
    function test_P1_oneNativeUnitStakeRedeemsExactly() public {
        _principalBond(100 ether, 30 days);
        _principalDonate();
        _principalBuyRaw();
        uint256 before_ = IERC20(detf).balanceOf(BONDER);
        uint256 backing_ = _principalStaking().stakingState().accountedBacking;
        _principalAssertStake(1);
        _assertFundedUnstake(detf, BONDER, 1);
        assertEq(IERC20(detf).balanceOf(BONDER), before_, "single native unit round trip");
        assertEq(_principalStaking().stakingState().accountedBacking, backing_, "funded liability round trip");
    }

    function test_P1_zeroNativePrincipalBondRevertsAtomically() public {
        _principalBond(100 ether, 30 days);
        _principalDonate();
        IERC20 lead_ = _principalLead();
        (bool quoted_, bytes memory result_) = detf.staticcall(abi.encodeCall(IUniswapV4Detf.previewBond, (lead_, 1, 30 days)));
        if (quoted_) {
            (, uint256 principal_,,) = abi.decode(result_, (uint256, uint256, uint256, uint256));
            assertEq(principal_, 0, "sub-native purchased DETF is unrepresentable");
        }
        _principalApprovePair(1);
        uint256 payment_ = lead_.balanceOf(BONDER);
        bytes32 before_ = _principalBookHash();
        vm.prank(BONDER);
        vm.expectRevert();
        detfInfo.bond(lead_, 1, 30 days, BONDER, false, block.timestamp + 1 hours);
        assertEq(_principalBookHash(), before_, "no new zero-principal NFT, supply or LP");
        assertEq(lead_.balanceOf(BONDER), payment_, "unrepresentable bond cannot take payment");
    }
'''
 source+='}\n'
old=re.findall(r'function (test_\w+)\(',before)
mapping={
 'test_P1_laterBond_creditsOriginalPrincipal_afterDonation':'test_P1_fundedPrincipalSurvivesDonationAndLaterBond',
 'test_P1_compound_creditsOriginalPrincipal_afterDonation':'test_P1_fundedPrincipalSurvivesDonationAndLaterBond',
 'test_P1_closeRejoin_creditsOriginalPrincipal_afterDonation':'test_P1_matureClaimRetainsDonatedProtocolLiquidity',
 'test_P1_buyClaim_previewIncludesPendingProtocolFees':'test_P1_stakingQuoteIgnoresLpFeesAndUsesFundedIndex',
 'test_P1_buyClaim_previewUsesRebasingBalance':'test_P1_stakingQuoteIgnoresLpFeesAndUsesFundedIndex',
 'test_P1_buyClaim_creditsOriginalPrincipal_afterDonation':'test_P1_stakingQuoteIgnoresLpFeesAndUsesFundedIndex',
 'test_P1_buyClaim_minimum_revertsEntireOriginalCredit':'test_P1_stakeMinimumRollsBackAllFundedAccounting',
 'test_P1_tinyPrincipal_belowShareBond_revertsAtomically':'test_P1_zeroNativePrincipalBondRevertsAtomically',
 'test_P1_tinyPrincipal_belowShareClaimPurchase_revertsAtomically':'test_P1_oneNativeUnitStakeRedeemsExactly',
 'test_P1_tinyPrincipal_aboveShareBond_floorsWithoutDilution':'test_P1_fundedPrincipalSurvivesDonationAndLaterBond; test_P1_oneNativeUnitStakeRedeemsExactly',
 'test_P1_tinyPrincipal_closeRejoin_belowShareRemainsUnassigned':'test_P1_matureClaimRetainsDonatedProtocolLiquidity; existing funded staking arithmetic/escrow dust coverage',
 'test_P1_tinyPrincipal_compoundBelowShare_preservesPendingRewards':'test_P1_fundedPrincipalSurvivesDonationAndLaterBond; existing funded staking distribution conservation/dust coverage',
}
assert set(old)==set(mapping)
record={'status':'applied; validation pending' if '--apply' in sys.argv else 'prepared; Solidity unchanged','path':str(p.relative_to(ROOT)),'before_sha256':hashlib.sha256(before.encode()).hexdigest(),'after_sha256':hashlib.sha256(source.encode()).hexdigest(),'before_executable_tests':33,'after_executable_tests':18,'coverage_mapping':mapping,'reason':'D32 funded DETF and sDETF replace LP-original-share liabilities, sale-to-id0, reward-to-LP compounding, and close/rejoin. Those retired economic assertions cannot be retained as requirements. Their funding/rounding/rollback/custody intent is consolidated into four shared production-binding cases plus two native-unit CP boundaries. Existing dust/conservation coverage still requires final traceability evidence.'}
if '--apply' in sys.argv:p.write_text(source)
else:(ART/'pending-UniswapV4Detf_OriginalPrincipal.t.sol.txt').write_text(source)
(ART/('v4-original-principal-consolidation.json' if '--apply' in sys.argv else 'pending-v4-original-principal-consolidation.json')).write_text(json.dumps(record,indent=2)+'\n')
print(record['status'])
