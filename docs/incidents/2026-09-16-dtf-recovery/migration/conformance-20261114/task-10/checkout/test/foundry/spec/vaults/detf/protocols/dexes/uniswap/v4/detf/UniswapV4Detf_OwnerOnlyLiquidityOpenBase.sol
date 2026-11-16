// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IMultiStepOwnable} from "@crane/contracts/interfaces/IMultiStepOwnable.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHook.sol";
import {TestBase_UniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf.sol";

/// @notice Open-layer owner-only liquidity asserts (PRD §7.7). Stage 11 Open inherits this.
abstract contract UniswapV4Detf_OwnerOnlyLiquidityOpenBase is TestBase_UniswapV4Detf {
    function test_reserveHook_ownerIsDetf() public view virtual {
        assertEq(IMultiStepOwnable(reserveHook).owner(), detf, "hook.owner()==detf");
        assertEq(IMultiStepOwnable(detfInfo.reservePool()).owner(), detf, "reservePool owner");
    }

    function test_reserveHook_thirdPartyAddReverts() public virtual {
        IHook h = IHook(reserveHook);
        vm.prank(detfUser);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, detfUser));
        h.deposit(1 ether, 1 ether, detfUser, 0, block.timestamp + 1 hours);

        vm.prank(detfUser);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, detfUser));
        IUniswapV4SeBufferHook(reserveHook).joinSingleAssetExactIn(
            address(pairToken), 1 ether, detfUser, 0, block.timestamp + 1 hours
        );
    }
}
