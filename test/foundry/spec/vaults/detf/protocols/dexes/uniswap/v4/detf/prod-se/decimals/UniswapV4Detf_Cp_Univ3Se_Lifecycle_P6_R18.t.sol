// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {UniswapV4DetfRepo} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfRepo.sol";
import {UniswapV4Detf_Cp_Univ3Se_Lifecycle_Decimals} from
    "test/foundry/spec/vaults/detf/protocols/dexes/uniswap/v4/detf/prod-se/decimals/UniswapV4Detf_Cp_Univ3Se_Lifecycle_Decimals.sol";

/// @notice Combo `P6_R18`. pairToken/pair0 6-dec; other/rate 18-dec; remaining 18. SE shares retain their existing decimals; DETF and sDETF use 9. Bond NFTs are non-fungible.
contract UniswapV4Detf_Cp_Univ3Se_Lifecycle_P6_R18 is UniswapV4Detf_Cp_Univ3Se_Lifecycle_Decimals {
    function _pairDecimals() internal pure override returns (uint8) { return 6; }
    function _rateDecimals() internal pure override returns (uint8) { return 18; }

    function test_unrepresentableRawFirstBondPreservesCapital() public {
        uint256 pairBefore = pairToken.balanceOf(detfUser);
        uint256 seSupplyBefore = IERC20(se).totalSupply();
        vm.prank(detfUser);
        vm.expectRevert(abi.encodeWithSelector(
            UniswapV4DetfRepo.InvalidRoute.selector, address(pairToken), se
        ));
        detfInfo.bond(
            IERC20(address(pairToken)), _uPair(100), DEFAULT_MIN_LOCK,
            detfUser, false, block.timestamp + 1 hours
        );
        assertEq(pairToken.balanceOf(detfUser), pairBefore);
        assertEq(pairToken.balanceOf(detf), 0);
        assertEq(IERC20(se).balanceOf(detf), 0);
        assertEq(IERC20(se).totalSupply(), seSupplyBefore);
        assertEq(IERC20(detf).totalSupply(), 0);
        assertEq(IERC20(reserveHook).totalSupply(), 0);
        assertFalse(detfInfo.isReserveLive());
    }
}
