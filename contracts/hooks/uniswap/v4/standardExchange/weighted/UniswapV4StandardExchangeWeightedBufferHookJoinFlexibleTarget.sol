// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
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
abstract contract UniswapV4StandardExchangeWeightedBufferHookJoinFlexibleTarget is
    UniswapV4StandardExchangeWeightedBufferHookTarget
{
    using SafeERC20 for IERC20;

    function previewJoinProportionalFlexible(uint256[] calldata amounts, bool[] calldata amountIsSeShare)
        public
        view
        returns (uint256 shares, uint256[] memory usedAmounts)
    {
        return _computeJoinProportionalFlexible(amounts, amountIsSeShare);
    }


    function joinProportionalFlexible(
        uint256[] calldata amounts,
        bool[] calldata amountIsSeShare,
        address to,
        uint256 sharesMin,
        uint256 deadline
    ) public nonReentrant returns (uint256 shares, uint256[] memory usedAmounts) {
        _requireDeadline(deadline);
        if (to == address(0)) revert ZeroAddress();
        _validateSeShareFlags(amountIsSeShare);
        _maybeMintProtocolFee();
        bool first = _totalSupply() == 0;
        (shares, usedAmounts) = _computeJoinProportionalFlexible(amounts, amountIsSeShare);
        if (shares < sharesMin) revert Slippage();
        _commitJoinFlexible(usedAmounts, amountIsSeShare, to, shares, first);
        emit IUniswapV4StandardExchangeWeightedBufferHook.JoinFlexible(
            msg.sender, to, shares, amounts, amountIsSeShare, usedAmounts, 0
        );
    }


    function _computeJoinProportionalFlexible(uint256[] memory amounts, bool[] memory amountIsSeShare)
        internal
        view
        returns (uint256 shares, uint256[] memory used)
    {
        Repo.Layout storage l = Repo._layout();
        if (amounts.length != l.numTokens || amountIsSeShare.length != l.numTokens) {
            revert ArrayLengthMismatch();
        }
        _validateSeShareFlags(amountIsSeShare);
        uint256[] memory invIn = _edgeToInvPreview(amounts, amountIsSeShare);
        if (_totalSupply() == 0) {
            return _firstMint(invIn, amounts);
        }
        uint256[] memory natives = _nativeAll();
        if (Math.isFullBookReserves(natives)) {
            return _fullPropJoin(amounts, invIn, _totalSupply());
        }
        return _partialJoin(amounts, invIn, _totalSupply());
    }


    function _commitJoinFlexible(
        uint256[] memory usedAmounts,
        bool[] memory amountIsSeShare,
        address to,
        uint256 shares,
        bool firstMint
    ) internal {
        Repo.Layout storage l = Repo._layout();
        // Pull edge units (pair or SE share), then buffer-last pair legs only.
        for (uint8 i; i < l.numTokens; ++i) {
            if (usedAmounts[i] == 0) continue;
            if (amountIsSeShare[i]) {
                _pull(l.standardExchanges[i], usedAmounts[i]);
            } else {
                _pull(l.tokens[i], usedAmounts[i]);
            }
        }
        for (uint8 i; i < l.numTokens; ++i) {
            if (usedAmounts[i] == 0 || amountIsSeShare[i]) continue;
            _bufferToken(i, usedAmounts[i]);
        }
        if (firstMint) {
            _mintLp(address(0), Math.MINIMUM_LIQUIDITY);
        }
        _mintLp(to, shares);
        _snapshotKLastIfFeeOn();
        _refundBufferedDust();
        _syncVaultReserves();
    }


    function previewJoinSingleAssetExactInFlexible(address tokenIn, uint256 amountIn, bool amountIsSeShare)
        public
        view
        returns (uint256 shares)
    {
        return _quoteSingleJoinExactInFlexible(tokenIn, amountIn, amountIsSeShare);
    }


    function joinSingleAssetExactInFlexible(
        address tokenIn,
        uint256 amountIn,
        bool amountIsSeShare,
        address to,
        uint256 sharesMin,
        uint256 deadline
    ) public nonReentrant returns (uint256 shares) {
        shares = _joinSingleAssetExactInFlexible(tokenIn, amountIn, amountIsSeShare, to, sharesMin, deadline);
    }


    function depositSingleFlexible(
        address tokenIn,
        uint256 amountIn,
        bool amountIsSeShare,
        address to,
        uint256 sharesMin,
        uint256 deadline
    ) public nonReentrant returns (uint256 shares) {
        shares = _joinSingleAssetExactInFlexible(tokenIn, amountIn, amountIsSeShare, to, sharesMin, deadline);
    }


    function previewDepositSingleFlexible(address tokenIn, uint256 amountIn, bool amountIsSeShare)
        public
        view
        returns (uint256 shares)
    {
        return previewJoinSingleAssetExactInFlexible(tokenIn, amountIn, amountIsSeShare);
    }


    function _joinSingleAssetExactInFlexible(
        address tokenIn,
        uint256 amountIn,
        bool amountIsSeShare,
        address to,
        uint256 sharesMin,
        uint256 deadline
    ) internal returns (uint256 shares) {
        _requireDeadline(deadline);
        if (to == address(0)) revert ZeroAddress();
        if (amountIn == 0) revert ZeroAmount();
        if (_totalSupply() == 0 || !Math.isFullBookReserves(_nativeAll())) revert NotFullBook();
        uint8 idx = _tokenIndex(tokenIn);
        if (amountIsSeShare && Repo._layout().standardExchanges[idx] == address(0)) {
            revert SeShareNotBuffered();
        }
        _maybeMintProtocolFee();
        shares = _quoteSingleJoinExactInFlexible(tokenIn, amountIn, amountIsSeShare);
        if (shares < sharesMin) revert Slippage();
        uint256[] memory used = new uint256[](Repo._layout().numTokens);
        used[idx] = amountIn;
        bool[] memory flags = new bool[](Repo._layout().numTokens);
        flags[idx] = amountIsSeShare;
        _commitJoinFlexible(used, flags, to, shares, false);
        emit IUniswapV4StandardExchangeWeightedBufferHook.DepositSingleFlexible(
            msg.sender, to, tokenIn, amountIn, amountIsSeShare, shares, 0
        );
    }


    function _quoteSingleJoinExactInFlexible(address tokenIn, uint256 amountIn, bool amountIsSeShare)
        internal
        view
        returns (uint256 shares)
    {
        uint8 idx = _tokenIndex(tokenIn);
        if (amountIsSeShare && Repo._layout().standardExchanges[idx] == address(0)) {
            revert SeShareNotBuffered();
        }
        uint256 feeWad = _feeOracle().dexSwapFeeOfVault(address(this));
        if (feeWad >= Math.WAD) revert InvalidFeeWad();
        uint256[] memory edge = new uint256[](Repo._layout().numTokens);
        edge[idx] = amountIn;
        bool[] memory flags = new bool[](Repo._layout().numTokens);
        flags[idx] = amountIsSeShare;
        uint256[] memory invIn = _edgeToInvPreview(edge, flags);
        shares = Math.singleJoinExactInShares(
            _invWadAll(),
            Repo._layout().weights,
            idx,
            Math.scaleTo(invIn[idx], Repo._layout().invScales[idx]),
            _totalSupply(),
            feeWad
        );
    }


}
