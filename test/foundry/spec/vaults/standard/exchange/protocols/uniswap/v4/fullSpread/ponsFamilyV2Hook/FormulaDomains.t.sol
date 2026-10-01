// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_UniswapV4FullSpreadPonsFamilyHook_Acceptance as Acceptance} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/test/bases/TestBase_UniswapV4FullSpreadPonsFamilyHook_Acceptance.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeOutMulti} from "contracts/interfaces/IStandardExchangeOutMulti.sol";
import {IStandardExchangeErrors} from "contracts/interfaces/IStandardExchangeErrors.sol";
import {IUniswapV4FullSpreadPonsFamilyHookLiquidReserve as Reserve} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/interfaces/IUniswapV4FullSpreadPonsFamilyHookLiquidReserve.sol";
import {StateLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol";
import {PoolIdLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolId.sol";

// tag::UniswapV4FullSpreadPonsFamilyHookFormulaDomainsTest[]
contract UniswapV4FullSpreadPonsFamilyHookFormulaDomainsTest is Acceptance {
    using PoolIdLibrary for *;
    function test_nonzeroDirectExactOutputAndCombinedPlacement() public {
        _bootstrap();
        uint256 quote = vault.previewExchangeOut(token1, token0, 1e15);
        assertGt(quote, 0);
        uint256 beforeIn = token1.balanceOf(address(this));
        uint256 beforeOut = token0.balanceOf(address(this));
        assertEq(vault.exchangeOut(token1, quote + 1e18, token0, 1e15, address(this), false, block.timestamp), quote);
        assertEq(beforeIn - token1.balanceOf(address(this)), quote);
        assertEq(token0.balanceOf(address(this)) - beforeOut, 1e15);
        _assertBooked();
    }

    function test_directExactOutputPrepaidRefundUsesOnlyCredit() public {
        _bootstrap();
        uint256 quote = vault.previewExchangeOut(token1, token0, 1e15);
        uint256 balance = token1.balanceOf(address(this));
        token1.transfer(address(vault), quote + 1e18);
        assertEq(vault.exchangeOut(token1, quote + 1e18, token0, 1e15, address(this), true, block.timestamp), quote);
        assertEq(balance - token1.balanceOf(address(this)), quote);
        _assertBooked();
    }

    function test_idleF3ExactDualPayout() public {
        _bootstrap();
        uint256[] memory amounts = _amounts(1e18, 1e18);
        uint256 quote = IStandardExchangeOutMulti(address(vault)).previewExchangeOutOneToMany(IERC20(address(vault)), _tokens(), amounts);
        uint256 before0 = token0.balanceOf(address(this));
        uint256 before1 = token1.balanceOf(address(this));
        uint256 supply = vault.totalSupply();
        assertEq(IStandardExchangeOutMulti(address(vault)).exchangeOutOneToMany(
            IERC20(address(vault)), quote, _tokens(), amounts, address(this), false, block.timestamp), quote);
        assertEq(vault.totalSupply(), supply - quote);
        assertEq(token0.balanceOf(address(this)) - before0, 1e18);
        assertEq(token1.balanceOf(address(this)) - before1, 1e18);
        _assertBooked();
    }

    function test_F3UnequalCeilRejectedBeforeSharesMove() public {
        _bootstrap();
        uint256 shares = vault.balanceOf(address(this));
        address[] memory tokens = _tokens();
        uint256[] memory amounts = _amounts(1e18, 2e18);
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.InvalidRoute.selector, address(vault), address(token0)));
        IStandardExchangeOutMulti(address(vault)).exchangeOutOneToMany(
            IERC20(address(vault)), shares, tokens, amounts, address(this), false, block.timestamp);
        assertEq(vault.balanceOf(address(this)), shares);
    }

    function test_R8PreservesFundedDualExitWhenCompositionCertificateFails() public {
        _bootstrap();
        token0.transfer(address(vault), 10e18);
        (uint256 d0, uint256 d1) = Reserve(address(vault)).deployedReserve();
        uint256[] memory amounts = _amounts((d0 + token0.balanceOf(address(vault))) / 1_000,
            (d1 + token1.balanceOf(address(vault))) / 1_000);
        uint256 burn = IStandardExchangeOutMulti(address(vault)).previewExchangeOutOneToMany(IERC20(address(vault)), _tokens(), amounts);
        (uint160 beforePrice,,,) = StateLibrary.getSlot0(poolManager, poolKey.toId());
        assertEq(IStandardExchangeOutMulti(address(vault)).exchangeOutOneToMany(
            IERC20(address(vault)), burn, _tokens(), amounts, address(this), false, block.timestamp), burn);
        (uint160 afterPrice,,,) = StateLibrary.getSlot0(poolManager, poolKey.toId());
        assertEq(afterPrice, beforePrice);
        _assertBooked();
    }

    function test_reverseDirectionExactOutputSucceedsInsideItsFirstStep() public {
        _bootstrap();
        _externalSwap(false, 1e18);
        uint256 used = vault.previewExchangeOut(token0, token1, 1e15);
        uint256 balance = token1.balanceOf(address(this));
        assertEq(vault.exchangeOut(token0, used, token1, 1e15, address(this), false, block.timestamp), used);
        assertEq(token1.balanceOf(address(this)) - balance, 1e15);
        _assertBooked();
    }
}
// end::UniswapV4FullSpreadPonsFamilyHookFormulaDomainsTest[]
