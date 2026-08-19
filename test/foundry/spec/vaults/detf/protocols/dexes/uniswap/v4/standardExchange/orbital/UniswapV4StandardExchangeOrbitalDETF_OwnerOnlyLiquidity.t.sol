// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IMultiStepOwnable} from "@crane/contracts/interfaces/IMultiStepOwnable.sol";
import {
    TestBase_UniswapV4StandardExchangeOrbitalDETF as TestBase
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalDETF.sol";
import {
    IUniswapV4StandardExchangeOrbitalBufferHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHook.sol";
/// @notice Stage E: DETF-deployed orbital reserve hook is owner-only LP; owner is the DETF diamond.
contract UniswapV4StandardExchangeOrbitalDETF_OwnerOnlyLiquidity_Test is TestBase {
    function test_reserveHook_ownerIsDetf() public view {
        assertEq(IMultiStepOwnable(detfInfo.reserveHook()).owner(), detf);
    }

    function test_reserveHook_thirdPartyAddReverts() public {
        IHook h = IHook(detfInfo.reserveHook());
        vm.prank(detfUser);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, detfUser));
        h.addLiquidity(1 ether, 1 ether, 1 ether, detfUser, 0, block.timestamp + 1 hours, "");
    }
}
