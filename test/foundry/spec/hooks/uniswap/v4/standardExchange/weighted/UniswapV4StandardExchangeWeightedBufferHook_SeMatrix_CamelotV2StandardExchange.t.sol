// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";

import {SeMatrixFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrixFixture.sol";
import {SeMatrix_CamelotFixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_CamelotFixture.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol";

/// @notice D20: weighted × CamelotV2StandardExchange. Face: 18-decimal pair token A of a seeded hermetic Camelot V2 pair; SE shares 27 decimals (reserve 18 + 9).
contract UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_CamelotV2StandardExchange is UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior {
    /// @dev The first fixture deploys the protocol and the SE package; later SE legs reuse both through it.
    address internal sharedFixture;

    function _seedAmmReserve() internal override {
        _seed();
        // Establish prior booked dust through real transfers and the normal
        // end-of-operation reserve sync; the initial zap can consume every unit.
        uint256 bookedBefore = fx.seBooked();
        address donor = makeAddr("Camelot prior dust donor");
        fx.fund(donor, 1);
        vm.prank(donor);
        IERC20(face).transfer(seUT, 1);
        address input = fx.otherToken();
        fx.fundOther(user, 1 ether);
        vm.startPrank(user);
        IERC20(input).approve(seUT, 1 ether);
        IStandardExchangeIn(seUT).exchangeIn(
            IERC20(input), 1 ether, IERC20(seUT), 0, user, false, block.timestamp
        );
        vm.stopPrank();
        assertGe(fx.seBooked(), bookedBefore + 1, "donated dust is booked before the isolation check");
    }

    function _newFixture() internal override returns (SeMatrixFixture) {
        SeMatrix_CamelotFixture f = new SeMatrix_CamelotFixture(_ctx(), sharedFixture);
        sharedFixture = address(f);
        return f;
    }
}
