// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IUniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {TestBase_UniswapV4Detf_Weighted} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Weighted.sol";

/// @notice T8.2 Weighted: creationPairPerDetfWad.length == n-1; Custom mint one pair.
///         T8.4 H8: mint allowed on pair A and not B.
contract UniswapV4Detf_Weighted is TestBase_UniswapV4Detf_Weighted {
    function test_T8_2_creationLength_eq_nMinusOne() public view {
        assertEq(detfInfo.creationPairPerDetfWad().length, 2, "n-1 for n=3");
        assertTrue(address(detfPkg) != address(0), "same unified pkg");
    }

    function test_T8_2_customMint_onePairOnly() public {
        IUniswapV4Detf.PkgArgs memory args = _customMintPair0Args();
        address customDetf = _deployWeightedHookThenDetf(args);
        IUniswapV4Detf info = IUniswapV4Detf(customDetf);
        IUniswapV4Detf.IoRoute[] memory mint_ = info.mintRoutes();
        assertEq(mint_.length, 1, "custom mint one row");
        assertEq(address(mint_[0].token), address(pair0), "pair0 only");
    }

    function test_T8_2_firstBond_thenMintPair0() public {
        _firstBond(80 ether);
        vm.startPrank(detfUser);
        uint256 out_ = detfInfo.mint(
            IERC20(address(pair0)),
            8 ether,
            0,
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertGt(out_, 0, "mint pair0");
        _assertNoJoinableDust();
    }

    function test_T8_4_mintAllowed_pairA_not_pairB() public {
        IUniswapV4Detf.PkgArgs memory args = _customMintPair0Args();
        args.symbol = "wH8";
        address customDetf = _deployWeightedHookThenDetf(args);
        IUniswapV4Detf info = IUniswapV4Detf(customDetf);
        vm.startPrank(detfUser);
        IERC20(address(pair0)).approve(customDetf, type(uint256).max);
        IERC20(address(pair1)).approve(customDetf, type(uint256).max);
        info.bond(
            IERC20(address(pair0)),
            80 ether,
            DEFAULT_MIN_LOCK,
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
        assertTrue(info.isMintingAllowed(IERC20(address(pair0))), "A mintable");
        assertFalse(info.isMintingAllowed(IERC20(address(pair1))), "B not on mintRoutes");
    }
}
