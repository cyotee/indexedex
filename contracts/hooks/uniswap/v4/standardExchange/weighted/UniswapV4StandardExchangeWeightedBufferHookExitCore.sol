// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV4StandardExchangeWeightedBufferHookJoinCore} from "./UniswapV4StandardExchangeWeightedBufferHookJoinCore.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {Math as FullMath} from "@crane/contracts/utils/Math.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {
    toBeforeSwapDelta,
    BeforeSwapDelta
} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BeforeSwapDelta.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {Hooks} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol";
import {LPFeeLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LPFeeLibrary.sol";
import {ModifyLiquidityParams, SwapParams} from
    "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {BalanceDelta} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IRateProvider} from
    "@crane/contracts/protocols/dexes/balancer/common/interfaces/IRateProvider.sol";
import {IAllowanceTransfer} from
    "@crane/contracts/interfaces/protocols/utils/permit2/IAllowanceTransfer.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {
    IUniswapV4StandardExchangeWeightedBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHook.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHookRepo as Repo
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookRepo.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHookMath as Math
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookMath.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHookPairPoolLib as PairPoolLib
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookPairPoolLib.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {
    UniswapV4SeBufferHookLegLib
} from "contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol";

/**
 * @title UniswapV4StandardExchangeWeightedBufferHookTarget
 * @notice Product logic: dual-scale weighted book, SE buffer-last LP, rated V4/SE swaps, MultiAssetLiquidity.
 * @dev No BaseHook / DeltaResolver inheritance. LP via ERC20Repo; inventory = face | live SE shares.
 */
import {
    UniswapV4StandardExchangeWeightedBufferHookLiquidityLib as LiqLib
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookLiquidityLib.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHookTarget
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookTarget.sol";

/**
 * @title UniswapV4StandardExchangeWeightedBufferHookExitTarget
 * @notice Join/exit + one-token aliases (inventory domain, buffer-last).
 */
abstract contract UniswapV4StandardExchangeWeightedBufferHookExitCore is
    UniswapV4StandardExchangeWeightedBufferHookJoinCore
{
    using SafeERC20 for IERC20;

    function _entryPreviewBurnToToken(uint256 lpAmount, address tokenOut)
        internal
        view
        returns (uint256 amountOut)
    {
        if (lpAmount == 0 || _totalSupply() == 0) return 0;
        Repo.Layout storage l = Repo._layout();
        UniswapV4SeBufferHookLegLib.LegKind k =
            UniswapV4SeBufferHookLegLib.classify(l.legs, tokenOut);
        if (k == UniswapV4SeBufferHookLegLib.LegKind.Unknown) return 0;
        if (k == UniswapV4SeBufferHookLegLib.LegKind.StandardExchange) {
            tokenOut = l.legs.pairOfStandardExchange[tokenOut];
        }
        uint256[] memory amounts = _entryPreviewExitProportional(lpAmount);
        address detf_ = l.legs.detfToken;
        uint8 jOut = _tokenIndex(tokenOut);
        for (uint8 i; i < l.numTokens; ++i) {
            if (amounts[i] == 0) continue;
            address t = l.tokens[i];
            if (t == tokenOut) {
                amountOut += amounts[i];
            } else if (t == detf_) {
                continue;
            } else {
                amountOut += Math.descale(Math.scaleTo(amounts[i], l.ratedScales[i]), l.ratedScales[jOut]);
            }
        }
    }

    function _entryPreviewExitProportional(uint256 burned) internal view returns (uint256[] memory) { return LiqLib.previewExit(burned, _flags()); }
    function _entryPreviewExitProportionalFlexible(uint256 burned, bool[] calldata flags) internal view returns (uint256[] memory) { return LiqLib.previewExit(burned, flags); }

    function _entryExitProportional(uint256 burned, address to, uint256[] calldata minima, uint256 deadline)
        internal onlyLiquidityRemover nonReentrant returns (uint256[] memory amounts) {
        _requireDeadline(deadline);
        if (to == address(0)) revert ZeroAddress();
        if (burned == 0) revert ZeroAmount();
        if (minima.length != Repo._layout().numTokens) revert InvalidN();
        amounts = LiqLib.exit(msg.sender, burned, _flags(), to, minima);
        _syncVaultReserves();
        int256[] memory deltas = new int256[](amounts.length);
        for (uint256 i; i < amounts.length; ++i) deltas[i] = -int256(amounts[i]);
        emit IUniswapV4StandardExchangeWeightedBufferHook.Exit(msg.sender, to, burned, deltas, 0);
    }
    function _entryExitProportionalFlexible(uint256 burned, address to, bool[] calldata flags, uint256[] calldata minima, uint256 deadline)
        internal onlyLiquidityRemover nonReentrant returns (uint256[] memory amounts) {
        _requireDeadline(deadline);
        if (to == address(0)) revert ZeroAddress();
        if (burned == 0) revert ZeroAmount();
        amounts = LiqLib.exit(msg.sender, burned, flags, to, minima);
        _syncVaultReserves();
        emit IUniswapV4StandardExchangeWeightedBufferHook.ExitFlexible(msg.sender, to, burned, flags, amounts, 0);
    }

    function _singleExitBounds(uint256 burned) private view {
        if (!_isLive()) revert NotFullBook();
        if (burned == 0) revert ZeroAmount();
        if (burned > FullMath.mulDiv(_totalSupply(), Math.WAD - Math.MIN_INVARIANT_RATIO, Math.WAD)) revert Math.MinInvariantRatio();
    }
    function _quoteExitSingleExactBptInFlexible(address tokenOut, uint256 burned, bool asShare) internal view returns (uint256) {
        _singleExitBounds(burned);
        return LiqLib.previewSingleExit(_tokenIndex(tokenOut), burned, asShare);
    }
    function _entryPreviewExitSingleAssetExactBptIn(address tokenOut, uint256 burned) internal view returns (uint256) { return _quoteExitSingleExactBptInFlexible(tokenOut, burned, false); }
    function _entryPreviewWithdrawSingle(address tokenOut, uint256 burned) internal view returns (uint256) { return _quoteExitSingleExactBptInFlexible(tokenOut, burned, false); }
    function _entryPreviewExitSingleAssetExactBptInFlexible(address tokenOut, uint256 burned, bool asShare) internal view returns (uint256) { return _quoteExitSingleExactBptInFlexible(tokenOut, burned, asShare); }
    function _entryPreviewWithdrawSingleFlexible(address tokenOut, uint256 burned, bool asShare) internal view returns (uint256) { return _quoteExitSingleExactBptInFlexible(tokenOut, burned, asShare); }

    function _exitSingleAssetFrom(address holder, address tokenOut, uint256 burned, bool asShare, address to, uint256 minimum, uint256 deadline) internal returns (uint256 out) {
        _requireDeadline(deadline);
        if (to == address(0)) revert ZeroAddress();
        _singleExitBounds(burned);
        out = LiqLib.singleExit(holder, _tokenIndex(tokenOut), burned, asShare, to, minimum, 0);
        _syncVaultReserves();
        emit IUniswapV4StandardExchangeWeightedBufferHook.WithdrawSingleFlexible(msg.sender, to, tokenOut, out, asShare, burned, 0);
    }
    function _entryExitSingleAssetExactBptIn(address tokenOut, uint256 burned, address to, uint256 minimum, uint256 deadline)
        internal onlyLiquidityRemover nonReentrant returns (uint256) { return _exitSingleAssetFrom(msg.sender, tokenOut, burned, false, to, minimum, deadline); }
    function _entryWithdrawSingle(address tokenOut, uint256 burned, address to, uint256 minimum, uint256 deadline)
        internal onlyLiquidityRemover nonReentrant returns (uint256) { return _exitSingleAssetFrom(msg.sender, tokenOut, burned, false, to, minimum, deadline); }
    function _entryExitSingleAssetExactBptInFlexible(address tokenOut, uint256 burned, bool asShare, address to, uint256 minimum, uint256 deadline)
        internal onlyLiquidityRemover nonReentrant returns (uint256) { return _exitSingleAssetFrom(msg.sender, tokenOut, burned, asShare, to, minimum, deadline); }
    function _entryWithdrawSingleFlexible(address tokenOut, uint256 burned, bool asShare, address to, uint256 minimum, uint256 deadline)
        internal onlyLiquidityRemover nonReentrant returns (uint256) { return _exitSingleAssetFrom(msg.sender, tokenOut, burned, asShare, to, minimum, deadline); }

    function _entryPreviewExitSingleAssetExactTokenOut(address tokenOut, uint256 amount) internal view returns (uint256 burned) {
        if (!_isLive()) revert NotFullBook();
        if (amount == 0) revert ZeroAmount();
        uint8 i = _tokenIndex(tokenOut);
        Repo.Layout storage l = Repo._layout();
        uint256 inventory;
        if (l.standardExchanges[i] == address(0)) inventory = amount;
        else {
            // Preserve the existing unsupported inverse-conversion boundary.
            inventory = IStandardExchangeOut(l.standardExchanges[i]).previewExchangeOut(IERC20(l.standardExchanges[i]), IERC20(tokenOut), amount);
            if (inventory == 0) revert IStandardExchangeOut.ExchangeOutNotAvailable();
        }
        burned = Math.singleExitExactOutSharesIn(_invWadAll(), l.weights, i, Math.scaleToUp(inventory, l.invScales[i]), _totalSupply(), _feeOracle().dexSwapFeeOfVault(address(this)));
        uint256 predicted = _quoteExitSingleExactBptInFlexible(tokenOut, burned, false);
        if (predicted < amount && predicted != 0) burned = FullMath.mulDiv(burned, amount, predicted, FullMath.Rounding.Ceil) + 1;
        if (_quoteExitSingleExactBptInFlexible(tokenOut, burned, false) < amount) revert Slippage();
    }
    function _entryPreviewWithdrawSingleExactOut(address tokenOut, uint256 amount) internal view returns (uint256) { return _entryPreviewExitSingleAssetExactTokenOut(tokenOut, amount); }

    function _exitExactOutput(address tokenOut, uint256 amount, address to, uint256 maximum, uint256 deadline) private returns (uint256 burned) {
        _requireDeadline(deadline);
        if (to == address(0)) revert ZeroAddress();
        burned = _entryPreviewExitSingleAssetExactTokenOut(tokenOut, amount);
        if (burned > maximum) revert Slippage();
        LiqLib.singleExit(msg.sender, _tokenIndex(tokenOut), burned, false, to, amount, amount);
        _syncVaultReserves();
        emit IUniswapV4StandardExchangeWeightedBufferHook.WithdrawSingleExactOut(msg.sender, to, tokenOut, amount, burned, 0);
    }
    function _entryExitSingleAssetExactTokenOut(address tokenOut, uint256 amount, address to, uint256 maximum, uint256 deadline)
        internal onlyLiquidityRemover nonReentrant returns (uint256) { return _exitExactOutput(tokenOut, amount, to, maximum, deadline); }
    function _entryWithdrawSingleExactOut(address tokenOut, uint256 amount, address to, uint256 maximum, uint256 deadline)
        internal onlyLiquidityRemover nonReentrant returns (uint256) { return _exitExactOutput(tokenOut, amount, to, maximum, deadline); }
}
