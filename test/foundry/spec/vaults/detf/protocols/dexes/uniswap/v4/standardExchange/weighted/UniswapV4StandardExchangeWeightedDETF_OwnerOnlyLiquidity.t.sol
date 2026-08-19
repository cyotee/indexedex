// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IMultiStepOwnable} from "@crane/contracts/interfaces/IMultiStepOwnable.sol";
import {
    TestBase_UniswapV4StandardExchangeWeightedDETF as TestBase
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/TestBase_UniswapV4StandardExchangeWeightedDETF.sol";
import {
    IUniswapV4StandardExchangeWeightedBufferHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHook.sol";
/// @notice Stage E: DETF-deployed weighted reserve hook is owner-only LP; owner is the DETF diamond.
contract UniswapV4StandardExchangeWeightedDETF_OwnerOnlyLiquidity_Test is TestBase {
    function test_reserveHook_ownerIsDetf() public view {
        assertEq(IMultiStepOwnable(detfInfo.reserveHook()).owner(), detf);
    }

    function test_reserveHook_thirdPartyAddReverts() public {
        IHook h = IHook(detfInfo.reserveHook());
        uint256 n = h.numTokens();
        uint256[] memory amounts = new uint256[](n);
        for (uint256 i; i < n; ++i) {
            amounts[i] = 1 ether;
        }
        vm.prank(detfUser);
        vm.expectRevert(abi.encodeWithSelector(IMultiStepOwnable.NotOwner.selector, detfUser));
        h.joinProportional(amounts, detfUser, 0, block.timestamp + 1 days);
    }
}
