// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {SwapParams} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";

import {
    TestBase_UniswapV4StandardExchangeWeightedDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/TestBase_UniswapV4StandardExchangeWeightedDETF.sol";
import {
    IUniswapV4StandardExchangeWeightedDETF
} from "contracts/vaults/detf/protocols/dexes/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedDETF.sol";
import {
    IUniswapV4StandardExchangeWeightedBufferHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHook.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHookPairPoolLib as PairPoolLib
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookPairPoolLib.sol";
import {SimpleMintableERC20} from "contracts/test/stubs/SimpleMintableERC20.sol";

/**
 * @title UniswapV4StandardExchangeWeightedDETF_N8AllSe
 * @notice Hermetic n=8 all-external-SE smoke: 7 distinct ERC-4626 SEs, 28 doors.
 *         Drives shipped `_deployDetfWired` / `_firstBondOn` / `_mintOn` (no SUT mocks).
 */
contract UniswapV4StandardExchangeWeightedDETF_N8AllSe is TestBase_UniswapV4StandardExchangeWeightedDETF {
    uint256 internal constant N8_BOND_AMT = 50 ether;

    function test_n8_allSe_deploy_wiresSevenDistinctSes() public {
        address d = _deployDetfWired(_argsN8_AllSe("wire"));
        IUniswapV4StandardExchangeWeightedDETF info = IUniswapV4StandardExchangeWeightedDETF(d);
        IHook hook_ = IHook(info.reserveHook());

        assertEq(info.n(), 8, "n");
        assertEq(info.m(), 7, "m");
        assertEq(hook_.numTokens(), 8, "hook n");
        assertEq(hook_.pairDoorCount(), 28, "C(8,2) doors");
        assertEq(hook_.standardExchange(info.detfBindingIndex()), address(0), "DETF self-leg raw");

        for (uint256 i; i < 7; ++i) {
            address se = info.standardExchange(i);
            assertTrue(se != address(0), "SE bound");
            assertTrue(se != d, "SE != DETF");
            for (uint256 j = i + 1; j < 7; ++j) {
                assertTrue(se != info.standardExchange(j), "SEs pairwise distinct");
            }
            assertEq(
                hook_.standardExchange(info.pairBindingIndex(i)), se, "hook SE matches pairToken(i)"
            );
        }
    }

    function test_n8_allSe_firstBond_fullBook() public {
        address d = _deployDetfWired(_argsN8_AllSe("bond"));
        IUniswapV4StandardExchangeWeightedDETF info = IUniswapV4StandardExchangeWeightedDETF(d);
        IHook hook_ = IHook(info.reserveHook());

        (uint256 tokenId, uint256 shares) = _firstBondOn(d, _n8BondAmts(), info.pairToken(0));

        assertTrue(info.isReserveLive(), "reserve live");
        assertTrue(hook_.isFullBook(), "full book");
        assertGt(tokenId, 0, "tokenId");
        assertGt(shares, 0, "shares");

        uint256[] memory nat_ = hook_.nativeReserves();
        assertEq(nat_.length, 8, "native reserve count");
        for (uint256 i; i < nat_.length; ++i) {
            assertGt(nat_[i], 0, "native reserve > 0");
        }
    }

    function test_n8_allSe_liveMint_onePair() public {
        address d = _deployDetfWired(_argsN8_AllSe("mint"));
        IUniswapV4StandardExchangeWeightedDETF info = IUniswapV4StandardExchangeWeightedDETF(d);
        address p0 = info.pairToken(0);
        _firstBondOn(d, _n8BondAmts(), p0);

        _fundPair(d, p0, detfUser, 20 ether);
        uint256 out_ = _mintOn(d, p0, 10 ether);
        assertGt(out_, 0, "mint out > 0");
    }

    function test_n8_allSe_oneDoorSwap() public {
        address d = _deployDetfWired(_argsN8_AllSe("swap"));
        IUniswapV4StandardExchangeWeightedDETF info = IUniswapV4StandardExchangeWeightedDETF(d);
        address p0 = info.pairToken(0);
        address p1 = info.pairToken(1);
        _firstBondOn(d, _n8BondAmts(), p0);

        address reserveHook_ = info.reserveHook();
        uint256 amountIn = 1 ether;
        uint256 preview = IHook(reserveHook_).previewSwapExactIn(p0, p1, amountIn);
        assertGt(preview, 0, "preview > 0");

        uint256 before = IERC20(p1).balanceOf(user);
        _swapExactInOnReserveHook(reserveHook_, p0, p1, amountIn);
        uint256 got = IERC20(p1).balanceOf(user) - before;
        assertGt(got, 0, "swap out > 0");
    }

    function _n8BondAmts() internal pure returns (uint256[] memory amts) {
        amts = new uint256[](7);
        for (uint256 i; i < 7; ++i) {
            amts[i] = N8_BOND_AMT;
        }
    }

    /// @dev Same PoolKey/router path as hook TestBase `_swapExactIn`, aimed at the DETF reserve hook.
    function _swapExactInOnReserveHook(
        address reserveHook_,
        address tokenIn,
        address tokenOut,
        uint256 amountIn
    ) internal {
        bool zeroForOne = tokenIn < tokenOut;
        PoolKey memory key = PairPoolLib.pairKey(tokenIn, tokenOut, 1, IHooks(reserveHook_));
        SwapParams memory params = SwapParams({
            zeroForOne: zeroForOne,
            amountSpecified: -int256(amountIn),
            sqrtPriceLimitX96: zeroForOne ? TickMath.MIN_SQRT_PRICE + 1 : TickMath.MAX_SQRT_PRICE - 1
        });
        SimpleMintableERC20(tokenIn).mint(user, amountIn);
        vm.startPrank(user);
        IERC20(tokenIn).approve(address(swapRouter), type(uint256).max);
        swapRouter.swapExactIn(key, params, "");
        vm.stopPrank();
    }
}
