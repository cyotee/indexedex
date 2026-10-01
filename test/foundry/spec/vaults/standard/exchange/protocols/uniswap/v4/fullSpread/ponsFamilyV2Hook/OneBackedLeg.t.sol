// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IStandardExchangeTransitionQuote as Transition} from "contracts/interfaces/IStandardExchangeTransitionQuote.sol";
import {IStandardExchangeExactOutputQuantityQuote as Quantity} from "contracts/interfaces/IStandardExchangeExactOutputQuantityQuote.sol";
import {IStandardExchangeErrors} from "contracts/interfaces/IStandardExchangeErrors.sol";
import {FullSpreadQuantityReference as Reference} from "contracts/test/bases/TestBase_UniswapV4FullSpreadExactOutputQuantity.sol";
import {TestBase_UniswapV4FullSpreadUnlockContextQuote as Shapes} from "contracts/test/bases/TestBase_UniswapV4FullSpreadUnlockContextQuote.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {SqrtPriceMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/SqrtPriceMath.sol";
import {LiquidityAmounts} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityAmounts.sol";
import {IStandardExchangeInMulti} from "contracts/interfaces/IStandardExchangeInMulti.sol";

import {TestBase_UniswapV4FullSpreadPonsFamilyHook_Acceptance as Acceptance} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/test/bases/TestBase_UniswapV4FullSpreadPonsFamilyHook_Acceptance.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IVaultFeeOracleManager} from "contracts/interfaces/IVaultFeeOracleManager.sol";
import {IUniswapV4FullSpreadPonsFamilyHookLiquidReserve as Reserve} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/interfaces/IUniswapV4FullSpreadPonsFamilyHookLiquidReserve.sol";

