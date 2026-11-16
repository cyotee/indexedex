// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {TestBase_UniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Adversarial} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Adversarial.sol";
import {TestBase_UniswapV4Detf_Quad} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Quad.sol";
import {TestBase_UniswapV4Detf_Quad_Adversarial} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Quad_Adversarial.sol";
import {Adversarial_A0Crops} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/adversarial/Adversarial_A0Crops.t.sol";

/// @notice Quad gold A0 / CROPS / F1. E6 N/A no residual-return.
contract UniswapV4Detf_Quad_Adversarial_A0Crops is
    TestBase_UniswapV4Detf_Quad_Adversarial,
    Adversarial_A0Crops
{
    function setUp()
        public
        override(TestBase_UniswapV4Detf_Quad_Adversarial, TestBase_UniswapV4Detf_Adversarial)
    {
        TestBase_UniswapV4Detf_Quad_Adversarial.setUp();
    }

    function test_firstBondMapsShareRequirementsToPairPayments() public {
        address[] memory accepted_ = detfInfo.acceptedBondTokens();
        assertEq(accepted_.length, 3);
        (address[] memory payments_, uint256[] memory amounts_) =
            detfInfo.previewFirstBondPayments(IERC20(address(pair0)), 100 ether);
        assertEq(payments_.length, 3);
        for (uint256 i_; i_ < payments_.length; ++i_) {
            assertEq(payments_[i_], accepted_[i_]);
            assertTrue(
                payments_[i_] == address(pair0) || payments_[i_] == address(pair1)
                    || payments_[i_] == address(pair2)
            );
            assertGt(amounts_[i_], 0);
        }
        uint256 leadBefore_ = pair0.balanceOf(detfUser);
        (, uint256 lp_) = _firstBond(100 ether);
        assertGt(lp_, 0);
        assertTrue(detfInfo.isReserveLive());
        assertEq(leadBefore_ - pair0.balanceOf(detfUser), 100 ether, "lead payment pulled once");
        address[3] memory pairs_ = [address(pair0), address(pair1), address(pair2)];
        address[3] memory shares_ = [se0, se1, se2];
        for (uint256 i_; i_ < 3; ++i_) {
            assertGt(IERC20(shares_[i_]).balanceOf(reserveHook), 0, "retained genesis shares");
            assertGt(IERC20(pairs_[i_]).balanceOf(reserveHook), 0, "actual genesis redemption");
            assertEq(IERC20(shares_[i_]).balanceOf(detf), 0, "no stranded caller shares");
            assertEq(IERC20(pairs_[i_]).balanceOf(detf), 0, "no stranded caller payment");
        }
    }

    function _firstBond(uint256 pairAmount_)
        internal
        override(TestBase_UniswapV4Detf_Quad_Adversarial, TestBase_UniswapV4Detf)
        returns (uint256 tokenId, uint256 shares)
    {
        return TestBase_UniswapV4Detf_Quad._firstBond(pairAmount_);
    }

    function _assertNoJoinableDust()
        internal
        view
        override(TestBase_UniswapV4Detf_Quad_Adversarial, TestBase_UniswapV4Detf)
    {
        TestBase_UniswapV4Detf_Quad._assertNoJoinableDust();
    }

    function _uniqueDetfArgs(string memory tag_)
        internal
        view
        override(TestBase_UniswapV4Detf_Quad_Adversarial, TestBase_UniswapV4Detf_Adversarial)
        returns (IUniswapV4Detf.PkgArgs memory)
    {
        return TestBase_UniswapV4Detf_Quad_Adversarial._uniqueDetfArgs(tag_);
    }

    function _approveUserForDetf(address detf_)
        internal
        override(TestBase_UniswapV4Detf_Quad_Adversarial, TestBase_UniswapV4Detf_Adversarial)
    {
        TestBase_UniswapV4Detf_Quad_Adversarial._approveUserForDetf(detf_);
    }

    function _deployHookThenDetfForPair(
        IUniswapV4Detf.PkgArgs memory args,
        address pair_,
        address se_
    )
        internal
        override(TestBase_UniswapV4Detf_Quad_Adversarial, TestBase_UniswapV4Detf_Adversarial)
        returns (address)
    {
        return TestBase_UniswapV4Detf_Quad_Adversarial._deployHookThenDetfForPair(args, pair_, se_);
    }
}
