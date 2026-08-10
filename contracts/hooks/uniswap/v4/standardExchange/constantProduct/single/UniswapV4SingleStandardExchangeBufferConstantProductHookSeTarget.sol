// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
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
    UniswapV4SingleStandardExchangeBufferConstantProductHookRepo as Repo
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookRepo.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHookMath as Math
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookMath.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib as ClaimLib
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHookPullLib as PullLib
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookPullLib.sol";
import {
    IUniswapV4SingleStandardExchangeBufferConstantProductHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/interfaces/IUniswapV4SingleStandardExchangeBufferConstantProductHook.sol";

/**
 * @title UniswapV4SingleStandardExchangeBufferConstantProductHookSeTarget
 * @notice Product logic only: CP hooks, liquidity, SE In/Out, product views.
 * @dev LP ERC-20, IBasicVault, IStandardVault are cut as shared facets on the diamond.
 *      LP supply/balances use ERC20Repo; vaultTokens/reserves use MultiAssetBasicVaultRepo
 *      (pair reserve accounting = virtual SE claim; raw = face inventory).
 */
abstract contract UniswapV4SingleStandardExchangeBufferConstantProductHookSeTarget is IHooks {
    using SafeERC20 for IERC20;

    address internal constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    error ZeroAddress();
    error ZeroAmount();
    error NotPoolManager();
    error TokenNotInVaultTokens();
    error SameToken();
    error RawIsSE();
    error NotLive();
    error NotZapEligible();
    error InvalidToken();
    error DeadlineExpired();
    error InsufficientLpOut();
    error InsufficientTokenOut();
    error AlreadyInitialized();
    error Reentrancy();
    error LiquidityNotAllowed();
    error InvalidPoolToken();
    error InvalidPoolFee();
    error HookNotImplemented();
    error UnsupportedRoute();

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

    function poolManager() public view returns (address) {
        return Repo._layout().poolManager;
    }

    function feeOracle() public view returns (address) {
        return Repo._layout().feeOracle;
    }

    function permit2() public pure returns (address) {
        return PERMIT2;
    }

    function standardExchange() public view returns (address) {
        return Repo._layout().standardExchange;
    }

    function pairToken() public view returns (address) {
        return Repo._layout().pairToken;
    }

    function rawToken() public view returns (address) {
        return Repo._layout().rawToken;
    }

    function currency0() public view returns (address) {
        return Repo._layout().currency0;
    }

    function currency1() public view returns (address) {
        return Repo._layout().currency1;
    }

    function rawReserve() public view returns (uint256) {
        return IERC20(Repo._layout().rawToken).balanceOf(address(this));
    }

    function seClaimSupply() public view returns (uint256) {
        return _seClaim();
    }

    function reserveCurrency0() public view returns (uint256) {
        return _reserveOfCurrency(Repo._layout().currency0);
    }

    function reserveCurrency1() public view returns (uint256) {
        return _reserveOfCurrency(Repo._layout().currency1);
    }

    function isLive() public view returns (bool) {
        return _isLive();
    }

    function isZapEligible() public view returns (bool) {
        return _isZapEligible();
    }

    function tradingFeePercent() public pure returns (uint256) {
        return Repo.TRADING_FEE_PERCENT;
    }

    function tradingFeeDenominator() public pure returns (uint256) {
        return Repo.TRADING_FEE_DENOMINATOR;
    }

    function dexSwapFeeAndFeeTo() public view returns (address feeTo_, uint256 dexFeeWad) {
        (IFeeCollectorProxy ft, uint256 wad) =
            IVaultFeeOracleQuery(Repo._layout().feeOracle).dexSwapFeeAndFeeToOfVault(address(this));
        return (address(ft), wad);
    }

    function kLast() public view returns (uint256) {
        return Repo._layout().kLast;
    }

    function _seClaim() internal view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        uint256 seBal = IERC20(l.standardExchange).balanceOf(address(this));
        if (seBal == 0) return 0;
        return IStandardExchangeIn(l.standardExchange).previewExchangeIn(
            IERC20(l.standardExchange), seBal, IERC20(l.pairToken)
        );
    }

    function _reserveOfCurrency(address c) internal view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        if (c == l.rawToken) return IERC20(l.rawToken).balanceOf(address(this));
        if (c == l.pairToken) return _seClaim();
        return 0;
    }

    function _isLive() internal view returns (bool) {
        return reserveCurrency0() > 0 && reserveCurrency1() > 0;
    }

    function _isZapEligible() internal view returns (bool) {
        return _isLive() && ERC20Repo._totalSupply() > Repo.MINIMUM_LIQUIDITY;
    }

    /// @dev Keep MultiAssetBasicVaultRepo reserves aligned with product book (raw face × virtual pair).
    function _syncReserves() internal {
        Repo.Layout storage l = Repo._layout();
        MultiAssetBasicVaultRepo._updateReserve(IERC20(l.rawToken), IERC20(l.rawToken).balanceOf(address(this)));
        MultiAssetBasicVaultRepo._updateReserve(IERC20(l.pairToken), _seClaim());
    }

    function _mintLp(address to, uint256 amount) internal {
        if (amount == 0) return;
        ERC20Repo._mint(to, amount);
    }

    function _burnLp(address from, uint256 amount) internal {
        ERC20Repo._burn(from, amount);
    }

    function _onlyPoolManager() internal view {
        if (msg.sender != Repo._layout().poolManager) revert NotPoolManager();
    }

    function _requireLive() internal view {
        if (!_isLive()) revert NotLive();
    }

    function _requireZapEligible() internal view {
        if (!_isZapEligible()) revert NotZapEligible();
    }

    function _requireNonZero(uint256 amount) internal pure {
        if (amount == 0) revert ZeroAmount();
    }

    function _requireDeadline(uint256 deadline) internal view {
        if (block.timestamp > deadline) revert DeadlineExpired();
    }

    function _decimalsOf(address token) internal view returns (uint8) {
        Repo.Layout storage l = Repo._layout();
        if (token == l.currency0) return l.decimalsCurrency0;
        if (token == l.currency1) return l.decimalsCurrency1;
        revert InvalidToken();
    }

    function _wadProduct() internal view returns (uint256) {
        return Math.toWad(reserveCurrency0(), Repo._layout().decimalsCurrency0)
            * Math.toWad(reserveCurrency1(), Repo._layout().decimalsCurrency1);
    }

    function _feeOnAndShare()
        internal
        view
        returns (bool feeOn, address feeTo_, uint256 ownerFeeShare)
    {
        uint256 dexFeeWad;
        (feeTo_, dexFeeWad) = dexSwapFeeAndFeeTo();
        feeOn = feeTo_ != address(0) && dexFeeWad != 0;
        ownerFeeShare = (dexFeeWad * Repo.TRADING_FEE_DENOMINATOR) / 1e18;
    }

    function _previewBufferClaimIn(uint256 amountInRaw) internal view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        return ClaimLib.previewBufferClaimIn(
            l.standardExchange,
            l.pairToken,
            amountInRaw,
            IVaultFeeOracleQuery(l.feeOracle),
            address(this)
        );
    }

    function _invertBufferClaimIn(uint256 claimInNeeded) internal view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        return ClaimLib.invertBufferClaimIn(
            l.standardExchange,
            l.pairToken,
            claimInNeeded,
            IVaultFeeOracleQuery(l.feeOracle),
            address(this)
        );
    }

    /* ---------------------------------------------------------------------- */
    /*                              SE buffer / unwrap                        */
    /* ---------------------------------------------------------------------- */

    function _bufferPair(uint256 amount) internal returns (uint256 seOut) {
        _requireNonZero(amount);
        Repo.Layout storage l = Repo._layout();
        uint256 minOut = IStandardExchangeIn(l.standardExchange).previewExchangeIn(
            IERC20(l.pairToken), amount, IERC20(l.standardExchange)
        );
        IERC20(l.pairToken).forceApprove(l.standardExchange, amount);
        seOut = IStandardExchangeIn(l.standardExchange).exchangeIn(
            IERC20(l.pairToken),
            amount,
            IERC20(l.standardExchange),
            minOut,
            address(this),
            false,
            block.timestamp
        );
    }

    function _unwrapSeShares(uint256 seIn) internal returns (uint256 pairOut) {
        _requireNonZero(seIn);
        Repo.Layout storage l = Repo._layout();
        uint256 minOut = IStandardExchangeIn(l.standardExchange).previewExchangeIn(
            IERC20(l.standardExchange), seIn, IERC20(l.pairToken)
        );
        pairOut = IStandardExchangeIn(l.standardExchange).exchangeIn(
            IERC20(l.standardExchange),
            seIn,
            IERC20(l.pairToken),
            minOut,
            address(this),
            false,
            block.timestamp
        );
    }

    function _unwrapExactPairOut(uint256 pairOut) internal returns (uint256 seIn) {
        _requireNonZero(pairOut);
        Repo.Layout storage l = Repo._layout();
        seIn = IStandardExchangeOut(l.standardExchange).previewExchangeOut(
            IERC20(l.standardExchange), IERC20(l.pairToken), pairOut
        );
        uint256 spent = IStandardExchangeOut(l.standardExchange).exchangeOut(
            IERC20(l.standardExchange),
            seIn,
            IERC20(l.pairToken),
            pairOut,
            address(this),
            false,
            block.timestamp
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

    function _refundPairDust(address to) internal {
        Repo.Layout storage l = Repo._layout();
        uint256 bal = IERC20(l.pairToken).balanceOf(address(this));
        if (bal > Repo.MAX_DUST_WEI) {
            IERC20(l.pairToken).safeTransfer(to, bal);
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                                  IHooks                                */
    /* ---------------------------------------------------------------------- */

    function getHookPermissions() public pure returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: true,
            beforeAddLiquidity: true,
            beforeSwap: true,
            beforeSwapReturnDelta: true,
            afterSwap: false,
            afterInitialize: false,
            beforeRemoveLiquidity: false,
            afterAddLiquidity: false,
            afterRemoveLiquidity: false,
            beforeDonate: false,
            afterDonate: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    function beforeInitialize(address, PoolKey calldata poolKey, uint160)
        external
        override
        returns (bytes4)
    {
        _onlyPoolManager();
        Repo.Layout storage l = Repo._layout();
        if (l.poolInitialized) revert AlreadyInitialized();
        address a = Currency.unwrap(poolKey.currency0);
        address b = Currency.unwrap(poolKey.currency1);
        if (!(a == l.currency0 && b == l.currency1)) revert InvalidPoolToken();
        if (poolKey.fee != 0) revert InvalidPoolFee();
        l.poolInitialized = true;
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

    function beforeRemoveLiquidity(address, PoolKey calldata, ModifyLiquidityParams calldata, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        revert HookNotImplemented();
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

    function beforeSwap(address, PoolKey calldata, SwapParams calldata params, bytes calldata)
        external
        override
        returns (bytes4, BeforeSwapDelta swapDelta, uint24)
    {
        _onlyPoolManager();
        _requireLive();
        if (params.amountSpecified < 0) {
            swapDelta = _swapExactInPm(params.zeroForOne, uint256(-params.amountSpecified));
        } else {
            swapDelta = _swapExactOutPm(params.zeroForOne, uint256(params.amountSpecified));
        }
        return (IHooks.beforeSwap.selector, swapDelta, 0);
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
    /*                              swap core                                 */
    /* ---------------------------------------------------------------------- */

    function _zeroForOneIsRawIn() internal view returns (bool) {
        return Repo._layout().currency0 == Repo._layout().rawToken;
    }

    /// @dev zeroForOne: currency0 → currency1
    function _swapExactInPm(bool zeroForOne, uint256 amountInRaw)
        internal
        returns (BeforeSwapDelta swapDelta)
    {
        uint256 amountOut = _execExactIn(zeroForOne, amountInRaw, true);
        swapDelta = toBeforeSwapDelta(int128(int256(amountInRaw)), int128(-int256(amountOut)));
    }

    function _swapExactOutPm(bool zeroForOne, uint256 amountOut)
        internal
        returns (BeforeSwapDelta swapDelta)
    {
        uint256 amountInRaw = _execExactOut(zeroForOne, amountOut, true);
        swapDelta = toBeforeSwapDelta(int128(-int256(amountOut)), int128(int256(amountInRaw)));
    }

    /// @param viaPm if true, take/settle with PoolManager; else tokens already on hook / pay recipient externally
    function _execExactIn(bool zeroForOne, uint256 amountIn, bool viaPm)
        internal
        returns (uint256 amountOut)
    {
        _requireNonZero(amountIn);
        Repo.Layout storage l = Repo._layout();
        bool rawIn = zeroForOne == _zeroForOneIsRawIn();
        address tokenIn = zeroForOne ? l.currency0 : l.currency1;
        address tokenOut = zeroForOne ? l.currency1 : l.currency0;

        amountOut = _quoteExactIn(zeroForOne, amountIn);
        if (amountOut == 0) revert InsufficientTokenOut();

        if (viaPm) {
            _take(Currency.wrap(tokenIn), address(this), amountIn);
        }

        if (rawIn) {
            // raw → pair: CP on face raw vs seClaim; unwrap pair
            uint256 claimOut = amountOut; // amountOut is pair face ≈ claim units
            _unwrapExactPairOut(claimOut);
        } else {
            // pair → raw: buffer pair last after quote; pay raw
            _bufferPair(amountIn);
            IERC20(l.rawToken); // raw inventory already held
            // amountOut raw already computed from claimIn
        }

        if (viaPm) {
            _settle(Currency.wrap(tokenOut), amountOut);
        }
        _syncReserves();
    }

    function _execExactOut(bool zeroForOne, uint256 amountOut, bool viaPm)
        internal
        returns (uint256 amountIn)
    {
        _requireNonZero(amountOut);
        Repo.Layout storage l = Repo._layout();
        bool rawIn = zeroForOne == _zeroForOneIsRawIn();
        address tokenIn = zeroForOne ? l.currency0 : l.currency1;
        address tokenOut = zeroForOne ? l.currency1 : l.currency0;

        amountIn = _quoteExactOut(zeroForOne, amountOut);
        _requireNonZero(amountIn);

        if (viaPm) {
            _take(Currency.wrap(tokenIn), address(this), amountIn);
        }

        if (rawIn) {
            _unwrapExactPairOut(amountOut);
        } else {
            _bufferPair(amountIn);
        }

        if (viaPm) {
            _settle(Currency.wrap(tokenOut), amountOut);
        }
        _syncReserves();
    }

    function _quoteExactIn(bool zeroForOne, uint256 amountIn) internal view returns (uint256 amountOut) {
        Repo.Layout storage l = Repo._layout();
        bool rawIn = zeroForOne == _zeroForOneIsRawIn();
        uint256 rawBal = IERC20(l.rawToken).balanceOf(address(this));
        uint256 seClaim = _seClaim();
        if (rawIn) {
            // face raw in → claim/pair out
            uint256 rInN = Math.toWad(rawBal, _decimalsOf(l.rawToken));
            uint256 rOutN = Math.toWad(seClaim, _decimalsOf(l.pairToken));
            uint256 aInN = Math.toWad(amountIn, _decimalsOf(l.rawToken));
            amountOut = Math.fromWadFloor(Math.saleQuote(aInN, rInN, rOutN), _decimalsOf(l.pairToken));
        } else {
            // pair in → claimIn → raw out
            uint256 claimIn = _previewBufferClaimIn(amountIn);
            uint256 rInN = Math.toWad(seClaim, _decimalsOf(l.pairToken));
            uint256 rOutN = Math.toWad(rawBal, _decimalsOf(l.rawToken));
            uint256 cInN = Math.toWad(claimIn, _decimalsOf(l.pairToken));
            amountOut = Math.fromWadFloor(Math.saleQuote(cInN, rInN, rOutN), _decimalsOf(l.rawToken));
        }
    }

    function _quoteExactOut(bool zeroForOne, uint256 amountOut) internal view returns (uint256 amountIn) {
        Repo.Layout storage l = Repo._layout();
        bool rawIn = zeroForOne == _zeroForOneIsRawIn();
        uint256 rawBal = IERC20(l.rawToken).balanceOf(address(this));
        uint256 seClaim = _seClaim();
        if (rawIn) {
            // need pair out → raw in
            uint256 claimOutN = Math.toWad(amountOut, _decimalsOf(l.pairToken));
            uint256 rInN = Math.toWad(rawBal, _decimalsOf(l.rawToken));
            uint256 rOutN = Math.toWad(seClaim, _decimalsOf(l.pairToken));
            amountIn = Math.fromWadCeil(Math.purchaseQuote(claimOutN, rInN, rOutN), _decimalsOf(l.rawToken));
        } else {
            // need raw out → claimIn → invert buffer
            uint256 rawOutN = Math.toWad(amountOut, _decimalsOf(l.rawToken));
            uint256 rInN = Math.toWad(seClaim, _decimalsOf(l.pairToken));
            uint256 rOutN = Math.toWad(rawBal, _decimalsOf(l.rawToken));
            uint256 claimInN = Math.purchaseQuote(rawOutN, rInN, rOutN);
            uint256 claimIn = Math.fromWadCeil(claimInN, _decimalsOf(l.pairToken));
            amountIn = _invertBufferClaimIn(claimIn);
        }
    }
    function previewSwapExactIn(bool zeroForOne, uint256 amountIn)
        external
        view
        returns (uint256 amountOut)
    {
        return _quoteExactIn(zeroForOne, amountIn);
    }

    function previewSwapExactOut(bool zeroForOne, uint256 amountOut)
        external
        view
        returns (uint256 amountIn)
    {
        return _quoteExactOut(zeroForOne, amountOut);
    }

    /* ---------------------------------------------------------------------- */
    /*                         IStandardExchangeIn / Out                      */
    /* ---------------------------------------------------------------------- */

    function previewExchangeIn(IERC20 tokenIn, uint256 amountIn, IERC20 tokenOut)
        external
        view
        returns (uint256 amountOut)
    {
        bool zfo = _routeZeroForOne(address(tokenIn), address(tokenOut));
        return _quoteExactIn(zfo, amountIn);
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
        bool zfo = _routeZeroForOne(address(tokenIn), address(tokenOut));
        // Quote on pre-pull book so inventory does not reprice the trade mid-path.
        amountOut = _quoteExactIn(zfo, amountIn);
        if (amountOut < minAmountOut) revert InsufficientTokenOut();
        // L-GAPS-11 / ISecurePullErrors: pretransfer credits claimed only when in-window
        // delta covers it — blocks free extract of SE book / raw inventory. Leftover
        // spendable economics unchanged (surplus delta not exact-matched).
        _securePull(IERC20(address(tokenIn)), amountIn, pretransferred);

        Repo.Layout storage l = Repo._layout();
        bool rawIn = zfo == _zeroForOneIsRawIn();
        if (rawIn) {
            _unwrapExactPairOut(amountOut);
            IERC20(l.pairToken).safeTransfer(recipient, amountOut);
        } else {
            _bufferPair(amountIn);
            IERC20(l.rawToken).safeTransfer(recipient, amountOut);
        }
        _syncReserves();
    }

    function previewExchangeOut(IERC20 tokenIn, IERC20 tokenOut, uint256 amountOut)
        external
        view
        returns (uint256 amountIn)
    {
        bool zfo = _routeZeroForOne(address(tokenIn), address(tokenOut));
        return _quoteExactOut(zfo, amountOut);
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
        bool zfo = _routeZeroForOne(address(tokenIn), address(tokenOut));
        amountIn = _quoteExactOut(zfo, amountOut);
        if (amountIn > maxAmountIn) revert InsufficientTokenOut();
        // L-GAPS-11: delta-gate claimed amountIn. Refund only in-window surplus above amountIn
        // (never absolute maxAmountIn - amountIn from free inventory / SE book).
        uint256 observedDelta = _securePull(IERC20(address(tokenIn)), amountIn, pretransferred);
        if (pretransferred && observedDelta > amountIn) {
            IERC20(address(tokenIn)).safeTransfer(msg.sender, observedDelta - amountIn);
        }

        Repo.Layout storage l = Repo._layout();
        bool rawIn = zfo == _zeroForOneIsRawIn();
        if (rawIn) {
            _unwrapExactPairOut(amountOut);
            IERC20(l.pairToken).safeTransfer(recipient, amountOut);
        } else {
            _bufferPair(amountIn);
            IERC20(l.rawToken).safeTransfer(recipient, amountOut);
        }
        _syncReserves();
    }

    /// @dev Delta-based secure pull (L-GAPS-11 / ISecurePullErrors; BasicVaultCommon peer).
    ///      Measures `observedDelta` over the pull window. Pretransfer credits exactly `claimed`
    ///      only when `claimed <= observedDelta`; otherwise reverts
    ///      `TransferDeltaInsufficient(claimed, observedDelta)`. Absolute inventory without a
    ///      positive in-window delta cannot free-extract SE book / raw face (I1). Surplus delta
    ///      is not exact-matched (leftover spendable / no exact-delta grief).
    function _securePull(IERC20 tokenIn, uint256 claimed, bool pretransferred)
        internal
        returns (uint256 observedDelta)
    {
        uint256 balBefore = tokenIn.balanceOf(address(this));
        if (!pretransferred) {
            tokenIn.safeTransferFrom(msg.sender, address(this), claimed);
        }
        observedDelta = tokenIn.balanceOf(address(this)) - balBefore;
        if (pretransferred) {
            if (claimed > observedDelta) {
                revert ISecurePullErrors.TransferDeltaInsufficient(claimed, observedDelta);
            }
        }
    }

    function _routeZeroForOne(address tokenIn, address tokenOut) internal view returns (bool) {
        Repo.Layout storage l = Repo._layout();
        if (tokenIn == l.currency0 && tokenOut == l.currency1) return true;
        if (tokenIn == l.currency1 && tokenOut == l.currency0) return false;
        revert UnsupportedRoute();
    }

    /* ---------------------------------------------------------------------- */
    /*                              protocol fee                              */
    /* ---------------------------------------------------------------------- */

    function _mintProtocolFeeIfNeeded() internal {
        (bool feeOn, address feeTo_, uint256 ownerFeeShare) = _feeOnAndShare();
        Repo.Layout storage l = Repo._layout();
        if (!feeOn) {
            l.kLast = 0;
            return;
        }
        uint256 kLast_ = l.kLast;
        if (kLast_ == 0) return;
        uint256 protocolLp =
            Math.calculateProtocolFee(ERC20Repo._totalSupply(), _wadProduct(), kLast_, ownerFeeShare);
        if (protocolLp > 0) _mintLp(feeTo_, protocolLp);
    }

    function _setKLastPostOp() internal {
        (bool feeOn,,) = _feeOnAndShare();
        Repo._layout().kLast = feeOn ? _wadProduct() : 0;
    }

    function _supplyAfterProtocolMint() internal view returns (uint256 supplyAdj) {
        supplyAdj = ERC20Repo._totalSupply();
        (bool feeOn,, uint256 ownerFeeShare) = _feeOnAndShare();
        uint256 kLast_ = Repo._layout().kLast;
        if (feeOn && kLast_ != 0 && supplyAdj > 0) {
            supplyAdj += Math.calculateProtocolFee(supplyAdj, _wadProduct(), kLast_, ownerFeeShare);
        }
    }

    /* ---------------------------------------------------------------------- */
}
