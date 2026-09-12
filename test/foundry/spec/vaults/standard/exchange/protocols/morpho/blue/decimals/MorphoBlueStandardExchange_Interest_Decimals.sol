// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IMorpho} from "@crane/contracts/external/morpho/blue/interfaces/IMorpho.sol";
import {MorphoBalancesLib} from
    "@crane/contracts/external/morpho/blue/libraries/periphery/MorphoBalancesLib.sol";
import {TestBase_MorphoBlueStandardExchange_Decimals} from
    "contracts/vaults/standard/exchange/protocols/morpho/blue/test/bases/TestBase_MorphoBlueStandardExchange_Decimals.sol";

/// @notice I1–I2 interest on a non-18 loan token.
abstract contract MorphoBlueStandardExchange_Interest_Decimals is
    TestBase_MorphoBlueStandardExchange_Decimals
{
    using MorphoBalancesLib for IMorpho;

    function test_I1_afterWarp_convertToAssets_matchesExpectedSupplyPlusIdle() public {
        uint256 shares = _wrapExactIn(user, _u(1_000));
        _borrowFromMarket(2_000 ether, _u(500));
        vm.warp(block.timestamp + 30 days);
        uint256 idle = _idleOf(se);
        uint256 expected = morpho.expectedSupplyAssets(marketParams, se);
        assertEq(se4626.totalAssets(), idle + expected, "I1 totalAssets == idle + expectedSupply");
        uint256 supply = IERC20(se).totalSupply();
        assertGt(supply, 0, "I1 supply");
        assertEq(se4626.convertToAssets(shares), se4626.convertToAssets(shares), "I1 convert stable");
    }

    function test_I2_redeemAfterInterest_assetsOutGtAssetsIn() public {
        uint256 assetsIn = _u(1_000);
        uint256 shares = _wrapExactIn(user, assetsIn);
        _borrowFromMarket(2_000 ether, _u(500));
        vm.warp(block.timestamp + 365 days);

        uint256 preview = seIn.previewExchangeIn(IERC20(se), shares, IERC20(address(loanToken)));
        uint256 expected = morpho.expectedSupplyAssets(marketParams, se) + _idleOf(se);
        assertGt(preview, assetsIn, "I2 preview assetsOut > assetsIn");

        uint256 borrowShares = morpho.position(marketId, BORROWER).borrowShares;
        _mintLoan(BORROWER, preview);
        vm.startPrank(BORROWER);
        loanToken.approve(address(morpho), type(uint256).max);
        morpho.repay(marketParams, 0, borrowShares, BORROWER, "");
        vm.stopPrank();

        preview = seIn.previewExchangeIn(IERC20(se), shares, IERC20(address(loanToken)));
        vm.prank(user);
        uint256 assetsOut = seIn.exchangeIn(
            IERC20(se), shares, IERC20(address(loanToken)), 0, user, false, _deadline()
        );
        assertEq(assetsOut, preview, "I2 preview == exec");
        assertGt(assetsOut, assetsIn, "I2 assetsOut > assetsIn");
        assertLe(assetsOut, expected + 1, "I2 vs Blue expected");
    }
}
