// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

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
import {ISignatureTransfer} from
    "@crane/contracts/interfaces/protocols/utils/permit2/ISignatureTransfer.sol";
import {IAllowanceTransfer} from
    "@crane/contracts/interfaces/protocols/utils/permit2/IAllowanceTransfer.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {
    UniswapV4WeightedSwapHookCommon
} from "contracts/hooks/uniswap/v4/weighted/UniswapV4WeightedSwapHookCommon.sol";
import {
    UniswapV4WeightedSwapHookRepo as Repo
} from "contracts/hooks/uniswap/v4/weighted/UniswapV4WeightedSwapHookRepo.sol";
import {
    UniswapV4WeightedSwapHookMath as Math
} from "contracts/hooks/uniswap/v4/weighted/UniswapV4WeightedSwapHookMath.sol";
import {
    IUniswapV4WeightedSwapHook
} from "contracts/hooks/uniswap/v4/weighted/interfaces/IUniswapV4WeightedSwapHook.sol";

abstract contract UniswapV4WeightedSwapHookLiquidityTarget is UniswapV4WeightedSwapHookCommon {
    function _maybeMintProtocolFee() internal returns (uint256 protocolLp) {
        (bool feeOn, address feeTo_, uint256 ownerFeeShare,) = _feeOnAndShare();
        Repo.Layout storage l = Repo._layout();
        if (!feeOn || l.kLast == 0) return 0;

        uint256[] memory rates = _loadRates();
        (uint8 mode,, uint256 rootK) = _measureK(rates);
        if (mode != l.kLastMode) return 0;

        // rootKLast = stored k (rootK = V or interim k, both stored as k itself)
        protocolLp = Math.protocolLpShares(_totalSupply(), rootK, l.kLast, ownerFeeShare);
        if (protocolLp > 0) {
            _mint(feeTo_, protocolLp);
            emit IUniswapV4WeightedSwapHook.ProtocolFeeMinted(feeTo_, protocolLp);
        }
    }


    function _previewProtocolMintShares()
        internal
        view
        returns (uint256 protocolLp, uint256 supplyAfter)
    {
        Repo.Layout storage l = Repo._layout();
        supplyAfter = _totalSupply();
        (bool feeOn,, uint256 ownerFeeShare,) = _feeOnAndShare();
        if (!feeOn || l.kLast == 0) return (0, supplyAfter);

        uint256[] memory rates = _loadRates();
        (uint8 mode,, uint256 rootK) = _measureK(rates);
        if (mode != l.kLastMode) return (0, supplyAfter);

        protocolLp = Math.protocolLpShares(_totalSupply(), rootK, l.kLast, ownerFeeShare);
        supplyAfter = _totalSupply() + protocolLp;
    }


    function _joinProportional(
        uint256[] memory amounts,
        address to,
        uint256 sharesMin,
        uint256 deadline,
        bytes calldata permit2Data
    ) internal returns (uint256 shares, uint256[] memory used) {
        _requireDeadline(deadline);
        if (to == address(0)) revert ZeroAddress();
        Repo.Layout storage l = Repo._layout();
        if (amounts.length != l.numTokens) revert InvalidN();

        _maybeMintProtocolFee();
        bool first = _totalSupply() == 0;
        (shares, used) = _computeJoinProportional(amounts);
        if (shares < sharesMin) revert Slippage();
        _commitJoin(used, to, shares, permit2Data, first);
    }


    function _computeJoinProportional(uint256[] memory amounts)
        internal
        view
        returns (uint256 shares, uint256[] memory used)
    {
        Repo.Layout storage l = Repo._layout();
        uint256 supply = _totalSupply();
        uint256[] memory rates = _loadRates();
        if (supply == 0) {
            return _firstMint(amounts, rates);
        }
        if (Math.isFullBookReserves(l.reserves)) {
            return _fullPropJoin(amounts, rates, supply);
        }
        return _partialJoin(amounts, rates, supply);
    }


    function _firstMint(uint256[] memory amounts, uint256[] memory rates)
        internal
        view
        returns (uint256 shares, uint256[] memory used)
    {
        Repo.Layout storage l = Repo._layout();
        uint256 n = l.numTokens;
        used = amounts;
        uint256 pos = Math.countPositive(amounts);
        if (n == 2) {
            // n==2: both legs required
            if (pos != 2) revert ZeroAmount();
        } else {
            if (pos < 2) revert ZeroAmount();
        }
        uint256[] memory scaled = _scaleAmounts(amounts, rates);
        if (pos == n) {
            // full first mint O2
            for (uint256 i; i < n; ++i) {
                if (amounts[i] == 0) revert ZeroAmount();
            }
            (shares,) = Math.firstMintSharesFull(l.weights, scaled);
        } else {
            // partial first mint O4 (n>=3)
            (shares,) = Math.firstMintSharesPartial(l.weights, scaled);
        }
    }


    function _fullPropJoin(uint256[] memory amounts, uint256[] memory rates, uint256 supply)
        internal
        view
        returns (uint256 shares, uint256[] memory used)
    {
        Repo.Layout storage l = Repo._layout();
        uint256 n = l.numTokens;
        for (uint256 i; i < n; ++i) {
            if (amounts[i] == 0) revert ZeroAmount();
        }
        uint256[] memory aS = _scaleAmounts(amounts, rates);
        uint256[] memory rS = _scaleReserves(rates);
        shares = Math.proportionalJoinShares(aS, rS, supply);
        used = new uint256[](n);
        for (uint256 i; i < n; ++i) {
            uint256 usedS = Math.proportionalUsedScaled(shares, rS[i], supply);
            used[i] = Math.descale(usedS, rates[i]);
            if (used[i] == 0 || used[i] > amounts[i]) revert Slippage();
        }
    }


    function _partialJoin(uint256[] memory amounts, uint256[] memory rates, uint256 supply)
        internal
        view
        returns (uint256 shares, uint256[] memory used)
    {
        Repo.Layout storage l = Repo._layout();
        uint256 n = l.numTokens;
        used = new uint256[](n);

        // working balances for k
        uint256[] memory working = new uint256[](n);
        for (uint256 i; i < n; ++i) {
            working[i] = Math.scaleTo(l.reserves[i], rates[i]);
        }
        uint256 kBefore = Math.computeInterimK(l.weights, working);

        bool anySeed;
        bool anyProp;
        // seed zeros fully
        for (uint256 i; i < n; ++i) {
            if (l.reserves[i] == 0 && amounts[i] > 0) {
                used[i] = amounts[i];
                working[i] = Math.scaleTo(amounts[i], rates[i]);
                anySeed = true;
            }
        }
        // prop on positive reserve legs
        uint256 minShares = type(uint256).max;
        for (uint256 i; i < n; ++i) {
            if (l.reserves[i] > 0 && amounts[i] > 0) {
                uint256 aS = Math.scaleTo(amounts[i], rates[i]);
                uint256 rS = Math.scaleTo(l.reserves[i], rates[i]);
                uint256 s = (aS * supply) / rS;
                if (s < minShares) minShares = s;
                anyProp = true;
            }
        }
        if (anyProp) {
            if (minShares == 0 || minShares == type(uint256).max) revert ZeroAmount();
            for (uint256 i; i < n; ++i) {
                if (l.reserves[i] > 0 && amounts[i] > 0) {
                    uint256 rS = Math.scaleTo(l.reserves[i], rates[i]);
                    uint256 usedS = Math.proportionalUsedScaled(minShares, rS, supply);
                    used[i] = Math.descale(usedS, rates[i]);
                    if (used[i] == 0) revert ZeroAmount();
                    working[i] = rS + usedS;
                }
            }
        }

        if (!anySeed && !anyProp) revert ZeroAmount();

        // Pure prop (no seed): Uni V2 min-ratio on positive legs.
        // Seed involved: prefer interim-k growth; if k does not rise (renorm discontinuity
        // when completing a leg), fall back to weight·balance NAV of seeds vs book.
        if (anySeed) {
            uint256 kAfter = Math.computeInterimK(l.weights, working);
            if (kAfter > kBefore) {
                shares = Math.partialJoinSharesFromK(supply, kBefore, kAfter);
            } else {
                shares = _seedNavShares(used, rates, supply);
            }
        } else {
            shares = minShares;
        }
    }


    function _joinUnbalanced(
        uint256[] memory amounts,
        address to,
        uint256 sharesMin,
        uint256 deadline,
        bytes calldata permit2Data
    ) internal returns (uint256 shares) {
        _requireDeadline(deadline);
        if (to == address(0)) revert ZeroAddress();
        Repo.Layout storage l = Repo._layout();
        if (amounts.length != l.numTokens) revert InvalidN();
        if (_totalSupply() == 0) {
            return _joinUnbalancedFirst(amounts, to, sharesMin, permit2Data);
        }
        if (!Math.isFullBookReserves(l.reserves)) revert NotFullBook();
        _maybeMintProtocolFee();
        shares = _quoteUnbalancedJoin(amounts);
        if (shares < sharesMin) revert Slippage();
        _commitJoin(amounts, to, shares, permit2Data, false);
    }


    function _joinUnbalancedFirst(
        uint256[] memory amounts,
        address to,
        uint256 sharesMin,
        bytes calldata permit2Data
    ) private returns (uint256 shares) {
        if (Math.countPositive(amounts) != Repo._layout().numTokens) revert NotFullBook();
        (shares,) = _firstMint(amounts, _loadRates());
        if (shares < sharesMin) revert Slippage();
        _commitJoin(amounts, to, shares, permit2Data, true);
    }


    function _quoteUnbalancedJoin(uint256[] memory amounts) internal view returns (uint256 shares) {
        Repo.Layout storage l = Repo._layout();
        uint256 feeWad = feeOracle().dexSwapFeeOfVault(address(this));
        if (feeWad >= Math.WAD) revert InvalidFeeWad();
        uint256[] memory rates = _loadRates();
        shares = Math.unbalancedJoinShares(
            _scaleReserves(rates), _scaleAmounts(amounts, rates), l.weights, _totalSupply(), feeWad
        );
    }


    function _commitJoin(
        uint256[] memory amounts,
        address to,
        uint256 shares,
        bytes calldata permit2Data,
        bool firstMint
    ) private {
        Repo.Layout storage l = Repo._layout();
        _pullAmounts(amounts, permit2Data);
        for (uint256 i; i < l.numTokens; ++i) {
            l.reserves[i] += amounts[i];
        }
        if (firstMint) {
            _mint(address(0), Math.MINIMUM_LIQUIDITY);
        }
        _mint(to, shares);
        _syncVaultReserves();
        _snapshotKLastIfFeeOn();
        emit IUniswapV4WeightedSwapHook.LiquidityJoined(msg.sender, to, shares, amounts);
    }


    function _joinSingleExactIn(
        address tokenIn,
        uint256 amountIn,
        address to,
        uint256 sharesMin,
        uint256 deadline,
        bytes calldata permit2Data
    ) internal returns (uint256 shares) {
        _requireDeadline(deadline);
        if (to == address(0)) revert ZeroAddress();
        if (amountIn == 0) revert ZeroAmount();
        Repo.Layout storage l = Repo._layout();
        if (_totalSupply() == 0 || !Math.isFullBookReserves(l.reserves)) revert NotFullBook();

        _maybeMintProtocolFee();
        shares = _quoteSingleJoinExactIn(tokenIn, amountIn);
        if (shares < sharesMin) revert Slippage();

        uint256 idx = _tokenIndex(tokenIn);
        uint256[] memory used = new uint256[](l.numTokens);
        used[idx] = amountIn;
        _pullAmounts(used, permit2Data);
        l.reserves[idx] += amountIn;
        _mint(to, shares);
        _syncVaultReserves();
        _snapshotKLastIfFeeOn();
        emit IUniswapV4WeightedSwapHook.LiquidityJoined(msg.sender, to, shares, used);
    }


    function _quoteSingleJoinExactIn(address tokenIn, uint256 amountIn)
        internal
        view
        returns (uint256 shares)
    {
        Repo.Layout storage l = Repo._layout();
        uint256 idx = _tokenIndex(tokenIn);
        uint256 feeWad = feeOracle().dexSwapFeeOfVault(address(this));
        if (feeWad >= Math.WAD) revert InvalidFeeWad();
        uint256[] memory rates = _loadRates();
        shares = Math.singleJoinExactInShares(
            _scaleReserves(rates),
            l.weights,
            idx,
            Math.scaleTo(amountIn, rates[idx]),
            _totalSupply(),
            feeWad
        );
    }


    function _joinSingleExactOut(
        address tokenIn,
        uint256 sharesOut,
        address to,
        uint256 amountInMax,
        uint256 deadline,
        bytes calldata permit2Data
    ) internal returns (uint256 amountIn) {
        _requireDeadline(deadline);
        if (to == address(0)) revert ZeroAddress();
        if (sharesOut == 0) revert ZeroAmount();
        Repo.Layout storage l = Repo._layout();
        if (_totalSupply() == 0 || !Math.isFullBookReserves(l.reserves)) revert NotFullBook();

        _maybeMintProtocolFee();
        amountIn = _quoteSingleJoinExactOut(tokenIn, sharesOut);
        if (amountIn > amountInMax) revert Slippage();

        uint256 idx = _tokenIndex(tokenIn);
        uint256[] memory used = new uint256[](l.numTokens);
        used[idx] = amountIn;
        _pullAmounts(used, permit2Data);
        l.reserves[idx] += amountIn;
        _mint(to, sharesOut);
        _syncVaultReserves();
        _snapshotKLastIfFeeOn();
        emit IUniswapV4WeightedSwapHook.LiquidityJoined(msg.sender, to, sharesOut, used);
    }


    function _quoteSingleJoinExactOut(address tokenIn, uint256 sharesOut)
        internal
        view
        returns (uint256 amountIn)
    {
        Repo.Layout storage l = Repo._layout();
        uint256 idx = _tokenIndex(tokenIn);
        uint256 feeWad = feeOracle().dexSwapFeeOfVault(address(this));
        if (feeWad >= Math.WAD) revert InvalidFeeWad();
        uint256[] memory rates = _loadRates();
        uint256 aS = Math.singleJoinExactOutAmountIn(
            _scaleReserves(rates), l.weights, idx, sharesOut, _totalSupply(), feeWad
        );
        amountIn = Math.descaleUp(aS, rates[idx]);
    }


    function _exitProportional(
        uint256 shares,
        address to,
        uint256[] memory amountsMin,
        uint256 deadline
    ) internal returns (uint256[] memory amounts) {
        _requireDeadline(deadline);
        if (to == address(0)) revert ZeroAddress();
        if (shares == 0) revert ZeroAmount();

        _maybeMintProtocolFee();
        Repo.Layout storage l = Repo._layout();
        if (amountsMin.length != l.numTokens) revert InvalidN();
        uint256 supply = _totalSupply();
        amounts = Math.proportionalExitAmounts(shares, l.reserves, supply);
        for (uint256 i; i < l.numTokens; ++i) {
            if (amounts[i] < amountsMin[i]) revert Slippage();
        }

        // D67 full book: no leg zeroing
        if (Math.isFullBookReserves(l.reserves)) {
            for (uint256 i; i < l.numTokens; ++i) {
                if (amounts[i] >= l.reserves[i]) revert WouldZeroReserve();
            }
        }

        _burn(msg.sender, shares);
        for (uint256 i; i < l.numTokens; ++i) {
            l.reserves[i] -= amounts[i];
            _push(l.tokens[i], to, amounts[i]);
        }
        _syncVaultReserves();
        // partial exit: require at least one positive if supply remains
        if (_totalSupply() > Math.MINIMUM_LIQUIDITY) {
            bool any;
            for (uint256 i; i < l.numTokens; ++i) {
                if (l.reserves[i] > 0) {
                    any = true;
                    break;
                }
            }
            if (!any) revert WouldZeroReserve();
        }
        _snapshotKLastIfFeeOn();
        emit IUniswapV4WeightedSwapHook.LiquidityExited(msg.sender, to, shares, amounts);
    }


    function _exitSingleExactIn(
        address tokenOut,
        uint256 sharesIn,
        address to,
        uint256 amountOutMin,
        uint256 deadline
    ) internal returns (uint256 amountOut) {
        _requireDeadline(deadline);
        if (to == address(0)) revert ZeroAddress();
        if (sharesIn == 0) revert ZeroAmount();
        Repo.Layout storage l = Repo._layout();
        if (!Math.isFullBookReserves(l.reserves)) revert NotFullBook();

        _maybeMintProtocolFee();
        amountOut = _quoteExitSingleExactIn(tokenOut, sharesIn);
        if (amountOut < amountOutMin) revert Slippage();
        uint256 idx = _tokenIndex(tokenOut);
        if (amountOut >= l.reserves[idx]) revert WouldZeroReserve();

        _burn(msg.sender, sharesIn);
        l.reserves[idx] -= amountOut;
        for (uint256 i; i < l.numTokens; ++i) {
            if (l.reserves[i] == 0) revert WouldZeroReserve();
        }
        _push(tokenOut, to, amountOut);
        _syncVaultReserves();
        _snapshotKLastIfFeeOn();
        uint256[] memory amts = new uint256[](l.numTokens);
        amts[idx] = amountOut;
        emit IUniswapV4WeightedSwapHook.LiquidityExited(msg.sender, to, sharesIn, amts);
    }


    function _quoteExitSingleExactIn(address tokenOut, uint256 sharesIn)
        internal
        view
        returns (uint256 amountOut)
    {
        Repo.Layout storage l = Repo._layout();
        uint256 idx = _tokenIndex(tokenOut);
        uint256 feeWad = feeOracle().dexSwapFeeOfVault(address(this));
        if (feeWad >= Math.WAD) revert InvalidFeeWad();
        uint256[] memory rates = _loadRates();
        uint256 outS = Math.singleExitExactInAmountOut(
            _scaleReserves(rates), l.weights, idx, sharesIn, _totalSupply(), feeWad
        );
        amountOut = Math.descale(outS, rates[idx]);
    }


    function _exitSingleExactOut(
        address tokenOut,
        uint256 amountOut,
        address to,
        uint256 sharesInMax,
        uint256 deadline
    ) internal returns (uint256 sharesIn) {
        _requireDeadline(deadline);
        if (to == address(0)) revert ZeroAddress();
        if (amountOut == 0) revert ZeroAmount();
        Repo.Layout storage l = Repo._layout();
        if (!Math.isFullBookReserves(l.reserves)) revert NotFullBook();

        _maybeMintProtocolFee();
        sharesIn = _quoteExitSingleExactOut(tokenOut, amountOut);
        if (sharesIn > sharesInMax) revert Slippage();
        uint256 idx = _tokenIndex(tokenOut);
        if (amountOut >= l.reserves[idx]) revert WouldZeroReserve();

        _burn(msg.sender, sharesIn);
        l.reserves[idx] -= amountOut;
        for (uint256 i; i < l.numTokens; ++i) {
            if (l.reserves[i] == 0) revert WouldZeroReserve();
        }
        _push(tokenOut, to, amountOut);
        _syncVaultReserves();
        _snapshotKLastIfFeeOn();
        uint256[] memory amts = new uint256[](l.numTokens);
        amts[idx] = amountOut;
        emit IUniswapV4WeightedSwapHook.LiquidityExited(msg.sender, to, sharesIn, amts);
    }


    function _quoteExitSingleExactOut(address tokenOut, uint256 amountOut)
        internal
        view
        returns (uint256 sharesIn)
    {
        Repo.Layout storage l = Repo._layout();
        uint256 idx = _tokenIndex(tokenOut);
        uint256 feeWad = feeOracle().dexSwapFeeOfVault(address(this));
        if (feeWad >= Math.WAD) revert InvalidFeeWad();
        uint256[] memory rates = _loadRates();
        sharesIn = Math.singleExitExactOutSharesIn(
            _scaleReserves(rates),
            l.weights,
            idx,
            Math.scaleToUp(amountOut, rates[idx]),
            _totalSupply(),
            feeWad
        );
    }


    function _previewJoinProportional(uint256[] memory amounts)
        internal
        view
        returns (uint256 shares, uint256[] memory used)
    {
        Repo.Layout storage l = Repo._layout();
        if (amounts.length != l.numTokens) revert InvalidN();
        (, uint256 supplyAfter) = _previewProtocolMintShares();
        uint256[] memory rates = _loadRates();
        if (_totalSupply() == 0) {
            return _firstMint(amounts, rates);
        }
        if (Math.isFullBookReserves(l.reserves)) {
            return _fullPropJoin(amounts, rates, supplyAfter);
        }
        return _partialJoin(amounts, rates, supplyAfter);
    }


    function _previewJoinUnbalanced(uint256[] memory amounts) internal view returns (uint256 shares) {
        Repo.Layout storage l = Repo._layout();
        if (amounts.length != l.numTokens) revert InvalidN();
        if (_totalSupply() == 0) {
            uint256[] memory rates0 = _loadRates();
            (shares,) = _firstMint(amounts, rates0);
            return shares;
        }
        if (!Math.isFullBookReserves(l.reserves)) revert NotFullBook();
        (, uint256 supplyAfter) = _previewProtocolMintShares();
        uint256[] memory rates = _loadRates();
        uint256 feeWad = feeOracle().dexSwapFeeOfVault(address(this));
        if (feeWad >= Math.WAD) revert InvalidFeeWad();
        uint256[] memory rS = _scaleReserves(rates);
        uint256[] memory aS = _scaleAmounts(amounts, rates);
        shares = Math.unbalancedJoinShares(rS, aS, l.weights, supplyAfter, feeWad);
    }


    function _previewJoinSingleExactIn(address tokenIn, uint256 amountIn)
        internal
        view
        returns (uint256 shares)
    {
        Repo.Layout storage l = Repo._layout();
        if (_totalSupply() == 0 || !Math.isFullBookReserves(l.reserves)) revert NotFullBook();
        if (amountIn == 0) revert ZeroAmount();
        // growth-aware: use post-protocol supply via temporary math with supplyAfter
        (uint256 protocolLp, uint256 supplyAfter) = _previewProtocolMintShares();
        protocolLp;
        uint256 idx = _tokenIndex(tokenIn);
        uint256 feeWad = feeOracle().dexSwapFeeOfVault(address(this));
        if (feeWad >= Math.WAD) revert InvalidFeeWad();
        uint256[] memory rates = _loadRates();
        shares = Math.singleJoinExactInShares(
            _scaleReserves(rates),
            l.weights,
            idx,
            Math.scaleTo(amountIn, rates[idx]),
            supplyAfter,
            feeWad
        );
    }


    function _previewJoinSingleExactOut(address tokenIn, uint256 sharesOut)
        internal
        view
        returns (uint256 amountIn)
    {
        Repo.Layout storage l = Repo._layout();
        if (_totalSupply() == 0 || !Math.isFullBookReserves(l.reserves)) revert NotFullBook();
        if (sharesOut == 0) revert ZeroAmount();
        (, uint256 supplyAfter) = _previewProtocolMintShares();
        uint256 idx = _tokenIndex(tokenIn);
        uint256 feeWad = feeOracle().dexSwapFeeOfVault(address(this));
        if (feeWad >= Math.WAD) revert InvalidFeeWad();
        uint256[] memory rates = _loadRates();
        uint256 aS = Math.singleJoinExactOutAmountIn(
            _scaleReserves(rates), l.weights, idx, sharesOut, supplyAfter, feeWad
        );
        amountIn = Math.descaleUp(aS, rates[idx]);
    }


    function _previewExitProportional(uint256 shares)
        internal
        view
        returns (uint256[] memory amounts)
    {
        if (shares == 0) revert ZeroAmount();
        (, uint256 supplyAfter) = _previewProtocolMintShares();
        Repo.Layout storage l = Repo._layout();
        amounts = Math.proportionalExitAmounts(shares, l.reserves, supplyAfter);
    }


    function _previewExitSingleExactIn(address tokenOut, uint256 sharesIn)
        internal
        view
        returns (uint256 amountOut)
    {
        Repo.Layout storage l = Repo._layout();
        if (!Math.isFullBookReserves(l.reserves)) revert NotFullBook();
        if (sharesIn == 0) revert ZeroAmount();
        (, uint256 supplyAfter) = _previewProtocolMintShares();
        uint256 idx = _tokenIndex(tokenOut);
        uint256 feeWad = feeOracle().dexSwapFeeOfVault(address(this));
        if (feeWad >= Math.WAD) revert InvalidFeeWad();
        uint256[] memory rates = _loadRates();
        uint256 outS = Math.singleExitExactInAmountOut(
            _scaleReserves(rates), l.weights, idx, sharesIn, supplyAfter, feeWad
        );
        amountOut = Math.descale(outS, rates[idx]);
    }


    function _previewExitSingleExactOut(address tokenOut, uint256 amountOut)
        internal
        view
        returns (uint256 sharesIn)
    {
        Repo.Layout storage l = Repo._layout();
        if (!Math.isFullBookReserves(l.reserves)) revert NotFullBook();
        if (amountOut == 0) revert ZeroAmount();
        (, uint256 supplyAfter) = _previewProtocolMintShares();
        uint256 idx = _tokenIndex(tokenOut);
        uint256 feeWad = feeOracle().dexSwapFeeOfVault(address(this));
        if (feeWad >= Math.WAD) revert InvalidFeeWad();
        uint256[] memory rates = _loadRates();
        sharesIn = Math.singleExitExactOutSharesIn(
            _scaleReserves(rates),
            l.weights,
            idx,
            Math.scaleToUp(amountOut, rates[idx]),
            supplyAfter,
            feeWad
        );
    }


    function _pullAmounts(uint256[] memory used, bytes calldata permit2Data) internal {
        Repo.Layout storage l = Repo._layout();
        if (permit2Data.length == 0) {
            for (uint256 i; i < l.numTokens; ++i) {
                if (used[i] > 0) _pull(l.tokens[i], used[i]);
            }
            return;
        }

        uint8 mode;
        if (permit2Data.length >= 32) {
            mode = abi.decode(permit2Data[:32], (uint8));
        } else {
            mode = uint8(permit2Data[0]);
        }

        if (mode == 0) {
            (, ISignatureTransfer.PermitBatchTransferFrom memory permit, bytes memory signature) =
                abi.decode(permit2Data, (uint8, ISignatureTransfer.PermitBatchTransferFrom, bytes));
            _pullSignatureBatch(used, permit, signature);
        } else if (mode == 1) {
            for (uint256 i; i < l.numTokens; ++i) {
                if (used[i] > 0) {
                    IAllowanceTransfer(PERMIT2).transferFrom(
                        msg.sender, address(this), uint160(used[i]), l.tokens[i]
                    );
                }
            }
        } else {
            revert InvalidPermit2Data();
        }
    }


    function _pullSignatureBatch(
        uint256[] memory used,
        ISignatureTransfer.PermitBatchTransferFrom memory permit,
        bytes memory signature
    ) internal {
        Repo.Layout storage l = Repo._layout();
        uint256 n;
        for (uint256 i; i < l.numTokens; ++i) {
            if (used[i] > 0) ++n;
        }
        if (permit.permitted.length != n) revert InvalidPermit2Data();

        ISignatureTransfer.SignatureTransferDetails[] memory details =
            new ISignatureTransfer.SignatureTransferDetails[](n);
        uint256 k;
        for (uint256 i; i < l.numTokens; ++i) {
            if (used[i] == 0) continue;
            if (permit.permitted[k].token != l.tokens[i]) revert InvalidPermit2Data();
            details[k] = ISignatureTransfer.SignatureTransferDetails({
                to: address(this),
                requestedAmount: used[i]
            });
            ++k;
        }
        ISignatureTransfer(PERMIT2).permitTransferFrom(permit, details, msg.sender, signature);
    }


    function previewJoinProportional(uint256[] calldata amounts)
        external
        view
        returns (uint256 shares, uint256[] memory usedAmounts)
    {
        return _previewJoinProportional(amounts);
    }


    function previewJoinSingleAssetExactIn(address tokenIn, uint256 amountIn)
        external
        view
        returns (uint256)
    {
        return _previewJoinSingleExactIn(tokenIn, amountIn);
    }


    function previewJoinSingleAssetExactOut(address tokenIn, uint256 sharesOut)
        external
        view
        returns (uint256)
    {
        return _previewJoinSingleExactOut(tokenIn, sharesOut);
    }


    function previewJoinUnbalanced(uint256[] calldata amounts) external view returns (uint256) {
        return _previewJoinUnbalanced(amounts);
    }


    function previewExitProportional(uint256 shares) external view returns (uint256[] memory) {
        return _previewExitProportional(shares);
    }


    function previewExitSingleAssetExactIn(address tokenOut, uint256 sharesIn)
        external
        view
        returns (uint256)
    {
        return _previewExitSingleExactIn(tokenOut, sharesIn);
    }


    function previewExitSingleAssetExactOut(address tokenOut, uint256 amountOut)
        external
        view
        returns (uint256)
    {
        return _previewExitSingleExactOut(tokenOut, amountOut);
    }


    function joinProportional(
        uint256[] calldata amounts,
        address to,
        uint256 sharesMin,
        uint256 deadline,
        bytes calldata permit2Data
    ) external nonReentrant returns (uint256 shares, uint256[] memory usedAmounts) {
        return _joinProportional(amounts, to, sharesMin, deadline, permit2Data);
    }


    function joinSingleAssetExactIn(
        address tokenIn,
        uint256 amountIn,
        address to,
        uint256 sharesMin,
        uint256 deadline,
        bytes calldata permit2Data
    ) external nonReentrant returns (uint256 shares) {
        return _joinSingleExactIn(tokenIn, amountIn, to, sharesMin, deadline, permit2Data);
    }


    function joinSingleAssetExactOut(
        address tokenIn,
        uint256 sharesOut,
        address to,
        uint256 amountInMax,
        uint256 deadline,
        bytes calldata permit2Data
    ) external nonReentrant returns (uint256 amountIn) {
        return _joinSingleExactOut(tokenIn, sharesOut, to, amountInMax, deadline, permit2Data);
    }


    function joinUnbalanced(
        uint256[] calldata amounts,
        address to,
        uint256 sharesMin,
        uint256 deadline,
        bytes calldata permit2Data
    ) external nonReentrant returns (uint256 shares) {
        return _joinUnbalanced(amounts, to, sharesMin, deadline, permit2Data);
    }


    function exitProportional(
        uint256 shares,
        address to,
        uint256[] calldata amountsMin,
        uint256 deadline
    ) external nonReentrant returns (uint256[] memory amounts) {
        return _exitProportional(shares, to, amountsMin, deadline);
    }


    function exitSingleAssetExactIn(
        address tokenOut,
        uint256 sharesIn,
        address to,
        uint256 amountOutMin,
        uint256 deadline
    ) external nonReentrant returns (uint256 amountOut) {
        return _exitSingleExactIn(tokenOut, sharesIn, to, amountOutMin, deadline);
    }


    function exitSingleAssetExactOut(
        address tokenOut,
        uint256 amountOut,
        address to,
        uint256 sharesInMax,
        uint256 deadline
    ) external nonReentrant returns (uint256 sharesIn) {
        return _exitSingleExactOut(tokenOut, amountOut, to, sharesInMax, deadline);
    }



}
