// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IFeeCollectorProxy} from "contracts/interfaces/proxies/IFeeCollectorProxy.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {
    toBeforeSwapDelta,
    BeforeSwapDelta
} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BeforeSwapDelta.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {Hooks} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol";
import {ModifyLiquidityParams, SwapParams} from
    "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {BalanceDelta} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";

import {
    UniswapV4DualStandardExchangeBufferConstantProductHookRepo as Repo
} from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookRepo.sol";
import {
    UniswapV4DualStandardExchangeBufferConstantProductHookMath as Math
} from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookMath.sol";
import {
    UniswapV4DualStandardExchangeBufferConstantProductHookClaimLib as ClaimLib
} from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookClaimLib.sol";
import {
    UniswapV4DualStandardExchangeBufferConstantProductHookPullLib as PullLib
} from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookPullLib.sol";
import {
    IUniswapV4DualStandardExchangeBufferConstantProductHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/dual/interfaces/IUniswapV4DualStandardExchangeBufferConstantProductHook.sol";

/**
 * @title UniswapV4DualStandardExchangeBufferConstantProductHookCommon
 * @notice Product logic: dual SE buffer CP hooks, deposit/withdraw/zap, product views.
 * @dev LP ERC-20 + IBasicVault/IStandardVault are shared facets. Bindings in Repo (initAccount).
 *      B6: depositFlexible / withdrawFlexible for pair and/or SE share per leg.
 *      M3: IStandardExchangeIn/Out for pair0↔pair1 book swaps (SeFacet).
 */
abstract contract UniswapV4DualStandardExchangeBufferConstantProductHookCommon {
    using SafeERC20 for IERC20;

    address internal constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    error ZeroAddress();
    error ZeroAmount();
    error NotPoolManager();
    error TokenNotInVaultTokens();
    error SameStandardExchange();
    error SamePairToken();
    error NotLive();
    error NotZapEligible();
    error InvalidPairToken();
    error DeadlineExpired();
    error InsufficientLpOut();
    error InsufficientTokenOut();
    error AlreadyInitialized();
    error Reentrancy();
    error LiquidityNotAllowed();
    error InvalidPoolToken();
    error InvalidPoolFee();
    error HookNotImplemented();
    error InvalidPermit2Data();
    error UnsupportedRoute();

    modifier nonReentrant() {
        Repo.Layout storage l = Repo._layout();
        if (l.reentrancyStatus == Repo.ENTERED) revert Reentrancy();
        l.reentrancyStatus = Repo.ENTERED;
        _;
        l.reentrancyStatus = Repo.NOT_ENTERED;
    }

    /// @dev Stack-safe frame for flexible deposit (B6).
    struct DepositFlexibleVars {
        uint256 amount0;
        bool amount0IsSeShare;
        uint256 amount1;
        bool amount1IsSeShare;
        address to;
        uint256 minLpAmount;
        address se0;
        address se1;
        address currency0;
        address currency1;
        uint256 used0;
        uint256 used1;
        uint256 lpAmount;
    }

    /// @dev Stack-safe frame for flexible withdraw (B6).
    struct WithdrawFlexibleVars {
        address to;
        bool receiveSeShare0;
        bool receiveSeShare1;
        uint256 minAmount0;
        uint256 minAmount1;
        address se0;
        address se1;
        address currency0;
        address currency1;
        uint256 seOut0;
        uint256 seOut1;
        uint256 amount0;
        uint256 amount1;
    }

    /// @dev Stack-safe intermediate for single-asset deposit preview.
    struct DepositSinglePreview {
        uint256 amountToSwap;
        uint256 amountOtherOut;
        uint256 amountKeptIn;
        uint256 x;
        uint256 y;
        uint256 used0;
        uint256 used1;
    }


    /* views used by deposit/withdraw internals (also on Hooks Facet) */
    function claimSupply0() public view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        return _claimSupply(l.se0, l.token0);
    }

    function claimSupply1() public view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        return _claimSupply(l.se1, l.token1);
    }

    function claimSupplyCurrency0() public view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        return _claimSupply(_seFor(l.currency0), l.currency0);
    }

    function claimSupplyCurrency1() public view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        return _claimSupply(_seFor(l.currency1), l.currency1);
    }

    /* ---- shared internals (Option 1a Common) ---- */

    function _securePull(IERC20 tokenIn, uint256 claimed, bool pretransferred)
        internal
        returns (uint256 observedDelta)
    {
        uint256 B0 = tokenIn.balanceOf(address(this));
        if (!pretransferred) {
            tokenIn.safeTransferFrom(msg.sender, address(this), claimed);
            return tokenIn.balanceOf(address(this)) - B0;
        }
        uint256 R = MultiAssetBasicVaultRepo._reserveOfToken(address(tokenIn));
        uint256 U = B0 >= R ? B0 - R : B0;
        if (claimed > U) {
            revert ISecurePullErrors.TransferDeltaInsufficient(claimed, U);
        }
        return claimed;
    }


    function _claimSupply(address se, address pairToken) internal view returns (uint256) {
        uint256 seBal = IERC20(se).balanceOf(address(this));
        if (seBal == 0) return 0;
        return IStandardExchangeIn(se).previewExchangeIn(IERC20(se), seBal, IERC20(pairToken));
    }


    function _seFor(address pairToken) internal view returns (address) {
        Repo.Layout storage l = Repo._layout();
        if (pairToken == l.token0) return l.se0;
        if (pairToken == l.token1) return l.se1;
        revert InvalidPairToken();
    }


    function _isBoundPairToken(address token) internal view returns (bool) {
        Repo.Layout storage l = Repo._layout();
        return token == l.token0 || token == l.token1;
    }


    function _isLive() internal view returns (bool) {
        return claimSupplyCurrency0() > 0 && claimSupplyCurrency1() > 0;
    }


    function _isZapEligible() internal view returns (bool) {
        return _isLive() && ERC20Repo._totalSupply() > Repo.MINIMUM_LIQUIDITY;
    }


    function _requireLive() internal view {
        if (!_isLive()) revert NotLive();
    }


    function _requireZapEligible() internal view {
        if (!_isZapEligible()) revert NotZapEligible();
    }


    function _onlyPoolManager() internal view {
        if (msg.sender != Repo._layout().poolManager) revert NotPoolManager();
    }


    function _requireNonZero(uint256 amount) internal pure {
        if (amount == 0) revert ZeroAmount();
    }


    function _requireDeadline(uint256 deadline) internal view {
        if (block.timestamp > deadline) revert DeadlineExpired();
    }


    function _decimalsCurrency0() internal view returns (uint8) {
        return Repo._layout().decimalsCurrency0;
    }


    function _decimalsCurrency1() internal view returns (uint8) {
        return Repo._layout().decimalsCurrency1;
    }


    function _decimalsOf(address token) internal view returns (uint8) {
        Repo.Layout storage l = Repo._layout();
        if (token == l.currency0) return l.decimalsCurrency0;
        if (token == l.currency1) return l.decimalsCurrency1;
        revert InvalidPairToken();
    }


    function _wadProduct() internal view returns (uint256) {
        uint256 xN = Math.toWad(claimSupplyCurrency0(), _decimalsCurrency0());
        uint256 yN = Math.toWad(claimSupplyCurrency1(), _decimalsCurrency1());
        return xN * yN;
    }


    function _feeOnAndShare() internal view returns (bool feeOn, address feeTo_, uint256 ownerFeeShare) {
        (IFeeCollectorProxy ft, uint256 dexFeeWad) =
            IVaultFeeOracleQuery(Repo._layout().feeOracle).dexSwapFeeAndFeeToOfVault(address(this));
        feeTo_ = address(ft);
        feeOn = feeTo_ != address(0) && dexFeeWad != 0;
        ownerFeeShare = (dexFeeWad * Repo.TRADING_FEE_DENOMINATOR) / 1e18;
    }


    function _previewBufferClaimIn(address se, address pairToken, uint256 amountInRaw)
        internal
        view
        returns (uint256)
    {
        return ClaimLib.previewBufferClaimIn(
            se, pairToken, amountInRaw, IVaultFeeOracleQuery(Repo._layout().feeOracle), address(this)
        );
    }


    function _invertBufferClaimIn(address se, address pairToken, uint256 claimInNeeded)
        internal
        view
        returns (uint256)
    {
        return ClaimLib.invertBufferClaimIn(
            se, pairToken, claimInNeeded, IVaultFeeOracleQuery(Repo._layout().feeOracle), address(this)
        );
    }


    function _buffer(address se, address pairToken, uint256 amount) internal returns (uint256 seOut) {
        _requireNonZero(amount);
        uint256 minOut = IStandardExchangeIn(se).previewExchangeIn(
            IERC20(pairToken), amount, IERC20(se)
        );
        IERC20(pairToken).forceApprove(se, amount);
        seOut = IStandardExchangeIn(se).exchangeIn(
            IERC20(pairToken), amount, IERC20(se), minOut, address(this), false, block.timestamp
        );
    }


    function _unwrap(address se, address pairToken, uint256 seIn) internal returns (uint256 tokenOut) {
        _requireNonZero(seIn);
        uint256 minOut = IStandardExchangeIn(se).previewExchangeIn(
            IERC20(se), seIn, IERC20(pairToken)
        );
        tokenOut = IStandardExchangeIn(se).exchangeIn(
            IERC20(se), seIn, IERC20(pairToken), minOut, address(this), false, block.timestamp
        );
    }


    function _unwrapExactOut(address se, address pairToken, uint256 tokenOut)
        internal
        returns (uint256 seIn)
    {
        _requireNonZero(tokenOut);
        seIn = IStandardExchangeOut(se).previewExchangeOut(IERC20(se), IERC20(pairToken), tokenOut);
        uint256 spent = IStandardExchangeOut(se).exchangeOut(
            IERC20(se), seIn, IERC20(pairToken), tokenOut, address(this), false, block.timestamp
        );
        require(spent == seIn, "unwrap exact-out");
    }


    function _take(Currency currency, address to, uint256 amount) internal {
        if (amount == 0) return;
        IPoolManager(Repo._layout().poolManager).take(currency, to, amount);
    }


    function _settle(Currency currency, uint256 amount) internal {
        if (amount == 0) return;
        IPoolManager pm = IPoolManager(Repo._layout().poolManager);
        pm.sync(currency);
        IERC20(Currency.unwrap(currency)).safeTransfer(address(pm), amount);
        pm.settle();
    }


    function _mintLp(address to, uint256 amount) internal {
        if (amount == 0) return;
        ERC20Repo._mint(to, amount);
    }


    function _burnLp(address from, uint256 amount) internal {
        ERC20Repo._burn(from, amount);
    }


    function _syncReserves() internal {
        Repo.Layout storage l = Repo._layout();
        MultiAssetBasicVaultRepo._updateReserve(IERC20(l.currency0), claimSupplyCurrency0());
        MultiAssetBasicVaultRepo._updateReserve(IERC20(l.currency1), claimSupplyCurrency1());
    }


    function _refundPairDust(address token, address to) internal {
        uint256 bal = IERC20(token).balanceOf(address(this));
        if (bal > Repo.MAX_DUST_WEI) {
            IERC20(token).safeTransfer(to, bal);
        }
    }


    function _refundBothPairDust(address to) internal {
        Repo.Layout storage l = Repo._layout();
        _refundPairDust(l.currency0, to);
        _refundPairDust(l.currency1, to);
    }


    function _swapExactIn(bool zeroForOne, uint256 amountInRaw)
        internal
        returns (BeforeSwapDelta swapDelta)
    {
        _requireNonZero(amountInRaw);
        (address tokenIn, address tokenOut, address seIn, address seOut) = _swapLegs(zeroForOne);
        uint256 reserveOut = _claimSupply(seOut, tokenOut);
        uint256 amountOut = _quoteExactInAmountOut(tokenIn, tokenOut, seIn, seOut, amountInRaw);
        if (amountOut == 0 || amountOut >= reserveOut) revert InsufficientTokenOut();

        _take(Currency.wrap(tokenIn), address(this), amountInRaw);
        _buffer(seIn, tokenIn, amountInRaw);
        _unwrapExactOut(seOut, tokenOut, amountOut);
        _settle(Currency.wrap(tokenOut), amountOut);

        swapDelta = toBeforeSwapDelta(int128(int256(amountInRaw)), int128(-int256(amountOut)));
    }


    function _swapExactOut(bool zeroForOne, uint256 amountOut)
        internal
        returns (BeforeSwapDelta swapDelta)
    {
        _requireNonZero(amountOut);
        (address tokenIn, address tokenOut, address seIn, address seOut) = _swapLegs(zeroForOne);
        uint256 reserveOut = _claimSupply(seOut, tokenOut);
        if (amountOut >= reserveOut) revert InsufficientTokenOut();
        uint256 amountInRaw = _quoteExactOutAmountIn(tokenIn, tokenOut, seIn, seOut, amountOut);
        _requireNonZero(amountInRaw);

        _take(Currency.wrap(tokenIn), address(this), amountInRaw);
        _buffer(seIn, tokenIn, amountInRaw);
        _unwrapExactOut(seOut, tokenOut, amountOut);
        _settle(Currency.wrap(tokenOut), amountOut);

        swapDelta = toBeforeSwapDelta(int128(-int256(amountOut)), int128(int256(amountInRaw)));
    }


    function _swapLegs(bool zeroForOne)
        internal
        view
        returns (address tokenIn, address tokenOut, address seIn, address seOut)
    {
        Repo.Layout storage l = Repo._layout();
        tokenIn = zeroForOne ? l.currency0 : l.currency1;
        tokenOut = zeroForOne ? l.currency1 : l.currency0;
        seIn = _seFor(tokenIn);
        seOut = _seFor(tokenOut);
    }


    function _quoteExactInAmountOut(
        address tokenIn,
        address tokenOut,
        address seIn,
        address seOut,
        uint256 amountInRaw
    ) internal view returns (uint256 amountOut) {
        uint256 claimIn = _previewBufferClaimIn(seIn, tokenIn, amountInRaw);
        uint256 claimInN = Math.toWad(claimIn, _decimalsOf(tokenIn));
        uint256 rInN = Math.toWad(_claimSupply(seIn, tokenIn), _decimalsOf(tokenIn));
        uint256 rOutN = Math.toWad(_claimSupply(seOut, tokenOut), _decimalsOf(tokenOut));
        amountOut = Math.fromWadFloor(Math.saleQuote(claimInN, rInN, rOutN), _decimalsOf(tokenOut));
    }


    function _quoteExactOutAmountIn(
        address tokenIn,
        address tokenOut,
        address seIn,
        address seOut,
        uint256 amountOut
    ) internal view returns (uint256 amountInRaw) {
        uint256 claimInN = Math.purchaseQuote(
            Math.toWad(amountOut, _decimalsOf(tokenOut)),
            Math.toWad(_claimSupply(seIn, tokenIn), _decimalsOf(tokenIn)),
            Math.toWad(_claimSupply(seOut, tokenOut), _decimalsOf(tokenOut))
        );
        uint256 claimIn = Math.fromWadCeil(claimInN, _decimalsOf(tokenIn));
        amountInRaw = _invertBufferClaimIn(seIn, tokenIn, claimIn);
    }


    function _deposit(
        uint256 amount0,
        uint256 amount1,
        address to,
        uint256 minLpAmount,
        uint256 deadline
    ) internal returns (uint256 lpAmount, uint256 used0, uint256 used1) {
        _requireDeadline(deadline);
        _requireNonZero(amount0);
        _requireNonZero(amount1);
        _mintProtocolFeeIfNeeded(true);

        Repo.Layout storage l = Repo._layout();
        if (ERC20Repo._totalSupply() == 0) {
            used0 = amount0;
            used1 = amount1;
            lpAmount = _firstMint(used0, used1, to);
        } else {
            (used0, used1) = _clampToClaimRatio(amount0, amount1);
            if (amount0 > used0) IERC20(l.currency0).safeTransfer(msg.sender, amount0 - used0);
            if (amount1 > used1) IERC20(l.currency1).safeTransfer(msg.sender, amount1 - used1);
            uint256 xBefore = claimSupplyCurrency0();
            uint256 yBefore = claimSupplyCurrency1();
            _buffer(_seFor(l.currency0), l.currency0, used0);
            _buffer(_seFor(l.currency1), l.currency1, used1);
            lpAmount = _mintFromClaimDeltas(xBefore, yBefore, to);
        }

        if (lpAmount < minLpAmount) revert InsufficientLpOut();
        _setKLastPostOp();
        _refundBothPairDust(msg.sender);
        _syncReserves();
        emit IHook.Deposit(msg.sender, to, used0, used1, lpAmount);
    }


    function _firstMint(uint256 used0, uint256 used1, address to)
        internal
        returns (uint256 lpAmount)
    {
        Repo.Layout storage l = Repo._layout();
        _buffer(_seFor(l.currency0), l.currency0, used0);
        _buffer(_seFor(l.currency1), l.currency1, used1);
        uint256 geometric = Math.mintSharesFirst(
            Math.toWad(claimSupplyCurrency0(), _decimalsCurrency0()),
            Math.toWad(claimSupplyCurrency1(), _decimalsCurrency1())
        );
        if (geometric <= Repo.MINIMUM_LIQUIDITY) revert InsufficientLpOut();
        lpAmount = geometric - Repo.MINIMUM_LIQUIDITY;
        _mintLp(address(0), Repo.MINIMUM_LIQUIDITY);
        _mintLp(to, lpAmount);
    }


    function _depositSingle(
        address tokenIn,
        uint256 amountIn,
        address to,
        uint256 minLpAmount,
        uint256 deadline
    ) internal returns (uint256 lpAmount) {
        _requireDeadline(deadline);
        _requireNonZero(amountIn);
        if (!_isBoundPairToken(tokenIn)) revert InvalidPairToken();
        _requireZapEligible();
        _mintProtocolFeeIfNeeded(true);

        (uint256 saleAmt, uint256 amountOtherOut) = _executeZapSwap(tokenIn, amountIn);
        lpAmount = _proportionalAddAfterZap(tokenIn, amountIn - saleAmt, amountOtherOut, to);
        if (lpAmount < minLpAmount) revert InsufficientLpOut();

        _setKLastPostOp();
        _refundBothPairDust(msg.sender);
        _syncReserves();
        emit IHook.DepositSingle(msg.sender, to, tokenIn, amountIn, lpAmount);
    }


    function _executeZapSwap(address tokenIn, uint256 amountIn)
        internal
        returns (uint256 saleAmt, uint256 amountOtherOut)
    {
        Repo.Layout storage l = Repo._layout();
        address tokenOut = tokenIn == l.currency0 ? l.currency1 : l.currency0;
        address seIn = _seFor(tokenIn);
        address seOut = _seFor(tokenOut);
        saleAmt = _computeSaleAmt(tokenIn, amountIn, seIn);
        amountOtherOut = _quoteExactInAmountOut(tokenIn, tokenOut, seIn, seOut, saleAmt);
        if (amountOtherOut == 0) revert InsufficientTokenOut();
        _buffer(seIn, tokenIn, saleAmt);
        _unwrapExactOut(seOut, tokenOut, amountOtherOut);
        emit IHook.ZapSwap(msg.sender, tokenIn, tokenOut, saleAmt, amountOtherOut);
    }


    function _computeSaleAmt(address tokenIn, uint256 amountIn, address seIn)
        internal
        view
        returns (uint256 saleAmt)
    {
        uint8 decIn = _decimalsOf(tokenIn);
        uint256 rInN = Math.toWad(_claimSupply(seIn, tokenIn), decIn);
        saleAmt = Math.fromWadFloor(
            Math.swapDepositSaleAmt(Math.toWad(amountIn, decIn), rInN), decIn
        );
        if (saleAmt > amountIn) saleAmt = amountIn;
        if (saleAmt == 0) saleAmt = amountIn / 2;
    }


    function _proportionalAddAfterZap(
        address tokenIn,
        uint256 keptIn,
        uint256 amountOtherOut,
        address to
    ) internal returns (uint256 lpAmount) {
        Repo.Layout storage l = Repo._layout();
        uint256 add0 = tokenIn == l.currency0 ? keptIn : amountOtherOut;
        uint256 add1 = tokenIn == l.currency0 ? amountOtherOut : keptIn;
        (uint256 used0, uint256 used1) = _clampToClaimRatio(add0, add1);
        if (add0 > used0) IERC20(l.currency0).safeTransfer(msg.sender, add0 - used0);
        if (add1 > used1) IERC20(l.currency1).safeTransfer(msg.sender, add1 - used1);

        uint256 xBefore = claimSupplyCurrency0();
        uint256 yBefore = claimSupplyCurrency1();
        _buffer(_seFor(l.currency0), l.currency0, used0);
        _buffer(_seFor(l.currency1), l.currency1, used1);
        lpAmount = _mintFromClaimDeltas(xBefore, yBefore, to);
    }


    function _clampToClaimRatio(uint256 amount0, uint256 amount1)
        internal
        view
        returns (uint256 used0, uint256 used1)
    {
        used0 = amount0;
        used1 = amount1;
        uint256 x = claimSupplyCurrency0();
        uint256 y = claimSupplyCurrency1();
        if (x == 0 || y == 0) revert NotLive();
        uint256 ideal1 = (used0 * y) / x;
        if (ideal1 <= used1) {
            used1 = ideal1;
        } else {
            used0 = (used1 * x) / y;
        }
        if (used0 == 0 || used1 == 0) revert ZeroAmount();
    }


    function _mintFromClaimDeltas(uint256 xBefore, uint256 yBefore, address to)
        internal
        returns (uint256 lpAmount)
    {
        uint256 dxN = Math.toWad(claimSupplyCurrency0() - xBefore, _decimalsCurrency0());
        uint256 dyN = Math.toWad(claimSupplyCurrency1() - yBefore, _decimalsCurrency1());
        uint256 xN = Math.toWad(xBefore, _decimalsCurrency0());
        uint256 yN = Math.toWad(yBefore, _decimalsCurrency1());
        lpAmount = Math.mintSharesLater(dxN, dyN, xN, yN, ERC20Repo._totalSupply());
        if (lpAmount == 0) revert InsufficientLpOut();
        _mintLp(to, lpAmount);
    }


    function _withdraw(
        uint256 lpAmount,
        address to,
        uint256 minAmount0,
        uint256 minAmount1,
        uint256 deadline
    ) internal returns (uint256 amount0, uint256 amount1) {
        _requireDeadline(deadline);
        _requireNonZero(lpAmount);

        _mintProtocolFeeIfNeeded(false);

        uint256 supply = ERC20Repo._totalSupply();
        if (lpAmount > ERC20Repo._balanceOf(msg.sender)) revert InsufficientLpOut();

        Repo.Layout storage l = Repo._layout();
        uint256 seBal0 = IERC20(_seFor(l.currency0)).balanceOf(address(this));
        uint256 seBal1 = IERC20(_seFor(l.currency1)).balanceOf(address(this));
        uint256 seOut0 = (seBal0 * lpAmount) / supply;
        uint256 seOut1 = (seBal1 * lpAmount) / supply;

        _burnLp(msg.sender, lpAmount);

        if (seOut0 > 0) {
            amount0 = _unwrap(_seFor(l.currency0), l.currency0, seOut0);
            IERC20(l.currency0).safeTransfer(to, amount0);
        }
        if (seOut1 > 0) {
            amount1 = _unwrap(_seFor(l.currency1), l.currency1, seOut1);
            IERC20(l.currency1).safeTransfer(to, amount1);
        }

        if (amount0 < minAmount0 || amount1 < minAmount1) revert InsufficientTokenOut();
        _setKLastPostOp();
        _refundBothPairDust(msg.sender);
        _syncReserves();
        emit IHook.Withdraw(msg.sender, to, lpAmount, amount0, amount1);
    }


    function _depositFlexibleSe(
        uint256 amount0,
        bool amount0IsSeShare,
        uint256 amount1,
        bool amount1IsSeShare,
        address to,
        uint256 minLpAmount,
        uint256 xPre,
        uint256 yPre
    ) internal returns (uint256 lpAmount, uint256 used0, uint256 used1) {
        DepositFlexibleVars memory v;
        v.amount0 = amount0;
        v.amount0IsSeShare = amount0IsSeShare;
        v.amount1 = amount1;
        v.amount1IsSeShare = amount1IsSeShare;
        v.to = to;
        v.minLpAmount = minLpAmount;
        _loadFlexibleLegs(v);

        if (ERC20Repo._totalSupply() == 0) {
            v.used0 = amount0;
            v.used1 = amount1;
            // First mint: SE pulls already contribute claims; buffer any pair legs then mint.
            v.lpAmount = _firstMintFlexible(v);
        } else {
            // Clamp against pre-pull claims (SE pulls already inflated live claim supplies).
            (v.used0, v.used1) = _clampFlexible(v, xPre, yPre);
            _refundFlexibleExcess(v);
            // Buffer pair legs only; SE legs already in inventory from pull.
            _intakeFlexible(v);
            v.lpAmount = _mintFromClaimDeltas(xPre, yPre, to);
        }

        if (v.lpAmount < minLpAmount) revert InsufficientLpOut();
        _setKLastPostOp();
        _refundBothPairDust(msg.sender);
        _syncReserves();
        emit IHook.DepositFlexible(
            msg.sender,
            to,
            amount0,
            amount0IsSeShare,
            amount1,
            amount1IsSeShare,
            v.used0,
            v.used1,
            v.lpAmount
        );
        return (v.lpAmount, v.used0, v.used1);
    }


    function _loadFlexibleLegs(DepositFlexibleVars memory v) private view {
        Repo.Layout storage l = Repo._layout();
        v.currency0 = l.currency0;
        v.currency1 = l.currency1;
        v.se0 = _seFor(l.currency0);
        v.se1 = _seFor(l.currency1);
    }


    function _firstMintFlexible(DepositFlexibleVars memory v) private returns (uint256 lpAmount) {
        _intakeFlexible(v);
        uint256 geometric = Math.mintSharesFirst(
            Math.toWad(claimSupplyCurrency0(), _decimalsCurrency0()),
            Math.toWad(claimSupplyCurrency1(), _decimalsCurrency1())
        );
        if (geometric <= Repo.MINIMUM_LIQUIDITY) revert InsufficientLpOut();
        lpAmount = geometric - Repo.MINIMUM_LIQUIDITY;
        _mintLp(address(0), Repo.MINIMUM_LIQUIDITY);
        _mintLp(v.to, lpAmount);
    }


    function _clampFlexible(DepositFlexibleVars memory v, uint256 x, uint256 y)
        private
        view
        returns (uint256 used0, uint256 used1)
    {
        uint256 claim0 = v.amount0IsSeShare
            ? _claimOfSe(v.se0, v.currency0, v.amount0)
            : _previewBufferClaimIn(v.se0, v.currency0, v.amount0);
        uint256 claim1 = v.amount1IsSeShare
            ? _claimOfSe(v.se1, v.currency1, v.amount1)
            : _previewBufferClaimIn(v.se1, v.currency1, v.amount1);
        if (claim0 == 0 || claim1 == 0) revert ZeroAmount();
        if (x == 0 || y == 0) revert NotLive();

        uint256 usedClaim0 = claim0;
        uint256 usedClaim1 = claim1;
        uint256 ideal1 = (usedClaim0 * y) / x;
        if (ideal1 <= usedClaim1) {
            usedClaim1 = ideal1;
        } else {
            usedClaim0 = (usedClaim1 * x) / y;
        }
        if (usedClaim0 == 0 || usedClaim1 == 0) revert ZeroAmount();

        // Pro-rate input units so claim contribution matches clamp (anti-skew: SE path has no buffer fee).
        used0 = (v.amount0 * usedClaim0) / claim0;
        used1 = (v.amount1 * usedClaim1) / claim1;
        if (used0 == 0 || used1 == 0) revert ZeroAmount();
    }


    function _intakeFlexible(DepositFlexibleVars memory v) private {
        if (v.amount0IsSeShare) {
            // SE shares already on hook from pull; inventory is live SE balance.
            if (v.used0 == 0) revert ZeroAmount();
        } else {
            _buffer(v.se0, v.currency0, v.used0);
        }
        if (v.amount1IsSeShare) {
            if (v.used1 == 0) revert ZeroAmount();
        } else {
            _buffer(v.se1, v.currency1, v.used1);
        }
    }


    function _refundFlexibleExcess(DepositFlexibleVars memory v) private {
        if (v.amount0 > v.used0) {
            address t0 = v.amount0IsSeShare ? v.se0 : v.currency0;
            IERC20(t0).safeTransfer(msg.sender, v.amount0 - v.used0);
        }
        if (v.amount1 > v.used1) {
            address t1 = v.amount1IsSeShare ? v.se1 : v.currency1;
            IERC20(t1).safeTransfer(msg.sender, v.amount1 - v.used1);
        }
    }


    function _withdrawFlexible(
        uint256 lpAmount,
        address to,
        bool receiveSeShare0,
        bool receiveSeShare1,
        uint256 minAmount0,
        uint256 minAmount1,
        uint256 deadline
    ) internal returns (uint256 amount0, uint256 amount1) {
        if (!receiveSeShare0 && !receiveSeShare1) {
            (amount0, amount1) = _withdraw(lpAmount, to, minAmount0, minAmount1, deadline);
            emit IHook.WithdrawFlexible(msg.sender, to, lpAmount, false, false, amount0, amount1);
            return (amount0, amount1);
        }

        _requireDeadline(deadline);
        _requireNonZero(lpAmount);
        _mintProtocolFeeIfNeeded(false);
        if (lpAmount > ERC20Repo._balanceOf(msg.sender)) revert InsufficientLpOut();

        WithdrawFlexibleVars memory v;
        v.to = to;
        v.receiveSeShare0 = receiveSeShare0;
        v.receiveSeShare1 = receiveSeShare1;
        v.minAmount0 = minAmount0;
        v.minAmount1 = minAmount1;
        _fillWithdrawFlexibleSeOuts(v, lpAmount);
        _burnLp(msg.sender, lpAmount);
        _payWithdrawFlexibleLegs(v);

        if (v.amount0 < v.minAmount0 || v.amount1 < v.minAmount1) revert InsufficientTokenOut();
        _setKLastPostOp();
        _refundBothPairDust(msg.sender);
        _syncReserves();
        emit IHook.WithdrawFlexible(
            msg.sender, v.to, lpAmount, v.receiveSeShare0, v.receiveSeShare1, v.amount0, v.amount1
        );
        return (v.amount0, v.amount1);
    }


    function _fillWithdrawFlexibleSeOuts(WithdrawFlexibleVars memory v, uint256 lpAmount)
        private
        view
    {
        Repo.Layout storage l = Repo._layout();
        v.currency0 = l.currency0;
        v.currency1 = l.currency1;
        v.se0 = _seFor(l.currency0);
        v.se1 = _seFor(l.currency1);
        uint256 supply = ERC20Repo._totalSupply();
        v.seOut0 = (IERC20(v.se0).balanceOf(address(this)) * lpAmount) / supply;
        v.seOut1 = (IERC20(v.se1).balanceOf(address(this)) * lpAmount) / supply;
    }


    function _payWithdrawFlexibleLegs(WithdrawFlexibleVars memory v) private {
        if (v.seOut0 > 0) {
            if (v.receiveSeShare0) {
                v.amount0 = v.seOut0;
                IERC20(v.se0).safeTransfer(v.to, v.seOut0);
            } else {
                v.amount0 = _unwrap(v.se0, v.currency0, v.seOut0);
                IERC20(v.currency0).safeTransfer(v.to, v.amount0);
            }
        }
        if (v.seOut1 > 0) {
            if (v.receiveSeShare1) {
                v.amount1 = v.seOut1;
                IERC20(v.se1).safeTransfer(v.to, v.seOut1);
            } else {
                v.amount1 = _unwrap(v.se1, v.currency1, v.seOut1);
                IERC20(v.currency1).safeTransfer(v.to, v.amount1);
            }
        }
    }


    function _claimOfSe(address se, address pairToken, uint256 seAmount)
        internal
        view
        returns (uint256)
    {
        if (seAmount == 0) return 0;
        return IStandardExchangeIn(se).previewExchangeIn(IERC20(se), seAmount, IERC20(pairToken));
    }


    function _routeZeroForOne(address tokenIn, address tokenOut) internal view returns (bool) {
        Repo.Layout storage l = Repo._layout();
        if (tokenIn == l.currency0 && tokenOut == l.currency1) return true;
        if (tokenIn == l.currency1 && tokenOut == l.currency0) return false;
        revert UnsupportedRoute();
    }


    function _executeBookSwap(bool zeroForOne, uint256 amountIn, uint256 amountOut, address recipient)
        internal
    {
        (address tokenIn, address tokenOut, address seIn, address seOut) = _swapLegs(zeroForOne);
        _buffer(seIn, tokenIn, amountIn);
        _unwrapExactOut(seOut, tokenOut, amountOut);
        IERC20(tokenOut).safeTransfer(recipient, amountOut);
        _syncReserves();
    }


    function _mintProtocolFeeIfNeeded(bool measurePreBuffer) internal {
        measurePreBuffer;
        (bool feeOn, address feeTo_, uint256 ownerFeeShare) = _feeOnAndShare();
        Repo.Layout storage l = Repo._layout();
        if (!feeOn) {
            l.kLast = 0;
            return;
        }
        uint256 kLast_ = l.kLast;
        if (kLast_ == 0) return;
        uint256 currentK = _wadProduct();
        uint256 protocolLp =
            Math.calculateProtocolFee(ERC20Repo._totalSupply(), currentK, kLast_, ownerFeeShare);
        if (protocolLp > 0) {
            _mintLp(feeTo_, protocolLp);
        }
    }


    function _setKLastPostOp() internal {
        (bool feeOn,,) = _feeOnAndShare();
        Repo.Layout storage l = Repo._layout();
        l.kLast = feeOn ? _wadProduct() : 0;
    }


    function _supplyAfterProtocolMint() internal view returns (uint256 supplyAdj) {
        supplyAdj = ERC20Repo._totalSupply();
        (bool feeOn,, uint256 ownerFeeShare) = _feeOnAndShare();
        uint256 kLast_ = Repo._layout().kLast;
        if (feeOn && kLast_ != 0 && supplyAdj > 0) {
            supplyAdj += Math.calculateProtocolFee(supplyAdj, _wadProduct(), kLast_, ownerFeeShare);
        }
    }


    function _previewDeposit(uint256 amount0, uint256 amount1)
        internal
        view
        returns (uint256 lpAmount, uint256 used0, uint256 used1)
    {
        _requireNonZero(amount0);
        _requireNonZero(amount1);
        if (ERC20Repo._totalSupply() == 0) {
            used0 = amount0;
            used1 = amount1;
            lpAmount = _previewFirstMintLp(used0, used1);
            return (lpAmount, used0, used1);
        }
        (used0, used1) = _clampToClaimRatio(amount0, amount1);
        lpAmount = _previewSubsequentLp(used0, used1, _supplyAfterProtocolMint());
    }


    function _previewFirstMintLp(uint256 used0, uint256 used1) internal view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        uint256 geometric = Math.mintSharesFirst(
            Math.toWad(
                _previewBufferClaimIn(_seFor(l.currency0), l.currency0, used0), _decimalsCurrency0()
            ),
            Math.toWad(
                _previewBufferClaimIn(_seFor(l.currency1), l.currency1, used1), _decimalsCurrency1()
            )
        );
        if (geometric <= Repo.MINIMUM_LIQUIDITY) return 0;
        return geometric - Repo.MINIMUM_LIQUIDITY;
    }


    function _previewSubsequentLp(uint256 used0, uint256 used1, uint256 supplyAdj)
        internal
        view
        returns (uint256)
    {
        Repo.Layout storage l = Repo._layout();
        uint256 x = claimSupplyCurrency0();
        uint256 y = claimSupplyCurrency1();
        return Math.mintSharesLater(
            Math.toWad(
                _previewBufferClaimIn(_seFor(l.currency0), l.currency0, used0), _decimalsCurrency0()
            ),
            Math.toWad(
                _previewBufferClaimIn(_seFor(l.currency1), l.currency1, used1), _decimalsCurrency1()
            ),
            Math.toWad(x, _decimalsCurrency0()),
            Math.toWad(y, _decimalsCurrency1()),
            supplyAdj
        );
    }


    function _previewZapSplit(address tokenIn, uint256 amountIn)
        internal
        view
        returns (uint256 amountToSwap, uint256 amountOtherOut, uint256 amountKeptIn)
    {
        _requireZapEligible();
        _requireNonZero(amountIn);
        if (!_isBoundPairToken(tokenIn)) revert InvalidPairToken();
        Repo.Layout storage l = Repo._layout();
        address seIn = _seFor(tokenIn);
        amountToSwap = _computeSaleAmt(tokenIn, amountIn, seIn);
        address tokenOut = tokenIn == l.currency0 ? l.currency1 : l.currency0;
        amountOtherOut =
            _quoteExactInAmountOut(tokenIn, tokenOut, seIn, _seFor(tokenOut), amountToSwap);
        amountKeptIn = amountIn - amountToSwap;
    }


    function _previewDepositSingle(address tokenIn, uint256 amountIn)
        internal
        view
        returns (uint256 lpAmount)
    {
        DepositSinglePreview memory p;
        (p.amountToSwap, p.amountOtherOut, p.amountKeptIn) = _previewZapSplit(tokenIn, amountIn);
        _applyZapToClaimsPreview(tokenIn, p);
        if (p.x == 0 || p.y == 0) return 0;
        _clampSingleDepositAdds(tokenIn, p);
        if (p.used0 == 0 || p.used1 == 0) return 0;
        return _mintSharesFromUsedPreview(p);
    }


    function _applyZapToClaimsPreview(address tokenIn, DepositSinglePreview memory p) private view {
        Repo.Layout storage l = Repo._layout();
        uint256 claimInDelta =
            _previewBufferClaimIn(_seFor(tokenIn), tokenIn, p.amountToSwap);
        p.x = claimSupplyCurrency0();
        p.y = claimSupplyCurrency1();
        if (tokenIn == l.currency0) {
            p.x += claimInDelta;
            p.y = p.y > p.amountOtherOut ? p.y - p.amountOtherOut : 0;
        } else {
            p.y += claimInDelta;
            p.x = p.x > p.amountOtherOut ? p.x - p.amountOtherOut : 0;
        }
    }


    function _clampSingleDepositAdds(address tokenIn, DepositSinglePreview memory p) private view {
        Repo.Layout storage l = Repo._layout();
        uint256 add0 = tokenIn == l.currency0 ? p.amountKeptIn : p.amountOtherOut;
        uint256 add1 = tokenIn == l.currency0 ? p.amountOtherOut : p.amountKeptIn;
        p.used0 = add0;
        p.used1 = add1;
        uint256 ideal1 = (p.used0 * p.y) / p.x;
        if (ideal1 <= p.used1) p.used1 = ideal1;
        else p.used0 = (p.used1 * p.x) / p.y;
    }


    function _mintSharesFromUsedPreview(DepositSinglePreview memory p)
        private
        view
        returns (uint256)
    {
        Repo.Layout storage l = Repo._layout();
        return Math.mintSharesLater(
            Math.toWad(
                _previewBufferClaimIn(_seFor(l.currency0), l.currency0, p.used0),
                _decimalsCurrency0()
            ),
            Math.toWad(
                _previewBufferClaimIn(_seFor(l.currency1), l.currency1, p.used1),
                _decimalsCurrency1()
            ),
            Math.toWad(p.x, _decimalsCurrency0()),
            Math.toWad(p.y, _decimalsCurrency1()),
            _supplyAfterProtocolMint()
        );
    }


    function _previewWithdraw(uint256 lpAmount)
        internal
        view
        returns (uint256 amount0, uint256 amount1)
    {
        _requireNonZero(lpAmount);
        uint256 supplyAdj = _supplyAfterProtocolMint();
        Repo.Layout storage l = Repo._layout();
        address se0 = _seFor(l.currency0);
        address se1 = _seFor(l.currency1);
        uint256 seOut0 = (IERC20(se0).balanceOf(address(this)) * lpAmount) / supplyAdj;
        uint256 seOut1 = (IERC20(se1).balanceOf(address(this)) * lpAmount) / supplyAdj;
        if (seOut0 > 0) {
            amount0 = IStandardExchangeIn(se0).previewExchangeIn(
                IERC20(se0), seOut0, IERC20(l.currency0)
            );
        }
        if (seOut1 > 0) {
            amount1 = IStandardExchangeIn(se1).previewExchangeIn(
                IERC20(se1), seOut1, IERC20(l.currency1)
            );
        }
    }


    function _previewDepositFlexible(
        uint256 amount0,
        bool amount0IsSeShare,
        uint256 amount1,
        bool amount1IsSeShare
    ) internal view returns (uint256 lpAmount, uint256 used0, uint256 used1) {
        if (!amount0IsSeShare && !amount1IsSeShare) {
            return _previewDeposit(amount0, amount1);
        }
        _requireNonZero(amount0);
        _requireNonZero(amount1);

        DepositFlexibleVars memory v;
        v.amount0 = amount0;
        v.amount0IsSeShare = amount0IsSeShare;
        v.amount1 = amount1;
        v.amount1IsSeShare = amount1IsSeShare;
        _loadFlexibleLegs(v);

        if (ERC20Repo._totalSupply() == 0) {
            used0 = amount0;
            used1 = amount1;
            uint256 c0 = amount0IsSeShare
                ? _claimOfSe(v.se0, v.currency0, used0)
                : _previewBufferClaimIn(v.se0, v.currency0, used0);
            uint256 c1 = amount1IsSeShare
                ? _claimOfSe(v.se1, v.currency1, used1)
                : _previewBufferClaimIn(v.se1, v.currency1, used1);
            uint256 geometric = Math.mintSharesFirst(
                Math.toWad(c0, _decimalsCurrency0()), Math.toWad(c1, _decimalsCurrency1())
            );
            if (geometric <= Repo.MINIMUM_LIQUIDITY) return (0, used0, used1);
            return (geometric - Repo.MINIMUM_LIQUIDITY, used0, used1);
        }

        uint256 x = claimSupplyCurrency0();
        uint256 y = claimSupplyCurrency1();
        (used0, used1) = _clampFlexible(v, x, y);
        uint256 dx = amount0IsSeShare
            ? _claimOfSe(v.se0, v.currency0, used0)
            : _previewBufferClaimIn(v.se0, v.currency0, used0);
        uint256 dy = amount1IsSeShare
            ? _claimOfSe(v.se1, v.currency1, used1)
            : _previewBufferClaimIn(v.se1, v.currency1, used1);
        lpAmount = Math.mintSharesLater(
            Math.toWad(dx, _decimalsCurrency0()),
            Math.toWad(dy, _decimalsCurrency1()),
            Math.toWad(x, _decimalsCurrency0()),
            Math.toWad(y, _decimalsCurrency1()),
            _supplyAfterProtocolMint()
        );
    }


    function _previewWithdrawFlexible(uint256 lpAmount, bool receiveSeShare0, bool receiveSeShare1)
        internal
        view
        returns (uint256 amount0, uint256 amount1)
    {
        if (!receiveSeShare0 && !receiveSeShare1) {
            return _previewWithdraw(lpAmount);
        }
        _requireNonZero(lpAmount);
        uint256 supplyAdj = _supplyAfterProtocolMint();
        Repo.Layout storage l = Repo._layout();
        address se0 = _seFor(l.currency0);
        address se1 = _seFor(l.currency1);
        uint256 seOut0 = (IERC20(se0).balanceOf(address(this)) * lpAmount) / supplyAdj;
        uint256 seOut1 = (IERC20(se1).balanceOf(address(this)) * lpAmount) / supplyAdj;
        if (seOut0 > 0) {
            amount0 = receiveSeShare0
                ? seOut0
                : IStandardExchangeIn(se0).previewExchangeIn(IERC20(se0), seOut0, IERC20(l.currency0));
        }
        if (seOut1 > 0) {
            amount1 = receiveSeShare1
                ? seOut1
                : IStandardExchangeIn(se1).previewExchangeIn(IERC20(se1), seOut1, IERC20(l.currency1));
        }
    }


    function _previewSwapExactIn(bool zeroForOne, uint256 amountIn)
        internal
        view
        returns (uint256 amountOut)
    {
        _requireNonZero(amountIn);
        _requireLive();
        Repo.Layout storage l = Repo._layout();
        address tokenIn = zeroForOne ? l.currency0 : l.currency1;
        address tokenOut = zeroForOne ? l.currency1 : l.currency0;
        address seIn = _seFor(tokenIn);
        address seOut = _seFor(tokenOut);
        uint256 reserveIn = _claimSupply(seIn, tokenIn);
        uint256 reserveOut = _claimSupply(seOut, tokenOut);
        uint256 claimIn = _previewBufferClaimIn(seIn, tokenIn, amountIn);
        uint256 claimInN = Math.toWad(claimIn, _decimalsOf(tokenIn));
        uint256 rInN = Math.toWad(reserveIn, _decimalsOf(tokenIn));
        uint256 rOutN = Math.toWad(reserveOut, _decimalsOf(tokenOut));
        uint256 outN = Math.saleQuote(claimInN, rInN, rOutN);
        amountOut = Math.fromWadFloor(outN, _decimalsOf(tokenOut));
    }


    function _previewSwapExactOut(bool zeroForOne, uint256 amountOut)
        internal
        view
        returns (uint256 amountIn)
    {
        _requireNonZero(amountOut);
        _requireLive();
        Repo.Layout storage l = Repo._layout();
        address tokenIn = zeroForOne ? l.currency0 : l.currency1;
        address tokenOut = zeroForOne ? l.currency1 : l.currency0;
        address seIn = _seFor(tokenIn);
        address seOut = _seFor(tokenOut);
        uint256 reserveIn = _claimSupply(seIn, tokenIn);
        uint256 reserveOut = _claimSupply(seOut, tokenOut);
        if (amountOut >= reserveOut) revert InsufficientTokenOut();
        uint256 claimInN = Math.purchaseQuote(
            Math.toWad(amountOut, _decimalsOf(tokenOut)),
            Math.toWad(reserveIn, _decimalsOf(tokenIn)),
            Math.toWad(reserveOut, _decimalsOf(tokenOut))
        );
        uint256 claimIn = Math.fromWadCeil(claimInN, _decimalsOf(tokenIn));
        amountIn = _invertBufferClaimIn(seIn, tokenIn, claimIn);
    }


    function _pullPermit2SignatureDual(
        uint256 amount0,
        uint256 amount1,
        bytes calldata permit2Data
    ) internal {
        Repo.Layout storage l = Repo._layout();
        PullLib.pullPermit2SignatureDual(l.currency0, l.currency1, amount0, amount1, permit2Data);
    }


    function _pullPermit2SignatureSingle(
        address tokenIn,
        uint256 amountIn,
        bytes calldata permit2Data
    ) internal {
        PullLib.pullPermit2SignatureSingle(tokenIn, amountIn, permit2Data);
    }


    function _pullPermit2AllowanceDual(uint256 amount0, uint256 amount1) internal {
        Repo.Layout storage l = Repo._layout();
        PullLib.pullPermit2AllowanceDual(l.currency0, l.currency1, amount0, amount1);
    }


    function _pullPermit2AllowanceSingle(address tokenIn, uint256 amountIn) internal {
        PullLib.pullPermit2AllowanceSingle(tokenIn, amountIn);
    }


    function _pullErc20Dual(uint256 amount0, uint256 amount1) internal {
        Repo.Layout storage l = Repo._layout();
        PullLib.pullErc20Dual(l.currency0, l.currency1, amount0, amount1);
    }


    function _pullErc20Single(address tokenIn, uint256 amountIn) internal {
        PullLib.pullErc20Single(tokenIn, amountIn);
    }


    function _pullFlexible(
        uint256 amount0,
        bool amount0IsSeShare,
        uint256 amount1,
        bool amount1IsSeShare
    ) internal {
        Repo.Layout storage l = Repo._layout();
        address t0 = amount0IsSeShare ? _seFor(l.currency0) : l.currency0;
        address t1 = amount1IsSeShare ? _seFor(l.currency1) : l.currency1;
        PullLib.pullErc20Dual(t0, t1, amount0, amount1);
    }

}
