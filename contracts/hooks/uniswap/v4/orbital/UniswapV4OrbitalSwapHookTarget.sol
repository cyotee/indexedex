// SPDX-License-Identifier: BUSL-1.1
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
import {LPFeeLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LPFeeLibrary.sol";
import {ModifyLiquidityParams, SwapParams} from
    "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {BalanceDelta} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {
    ISignatureTransfer
} from "@crane/contracts/interfaces/protocols/utils/permit2/ISignatureTransfer.sol";
import {
    IAllowanceTransfer
} from "@crane/contracts/interfaces/protocols/utils/permit2/IAllowanceTransfer.sol";
import {
    UniswapV4OrbitalSwapHookCommon
} from "contracts/hooks/uniswap/v4/orbital/UniswapV4OrbitalSwapHookCommon.sol";
import {
    UniswapV4OrbitalSwapHookRepo as Repo
} from "contracts/hooks/uniswap/v4/orbital/UniswapV4OrbitalSwapHookRepo.sol";
import {
    UniswapV4OrbitalSwapHookMath as Math
} from "contracts/hooks/uniswap/v4/orbital/UniswapV4OrbitalSwapHookMath.sol";

/**
 * @title UniswapV4OrbitalSwapHookTarget
 * @notice IHooks + LP execute + sphere swap settle (PRD §4.3–§4.6).
 */
