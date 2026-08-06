// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
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
import {
    ISignatureTransfer
} from "@crane/contracts/interfaces/protocols/utils/permit2/ISignatureTransfer.sol";
import {
    IAllowanceTransfer
} from "@crane/contracts/interfaces/protocols/utils/permit2/IAllowanceTransfer.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {
    IUniswapV4StandardExchangeOrbitalBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/interfaces/IUniswapV4StandardExchangeOrbitalBufferHook.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHookRepo as Repo
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookRepo.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHookMath as Math
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookMath.sol";
import {
    UniswapV4StandardExchangeOrbitalBufferHookClaimLib as ClaimLib
} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookClaimLib.sol";

/**
 * @title UniswapV4StandardExchangeOrbitalBufferHookTarget
 * @notice Product logic: IHooks + multipath LP + zap-in + SE In/Out + sphere settle on effective reserves.
 */
abstract contract UniswapV4StandardExchangeOrbitalBufferHookTarget is
    IHooks,
    IUniswapV4StandardExchangeOrbitalBufferHook,
    IStandardExchangeIn,
    IStandardExchangeOut
{
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
    error FullBookRequiresThreeLegs();
    error ReservesExceedRadius();
    error InvalidPermit2Data();
    error FirstMintRequiresTwoLegs();
    error NotZapEligible();
    error InvalidIndex();
    error InsufficientPretransfer();

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

    function standardExchange(uint8 i) public view returns (address) {
        return Repo._seAt(Repo._layout(), i);
    }

    function rateProvider(uint8 i) public view returns (address) {
        return Repo._rpAt(Repo._layout(), i);
    }

    function isBuffered(uint8 i) public view returns (bool) {
        return Repo._seAt(Repo._layout(), i) != address(0);
    }

    function permit2() public pure returns (address) {
        return PERMIT2;
    }

    function rawReserve(uint8 i) public view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        address t = Repo._tokenAt(l, i);
        if (Repo._seAt(l, i) != address(0)) return 0;
        return l.reserves[t];
    }

    function seBalance(uint8 i) public view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        address se = Repo._seAt(l, i);
        if (se == address(0)) return 0;
        return IERC20(se).balanceOf(address(this));
    }

    function seClaim(uint8 i) public view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        address se = Repo._seAt(l, i);
        if (se == address(0)) return 0;
        return ClaimLib.seClaimOf(se, Repo._tokenAt(l, i), IERC20(se).balanceOf(address(this)));
    }

    function effectiveReserve(uint8 i) public view returns (uint256) {
        return _effectiveNativeAt(i);
    }

    function effectiveReserves() public view returns (uint256 e0, uint256 e1, uint256 e2) {
        e0 = _effectiveNativeAt(0);
        e1 = _effectiveNativeAt(1);
        e2 = _effectiveNativeAt(2);
    }

    function radius() public view returns (uint256) {
        return Repo._layout().R;
    }

    function lSquared() public view returns (uint256) {
        return Repo._layout().L_SQUARED;
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

    function kLastMode() public view returns (IUniswapV4StandardExchangeOrbitalBufferHook.KLastMode) {
        return IUniswapV4StandardExchangeOrbitalBufferHook.KLastMode(Repo._layout().kLastMode);
    }

    function pairPoolTickSpacing() public view returns (int24) {
        return Repo._layout().tickSpacing;
    }

    function pairPoolSqrtPriceX96() public view returns (uint160) {
        return Repo._layout().sqrtPriceX96;
    }

    function isZapEligible() public view returns (bool) {
        if (_totalSupply() <= Repo.MINIMUM_LIQUIDITY) return false;
        (uint256 e0, uint256 e1, uint256 e2) = _effectiveWad();
        return e0 > 0 && e1 > 0 && e2 > 0;
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

    function _effectiveNativeAt(uint8 i) internal view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        address t = Repo._tokenAt(l, i);
        address se = Repo._seAt(l, i);
        address rp = Repo._rpAt(l, i);
        uint256 seBal = se == address(0) ? 0 : IERC20(se).balanceOf(address(this));
        return ClaimLib.effectiveNative(se, rp, t, l.reserves[t], seBal);
    }

    function _effectiveNativeOf(address token) internal view returns (uint256) {
        return _effectiveNativeAt(Repo._indexOf(Repo._layout(), token));
    }

    function _effectiveWad() internal view returns (uint256 e0, uint256 e1, uint256 e2) {
        Repo.Layout storage l = Repo._layout();
        e0 = _toWad(l.token0, _effectiveNativeAt(0));
        e1 = _toWad(l.token1, _effectiveNativeAt(1));
        e2 = _toWad(l.token2, _effectiveNativeAt(2));
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
        MultiAssetBasicVaultRepo._updateReserve(IERC20(l.token0), _effectiveNativeAt(0));
        MultiAssetBasicVaultRepo._updateReserve(IERC20(l.token1), _effectiveNativeAt(1));
        MultiAssetBasicVaultRepo._updateReserve(IERC20(l.token2), _effectiveNativeAt(2));
    }

    function _recomputeL2() internal {
        Repo.Layout storage l = Repo._layout();
        if (l.R == 0) {
            l.L_SQUARED = 0;
            return;
        }
        (uint256 r0, uint256 r1, uint256 r2) = _effectiveWad();
        l.L_SQUARED = Math.recomputeL2(l.R, r0, r1, r2);
    }

    function _requirePostUnderRadius() internal view {
        Repo.Layout storage l = Repo._layout();
        if (l.R == 0) return;
        (uint256 r0, uint256 r1, uint256 r2) = _effectiveWad();
        if (r0 >= l.R || r1 >= l.R || r2 >= l.R) revert ReservesExceedRadius();
    }

    function _witnessAndLegs(address tokenIn, address tokenOut)
        internal
        view
        returns (address tokenZ)
    {
        if (!_isBound(tokenIn) || !_isBound(tokenOut) || tokenIn == tokenOut) revert InvalidRoute(tokenIn, tokenOut);
        Repo.Layout storage l = Repo._layout();
        if (tokenIn != l.token0 && tokenOut != l.token0) return l.token0;
        if (tokenIn != l.token1 && tokenOut != l.token1) return l.token1;
        return l.token2;
    }

    function _seOf(address token) internal view returns (address) {
        return Repo._seAt(Repo._layout(), Repo._indexOf(Repo._layout(), token));
    }

    function _rpOf(address token) internal view returns (address) {
        return Repo._rpAt(Repo._layout(), Repo._indexOf(Repo._layout(), token));
    }

    /* ---------------------------------------------------------------------- */
    /*                         buffer / unwrap                                */
    /* ---------------------------------------------------------------------- */

    function _bufferToken(address token, uint256 amount) internal returns (uint256 seOut) {
        if (amount == 0) return 0;
        address se = _seOf(token);
        if (se == address(0)) {
            Repo._layout().reserves[token] += amount;
            return 0;
        }
        uint256 minOut =
            IStandardExchangeIn(se).previewExchangeIn(IERC20(token), amount, IERC20(se));
        IERC20(token).forceApprove(se, amount);
        seOut = IStandardExchangeIn(se).exchangeIn(
            IERC20(token), amount, IERC20(se), minOut, address(this), false, block.timestamp
        );
    }

    function _unwrapSeShares(address token, uint256 seIn) internal returns (uint256 pairOut) {
        if (seIn == 0) return 0;
        address se = _seOf(token);
        uint256 minOut =
            IStandardExchangeIn(se).previewExchangeIn(IERC20(se), seIn, IERC20(token));
        IERC20(se).forceApprove(se, seIn);
        pairOut = IStandardExchangeIn(se).exchangeIn(
            IERC20(se), seIn, IERC20(token), minOut, address(this), false, block.timestamp
        );
    }

    function _unwrapExactTokenOut(address token, uint256 amountOut) internal returns (uint256 seIn) {
        if (amountOut == 0) return 0;
        address se = _seOf(token);
        seIn = ClaimLib.invertUnwrapExactTokenOut(se, token, amountOut);
        IERC20(se).forceApprove(se, seIn);
        uint256 got = IStandardExchangeOut(se).exchangeOut(
            IERC20(se), seIn, IERC20(token), amountOut, address(this), false, block.timestamp
        );
        if (got < amountOut) revert InsufficientTokenOut();
    }

    function _bufferLastUsed(uint256 u0, uint256 u1, uint256 u2) internal {
        // Binding index order for used > 0
        if (u0 > 0) _bufferToken(Repo._layout().token0, u0);
        if (u1 > 0) _bufferToken(Repo._layout().token1, u1);
        if (u2 > 0) _bufferToken(Repo._layout().token2, u2);
    }

    function _refundBufferedDust(address token) internal {
        address se = _seOf(token);
        if (se == address(0)) return;
        uint256 bal = IERC20(token).balanceOf(address(this));
        if (bal > Repo.MAX_DUST_WEI) {
            IERC20(token).safeTransfer(msg.sender, bal);
        }
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
        // Buffer-last: unwrap out already done inside execute; buffer in after take
        if (_seOf(tokenIn) != address(0)) {
            _bufferToken(tokenIn, amountIn);
        } else {
            Repo._layout().reserves[tokenIn] += amountIn;
        }
        _settle(Currency.wrap(tokenOut), amountOut);
        _recomputeL2();
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
        // Debit out inventory (unwrap if SE) before buffer-in (caller takes in then buffers)
        if (_seOf(tokenOut) != address(0)) {
            _unwrapExactTokenOut(tokenOut, amountOut);
        } else {
            uint256 rOut = Repo._layout().reserves[tokenOut];
            if (amountOut == 0 || amountOut >= rOut) revert Math.Drain();
            Repo._layout().reserves[tokenOut] = rOut - amountOut;
        }
        _requirePostUnderRadius();
        feeWad;
    }

    function _swapExactOutExecute(address tokenIn, address tokenOut, uint256 amountOut, uint256 feeWad)
        internal
        returns (uint256 amountIn)
    {
        _requireNonZero(amountOut);
        amountIn = _previewSwapExactOut(tokenIn, tokenOut, amountOut);
        if (_seOf(tokenOut) != address(0)) {
            _unwrapExactTokenOut(tokenOut, amountOut);
        } else {
            uint256 rOut = Repo._layout().reserves[tokenOut];
            if (amountOut >= rOut) revert Math.Drain();
            Repo._layout().reserves[tokenOut] = rOut - amountOut;
        }
        _requirePostUnderRadius();
        feeWad;
    }

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
        uint256 eIn = _effectiveNativeOf(tokenIn);
        uint256 eOut = _effectiveNativeOf(tokenOut);
        if (eIn == 0 || eOut == 0) revert NotLive();
        address tokenZ = _witnessAndLegs(tokenIn, tokenOut);
        uint256 feeWad = _feeOracle().dexSwapFeeOfVault(address(this));
        if (feeWad >= Math.WAD) revert Math.MathDomain();

        // Composition: buffered in → claim-in / rate; raw in → face
        uint256 dInNative = amountIn;
        if (_seOf(tokenIn) != address(0)) {
            dInNative = ClaimLib.previewBufferClaimIn(
                _seOf(tokenIn), _rpOf(tokenIn), tokenIn, amountIn, address(this)
            );
            if (dInNative == 0) revert ZeroAmount();
        }
        uint256 dxNet = Math.applyTradingFeeNet(_toWad(tokenIn, dInNative), feeWad);
        uint256 dyWad = Math.sphereExactInOutWad(
            l.R,
            l.L_SQUARED,
            _toWad(tokenIn, eIn),
            _toWad(tokenOut, eOut),
            _toWad(tokenZ, _effectiveNativeOf(tokenZ)),
            dxNet
        );
        uint256 dOutNative = _fromWadFloor(tokenOut, dyWad);
        if (_seOf(tokenOut) != address(0)) {
            (amountOut,) = ClaimLib.previewUnwrapForEffectiveOut(
                _seOf(tokenOut), _rpOf(tokenOut), tokenOut, dOutNative
            );
        } else {
            amountOut = dOutNative;
        }
        if (amountOut == 0 || amountOut >= eOut) revert Math.Drain();
    }

    function _previewSwapExactOut(address tokenIn, address tokenOut, uint256 amountOut)
        internal
        view
        returns (uint256 amountIn)
    {
        _requireNonZero(amountOut);
        Repo.Layout storage l = Repo._layout();
        if (l.R == 0) revert NotLive();
        uint256 eIn = _effectiveNativeOf(tokenIn);
        uint256 eOut = _effectiveNativeOf(tokenOut);
        if (eIn == 0 || eOut == 0) revert NotLive();
        if (amountOut >= eOut) revert Math.Drain();
        address tokenZ = _witnessAndLegs(tokenIn, tokenOut);
        uint256 feeWad = _feeOracle().dexSwapFeeOfVault(address(this));
        if (feeWad >= Math.WAD) revert Math.MathDomain();

        // Map amountOut (pool tokens) → effective dOut for sphere
        uint256 dOutNative = amountOut;
        if (_seOf(tokenOut) != address(0)) {
            // Invert: shares for exact token out, then effective of those shares
            uint256 shares = ClaimLib.invertUnwrapExactTokenOut(_seOf(tokenOut), tokenOut, amountOut);
            if (_rpOf(tokenOut) != address(0)) {
                dOutNative = (shares * ClaimLib.getRateFailClosed(_rpOf(tokenOut))) / 1e18;
            } else {
                dOutNative = ClaimLib.seClaimOf(_seOf(tokenOut), tokenOut, shares);
            }
        }
        uint256 dxNet = Math.sphereExactOutInNetWad(
            l.R,
            l.L_SQUARED,
            _toWad(tokenIn, eIn),
            _toWad(tokenOut, eOut),
            _toWad(tokenZ, _effectiveNativeOf(tokenZ)),
            _toWad(tokenOut, dOutNative)
        );
        uint256 dInGrossWad = Math.grossUpExactOut(dxNet, feeWad);
        uint256 dInNative = _fromWadCeil(tokenIn, dInGrossWad);
        if (_seOf(tokenIn) != address(0)) {
            // Invert buffer claim-in: find raw amount that yields dInNative effective
            // Linear approx for rate; claim path uses binary search helper inline
            amountIn = _invertBufferForEffective(tokenIn, dInNative);
        } else {
            amountIn = dInNative;
        }
        _requireNonZero(amountIn);
    }

    function _invertBufferForEffective(address token, uint256 dInNative)
        internal
        view
        returns (uint256 amountInRaw)
    {
        if (dInNative == 0) return 0;
        address se = _seOf(token);
        address rp = _rpOf(token);
        if (rp != address(0)) {
            // shares = dIn * 1e18 / rate; raw ≈ shares via preview invert (1:1 ERC4626 often)
            uint256 rate = ClaimLib.getRateFailClosed(rp);
            uint256 shares = (dInNative * 1e18 + rate - 1) / rate;
            // For ERC4626 SE, preview convert shares → assets via exchangeOut se→token is claim;
            // invert shares from assets: use exchangeOut token→se? Prefer convert shares→assets then ceil.
            // assets ≈ previewExchangeIn(se, shares, token) inverse ≈ deposit preview.
            // Use binary search on raw for claim-in target.
        }
        uint256 hi = dInNative * 2 + 1;
        uint256 guard;
        while (
            ClaimLib.previewBufferClaimIn(se, rp, token, hi, address(this)) < dInNative
                && guard < 64
        ) {
            hi = hi * 2;
            unchecked {
                ++guard;
            }
        }
        if (ClaimLib.previewBufferClaimIn(se, rp, token, hi, address(this)) < dInNative) {
            revert ClaimLib.SeInvertUnavailable();
        }
        uint256 lo = 1;
        while (lo < hi) {
            uint256 mid = (lo + hi) / 2;
            if (ClaimLib.previewBufferClaimIn(se, rp, token, mid, address(this)) >= dInNative) {
                hi = mid;
            } else {
                lo = mid + 1;
            }
        }
        return lo;
    }

    /* ---------------------------------------------------------------------- */
    /*                           Protocol growth mint                         */
    /* ---------------------------------------------------------------------- */

    function _maybeMintProtocolFee() internal returns (uint256 protocolLp) {
        (bool feeOn, address feeTo_, uint256 ownerFeeShare,) = _feeOnAndShare();
        Repo.Layout storage l = Repo._layout();
        if (!feeOn || l.kLast == 0) return 0;

        (uint256 r0, uint256 r1, uint256 r2) = _effectiveWad();
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
        (uint256 r0, uint256 r1, uint256 r2) = _effectiveWad();
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

        (uint256 r0, uint256 r1, uint256 r2) = _effectiveWad();
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

    function depositSingle(
        address tokenIn,
        uint256 amountIn,
        address to,
        uint256 sharesMin,
        uint256 deadline,
        bytes calldata permit2Data
    ) external nonReentrant returns (uint256 shares) {
        return _depositSingle(tokenIn, amountIn, to, sharesMin, deadline, permit2Data);
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

    function previewDepositSingle(address tokenIn, uint256 amountIn)
        external
        view
        returns (uint256 shares)
    {
        return _previewDepositSingle(tokenIn, amountIn);
    }

    function previewZapSplit(address tokenIn, uint256 amountIn)
        external
        view
        returns (uint256 saleJ, uint256 saleK, uint256 residualIn, uint256 outJ, uint256 outK)
    {
        return _previewZapSplit(tokenIn, amountIn);
    }

    function _computeAdd(uint256 a0Max, uint256 a1Max, uint256 a2Max, uint256 supply)
        internal
        view
        returns (uint256 shares, uint256 used0, uint256 used1, uint256 used2)
    {
        if (supply == 0) {
            return _computeFirstMint(a0Max, a1Max, a2Max);
        }
        (uint256 e0, uint256 e1, uint256 e2) = _effectiveWad();
        if (e0 > 0 && e1 > 0 && e2 > 0) {
            return _computeFullBook(a0Max, a1Max, a2Max, supply);
        }
        if (Repo._layout().R == 0) revert NotLive();
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
        // Preview effective used for SE legs (claim-in of buffer)
        Repo.Layout storage l = Repo._layout();
        uint256 e0 = used0;
        uint256 e1 = used1;
        uint256 e2 = used2;
        if (l.se0 != address(0) && used0 > 0) {
            e0 = ClaimLib.previewBufferClaimIn(l.se0, l.rp0, l.token0, used0, address(this));
        }
        if (l.se1 != address(0) && used1 > 0) {
            e1 = ClaimLib.previewBufferClaimIn(l.se1, l.rp1, l.token1, used1, address(this));
        }
        if (l.se2 != address(0) && used2 > 0) {
            e2 = ClaimLib.previewBufferClaimIn(l.se2, l.rp2, l.token2, used2, address(this));
        }
        shares = Math.firstMintShares(
            _toWad(l.token0, e0) + _toWad(l.token1, e1) + _toWad(l.token2, e2)
        );
    }

    function _computeFullBook(uint256 a0Max, uint256 a1Max, uint256 a2Max, uint256 supply)
        internal
        view
        returns (uint256 shares, uint256 used0, uint256 used1, uint256 used2)
    {
        if (a0Max == 0 || a1Max == 0 || a2Max == 0) revert FullBookRequiresThreeLegs();
        Repo.Layout storage l = Repo._layout();
        (uint256 e0, uint256 e1, uint256 e2) = _effectiveWad();
        // Map max face → max effective for ratio
        uint256 a0e = a0Max;
        uint256 a1e = a1Max;
        uint256 a2e = a2Max;
        if (l.se0 != address(0)) {
            a0e = ClaimLib.previewBufferClaimIn(l.se0, l.rp0, l.token0, a0Max, address(this));
        }
        if (l.se1 != address(0)) {
            a1e = ClaimLib.previewBufferClaimIn(l.se1, l.rp1, l.token1, a1Max, address(this));
        }
        if (l.se2 != address(0)) {
            a2e = ClaimLib.previewBufferClaimIn(l.se2, l.rp2, l.token2, a2Max, address(this));
        }
        shares = Math.fullBookShares(
            _toWad(l.token0, a0e),
            _toWad(l.token1, a1e),
            _toWad(l.token2, a2e),
            e0,
            e1,
            e2,
            supply
        );
        uint256 u0e = _fromWadFloor(l.token0, Math.fullBookUsedWad(shares, e0, supply));
        uint256 u1e = _fromWadFloor(l.token1, Math.fullBookUsedWad(shares, e1, supply));
        uint256 u2e = _fromWadFloor(l.token2, Math.fullBookUsedWad(shares, e2, supply));
        // Invert effective → face for SE legs
        used0 = l.se0 == address(0) ? u0e : _invertBufferForEffective(l.token0, u0e);
        used1 = l.se1 == address(0) ? u1e : _invertBufferForEffective(l.token1, u1e);
        used2 = l.se2 == address(0) ? u2e : _invertBufferForEffective(l.token2, u2e);
        if (used0 == 0 || used1 == 0 || used2 == 0) revert ZeroAmount();
    }

    function _computePartial(uint256 a0Max, uint256 a1Max, uint256 a2Max, uint256 supply)
        internal
        view
        returns (uint256 shares, uint256 used0, uint256 used1, uint256 used2)
    {
        Repo.Layout storage l = Repo._layout();
        uint256 e0n = _effectiveNativeAt(0);
        uint256 e1n = _effectiveNativeAt(1);
        uint256 e2n = _effectiveNativeAt(2);
        (used0, used1, used2) = _partialUsed(a0Max, a1Max, a2Max, e0n, e1n, e2n);
        shares = Math.sphereNavShares(
            supply,
            l.R,
            _toWad(l.token0, e0n),
            _toWad(l.token1, e1n),
            _toWad(l.token2, e2n),
            _toWad(l.token0, used0),
            _toWad(l.token1, used1),
            _toWad(l.token2, used2)
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
        Repo.Layout storage l = Repo._layout();
        if (r0 > 0 && a0Max > 0) {
            used0 = _fromWadFloor(l.token0, Math.fullBookUsedWad(minShares, _toWad(l.token0, r0), supply));
            if (used0 == 0) revert ZeroAmount();
        }
        if (r1 > 0 && a1Max > 0) {
            used1 = _fromWadFloor(l.token1, Math.fullBookUsedWad(minShares, _toWad(l.token1, r1), supply));
            if (used1 == 0) revert ZeroAmount();
        }
        if (r2 > 0 && a2Max > 0) {
            used2 = _fromWadFloor(l.token2, Math.fullBookUsedWad(minShares, _toWad(l.token2, r2), supply));
            if (used2 == 0) revert ZeroAmount();
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
        Repo.Layout storage l = Repo._layout();
        if (r0 > 0 && a0Max > 0) {
            minShares = (_toWad(l.token0, a0Max) * supply) / _toWad(l.token0, r0);
        }
        if (r1 > 0 && a1Max > 0) {
            uint256 s = (_toWad(l.token1, a1Max) * supply) / _toWad(l.token1, r1);
            if (s < minShares) minShares = s;
        }
        if (r2 > 0 && a2Max > 0) {
            uint256 s = (_toWad(l.token2, a2Max) * supply) / _toWad(l.token2, r2);
            if (s < minShares) minShares = s;
        }
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
        // Buffer-last SE legs; raw legs credit reserves inside _bufferToken
        _bufferLastUsed(used0, used1, used2);
        _applyAdd(supply, shares, used0, used1, used2, to);
        // D35: refund free buffered-token dust after multipath add
        _refundConservation(msg.sender);
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
            // R from post-buffer effective used
            uint256 e0 = _effectiveNativeAt(0);
            uint256 e1 = _effectiveNativeAt(1);
            uint256 e2 = _effectiveNativeAt(2);
            // If only partial legs deposited, effective may be zero on unused
            if (used0 == 0) e0 = 0;
            if (used1 == 0) e1 = 0;
            if (used2 == 0) e2 = 0;
            // For first mint, R from the used effective amounts after buffer
            // Re-read post-buffer: unused legs stay 0
            e0 = used0 > 0 ? _effectiveNativeAt(0) : 0;
            e1 = used1 > 0 ? _effectiveNativeAt(1) : 0;
            e2 = used2 > 0 ? _effectiveNativeAt(2) : 0;
            l.R = Math.firstMintRadius(
                _toWad(l.token0, e0), _toWad(l.token1, e1), _toWad(l.token2, e2)
            );
            _mintLp(address(0), Repo.MINIMUM_LIQUIDITY);
            _mintLp(to, shares);
        } else {
            _requirePostUnderRadius();
            _mintLp(to, shares);
        }
        used0;
        used1;
        used2;
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
        // Pro-rata on raw reserves and/or SE share balances
        if (l.se0 == address(0)) {
            a0 = (shares * l.reserves[l.token0]) / supply;
        } else {
            uint256 seBal = IERC20(l.se0).balanceOf(address(this));
            uint256 seOut = (shares * seBal) / supply;
            a0 = ClaimLib.previewUnwrapShares(l.se0, l.token0, seOut);
        }
        if (l.se1 == address(0)) {
            a1 = (shares * l.reserves[l.token1]) / supply;
        } else {
            uint256 seBal = IERC20(l.se1).balanceOf(address(this));
            uint256 seOut = (shares * seBal) / supply;
            a1 = ClaimLib.previewUnwrapShares(l.se1, l.token1, seOut);
        }
        if (l.se2 == address(0)) {
            a2 = (shares * l.reserves[l.token2]) / supply;
        } else {
            uint256 seBal = IERC20(l.se2).balanceOf(address(this));
            uint256 seOut = (shares * seBal) / supply;
            a2 = ClaimLib.previewUnwrapShares(l.se2, l.token2, seOut);
        }
    }

    function _burnAndPay(uint256 shares, address to, uint256 a0, uint256 a1, uint256 a2) private {
        Repo.Layout storage l = Repo._layout();
        uint256 supply = _totalSupply();
        _burnLp(msg.sender, shares);

        if (l.se0 == address(0)) {
            l.reserves[l.token0] -= a0;
            if (a0 > 0) IERC20(l.token0).safeTransfer(to, a0);
        } else {
            uint256 seBal = IERC20(l.se0).balanceOf(address(this));
            uint256 seOut = (shares * seBal) / supply;
            uint256 pairOut = seOut > 0 ? _unwrapSeShares(l.token0, seOut) : 0;
            if (pairOut > 0) IERC20(l.token0).safeTransfer(to, pairOut);
            a0 = pairOut;
        }
        if (l.se1 == address(0)) {
            l.reserves[l.token1] -= a1;
            if (a1 > 0) IERC20(l.token1).safeTransfer(to, a1);
        } else {
            uint256 seBal = IERC20(l.se1).balanceOf(address(this));
            uint256 seOut = (shares * seBal) / supply;
            uint256 pairOut = seOut > 0 ? _unwrapSeShares(l.token1, seOut) : 0;
            if (pairOut > 0) IERC20(l.token1).safeTransfer(to, pairOut);
            a1 = pairOut;
        }
        if (l.se2 == address(0)) {
            l.reserves[l.token2] -= a2;
            if (a2 > 0) IERC20(l.token2).safeTransfer(to, a2);
        } else {
            uint256 seBal = IERC20(l.se2).balanceOf(address(this));
            uint256 seOut = (shares * seBal) / supply;
            uint256 pairOut = seOut > 0 ? _unwrapSeShares(l.token2, seOut) : 0;
            if (pairOut > 0) IERC20(l.token2).safeTransfer(to, pairOut);
            a2 = pairOut;
        }

        if (_totalSupply() == 0) {
            l.L_SQUARED = 0;
        } else {
            _recomputeL2();
        }
        _snapshotKLastIfFeeOn();
        _refundConservation(msg.sender);
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
        // Use supplyAfter for pro-rata simulation
        Repo.Layout storage l = Repo._layout();
        if (l.se0 == address(0)) {
            a0 = (shares_ * l.reserves[l.token0]) / supplyAfter;
        } else {
            uint256 seBal = IERC20(l.se0).balanceOf(address(this));
            a0 = ClaimLib.previewUnwrapShares(l.se0, l.token0, (shares_ * seBal) / supplyAfter);
        }
        if (l.se1 == address(0)) {
            a1 = (shares_ * l.reserves[l.token1]) / supplyAfter;
        } else {
            uint256 seBal = IERC20(l.se1).balanceOf(address(this));
            a1 = ClaimLib.previewUnwrapShares(l.se1, l.token1, (shares_ * seBal) / supplyAfter);
        }
        if (l.se2 == address(0)) {
            a2 = (shares_ * l.reserves[l.token2]) / supplyAfter;
        } else {
            uint256 seBal = IERC20(l.se2).balanceOf(address(this));
            a2 = ClaimLib.previewUnwrapShares(l.se2, l.token2, (shares_ * seBal) / supplyAfter);
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                                   Zap-in                               */
    /* ---------------------------------------------------------------------- */

    /// @dev Shared zap plan: Math.zapSplitWad (λ law) + sequential SE-aware out quotes + post-swap full-book shares.
    struct ZapPlan {
        uint8 inIdx;
        uint8 j;
        uint8 k;
        uint256 saleJ;
        uint256 saleK;
        uint256 residual;
        uint256 outJ;
        uint256 outK;
        uint256 shares;
        uint256 used0;
        uint256 used1;
        uint256 used2;
    }

    function _depositSingle(
        address tokenIn,
        uint256 amountIn,
        address to,
        uint256 sharesMin,
        uint256 deadline,
        bytes calldata permit2Data
    ) internal returns (uint256 shares) {
        _requireDeadline(deadline);
        _requireNonZero(amountIn);
        if (to == address(0)) revert ZeroAddress();
        if (!isZapEligible()) revert NotZapEligible();
        if (!_isBound(tokenIn)) revert InvalidPoolToken();

        _maybeMintProtocolFee();
        ZapPlan memory plan = _planZap(tokenIn, amountIn);
        if (plan.shares < sharesMin) revert InsufficientSharesOut();

        _pullTokenIn(tokenIn, amountIn, permit2Data);
        _executeZapSwaps(tokenIn, plan);
        // Multipath join residual + outs using planned used amounts (same numbers as preview).
        uint256 supplyBefore = _totalSupply();
        _bufferLastUsed(plan.used0, plan.used1, plan.used2);
        _applyAdd(supplyBefore, plan.shares, plan.used0, plan.used1, plan.used2, to);
        shares = plan.shares;
        // D47 unused residual/outs face + D35 buffered dust
        _refundConservation(msg.sender);
        emit DepositSingle(msg.sender, to, tokenIn, amountIn, shares);
    }

    function _pullTokenIn(address tokenIn, uint256 amountIn, bytes calldata permit2Data) private {
        if (permit2Data.length == 0) {
            IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        } else {
            _pullSingle(tokenIn, amountIn, permit2Data);
        }
    }

    function _executeZapSwaps(address tokenIn, ZapPlan memory plan) private {
        Repo.Layout storage l = Repo._layout();
        address tokenJ = Repo._tokenAt(l, plan.j);
        address tokenK = Repo._tokenAt(l, plan.k);
        uint256 feeWad = _feeOracle().dexSwapFeeOfVault(address(this));
        if (plan.saleJ > 0) {
            uint256 gotJ = _internalSwapExactIn(tokenIn, tokenJ, plan.saleJ, feeWad);
            emit ZapSwap(msg.sender, tokenIn, tokenJ, plan.saleJ, gotJ);
        }
        if (plan.saleK > 0) {
            uint256 gotK = _internalSwapExactIn(tokenIn, tokenK, plan.saleK, feeWad);
            emit ZapSwap(msg.sender, tokenIn, tokenK, plan.saleK, gotK);
        }
    }

    function _internalSwapExactIn(address tokenIn, address tokenOut, uint256 amountIn, uint256 feeWad)
        internal
        returns (uint256 amountOut)
    {
        amountOut = _previewSwapExactIn(tokenIn, tokenOut, amountIn);
        if (_seOf(tokenOut) != address(0)) {
            _unwrapExactTokenOut(tokenOut, amountOut);
        } else {
            Repo._layout().reserves[tokenOut] -= amountOut;
        }
        if (_seOf(tokenIn) != address(0)) {
            _bufferToken(tokenIn, amountIn);
        } else {
            Repo._layout().reserves[tokenIn] += amountIn;
        }
        _recomputeL2();
        feeWad;
    }

    function _otherIdx(uint8 inIdx) private pure returns (uint8 j, uint8 k) {
        if (inIdx == 0) return (1, 2);
        if (inIdx == 1) return (0, 2);
        return (0, 1);
    }

    function _zapAmountsToBinding(
        uint8 inIdx,
        uint8 j,
        uint256 residual,
        uint256 outJ,
        uint256 outK
    ) private pure returns (uint256 a0, uint256 a1, uint256 a2) {
        if (inIdx == 0) {
            a0 = residual;
            a1 = j == 1 ? outJ : outK;
            a2 = j == 1 ? outK : outJ;
        } else if (inIdx == 1) {
            a1 = residual;
            a0 = j == 0 ? outJ : outK;
            a2 = j == 0 ? outK : outJ;
        } else {
            a2 = residual;
            a0 = j == 0 ? outJ : outK;
            a1 = j == 0 ? outK : outJ;
        }
    }

    /// @notice Single pure pipeline for preview + exec (PRD λ via Math.zapSplitWad).
    function _planZap(address tokenIn, uint256 amountIn) internal view returns (ZapPlan memory p) {
        if (!isZapEligible()) revert NotZapEligible();
        if (!_isBound(tokenIn)) revert InvalidPoolToken();
        _requireNonZero(amountIn);

        Repo.Layout storage l = Repo._layout();
        p.inIdx = Repo._indexOf(l, tokenIn);
        (p.j, p.k) = _otherIdx(p.inIdx);

        (uint256 e0, uint256 e1, uint256 e2) = _effectiveWad();
        uint256 feeWad = _feeOracle().dexSwapFeeOfVault(address(this));
        uint256 amountInWad = _toWad(tokenIn, amountIn);

        (uint256 sJWad, uint256 sKWad, uint256 aInWad, uint256 aJWad, uint256 aKWad) = Math.zapSplitWad(
            e0, e1, e2, l.R, l.L_SQUARED, feeWad, p.inIdx, amountInWad
        );
        aInWad; // residual WAD used only for face mapping via conservation below

        // Face sales: ceil so user pays enough; clamp to amountIn
        p.saleJ = _fromWadCeil(tokenIn, sJWad);
        p.saleK = _fromWadCeil(tokenIn, sKWad);
        if (p.saleJ + p.saleK > amountIn) {
            p.saleJ = _fromWadFloor(tokenIn, sJWad);
            p.saleK = _fromWadFloor(tokenIn, sKWad);
            if (p.saleJ + p.saleK > amountIn) {
                if (p.saleJ >= amountIn) {
                    p.saleJ = amountIn / 2;
                    p.saleK = amountIn - p.saleJ;
                } else {
                    p.saleK = amountIn - p.saleJ;
                }
            }
        }
        p.residual = amountIn - p.saleJ - p.saleK;

        // Sequential SE-aware outs (same composition as live _previewSwapExactIn)
        address tokenJ = Repo._tokenAt(l, p.j);
        address tokenK = Repo._tokenAt(l, p.k);
        p.outJ = p.saleJ > 0 ? _previewSwapExactIn(tokenIn, tokenJ, p.saleJ) : 0;
        p.outK = p.saleK > 0 ? _previewZapSecondLegEffective(tokenIn, tokenJ, tokenK, p.saleJ, p.saleK) : 0;
        // Prefer algebraic outs when closer (optional consistency with λ):
        if (aJWad > 0 && _seOf(tokenJ) == address(0)) {
            uint256 algJ = _fromWadFloor(tokenJ, aJWad);
            if (algJ > 0) p.outJ = algJ;
        }
        if (aKWad > 0 && _seOf(tokenK) == address(0)) {
            // second-leg algebraic is on post-first book — keep sequential SE-aware quote as SoT
        }

        (uint256 a0, uint256 a1, uint256 a2) =
            _zapAmountsToBinding(p.inIdx, p.j, p.residual, p.outJ, p.outK);
        (, uint256 supplyAfter) = _previewProtocolMintShares();
        (p.shares, p.used0, p.used1, p.used2) =
            _computeAddAfterSimulatedZapEffective(tokenIn, p.saleJ, p.saleK, p.outJ, p.outK, a0, a1, a2, supplyAfter);
    }

    function _previewZapSplit(address tokenIn, uint256 amountIn)
        internal
        view
        returns (uint256 saleJ, uint256 saleK, uint256 residualIn, uint256 outJ, uint256 outK)
    {
        ZapPlan memory p = _planZap(tokenIn, amountIn);
        return (p.saleJ, p.saleK, p.residual, p.outJ, p.outK);
    }

    function _previewDepositSingle(address tokenIn, uint256 amountIn)
        internal
        view
        returns (uint256 shares)
    {
        return _planZap(tokenIn, amountIn).shares;
    }

    /// @dev SE-aware second-leg out: apply first swap effective deltas, then quote saleK.
    function _previewZapSecondLegEffective(
        address tokenIn,
        address tokenJ,
        address tokenK,
        uint256 saleJ,
        uint256 saleK
    ) private view returns (uint256 outK) {
        Repo.Layout storage l = Repo._layout();
        uint256 feeWad = _feeOracle().dexSwapFeeOfVault(address(this));

        // Snapshot effective natives
        uint256 eInN = _effectiveNativeOf(tokenIn);
        uint256 eJN = _effectiveNativeOf(tokenJ);
        uint256 eKN = _effectiveNativeOf(tokenK);

        // First swap: dIn native (claim-in or face), dOut native (face out)
        uint256 dIn0 = _dInNative(tokenIn, saleJ);
        uint256 outJ = _previewSwapExactIn(tokenIn, tokenJ, saleJ);
        uint256 dOut0 = _dOutNativeDebit(tokenJ, outJ);

        // Live book: raw reserves += face sale / -= face out; SE effective changes by claim deltas.
        // Sphere domain uses effective natives in WAD.
        eInN += dIn0;
        eJN -= dOut0;
        if (eJN == 0 || eInN == 0) revert Math.MathDomain();

        uint256 eIn = _toWad(tokenIn, eInN);
        uint256 eJ = _toWad(tokenJ, eJN);
        uint256 eK = _toWad(tokenK, eKN);
        uint256 L2b = Math.recomputeL2(l.R, eIn, eJ, eK);

        uint256 dIn1 = _dInNative(tokenIn, saleK);
        uint256 dxNet = Math.applyTradingFeeNet(_toWad(tokenIn, dIn1), feeWad);
        uint256 dyK = Math.sphereExactInOutWad(l.R, L2b, eIn, eK, eJ, dxNet);
        // Map effective out WAD → face out (raw floor, or SE unwrap of that effective)
        outK = _effectiveWadOutToFace(tokenK, dyK);
    }

    function _dInNative(address token, uint256 faceIn) private view returns (uint256) {
        if (faceIn == 0) return 0;
        address se = _seOf(token);
        if (se == address(0)) return faceIn;
        return ClaimLib.previewBufferClaimIn(se, _rpOf(token), token, faceIn, address(this));
    }

    function _dOutNativeDebit(address token, uint256 faceOut) private view returns (uint256) {
        if (faceOut == 0) return 0;
        address se = _seOf(token);
        if (se == address(0)) return faceOut;
        // Effective reduction from unwrapping enough shares to deliver faceOut
        uint256 shares = ClaimLib.invertUnwrapExactTokenOut(se, token, faceOut);
        address rp = _rpOf(token);
        if (rp != address(0)) {
            return (shares * ClaimLib.getRateFailClosed(rp)) / 1e18;
        }
        return ClaimLib.seClaimOf(se, token, shares);
    }

    function _effectiveWadOutToFace(address token, uint256 outWad) private view returns (uint256) {
        if (outWad == 0) return 0;
        address se = _seOf(token);
        uint256 outNative = _fromWadFloor(token, outWad);
        if (se == address(0)) return outNative;
        // Face token from unwrapping shares that realize outNative effective
        address rp = _rpOf(token);
        if (rp != address(0)) {
            uint256 rate = ClaimLib.getRateFailClosed(rp);
            uint256 shares = (outNative * 1e18 + rate - 1) / rate;
            return ClaimLib.previewUnwrapShares(se, token, shares);
        }
        (uint256 face,) = ClaimLib.previewUnwrapForEffectiveOut(se, address(0), token, outNative);
        return face;
    }

    /// @dev Post-swap effective book after sales/outs (SE-aware dIn/dOut), then full-book used/shares.
    function _computeAddAfterSimulatedZapEffective(
        address tokenIn,
        uint256 saleJ,
        uint256 saleK,
        uint256 outJ,
        uint256 outK,
        uint256 a0,
        uint256 a1,
        uint256 a2,
        uint256 supply
    ) private view returns (uint256 shares, uint256 used0, uint256 used1, uint256 used2) {
        Repo.Layout storage l = Repo._layout();
        uint256 e0 = _effectiveNativeAt(0);
        uint256 e1 = _effectiveNativeAt(1);
        uint256 e2 = _effectiveNativeAt(2);
        uint8 inIdx = Repo._indexOf(l, tokenIn);
        (uint8 j, uint8 k) = _otherIdx(inIdx);

        // Apply two sales of tokenIn and outs on j then k
        uint256 dIn = _dInNative(tokenIn, saleJ) + _dInNative(tokenIn, saleK);
        if (inIdx == 0) e0 += dIn;
        else if (inIdx == 1) e1 += dIn;
        else e2 += dIn;

        uint256 dOutJ = _dOutNativeDebit(Repo._tokenAt(l, j), outJ);
        uint256 dOutK = _dOutNativeDebit(Repo._tokenAt(l, k), outK);
        if (j == 0) e0 -= dOutJ;
        else if (j == 1) e1 -= dOutJ;
        else e2 -= dOutJ;
        if (k == 0) e0 -= dOutK;
        else if (k == 1) e1 -= dOutK;
        else e2 -= dOutK;

        if (e0 == 0 || e1 == 0 || e2 == 0) revert Math.MathDomain();

        // Max face for multipath = residual + outs (a0,a1,a2); map to effective for SE legs
        uint256 a0e = a0;
        uint256 a1e = a1;
        uint256 a2e = a2;
        if (l.se0 != address(0) && a0 > 0) {
            a0e = ClaimLib.previewBufferClaimIn(l.se0, l.rp0, l.token0, a0, address(this));
        }
        if (l.se1 != address(0) && a1 > 0) {
            a1e = ClaimLib.previewBufferClaimIn(l.se1, l.rp1, l.token1, a1, address(this));
        }
        if (l.se2 != address(0) && a2 > 0) {
            a2e = ClaimLib.previewBufferClaimIn(l.se2, l.rp2, l.token2, a2, address(this));
        }

        shares = Math.fullBookShares(
            _toWad(l.token0, a0e),
            _toWad(l.token1, a1e),
            _toWad(l.token2, a2e),
            _toWad(l.token0, e0),
            _toWad(l.token1, e1),
            _toWad(l.token2, e2),
            supply
        );
        uint256 u0e = _fromWadFloor(l.token0, Math.fullBookUsedWad(shares, _toWad(l.token0, e0), supply));
        uint256 u1e = _fromWadFloor(l.token1, Math.fullBookUsedWad(shares, _toWad(l.token1, e1), supply));
        uint256 u2e = _fromWadFloor(l.token2, Math.fullBookUsedWad(shares, _toWad(l.token2, e2), supply));
        used0 = l.se0 == address(0) ? u0e : _invertBufferForEffective(l.token0, u0e);
        used1 = l.se1 == address(0) ? u1e : _invertBufferForEffective(l.token1, u1e);
        used2 = l.se2 == address(0) ? u2e : _invertBufferForEffective(l.token2, u2e);
        if (used0 == 0 || used1 == 0 || used2 == 0) revert ZeroAmount();
        // Cap used to available maxes
        if (used0 > a0) used0 = a0;
        if (used1 > a1) used1 = a1;
        if (used2 > a2) used2 = a2;
    }

    /// @notice D47 unused free face + D35 buffered dust > MAX_DUST_WEI → msg.sender.
    function _refundConservation(address to) internal {
        if (to == address(0)) return;
        Repo.Layout storage l = Repo._layout();
        _refundFreeOfToken(l.token0, l.se0 != address(0), to);
        _refundFreeOfToken(l.token1, l.se1 != address(0), to);
        _refundFreeOfToken(l.token2, l.se2 != address(0), to);
    }

    function _refundFreeOfToken(address token, bool buffered, address to) private {
        uint256 free = _freeTokenBalance(token);
        if (free == 0) return;
        if (buffered) {
            if (free > Repo.MAX_DUST_WEI) IERC20(token).safeTransfer(to, free);
        } else if (free > 0) {
            IERC20(token).safeTransfer(to, free);
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                              SE In / Out                               */
    /* ---------------------------------------------------------------------- */

    function previewExchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut)
        external
        view
        returns (uint256 amountOut)
    {
        return _previewSwapExactIn(address(tokenIn), address(tokenOut), amountIn);
    }

    function exchangeIn(
        IERC20 tokenIn,
        uint256 amountIn,
        IERC20 tokenOut,
        uint256 minAmountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external nonReentrant returns (uint256 amountOut) {
        _requireDeadline(deadline);
        _requireNonZero(amountIn);
        if (recipient == address(0)) revert ZeroAddress();
        address tin = address(tokenIn);
        address tout = address(tokenOut);
        if (!_isBound(tin) || !_isBound(tout) || tin == tout) revert InvalidRoute(tin, tout);
        // Reject SE share addresses
        Repo.Layout storage l = Repo._layout();
        if (tin == l.se0 || tin == l.se1 || tin == l.se2 || tout == l.se0 || tout == l.se1 || tout == l.se2) {
            revert InvalidRoute(tin, tout);
        }

        if (!pretransferred) {
            _pullSeFunding(tin, amountIn);
        } else {
            _requirePretransferred(tin, amountIn);
        }

        uint256 feeWad = _feeOracle().dexSwapFeeOfVault(address(this));
        amountOut = _previewSwapExactIn(tin, tout, amountIn);
        if (amountOut < minAmountOut) revert InsufficientTokenOut();

        // Execute book swap (no PM)
        if (_seOf(tout) != address(0)) {
            _unwrapExactTokenOut(tout, amountOut);
        } else {
            l.reserves[tout] -= amountOut;
        }
        if (_seOf(tin) != address(0)) {
            _bufferToken(tin, amountIn);
        } else {
            l.reserves[tin] += amountIn;
        }
        _recomputeL2();
        IERC20(tout).safeTransfer(recipient, amountOut);
        _syncVaultReserves();
        emit Swap(msg.sender, tin, tout, amountIn, amountOut, feeWad);
    }

    function previewExchangeOut(IERC20 tokenIn, IERC20 tokenOut, uint256 amountOut)
        external
        view
        returns (uint256 amountIn)
    {
        return _previewSwapExactOut(address(tokenIn), address(tokenOut), amountOut);
    }

    function exchangeOut(
        IERC20 tokenIn,
        uint256 maxAmountIn,
        IERC20 tokenOut,
        uint256 amountOut,
        address recipient,
        bool pretransferred,
        uint256 deadline
    ) external nonReentrant returns (uint256 amountIn) {
        _requireDeadline(deadline);
        _requireNonZero(amountOut);
        if (recipient == address(0)) revert ZeroAddress();
        address tin = address(tokenIn);
        address tout = address(tokenOut);
        if (!_isBound(tin) || !_isBound(tout) || tin == tout) revert InvalidRoute(tin, tout);

        amountIn = _previewSwapExactOut(tin, tout, amountOut);
        if (amountIn > maxAmountIn) revert InsufficientTokenOut();

        if (!pretransferred) {
            _pullSeFunding(tin, amountIn);
        } else {
            // Free balance must cover the quoted amountIn (max may be higher; refund excess).
            _requirePretransferred(tin, amountIn);
            if (maxAmountIn > amountIn) {
                uint256 free = _freeTokenBalance(tin);
                // Only refund excess free above amountIn that user pre-sent (up to max-amountIn gap).
                uint256 excessCap = maxAmountIn - amountIn;
                uint256 freeAfterNeed = free > amountIn ? free - amountIn : 0;
                uint256 refund = freeAfterNeed < excessCap ? freeAfterNeed : excessCap;
                if (refund > 0) IERC20(tin).safeTransfer(msg.sender, refund);
            }
        }

        uint256 feeWad = _feeOracle().dexSwapFeeOfVault(address(this));
        Repo.Layout storage l = Repo._layout();
        if (_seOf(tout) != address(0)) {
            _unwrapExactTokenOut(tout, amountOut);
        } else {
            l.reserves[tout] -= amountOut;
        }
        if (_seOf(tin) != address(0)) {
            _bufferToken(tin, amountIn);
        } else {
            l.reserves[tin] += amountIn;
        }
        _recomputeL2();
        IERC20(tout).safeTransfer(recipient, amountOut);
        _syncVaultReserves();
        emit Swap(msg.sender, tin, tout, amountIn, amountOut, feeWad);
    }

    /// @notice Free pool-token balance not counted as intentional raw book inventory.
    function _freeTokenBalance(address token) internal view returns (uint256 free) {
        uint256 bal = IERC20(token).balanceOf(address(this));
        if (_seOf(token) != address(0)) {
            // Buffered leg: free face balance is never book (SE shares are book).
            return bal;
        }
        uint256 book = Repo._layout().reserves[token];
        return bal > book ? bal - book : 0;
    }

    function _requirePretransferred(address token, uint256 amount) internal view {
        if (_freeTokenBalance(token) < amount) revert InsufficientPretransfer();
    }

    function _pullSeFunding(address token, uint256 amount) internal {
        // D49c: transferFrom if allowance, else Permit2 AllowanceTransfer
        uint256 allowance = IERC20(token).allowance(msg.sender, address(this));
        if (allowance >= amount) {
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        } else {
            IAllowanceTransfer(PERMIT2).transferFrom(msg.sender, address(this), uint160(amount), token);
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                              Permit2 / pull                            */
    /* ---------------------------------------------------------------------- */

    function _pullLegs(uint256 u0, uint256 u1, uint256 u2, bytes calldata permit2Data) internal {
        address t0 = token0();
        address t1 = token1();
        address t2 = token2();
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

    function _pullSingle(address token, uint256 amount, bytes calldata permit2Data) internal {
        uint8 mode = uint8(permit2Data[0]);
        if (permit2Data.length >= 32) {
            mode = abi.decode(permit2Data[:32], (uint8));
        }
        if (mode == 1) {
            IAllowanceTransfer(PERMIT2).transferFrom(msg.sender, address(this), uint160(amount), token);
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
        address[3] memory tokens = [token0(), token1(), token2()];
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
            IAllowanceTransfer(PERMIT2).transferFrom(msg.sender, address(this), uint160(u0), token0());
        }
        if (u1 > 0) {
            IAllowanceTransfer(PERMIT2).transferFrom(msg.sender, address(this), uint160(u1), token1());
        }
        if (u2 > 0) {
            IAllowanceTransfer(PERMIT2).transferFrom(msg.sender, address(this), uint160(u2), token2());
        }
    }
}
