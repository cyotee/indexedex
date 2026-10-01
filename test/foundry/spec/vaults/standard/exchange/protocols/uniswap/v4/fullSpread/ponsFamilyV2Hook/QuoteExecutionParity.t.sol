// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {TestBase_UniswapV4FullSpreadPonsFamilyHook_Acceptance as Acceptance} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/test/bases/TestBase_UniswapV4FullSpreadPonsFamilyHook_Acceptance.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IStandardExchangeErrors} from "contracts/interfaces/IStandardExchangeErrors.sol";
import {IStandardExchangeTransitionQuote as Transition} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {UniswapV4FullSpreadPonsFamilyHookCommon as Common} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookCommon.sol";

// tag::UniswapV4FullSpreadPonsFamilyHookQuoteExecutionParityTest[]
contract UniswapV4FullSpreadPonsFamilyHookQuoteExecutionParityTest is Acceptance {
    function test_singleSidedActivationRejectedBeforeTokenPull() public {
        token0.approve(address(vault), 0);
        bytes memory expected = abi.encodeWithSelector(IStandardExchangeErrors.InvalidRoute.selector, address(token0), address(vault));
        vm.expectRevert(expected);
        vault.previewExchangeIn(token0, 1e18, IERC20(address(vault)));
        vm.expectRevert(expected);
        vault.exchangeIn(token0, 1e18, IERC20(address(vault)), 0, address(this), false, block.timestamp);
        assertEq(vault.totalSupply(), 0);
        assertEq(token0.balanceOf(address(vault)), 0);
    }

    function test_registryBootstrapAndRepeatedCompositionBothDirections() public {
        _bootstrap();
        for (uint256 i; i < 4; ++i) {
            IERC20 input = i % 2 == 0 ? token0 : token1;
            uint256 amount = i % 2 == 0 ? unit0 : unit1;
            uint256 beforeShares = vault.balanceOf(address(this));
            uint256 quote = vault.previewExchangeIn(input, amount, IERC20(address(vault)));
            uint256 gasBefore = gasleft();
            uint256 result = vault.exchangeIn(input, amount, IERC20(address(vault)), quote, address(this), false, block.timestamp);
            emit log_named_uint("proxy composition gas", gasBefore - gasleft());
            assertGt(result, 0);
            assertEq(result, quote);
            assertEq(vault.balanceOf(address(this)) - beforeShares, quote);
            _assertBooked();
        }
    }

    function test_directExactInputBothDirections() public {
        _bootstrap();
        for (uint256 i; i < 2; ++i) {
            IERC20 input = i == 0 ? token0 : token1;
            IERC20 output = i == 0 ? token1 : token0;
            uint256 quote = vault.previewExchangeIn(input, 1e15, output);
            uint256 beforeBalance = output.balanceOf(address(this));
            assertEq(vault.exchangeIn(input, 1e15, output, quote, address(this), false, block.timestamp), quote);
            assertEq(output.balanceOf(address(this)) - beforeBalance, quote);
            _assertBooked();
        }
    }

    function test_idleShareRedemptionBothDirections() public {
        _bootstrap();
        for (uint256 i; i < 2; ++i) {
            IERC20 output = i == 0 ? token0 : token1;
            uint256 quote = vault.previewExchangeIn(IERC20(address(vault)), 1e18, output);
            uint256 beforeBalance = output.balanceOf(address(this));
            assertEq(vault.exchangeIn(IERC20(address(vault)), 1e18, output, quote, address(this), false, block.timestamp), quote);
            assertEq(output.balanceOf(address(this)) - beforeBalance, quote);
            _assertBooked();
        }
    }

    function test_idleExactSharesRejectedBeforeFunding() public {
        _bootstrap();
        bytes memory expected = abi.encodeWithSelector(IStandardExchangeErrors.InvalidRoute.selector, address(token0), address(vault));
        vm.expectRevert(expected);
        vault.previewExchangeOut(token0, IERC20(address(vault)), 1e18);
        uint256 balance = token0.balanceOf(address(this));
        vm.expectRevert(expected);
        vault.exchangeOut(token0, 10e18, IERC20(address(vault)), 1e18, address(this), false, block.timestamp);
        assertEq(token0.balanceOf(address(this)), balance);
    }

    function test_transitionDepositMatchesFullPostState() public {
        _bootstrap();
        (bytes memory snapshot,) = Transition(address(vault)).quoteState(address(token0), address(this));
        (bytes memory next,, uint256 shares,) = Transition(address(vault)).quoteTransition(snapshot, Transition.Operation.DepositExactIn, 1e18);
        Common.InventoryQuote memory expected = abi.decode(next, (Common.InventoryQuote));
        assertEq(vault.exchangeIn(token0, 1e18, IERC20(address(vault)), shares, address(this), false, block.timestamp), shares);
        (bytes memory actualState,) = Transition(address(vault)).quoteState(address(token0), address(this));
        Common.InventoryQuote memory actual = abi.decode(actualState, (Common.InventoryQuote));
        // liquidityDelta is a simulation overlay, not a persisted position field.
        expected.liquidityDelta = 0;
        assertEq(keccak256(abi.encode(actual)), keccak256(abi.encode(expected)));
        _assertBooked();
    }
}
// end::UniswapV4FullSpreadPonsFamilyHookQuoteExecutionParityTest[]
