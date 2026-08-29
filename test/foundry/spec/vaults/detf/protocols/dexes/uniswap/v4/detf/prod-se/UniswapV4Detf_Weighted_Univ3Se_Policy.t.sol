// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {
    IUniswapV4Detf,
    IUniswapV4DetfDFPkg
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {TestBase_UniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Weighted_Univ3Se} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Weighted_Univ3Se.sol";
import {TestBase_UniswapV4Detf_Weighted_ProdSe} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Weighted_ProdSe.sol";
import {UniswapV4Detf_Stage11PolicySuite} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Stage11PolicySuite.sol";

/// @notice H_WE_GV3 Stage 11 Policy (§7.0). FC names use fixture id (R-16).
contract UniswapV4Detf_Weighted_Univ3Se_Policy is
    TestBase_UniswapV4Detf_Weighted_Univ3Se,
    UniswapV4Detf_Stage11PolicySuite
{
    function setUp()
        public
        override(TestBase_UniswapV4Detf_Weighted_Univ3Se, UniswapV4Detf_Stage11PolicySuite)
    {
        TestBase_UniswapV4Detf_Weighted_Univ3Se.setUp();
        policyCreator = makeAddr("creator");
    }

    function _firstBond(uint256 pairAmount_)
        internal
        override(TestBase_UniswapV4Detf, TestBase_UniswapV4Detf_Weighted_ProdSe)
        returns (uint256 tokenId, uint256 shares)
    {
        return TestBase_UniswapV4Detf_Weighted_ProdSe._firstBond(pairAmount_);
    }

    function _assertNoJoinableDust()
        internal
        view
        override(TestBase_UniswapV4Detf, TestBase_UniswapV4Detf_Weighted_ProdSe)
    {
        TestBase_UniswapV4Detf_Weighted_ProdSe._assertNoJoinableDust();
    }

    function _deployInstance(IUniswapV4Detf.PkgArgs memory args)
        internal
        override
        returns (address)
    {
        return _deployWeightedHookThenDetf(args);
    }

    function _baseArgs() internal override returns (IUniswapV4Detf.PkgArgs memory) {
        return _nLegDetfArgs(2);
    }

    function test_FC1_univ4Detf_H_WE_GV3_feeToAndCreatorCanClaim() public { _assertFC1(); }
    function test_FC2_univ4Detf_H_WE_GV3_claimEqualsPendingAndBalance() public { _assertFC2(); }
    function test_FC3_univ4Detf_H_WE_GV3_dueAmountsFloor() public { _assertFC3(); }
    function test_FC4_univ4Detf_H_WE_GV3_newSharesDoNotClaimOldPot() public { _assertFC4(); }
    function test_FC5_univ4Detf_H_WE_GV3_newPotAtNewWeights() public { _assertFC5(); }
    function test_FC6_univ4Detf_H_WE_GV3_secondClaimZero() public { _assertFC6(); }
    function test_FC7_univ4Detf_H_WE_GV3_nonOwnerCannotClaim() public { _assertFC7(); }
    function test_FC8_univ4Detf_H_WE_GV3_ids1and2CannotSellOrClose() public { _assertFC8(); }
    function test_FC9_univ4Detf_H_WE_GV3_d2NoOriginalShares() public { _assertFC9(); }
    function test_FC10_univ4Detf_H_WE_GV3_feeToChangeDoesNotMoveId1() public { _assertFC10(); }
    function test_FC11_univ4Detf_H_WE_GV3_creatorZeroFeeToOwnsBoth() public { _assertFC11(); }
    function test_FC12_univ4Detf_H_WE_GV3_conservationTwoWaves() public { _assertFC12(); }

    function test_T6_openingLengthMismatch_reverts() public {
        IUniswapV4Detf.PkgArgs memory args = _nLegDetfArgs(2);
        args.name = "BadOpenLen Wgt S11";
        args.symbol = "bOLWS11";
        args.openingPairPerDetfWad = new uint256[](1);
        args.openingPairPerDetfWad[0] = LAUNCH_RICH_START;
        vm.expectRevert(IUniswapV4DetfDFPkg.InvalidCreationRate.selector);
        this.deployInstanceExternal(args);
    }

    function deployInstanceExternal(IUniswapV4Detf.PkgArgs memory args) external {
        _deployInstance(args);
    }

    function test_T8_4_policy_pairA_not_pairB_via_trades() public {
        address d = _deployPolicyLaunchRichLive();
        IUniswapV4Detf info = IUniswapV4Detf(d);
        address[] memory toks_ = IUniswapV4SeBufferHook(info.hook()).tokens();
        address a_;
        address b_;
        for (uint256 i; i < toks_.length; ++i) {
            if (toks_[i] == d) continue;
            if (a_ == address(0)) a_ = toks_[i];
            else if (b_ == address(0) && toks_[i] != a_) b_ = toks_[i];
        }
        IERC20 pairA = IERC20(a_);
        IERC20 pairB = IERC20(b_);
        for (uint256 i; i < 96 && (info.isMintingAllowed(pairB) || !info.isMintingAllowed(pairA)); ++i) {
            try this.donateExternal(d, 50 ether) {} catch {}
            uint256 bal_ = IERC20(d).balanceOf(detfUser);
            if (bal_ == 0) break;
            uint256 push_ = bal_ > 40 ether ? 40 ether : bal_;
            vm.prank(detfUser);
            IERC20(d).transfer(d, push_);
            _ownerSwap(d, d, address(pairB), push_);
        }
        assertTrue(info.isMintingAllowed(pairA), "A mintable");
        assertFalse(info.isMintingAllowed(pairB), "B not mintable");
        vm.startPrank(detfUser);
        uint256 out_ = info.mint(pairA, LIVE_MINT_AMT, 0, detfUser, false, _deadline());
        vm.stopPrank();
        assertGt(out_, 0, "live mint A");
        vm.startPrank(detfUser);
        vm.expectRevert();
        info.mint(pairB, 1 ether, 0, detfUser, false, _deadline());
        vm.stopPrank();
    }

}
