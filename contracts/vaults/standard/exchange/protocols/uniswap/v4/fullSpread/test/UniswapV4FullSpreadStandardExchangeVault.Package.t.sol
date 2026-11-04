// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {TestBase_UniswapV4FullSpreadStandardExchangeVault} from "./bases/TestBase_UniswapV4FullSpreadStandardExchangeVault.sol";

contract UniswapV4FullSpreadStandardExchangeVault_Package_Test is TestBase_UniswapV4FullSpreadStandardExchangeVault {
    function test_bootstrapBundleDepositMintsShares() public {
        _fund(address(this), 1_000_000 ether, 1_000_000 ether);
        _approve(address(vault));
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 1_000 ether;
        amounts[1] = 1_000 ether;
        (uint256 shares, uint256[] memory refunds) = vault.exchangeBundleInForSingleOut(
            amounts, address(vault), 0, address(this), false, block.timestamp
        );
        assertGt(shares, 0);
        assertEq(vault.balanceOf(address(this)), shares);
        assertGt(vault.totalSupply(), shares);
        assertEq(refunds.length, 2);
        assertGt(vault.positionLiquidity(), 1000);
    }

    function test_oneSidedDepositThenExit() public {
        _fund(address(this), 2_000_000 ether, 2_000_000 ether);
        _approve(address(vault));
        uint256[] memory amounts = new uint256[](2);
        amounts[0] = 100_000 ether;
        amounts[1] = 100_000 ether;
        vault.exchangeBundleInForSingleOut(amounts, address(vault), 0, address(this), false, block.timestamp);
        address face0 = address(token0) == address(0) ? address(token1) : address(token0);
        // currency0 is the lower address. Deposit that face.
        address inToken = address(token0);(uint256 shares, uint256 refunded) = vault.exchangeIn(inToken, 1_000 ether, address(vault), 0, address(this), false, block.timestamp
        );
        assertGt(shares, 0);
        assertLt(refunded, 1_000 ether);(uint256 out, uint256 exitRefund) = vault.exchangeIn(address(vault), shares, inToken, 0, address(this), false, block.timestamp
        );
        assertGt(out, 0);
        assertEq(exitRefund, 0);
        face0;
    }
}
