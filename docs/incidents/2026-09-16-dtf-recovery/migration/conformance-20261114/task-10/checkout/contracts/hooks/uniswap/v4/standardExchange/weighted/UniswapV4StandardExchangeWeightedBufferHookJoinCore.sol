// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

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
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
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
 * @title UniswapV4StandardExchangeWeightedBufferHookJoinTarget
 * @notice Join/exit + one-token aliases (inventory domain, buffer-last).
 */
abstract contract UniswapV4StandardExchangeWeightedBufferHookJoinCore is
    UniswapV4StandardExchangeWeightedBufferHookTarget
{
    using SafeERC20 for IERC20;

    function _feeSince(uint256 supplyBefore, uint256 net) private view returns (uint256) {
        return _totalSupply() - supplyBefore - (supplyBefore == 0 ? Math.MINIMUM_LIQUIDITY : 0) - net;
    }

    function _flags() internal view returns (bool[] memory) { return new bool[](Repo._layout().numTokens); }

    function _validateSeShareFlags(bool[] memory flags) internal view {
        Repo.Layout storage l = Repo._layout();
        if (flags.length != l.numTokens) revert ArrayLengthMismatch();
        for (uint8 i; i < l.numTokens; ++i) if (flags[i] && l.standardExchanges[i] == address(0)) revert SeShareNotBuffered();
    }

    function _entryPreviewJoinProportional(uint256[] calldata amounts) internal view returns (uint256, uint256[] memory) {
        if (amounts.length != Repo._layout().numTokens) revert InvalidN();
        return LiqLib.previewJoin(amounts, _flags(), false);
    }

    function _entryJoinProportional(uint256[] calldata amounts, address to, uint256 minimum, uint256 deadline)
        internal onlyLiquidityOwner nonReentrant returns (uint256 net, uint256[] memory used)
    {
        if (amounts.length != Repo._layout().numTokens) revert InvalidN();
        return _joinComponents(amounts, _flags(), false, to, minimum, deadline, 0);
    }

    function _joinComponents(uint256[] memory amounts, bool[] memory flags, bool rebalance, address to, uint256 minimum, uint256 deadline, uint256 exactNet)
        internal returns (uint256 net, uint256[] memory used)
    {
        _requireDeadline(deadline);
        if (to == address(0)) revert ZeroAddress();
        uint256 supplyBefore = _totalSupply();
        (net, used) = LiqLib.join(amounts, flags, rebalance, to, minimum, exactNet);
        _syncVaultReserves();
        int256[] memory deltas = new int256[](used.length);
        for (uint256 i; i < used.length; ++i) deltas[i] = int256(used[i]);
        emit IUniswapV4StandardExchangeWeightedBufferHook.Join(msg.sender, to, net, deltas, _feeSince(supplyBefore, net));
    }

    function _entryPreviewJoinProportionalFlexible(uint256[] calldata amounts, bool[] calldata flags) internal view returns (uint256, uint256[] memory) {
        return LiqLib.previewJoin(amounts, flags, false);
    }

    function _entryJoinProportionalFlexible(uint256[] calldata amounts, bool[] calldata flags, address to, uint256 minimum, uint256 deadline)
        internal onlyLiquidityOwner nonReentrant returns (uint256 net, uint256[] memory used)
    {
        uint256 supplyBefore = _totalSupply();
        (net, used) = _joinComponents(amounts, flags, false, to, minimum, deadline, 0);
        emit IUniswapV4StandardExchangeWeightedBufferHook.JoinFlexible(msg.sender, to, net, amounts, flags, used, _feeSince(supplyBefore, net));
    }

    function _entryPreviewJoinUnbalanced(uint256[] calldata amounts) internal view returns (uint256 net) {
        _unbalancedTopology(amounts);
        (net,) = LiqLib.previewJoin(amounts, _flags(), true);
    }

    function _entryJoinUnbalanced(uint256[] calldata amounts, address to, uint256 minimum, uint256 deadline)
        internal onlyLiquidityOwner nonReentrant returns (uint256 net)
    {
        _unbalancedTopology(amounts);
        (net,) = _joinComponents(amounts, _flags(), true, to, minimum, deadline, 0);
    }

    function _unbalancedTopology(uint256[] memory amounts) private view {
        if (amounts.length != Repo._layout().numTokens) revert InvalidN();
        if (_totalSupply() == 0) {
            if (Math.countPositive(amounts) != Repo._layout().numTokens) revert NotFullBook();
        }
    }

    function _entryPreviewJoinUnbalanced(address[] calldata tokensIn, uint256[] calldata amounts) internal view returns (uint256 net) {
        (uint256[] memory edge, bool[] memory flags) = _accumulateJoin(tokensIn, amounts);
        if (_totalSupply() == 0 && Math.countPositive(edge) != Repo._layout().numTokens) return 0;
        (net,) = LiqLib.previewJoin(edge, flags, true);
    }

    function _entryJoinUnbalanced(address[] calldata tokensIn, uint256[] calldata amounts, address to, uint256 minimum, uint256 deadline)
        internal onlyLiquidityOwner nonReentrant returns (uint256 net)
    {
        (uint256[] memory edge, bool[] memory flags) = _accumulateJoin(tokensIn, amounts);
        if (_totalSupply() == 0 && Math.countPositive(edge) != Repo._layout().numTokens) revert FirstJoinMustBeFullBook();
        (net,) = _joinComponents(edge, flags, true, to, minimum, deadline, 0);
    }

    function _accumulateJoin(address[] calldata tokensIn, uint256[] calldata amounts)
        internal
        view
        returns (uint256[] memory edge, bool[] memory isSe)
    {
        if (tokensIn.length != amounts.length) {
            revert IStandardExchangeErrors.InvalidRoute(address(0), address(0));
        }
        Repo.Layout storage l = Repo._layout();
        uint8 n = l.numTokens;
        edge = new uint256[](n);
        isSe = new bool[](n);
        bool[] memory sawPair = new bool[](n);
        bool[] memory sawSe = new bool[](n);
        for (uint256 i; i < tokensIn.length; ++i) {
            if (amounts[i] == 0) continue;
            UniswapV4SeBufferHookLegLib.LegKind kind =
                UniswapV4SeBufferHookLegLib.classify(l.legs, tokensIn[i]);
            if (kind == UniswapV4SeBufferHookLegLib.LegKind.Unknown) {
                revert IStandardExchangeErrors.InvalidRoute(tokensIn[i], address(0));
            }
            uint8 idx;
            if (kind == UniswapV4SeBufferHookLegLib.LegKind.Detf) {
                idx = _tokenIndex(tokensIn[i]);
                edge[idx] += amounts[i];
                continue;
            }
            if (kind == UniswapV4SeBufferHookLegLib.LegKind.Pair) {
                idx = _tokenIndex(tokensIn[i]);
                if (sawSe[idx]) revert PairAndShareSameLeg();
                sawPair[idx] = true;
                edge[idx] += amounts[i];
                continue;
            }
            address pair_ = l.legs.pairOfStandardExchange[tokensIn[i]];
            idx = _tokenIndex(pair_);
            if (sawPair[idx]) revert PairAndShareSameLeg();
            sawSe[idx] = true;
            isSe[idx] = true;
            edge[idx] += amounts[i];
        }
    }

    function _singleInputs(address tokenIn, uint256 amount, bool asShare) internal view returns (uint256[] memory amounts, bool[] memory flags) {
        Repo.Layout storage l = Repo._layout();
        UniswapV4SeBufferHookLegLib.LegKind kind = UniswapV4SeBufferHookLegLib.classify(l.legs, tokenIn);
        if (kind == UniswapV4SeBufferHookLegLib.LegKind.Unknown) revert IStandardExchangeErrors.InvalidRoute(tokenIn, address(0));
        if (kind == UniswapV4SeBufferHookLegLib.LegKind.StandardExchange) { tokenIn = l.legs.pairOfStandardExchange[tokenIn]; asShare = true; }
        uint8 i = _tokenIndex(tokenIn);
        if (asShare && l.standardExchanges[i] == address(0)) revert SeShareNotBuffered();
        amounts = new uint256[](l.numTokens); flags = _flags();
        amounts[i] = amount; flags[i] = asShare;
    }

    function _quoteSingleJoinExactInFlexible(address tokenIn, uint256 amount, bool asShare) internal view returns (uint256 net) {
        if (_totalSupply() == 0 || amount == 0) return 0;
        (uint256[] memory amounts, bool[] memory flags) = _singleInputs(tokenIn, amount, asShare);
        (net,) = LiqLib.previewJoin(amounts, flags, true);
    }

    function _entryPreviewJoinSingleAssetExactIn(address tokenIn, uint256 amount) internal view returns (uint256) {
        if (UniswapV4SeBufferHookLegLib.classify(Repo._layout().legs, tokenIn) == UniswapV4SeBufferHookLegLib.LegKind.Unknown) return 0;
        return _quoteSingleJoinExactInFlexible(tokenIn, amount, false);
    }
    function _entryPreviewDepositSingle(address tokenIn, uint256 amount) internal view returns (uint256) { return _entryPreviewJoinSingleAssetExactIn(tokenIn, amount); }
    function _entryPreviewJoinSingleAssetExactInFlexible(address tokenIn, uint256 amount, bool asShare) internal view returns (uint256) { return _quoteSingleJoinExactInFlexible(tokenIn, amount, asShare); }
    function _entryPreviewDepositSingleFlexible(address tokenIn, uint256 amount, bool asShare) internal view returns (uint256) { return _quoteSingleJoinExactInFlexible(tokenIn, amount, asShare); }

    function _singleJoin(address tokenIn, uint256 amount, bool asShare, address to, uint256 minimum, uint256 deadline, uint256 exactNet) internal returns (uint256 net) {
        _requireDeadline(deadline);
        if (amount == 0) revert ZeroAmount();
        if (_totalSupply() == 0) revert NotFullBook();
        (uint256[] memory amounts, bool[] memory flags) = _singleInputs(tokenIn, amount, asShare);
        (net,) = _joinComponents(amounts, flags, true, to, minimum, deadline, exactNet);
    }

    function _entryJoinSingleAssetExactIn(address tokenIn, uint256 amount, address to, uint256 minimum, uint256 deadline)
        internal onlyLiquidityOwner nonReentrant returns (uint256 net) {
        uint256 supplyBefore = _totalSupply();
        net = _singleJoin(tokenIn, amount, false, to, minimum, deadline, 0);
        emit IUniswapV4StandardExchangeWeightedBufferHook.DepositSingle(msg.sender, to, tokenIn, amount, net, _feeSince(supplyBefore, net));
    }
    function _entryDepositSingle(address tokenIn, uint256 amount, address to, uint256 minimum, uint256 deadline)
        internal onlyLiquidityOwner nonReentrant returns (uint256 net) {
        uint256 supplyBefore = _totalSupply();
        net = _singleJoin(tokenIn, amount, false, to, minimum, deadline, 0);
        emit IUniswapV4StandardExchangeWeightedBufferHook.DepositSingle(msg.sender, to, tokenIn, amount, net, _feeSince(supplyBefore, net));
    }
    function _entryJoinSingleAssetExactInFlexible(address tokenIn, uint256 amount, bool asShare, address to, uint256 minimum, uint256 deadline)
        internal onlyLiquidityOwner nonReentrant returns (uint256 net) {
        uint256 supplyBefore = _totalSupply();
        net = _singleJoin(tokenIn, amount, asShare, to, minimum, deadline, 0);
        emit IUniswapV4StandardExchangeWeightedBufferHook.DepositSingleFlexible(msg.sender, to, tokenIn, amount, asShare, net, _feeSince(supplyBefore, net));
    }
    function _entryDepositSingleFlexible(address tokenIn, uint256 amount, bool asShare, address to, uint256 minimum, uint256 deadline)
        internal onlyLiquidityOwner nonReentrant returns (uint256 net) {
        uint256 supplyBefore = _totalSupply();
        net = _singleJoin(tokenIn, amount, asShare, to, minimum, deadline, 0);
        emit IUniswapV4StandardExchangeWeightedBufferHook.DepositSingleFlexible(msg.sender, to, tokenIn, amount, asShare, net, _feeSince(supplyBefore, net));
    }

    /// @dev Existing forward sizing, verified against the complete net component quote.
    /// No exact-output SE call or monotonic-search assumption is introduced.
    function _entryPreviewJoinSingleAssetExactOut(address tokenIn, uint256 net) internal view returns (uint256 amount) {
        if (_totalSupply() == 0) revert NotFullBook();
        if (net == 0) revert ZeroAmount();
        uint256 gross = LiqLib.grossForNet(net);
        uint8 i = _tokenIndex(tokenIn);
        Repo.Layout storage l = Repo._layout();
        uint256 coordinate = l.standardExchanges[i] == address(0) ? l.rawReserves[i] : l.seReserves[i];
        uint256 units = FullMath.mulDiv(gross, coordinate, _totalSupply(), FullMath.Rounding.Ceil);
        if (l.standardExchanges[i] != address(0)) {
            (uint256 quote,) = IStandardExchangeIn(l.standardExchanges[i]).previewExchangeIn(IERC20(l.tokens[i]), units, IERC20(l.standardExchanges[i]));
            if (quote == 0) revert IStandardExchangeOut.ExchangeOutNotAvailable();
            units = FullMath.mulDiv(units, units, quote, FullMath.Rounding.Ceil);
        }
        amount = FullMath.mulDiv(units, 1e18, l.weights[i], FullMath.Rounding.Ceil);
        uint256 predicted = _entryPreviewJoinSingleAssetExactIn(tokenIn, amount);
        if (predicted < net && predicted != 0) amount = FullMath.mulDiv(amount, net, predicted, FullMath.Rounding.Ceil);
        amount += amount / 1000 + 1;
        if (_entryPreviewJoinSingleAssetExactIn(tokenIn, amount) < net) revert Slippage();
    }

    function _entryJoinSingleAssetExactOut(address tokenIn, uint256 net, address to, uint256 maximum, uint256 deadline)
        internal onlyLiquidityOwner nonReentrant returns (uint256 amount) {
        _requireDeadline(deadline);
        if (net == 0) revert ZeroAmount();
        LiqLib.grossForNet(net);
        uint256 budget = _entryPreviewJoinSingleAssetExactOut(tokenIn, net);
        if (budget > maximum) budget = maximum;
        if (_entryPreviewJoinSingleAssetExactIn(tokenIn, budget) < net) revert Slippage();
        uint256 beforeBalance = IERC20(tokenIn).balanceOf(msg.sender);
        _singleJoin(tokenIn, budget, false, to, net, deadline, net);
        amount = beforeBalance - IERC20(tokenIn).balanceOf(msg.sender);
        if (amount > maximum) revert Slippage();
    }
}
