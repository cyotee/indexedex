// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {TestBase_SlipstreamStandardExchange_Decimals} from
    "contracts/protocols/dexes/aerodrome/slipstream/test/bases/TestBase_SlipstreamStandardExchange_Decimals.sol";

/// @notice Live zap money paths on combo-decimal pair tokens. pairToken = tokenA role.
/// @dev After address sort, pairToken0/1 may swap; amounts use `_u0`/`_u1`.
abstract contract SlipstreamStandardExchange_Routes_Decimals is TestBase_SlipstreamStandardExchange_Decimals {
    uint8 internal constant _DECIMALS_REMATCH = 2;
    address internal alice;

    function setUp() public virtual override {
        super.setUp();
        alice = makeAddr("slipRoutesAlice");
    }

    function _previewIn(IERC20 tokenIn_, uint256 amountIn_, IERC20 tokenOut_) internal view returns (uint256) {
        return vault.previewExchangeIn(tokenIn_, amountIn_, tokenOut_);
    }

    /// @dev Mixed-decimal CL exact-out preview can undershoot exec by up to ~0.1%.
    function _approxEq(uint256 a, uint256 b, string memory err) internal pure {
        uint256 hi = a > b ? a : b;
        uint256 lo = a > b ? b : a;
        uint256 slack = hi / 1000 + 1;
        assertLe(hi - lo, slack, err);
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

    function test_zapIn_token0_toShares_firstJoin_previewEqExec() public {
        uint256 amountIn_ = _u0(10);
        pairToken0.mint(alice, amountIn_);
        uint256 shares_ = _zapIn(alice, IERC20(address(pairToken0)), amountIn_, IERC20(address(vault)));
        assertGt(shares_, 0, "first join minted");
        assertEq(IERC20(address(vault)).balanceOf(alice), shares_);
        assertEq(IERC20(address(vault)).totalSupply(), shares_);
    }

    function test_zapIn_token1_toShares_firstJoin_previewEqExec() public {
        uint256 amountIn_ = _u1(10);
        pairToken1.mint(alice, amountIn_);
        uint256 shares_ = _zapIn(alice, IERC20(address(pairToken1)), amountIn_, IERC20(address(vault)));
        assertGt(shares_, 0, "first join minted");
        assertEq(IERC20(address(vault)).balanceOf(alice), shares_);
    }

    function test_zapIn_token0_subsequentJoin_previewEqExec() public {
        uint256 amountIn_ = _u0(10);
        pairToken0.mint(alice, amountIn_ * 2);
        uint256 first_ = _zapIn(alice, IERC20(address(pairToken0)), amountIn_, IERC20(address(vault)));
        uint256 second_ = _zapIn(alice, IERC20(address(pairToken0)), amountIn_, IERC20(address(vault)));
        assertGt(first_, 0);
        assertGt(second_, 0);
        assertEq(IERC20(address(vault)).totalSupply(), first_ + second_);
    }

    function test_zapIn_token1_subsequentJoin_previewEqExec() public {
        uint256 amountIn_ = _u1(10);
        pairToken1.mint(alice, amountIn_ * 2);
        uint256 first_ = _zapIn(alice, IERC20(address(pairToken1)), amountIn_, IERC20(address(vault)));
        uint256 second_ = _zapIn(alice, IERC20(address(pairToken1)), amountIn_, IERC20(address(vault)));
        assertGt(first_, 0);
        assertGt(second_, 0);
        assertEq(IERC20(address(vault)).balanceOf(alice), first_ + second_);
    }

    function test_zapOut_shares_toToken0_previewEqExec() public {
        uint256 amountIn0_ = _u0(20);
        uint256 amountIn1_ = _u1(20);
        pairToken0.mint(alice, amountIn0_);
        pairToken1.mint(alice, amountIn1_);
        _zapIn(alice, IERC20(address(pairToken0)), amountIn0_, IERC20(address(vault)));
        _zapIn(alice, IERC20(address(pairToken1)), amountIn1_, IERC20(address(vault)));
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
        _approxEq(used_, preview_, "previewExchangeOut ~= exchangeOut");
        assertGt(pairToken0.balanceOf(alice), before_, "token0 paid");
    }

    function test_zapOut_shares_toToken1_previewEqExec() public {
        uint256 amountIn0_ = _u0(20);
        uint256 amountIn1_ = _u1(20);
        pairToken0.mint(alice, amountIn0_);
        pairToken1.mint(alice, amountIn1_);
        _zapIn(alice, IERC20(address(pairToken0)), amountIn0_, IERC20(address(vault)));
        _zapIn(alice, IERC20(address(pairToken1)), amountIn1_, IERC20(address(vault)));
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
        _approxEq(used_, preview_, "previewExchangeOut ~= exchangeOut");
        assertGt(pairToken1.balanceOf(alice), before_, "token1 paid");
    }

    function test_exchangeIn_token0_toToken1_previewEqExec() public {
        uint256 amountIn_ = _u0(5);
        pairToken0.mint(alice, amountIn_);
        uint256 out_ = _zapIn(alice, IERC20(address(pairToken0)), amountIn_, IERC20(address(pairToken1)));
        assertGt(out_, 0, "t0->t1");
        assertEq(pairToken1.balanceOf(alice), out_);
    }

    function test_exchangeIn_token1_toToken0_previewEqExec() public {
        uint256 amountIn_ = _u1(5);
        pairToken1.mint(alice, amountIn_);
        uint256 out_ = _zapIn(alice, IERC20(address(pairToken1)), amountIn_, IERC20(address(pairToken0)));
        assertGt(out_, 0, "t1->t0");
        assertEq(pairToken0.balanceOf(alice), out_);
    }

    function test_exchangeOut_token0_toToken1_previewEqExec() public {
        uint256 amountOut_ = _u1(1);
        pairToken0.mint(alice, _u0(100));
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
        _approxEq(used_, preview_, "previewExchangeOut ~= exchangeOut");
        assertGe(pairToken1.balanceOf(alice), amountOut_, "token1 paid");
    }

    function test_exchangeOut_token1_toToken0_previewEqExec() public {
        uint256 amountOut_ = _u0(1);
        pairToken1.mint(alice, _u1(100));
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
        _approxEq(used_, preview_, "previewExchangeOut ~= exchangeOut");
        assertGe(pairToken0.balanceOf(alice), amountOut_, "token0 paid");
    }
}
