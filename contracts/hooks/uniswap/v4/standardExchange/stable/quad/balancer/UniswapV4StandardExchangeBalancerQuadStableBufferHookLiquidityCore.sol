// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {UniswapV4StandardExchangeBalancerQuadStableBufferHookClaimLib as ClaimLib} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookClaimLib.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {
    IUniswapV4StandardExchangeBalancerQuadStableBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/interfaces/IUniswapV4StandardExchangeBalancerQuadStableBufferHook.sol";
import {
    UniswapV4StandardExchangeBalancerQuadStableBufferHookRepo as Repo
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookRepo.sol";
import {
    UniswapV4StandardExchangeBalancerQuadStableBufferHookMath as Math
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookMath.sol";
import {
    UniswapV4BalancerStableLiquidityUnitsCore
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4BalancerStableLiquidityUnitsCore.sol";

/**
 * @title UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityCore
 * @notice Join/exit + one-token aliases with native inventory settlement.
 * @dev Non-proportional liquidity uses the same SE-valued Balancer invariant as swaps.
 *      Full book only for single-asset and post-seed proportional. First mint requires all active balances > 0.
 */
abstract contract UniswapV4StandardExchangeBalancerQuadStableBufferHookLiquidityCore is
    UniswapV4BalancerStableLiquidityUnitsCore
{
    using SafeERC20 for IERC20;

    /* ---------------------------------------------------------------------- */
    /*                         liquidity: join / exit                         */
    /* ---------------------------------------------------------------------- */

    function _entryPreviewJoinProportional(uint256[] calldata amounts)
        internal
        view
        returns (uint256 shares, uint256[] memory usedAmounts)
    {
        // Simulate protocol growth mint dilution (exec mints before join algebra).
        return _computeJoinProportional(amounts, _previewSupplyAfterProtocolMint());
    }

    function _entryJoinProportional(
        uint256[] calldata amounts,
        address to,
        uint256 sharesMin,
        uint256 deadline
    ) internal nonReentrant returns (uint256 shares, uint256[] memory usedAmounts) {
        _requireDeadline(deadline);
        if (to == address(0)) revert ZeroAddress();
        uint256 protocolShares = _maybeMintProtocolFee();
        bool first = _totalSupply() == 0;
        // After real protocol mint, use live supply (do not double-simulate mint).
        (shares, usedAmounts) = _computeJoinProportional(amounts, _totalSupply());
        if (shares < sharesMin) revert Slippage();
        uint256[] memory used = _checkedAmounts(usedAmounts);
        _commitJoin(used, to, shares, first, protocolShares);
    }

    function _computeJoinProportional(uint256[] memory amounts, uint256 supply)
        internal
        view
        returns (uint256 shares, uint256[] memory used)
    {
        _requireAmountsLength(amounts);
        uint256[] memory pairIn = _checkedAmounts(amounts);
        uint256[] memory invIn = _pairToInvPreview(pairIn);
        if (supply == 0) {
            return _firstMint(invIn, pairIn);
        }
        uint256[] memory natives = _nativeAll();
        if (!Math.isFullBookReserves(natives)) revert NotFullBook();
        return _fullPropJoin(pairIn, invIn, supply);
    }

    function _firstMint(uint256[] memory invAmounts, uint256[] memory pairAmounts)
        internal
        view
        returns (uint256 shares, uint256[] memory usedPair)
    {
        // First mint requires all active balances inventory deltas > 0.
        for (uint256 i; i < Repo._numTokens(); ++i) {
            if (invAmounts[i] == 0 || pairAmounts[i] == 0) revert ZeroAmount();
        }
        uint256[] memory scaled = _initialLiquidityValues(pairAmounts, new bool[](pairAmounts.length));
        shares = Math.firstMintShares(scaled, _amp());
        usedPair = Math.toDynamic(pairAmounts);
    }

    function _fullPropJoin(uint256[] memory pairAmounts, uint256[] memory invIn, uint256 supply)
        internal
        view
        returns (uint256 shares, uint256[] memory usedPairDyn)
    {
        invIn;
        return _quoteFlexibleJoin(pairAmounts, new bool[](pairAmounts.length), supply);
    }

    function _commitJoin(
        uint256[] memory pairUsed,
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
        _refundBufferedDust();
        _snapshotKLastIfFeeOn();
        _syncVaultReserves();
        int256[] memory deltas = new int256[](Repo._numTokens());
        for (uint256 i; i < Repo._numTokens(); ++i) {
            deltas[i] = int256(pairUsed[i]);
        }
        emit IUniswapV4StandardExchangeBalancerQuadStableBufferHook.Join(
            msg.sender, to, shares, deltas, protocolSharesMinted
        );
    }

    /* ----------------------------- unbalanced and exact-output liquidity ----------------------------- */

    function _entryPreviewJoinUnbalanced(uint256[] calldata amounts) internal view returns (uint256 shares) {
        return _quoteJoinUnbalanced(amounts, _previewSupplyAfterProtocolMint());
    }

    function _entryJoinUnbalanced(uint256[] calldata amounts, address to, uint256 sharesMin, uint256 deadline)
        internal nonReentrant returns (uint256 shares)
    {
        _requireDeadline(deadline);
        if (to == address(0)) revert ZeroAddress();
        uint256 protocolShares = _maybeMintProtocolFee();
        bool first = _totalSupply() == 0;
        shares = _quoteJoinUnbalanced(amounts, _totalSupply());
        if (shares < sharesMin || shares == 0) revert Slippage();
        _commitJoin(amounts, to, shares, first, protocolShares);
    }

    function _quoteJoinUnbalanced(uint256[] memory amounts, uint256 supply) internal view returns (uint256 shares) {
        _requireAmountsLength(amounts);
        uint256[] memory inv = _pairToInvPreview(amounts);
        if (supply == 0) {
            (shares,) = _firstMint(inv, amounts);
            return shares;
        }
        return Math.unbalancedJoinShares(_ratedWadAll(), _liquidityAmounts(inv), _amp(), supply, dexSwapFee());
    }

    function _entryPreviewJoinSingleAssetExactOut(address tokenIn, uint256 sharesOut) internal view returns (uint256) {
        return _quoteSingleJoinExactOut(tokenIn, sharesOut, _previewSupplyAfterProtocolMint());
    }

    function _entryJoinSingleAssetExactOut(address tokenIn, uint256 sharesOut, address to, uint256 amountInMax, uint256 deadline)
        internal nonReentrant returns (uint256 amountIn)
    {
        _requireDeadline(deadline);
        if (to == address(0)) revert ZeroAddress();
        uint256 protocolShares = _maybeMintProtocolFee();
        amountIn = _quoteSingleJoinExactOut(tokenIn, sharesOut, _totalSupply());
        if (amountIn > amountInMax) revert Slippage();
        (uint8 index, bool isShare) = _indexOfPairOrSe(tokenIn);
        _pull(tokenIn, amountIn);
        if (!isShare) _bufferToken(index, amountIn);
        _mintLp(to, sharesOut);
        _refundBufferedDust();
        _snapshotKLastIfFeeOn();
        _syncVaultReserves();
        emit IUniswapV4StandardExchangeBalancerQuadStableBufferHook.DepositSingle(
            msg.sender, to, tokenIn, amountIn, sharesOut, protocolShares
        );
    }

    function _quoteSingleJoinExactOut(address tokenIn, uint256 sharesOut, uint256 supply)
        internal view returns (uint256 amountIn)
    {
        (uint8 index, bool isShare) = _indexOfPairOrSe(tokenIn);
        uint256 scaledIn = Math.singleJoinExactOutAmountIn(
            _ratedWadAll(), sharesOut, index, _amp(), supply, dexSwapFee()
        );
        Repo.Layout storage l = Repo._layout();
        uint256 invIn = _liquidityInventory(index, scaledIn, true);
        address se = l.standardExchanges[index];
        if (isShare || se == address(0)) return invIn;
        return ClaimLib.bufferInputForShares(se, tokenIn, invIn);
    }

    function _entryPreviewExitSingleAssetExactTokenOut(address tokenOut, uint256 amountOut) internal view returns (uint256) {
        return _quoteSingleExitExactTokenOut(tokenOut, amountOut, _previewSupplyAfterProtocolMint());
    }

    function _entryExitSingleAssetExactTokenOut(address tokenOut, uint256 amountOut, address to, uint256 sharesInMax, uint256 deadline)
        internal nonReentrant returns (uint256 sharesIn)
    {
        return _exitSingleExactTokenOut(tokenOut, amountOut, to, sharesInMax, deadline);
    }

    function _quoteSingleExitExactTokenOut(address tokenOut, uint256 amountOut, uint256 supply)
        internal view returns (uint256)
    {
        (uint8 index, bool isShare) = _indexOfPairOrSe(tokenOut);
        Repo.Layout storage l = Repo._layout();
        uint256 invOut = amountOut;
        address se = l.standardExchanges[index];
        if (!isShare && se != address(0)) {
            invOut = IStandardExchangeOut(se).previewExchangeOut(IERC20(se), IERC20(tokenOut), amountOut);
        }
        return Math.singleExitExactTokenOutShares(
            _ratedWadAll(), _liquidityValue(index, invOut, true), index, _amp(), supply, dexSwapFee()
        );
    }

    function _exitSingleExactTokenOut(address tokenOut, uint256 amountOut, address to, uint256 sharesInMax, uint256 deadline)
        internal returns (uint256 sharesIn)
    {
        _requireDeadline(deadline);
        if (to == address(0)) revert ZeroAddress();
        uint256 protocolShares = _maybeMintProtocolFee();
        sharesIn = _quoteSingleExitExactTokenOut(tokenOut, amountOut, _totalSupply());
        if (sharesIn == 0 || sharesIn > sharesInMax) revert Slippage();
        (uint8 index, bool isShare) = _indexOfPairOrSe(tokenOut);
        _burnLp(msg.sender, sharesIn);
        if (!isShare && Repo._layout().standardExchanges[index] != address(0)) {
            _unwrapExactTokenOut(index, amountOut, to);
        } else {
            if (amountOut >= _nativeAt(index)) revert WouldZeroReserve();
            if (!isShare) _debitRawIntentional(index, amountOut);
            IERC20(tokenOut).safeTransfer(to, amountOut);
        }
        if (!Math.isFullBookReserves(_nativeAll())) revert WouldZeroReserve();
        _snapshotKLastIfFeeOn();
        _syncVaultReserves();
        emit IUniswapV4StandardExchangeBalancerQuadStableBufferHook.WithdrawSingle(
            msg.sender, to, tokenOut, amountOut, sharesIn, protocolShares
        );
    }

    function _entryPreviewWithdrawSingleExactOut(address tokenOut, uint256 amountOut) internal view returns (uint256) {
        return _entryPreviewExitSingleAssetExactTokenOut(tokenOut, amountOut);
    }

    function _entryWithdrawSingleExactOut(address tokenOut, uint256 amountOut, address to, uint256 sharesInMax, uint256 deadline)
        internal nonReentrant returns (uint256)
    {
        return _exitSingleExactTokenOut(tokenOut, amountOut, to, sharesInMax, deadline);
    }

    /* -------------------------- single-asset join --------------------------- */

    function _entryPreviewJoinSingleAssetExactIn(address tokenIn, uint256 amountIn)
        internal
        view
        returns (uint256 shares)
    {
        return _quoteSingleJoinExactIn(tokenIn, amountIn, _previewSupplyAfterProtocolMint());
    }

    function _entryJoinSingleAssetExactIn(
        address tokenIn,
        uint256 amountIn,
        address to,
        uint256 sharesMin,
        uint256 deadline
    ) internal nonReentrant returns (uint256 shares) {
        shares = _joinSingleAssetExactIn(tokenIn, amountIn, to, sharesMin, deadline);
    }

    function _entryDepositSingle(
        address tokenIn,
        uint256 amountIn,
        address to,
        uint256 sharesMin,
        uint256 deadline
    ) internal nonReentrant returns (uint256 shares) {
        shares = _joinSingleAssetExactIn(tokenIn, amountIn, to, sharesMin, deadline);
    }

    function _entryPreviewDepositSingle(address tokenIn, uint256 amountIn)
        internal
        view
        returns (uint256 shares)
    {
        return _entryPreviewJoinSingleAssetExactIn(tokenIn, amountIn);
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
        (uint8 idx, bool seUnit) = _indexOfPairOrSe(tokenIn);
        shares = _quoteSingleJoinExactIn(tokenIn, amountIn, _totalSupply());
        if (shares < sharesMin) revert Slippage();
        if (seUnit) {
            // B6: pull SE vault shares directly into inventory (no buffer wrap).
            _pull(tokenIn, amountIn);
        } else {
            uint256[] memory used = new uint256[](Repo._numTokens());
            used[idx] = amountIn;
            _pullAmounts(used);
            _bufferLast(used);
            _refundBufferedDust();
        }
        _mintLp(to, shares);
        _snapshotKLastIfFeeOn();
        _syncVaultReserves();
        emit IUniswapV4StandardExchangeBalancerQuadStableBufferHook.DepositSingle(
            msg.sender, to, tokenIn, amountIn, shares, protocolShares
        );
    }

    function _quoteSingleJoinExactIn(address tokenIn, uint256 amountIn, uint256 supply)
        internal
        view
        returns (uint256 shares)
    {
        (uint8 idx, bool seUnit) = _indexOfPairOrSe(tokenIn);
        uint256 feeWad = _feeOracle().dexSwapFeeOfVault(address(this));
        if (feeWad >= Math.WAD) revert InvalidFeeWad();
        uint256 invIn;
        if (seUnit) {
            // Inventory unit already (SE share amount).
            invIn = amountIn;
        } else {
            uint256[] memory pair = new uint256[](Repo._numTokens());
            pair[idx] = amountIn;
            invIn = _pairToInvPreview(pair)[idx];
        }
        shares = Math.singleJoinExactInShares(
            _ratedWadAll(),
            _liquidityValue(idx, invIn, false),
            idx,
            _amp(),
            supply,
            feeWad
        );
    }

    /* -------------------------- proportional exit --------------------------- */

    function _entryPreviewExitProportional(uint256 shares)
        internal
        view
        returns (uint256[] memory amounts)
    {
        uint256[] memory natives = _nativeAll();
        uint256[] memory invOut =
            Math.proportionalExitAmounts(shares, natives, _previewSupplyAfterProtocolMint());
        uint256[] memory pairOut = _invToPairOutPreview(invOut);
        amounts = Math.toDynamic(pairOut);
    }

    function _entryExitProportional(
        uint256 shares,
        address to,
        uint256[] calldata amountsMin,
        uint256 deadline
    ) internal nonReentrant returns (uint256[] memory amounts) {
        _requireDeadline(deadline);
        if (to == address(0)) revert ZeroAddress();
        if (shares == 0) revert ZeroAmount();
        _requireAmountsLength(amountsMin);
        uint256 protocolShares = _maybeMintProtocolFee();
        Repo.Layout storage l = Repo._layout();
        uint256[] memory natives = _nativeAll();
        uint256[] memory invOut =
            Math.proportionalExitAmounts(shares, natives, _totalSupply());
        // Full-book floor: leave all active balances native > 0
        for (uint256 i; i < Repo._numTokens(); ++i) {
            if (invOut[i] >= natives[i]) revert WouldZeroReserve();
        }
        uint256[] memory pairOut = _invToPairOutPreview(invOut);
        for (uint256 i; i < Repo._numTokens(); ++i) {
            if (pairOut[i] < amountsMin[i]) revert Slippage();
        }
        _burnLp(msg.sender, shares);
        for (uint8 i; i < Repo._numTokens(); ++i) {
            if (invOut[i] == 0) continue;
            if (l.standardExchanges[i] != address(0)) {
                _unwrapSeShares(i, invOut[i], to);
            } else {
                _debitRawIntentional(i, invOut[i]);
                IERC20(l.tokens[i]).safeTransfer(to, invOut[i]);
            }
        }
        // post-state full book
        for (uint8 i; i < Repo._numTokens(); ++i) {
            if (_nativeAt(i) == 0) revert WouldZeroReserve();
        }
        _snapshotKLastIfFeeOn();
        _syncVaultReserves();
        int256[] memory deltas = new int256[](Repo._numTokens());
        for (uint256 i; i < Repo._numTokens(); ++i) {
            deltas[i] = -int256(pairOut[i]);
        }
        amounts = Math.toDynamic(pairOut);
        emit IUniswapV4StandardExchangeBalancerQuadStableBufferHook.Exit(
            msg.sender, to, shares, deltas, protocolShares
        );
    }

    /* ----------------------- single-asset exact BPT in ---------------------- */

    function _entryPreviewExitSingleAssetExactBptIn(address tokenOut, uint256 sharesIn)
        internal
        view
        returns (uint256 amountOut)
    {
        return _quoteExitSingleExactBptIn(tokenOut, sharesIn);
    }

    function _entryExitSingleAssetExactBptIn(
        address tokenOut,
        uint256 sharesIn,
        address to,
        uint256 amountOutMin,
        uint256 deadline
    ) internal nonReentrant returns (uint256 amountOut) {
        amountOut = _exitSingleAssetExactBptIn(tokenOut, sharesIn, to, amountOutMin, deadline);
    }

    function _entryWithdrawSingle(
        address tokenOut,
        uint256 sharesIn,
        address to,
        uint256 amountOutMin,
        uint256 deadline
    ) internal nonReentrant returns (uint256 amountOut) {
        amountOut = _exitSingleAssetExactBptIn(tokenOut, sharesIn, to, amountOutMin, deadline);
    }

    function _entryPreviewWithdrawSingle(address tokenOut, uint256 sharesIn)
        internal
        view
        returns (uint256 amountOut)
    {
        return _entryPreviewExitSingleAssetExactBptIn(tokenOut, sharesIn);
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
        (uint8 idx, bool seUnit) = _indexOfPairOrSe(tokenOut);
        Repo.Layout storage l = Repo._layout();
        uint256 invOut = _singleExitInvOut(idx, sharesIn);
        if (invOut >= _nativeAt(idx)) revert WouldZeroReserve();
        _burnLp(msg.sender, sharesIn);
        if (l.standardExchanges[idx] != address(0)) {
            if (seUnit) {
                // B6: pay out SE vault shares without unwrap.
                IERC20(l.standardExchanges[idx]).safeTransfer(to, invOut);
            } else {
                _unwrapSeShares(idx, invOut, to);
            }
        } else {
            _debitRawIntentional(idx, invOut);
            IERC20(tokenOut).safeTransfer(to, invOut);
        }
        for (uint8 i; i < Repo._numTokens(); ++i) {
            if (_nativeAt(i) == 0) revert WouldZeroReserve();
        }
        _snapshotKLastIfFeeOn();
        _syncVaultReserves();
        emit IUniswapV4StandardExchangeBalancerQuadStableBufferHook.WithdrawSingle(
            msg.sender, to, tokenOut, amountOut, sharesIn, protocolShares
        );
    }

    function _singleExitInvOut(uint8 idx, uint256 sharesIn) internal view returns (uint256 invOut) {
        uint256 feeWad = _feeOracle().dexSwapFeeOfVault(address(this));
        if (feeWad >= Math.WAD) revert InvalidFeeWad();
        // Match exec: protocol mint first (when fee-on), then burn sharesIn against post-mint supply.
        uint256 outS = Math.singleExitExactBptInAmountOut(
            _ratedWadAll(), sharesIn, idx, _amp(), _previewSupplyAfterProtocolMint(), feeWad
        );
        invOut = _liquidityInventory(idx, outS, false);
    }

    function _quoteExitSingleExactBptIn(address tokenOut, uint256 sharesIn)
        internal
        view
        returns (uint256 amountOut)
    {
        (uint8 idx, bool seUnit) = _indexOfPairOrSe(tokenOut);
        uint256 invOut = _singleExitInvOut(idx, sharesIn);
        if (seUnit) {
            // B6: amountOut is SE share inventory units.
            amountOut = invOut;
        } else {
            uint256[] memory inv = new uint256[](Repo._numTokens());
            inv[idx] = invOut;
            uint256[] memory pair = _invToPairOutPreview(inv);
            amountOut = pair[idx];
        }
    }
}
