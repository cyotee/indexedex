// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {
    TestBase_UniswapV4SingleStandardExchangeDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/TestBase_UniswapV4SingleStandardExchangeDETF.sol";
import {
    UniswapV4SingleStandardExchangeDETFRepo as Repo
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeDETFRepo.sol";

/// @notice Phase 2: permissionless first bond → live; pre-live mint/burn blocked.
contract UniswapV4SingleStandardExchangeDETF_FirstBondTest is TestBase_UniswapV4SingleStandardExchangeDETF {
    function test_firstBond_goesLive() public {
        _assertInert();
        (uint256 tokenId, uint256 shares) = _firstBond(100 ether);
        _assertLive();
        assertGt(shares, 0, "lp principal");
        assertGt(tokenId, 0, "bond nft");
        assertGt(detfInfo.userBondedLp(), 0, "user bonded lp tracked");
        // Lazy compound after first bond is a realize path → may seed lastExpansionTimestamp.
        // Primary mint/burn still must not advance the clock (covered in MintBurn suite).
    }

    function test_preLive_mintBlocked() public {
        _assertInert();
        vm.startPrank(detfUser);
        vm.expectRevert();
        detfExchangeIn.exchangeIn(
            IERC20(address(pairToken)),
            1 ether,
            IERC20(detf),
            0,
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function test_preLive_burnBlocked() public {
        // Cannot burn without supply; still assert inert gates.
        _assertInert();
        assertFalse(detfInfo.isBurningAllowed());
    }

    function test_dust_firstBond_reverts() public {
        vm.startPrank(detfUser);
        vm.expectRevert();
        detfInfo.bond(
            IERC20(address(pairToken)),
            1, // dust
            DEFAULT_MIN_LOCK,
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
        _assertInert();
    }
}
