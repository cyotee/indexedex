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
import {
    UniswapV4DualStandardExchangeBufferConstantProductHookCommon
} from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookCommon.sol";
import {
    UniswapV4DualStandardExchangeBufferConstantProductHookRepo as Repo
} from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookRepo.sol";
import {
    UniswapV4DualStandardExchangeBufferConstantProductHookMath as Math
} from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookMath.sol";
import {
    UniswapV4DualStandardExchangeBufferConstantProductHookClaimLib as ClaimLib
} from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookClaimLib.sol";
import {
    UniswapV4DualStandardExchangeBufferConstantProductHookPullLib as PullLib
} from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookPullLib.sol";
import {
    IUniswapV4DualStandardExchangeBufferConstantProductHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/dual/interfaces/IUniswapV4DualStandardExchangeBufferConstantProductHook.sol";
import {
    UniswapV4SeBufferHookLegLib
} from "contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol";

/// @title UniswapV4DualStandardExchangeBufferConstantProductHookDepositTarget
/// @notice Role Target for size-split Dual SE CP Buffer hook (Option 1a).
abstract contract UniswapV4DualStandardExchangeBufferConstantProductHookDepositTarget is UniswapV4DualStandardExchangeBufferConstantProductHookCommon {
    using SafeERC20 for IERC20;

    function deposit(
        uint256 amount0,
        uint256 amount1,
        address to,
        uint256 minLpAmount,
        uint256 deadline
    ) external nonReentrant returns (uint256 lpAmount, uint256 used0, uint256 used1) {
        _pullErc20Dual(amount0, amount1);
        return _deposit(amount0, amount1, to, minLpAmount, deadline);
    }


    function depositSingle(
        address tokenIn,
        uint256 amountIn,
        address to,
        uint256 minLpAmount,
        uint256 deadline
    ) external nonReentrant returns (uint256 lpAmount) {
        _pullErc20Single(tokenIn, amountIn);
        return _depositSingle(tokenIn, amountIn, to, minLpAmount, deadline);
    }


    function depositWithPermit2Signature(
        uint256 amount0,
        uint256 amount1,
        address to,
        uint256 minLpAmount,
        uint256 deadline,
        bytes calldata permit2Data
    ) external nonReentrant returns (uint256 lpAmount, uint256 used0, uint256 used1) {
        _pullPermit2SignatureDual(amount0, amount1, permit2Data);
        return _deposit(amount0, amount1, to, minLpAmount, deadline);
    }


    function depositWithPermit2Allowance(
        uint256 amount0,
        uint256 amount1,
        address to,
        uint256 minLpAmount,
        uint256 deadline
    ) external nonReentrant returns (uint256 lpAmount, uint256 used0, uint256 used1) {
        _pullPermit2AllowanceDual(amount0, amount1);
        return _deposit(amount0, amount1, to, minLpAmount, deadline);
    }


    function depositSingleWithPermit2Signature(
        address tokenIn,
        uint256 amountIn,
        address to,
        uint256 minLpAmount,
        uint256 deadline,
        bytes calldata permit2Data
    ) external nonReentrant returns (uint256 lpAmount) {
        _pullPermit2SignatureSingle(tokenIn, amountIn, permit2Data);
        return _depositSingle(tokenIn, amountIn, to, minLpAmount, deadline);
    }


    function depositSingleWithPermit2Allowance(
        address tokenIn,
        uint256 amountIn,
        address to,
        uint256 minLpAmount,
        uint256 deadline
    ) external nonReentrant returns (uint256 lpAmount) {
        _pullPermit2AllowanceSingle(tokenIn, amountIn);
        return _depositSingle(tokenIn, amountIn, to, minLpAmount, deadline);
    }


    function depositFlexible(
        uint256 amount0,
        bool amount0IsSeShare,
        uint256 amount1,
        bool amount1IsSeShare,
        address to,
        uint256 minLpAmount,
        uint256 deadline
    ) external nonReentrant returns (uint256 lpAmount, uint256 used0, uint256 used1) {
        // Pure pair: pull then existing deposit (free pair does not inflate claims pre-buffer).
        if (!amount0IsSeShare && !amount1IsSeShare) {
            _pullFlexible(amount0, false, amount1, false);
            (lpAmount, used0, used1) = _deposit(amount0, amount1, to, minLpAmount, deadline);
            emit IHook.DepositFlexible(
                msg.sender, to, amount0, false, amount1, false, used0, used1, lpAmount
            );
            return (lpAmount, used0, used1);
        }

        // SE-bearing path: fee + claim snapshot must be pre-pull (SE is claim-bearing immediately).
        _requireDeadline(deadline);
        _requireNonZero(amount0);
        _requireNonZero(amount1);
        _mintProtocolFeeIfNeeded(true);
        uint256 xPre = claimSupplyCurrency0();
        uint256 yPre = claimSupplyCurrency1();
        _pullFlexible(amount0, amount0IsSeShare, amount1, amount1IsSeShare);
        return _depositFlexibleSe(
            amount0, amount0IsSeShare, amount1, amount1IsSeShare, to, minLpAmount, xPre, yPre
        );
    }


    function previewDeposit(uint256 amount0, uint256 amount1)
        external
        view
        returns (uint256 lpAmount, uint256 used0, uint256 used1)
    {
        return _previewDeposit(amount0, amount1);
    }


    function previewDepositSingle(address tokenIn, uint256 amountIn)
        external
        view
        returns (uint256 lpAmount)
    {
        return _previewDepositSingle(tokenIn, amountIn);
    }


    function previewZapSplit(address tokenIn, uint256 amountIn)
        external
        view
        returns (uint256 amountToSwap, uint256 amountOtherOut, uint256 amountKeptIn)
    {
        return _previewZapSplit(tokenIn, amountIn);
    }


    function previewDepositFlexible(
        uint256 amount0,
        bool amount0IsSeShare,
        uint256 amount1,
        bool amount1IsSeShare
    ) external view returns (uint256 lpAmount, uint256 used0, uint256 used1) {
        return _previewDepositFlexible(amount0, amount0IsSeShare, amount1, amount1IsSeShare);
    }

    struct JoinUnbalancedAcc {
        uint256 amt0;
        uint256 amt1;
        bool isSe0;
        bool isSe1;
        bool saw0;
        bool saw1;
    }

    function joinProportional(
        uint256[] calldata amounts,
        address to,
        uint256 sharesMin,
        uint256 deadline
    ) external nonReentrant returns (uint256 shares, uint256[] memory usedAmounts) {
        if (amounts.length != 2) revert InvalidRoute();
        if (amounts[0] == 0 || amounts[1] == 0) {
            if (!_isLive()) revert FirstJoinMustBeFullBook();
            revert InvalidRoute();
        }
        _pullErc20Dual(amounts[0], amounts[1]);
        uint256 used0;
        uint256 used1;
        (shares, used0, used1) = _deposit(amounts[0], amounts[1], to, sharesMin, deadline);
        usedAmounts = new uint256[](2);
        usedAmounts[0] = used0;
        usedAmounts[1] = used1;
    }

    function previewJoinProportional(uint256[] calldata amounts)
        external
        view
        returns (uint256 shares, uint256[] memory usedAmounts)
    {
        if (amounts.length != 2) revert InvalidRoute();
        usedAmounts = new uint256[](2);
        if (amounts[0] == 0 || amounts[1] == 0) return (0, usedAmounts);
        uint256 used0;
        uint256 used1;
        (shares, used0, used1) = _previewDeposit(amounts[0], amounts[1]);
        usedAmounts[0] = used0;
        usedAmounts[1] = used1;
    }

    function joinUnbalanced(
        address[] calldata tokensIn,
        uint256[] calldata amounts,
        address to,
        uint256 sharesMin,
        uint256 deadline
    ) external nonReentrant returns (uint256 shares) {
        JoinUnbalancedAcc memory acc = _accumulateJoin(tokensIn, amounts);
        _requireFirstJoinFullBook(acc);
        shares = _joinAcc(acc, to, sharesMin, deadline);
    }

    function previewJoinUnbalanced(address[] calldata tokensIn, uint256[] calldata amounts)
        external
        view
        returns (uint256 shares)
    {
        JoinUnbalancedAcc memory acc = _accumulateJoin(tokensIn, amounts);
        if (!_isLive() && (!acc.saw0 || !acc.saw1)) return 0;
        if (acc.saw0 && acc.saw1) {
            if (!acc.isSe0 && !acc.isSe1) {
                (shares,,) = _previewDeposit(acc.amt0, acc.amt1);
            } else {
                (shares,,) = _previewDepositFlexible(acc.amt0, acc.isSe0, acc.amt1, acc.isSe1);
            }
            return shares;
        }
        return _previewJoinOneLeg(acc);
    }

    function joinSingleAssetExactIn(
        address tokenIn,
        uint256 amountIn,
        address to,
        uint256 sharesMin,
        uint256 deadline
    ) external nonReentrant returns (uint256 shares) {
        if (!_isLive()) revert NotLive();
        UniswapV4SeBufferHookLegLib.LegKind kind = _classify(tokenIn);
        if (kind == UniswapV4SeBufferHookLegLib.LegKind.Unknown) revert InvalidRoute();
        _pullErc20Single(tokenIn, amountIn);
        if (kind == UniswapV4SeBufferHookLegLib.LegKind.StandardExchange) {
            address pair = Repo._layout().legs.pairOfStandardExchange[tokenIn];
            uint256 pairOut = _unwrap(tokenIn, pair, amountIn);
            return _depositSingle(pair, pairOut, to, sharesMin, deadline);
        }
        return _depositSingle(tokenIn, amountIn, to, sharesMin, deadline);
    }

    function previewJoinSingleAssetExactIn(address tokenIn, uint256 amountIn)
        external
        view
        returns (uint256 shares)
    {
        if (!_isLive() || amountIn == 0) return 0;
        UniswapV4SeBufferHookLegLib.LegKind kind = _classify(tokenIn);
        if (kind == UniswapV4SeBufferHookLegLib.LegKind.Unknown) return 0;
        if (kind == UniswapV4SeBufferHookLegLib.LegKind.StandardExchange) {
            address pair = Repo._layout().legs.pairOfStandardExchange[tokenIn];
            uint256 pairOut = IStandardExchangeIn(tokenIn).previewExchangeIn(
                IERC20(tokenIn), amountIn, IERC20(pair)
            );
            if (pairOut == 0) return 0;
            return _previewDepositSingle(pair, pairOut);
        }
        return _previewDepositSingle(tokenIn, amountIn);
    }

    function joinSingleAssetExactOut(
        address tokenIn,
        uint256 sharesOut,
        address to,
        uint256 amountInMax,
        uint256 deadline
    ) external pure returns (uint256) {
        tokenIn;
        sharesOut;
        to;
        amountInMax;
        deadline;
        revert InvalidRoute();
    }

    function previewJoinSingleAssetExactOut(address tokenIn, uint256 sharesOut)
        external
        view
        returns (uint256)
    {
        tokenIn;
        sharesOut;
        return 0;
    }

    function _accumulateJoin(address[] calldata tokensIn, uint256[] calldata amounts)
        internal
        view
        returns (JoinUnbalancedAcc memory acc)
    {
        if (tokensIn.length != amounts.length || tokensIn.length == 0) revert InvalidRoute();
        Repo.Layout storage l = Repo._layout();
        for (uint256 i; i < tokensIn.length; ++i) {
            if (amounts[i] == 0) revert InvalidRoute();
            UniswapV4SeBufferHookLegLib.LegKind kind = _classify(tokensIn[i]);
            if (kind == UniswapV4SeBufferHookLegLib.LegKind.Unknown) revert InvalidRoute();
            uint256 idx;
            bool isSe;
            if (kind == UniswapV4SeBufferHookLegLib.LegKind.Pair) {
                if (tokensIn[i] == l.currency0) idx = 0;
                else if (tokensIn[i] == l.currency1) idx = 1;
                else revert InvalidRoute();
            } else if (kind == UniswapV4SeBufferHookLegLib.LegKind.StandardExchange) {
                address pair = l.legs.pairOfStandardExchange[tokensIn[i]];
                if (pair == l.currency0) idx = 0;
                else if (pair == l.currency1) idx = 1;
                else revert InvalidRoute();
                isSe = true;
            } else {
                revert InvalidRoute();
            }
            if (idx == 0) {
                if (acc.saw0) revert PairAndShareSameLeg();
                acc.saw0 = true;
                acc.isSe0 = isSe;
                acc.amt0 = amounts[i];
            } else {
                if (acc.saw1) revert PairAndShareSameLeg();
                acc.saw1 = true;
                acc.isSe1 = isSe;
                acc.amt1 = amounts[i];
            }
        }
    }

    function _requireFirstJoinFullBook(JoinUnbalancedAcc memory acc) internal view {
        if (_isLive()) return;
        if (!acc.saw0 || !acc.saw1) revert FirstJoinMustBeFullBook();
    }

    function _joinAcc(
        JoinUnbalancedAcc memory acc,
        address to,
        uint256 sharesMin,
        uint256 deadline
    ) internal returns (uint256 shares) {
        if (acc.saw0 && acc.saw1) {
            if (!acc.isSe0 && !acc.isSe1) {
                _pullErc20Dual(acc.amt0, acc.amt1);
                (shares,,) = _deposit(acc.amt0, acc.amt1, to, sharesMin, deadline);
                return shares;
            }
            _requireDeadline(deadline);
            _requireNonZero(acc.amt0);
            _requireNonZero(acc.amt1);
            _mintProtocolFeeIfNeeded(true);
            uint256 xPre = claimSupplyCurrency0();
            uint256 yPre = claimSupplyCurrency1();
            _pullFlexible(acc.amt0, acc.isSe0, acc.amt1, acc.isSe1);
            (shares,,) = _depositFlexibleSe(
                acc.amt0, acc.isSe0, acc.amt1, acc.isSe1, to, sharesMin, xPre, yPre
            );
            return shares;
        }
        return _joinOneLeg(acc, to, sharesMin, deadline);
    }

    function _joinOneLeg(
        JoinUnbalancedAcc memory acc,
        address to,
        uint256 sharesMin,
        uint256 deadline
    ) internal returns (uint256 shares) {
        Repo.Layout storage l = Repo._layout();
        address tokenIn;
        uint256 amountIn;
        bool isSe;
        if (acc.saw0) {
            isSe = acc.isSe0;
            amountIn = acc.amt0;
            tokenIn = isSe ? l.legs.standardExchangeOf[l.currency0] : l.currency0;
        } else {
            isSe = acc.isSe1;
            amountIn = acc.amt1;
            tokenIn = isSe ? l.legs.standardExchangeOf[l.currency1] : l.currency1;
        }
        _pullErc20Single(tokenIn, amountIn);
        if (isSe) {
            address pair = l.legs.pairOfStandardExchange[tokenIn];
            uint256 pairOut = _unwrap(tokenIn, pair, amountIn);
            return _depositSingle(pair, pairOut, to, sharesMin, deadline);
        }
        return _depositSingle(tokenIn, amountIn, to, sharesMin, deadline);
    }

    function _previewJoinOneLeg(JoinUnbalancedAcc memory acc) internal view returns (uint256 shares) {
        Repo.Layout storage l = Repo._layout();
        address tokenIn;
        uint256 amountIn;
        bool isSe;
        if (acc.saw0) {
            isSe = acc.isSe0;
            amountIn = acc.amt0;
            tokenIn = isSe ? l.legs.standardExchangeOf[l.currency0] : l.currency0;
        } else {
            isSe = acc.isSe1;
            amountIn = acc.amt1;
            tokenIn = isSe ? l.legs.standardExchangeOf[l.currency1] : l.currency1;
        }
        if (isSe) {
            address pair = l.legs.pairOfStandardExchange[tokenIn];
            uint256 pairOut = IStandardExchangeIn(tokenIn).previewExchangeIn(
                IERC20(tokenIn), amountIn, IERC20(pair)
            );
            if (pairOut == 0) return 0;
            return _previewDepositSingle(pair, pairOut);
        }
        return _previewDepositSingle(tokenIn, amountIn);
    }

}
