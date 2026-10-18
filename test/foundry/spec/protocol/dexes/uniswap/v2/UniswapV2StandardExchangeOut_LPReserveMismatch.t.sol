// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {
    TestBase_UniswapV2StandardExchange_MultiPool
} from "contracts/protocols/dexes/uniswap/v2/test/bases/TestBase_UniswapV2StandardExchange_MultiPool.sol";
import {UniswapV2LpBacking} from "contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeOutTarget.sol";

/// @notice RC-08 exact-out LP equality errors and matched-book controls on the production proxy.
contract UniswapV2StandardExchangeOut_LPReserveMismatch_Test is TestBase_UniswapV2StandardExchange_MultiPool {
    /// @notice A donated LP balance rejects token-to-vault exact-out with held before booked.
    function test_exchangeOut_zapInVaultDeposit_lpReserveMismatch() public {
        _expectMismatch(IERC20(address(balancedVault)));
    }

    /// @notice A donated LP balance rejects token-to-pair exact-out with held before booked.
    function test_exchangeOut_passThroughZapIn_lpReserveMismatch() public {
        _expectMismatch(IERC20(address(uniswapBalancedPair)));
    }

    /// @notice Token-to-vault exact-out succeeds when the fresh vault holds exactly its booked LP.
    function test_exchangeOut_zapInVaultDeposit_matchedBook() public {
        _expectMatchedBook(IERC20(address(balancedVault)));
    }

    /// @notice Token-to-pair exact-out succeeds when the fresh vault holds exactly its booked LP.
    function test_exchangeOut_passThroughZapIn_matchedBook() public {
        _expectMatchedBook(IERC20(address(uniswapBalancedPair)));
    }

    /// @dev Fund and approve a pull call without modifying the vault's LP reserve or share supply.
    function _prepareInput() internal {
        assertEq(balancedVault.totalSupply(), 0, "fresh share supply");
        assertEq(balancedVault.totalAssets(), 0, "fresh booked LP");
        assertEq(uniswapBalancedPair.balanceOf(address(balancedVault)), 0, "fresh held LP");
        uniswapBalancedTokenA.mint(address(this), TEST_AMOUNT);
        uniswapBalancedTokenA.approve(address(balancedVault), TEST_AMOUNT);
    }

    /// @dev Donate real LP, require exact error bytes, and prove the failed call rolls back.
    function _expectMismatch(IERC20 tokenOut_) internal {
        _prepareInput();
        uint256 donation_ = TEST_AMOUNT / 50;
        assertTrue(uniswapBalancedPair.transfer(address(balancedVault), donation_));
        uint256 inputBefore_ = uniswapBalancedTokenA.balanceOf(address(this));
        uint256 poolSupplyBefore_ = uniswapBalancedPair.totalSupply();
        uint256 outputBefore_ = tokenOut_.balanceOf(address(this));
        uint256 heldBefore_ = uniswapBalancedPair.balanceOf(address(balancedVault));
        uint256 bookedBefore_ = 0;
        vm.expectRevert(abi.encodeWithSelector(
            UniswapV2LpBacking.LPReserveMismatch.selector, heldBefore_, bookedBefore_
        ));
        balancedVault.exchangeOut(
            IERC20(address(uniswapBalancedTokenA)), TEST_AMOUNT, tokenOut_, 1 ether, address(this), false, _deadline()
        );
        assertEq(uniswapBalancedPair.balanceOf(address(balancedVault)), heldBefore_, "donated LP unchanged");
        assertEq(balancedVault.totalAssets(), bookedBefore_, "booked LP unchanged");
        assertEq(balancedVault.totalSupply(), 0, "no shares issued");
        assertEq(uniswapBalancedTokenA.balanceOf(address(this)), inputBefore_, "input pull rolled back");
        assertEq(uniswapBalancedPair.totalSupply(), poolSupplyBefore_, "pool mint rolled back");
        assertEq(tokenOut_.balanceOf(address(this)), outputBefore_, "output rolled back");
    }

    /// @dev Exercise the identical route and amounts without the LP donation; any revert fails the control.
    function _expectMatchedBook(IERC20 tokenOut_) internal {
        _prepareInput();
        uint256 inputBefore_ = uniswapBalancedTokenA.balanceOf(address(this));
        uint256 outputBefore_ = tokenOut_.balanceOf(address(this));
        uint256 poolSupplyBefore_ = uniswapBalancedPair.totalSupply();
        uint256 used_ = balancedVault.exchangeOut(
            IERC20(address(uniswapBalancedTokenA)), TEST_AMOUNT, tokenOut_, 1 ether, address(this), false, _deadline()
        );
        assertGt(used_, 0, "positive input");
        assertLe(used_, TEST_AMOUNT, "input within maximum");
        assertEq(inputBefore_ - uniswapBalancedTokenA.balanceOf(address(this)), used_, "exact input debit");
        if (address(tokenOut_) == address(balancedVault)) {
            assertEq(tokenOut_.balanceOf(address(this)) - outputBefore_, 1 ether, "exact requested shares");
            assertEq(balancedVault.totalSupply(), 1 ether, "exact share issue");
        } else {
            uint256 mintedLp_ = uniswapBalancedPair.totalSupply() - poolSupplyBefore_;
            assertGe(mintedLp_, 1 ether, "requested LP satisfied");
            assertEq(tokenOut_.balanceOf(address(this)) - outputBefore_, mintedLp_, "all new LP paid");
            assertEq(balancedVault.totalSupply(), 0, "pass-through issues no shares");
        }
        assertEq(
            uniswapBalancedPair.balanceOf(address(balancedVault)), balancedVault.totalAssets(), "held LP equals book"
        );
    }
}