// tag::UniswapV4FullSpreadPonsFamilyHookOneBackedLegTest[]
contract UniswapV4FullSpreadPonsFamilyHookOneBackedLegTest is Acceptance {
    function _decimalsA() internal pure override returns (uint8) { return 6; }
    function _decimalsB() internal pure override returns (uint8) { return 6; }
    function _tickSpacing() internal pure override returns (int24) { return 10; }
    function _initialPrice() internal pure override returns (uint160) { return TickMath.getSqrtPriceAtTick(-60); }

    function test_fundedBlockedLinearExactOutputInNaturallyOneSidedBook() public {
        _oneSided();
        uint256 quote = abi.decode(_nested(abi.encodeCall(IStandardExchangeOut.previewExchangeOut,
            (IERC20(address(vault)), token0, 1))), (uint256));
        assertGt(quote, 0);
        uint256 balance = token0.balanceOf(address(this));
        uint256 supply = vault.totalSupply();
        assertEq(abi.decode(_nested(abi.encodeCall(IStandardExchangeOut.exchangeOut,
            (IERC20(address(vault)), quote, token0, 1, address(this), false, block.timestamp))), (uint256)), quote);
        assertEq(token0.balanceOf(address(this)) - balance, 1);
        assertEq(vault.totalSupply(), supply - quote);
        _assertBooked();
    }

    function test_idleLinearExactOutputWithClosedPlacement() public {
        _oneSided();
        uint256 free = token0.balanceOf(address(vault));
        bool succeeded;
        // Test-side enumeration checks the few settlement-rounding neighbours;
        // production uses only the selected linear equation and fixed stencil.
        for (uint256 adjustment; adjustment < 4 && adjustment < free; ++adjustment) {
            uint256 output = free - adjustment;
            try vault.previewExchangeOut(IERC20(address(vault)), token0, output) returns (uint256 shares) {
                uint256 balance = token0.balanceOf(address(this));
                assertEq(vault.exchangeOut(IERC20(address(vault)), shares, token0, output, address(this), false, block.timestamp), shares);
                assertEq(token0.balanceOf(address(this)) - balance, output);
                succeeded = true;
                break;
            } catch {}
        }
        assertTrue(succeeded, "no supported CC neighbour found");
        _assertBooked();
    }

    function _oneSided() private {
        vm.startPrank(owner);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultLiquidReservePercentageOfTypeId(type(Reserve).interfaceId, 0);
        IVaultFeeOracleManager(address(indexedexManager)).setDefaultLiquidReservePercentage(0);
        vm.stopPrank();
        _activateWithoutOpposingDust();
        _externalSwap(true, 5e31);
        Reserve(address(vault)).rebalanceLiquidReserve();
        (, uint256 deployed1) = Reserve(address(vault)).deployedReserve();
        assertEq(token1.balanceOf(address(vault)), 0);
        assertEq(deployed1, 0);
        assertGt(token0.balanceOf(address(vault)), 0);
    }

    function _activateWithoutOpposingDust() private {
        uint160 q = _initialPrice();
        uint160 a = TickMath.getSqrtPriceAtTick(TickMath.minUsableTick(_tickSpacing()));
        uint160 b = TickMath.getSqrtPriceAtTick(TickMath.maxUsableTick(_tickSpacing()));
        uint256 amount0;
        uint256 amount1;
        // Fixture-only integer enumeration chooses a funded basket whose smaller
        // placement stencil still consumes every token1 unit. No assets are erased
        // and no exact-output amount is obtained by search in the implementation.
        for (uint256 i; i < 10_000; ++i) {
            amount1 = 1_000 * unit1 + i;
            uint128 liquidity = uint128(amount1 * (uint256(1) << 96) / (q - a));
            amount0 = SqrtPriceMath.getAmount0Delta(q, b, liquidity, true);
            uint128 target = LiquidityAmounts.getLiquidityForAmounts(q, a, b, amount0, amount1);
            if (target > 0 && SqrtPriceMath.getAmount1Delta(a, q, target - 1, true) == amount1) break;
            if (i == 9_999) revert("no exact fixture basket");
        }
        uint256 issued = IStandardExchangeInMulti(address(vault)).exchangeInManyToOne(
            _tokens(), _amounts(amount0, amount1), IERC20(address(vault)), 0, address(this), false, block.timestamp);
        assertGt(issued, 0);
        assertEq(token1.balanceOf(address(vault)), 0, "actual placement consumes opposing sleeve");
        _assertBooked();
    }

    function test_linearQuantityIgnoresZeroHolderButTransitionRequiresShares() public {
        _oneSided();
        (bytes memory state,) = abi.decode(_nested(abi.encodeCall(Transition.quoteState, (address(token0), address(0)))), (bytes, uint256));
        (Shapes.Snapshot memory q, uint256 backing, uint256 opposing) = Reference.backing(state);
        assertEq(opposing, 0); assertEq(q.shares, 0);
        uint256 required = Quantity(address(vault)).quoteSharesForExactAssets(state, 1);
        assertEq(required, Math.mulDiv(1, q.supply, backing, Math.Rounding.Ceil)); assertGt(required, 0);
        vm.expectRevert(abi.encodeWithSelector(Transition.InsufficientQuoteShares.selector, required, 0));
        Transition(address(vault)).quoteTransition(state, Transition.Operation.WithdrawExactOut, 1);
        assertEq(abi.decode(_nested(abi.encodeCall(IStandardExchangeOut.exchangeOut,
            (IERC20(address(vault)), required, token0, 1, address(this), false, block.timestamp))), (uint256)), required);
        _assertBooked();
    }

    function test_linearQuantityDoesNotPromiseLocalCover() public {
        _oneSided();
        (bytes memory state,) = abi.decode(_nested(abi.encodeCall(Transition.quoteState, (address(token0), address(0)))), (bytes, uint256));
        (Shapes.Snapshot memory q, uint256 backing, uint256 opposing) = Reference.backing(state);
        uint256 available = token0.balanceOf(address(vault)); uint256 wanted = available + 1;
        assertEq(opposing, 0); assertGe(backing, wanted);
        uint256 required = Quantity(address(vault)).quoteSharesForExactAssets(state, wanted);
        assertEq(required, Math.mulDiv(wanted, q.supply, backing, Math.Rounding.Ceil));
        assertLe(required, vault.balanceOf(address(this)));
        uint256 supply = vault.totalSupply();
        bytes memory callData = abi.encodeCall(IStandardExchangeOut.exchangeOut,
            (IERC20(address(vault)), required, token0, wanted, address(this), false, block.timestamp));
        vm.expectRevert(abi.encodeWithSignature("UniswapV4Exchange_InsufficientLocalReserve(address,uint256,uint256)", address(token0), wanted, available));
        _nested(callData);
        assertEq(vault.totalSupply(), supply); assertEq(token0.balanceOf(address(vault)), available); _assertBooked();
    }

    function test_oneOpposingWeiInvalidatesFreshQuantityNotOldSuppliedState() public {
        _oneSided();
        (bytes memory oldState,) = abi.decode(_nested(abi.encodeCall(Transition.quoteState, (address(token0), address(0)))), (bytes, uint256));
        uint256 expected = Quantity(address(vault)).quoteSharesForExactAssets(oldState, 1);
        token1.transfer(address(vault), 1);
        (bytes memory state,) = abi.decode(_nested(abi.encodeCall(Transition.quoteState, (address(token0), address(0)))), (bytes, uint256));
        (,, uint256 opposing) = Reference.backing(state); assertEq(opposing, 1);
        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.InvalidRoute.selector, address(vault), address(token0)));
        Quantity(address(vault)).quoteSharesForExactAssets(state, 1);
        assertEq(Quantity(address(vault)).quoteSharesForExactAssets(oldState, 1), expected);
    }
}
// end::UniswapV4FullSpreadPonsFamilyHookOneBackedLegTest[]
