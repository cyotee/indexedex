// SPDX-License-Identifier: BUSL-1.1
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
 * @title UniswapV4StandardExchangeWeightedBufferHookLiquidityTarget
 * @notice Join/exit + one-token aliases (inventory domain, buffer-last).
 */
abstract contract UniswapV4StandardExchangeWeightedBufferHookLiquidityTarget is
    UniswapV4StandardExchangeWeightedBufferHookTarget
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
        return _computeJoinProportional(amounts);
    }

    function joinProportional(
        uint256[] calldata amounts,
        address to,
        uint256 sharesMin,
        uint256 deadline
    ) public nonReentrant returns (uint256 shares, uint256[] memory usedAmounts) {
        _requireDeadline(deadline);
        if (to == address(0)) revert ZeroAddress();
        uint256 protocolBefore = _maybeMintProtocolFee();
        bool first = _totalSupply() == 0;
        (shares, usedAmounts) = _computeJoinProportional(amounts);
        if (shares < sharesMin) revert Slippage();
        _commitJoin(usedAmounts, to, shares, first);
        protocolBefore;
    }

    function _computeJoinProportional(uint256[] memory amounts)
        internal
        view
        returns (uint256 shares, uint256[] memory used)
    {
        Repo.Layout storage l = Repo._layout();
        if (amounts.length != l.numTokens) revert InvalidN();
        uint256 supply = _totalSupply();
        // amounts are pair-token edge; map to inventory for algebra
        uint256[] memory invIn = _pairToInvPreview(amounts);
        if (supply == 0) {
            return _firstMint(invIn, amounts);
        }
        uint256[] memory natives = _nativeAll();
        if (Math.isFullBookReserves(natives)) {
            return _fullPropJoin(amounts, invIn, supply);
        }
        return _partialJoin(amounts, invIn, supply);
    }

    function _firstMint(uint256[] memory invAmounts, uint256[] memory pairAmounts)
        internal
        view
        returns (uint256 shares, uint256[] memory usedPair)
    {
        Repo.Layout storage l = Repo._layout();
        uint256 n = l.numTokens;
        usedPair = pairAmounts;
        uint256 pos = Math.countPositive(invAmounts);
        if (n == 2) {
            if (pos != 2) revert ZeroAmount();
        } else {
            if (pos < 2) revert ZeroAmount();
        }
        uint256[] memory scaled = _scaleInvAmounts(invAmounts);
        if (pos == n) {
            for (uint256 i; i < n; ++i) {
                if (invAmounts[i] == 0) revert ZeroAmount();
            }
            (shares,) = Math.firstMintSharesFull(l.weights, scaled);
        } else {
            (shares,) = Math.firstMintSharesPartial(l.weights, scaled);
        }
    }

    function _fullPropJoin(uint256[] memory pairAmounts, uint256[] memory invIn, uint256 supply)
        internal
        view
        returns (uint256 shares, uint256[] memory usedPair)
    {
        Repo.Layout storage l = Repo._layout();
        uint256 n = l.numTokens;
        for (uint256 i; i < n; ++i) {
            if (pairAmounts[i] == 0) revert ZeroAmount();
        }
        uint256[] memory aS = _scaleInvAmounts(invIn);
        uint256[] memory rS = _invWadAll();
        shares = Math.proportionalJoinShares(aS, rS, supply);
        usedPair = new uint256[](n);
        // proportional used inventory → back to pair (for SE use share used; pull is pair)
        // For prop joins user supplies max pair; used inventory = prop of live book
        for (uint256 i; i < n; ++i) {
            uint256 usedS = Math.proportionalUsedScaled(shares, rS[i], supply);
            uint256 usedInv = Math.descale(usedS, l.invScales[i]);
            if (usedInv == 0) revert Slippage();
            // map inv used → pair for pull: raw face or buffer invert
            if (l.standardExchanges[i] == address(0)) {
                usedPair[i] = usedInv;
            } else {
                if (invIn[i] == 0) revert ZeroAmount();
                usedPair[i] = (pairAmounts[i] * usedInv) / invIn[i];
                if (usedPair[i] == 0 || usedPair[i] > pairAmounts[i]) revert Slippage();
            }
        }
    }

    function _partialJoin(uint256[] memory pairAmounts, uint256[] memory invIn, uint256 supply)
        internal
        view
        returns (uint256 shares, uint256[] memory usedPair)
    {
        Repo.Layout storage l = Repo._layout();
        uint256 n = l.numTokens;
        uint256[] memory natives = new uint256[](n);
        for (uint8 i; i < n; ++i) {
            natives[i] = _nativeAt(i);
        }
        LiqLib.PartialJoinArgs memory a;
        a.weights = l.weights;
        a.invScales = l.invScales;
        a.natives = natives;
        a.invIn = invIn;
        a.pairAmounts = pairAmounts;
        a.ses = l.standardExchanges;
        a.supply = supply;
        LiqLib.PartialJoinResult memory r = LiqLib.partialJoin(a);
        shares = r.shares;
        usedPair = r.usedPair;
    }

    function _commitJoin(uint256[] memory pairUsed, address to, uint256 shares, bool firstMint)
        internal
    {
        _pullAmounts(pairUsed);
        _bufferLast(pairUsed);
        if (firstMint) {
            _mintLp(address(0), Math.MINIMUM_LIQUIDITY);
        }
        _mintLp(to, shares);
        _snapshotKLastIfFeeOn();
        _refundBufferedDust();
        _syncVaultReserves();
        int256[] memory deltas = new int256[](pairUsed.length);
        for (uint256 i; i < pairUsed.length; ++i) {
            deltas[i] = int256(pairUsed[i]);
        }
        emit IUniswapV4StandardExchangeWeightedBufferHook.Join(msg.sender, to, shares, deltas, 0);
    }

    function previewJoinUnbalanced(uint256[] calldata amounts) public view returns (uint256 shares) {
        return _quoteUnbalancedJoin(amounts);
    }

    function joinUnbalanced(uint256[] calldata amounts, address to, uint256 sharesMin, uint256 deadline)
        public
        nonReentrant
        returns (uint256 shares)
    {
        _requireDeadline(deadline);
        if (to == address(0)) revert ZeroAddress();
        Repo.Layout storage l = Repo._layout();
        if (amounts.length != l.numTokens) revert InvalidN();
        if (_totalSupply() == 0) {
            if (Math.countPositive(amounts) != l.numTokens) revert NotFullBook();
            _maybeMintProtocolFee();
            (shares,) = _firstMint(_pairToInvPreview(amounts), amounts);
            if (shares < sharesMin) revert Slippage();
            _commitJoin(amounts, to, shares, true);
            return shares;
        }
        if (!Math.isFullBookReserves(_nativeAll())) revert NotFullBook();
        _maybeMintProtocolFee();
        shares = _quoteUnbalancedJoin(amounts);
        if (shares < sharesMin) revert Slippage();
        _commitJoin(amounts, to, shares, false);
    }

    function _quoteUnbalancedJoin(uint256[] memory pairAmounts) internal view returns (uint256 shares) {
        // Taxable join uses usageFee channel for growth; swap fee on unbalanced per monomorph uses dexSwapFee
        uint256 feeWad = _feeOracle().dexSwapFeeOfVault(address(this));
        if (feeWad >= Math.WAD) revert InvalidFeeWad();
        uint256[] memory invIn = _pairToInvPreview(pairAmounts);
        shares = Math.unbalancedJoinShares(
            _invWadAll(), _scaleInvAmounts(invIn), Repo._layout().weights, _totalSupply(), feeWad
        );
    }

    function previewJoinSingleAssetExactIn(address tokenIn, uint256 amountIn)
        public
        view
        returns (uint256 shares)
    {
        return _quoteSingleJoinExactIn(tokenIn, amountIn);
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
        _maybeMintProtocolFee();
        shares = _quoteSingleJoinExactIn(tokenIn, amountIn);
        if (shares < sharesMin) revert Slippage();
        uint8 idx = _tokenIndex(tokenIn);
        uint256[] memory used = new uint256[](Repo._layout().numTokens);
        used[idx] = amountIn;
        _commitJoin(used, to, shares, false);
        emit IUniswapV4StandardExchangeWeightedBufferHook.DepositSingle(msg.sender, to, tokenIn, amountIn, shares, 0);
    }

    function previewDepositSingle(address tokenIn, uint256 amountIn)
        public
        view
        returns (uint256 shares)
    {
        return previewJoinSingleAssetExactIn(tokenIn, amountIn);
    }

    function _quoteSingleJoinExactIn(address tokenIn, uint256 amountIn)
        internal
        view
        returns (uint256 shares)
    {
        uint8 idx = _tokenIndex(tokenIn);
        uint256 feeWad = _feeOracle().dexSwapFeeOfVault(address(this));
        if (feeWad >= Math.WAD) revert InvalidFeeWad();
        uint256[] memory pair = new uint256[](Repo._layout().numTokens);
        pair[idx] = amountIn;
        uint256[] memory invIn = _pairToInvPreview(pair);
        shares = Math.singleJoinExactInShares(
            _invWadAll(),
            Repo._layout().weights,
            idx,
            Math.scaleTo(invIn[idx], Repo._layout().invScales[idx]),
            _totalSupply(),
            feeWad
        );
    }

    function previewJoinSingleAssetExactOut(address tokenIn, uint256 sharesOut)
        public
        view
        returns (uint256 amountIn)
    {
        return _quoteSingleJoinExactOut(tokenIn, sharesOut);
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
        _maybeMintProtocolFee();
        amountIn = _quoteSingleJoinExactOut(tokenIn, sharesOut);
        if (amountIn > amountInMax) revert Slippage();
        uint8 idx = _tokenIndex(tokenIn);
        uint256[] memory used = new uint256[](Repo._layout().numTokens);
        used[idx] = amountIn;
        _commitJoin(used, to, sharesOut, false);
    }

    function _quoteSingleJoinExactOut(address tokenIn, uint256 sharesOut)
        internal
        view
        returns (uint256 amountIn)
    {
        uint8 idx = _tokenIndex(tokenIn);
        uint256 feeWad = _feeOracle().dexSwapFeeOfVault(address(this));
        if (feeWad >= Math.WAD) revert InvalidFeeWad();
        Repo.Layout storage l = Repo._layout();
        uint256 aS = Math.singleJoinExactOutAmountIn(
            _invWadAll(), l.weights, idx, sharesOut, _totalSupply(), feeWad
        );
        uint256 invNeeded = Math.descaleUp(aS, l.invScales[idx]);
        if (l.standardExchanges[idx] == address(0)) {
            amountIn = invNeeded;
        } else {
            // Invert buffer: pair such that sharesOut ≈ invNeeded — use linear approx via 1-share preview
            address se = l.standardExchanges[idx];
            address t = l.tokens[idx];
            // binary search forbidden — use SE preview invert via previewExchangeOut if available
            // amountIn pair → shares: use exchangeOut preview for exact shares as amountOut of SE
            // When SE is ERC-4626 wrapper, deposit assets for shares: approximate assets = convertToAssets
            // Use iterative single closed form: previewExchangeIn(pair, X, se) ≈ invNeeded
            // Closed form for 1:1 wrappers: amountIn ≈ invNeeded when no fee; with fee gross-up via usageFee
            uint256 feeSe = _feeOracle().usageFeeOfVault(se);
            if (feeSe >= Math.WAD) feeSe = 0;
            // Try: pairIn = invNeeded if rate 1; adjust with preview
            amountIn = invNeeded;
            uint256 got =
                IStandardExchangeIn(se).previewExchangeIn(IERC20(t), amountIn, IERC20(se));
            if (got < invNeeded && got > 0) {
                amountIn = (invNeeded * amountIn + got - 1) / got;
            }
            if (feeSe != 0) {
                amountIn = Math.grossUpExactOut(amountIn, feeSe);
            }
        }
    }

    function previewExitProportional(uint256 shares)
        public
        view
        returns (uint256[] memory amounts)
    {
        // amounts = pair-token edge
        uint256[] memory natives = _nativeAll();
        uint256[] memory invOut = Math.proportionalExitAmounts(shares, natives, _totalSupply());
        amounts = _invToPairOutPreview(invOut);
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
        _maybeMintProtocolFee();
        Repo.Layout storage l = Repo._layout();
        if (amountsMin.length != l.numTokens) revert InvalidN();
        uint256[] memory natives = _nativeAll();
        uint256[] memory invOut = Math.proportionalExitAmounts(shares, natives, _totalSupply());
        if (Math.isFullBookReserves(natives)) {
            for (uint256 i; i < l.numTokens; ++i) {
                if (invOut[i] >= natives[i]) revert WouldZeroReserve();
            }
        }
        amounts = _invToPairOutPreview(invOut);
        for (uint256 i; i < l.numTokens; ++i) {
            if (amounts[i] < amountsMin[i]) revert Slippage();
        }
        _burnLp(msg.sender, shares);
        for (uint8 i; i < l.numTokens; ++i) {
            if (invOut[i] == 0) continue;
            if (l.standardExchanges[i] != address(0)) {
                _unwrapSeShares(i, invOut[i], to);
            } else {
                l.rawReserves[i] -= invOut[i];
                IERC20(l.tokens[i]).safeTransfer(to, invOut[i]);
            }
        }
        _snapshotKLastIfFeeOn();
        _syncVaultReserves();
        int256[] memory deltas = new int256[](l.numTokens);
        for (uint256 i; i < l.numTokens; ++i) {
            deltas[i] = -int256(amounts[i]);
        }
        emit IUniswapV4StandardExchangeWeightedBufferHook.Exit(msg.sender, to, shares, deltas, 0);
    }

    function _invToPairOutPreview(uint256[] memory invOut)
        internal
        view
        returns (uint256[] memory pairOut)
    {
        Repo.Layout storage l = Repo._layout();
        pairOut = new uint256[](l.numTokens);
        for (uint8 i; i < l.numTokens; ++i) {
            if (invOut[i] == 0) continue;
            address se = l.standardExchanges[i];
            if (se == address(0)) {
                pairOut[i] = invOut[i];
            } else {
                pairOut[i] = IStandardExchangeIn(se).previewExchangeIn(
                    IERC20(se), invOut[i], IERC20(l.tokens[i])
                );
            }
        }
    }

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
        _maybeMintProtocolFee();
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
            l.rawReserves[idx] -= invOut;
            IERC20(tokenOut).safeTransfer(to, invOut);
        }
        for (uint8 i; i < l.numTokens; ++i) {
            if (_nativeAt(i) == 0) revert WouldZeroReserve();
        }
        _snapshotKLastIfFeeOn();
        _syncVaultReserves();
        emit IUniswapV4StandardExchangeWeightedBufferHook.WithdrawSingle(msg.sender, to, tokenOut, amountOut, sharesIn, 0);
    }

    function previewWithdrawSingle(address tokenOut, uint256 sharesIn)
        public
        view
        returns (uint256 amountOut)
    {
        return previewExitSingleAssetExactBptIn(tokenOut, sharesIn);
    }

    function _singleExitInvOut(uint8 idx, uint256 sharesIn) internal view returns (uint256 invOut) {
        uint256 feeWad = _feeOracle().dexSwapFeeOfVault(address(this));
        if (feeWad >= Math.WAD) revert InvalidFeeWad();
        uint256 outS = Math.singleExitExactInAmountOut(
            _invWadAll(), Repo._layout().weights, idx, sharesIn, _totalSupply(), feeWad
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
        uint256[] memory inv = new uint256[](Repo._layout().numTokens);
        inv[idx] = invOut;
        uint256[] memory pair = _invToPairOutPreview(inv);
        amountOut = pair[idx];
    }

    function previewExitSingleAssetExactTokenOut(address tokenOut, uint256 amountOut)
        public
        view
        returns (uint256 sharesIn)
    {
        return _quoteExitSingleExactTokenOut(tokenOut, amountOut);
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
        _maybeMintProtocolFee();
        sharesIn = _quoteExitSingleExactTokenOut(tokenOut, amountOut);
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
            l.rawReserves[idx] -= invOut;
            IERC20(tokenOut).safeTransfer(to, invOut);
        }
        for (uint8 i; i < l.numTokens; ++i) {
            if (_nativeAt(i) == 0) revert WouldZeroReserve();
        }
        _snapshotKLastIfFeeOn();
        _syncVaultReserves();
        emit IUniswapV4StandardExchangeWeightedBufferHook.WithdrawSingleExactOut(msg.sender, to, tokenOut, amountOut, sharesIn, 0);
    }

    function previewWithdrawSingleExactOut(address tokenOut, uint256 amountOut)
        public
        view
        returns (uint256 sharesIn)
    {
        return previewExitSingleAssetExactTokenOut(tokenOut, amountOut);
    }

    function _quoteExitSingleExactTokenOut(address tokenOut, uint256 amountOut)
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
        sharesIn = Math.singleExitExactOutSharesIn(
            _invWadAll(),
            l.weights,
            idx,
            Math.scaleToUp(invOut, l.invScales[idx]),
            _totalSupply(),
            feeWad
        );
    }

    /* ---------------------------------------------------------------------- */
    /*                    B6: flexible SE-share / pair LP                     */
    /* ---------------------------------------------------------------------- */

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

    /// @dev Map user edge amounts → inventory deltas (SE shares or face). SE-share legs pass through.
    function _edgeToInvPreview(uint256[] memory amounts, bool[] memory amountIsSeShare)
        internal
        view
        returns (uint256[] memory invDeltas)
    {
        Repo.Layout storage l = Repo._layout();
        invDeltas = new uint256[](l.numTokens);
        for (uint8 i; i < l.numTokens; ++i) {
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
        Repo.Layout storage l = Repo._layout();
        if (flags.length != l.numTokens) revert ArrayLengthMismatch();
        for (uint8 i; i < l.numTokens; ++i) {
            if (flags[i] && l.standardExchanges[i] == address(0)) revert SeShareNotBuffered();
        }
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

    function previewExitProportionalFlexible(uint256 shares, bool[] calldata receiveSeShare)
        public
        view
        returns (uint256[] memory amounts)
    {
        _validateSeShareFlags(receiveSeShare);
        uint256[] memory natives = _nativeAll();
        uint256[] memory invOut = Math.proportionalExitAmounts(shares, natives, _totalSupply());
        amounts = _invToEdgeOutPreview(invOut, receiveSeShare);
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
        _maybeMintProtocolFee();
        Repo.Layout storage l = Repo._layout();
        if (amountsMin.length != l.numTokens || receiveSeShare.length != l.numTokens) {
            revert ArrayLengthMismatch();
        }
        uint256[] memory natives = _nativeAll();
        uint256[] memory invOut = Math.proportionalExitAmounts(shares, natives, _totalSupply());
        if (Math.isFullBookReserves(natives)) {
            for (uint256 i; i < l.numTokens; ++i) {
                if (invOut[i] >= natives[i]) revert WouldZeroReserve();
            }
        }
        amounts = _invToEdgeOutPreview(invOut, receiveSeShare);
        for (uint256 i; i < l.numTokens; ++i) {
            if (amounts[i] < amountsMin[i]) revert Slippage();
        }
        _burnLp(msg.sender, shares);
        for (uint8 i; i < l.numTokens; ++i) {
            if (invOut[i] == 0) continue;
            if (l.standardExchanges[i] != address(0)) {
                if (receiveSeShare[i]) {
                    IERC20(l.standardExchanges[i]).safeTransfer(to, invOut[i]);
                } else {
                    _unwrapSeShares(i, invOut[i], to);
                }
            } else {
                l.rawReserves[i] -= invOut[i];
                IERC20(l.tokens[i]).safeTransfer(to, invOut[i]);
            }
        }
        _snapshotKLastIfFeeOn();
        _syncVaultReserves();
        emit IUniswapV4StandardExchangeWeightedBufferHook.ExitFlexible(
            msg.sender, to, shares, receiveSeShare, amounts, 0
        );
    }

    function _invToEdgeOutPreview(uint256[] memory invOut, bool[] memory receiveSeShare)
        internal
        view
        returns (uint256[] memory edgeOut)
    {
        Repo.Layout storage l = Repo._layout();
        edgeOut = new uint256[](l.numTokens);
        for (uint8 i; i < l.numTokens; ++i) {
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
        _maybeMintProtocolFee();
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
            l.rawReserves[idx] -= invOut;
            IERC20(tokenOut).safeTransfer(to, invOut);
        }
        for (uint8 i; i < l.numTokens; ++i) {
            if (_nativeAt(i) == 0) revert WouldZeroReserve();
        }
        _snapshotKLastIfFeeOn();
        _syncVaultReserves();
        emit IUniswapV4StandardExchangeWeightedBufferHook.WithdrawSingleFlexible(
            msg.sender, to, tokenOut, amountOut, receiveSeShare, sharesIn, 0
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
