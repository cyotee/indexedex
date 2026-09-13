// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {
    toBeforeSwapDelta,
    BeforeSwapDelta
} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BeforeSwapDelta.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {Hooks} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol";
import {ModifyLiquidityParams, SwapParams} from
    "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {BalanceDelta} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHookCommon
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHookRepo as Repo
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookRepo.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHookMath as Math
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookMath.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHookClaimLib as ClaimLib
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookClaimLib.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHookPairPoolLib as PairPoolLib
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookPairPoolLib.sol";
import {
    IUniswapV4StandardExchangeOrbitalBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHook.sol";
import {
    UniswapV4SeBufferHookLegLib
} from "contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol";

/// @title UniswapV4StandardExchangeOrbitalBufferHookDepositTarget
/// @notice Role Target for orbital buffer hook size split (Option 1a).
abstract contract UniswapV4StandardExchangeOrbitalBufferHookDepositTarget is UniswapV4StandardExchangeOrbitalBufferHookCommon {
    using SafeERC20 for IERC20;

    function addLiquidity(
        uint256 a0Max,
        uint256 a1Max,
        uint256 a2Max,
        address to,
        uint256 sharesMin,
        uint256 deadline,
        bytes calldata permit2Data
    ) external onlyLiquidityOwner nonReentrant returns (uint256 shares, uint256 a0, uint256 a1, uint256 a2) {
        return _addLiquidity(a0Max, a1Max, a2Max, to, sharesMin, deadline, permit2Data);
    }


    function depositSingle(
        address tokenIn,
        uint256 amountIn,
        address to,
        uint256 sharesMin,
        uint256 deadline,
        bytes calldata permit2Data
    ) external onlyLiquidityOwner nonReentrant returns (uint256 shares) {
        return _depositSingle(tokenIn, amountIn, to, sharesMin, deadline, permit2Data);
    }


    function previewAddLiquidity(uint256 a0Max, uint256 a1Max, uint256 a2Max)
        external
        view
        returns (uint256 shares, uint256 a0, uint256 a1, uint256 a2)
    {
        return _previewAddLiquidity(a0Max, a1Max, a2Max);
    }


    function previewDepositSingle(address tokenIn, uint256 amountIn)
        external
        view
        returns (uint256 shares)
    {
        return _previewDepositSingle(tokenIn, amountIn);
    }


    function previewZapSplit(address tokenIn, uint256 amountIn)
        external
        view
        returns (uint256 saleJ, uint256 saleK, uint256 residualIn, uint256 outJ, uint256 outK)
    {
        return _previewZapSplit(tokenIn, amountIn);
    }


    function depositFlexible(
        uint256 amount0,
        bool amount0IsSeShare,
        uint256 amount1,
        bool amount1IsSeShare,
        uint256 amount2,
        bool amount2IsSeShare,
        address to,
        uint256 sharesMin,
        uint256 deadline
    ) external onlyLiquidityOwner nonReentrant returns (uint256 shares, uint256 used0, uint256 used1, uint256 used2) {
        DepositFlexibleVars memory v;
        v.amount0 = amount0;
        v.amount0IsSeShare = amount0IsSeShare;
        v.amount1 = amount1;
        v.amount1IsSeShare = amount1IsSeShare;
        v.amount2 = amount2;
        v.amount2IsSeShare = amount2IsSeShare;
        v.to = to;
        v.sharesMin = sharesMin;
        return _depositFlexible(v, deadline);
    }


    function previewDepositFlexible(
        uint256 amount0,
        bool amount0IsSeShare,
        uint256 amount1,
        bool amount1IsSeShare,
        uint256 amount2,
        bool amount2IsSeShare
    ) external view returns (uint256 shares, uint256 used0, uint256 used1, uint256 used2) {
        DepositFlexibleVars memory v;
        v.amount0 = amount0;
        v.amount0IsSeShare = amount0IsSeShare;
        v.amount1 = amount1;
        v.amount1IsSeShare = amount1IsSeShare;
        v.amount2 = amount2;
        v.amount2IsSeShare = amount2IsSeShare;
        return _previewDepositFlexible(v);
    }

    struct JoinUnbalancedAcc {
        uint256 amount0;
        uint256 amount1;
        uint256 amount2;
        bool isSe0;
        bool isSe1;
        bool isSe2;
        bool saw0;
        bool saw1;
        bool saw2;
    }

    function joinProportional(
        uint256[] calldata amounts,
        address to,
        uint256 sharesMin,
        uint256 deadline
    ) external onlyLiquidityOwner nonReentrant returns (uint256 shares, uint256[] memory usedAmounts) {
        if (amounts.length != 3) revert InvalidRoute(address(0), address(0));
        uint256 used0;
        uint256 used1;
        uint256 used2;
        (shares, used0, used1, used2) =
            _addLiquidity(amounts[0], amounts[1], amounts[2], to, sharesMin, deadline, "");
        usedAmounts = new uint256[](3);
        usedAmounts[0] = used0;
        usedAmounts[1] = used1;
        usedAmounts[2] = used2;
    }

    function previewJoinProportional(uint256[] calldata amounts)
        external
        view
        returns (uint256 shares, uint256[] memory usedAmounts)
    {
        if (amounts.length != 3) revert InvalidRoute(address(0), address(0));
        uint256 used0;
        uint256 used1;
        uint256 used2;
        (shares, used0, used1, used2) = _previewAddLiquidity(amounts[0], amounts[1], amounts[2]);
        usedAmounts = new uint256[](3);
        usedAmounts[0] = used0;
        usedAmounts[1] = used1;
        usedAmounts[2] = used2;
    }

    function joinUnbalanced(
        address[] calldata tokensIn,
        uint256[] calldata amounts,
        address to,
        uint256 sharesMin,
        uint256 deadline
    ) external onlyLiquidityOwner nonReentrant returns (uint256 shares) {
        JoinUnbalancedAcc memory acc = _accumulateJoin(tokensIn, amounts);
        _requireFirstJoinFullBook(acc);
        DepositFlexibleVars memory v = _accToFlexible(acc, to, sharesMin);
        (shares,,,) = _depositFlexible(v, deadline);
    }

    function previewJoinUnbalanced(address[] calldata tokensIn, uint256[] calldata amounts)
        external
        view
        returns (uint256 shares)
    {
        JoinUnbalancedAcc memory acc = _accumulateJoin(tokensIn, amounts);
        if (!_isLive() && !(acc.saw0 && acc.saw1 && acc.saw2)) {
            return 0;
        }
        DepositFlexibleVars memory v = _accToFlexible(acc, address(0), 0);
        (shares,,,) = _previewDepositFlexible(v);
    }

    function joinSingleAssetExactIn(
        address tokenIn,
        uint256 amountIn,
        address to,
        uint256 sharesMin,
        uint256 deadline
    ) external onlyLiquidityOwner nonReentrant returns (uint256 shares) {
        if (!_isLive()) revert NotLive();
        Repo.Layout storage l = Repo._layout();
        UniswapV4SeBufferHookLegLib.LegKind kind_ =
            UniswapV4SeBufferHookLegLib.classify(l.legs, tokenIn);
        if (kind_ == UniswapV4SeBufferHookLegLib.LegKind.Unknown) {
            revert InvalidRoute(tokenIn, address(0));
        }
        if (kind_ == UniswapV4SeBufferHookLegLib.LegKind.StandardExchange) {
            IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
            address pair_ = l.legs.pairOfStandardExchange[tokenIn];
            uint256 pairOut_ = _unwrapSeShares(pair_, amountIn);
            return _depositSingleFromBalance(pair_, pairOut_, to, sharesMin, deadline);
        }
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        return _depositSingleFromBalance(tokenIn, amountIn, to, sharesMin, deadline);
    }

    function previewJoinSingleAssetExactIn(address tokenIn, uint256 amountIn)
        external
        view
        returns (uint256 shares)
    {
        if (!_isLive() || amountIn == 0) return 0;
        Repo.Layout storage l = Repo._layout();
        UniswapV4SeBufferHookLegLib.LegKind kind_ =
            UniswapV4SeBufferHookLegLib.classify(l.legs, tokenIn);
        if (kind_ == UniswapV4SeBufferHookLegLib.LegKind.Unknown) return 0;
        if (kind_ == UniswapV4SeBufferHookLegLib.LegKind.StandardExchange) {
            address pair_ = l.legs.pairOfStandardExchange[tokenIn];
            uint256 pairOut_ = ClaimLib.previewUnwrapShares(tokenIn, pair_, amountIn);
            if (pairOut_ == 0) return 0;
            return _previewDepositSingle(pair_, pairOut_);
        }
        return _previewDepositSingle(tokenIn, amountIn);
    }

    function joinSingleAssetExactOut(
        address tokenIn,
        uint256 sharesOut,
        address to,
        uint256 amountInMax,
        uint256 deadline
    ) external onlyLiquidityOwner nonReentrant returns (uint256 amountIn) {
        sharesOut;
        to;
        amountInMax;
        deadline;
        revert InvalidRoute(tokenIn, address(0));
    }

    function previewJoinSingleAssetExactOut(address, uint256) external view returns (uint256) {
        return 0;
    }

    function _accumulateJoin(address[] calldata tokensIn, uint256[] calldata amounts)
        internal
        view
        returns (JoinUnbalancedAcc memory acc)
    {
        if (tokensIn.length != amounts.length) revert InvalidRoute(address(0), address(0));
        Repo.Layout storage l = Repo._layout();
        for (uint256 i; i < tokensIn.length; ++i) {
            if (amounts[i] == 0) continue;
            UniswapV4SeBufferHookLegLib.LegKind kind_ =
                UniswapV4SeBufferHookLegLib.classify(l.legs, tokensIn[i]);
            if (kind_ == UniswapV4SeBufferHookLegLib.LegKind.Unknown) {
                revert InvalidRoute(tokensIn[i], address(0));
            }
            uint8 idx_;
            bool isSe_;
            if (kind_ == UniswapV4SeBufferHookLegLib.LegKind.StandardExchange) {
                idx_ = Repo._indexOf(l, l.legs.pairOfStandardExchange[tokensIn[i]]);
                isSe_ = true;
            } else {
                idx_ = Repo._indexOf(l, tokensIn[i]);
            }
            _creditJoinAcc(acc, idx_, amounts[i], isSe_);
        }
    }

    function _creditJoinAcc(JoinUnbalancedAcc memory acc, uint8 idx_, uint256 amount, bool isSe_)
        private
        pure
    {
        if (idx_ == 0) {
            if (acc.saw0 && acc.isSe0 != isSe_) revert PairAndShareSameLeg();
            if (acc.saw0 && acc.isSe0 == isSe_) revert InvalidRoute(address(0), address(0));
            acc.saw0 = true;
            acc.isSe0 = isSe_;
            acc.amount0 += amount;
        } else if (idx_ == 1) {
            if (acc.saw1 && acc.isSe1 != isSe_) revert PairAndShareSameLeg();
            if (acc.saw1 && acc.isSe1 == isSe_) revert InvalidRoute(address(0), address(0));
            acc.saw1 = true;
            acc.isSe1 = isSe_;
            acc.amount1 += amount;
        } else {
            if (acc.saw2 && acc.isSe2 != isSe_) revert PairAndShareSameLeg();
            if (acc.saw2 && acc.isSe2 == isSe_) revert InvalidRoute(address(0), address(0));
            acc.saw2 = true;
            acc.isSe2 = isSe_;
            acc.amount2 += amount;
        }
    }

    function _requireFirstJoinFullBook(JoinUnbalancedAcc memory acc) internal view {
        if (_isLive()) return;
        if (!(acc.saw0 && acc.saw1 && acc.saw2)) revert FirstJoinMustBeFullBook();
    }

    function _accToFlexible(JoinUnbalancedAcc memory acc, address to, uint256 sharesMin)
        private
        pure
        returns (DepositFlexibleVars memory v)
    {
        v.amount0 = acc.amount0;
        v.amount0IsSeShare = acc.isSe0;
        v.amount1 = acc.amount1;
        v.amount1IsSeShare = acc.isSe1;
        v.amount2 = acc.amount2;
        v.amount2IsSeShare = acc.isSe2;
        v.to = to;
        v.sharesMin = sharesMin;
    }
}
