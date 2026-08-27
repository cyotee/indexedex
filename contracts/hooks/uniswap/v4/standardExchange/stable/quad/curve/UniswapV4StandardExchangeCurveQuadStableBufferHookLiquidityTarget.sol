// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {
    IUniswapV4StandardExchangeCurveQuadStableBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableBufferHook.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableBufferHookRepo as Repo
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookRepo.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableBufferHookMath as Math
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookMath.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableBufferHookTarget
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookTarget.sol";

/**
 * @title UniswapV4StandardExchangeCurveQuadStableBufferHookLiquidityTarget
 * @notice Join/exit + one-token aliases on inventory domain (StableSwap single-asset + prop).
 * @dev Firm M2: joinUnbalanced / joinSingleAssetExactOut / exitSingleAssetExactTokenOut shipped closed-form.
 *      B6: flexible SE-share / pair LP paths with per-leg flags.
 *      Full book only for single-asset and post-seed proportional. First mint requires all four > 0.
 */
abstract contract UniswapV4StandardExchangeCurveQuadStableBufferHookLiquidityTarget is
    UniswapV4StandardExchangeCurveQuadStableBufferHookTarget
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
        emit IUniswapV4StandardExchangeCurveQuadStableBufferHook.Join(
            msg.sender, to, shares, deltas, protocolSharesMinted
        );
    }

    /* ----------------------- firm: unbalanced join -------------------------- */

    function previewJoinUnbalanced(uint256[] calldata amounts) public view returns (uint256 shares) {
        (address[] memory ts, uint256[] memory am) = _tokensAmountsFromOrdered(amounts);
        return _previewJoinUnbalancedLiq(ts, am);
    }

    function joinUnbalanced(uint256[] calldata amounts, address to, uint256 sharesMin, uint256 deadline)
        public
        nonReentrant
        returns (uint256 shares)
    {
        (address[] memory ts, uint256[] memory am) = _tokensAmountsFromOrdered(amounts);
        shares = _joinUnbalancedLiq(ts, am, to, sharesMin, deadline);
    }

    function previewJoinUnbalanced(address[] calldata tokensIn, uint256[] calldata amounts)
        public
        view
        returns (uint256 shares)
    {
        return _previewJoinUnbalancedLiq(tokensIn, amounts);
    }

    function joinUnbalanced(
        address[] calldata tokensIn,
        uint256[] calldata amounts,
        address to,
        uint256 sharesMin,
        uint256 deadline
    ) public nonReentrant returns (uint256 shares) {
        shares = _joinUnbalancedLiq(tokensIn, amounts, to, sharesMin, deadline);
    }

    function _previewJoinUnbalancedLiq(address[] memory tokensIn, uint256[] memory amounts)
        internal
        view
        returns (uint256 shares)
    {
        JoinUnbalancedAcc memory acc = _accumulateJoin(tokensIn, amounts);
        if (!_isLive()) {
            for (uint8 i; i < Repo.N_TOKENS; ++i) {
                if (!acc.filled[i]) return 0;
            }
        }
        uint256[] memory used = Math.toDynamic(acc.edge);
        uint256 supply = _previewSupplyAfterProtocolMint();
        if (supply == 0) {
            (shares,) = _computeJoinProportional(used, 0);
            return shares;
        }
        return _quoteUnbalancedJoin(used, supply);
    }

    function _joinUnbalancedLiq(
        address[] memory tokensIn,
        uint256[] memory amounts,
        address to,
        uint256 sharesMin,
        uint256 deadline
    ) internal returns (uint256 shares) {
        _requireDeadline(deadline);
        if (to == address(0)) revert ZeroAddress();
        JoinUnbalancedAcc memory acc = _accumulateJoin(tokensIn, amounts);
        _requireFirstJoinFullBook(acc);
        uint256 protocolShares = _maybeMintProtocolFee();
        bool first = _totalSupply() == 0;
        uint256[] memory used = Math.toDynamic(acc.edge);
        if (first) {
            (shares,) = _computeJoinProportional(used, 0);
            if (shares < sharesMin) revert Slippage();
            _commitJoin(acc.edge, to, shares, true, protocolShares);
            return shares;
        }
        if (!Math.isFullBookReserves(_nativeAll())) revert NotFullBook();
        shares = _quoteUnbalancedJoin(used, _totalSupply());
        if (shares < sharesMin) revert Slippage();
        _commitJoin(acc.edge, to, shares, false, protocolShares);
    }

    function _quoteUnbalancedJoin(uint256[] memory pairAmounts, uint256 supply)
        internal
        view
        returns (uint256 shares)
    {
        _requireAmountsLen4(pairAmounts);
        uint256 feeWad = _feeOracle().dexSwapFeeOfVault(address(this));
        if (feeWad >= Math.WAD) revert InvalidFeeWad();
        uint256[4] memory pairIn = _toFixed4(pairAmounts);
        uint256[4] memory invIn = _pairToInvPreview(pairIn);
        shares = Math.unbalancedJoinShares(
            _invWadAll(), _scaleInv(invIn), _amp(), supply, feeWad
        );
    }

    /* -------------------- firm: single-asset exact LP out ------------------- */

    function previewJoinSingleAssetExactOut(address tokenIn, uint256 sharesOut)
        public
        view
        returns (uint256 amountIn)
    {
        return _quoteSingleJoinExactOut(tokenIn, sharesOut, _previewSupplyAfterProtocolMint());
    }

    function joinSingleAssetExactOut(
        address tokenIn,
        uint256 sharesOut,
        address to,
        uint256 amountInMax,
        uint256 deadline
    ) public nonReentrant returns (uint256 amountIn) {
        _requireDeadline(deadline);
        if (to == address(0)) revert ZeroAddress();
        if (sharesOut == 0) revert ZeroAmount();
        if (_totalSupply() == 0 || !Math.isFullBookReserves(_nativeAll())) revert NotFullBook();
        uint256 protocolShares = _maybeMintProtocolFee();
        amountIn = _quoteSingleJoinExactOut(tokenIn, sharesOut, _totalSupply());
        if (amountIn > amountInMax) revert Slippage();
        uint8 idx = _tokenIndex(tokenIn);
        uint256[4] memory used;
        used[idx] = amountIn;
        _pullAmounts(used);
        _bufferLast(used);
        _mintLp(to, sharesOut);
        _snapshotKLastIfFeeOn();
        _refundBufferedDust();
        _syncVaultReserves();
        emit IUniswapV4StandardExchangeCurveQuadStableBufferHook.DepositSingle(
            msg.sender, to, tokenIn, amountIn, sharesOut, protocolShares
        );
    }

    function _quoteSingleJoinExactOut(address tokenIn, uint256 sharesOut, uint256 supply)
        internal
        view
        returns (uint256 amountIn)
    {
        uint8 idx = _tokenIndex(tokenIn);
        uint256 feeWad = _feeOracle().dexSwapFeeOfVault(address(this));
        if (feeWad >= Math.WAD) revert InvalidFeeWad();
        Repo.Layout storage l = Repo._layout();
        uint256 aS = Math.singleJoinExactOutAmountIn(
            _invWadAll(), idx, sharesOut, _amp(), supply, feeWad
        );
        uint256 invNeeded = Math.descaleUp(aS, l.invScales[idx]);
        if (l.standardExchanges[idx] == address(0)) {
            amountIn = invNeeded;
        } else {
            // Invert buffer preview: pair such that SE shares ≈ invNeeded (closed-form, no binary search).
            address se = l.standardExchanges[idx];
            address t = l.tokens[idx];
            amountIn = invNeeded;
            uint256 got = IStandardExchangeIn(se).previewExchangeIn(IERC20(t), amountIn, IERC20(se));
            if (got < invNeeded && got > 0) {
                amountIn = (invNeeded * amountIn + got - 1) / got;
            }
        }
    }

    /* ----------------- firm: single-asset exact token out exit -------------- */

    function previewExitSingleAssetExactTokenOut(address tokenOut, uint256 amountOut)
        public
        view
        returns (uint256 sharesIn)
    {
        return _quoteExitSingleExactTokenOut(tokenOut, amountOut, _previewSupplyAfterProtocolMint());
    }

    function exitSingleAssetExactTokenOut(
        address tokenOut,
        uint256 amountOut,
        address to,
        uint256 sharesInMax,
        uint256 deadline
    ) public nonReentrant returns (uint256 sharesIn) {
        sharesIn = _exitSingleAssetExactTokenOut(tokenOut, amountOut, to, sharesInMax, deadline);
    }

    function previewWithdrawSingleExactOut(address tokenOut, uint256 amountOut)
        public
        view
        returns (uint256 sharesIn)
    {
        return previewExitSingleAssetExactTokenOut(tokenOut, amountOut);
    }

    function withdrawSingleExactOut(
        address tokenOut,
        uint256 amountOut,
        address to,
        uint256 sharesInMax,
        uint256 deadline
    ) public nonReentrant returns (uint256 sharesIn) {
        sharesIn = _exitSingleAssetExactTokenOut(tokenOut, amountOut, to, sharesInMax, deadline);
    }

    function _exitSingleAssetExactTokenOut(
        address tokenOut,
        uint256 amountOut,
        address to,
        uint256 sharesInMax,
        uint256 deadline
    ) internal returns (uint256 sharesIn) {
        _requireDeadline(deadline);
        if (to == address(0)) revert ZeroAddress();
        if (amountOut == 0) revert ZeroAmount();
        if (!Math.isFullBookReserves(_nativeAll())) revert NotFullBook();
        uint256 protocolShares = _maybeMintProtocolFee();
        sharesIn = _quoteExitSingleExactTokenOut(tokenOut, amountOut, _totalSupply());
        if (sharesIn > sharesInMax) revert Slippage();
        uint8 idx = _tokenIndex(tokenOut);
        Repo.Layout storage l = Repo._layout();
        uint256 invOut;
        if (l.standardExchanges[idx] == address(0)) {
            invOut = amountOut;
        } else {
            invOut = IStandardExchangeOut(l.standardExchanges[idx]).previewExchangeOut(
                IERC20(l.standardExchanges[idx]), IERC20(tokenOut), amountOut
            );
        }
        if (invOut >= _nativeAt(idx)) revert WouldZeroReserve();
        _burnLp(msg.sender, sharesIn);
        if (l.standardExchanges[idx] != address(0)) {
            _unwrapExactTokenOut(idx, amountOut, to);
        } else {
            _debitRawIntentional(idx, invOut);
            IERC20(tokenOut).safeTransfer(to, invOut);
        }
        for (uint8 i; i < Repo.N_TOKENS; ++i) {
            if (_nativeAt(i) == 0) revert WouldZeroReserve();
        }
        _snapshotKLastIfFeeOn();
        _syncVaultReserves();
        emit IUniswapV4StandardExchangeCurveQuadStableBufferHook.WithdrawSingleExactOut(
            msg.sender, to, tokenOut, amountOut, sharesIn, protocolShares
        );
    }

    function _quoteExitSingleExactTokenOut(address tokenOut, uint256 amountOut, uint256 supply)
        internal
        view
        returns (uint256 sharesIn)
    {
        uint8 idx = _tokenIndex(tokenOut);
        uint256 feeWad = _feeOracle().dexSwapFeeOfVault(address(this));
        if (feeWad >= Math.WAD) revert InvalidFeeWad();
        Repo.Layout storage l = Repo._layout();
        uint256 invOut;
        if (l.standardExchanges[idx] == address(0)) {
            invOut = amountOut;
        } else {
            invOut = IStandardExchangeOut(l.standardExchanges[idx]).previewExchangeOut(
                IERC20(l.standardExchanges[idx]), IERC20(tokenOut), amountOut
            );
        }
        sharesIn = Math.singleExitExactTokenOutSharesIn(
            _invWadAll(),
            idx,
            Math.scaleToUp(invOut, l.invScales[idx]),
            _amp(),
            supply,
            feeWad
        );
    }

    /* -------------------------- single-asset join --------------------------- */

    function previewJoinSingleAssetExactIn(address tokenIn, uint256 amountIn)
        public
        view
        returns (uint256 shares)
    {
        if (!_isLive() || amountIn == 0) return 0;
        (bool ok, uint8 idx, bool isSeShare) = _tryResolveJoinToken(tokenIn);
        if (!ok) return 0;
        if (isSeShare) {
            return _quoteSingleJoinExactInFlexible(
                Repo._layout().tokens[idx], amountIn, true, _previewSupplyAfterProtocolMint()
            );
        }
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
        if (!_isLive()) revert NotLive();
        (uint8 idx, bool isSeShare) = _resolveJoinToken(tokenIn);
        if (isSeShare) {
            shares = _joinSingleAssetExactInFlexible(
                Repo._layout().tokens[idx], amountIn, true, to, sharesMin, deadline
            );
            return shares;
        }
        uint256 protocolShares = _maybeMintProtocolFee();
        shares = _quoteSingleJoinExactIn(tokenIn, amountIn, _totalSupply());
        if (shares < sharesMin) revert Slippage();
        uint256[4] memory used;
        used[idx] = amountIn;
        _pullAmounts(used);
        _bufferLast(used);
        _mintLp(to, shares);
        _snapshotKLastIfFeeOn();
        _refundBufferedDust();
        _syncVaultReserves();
        emit IUniswapV4StandardExchangeCurveQuadStableBufferHook.DepositSingle(
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

    function previewBurnToToken(uint256 lpAmount, address tokenOut)
        public
        view
        returns (uint256 amountOut)
    {
        if (lpAmount == 0 || _totalSupply() == 0 || !_isLive()) return 0;
        (bool ok, uint8 idx, bool wantSe) = _tryResolveJoinToken(tokenOut);
        if (!ok) return 0;
        uint256[4] memory invOut =
            Math.proportionalExitAmounts(lpAmount, _nativeAll(), _previewSupplyAfterProtocolMint());
        if (wantSe) return invOut[idx];
        uint256[4] memory pairOut = _invToPairOutPreview(invOut);
        return pairOut[idx];
    }

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
        emit IUniswapV4StandardExchangeCurveQuadStableBufferHook.Exit(
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
        emit IUniswapV4StandardExchangeCurveQuadStableBufferHook.WithdrawSingle(
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

    /* ---------------------------------------------------------------------- */
    /*                    B6: flexible SE-share / pair LP                     */
    /* ---------------------------------------------------------------------- */

    function previewJoinProportionalFlexible(uint256[] calldata amounts, bool[] calldata amountIsSeShare)
        public
        view
        returns (uint256 shares, uint256[] memory usedAmounts)
    {
        return _computeJoinProportionalFlexible(amounts, amountIsSeShare, _previewSupplyAfterProtocolMint());
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
        uint256 protocolShares = _maybeMintProtocolFee();
        bool first = _totalSupply() == 0;
        (shares, usedAmounts) = _computeJoinProportionalFlexible(amounts, amountIsSeShare, _totalSupply());
        if (shares < sharesMin) revert Slippage();
        _commitJoinFlexible(usedAmounts, amountIsSeShare, to, shares, first, protocolShares);
        emit IUniswapV4StandardExchangeCurveQuadStableBufferHook.JoinFlexible(
            msg.sender, to, shares, amounts, amountIsSeShare, usedAmounts, protocolShares
        );
    }

    function _computeJoinProportionalFlexible(
        uint256[] memory amounts,
        bool[] memory amountIsSeShare,
        uint256 supply
    ) internal view returns (uint256 shares, uint256[] memory used) {
        _requireAmountsLen4(amounts);
        if (amountIsSeShare.length != Repo.N_TOKENS) revert ArrayLengthMismatch();
        _validateSeShareFlags(amountIsSeShare);
        uint256[4] memory edge = _toFixed4(amounts);
        uint256[4] memory invIn = _edgeToInvPreview(edge, amountIsSeShare);
        if (supply == 0) {
            return _firstMint(invIn, edge);
        }
        uint256[4] memory natives = _nativeAll();
        if (!Math.isFullBookReserves(natives)) revert NotFullBook();
        return _fullPropJoin(edge, invIn, supply);
    }

    /// @dev Map user edge amounts → inventory deltas (SE shares or face). SE-share legs pass through.
    function _edgeToInvPreview(uint256[4] memory amounts, bool[] memory amountIsSeShare)
        internal
        view
        returns (uint256[4] memory invDeltas)
    {
        Repo.Layout storage l = Repo._layout();
        for (uint8 i; i < Repo.N_TOKENS; ++i) {
            if (amounts[i] == 0) continue;
            if (amountIsSeShare[i]) {
                invDeltas[i] = amounts[i];
            } else {
                address se = l.standardExchanges[i];
                if (se == address(0)) {
                    invDeltas[i] = amounts[i];
                } else {
                    invDeltas[i] = IStandardExchangeIn(se).previewExchangeIn(
                        IERC20(l.tokens[i]), amounts[i], IERC20(se)
                    );
                }
            }
        }
    }

    function _validateSeShareFlags(bool[] memory flags) internal view {
        if (flags.length != Repo.N_TOKENS) revert ArrayLengthMismatch();
        Repo.Layout storage l = Repo._layout();
        for (uint8 i; i < Repo.N_TOKENS; ++i) {
            if (flags[i] && l.standardExchanges[i] == address(0)) revert SeShareNotBuffered();
        }
    }

    function _commitJoinFlexible(
        uint256[] memory usedAmounts,
        bool[] memory amountIsSeShare,
        address to,
        uint256 shares,
        bool firstMint,
        uint256 protocolSharesMinted
    ) internal {
        Repo.Layout storage l = Repo._layout();
        // Pull edge units (pair or SE share), then buffer-last pair legs only.
        for (uint8 i; i < Repo.N_TOKENS; ++i) {
            if (usedAmounts[i] == 0) continue;
            if (amountIsSeShare[i]) {
                _pull(l.standardExchanges[i], usedAmounts[i]);
            } else {
                _pull(l.tokens[i], usedAmounts[i]);
            }
        }
        for (uint8 i; i < Repo.N_TOKENS; ++i) {
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
        // silence unused when no event from caller
        protocolSharesMinted;
    }

    function previewExitProportionalFlexible(uint256 shares, bool[] calldata receiveSeShare)
        public
        view
        returns (uint256[] memory amounts)
    {
        _validateSeShareFlags(receiveSeShare);
        uint256[4] memory natives = _nativeAll();
        uint256[4] memory invOut =
            Math.proportionalExitAmounts(shares, natives, _previewSupplyAfterProtocolMint());
        amounts = Math.toDynamic(_invToEdgeOutPreview(invOut, receiveSeShare));
    }

    function exitProportionalFlexible(
        uint256 shares,
        address to,
        bool[] calldata receiveSeShare,
        uint256[] calldata amountsMin,
        uint256 deadline
    ) public nonReentrant returns (uint256[] memory amounts) {
        _requireDeadline(deadline);
        if (to == address(0)) revert ZeroAddress();
        if (shares == 0) revert ZeroAmount();
        _validateSeShareFlags(receiveSeShare);
        _requireAmountsLen4(amountsMin);
        uint256 protocolShares = _maybeMintProtocolFee();
        uint256[4] memory invOut = Math.proportionalExitAmounts(shares, _nativeAll(), _totalSupply());
        _requireExitFloors(invOut);
        uint256[4] memory edgeOut = _invToEdgeOutPreview(invOut, receiveSeShare);
        _requireEdgeMins(edgeOut, amountsMin);
        _burnLp(msg.sender, shares);
        _payExitFlexibleLegs(invOut, receiveSeShare, to);
        _requirePostFullBook();
        _snapshotKLastIfFeeOn();
        _syncVaultReserves();
        amounts = Math.toDynamic(edgeOut);
        emit IUniswapV4StandardExchangeCurveQuadStableBufferHook.ExitFlexible(
            msg.sender, to, shares, receiveSeShare, amounts, protocolShares
        );
    }

    function _requireExitFloors(uint256[4] memory invOut) internal view {
        uint256[4] memory natives = _nativeAll();
        for (uint256 i; i < Repo.N_TOKENS; ++i) {
            if (invOut[i] >= natives[i]) revert WouldZeroReserve();
        }
    }

    function _requireEdgeMins(uint256[4] memory edgeOut, uint256[] calldata amountsMin) internal pure {
        for (uint256 i; i < Repo.N_TOKENS; ++i) {
            if (edgeOut[i] < amountsMin[i]) revert Slippage();
        }
    }

    function _requirePostFullBook() internal view {
        for (uint8 i; i < Repo.N_TOKENS; ++i) {
            if (_nativeAt(i) == 0) revert WouldZeroReserve();
        }
    }

    function _payExitFlexibleLegs(uint256[4] memory invOut, bool[] memory receiveSeShare, address to)
        internal
    {
        Repo.Layout storage l = Repo._layout();
        for (uint8 i; i < Repo.N_TOKENS; ++i) {
            uint256 amt = invOut[i];
            if (amt == 0) continue;
            address se = l.standardExchanges[i];
            if (se != address(0)) {
                if (receiveSeShare[i]) {
                    IERC20(se).safeTransfer(to, amt);
                } else {
                    _unwrapSeShares(i, amt, to);
                }
            } else {
                _debitRawIntentional(i, amt);
                IERC20(l.tokens[i]).safeTransfer(to, amt);
            }
        }
    }

    function _invToEdgeOutPreview(uint256[4] memory invOut, bool[] memory receiveSeShare)
        internal
        view
        returns (uint256[4] memory edgeOut)
    {
        Repo.Layout storage l = Repo._layout();
        for (uint8 i; i < Repo.N_TOKENS; ++i) {
            if (invOut[i] == 0) continue;
            address se = l.standardExchanges[i];
            if (se == address(0)) {
                edgeOut[i] = invOut[i];
            } else if (receiveSeShare[i]) {
                edgeOut[i] = invOut[i];
            } else {
                edgeOut[i] = IStandardExchangeIn(se).previewExchangeIn(
                    IERC20(se), invOut[i], IERC20(l.tokens[i])
                );
            }
        }
    }

    function previewJoinSingleAssetExactInFlexible(address tokenIn, uint256 amountIn, bool amountIsSeShare)
        public
        view
        returns (uint256 shares)
    {
        return _quoteSingleJoinExactInFlexible(tokenIn, amountIn, amountIsSeShare, _previewSupplyAfterProtocolMint());
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
        uint256 protocolShares = _maybeMintProtocolFee();
        shares = _quoteSingleJoinExactInFlexible(tokenIn, amountIn, amountIsSeShare, _totalSupply());
        if (shares < sharesMin) revert Slippage();
        uint256[] memory used = new uint256[](Repo.N_TOKENS);
        used[idx] = amountIn;
        bool[] memory flags = new bool[](Repo.N_TOKENS);
        flags[idx] = amountIsSeShare;
        _commitJoinFlexible(used, flags, to, shares, false, protocolShares);
        emit IUniswapV4StandardExchangeCurveQuadStableBufferHook.DepositSingleFlexible(
            msg.sender, to, tokenIn, amountIn, amountIsSeShare, shares, protocolShares
        );
    }

    function _quoteSingleJoinExactInFlexible(
        address tokenIn,
        uint256 amountIn,
        bool amountIsSeShare,
        uint256 supply
    ) internal view returns (uint256 shares) {
        uint8 idx = _tokenIndex(tokenIn);
        if (amountIsSeShare && Repo._layout().standardExchanges[idx] == address(0)) {
            revert SeShareNotBuffered();
        }
        uint256 feeWad = _feeOracle().dexSwapFeeOfVault(address(this));
        if (feeWad >= Math.WAD) revert InvalidFeeWad();
        uint256[4] memory edge;
        edge[idx] = amountIn;
        bool[] memory flags = new bool[](Repo.N_TOKENS);
        flags[idx] = amountIsSeShare;
        uint256[4] memory invIn = _edgeToInvPreview(edge, flags);
        shares = Math.singleJoinExactInShares(
            _invWadAll(),
            Math.scaleTo(invIn[idx], Repo._layout().invScales[idx]),
            idx,
            _amp(),
            supply,
            feeWad
        );
    }

    function previewExitSingleAssetExactBptInFlexible(
        address tokenOut,
        uint256 sharesIn,
        bool receiveSeShare
    ) public view returns (uint256 amountOut) {
        return _quoteExitSingleExactBptInFlexible(tokenOut, sharesIn, receiveSeShare);
    }

    function exitSingleAssetExactBptInFlexible(
        address tokenOut,
        uint256 sharesIn,
        bool receiveSeShare,
        address to,
        uint256 amountOutMin,
        uint256 deadline
    ) public nonReentrant returns (uint256 amountOut) {
        amountOut = _exitSingleAssetExactBptInFlexible(
            tokenOut, sharesIn, receiveSeShare, to, amountOutMin, deadline
        );
    }

    function withdrawSingleFlexible(
        address tokenOut,
        uint256 sharesIn,
        bool receiveSeShare,
        address to,
        uint256 amountOutMin,
        uint256 deadline
    ) public nonReentrant returns (uint256 amountOut) {
        amountOut = _exitSingleAssetExactBptInFlexible(
            tokenOut, sharesIn, receiveSeShare, to, amountOutMin, deadline
        );
    }

    function previewWithdrawSingleFlexible(address tokenOut, uint256 sharesIn, bool receiveSeShare)
        public
        view
        returns (uint256 amountOut)
    {
        return previewExitSingleAssetExactBptInFlexible(tokenOut, sharesIn, receiveSeShare);
    }

    function _exitSingleAssetExactBptInFlexible(
        address tokenOut,
        uint256 sharesIn,
        bool receiveSeShare,
        address to,
        uint256 amountOutMin,
        uint256 deadline
    ) internal returns (uint256 amountOut) {
        _requireDeadline(deadline);
        if (to == address(0)) revert ZeroAddress();
        if (sharesIn == 0) revert ZeroAmount();
        if (!Math.isFullBookReserves(_nativeAll())) revert NotFullBook();
        uint8 idx = _tokenIndex(tokenOut);
        if (receiveSeShare && Repo._layout().standardExchanges[idx] == address(0)) {
            revert SeShareNotBuffered();
        }
        uint256 protocolShares = _maybeMintProtocolFee();
        amountOut = _quoteExitSingleExactBptInFlexible(tokenOut, sharesIn, receiveSeShare);
        if (amountOut < amountOutMin) revert Slippage();
        uint256 invOut = _singleExitInvOut(idx, sharesIn);
        if (invOut >= _nativeAt(idx)) revert WouldZeroReserve();
        _burnLp(msg.sender, sharesIn);
        Repo.Layout storage l = Repo._layout();
        if (l.standardExchanges[idx] != address(0)) {
            if (receiveSeShare) {
                IERC20(l.standardExchanges[idx]).safeTransfer(to, invOut);
            } else {
                _unwrapSeShares(idx, invOut, to);
            }
        } else {
            _debitRawIntentional(idx, invOut);
            IERC20(tokenOut).safeTransfer(to, invOut);
        }
        for (uint8 i; i < Repo.N_TOKENS; ++i) {
            if (_nativeAt(i) == 0) revert WouldZeroReserve();
        }
        _snapshotKLastIfFeeOn();
        _syncVaultReserves();
        emit IUniswapV4StandardExchangeCurveQuadStableBufferHook.WithdrawSingleFlexible(
            msg.sender, to, tokenOut, amountOut, receiveSeShare, sharesIn, protocolShares
        );
    }

    function _quoteExitSingleExactBptInFlexible(address tokenOut, uint256 sharesIn, bool receiveSeShare)
        internal
        view
        returns (uint256 amountOut)
    {
        uint8 idx = _tokenIndex(tokenOut);
        if (receiveSeShare && Repo._layout().standardExchanges[idx] == address(0)) {
            revert SeShareNotBuffered();
        }
        uint256 invOut = _singleExitInvOut(idx, sharesIn);
        if (receiveSeShare || Repo._layout().standardExchanges[idx] == address(0)) {
            amountOut = invOut;
        } else {
            address se = Repo._layout().standardExchanges[idx];
            amountOut = IStandardExchangeIn(se).previewExchangeIn(
                IERC20(se), invOut, IERC20(tokenOut)
            );
        }
    }
}