abstract contract UniswapV4OrbitalSwapHookTarget is UniswapV4OrbitalSwapHookCommon, IHooks {
    using SafeERC20 for IERC20;
    using LPFeeLibrary for uint24;

    constructor(
        IPoolManager poolManager_,
        IVaultFeeOracleQuery feeOracle_,
        address token0_,
        address token1_,
        address token2_
    ) UniswapV4OrbitalSwapHookCommon(poolManager_, feeOracle_, token0_, token1_, token2_) {}

    function getHookPermissions() public pure returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: true,
            afterInitialize: false,
            beforeAddLiquidity: true,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: true,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: false,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: true,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    /* ---------------------------------------------------------------------- */
    /*                                  IHooks                                */
    /* ---------------------------------------------------------------------- */

    function beforeInitialize(address, PoolKey calldata poolKey, uint160)
        external
        view
        override
        returns (bytes4)
    {
        _onlyPoolManager();
        address a = Currency.unwrap(poolKey.currency0);
        address b = Currency.unwrap(poolKey.currency1);
        if (!_isBound(a) || !_isBound(b) || a == b) revert InvalidPoolToken();
        if (poolKey.fee != LPFeeLibrary.DYNAMIC_FEE_FLAG) revert InvalidPoolFee();
        return IHooks.beforeInitialize.selector;
    }

    function afterInitialize(address, PoolKey calldata, uint160, int24)
        external
        pure
        override
        returns (bytes4)
    {
        revert HookNotImplemented();
    }

    function beforeAddLiquidity(address, PoolKey calldata, ModifyLiquidityParams calldata, bytes calldata)
        external
        view
        override
        returns (bytes4)
    {
        _onlyPoolManager();
        revert LiquidityNotAllowed();
    }

    function afterAddLiquidity(
        address,
        PoolKey calldata,
        ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) external pure override returns (bytes4, BalanceDelta) {
        revert HookNotImplemented();
    }

    function beforeRemoveLiquidity(
        address,
        PoolKey calldata,
        ModifyLiquidityParams calldata,
        bytes calldata
    ) external view override returns (bytes4) {
        _onlyPoolManager();
        revert LiquidityNotAllowed();
    }

    function afterRemoveLiquidity(
        address,
        PoolKey calldata,
        ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) external pure override returns (bytes4, BalanceDelta) {
        revert HookNotImplemented();
    }

    function beforeSwap(address, PoolKey calldata key, SwapParams calldata params, bytes calldata)
        external
        override
        returns (bytes4, BeforeSwapDelta swapDelta, uint24)
    {
        _onlyPoolManager();
        _lock();
        address c0 = Currency.unwrap(key.currency0);
        address c1 = Currency.unwrap(key.currency1);
        if (!_isBound(c0) || !_isBound(c1)) {
            _unlock();
            revert InvalidPoolToken();
        }

        address tokenIn = params.zeroForOne ? c0 : c1;
        address tokenOut = params.zeroForOne ? c1 : c0;
        uint256 feeWad = _feeOracle.dexSwapFeeOfVault(address(this));
        if (feeWad >= Math.WAD) {
            _unlock();
            revert Math.MathDomain();
        }

        uint256 amountIn;
        uint256 amountOut;
        if (params.amountSpecified < 0) {
            amountIn = uint256(-params.amountSpecified);
            amountOut = _swapExactInExecute(tokenIn, tokenOut, amountIn, feeWad);
            swapDelta = toBeforeSwapDelta(int128(int256(amountIn)), int128(-int256(amountOut)));
        } else {
            amountOut = uint256(params.amountSpecified);
            amountIn = _swapExactOutExecute(tokenIn, tokenOut, amountOut, feeWad);
            swapDelta = toBeforeSwapDelta(int128(-int256(amountOut)), int128(int256(amountIn)));
        }

        _take(Currency.wrap(tokenIn), address(this), amountIn);
        _settle(Currency.wrap(tokenOut), amountOut);

        emit Swap(tx.origin, tokenIn, tokenOut, amountIn, amountOut, feeWad);
        _unlock();
        return (IHooks.beforeSwap.selector, swapDelta, Math.feeOverridePips(feeWad));
    }

    function afterSwap(address, PoolKey calldata, SwapParams calldata, BalanceDelta, bytes calldata)
        external
        pure
        override
        returns (bytes4, int128)
    {
        revert HookNotImplemented();
    }

    function beforeDonate(address, PoolKey calldata, uint256, uint256, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        revert HookNotImplemented();
    }

    function afterDonate(address, PoolKey calldata, uint256, uint256, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        revert HookNotImplemented();
    }

    /* ---------------------------------------------------------------------- */
    /*                              Swap execute                              */
    /* ---------------------------------------------------------------------- */

    function _swapExactInExecute(address tokenIn, address tokenOut, uint256 amountIn, uint256 feeWad)
        internal
        returns (uint256 amountOut)
    {
        _requireNonZero(amountIn);
        amountOut = _previewSwapExactIn(tokenIn, tokenOut, amountIn);
        // re-read fee path already validated in preview; update reserves with native gross
        Repo.Layout storage l = Repo._layout();
        uint256 rOut = l.reserves[tokenOut];
        if (amountOut == 0 || amountOut >= rOut) revert Math.Drain();
        l.reserves[tokenIn] += amountIn;
        l.reserves[tokenOut] = rOut - amountOut;
        _requirePostUnderRadius();
        _recomputeL2();
        feeWad; // fee applied in preview/quote path; residual stays in input reserve
    }

    function _swapExactOutExecute(address tokenIn, address tokenOut, uint256 amountOut, uint256 feeWad)
        internal
        returns (uint256 amountIn)
    {
        _requireNonZero(amountOut);
        amountIn = _previewSwapExactOut(tokenIn, tokenOut, amountOut);
        Repo.Layout storage l = Repo._layout();
        uint256 rOut = l.reserves[tokenOut];
        if (amountOut >= rOut) revert Math.Drain();
        l.reserves[tokenIn] += amountIn;
        l.reserves[tokenOut] = rOut - amountOut;
        _requirePostUnderRadius();
        _recomputeL2();
        feeWad;
    }

    /* ---------------------------------------------------------------------- */
    /*                              Swap previews                             */
    /* ---------------------------------------------------------------------- */

    function _previewSwapExactIn(address tokenIn, address tokenOut, uint256 amountIn)
        internal
        view
        returns (uint256 amountOut)
    {
        _requireNonZero(amountIn);
        Repo.Layout storage l = Repo._layout();
        if (l.R == 0) revert NotLive();
        uint256 rIn = l.reserves[tokenIn];
        uint256 rOut = l.reserves[tokenOut];
        if (rIn == 0 || rOut == 0) revert NotLive();
        address tokenZ = _witnessAndLegs(tokenIn, tokenOut);
        uint256 feeWad = _feeOracle.dexSwapFeeOfVault(address(this));
        if (feeWad >= Math.WAD) revert Math.MathDomain();
        uint256 dxNet =
            Math.applyTradingFeeNet(_toWad(tokenIn, amountIn), feeWad);
        uint256 dyWad = Math.sphereExactInOutWad(
            l.R,
            l.L_SQUARED,
            _toWad(tokenIn, rIn),
            _toWad(tokenOut, rOut),
            _toWad(tokenZ, l.reserves[tokenZ]),
            dxNet
        );
        amountOut = _fromWadFloor(tokenOut, dyWad);
        if (amountOut == 0 || amountOut >= rOut) revert Math.Drain();
    }

    function _previewSwapExactOut(address tokenIn, address tokenOut, uint256 amountOut)
        internal
        view
        returns (uint256 amountIn)
    {
        _requireNonZero(amountOut);
        Repo.Layout storage l = Repo._layout();
        if (l.R == 0) revert NotLive();
        uint256 rIn = l.reserves[tokenIn];
        uint256 rOut = l.reserves[tokenOut];
        if (rIn == 0 || rOut == 0) revert NotLive();
        if (amountOut >= rOut) revert Math.Drain();
        address tokenZ = _witnessAndLegs(tokenIn, tokenOut);
        uint256 feeWad = _feeOracle.dexSwapFeeOfVault(address(this));
        if (feeWad >= Math.WAD) revert Math.MathDomain();
        uint256 dxNet = Math.sphereExactOutInNetWad(
            l.R,
            l.L_SQUARED,
            _toWad(tokenIn, rIn),
            _toWad(tokenOut, rOut),
            _toWad(tokenZ, l.reserves[tokenZ]),
            _toWad(tokenOut, amountOut)
        );
        amountIn = _fromWadCeil(tokenIn, Math.grossUpExactOut(dxNet, feeWad));
        _requireNonZero(amountIn);
    }

    /* ---------------------------------------------------------------------- */
    /*                           Protocol growth mint                         */
    /* ---------------------------------------------------------------------- */

    function _maybeMintProtocolFee() internal returns (uint256 protocolLp) {
        (bool feeOn, address feeTo_, uint256 ownerFeeShare,) = _feeOnAndShare();
        Repo.Layout storage l = Repo._layout();
        if (!feeOn || l.kLast == 0) return 0;

        (uint256 r0, uint256 r1, uint256 r2) = _reservesWad();
        (uint8 mode, , uint256 rootK) = _measureK(r0, r1, r2);
        if (mode != l.kLastMode) return 0;

        uint256 rootKLast = _rootFromStored(mode, l.kLast);
        protocolLp = Math.protocolLpShares(l.totalSupply, rootK, rootKLast, ownerFeeShare);
        if (protocolLp > 0) {
            _mint(feeTo_, protocolLp);
            emit ProtocolFeeMinted(feeTo_, protocolLp);
        }
    }

    function _snapshotKLastIfFeeOn() internal {
        (bool feeOn,,,) = _feeOnAndShare();
        Repo.Layout storage l = Repo._layout();
        if (!feeOn) {
            l.kLast = 0;
            return;
        }
        (uint256 r0, uint256 r1, uint256 r2) = _reservesWad();
        (uint8 mode, uint256 k,) = _measureK(r0, r1, r2);
        l.kLast = k;
        l.kLastMode = mode;
    }

    /// @dev Simulate protocol mint for preview dilution (D58).
    function _previewProtocolMintShares()
        internal
        view
        returns (uint256 protocolLp, uint256 supplyAfter)
    {
        Repo.Layout storage l = Repo._layout();
        supplyAfter = l.totalSupply;
        (bool feeOn,, uint256 ownerFeeShare,) = _feeOnAndShare();
        if (!feeOn || l.kLast == 0) return (0, supplyAfter);

        (uint256 r0, uint256 r1, uint256 r2) = _reservesWad();
        (uint8 mode,, uint256 rootK) = _measureK(r0, r1, r2);
        if (mode != l.kLastMode) return (0, supplyAfter);

        uint256 rootKLast = _rootFromStored(mode, l.kLast);
        protocolLp = Math.protocolLpShares(l.totalSupply, rootK, rootKLast, ownerFeeShare);
        supplyAfter = l.totalSupply + protocolLp;
    }

    /* ---------------------------------------------------------------------- */
    /*                              Liquidity core                            */
    /* ---------------------------------------------------------------------- */

    function _computeAdd(
        uint256 a0Max,
        uint256 a1Max,
        uint256 a2Max,
        uint256 supply
    )
        internal
        view
        returns (uint256 shares, uint256 used0, uint256 used1, uint256 used2)
    {
        if (supply == 0) {
            return _computeFirstMint(a0Max, a1Max, a2Max);
        }
        Repo.Layout storage l = Repo._layout();
        if (l.reserves[_token0] > 0 && l.reserves[_token1] > 0 && l.reserves[_token2] > 0) {
            return _computeFullBook(a0Max, a1Max, a2Max, supply);
        }
        if (l.R == 0) revert NotLive();
        return _computePartial(a0Max, a1Max, a2Max, supply);
    }

    function _computeFirstMint(uint256 a0Max, uint256 a1Max, uint256 a2Max)
        internal
        view
        returns (uint256 shares, uint256 used0, uint256 used1, uint256 used2)
    {
        uint256 nPos;
        if (a0Max > 0) nPos++;
        if (a1Max > 0) nPos++;
        if (a2Max > 0) nPos++;
        if (nPos < 2) revert FirstMintRequiresTwoLegs();
        used0 = a0Max;
        used1 = a1Max;
        used2 = a2Max;
        shares = Math.firstMintShares(
            _toWad(_token0, used0) + _toWad(_token1, used1) + _toWad(_token2, used2)
        );
    }

    function _computeFullBook(uint256 a0Max, uint256 a1Max, uint256 a2Max, uint256 supply)
        internal
        view
        returns (uint256 shares, uint256 used0, uint256 used1, uint256 used2)
    {
        if (a0Max == 0 || a1Max == 0 || a2Max == 0) revert FullBookRequiresThreeLegs();
        Repo.Layout storage l = Repo._layout();
        shares = Math.fullBookShares(
            _toWad(_token0, a0Max),
            _toWad(_token1, a1Max),
            _toWad(_token2, a2Max),
            _toWad(_token0, l.reserves[_token0]),
            _toWad(_token1, l.reserves[_token1]),
            _toWad(_token2, l.reserves[_token2]),
            supply
        );
        used0 = _fromWadFloor(
            _token0, Math.fullBookUsedWad(shares, _toWad(_token0, l.reserves[_token0]), supply)
        );
        used1 = _fromWadFloor(
            _token1, Math.fullBookUsedWad(shares, _toWad(_token1, l.reserves[_token1]), supply)
        );
        used2 = _fromWadFloor(
            _token2, Math.fullBookUsedWad(shares, _toWad(_token2, l.reserves[_token2]), supply)
        );
        if (used0 == 0 || used1 == 0 || used2 == 0) revert ZeroAmount();
    }

    function _computePartial(uint256 a0Max, uint256 a1Max, uint256 a2Max, uint256 supply)
        internal
        view
        returns (uint256 shares, uint256 used0, uint256 used1, uint256 used2)
    {
        Repo.Layout storage l = Repo._layout();
        (used0, used1, used2) =
            _partialUsed(a0Max, a1Max, a2Max, l.reserves[_token0], l.reserves[_token1], l.reserves[_token2]);
        shares = Math.sphereNavShares(
            supply,
            l.R,
            _toWad(_token0, l.reserves[_token0]),
            _toWad(_token1, l.reserves[_token1]),
            _toWad(_token2, l.reserves[_token2]),
            _toWad(_token0, used0),
            _toWad(_token1, used1),
            _toWad(_token2, used2)
        );
    }

    function _partialUsed(
        uint256 a0Max,
        uint256 a1Max,
        uint256 a2Max,
        uint256 r0,
        uint256 r1,
        uint256 r2
    ) internal view returns (uint256 used0, uint256 used1, uint256 used2) {
        bool anyZ;
        if (r0 == 0 && a0Max > 0) {
            used0 = a0Max;
            anyZ = true;
        }
        if (r1 == 0 && a1Max > 0) {
            used1 = a1Max;
            anyZ = true;
        }
        if (r2 == 0 && a2Max > 0) {
            used2 = a2Max;
            anyZ = true;
        }

        uint256 minShares = _partialMinShares(a0Max, a1Max, a2Max, r0, r1, r2);
        if (minShares == type(uint256).max) {
            if (!anyZ) revert ZeroAmount();
            return (used0, used1, used2);
        }
        if (minShares == 0) revert ZeroAmount();

        uint256 supply = Repo._layout().totalSupply;
        if (r0 > 0 && a0Max > 0) {
            used0 = _legUsed(_token0, r0, minShares, supply);
        }
        if (r1 > 0 && a1Max > 0) {
            used1 = _legUsed(_token1, r1, minShares, supply);
        }
        if (r2 > 0 && a2Max > 0) {
            used2 = _legUsed(_token2, r2, minShares, supply);
        }
    }

    function _partialMinShares(
        uint256 a0Max,
        uint256 a1Max,
        uint256 a2Max,
        uint256 r0,
        uint256 r1,
        uint256 r2
    ) internal view returns (uint256 minShares) {
        minShares = type(uint256).max;
        uint256 supply = Repo._layout().totalSupply;
        if (r0 > 0 && a0Max > 0) {
            minShares = (_toWad(_token0, a0Max) * supply) / _toWad(_token0, r0);
        }
        if (r1 > 0 && a1Max > 0) {
            uint256 s = (_toWad(_token1, a1Max) * supply) / _toWad(_token1, r1);
            if (s < minShares) minShares = s;
        }
        if (r2 > 0 && a2Max > 0) {
            uint256 s = (_toWad(_token2, a2Max) * supply) / _toWad(_token2, r2);
            if (s < minShares) minShares = s;
        }
    }

    function _legUsed(address token, uint256 r, uint256 shares, uint256 supply)
        internal
        view
        returns (uint256 used)
    {
        used = _fromWadFloor(token, Math.fullBookUsedWad(shares, _toWad(token, r), supply));
        if (used == 0) revert ZeroAmount();
    }

    function _addLiquidity(
        uint256 a0Max,
        uint256 a1Max,
        uint256 a2Max,
        address to,
        uint256 sharesMin,
        uint256 deadline,
        bytes calldata permit2Data
    ) internal returns (uint256 shares, uint256 used0, uint256 used1, uint256 used2) {
        _requireDeadline(deadline);
        if (to == address(0)) revert ZeroAddress();

        _maybeMintProtocolFee();
        Repo.Layout storage l = Repo._layout();
        uint256 supply = l.totalSupply;

        (shares, used0, used1, used2) = _computeAdd(a0Max, a1Max, a2Max, supply);
        if (shares < sharesMin) revert InsufficientSharesOut();

        _pullLegs(used0, used1, used2, permit2Data);

        if (supply == 0) {
            uint256 a0W = _toWad(_token0, used0);
            uint256 a1W = _toWad(_token1, used1);
            uint256 a2W = _toWad(_token2, used2);
            l.R = Math.firstMintRadius(a0W, a1W, a2W);
            l.reserves[_token0] = used0;
            l.reserves[_token1] = used1;
            l.reserves[_token2] = used2;
            _mint(address(0), Repo.MINIMUM_LIQUIDITY);
            _mint(to, shares);
            _recomputeL2();
            _snapshotKLastIfFeeOn();
        } else {
            l.reserves[_token0] += used0;
            l.reserves[_token1] += used1;
            l.reserves[_token2] += used2;
            _requirePostUnderRadius();
            _mint(to, shares);
            _recomputeL2();
            _snapshotKLastIfFeeOn();
        }

        emit LiquidityAdded(msg.sender, to, shares, used0, used1, used2);
    }

    function _removeLiquidity(
        uint256 shares,
        address to,
        uint256 a0Min,
        uint256 a1Min,
        uint256 a2Min,
        uint256 deadline
    ) internal returns (uint256 a0, uint256 a1, uint256 a2) {
        _requireDeadline(deadline);
        _requireNonZero(shares);
        if (to == address(0)) revert ZeroAddress();

        _maybeMintProtocolFee();
        Repo.Layout storage l = Repo._layout();
        uint256 supply = l.totalSupply;
        if (shares > l.balanceOf[msg.sender]) revert InsufficientSharesOut();

        a0 = (shares * l.reserves[_token0]) / supply;
        a1 = (shares * l.reserves[_token1]) / supply;
        a2 = (shares * l.reserves[_token2]) / supply;
        // Pro-rata in WAD then floor (D25) — native floor equivalent when uniform
        // Recalc via WAD for correctness with mixed decimals
        a0 = _fromWadFloor(
            _token0, (shares * _toWad(_token0, l.reserves[_token0])) / supply
        );
        a1 = _fromWadFloor(
            _token1, (shares * _toWad(_token1, l.reserves[_token1])) / supply
        );
        a2 = _fromWadFloor(
            _token2, (shares * _toWad(_token2, l.reserves[_token2])) / supply
        );

        if (a0 < a0Min || a1 < a1Min || a2 < a2Min) revert InsufficientTokenOut();

        _burn(msg.sender, shares);
        l.reserves[_token0] -= a0;
        l.reserves[_token1] -= a1;
        l.reserves[_token2] -= a2;
        if (l.R > 0 && l.totalSupply > 0) {
            _recomputeL2();
        } else if (l.totalSupply == 0) {
            l.L_SQUARED = 0;
            // R sticky (D25a)
        } else {
            _recomputeL2();
        }
        _snapshotKLastIfFeeOn();

        if (a0 > 0) IERC20(_token0).safeTransfer(to, a0);
        if (a1 > 0) IERC20(_token1).safeTransfer(to, a1);
        if (a2 > 0) IERC20(_token2).safeTransfer(to, a2);

        emit LiquidityRemoved(msg.sender, to, shares, a0, a1, a2);
    }

    function _previewAddLiquidity(uint256 a0Max, uint256 a1Max, uint256 a2Max)
        internal
        view
        returns (uint256 shares, uint256 a0, uint256 a1, uint256 a2)
    {
        (, uint256 supplyAfter) = _previewProtocolMintShares();
        return _computeAdd(a0Max, a1Max, a2Max, supplyAfter);
    }

    function _previewRemoveLiquidity(uint256 shares_)
        internal
        view
        returns (uint256 a0, uint256 a1, uint256 a2)
    {
        _requireNonZero(shares_);
        (uint256 protocolLp, uint256 supplyAfter) = _previewProtocolMintShares();
        protocolLp;
        Repo.Layout storage l = Repo._layout();
        // After protocol mint, reserves unchanged; supply dilutes
        a0 = _fromWadFloor(
            _token0, (shares_ * _toWad(_token0, l.reserves[_token0])) / supplyAfter
        );
        a1 = _fromWadFloor(
            _token1, (shares_ * _toWad(_token1, l.reserves[_token1])) / supplyAfter
        );
        a2 = _fromWadFloor(
            _token2, (shares_ * _toWad(_token2, l.reserves[_token2])) / supplyAfter
        );
    }

    /* ---------------------------------------------------------------------- */
    /*                              Permit2 / pull                            */
    /* ---------------------------------------------------------------------- */

    function _pullLegs(uint256 u0, uint256 u1, uint256 u2, bytes calldata permit2Data) internal {
        if (permit2Data.length == 0) {
            if (u0 > 0) IERC20(_token0).safeTransferFrom(msg.sender, address(this), u0);
            if (u1 > 0) IERC20(_token1).safeTransferFrom(msg.sender, address(this), u1);
            if (u2 > 0) IERC20(_token2).safeTransferFrom(msg.sender, address(this), u2);
            return;
        }

        uint8 mode = uint8(permit2Data[0]);
        // abi.encode(uint8, ...) packs mode in last byte of first 32-byte word
        // Prefer abi.decode of full payload
        if (permit2Data.length >= 32) {
            mode = abi.decode(permit2Data[:32], (uint8));
        }

        if (mode == 0) {
            (, ISignatureTransfer.PermitBatchTransferFrom memory permit, bytes memory signature) =
                abi.decode(permit2Data, (uint8, ISignatureTransfer.PermitBatchTransferFrom, bytes));
            _pullSignatureBatch(u0, u1, u2, permit, signature);
        } else if (mode == 1) {
            _pullAllowance(u0, u1, u2);
        } else {
            revert InvalidPermit2Data();
        }
    }

    function _pullSignatureBatch(
        uint256 u0,
        uint256 u1,
        uint256 u2,
        ISignatureTransfer.PermitBatchTransferFrom memory permit,
        bytes memory signature
    ) internal {
        uint256 n;
        if (u0 > 0) n++;
        if (u1 > 0) n++;
        if (u2 > 0) n++;
        if (permit.permitted.length != n) revert InvalidPermit2Data();

        ISignatureTransfer.SignatureTransferDetails[] memory details =
            new ISignatureTransfer.SignatureTransferDetails[](n);
        uint256 k;
        address[3] memory tokens = [_token0, _token1, _token2];
        uint256[3] memory used = [u0, u1, u2];
        for (uint256 i; i < 3; i++) {
            if (used[i] == 0) continue;
            if (permit.permitted[k].token != tokens[i]) revert InvalidPermit2Data();
            details[k] = ISignatureTransfer.SignatureTransferDetails({
                to: address(this),
                requestedAmount: used[i]
            });
            k++;
        }

        ISignatureTransfer(PERMIT2).permitTransferFrom(permit, details, msg.sender, signature);
    }

    function _pullAllowance(uint256 u0, uint256 u1, uint256 u2) internal {
        if (u0 > 0) {
            IAllowanceTransfer(PERMIT2).transferFrom(msg.sender, address(this), uint160(u0), _token0);
        }
        if (u1 > 0) {
            IAllowanceTransfer(PERMIT2).transferFrom(msg.sender, address(this), uint160(u1), _token1);
        }
        if (u2 > 0) {
            IAllowanceTransfer(PERMIT2).transferFrom(msg.sender, address(this), uint160(u2), _token2);
        }
    }
}
