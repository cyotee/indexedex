// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {
    TestBase_UniswapV4StandardExchangeOrbitalDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/TestBase_UniswapV4StandardExchangeOrbitalDETF.sol";
import {
    UniswapV4StandardExchangeOrbitalDETFRepo as Repo
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalDETFRepo.sol";
import {
    IUniswapV4StandardExchangeOrbitalDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalDETF.sol";

contract UniswapV4StandardExchangeOrbitalDETF_FirstBondTest is TestBase_UniswapV4StandardExchangeOrbitalDETF {
    function test_firstBond_bothPairs_setsLive() public {
        _assertInert();
        (uint256 tokenId, uint256 shares) = _firstBondBothPairs(100 ether, 100 ether);
        _assertLive();
        assertGt(tokenId, 0);
        assertGt(shares, 0);
        assertEq(
            uint8(detfInfo.capitalModeOf(tokenId)),
            uint8(IUniswapV4StandardExchangeOrbitalDETF.CapitalMode.Dual)
        );
        assertEq(detfInfo.capitalToken0Of(tokenId), pair0);
        assertEq(detfInfo.capitalToken1Of(tokenId), pair1);
    }

    function test_firstBond_singlePair_reverts() public {
        vm.startPrank(detfUser);
        vm.expectRevert(Repo.FirstBondRequiresBothPairs.selector);
        detfInfo.bond(
            IERC20(pair0),
            100 ether,
            DEFAULT_MIN_LOCK,
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function test_preLive_mint_reverts() public {
        _assertInert();
        vm.startPrank(detfUser);
        vm.expectRevert(Repo.ReserveNotLive.selector);
        detfExchangeIn.exchangeIn(
            IERC20(pair0),
            10 ether,
            IERC20(detf),
            0,
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
    }

    function test_preLive_burn_reverts() public {
        // mint free DETF can't happen pre-live; try burn with 0 path — need detf balance.
        // Just assert ReserveNotLive on exchangeIn DETF->pair with zero balance still hits live check first after pull fails
        // Fund detfUser with DETF by dealing (only for gate test; production mint blocked pre-live).
        deal(detf, detfUser, 1 ether);
        vm.startPrank(detfUser);
        IERC20(detf).approve(detf, type(uint256).max);
        vm.expectRevert(Repo.ReserveNotLive.selector);
        detfExchangeIn.exchangeIn(
            IERC20(detf),
            1 ether,
            IERC20(pair0),
            0,
            detfUser,
            false,
            block.timestamp + 1 hours
        );
        vm.stopPrank();
    }
}
