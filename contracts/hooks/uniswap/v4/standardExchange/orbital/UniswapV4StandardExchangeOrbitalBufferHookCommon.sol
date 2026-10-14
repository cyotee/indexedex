// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV4SeBufferHookContextQuoteLib as ContextQuote} from "contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookContextQuoteLib.sol";
import {UniswapV4StandardExchangeOrbitalBufferHookExitQuoteLib as ExitQuoteLib} from "contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookExitQuoteLib.sol";
import {UniswapV4SeBufferHookLegLib as LegLib} from "contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol";

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
        address se = Repo._seAt(l, i);
        if (se == address(0)) return l.reserves[Repo._tokenAt(l, i)] > 0;
        return IERC20(se).balanceOf(address(this)) > 0;
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

    /// @dev Booked face for a raw leg, held SE shares for a buffered leg. Not a rate.
    function _rawInventoryAt(uint8 i) internal view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        address se = Repo._seAt(l, i);
        if (se == address(0)) return l.reserves[Repo._tokenAt(l, i)];
        return IERC20(se).balanceOf(address(this));
    }

    function _rawSnap() private view returns (RawSnap memory s) {
        s.b0 = _rawInventoryAt(0);
        s.b1 = _rawInventoryAt(1);
        s.b2 = _rawInventoryAt(2);
    }

    /// @dev Face input in ownership units. A zero SE mint is zero credit, not the face amount.
    function _previewRawSharesFromFace(uint8 i, uint256 face) private view returns (uint256) {
        if (face == 0) return 0;
        Repo.Layout storage l = Repo._layout();
        address se = Repo._seAt(l, i);
        if (se == address(0)) return face;
        return ClaimLib.previewBufferSharesIn(se, Repo._tokenAt(l, i), face);
    }

    function _rawOffered(uint8 i, uint256 amount, bool isShare) private view returns (uint256) {
        if (isShare) return amount;
        return _previewRawSharesFromFace(i, amount);
    }

    /// @dev Smallest face at or under `faceMax` whose forward share preview covers `required`.
    ///      Raw and identity legs use the required amount itself. Zero means the max cannot back.
    function _faceForRawShares(uint8 i, uint256 required, uint256 faceMax) private view returns (uint256) {
        if (required == 0) return 0;
        Repo.Layout storage l = Repo._layout();
        address se = Repo._seAt(l, i);
        address token = Repo._tokenAt(l, i);
        if (se == address(0) || se == token) return required > faceMax ? 0 : required;
        return _searchFaceForShares(i, required, faceMax);
    }

    function _searchFaceForShares(uint8 i, uint256 required, uint256 faceMax) private view returns (uint256) {
        uint256 above = _previewRawSharesFromFace(i, faceMax);
        if (above < required || faceMax == 0) return 0;
        uint256 low = 1;
        uint256 high = faceMax;
        uint256 below;
        uint256 probes;
        while (low < high) {
            uint256 mid = low + (high - low) / 2;
            if (above > below && probes < 8) {
                mid = low - 1 + FullPrecisionMath.mulDiv(required - below, high - low + 1, above - below);
                if (mid < low) mid = low;
                if (mid >= high) mid = high - 1;
                unchecked { ++probes; }
            }
            uint256 got = _previewRawSharesFromFace(i, mid);
            if (got >= required) {
                high = mid;
                above = got;
            } else {
                low = mid + 1;
                below = got;
            }
        }
        if (_previewRawSharesFromFace(i, low) < required) return 0;
        return low;
    }

    function _usedForRawRequired(uint8 i, uint256 offered, bool isShare, uint256 required)
        private
        view
        returns (uint256)
    {
        if (required == 0) return 0;
        if (isShare) return required > offered ? 0 : required;
        return _faceForRawShares(i, required, offered);
    }

    function _guardFlexibleFullBookBacking(uint256 supply, DepositFlexibleVars memory v, RawSnap memory before)
        private
        view
    {
        if (supply == 0 || v.shares == 0 || v.amount0 == 0 || v.amount1 == 0 || v.amount2 == 0) return;
        (uint256 e0, uint256 e1, uint256 e2) = _effectiveWad();
        if (e0 == 0 || e1 == 0 || e2 == 0) return;
        _requireRawBacking(supply, v.shares, before);
    }

    function _requireRawBacking(uint256 supply, uint256 shares, RawSnap memory before) private view {
        if (!Math.rawInventoryBacks(_deliveredRaw(0, before.b0), supply, shares, before.b0)
            || !Math.rawInventoryBacks(_deliveredRaw(1, before.b1), supply, shares, before.b1)
            || !Math.rawInventoryBacks(_deliveredRaw(2, before.b2), supply, shares, before.b2))
        {
            revert InsufficientTokenOut();
        }
    }

    function _deliveredRaw(uint8 i, uint256 before) private view returns (uint256) {
        uint256 nowBal = _rawInventoryAt(i);
        if (nowBal < before) revert InsufficientTokenOut();
        return nowBal - before;
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
        // Identity legs custody their backing in the face token; keep its native-unit book.
        for (uint8 i; i < 3; ++i) {
            address token = Repo._tokenAt(l, i);
            if (Repo._seAt(l, i) == token) l.reserves[token] = IERC20(token).balanceOf(address(this));
        }
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

    function _bufferToken(address token, uint256 amount, bool quoteMin_) internal returns (uint256 seOut) {
        if (amount == 0) return 0;
        address se = _seOf(token);
        if (se == address(0)) {
            Repo._layout().reserves[token] += amount;
            return 0;
        }
        if (se == token) return amount;
        uint256 minOut;
        if (quoteMin_) {
            uint256 m = IStandardExchangeIn(se).previewExchangeIn(IERC20(token), amount, IERC20(se));
            minOut = m;
        }
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

    function _receiveOutput(address token, ExactInOutput memory output, bool quoteMin_)
        private returns (uint256 amountOut)
    {
        if (_seOf(token) == address(0)) {
            uint256 reserve = Repo._layout().reserves[token];
            if (output.amountOut == 0 || output.amountOut >= reserve) revert Math.Drain();
            Repo._layout().reserves[token] = reserve - output.amountOut;
            return output.amountOut;
        }
        if (output.sharesOut == 0) revert InsufficientTokenOut();
        if (output.sharesOut > _spendableSeShares(token)) revert Math.Drain();
        if (_seOf(token) == token) return output.sharesOut;
        uint256 beforeOut = IERC20(token).balanceOf(address(this));
        uint256 minOut = output.amountOut > 0 ? output.amountOut - 1 : 0;
        if (quoteMin_) _unwrapSeShares(token, output.sharesOut);
        else _unwrapSeShares(token, output.sharesOut, minOut);
        amountOut = IERC20(token).balanceOf(address(this)) - beforeOut;
        if (amountOut < output.amountOut) revert InsufficientTokenOut();
    }

    function _unwrapSeShares(address token, uint256 seIn) internal returns (uint256 pairOut) {
        if (seIn == 0) return 0;
        address se = _seOf(token);
        if (se == token) return seIn;
        uint256 m = IStandardExchangeIn(se).previewExchangeIn(IERC20(se), seIn, IERC20(token));
        return _unwrapSeShares(token, seIn, m > 0 ? m - 1 : 0);
    }

    function _unwrapSeShares(address token, uint256 seIn, uint256 minOut) internal returns (uint256 pairOut) {
        if (seIn == 0) return 0;
        address se = _seOf(token);
        if (se == token) return seIn;
        IERC20(se).forceApprove(se, seIn);
        pairOut = IStandardExchangeIn(se).exchangeIn(
            IERC20(se), seIn, IERC20(token), minOut, address(this), false, block.timestamp
        );
        IERC20(se).forceApprove(se, 0);
    }


    function _unwrapExactTokenOut(address token, uint256 amountOut) internal {
        if (amountOut == 0) return;
        address se = _seOf(token);
        if (se == token) return;
        uint256 cap = _spendableSeShares(token);
        if (cap == 0) revert InsufficientTokenOut();
        uint256 quotedIn = ClaimLib.invertUnwrapExactTokenOut(se, token, amountOut);
        if (quotedIn == 0 || quotedIn > cap) revert InsufficientTokenOut();
        uint256 maxIn = quotedIn;
        IERC20(se).forceApprove(se, maxIn);
        uint256 beforeOut = IERC20(token).balanceOf(address(this));
        IStandardExchangeOut(se).exchangeOut(
            IERC20(se), maxIn, IERC20(token), amountOut, address(this), false, block.timestamp
        );
        IERC20(se).forceApprove(se, 0);
        if (IERC20(token).balanceOf(address(this)) - beforeOut < amountOut) revert InsufficientTokenOut();
    }


    function _bufferLastUsed(uint256 u0, uint256 u1, uint256 u2) internal {
        // Binding index order for used > 0
        if (u0 > 0) _bufferToken(Repo._layout().token0, u0);
        if (u1 > 0) _bufferToken(Repo._layout().token1, u1);
        if (u2 > 0) _bufferToken(Repo._layout().token2, u2);
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


    function _previewSwapAfterExchange(address tokenIn, address pairToken, address rawTokenOut, uint256 amountIn)
        internal view returns (uint256 amountOut)
    {
        address se = _seOf(pairToken);
        if (se == address(0) || _seOf(rawTokenOut) != address(0)) revert InvalidPoolToken();
        SwapLiveCtx memory ctx = _loadSwapLiveCtx(pairToken, rawTokenOut);
        LegLib.ExternalQuote memory q = LegLib.afterExternalExchange(se, pairToken, tokenIn, amountIn, address(this));
        (uint256 minted,) = LegLib.depositAfterExchange(q, q.assets);
        // D60: a buffered leg is valued as shares x rate; the SE never values the hook's reserve.
        (uint256 held, uint256 inflow) = _projectedInputValue(q, pairToken, minted);
        if (held == 0) revert NotLive();
        SphereLegsWad memory legs = _loadSphereLegs(pairToken, rawTokenOut, ctx.tokenZ);
        legs.xWad = _toWad(pairToken, held);
        legs.L2 = Math.recomputeL2(legs.R, legs.xWad, legs.yWad, legs.zWad);
        uint256 net = Math.applyTradingFeeNet(_toWad(pairToken, inflow), ctx.feeWad);
        amountOut = _fromWadFloor(rawTokenOut, _sphereExactIn(legs, net));
        if (amountOut == 0 || amountOut >= ctx.eOutNative) revert Math.Drain();
    }

    function _projectedInputValue(LegLib.ExternalQuote memory q, address pair, uint256 minted)
        private view returns (uint256 held, uint256 inflow)
    {
        address provider = _rpOf(pair);
        if (provider == address(0)) revert ClaimLib.RateProviderRequired();
        uint256 rate = LegLib.rateAfterExchange(q, pair, provider);
        held = ClaimLib.ratedNative(q.heldShares, rate, address(q.exchange), pair);
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
            se == address(0) ? 0 : IERC20(se).balanceOf(address(this)), manager);
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


    function _faceInToEffectiveNative(address tokenIn, uint256 amountIn)
        private
        view
        returns (uint256 dInNative)
    {
        dInNative = amountIn;
        address se = _seOf(tokenIn);
        if (se != address(0) && se != tokenIn) {
            uint256 claim_ = ClaimLib.previewBufferClaimIn(se, _rpOf(tokenIn), tokenIn, amountIn, address(this));
            if (claim_ != 0) dInNative = claim_;
        }
    }


    function _effectiveOutToFaceOut(address tokenOut, uint256 dOutNative)
        private
        view
        returns (ExactInOutput memory output)
    {
        address se = _seOf(tokenOut);
        if (se != address(0)) {
            (output.amountOut, output.sharesOut) = ClaimLib.previewUnwrapForEffectiveOut(se, _rpOf(tokenOut), tokenOut, dOutNative);
            if (output.sharesOut == 0) revert InsufficientTokenOut();
            if (output.sharesOut > _spendableSeShares(tokenOut)) revert Math.Drain();
        } else {
            output.amountOut = dOutNative;
        }
    }


    function _invertBufferForEffective(address token, uint256 dInNative)
        internal
        view
        returns (uint256 amountInRaw)
    {
        if (dInNative == 0) return 0;
        return ClaimLib.invertBufferForEffective(_seOf(token), _rpOf(token), token, dInNative);
    }


    function _maybeMintProtocolFee() internal returns (uint256 protocolLp) {
        (bool feeOn, address feeTo_, uint256 ownerFeeShare,) = _feeOnAndShare();
        Repo.Layout storage l = Repo._layout();
        if (!feeOn || l.kLast == 0) return 0;

        (uint256 r0, uint256 r1, uint256 r2) = _effectiveWad();
        (uint8 mode, uint256 k, uint256 rootK) = _measureK(r0, r1, r2);
        if (mode != l.kLastMode) return 0;

        uint256 rootKLast = _rootFromStored(mode, l.kLast);
        protocolLp = Math.protocolLpShares(_totalSupply(), rootK, rootKLast, ownerFeeShare);
        if (protocolLp > 0) {
            _mintLp(feeTo_, protocolLp);
            l.kLast = k;
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
        if (a0Max == 0 && a1Max == 0 && a2Max == 0) return (0, 0, 0, 0);
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


    /// @dev Subsequent full-book ownership. Incumbent and contribution are raw inventory
    ///      units (booked face, or SE shares). Rates stay on the partial and swap paths.
    function _fullBookSharesUsed(uint256 a0Max, uint256 a1Max, uint256 a2Max, uint256 supply)
        private
        view
        returns (SharesUsed memory r)
    {
        uint256 b0 = _rawInventoryAt(0);
        uint256 b1 = _rawInventoryAt(1);
        uint256 b2 = _rawInventoryAt(2);
        uint256 c0 = _previewRawSharesFromFace(0, a0Max);
        uint256 c1 = _previewRawSharesFromFace(1, a1Max);
        uint256 c2 = _previewRawSharesFromFace(2, a2Max);
        r.shares = Math.rawFullBookShares(supply, c0, b0, c1, b1, c2, b2);
        if (r.shares == 0) return r;
        r.used0 = _faceForRawShares(0, Math.rawRequiredInventory(r.shares, b0, supply), a0Max);
        r.used1 = _faceForRawShares(1, Math.rawRequiredInventory(r.shares, b1, supply), a1Max);
        r.used2 = _faceForRawShares(2, Math.rawRequiredInventory(r.shares, b2, supply), a2Max);
        if (r.used0 == 0 || r.used1 == 0 || r.used2 == 0) {
            r.shares = 0;
            r.used0 = 0;
            r.used1 = 0;
            r.used2 = 0;
        }
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
        r.used0 = _executablePartialFace(0, r.used0, a0Max);
        r.used1 = _executablePartialFace(1, r.used1, a1Max);
        r.used2 = _executablePartialFace(2, r.used2, a2Max);
        r.shares = _partialNavShares(supply, e0n, e1n, e2n, r.used0, r.used1, r.used2);
    }


    /// @dev Forward deposit feasibility is discontinuous in native units. A
    /// ratio-rounded intake can fail even though the offered budget is valid.
    /// Both candidates are within the radius-capped budget; reprice LP from
    /// the selected amounts rather than executing a zero-quote reduced intake.
    function _executablePartialFace(uint8 i, uint256 used, uint256 offered) private view returns (uint256) {
        if (used == 0 || _previewRawSharesFromFace(i, used) != 0) return used;
        if (used != offered && _previewRawSharesFromFace(i, offered) != 0) return offered;
        return 0;
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
            if (!anyZ) return (0, 0, 0);
            return (used0, used1, used2);
        }
        if (minShares == 0) return (0, 0, 0);

        uint256 supply = _totalSupply();
        Repo.Layout storage l = Repo._layout();
        if (r0 > 0 && a0Max > 0) {
            used0 = _fromWadFloor(l.token0, Math.fullBookUsedWad(minShares, _toWad(l.token0, r0), supply));
            if (used0 == 0) return (0, 0, 0);
        }
        if (r1 > 0 && a1Max > 0) {
            used1 = _fromWadFloor(l.token1, Math.fullBookUsedWad(minShares, _toWad(l.token1, r1), supply));
            if (used1 == 0) return (0, 0, 0);
        }
        if (r2 > 0 && a2Max > 0) {
            used2 = _fromWadFloor(l.token2, Math.fullBookUsedWad(minShares, _toWad(l.token2, r2), supply));
            if (used2 == 0) return (0, 0, 0);
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

        FaceSnap memory snap = _faceSnap();
        _maybeMintProtocolFee();
        (shares, used0, used1, used2) = _fundFullOrPartial(a0Max, a1Max, a2Max, to, sharesMin, permit2Data);
        _refundConservation(msg.sender, snap);
        emit LiquidityAdded(msg.sender, to, shares, used0, used1, used2);
    }

    function _fundFullOrPartial(
        uint256 a0Max,
        uint256 a1Max,
        uint256 a2Max,
        address to,
        uint256 sharesMin,
        bytes memory permit2Data
    ) private returns (uint256 shares, uint256 used0, uint256 used1, uint256 used2) {
        uint256 supply = _totalSupply();
        RawSnap memory book = _rawSnap();
        bool fullBook = _offerIsFullBook(supply, a0Max, a1Max, a2Max);
        (shares, used0, used1, used2) = _computeAdd(a0Max, a1Max, a2Max, supply);
        if (shares == 0) revert ZeroAmount();
        if (shares < sharesMin) revert InsufficientSharesOut();
        _pullLegs(used0, used1, used2, permit2Data);
        _bufferLastUsed(used0, used1, used2);
        if (fullBook) _requireRawBacking(supply, shares, book);
        _applyAdd(supply, shares, used0, used1, used2, to);
    }

    function _offerIsFullBook(uint256 supply, uint256 a0, uint256 a1, uint256 a2) private view returns (bool) {
        if (supply == 0 || a0 == 0 || a1 == 0 || a2 == 0) return false;
        (uint256 e0, uint256 e1, uint256 e2) = _effectiveWad();
        return e0 > 0 && e1 > 0 && e2 > 0;
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
        return _removeLiquidityAndSettle(shares, to, a0Min, a1Min, a2Min, deadline, true);
    }

    function _removeLiquidityAndSettle(uint256 shares, address to, uint256 a0Min, uint256 a1Min,
        uint256 a2Min, uint256 deadline, bool refundFree)
        internal returns (uint256 a0, uint256 a1, uint256 a2)
    {
        return _removeLiquidityFrom(msg.sender, shares, to, a0Min, a1Min, a2Min, deadline, refundFree);
    }

    function _removeLiquidityFrom(address holder, uint256 shares, address to, uint256 a0Min, uint256 a1Min,
        uint256 a2Min, uint256 deadline, bool refundFree)
        internal returns (uint256 a0, uint256 a1, uint256 a2)
    {
        _requireDeadline(deadline);
        _requireNonZero(shares);
        if (to == address(0)) revert ZeroAddress();

        _maybeMintProtocolFee();
        if (shares > _balanceOf(holder)) revert InsufficientSharesOut();

        (a0, a1, a2) = _proRataOut(shares);
        if (a0 < a0Min || a1 < a1Min || a2 < a2Min) revert InsufficientTokenOut();

        (a0, a1, a2) = _burnAndPay(holder, shares, to, a0, a1, a2, refundFree);
        emit LiquidityRemoved(msg.sender, to, shares, a0, a1, a2);
    }


    function _exitSingleAssetFrom(address holder, address tokenOut, uint256 shares, address to, uint256 deadline)
        internal returns (uint256 amountOut)
    {
        address pair = _resolveBurnTokenOut(tokenOut);
        if (pair == address(0)) revert InvalidRoute(tokenOut, address(0));
        if (to == address(0)) revert ZeroAddress();
        uint256 freeBefore = _freeTokenBalance(pair);
        uint256[3] memory amounts;
        (amounts[0], amounts[1], amounts[2]) = _removeLiquidityFrom(
            holder, shares, address(this), 0, 0, 0, deadline, false
        );
        for (uint8 i; i < 3; ++i) {
            address input = Repo._tokenAt(Repo._layout(), i);
            if (input == pair || amounts[i] == 0) continue;
            _internalSwapExactIn(input, pair, amounts[i], _feeOracle().dexSwapFeeOfVault(address(this)));
        }
        amountOut = _freeTokenBalance(pair) - freeBefore;
        if (tokenOut != pair && amountOut > 0) amountOut = _bufferToken(pair, amountOut);
        IERC20(tokenOut).safeTransfer(to, amountOut);
        _syncVaultReserves();
    }

    function _resolveBurnTokenOut(address tokenOut) internal view returns (address) {
        Repo.Layout storage l = Repo._layout();
        LegLib.LegKind kind_ = LegLib.classify(l.legs, tokenOut);
        if (kind_ == LegLib.LegKind.StandardExchange) return l.legs.pairOfStandardExchange[tokenOut];
        if (kind_ == LegLib.LegKind.Pair || kind_ == LegLib.LegKind.Detf) return tokenOut;
        return address(0);
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


    function _burnAndPay(address holder, uint256 shares, address to, uint256 a0, uint256 a1, uint256 a2, bool refundFree)
        private
        returns (uint256, uint256, uint256)
    {
        Repo.Layout storage l = Repo._layout();
        FaceSnap memory snap = _faceSnap();
        uint256 supply = _totalSupply();
        _burnLp(holder, shares);

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
        if (refundFree) _refundConservation(msg.sender, snap);
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

        FaceSnap memory snap = _faceSnap();
        _maybeMintProtocolFee();
        uint256 supply = _totalSupply();
        RawSnap memory book = _rawSnap();
        _fillComputeAddFlexible(v, supply);
        if (v.shares == 0) revert ZeroAmount();
        if (v.shares < v.sharesMin) revert InsufficientSharesOut();

        _pullFlexible(v);
        _bufferFlexibleUsed(v);
        _guardFlexibleFullBookBacking(supply, v, book);
        _applyAdd(supply, v.shares, v.used0, v.used1, v.used2, v.to);
        _refundConservation(msg.sender, snap);
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
            if (rp == address(0)) revert ClaimLib.RateProviderRequired();
            return ClaimLib.ratedNative(amount, ClaimLib.getRateFailClosed(rp), se, token);
        }
        return _previewClaimInAt(i, amount);
    }


    function _fillComputeAddFlexible(DepositFlexibleVars memory v, uint256 supply) private view {
        FlexScratch memory s;
        s.supply = supply;

        if (supply == 0) {
            s.o0 = _offeredEffectiveNative(0, v.amount0, v.amount0IsSeShare);
            s.o1 = _offeredEffectiveNative(1, v.amount1, v.amount1IsSeShare);
            s.o2 = _offeredEffectiveNative(2, v.amount2, v.amount2IsSeShare);
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
            if (v.amount0 == 0 && v.amount1 == 0 && v.amount2 == 0) return;
        }
        s.o0 = _offeredEffectiveNative(0, v.amount0, v.amount0IsSeShare);
        s.o1 = _offeredEffectiveNative(1, v.amount1, v.amount1IsSeShare);
        s.o2 = _offeredEffectiveNative(2, v.amount2, v.amount2IsSeShare);
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
        uint256 b0 = _rawInventoryAt(0);
        uint256 b1 = _rawInventoryAt(1);
        uint256 b2 = _rawInventoryAt(2);
        uint256 c0 = _rawOffered(0, v.amount0, v.amount0IsSeShare);
        uint256 c1 = _rawOffered(1, v.amount1, v.amount1IsSeShare);
        uint256 c2 = _rawOffered(2, v.amount2, v.amount2IsSeShare);
        v.shares = Math.rawFullBookShares(s.supply, c0, b0, c1, b1, c2, b2);
        if (v.shares == 0) return;
        v.used0 = _usedForRawRequired(0, v.amount0, v.amount0IsSeShare, Math.rawRequiredInventory(v.shares, b0, s.supply));
        v.used1 = _usedForRawRequired(1, v.amount1, v.amount1IsSeShare, Math.rawRequiredInventory(v.shares, b1, s.supply));
        v.used2 = _usedForRawRequired(2, v.amount2, v.amount2IsSeShare, Math.rawRequiredInventory(v.shares, b2, s.supply));
        if (v.used0 == 0 || v.used1 == 0 || v.used2 == 0) {
            v.shares = 0;
            v.used0 = 0;
            v.used1 = 0;
            v.used2 = 0;
        }
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
        if (u0 == 0 && u1 == 0 && u2 == 0) return 0;
        uint256 radius = Repo._layout().R;
        if (supply == 0 || radius == 0) return 0;
        Repo.Layout storage l = Repo._layout();
        Math.SphereNavArgs memory nav;
        nav.supply = supply;
        nav.R = radius;
        nav.r0Wad = _toWad(l.token0, e0n);
        nav.r1Wad = _toWad(l.token1, e1n);
        nav.r2Wad = _toWad(l.token2, e2n);
        if (nav.r0Wad >= radius || nav.r1Wad >= radius || nav.r2Wad >= radius) return 0;
        nav.used0Wad = _toWad(l.token0, u0);
        nav.used1Wad = _toWad(l.token1, u1);
        nav.used2Wad = _toWad(l.token2, u2);
        return Math.sphereNavShares(nav);
    }


    function _pullFlexible(DepositFlexibleVars memory v) private {
        Repo.Layout storage l = Repo._layout();
        if (v.used0 > 0) {
            address t0 = v.amount0IsSeShare ? l.se0 : l.token0;
            _pullDirectExact(t0, v.used0);
        }
        if (v.used1 > 0) {
            address t1 = v.amount1IsSeShare ? l.se1 : l.token1;
            _pullDirectExact(t1, v.used1);
        }
        if (v.used2 > 0) {
            address t2 = v.amount2IsSeShare ? l.se2 : l.token2;
            _pullDirectExact(t2, v.used2);
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
        FaceSnap memory snap = _faceSnap();
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
        _refundConservation(msg.sender, snap);
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

        FaceSnap memory snap = _faceSnap();
        _maybeMintProtocolFee();
        ZapPlan memory plan = _planZap(tokenIn, amountIn);
        if (plan.shares == 0) revert ZeroAmount();
        if (plan.shares < sharesMin) revert InsufficientSharesOut();

        _pullTokenIn(tokenIn, amountIn, permit2Data);
        return _executeDepositSinglePlan(tokenIn, amountIn, to, plan, snap);
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

        FaceSnap memory snap = _faceSnap();
        Repo.Layout storage l = Repo._layout();
        if (tokenIn == l.token0) snap.o0 -= amountIn;
        else if (tokenIn == l.token1) snap.o1 -= amountIn;
        else snap.o2 -= amountIn;
        _maybeMintProtocolFee();
        ZapPlan memory plan = _planZap(tokenIn, amountIn);
        if (plan.shares == 0) revert ZeroAmount();
        if (plan.shares < sharesMin) revert InsufficientSharesOut();
        return _executeDepositSinglePlan(tokenIn, amountIn, to, plan, snap);
    }

    function _executeDepositSinglePlan(
        address tokenIn,
        uint256 amountIn,
        address to,
        ZapPlan memory plan,
        FaceSnap memory snap
    ) private returns (uint256 shares) {
        _executeZapSwaps(tokenIn, plan);
        uint256 supplyBefore = _totalSupply();
        _bufferLastUsed(plan.used0, plan.used1, plan.used2);
        // Planned zap settlement does not reproduce the projection exactly on fee-bearing
        // nested pools. Re-checking the quoted mint against that live book rejects a few
        // share wei and splits preview from execution. Direct joins still check backing.
        _syncRawFaceToBook();
        _applyAdd(supplyBefore, plan.shares, plan.used0, plan.used1, plan.used2, to);
        shares = plan.shares;
        _refundConservation(msg.sender, snap);
        emit DepositSingle(msg.sender, to, tokenIn, amountIn, shares);
    }

    /// @dev Internal sphere swaps rebook without moving face. Floor/ceil of used vs
    ///      sales leaves raw face above `reserves`. Raise the book to face so leftover
    ///      free face is zero (SeLifecycle). Buffered SE legs keep share-backed book.
    function _syncRawFaceToBook() private {
        Repo.Layout storage l = Repo._layout();
        _raiseRawBookToFace(l.token0, l.se0);
        _raiseRawBookToFace(l.token1, l.se1);
        _raiseRawBookToFace(l.token2, l.se2);
    }

    function _raiseRawBookToFace(address token, address se) private {
        if (se != address(0)) return;
        uint256 bal = IERC20(token).balanceOf(address(this));
        uint256 book = Repo._layout().reserves[token];
        if (bal > book) Repo._layout().reserves[token] = bal;
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


    function _executeZapSwaps(address tokenIn, ZapPlan memory plan) private {
        Repo.Layout storage l = Repo._layout();
        address tokenJ = Repo._tokenAt(l, plan.j);
        address tokenK = Repo._tokenAt(l, plan.k);
        uint256 feeWad = _feeOracle().dexSwapFeeOfVault(address(this));
        if (plan.saleJ > 0) {
            uint256 gotJ = _executePlannedOrQuotedSwap(tokenIn, tokenJ, plan.saleJ, plan.outJ, plan.sharesJ, feeWad);
            emit ZapSwap(msg.sender, tokenIn, tokenJ, plan.saleJ, gotJ);
        }
        if (plan.saleK > 0) {
            uint256 gotK = _executePlannedOrQuotedSwap(tokenIn, tokenK, plan.saleK, plan.outK, plan.sharesK, feeWad);
            emit ZapSwap(msg.sender, tokenIn, tokenK, plan.saleK, gotK);
        }
    }

    /// @dev The deposit plan already simulated this swap, including the sequential rate.
    ///      Re-quoting inside the 31M chain cap runs out of gas on the second leg and
    ///      reports RateProviderFailed. Settle the planned output.
    function _executePlannedOrQuotedSwap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 plannedOut,
        uint256 plannedShares,
        uint256 feeWad
    ) private returns (uint256 amountOut) {
        feeWad;
        ExactInOutput memory output;
        output.amountOut = plannedOut;
        output.sharesOut = plannedShares;
        amountOut = _receivePlannedOutput(tokenOut, output);
        if (_seOf(tokenIn) != address(0)) _bufferToken(tokenIn, amountIn, false);
        else Repo._layout().reserves[tokenIn] += amountIn;
        _recomputeL2();
    }


    function _internalSwapExactIn(address tokenIn, address tokenOut, uint256 amountIn, uint256 feeWad)
        internal
        returns (uint256 amountOut)
    {
        // Single-source fee with zap plan (do not re-fetch oracle fee inside preview).
        ExactInOutput memory output = _previewSwapExactInPlan(tokenIn, tokenOut, amountIn, feeWad);
        amountOut = _receiveExactInOutput(tokenOut, output);
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
        (uint256 e0, uint256 e1, uint256 e2) = _effectiveWad();
        if (e0 + 1 >= l.R || e1 + 1 >= l.R || e2 + 1 >= l.R
            || (eIn > 0 && amountIn > eIn && _ratioZapWouldDrain(p.inIdx, amountIn)))
        {
            return _singleSidedPlan(tokenIn, amountIn);
        }

        if (e0 == 0 || e1 == 0 || e2 == 0 || l.R == 0
            || _toWad(tokenIn, amountIn) < 3)
        {
            return _singleSidedPlan(tokenIn, amountIn);
        }

        ExitQuoteLib.DepositQuote memory q = ExitQuoteLib.planDeposit(tokenIn, amountIn);
        if (q.shares == 0) return _singleSidedPlan(tokenIn, amountIn);
        p.saleJ = q.saleJ;
        p.saleK = q.saleK;
        p.residual = q.offered[p.inIdx];
        p.outJ = q.offered[p.j];
        p.outK = q.offered[p.k];
        p.sharesJ = q.sharesJ;
        p.sharesK = q.sharesK;
        p.shares = q.shares;
        p.used0 = q.used[0];
        p.used1 = q.used[1];
        p.used2 = q.used[2];
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
    function _faceSnap() internal view returns (FaceSnap memory snap) {
        Repo.Layout storage l = Repo._layout();
        snap.o0 = IERC20(l.token0).balanceOf(address(this));
        snap.o1 = IERC20(l.token1).balanceOf(address(this));
        snap.o2 = IERC20(l.token2).balanceOf(address(this));
    }

    /// @dev Refund this-call surplus only. Non-identity buffered legs: face above the opening
    ///      snap (`offered - used` plus SE receipts this call). Identity (`se == token`): 0
    ///      (share backing). Raw: 0 (unused is not pulled; resting above book stays as book).
    ///      Never the whole free balance. Dust, including amounts at or below `MAX_DUST_WEI`,
    ///      is returned when it is this-call surplus.
    function _refundConservation(address to, FaceSnap memory snap) internal {
        if (to == address(0)) return;
        Repo.Layout storage l = Repo._layout();
        _refundThisCallSurplus(l.token0, l.se0, snap.o0, to);
        _refundThisCallSurplus(l.token1, l.se1, snap.o1, to);
        _refundThisCallSurplus(l.token2, l.se2, snap.o2, to);
    }

    function _refundThisCallSurplus(address token, address se, uint256 opening, address to) private {
        if (se == token || se == address(0)) return;
        uint256 bal = IERC20(token).balanceOf(address(this));
        if (bal > opening) IERC20(token).safeTransfer(to, bal - opening);
    }


    function _freeTokenBalance(address token) internal view returns (uint256 free) {
        uint256 bal = IERC20(token).balanceOf(address(this));
        if (_seOf(token) != address(0)) {
            if (_seOf(token) == token) return 0;
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
        address se = _seOf(address(token));
        uint256 booked = se == address(0) || se == address(token)
            ? Repo._layout().reserves[address(token)] : 0;
        return LocalCreditLib.available(token.balanceOf(address(this)), booked);
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
