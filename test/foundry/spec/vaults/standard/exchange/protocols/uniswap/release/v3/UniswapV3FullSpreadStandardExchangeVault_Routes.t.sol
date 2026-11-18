// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {FullSpreadReleaseFixture} from "./harness/FullSpreadReleaseFixture.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {IUniswapV3MintCallback} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/callback/IUniswapV3MintCallback.sol";
import {IUniswapV3SwapCallback} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/callback/IUniswapV3SwapCallback.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {UniswapV3FullSpreadStandardExchangeVaultCommon as Common} from "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultCommon.sol";

/// @notice V3-ACC-02/03/12/14/17: migrated public route regressions.
contract UniswapV3FullSpreadStandardExchangeVault_Routes_Test is FullSpreadReleaseFixture {
    function test_exchangeIn_exactIn_bothDirections() public {
        for (uint256 i; i < 2; ++i) {
            IERC20 input = i == 0 ? token0 : token1;
            IERC20 output = i == 0 ? token1 : token0;
            uint256 beforeInput = input.balanceOf(alice);
            _fund(input, alice, 10 ether);
            (uint256 quote,) = vault.previewExchangeIn(input, 10 ether, output);
            uint256 beforeOutput = output.balanceOf(alice);
            vm.startPrank(alice);
            input.approve(address(vault), 10 ether);
            (uint256 paid, uint256 refund) = vault.exchangeIn(input, 10 ether, output, quote, alice, false, block.timestamp);
            vm.stopPrank();
            assertGt(quote, 0);
            assertEq(paid, quote);
            assertEq(output.balanceOf(alice) - beforeOutput, paid);
            assertEq(input.balanceOf(alice) - beforeInput, refund);
            assertEq(vault.totalSupply(), 0, "pass-through mints no shares");
        }
    }

    function test_exchangeOut_exactOut_bothDirections_failClosed() public {
        for (uint256 i; i < 2; ++i) {
            IERC20 input = i == 0 ? token0 : token1;
            IERC20 output = i == 0 ? token1 : token0;
            assertEq(vault.previewExchangeOut(input, output, 1 ether), 0);
            bytes32 beforeState = _state(alice);
            vm.prank(alice);
            vm.expectRevert(IStandardExchangeOut.ExchangeOutNotAvailable.selector);
            vault.exchangeOut(input, type(uint256).max, output, 1 ether, alice, false, block.timestamp);
            assertEq(_state(alice), beforeState);
        }
    }

    function test_twoTokenActivation_createsPositionsAndShares() public {
        uint256 shares = _joinFor(100 ether, 100 ether, alice);
        assertEq(vault.balanceOf(alice), shares);
        assertEq(vault.balanceOf(address(0)), 1000);
        assertEq(vault.totalSupply(), uint256(_liquidity()));
        assertEq(vault.totalSupply(), shares + 1000);
        _assertReserves();
    }

    function test_zapIn_subsequentDeposit_addsSameTicks() public {
        _join(100 ether, 100 ether);
        uint256 supply = vault.totalSupply();
        uint128 liquidity = _liquidity();
        (uint256 added,) = _mintOne(token0, 100 ether, alice);
        assertGt(added, 0);
        assertEq(added, uint256(_liquidity() - liquidity) * supply / liquidity);
        assertEq(vault.totalSupply(), supply + added);
        assertEq(vault.balanceOf(address(0)), 1000);
    }

    function test_zapOut_paysMeasuredToken() public {
        uint256 shares = _joinFor(100 ether, 100 ether, alice) / 2;
        (uint256 quoted,) = vault.previewExchangeIn(IERC20(address(vault)), shares, token0);
        uint256 supply = vault.totalSupply();
        uint256 balance = token0.balanceOf(alice);
        vm.prank(alice);
        (uint256 paid,) = vault.exchangeIn(IERC20(address(vault)), shares, token0, quoted, alice, false, block.timestamp);
        assertGt(quoted, 0);
        assertEq(paid, quoted);
        assertEq(token0.balanceOf(alice) - balance, paid);
        assertEq(vault.totalSupply(), supply - shares);
    }

    function test_unsupportedRoutes_revert() public {
        IERC20 foreign = IERC20(address(new ERC20PermitMintableStub("Foreign", "FOR", 18, address(this), 0)));
        vm.expectRevert(IStandardExchangeIn.ExchangeInNotAvailable.selector);
        vault.exchangeIn(foreign, 1 ether, token0, 0, alice, false, block.timestamp);
        _join(10 ether, 10 ether);
        vm.expectRevert(IStandardExchangeIn.ExchangeInNotAvailable.selector);
        vault.exchangeIn(IERC20(address(vault)), 1, IERC20(address(vault)), 0, alice, false, block.timestamp);
    }

    function test_deadline_reverts() public {
        vm.warp(1000);
        _disable(true);
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.DeadlineExceeded.selector, 1, 1000));
        vault.exchangeIn(token0, 1 ether, token1, 0, alice, false, 1);
    }

    function test_slippage_revertsWithoutPartialMint() public {
        _join(100 ether, 100 ether);
        _fund(token0, address(this), 100 ether);
        token0.approve(address(vault), 100 ether);
        (uint256 quote,) = vault.previewExchangeIn(token0, 100 ether, IERC20(address(vault)));
        bytes32 beforeState = _state(address(this));
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.AmountOutNotMet.selector, quote + 1, quote));
        vault.exchangeIn(token0, 100 ether, IERC20(address(vault)), quote + 1, alice, false, block.timestamp);
        assertEq(_state(address(this)), beforeState);
    }

    function test_callbackSpoof_reverts() public {
        vm.expectRevert(Common.UniswapV3Exchange_CallbackNotAuthorized.selector);
        IUniswapV3MintCallback(address(vault)).uniswapV3MintCallback(1, 1, "");
        vm.expectRevert(Common.UniswapV3Exchange_CallbackNotAuthorized.selector);
        IUniswapV3SwapCallback(address(vault)).uniswapV3SwapCallback(1, 1, "");
    }
}
