// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {
    IUniswapV4StandardExchangeQuadStableBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/interfaces/IUniswapV4StandardExchangeQuadStableBufferHook.sol";
import {
    UniswapV4StandardExchangeQuadStableBufferHookRepo as Repo
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/UniswapV4StandardExchangeQuadStableBufferHookRepo.sol";
import {
    UniswapV4StandardExchangeQuadStableBufferHookMath as Math
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/UniswapV4StandardExchangeQuadStableBufferHookMath.sol";
import {
    UniswapV4StandardExchangeQuadStableBufferHookTarget
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/UniswapV4StandardExchangeQuadStableBufferHookTarget.sol";

/**
 * @title UniswapV4StandardExchangeQuadStableBufferHookLiquidityTarget
 * @notice Join/exit + one-token aliases on inventory domain (StableSwap single-asset + prop).
 * @dev Phase 0 OMIT: joinSingleAssetExactOut / exitSingleAssetExactTokenOut / joinUnbalanced → InvalidRoute.
 *      Full book only for single-asset and post-seed proportional. First mint requires all four > 0.
 */
abstract contract UniswapV4StandardExchangeQuadStableBufferHookLiquidityTarget is
    UniswapV4StandardExchangeQuadStableBufferHookTarget
{
    using SafeERC20 for IERC20;

    /* ---------------------------------------------------------------------- */
    /*                         liquidity: join / exit                         */
    /* ---------------------------------------------------------------------- */

    function previewJoinProportional(uint256[] calldata amounts)
        public
        view
        returns (uint256 shares, uint256[] memory usedAmounts)
    {
        // Simulate protocol growth mint dilution (exec mints before join algebra).
        return _computeJoinProportional(amounts, _previewSupplyAfterProtocolMint());
    }

    function joinProportional(
        uint256[] calldata amounts,
        address to,
        uint256 sharesMin,
        uint256 deadline
    ) public nonReentrant returns (uint256 shares, uint256[] memory usedAmounts) {
        _requireDeadline(deadline);
        if (to == address(0)) revert ZeroAddress();
        uint256 protocolShares = _maybeMintProtocolFee();
        bool first = _totalSupply() == 0;
        // After real protocol mint, use live supply (do not double-simulate mint).
        (shares, usedAmounts) = _computeJoinProportional(amounts, _totalSupply());
        if (shares < sharesMin) revert Slippage();
        uint256[4] memory used = _toFixed4(usedAmounts);
        _commitJoin(used, to, shares, first, protocolShares);
    }

    function _computeJoinProportional(uint256[] memory amounts, uint256 supply)
        internal
        view
        returns (uint256 shares, uint256[] memory used)
    {
        _requireAmountsLen4(amounts);
        uint256[4] memory pairIn = _toFixed4(amounts);
        uint256[4] memory invIn = _pairToInvPreview(pairIn);
        if (supply == 0) {
            return _firstMint(invIn, pairIn);
        }
        uint256[4] memory natives = _nativeAll();
        if (!Math.isFullBookReserves(natives)) revert NotFullBook();
        return _fullPropJoin(pairIn, invIn, supply);
    }

    function _firstMint(uint256[4] memory invAmounts, uint256[4] memory pairAmounts)
        internal
        view
        returns (uint256 shares, uint256[] memory usedPair)
    {
        // First mint requires all four inventory deltas > 0.
        for (uint256 i; i < Repo.N_TOKENS; ++i) {
            if (invAmounts[i] == 0 || pairAmounts[i] == 0) revert ZeroAmount();
        }
        uint256[4] memory scaled = _scaleInv(invAmounts);
        shares = Math.firstMintShares(scaled);
        usedPair = Math.toDynamic(pairAmounts);
    }

    function _fullPropJoin(uint256[4] memory pairAmounts, uint256[4] memory invIn, uint256 supply)
        internal
        view
        returns (uint256 shares, uint256[] memory usedPairDyn)
    {
        Repo.Layout storage l = Repo._layout();
        for (uint256 i; i < Repo.N_TOKENS; ++i) {
            if (pairAmounts[i] == 0) revert ZeroAmount();
        }
        uint256[4] memory aS = _scaleInv(invIn);
        uint256[4] memory rS = _invWadAll();
        shares = Math.proportionalJoinShares(aS, rS, supply);
        uint256[4] memory usedPair;
        for (uint256 i; i < Repo.N_TOKENS; ++i) {
            uint256 usedS = Math.proportionalUsedWad(shares, rS[i], supply);
            uint256 usedInv = Math.descale(usedS, l.invScales[i]);
            if (usedInv == 0) revert Slippage();
            if (l.standardExchanges[i] == address(0)) {
                usedPair[i] = usedInv;
            } else {
                if (invIn[i] == 0) revert ZeroAmount();
                usedPair[i] = (pairAmounts[i] * usedInv) / invIn[i];
                if (usedPair[i] == 0 || usedPair[i] > pairAmounts[i]) revert Slippage();
            }
        }
        usedPairDyn = Math.toDynamic(usedPair);
    }

    function _commitJoin(
        uint256[4] memory pairUsed,
        address to,
        uint256 shares,
        bool firstMint,
        uint256 protocolSharesMinted
    ) internal {
        _pullAmounts(pairUsed);
        _bufferLast(pairUsed);
        if (firstMint) {
            _mintLp(address(0), Math.MINIMUM_LIQUIDITY);
        }
        _mintLp(to, shares);
        _snapshotKLastIfFeeOn();
        _refundBufferedDust();
        _syncVaultReserves();
        int256[4] memory deltas;
        for (uint256 i; i < Repo.N_TOKENS; ++i) {
            deltas[i] = int256(pairUsed[i]);
        }
        emit IUniswapV4StandardExchangeQuadStableBufferHook.Join(
            msg.sender, to, shares, deltas, protocolSharesMinted
        );
    }

    /* ----------------------------- Phase 0 OMIT ----------------------------- */

    function previewJoinUnbalanced(uint256[] calldata) public pure returns (uint256) {
        revert IUniswapV4StandardExchangeQuadStableBufferHook.InvalidRoute();
    }

    function joinUnbalanced(uint256[] calldata, address, uint256, uint256)
        public
        pure
        returns (uint256)
    {
        revert IUniswapV4StandardExchangeQuadStableBufferHook.InvalidRoute();
    }

    function previewJoinSingleAssetExactOut(address, uint256) public pure returns (uint256) {
        revert IUniswapV4StandardExchangeQuadStableBufferHook.InvalidRoute();
    }

    function joinSingleAssetExactOut(address, uint256, address, uint256, uint256)
        public
        pure
        returns (uint256)
    {
        revert IUniswapV4StandardExchangeQuadStableBufferHook.InvalidRoute();
    }

    function previewExitSingleAssetExactTokenOut(address, uint256) public pure returns (uint256) {
        revert IUniswapV4StandardExchangeQuadStableBufferHook.InvalidRoute();
    }

    function exitSingleAssetExactTokenOut(address, uint256, address, uint256, uint256)
        public
        pure
        returns (uint256)
    {
        revert IUniswapV4StandardExchangeQuadStableBufferHook.InvalidRoute();
    }

    function previewWithdrawSingleExactOut(address, uint256) public pure returns (uint256) {
        revert IUniswapV4StandardExchangeQuadStableBufferHook.InvalidRoute();
    }

    function withdrawSingleExactOut(address, uint256, address, uint256, uint256)
        public
        pure
        returns (uint256)
    {
        revert IUniswapV4StandardExchangeQuadStableBufferHook.InvalidRoute();
    }

    /* -------------------------- single-asset join --------------------------- */

    function previewJoinSingleAssetExactIn(address tokenIn, uint256 amountIn)
        public
        view
        returns (uint256 shares)
    {
        return _quoteSingleJoinExactIn(tokenIn, amountIn, _previewSupplyAfterProtocolMint());
    }

    function joinSingleAssetExactIn(
        address tokenIn,
        uint256 amountIn,
        address to,
        uint256 sharesMin,
        uint256 deadline
    ) public nonReentrant returns (uint256 shares) {
        shares = _joinSingleAssetExactIn(tokenIn, amountIn, to, sharesMin, deadline);
    }

    function depositSingle(
        address tokenIn,
        uint256 amountIn,
        address to,
        uint256 sharesMin,
        uint256 deadline
    ) public nonReentrant returns (uint256 shares) {
        shares = _joinSingleAssetExactIn(tokenIn, amountIn, to, sharesMin, deadline);
    }

    function previewDepositSingle(address tokenIn, uint256 amountIn)
        public
        view
        returns (uint256 shares)
    {
        return previewJoinSingleAssetExactIn(tokenIn, amountIn);
    }

    function _joinSingleAssetExactIn(
        address tokenIn,
        uint256 amountIn,
        address to,
        uint256 sharesMin,
        uint256 deadline
    ) internal returns (uint256 shares) {
        _requireDeadline(deadline);
        if (to == address(0)) revert ZeroAddress();
        if (amountIn == 0) revert ZeroAmount();
        if (_totalSupply() == 0 || !Math.isFullBookReserves(_nativeAll())) revert NotFullBook();
        uint256 protocolShares = _maybeMintProtocolFee();
        shares = _quoteSingleJoinExactIn(tokenIn, amountIn, _totalSupply());
        if (shares < sharesMin) revert Slippage();
        uint8 idx = _tokenIndex(tokenIn);
        uint256[4] memory used;
        used[idx] = amountIn;
        _pullAmounts(used);
        _bufferLast(used);
        _mintLp(to, shares);
        _snapshotKLastIfFeeOn();
        _refundBufferedDust();
        _syncVaultReserves();
        emit IUniswapV4StandardExchangeQuadStableBufferHook.DepositSingle(
            msg.sender, to, tokenIn, amountIn, shares, protocolShares
        );
    }

    function _quoteSingleJoinExactIn(address tokenIn, uint256 amountIn, uint256 supply)
        internal
        view
        returns (uint256 shares)
    {
        uint8 idx = _tokenIndex(tokenIn);
        uint256 feeWad = _feeOracle().dexSwapFeeOfVault(address(this));
        if (feeWad >= Math.WAD) revert InvalidFeeWad();
        uint256[4] memory pair;
        pair[idx] = amountIn;
        uint256[4] memory invIn = _pairToInvPreview(pair);
        shares = Math.singleJoinExactInShares(
            _invWadAll(),
            Math.scaleTo(invIn[idx], Repo._layout().invScales[idx]),
            idx,
            _amp(),
            supply,
            feeWad
        );
    }

    /* -------------------------- proportional exit --------------------------- */

    function previewExitProportional(uint256 shares)
        public
        view
        returns (uint256[] memory amounts)
    {
        uint256[4] memory natives = _nativeAll();
        uint256[4] memory invOut =
            Math.proportionalExitAmounts(shares, natives, _previewSupplyAfterProtocolMint());
        uint256[4] memory pairOut = _invToPairOutPreview(invOut);
        amounts = Math.toDynamic(pairOut);
    }

    function exitProportional(
        uint256 shares,
        address to,
        uint256[] calldata amountsMin,
        uint256 deadline
    ) public nonReentrant returns (uint256[] memory amounts) {
        _requireDeadline(deadline);
        if (to == address(0)) revert ZeroAddress();
        if (shares == 0) revert ZeroAmount();
        _requireAmountsLen4(amountsMin);
        uint256 protocolShares = _maybeMintProtocolFee();
        Repo.Layout storage l = Repo._layout();
        uint256[4] memory natives = _nativeAll();
        uint256[4] memory invOut =
            Math.proportionalExitAmounts(shares, natives, _totalSupply());
        // Full-book floor: leave all four native > 0
        for (uint256 i; i < Repo.N_TOKENS; ++i) {
            if (invOut[i] >= natives[i]) revert WouldZeroReserve();
        }
        uint256[4] memory pairOut = _invToPairOutPreview(invOut);
        for (uint256 i; i < Repo.N_TOKENS; ++i) {
            if (pairOut[i] < amountsMin[i]) revert Slippage();
        }
        _burnLp(msg.sender, shares);
        for (uint8 i; i < Repo.N_TOKENS; ++i) {
            if (invOut[i] == 0) continue;
            if (l.standardExchanges[i] != address(0)) {
                _unwrapSeShares(i, invOut[i], to);
            } else {
                _debitRawIntentional(i, invOut[i]);
                IERC20(l.tokens[i]).safeTransfer(to, invOut[i]);
            }
        }
        // post-state full book
        for (uint8 i; i < Repo.N_TOKENS; ++i) {
            if (_nativeAt(i) == 0) revert WouldZeroReserve();
        }
        _snapshotKLastIfFeeOn();
        _syncVaultReserves();
        int256[4] memory deltas;
        for (uint256 i; i < Repo.N_TOKENS; ++i) {
            deltas[i] = -int256(pairOut[i]);
        }
        amounts = Math.toDynamic(pairOut);
        emit IUniswapV4StandardExchangeQuadStableBufferHook.Exit(
            msg.sender, to, shares, deltas, protocolShares
        );
    }

    /* ----------------------- single-asset exact BPT in ---------------------- */

    function previewExitSingleAssetExactBptIn(address tokenOut, uint256 sharesIn)
        public
        view
        returns (uint256 amountOut)
    {
        return _quoteExitSingleExactBptIn(tokenOut, sharesIn);
    }

    function exitSingleAssetExactBptIn(
        address tokenOut,
        uint256 sharesIn,
        address to,
        uint256 amountOutMin,
        uint256 deadline
    ) public nonReentrant returns (uint256 amountOut) {
        amountOut = _exitSingleAssetExactBptIn(tokenOut, sharesIn, to, amountOutMin, deadline);
    }

    function withdrawSingle(
        address tokenOut,
        uint256 sharesIn,
        address to,
        uint256 amountOutMin,
        uint256 deadline
    ) public nonReentrant returns (uint256 amountOut) {
        amountOut = _exitSingleAssetExactBptIn(tokenOut, sharesIn, to, amountOutMin, deadline);
    }

    function previewWithdrawSingle(address tokenOut, uint256 sharesIn)
        public
        view
        returns (uint256 amountOut)
    {
        return previewExitSingleAssetExactBptIn(tokenOut, sharesIn);
    }

    function _exitSingleAssetExactBptIn(
        address tokenOut,
        uint256 sharesIn,
        address to,
        uint256 amountOutMin,
        uint256 deadline
    ) internal returns (uint256 amountOut) {
        _requireDeadline(deadline);
        if (to == address(0)) revert ZeroAddress();
        if (sharesIn == 0) revert ZeroAmount();
        if (!Math.isFullBookReserves(_nativeAll())) revert NotFullBook();
        uint256 protocolShares = _maybeMintProtocolFee();
        amountOut = _quoteExitSingleExactBptIn(tokenOut, sharesIn);
        if (amountOut < amountOutMin) revert Slippage();
        uint8 idx = _tokenIndex(tokenOut);
        Repo.Layout storage l = Repo._layout();
        uint256 invOut = _singleExitInvOut(idx, sharesIn);
        if (invOut >= _nativeAt(idx)) revert WouldZeroReserve();
        _burnLp(msg.sender, sharesIn);
        if (l.standardExchanges[idx] != address(0)) {
            _unwrapSeShares(idx, invOut, to);
        } else {
            _debitRawIntentional(idx, invOut);
            IERC20(tokenOut).safeTransfer(to, invOut);
        }
        for (uint8 i; i < Repo.N_TOKENS; ++i) {
            if (_nativeAt(i) == 0) revert WouldZeroReserve();
        }
        _snapshotKLastIfFeeOn();
        _syncVaultReserves();
        emit IUniswapV4StandardExchangeQuadStableBufferHook.WithdrawSingle(
            msg.sender, to, tokenOut, amountOut, sharesIn, protocolShares
        );
    }

    function _singleExitInvOut(uint8 idx, uint256 sharesIn) internal view returns (uint256 invOut) {
        uint256 feeWad = _feeOracle().dexSwapFeeOfVault(address(this));
        if (feeWad >= Math.WAD) revert InvalidFeeWad();
        // Match exec: protocol mint first (when fee-on), then burn sharesIn against post-mint supply.
        uint256 outS = Math.singleExitExactBptInAmountOut(
            _invWadAll(), sharesIn, idx, _amp(), _previewSupplyAfterProtocolMint(), feeWad
        );
        invOut = Math.descale(outS, Repo._layout().invScales[idx]);
    }

    function _quoteExitSingleExactBptIn(address tokenOut, uint256 sharesIn)
        internal
        view
        returns (uint256 amountOut)
    {
        uint8 idx = _tokenIndex(tokenOut);
        uint256 invOut = _singleExitInvOut(idx, sharesIn);
        uint256[4] memory inv;
        inv[idx] = invOut;
        uint256[4] memory pair = _invToPairOutPreview(inv);
        amountOut = pair[idx];
    }
}
