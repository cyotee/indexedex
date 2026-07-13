// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IBalancerV3Pool} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IBalancerV3Pool.sol";
import {
    PoolSwapParams,
    SwapKind
} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/VaultTypes.sol";
import {Math} from "@crane/contracts/utils/Math.sol";

import {
    TestBase_StandardExchangeBufferPool_UniswapV2
} from "test/foundry/spec/protocols/dexes/balancer/v3/pools/constProd/standardExchange/uniswapV2/bases/TestBase_StandardExchangeBufferPool_UniswapV2.sol";

/**
 * @title TestBase_StandardExchangeBufferPool_UniV2
 * @notice Thin extension of `TestBase_StandardExchangeBufferPool_UniswapV2` that adds the
 *         rate-tracking integration test interface described in the Task 4 brief:
 *         real-trade rate levers (`_shiftRateUp` / `_shiftRateDown`) and the quote / full-path
 *         swap helpers the rate-tracking tests need.
 *
 * @dev Deliberately does NOT duplicate the existing UniswapV2 SE-vault fixture. Everything about
 *      constructing the Uniswap V2 pair, the SE vault, and the Balancer V3 buffer pool is inherited
 *      unchanged from `TestBase_StandardExchangeBufferPool_UniswapV2` (which itself extends
 *      `TestBase_StandardExchangeBufferPool`). This file only adds:
 *        - `counterAsset` / `shareToken` naming aliases for the brief's "Produces" list
 *          (the base already exposes the same tokens as `ttb` / `shares`; no renaming, just aliasing
 *          so both this suite and the existing comparative suite keep working unchanged).
 *        - `_shiftRateUp` / `_shiftRateDown` — real Uniswap V2 trades through `uniV2Router` that
 *          move the SE vault's NAV (and therefore `seRateProvider.getRate()`), asserting the
 *          direction deterministically.
 *        - `_quoteSwapExactIn` — direct `onSwap` quote helper (no state change), reading live
 *          balances from the Vault, matching the pattern already used in
 *          `StandardExchangeBufferPoolTarget.t.sol`.
 *        - `_navTtaPerRawShare` — NAV identity helper (`scalingFactor * rate / 1e18`).
 *        - `_swapThroughBalancerVault` — thin wrapper around the parent's `_doSwapExactIn`-style
 *          router swap, exposed under the brief's requested name.
 */
