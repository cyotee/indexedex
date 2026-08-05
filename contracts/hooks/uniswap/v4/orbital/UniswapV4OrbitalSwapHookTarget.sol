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
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {
    ISignatureTransfer
} from "@crane/contracts/interfaces/protocols/utils/permit2/ISignatureTransfer.sol";
import {
    IAllowanceTransfer
} from "@crane/contracts/interfaces/protocols/utils/permit2/IAllowanceTransfer.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {
    IUniswapV4OrbitalSwapHook
} from "contracts/hooks/uniswap/v4/orbital/interfaces/IUniswapV4OrbitalSwapHook.sol";
import {
    UniswapV4OrbitalSwapHookRepo as Repo
} from "contracts/hooks/uniswap/v4/orbital/UniswapV4OrbitalSwapHookRepo.sol";
import {
    UniswapV4OrbitalSwapHookMath as Math
} from "contracts/hooks/uniswap/v4/orbital/UniswapV4OrbitalSwapHookMath.sol";

/**
 * @title UniswapV4OrbitalSwapHookTarget
 * @notice Product logic: IHooks + LP execute + sphere swap settle (product PRD).
 * @dev Bindings in Repo (initAccount). LP via ERC20Repo; vault reserves via MultiAssetBasicVaultRepo.
 *      No constructor immutables; no monomorph Common inheritance.
 */
