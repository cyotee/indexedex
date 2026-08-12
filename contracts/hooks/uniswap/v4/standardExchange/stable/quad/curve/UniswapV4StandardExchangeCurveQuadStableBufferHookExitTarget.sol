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
abstract contract UniswapV4StandardExchangeCurveQuadStableBufferHookExitTarget is
    UniswapV4StandardExchangeCurveQuadStableBufferHookTarget
{
    using SafeERC20 for IERC20;

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