abstract contract TestBase_StandardExchangeBufferPool_UniV2 is TestBase_StandardExchangeBufferPool_UniswapV2 {
    /* ---------------------------------------------------------------------- */
    /*                          Brief Naming Aliases                           */
    /* ---------------------------------------------------------------------- */

    /// @notice Alias for `ttb` (USDC) — the other side of the underlying Uniswap V2 pair.
    function counterAsset() public view returns (IERC20) {
        return ttb;
    }

    /// @notice Alias for `shares` — the SE vault share token.
    function shareToken() public view returns (IERC20) {
        return shares;
    }

    /* ---------------------------------------------------------------------- */
    /*                              Rate Levers                                */
    /* ---------------------------------------------------------------------- */

    /**
     * @dev Moves the SE share NAV (in TTA terms) by trading through the underlying
     *      Uniswap V2 pair. Buying counterAsset with TTA raises counterAsset's TTA
     *      price; LP value in TTA terms ~ 2*sqrt(k * p_counter), so the share NAV —
     *      and therefore seRateProvider.getRate() — rises. Swap fees push NAV up in
     *      both directions, so _shiftRateDown trades the opposite way and asserts
     *      the net effect.
     */
    function _shiftRateUp() internal returns (uint256 newRate) {
        uint256 before = seRateProvider.getRate();
        uint256 amountIn = tta.balanceOf(address(this)) / 10;
        if (amountIn == 0) {
            mintTTA(address(this), 1_000_000e18);
            amountIn = tta.balanceOf(address(this)) / 10;
        }
        _swapThroughV2Pair(tta, ttb, amountIn);
        newRate = seRateProvider.getRate();
        assertGt(newRate, before, "rate did not increase");
    }

    function _shiftRateDown() internal returns (uint256 newRate) {
        uint256 before = seRateProvider.getRate();
        uint256 amountIn = ttb.balanceOf(address(this)) / 10;
        if (amountIn == 0) {
            // Acquire counterAsset by trading a chunk of TTA for it first (not rate-asserted).
            mintTTA(address(this), 1_000_000e18);
            uint256 seedIn = tta.balanceOf(address(this)) / 2;
            _swapThroughV2Pair(tta, ttb, seedIn);
            amountIn = ttb.balanceOf(address(this)) / 10;
        }
        _swapThroughV2Pair(ttb, tta, amountIn);
        newRate = seRateProvider.getRate();
        assertLt(newRate, before, "rate did not decrease");
    }

    /**
     * @dev Trades `amountIn` of `tokenIn` for `tokenOut` through the underlying Uniswap V2
     *      DAI/USDC pair via `uniV2Router`, minting/dealing `tokenIn` to this test contract
     *      first (mirroring the swap helpers in the UniswapV2 SE-vault spec tests).
     */
    function _swapThroughV2Pair(IERC20 tokenIn, IERC20 tokenOut, uint256 amountIn) internal {
        _mintTestToken(tokenIn, address(this), amountIn);

        address[] memory path = new address[](2);
        path[0] = address(tokenIn);
        path[1] = address(tokenOut);

        tokenIn.approve(address(uniV2Router), amountIn);
        uniV2Router.swapExactTokensForTokens(amountIn, 1, path, address(this), block.timestamp + 1 hours);
    }

    /// @dev Mints `amount` of `token` (tta or counterAsset) to `to`, using the concrete mint()
    ///      entry points exposed by the underlying ERC20TestToken instances (dai / usdc).
    function _mintTestToken(IERC20 token, address to, uint256 amount) internal {
        if (address(token) == address(dai)) {
            dai.mint(to, amount);
        } else if (address(token) == address(usdc)) {
            usdc.mint(to, amount);
        } else {
            revert("unsupported token for _mintTestToken");
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                         Quote / Swap Helpers                            */
    /* ---------------------------------------------------------------------- */

    /**
     * @dev Direct (non-state-changing) quote via `onSwap`, built from Vault-fresh live balances —
     *      the same pattern used in `StandardExchangeBufferPoolTarget.t.sol`. `onSwap` computes
     *      and returns amounts in the Vault's scaled18(+rated) space; this helper converts the
     *      output back to RAW token units (dividing out the output token's rate/scalingFactor)
     *      so callers can compare directly against NAV identities expressed in raw-share terms
     *      (`_navTtaPerRawShare`), matching what a real swap would actually deliver to a user.
     */
    function _quoteSwapExactIn(IERC20 tokenIn, IERC20 tokenOut, uint256 amountIn)
        internal
        returns (uint256 amountOut)
    {
        (PoolSwapParams memory params, uint256 idxOut) = _buildQuoteParams(tokenIn, tokenOut, amountIn);
        uint256 outScaled18 = IBalancerV3Pool(bufferPool).onSwap(params);

        (uint256[] memory scalingFactors, uint256[] memory rates) = bv3Vault.getPoolTokenRates(bufferPool);
        uint256 denom = scalingFactors[idxOut] * rates[idxOut];
        amountOut = denom == 0 ? outScaled18 : Math.mulDiv(outScaled18, 1e18, denom);
    }

    /**
     * @dev Builds the `PoolSwapParams` for a quote WITHOUT calling `onSwap`, so callers that need
     *      `onSwap` to be the literal next external call (e.g. under `vm.expectRevert`) can arm the
     *      revert expectation immediately before invoking `onSwap` themselves, instead of having it
     *      consumed early by this helper's own index/balance lookups.
     */
    function _buildQuoteParams(IERC20 tokenIn, IERC20 tokenOut, uint256 amountIn)
        internal
        view
        returns (PoolSwapParams memory params, uint256 idxOut)
    {
        uint256 idxIn = address(tokenIn) == address(tta) ? _ttaIdx() : _sharesIdx();
        idxOut = address(tokenOut) == address(tta) ? _ttaIdx() : _sharesIdx();

        uint256[] memory bal = bv3Vault.getCurrentLiveBalances(bufferPool);
        params = PoolSwapParams({
            kind: SwapKind.EXACT_IN,
            amountGivenScaled18: amountIn,
            balancesScaled18: bal,
            indexIn: idxIn,
            indexOut: idxOut,
            router: address(0),
            userData: ""
        });
    }

    /// @dev NAV identity: TTA per raw share = scalingFactor * rate / 1e18, where `scalingFactor`
    ///      is the Vault's decimal scaling factor for the shares token (10^(18-decimals), i.e. 1
    ///      for an 18-decimal token like the SE vault share token used throughout this fixture)
    ///      and `rate` is the Vault-sourced rate (`IVault.getPoolTokenRates`), read live so this
    ///      always matches the exact values `onSwap` sees.
    ///
    ///      NOTE: in integer arithmetic this floors to 0 whenever `scalingFactor * rate < 1e18`
    ///      (true in this fixture, where the SE vault's raw share supply is large relative to
    ///      backing value, so the true NAV genuinely is a sub-1-wei-per-1e18 fraction). Callers
    ///      needing shares-out from a TTA amount at this NAV MUST use `_sharesOutAtNav`, which
    ///      fuses the multiply/divide into a single `mulDiv` instead of inverting this value
    ///      (`dx * 1e18 / _navTtaPerRawShare(rate)` would revert FullMulDivFailed in that regime).
    ///      Exposed anyway because it is the direct "NAV" quantity the brief's tests describe.
    function _navTtaPerRawShare(uint256 rate) internal view returns (uint256) {
        (uint256[] memory scalingFactors,) = bv3Vault.getPoolTokenRates(bufferPool);
        uint256 scalingFactor = scalingFactors[_sharesIdx()];
        return Math.mulDiv(scalingFactor, rate, 1e18);
    }

    /// @dev Raw shares-out for `dx` raw TTA in, at the NAV identity: since TTA is a STANDARD
    ///      (unrated) 18-decimal token, `dx` raw == `dx` scaled18. At baseline (virtualTTA ==
    ///      derivedY, 50/50 effective weights) the pool's scaled18 quote for a small trade is
    ///      ~= dx (constant-product marginal price 1:1 in scaled18 space); converting that
    ///      scaled18 shares-out back to RAW shares via the same `scaled18 = raw * scalingFactor *
    ///      rate / 1e18` identity `_liftSharesToScaled18Rated` uses in production gives:
    ///        rawSharesOut = dx * 1e18 / (scalingFactor * rate)
    ///      Computed as a single `mulDiv` (not `dx * 1e18 / _navTtaPerRawShare(rate)`, which
    ///      would double-apply the `/1e18` baked into `_navTtaPerRawShare` and additionally
    ///      floors to 0 / reverts FullMulDivFailed whenever rate << 1e18 — see that function's
    ///      docs).
    function _sharesOutAtNav(uint256 dx, uint256 rate) internal view returns (uint256) {
        (uint256[] memory scalingFactors,) = bv3Vault.getPoolTokenRates(bufferPool);
        uint256 scalingFactor = scalingFactors[_sharesIdx()];
        return Math.mulDiv(dx, 1e18, scalingFactor * rate);
    }

    function _ttaIdx() internal view returns (uint256) {
        (IERC20[] memory tokens,,,) = bv3Vault.getPoolTokenInfo(bufferPool);
        return address(tokens[0]) == address(tta) ? 0 : 1;
    }

    function _sharesIdx() internal view returns (uint256) {
        return _ttaIdx() == 0 ? 1 : 0;
    }

    /// @dev Full-path EXACT_IN swap through the Balancer V3 RouterMock (this contract as user).
    function _swapThroughBalancerVault(IERC20 tokenIn, IERC20 tokenOut, uint256 amountIn)
        internal
        returns (uint256 amountOut)
    {
        _fundSelfWith(tokenIn, amountIn);
        tokenIn.approve(address(permit2), type(uint256).max);
        permit2.approve(address(tokenIn), address(router), type(uint160).max, type(uint48).max);
        amountOut = router.swapSingleTokenExactIn(
            bufferPool,
            tokenIn,
            tokenOut,
            amountIn,
            0,
            block.timestamp,
            false,
            bytes("")
        );
    }

    /// @dev Ensures this test contract holds at least `amount` of `token`, minting via the
    ///      appropriate path: TTA / counterAsset are ERC20TestTokens with a direct `mint()`
    ///      entry point; the share token is minted via the full V2-addLiquidity -> SE-vault-deposit
    ///      path (`mintShares`), same as `_initPool`/`mintShares` do for other actors.
    function _fundSelfWith(IERC20 token, uint256 amount) internal {
        uint256 have = token.balanceOf(address(this));
        if (have >= amount) return;
        uint256 shortfall = amount - have;

        if (address(token) == address(tta) || address(token) == address(ttb)) {
            _mintTestToken(token, address(this), shortfall);
        } else if (address(token) == address(shareToken())) {
            // mintShares uses a DAI-amount input to size the V2 liquidity add; over-provision
            // generously (shares received are highly correlated with DAI input) then top up
            // once more if still short due to price impact / vault fees.
            uint256 daiAmount = shortfall * 2 + 1e18;
            for (uint256 i = 0; i < 5 && token.balanceOf(address(this)) < amount; ++i) {
                mintShares(address(this), daiAmount);
                daiAmount *= 2;
            }
        } else {
            revert("unsupported token for _fundSelfWith");
        }
    }
}
