// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_UniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Orbital} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Orbital.sol";
import {UniswapV4Detf_Alignment_CloseD25OpenBase} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_Alignment_CloseD25OpenBase.sol";

/// @notice Orbital gold D25 close alignment (WP-UDPL-OR).
contract UniswapV4Detf_Orbital_Alignment_CloseD25 is
    TestBase_UniswapV4Detf_Orbital,
    UniswapV4Detf_Alignment_CloseD25OpenBase
{
    function setUp() public override(TestBase_UniswapV4Detf_Orbital, TestBase_UniswapV4Detf) {
        TestBase_UniswapV4Detf_Orbital.setUp();
        address alice_ = makeAddr("d25alice");
        address bob_ = makeAddr("d25bob");
        pair1.mint(alice_, 10_000_000 ether);
        pair1.mint(bob_, 10_000_000 ether);
        vm.prank(alice_);
        pair1.approve(detf, type(uint256).max);
        vm.prank(bob_);
        pair1.approve(detf, type(uint256).max);
    }

    function _firstBond(uint256 pairAmount_)
        internal
        override(TestBase_UniswapV4Detf, TestBase_UniswapV4Detf_Orbital)
        returns (uint256 tokenId, uint256 shares)
    {
        return TestBase_UniswapV4Detf_Orbital._firstBond(pairAmount_);
    }

    function _assertNoJoinableDust()
        internal
        view
        override(TestBase_UniswapV4Detf, TestBase_UniswapV4Detf_Orbital)
    {
        TestBase_UniswapV4Detf_Orbital._assertNoJoinableDust();
    }
}
