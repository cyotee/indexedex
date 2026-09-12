// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {
    UniswapV4SingleStandardExchangeBufferConstantProductHookRepo as Repo
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookRepo.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHookPullLib as PullLib
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookPullLib.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHook.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {UniswapV4SingleStandardExchangeBufferConstantProductHookMath as Math} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookMath.sol";
import {UniswapV4SeBufferHookLegLib} from "contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol";
import {Math as FullMath} from "@crane/contracts/utils/Math.sol";

import {
    UniswapV4SingleStandardExchangeBufferConstantProductHookDepositCommon
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookDepositCommon.sol";

/// @title UniswapV4SingleStandardExchangeBufferConstantProductHookDepositSingleTarget
/// @notice Single-asset CP deposits sharing the reserve accounting and reentrancy guard.
abstract contract UniswapV4SingleStandardExchangeBufferConstantProductHookDepositSingleTarget is
    UniswapV4SingleStandardExchangeBufferConstantProductHookDepositCommon
{
    function previewSwapAfterExchange(address tokenIn, address pairToken, address rawTokenOut, uint256 amountIn)
        external view returns (uint256 amountOut)
    {
        Repo.Layout storage l = Repo._layout();
        if (pairToken != l.pairToken || rawTokenOut != l.rawToken) revert UnsupportedRoute();
        UniswapV4SeBufferHookLegLib.ExternalQuote memory q = UniswapV4SeBufferHookLegLib
            .afterExternalExchange(l.standardExchange, pairToken, tokenIn, amountIn, address(this));
        return _swapAtExternalState(q);
    }

    function previewBondAfterDeposit(address tokenIn, address pairToken, address detfToken, uint256 amountIn, uint256 multiplier)
        external view returns (uint256 pairValue, uint256 purchasedDetf, uint256 liquidityDetf)
    {
        Repo.Layout storage l = Repo._layout();
        if (pairToken != l.pairToken || detfToken != l.rawToken) revert UnsupportedRoute();
        UniswapV4SeBufferHookLegLib.ExternalQuote memory q = UniswapV4SeBufferHookLegLib
            .afterExternalDeposit(l.standardExchange, pairToken, tokenIn, amountIn, address(this));
        pairValue = q.exchange.quoteAssets(q.state, q.assets);
        if (!_isLive()) return (pairValue, 0, 0);
        liquidityDetf = UniswapV4SeBufferHookLegLib.matchingLiquidityDetf(
            q, IERC20(l.rawToken).balanceOf(address(this)), pairValue,
            _supplyAfterProtocolMintForPairClaim(q.heldAssets), Repo.MAX_DUST_WEI
        );
        q.assets = FullMath.mulDiv(pairValue, multiplier, 1e18);
        purchasedDetf = _swapAtExternalState(q);
    }

    function _swapAtExternalState(UniswapV4SeBufferHookLegLib.ExternalQuote memory q)
        private view returns (uint256)
    {
        (uint256 minted, uint256 afterClaim) = UniswapV4SeBufferHookLegLib.depositAfterExchange(q, q.assets);
        uint256 beforeClaim = q.heldAssets;
        if (beforeClaim == 0 && q.heldShares > 0) beforeClaim = 1;
        if (afterClaim == 0 && q.heldShares + minted > 0) afterClaim = 1;
        return _quotePairClaimIn(beforeClaim, afterClaim > beforeClaim ? afterClaim - beforeClaim : 0);
    }

    function _quotePairClaimIn(uint256 seClaim, uint256 claimIn) private view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        return Math.fromWadFloor(Math.saleQuote(
            Math.toWad(claimIn, _decimalsOf(l.pairToken)),
            Math.toWad(seClaim, _decimalsOf(l.pairToken)),
            Math.toWad(IERC20(l.rawToken).balanceOf(address(this)), _decimalsOf(l.rawToken))
        ), _decimalsOf(l.rawToken));
    }

    /// @notice CP joinSingleAssetExactIn entry point.
    function joinSingleAssetExactIn(address tokenIn, uint256 amountIn, address to, uint256 sharesMin, uint256 deadline)
        external
        onlyLiquidityOwner
        nonReentrant
        accrueProtocolFee
        returns (uint256 shares)
    {
        if (!_isLive()) revert NotLive();
        Repo.Layout storage l = Repo._layout();
        UniswapV4SeBufferHookLegLib.LegKind kind = UniswapV4SeBufferHookLegLib.classify(l.legs, tokenIn);
        if (kind == UniswapV4SeBufferHookLegLib.LegKind.Unknown) revert InvalidRoute();
        PullLib.pullErc20Single(tokenIn, amountIn);
        if (kind == UniswapV4SeBufferHookLegLib.LegKind.StandardExchange) {
            uint256 pairOut = _unwrapSeShares(amountIn);
            return _depositSingle(l.pairToken, pairOut, to, sharesMin, deadline);
        }
        return _depositSingle(tokenIn, amountIn, to, sharesMin, deadline);
    }

    /// @notice CP joinSingleAssetExactOut entry point.
    function joinSingleAssetExactOut(
        address tokenIn,
        uint256 sharesOut,
        address to,
        uint256 amountInMax,
        uint256 deadline
    ) external onlyLiquidityOwner nonReentrant returns (uint256 amountIn) {
        if (!_isLive()) revert NotLive();
        // Preview includes pending protocol LP; quote before minting that LP into supply.
        uint256 previewIn = IHook(address(this)).previewDepositSingle(tokenIn, amountInMax);
        if (previewIn < sharesOut) revert InsufficientLpOut();
        _mintProtocolFeeIfNeeded();
        PullLib.pullErc20Single(tokenIn, amountInMax);
        uint256 minted = _depositSingle(tokenIn, amountInMax, to, sharesOut, deadline);
        minted;
        return amountInMax;
    }

    /// @notice CP depositSingle entry point.
    function depositSingle(address tokenIn, uint256 amountIn, address to, uint256 minLpAmount, uint256 deadline)
        external
        onlyLiquidityOwner
        nonReentrant
        accrueProtocolFee
        returns (uint256 lpAmount)
    {
        PullLib.pullErc20Single(tokenIn, amountIn);
        return _depositSingle(tokenIn, amountIn, to, minLpAmount, deadline);
    }

    /// @notice CP depositSingleWithPermit2Signature entry point.
    function depositSingleWithPermit2Signature(
        address tokenIn,
        uint256 amountIn,
        address to,
        uint256 minLpAmount,
        uint256 deadline,
        bytes calldata permit2Data
    ) external onlyLiquidityOwner nonReentrant accrueProtocolFee returns (uint256 lpAmount) {
        PullLib.pullPermit2SignatureSingle(tokenIn, amountIn, permit2Data);
        return _depositSingle(tokenIn, amountIn, to, minLpAmount, deadline);
    }

    /// @notice CP depositSingleWithPermit2Allowance entry point.
    function depositSingleWithPermit2Allowance(
        address tokenIn,
        uint256 amountIn,
        address to,
        uint256 minLpAmount,
        uint256 deadline
    ) external onlyLiquidityOwner nonReentrant accrueProtocolFee returns (uint256 lpAmount) {
        PullLib.pullPermit2AllowanceSingle(tokenIn, amountIn);
        return _depositSingle(tokenIn, amountIn, to, minLpAmount, deadline);
    }
}
