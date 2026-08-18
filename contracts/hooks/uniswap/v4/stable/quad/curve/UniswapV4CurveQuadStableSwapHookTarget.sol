// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
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
import {ModifyLiquidityParams, SwapParams} from
    "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {BalanceDelta} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {IRateProvider} from
    "@crane/contracts/protocols/dexes/balancer/common/interfaces/IRateProvider.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {
    IUniswapV4CurveQuadStableSwapHook
} from "contracts/hooks/uniswap/v4/stable/quad/curve/interfaces/IUniswapV4CurveQuadStableSwapHook.sol";
import {
    UniswapV4CurveQuadStableSwapHookRepo as Repo
} from "contracts/hooks/uniswap/v4/stable/quad/curve/UniswapV4CurveQuadStableSwapHookRepo.sol";
import {
    UniswapV4CurveQuadStableSwapHookMath as Math
} from "contracts/hooks/uniswap/v4/stable/quad/curve/UniswapV4CurveQuadStableSwapHookMath.sol";
import {
    UniswapV4CurveQuadStableSwapHookBeforeInitializeLib as BeforeInitializeLib
} from "contracts/hooks/uniswap/v4/stable/quad/curve/UniswapV4CurveQuadStableSwapHookBeforeInitializeLib.sol";

/**
 * @title UniswapV4CurveQuadStableSwapHookTarget
 * @notice Product logic: IHooks + LP execute + StableSwap beforeSwap (fee-on-output).
 * @dev Bindings in Repo (initAccount). LP via ERC20Repo; vault reserves via MultiAssetBasicVaultRepo.
 *      No constructor immutables; no monomorph Common inheritance. No BaseHook / DeltaResolver.
 */
