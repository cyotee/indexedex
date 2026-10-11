// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20PermitMintableStub} from "@crane/contracts/tokens/ERC20/ERC20PermitMintableStub.sol";
import {IUniswapV3Pool} from "@crane/contracts/protocols/dexes/uniswap/v3/interfaces/IUniswapV3Pool.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v3/libraries/TickMath.sol";
import {UniswapV3Quoter} from "@crane/contracts/utils/math/UniswapV3Quoter.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {UniswapV3FullSpreadStandardExchangeVaultCommon} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultCommon.sol";
import {TestBase_UniswapV3FullSpreadStandardExchangeVault} from
    "contracts/vaults/standard/exchange/protocols/uniswap/v3/test/bases/TestBase_UniswapV3FullSpreadStandardExchangeVault.sol";

/// @notice RC-04: exact-output quote rejection and funded settlement on the FullSpread proxy.
/// @dev The real pool fixture has no execution-only short-fill hook. Quote-stage rollback below
/// does not claim coverage of the distinct post-swap output-delta guard.
contract UniswapV3FullSpreadExactOutputFill_Test is TestBase_UniswapV3FullSpreadStandardExchangeVault {
    IUniswapV3Pool internal pool;
    IStandardExchangeProxy internal vault;
    address internal payer;
    address internal recipient;

    /// @notice Use the production manager package and real V3 liquidity fixture.
    function setUp() public override {
        super.setUp();
        ERC20PermitMintableStub tokenA_ = new ERC20PermitMintableStub("Token A", "A", 18, address(this), 0);
        ERC20PermitMintableStub tokenB_ = new ERC20PermitMintableStub("Token B", "B", 18, address(this), 0);
        pool = _createPoolOneToOne(address(tokenA_), address(tokenB_), FEE_MEDIUM);
        _seedExternalLiquidity(pool, 50_000_000e18);
        vault = _deployVault(pool);
        payer = makeAddr("v3ExactOutputPayer");
        recipient = makeAddr("v3ExactOutputRecipient");
    }

    /// @notice Both directions reject the raw quoter's incomplete result at the vault preview.
    function test_RC04_unfilledQuoteAndPreview_revert(bool zeroForOne_) public {
        (IERC20 input_, IERC20 output_) = _tokens(zeroForOne_);
        uint256 requested_ = output_.balanceOf(address(pool)) + 1;
        UniswapV3Quoter.SwapQuoteResult memory quote_ = _quote(zeroForOne_, requested_);
        assertEq(quote_.fullyFilled, false, "fixture quote is incomplete");
        assertEq(quote_.amountOut < requested_, true, "quote reports actual partial output");
        vm.expectRevert(_notFilled(requested_, quote_.amountOut));
        vault.previewExchangeOut(input_, output_, requested_);
    }

    /// @notice An incomplete execution quote leaves input, payout, pool and vault balances unchanged.
    function test_RC04_unfilledExecutionQuote_preservesBalances(bool zeroForOne_) public {
        (IERC20 input_, IERC20 output_) = _tokens(zeroForOne_);
        uint256 requested_ = output_.balanceOf(address(pool)) + 1;
        UniswapV3Quoter.SwapQuoteResult memory quote_ = _quote(zeroForOne_, requested_);
        assertEq(quote_.fullyFilled, false);
        ERC20PermitMintableStub(address(input_)).mint(payer, 1 ether);
        vm.prank(payer);
        input_.approve(address(vault), 1 ether);
        uint256[4] memory balances_ = [input_.balanceOf(address(pool)), output_.balanceOf(address(pool)),
            input_.balanceOf(address(vault)), output_.balanceOf(address(vault))];

        vm.prank(payer);
        vm.expectRevert(_notFilled(requested_, quote_.amountOut));
        vault.exchangeOut(input_, 1 ether, output_, requested_, recipient, false, block.timestamp + 1 hours);

        assertEq(input_.balanceOf(payer), 1 ether, "no input spent");
        assertEq(input_.allowance(payer, address(vault)), 1 ether, "allowance unchanged");
        assertEq(output_.balanceOf(recipient), 0, "no payout");
        assertEq(input_.balanceOf(address(pool)), balances_[0]);
        assertEq(output_.balanceOf(address(pool)), balances_[1]);
        assertEq(input_.balanceOf(address(vault)), balances_[2]);
        assertEq(output_.balanceOf(address(vault)), balances_[3]);
    }

    /// @notice A funded request pays exactly its output and pulls only the quoted input in either direction.
    function test_RC04_fillableExactOutput_paysRequestedOutputWithinMaximum(bool zeroForOne_) public {
        (IERC20 input_, IERC20 output_) = _tokens(zeroForOne_);
        uint256 requested_ = 1 ether;
        UniswapV3Quoter.SwapQuoteResult memory quote_ = _quote(zeroForOne_, requested_);
        assertEq(quote_.fullyFilled, true);
        assertEq(quote_.amountOut, requested_);
        uint256 quotedInput_ = vault.previewExchangeOut(input_, output_, requested_);
        assertEq(quotedInput_, quote_.amountIn);
        uint256 maximum_ = quotedInput_ + 1 ether;
        ERC20PermitMintableStub(address(input_)).mint(payer, maximum_);
        vm.prank(payer);
        input_.approve(address(vault), maximum_);
        uint256 poolInputBefore_ = input_.balanceOf(address(pool));
        uint256 poolOutputBefore_ = output_.balanceOf(address(pool));

        vm.prank(payer);
        uint256 used_ = vault.exchangeOut(input_, maximum_, output_, requested_, recipient, false, block.timestamp + 1 hours);

        assertEq(used_, quotedInput_);
        assertEq(used_ <= maximum_, true, "input ceiling respected");
        assertEq(input_.balanceOf(payer), maximum_ - used_, "unused maximum stays with payer");
        assertEq(output_.balanceOf(recipient), requested_);
        assertEq(input_.balanceOf(address(pool)) - poolInputBefore_, used_);
        assertEq(poolOutputBefore_ - output_.balanceOf(address(pool)), requested_);
        assertEq(input_.balanceOf(address(vault)), 0);
        assertEq(output_.balanceOf(address(vault)), 0);
    }

    /// @notice The zero-output preview remains zero in both directions.
    function test_RC04_zeroOutputPreview_returnsZero(bool zeroForOne_) public {
        (IERC20 input_, IERC20 output_) = _tokens(zeroForOne_);
        assertEq(vault.previewExchangeOut(input_, output_, 0), 0);
    }

    function _tokens(bool zeroForOne_) internal view returns (IERC20 input_, IERC20 output_) {
        return zeroForOne_ ? (IERC20(pool.token0()), IERC20(pool.token1())) : (IERC20(pool.token1()), IERC20(pool.token0()));
    }

    function _quote(bool zeroForOne_, uint256 requested_) internal view returns (UniswapV3Quoter.SwapQuoteResult memory) {
        return UniswapV3Quoter.quoteExactOutput(UniswapV3Quoter.SwapQuoteParams({
            pool: pool, zeroForOne: zeroForOne_, amount: requested_,
            sqrtPriceLimitX96: zeroForOne_ ? TickMath.MIN_SQRT_RATIO + 1 : TickMath.MAX_SQRT_RATIO - 1,
            maxSteps: 0
        }));
    }

    function _notFilled(uint256 requested_, uint256 delivered_) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(
            UniswapV3FullSpreadStandardExchangeVaultCommon.UniswapV3Exchange_ExactOutputNotFilled.selector,
            requested_, delivered_
        );
    }
}
