// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ICamelotPair} from "@crane/contracts/interfaces/protocols/dexes/camelot/v2/ICamelotPair.sol";
import {IStandardExchangeErrors} from "contracts/interfaces/IStandardExchangeErrors.sol";
import {IStandardExchangeProxy} from "contracts/interfaces/proxies/IStandardExchangeProxy.sol";
import {MintableERC20Decimals} from "contracts/test/stubs/MintableERC20Decimals.sol";
import {TestBase_CamelotV2StandardExchange_Decimals} from
    "contracts/protocols/dexes/camelot/v2/test/bases/TestBase_CamelotV2StandardExchange_Decimals.sol";

/**
 * @title CamelotV2StandardExchangeIn_Swap_Decimals
 * @notice Route 1 pass-through swap on combo decimals. pairToken = tokenA.
 * @dev After Camelot pair address sort, token0/token1 may swap; roles stay pairToken vs other.
 *      vaultShare stays 18.
 */
abstract contract CamelotV2StandardExchangeIn_Swap_Decimals is TestBase_CamelotV2StandardExchange_Decimals {
    MintableERC20Decimals internal tokenA;
    MintableERC20Decimals internal tokenB;
    IStandardExchangeProxy internal vault;
    ICamelotPair internal pair;

    function setUp() public virtual override {
        super.setUp();

        tokenA = new MintableERC20Decimals("Token A", "TKNA", _tokenADecimals());
        tokenB = new MintableERC20Decimals("Token B", "TKNB", _tokenBDecimals());
        tokenA.mint(address(this), _uA(10_000));
        tokenB.mint(address(this), _uB(10_000));

        vm.label(address(tokenA), "pairToken-tokenA");
        vm.label(address(tokenB), "otherToken-tokenB");

        uint256 seedA = _uA(1000);
        uint256 seedB = _uB(1000);
        tokenA.approve(address(camelotV2StandardExchangeDFPkg), seedA);
        tokenB.approve(address(camelotV2StandardExchangeDFPkg), seedB);

        address vaultAddr = camelotV2StandardExchangeDFPkg.deployVault(
            IERC20(address(tokenA)), seedA, IERC20(address(tokenB)), seedB, address(this)
        );

        vault = IStandardExchangeProxy(vaultAddr);
        pair = ICamelotPair(camelotV2Factory.getPair(address(tokenA), address(tokenB)));
        require(address(pair) != address(0), "pair");
    }

    function _deadline() internal view returns (uint256) {
        return block.timestamp + 1 hours;
    }

    function _amountIn(bool aToB) internal view returns (uint256) {
        return aToB ? _uA(1) : _uB(1);
    }

    /* ---------------------------------------------------------------------- */
    /*                          Preview vs pool math                          */
    /* ---------------------------------------------------------------------- */

    /// @notice pairToken → other. Amount is `_uA(1)` of pairToken.
    function test_Route1Swap_previewVsMath_AtoB() public view {
        _test_previewVsMath(true);
    }

    /// @notice other → pairToken. Amount is `_uB(1)` of the other token.
    function test_Route1Swap_previewVsMath_BtoA() public view {
        _test_previewVsMath(false);
    }

    function _test_previewVsMath(bool aToB) internal view {
        IERC20 tokenIn = aToB ? IERC20(address(tokenA)) : IERC20(address(tokenB));
        IERC20 tokenOut = aToB ? IERC20(address(tokenB)) : IERC20(address(tokenA));
        uint256 amountIn = _amountIn(aToB);

        uint256 expectedFromPool = pair.getAmountOut(amountIn, address(tokenIn));
        uint256 preview = vault.previewExchangeIn(tokenIn, amountIn, tokenOut);

        assertEq(preview, expectedFromPool, "Preview should match pair.getAmountOut()");
        assertTrue(preview > 0, "Preview non-zero");
    }

    /* ---------------------------------------------------------------------- */
    /*                       Execution vs preview (H)                         */
    /* ---------------------------------------------------------------------- */

    /// @notice pairToken → other exec vs preview. Amount `_uA(1)`.
    function test_Route1Swap_execVsPreview_AtoB() public {
        _test_execVsPreview(true);
    }

    /// @notice other → pairToken exec vs preview. Amount `_uB(1)`.
    function test_Route1Swap_execVsPreview_BtoA() public {
        _test_execVsPreview(false);
    }

    function _test_execVsPreview(bool aToB) internal {
        MintableERC20Decimals tokenInStub = aToB ? tokenA : tokenB;
        IERC20 tokenIn = IERC20(address(tokenInStub));
        IERC20 tokenOut = aToB ? IERC20(address(tokenB)) : IERC20(address(tokenA));
        uint256 amountIn = _amountIn(aToB);

        address recipient = makeAddr("swapRecipient");
        tokenInStub.mint(address(this), amountIn);
        tokenInStub.approve(address(vault), amountIn);

        uint256 preview = vault.previewExchangeIn(tokenIn, amountIn, tokenOut);
        uint256 amountOut = vault.exchangeIn(tokenIn, amountIn, tokenOut, 0, recipient, false, _deadline());

        assertEq(amountOut, preview, "Execution should match preview");
        assertEq(tokenOut.balanceOf(recipient), preview, "Recipient should receive preview amount");
    }

    /* ---------------------------------------------------------------------- */
    /*                            Balance changes                             */
    /* ---------------------------------------------------------------------- */

    /// @notice pairToken → other balance deltas. Amount `_uA(1)`.
    function test_Route1Swap_balanceChanges_AtoB() public {
        _test_balanceChanges(true);
    }

    /// @notice other → pairToken balance deltas. Amount `_uB(1)`.
    function test_Route1Swap_balanceChanges_BtoA() public {
        _test_balanceChanges(false);
    }

    function _test_balanceChanges(bool aToB) internal {
        MintableERC20Decimals tokenInStub = aToB ? tokenA : tokenB;
        IERC20 tokenIn = IERC20(address(tokenInStub));
        IERC20 tokenOut = aToB ? IERC20(address(tokenB)) : IERC20(address(tokenA));
        uint256 amountIn = _amountIn(aToB);

        address recipient = makeAddr("balRecipient");
        tokenInStub.mint(address(this), amountIn);
        tokenInStub.approve(address(vault), amountIn);

        uint256 senderBefore = tokenIn.balanceOf(address(this));
        uint256 recipientBefore = tokenOut.balanceOf(recipient);

        uint256 amountOut = vault.exchangeIn(tokenIn, amountIn, tokenOut, 0, recipient, false, _deadline());

        assertEq(tokenIn.balanceOf(address(this)), senderBefore - amountIn, "Sender tokenIn decreased");
        assertEq(tokenOut.balanceOf(recipient), recipientBefore + amountOut, "Recipient tokenOut increased");
        assertTrue(amountOut > 0, "Non-zero out");
    }

    /* ---------------------------------------------------------------------- */
    /*                         H3 / minOut residual                           */
    /* ---------------------------------------------------------------------- */

    /// @notice H3-class: failed Route1 minOut leaves no free vault share inventory.
    /// @dev pairToken in is `_uA(1)`. vaultShare stays 18.
    function test_Route1Swap_H3_minOutTooHigh_noFreeShares() public {
        IERC20 tokenIn = IERC20(address(tokenA));
        IERC20 tokenOut = IERC20(address(tokenB));
        uint256 amountIn = _uA(1);

        tokenA.mint(address(this), amountIn);
        tokenA.approve(address(vault), amountIn);

        uint256 preview = vault.previewExchangeIn(tokenIn, amountIn, tokenOut);
        uint256 minTooHigh = preview + 1;
        uint256 sharesBefore = IERC20(address(vault)).balanceOf(address(vault));
        uint256 balBefore = tokenA.balanceOf(address(this));

        vm.expectRevert(abi.encodeWithSelector(IStandardExchangeErrors.MinAmountNotMet.selector, minTooHigh, preview));
        vault.exchangeIn(tokenIn, amountIn, tokenOut, minTooHigh, makeAddr("recipient"), false, _deadline());

        assertEq(IERC20(address(vault)).balanceOf(address(vault)), sharesBefore, "H3 residual vault shares");
        assertEq(tokenA.balanceOf(address(this)), balBefore, "input not consumed on failed swap");
    }
}
