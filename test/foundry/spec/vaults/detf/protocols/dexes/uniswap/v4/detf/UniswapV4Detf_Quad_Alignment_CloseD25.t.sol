// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {TestBase_UniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Quad} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Quad.sol";
import {UniswapV4Detf_Alignment_CloseD25Base} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Alignment_CloseD25Base.sol";

/// @notice Quad gold D25 close alignment (WP-UDPL-QD).
/// @dev Quad `tokens()` is address-sorted so DETF may not be index 0. Bodies match CloseD25OpenBase
///      except D25-1/D25-4 locate the DETF slot.
contract UniswapV4Detf_Quad_Alignment_CloseD25 is
    TestBase_UniswapV4Detf_Quad,
    UniswapV4Detf_Alignment_CloseD25Base
{
    function setUp() public override(TestBase_UniswapV4Detf_Quad, TestBase_UniswapV4Detf) {
        TestBase_UniswapV4Detf_Quad.setUp();
    }

    function _firstBond(uint256 pairAmount_)
        internal
        override(TestBase_UniswapV4Detf_Quad, TestBase_UniswapV4Detf)
        returns (uint256 tokenId, uint256 shares)
    {
        return TestBase_UniswapV4Detf_Quad._firstBond(pairAmount_);
    }

    function _assertNoJoinableDust()
        internal
        view
        override(TestBase_UniswapV4Detf_Quad, TestBase_UniswapV4Detf)
    {
        TestBase_UniswapV4Detf_Quad._assertNoJoinableDust();
    }

    function _bondAs(address bonder_, uint256 pairAmount_)
        internal
        override
        returns (uint256 tokenId_, uint256 shares_)
    {
        pair0.mint(bonder_, pairAmount_);
        pair1.mint(bonder_, pairAmount_);
        pair2.mint(bonder_, pairAmount_);
        vm.startPrank(bonder_);
        pair0.approve(detf, type(uint256).max);
        pair1.approve(detf, type(uint256).max);
        pair2.approve(detf, type(uint256).max);
        IERC20(se0).approve(detf, type(uint256).max);
        IERC20(se1).approve(detf, type(uint256).max);
        IERC20(se2).approve(detf, type(uint256).max);
        (tokenId_, shares_) = detfInfo.bond(
            IERC20(address(pairToken)),
            pairAmount_,
            DEFAULT_MIN_LOCK,
            bonder_,
            false,
            _deadline()
        );
        vm.stopPrank();
    }

    function _detfIndex(address[] memory toks_) internal view returns (uint256 idx) {
        for (uint256 i; i < toks_.length; ++i) {
            if (toks_[i] == detf) return i;
        }
        revert("no DETF in tokens()");
    }

    function test_D25_1_userDetfOnlyFromClaimRewards() public {
        (, uint256 bobId_) = _liveAliceBob();
        IERC20 detfToken_ = IERC20(detf);
        uint256 pending_ = _nft().pendingRewards(bobId_);
        uint256 detfBeforeClaim_ = detfToken_.balanceOf(d25Bob);
        uint256 claimed_ = _claimRewardsAs(d25Bob, bobId_);
        assertApproxEqAbs(claimed_, pending_, 1, "D25-1 claimed==pending");
        assertEq(detfToken_.balanceOf(d25Bob) - detfBeforeClaim_, claimed_, "D25-1 DETF from claimRewards");
        uint256 detfAfterClaim_ = detfToken_.balanceOf(d25Bob);
        uint256[] memory out_ = _closeAs(d25Bob, bobId_);
        address[] memory toks_ = IUniswapV4SeBufferHook(detfInfo.hook()).tokens();
        assertEq(out_[_detfIndex(toks_)], 0, "D25-1 DETF slot unpaid");
        assertEq(detfToken_.balanceOf(d25Bob), detfAfterClaim_, "D25-1 close does not pay DETF");
        assertEq(detfToken_.balanceOf(detf), 0, "D25-1 diamond DETF 0");
    }

    function test_D25_2_withdrawnDetfNotBurned() public {
        _assert_D25_2_withdrawnDetfNotBurned();
    }

    function test_D25_3_id0OriginalSharesRise() public {
        _assert_D25_3_id0OriginalSharesRise();
    }

    function test_D25_4_userReceivesNonDetfBasket() public {
        (, uint256 bobId_) = _liveAliceBob();
        address[] memory toks_ = IUniswapV4SeBufferHook(detfInfo.hook()).tokens();
        uint256 detfIdx_ = _detfIndex(toks_);
        uint256 pairBefore_ = pairToken.balanceOf(d25Bob);
        uint256[] memory out_ = _closeAs(d25Bob, bobId_);
        assertEq(out_.length, toks_.length, "tokens() order");
        assertEq(out_[detfIdx_], 0, "DETF slot unpaid");
        uint256 pairPaid_;
        for (uint256 i; i < toks_.length; ++i) {
            if (toks_[i] == address(pairToken)) pairPaid_ = out_[i];
        }
        assertGt(pairPaid_, 0, "pair basket");
        assertEq(pairToken.balanceOf(d25Bob) - pairBefore_, pairPaid_, "pair paid");
        assertEq(IERC20(detf).balanceOf(detf), 0, "diamond DETF 0");
    }

    function test_D25_5_ids1and2CannotClose() public {
        _assert_D25_5_ids1and2CannotClose();
    }

    function test_D25_6_previewEqualsExecute() public {
        _assert_D25_6_previewEqualsExecute();
    }

    function test_D25_7_minRejoinLpOutGt0() public {
        _assert_D25_7_minRejoinLpOutGt0();
    }

    function test_D25_lastClose_feeCreatorPendingDoesNotJump() public {
        _assert_D25_lastClose_feeCreatorPendingDoesNotJump();
    }
}
