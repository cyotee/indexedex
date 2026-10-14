// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {NativeStandardYieldPreviewTarget} from "contracts/vaults/standard/sy/NativeStandardYieldPreviewTarget.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {Math as FullMath} from "@crane/contracts/utils/Math.sol";
import {UniswapV4StandardExchangeOrbitalBufferHookRepo as Repo} from "./UniswapV4StandardExchangeOrbitalBufferHookRepo.sol";

import {UniswapV4StandardExchangeOrbitalBufferHookExitQuoteLib as ExitQuoteLib} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookExitQuoteLib.sol";
import {UniswapV4StandardExchangeOrbitalBufferHookRepo as Repo} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookRepo.sol";
import {UniswapV4StandardExchangeOrbitalBufferHookDepositCore} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookDepositCore.sol";

/// @notice Read-only liquidity quotes. Shared core retains the accounting and checks.
abstract contract UniswapV4StandardExchangeOrbitalBufferHookDepositQueryTarget is UniswapV4StandardExchangeOrbitalBufferHookDepositCore, NativeStandardYieldPreviewTarget {
    function getTokensIn() public view override returns (address[] memory tokens) {
        Repo.Layout storage l = Repo._layout();
        uint256 count = 3;
        for (uint8 i; i < 3; ++i) if (Repo._seAt(l, i) != address(0)) ++count;
        tokens = new address[](count);
        count = 3;
        for (uint8 i; i < 3; ++i) {
            tokens[i] = Repo._tokenAt(l, i);
            address se = Repo._seAt(l, i);
            if (se != address(0)) tokens[count++] = se;
        }
    }
    function getTokensOut() public view override returns (address[] memory) { return getTokensIn(); }
    function yieldToken() external pure override returns (address) { return address(0); }
    function assetInfo() external view override returns (IStandardizedYield.AssetType, address, uint8) {
        return (IStandardizedYield.AssetType.LIQUIDITY, address(this), 18);
    }
    function exchangeRate() external view override returns (uint256) {
        (, uint256 supply) = _previewProtocolMintShares();
        if (supply == 0) return 1e18;
        (uint256 x, uint256 y, uint256 z) = _effectiveWad();
        (,, uint256 root) = _measureK(x, y, z);
        return FullMath.mulDiv(root, 1e18, supply);
    }
    function previewExchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut) external view returns (uint256) {
        return _previewExchangeIn(tokenIn, amountIn, tokenOut);
    }

    function previewJoinAfterDeposit(address tokenIn, address pairToken, uint256 amountIn)
        external view returns (uint256)
    {
        if (!_isLive() || amountIn == 0) return 0;
        _requireZapEligibleOrOwnerMin();
        return ExitQuoteLib.previewJoinAfterDeposit(tokenIn, pairToken, amountIn);
    }

    function previewBondAfterDeposit(address tokenIn, address pairToken, address detfToken, uint256 amountIn, uint256 multiplier)
        external view returns (uint256, uint256, uint256)
    {
        return ExitQuoteLib.previewBondAfterDeposit(tokenIn, pairToken, detfToken, amountIn, multiplier);
    }

    function radius() public view returns (uint256) {
        return Repo._layout().R;
    }

    function previewAddLiquidity(uint256 a0Max, uint256 a1Max, uint256 a2Max)
        external
        view
        returns (uint256 shares, uint256 a0, uint256 a1, uint256 a2)
    {
        return _entryPreviewAddLiquidity(a0Max, a1Max, a2Max);
    }

    function previewDepositSingle(address tokenIn, uint256 amountIn)
        external
        view
        returns (uint256 shares)
    {
        return _entryPreviewDepositSingle(tokenIn, amountIn);
    }

    function previewZapSplit(address tokenIn, uint256 amountIn)
        external
        view
        returns (uint256 saleJ, uint256 saleK, uint256 residualIn, uint256 outJ, uint256 outK)
    {
        return _entryPreviewZapSplit(tokenIn, amountIn);
    }

    function previewDepositFlexible(
        uint256 amount0,
        bool amount0IsSeShare,
        uint256 amount1,
        bool amount1IsSeShare,
        uint256 amount2,
        bool amount2IsSeShare
    ) external view returns (uint256 shares, uint256 used0, uint256 used1, uint256 used2) {
        return _entryPreviewDepositFlexible(amount0, amount0IsSeShare, amount1, amount1IsSeShare, amount2, amount2IsSeShare);
    }

    function previewJoinProportional(uint256[] calldata amounts)
        external
        view
        returns (uint256 shares, uint256[] memory usedAmounts)
    {
        return _entryPreviewJoinProportional(amounts);
    }

    function previewJoinUnbalanced(address[] calldata tokensIn, uint256[] calldata amounts)
        external
        view
        returns (uint256 shares)
    {
        return _entryPreviewJoinUnbalanced(tokensIn, amounts);
    }

    function previewJoinSingleAssetExactIn(address tokenIn, uint256 amountIn)
        external
        view
        returns (uint256 shares)
    {
        return _entryPreviewJoinSingleAssetExactIn(tokenIn, amountIn);
    }

    function previewJoinSingleAssetExactOut(address tokenIn, uint256 sharesOut) external view returns (uint256) {
        return _entryPreviewJoinSingleAssetExactOut(tokenIn, sharesOut);
    }

}
