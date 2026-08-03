// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
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
import {ModifyLiquidityParams, SwapParams} from
    "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {BalanceDelta} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {
    UniswapV4DualStandardExchangeBufferConstantProductHookCommon
} from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookCommon.sol";
import {
    UniswapV4DualStandardExchangeBufferConstantProductHookPullLib as PullLib
} from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookPullLib.sol";
import {
    UniswapV4DualStandardExchangeBufferConstantProductHookRepo as Repo
} from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookRepo.sol";
import {
    UniswapV4DualStandardExchangeBufferConstantProductHookMath as Math
} from "contracts/hooks/uniswap/v4/standardExchange/dual/UniswapV4DualStandardExchangeBufferConstantProductHookMath.sol";
import {
    IUniswapV4DualStandardExchangeBufferConstantProductHook as IHook
} from "contracts/hooks/uniswap/v4/standardExchange/dual/interfaces/IUniswapV4DualStandardExchangeBufferConstantProductHook.sol";

/**
 * @title UniswapV4DualStandardExchangeBufferConstantProductHookTarget
 * @notice IHooks + deposit/withdraw/zap/swap orchestration per PRD v3.12.
 */
abstract contract UniswapV4DualStandardExchangeBufferConstantProductHookTarget is
    UniswapV4DualStandardExchangeBufferConstantProductHookCommon,
    IHooks
{
    using SafeERC20 for IERC20;

    constructor(
        IPoolManager poolManager_,
        IVaultFeeOracleQuery feeOracle_,
        address se0_,
        address token0_,
        address se1_,
        address token1_
    )
        UniswapV4DualStandardExchangeBufferConstantProductHookCommon(
            poolManager_, feeOracle_, se0_, token0_, se1_, token1_
        )
    {}

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

    /* ---------------------------------------------------------------------- */
    /*                                  IHooks                                */
    /* ---------------------------------------------------------------------- */

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
        if (!(a == _currency0 && b == _currency1)) revert InvalidPoolToken();
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
            swapDelta = _swapExactIn(params.zeroForOne, uint256(-params.amountSpecified));
        } else {
            swapDelta = _swapExactOut(params.zeroForOne, uint256(params.amountSpecified));
        }
        return (IHooks.beforeSwap.selector, swapDelta, 0);
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
        tokenIn = zeroForOne ? _currency0 : _currency1;
        tokenOut = zeroForOne ? _currency1 : _currency0;
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
    /*                         deposit / withdraw                             */
    /* ---------------------------------------------------------------------- */

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

        if (Repo._layout().totalSupply == 0) {
            used0 = amount0;
            used1 = amount1;
            lpAmount = _firstMint(used0, used1, to);
        } else {
            (used0, used1) = _clampToClaimRatio(amount0, amount1);
            if (amount0 > used0) IERC20(_currency0).safeTransfer(msg.sender, amount0 - used0);
            if (amount1 > used1) IERC20(_currency1).safeTransfer(msg.sender, amount1 - used1);
            uint256 xBefore = claimSupplyCurrency0();
            uint256 yBefore = claimSupplyCurrency1();
            _buffer(_seFor(_currency0), _currency0, used0);
            _buffer(_seFor(_currency1), _currency1, used1);
            lpAmount = _mintFromClaimDeltas(xBefore, yBefore, to);
        }

        if (lpAmount < minLpAmount) revert InsufficientLpOut();
        _setKLastPostOp();
        _refundBothPairDust(msg.sender);
        emit IHook.Deposit(msg.sender, to, used0, used1, lpAmount);
    }

    function _firstMint(uint256 used0, uint256 used1, address to)
        internal
        returns (uint256 lpAmount)
    {
        _buffer(_seFor(_currency0), _currency0, used0);
        _buffer(_seFor(_currency1), _currency1, used1);
        uint256 geometric = Math.mintSharesFirst(
            Math.toWad(claimSupplyCurrency0(), _decimalsCurrency0()),
            Math.toWad(claimSupplyCurrency1(), _decimalsCurrency1())
        );
        if (geometric <= Repo.MINIMUM_LIQUIDITY) revert InsufficientLpOut();
        lpAmount = geometric - Repo.MINIMUM_LIQUIDITY;
        _mint(address(0), Repo.MINIMUM_LIQUIDITY);
        _mint(to, lpAmount);
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
        emit IHook.DepositSingle(msg.sender, to, tokenIn, amountIn, lpAmount);
    }

    function _executeZapSwap(address tokenIn, uint256 amountIn)
        internal
        returns (uint256 saleAmt, uint256 amountOtherOut)
    {
        address tokenOut = tokenIn == _currency0 ? _currency1 : _currency0;
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
        uint256 add0 = tokenIn == _currency0 ? keptIn : amountOtherOut;
        uint256 add1 = tokenIn == _currency0 ? amountOtherOut : keptIn;
        (uint256 used0, uint256 used1) = _clampToClaimRatio(add0, add1);
        if (add0 > used0) IERC20(_currency0).safeTransfer(msg.sender, add0 - used0);
        if (add1 > used1) IERC20(_currency1).safeTransfer(msg.sender, add1 - used1);

        uint256 xBefore = claimSupplyCurrency0();
        uint256 yBefore = claimSupplyCurrency1();
        _buffer(_seFor(_currency0), _currency0, used0);
        _buffer(_seFor(_currency1), _currency1, used1);
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
        lpAmount = Math.mintSharesLater(dxN, dyN, xN, yN, Repo._layout().totalSupply);
        if (lpAmount == 0) revert InsufficientLpOut();
        _mint(to, lpAmount);
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

        Repo.Layout storage l = Repo._layout();
        uint256 supply = l.totalSupply;
        if (lpAmount > l.balanceOf[msg.sender]) revert InsufficientLpOut();

        uint256 seBal0 = IERC20(_seFor(_currency0)).balanceOf(address(this));
        uint256 seBal1 = IERC20(_seFor(_currency1)).balanceOf(address(this));
        uint256 seOut0 = (seBal0 * lpAmount) / supply;
        uint256 seOut1 = (seBal1 * lpAmount) / supply;

        _burn(msg.sender, lpAmount);

        if (seOut0 > 0) {
            amount0 = _unwrap(_seFor(_currency0), _currency0, seOut0);
            IERC20(_currency0).safeTransfer(to, amount0);
        }
        if (seOut1 > 0) {
            amount1 = _unwrap(_seFor(_currency1), _currency1, seOut1);
            IERC20(_currency1).safeTransfer(to, amount1);
        }

        if (amount0 < minAmount0 || amount1 < minAmount1) revert InsufficientTokenOut();
        _setKLastPostOp();
        _refundBothPairDust(msg.sender);
        emit IHook.Withdraw(msg.sender, to, lpAmount, amount0, amount1);
    }

    /* ---------------------------------------------------------------------- */
    /*                              D57 protocol fee                          */
    /* ---------------------------------------------------------------------- */

    /// @param measurePreBuffer true for deposit paths (D72); false for withdraw (use current k).
    function _mintProtocolFeeIfNeeded(bool measurePreBuffer) internal {
        measurePreBuffer; // k is always pre-buffer when called before buffer; withdraw before burn
        (bool feeOn, address feeTo_, uint256 ownerFeeShare) = _feeOnAndShare();
        Repo.Layout storage l = Repo._layout();
        if (!feeOn) {
            l.kLast = 0;
            return;
        }
        uint256 kLast_ = l.kLast;
        if (kLast_ == 0) return;
        uint256 currentK = _wadProduct();
        uint256 protocolLp = Math.calculateProtocolFee(l.totalSupply, currentK, kLast_, ownerFeeShare);
        if (protocolLp > 0) {
            _mint(feeTo_, protocolLp);
        }
    }

    function _setKLastPostOp() internal {
        (bool feeOn,,) = _feeOnAndShare();
        Repo.Layout storage l = Repo._layout();
        l.kLast = feeOn ? _wadProduct() : 0;
    }

    /* ---------------------------------------------------------------------- */
    /*                              previews                                  */
    /* ---------------------------------------------------------------------- */

    function _supplyAfterProtocolMint() internal view returns (uint256 supplyAdj) {
        supplyAdj = Repo._layout().totalSupply;
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
        if (Repo._layout().totalSupply == 0) {
            used0 = amount0;
            used1 = amount1;
            lpAmount = _previewFirstMintLp(used0, used1);
            return (lpAmount, used0, used1);
        }
        (used0, used1) = _clampToClaimRatio(amount0, amount1);
        lpAmount = _previewSubsequentLp(used0, used1, _supplyAfterProtocolMint());
    }

    function _previewFirstMintLp(uint256 used0, uint256 used1) internal view returns (uint256) {
        uint256 geometric = Math.mintSharesFirst(
            Math.toWad(
                _previewBufferClaimIn(_seFor(_currency0), _currency0, used0), _decimalsCurrency0()
            ),
            Math.toWad(
                _previewBufferClaimIn(_seFor(_currency1), _currency1, used1), _decimalsCurrency1()
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
        uint256 x = claimSupplyCurrency0();
        uint256 y = claimSupplyCurrency1();
        return Math.mintSharesLater(
            Math.toWad(
                _previewBufferClaimIn(_seFor(_currency0), _currency0, used0), _decimalsCurrency0()
            ),
            Math.toWad(
                _previewBufferClaimIn(_seFor(_currency1), _currency1, used1), _decimalsCurrency1()
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
        address seIn = _seFor(tokenIn);
        amountToSwap = _computeSaleAmt(tokenIn, amountIn, seIn);
        address tokenOut = tokenIn == _currency0 ? _currency1 : _currency0;
        amountOtherOut =
            _quoteExactInAmountOut(tokenIn, tokenOut, seIn, _seFor(tokenOut), amountToSwap);
        amountKeptIn = amountIn - amountToSwap;
    }

    function _previewDepositSingle(address tokenIn, uint256 amountIn)
        internal
        view
        returns (uint256 lpAmount)
    {
        (uint256 amountToSwap, uint256 amountOtherOut, uint256 amountKeptIn) =
            _previewZapSplit(tokenIn, amountIn);

        address seIn = _seFor(tokenIn);
        address tokenOut = tokenIn == _currency0 ? _currency1 : _currency0;
        uint256 claimInDelta = _previewBufferClaimIn(seIn, tokenIn, amountToSwap);

        // Post internal-swap claims (exit unwrap fee-less ⇒ claim out ↓ by amountOtherOut).
        uint256 x = claimSupplyCurrency0();
        uint256 y = claimSupplyCurrency1();
        if (tokenIn == _currency0) {
            x += claimInDelta;
            y = y > amountOtherOut ? y - amountOtherOut : 0;
        } else {
            y += claimInDelta;
            x = x > amountOtherOut ? x - amountOtherOut : 0;
        }
        if (x == 0 || y == 0) return 0;

        uint256 add0 = tokenIn == _currency0 ? amountKeptIn : amountOtherOut;
        uint256 add1 = tokenIn == _currency0 ? amountOtherOut : amountKeptIn;
        uint256 used0 = add0;
        uint256 used1 = add1;
        uint256 ideal1 = (used0 * y) / x;
        if (ideal1 <= used1) used1 = ideal1;
        else used0 = (used1 * x) / y;
        if (used0 == 0 || used1 == 0) return 0;

        // Claim deltas for the proportional add buffers against post-swap book.
        uint256 dx = _previewBufferClaimIn(_seFor(_currency0), _currency0, used0);
        uint256 dy = _previewBufferClaimIn(_seFor(_currency1), _currency1, used1);
        lpAmount = Math.mintSharesLater(
            Math.toWad(dx, _decimalsCurrency0()),
            Math.toWad(dy, _decimalsCurrency1()),
            Math.toWad(x, _decimalsCurrency0()),
            Math.toWad(y, _decimalsCurrency1()),
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
        address se0 = _seFor(_currency0);
        address se1 = _seFor(_currency1);
        uint256 seOut0 = (IERC20(se0).balanceOf(address(this)) * lpAmount) / supplyAdj;
        uint256 seOut1 = (IERC20(se1).balanceOf(address(this)) * lpAmount) / supplyAdj;
        if (seOut0 > 0) {
            amount0 = IStandardExchangeIn(se0).previewExchangeIn(
                IERC20(se0), seOut0, IERC20(_currency0)
            );
        }
        if (seOut1 > 0) {
            amount1 = IStandardExchangeIn(se1).previewExchangeIn(
                IERC20(se1), seOut1, IERC20(_currency1)
            );
        }
    }

    function _previewSwapExactIn(bool zeroForOne, uint256 amountIn)
        internal
        view
        returns (uint256 amountOut)
    {
        _requireNonZero(amountIn);
        _requireLive();
        address tokenIn = zeroForOne ? _currency0 : _currency1;
        address tokenOut = zeroForOne ? _currency1 : _currency0;
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
        address tokenIn = zeroForOne ? _currency0 : _currency1;
        address tokenOut = zeroForOne ? _currency1 : _currency0;
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

    /* ---------------------------------------------------------------------- */
    /*                           ERC-20 internals                             */
    /* ---------------------------------------------------------------------- */

    function _mint(address to, uint256 amount) internal {
        Repo.Layout storage l = Repo._layout();
        l.totalSupply += amount;
        l.balanceOf[to] += amount;
    }

    function _burn(address from, uint256 amount) internal {
        Repo.Layout storage l = Repo._layout();
        l.balanceOf[from] -= amount;
        l.totalSupply -= amount;
    }

    /* ---------------------------------------------------------------------- */
    /*                              Permit2 pulls                             */
    /* ---------------------------------------------------------------------- */

    function _pullPermit2SignatureDual(
        uint256 amount0,
        uint256 amount1,
        bytes calldata permit2Data
    ) internal {
        PullLib.pullPermit2SignatureDual(_currency0, _currency1, amount0, amount1, permit2Data);
    }

    function _pullPermit2SignatureSingle(
        address tokenIn,
        uint256 amountIn,
        bytes calldata permit2Data
    ) internal {
        PullLib.pullPermit2SignatureSingle(tokenIn, amountIn, permit2Data);
    }

    function _pullPermit2AllowanceDual(uint256 amount0, uint256 amount1) internal {
        PullLib.pullPermit2AllowanceDual(_currency0, _currency1, amount0, amount1);
    }

    function _pullPermit2AllowanceSingle(address tokenIn, uint256 amountIn) internal {
        PullLib.pullPermit2AllowanceSingle(tokenIn, amountIn);
    }

    function _pullErc20Dual(uint256 amount0, uint256 amount1) internal {
        PullLib.pullErc20Dual(_currency0, _currency1, amount0, amount1);
    }

    function _pullErc20Single(address tokenIn, uint256 amountIn) internal {
        PullLib.pullErc20Single(tokenIn, amountIn);
    }
}
