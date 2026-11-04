// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {TestBase_UniswapV4FullSpreadStandardExchangeVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/test/bases/TestBase_UniswapV4FullSpreadStandardExchangeVault.sol";

interface IFullSpreadQuote {
    function previewExchangeIn(address tokenIn, uint256 amountIn, address tokenOut)
        external
        view
        returns (uint256 amountOut, uint256 amountRefunded);

    function previewExchangeBundleInForSingleOut(uint256[] calldata amountsIn, address tokenOut)
        external
        view
        returns (uint256 amountOut, uint256[] memory amountsRefunded);

    function previewExchangeBundleOut(address tokenIn, uint256 amountIn, address[] calldata tokensOut)
        external
        view
        returns (uint256[] memory amountsOut, uint256 amountRefunded);

    function exchangeBundleInForSingleOut(
        uint256[] calldata amountsIn,
        address tokenOut,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 amountOut, uint256[] memory amountsRefunded);

    function exchangeBundleOut(
        address tokenIn,
        uint256 amountIn,
        address[] calldata tokensOut,
        uint256[] calldata minAmountsOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256[] memory amountsOut, uint256 amountRefunded);

    function balanceOf(address account) external view returns (uint256);
}

contract UniswapV4FullSpreadStandardExchangeVault_QuotesAndRate_Test is TestBase_UniswapV4FullSpreadStandardExchangeVault {
    uint256 internal constant PREVIEW_GAS = 5_000_000;
    IFullSpreadQuote internal quote;

    function setUp() public override {
        super.setUp();
        quote = IFullSpreadQuote(address(vault));
        _fund(address(this), 2_000_000 ether, 2_000_000 ether);
        _approve(address(vault));
        uint256[] memory amounts_ = new uint256[](2);
        amounts_[0] = 100_000 ether;
        amounts_[1] = 100_000 ether;
        quote.exchangeBundleInForSingleOut(amounts_, address(vault), 0, address(this), false, block.timestamp);
    }

    function test_bundlePreviewMatchesExecution() public {
        uint256[] memory amounts_ = new uint256[](2);
        amounts_[0] = 1_000 ether;
        amounts_[1] = 800 ether;
        (uint256 preview_, uint256[] memory previewRefund_) =
            quote.previewExchangeBundleInForSingleOut(amounts_, address(vault));
        (uint256 shares_, uint256[] memory refund_) = quote.exchangeBundleInForSingleOut(
            amounts_, address(vault), preview_, address(this), false, block.timestamp
        );
        assertEq(shares_, preview_);
        assertEq(refund_[0], previewRefund_[0]);
        assertEq(refund_[1], previewRefund_[1]);
        address[] memory tokens_ = new address[](2);
        tokens_[0] = address(token0);
        tokens_[1] = address(token1);
        (uint256[] memory outPreview_, uint256 outRefund_) =
            quote.previewExchangeBundleOut(address(vault), shares_, tokens_);
        assertEq(outRefund_, 0);
        (uint256[] memory out_, uint256 refunded_) = quote.exchangeBundleOut(
            address(vault), shares_, tokens_, outPreview_, address(this), false, block.timestamp
        );
        assertEq(refunded_, 0);
        assertEq(out_[0], outPreview_[0]);
        assertEq(out_[1], outPreview_[1]);
    }

    function test_unsupportedPreviewIsZero() public {(uint256 out_, uint256 refund_) = quote.previewExchangeIn(address(0xBEEF), 1 ether, address(vault));
        assertEq(out_, 0);
        assertEq(refund_, 0);
    }

    function test_previewGasFitsCeiling() public {
        uint256 gas_ = gasleft();quote.previewExchangeIn(address(token0), 1 ether, address(vault));
        assertLt(gas_ - gasleft(), PREVIEW_GAS);
    }

    function test_getRateAndExchangeOutAreAbsent() public {
        assertEq(address(vault).code.length > 0, true);
        (bool ok_,) = address(vault).staticcall(abi.encodeWithSignature("getRate()"));
        assertFalse(ok_, "getRate is absent");
        assertEq(
            IStandardExchangeOut(address(vault)).previewExchangeOut(IERC20(address(token0)), IERC20(address(vault)), 1 ether),
            0
        );
        vm.expectRevert(IStandardExchangeOut.ExchangeOutNotAvailable.selector);
        IStandardExchangeOut(address(vault)).exchangeOut(
            IERC20(address(token0)), 1 ether, IERC20(address(vault)), 0, address(this), false, block.timestamp
        );
    }
}
