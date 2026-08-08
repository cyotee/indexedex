// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IFeeCollectorProxy} from "contracts/interfaces/proxies/IFeeCollectorProxy.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
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
 * @title UniswapV4SingleStandardExchangeBufferConstantProductHookDepositTarget
 * @notice Product logic only: CP hooks, liquidity, SE In/Out, product views.
 * @dev LP ERC-20, IBasicVault, IStandardVault are cut as shared facets on the diamond.
 *      LP supply/balances use ERC20Repo; vaultTokens/reserves use MultiAssetBasicVaultRepo
 *      (pair reserve accounting = virtual SE claim; raw = face inventory).
 */
abstract contract UniswapV4SingleStandardExchangeBufferConstantProductHookDepositTarget {
    using SafeERC20 for IERC20;

    event Deposit(address indexed sender, address indexed to, uint256 amount0, uint256 amount1, uint256 used0, uint256 used1, uint256 lpAmount);
    event DepositSingle(address indexed sender, address indexed to, address tokenIn, uint256 amountIn, uint256 lpAmount);
    event DepositSeShares(
        address indexed sender,
        address indexed to,
        uint256 amountRaw,
        uint256 amountSe,
        uint256 usedRaw,
        uint256 usedSe,
        uint256 lpAmount
    );
    event Withdraw(address indexed sender, address indexed to, uint256 lpAmount, uint256 amount0, uint256 amount1);
    event WithdrawSingle(address indexed sender, address indexed to, uint256 lpAmount, address tokenOut, uint256 amountOut);
    event ZapSwap(address indexed sender, address tokenIn, address tokenOut, uint256 amountIn, uint256 amountOut);


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

    function _refundPairDust(address to) internal {
        Repo.Layout storage l = Repo._layout();
        uint256 bal = IERC20(l.pairToken).balanceOf(address(this));
        if (bal > Repo.MAX_DUST_WEI) {
            IERC20(l.pairToken).safeTransfer(to, bal);
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                              swap core                                 */
    /* ---------------------------------------------------------------------- */

    function _zeroForOneIsRawIn() internal view returns (bool) {
        return Repo._layout().currency0 == Repo._layout().rawToken;
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
    function _routeZeroForOne(address tokenIn, address tokenOut) internal view returns (bool) {
        Repo.Layout storage l = Repo._layout();
        if (tokenIn == l.currency0 && tokenOut == l.currency1) return true;
        if (tokenIn == l.currency1 && tokenOut == l.currency0) return false;
        revert UnsupportedRoute();
    }

    function deposit(uint256 amount0, uint256 amount1, address to, uint256 minLpAmount, uint256 deadline)
        external
        nonReentrant
        returns (uint256 lpAmount, uint256 used0, uint256 used1)
    {
        PullLib.pullErc20Dual(currency0(), currency1(), amount0, amount1);
        return _deposit(amount0, amount1, to, minLpAmount, deadline);
    }

    function depositWithPermit2Signature(
        uint256 amount0,
        uint256 amount1,
        address to,
        uint256 minLpAmount,
        uint256 deadline,
        bytes calldata permit2Data
    ) external nonReentrant returns (uint256 lpAmount, uint256 used0, uint256 used1) {
        PullLib.pullPermit2SignatureDual(currency0(), currency1(), amount0, amount1, permit2Data);
        return _deposit(amount0, amount1, to, minLpAmount, deadline);
    }

    function depositWithPermit2Allowance(
        uint256 amount0,
        uint256 amount1,
        address to,
        uint256 minLpAmount,
        uint256 deadline
    ) external nonReentrant returns (uint256 lpAmount, uint256 used0, uint256 used1) {
        PullLib.pullPermit2AllowanceDual(currency0(), currency1(), amount0, amount1);
        return _deposit(amount0, amount1, to, minLpAmount, deadline);
    }

    function depositSingle(address tokenIn, uint256 amountIn, address to, uint256 minLpAmount, uint256 deadline)
        external
        nonReentrant
        returns (uint256 lpAmount)
    {
        PullLib.pullErc20Single(tokenIn, amountIn);
        return _depositSingle(tokenIn, amountIn, to, minLpAmount, deadline);
    }

    function depositSingleWithPermit2Signature(
        address tokenIn,
        uint256 amountIn,
        address to,
        uint256 minLpAmount,
        uint256 deadline,
        bytes calldata permit2Data
    ) external nonReentrant returns (uint256 lpAmount) {
        PullLib.pullPermit2SignatureSingle(tokenIn, amountIn, permit2Data);
        return _depositSingle(tokenIn, amountIn, to, minLpAmount, deadline);
    }

    function depositSingleWithPermit2Allowance(
        address tokenIn,
        uint256 amountIn,
        address to,
        uint256 minLpAmount,
        uint256 deadline
    ) external nonReentrant returns (uint256 lpAmount) {
        PullLib.pullPermit2AllowanceSingle(tokenIn, amountIn);
        return _depositSingle(tokenIn, amountIn, to, minLpAmount, deadline);
    }

    /// @notice B6: deposit face rawToken + SE vault shares for the buffered leg (no pair buffer).
    function depositWithSeShares(
        uint256 amountRaw,
        uint256 amountSe,
        address to,
        uint256 minLpAmount,
        uint256 deadline
    ) external nonReentrant returns (uint256 lpAmount, uint256 usedRaw, uint256 usedSe) {
        Repo.Layout storage l = Repo._layout();
        PullLib.pullErc20Single(l.rawToken, amountRaw);
        PullLib.pullErc20Single(l.standardExchange, amountSe);
        return _depositWithSeShares(amountRaw, amountSe, to, minLpAmount, deadline);
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
        _mintProtocolFeeIfNeeded();

        Repo.Layout storage l = Repo._layout();
        // Caller already pulled amount0/1. Back out pre-pull book (raw face excludes pull; seClaim ignores free pair).
        (uint256 xBefore, uint256 yBefore) = _reservesBeforeDualPull(amount0, amount1);

        if (ERC20Repo._totalSupply() == 0) {
            used0 = amount0;
            used1 = amount1;
            lpAmount = _firstMint(used0, used1, to);
        } else {
            (used0, used1) = _clampToReserveRatioFrom(xBefore, yBefore, amount0, amount1);
            if (amount0 > used0) IERC20(l.currency0).safeTransfer(msg.sender, amount0 - used0);
            if (amount1 > used1) IERC20(l.currency1).safeTransfer(msg.sender, amount1 - used1);
            _intakePoolAmounts(used0, used1);
            lpAmount = _mintFromDeltas(xBefore, yBefore, to);
        }
        if (lpAmount < minLpAmount) revert InsufficientLpOut();
        _syncReserves();
        _setKLastPostOp();
        _refundPairDust(msg.sender);
        emit Deposit(msg.sender, to, amount0, amount1, used0, used1, lpAmount);
    }

    /// @dev After dual pull of (amount0, amount1), reconstruct pre-pull effective reserves.
    function _reservesBeforeDualPull(uint256 amount0, uint256 amount1)
        internal
        view
        returns (uint256 x, uint256 y)
    {
        Repo.Layout storage l = Repo._layout();
        uint256 seClaim = _seClaim();
        uint256 rawBal = IERC20(l.rawToken).balanceOf(address(this));
        if (l.currency0 == l.rawToken) {
            x = rawBal - amount0;
            y = seClaim;
        } else {
            x = seClaim;
            y = rawBal - amount1;
        }
    }

    function _clampToReserveRatioFrom(uint256 x, uint256 y, uint256 amount0, uint256 amount1)
        internal
        pure
        returns (uint256 used0, uint256 used1)
    {
        used0 = amount0;
        used1 = amount1;
        if (x == 0 || y == 0) revert NotLive();
        uint256 ideal1 = (used0 * y) / x;
        if (ideal1 <= used1) {
            used1 = ideal1;
        } else {
            used0 = (used1 * x) / y;
        }
        if (used0 == 0 || used1 == 0) revert ZeroAmount();
    }

    function _intakePoolAmounts(uint256 used0, uint256 used1) internal {
        Repo.Layout storage l = Repo._layout();
        // Buffer pair last among intakes
        if (l.currency0 == l.pairToken) {
            // pair is currency0: hold raw (c1) already; buffer pair
            _bufferPair(used0);
        } else {
            // raw is currency0: hold raw; buffer pair (c1)
            _bufferPair(used1);
        }
    }

    function _firstMint(uint256 used0, uint256 used1, address to) internal returns (uint256 lpAmount) {
        _intakePoolAmounts(used0, used1);
        uint256 geometric = Math.mintSharesFirst(
            Math.toWad(reserveCurrency0(), Repo._layout().decimalsCurrency0),
            Math.toWad(reserveCurrency1(), Repo._layout().decimalsCurrency1)
        );
        if (geometric <= Repo.MINIMUM_LIQUIDITY) revert InsufficientLpOut();
        lpAmount = geometric - Repo.MINIMUM_LIQUIDITY;
        _mintLp(address(0), Repo.MINIMUM_LIQUIDITY);
        _mintLp(to, lpAmount);
    }

    function _clampToReserveRatio(uint256 amount0, uint256 amount1)
        internal
        view
        returns (uint256 used0, uint256 used1)
    {
        used0 = amount0;
        used1 = amount1;
        uint256 x = reserveCurrency0();
        uint256 y = reserveCurrency1();
        if (x == 0 || y == 0) revert NotLive();
        uint256 ideal1 = (used0 * y) / x;
        if (ideal1 <= used1) {
            used1 = ideal1;
        } else {
            used0 = (used1 * x) / y;
        }
        if (used0 == 0 || used1 == 0) revert ZeroAmount();
    }

    function _mintFromDeltas(uint256 xBefore, uint256 yBefore, address to)
        internal
        returns (uint256 lpAmount)
    {
        uint256 dxN = Math.toWad(reserveCurrency0() - xBefore, Repo._layout().decimalsCurrency0);
        uint256 dyN = Math.toWad(reserveCurrency1() - yBefore, Repo._layout().decimalsCurrency1);
        uint256 xN = Math.toWad(xBefore, Repo._layout().decimalsCurrency0);
        uint256 yN = Math.toWad(yBefore, Repo._layout().decimalsCurrency1);
        lpAmount = Math.mintSharesLater(dxN, dyN, xN, yN, ERC20Repo._totalSupply());
        if (lpAmount == 0) revert InsufficientLpOut();
        _mintLp(to, lpAmount);
    }

    /// @dev B6 proportional deposit: raw face + SE shares; book uses claim of SE shares (anti-skew).
    function _depositWithSeShares(
        uint256 amountRaw,
        uint256 amountSe,
        address to,
        uint256 minLpAmount,
        uint256 deadline
    ) internal returns (uint256 lpAmount, uint256 usedRaw, uint256 usedSe) {
        _requireDeadline(deadline);
        _requireNonZero(amountRaw);
        _requireNonZero(amountSe);
        _mintProtocolFeeIfNeeded();

        if (ERC20Repo._totalSupply() == 0) {
            usedRaw = amountRaw;
            usedSe = amountSe;
            lpAmount = _firstMintSeShares(to);
        } else {
            (lpAmount, usedRaw, usedSe) = _laterMintSeShares(amountRaw, amountSe, to);
        }

        if (lpAmount < minLpAmount) revert InsufficientLpOut();
        _syncReserves();
        _setKLastPostOp();
        _refundPairDust(msg.sender);
        emit DepositSeShares(msg.sender, to, amountRaw, amountSe, usedRaw, usedSe, lpAmount);
    }

    function _firstMintSeShares(address to) internal returns (uint256 lpAmount) {
        // Inventory already on hook (pulled SE + raw); no buffer.
        Repo.Layout storage l = Repo._layout();
        uint256 geometric = Math.mintSharesFirst(
            Math.toWad(reserveCurrency0(), l.decimalsCurrency0),
            Math.toWad(reserveCurrency1(), l.decimalsCurrency1)
        );
        if (geometric <= Repo.MINIMUM_LIQUIDITY) revert InsufficientLpOut();
        lpAmount = geometric - Repo.MINIMUM_LIQUIDITY;
        _mintLp(address(0), Repo.MINIMUM_LIQUIDITY);
        _mintLp(to, lpAmount);
    }

    function _laterMintSeShares(uint256 amountRaw, uint256 amountSe, address to)
        internal
        returns (uint256 lpAmount, uint256 usedRaw, uint256 usedSe)
    {
        (uint256 rawBefore, uint256 seClaimBefore, uint256 claimOffered) =
            _seDepositPrePullBook(amountRaw, amountSe);
        if (rawBefore == 0 || seClaimBefore == 0) revert NotLive();
        if (claimOffered == 0) revert ZeroAmount();

        uint256 usedClaim;
        (usedRaw, usedClaim) =
            _clampToReserveRatioFrom(rawBefore, seClaimBefore, amountRaw, claimOffered);
        // Linear in SE unwrap claim for ERC-4626-style SE (claim of subset of shares).
        usedSe = (amountSe * usedClaim) / claimOffered;
        if (usedSe == 0 || usedRaw == 0) revert ZeroAmount();

        _refundSeDepositExcess(amountRaw, amountSe, usedRaw, usedSe);
        lpAmount = _mintFromDeltas(_poolOrderX(rawBefore, seClaimBefore), _poolOrderY(rawBefore, seClaimBefore), to);
    }

    function _seDepositPrePullBook(uint256 amountRaw, uint256 amountSe)
        internal
        view
        returns (uint256 rawBefore, uint256 seClaimBefore, uint256 claimOffered)
    {
        Repo.Layout storage l = Repo._layout();
        uint256 seBalAfter = IERC20(l.standardExchange).balanceOf(address(this));
        if (seBalAfter < amountSe) revert ZeroAmount();
        rawBefore = IERC20(l.rawToken).balanceOf(address(this)) - amountRaw;
        seClaimBefore = _previewSeClaimOfBal(seBalAfter - amountSe);
        claimOffered = _previewSeClaimOfBal(amountSe);
    }

    function _refundSeDepositExcess(
        uint256 amountRaw,
        uint256 amountSe,
        uint256 usedRaw,
        uint256 usedSe
    ) internal {
        Repo.Layout storage l = Repo._layout();
        if (amountRaw > usedRaw) {
            IERC20(l.rawToken).safeTransfer(msg.sender, amountRaw - usedRaw);
        }
        if (amountSe > usedSe) {
            IERC20(l.standardExchange).safeTransfer(msg.sender, amountSe - usedSe);
        }
    }

    function _poolOrderX(uint256 rawAmt, uint256 seClaimAmt) internal view returns (uint256) {
        return Repo._layout().currency0 == Repo._layout().rawToken ? rawAmt : seClaimAmt;
    }

    function _poolOrderY(uint256 rawAmt, uint256 seClaimAmt) internal view returns (uint256) {
        return Repo._layout().currency0 == Repo._layout().rawToken ? seClaimAmt : rawAmt;
    }

    function _previewSeClaimOfBal(uint256 seBal) internal view returns (uint256) {
        if (seBal == 0) return 0;
        Repo.Layout storage l = Repo._layout();
        return IStandardExchangeIn(l.standardExchange).previewExchangeIn(
            IERC20(l.standardExchange), seBal, IERC20(l.pairToken)
        );
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
        Repo.Layout storage l = Repo._layout();
        if (tokenIn != l.rawToken && tokenIn != l.pairToken) revert InvalidToken();
        _requireZapEligible();
        _mintProtocolFeeIfNeeded();

        (uint256 saleAmt, uint256 amountOtherOut, address tokenOut) = _executeZapInSwap(tokenIn, amountIn);
        uint256 keptIn = amountIn - saleAmt;
        lpAmount = _proportionalAddAfterZap(tokenIn, tokenOut, keptIn, amountOtherOut, to);
        if (lpAmount < minLpAmount) revert InsufficientLpOut();
        _syncReserves();
        _setKLastPostOp();
        _refundPairDust(msg.sender);
        emit DepositSingle(msg.sender, to, tokenIn, amountIn, lpAmount);
    }

    function _executeZapInSwap(address tokenIn, uint256 amountIn)
        internal
        returns (uint256 saleAmt, uint256 amountOtherOut, address tokenOut)
    {
        Repo.Layout storage l = Repo._layout();
        tokenOut = tokenIn == l.rawToken ? l.pairToken : l.rawToken;
        bool zfo = _routeZeroForOne(tokenIn, tokenOut);

        // Pre-pull reserves (caller already pulled amountIn).
        if (tokenIn == l.rawToken) {
            uint256 rawBefore = IERC20(l.rawToken).balanceOf(address(this)) - amountIn;
            uint256 rInN = Math.toWad(rawBefore, _decimalsOf(l.rawToken));
            saleAmt = Math.fromWadFloor(
                Math.swapDepositSaleAmt(Math.toWad(amountIn, _decimalsOf(l.rawToken)), rInN),
                _decimalsOf(l.rawToken)
            );
        } else {
            uint256 claimInFull = _previewBufferClaimIn(amountIn);
            uint256 rInN = Math.toWad(_seClaim(), _decimalsOf(l.pairToken));
            uint256 saleClaimN = Math.swapDepositSaleAmt(
                Math.toWad(claimInFull, _decimalsOf(l.pairToken)), rInN
            );
            if (claimInFull == 0) {
                saleAmt = amountIn / 2;
            } else {
                saleAmt = (amountIn * Math.fromWadFloor(saleClaimN, _decimalsOf(l.pairToken))) / claimInFull;
            }
        }
        if (saleAmt > amountIn) saleAmt = amountIn;
        if (saleAmt == 0) saleAmt = amountIn / 2;

        // Quote on pre-buffer book with pulled inventory (raw-in includes amountIn for face quote).
        amountOtherOut = _quoteExactInZap(zfo, saleAmt, tokenIn, amountIn);
        if (amountOtherOut == 0) revert InsufficientTokenOut();

        if (tokenIn == l.pairToken) {
            _bufferPair(saleAmt);
        } else {
            _unwrapExactPairOut(amountOtherOut);
        }
        emit ZapSwap(msg.sender, tokenIn, tokenOut, saleAmt, amountOtherOut);
    }

    /// @dev Zap exact-in quote treating just-pulled tokenIn inventory carefully.
    function _quoteExactInZap(bool zeroForOne, uint256 amountIn, address tokenIn, uint256 pulledIn)
        internal
        view
        returns (uint256 amountOut)
    {
        Repo.Layout storage l = Repo._layout();
        bool rawIn = zeroForOne == _zeroForOneIsRawIn();
        uint256 rawBal = IERC20(l.rawToken).balanceOf(address(this));
        uint256 seClaim = _seClaim();
        // Exclude unused pull residual from sale-side reserve for raw-in book.
        if (tokenIn == l.rawToken && rawIn) {
            // full pull is on hook; reserve for CP is pre-pull + we sell saleAmt of the pull
            rawBal = rawBal - pulledIn; // pre-pull raw reserve
        }
        if (rawIn) {
            uint256 rInN = Math.toWad(rawBal, _decimalsOf(l.rawToken));
            uint256 rOutN = Math.toWad(seClaim, _decimalsOf(l.pairToken));
            uint256 aInN = Math.toWad(amountIn, _decimalsOf(l.rawToken));
            amountOut = Math.fromWadFloor(Math.saleQuote(aInN, rInN, rOutN), _decimalsOf(l.pairToken));
        } else {
            uint256 claimIn = _previewBufferClaimIn(amountIn);
            uint256 rInN = Math.toWad(seClaim, _decimalsOf(l.pairToken));
            uint256 rOutN = Math.toWad(rawBal, _decimalsOf(l.rawToken));
            uint256 cInN = Math.toWad(claimIn, _decimalsOf(l.pairToken));
            amountOut = Math.fromWadFloor(Math.saleQuote(cInN, rInN, rOutN), _decimalsOf(l.rawToken));
        }
    }

    function _proportionalAddAfterZap(
        address tokenIn,
        address tokenOut,
        uint256 keptIn,
        uint256 amountOtherOut,
        address to
    ) internal returns (uint256 lpAmount) {
        Repo.Layout storage l = Repo._layout();
        uint256 add0;
        uint256 add1;
        if (tokenIn == l.currency0) {
            add0 = keptIn;
            add1 = amountOtherOut;
        } else {
            add0 = amountOtherOut;
            add1 = keptIn;
        }
        // Book after zap swap already reflects inventory; measure before proportional intake.
        uint256 xBefore = reserveCurrency0();
        uint256 yBefore = reserveCurrency1();
        // Back out free pair / raw still sitting as add legs before buffer.
        if (l.currency0 == l.rawToken) {
            // raw leg on hook as free raw; pair leg may be free pair from swap out or kept pair
            if (tokenIn == l.rawToken) {
                xBefore = IERC20(l.rawToken).balanceOf(address(this)) - add0;
                // pair out from swap is free pair not yet in seClaim
                yBefore = _seClaim();
            } else {
                // tokenIn pair: kept pair free; otherOut raw already in raw bal
                xBefore = IERC20(l.rawToken).balanceOf(address(this)) - add1;
                yBefore = _seClaim();
            }
        } else {
            if (tokenIn == l.rawToken) {
                yBefore = IERC20(l.rawToken).balanceOf(address(this)) - add0;
                xBefore = _seClaim();
            } else {
                yBefore = IERC20(l.rawToken).balanceOf(address(this)) - add1;
                xBefore = _seClaim();
            }
        }

        (uint256 used0, uint256 used1) = _clampToReserveRatioFrom(xBefore, yBefore, add0, add1);
        if (add0 > used0) IERC20(l.currency0).safeTransfer(msg.sender, add0 - used0);
        if (add1 > used1) IERC20(l.currency1).safeTransfer(msg.sender, add1 - used1);

        _intakePoolAmounts(used0, used1);
        lpAmount = _mintFromDeltas(xBefore, yBefore, to);
        tokenOut;
    }

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
    function previewDeposit(uint256 amount0, uint256 amount1)
        external
        view
        returns (uint256 lpAmount, uint256 used0, uint256 used1)
    {
        _requireNonZero(amount0);
        _requireNonZero(amount1);
        if (ERC20Repo._totalSupply() == 0) {
            used0 = amount0;
            used1 = amount1;
            uint256 geometric = Math.mintSharesFirst(
                Math.toWad(_previewReserveAfterIntake(true, used0, used1), Repo._layout().decimalsCurrency0),
                Math.toWad(_previewReserveAfterIntake(false, used0, used1), Repo._layout().decimalsCurrency1)
            );
            if (geometric <= Repo.MINIMUM_LIQUIDITY) return (0, used0, used1);
            return (geometric - Repo.MINIMUM_LIQUIDITY, used0, used1);
        }
        (used0, used1) = _clampToReserveRatio(amount0, amount1);
        uint256 x = reserveCurrency0();
        uint256 y = reserveCurrency1();
        uint256 dx = _previewDelta0(used0, used1);
        uint256 dy = _previewDelta1(used0, used1);
        lpAmount = Math.mintSharesLater(
            Math.toWad(dx, Repo._layout().decimalsCurrency0),
            Math.toWad(dy, Repo._layout().decimalsCurrency1),
            Math.toWad(x, Repo._layout().decimalsCurrency0),
            Math.toWad(y, Repo._layout().decimalsCurrency1),
            _supplyAfterProtocolMint()
        );
    }

    function _previewReserveAfterIntake(bool forC0, uint256 used0, uint256 used1)
        internal
        view
        returns (uint256)
    {
        Repo.Layout storage l = Repo._layout();
        if (forC0) {
            if (l.currency0 == l.rawToken) return used0;
            return _previewBufferClaimIn(used0);
        } else {
            if (l.currency1 == l.rawToken) return used1;
            return _previewBufferClaimIn(used1);
        }
    }

    function _previewDelta0(uint256 used0, uint256) internal view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        if (l.currency0 == l.rawToken) return used0;
        return _previewBufferClaimIn(used0);
    }

    function _previewDelta1(uint256, uint256 used1) internal view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        if (l.currency1 == l.rawToken) return used1;
        return _previewBufferClaimIn(used1);
    }

    function previewDepositSingle(address tokenIn, uint256 amountIn)
        external
        view
        returns (uint256 lpAmount)
    {
        (uint256 saleAmt, uint256 otherOut, uint256 kept) = _previewZapSplit(tokenIn, amountIn);
        Repo.Layout storage l = Repo._layout();
        uint256 add0 = tokenIn == l.currency0 ? kept : otherOut;
        uint256 add1 = tokenIn == l.currency0 ? otherOut : kept;
        (uint256 used0, uint256 used1) = _clampToReserveRatio(add0, add1);
        uint256 x = reserveCurrency0();
        uint256 y = reserveCurrency1();
        lpAmount = Math.mintSharesLater(
            Math.toWad(_previewDelta0(used0, used1), l.decimalsCurrency0),
            Math.toWad(_previewDelta1(used0, used1), l.decimalsCurrency1),
            Math.toWad(x, l.decimalsCurrency0),
            Math.toWad(y, l.decimalsCurrency1),
            _supplyAfterProtocolMint()
        );
        saleAmt;
    }

    function previewZapSplit(address tokenIn, uint256 amountIn)
        external
        view
        returns (uint256 amountToSwap, uint256 amountOtherOut, uint256 amountKeptIn)
    {
        return _previewZapSplit(tokenIn, amountIn);
    }

    /// @notice B6 preview: raw + SE shares proportional deposit (no buffer fee path).
    function previewDepositWithSeShares(uint256 amountRaw, uint256 amountSe)
        external
        view
        returns (uint256 lpAmount, uint256 usedRaw, uint256 usedSe)
    {
        _requireNonZero(amountRaw);
        _requireNonZero(amountSe);
        uint256 claimOffered = _previewSeClaimOfBal(amountSe);
        if (claimOffered == 0) return (0, 0, 0);

        if (ERC20Repo._totalSupply() == 0) {
            usedRaw = amountRaw;
            usedSe = amountSe;
            lpAmount = _previewFirstMintSeShares(usedRaw, claimOffered);
            return (lpAmount, usedRaw, usedSe);
        }

        return _previewLaterMintSeShares(amountRaw, amountSe, claimOffered);
    }

    function _previewFirstMintSeShares(uint256 usedRaw, uint256 claimOffered)
        internal
        view
        returns (uint256 lpAmount)
    {
        Repo.Layout storage l = Repo._layout();
        uint256 r0 = _poolOrderX(usedRaw, claimOffered);
        uint256 r1 = _poolOrderY(usedRaw, claimOffered);
        uint256 geometric =
            Math.mintSharesFirst(Math.toWad(r0, l.decimalsCurrency0), Math.toWad(r1, l.decimalsCurrency1));
        if (geometric <= Repo.MINIMUM_LIQUIDITY) return 0;
        return geometric - Repo.MINIMUM_LIQUIDITY;
    }

    function _previewLaterMintSeShares(uint256 amountRaw, uint256 amountSe, uint256 claimOffered)
        internal
        view
        returns (uint256 lpAmount, uint256 usedRaw, uint256 usedSe)
    {
        Repo.Layout storage l = Repo._layout();
        uint256 rawBal = IERC20(l.rawToken).balanceOf(address(this));
        uint256 seClaim = _seClaim();
        if (rawBal == 0 || seClaim == 0) revert NotLive();
        uint256 usedClaim;
        (usedRaw, usedClaim) = _clampToReserveRatioFrom(rawBal, seClaim, amountRaw, claimOffered);
        usedSe = (amountSe * usedClaim) / claimOffered;
        if (usedSe == 0 || usedRaw == 0) return (0, usedRaw, usedSe);

        uint256 dx = _poolOrderX(usedRaw, usedClaim);
        uint256 dy = _poolOrderY(usedRaw, usedClaim);
        lpAmount = Math.mintSharesLater(
            Math.toWad(dx, l.decimalsCurrency0),
            Math.toWad(dy, l.decimalsCurrency1),
            Math.toWad(reserveCurrency0(), l.decimalsCurrency0),
            Math.toWad(reserveCurrency1(), l.decimalsCurrency1),
            _supplyAfterProtocolMint()
        );
    }

    function _previewZapSplit(address tokenIn, uint256 amountIn)
        internal
        view
        returns (uint256 saleAmt, uint256 amountOtherOut, uint256 keptIn)
    {
        Repo.Layout storage l = Repo._layout();
        address tokenOut = tokenIn == l.rawToken ? l.pairToken : l.rawToken;
        bool zfo = _routeZeroForOne(tokenIn, tokenOut);
        if (tokenIn == l.rawToken) {
            uint256 rInN = Math.toWad(IERC20(l.rawToken).balanceOf(address(this)), _decimalsOf(l.rawToken));
            saleAmt = Math.fromWadFloor(
                Math.swapDepositSaleAmt(Math.toWad(amountIn, _decimalsOf(l.rawToken)), rInN),
                _decimalsOf(l.rawToken)
            );
        } else {
            uint256 claimInFull = _previewBufferClaimIn(amountIn);
            uint256 rInN = Math.toWad(_seClaim(), _decimalsOf(l.pairToken));
            uint256 saleClaim =
                Math.fromWadFloor(
                    Math.swapDepositSaleAmt(Math.toWad(claimInFull, _decimalsOf(l.pairToken)), rInN),
                    _decimalsOf(l.pairToken)
                );
            saleAmt = claimInFull == 0 ? amountIn / 2 : (amountIn * saleClaim) / claimInFull;
        }
        if (saleAmt > amountIn) saleAmt = amountIn;
        if (saleAmt == 0) saleAmt = amountIn / 2;
        amountOtherOut = _quoteExactIn(zfo, saleAmt);
        keptIn = amountIn - saleAmt;
    }

}
