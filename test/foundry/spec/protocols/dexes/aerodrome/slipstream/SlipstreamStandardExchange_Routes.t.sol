// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {
    TestBase_SlipstreamStandardExchange
} from "contracts/protocols/dexes/aerodrome/slipstream/test/bases/TestBase_SlipstreamStandardExchange.sol";

/**
 * @title SlipstreamStandardExchange_Routes
 * @notice Gold 18-dec live zap: `exchangeIn` / `exchangeOut` token0/token1 → shares and reverse.
 * @dev Production SUT via `TestBase_SlipstreamStandardExchange`. Preview == exec.
 *      Quote-only `SlipstreamStandardExchangeRoutes_Test.t.sol` is unchanged.
 */
contract SlipstreamStandardExchange_Routes_Test is TestBase_SlipstreamStandardExchange {
    address internal alice = makeAddr("slipRoutesAlice");

    function _previewIn(IERC20 tokenIn_, uint256 amountIn_, IERC20 tokenOut_) internal view returns (uint256) {
        return vault.previewExchangeIn(tokenIn_, amountIn_, tokenOut_);
    }

    function _zapIn(address who_, IERC20 tokenIn_, uint256 amountIn_, IERC20 tokenOut_)
        internal
        returns (uint256 out_)
    {
        vm.startPrank(who_);
        tokenIn_.approve(address(vault), amountIn_);
        uint256 preview_ = _previewIn(tokenIn_, amountIn_, tokenOut_);
        out_ = vault.exchangeIn(tokenIn_, amountIn_, tokenOut_, 0, who_, false, _deadline());
        vm.stopPrank();
        assertEq(out_, preview_, "previewExchangeIn == exchangeIn");
    }

    /// @notice First join: token0 → vaultShare, preview == exec.
    function test_zapIn_token0_toShares_firstJoin_previewEqExec() public {
        uint256 amountIn_ = 10 ether;
        pairToken0.mint(alice, amountIn_);
        uint256 shares_ = _zapIn(alice, IERC20(address(pairToken0)), amountIn_, IERC20(address(vault)));
        assertGt(shares_, 0, "first join minted");
        assertEq(IERC20(address(vault)).balanceOf(alice), shares_);
        assertEq(IERC20(address(vault)).totalSupply(), shares_);
    }

    /// @notice First join: token1 → vaultShare, preview == exec.
    function test_zapIn_token1_toShares_firstJoin_previewEqExec() public {
        uint256 amountIn_ = 10 ether;
        pairToken1.mint(alice, amountIn_);
        uint256 shares_ = _zapIn(alice, IERC20(address(pairToken1)), amountIn_, IERC20(address(vault)));
        assertGt(shares_, 0, "first join minted");
        assertEq(IERC20(address(vault)).balanceOf(alice), shares_);
    }

    /// @notice Subsequent join: second token0 zap mints additional shares.
    function test_zapIn_token0_subsequentJoin_previewEqExec() public {
        uint256 amountIn_ = 10 ether;
        pairToken0.mint(alice, amountIn_ * 2);
        uint256 first_ = _zapIn(alice, IERC20(address(pairToken0)), amountIn_, IERC20(address(vault)));
        uint256 second_ = _zapIn(alice, IERC20(address(pairToken0)), amountIn_, IERC20(address(vault)));
        assertGt(first_, 0);
        assertGt(second_, 0);
        assertEq(IERC20(address(vault)).totalSupply(), first_ + second_);
    }

    /// @notice Subsequent join: second token1 zap mints additional shares.
    function test_zapIn_token1_subsequentJoin_previewEqExec() public {
        uint256 amountIn_ = 10 ether;
        pairToken1.mint(alice, amountIn_ * 2);
        uint256 first_ = _zapIn(alice, IERC20(address(pairToken1)), amountIn_, IERC20(address(vault)));
        uint256 second_ = _zapIn(alice, IERC20(address(pairToken1)), amountIn_, IERC20(address(vault)));
        assertGt(first_, 0);
        assertGt(second_, 0);
        assertEq(IERC20(address(vault)).balanceOf(alice), first_ + second_);
    }

    /// @notice Zap out: shares → token0, preview == exec.
    function test_zapOut_shares_toToken0_previewEqExec() public {
        uint256 amountIn_ = 20 ether;
        pairToken0.mint(alice, amountIn_);
        pairToken1.mint(alice, amountIn_);
        _zapIn(alice, IERC20(address(pairToken0)), amountIn_, IERC20(address(vault)));
        _zapIn(alice, IERC20(address(pairToken1)), amountIn_, IERC20(address(vault)));
        uint256 minOut_ = 1;
        uint256 before_ = pairToken0.balanceOf(alice);
        uint256 shares_ = IERC20(address(vault)).balanceOf(alice);
        vm.startPrank(alice);
        uint256 preview_ =
            vault.previewExchangeOut(IERC20(address(vault)), IERC20(address(pairToken0)), minOut_);
        assertGt(preview_, 0, "quoted shares");
        uint256 used_ = vault.exchangeOut(
            IERC20(address(vault)), shares_, IERC20(address(pairToken0)), minOut_, alice, false, _deadline()
        );
        vm.stopPrank();
        assertEq(used_, preview_, "previewExchangeOut == exchangeOut");
        assertGt(pairToken0.balanceOf(alice), before_, "token0 paid");
    }

    /// @notice Zap out: shares → token1, preview == exec.
    function test_zapOut_shares_toToken1_previewEqExec() public {
        uint256 amountIn_ = 20 ether;
        pairToken0.mint(alice, amountIn_);
        pairToken1.mint(alice, amountIn_);
        _zapIn(alice, IERC20(address(pairToken0)), amountIn_, IERC20(address(vault)));
        _zapIn(alice, IERC20(address(pairToken1)), amountIn_, IERC20(address(vault)));
        uint256 minOut_ = 1;
        uint256 before_ = pairToken1.balanceOf(alice);
        uint256 shares_ = IERC20(address(vault)).balanceOf(alice);
        vm.startPrank(alice);
        uint256 preview_ =
            vault.previewExchangeOut(IERC20(address(vault)), IERC20(address(pairToken1)), minOut_);
        assertGt(preview_, 0, "quoted shares");
        uint256 used_ = vault.exchangeOut(
            IERC20(address(vault)), shares_, IERC20(address(pairToken1)), minOut_, alice, false, _deadline()
        );
        vm.stopPrank();
        assertEq(used_, preview_, "previewExchangeOut == exchangeOut");
        assertGt(pairToken1.balanceOf(alice), before_, "token1 paid");
    }

    /// @notice Direct swap exact-in token0 → token1, preview == exec.
    function test_exchangeIn_token0_toToken1_previewEqExec() public {
        uint256 amountIn_ = 5 ether;
        pairToken0.mint(alice, amountIn_);
        uint256 out_ = _zapIn(alice, IERC20(address(pairToken0)), amountIn_, IERC20(address(pairToken1)));
        assertGt(out_, 0, "t0->t1");
        assertEq(pairToken1.balanceOf(alice), out_);
    }

    /// @notice Direct swap exact-in token1 → token0, preview == exec.
    function test_exchangeIn_token1_toToken0_previewEqExec() public {
        uint256 amountIn_ = 5 ether;
        pairToken1.mint(alice, amountIn_);
        uint256 out_ = _zapIn(alice, IERC20(address(pairToken1)), amountIn_, IERC20(address(pairToken0)));
        assertGt(out_, 0, "t1->t0");
        assertEq(pairToken0.balanceOf(alice), out_);
    }

    /// @notice Exact-out token0 → token1, preview == exec.
    function test_exchangeOut_token0_toToken1_previewEqExec() public {
        uint256 amountOut_ = 1 ether;
        pairToken0.mint(alice, 100 ether);
        vm.startPrank(alice);
        IERC20(address(pairToken0)).approve(address(vault), type(uint256).max);
        uint256 preview_ =
            vault.previewExchangeOut(IERC20(address(pairToken0)), IERC20(address(pairToken1)), amountOut_);
        uint256 used_ = vault.exchangeOut(
            IERC20(address(pairToken0)),
            type(uint256).max,
            IERC20(address(pairToken1)),
            amountOut_,
            alice,
            false,
            _deadline()
        );
        vm.stopPrank();
        assertGt(preview_, 0, "quoted used");
        assertEq(used_, preview_, "previewExchangeOut == exchangeOut");
        assertEq(pairToken1.balanceOf(alice), amountOut_);
    }

    /// @notice Exact-out token1 → token0, preview == exec.
    function test_exchangeOut_token1_toToken0_previewEqExec() public {
        uint256 amountOut_ = 1 ether;
        pairToken1.mint(alice, 100 ether);
        vm.startPrank(alice);
        IERC20(address(pairToken1)).approve(address(vault), type(uint256).max);
        uint256 preview_ =
            vault.previewExchangeOut(IERC20(address(pairToken1)), IERC20(address(pairToken0)), amountOut_);
        uint256 used_ = vault.exchangeOut(
            IERC20(address(pairToken1)),
            type(uint256).max,
            IERC20(address(pairToken0)),
            amountOut_,
            alice,
            false,
            _deadline()
        );
        vm.stopPrank();
        assertGt(preview_, 0, "quoted used");
        assertEq(used_, preview_, "previewExchangeOut == exchangeOut");
        assertEq(pairToken0.balanceOf(alice), amountOut_);
    }
}