abstract contract UniswapV4OrbitalSwapHookTarget is IHooks, IUniswapV4OrbitalSwapHook {
    using SafeERC20 for IERC20;
    using LPFeeLibrary for uint24;

    address internal constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    error ZeroAddress();
    error ZeroAmount();
    error SameToken();
    error NotPoolManager();
    error DeadlineExpired();
    error InsufficientSharesOut();
    error InsufficientTokenOut();
    error LiquidityNotAllowed();
    error InvalidPoolToken();
    error InvalidPoolFee();
    error HookNotImplemented();
    error Reentrancy();
    error NotLive();
    error InvalidRoute();
    error FullBookRequiresThreeLegs();
    error ReservesExceedRadius();
    error InvalidPermit2Data();
    error FirstMintRequiresTwoLegs();

    event LiquidityAdded(
        address indexed provider,
        address indexed to,
        uint256 shares,
        uint256 amount0,
        uint256 amount1,
        uint256 amount2
    );
    event LiquidityRemoved(
        address indexed provider,
        address indexed to,
        uint256 shares,
        uint256 amount0,
        uint256 amount1,
        uint256 amount2
    );
    event Swap(
        address indexed sender,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 feeWad
    );
    event ProtocolFeeMinted(address indexed feeTo, uint256 shares);

    modifier nonReentrant() {
        Repo.Layout storage l = Repo._layout();
        if (l.reentrancyStatus == Repo.ENTERED) revert Reentrancy();
        l.reentrancyStatus = Repo.ENTERED;
        _;
        l.reentrancyStatus = Repo.NOT_ENTERED;
    }

    /* ---------------------------------------------------------------------- */
    /*                              bindings / views                          */
    /* ---------------------------------------------------------------------- */

    function poolManager() public view returns (IPoolManager) {
        return IPoolManager(Repo._layout().poolManager);
    }

    function feeOracle() public view returns (IVaultFeeOracleQuery) {
        return IVaultFeeOracleQuery(Repo._layout().feeOracle);
    }

    function token0() public view returns (address) {
        return Repo._layout().token0;
    }

    function token1() public view returns (address) {
        return Repo._layout().token1;
    }

    function token2() public view returns (address) {
        return Repo._layout().token2;
    }

    function radius() public view returns (uint256) {
        return Repo._layout().R;
    }

    function lSquared() public view returns (uint256) {
        return Repo._layout().L_SQUARED;
    }

    function reserveOf(address token) public view returns (uint256) {
        return Repo._layout().reserves[token];
    }

    function dexSwapFee() public view returns (uint256) {
        return IVaultFeeOracleQuery(Repo._layout().feeOracle).dexSwapFeeOfVault(address(this));
    }

    function usageFee() public view returns (uint256) {
        return IVaultFeeOracleQuery(Repo._layout().feeOracle).usageFeeOfVault(address(this));
    }

    function feeTo() public view returns (address) {
        return address(IVaultFeeOracleQuery(Repo._layout().feeOracle).feeTo());
    }

    function kLast() public view returns (uint256) {
        return Repo._layout().kLast;
    }

    function kLastMode() public view returns (IUniswapV4OrbitalSwapHook.KLastMode) {
        return IUniswapV4OrbitalSwapHook.KLastMode(Repo._layout().kLastMode);
    }

    function permit2() public pure returns (address) {
        return PERMIT2;
    }

    function pairPoolTickSpacing() public view returns (int24) {
        return Repo._layout().tickSpacing;
    }

    function pairPoolSqrtPriceX96() public view returns (uint160) {
        return Repo._layout().sqrtPriceX96;
    }

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
    /*                              internal helpers                          */
    /* ---------------------------------------------------------------------- */

    function _token0() internal view returns (address) {
        return Repo._layout().token0;
    }

    function _token1() internal view returns (address) {
        return Repo._layout().token1;
    }

    function _token2() internal view returns (address) {
        return Repo._layout().token2;
    }

    function _feeOracle() internal view returns (IVaultFeeOracleQuery) {
        return IVaultFeeOracleQuery(Repo._layout().feeOracle);
    }

    function _poolManager() internal view returns (IPoolManager) {
        return IPoolManager(Repo._layout().poolManager);
    }

    function _isBound(address token) internal view returns (bool) {
        Repo.Layout storage l = Repo._layout();
        return token == l.token0 || token == l.token1 || token == l.token2;
    }

    function _decimalsOf(address token) internal view returns (uint8) {
        Repo.Layout storage l = Repo._layout();
        if (token == l.token0) return l.decimals0;
        if (token == l.token1) return l.decimals1;
        if (token == l.token2) return l.decimals2;
        revert InvalidPoolToken();
    }

    function _toWad(address token, uint256 amount) internal view returns (uint256) {
        return Math.toWad(amount, _decimalsOf(token));
    }

    function _fromWadFloor(address token, uint256 amountWad) internal view returns (uint256) {
        return Math.fromWadFloor(amountWad, _decimalsOf(token));
    }

    function _fromWadCeil(address token, uint256 amountWad) internal view returns (uint256) {
        return Math.fromWadCeil(amountWad, _decimalsOf(token));
    }

    function _reserveWad(address token) internal view returns (uint256) {
        return _toWad(token, Repo._layout().reserves[token]);
    }

    function _reservesWad() internal view returns (uint256 r0, uint256 r1, uint256 r2) {
        r0 = _reserveWad(_token0());
        r1 = _reserveWad(_token1());
        r2 = _reserveWad(_token2());
    }

    function _onlyPoolManager() internal view {
        if (msg.sender != Repo._layout().poolManager) revert NotPoolManager();
    }

    function _requireDeadline(uint256 deadline) internal view {
        if (block.timestamp > deadline) revert DeadlineExpired();
    }

    function _requireNonZero(uint256 amount) internal pure {
        if (amount == 0) revert ZeroAmount();
    }

    function _feeOnAndShare()
        internal
        view
        returns (bool feeOn, address feeTo_, uint256 ownerFeeShare, uint256 usageFeeWad)
    {
        IVaultFeeOracleQuery fo = _feeOracle();
        feeTo_ = address(fo.feeTo());
        usageFeeWad = fo.usageFeeOfVault(address(this));
        ownerFeeShare = (usageFeeWad * Repo.FEE_DENOMINATOR) / Math.WAD;
        feeOn = feeTo_ != address(0) && usageFeeWad != 0 && usageFeeWad < Math.WAD
            && ownerFeeShare != 0;
    }

    function _measureK(uint256 r0, uint256 r1, uint256 r2)
        internal
        pure
        returns (uint8 mode, uint256 k, uint256 rootK)
    {
        if (r0 > 0 && r1 > 0 && r2 > 0) {
            mode = 0;
            k = r0 * r1 * r2;
            rootK = Math.cbrt(k);
        } else {
            mode = 1;
            k = r0 + r1 + r2;
            rootK = k;
        }
    }

    function _rootFromStored(uint8 mode, uint256 kStored) internal pure returns (uint256) {
        if (kStored == 0) return 0;
        if (mode == 0) return Math.cbrt(kStored);
        return kStored;
    }

    function _take(Currency currency, address to, uint256 amount) internal {
        if (amount == 0) return;
        _poolManager().take(currency, to, amount);
    }

    function _settle(Currency currency, uint256 amount) internal {
        if (amount == 0) return;
        _poolManager().sync(currency);
        IERC20(Currency.unwrap(currency)).safeTransfer(address(_poolManager()), amount);
        _poolManager().settle();
    }

    function _lock() internal {
        Repo.Layout storage l = Repo._layout();
        if (l.reentrancyStatus == Repo.ENTERED) revert Reentrancy();
        l.reentrancyStatus = Repo.ENTERED;
    }

    function _unlock() internal {
        Repo._layout().reentrancyStatus = Repo.NOT_ENTERED;
    }

    function _mintLp(address to, uint256 amount) internal {
        if (amount == 0) return;
        ERC20Repo._mint(to, amount);
    }

    function _burnLp(address from, uint256 amount) internal {
        ERC20Repo._burn(from, amount);
    }

    function _totalSupply() internal view returns (uint256) {
        return ERC20Repo._totalSupply();
    }

    function _balanceOf(address account) internal view returns (uint256) {
        return ERC20Repo._balanceOf(account);
    }

    function _syncVaultReserves() internal {
        Repo.Layout storage l = Repo._layout();
        MultiAssetBasicVaultRepo._updateReserve(IERC20(l.token0), l.reserves[l.token0]);
        MultiAssetBasicVaultRepo._updateReserve(IERC20(l.token1), l.reserves[l.token1]);
        MultiAssetBasicVaultRepo._updateReserve(IERC20(l.token2), l.reserves[l.token2]);
    }

    function _recomputeL2() internal {
        Repo.Layout storage l = Repo._layout();
        if (l.R == 0) {
            l.L_SQUARED = 0;
            return;
        }
        (uint256 r0, uint256 r1, uint256 r2) = _reservesWad();
        l.L_SQUARED = Math.recomputeL2(l.R, r0, r1, r2);
    }

    function _requirePostUnderRadius() internal view {
        Repo.Layout storage l = Repo._layout();
        if (l.R == 0) return;
        (uint256 r0, uint256 r1, uint256 r2) = _reservesWad();
        if (r0 >= l.R || r1 >= l.R || r2 >= l.R) revert ReservesExceedRadius();
    }

    function _witnessAndLegs(address tokenIn, address tokenOut)
        internal
        view
        returns (address tokenZ)
    {
        if (!_isBound(tokenIn) || !_isBound(tokenOut) || tokenIn == tokenOut) revert InvalidRoute();
        address t0 = _token0();
        address t1 = _token1();
        address t2 = _token2();
        if (tokenIn != t0 && tokenOut != t0) return t0;
        if (tokenIn != t1 && tokenOut != t1) return t1;
        return t2;
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
        uint256 feeWad = _feeOracle().dexSwapFeeOfVault(address(this));
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
        _syncVaultReserves();

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
        Repo.Layout storage l = Repo._layout();
        uint256 rOut = l.reserves[tokenOut];
        if (amountOut == 0 || amountOut >= rOut) revert Math.Drain();
        l.reserves[tokenIn] += amountIn;
        l.reserves[tokenOut] = rOut - amountOut;
        _requirePostUnderRadius();
        _recomputeL2();
        feeWad;
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

    function previewSwapExactIn(address tokenIn, address tokenOut, uint256 amountIn)
        external
        view
        returns (uint256 amountOut)
    {
        return _previewSwapExactIn(tokenIn, tokenOut, amountIn);
    }

    function previewSwapExactOut(address tokenIn, address tokenOut, uint256 amountOut)
        external
        view
        returns (uint256 amountIn)
    {
        return _previewSwapExactOut(tokenIn, tokenOut, amountOut);
    }

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
        uint256 feeWad = _feeOracle().dexSwapFeeOfVault(address(this));
        if (feeWad >= Math.WAD) revert Math.MathDomain();
        uint256 dxNet = Math.applyTradingFeeNet(_toWad(tokenIn, amountIn), feeWad);
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
        uint256 feeWad = _feeOracle().dexSwapFeeOfVault(address(this));
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
        (uint8 mode,, uint256 rootK) = _measureK(r0, r1, r2);
        if (mode != l.kLastMode) return 0;

        uint256 rootKLast = _rootFromStored(mode, l.kLast);
        protocolLp = Math.protocolLpShares(_totalSupply(), rootK, rootKLast, ownerFeeShare);
        if (protocolLp > 0) {
            _mintLp(feeTo_, protocolLp);
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

    function _previewProtocolMintShares()
        internal
        view
        returns (uint256 protocolLp, uint256 supplyAfter)
    {
        supplyAfter = _totalSupply();
        (bool feeOn,, uint256 ownerFeeShare,) = _feeOnAndShare();
        Repo.Layout storage l = Repo._layout();
        if (!feeOn || l.kLast == 0) return (0, supplyAfter);

        (uint256 r0, uint256 r1, uint256 r2) = _reservesWad();
        (uint8 mode,, uint256 rootK) = _measureK(r0, r1, r2);
        if (mode != l.kLastMode) return (0, supplyAfter);

        uint256 rootKLast = _rootFromStored(mode, l.kLast);
        protocolLp = Math.protocolLpShares(_totalSupply(), rootK, rootKLast, ownerFeeShare);
        supplyAfter = _totalSupply() + protocolLp;
    }

    /* ---------------------------------------------------------------------- */
    /*                              Liquidity API                             */
    /* ---------------------------------------------------------------------- */

    function addLiquidity(
        uint256 a0Max,
        uint256 a1Max,
        uint256 a2Max,
        address to,
        uint256 sharesMin,
        uint256 deadline,
        bytes calldata permit2Data
    ) external nonReentrant returns (uint256 shares, uint256 a0, uint256 a1, uint256 a2) {
        return _addLiquidity(a0Max, a1Max, a2Max, to, sharesMin, deadline, permit2Data);
    }

    function removeLiquidity(
        uint256 shares,
        address to,
        uint256 a0Min,
        uint256 a1Min,
        uint256 a2Min,
        uint256 deadline
    ) external nonReentrant returns (uint256 a0, uint256 a1, uint256 a2) {
        return _removeLiquidity(shares, to, a0Min, a1Min, a2Min, deadline);
    }

    function previewAddLiquidity(uint256 a0Max, uint256 a1Max, uint256 a2Max)
        external
        view
        returns (uint256 shares, uint256 a0, uint256 a1, uint256 a2)
    {
        return _previewAddLiquidity(a0Max, a1Max, a2Max);
    }

    function previewRemoveLiquidity(uint256 shares)
        external
        view
        returns (uint256 a0, uint256 a1, uint256 a2)
    {
        return _previewRemoveLiquidity(shares);
    }

    /* ---------------------------------------------------------------------- */
    /*                              Liquidity core                            */
    /* ---------------------------------------------------------------------- */

    function _computeAdd(uint256 a0Max, uint256 a1Max, uint256 a2Max, uint256 supply)
        internal
        view
        returns (uint256 shares, uint256 used0, uint256 used1, uint256 used2)
    {
        if (supply == 0) {
            return _computeFirstMint(a0Max, a1Max, a2Max);
        }
        Repo.Layout storage l = Repo._layout();
        address t0 = l.token0;
        address t1 = l.token1;
        address t2 = l.token2;
        if (l.reserves[t0] > 0 && l.reserves[t1] > 0 && l.reserves[t2] > 0) {
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
            _toWad(_token0(), used0) + _toWad(_token1(), used1) + _toWad(_token2(), used2)
        );
    }

    function _computeFullBook(uint256 a0Max, uint256 a1Max, uint256 a2Max, uint256 supply)
        internal
        view
        returns (uint256 shares, uint256 used0, uint256 used1, uint256 used2)
    {
        if (a0Max == 0 || a1Max == 0 || a2Max == 0) revert FullBookRequiresThreeLegs();
        Repo.Layout storage l = Repo._layout();
        address t0 = l.token0;
        address t1 = l.token1;
        address t2 = l.token2;
        shares = Math.fullBookShares(
            _toWad(t0, a0Max),
            _toWad(t1, a1Max),
            _toWad(t2, a2Max),
            _toWad(t0, l.reserves[t0]),
            _toWad(t1, l.reserves[t1]),
            _toWad(t2, l.reserves[t2]),
            supply
        );
        used0 = _fromWadFloor(t0, Math.fullBookUsedWad(shares, _toWad(t0, l.reserves[t0]), supply));
        used1 = _fromWadFloor(t1, Math.fullBookUsedWad(shares, _toWad(t1, l.reserves[t1]), supply));
        used2 = _fromWadFloor(t2, Math.fullBookUsedWad(shares, _toWad(t2, l.reserves[t2]), supply));
        if (used0 == 0 || used1 == 0 || used2 == 0) revert ZeroAmount();
    }

    function _computePartial(uint256 a0Max, uint256 a1Max, uint256 a2Max, uint256 supply)
        internal
        view
        returns (uint256 shares, uint256 used0, uint256 used1, uint256 used2)
    {
        Repo.Layout storage l = Repo._layout();
        address t0 = l.token0;
        address t1 = l.token1;
        address t2 = l.token2;
        (used0, used1, used2) =
            _partialUsed(a0Max, a1Max, a2Max, l.reserves[t0], l.reserves[t1], l.reserves[t2]);
        shares = Math.sphereNavShares(
            supply,
            l.R,
            _toWad(t0, l.reserves[t0]),
            _toWad(t1, l.reserves[t1]),
            _toWad(t2, l.reserves[t2]),
            _toWad(t0, used0),
            _toWad(t1, used1),
            _toWad(t2, used2)
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

        uint256 supply = _totalSupply();
        if (r0 > 0 && a0Max > 0) {
            used0 = _legUsed(_token0(), r0, minShares, supply);
        }
        if (r1 > 0 && a1Max > 0) {
            used1 = _legUsed(_token1(), r1, minShares, supply);
        }
        if (r2 > 0 && a2Max > 0) {
            used2 = _legUsed(_token2(), r2, minShares, supply);
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
        uint256 supply = _totalSupply();
        if (r0 > 0 && a0Max > 0) {
            minShares = (_toWad(_token0(), a0Max) * supply) / _toWad(_token0(), r0);
        }
        if (r1 > 0 && a1Max > 0) {
            uint256 s = (_toWad(_token1(), a1Max) * supply) / _toWad(_token1(), r1);
            if (s < minShares) minShares = s;
        }
        if (r2 > 0 && a2Max > 0) {
            uint256 s = (_toWad(_token2(), a2Max) * supply) / _toWad(_token2(), r2);
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
        uint256 supply = _totalSupply();

        (shares, used0, used1, used2) = _computeAdd(a0Max, a1Max, a2Max, supply);
        if (shares < sharesMin) revert InsufficientSharesOut();

        _pullLegs(used0, used1, used2, permit2Data);
        _applyAdd(supply, shares, used0, used1, used2, to);
        emit LiquidityAdded(msg.sender, to, shares, used0, used1, used2);
    }

    function _applyAdd(
        uint256 supply,
        uint256 shares,
        uint256 used0,
        uint256 used1,
        uint256 used2,
        address to
    ) private {
        Repo.Layout storage l = Repo._layout();
        if (supply == 0) {
            l.R = Math.firstMintRadius(
                _toWad(l.token0, used0), _toWad(l.token1, used1), _toWad(l.token2, used2)
            );
            l.reserves[l.token0] = used0;
            l.reserves[l.token1] = used1;
            l.reserves[l.token2] = used2;
            _mintLp(address(0), Repo.MINIMUM_LIQUIDITY);
            _mintLp(to, shares);
        } else {
            l.reserves[l.token0] += used0;
            l.reserves[l.token1] += used1;
            l.reserves[l.token2] += used2;
            _requirePostUnderRadius();
            _mintLp(to, shares);
        }
        _recomputeL2();
        _snapshotKLastIfFeeOn();
        _syncVaultReserves();
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
        if (shares > _balanceOf(msg.sender)) revert InsufficientSharesOut();

        (a0, a1, a2) = _proRataOut(shares);
        if (a0 < a0Min || a1 < a1Min || a2 < a2Min) revert InsufficientTokenOut();

        _burnAndPay(shares, to, a0, a1, a2);
        emit LiquidityRemoved(msg.sender, to, shares, a0, a1, a2);
    }

    function _proRataOut(uint256 shares)
        private
        view
        returns (uint256 a0, uint256 a1, uint256 a2)
    {
        Repo.Layout storage l = Repo._layout();
        uint256 supply = _totalSupply();
        a0 = _fromWadFloor(l.token0, (shares * _toWad(l.token0, l.reserves[l.token0])) / supply);
        a1 = _fromWadFloor(l.token1, (shares * _toWad(l.token1, l.reserves[l.token1])) / supply);
        a2 = _fromWadFloor(l.token2, (shares * _toWad(l.token2, l.reserves[l.token2])) / supply);
    }

    function _burnAndPay(uint256 shares, address to, uint256 a0, uint256 a1, uint256 a2) private {
        Repo.Layout storage l = Repo._layout();
        _burnLp(msg.sender, shares);
        l.reserves[l.token0] -= a0;
        l.reserves[l.token1] -= a1;
        l.reserves[l.token2] -= a2;
        if (_totalSupply() == 0) {
            l.L_SQUARED = 0;
        } else {
            _recomputeL2();
        }
        _snapshotKLastIfFeeOn();
        if (a0 > 0) IERC20(l.token0).safeTransfer(to, a0);
        if (a1 > 0) IERC20(l.token1).safeTransfer(to, a1);
        if (a2 > 0) IERC20(l.token2).safeTransfer(to, a2);
        _syncVaultReserves();
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
        address t0 = l.token0;
        address t1 = l.token1;
        address t2 = l.token2;
        a0 = _fromWadFloor(t0, (shares_ * _toWad(t0, l.reserves[t0])) / supplyAfter);
        a1 = _fromWadFloor(t1, (shares_ * _toWad(t1, l.reserves[t1])) / supplyAfter);
        a2 = _fromWadFloor(t2, (shares_ * _toWad(t2, l.reserves[t2])) / supplyAfter);
    }

    /* ---------------------------------------------------------------------- */
    /*                              Permit2 / pull                            */
    /* ---------------------------------------------------------------------- */

    function _pullLegs(uint256 u0, uint256 u1, uint256 u2, bytes calldata permit2Data) internal {
        address t0 = _token0();
        address t1 = _token1();
        address t2 = _token2();
        if (permit2Data.length == 0) {
            if (u0 > 0) IERC20(t0).safeTransferFrom(msg.sender, address(this), u0);
            if (u1 > 0) IERC20(t1).safeTransferFrom(msg.sender, address(this), u1);
            if (u2 > 0) IERC20(t2).safeTransferFrom(msg.sender, address(this), u2);
            return;
        }

        uint8 mode = uint8(permit2Data[0]);
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
        address[3] memory tokens = [_token0(), _token1(), _token2()];
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
            IAllowanceTransfer(PERMIT2).transferFrom(msg.sender, address(this), uint160(u0), _token0());
        }
        if (u1 > 0) {
            IAllowanceTransfer(PERMIT2).transferFrom(msg.sender, address(this), uint160(u1), _token1());
        }
        if (u2 > 0) {
            IAllowanceTransfer(PERMIT2).transferFrom(msg.sender, address(this), uint160(u2), _token2());
        }
    }
}
