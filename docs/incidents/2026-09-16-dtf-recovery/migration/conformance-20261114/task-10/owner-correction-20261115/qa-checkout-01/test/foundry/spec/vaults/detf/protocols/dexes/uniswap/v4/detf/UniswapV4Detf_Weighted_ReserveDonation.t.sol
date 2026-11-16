// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {TestBase_UniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Weighted} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Weighted.sol";
import {UniswapV4Detf_ReserveDonationBase} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_ReserveDonationBase.sol";
import {UniswapV4Detf_ReserveDonationOpenBase} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_ReserveDonationOpenBase.sol";

/// @notice Weighted gold donation R12a. OpenBase+Base. Weighted setUp.
contract UniswapV4Detf_Weighted_ReserveDonation is
    TestBase_UniswapV4Detf_Weighted,
    UniswapV4Detf_ReserveDonationOpenBase,
    UniswapV4Detf_ReserveDonationBase
{
    function setUp() public override(TestBase_UniswapV4Detf_Weighted, TestBase_UniswapV4Detf) {
        TestBase_UniswapV4Detf_Weighted.setUp();
    }

    function _firstBond(uint256 pairAmount_)
        internal
        override(TestBase_UniswapV4Detf, TestBase_UniswapV4Detf_Weighted)
        returns (uint256 tokenId, uint256 shares)
    {
        return TestBase_UniswapV4Detf_Weighted._firstBond(pairAmount_);
    }

    function _assertNoJoinableDust()
        internal
        view
        override(TestBase_UniswapV4Detf, TestBase_UniswapV4Detf_Weighted)
    {
        TestBase_UniswapV4Detf_Weighted._assertNoJoinableDust();
    }

    function _uniqueDetfArgs(string memory tag)
        internal
        view
        override
        returns (IUniswapV4Detf.PkgArgs memory args)
    {
        args = _nLegDetfArgs(2);
        args.name = string.concat("UniV4 DETF ", tag);
        args.symbol = string.concat("uv4", tag);
    }

    function _bondAs(address bonder_, uint256 pairAmount_)
        internal
        override
        returns (uint256 tokenId_, uint256 shares_)
    {
        _fundActor(detf, bonder_, pairAmount_ * 4);
        return super._bondAs(bonder_, pairAmount_);
    }

    function test_DN5_inert_reverts() public override {
        address inert_ = _deployWeightedHookThenDetf(_uniqueDetfArgs("dn5"));
        pairToken.mint(detfUser, 1 ether);
        vm.startPrank(detfUser);
        pairToken.approve(inert_, 1 ether);
        vm.expectRevert();
        IUniswapV4Detf(inert_).donate(IERC20(address(pairToken)), 1 ether, false);
        vm.stopPrank();
    }
}