abstract contract UniswapV4CurveQuadStableSwapHookTarget is IHooks, IUniswapV4CurveQuadStableSwapHook {
    error InvalidTokenOrder();
    error InvalidToken();
    error InvalidFee();
    error InvalidAmp();
    error ZeroAmount();
    error Slippage();
    error NotZapEligible();
    error SwapNotLive();
    error InvariantFailed();
    error RateProviderFailed();
    error InvalidRoute();
    error InvalidPoolKey();
    error LiquidityNotAllowed();
    error DonateNotAllowed();
    error HookNotImplemented();
    error NotPoolManager();
    error Reentrancy();
    error ZeroAddress();
    error TransferFailed();

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

    function token0() public view returns (address) {
        return Repo._layout().token0;
    }

    function token1() public view returns (address) {
        return Repo._layout().token1;
    }

    function token2() public view returns (address) {
        return Repo._layout().token2;
    }

    function token3() public view returns (address) {
        return Repo._layout().token3;
    }

    function tokens() public view returns (address[4] memory t) {
        Repo.Layout storage l = Repo._layout();
        t[0] = l.token0;
        t[1] = l.token1;
        t[2] = l.token2;
        t[3] = l.token3;
    }

    function lpFeePips() public view returns (uint24) {
        return Repo._layout().lpFeePips;
    }

    function baseAmp() public view returns (uint256) {
        return Repo._layout().baseAmp;
    }

    function getCurrentAmp() public view returns (uint256) {
        return Repo._layout().baseAmp * Math.AMP_PRECISION;
    }

    function rateProvider(uint256 index) public view returns (address) {
        Repo.Layout storage l = Repo._layout();
        if (index == 0) return l.rateProvider0;
        if (index == 1) return l.rateProvider1;
        if (index == 2) return l.rateProvider2;
        if (index == 3) return l.rateProvider3;
        revert InvalidRoute();
    }

    function rateProviders() public view returns (address[4] memory p) {
        Repo.Layout storage l = Repo._layout();
        p[0] = l.rateProvider0;
        p[1] = l.rateProvider1;
        p[2] = l.rateProvider2;
        p[3] = l.rateProvider3;
    }

    function reserveOf(address token) public view returns (uint256) {
        return Repo._layout().reserves[_tokenIndex(token)];
    }

    function effectiveRate(uint256 index) public view returns (uint256) {
        return _effectiveRate(index);
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
            beforeDonate: true,
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
        return BeforeInitializeLib.beforeInitialize(poolKey);
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
        view
        override
        returns (bytes4)
    {
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
        swapDelta = params.amountSpecified < 0
            ? _beforeSwapExactIn(key, params)
            : _beforeSwapExactOut(key, params);
        return (IHooks.beforeSwap.selector, swapDelta, 0);
    }

    function _beforeSwapExactIn(PoolKey calldata key, SwapParams calldata params)
        private
        returns (BeforeSwapDelta swapDelta)
    {
        (address tokenIn, address tokenOut, uint256 i, uint256 j) = _swapRoute(key, params.zeroForOne);
        Repo.Layout storage l = Repo._layout();
        if (l.reserves[i] == 0 || l.reserves[j] == 0) revert SwapNotLive();

        uint256 amountIn = uint256(-params.amountSpecified);
        if (amountIn == 0) revert ZeroAmount();
        (uint256 amountOut, uint256[4] memory newR) = Math.quoteExactIn(
            l.reserves, _loadRates(), i, j, amountIn, getCurrentAmp(), l.lpFeePips
        );
        l.reserves = newR;
        _take(Currency.wrap(tokenIn), address(this), amountIn);
        _settle(Currency.wrap(tokenOut), amountOut);
        _syncVaultReserves();
        swapDelta = toBeforeSwapDelta(int128(int256(amountIn)), int128(-int256(amountOut)));
    }

    function _beforeSwapExactOut(PoolKey calldata key, SwapParams calldata params)
        private
        returns (BeforeSwapDelta swapDelta)
    {
        (address tokenIn, address tokenOut, uint256 i, uint256 j) = _swapRoute(key, params.zeroForOne);
        Repo.Layout storage l = Repo._layout();
        if (l.reserves[i] == 0 || l.reserves[j] == 0) revert SwapNotLive();

        uint256 amountOut = uint256(params.amountSpecified);
        if (amountOut == 0) revert ZeroAmount();
        (uint256 amountIn, uint256[4] memory newR) = Math.quoteExactOut(
            l.reserves, _loadRates(), i, j, amountOut, getCurrentAmp(), l.lpFeePips
        );
        l.reserves = newR;
        _take(Currency.wrap(tokenIn), address(this), amountIn);
        _settle(Currency.wrap(tokenOut), amountOut);
        _syncVaultReserves();
        swapDelta = toBeforeSwapDelta(int128(-int256(amountOut)), int128(int256(amountIn)));
    }

    function _swapRoute(PoolKey calldata key, bool zeroForOne)
        private
        view
        returns (address tokenIn, address tokenOut, uint256 i, uint256 j)
    {
        address c0 = Currency.unwrap(key.currency0);
        address c1 = Currency.unwrap(key.currency1);
        tokenIn = zeroForOne ? c0 : c1;
        tokenOut = zeroForOne ? c1 : c0;
        i = _tokenIndex(tokenIn);
        j = _tokenIndex(tokenOut);
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
        view
        override
        returns (bytes4)
    {
        _onlyPoolManager();
        revert DonateNotAllowed();
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
    /*                         public LP / zap / preview                      */
    /* ---------------------------------------------------------------------- */

    function previewAddLiquidity(uint256[4] calldata amounts)
        external
        view
        returns (uint256 shares, uint256[4] memory actualAmounts)
    {
        return _previewAddLiquidity(amounts);
    }

    function previewRemoveLiquidity(uint256 shares) external view returns (uint256[4] memory amounts) {
        return _previewRemoveLiquidity(shares);
    }

    function previewZapIn(uint256[4] calldata amounts)
        external
        view
        returns (uint256 shares, uint256[4] memory amountsUsed)
    {
        return _previewZapIn(amounts);
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

    function addLiquidity(
        uint256[4] calldata amounts,
        uint256[4] calldata minAmounts,
        address to,
        uint256 sharesMin
    ) external nonReentrant returns (uint256 shares, uint256[4] memory actualAmounts) {
        return _addLiquidity(amounts, minAmounts, to, sharesMin);
    }

    function zapIn(uint256[4] calldata amounts, address to, uint256 sharesMin)
        external
        nonReentrant
        returns (uint256 shares, uint256[4] memory amountsUsed)
    {
        return _zapIn(amounts, to, sharesMin);
    }

    function removeLiquidity(uint256 shares, address to, uint256[4] calldata minAmounts)
        external
        nonReentrant
        returns (uint256[4] memory amounts)
    {
        return _removeLiquidity(shares, to, minAmounts);
    }

    /* ---------------------------------------------------------------------- */
    /*                              token helpers                             */
    /* ---------------------------------------------------------------------- */

    function _tokenIndex(address token) internal view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        if (token == l.token0) return 0;
        if (token == l.token1) return 1;
        if (token == l.token2) return 2;
        if (token == l.token3) return 3;
        revert InvalidRoute();
    }

    function _tokenAt(uint256 index) internal view returns (address) {
        Repo.Layout storage l = Repo._layout();
        if (index == 0) return l.token0;
        if (index == 1) return l.token1;
        if (index == 2) return l.token2;
        if (index == 3) return l.token3;
        revert InvalidRoute();
    }

    function _baseScaleAt(uint256 index) internal view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        if (index == 0) return l.baseScale0;
        if (index == 1) return l.baseScale1;
        if (index == 2) return l.baseScale2;
        if (index == 3) return l.baseScale3;
        revert InvalidRoute();
    }

    function _effectiveRate(uint256 index) internal view returns (uint256) {
        uint256 base = _baseScaleAt(index);
        address provider = rateProvider(index);
        uint256 oracleRate = Math.RATE_PRECISION;
        if (provider != address(0)) {
            oracleRate = _getRateFailClosed(provider);
        }
        return (base * oracleRate) / Math.RATE_PRECISION;
    }

    function _loadRates() internal view returns (uint256[4] memory rates) {
        rates[0] = _effectiveRate(0);
        rates[1] = _effectiveRate(1);
        rates[2] = _effectiveRate(2);
        rates[3] = _effectiveRate(3);
    }

    function _getRateFailClosed(address provider) internal view returns (uint256 rate) {
        (bool ok, bytes memory ret) =
            provider.staticcall(abi.encodeWithSelector(IRateProvider.getRate.selector));
        if (!ok || ret.length != 32) revert RateProviderFailed();
        rate = abi.decode(ret, (uint256));
        if (rate == 0) revert RateProviderFailed();
    }

    function _onlyPoolManager() internal view {
        if (msg.sender != Repo._layout().poolManager) revert NotPoolManager();
    }

    /* ---------------------------------------------------------------------- */
    /*                           pull / push / settle                         */
    /* ---------------------------------------------------------------------- */

    function _pull(address token, uint256 amount) internal {
        if (amount == 0) return;
        _callOptionalReturn(
            token, abi.encodeWithSelector(IERC20.transferFrom.selector, msg.sender, address(this), amount)
        );
    }

    function _push(address token, address to, uint256 amount) internal {
        if (amount == 0) return;
        _callOptionalReturn(token, abi.encodeWithSelector(IERC20.transfer.selector, to, amount));
    }

    function _callOptionalReturn(address token, bytes memory data) private {
        (bool success, bytes memory returndata) = token.call(data);
        if (!success) {
            if (returndata.length > 0) {
                assembly {
                    revert(add(returndata, 0x20), mload(returndata))
                }
            }
            revert TransferFailed();
        }
        if (returndata.length > 0) {
            require(abi.decode(returndata, (bool)), "ERC20 op false");
        }
    }

    function _take(Currency currency, address recipient, uint256 amount) internal {
        if (amount == 0) return;
        IPoolManager(Repo._layout().poolManager).take(currency, recipient, amount);
    }

    function _settle(Currency currency, uint256 amount) internal {
        if (amount == 0) return;
        IPoolManager pm = IPoolManager(Repo._layout().poolManager);
        pm.sync(currency);
        _callOptionalReturn(
            Currency.unwrap(currency),
            abi.encodeWithSelector(IERC20.transfer.selector, address(pm), amount)
        );
        pm.settle();
    }

    /* ---------------------------------------------------------------------- */
    /*                         LP mint/burn + vault sync                      */
    /* ---------------------------------------------------------------------- */

    function _mintLp(address to, uint256 amount) internal {
        ERC20Repo._mint(to, amount);
    }

    function _burnLp(address from, uint256 amount) internal {
        ERC20Repo._burn(from, amount);
    }

    function _totalSupply() internal view returns (uint256) {
        return ERC20Repo._totalSupply();
    }

    function _syncVaultReserves() internal {
        Repo.Layout storage l = Repo._layout();
        MultiAssetBasicVaultRepo._updateReserve(IERC20(l.token0), l.reserves[0]);
        MultiAssetBasicVaultRepo._updateReserve(IERC20(l.token1), l.reserves[1]);
        MultiAssetBasicVaultRepo._updateReserve(IERC20(l.token2), l.reserves[2]);
        MultiAssetBasicVaultRepo._updateReserve(IERC20(l.token3), l.reserves[3]);
    }

    function _isZapEligible() internal view returns (bool) {
        if (_totalSupply() <= Math.MINIMUM_LIQUIDITY) return false;
        uint256[4] memory r = Repo._layout().reserves;
        return r[0] > 0 && r[1] > 0 && r[2] > 0 && r[3] > 0;
    }

    function _requireZapEligible() internal view {
        if (!_isZapEligible()) revert NotZapEligible();
    }

    /* ---------------------------------------------------------------------- */
    /*                            liquidity + zap                             */
    /* ---------------------------------------------------------------------- */

    function _previewAddLiquidity(uint256[4] memory amounts)
        internal
        view
        returns (uint256 shares, uint256[4] memory actual)
    {
        Repo.Layout storage l = Repo._layout();
        uint256[4] memory rates = _loadRates();
        uint256 supply = _totalSupply();
        if (supply == 0) {
            for (uint256 i; i < 4; ++i) {
                if (amounts[i] == 0) revert ZeroAmount();
            }
            uint256[4] memory scaled;
            for (uint256 i; i < 4; ++i) {
                scaled[i] = Math.scaleTo(amounts[i], rates[i]);
            }
            shares = Math.firstMintShares(scaled);
            actual = amounts;
            return (shares, actual);
        }
        (shares, actual) = Math.laterMintShares(amounts, l.reserves, supply);
    }

    function _addLiquidity(
        uint256[4] memory amounts,
        uint256[4] memory minAmounts,
        address to,
        uint256 sharesMin
    ) internal returns (uint256 shares, uint256[4] memory actual) {
        if (to == address(0)) revert ZeroAddress();
        (shares, actual) = _previewAddLiquidity(amounts);
        if (shares < sharesMin) revert Slippage();
        for (uint256 i; i < 4; ++i) {
            if (actual[i] < minAmounts[i]) revert Slippage();
        }

        Repo.Layout storage l = Repo._layout();
        bool first = _totalSupply() == 0;

        for (uint256 i; i < 4; ++i) {
            _pull(_tokenAt(i), actual[i]);
            l.reserves[i] += actual[i];
        }

        if (first) {
            _mintLp(address(0), Math.MINIMUM_LIQUIDITY);
        }
        _mintLp(to, shares);
        _syncVaultReserves();
        _requirePriceable();
    }

    function _previewRemoveLiquidity(uint256 shares)
        internal
        view
        returns (uint256[4] memory amounts)
    {
        return Math.removeAmounts(shares, Repo._layout().reserves, _totalSupply());
    }

    function _removeLiquidity(uint256 shares, address to, uint256[4] memory minAmounts)
        internal
        returns (uint256[4] memory amounts)
    {
        if (to == address(0)) revert ZeroAddress();
        if (shares == 0) revert ZeroAmount();
        Repo.Layout storage l = Repo._layout();
        amounts = Math.removeAmounts(shares, l.reserves, _totalSupply());
        for (uint256 i; i < 4; ++i) {
            if (amounts[i] < minAmounts[i]) revert Slippage();
        }
        _burnLp(msg.sender, shares);
        for (uint256 i; i < 4; ++i) {
            l.reserves[i] -= amounts[i];
            _push(_tokenAt(i), to, amounts[i]);
        }
        _syncVaultReserves();
    }

    function _previewSwapExactIn(address tokenIn, address tokenOut, uint256 amountIn)
        internal
        view
        returns (uint256 amountOut)
    {
        uint256 i = _tokenIndex(tokenIn);
        uint256 j = _tokenIndex(tokenOut);
        Repo.Layout storage l = Repo._layout();
        if (l.reserves[i] == 0 || l.reserves[j] == 0) revert SwapNotLive();
        (amountOut,) =
            Math.quoteExactIn(l.reserves, _loadRates(), i, j, amountIn, getCurrentAmp(), l.lpFeePips);
    }

    function _previewSwapExactOut(address tokenIn, address tokenOut, uint256 amountOut)
        internal
        view
        returns (uint256 amountIn)
    {
        uint256 i = _tokenIndex(tokenIn);
        uint256 j = _tokenIndex(tokenOut);
        Repo.Layout storage l = Repo._layout();
        if (l.reserves[i] == 0 || l.reserves[j] == 0) revert SwapNotLive();
        (amountIn,) =
            Math.quoteExactOut(l.reserves, _loadRates(), i, j, amountOut, getCurrentAmp(), l.lpFeePips);
    }

    /* ---------------------------------------------------------------------- */
    /*                         Zap Algorithm A (plan §6.5)                    */
    /* ---------------------------------------------------------------------- */

    function _previewZapIn(uint256[4] memory amounts)
        internal
        view
        returns (uint256 shares, uint256[4] memory amountsUsed)
    {
        _requireZapEligible();
        bool any;
        for (uint256 i; i < 4; ++i) {
            if (amounts[i] > 0) any = true;
        }
        if (!any) revert ZeroAmount();

        uint256[4] memory rates = _loadRates();
        Repo.Layout storage l = Repo._layout();
        uint256[4] memory W = amounts;
        uint256[4] memory workingR = l.reserves;
        uint256 amp = getCurrentAmp();

        (W, workingR) = _zapRebalance(W, workingR, rates, amp);
        (shares, amountsUsed) = Math.laterMintShares(W, workingR, _totalSupply());
    }

    function _zapIn(uint256[4] memory amounts, address to, uint256 sharesMin)
        internal
        returns (uint256 shares, uint256[4] memory amountsUsed)
    {
        if (to == address(0)) revert ZeroAddress();
        _requireZapEligible();
        bool any;
        for (uint256 i; i < 4; ++i) {
            if (amounts[i] > 0) any = true;
        }
        if (!any) revert ZeroAmount();

        for (uint256 i; i < 4; ++i) {
            if (amounts[i] > 0) _pull(_tokenAt(i), amounts[i]);
        }

        uint256[4] memory rates = _loadRates();
        Repo.Layout storage l = Repo._layout();
        uint256[4] memory W = amounts;
        uint256[4] memory workingR = l.reserves;
        uint256 amp = getCurrentAmp();

        (W, workingR) = _zapRebalance(W, workingR, rates, amp);

        (shares, amountsUsed) = Math.laterMintShares(W, workingR, _totalSupply());
        if (shares < sharesMin) revert Slippage();

        for (uint256 i; i < 4; ++i) {
            l.reserves[i] = workingR[i] + amountsUsed[i];
            uint256 refund = W[i] - amountsUsed[i];
            if (refund > 0) _push(_tokenAt(i), msg.sender, refund);
        }
        _mintLp(to, shares);
        _syncVaultReserves();
        _requirePriceable();
    }

    struct ZapWork {
        uint256[4] W;
        uint256[4] workingR;
        uint256[4] rates;
        uint256 amp;
        uint24 fee;
    }

    function _zapRebalance(
        uint256[4] memory W,
        uint256[4] memory workingR,
        uint256[4] memory rates,
        uint256 amp
    ) internal view returns (uint256[4] memory, uint256[4] memory) {
        ZapWork memory z;
        z.W = W;
        z.workingR = workingR;
        z.rates = rates;
        z.amp = amp;
        z.fee = Repo._layout().lpFeePips;
        _zapRebalanceWork(z);
        return (z.W, z.workingR);
    }

    function _zapRebalanceWork(ZapWork memory z) private view {
        for (uint256 pass; pass < 2; ++pass) {
            (uint256[4] memory T_s, bool allMatch) = _zapTargets(z);
            if (allMatch) return;
            _zapPassSurplusDeficit(z, T_s);
        }
        _zapSeedZeroLegs(z);
    }

    function _zapSeedZeroLegs(ZapWork memory z) private view {
        for (uint256 round; round < 4; ++round) {
            bool anyZero;
            for (uint256 j; j < 4; ++j) {
                if (z.W[j] == 0 && z.workingR[j] > 0) {
                    anyZero = true;
                    break;
                }
            }
            if (!anyZero) return;

            uint256 i = 0;
            for (uint256 k = 1; k < 4; ++k) {
                if (z.W[k] > z.W[i]) i = k;
            }
            if (z.W[i] == 0) return;

            for (uint256 j; j < 4; ++j) {
                if (j == i || z.W[j] != 0 || z.workingR[j] == 0) continue;
                uint256 slice = z.W[i] / 4;
                if (slice == 0) slice = 1;
                if (slice > z.W[i]) slice = z.W[i];
                uint256 maxV = _maxViableIn(z, i, j, slice);
                if (maxV == 0) {
                    maxV = _maxViableIn(z, i, j, 1);
                    if (maxV == 0) continue;
                    slice = maxV;
                } else if (slice > maxV) {
                    slice = maxV;
                }
                _zapTryExecuteExactIn(z, i, j, slice);
            }
        }
    }

    function _zapTargets(ZapWork memory z)
        private
        pure
        returns (uint256[4] memory T_s, bool allMatch)
    {
        uint256 V;
        uint256 S;
        uint256[4] memory wS;
        uint256[4] memory rS;
        for (uint256 i; i < 4; ++i) {
            wS[i] = Math.scaleTo(z.W[i], z.rates[i]);
            rS[i] = Math.scaleTo(z.workingR[i], z.rates[i]);
            V += wS[i];
            S += rS[i];
        }
        allMatch = true;
        if (S == 0 || V == 0) return (T_s, true);
        for (uint256 i; i < 4; ++i) {
            T_s[i] = (V * rS[i]) / S;
            if (wS[i] > T_s[i] + 1 || wS[i] + 1 < T_s[i]) allMatch = false;
        }
    }

    function _zapPassSurplusDeficit(ZapWork memory z, uint256[4] memory T_s) private view {
        for (uint256 n; n < 12; ++n) {
            if (!_zapOneInternalSwap(z, T_s)) break;
        }
    }

    function _zapOneInternalSwap(ZapWork memory z, uint256[4] memory T_s)
        private
        view
        returns (bool did)
    {
        for (uint256 i; i < 4; ++i) {
            uint256 wSi = Math.scaleTo(z.W[i], z.rates[i]);
            if (!(wSi > T_s[i] + 1)) continue;
            for (uint256 j; j < 4; ++j) {
                if (j == i) continue;
                uint256 wSj = Math.scaleTo(z.W[j], z.rates[j]);
                if (!(wSj + 1 < T_s[j])) continue;
                if (_zapApplyPair(z, i, j, T_s[j] - wSj, wSi, T_s[i])) return true;
            }
        }
        return false;
    }

    function _zapApplyPair(
        ZapWork memory z,
        uint256 i,
        uint256 j,
        uint256 needJScaled,
        uint256 wSi,
        uint256 Tsi
    ) private view returns (bool) {
        uint256 wantUserOut = Math.descaleUp(needJScaled, z.rates[j]);
        uint256 swapIn = _zapSizeSwapIn(z, i, j, wantUserOut, wSi, Tsi);
        if (swapIn == 0) return false;
        return _zapTryExecuteExactIn(z, i, j, swapIn);
    }

    function _zapTryExecuteExactIn(ZapWork memory z, uint256 i, uint256 j, uint256 swapIn)
        private
        view
        returns (bool)
    {
        try this.zapQuoteExactInExternal(z.workingR, z.rates, i, j, swapIn, z.amp, z.fee) returns (
            uint256 userOut, uint256[4] memory newR
        ) {
            if (userOut == 0 || swapIn > z.W[i]) return false;
            z.workingR = newR;
            z.W[i] -= swapIn;
            z.W[j] += userOut;
            return true;
        } catch {
            return false;
        }
    }

    /// @dev External boundary so zap internal swaps can try/catch quote failures (must be cut).
    function zapQuoteExactInExternal(
        uint256[4] memory reserves_,
        uint256[4] memory rates,
        uint256 i,
        uint256 j,
        uint256 swapIn,
        uint256 amp,
        uint24 fee
    ) external pure returns (uint256 userOut, uint256[4] memory newR) {
        return Math.quoteExactIn(reserves_, rates, i, j, swapIn, amp, fee);
    }

    function _zapSizeSwapIn(
        ZapWork memory z,
        uint256 i,
        uint256 j,
        uint256 wantUserOutRaw,
        uint256 wSi,
        uint256 Tsi
    ) private view returns (uint256 swapIn) {
        uint256 rawSurplus = Math.descale(wSi > Tsi ? wSi - Tsi : 0, z.rates[i]);
        if (rawSurplus == 0 || wantUserOutRaw == 0) return 0;

        uint256 amountInIdeal = _closedFormInverseExactIn(z, i, j, wantUserOutRaw);
        if (amountInIdeal == 0) {
            return _maxViableIn(z, i, j, rawSurplus);
        }
        swapIn = rawSurplus < amountInIdeal ? rawSurplus : amountInIdeal;
        uint256 maxViable = _maxViableIn(z, i, j, rawSurplus);
        if (maxViable == 0) return 0;
        if (swapIn > maxViable) swapIn = maxViable;
    }

    function _closedFormInverseExactIn(ZapWork memory z, uint256 i, uint256 j, uint256 wantUserOutRaw)
        private
        view
        returns (uint256 amountInIdeal)
    {
        if (wantUserOutRaw == 0) return 0;
        uint256 rawOutNeeded = Math.feeOnOutputExactOutGrossUp(wantUserOutRaw, z.fee);
        if (rawOutNeeded >= z.workingR[j]) return 0;

        uint256[4] memory xp;
        xp[0] = Math.scaleTo(z.workingR[0], z.rates[0]);
        xp[1] = Math.scaleTo(z.workingR[1], z.rates[1]);
        xp[2] = Math.scaleTo(z.workingR[2], z.rates[2]);
        xp[3] = Math.scaleTo(z.workingR[3], z.rates[3]);
        if (xp[0] == 0 || xp[1] == 0 || xp[2] == 0 || xp[3] == 0) return 0;

        try this.tryGetYForZap(xp, z.amp, i, j, rawOutNeeded, z.rates[j]) returns (uint256 xInNew) {
            if (xInNew <= xp[i]) return 0;
            amountInIdeal = Math.descaleUp(xInNew - xp[i], z.rates[i]);
        } catch {
            return 0;
        }
    }

    /// @dev External try/catch boundary for zap inverse (must be cut).
    function tryGetYForZap(
        uint256[4] memory xp,
        uint256 amp,
        uint256 i,
        uint256 j,
        uint256 rawOutNeeded,
        uint256 rateOut
    ) external pure returns (uint256 xInNew) {
        uint256 D = Math.getD(xp, amp);
        uint256 yOutScaledDelta = Math.scaleToUp(rawOutNeeded, rateOut);
        if (yOutScaledDelta >= xp[j]) revert InvariantFailed();
        uint256 yOutNew = xp[j] - yOutScaledDelta;
        if (yOutNew == 0) revert InvariantFailed();
        xInNew = Math.getY(j, i, yOutNew, xp, amp, D);
    }

    function _maxViableIn(ZapWork memory z, uint256 i, uint256 j, uint256 rawSurplus)
        private
        view
        returns (uint256 maxViableIn)
    {
        uint256 outScaled = Math.scaleTo(z.workingR[j], z.rates[j]);
        uint256 leaveAmt = outScaled > 1e12 ? 1e12 : (outScaled > 1 ? 1 : 0);
        if (leaveAmt == 0 || outScaled <= leaveAmt) return 0;
        uint256 maxRawOut = Math.descale(outScaled - leaveAmt, z.rates[j]);
        if (maxRawOut == 0) return 0;
        (uint256 maxUserOut,) = Math.feeOnOutputExactIn(maxRawOut, z.fee);
        if (maxUserOut == 0) return 0;
        uint256 ideal = _closedFormInverseExactIn(z, i, j, maxUserOut);
        if (ideal == 0) return 0;
        maxViableIn = ideal < rawSurplus ? ideal : rawSurplus;
    }

    function _requirePriceable() internal view {
        uint256[4] memory r = Repo._layout().reserves;
        uint256[4] memory rates = _loadRates();
        uint256[4] memory xp;
        for (uint256 i; i < 4; ++i) {
            xp[i] = Math.scaleTo(r[i], rates[i]);
        }
        if (xp[0] == 0 || xp[1] == 0 || xp[2] == 0 || xp[3] == 0) revert InvariantFailed();
        Math.getD(xp, getCurrentAmp());
    }
}
