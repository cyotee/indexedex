// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {ExchangeInAmount} from "contracts/utils/ExchangeInAmount.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {UniswapV4BufferHookLiquidityRouteLib as Components} from "contracts/hooks/uniswap/v4/libs/UniswapV4BufferHookLiquidityRouteLib.sol";

import {UniswapV4DualStandardExchangeBufferConstantProductHookDepositQuoteLib as DepositQuoteLib}
    from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookDepositQuoteLib.sol";
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
import {LocalCreditLib} from "contracts/utils/LocalCreditLib.sol";
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
import {
    UniswapV4SeBufferHookLegLib
} from "contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol";

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
    error InvalidRoute();
    error PairAndShareSameLeg();
    error FirstJoinMustBeFullBook();

    modifier unlockedQuery() {
        _requireQueryUnlocked();
        _;
    }

    function _requireQueryUnlocked() internal view {
        if (Repo._layout().reentrancyStatus == Repo.ENTERED) revert Reentrancy();
    }

    modifier nonReentrant() {
        Repo.Layout storage l = Repo._layout();
        if (l.reentrancyStatus == Repo.ENTERED) revert Reentrancy();
        l.reentrancyStatus = Repo.ENTERED;
        _;
        l.reentrancyStatus = Repo.NOT_ENTERED;
    }

    /* views used by deposit/withdraw internals (also on Hooks Facet) */
    function claimSupply0() public view unlockedQuery returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        return _claimSupply(l.se0, l.token0);
    }

    function claimSupply1() public view unlockedQuery returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        return _claimSupply(l.se1, l.token1);
    }

    function claimSupplyCurrency0() public view unlockedQuery returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        return _claimSupply(_seFor(l.currency0), l.currency0);
    }

    function claimSupplyCurrency1() public view unlockedQuery returns (uint256) {
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

    /// @dev Buffered face is unbooked; an identity leg deducts its native-unit custody book.
    function _unbookedBalance(IERC20 token) internal view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        uint256 booked = l.localReserves[address(token)] + l.shareReserves[address(token)];
        return LocalCreditLib.available(token.balanceOf(address(this)), booked);
    }

    /// @dev Exact-out input (D15): false-flag pulls `used` and refunds nothing. True-flag credits
    ///      `budget(available, maxAmountIn)` and refunds `credit - used` to `msg.sender` only.
    function _pullExactOutInput(IERC20 token, uint256 used, uint256 maxAmountIn, bool pretransferred)
        internal
    {
        _securePull(token, used, pretransferred);
        if (!pretransferred) return;
        uint256 credit = LocalCreditLib.budget(_unbookedBalance(token), maxAmountIn);
        if (credit > used) token.safeTransfer(msg.sender, credit - used);
    }

    /// @dev D60: SE shares held x the leg's provider rate (pair units); never an SE self-quote.
    function _claimSupply(address se, address pairToken) internal view returns (uint256) {
        pairToken;
        return ClaimLib.ratedReserve(se);
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

    function _classify(address addr)
        internal
        view
        returns (UniswapV4SeBufferHookLegLib.LegKind)
    {
        return UniswapV4SeBufferHookLegLib.classify(Repo._layout().legs, addr);
    }

    function _tryRouteZeroForOne(address tokenIn, address tokenOut)
        internal
        view
        returns (bool ok, bool zfo)
    {
        UniswapV4SeBufferHookLegLib.LegKind kIn = _classify(tokenIn);
        UniswapV4SeBufferHookLegLib.LegKind kOut = _classify(tokenOut);
        if (
            kIn == UniswapV4SeBufferHookLegLib.LegKind.Unknown
                || kOut == UniswapV4SeBufferHookLegLib.LegKind.Unknown
        ) {
            return (false, false);
        }
        Repo.Layout storage l = Repo._layout();
        address in_ = kIn == UniswapV4SeBufferHookLegLib.LegKind.StandardExchange
            ? l.legs.pairOfStandardExchange[tokenIn]
            : tokenIn;
        address out_ = kOut == UniswapV4SeBufferHookLegLib.LegKind.StandardExchange
            ? l.legs.pairOfStandardExchange[tokenOut]
            : tokenOut;
        if (in_ == l.currency0 && out_ == l.currency1) return (true, true);
        if (in_ == l.currency1 && out_ == l.currency0) return (true, false);
        return (false, false);
    }


    function _isLive() internal view returns (bool) {
        Repo.Layout storage l = Repo._layout();
        return (l.shareReserves[l.se0] != 0 || l.localReserves[l.token0] != 0)
            && (l.shareReserves[l.se1] != 0 || l.localReserves[l.token1] != 0);
    }


    function _isZapEligible() internal view returns (bool) {
        return ERC20Repo._totalSupply() > Repo.MINIMUM_LIQUIDITY;
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

    function _previewBufferClaimIn(address se, address pairToken, uint256 amountInRaw)
        internal
        view
        returns (uint256)
    {
        return ClaimLib.previewBufferClaimIn(se, pairToken, amountInRaw);
    }


    function _invertBufferClaimIn(address se, address pairToken, uint256 claimInNeeded)
        internal
        view
        returns (uint256)
    {
        return ClaimLib.invertBufferClaimIn(se, pairToken, claimInNeeded);
    }


    /// @dev Receipts belong to the current operation until explicitly accepted or booked.
    function _convert(address se, address pair, uint256 amount, bool deposit)
        internal returns (ExchangeInAmount.Result memory result)
    {
        if (amount == 0) return result;
        IERC20 input = IERC20(deposit ? pair : se);
        IERC20 output = IERC20(deposit ? se : pair);
        uint256 inputBefore = input.balanceOf(address(this));
        uint256 outputBefore = output.balanceOf(address(this));
        input.forceApprove(se, amount);
        result = ExchangeInAmount.exchangeResult(IStandardExchangeIn(se), input, amount, output,
            0, address(this), false, block.timestamp);
        ExchangeInAmount.requireReceipt(amount, result, inputBefore, input.balanceOf(address(this)),
            outputBefore, output.balanceOf(address(this)));
        input.forceApprove(se, 0);
    }

    function _bufferPool(address se, address pair, uint256 amount) internal {
        Repo.Layout storage l = Repo._layout();
        if (se == pair || ClaimLib.disabled(se)) {
            l.localReserves[pair] += amount;
            return;
        }
        ExchangeInAmount.Result memory result = _convert(se, pair, amount, true);
        l.shareReserves[se] += result.amountOut;
        l.localReserves[pair] += result.amountRefunded;
    }

    function _assemble(address pair, uint256 amount, bool asShare, bool genesis, DepositQuoteLib.Component memory old)
        private returns (DepositQuoteLib.Component memory available)
    {
        if (amount == 0) return available;
        address se = _seFor(pair);
        if (se == pair) { available.local = amount; return available; }
        if (asShare) available.shares = amount;
        else if (genesis) {
            if (ClaimLib.disabled(se)) revert IVaultRegistryDisableQuery.VaultDisabled(se);
            ExchangeInAmount.Result memory result = _convert(se, pair, amount, true);
            available.shares = result.amountOut;
            available.local = result.amountRefunded;
        }
        else if (old.shares == 0 || ClaimLib.disabled(se)) available.local = amount;
        else {
            uint256 forwarded = DepositQuoteLib.pairToDeposit(se, amount, old, bytes(""));
            ExchangeInAmount.Result memory result = _convert(se, pair, forwarded, true);
            available.shares = result.amountOut;
            available.local = ExchangeInAmount.localCredit(amount, forwarded, result.amountRefunded);
        }
        uint256 spend;
        if (genesis) (spend,) = Components.bootstrapSplit(available.shares);
        else spend = DepositQuoteLib.redemptionFor(se, available, old, bytes(""));
        if (spend != 0) {
            ExchangeInAmount.Result memory redeemed = _convert(se, pair, spend, false);
            if (genesis && (redeemed.amountRefunded != 0 || redeemed.amountOut == 0)) revert InsufficientTokenOut();
            available.local += redeemed.amountOut;
            available.shares -= spend - redeemed.amountRefunded;
        }
    }

    function _accept(address pair, DepositQuoteLib.Component memory available, DepositQuoteLib.Component memory old,
        uint256 gross, uint256 supply, bool asShare, uint256 supplied) private returns (uint256 used)
    {
        Repo.Layout storage l = Repo._layout();
        address se = _seFor(pair);
        uint256 shares = supply == 0 ? available.shares : Components.componentContribution(gross, old.shares, supply);
        uint256 local = supply == 0 ? available.local : Components.componentContribution(gross, old.local, supply);
        l.shareReserves[se] = old.shares + shares;
        l.localReserves[pair] = old.local + local;
        uint256 refundShares = available.shares - shares;
        uint256 refundPair = available.local - local;
        used = supplied - (asShare && se != pair ? refundShares : refundPair);
    }

    function _joinComponents(uint256 amount0, bool asShare0, uint256 amount1, bool asShare1, address to, uint256 minimum)
        internal returns (uint256 netLp, uint256 used0, uint256 used1)
    {
        if (to == address(0)) revert ZeroAddress();
        if (amount0 == 0 && amount1 == 0) revert ZeroAmount();
        Repo.Layout storage l = Repo._layout();
        uint256 supply = ERC20Repo._totalSupply();
        if (supply == 0) {
            _requireNonZero(amount0);
            _requireNonZero(amount1);
        }
        DepositQuoteLib.Component memory x = DepositQuoteLib.book(l.currency0);
        DepositQuoteLib.Component memory y = DepositQuoteLib.book(l.currency1);
        if (supply != 0 && (amount0 == 0 || amount1 == 0)) {
            bool first = amount0 != 0;
            address token = first ? (asShare0 ? _seFor(l.currency0) : l.currency0)
                : (asShare1 ? _seFor(l.currency1) : l.currency1);
            uint256 amount = first ? amount0 : amount1;
            uint256 callerBefore = IERC20(token).balanceOf(msg.sender);
            netLp = _depositSingle(token, amount, to, minimum, block.timestamp);
            uint256 used = amount - (IERC20(token).balanceOf(msg.sender) - callerBefore);
            return (netLp, first ? used : 0, first ? 0 : used);
        }
        DepositQuoteLib.Component memory a = _assemble(l.currency0, amount0, asShare0, supply == 0, x);
        DepositQuoteLib.Component memory b = _assemble(l.currency1, amount1, asShare1, supply == 0, y);
        // Paid swaps (if any) completed before this call. Custody conversions above
        // do not credit contributions; take the incumbent mint boundary now.
        x = DepositQuoteLib.book(l.currency0);
        y = DepositQuoteLib.book(l.currency1);
        uint256 gross = supply == 0 ? DepositQuoteLib.seed(a, b) : DepositQuoteLib.limit(a, b, x, y, supply);
        if (gross == 0) revert InsufficientLpOut();
        (IFeeCollectorProxy feeTo, uint256 fee) = IVaultFeeOracleQuery(l.feeOracle).dexSwapFeeAndFeeToOfVault(address(this));
        uint256 feeLp;
        (netLp, feeLp) = Components.splitMintFee(gross, fee, address(feeTo), fee != 0);
        if (netLp < minimum) revert InsufficientLpOut();
        used0 = _accept(l.currency0, a, x, gross, supply, asShare0, amount0);
        used1 = _accept(l.currency1, b, y, gross, supply, asShare1, amount1);
        if (supply == 0) _mintLp(address(0), Repo.MINIMUM_LIQUIDITY);
        _mintLp(address(feeTo), feeLp);
        _mintLp(to, netLp);
        _refundAccepted(l.currency0, a, x, gross, supply);
        _refundAccepted(l.currency1, b, y, gross, supply);
        _syncReserves();
    }

    function _refundAccepted(address pair, DepositQuoteLib.Component memory available, DepositQuoteLib.Component memory old,
        uint256 gross, uint256 supply) private
    {
        if (supply == 0) return;
        uint256 shares = available.shares - Components.componentContribution(gross, old.shares, supply);
        uint256 local = available.local - Components.componentContribution(gross, old.local, supply);
        if (shares != 0) IERC20(_seFor(pair)).safeTransfer(msg.sender, shares);
        if (local != 0) IERC20(pair).safeTransfer(msg.sender, local);
    }

    function _allocateExit(address pair, uint256 burned, uint256 supply)
        private returns (DepositQuoteLib.Component memory allocated)
    {
        Repo.Layout storage l = Repo._layout();
        address se = _seFor(pair);
        allocated.shares = Components.componentAllocation(burned, l.shareReserves[se], supply);
        allocated.local = Components.componentAllocation(burned, l.localReserves[pair], supply);
        l.shareReserves[se] -= allocated.shares;
        l.localReserves[pair] -= allocated.local;
    }

    function _payComponent(address pair, DepositQuoteLib.Component memory allocated, bool asShare, address to)
        private returns (uint256 amount)
    {
        address se = _seFor(pair);
        if (se == pair) amount = allocated.local;
        else if (asShare) amount = allocated.shares + (allocated.local == 0 ? 0 : _buffer(se, pair, allocated.local));
        else amount = allocated.local + (allocated.shares == 0 ? 0 : _unwrap(se, pair, allocated.shares));
        if (to != address(this) && amount != 0) IERC20(asShare ? se : pair).safeTransfer(to, amount);
    }

    function _buffer(address se, address pairToken, uint256 amount) internal returns (uint256 seOut) {
        if (se == pairToken) return amount;
        if (ClaimLib.disabled(se)) revert IVaultRegistryDisableQuery.VaultDisabled(se);
        ExchangeInAmount.Result memory result = _convert(se, pairToken, amount, true);
        // A share-only request cannot silently discard the caller's refunded pair component.
        if (result.amountRefunded != 0 || (amount != 0 && result.amountOut == 0)) revert InsufficientTokenOut();
        return result.amountOut;
    }


    function _unwrap(address se, address pairToken, uint256 seIn) internal returns (uint256 tokenOut) {
        if (seIn == 0 || se == pairToken) return seIn;
        ExchangeInAmount.Result memory result = _convert(se, pairToken, seIn, false);
        if (result.amountRefunded != 0 || result.amountOut == 0) revert InsufficientTokenOut();
        return result.amountOut;
    }


    function _unwrapExactOut(address se, address pairToken, uint256 tokenOut, uint256 maxShares)
        internal returns (uint256 seIn)
    {
        _requireNonZero(tokenOut);
        if (maxShares == 0 || maxShares >= Repo._layout().shareReserves[se]) revert InsufficientTokenOut();
        uint256 sharesBefore = IERC20(se).balanceOf(address(this));
        uint256 pairBefore = IERC20(pairToken).balanceOf(address(this));
        IERC20(se).forceApprove(se, maxShares);
        seIn = IStandardExchangeOut(se).exchangeOut(IERC20(se), maxShares, IERC20(pairToken), tokenOut,
            address(this), false, block.timestamp);
        IERC20(se).forceApprove(se, 0);
        if (seIn != maxShares || sharesBefore - IERC20(se).balanceOf(address(this)) != seIn) revert InsufficientTokenOut();
        uint256 received = IERC20(pairToken).balanceOf(address(this)) - pairBefore;
        if (received < tokenOut) revert InsufficientTokenOut();
        Repo._layout().localReserves[pairToken] += received - tokenOut;
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
        uint256 reserve0 = _claimSupply(_seFor(l.currency0), l.currency0);
        uint256 reserve1 = _claimSupply(_seFor(l.currency1), l.currency1);
        MultiAssetBasicVaultRepo._updateReserve(IERC20(l.currency0), reserve0);
        MultiAssetBasicVaultRepo._updateReserve(IERC20(l.currency1), reserve1);
    }

    function _swapExactIn(bool zeroForOne, uint256 amountInRaw)
        internal
        returns (BeforeSwapDelta swapDelta)
    {
        _requireNonZero(amountInRaw);
        BookSwapPlan memory plan = _planExactIn(zeroForOne, amountInRaw);
        _take(Currency.wrap(plan.tokenIn), address(this), amountInRaw);
        uint256 amountOut = _executePlannedSwap(plan, true, address(this));
        _settle(Currency.wrap(plan.tokenOut), amountOut);

        swapDelta = toBeforeSwapDelta(int128(int256(amountInRaw)), int128(-int256(amountOut)));
    }


    function _swapExactOut(bool zeroForOne, uint256 amountOut)
        internal
        returns (BeforeSwapDelta swapDelta)
    {
        _requireNonZero(amountOut);
        BookSwapPlan memory plan = _planExactOut(zeroForOne, amountOut);
        uint256 amountInRaw = plan.amountIn;
        _requireNonZero(amountInRaw);

        _take(Currency.wrap(plan.tokenIn), address(this), amountInRaw);
        _executePlannedSwap(plan, false, address(this));
        _settle(Currency.wrap(plan.tokenOut), amountOut);

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
        return _quoteExactInOutput(tokenIn, tokenOut, seIn, seOut, amountInRaw).amount;
    }

    function _quoteExactInOutput(address tokenIn, address tokenOut, address seIn, address seOut, uint256 amountInRaw)
        internal view returns (ClaimLib.OutputQuote memory output)
    {
        return _quoteExactInContext(tokenIn, tokenOut, seIn, seOut, amountInRaw, address(0));
    }

    function _quoteExactInContext(address tokenIn, address tokenOut, address seIn, address seOut, uint256 amountInRaw, address manager)
        private view returns (ClaimLib.OutputQuote memory output)
    {
        uint256 claimIn = manager == address(0) ? _previewBufferClaimIn(seIn, tokenIn, amountInRaw) : ClaimLib.previewInputWithContext(seIn, amountInRaw, manager);
        uint256 claimInN = Math.toWad(claimIn, _decimalsOf(tokenIn));
        uint256 rInN = Math.toWad(manager == address(0) ? _claimSupply(seIn, tokenIn) : ClaimLib.ratedReserveWithContext(seIn, manager), _decimalsOf(tokenIn));
        uint256 rOutN = Math.toWad(manager == address(0) ? _claimSupply(seOut, tokenOut) : ClaimLib.ratedReserveWithContext(seOut, manager), _decimalsOf(tokenOut));
        uint256 budget = Math.fromWadFloor(Math.saleQuote(claimInN, rInN, rOutN), _decimalsOf(tokenOut));
        output = manager == address(0) ? ClaimLib.previewOutputExactIn(seOut, budget) : ClaimLib.previewOutputWithContext(seOut, budget, manager);
    }


    function _quoteExactOutAmountIn(
        address tokenIn,
        address tokenOut,
        address seIn,
        address seOut,
        uint256 amountOut
    ) internal view returns (uint256 amountInRaw) {
        (, uint256 debit) = ClaimLib.previewOutputExactOut(seOut, amountOut);
        uint256 claimInN = Math.purchaseQuote(
            Math.toWad(debit, _decimalsOf(tokenOut)),
            Math.toWad(_claimSupply(seIn, tokenIn), _decimalsOf(tokenIn)),
            Math.toWad(_claimSupply(seOut, tokenOut), _decimalsOf(tokenOut))
        );
        uint256 claimIn = Math.fromWadCeil(claimInN, _decimalsOf(tokenIn));
        ClaimLib.requireInputInverse(seIn, claimIn);
        amountInRaw = _invertBufferClaimIn(seIn, tokenIn, claimIn);
    }


    function _deposit(uint256 amount0, uint256 amount1, address to, uint256 minLpAmount, uint256 deadline)
        internal returns (uint256 lpAmount, uint256 used0, uint256 used1)
    {
        _requireDeadline(deadline);
        (lpAmount, used0, used1) = _joinComponents(amount0, false, amount1, false, to, minLpAmount);
        emit IHook.Deposit(msg.sender, to, used0, used1, lpAmount);
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
        UniswapV4SeBufferHookLegLib.LegKind kind = _classify(tokenIn);
        if (kind == UniswapV4SeBufferHookLegLib.LegKind.Unknown) revert InvalidPairToken();
        _requireZapEligible();
        bool asShare = kind == UniswapV4SeBufferHookLegLib.LegKind.StandardExchange;
        Repo.Layout storage l = Repo._layout();
        address pair = asShare ? l.legs.pairOfStandardExchange[tokenIn] : tokenIn;
        bool first = pair == l.currency0;
        if (!asShare && amountIn == 1) revert InsufficientLpOut();
        uint256 pairAmount = amountIn;
        if (asShare) {
            ExchangeInAmount.Result memory result = _convert(tokenIn, pair, amountIn, false);
            pairAmount = result.amountOut;
            if (result.amountRefunded != 0) IERC20(tokenIn).safeTransfer(msg.sender, result.amountRefunded);
        }
        uint256 swapAmount = DepositQuoteLib.swapAmount(pair, pairAmount);
        if (swapAmount == 0 || swapAmount >= pairAmount) revert InsufficientLpOut();
        uint256 other = _executePlannedSwap(_planExactIn(first, swapAmount), true, address(this));
        emit IHook.ZapSwap(msg.sender, pair, first ? l.currency1 : l.currency0, swapAmount, other);
        // Only the unspent caller input and actual swap proceeds back the mint.
        uint256 kept = pairAmount - swapAmount;
        (lpAmount,,) = _joinComponents(first ? kept : other, false,
            first ? other : kept, false, to, minLpAmount);
        emit IHook.DepositSingle(msg.sender, to, tokenIn, amountIn, lpAmount);
    }

    function _withdraw(
        uint256 lpAmount,
        address to,
        uint256 minAmount0,
        uint256 minAmount1,
        uint256 deadline
    ) internal returns (uint256 amount0, uint256 amount1) {
        return _withdrawAndSettle(lpAmount, to, minAmount0, minAmount1, deadline, true);
    }

    /// @dev A composed exit retains its own raw withdrawals until the final asset is paid.
    function _withdrawAndSettle(
        uint256 lpAmount,
        address to,
        uint256 minAmount0,
        uint256 minAmount1,
        uint256 deadline,
        bool refundDust
    ) internal returns (uint256 amount0, uint256 amount1) {
        return _withdrawFrom(msg.sender, lpAmount, to, minAmount0, minAmount1, deadline, refundDust);
    }

    function _withdrawFrom(
        address holder, uint256 lpAmount, address to, uint256 minAmount0,
        uint256 minAmount1, uint256 deadline, bool
    ) internal returns (uint256 amount0, uint256 amount1) {
        _requireDeadline(deadline);
        _requireNonZero(lpAmount);
        if (to == address(0)) revert ZeroAddress();
        uint256 supply = ERC20Repo._totalSupply();
        if (lpAmount > ERC20Repo._balanceOf(holder)) revert InsufficientLpOut();
        Repo.Layout storage l = Repo._layout();
        DepositQuoteLib.Component memory a = _allocateExit(l.currency0, lpAmount, supply);
        DepositQuoteLib.Component memory b = _allocateExit(l.currency1, lpAmount, supply);
        _burnLp(holder, lpAmount);
        amount0 = _payComponent(l.currency0, a, false, to);
        amount1 = _payComponent(l.currency1, b, false, to);
        if (amount0 < minAmount0 || amount1 < minAmount1) revert InsufficientTokenOut();
        _syncReserves();
        emit IHook.Withdraw(msg.sender, to, lpAmount, amount0, amount1);
    }

    function _exitSingleAssetFrom(address holder, address tokenOut, uint256 sharesIn, address to, uint256 deadline)
        internal returns (uint256 amountOut)
    {
        if (to == address(0)) revert ZeroAddress();
        UniswapV4SeBufferHookLegLib.LegKind kind = _classify(tokenOut);
        if (kind == UniswapV4SeBufferHookLegLib.LegKind.Unknown) revert InvalidRoute();
        Repo.Layout storage l = Repo._layout();
        bool asShare = kind == UniswapV4SeBufferHookLegLib.LegKind.StandardExchange;
        address pair = asShare ? l.legs.pairOfStandardExchange[tokenOut] : tokenOut;
        bool outIs0 = pair == l.currency0;
        if (!outIs0 && pair != l.currency1) revert InvalidRoute();
        (uint256 a0, uint256 a1) = _withdrawFrom(holder, sharesIn, address(this), 0, 0, deadline, false);
        amountOut = outIs0 ? a0 : a1;
        uint256 residual = outIs0 ? a1 : a0;
        if (residual > 0) amountOut += _executePlannedSwap(_planExactIn(!outIs0, residual), true, address(this));
        if (asShare && amountOut > 0) amountOut = _buffer(tokenOut, pair, amountOut);
        IERC20(tokenOut).safeTransfer(to, amountOut);
        _syncReserves();
    }

    function _depositFlexibleSe(
        uint256 amount0, bool amount0IsSeShare, uint256 amount1, bool amount1IsSeShare,
        address to, uint256 minLpAmount
    ) internal returns (uint256 lpAmount, uint256 used0, uint256 used1) {
        (lpAmount, used0, used1) = _joinComponents(amount0, amount0IsSeShare, amount1, amount1IsSeShare, to, minLpAmount);
        emit IHook.DepositFlexible(msg.sender, to, amount0, amount0IsSeShare, amount1, amount1IsSeShare,
            used0, used1, lpAmount);
    }

    function _withdrawFlexible(
        uint256 lpAmount, address to, bool receiveSeShare0, bool receiveSeShare1,
        uint256 minAmount0, uint256 minAmount1, uint256 deadline
    ) internal returns (uint256 amount0, uint256 amount1) {
        _requireDeadline(deadline);
        _requireNonZero(lpAmount);
        if (to == address(0)) revert ZeroAddress();
        uint256 supply = ERC20Repo._totalSupply();
        if (lpAmount > ERC20Repo._balanceOf(msg.sender)) revert InsufficientLpOut();
        Repo.Layout storage l = Repo._layout();
        DepositQuoteLib.Component memory a = _allocateExit(l.currency0, lpAmount, supply);
        DepositQuoteLib.Component memory b = _allocateExit(l.currency1, lpAmount, supply);
        _burnLp(msg.sender, lpAmount);
        amount0 = _payComponent(l.currency0, a, receiveSeShare0, to);
        amount1 = _payComponent(l.currency1, b, receiveSeShare1, to);
        if (amount0 < minAmount0 || amount1 < minAmount1) revert InsufficientTokenOut();
        _syncReserves();
        emit IHook.WithdrawFlexible(msg.sender, to, lpAmount, receiveSeShare0, receiveSeShare1, amount0, amount1);
    }

    function _routeZeroForOne(address tokenIn, address tokenOut) internal view returns (bool) {
        Repo.Layout storage l = Repo._layout();
        if (tokenIn == l.currency0 && tokenOut == l.currency1) return true;
        if (tokenIn == l.currency1 && tokenOut == l.currency0) return false;
        revert UnsupportedRoute();
    }


    struct BookSwapPlan {
        address tokenIn;
        address tokenOut;
        address seIn;
        address seOut;
        uint256 amountIn;
        ClaimLib.OutputQuote output;
    }

    function _planExactIn(bool zeroForOne, uint256 amountIn) internal view returns (BookSwapPlan memory plan) {
        return _planExactInContext(zeroForOne, amountIn, address(0));
    }

    function _planExactInContext(bool zeroForOne, uint256 amountIn, address manager) private view returns (BookSwapPlan memory plan) {
        _requireNonZero(amountIn);
        _requireLive();
        (plan.tokenIn, plan.tokenOut, plan.seIn, plan.seOut) = _swapLegs(zeroForOne);
        plan.amountIn = amountIn;
        plan.output = _quoteExactInContext(plan.tokenIn, plan.tokenOut, plan.seIn, plan.seOut, amountIn, manager);
    }

    function _planExactOut(bool zeroForOne, uint256 amountOut) internal view returns (BookSwapPlan memory plan) {
        _requireNonZero(amountOut);
        _requireLive();
        (plan.tokenIn, plan.tokenOut, plan.seIn, plan.seOut) = _swapLegs(zeroForOne);
        (plan.output,) = ClaimLib.previewOutputExactOut(plan.seOut, amountOut);
        plan.amountIn = _quoteExactOutAmountIn(plan.tokenIn, plan.tokenOut, plan.seIn, plan.seOut, amountOut);
    }

    function _unwrapPlanned(address se, address pair, ClaimLib.OutputQuote memory output) internal returns (uint256 amountOut) {
        Repo.Layout storage l = Repo._layout();
        l.localReserves[pair] -= output.local;
        amountOut = output.local;
        if (output.shares != 0) {
            if (output.shares >= l.shareReserves[se]) revert InsufficientTokenOut();
            ExchangeInAmount.Result memory result = _convert(se, pair, output.shares, false);
            l.shareReserves[se] -= output.shares - result.amountRefunded;
            amountOut += result.amountOut;
        }
        if (amountOut < output.amount) revert InsufficientTokenOut();
    }

    function _executePlannedSwap(BookSwapPlan memory plan, bool exactIn, address recipient) internal returns (uint256 amountOut) {
        if (plan.output.amount == 0) revert InsufficientTokenOut();
        _bufferPool(plan.seIn, plan.tokenIn, plan.amountIn);
        if (exactIn) amountOut = _unwrapPlanned(plan.seOut, plan.tokenOut, plan.output);
        else {
            Repo.Layout storage l = Repo._layout();
            l.localReserves[plan.tokenOut] -= plan.output.local;
            amountOut = plan.output.amount;
            if (plan.output.shares != 0) {
                uint256 spent = _unwrapExactOut(plan.seOut, plan.tokenOut,
                    amountOut - plan.output.local, plan.output.shares);
                l.shareReserves[plan.seOut] -= spent;
            }
        }
        if (recipient != address(this)) IERC20(plan.tokenOut).safeTransfer(recipient, amountOut);
        _syncReserves();
    }

    function _previewDeposit(uint256 amount0, uint256 amount1)
        internal view returns (uint256 lpAmount, uint256 used0, uint256 used1)
    {
        return DepositQuoteLib.previewFlexible(amount0, false, amount1, false);
    }

    function _previewZapSplit(address tokenIn, uint256 amountIn)
        internal
        view
        returns (uint256 amountToSwap, uint256 amountOtherOut, uint256 amountKeptIn)
    {
        _requireZapEligible();
        _requireNonZero(amountIn);
        if (!_isBoundPairToken(tokenIn)) revert InvalidPairToken();
        amountToSwap = DepositQuoteLib.swapAmount(tokenIn, amountIn);
        amountKeptIn = amountIn - amountToSwap;
        if (amountToSwap != 0)
            amountOtherOut = _planExactIn(tokenIn == Repo._layout().currency0, amountToSwap).output.amount;
    }


    function _previewDepositSingle(address tokenIn, uint256 amountIn) internal view returns (uint256 lpAmount) {
        _requireZapEligible();
        _requireNonZero(amountIn);
        if (_classify(tokenIn) == UniswapV4SeBufferHookLegLib.LegKind.Unknown) revert InvalidPairToken();
        (, lpAmount) = DepositQuoteLib.preview(tokenIn, amountIn);
    }


    function _previewWithdraw(uint256 lpAmount) internal view returns (uint256 amount0, uint256 amount1) {
        _requireNonZero(lpAmount);
        return DepositQuoteLib.previewWithdraw(lpAmount, false, false);
    }


    function _previewDepositFlexible(uint256 amount0, bool asShare0, uint256 amount1, bool asShare1)
        internal view returns (uint256 lpAmount, uint256 used0, uint256 used1)
    {
        return DepositQuoteLib.previewFlexible(amount0, asShare0, amount1, asShare1);
    }


    function _previewWithdrawFlexible(uint256 lpAmount, bool asShare0, bool asShare1)
        internal view returns (uint256 amount0, uint256 amount1)
    {
        _requireNonZero(lpAmount);
        return DepositQuoteLib.previewWithdraw(lpAmount, asShare0, asShare1);
    }


    function _previewSwapExactIn(bool zeroForOne, uint256 amountIn)
        internal
        view
        returns (uint256 amountOut)
    {
        return _planExactInContext(zeroForOne, amountIn, Repo._layout().poolManager).output.amount;
    }


    function _previewSwapExactOut(bool zeroForOne, uint256 amountOut)
        internal
        view
        returns (uint256 amountIn)
    {
        return _planExactOut(zeroForOne, amountOut).amountIn;
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
