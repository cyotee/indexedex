// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IMultiStepOwnable} from "@crane/contracts/interfaces/IMultiStepOwnable.sol";
import {
    TestBase_UniswapV4StandardExchangeCurveQuadStableDETF as TestBase
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/stable/quad/curve/TestBase_UniswapV4StandardExchangeCurveQuadStableDETF.sol";
import {
    IUniswapV4StandardExchangeCurveQuadStableBufferHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableBufferHook.sol";
/// @notice Stage E: DETF-deployed curve-quad reserve hook is owner-only LP; owner is the DETF diamond.
contract UniswapV4StandardExchangeCurveQuadStableDETF_OwnerOnlyLiquidity_Test is TestBase {
    function test_reserveHook_ownerIsDetf() public view {
        assertEq(IMultiStepOwnable(detfInfo.reserveHook()).owner(), detf);
    }

    function test_reserveHook_thirdPartyAddReverts() public {
        IHook h = IHook(detfInfo.reserveHook());
        uint256[] memory amounts = new uint256[](4);
        amounts[0] = 1 ether;
        amounts[1] = 1 ether;
        amounts[2] = 1 ether;
        amounts[3] = 1 ether;
        vm.prank(detfUser);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, detfUser));
        h.joinProportional(amounts, detfUser, 0, block.timestamp + 1 days);
    }
}
