// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {UniswapV4StandardExchangeOrbitalBufferHookMath as HookMath} from
    "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookMath.sol";
import {OrbitalRawLiquidityRef as Ref} from "./rawLiquidity/OrbitalRawLiquidityRef.sol";

/// @notice Helper arithmetic. These vectors are not claimed to be reachable deployed states.
contract UniswapV4StandardExchangeOrbitalBufferHook_RawLiquidityConversionsTest is Test {
    function test_illustrative_rawEight_ratedFloorsNine() public pure {
        uint256 supply = 12;
        uint256 held = 3;
        uint256 contributed = 2;
        uint256 rate = 1.5e18;
        uint256 rawMint = Ref.floorShares(supply, contributed, held);
        uint256 ratedHeld = held * rate / 1e18;
        uint256 ratedIn = contributed * rate / 1e18;
        uint256 ratedMint = supply * ratedIn / ratedHeld;
        assertEq(rawMint, 8);
        assertEq(ratedMint, 9);
        assertEq(HookMath.rawLegFloorShares(supply, contributed, held), rawMint);
    }

    function test_ceilBacking_notFloorPull() public pure {
        uint256 supply = 10;
        uint256 held = 3;
        uint256 contributed = 1;
        uint256 minted = Ref.floorShares(supply, contributed, held);
        assertEq(minted, 3);
        uint256 floored = minted * held / supply;
        uint256 required = Ref.ceilRequired(minted, held, supply);
        assertEq(floored, 0);
        assertEq(required, 1);
        assertTrue(Ref.backs(required, supply, minted, held));
        assertFalse(Ref.backs(floored, supply, minted, held));
        assertEq(HookMath.rawRequiredInventory(minted, held, supply), required);
    }

    function test_rawFullBook_minLeg_andZeroConversion() public pure {
        uint256 minted = Ref.min3(
            Ref.floorShares(100, 40, 80),
            Ref.floorShares(100, 10, 50),
            Ref.floorShares(100, 25, 25)
        );
        assertEq(minted, Ref.floorShares(100, 10, 50));
        assertEq(HookMath.rawFullBookShares(100, 40, 80, 10, 50, 25, 25), minted);
        assertEq(HookMath.rawFullBookShares(100, 0, 80, 10, 50, 25, 25), 0);
    }

    function test_overflowingProduct_revertsRatherThanWrapping() public {
        vm.expectRevert();
        this.externalOverflow();
    }

    function externalOverflow() external pure {
        HookMath.rawLegFloorShares(type(uint256).max, type(uint256).max, 2);
    }
}
