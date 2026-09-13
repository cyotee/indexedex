// SPDX-License-Identifier: BSL-1.1
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
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {
    UniswapV4HookOwnerOnlyLiquidityLib
} from "contracts/hooks/uniswap/v4/libs/UniswapV4HookOwnerOnlyLiquidityLib.sol";
import {MultiStepOwnableRepo} from "@crane/contracts/access/ERC8023/MultiStepOwnableRepo.sol";
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
 * @title UniswapV4StandardExchangeOrbitalBufferHookCommon
 * @notice Product logic: IHooks + multipath LP + zap-in + SE In/Out + sphere settle on effective reserves.
 */
abstract contract UniswapV4StandardExchangeOrbitalBufferHookCommon {
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
    /// @notice B6: SE-share flag set on a raw (unbuffered) leg.
    error InvalidSeShareLeg();
    error InvalidRoute(address tokenIn, address tokenOut);
    error PairAndShareSameLeg();
    error FirstJoinMustBeFullBook();

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
    event DepositSingle(
        address indexed sender, address indexed to, address tokenIn, uint256 amountIn, uint256 shares
    );
    event ZapSwap(
        address indexed sender, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut
    );
    event ProtocolFeeMinted(address indexed feeTo, uint256 shares);
    event Swap(
        address indexed sender,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 feeWad
    );
    event DepositFlexible(
        address indexed provider,
        address indexed to,
        uint256 amount0,
        bool amount0IsSeShare,
        uint256 amount1,
        bool amount1IsSeShare,
        uint256 amount2,
        bool amount2IsSeShare,
        uint256 used0,
        uint256 used1,
        uint256 used2,
        uint256 shares
    );
    event WithdrawFlexible(
        address indexed provider,
        address indexed to,
        uint256 shares,
        bool receiveSeShare0,
        bool receiveSeShare1,
        bool receiveSeShare2,
        uint256 amount0,
        uint256 amount1,
        uint256 amount2
    );

    function token0() public view returns (address) {
        return Repo._layout().token0;
    }

    function token1() public view returns (address) {
        return Repo._layout().token1;
    }

    function token2() public view returns (address) {
        return Repo._layout().token2;
    }

    function isZapEligible() public view returns (bool) {
        if (_totalSupply() <= Repo.MINIMUM_LIQUIDITY) return false;
        return _isLive();
    }

    function isLive() public view returns (bool) {
        return _isLive();
    }

    function _isLive() internal view returns (bool) {
        Repo.Layout storage l = Repo._layout();
        return _legLive(l, 0) && _legLive(l, 1) && _legLive(l, 2);
    }

    function _legLive(Repo.Layout storage l, uint8 i) private view returns (bool) {
        address se = Repo._seAt(l, i);
        if (se == address(0)) return l.reserves[Repo._tokenAt(l, i)] > 0;
        return IERC20(se).balanceOf(address(this)) > 0;
    }

    /// @dev D89: owner may zap at MINIMUM_LIQUIDITY. Public still sees isZapEligible()==false.
    function _requireZapEligibleOrOwnerMin() internal view {
        if (isZapEligible()) return;
        if (_totalSupply() == Repo.MINIMUM_LIQUIDITY && msg.sender == MultiStepOwnableRepo._owner()) return;
        revert NotZapEligible();
    }

    modifier nonReentrant() {
        Repo.Layout storage l = Repo._layout();
        if (l.reentrancyStatus == Repo.ENTERED) revert Reentrancy();
        l.reentrancyStatus = Repo.ENTERED;
        _;
        l.reentrancyStatus = Repo.NOT_ENTERED;
    }

    modifier onlyLiquidityOwner() {
        UniswapV4HookOwnerOnlyLiquidityLib.enforce(Repo._layout().ownerOnlyLiquidity);
        _;
    }

    /* ---------------------------------------------------------------------- */
    /*                              bindings / views                          */
    /* ---------------------------------------------------------------------- */


    /* structs */
    struct SphereLegsWad {
        uint256 R;
        uint256 L2;
        uint256 xWad;
        uint256 yWad;
        uint256 zWad;
    }

    struct SwapLiveCtx {
        address tokenZ;
        uint256 feeWad;
        uint256 eOutNative;
    }

    struct SharesUsed {
        uint256 shares;
        uint256 used0;
        uint256 used1;
        uint256 used2;
    }

    struct DepositFlexibleVars {
        uint256 amount0;
        bool amount0IsSeShare;
        uint256 amount1;
        bool amount1IsSeShare;
        uint256 amount2;
        bool amount2IsSeShare;
        address to;
        uint256 sharesMin;
        uint256 used0;
        uint256 used1;
        uint256 used2;
        uint256 shares;
    }

    struct WithdrawFlexibleVars {
        uint256 shares;
        address to;
        bool receiveSeShare0;
        bool receiveSeShare1;
        bool receiveSeShare2;
        uint256 a0Min;
        uint256 a1Min;
        uint256 a2Min;
    }

    struct FlexScratch {
        uint256 o0;
        uint256 o1;
        uint256 o2;
        uint256 e0;
        uint256 e1;
        uint256 e2;
        uint256 supply;
    }

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

    struct ZapSimArgs {
        address tokenIn;
        uint256 saleJ;
        uint256 saleK;
        uint256 outJ;
        uint256 outK;
        uint256 a0;
        uint256 a1;
        uint256 a2;
        uint256 supply;
    }


    /* internals */
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


    function _decimalsOf(address token) internal view returns (uint8 d) {
        Repo.Layout storage l = Repo._layout();
        if (token == l.token0) d = l.decimals0;
        else if (token == l.token1) d = l.decimals1;
        else if (token == l.token2) d = l.decimals2;
        else revert InvalidPoolToken();
        // CREATE3 DETF may not exist at hook bind, so stored decimals can be 0.
        if (d == 0) d = 18;
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


    function _bufferToken(address token, uint256 amount) internal returns (uint256 seOut) {
        if (amount == 0) return 0;
        address se = _seOf(token);
        if (se == address(0)) {
            Repo._layout().reserves[token] += amount;
            return 0;
        }
        uint256 minOut;
        try IStandardExchangeIn(se).previewExchangeIn(IERC20(token), amount, IERC20(se))
            returns (uint256 m)
        {
            minOut = m > 0 ? m - 1 : 0;
        } catch {}
        IERC20(token).forceApprove(se, amount);
        seOut = IStandardExchangeIn(se).exchangeIn(
            IERC20(token), amount, IERC20(se), minOut, address(this), false, block.timestamp
        );
        IERC20(token).forceApprove(se, 0);
    }


    function _spendableSeShares(address token) internal view returns (uint256) {
        address se = _seOf(token);
        if (se == address(0)) return 0;
        uint256 seBal = IERC20(se).balanceOf(address(this));
        // Leave 1 wei so `_isLive` stays true. Keep-10 blocked owner last-exit unwrap.
        return seBal > 1 ? seBal - 1 : 0;
    }

    function _unwrapSeShares(address token, uint256 seIn) internal returns (uint256 pairOut) {
        if (seIn == 0) return 0;
        address se = _seOf(token);
        uint256 minOut;
        try IStandardExchangeIn(se).previewExchangeIn(IERC20(se), seIn, IERC20(token)) returns (uint256 m) {
            minOut = m > 0 ? m - 1 : 0;
        } catch {
            minOut = 0;
        }
        IERC20(se).forceApprove(se, seIn);
        pairOut = IStandardExchangeIn(se).exchangeIn(
            IERC20(se), seIn, IERC20(token), minOut, address(this), false, block.timestamp
        );
        IERC20(se).forceApprove(se, 0);
    }


    function _unwrapExactTokenOut(address token, uint256 amountOut) internal returns (uint256 seIn) {
        if (amountOut == 0) return 0;
        address se = _seOf(token);
        uint256 cap = _spendableSeShares(token);
        if (cap == 0) revert InsufficientTokenOut();
        seIn = ClaimLib.invertUnwrapExactTokenOut(se, token, amountOut);
        if (seIn > cap) {
            uint256 pairGot = _unwrapSeShares(token, cap);
            if (pairGot < amountOut) revert InsufficientTokenOut();
            return cap;
        }
        IERC20(se).forceApprove(se, seIn);
        uint256 got = IStandardExchangeOut(se).exchangeOut(
            IERC20(se), seIn, IERC20(token), amountOut, address(this), false, block.timestamp
        );
        IERC20(se).forceApprove(se, 0);
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


    function _swapExactInExecute(address tokenIn, address tokenOut, uint256 amountIn, uint256 feeWad)
        internal
        returns (uint256 amountOut)
    {
        _requireNonZero(amountIn);
        // L-FEE-3 / single-source: use the feeWad already loaded for this swap (do not re-fetch).
        amountOut = _previewSwapExactInWithFee(tokenIn, tokenOut, amountIn, feeWad);
        // Debit out inventory (unwrap if SE) before buffer-in (caller takes in then buffers)
        if (_seOf(tokenOut) != address(0)) {
            _unwrapExactTokenOut(tokenOut, amountOut);
        } else {
            uint256 rOut = Repo._layout().reserves[tokenOut];
            if (amountOut == 0 || amountOut >= rOut) revert Math.Drain();
            Repo._layout().reserves[tokenOut] = rOut - amountOut;
        }
        _requirePostUnderRadius();
    }


    function _swapExactOutExecute(address tokenIn, address tokenOut, uint256 amountOut, uint256 feeWad)
        internal
        returns (uint256 amountIn)
    {
        _requireNonZero(amountOut);
        // L-FEE-3 / single-source: use the feeWad already loaded for this swap (do not re-fetch).
        amountIn = _previewSwapExactOutWithFee(tokenIn, tokenOut, amountOut, feeWad);
        if (_seOf(tokenOut) != address(0)) {
            _unwrapExactTokenOut(tokenOut, amountOut);
        } else {
            uint256 rOut = Repo._layout().reserves[tokenOut];
            if (amountOut >= rOut) revert Math.Drain();
            Repo._layout().reserves[tokenOut] = rOut - amountOut;
        }
        _requirePostUnderRadius();
    }


    function _previewSwapExactIn(address tokenIn, address tokenOut, uint256 amountIn)
        internal
        view
        returns (uint256 amountOut)
    {
        SwapLiveCtx memory ctx = _loadSwapLiveCtx(tokenIn, tokenOut);
        return _previewSwapExactInWithFee(tokenIn, tokenOut, amountIn, ctx.feeWad);
    }


    function _previewSwapExactInWithFee(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 feeWad
    ) internal view returns (uint256 amountOut) {
        _requireNonZero(amountIn);
        if (feeWad >= Math.WAD) revert Math.MathDomain();
        SwapLiveCtx memory ctx = _loadSwapLiveCtxBook(tokenIn, tokenOut);
        ctx.feeWad = feeWad;

        uint256 dInNative = _faceInToEffectiveNative(tokenIn, amountIn);
        uint256 dxNet = Math.applyTradingFeeNet(_toWad(tokenIn, dInNative), ctx.feeWad);
        SphereLegsWad memory legs = _loadSphereLegs(tokenIn, tokenOut, ctx.tokenZ);
        uint256 dOutNative = _fromWadFloor(tokenOut, _sphereExactIn(legs, dxNet));
        amountOut = _effectiveOutToFaceOut(tokenOut, dOutNative);
        if (amountOut == 0 || amountOut >= ctx.eOutNative) revert Math.Drain();
    }


    function _previewSwapExactOut(address tokenIn, address tokenOut, uint256 amountOut)
        internal
        view
        returns (uint256 amountIn)
    {
        SwapLiveCtx memory ctx = _loadSwapLiveCtx(tokenIn, tokenOut);
        return _previewSwapExactOutWithFee(tokenIn, tokenOut, amountOut, ctx.feeWad);
    }


    function _previewSwapExactOutWithFee(
        address tokenIn,
        address tokenOut,
        uint256 amountOut,
        uint256 feeWad
    ) internal view returns (uint256 amountIn) {
        _requireNonZero(amountOut);
        if (feeWad >= Math.WAD) revert Math.MathDomain();
        SwapLiveCtx memory ctx = _loadSwapLiveCtxBook(tokenIn, tokenOut);
        ctx.feeWad = feeWad;
        if (amountOut >= ctx.eOutNative) revert Math.Drain();

        uint256 dOutNative = _faceOutToEffectiveNative(tokenOut, amountOut);
        SphereLegsWad memory legs = _loadSphereLegs(tokenIn, tokenOut, ctx.tokenZ);
        uint256 dyWad = _toWad(tokenOut, dOutNative);
        uint256 dxNet = _sphereExactOut(legs, dyWad);
        uint256 dInNative = _fromWadCeil(tokenIn, Math.grossUpExactOut(dxNet, ctx.feeWad));
        amountIn = _effectiveInToFaceIn(tokenIn, dInNative);
        _requireNonZero(amountIn);
    }


    function _loadSwapLiveCtx(address tokenIn, address tokenOut)
        private
        view
        returns (SwapLiveCtx memory ctx)
    {
        ctx = _loadSwapLiveCtxBook(tokenIn, tokenOut);
        ctx.feeWad = _feeOracle().dexSwapFeeOfVault(address(this));
        if (ctx.feeWad >= Math.WAD) revert Math.MathDomain();
    }


    function _loadSwapLiveCtxBook(address tokenIn, address tokenOut)
        private
        view
        returns (SwapLiveCtx memory ctx)
    {
        Repo.Layout storage l = Repo._layout();
        if (l.R == 0) revert NotLive();
        uint256 eIn = _effectiveNativeOf(tokenIn);
        ctx.eOutNative = _effectiveNativeOf(tokenOut);
        if (eIn == 0 || ctx.eOutNative == 0) revert NotLive();
        ctx.tokenZ = _witnessAndLegs(tokenIn, tokenOut);
    }


    function _loadSphereLegs(address tokenIn, address tokenOut, address tokenZ)
        private
        view
        returns (SphereLegsWad memory s)
    {
        Repo.Layout storage l = Repo._layout();
        s.R = l.R;
        s.L2 = l.L_SQUARED;
        s.xWad = _toWad(tokenIn, _effectiveNativeOf(tokenIn));
        s.yWad = _toWad(tokenOut, _effectiveNativeOf(tokenOut));
        s.zWad = _toWad(tokenZ, _effectiveNativeOf(tokenZ));
    }


    function _sphereExactIn(SphereLegsWad memory s, uint256 dxNet)
        private
        pure
        returns (uint256 dyWad)
    {
        return Math.sphereExactInOutWad(s.R, s.L2, s.xWad, s.yWad, s.zWad, dxNet);
    }


    function _sphereExactOut(SphereLegsWad memory s, uint256 dyWad)
        private
        pure
        returns (uint256 dxNet)
    {
        return Math.sphereExactOutInNetWad(s.R, s.L2, s.xWad, s.yWad, s.zWad, dyWad);
    }


    function _faceInToEffectiveNative(address tokenIn, uint256 amountIn)
        private
        view
        returns (uint256 dInNative)
    {
        dInNative = amountIn;
        address se = _seOf(tokenIn);
        if (se != address(0)) {
            dInNative = ClaimLib.previewBufferClaimIn(se, _rpOf(tokenIn), tokenIn, amountIn, address(this));
            if (dInNative == 0) revert ZeroAmount();
        }
    }


    function _effectiveOutToFaceOut(address tokenOut, uint256 dOutNative)
        private
        view
        returns (uint256 amountOut)
    {
        address se = _seOf(tokenOut);
        if (se != address(0)) {
            (amountOut,) = ClaimLib.previewUnwrapForEffectiveOut(se, _rpOf(tokenOut), tokenOut, dOutNative);
        } else {
            amountOut = dOutNative;
        }
    }


    function _faceOutToEffectiveNative(address tokenOut, uint256 amountOut)
        private
        view
        returns (uint256 dOutNative)
    {
        dOutNative = amountOut;
        address se = _seOf(tokenOut);
        if (se == address(0)) return dOutNative;
        uint256 shares = ClaimLib.invertUnwrapExactTokenOut(se, tokenOut, amountOut);
        address rp = _rpOf(tokenOut);
        if (rp != address(0)) {
            dOutNative = (shares * ClaimLib.getRateFailClosed(rp)) / 1e18;
        } else {
            dOutNative = ClaimLib.seClaimOf(se, tokenOut, shares);
        }
    }


    function _effectiveInToFaceIn(address tokenIn, uint256 dInNative)
        private
        view
        returns (uint256 amountIn)
    {
        if (_seOf(tokenIn) != address(0)) {
            amountIn = _invertBufferForEffective(tokenIn, dInNative);
        } else {
            amountIn = dInNative;
        }
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


    function _computeAdd(uint256 a0Max, uint256 a1Max, uint256 a2Max, uint256 supply)
        internal
        view
        returns (uint256 shares, uint256 used0, uint256 used1, uint256 used2)
    {
        if (supply == 0) {
            return _computeFirstMint(a0Max, a1Max, a2Max);
        }
        (uint256 e0, uint256 e1, uint256 e2) = _effectiveWad();
        // Live 3-positive book still accepts 1- or 2-leg residual joins via partial
        // NAV (R19 leftover pair/SE). Full-book is only when every leg is offered.
        if (e0 > 0 && e1 > 0 && e2 > 0 && a0Max > 0 && a1Max > 0 && a2Max > 0) {
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
        shares = Math.firstMintShares(_sumFaceEffectiveWad(used0, used1, used2));
    }


    function _computeFullBook(uint256 a0Max, uint256 a1Max, uint256 a2Max, uint256 supply)
        internal
        view
        returns (uint256 shares, uint256 used0, uint256 used1, uint256 used2)
    {
        if (a0Max == 0 || a1Max == 0 || a2Max == 0) revert FullBookRequiresThreeLegs();
        SharesUsed memory r = _fullBookSharesUsed(a0Max, a1Max, a2Max, supply);
        shares = r.shares;
        used0 = r.used0;
        used1 = r.used1;
        used2 = r.used2;
    }


    function _computePartial(uint256 a0Max, uint256 a1Max, uint256 a2Max, uint256 supply)
        internal
        view
        returns (uint256 shares, uint256 used0, uint256 used1, uint256 used2)
    {
        (a0Max, a1Max, a2Max) = _capFaceUnderRadius(a0Max, a1Max, a2Max);
        if (a0Max == 0 && a1Max == 0 && a2Max == 0) revert ZeroAmount();
        SharesUsed memory r = _partialSharesUsed(a0Max, a1Max, a2Max, supply);
        shares = r.shares;
        used0 = r.used0;
        used1 = r.used1;
        used2 = r.used2;
    }

    /// @dev Single-sided leftover must stay strictly inside R (same gate as `_requirePostUnderRadius`).
    function _capFaceUnderRadius(uint256 a0, uint256 a1, uint256 a2)
        private
        view
        returns (uint256, uint256, uint256)
    {
        Repo.Layout storage l = Repo._layout();
        if (l.R == 0) return (a0, a1, a2);
        (uint256 e0, uint256 e1, uint256 e2) = _effectiveWad();
        a0 = _capOneFaceUnderRadius(l.token0, a0, e0, l.R);
        a1 = _capOneFaceUnderRadius(l.token1, a1, e1, l.R);
        a2 = _capOneFaceUnderRadius(l.token2, a2, e2, l.R);
        return (a0, a1, a2);
    }

    function _capOneFaceUnderRadius(address token, uint256 face, uint256 eWad, uint256 R)
        private
        view
        returns (uint256)
    {
        if (face == 0) return 0;
        if (eWad + 1 >= R) return 0;
        uint256 roomFace = _fromWadFloor(token, R - eWad - 1);
        return face > roomFace ? roomFace : face;
    }


    function _previewClaimInAt(uint8 i, uint256 faceAmount) private view returns (uint256) {
        if (faceAmount == 0) return 0;
        Repo.Layout storage l = Repo._layout();
        address se = Repo._seAt(l, i);
        if (se == address(0)) return faceAmount;
        return ClaimLib.previewBufferClaimIn(
            se, Repo._rpAt(l, i), Repo._tokenAt(l, i), faceAmount, address(this)
        );
    }


    function _sumFaceEffectiveWad(uint256 a0, uint256 a1, uint256 a2)
        private
        view
        returns (uint256 sumWad)
    {
        Repo.Layout storage l = Repo._layout();
        sumWad = _toWad(l.token0, _previewClaimInAt(0, a0));
        sumWad += _toWad(l.token1, _previewClaimInAt(1, a1));
        sumWad += _toWad(l.token2, _previewClaimInAt(2, a2));
    }


    function _fullBookSharesUsed(uint256 a0Max, uint256 a1Max, uint256 a2Max, uint256 supply)
        private
        view
        returns (SharesUsed memory r)
    {
        (uint256 e0, uint256 e1, uint256 e2) = _effectiveWad();
        Math.FullBookArgs memory fb;
        fb.a0Wad = _toWad(Repo._layout().token0, _previewClaimInAt(0, a0Max));
        fb.a1Wad = _toWad(Repo._layout().token1, _previewClaimInAt(1, a1Max));
        fb.a2Wad = _toWad(Repo._layout().token2, _previewClaimInAt(2, a2Max));
        fb.e0Wad = e0;
        fb.e1Wad = e1;
        fb.e2Wad = e2;
        fb.supply = supply;
        r.shares = Math.fullBookShares(fb);
        r.used0 = _effectiveUsedWadToFace(0, Math.fullBookUsedWad(r.shares, e0, supply));
        r.used1 = _effectiveUsedWadToFace(1, Math.fullBookUsedWad(r.shares, e1, supply));
        r.used2 = _effectiveUsedWadToFace(2, Math.fullBookUsedWad(r.shares, e2, supply));
        if (r.used0 == 0 || r.used1 == 0 || r.used2 == 0) revert ZeroAmount();
    }


    function _partialSharesUsed(uint256 a0Max, uint256 a1Max, uint256 a2Max, uint256 supply)
        private
        view
        returns (SharesUsed memory r)
    {
        uint256 e0n = _effectiveNativeAt(0);
        uint256 e1n = _effectiveNativeAt(1);
        uint256 e2n = _effectiveNativeAt(2);
        (r.used0, r.used1, r.used2) = _partialUsed(a0Max, a1Max, a2Max, e0n, e1n, e2n);
        Math.SphereNavArgs memory nav;
        nav.supply = supply;
        nav.R = Repo._layout().R;
        nav.r0Wad = _toWad(Repo._layout().token0, e0n);
        nav.r1Wad = _toWad(Repo._layout().token1, e1n);
        nav.r2Wad = _toWad(Repo._layout().token2, e2n);
        nav.used0Wad = _toWad(Repo._layout().token0, r.used0);
        nav.used1Wad = _toWad(Repo._layout().token1, r.used1);
        nav.used2Wad = _toWad(Repo._layout().token2, r.used2);
        r.shares = Math.sphereNavShares(nav);
    }


    function _effectiveUsedWadToFace(uint8 i, uint256 usedWad) private view returns (uint256 face) {
        Repo.Layout storage l = Repo._layout();
        address token = Repo._tokenAt(l, i);
        face = _fromWadFloor(token, usedWad);
        if (Repo._seAt(l, i) != address(0)) {
            face = _invertBufferForEffective(token, face);
        }
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
        bytes memory permit2Data
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

        (a0, a1, a2) = _burnAndPay(shares, to, a0, a1, a2);
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


    function _burnAndPay(uint256 shares, address to, uint256 a0, uint256 a1, uint256 a2)
        private
        returns (uint256, uint256, uint256)
    {
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
        return (a0, a1, a2);
    }


    function _depositFlexible(DepositFlexibleVars memory v, uint256 deadline)
        internal
        returns (uint256 shares, uint256 used0, uint256 used1, uint256 used2)
    {
        // Pure pair path: reuse existing multipath deposit (empty Permit2 = transferFrom).
        if (!v.amount0IsSeShare && !v.amount1IsSeShare && !v.amount2IsSeShare) {
            bytes memory emptyPermit2;
            (shares, used0, used1, used2) = _addLiquidity(
                v.amount0, v.amount1, v.amount2, v.to, v.sharesMin, deadline, emptyPermit2
            );
            v.used0 = used0;
            v.used1 = used1;
            v.used2 = used2;
            v.shares = shares;
            _emitDepositFlexible(v);
            return (shares, used0, used1, used2);
        }

        _requireDeadline(deadline);
        if (v.to == address(0)) revert ZeroAddress();
        _validateSeShareFlags(v.amount0IsSeShare, v.amount1IsSeShare, v.amount2IsSeShare);

        _maybeMintProtocolFee();
        uint256 supply = _totalSupply();
        _fillComputeAddFlexible(v, supply);
        if (v.shares < v.sharesMin) revert InsufficientSharesOut();

        _pullFlexible(v);
        _bufferFlexibleUsed(v);
        _applyAdd(supply, v.shares, v.used0, v.used1, v.used2, v.to);
        _refundConservation(msg.sender);
        _emitDepositFlexible(v);
        return (v.shares, v.used0, v.used1, v.used2);
    }


    function _emitDepositFlexible(DepositFlexibleVars memory v) private {
        emit DepositFlexible(
            msg.sender,
            v.to,
            v.amount0,
            v.amount0IsSeShare,
            v.amount1,
            v.amount1IsSeShare,
            v.amount2,
            v.amount2IsSeShare,
            v.used0,
            v.used1,
            v.used2,
            v.shares
        );
    }


    function _withdrawFlexible(WithdrawFlexibleVars memory w, uint256 deadline)
        internal
        returns (uint256 a0, uint256 a1, uint256 a2)
    {
        if (!w.receiveSeShare0 && !w.receiveSeShare1 && !w.receiveSeShare2) {
            (a0, a1, a2) =
                _removeLiquidity(w.shares, w.to, w.a0Min, w.a1Min, w.a2Min, deadline);
            emit WithdrawFlexible(msg.sender, w.to, w.shares, false, false, false, a0, a1, a2);
            return (a0, a1, a2);
        }

        _requireDeadline(deadline);
        _requireNonZero(w.shares);
        if (w.to == address(0)) revert ZeroAddress();
        _validateSeShareFlags(w.receiveSeShare0, w.receiveSeShare1, w.receiveSeShare2);

        _maybeMintProtocolFee();
        if (w.shares > _balanceOf(msg.sender)) revert InsufficientSharesOut();

        (a0, a1, a2) = _proRataOutFlexible(
            w.shares, w.receiveSeShare0, w.receiveSeShare1, w.receiveSeShare2
        );
        if (a0 < w.a0Min || a1 < w.a1Min || a2 < w.a2Min) revert InsufficientTokenOut();

        _burnAndPayFlexible(w.shares, w.to, w.receiveSeShare0, w.receiveSeShare1, w.receiveSeShare2);
        emit WithdrawFlexible(
            msg.sender,
            w.to,
            w.shares,
            w.receiveSeShare0,
            w.receiveSeShare1,
            w.receiveSeShare2,
            a0,
            a1,
            a2
        );
    }


    function _previewDepositFlexible(DepositFlexibleVars memory v)
        internal
        view
        returns (uint256 shares, uint256 used0, uint256 used1, uint256 used2)
    {
        if (!v.amount0IsSeShare && !v.amount1IsSeShare && !v.amount2IsSeShare) {
            return _previewAddLiquidity(v.amount0, v.amount1, v.amount2);
        }
        _validateSeShareFlags(v.amount0IsSeShare, v.amount1IsSeShare, v.amount2IsSeShare);
        (, uint256 supplyAfter) = _previewProtocolMintShares();
        _fillComputeAddFlexible(v, supplyAfter);
        return (v.shares, v.used0, v.used1, v.used2);
    }


    function _previewWithdrawFlexible(
        uint256 shares_,
        bool receiveSeShare0,
        bool receiveSeShare1,
        bool receiveSeShare2
    ) internal view returns (uint256 a0, uint256 a1, uint256 a2) {
        if (!receiveSeShare0 && !receiveSeShare1 && !receiveSeShare2) {
            return _previewRemoveLiquidity(shares_);
        }
        _requireNonZero(shares_);
        _validateSeShareFlags(receiveSeShare0, receiveSeShare1, receiveSeShare2);
        (uint256 protocolLp, uint256 supplyAfter) = _previewProtocolMintShares();
        protocolLp;
        return _proRataOutFlexibleAtSupply(
            shares_, supplyAfter, receiveSeShare0, receiveSeShare1, receiveSeShare2
        );
    }


    function _validateSeShareFlags(bool f0, bool f1, bool f2) private view {
        Repo.Layout storage l = Repo._layout();
        if (f0 && l.se0 == address(0)) revert InvalidSeShareLeg();
        if (f1 && l.se1 == address(0)) revert InvalidSeShareLeg();
        if (f2 && l.se2 == address(0)) revert InvalidSeShareLeg();
    }


    function _offeredEffectiveNative(uint8 i, uint256 amount, bool isSeShare)
        private
        view
        returns (uint256)
    {
        if (amount == 0) return 0;
        Repo.Layout storage l = Repo._layout();
        address se = Repo._seAt(l, i);
        address token = Repo._tokenAt(l, i);
        address rp = Repo._rpAt(l, i);
        if (isSeShare) {
            if (rp != address(0)) {
                return (amount * ClaimLib.getRateFailClosed(rp)) / 1e18;
            }
            return ClaimLib.seClaimOf(se, token, amount);
        }
        return _previewClaimInAt(i, amount);
    }


    function _fillComputeAddFlexible(DepositFlexibleVars memory v, uint256 supply) private view {
        FlexScratch memory s;
        s.supply = supply;
        s.o0 = _offeredEffectiveNative(0, v.amount0, v.amount0IsSeShare);
        s.o1 = _offeredEffectiveNative(1, v.amount1, v.amount1IsSeShare);
        s.o2 = _offeredEffectiveNative(2, v.amount2, v.amount2IsSeShare);

        if (supply == 0) {
            _fillFirstMintFlexible(v, s);
            return;
        }

        (s.e0, s.e1, s.e2) = _effectiveWad();
        if (
            s.e0 > 0 && s.e1 > 0 && s.e2 > 0 && v.amount0 > 0 && v.amount1 > 0 && v.amount2 > 0
        ) {
            _fillFullBookFlexible(v, s);
            return;
        }

        if (Repo._layout().R == 0) revert NotLive();
        if (!v.amount0IsSeShare && !v.amount1IsSeShare && !v.amount2IsSeShare) {
            (v.amount0, v.amount1, v.amount2) = _capFaceUnderRadius(v.amount0, v.amount1, v.amount2);
            if (v.amount0 == 0 && v.amount1 == 0 && v.amount2 == 0) revert ZeroAmount();
            s.o0 = _offeredEffectiveNative(0, v.amount0, false);
            s.o1 = _offeredEffectiveNative(1, v.amount1, false);
            s.o2 = _offeredEffectiveNative(2, v.amount2, false);
        }
        _fillPartialFlexible(v, s);
    }


    function _fillFirstMintFlexible(DepositFlexibleVars memory v, FlexScratch memory s)
        private
        view
    {
        uint256 nPos;
        if (v.amount0 > 0) nPos++;
        if (v.amount1 > 0) nPos++;
        if (v.amount2 > 0) nPos++;
        if (nPos < 2) revert FirstMintRequiresTwoLegs();
        v.used0 = v.amount0;
        v.used1 = v.amount1;
        v.used2 = v.amount2;
        Repo.Layout storage l = Repo._layout();
        v.shares = Math.firstMintShares(
            _toWad(l.token0, s.o0) + _toWad(l.token1, s.o1) + _toWad(l.token2, s.o2)
        );
    }


    function _fillFullBookFlexible(DepositFlexibleVars memory v, FlexScratch memory s)
        private
        view
    {
        if (v.amount0 == 0 || v.amount1 == 0 || v.amount2 == 0) revert FullBookRequiresThreeLegs();
        if (s.o0 == 0 || s.o1 == 0 || s.o2 == 0) revert ZeroAmount();
        v.shares = _fullBookSharesFromOffered(s);
        if (v.shares == 0) revert ZeroAmount();
        v.used0 = _mapUsedInput(v.amount0, s.o0, 0, v.shares, s.e0, s.supply);
        v.used1 = _mapUsedInput(v.amount1, s.o1, 1, v.shares, s.e1, s.supply);
        v.used2 = _mapUsedInput(v.amount2, s.o2, 2, v.shares, s.e2, s.supply);
        if (v.used0 == 0 || v.used1 == 0 || v.used2 == 0) revert ZeroAmount();
    }


    function _fullBookSharesFromOffered(FlexScratch memory s) private view returns (uint256 shares_) {
        Repo.Layout storage l = Repo._layout();
        shares_ = (_toWad(l.token0, s.o0) * s.supply) / s.e0;
        uint256 s1 = (_toWad(l.token1, s.o1) * s.supply) / s.e1;
        if (s1 < shares_) shares_ = s1;
        uint256 s2 = (_toWad(l.token2, s.o2) * s.supply) / s.e2;
        if (s2 < shares_) shares_ = s2;
    }


    function _mapUsedInput(
        uint256 amount,
        uint256 offeredEff,
        uint8 i,
        uint256 shares_,
        uint256 eWad,
        uint256 supply
    ) private view returns (uint256 used) {
        address token = Repo._tokenAt(Repo._layout(), i);
        uint256 uEff = _fromWadFloor(token, Math.fullBookUsedWad(shares_, eWad, supply));
        used = (amount * uEff) / offeredEff;
    }


    function _fillPartialFlexible(DepositFlexibleVars memory v, FlexScratch memory s) private view {
        uint256 e0n = _effectiveNativeAt(0);
        uint256 e1n = _effectiveNativeAt(1);
        uint256 e2n = _effectiveNativeAt(2);
        (uint256 u0, uint256 u1, uint256 u2) = _partialUsed(s.o0, s.o1, s.o2, e0n, e1n, e2n);
        v.shares = _partialNavShares(s.supply, e0n, e1n, e2n, u0, u1, u2);
        v.used0 = s.o0 > 0 ? (v.amount0 * u0) / s.o0 : 0;
        v.used1 = s.o1 > 0 ? (v.amount1 * u1) / s.o1 : 0;
        v.used2 = s.o2 > 0 ? (v.amount2 * u2) / s.o2 : 0;
    }


    function _partialNavShares(
        uint256 supply,
        uint256 e0n,
        uint256 e1n,
        uint256 e2n,
        uint256 u0,
        uint256 u1,
        uint256 u2
    ) private view returns (uint256) {
        Math.SphereNavArgs memory nav;
        nav.supply = supply;
        nav.R = Repo._layout().R;
        Repo.Layout storage l = Repo._layout();
        nav.r0Wad = _toWad(l.token0, e0n);
        nav.r1Wad = _toWad(l.token1, e1n);
        nav.r2Wad = _toWad(l.token2, e2n);
        nav.used0Wad = _toWad(l.token0, u0);
        nav.used1Wad = _toWad(l.token1, u1);
        nav.used2Wad = _toWad(l.token2, u2);
        return Math.sphereNavShares(nav);
    }


    function _pullFlexible(DepositFlexibleVars memory v) private {
        Repo.Layout storage l = Repo._layout();
        if (v.used0 > 0) {
            address t0 = v.amount0IsSeShare ? l.se0 : l.token0;
            IERC20(t0).safeTransferFrom(msg.sender, address(this), v.used0);
        }
        if (v.used1 > 0) {
            address t1 = v.amount1IsSeShare ? l.se1 : l.token1;
            IERC20(t1).safeTransferFrom(msg.sender, address(this), v.used1);
        }
        if (v.used2 > 0) {
            address t2 = v.amount2IsSeShare ? l.se2 : l.token2;
            IERC20(t2).safeTransferFrom(msg.sender, address(this), v.used2);
        }
    }


    function _bufferFlexibleUsed(DepositFlexibleVars memory v) private {
        if (!v.amount0IsSeShare && v.used0 > 0) _bufferToken(Repo._layout().token0, v.used0);
        if (!v.amount1IsSeShare && v.used1 > 0) _bufferToken(Repo._layout().token1, v.used1);
        if (!v.amount2IsSeShare && v.used2 > 0) _bufferToken(Repo._layout().token2, v.used2);
    }


    function _proRataOutFlexible(
        uint256 shares,
        bool receiveSeShare0,
        bool receiveSeShare1,
        bool receiveSeShare2
    ) private view returns (uint256 a0, uint256 a1, uint256 a2) {
        return _proRataOutFlexibleAtSupply(
            shares, _totalSupply(), receiveSeShare0, receiveSeShare1, receiveSeShare2
        );
    }


    function _proRataOutFlexibleAtSupply(
        uint256 shares,
        uint256 supply,
        bool receiveSeShare0,
        bool receiveSeShare1,
        bool receiveSeShare2
    ) private view returns (uint256 a0, uint256 a1, uint256 a2) {
        Repo.Layout storage l = Repo._layout();
        if (l.se0 == address(0)) {
            a0 = (shares * l.reserves[l.token0]) / supply;
        } else {
            uint256 seOut = (shares * IERC20(l.se0).balanceOf(address(this))) / supply;
            a0 = receiveSeShare0 ? seOut : ClaimLib.previewUnwrapShares(l.se0, l.token0, seOut);
        }
        if (l.se1 == address(0)) {
            a1 = (shares * l.reserves[l.token1]) / supply;
        } else {
            uint256 seOut = (shares * IERC20(l.se1).balanceOf(address(this))) / supply;
            a1 = receiveSeShare1 ? seOut : ClaimLib.previewUnwrapShares(l.se1, l.token1, seOut);
        }
        if (l.se2 == address(0)) {
            a2 = (shares * l.reserves[l.token2]) / supply;
        } else {
            uint256 seOut = (shares * IERC20(l.se2).balanceOf(address(this))) / supply;
            a2 = receiveSeShare2 ? seOut : ClaimLib.previewUnwrapShares(l.se2, l.token2, seOut);
        }
    }


    function _burnAndPayFlexible(
        uint256 shares,
        address to,
        bool receiveSeShare0,
        bool receiveSeShare1,
        bool receiveSeShare2
    ) private {
        Repo.Layout storage l = Repo._layout();
        uint256 supply = _totalSupply();
        _burnLp(msg.sender, shares);

        _payFlexibleLeg(0, shares, supply, to, receiveSeShare0);
        _payFlexibleLeg(1, shares, supply, to, receiveSeShare1);
        _payFlexibleLeg(2, shares, supply, to, receiveSeShare2);

        if (_totalSupply() == 0) {
            l.L_SQUARED = 0;
        } else {
            _recomputeL2();
        }
        _snapshotKLastIfFeeOn();
        _refundConservation(msg.sender);
        _syncVaultReserves();
    }


    function _payFlexibleLeg(
        uint8 i,
        uint256 shares,
        uint256 supply,
        address to,
        bool receiveSeShare
    ) private {
        Repo.Layout storage l = Repo._layout();
        address se = Repo._seAt(l, i);
        address token = Repo._tokenAt(l, i);
        if (se == address(0)) {
            uint256 amt = (shares * l.reserves[token]) / supply;
            l.reserves[token] -= amt;
            if (amt > 0) IERC20(token).safeTransfer(to, amt);
            return;
        }
        uint256 seOut = (shares * IERC20(se).balanceOf(address(this))) / supply;
        if (seOut == 0) return;
        if (receiveSeShare) {
            IERC20(se).safeTransfer(to, seOut);
        } else {
            uint256 pairOut = _unwrapSeShares(token, seOut);
            if (pairOut > 0) IERC20(token).safeTransfer(to, pairOut);
        }
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
        _requireZapEligibleOrOwnerMin();
        if (!_isBound(tokenIn)) revert InvalidPoolToken();

        _maybeMintProtocolFee();
        ZapPlan memory plan = _planZap(tokenIn, amountIn);
        if (plan.shares < sharesMin) revert InsufficientSharesOut();

        _pullTokenIn(tokenIn, amountIn, permit2Data);
        return _executeDepositSinglePlan(tokenIn, amountIn, to, plan);
    }

    /// @dev Zap-in when `amountIn` of `tokenIn` is already on the hook (joinSingleAsset SE unwrap).
    function _depositSingleFromBalance(
        address tokenIn,
        uint256 amountIn,
        address to,
        uint256 sharesMin,
        uint256 deadline
    ) internal returns (uint256 shares) {
        _requireDeadline(deadline);
        _requireNonZero(amountIn);
        if (to == address(0)) revert ZeroAddress();
        _requireZapEligibleOrOwnerMin();
        if (!_isBound(tokenIn)) revert InvalidPoolToken();

        _maybeMintProtocolFee();
        ZapPlan memory plan = _planZap(tokenIn, amountIn);
        if (plan.shares < sharesMin) revert InsufficientSharesOut();
        return _executeDepositSinglePlan(tokenIn, amountIn, to, plan);
    }

    function _executeDepositSinglePlan(
        address tokenIn,
        uint256 amountIn,
        address to,
        ZapPlan memory plan
    ) private returns (uint256 shares) {
        _executeZapSwaps(tokenIn, plan);
        uint256 supplyBefore = _totalSupply();
        _bufferLastUsed(plan.used0, plan.used1, plan.used2);
        _applyAdd(supplyBefore, plan.shares, plan.used0, plan.used1, plan.used2, to);
        shares = plan.shares;
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
        // Single-source fee with zap plan (do not re-fetch oracle fee inside preview).
        amountOut = _previewSwapExactInWithFee(tokenIn, tokenOut, amountIn, feeWad);
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


    function _planZap(address tokenIn, uint256 amountIn) internal view returns (ZapPlan memory p) {
        _requireZapEligibleOrOwnerMin();
        if (!_isBound(tokenIn)) revert InvalidPoolToken();
        _requireNonZero(amountIn);

        Repo.Layout storage l = Repo._layout();
        p.inIdx = Repo._indexOf(l, tokenIn);
        (p.j, p.k) = _otherIdx(p.inIdx);

        // Close rejoin can return more DETF than remaining book. A 3-leg ratio zap
        // would drain pair SE (MathDomain). Use single-sided only when an other
        // leg is small vs amountIn (live depositClaim/Policy mint stays ratio zap).
        uint256 eIn = _effectiveNativeOf(tokenIn);
        if (eIn > 0 && amountIn > eIn && _ratioZapWouldDrain(p.inIdx, amountIn)) {
            return _singleSidedPlan(tokenIn, amountIn);
        }

        _fillZapSales(p, tokenIn, amountIn);
        _fillZapOuts(p, tokenIn);
        _fillZapShares(p, tokenIn);
    }

    function _ratioZapWouldDrain(uint8 inIdx, uint256 amountIn) private view returns (bool) {
        (uint8 j, uint8 k) = _otherIdx(inIdx);
        uint256 quarter = amountIn / 4;
        return _effectiveNativeAt(j) < quarter || _effectiveNativeAt(k) < quarter;
    }

    function _singleSidedPlan(address tokenIn, uint256 amountIn) private view returns (ZapPlan memory p) {
        Repo.Layout storage l = Repo._layout();
        p.inIdx = Repo._indexOf(l, tokenIn);
        (p.j, p.k) = _otherIdx(p.inIdx);
        p.residual = amountIn;
        uint256 a0;
        uint256 a1;
        uint256 a2;
        if (p.inIdx == 0) a0 = amountIn;
        else if (p.inIdx == 1) a1 = amountIn;
        else a2 = amountIn;
        (, uint256 supplyAfter) = _previewProtocolMintShares();
        (p.shares, p.used0, p.used1, p.used2) = _computePartial(a0, a1, a2, supplyAfter);
    }


    function _runZapSplit(address tokenIn, uint256 amountIn, uint8 inIdx)
        private
        view
        returns (Math.ZapSplitResult memory z)
    {
        Math.ZapSplitArgs memory a;
        (a.e0, a.e1, a.e2) = _effectiveWad();
        Repo.Layout storage l = Repo._layout();
        a.R = l.R;
        a.L2 = l.L_SQUARED;
        a.feeWad = _feeOracle().dexSwapFeeOfVault(address(this));
        a.inIdx = inIdx;
        a.amountInWad = _toWad(tokenIn, amountIn);
        return Math.zapSplitWad(a);
    }


    function _fillZapSales(ZapPlan memory p, address tokenIn, uint256 amountIn) private view {
        Math.ZapSplitResult memory z = _runZapSplit(tokenIn, amountIn, p.inIdx);
        p.saleJ = _fromWadCeil(tokenIn, z.sJWad);
        p.saleK = _fromWadCeil(tokenIn, z.sKWad);
        if (p.saleJ + p.saleK > amountIn) {
            p.saleJ = _fromWadFloor(tokenIn, z.sJWad);
            p.saleK = _fromWadFloor(tokenIn, z.sKWad);
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
        // Stash algebraic aJ for raw-leg preference in _fillZapOuts via residual field? keep on stack via z.aJWad call below.
        // Apply algebraic outJ preference for raw (non-SE) j inside this frame while z is live.
        p.outJ = z.aJWad; // temporary: WAD out; converted in _fillZapOuts if non-SE
    }


    function _fillZapOuts(ZapPlan memory p, address tokenIn) private view {
        Repo.Layout storage l = Repo._layout();
        address tokenJ = Repo._tokenAt(l, p.j);
        address tokenK = Repo._tokenAt(l, p.k);

        uint256 algJWad = p.outJ; // stashed WAD from _fillZapSales
        p.outJ = p.saleJ > 0 ? _previewSwapExactIn(tokenIn, tokenJ, p.saleJ) : 0;
        p.outK = p.saleK > 0 ? _previewZapSecondLegEffective(tokenIn, tokenJ, tokenK, p.saleJ, p.saleK) : 0;

        if (algJWad > 0 && _seOf(tokenJ) == address(0)) {
            uint256 algJ = _fromWadFloor(tokenJ, algJWad);
            if (algJ > 0) p.outJ = algJ;
        }
    }


    function _fillZapShares(ZapPlan memory p, address tokenIn) private view {
        (uint256 a0, uint256 a1, uint256 a2) =
            _zapAmountsToBinding(p.inIdx, p.j, p.residual, p.outJ, p.outK);
        (, uint256 supplyAfter) = _previewProtocolMintShares();
        ZapSimArgs memory sim;
        sim.tokenIn = tokenIn;
        sim.saleJ = p.saleJ;
        sim.saleK = p.saleK;
        sim.outJ = p.outJ;
        sim.outK = p.outK;
        sim.a0 = a0;
        sim.a1 = a1;
        sim.a2 = a2;
        sim.supply = supplyAfter;
        SharesUsed memory r = _computeAddAfterSimulatedZapEffective(sim);
        p.shares = r.shares;
        p.used0 = r.used0;
        p.used1 = r.used1;
        p.used2 = r.used2;
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


    function _previewZapSecondLegEffective(
        address tokenIn,
        address tokenJ,
        address tokenK,
        uint256 saleJ,
        uint256 saleK
    ) private view returns (uint256 outK) {
        uint256 feeWad = _feeOracle().dexSwapFeeOfVault(address(this));
        SphereLegsWad memory legs = _sphereLegsAfterFirstZapLeg(tokenIn, tokenJ, tokenK, saleJ);

        uint256 dIn1 = _dInNative(tokenIn, saleK);
        uint256 dxNet = Math.applyTradingFeeNet(_toWad(tokenIn, dIn1), feeWad);
        // Map effective out WAD → face out (raw floor, or SE unwrap of that effective)
        outK = _effectiveWadOutToFace(tokenK, _sphereExactIn(legs, dxNet));
    }


    function _sphereLegsAfterFirstZapLeg(
        address tokenIn,
        address tokenJ,
        address tokenK,
        uint256 saleJ
    ) private view returns (SphereLegsWad memory legs) {
        uint256 eInN = _effectiveNativeOf(tokenIn);
        uint256 eJN = _effectiveNativeOf(tokenJ);
        uint256 eKN = _effectiveNativeOf(tokenK);

        eInN += _dInNative(tokenIn, saleJ);
        eJN -= _dOutNativeDebit(tokenJ, _previewSwapExactIn(tokenIn, tokenJ, saleJ));
        if (eJN == 0 || eInN == 0) revert Math.MathDomain();

        legs.R = Repo._layout().R;
        legs.xWad = _toWad(tokenIn, eInN);
        legs.yWad = _toWad(tokenK, eKN);
        legs.zWad = _toWad(tokenJ, eJN);
        legs.L2 = Math.recomputeL2(legs.R, legs.xWad, legs.zWad, legs.yWad);
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


    function _computeAddAfterSimulatedZapEffective(ZapSimArgs memory s)
        private
        view
        returns (SharesUsed memory r)
    {
        Repo.Layout storage l = Repo._layout();
        (uint256 e0, uint256 e1, uint256 e2) = _simulatedEffectiveAfterZap(s);

        Math.FullBookArgs memory fb = _faceToFullBookArgs(s.a0, s.a1, s.a2, e0, e1, e2, s.supply);
        r.shares = Math.fullBookShares(fb);

        uint256 u0e = _fromWadFloor(l.token0, Math.fullBookUsedWad(r.shares, fb.e0Wad, s.supply));
        uint256 u1e = _fromWadFloor(l.token1, Math.fullBookUsedWad(r.shares, fb.e1Wad, s.supply));
        uint256 u2e = _fromWadFloor(l.token2, Math.fullBookUsedWad(r.shares, fb.e2Wad, s.supply));
        r.used0 = l.se0 == address(0) ? u0e : _invertBufferForEffective(l.token0, u0e);
        r.used1 = l.se1 == address(0) ? u1e : _invertBufferForEffective(l.token1, u1e);
        r.used2 = l.se2 == address(0) ? u2e : _invertBufferForEffective(l.token2, u2e);
        if (r.used0 == 0 || r.used1 == 0 || r.used2 == 0) revert ZeroAmount();
        // Cap used to available maxes
        if (r.used0 > s.a0) r.used0 = s.a0;
        if (r.used1 > s.a1) r.used1 = s.a1;
        if (r.used2 > s.a2) r.used2 = s.a2;
    }


    function _simulatedEffectiveAfterZap(ZapSimArgs memory s)
        private
        view
        returns (uint256 e0, uint256 e1, uint256 e2)
    {
        Repo.Layout storage l = Repo._layout();
        e0 = _effectiveNativeAt(0);
        e1 = _effectiveNativeAt(1);
        e2 = _effectiveNativeAt(2);
        uint8 inIdx = Repo._indexOf(l, s.tokenIn);
        (uint8 j, uint8 k) = _otherIdx(inIdx);

        uint256 dIn = _dInNative(s.tokenIn, s.saleJ) + _dInNative(s.tokenIn, s.saleK);
        if (inIdx == 0) e0 += dIn;
        else if (inIdx == 1) e1 += dIn;
        else e2 += dIn;

        uint256 dOutJ = _dOutNativeDebit(Repo._tokenAt(l, j), s.outJ);
        uint256 dOutK = _dOutNativeDebit(Repo._tokenAt(l, k), s.outK);
        if (j == 0) e0 -= dOutJ;
        else if (j == 1) e1 -= dOutJ;
        else e2 -= dOutJ;
        if (k == 0) e0 -= dOutK;
        else if (k == 1) e1 -= dOutK;
        else e2 -= dOutK;

        if (e0 == 0 || e1 == 0 || e2 == 0) revert Math.MathDomain();
    }


    function _faceToFullBookArgs(
        uint256 a0,
        uint256 a1,
        uint256 a2,
        uint256 e0,
        uint256 e1,
        uint256 e2,
        uint256 supply
    ) private view returns (Math.FullBookArgs memory fb) {
        Repo.Layout storage l = Repo._layout();
        fb.a0Wad = _toWad(l.token0, _previewClaimInAt(0, a0));
        fb.a1Wad = _toWad(l.token1, _previewClaimInAt(1, a1));
        fb.a2Wad = _toWad(l.token2, _previewClaimInAt(2, a2));
        fb.e0Wad = _toWad(l.token0, e0);
        fb.e1Wad = _toWad(l.token1, e1);
        fb.e2Wad = _toWad(l.token2, e2);
        fb.supply = supply;
    }


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


    function _freeTokenBalance(address token) internal view returns (uint256 free) {
        uint256 bal = IERC20(token).balanceOf(address(this));
        if (_seOf(token) != address(0)) {
            // Buffered leg: free face balance is never book (SE shares are book).
            return bal;
        }
        uint256 book = Repo._layout().reserves[token];
        return bal > book ? bal - book : 0;
    }


    function _securePull(IERC20 tokenIn, uint256 claimed, bool pretransferred)
        internal
        returns (uint256 observedDelta)
    {
        uint256 B0 = tokenIn.balanceOf(address(this));
        if (!pretransferred) {
            _pullSeFunding(address(tokenIn), claimed);
            return tokenIn.balanceOf(address(this)) - B0;
        }
        uint256 R = MultiAssetBasicVaultRepo._reserveOfToken(address(tokenIn));
        uint256 U = B0 >= R ? B0 - R : B0;
        if (claimed > U) {
            revert ISecurePullErrors.TransferDeltaInsufficient(claimed, U);
        }
        return claimed;
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


    function _pullLegs(uint256 u0, uint256 u1, uint256 u2, bytes memory permit2Data) internal {
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
            uint256 raw;
            assembly {
                raw := mload(add(permit2Data, 0x20))
            }
            mode = uint8(raw);
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
