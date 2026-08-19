// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IMultiStepOwnable} from "@crane/contracts/interfaces/IMultiStepOwnable.sol";
import {
    TestBase_UniswapV4SingleStandardExchangeDETF as TestBase
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeDETF.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHook.sol";

/// @notice Stage E: DETF-deployed CP reserve hook is owner-only LP; owner is the DETF diamond.
contract UniswapV4SingleStandardExchangeDETF_OwnerOnlyLiquidity_Test is TestBase {
    function test_reserveHook_ownerIsDetf() public view {
        address hook_ = detfInfo.reserveHook();
        assertEq(IMultiStepOwnable(hook_).owner(), detf);
    }

    function test_reserveHook_thirdPartyAddReverts() public {
        IHook h = IHook(detfInfo.reserveHook());
        uint256 a0 = 1 ether;
        uint256 a1 = 1 ether;
        vm.prank(detfUser);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, detfUser));
        h.deposit(a0, a1, detfUser, 0, block.timestamp + 1 hours);
    }
}
