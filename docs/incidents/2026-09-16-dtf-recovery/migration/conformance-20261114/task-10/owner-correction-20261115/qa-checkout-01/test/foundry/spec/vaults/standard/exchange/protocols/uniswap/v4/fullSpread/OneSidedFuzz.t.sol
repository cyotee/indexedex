// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {TestBase_UniswapV4FullSpreadStandardExchangeVault} from "contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/test/bases/TestBase_UniswapV4FullSpreadStandardExchangeVault.sol";

interface IFullSpreadFuzzMoney {
    function exchangeIn(
        address tokenIn,
        uint256 amountIn,
        address tokenOut,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 amountOut, uint256 amountRefunded);

    function previewExchangeIn(address tokenIn, uint256 amountIn, address tokenOut)
        external
        view
        returns (uint256 amountOut, uint256 amountRefunded);

    function exchangeBundleInForSingleOut(
        uint256[] calldata amountsIn,
        address tokenOut,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 amountOut, uint256[] memory amountsRefunded);
}

/// @notice 49% one-sided mint across a token-scale range. A run either mints with an input-only refund or refunds the whole input.
contract UniswapV4FullSpreadStandardExchangeVault_OneSidedFuzz_Test is TestBase_UniswapV4FullSpreadStandardExchangeVault {
    IFullSpreadFuzzMoney internal money;

    function setUp() public override {
        super.setUp();
        money = IFullSpreadFuzzMoney(address(vault));
        _fund(address(this), 4_000_000 ether, 4_000_000 ether);
        _approve(address(vault));
        uint256[] memory amounts_ = new uint256[](2);
        amounts_[0] = 100_000 ether;
        amounts_[1] = 100_000 ether;
        money.exchangeBundleInForSingleOut(amounts_, address(vault), 0, address(this), false, block.timestamp);
    }

    function testFuzz_oneSidedPreviewMatchesExecution(bool token1_, uint256 rawAmount_) public {
        uint256 cap0_ = type(uint256).max - token0.totalSupply();
        uint256 cap1_ = type(uint256).max - token1.totalSupply();
        uint256 cap_ = cap0_ < cap1_ ? cap0_ : cap1_;
        uint256 amount_ = bound(rawAmount_, 1, cap_);
        address tokenIn_ = token1_ ? address(token1) : address(token0);
        address other_ = token1_ ? address(token0) : address(token1);
        _fund(address(this), amount_, amount_);
        uint256 otherBefore_ = IERC20(other_).balanceOf(address(this));
        uint256 vaultOtherBefore_ = IERC20(other_).balanceOf(address(vault));
        (uint256 preview_, uint256 previewRefund_) = money.previewExchangeIn(tokenIn_, amount_, address(vault));
        (uint256 shares_, uint256 refund_) = money.exchangeIn(
            tokenIn_, amount_, address(vault), preview_, address(this), false, block.timestamp
        );
        assertEq(shares_, preview_, "preview matches execution");
        assertEq(refund_, previewRefund_, "refund preview matches execution");
        if (shares_ == 0) {
            assertEq(refund_, amount_, "unusable input is refunded whole");
        } else {
            assertLt(refund_, amount_, "a mint consumes some input");
        }
        assertEq(IERC20(other_).balanceOf(address(this)), otherBefore_, "refund is not the other token");
        assertEq(IERC20(other_).balanceOf(address(vault)), vaultOtherBefore_, "other token is not booked");
    }
}
