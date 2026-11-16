// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV4SeBufferHookContextQuoteLib as ContextQuote} from "contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookContextQuoteLib.sol";
import {UniswapV4SeBufferHookLegLib as LegLib} from "contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol";

import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {ExchangeInAmount} from "contracts/utils/ExchangeInAmount.sol";
import {UniswapV4StandardExchangeOrbitalBufferHookExitQuoteLib as ExitQuoteLib} from "./UniswapV4StandardExchangeOrbitalBufferHookExitQuoteLib.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {UniswapV4BufferHookLiquidityRouteLib as LiquidityRoute} from "contracts/hooks/uniswap/v4/libs/UniswapV4BufferHookLiquidityRouteLib.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {Math as FullPrecisionMath} from "@crane/contracts/utils/Math.sol";
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
import {LocalCreditLib} from "contracts/utils/LocalCreditLib.sol";
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
    error InvalidTransferAmount();
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

    function _bindingToken0() internal view returns (address) {
        return Repo._layout().token0;
    }

    function _bindingToken1() internal view returns (address) {
        return Repo._layout().token1;
    }

    function _bindingToken2() internal view returns (address) {
        return Repo._layout().token2;
    }

    function _bindingIsZapEligible() internal view returns (bool) {
        if (_totalSupply() <= Repo.MINIMUM_LIQUIDITY) return false;
        return _isLive();
    }

    function _bindingIsLive() internal view returns (bool) {
        return _isLive();
    }

    function _isLive() internal view returns (bool) {
        Repo.Layout storage l = Repo._layout();
        return _legLive(l, 0) && _legLive(l, 1) && _legLive(l, 2);
    }

    function _legLive(Repo.Layout storage l, uint8 i) private view returns (bool) {
        return l.reserves[Repo._tokenAt(l, i)] != 0 || l.seShares[Repo._seAt(l, i)] != 0;
    }

    /// @dev D89: owner may zap at MINIMUM_LIQUIDITY. Public still sees isZapEligible()==false.
    function _requireZapEligibleOrOwnerMin() internal view {
        if (_bindingIsZapEligible()) return;
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

    modifier onlyLiquidityRemover() {
        UniswapV4HookOwnerOnlyLiquidityLib.enforceRemoval(
            Repo._layout().ownerOnlyLiquidity,
            address(IVaultFeeOracleQuery(Repo._layout().feeOracle).feeTo())
        );
        _;
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

    /// @dev Pre-pull raw inventory. Not a face-refund snapshot.
    struct RawSnap {
        uint256 b0;
        uint256 b1;
        uint256 b2;
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
        /// @dev SE shares the plan already quoted for each output. Zero when that leg is raw.
        uint256 sharesJ;
        uint256 sharesK;
        uint256 shares;
        uint256 used0;
        uint256 used1;
        uint256 used2;
    }

    struct FaceSnap {
        uint256 o0;
        uint256 o1;
        uint256 o2;
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
        uint256 seBal = se == address(0) ? 0 : l.seShares[se];
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

    /// @dev Booked face for a raw leg, held SE shares for a buffered leg. Not a rate.


    function _onlyPoolManager() internal view {
        if (msg.sender != Repo._layout().poolManager) revert NotPoolManager();
    }


    function _requireDeadline(uint256 deadline) internal view {
        if (block.timestamp > deadline) revert DeadlineExpired();
    }


    function _requireNonZero(uint256 amount) internal pure {
        if (amount == 0) revert ZeroAmount();
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
        return _bufferToken(token, amount, true);
    }

    function _bufferToken(address token, uint256 amount, bool) internal returns (uint256 seOut) {
        if (amount == 0) return 0;
        Repo.Layout storage l = Repo._layout();
        address se = _seOf(token);
        if (se == address(0) || Repo._isDisabled(se)) {
            l.reserves[token] += amount;
            return 0;
        }
        ExchangeInAmount.Result memory result = _convertCaller(token, amount, false, 0);
        l.seShares[se] += result.amountOut;
        l.reserves[token] += result.amountRefunded;
        return result.amountOut;
    }

    /// @dev Does not mutate pool books. Both tuple words must reconcile with actual custody.
    function _convertCaller(address token, uint256 amount, bool redeem, uint256 minimum)
        internal returns (ExchangeInAmount.Result memory result)
    {
        if (amount == 0) return result;
        address se = _seOf(token);
        if (!redeem && Repo._isDisabled(se)) revert IVaultRegistryDisableQuery.VaultDisabled(se);
        IERC20 input = IERC20(redeem ? se : token);
        IERC20 output = IERC20(redeem ? token : se);
        uint256 inputBefore = input.balanceOf(address(this));
        uint256 outputBefore = output.balanceOf(address(this));
        input.forceApprove(se, amount);
        result = ExchangeInAmount.exchangeResult(IStandardExchangeIn(se), input, amount, output,
            minimum, address(this), false, block.timestamp);
        input.forceApprove(se, 0);
        ExchangeInAmount.requireReceipt(amount, result, inputBefore, input.balanceOf(address(this)),
            outputBefore, output.balanceOf(address(this)));
    }


    function _spendableSeShares(address token) internal view returns (uint256) {
        uint256 shares = Repo._layout().seShares[_seOf(token)];
        return shares > 1 ? shares - 1 : 0;
    }

    struct ExactInOutput {
        uint256 amountOut;
        uint256 sharesOut;
    }

    function _receiveExactInOutput(address token, ExactInOutput memory output) internal returns (uint256 amountOut) {
        return _receiveOutput(token, output, true);
    }

    /// @dev Planned zap leg. The plan already quoted the payout, so do not run that quote again.
    function _receivePlannedOutput(address token, ExactInOutput memory output) internal returns (uint256 amountOut) {
        return _receiveOutput(token, output, false);
    }

    function _receiveOutput(address token, ExactInOutput memory output, bool)
        private returns (uint256 amountOut)
    {
        Repo.Layout storage l = Repo._layout();
        address se = _seOf(token);
        uint256 local = output.sharesOut == 0 ? output.amountOut : l.reserves[token];
        if (local > l.reserves[token]) revert Math.Drain();
        l.reserves[token] -= local;
        amountOut = local;
        if (output.sharesOut != 0) {
            if (output.sharesOut > _spendableSeShares(token)) revert Math.Drain();
            ExchangeInAmount.Result memory result = _convertCaller(token, output.sharesOut, true, 0);
            l.seShares[se] -= ExchangeInAmount.consumedInput(output.sharesOut, result.amountRefunded);
            amountOut += result.amountOut;
        }
        if (amountOut == 0 || amountOut < output.amountOut) revert InsufficientTokenOut();
    }

    function _unwrapSeShares(address token, uint256 seIn) internal returns (uint256 pairOut) {
        return _unwrapSeShares(token, seIn, 0);
    }

    function _unwrapSeShares(address token, uint256 seIn, uint256 minOut) internal returns (uint256 pairOut) {
        ExchangeInAmount.Result memory result = _convertCaller(token, seIn, true, minOut);
        if (result.amountRefunded != 0) revert ExchangeInAmount.InvalidExchangeReceipt();
        return result.amountOut;
    }


    function _unwrapExactTokenOut(address token, uint256 amountOut) internal {
        if (amountOut == 0) return;
        Repo.Layout storage l = Repo._layout();
        uint256 local = amountOut < l.reserves[token] ? amountOut : l.reserves[token];
        l.reserves[token] -= local;
        uint256 deficit = amountOut - local;
        if (deficit == 0) return;
        address se = _seOf(token);
        uint256 quoted = ClaimLib.invertUnwrapExactTokenOut(se, token, deficit);
        if (quoted == 0 || quoted > _spendableSeShares(token)) revert InsufficientTokenOut();
        uint256 beforeShares = IERC20(se).balanceOf(address(this));
        uint256 beforePair = IERC20(token).balanceOf(address(this));
        IERC20(se).forceApprove(se, quoted);
        uint256 spent = IStandardExchangeOut(se).exchangeOut(IERC20(se), quoted, IERC20(token),
            deficit, address(this), false, block.timestamp);
        IERC20(se).forceApprove(se, 0);
        uint256 received = IERC20(token).balanceOf(address(this)) - beforePair;
        if (beforeShares - IERC20(se).balanceOf(address(this)) != spent || spent > quoted || received < deficit) {
            revert ExchangeInAmount.InvalidExchangeReceipt();
        }
        l.seShares[se] -= spent;
        l.reserves[token] += received - deficit;
    }





    function _swapExactInExecute(address tokenIn, address tokenOut, uint256 amountIn, uint256 feeWad)
        internal
        returns (uint256 amountOut)
    {
        _requireNonZero(amountIn);
        // L-FEE-3 / single-source: use the feeWad already loaded for this swap (do not re-fetch).
        ExactInOutput memory output = _previewSwapExactInPlan(tokenIn, tokenOut, amountIn, feeWad);
        amountOut = _receiveExactInOutput(tokenOut, output);
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


    function _previewSwapAfterExchange(address tokenIn, address pair, address rawOut, uint256 amountIn)
        internal view returns (uint256 amountOut)
    {
        address se = _seOf(pair);
        if (se == address(0) || _seOf(rawOut) != address(0)) revert InvalidPoolToken();
        if (Repo._isDisabled(se) && tokenIn != se) revert IVaultRegistryDisableQuery.VaultDisabled(se);
        if (!ContextQuote.transitionSupported(se)) {
            ExchangeInAmount.Result memory result = ExchangeInAmount.previewResult(IStandardExchangeIn(se), IERC20(tokenIn), amountIn, IERC20(pair));
            return _previewSwapExactIn(pair, rawOut, result.amountOut);
        }
        SwapLiveCtx memory ctx = _loadSwapLiveCtx(pair, rawOut);
        LegLib.ExternalQuote memory q = LegLib.afterExternalExchange(se, pair, tokenIn, amountIn, address(this));
        uint256 held;
        uint256 inflow;
        if (Repo._isDisabled(se)) {
            held = _effectiveNativeOf(pair);
            inflow = q.assets;
        } else {
            (ExchangeInAmount.Result memory result,) = ClaimLib.conversionQuote(se, pair, q.assets, false, q.state, false);
            (held, inflow) = _projectedInputValue(q, pair, result.amountOut);
            inflow += result.amountRefunded;
        }
        SphereLegsWad memory legs = _loadSphereLegs(pair, rawOut, ctx.tokenZ);
        legs.xWad = _toWad(pair, held);
        legs.L2 = Math.recomputeL2(legs.R, legs.xWad, legs.yWad, legs.zWad);
        amountOut = _fromWadFloor(rawOut, _sphereExactIn(legs, Math.applyTradingFeeNet(_toWad(pair, inflow), ctx.feeWad)));
        if (amountOut == 0 || amountOut >= ctx.eOutNative) revert Math.Drain();
    }

    function _projectedInputValue(LegLib.ExternalQuote memory q, address pair, uint256 minted)
        private view returns (uint256 held, uint256 inflow)
    {
        address provider = _rpOf(pair);
        if (provider == address(0)) revert ClaimLib.RateProviderRequired();
        uint256 rate = LegLib.rateAfterExchange(q, pair, provider);
        held = Repo._layout().reserves[pair] + ClaimLib.ratedNative(Repo._layout().seShares[address(q.exchange)], rate, address(q.exchange), pair);
        inflow = ClaimLib.ratedNative(minted, rate, address(q.exchange), pair);
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
        return _previewSwapExactInPlan(tokenIn, tokenOut, amountIn, feeWad).amountOut;
    }

    function _previewSwapExactInPlan(address tokenIn, address tokenOut, uint256 amountIn, uint256 feeWad)
        internal view returns (ExactInOutput memory output)
    {
        return _previewSwapExactInContext(tokenIn, tokenOut, amountIn, feeWad, address(0));
    }

    function _previewSwapExactInContext(address tokenIn, address tokenOut, uint256 amountIn, uint256 feeWad, address manager)
        internal view returns (ExactInOutput memory output)
    {
        (output.amountOut, output.sharesOut) = ClaimLib.previewSwapExactInContext(tokenIn, tokenOut, amountIn, feeWad, manager);
    }

    function _effectiveNativeWithContext(address token, address manager) private view returns (uint256) {
        address se = _seOf(token);
        return ClaimLib.effectiveNativeWithContext(se, _rpOf(token), token, Repo._layout().reserves[token],
            se == address(0) ? 0 : Repo._layout().seShares[se], manager);
    }

    function _sphereLegsWithContext(address input, address output, address other, address manager) private view returns (SphereLegsWad memory s) {
        s.R = Repo._layout().R;
        s.xWad = _toWad(input, _effectiveNativeWithContext(input, manager));
        s.yWad = _toWad(output, _effectiveNativeWithContext(output, manager));
        s.zWad = _toWad(other, _effectiveNativeWithContext(other, manager));
        s.L2 = Math.recomputeL2(s.R, s.xWad, s.yWad, s.zWad);
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
        return ClaimLib.previewSwapExactOutBook(tokenIn, tokenOut, amountOut, feeWad);
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
        s.xWad = _toWad(tokenIn, _effectiveNativeOf(tokenIn));
        s.yWad = _toWad(tokenOut, _effectiveNativeOf(tokenOut));
        s.zWad = _toWad(tokenZ, _effectiveNativeOf(tokenZ));
        // Underlying SE yield may change effective balances between hook operations.
        // Use the same sphere formula over this live book, rather than mixing new
        // coordinates with the last operation's stored sphere parameter.
        s.L2 = Math.recomputeL2(s.R, s.xWad, s.yWad, s.zWad);
    }


    function _sphereExactIn(SphereLegsWad memory s, uint256 dxNet)
        internal
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








    function _invertBufferForEffective(address token, uint256 dInNative)
        internal
        view
        returns (uint256 amountInRaw)
    {
        if (dInNative == 0) return 0;
        return ClaimLib.invertBufferForEffective(_seOf(token), _rpOf(token), token, dInNative);
    }


    struct JoinBasket {
        uint256[3] shares;
        uint256[3] local;
        uint256[3] used;
        uint256[3] purchased;
    }

    struct JoinBook {
        uint256 supply;
        uint256[3] shares;
        uint256[3] local;
    }

    /// @dev Mint ownership uses the incumbent quantities after caller-paid preparation.
    function _joinBook() internal view returns (JoinBook memory book) {
        Repo.Layout storage l = Repo._layout();
        book.supply = _totalSupply();
        for (uint8 i; i < 3; ++i) {
            book.shares[i] = l.seShares[Repo._seAt(l, i)];
            book.local[i] = l.reserves[Repo._tokenAt(l, i)];
        }
    }

    function _missingJoinLeg(uint256[3] memory amounts, JoinBook memory book) private pure returns (bool) {
        if (book.supply == 0) return false;
        for (uint8 i; i < 3; ++i) {
            if (amounts[i] == 0 && (book.shares[i] != 0 || book.local[i] != 0)) return true;
        }
        return false;
    }

    function _quoteJoin(uint256[3] memory amounts, bool[3] memory flags, JoinBook memory book)
        private view returns (JoinBasket memory basket, uint256 gross)
    {
        Repo.Layout storage l = Repo._layout();
        if (book.supply != 0 && _missingJoinLeg(amounts, book)) {
            ExitQuoteLib.JoinQuote memory q = ExitQuoteLib.quotePreparedJoin(amounts, flags);
            basket.shares = q.shares;
            basket.local = q.local;
            basket.purchased = q.purchased;
            book.shares = q.bookShares;
            book.local = q.bookLocal;
            gross = _basketGross(basket, book);
            for (uint8 i; i < 3; ++i) {
                uint256 refund = flags[i] ? basket.shares[i] - LiquidityRoute.componentContribution(gross, book.shares[i], book.supply)
                    : basket.local[i] - LiquidityRoute.componentContribution(gross, book.local[i], book.supply);
                basket.used[i] = amounts[i] - FullPrecisionMath.min(amounts[i], refund);
            }
            return (basket, gross);
        }
        for (uint8 i; i < 3; ++i) {
            address se = Repo._seAt(l, i);
            address token = Repo._tokenAt(l, i);
            ClaimLib.Contribution memory c = ClaimLib.quoteContribution(
                se, token, book.shares[i], book.local[i], amounts[i], flags[i], book.supply == 0,
                bytes("")
            );
            basket.shares[i] = c.shares;
            basket.local[i] = c.local;
        }
        gross = _basketGross(basket, book);
        for (uint8 i; i < 3; ++i) {
            uint256 accepted = book.supply == 0 ? (flags[i] ? basket.shares[i] : basket.local[i])
                : LiquidityRoute.componentContribution(gross,
                    flags[i] ? book.shares[i] : book.local[i], book.supply);
            uint256 available = flags[i] ? basket.shares[i] : basket.local[i];
            basket.used[i] = amounts[i] - FullPrecisionMath.min(amounts[i], available - accepted);
        }
    }

    function _basketGross(JoinBasket memory basket, JoinBook memory book) private view returns (uint256 gross) {
        Repo.Layout storage l = Repo._layout();
        if (book.supply == 0) {
            uint256 positive;
            uint256 seed;
            for (uint8 i; i < 3; ++i) {
                address se = Repo._seAt(l, i);
                uint256 coordinate = se == address(0) ? basket.local[i] : basket.shares[i];
                if (coordinate != 0) ++positive;
                seed += Math.toWad(coordinate, se == address(0) ? _decimalsOf(Repo._tokenAt(l, i)) : IERC20Metadata(se).decimals());
            }
            if (positive < 2) revert FirstMintRequiresTwoLegs();
            return LiquidityRoute.genesisGross(seed, Repo.MINIMUM_LIQUIDITY);
        }
        uint256[] memory available = new uint256[](6);
        uint256[] memory booked = new uint256[](6);
        for (uint8 i; i < 3; ++i) {
            available[2 * i] = basket.shares[i];
            available[2 * i + 1] = basket.local[i];
            booked[2 * i] = book.shares[i];
            booked[2 * i + 1] = book.local[i];
        }
        return LiquidityRoute.maxComponentMint(available, booked, book.supply);
    }

    /// @dev Conversion receipts stay caller-owned until the common six-component mint is accepted.
    function _assembleJoin(uint256[3] memory amounts, bool[3] memory flags, JoinBook memory book)
        private returns (JoinBasket memory basket)
    {
        Repo.Layout storage l = Repo._layout();
        for (uint8 i; i < 3; ++i) {
            address se = Repo._seAt(l, i);
            address token = Repo._tokenAt(l, i);
            if (se == address(0)) basket.local[i] = amounts[i];
            else {
                if (book.supply == 0 && !flags[i] && amounts[i] != 0) {
                    ExchangeInAmount.Result memory acquired = _convertCaller(token, amounts[i], false, 0);
                    (uint256 seedBurn,) = LiquidityRoute.bootstrapSplit(acquired.amountOut);
                    ExchangeInAmount.Result memory seed = _convertCaller(token, seedBurn, true, 0);
                    if (seed.amountRefunded != 0 || seed.amountOut == 0) revert ExchangeInAmount.InvalidExchangeReceipt();
                    basket.shares[i] = acquired.amountOut - seedBurn;
                    basket.local[i] = acquired.amountRefunded + seed.amountOut;
                    continue;
                }
                ClaimLib.Contribution memory c = ClaimLib.quoteContribution(
                    se, token, book.shares[i], book.local[i], amounts[i], flags[i], book.supply == 0, bytes("")
                );
                ExchangeInAmount.Result memory result = _convertCaller(token, c.convert, flags[i], 0);
                if (flags[i]) {
                    basket.shares[i] = ExchangeInAmount.localCredit(amounts[i], c.convert, result.amountRefunded);
                    basket.local[i] = result.amountOut;
                    if (book.supply == 0 && amounts[i] != 0 && (c.convert == 0 || result.amountRefunded != 0 || result.amountOut == 0)) {
                        revert ExchangeInAmount.InvalidExchangeReceipt();
                    }
                } else {
                    basket.shares[i] = result.amountOut;
                    basket.local[i] = ExchangeInAmount.localCredit(amounts[i], c.convert, result.amountRefunded);
                }
            }
        }
    }

    function _acceptJoin(uint256[3] memory amounts, bool[3] memory flags, address to, uint256 minimum, JoinBook memory book)
        private returns (uint256 net, uint256[3] memory used)
    {
        JoinBasket memory basket;
        if (book.supply != 0 && _missingJoinLeg(amounts, book)) {
            basket = _prepareJoin(amounts, flags, book);
            book = _joinBook();
        } else basket = _assembleJoin(amounts, flags, book);
        net = _acceptJoinBasket(basket, book, to, minimum);
        for (uint8 i; i < 3; ++i) {
            used[i] = amounts[i] - FullPrecisionMath.min(amounts[i], flags[i] ? basket.shares[i] : basket.local[i]);
        }
    }

    /// @dev Mutates the caller basket to the refunded components, for legacy used-amount reporting.
    function _acceptJoinBasket(JoinBasket memory basket, JoinBook memory book, address to, uint256 minimum)
        private returns (uint256 net)
    {
        uint256 gross = _basketGross(basket, book);
        if (gross == 0) revert ZeroAmount();
        uint256 fee;
        address feeRecipient;
        (net, fee, feeRecipient) = ClaimLib.netMint(gross);
        if (net < minimum) revert InsufficientSharesOut();
        Repo.Layout storage l = Repo._layout();
        for (uint8 i; i < 3; ++i) {
            address se = Repo._seAt(l, i);
            address token = Repo._tokenAt(l, i);
            uint256 shareAccepted = book.supply == 0 ? basket.shares[i]
                : LiquidityRoute.componentContribution(gross, book.shares[i], book.supply);
            uint256 localAccepted = book.supply == 0 ? basket.local[i]
                : LiquidityRoute.componentContribution(gross, book.local[i], book.supply);
            uint256 shareRefund = basket.shares[i] - shareAccepted;
            uint256 localRefund = basket.local[i] - localAccepted;
            if (se != address(0)) l.seShares[se] += shareAccepted;
            l.reserves[token] += localAccepted;
            basket.shares[i] = shareRefund;
            basket.local[i] = localRefund;
        }
        if (book.supply == 0) {
            (uint256 e0, uint256 e1, uint256 e2) = _effectiveWad();
            l.R = Math.firstMintRadius(e0, e1, e2);
            _mintLp(address(0), Repo.MINIMUM_LIQUIDITY);
        } else _requirePostUnderRadius();
        _mintLp(to, net);
        if (fee != 0) {
            _mintLp(feeRecipient, fee);
            emit ProtocolFeeMinted(feeRecipient, fee);
        }
        _recomputeL2();
        _syncVaultReserves();
        for (uint8 i; i < 3; ++i) {
            if (basket.shares[i] != 0) IERC20(Repo._seAt(l, i)).safeTransfer(msg.sender, basket.shares[i]);
            if (basket.local[i] != 0) IERC20(Repo._tokenAt(l, i)).safeTransfer(msg.sender, basket.local[i]);
        }
    }

    function _nativeJoinQuote(uint256[] calldata localAmounts, uint256[] calldata shareAmounts)
        private view returns (ExitQuoteLib.JoinQuote memory q)
    {
        if (localAmounts.length != 3 || shareAmounts.length != 3) revert InvalidRoute(address(0), address(0));
        if (!_isLive()) revert NotLive();
        Repo.Layout storage l = Repo._layout();
        for (uint8 i; i < 3; ++i) {
            address se = Repo._seAt(l, i);
            if (se == address(0) && shareAmounts[i] != 0) revert InvalidSeShareLeg();
            q.local[i] = localAmounts[i];
            q.shares[i] = shareAmounts[i];
            q.bookLocal[i] = l.reserves[Repo._tokenAt(l, i)];
            q.bookShares[i] = l.seShares[se];
            if (se != address(0) && (q.bookShares[i] != 0 || q.shares[i] != 0)) {
                q.rates[i] = ClaimLib.getRateFailClosed(Repo._rpAt(l, i));
            }
        }
        return ExitQuoteLib.prepareNativeInKind(q);
    }

    /// @dev Keep every paid receipt. Only a missing native component may require conversion.
    function _nativeJoinBasket(ExitQuoteLib.JoinQuote memory q)
        private view returns (JoinBasket memory basket, uint256[3] memory conversions, bool[3] memory redeems)
    {
        Repo.Layout storage l = Repo._layout();
        for (uint8 i; i < 3; ++i) {
            basket.shares[i] = q.shares[i];
            basket.local[i] = q.local[i];
            basket.purchased[i] = q.purchased[i];
            address se = Repo._seAt(l, i);
            if (se == address(0)) continue;
            bool redeem = q.local[i] == 0 && q.bookLocal[i] != 0;
            bool deposit = q.shares[i] == 0 && q.bookShares[i] != 0;
            if (!redeem && !deposit) continue;
            address token = Repo._tokenAt(l, i);
            uint256 amount = redeem ? q.shares[i] : q.local[i];
            ClaimLib.Contribution memory c = ClaimLib.quoteContribution(
                se, token, q.bookShares[i], q.bookLocal[i], amount, redeem, false, bytes("")
            );
            basket.shares[i] = c.shares;
            basket.local[i] = c.local;
            conversions[i] = c.convert;
            redeems[i] = redeem;
        }
    }

    function _previewJoinNativeComponents(uint256[] calldata localAmounts, uint256[] calldata shareAmounts)
        internal view returns (uint256 net)
    {
        ExitQuoteLib.JoinQuote memory q = _nativeJoinQuote(localAmounts, shareAmounts);
        (JoinBasket memory basket,,) = _nativeJoinBasket(q);
        JoinBook memory book = _joinBook();
        book.shares = q.bookShares;
        book.local = q.bookLocal;
        (net,,) = ClaimLib.netMint(_basketGross(basket, book));
    }

    function _joinNativeComponents(uint256[] calldata localAmounts, uint256[] calldata shareAmounts,
        address to, uint256 minimum, uint256 deadline) internal returns (uint256 net)
    {
        _requireDeadline(deadline);
        if (to == address(0)) revert ZeroAddress();
        ExitQuoteLib.JoinQuote memory q = _nativeJoinQuote(localAmounts, shareAmounts);
        Repo.Layout storage l = Repo._layout();
        for (uint8 i; i < 3; ++i) {
            _pullDirectExact(Repo._tokenAt(l, i), localAmounts[i]);
            if (shareAmounts[i] != 0) _pullDirectExact(Repo._seAt(l, i), shareAmounts[i]);
        }
        for (uint8 i; i < 3; ++i) {
            l.reserves[Repo._tokenAt(l, i)] = q.bookLocal[i];
            if (Repo._seAt(l, i) != address(0)) l.seShares[Repo._seAt(l, i)] = q.bookShares[i];
        }
        JoinBook memory book = _joinBook();
        (JoinBasket memory basket, uint256[3] memory conversions, bool[3] memory redeems) = _nativeJoinBasket(q);
        for (uint8 i; i < 3; ++i) {
            if (conversions[i] == 0) continue;
            ExchangeInAmount.Result memory result = _convertCaller(Repo._tokenAt(l, i), conversions[i], redeems[i], 0);
            if (redeems[i]) {
                basket.shares[i] = ExchangeInAmount.localCredit(q.shares[i], conversions[i], result.amountRefunded);
                basket.local[i] = result.amountOut;
            } else {
                basket.shares[i] = result.amountOut;
                basket.local[i] = ExchangeInAmount.localCredit(q.local[i], conversions[i], result.amountRefunded);
            }
        }
        return _acceptJoinBasket(basket, book, to, minimum);
    }

    function _addLiquidity(uint256 a0, uint256 a1, uint256 a2, address to, uint256 minimum,
        uint256 deadline, bytes memory permit2Data)
        internal returns (uint256 net, uint256 u0, uint256 u1, uint256 u2)
    {
        _requireDeadline(deadline);
        if (to == address(0)) revert ZeroAddress();
        uint256[3] memory amounts = [a0, a1, a2];
        bool[3] memory flags;
        JoinBook memory book = _joinBook();
        _pullLegs(a0, a1, a2, permit2Data);
        uint256[3] memory used;
        (net, used) = _acceptJoin(amounts, flags, to, minimum, book);
        emit LiquidityAdded(msg.sender, to, net, used[0], used[1], used[2]);
        return (net, used[0], used[1], used[2]);
    }

    function _depositFlexible(DepositFlexibleVars memory v, uint256 deadline)
        internal returns (uint256 net, uint256 u0, uint256 u1, uint256 u2)
    {
        _requireDeadline(deadline);
        if (v.to == address(0)) revert ZeroAddress();
        _validateSeShareFlags(v.amount0IsSeShare, v.amount1IsSeShare, v.amount2IsSeShare);
        uint256[3] memory amounts = [v.amount0, v.amount1, v.amount2];
        bool[3] memory flags = [v.amount0IsSeShare, v.amount1IsSeShare, v.amount2IsSeShare];
        JoinBook memory book = _joinBook();
        Repo.Layout storage l = Repo._layout();
        for (uint8 i; i < 3; ++i) _pullDirectExact(flags[i] ? Repo._seAt(l, i) : Repo._tokenAt(l, i), amounts[i]);
        uint256[3] memory used;
        (net, used) = _acceptJoin(amounts, flags, v.to, v.sharesMin, book);
        emit DepositFlexible(msg.sender, v.to, v.amount0, flags[0], v.amount1, flags[1], v.amount2, flags[2],
            used[0], used[1], used[2], net);
        return (net, used[0], used[1], used[2]);
    }

    function _previewDepositFlexible(DepositFlexibleVars memory v)
        internal view returns (uint256 net, uint256 u0, uint256 u1, uint256 u2)
    {
        _validateSeShareFlags(v.amount0IsSeShare, v.amount1IsSeShare, v.amount2IsSeShare);
        (JoinBasket memory basket, uint256 gross) = _quoteJoin([v.amount0, v.amount1, v.amount2],
            [v.amount0IsSeShare, v.amount1IsSeShare, v.amount2IsSeShare], _joinBook());
        (net,,) = ClaimLib.netMint(gross);
        return (net, basket.used[0], basket.used[1], basket.used[2]);
    }

    function _previewAddLiquidity(uint256 a0, uint256 a1, uint256 a2)
        internal view returns (uint256 net, uint256 u0, uint256 u1, uint256 u2)
    {
        bool[3] memory flags;
        (JoinBasket memory basket, uint256 gross) = _quoteJoin([a0, a1, a2], flags, _joinBook());
        (net,,) = ClaimLib.netMint(gross);
        return (net, basket.used[0], basket.used[1], basket.used[2]);
    }

    function _validateSeShareFlags(bool f0, bool f1, bool f2) private view {
        Repo.Layout storage l = Repo._layout();
        if ((f0 && l.se0 == address(0)) || (f1 && l.se1 == address(0)) || (f2 && l.se2 == address(0))) revert InvalidSeShareLeg();
    }

    function _removeLiquidity(uint256 shares, address to, uint256 min0, uint256 min1, uint256 min2, uint256 deadline)
        internal returns (uint256 a0, uint256 a1, uint256 a2)
    {
        return _removeLiquidityFrom(msg.sender, shares, to, min0, min1, min2, deadline, true);
    }

    function _removeLiquidityFrom(address holder, uint256 shares, address to, uint256 min0, uint256 min1,
        uint256 min2, uint256 deadline, bool)
        internal returns (uint256 a0, uint256 a1, uint256 a2)
    {
        _requireDeadline(deadline);
        _requireNonZero(shares);
        if (to == address(0)) revert ZeroAddress();
        if (shares > _balanceOf(holder)) revert InsufficientSharesOut();
        uint256 supply = _totalSupply();
        _burnLp(holder, shares);
        a0 = _payComponentLeg(0, shares, supply, to, false);
        a1 = _payComponentLeg(1, shares, supply, to, false);
        a2 = _payComponentLeg(2, shares, supply, to, false);
        if (a0 < min0 || a1 < min1 || a2 < min2) revert InsufficientTokenOut();
        _recomputeL2();
        _syncVaultReserves();
        emit LiquidityRemoved(msg.sender, to, shares, a0, a1, a2);
    }

    function _withdrawFlexible(WithdrawFlexibleVars memory w, uint256 deadline)
        internal returns (uint256 a0, uint256 a1, uint256 a2)
    {
        _requireDeadline(deadline);
        _requireNonZero(w.shares);
        if (w.to == address(0)) revert ZeroAddress();
        _validateSeShareFlags(w.receiveSeShare0, w.receiveSeShare1, w.receiveSeShare2);
        if (w.shares > _balanceOf(msg.sender)) revert InsufficientSharesOut();
        uint256 supply = _totalSupply();
        _burnLp(msg.sender, w.shares);
        a0 = _payComponentLeg(0, w.shares, supply, w.to, w.receiveSeShare0);
        a1 = _payComponentLeg(1, w.shares, supply, w.to, w.receiveSeShare1);
        a2 = _payComponentLeg(2, w.shares, supply, w.to, w.receiveSeShare2);
        if (a0 < w.a0Min || a1 < w.a1Min || a2 < w.a2Min) revert InsufficientTokenOut();
        _recomputeL2();
        _syncVaultReserves();
        emit WithdrawFlexible(msg.sender, w.to, w.shares, w.receiveSeShare0, w.receiveSeShare1,
            w.receiveSeShare2, a0, a1, a2);
    }

    function _payComponentLeg(uint8 i, uint256 burned, uint256 supply, address to, bool asShare)
        private returns (uint256 amountOut)
    {
        Repo.Layout storage l = Repo._layout();
        address token = Repo._tokenAt(l, i);
        address se = Repo._seAt(l, i);
        uint256 local = LiquidityRoute.componentAllocation(burned, l.reserves[token], supply);
        uint256 shares = LiquidityRoute.componentAllocation(burned, l.seShares[se], supply);
        l.reserves[token] -= local;
        if (se != address(0)) l.seShares[se] -= shares;
        if (se == address(0)) amountOut = local;
        else {
            ExchangeInAmount.Result memory result = _convertCaller(token, asShare ? local : shares, !asShare, 0);
            // A requested single-asset payout cannot silently retain the holder's other component.
            if (result.amountRefunded != 0) revert ExchangeInAmount.InvalidExchangeReceipt();
            amountOut = (asShare ? shares : local) + result.amountOut;
        }
        if (amountOut != 0 && to != address(this)) IERC20(asShare ? se : token).safeTransfer(to, amountOut);
    }

    function _previewComponentLeg(uint8 i, uint256 burned, uint256 supply, bool asShare)
        private view returns (uint256 amountOut)
    {
        Repo.Layout storage l = Repo._layout();
        address token = Repo._tokenAt(l, i);
        address se = Repo._seAt(l, i);
        uint256 local = LiquidityRoute.componentAllocation(burned, l.reserves[token], supply);
        uint256 shares = LiquidityRoute.componentAllocation(burned, l.seShares[se], supply);
        if (se == address(0)) return local;
        if (asShare && local != 0 && Repo._isDisabled(se)) revert IVaultRegistryDisableQuery.VaultDisabled(se);
        (ExchangeInAmount.Result memory result,) = ClaimLib.conversionQuote(se, token,
            asShare ? local : shares, !asShare, bytes(""), false);
        if (result.amountRefunded != 0) revert ExchangeInAmount.InvalidExchangeReceipt();
        return (asShare ? shares : local) + result.amountOut;
    }

    function _previewRemoveLiquidity(uint256 shares) internal view returns (uint256, uint256, uint256) {
        _requireNonZero(shares);
        uint256 supply = _totalSupply();
        return (_previewComponentLeg(0, shares, supply, false), _previewComponentLeg(1, shares, supply, false),
            _previewComponentLeg(2, shares, supply, false));
    }

    function _previewWithdrawFlexible(uint256 shares, bool f0, bool f1, bool f2)
        internal view returns (uint256, uint256, uint256)
    {
        _requireNonZero(shares);
        _validateSeShareFlags(f0, f1, f2);
        uint256 supply = _totalSupply();
        return (_previewComponentLeg(0, shares, supply, f0), _previewComponentLeg(1, shares, supply, f1),
            _previewComponentLeg(2, shares, supply, f2));
    }

    function _exitSingleAssetFrom(address holder, address tokenOut, uint256 shares, address to, uint256 deadline)
        internal returns (uint256 amountOut)
    {
        address pair = _resolveBurnTokenOut(tokenOut);
        if (pair == address(0)) revert InvalidRoute(tokenOut, address(0));
        if (to == address(0)) revert ZeroAddress();
        uint256[3] memory amounts;
        (amounts[0], amounts[1], amounts[2]) = _removeLiquidityFrom(holder, shares, address(this), 0, 0, 0, deadline, false);
        for (uint8 i; i < 3; ++i) {
            address input = Repo._tokenAt(Repo._layout(), i);
            if (input == pair) amountOut += amounts[i];
            else if (amounts[i] != 0) amountOut += _internalSwapExactIn(input, pair, amounts[i], _feeOracle().dexSwapFeeOfVault(address(this)));
        }
        if (tokenOut != pair && amountOut != 0) {
            ExchangeInAmount.Result memory result = _convertCaller(pair, amountOut, false, 0);
            if (result.amountRefunded != 0) revert ExchangeInAmount.InvalidExchangeReceipt();
            amountOut = result.amountOut;
        }
        IERC20(tokenOut).safeTransfer(to, amountOut);
        _syncVaultReserves();
    }

    function _resolveBurnTokenOut(address tokenOut) internal view returns (address) {
        Repo.Layout storage l = Repo._layout();
        LegLib.LegKind kind = LegLib.classify(l.legs, tokenOut);
        if (kind == LegLib.LegKind.StandardExchange) return l.legs.pairOfStandardExchange[tokenOut];
        if (kind == LegLib.LegKind.Pair || kind == LegLib.LegKind.Detf) return tokenOut;
        return address(0);
    }

    function _depositSingle(address tokenIn, uint256 amountIn, address to, uint256 sharesMin,
        uint256 deadline, bytes calldata permit2Data) internal returns (uint256 shares)
    {
        _requireDeadline(deadline);
        _requireNonZero(amountIn);
        if (to == address(0)) revert ZeroAddress();
        _requireZapEligibleOrOwnerMin();
        if (!_isBound(tokenIn)) revert InvalidPoolToken();
        JoinBook memory book = _joinBook();
        _pullTokenIn(tokenIn, amountIn, permit2Data);
        return _acceptSingle(tokenIn, amountIn, false, to, sharesMin, book);
    }

    /// @dev The caller buys missing legs before proportional component acceptance.
    function _acceptSingle(address pair, uint256 amountIn, bool asShare, address to,
        uint256 minimum, JoinBook memory book) internal returns (uint256 shares)
    {
        uint256[3] memory offered;
        bool[3] memory flags;
        uint8 index = Repo._indexOf(Repo._layout(), pair);
        offered[index] = amountIn;
        flags[index] = asShare;
        (shares,) = _acceptJoin(offered, flags, to, minimum, book);
        emit DepositSingle(msg.sender, to, asShare ? _seOf(pair) : pair, amountIn, shares);
    }

    function _prepareJoin(uint256[3] memory amounts, bool[3] memory flags, JoinBook memory book)
        private returns (JoinBasket memory basket)
    {
        Repo.Layout storage l = Repo._layout();
        ExitQuoteLib.JoinQuote memory q;
        q.bookShares = book.shares;
        q.bookLocal = book.local;
        for (uint8 i; i < 3; ++i) {
            if (flags[i]) q.shares[i] = amounts[i];
            else q.local[i] = amounts[i];
            if (Repo._seAt(l, i) != address(0) && (q.bookShares[i] != 0 || q.shares[i] != 0)) {
                q.rates[i] = ClaimLib.getRateFailClosed(Repo._rpAt(l, i));
            }
        }
        q = ExitQuoteLib.prepareInKind(q, amounts);
        uint256[3] memory remaining;
        for (uint8 i; i < 3; ++i) {
            if ((q.bookShares[i] != 0 || q.bookLocal[i] != 0) && q.shares[i] == 0 && q.local[i] == 0) revert ZeroAmount();
            if (Repo._seAt(l, i) != address(0)) l.seShares[Repo._seAt(l, i)] = q.bookShares[i];
            l.reserves[Repo._tokenAt(l, i)] = q.bookLocal[i];
            if (amounts[i] != 0) remaining[i] = flags[i] ? q.shares[i] : q.local[i];
        }
        basket = _assembleJoin(remaining, flags, _joinBook());
        basket.purchased = q.purchased;
        for (uint8 i; i < 3; ++i) if (amounts[i] == 0) {
            basket.shares[i] = q.shares[i];
            basket.local[i] = q.local[i];
        }
    }

    function _pullTokenIn(address tokenIn, uint256 amountIn, bytes calldata permit2Data) private {
        uint256 beforeBalance = IERC20(tokenIn).balanceOf(address(this));
        if (permit2Data.length == 0) {
            IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        } else {
            _pullSingle(tokenIn, amountIn, permit2Data);
        }
        _requireReceived(tokenIn, amountIn, beforeBalance);
    }




    function _internalSwapExactIn(address tokenIn, address tokenOut, uint256 amountIn, uint256 feeWad)
        internal
        returns (uint256 amountOut)
    {
        // Single-source fee with zap plan (do not re-fetch oracle fee inside preview).
        ExactInOutput memory output;
        (output.amountOut, output.sharesOut) = ClaimLib.previewLiquiditySwap(tokenIn, tokenOut, amountIn, feeWad);
        amountOut = _receiveExactInOutput(tokenOut, output);
        if (_seOf(tokenIn) != address(0)) {
            _bufferToken(tokenIn, amountIn);
        } else {
            Repo._layout().reserves[tokenIn] += amountIn;
        }
        _recomputeL2();
    }





    function _planZap(address tokenIn, uint256 amountIn) internal view returns (ZapPlan memory p) {
        _requireZapEligibleOrOwnerMin();
        if (!_isBound(tokenIn)) revert InvalidPoolToken();
        _requireNonZero(amountIn);
        p.inIdx = Repo._indexOf(Repo._layout(), tokenIn);
        p.j = p.inIdx == 0 ? 1 : 0;
        p.k = 3 - p.inIdx - p.j;
        p.residual = amountIn;
        uint256[3] memory offered;
        bool[3] memory flags;
        offered[p.inIdx] = amountIn;
        (JoinBasket memory basket, uint256 gross) = _quoteJoin(offered, flags, _joinBook());
        (p.shares,,) = ClaimLib.netMint(gross);
        uint256 total = _toWad(_bindingToken0(), _effectiveNativeAt(0))
            + _toWad(_bindingToken1(), _effectiveNativeAt(1)) + _toWad(_bindingToken2(), _effectiveNativeAt(2));
        p.saleJ = FullPrecisionMath.mulDiv(amountIn, _toWad(Repo._tokenAt(Repo._layout(), p.j), _effectiveNativeAt(p.j)), total);
        p.saleK = FullPrecisionMath.mulDiv(amountIn, _toWad(Repo._tokenAt(Repo._layout(), p.k), _effectiveNativeAt(p.k)), total);
        p.residual = amountIn - p.saleJ - p.saleK;
        p.outJ = basket.purchased[p.j];
        p.outK = basket.purchased[p.k];
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


    /// @dev Opening face balances of the three pool tokens. Refunds compare against this snap
    ///      so resting D12 credit is not paid to the current caller (APEX-2026-008 / R6).


    function _freeTokenBalance(address token) internal view returns (uint256) {
        return LocalCreditLib.available(IERC20(token).balanceOf(address(this)), Repo._layout().reserves[token]);
    }


    function _securePull(IERC20 tokenIn, uint256 claimed, bool pretransferred)
        internal
        returns (uint256 observedDelta)
    {
        uint256 B0 = tokenIn.balanceOf(address(this));
        if (!pretransferred) {
            _pullSeFunding(address(tokenIn), claimed);
            uint256 delta = tokenIn.balanceOf(address(this)) - B0;
            if (delta != claimed) {
                revert ISecurePullErrors.TransferDeltaInsufficient(claimed, delta);
            }
            return claimed;
        }
        LocalCreditLib.requirePretransferCaller(msg.sender);
        uint256 U = _unbookedBalance(tokenIn);
        if (claimed > U) {
            revert ISecurePullErrors.TransferDeltaInsufficient(claimed, U);
        }
        return claimed;
    }

    /// @dev Exact-out input: false-flag pulls `used` and refunds nothing. True-flag credits
    ///      `budget(available, maxAmountIn)` and refunds `credit - used` only.
    function _pullExactOutInput(IERC20 token, uint256 used, uint256 maxAmountIn, bool pretransferred)
        internal
    {
        _securePull(token, used, pretransferred);
        if (!pretransferred) return;
        uint256 credit = LocalCreditLib.budget(_unbookedBalance(token), maxAmountIn);
        if (credit > used) token.safeTransfer(msg.sender, credit - used);
    }

    /// @dev Credit is measured in locally held token units, never against rated claim value.
    ///      Non-identity buffered legs hold their backing as a different SE token.
    function _unbookedBalance(IERC20 token) internal view returns (uint256) {
        return LocalCreditLib.available(token.balanceOf(address(this)), Repo._layout().reserves[address(token)]);
    }


    function _pullSeFunding(address token, uint256 amount) internal {
        // D49c: transferFrom if allowance, else Permit2 AllowanceTransfer
        uint256 allowance = IERC20(token).allowance(msg.sender, address(this));
        if (allowance >= amount) {
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        } else {
            _pullPermit2(token, amount);
        }
    }


    function _pullDirectExact(address token, uint256 amount) internal {
        if (amount == 0) return;
        uint256 beforeBalance = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        _requireReceived(token, amount, beforeBalance);
    }

    function _requireReceived(address token, uint256 amount, uint256 beforeBalance) private view {
        uint256 afterBalance = IERC20(token).balanceOf(address(this));
        uint256 received = afterBalance > beforeBalance ? afterBalance - beforeBalance : 0;
        if (received != amount) revert ISecurePullErrors.TransferDeltaInsufficient(amount, received);
    }

    function _pullPermit2(address token, uint256 amount) private {
        if (amount > type(uint160).max) revert InvalidTransferAmount();
        IAllowanceTransfer(PERMIT2).transferFrom(msg.sender, address(this), uint160(amount), token);
    }

    function _pullLegs(uint256 u0, uint256 u1, uint256 u2, bytes memory permit2Data) internal {
        address[3] memory tokens = [_bindingToken0(), _bindingToken1(), _bindingToken2()];
        uint256[3] memory amounts = [u0, u1, u2];
        uint256[3] memory beforeBalances;
        for (uint256 i; i < 3; ++i) {
            if (amounts[i] > 0) beforeBalances[i] = IERC20(tokens[i]).balanceOf(address(this));
        }
        _transferLegs(u0, u1, u2, permit2Data);
        for (uint256 i; i < 3; ++i) {
            if (amounts[i] > 0) _requireReceived(tokens[i], amounts[i], beforeBalances[i]);
        }
    }

    function _transferLegs(uint256 u0, uint256 u1, uint256 u2, bytes memory permit2Data) private {
        address t0 = _bindingToken0();
        address t1 = _bindingToken1();
        address t2 = _bindingToken2();
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
            _pullPermit2(token, amount);
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
        address[3] memory tokens = [_bindingToken0(), _bindingToken1(), _bindingToken2()];
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
            _pullPermit2(_bindingToken0(), u0);
        }
        if (u1 > 0) {
            _pullPermit2(_bindingToken1(), u1);
        }
        if (u2 > 0) {
            _pullPermit2(_bindingToken2(), u2);
        }
    }


}
