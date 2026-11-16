// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IMultiStepOwnable} from "@crane/contracts/interfaces/IMultiStepOwnable.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {TestBase_UniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Orbital} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Orbital.sol";
import {UniswapV4Detf_OwnerOnlyLiquidityBase} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_OwnerOnlyLiquidityBase.sol";
import {UniswapV4Detf_OwnerOnlyLiquidityOpenBase} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4Detf_OwnerOnlyLiquidityOpenBase.sol";

/// @notice Orbital gold owner-only liquidity. Third-party add uses joinSingleAssetExactIn.
contract UniswapV4Detf_Orbital_OwnerOnlyLiquidity is
    TestBase_UniswapV4Detf_Orbital,
    UniswapV4Detf_OwnerOnlyLiquidityBase,
    UniswapV4Detf_OwnerOnlyLiquidityOpenBase
{
    function setUp() public override(TestBase_UniswapV4Detf_Orbital, TestBase_UniswapV4Detf) {
        TestBase_UniswapV4Detf_Orbital.setUp();
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

    function test_reserveHook_ownerIsDetf()
        public
        view
        override(UniswapV4Detf_OwnerOnlyLiquidityBase, UniswapV4Detf_OwnerOnlyLiquidityOpenBase)
    {
        UniswapV4Detf_OwnerOnlyLiquidityOpenBase.test_reserveHook_ownerIsDetf();
    }

    function test_reserveHook_thirdPartyAddReverts()
        public
        override(UniswapV4Detf_OwnerOnlyLiquidityBase, UniswapV4Detf_OwnerOnlyLiquidityOpenBase)
    {
        vm.prank(detfUser);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, detfUser));
        IUniswapV4SeBufferHook(reserveHook).joinSingleAssetExactIn(
            address(pairToken), 1 ether, detfUser, 0, block.timestamp + 1 hours
        );
    }
}
