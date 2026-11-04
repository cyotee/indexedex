// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.24;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IRateProvider} from "@crane/contracts/protocols/dexes/balancer/common/interfaces/IRateProvider.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";

interface IFullSpreadHookTuple {
    function exchangeIn(
        address tokenIn,
        uint256 amountIn,
        address tokenOut,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external returns (uint256 amountOut, uint256 amountRefunded);
}
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {SeMatrix_FullSpreadV4Fixture} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/SeMatrix_FullSpreadV4Fixture.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault
        as FullSpreadCpRow
} from "test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol";

/// @notice Composed hook controls for this vault. The matrix rows remain the topology proofs.
/// @dev FS-A26 stays open: the PairToken identity bind is rejected without asset(). This file does not add asset().
contract UniswapV4FullSpreadStandardExchangeVault_BufferHookIntegration_Test is FullSpreadCpRow {

    function test_getRateAbsentAndProviderReadsTuple() public {
        (bool ok_,) = seUT.staticcall(abi.encodeWithSignature("getRate()"));
        assertFalse(ok_, "getRate is absent");
        address provider_ = SeMatrix_FullSpreadV4Fixture(address(fx)).currency0Provider();
        assertGt(IRateProvider(provider_).getRate(), 0, "external provider reads the tuple");
    }

    function test_stagedPretransferIsNotCreditedToLaterCaller() public {
        _seed();
        uint256 amt_ = _f(1);
        fx.fund(rowEoa, amt_);
        vm.prank(rowEoa);
        IERC20(face).transfer(hook, amt_);
        uint256 resting_ = IERC20(face).balanceOf(hook);
        uint256 bobBefore_ = IERC20(raw).balanceOf(rowBob);
        fx.fund(rowBob, amt_);
        vm.startPrank(rowBob);
        IERC20(face).approve(address(swapRouter), amt_);
        vm.stopPrank();
        bool zeroForOne_ = face < raw;
        vm.prank(rowBob);
        swapRouter.swapExactIn(
            poolKey,
            SwapParams({
                zeroForOne: zeroForOne_,
                amountSpecified: -int256(amt_),
                sqrtPriceLimitX96: _sqrtLimit(zeroForOne_)
            }),
            ""
        );
        assertGt(IERC20(raw).balanceOf(rowBob), bobBefore_, "later caller is paid for its own input");
        assertGe(IERC20(face).balanceOf(hook), resting_, "staged pretransfer is not consumed by the later caller");
        assertEq(IERC20(face).balanceOf(rowBob), 0, "later caller is not refunded the staged pretransfer");
    }

    function test_exactOutHookPaysNeitherToken() public {
        _seed();
        uint256 faceBefore_ = IERC20(face).balanceOf(user);
        uint256 rawBefore_ = IERC20(raw).balanceOf(user);
        bool zeroForOne_ = raw < face;
        vm.expectRevert();
        vm.prank(user);
        swapRouter.swapExactOut(
            poolKey,
            SwapParams({
                zeroForOne: zeroForOne_,
                amountSpecified: int256(_f(1)),
                sqrtPriceLimitX96: _sqrtLimit(zeroForOne_)
            }),
            type(uint256).max,
            ""
        );
        assertEq(IERC20(face).balanceOf(user), faceBefore_, "exact-out pays no face");
        assertEq(IERC20(raw).balanceOf(user), rawBefore_, "exact-out pays no raw");
        assertEq(IStandardExchangeOut(seUT).previewExchangeOut(IERC20(face), IERC20(seUT), _f(1)), 0);
    }

    function test_identityAttemptDoesNotBurnCallerPosition() public {
        _seed();
        uint256 amount_ = _f(1);
        fx.fund(user, amount_);
        vm.startPrank(user);
        IERC20(face).approve(seUT, amount_);
        (uint256 minted_,) = IFullSpreadHookTuple(seUT).exchangeIn(
            face, amount_, seUT, 0, user, false, block.timestamp
        );
        vm.stopPrank();
        assertGt(minted_, 0, "caller has a position to protect");
        uint256 shares_ = IERC20(seUT).balanceOf(user);
        uint256 faceBefore_ = IERC20(face).balanceOf(user);
        vm.prank(user);
        vm.expectRevert();
        IFullSpreadHookTuple(seUT).exchangeIn(seUT, shares_, seUT, 0, user, false, block.timestamp);
        assertEq(IERC20(seUT).balanceOf(user), shares_, "identity attempt burns no position");
        assertEq(IERC20(face).balanceOf(user), faceBefore_, "identity attempt pays nothing");
        (bool ok_,) = seUT.staticcall(abi.encodeWithSignature("asset()"));
        assertFalse(ok_, "asset is absent");
    }
}
