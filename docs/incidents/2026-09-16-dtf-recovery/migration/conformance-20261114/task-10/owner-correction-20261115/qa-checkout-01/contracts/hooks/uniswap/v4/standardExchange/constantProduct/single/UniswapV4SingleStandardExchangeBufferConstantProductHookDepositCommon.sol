// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV4SingleStandardExchangeBufferConstantProductHookInQuoteBase} from "./UniswapV4SingleStandardExchangeBufferConstantProductHookInQuoteBase.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IFeeCollectorProxy} from "contracts/interfaces/proxies/IFeeCollectorProxy.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";

import {
    UniswapV4HookOwnerOnlyLiquidityLib
} from "contracts/hooks/uniswap/v4/libs/UniswapV4HookOwnerOnlyLiquidityLib.sol";
import {MultiStepOwnableRepo} from "@crane/contracts/access/ERC8023/MultiStepOwnableRepo.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHookRepo as Repo
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookRepo.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHookMath as Math
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookMath.sol";
import {
    UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib as ClaimLib
} from "contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol";
import {UniswapV4SeBufferHookLegLib} from "contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol";

/**
 * @title UniswapV4SingleStandardExchangeBufferConstantProductHookDepositCommon
 * @notice Internal-only CP deposit helpers shared by execution and preview targets.
 * @dev LP ERC-20, IBasicVault, IStandardVault are cut as shared facets on the diamond.
 *      LP supply/balances use ERC20Repo; vaultTokens/reserves use MultiAssetBasicVaultRepo
 *      (pair reserve accounting = virtual SE claim; raw = face inventory).
 */
abstract contract UniswapV4SingleStandardExchangeBufferConstantProductHookDepositCommon is UniswapV4SingleStandardExchangeBufferConstantProductHookInQuoteBase {
    using SafeERC20 for IERC20;

    event Deposit(
        address indexed sender,
        address indexed to,
        uint256 amount0,
        uint256 amount1,
        uint256 used0,
        uint256 used1,
        uint256 lpAmount
    );
    event DepositSingle(
        address indexed sender, address indexed to, address tokenIn, uint256 amountIn, uint256 lpAmount
    );
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
    event WithdrawSingle(
        address indexed sender, address indexed to, uint256 lpAmount, address tokenOut, uint256 amountOut
    );
    /// @dev A buffered counter-leg amount is the pair-unit value of the purchased
    /// native share/local basket, not a promise to liquidate that basket.
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
    error InvalidRoute();
    error PairAndShareSameLeg();
    error FirstJoinMustBeFullBook();

    modifier nonReentrant() {
        Repo.Layout storage l = Repo._layout();
        if (l.reentrancyStatus == Repo.ENTERED) revert Reentrancy();
        l.reentrancyStatus = Repo.ENTERED;
        _;
        l.reentrancyStatus = Repo.NOT_ENTERED;
    }

    /// @dev Accrue reserve growth before liquidity transfers or SE conversion change inventory.

    modifier onlyLiquidityOwner() {
        UniswapV4HookOwnerOnlyLiquidityLib.enforce(Repo._layout().ownerOnlyLiquidity);
        _;
    }

    /* ---------------------------------------------------------------------- */
    /*                              bindings / views                          */
    /* ---------------------------------------------------------------------- */

    function poolManager() internal view returns (address) {
        return Repo._layout().poolManager;
    }

    function feeOracle() internal view returns (address) {
        return Repo._layout().feeOracle;
    }

    function permit2() internal pure returns (address) {
        return PERMIT2;
    }

    function standardExchange() internal view returns (address) {
        return Repo._layout().standardExchange;
    }

    function pairToken() internal view returns (address) {
        return Repo._layout().pairToken;
    }

    function rawToken() internal view returns (address) {
        return Repo._layout().rawToken;
    }

    function currency0() internal view returns (address) {
        return Repo._layout().currency0;
    }

    function currency1() internal view returns (address) {
        return Repo._layout().currency1;
    }

    function rawReserve() internal view returns (uint256) {
        return Repo._layout().bookedRaw;
    }

    function seClaimSupply() internal view returns (uint256) {
        return _seClaim();
    }

    function reserveCurrency0() internal view returns (uint256) {
        return _reserveOfCurrency(Repo._layout().currency0);
    }

    function reserveCurrency1() internal view returns (uint256) {
        return _reserveOfCurrency(Repo._layout().currency1);
    }

    function isLive() internal view returns (bool) {
        return _isLive();
    }

    function isZapEligible() internal view returns (bool) {
        return _isZapEligible();
    }

    function tradingFeePercent() internal pure returns (uint256) {
        return Repo.TRADING_FEE_PERCENT;
    }

    function tradingFeeDenominator() internal pure returns (uint256) {
        return Repo.TRADING_FEE_DENOMINATOR;
    }

    function dexSwapFeeAndFeeTo() internal view returns (address feeTo_, uint256 dexFeeWad) {
        (IFeeCollectorProxy ft, uint256 wad) =
            IVaultFeeOracleQuery(Repo._layout().feeOracle).dexSwapFeeAndFeeToOfVault(address(this));
        return (address(ft), wad);
    }

    function kLast() internal view returns (uint256) {
        return Repo._layout().kLast;
    }

    /// @dev D60: SE shares held x provider rate (pair units); never an SE self-quote.
    function _seClaim() internal view returns (uint256) {
        return ClaimLib.ratedReserve();
    }

    function _reserveOfCurrency(address c) internal view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        if (c == l.rawToken) return l.bookedRaw;
        if (c == l.pairToken) return _seClaim();
        return 0;
    }

    function _isLive() internal view returns (bool) {
        Repo.Layout storage l = Repo._layout();
        return ERC20Repo._totalSupply() != 0 && l.bookedRaw != 0
            && (l.bookedSeShares != 0 || l.localPairReserve != 0);
    }

    function _isZapEligible() internal view returns (bool) {
        return _isLive() && ERC20Repo._totalSupply() > Repo.MINIMUM_LIQUIDITY;
    }

    /// @dev Keep MultiAssetBasicVaultRepo reserves aligned with product book (raw face × virtual pair).
    function _syncReserves() internal {
        Repo.Layout storage l = Repo._layout();
        MultiAssetBasicVaultRepo._updateReserve(IERC20(l.rawToken), l.bookedRaw);
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
        if (_isZapEligible()) return;
        // D89: owner may depositSingle at MINIMUM_LIQUIDITY (public still reverts).
        if (
            ERC20Repo._totalSupply() == Repo.MINIMUM_LIQUIDITY && _isLive()
                && msg.sender == MultiStepOwnableRepo._owner()
        ) {
            return;
        }
        revert NotZapEligible();
    }

    function _requireNonZero(uint256 amount) internal pure {
        if (amount == 0) revert ZeroAmount();
    }

    function _requireDeadline(uint256 deadline) internal view {
        if (block.timestamp > deadline) revert DeadlineExpired();
    }

    function _decimalsOf(address token) internal view returns (uint8 d) {
        return _singleDecimals(token);
    }

    function _wadProduct() internal view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        return Math.toWad(reserveCurrency0(), _decimalsOf(l.currency0))
            * Math.toWad(reserveCurrency1(), _decimalsOf(l.currency1));
    }

    function _feeOnAndShare() internal view returns (bool feeOn, address feeTo_, uint256 ownerFeeShare) {
        uint256 dexFeeWad;
        (feeTo_, dexFeeWad) = dexSwapFeeAndFeeTo();
        feeOn = feeTo_ != address(0) && dexFeeWad != 0;
        ownerFeeShare = (dexFeeWad * Repo.TRADING_FEE_DENOMINATOR) / 1e18;
    }

    function _previewBufferClaimIn(uint256 amountInRaw) internal view returns (uint256) {
        return ClaimLib.previewBufferClaimIn(amountInRaw);
    }

    function _invertBufferClaimIn(uint256 claimInNeeded) internal view returns (uint256) {
        return ClaimLib.invertBufferClaimIn(claimInNeeded);
    }

    /* ---------------------------------------------------------------------- */
    /*                              SE buffer / unwrap                        */
    /* ---------------------------------------------------------------------- */

    function _bufferPair(uint256 amount) internal returns (uint256) {
        return ClaimLib.bufferPoolPair(amount);
    }

    function _spendableSeShares() internal view returns (uint256) {
        return Repo._layout().bookedSeShares;
    }

    function _spendableRaw() internal view returns (uint256) {
        return Repo._layout().bookedRaw;
    }

    function _unwrapSeShares(uint256 seIn) internal returns (uint256 pairOut) {
        uint256 cap = _spendableSeShares();
        if (seIn > cap) seIn = cap;
        if (seIn == 0) return 0;
        Repo.Layout storage l = Repo._layout();
        if (l.pairToken == l.standardExchange) return seIn;(uint256 minOut,) = IStandardExchangeIn(l.standardExchange).previewExchangeIn(IERC20(l.standardExchange), seIn, IERC20(l.pairToken));
        // Uni V3/V4 SE pulls shares via transferFrom when pretransferred=false.
        IERC20(l.standardExchange).forceApprove(l.standardExchange, seIn);(pairOut,) = IStandardExchangeIn(l.standardExchange).exchangeIn(IERC20(l.standardExchange), seIn, IERC20(l.pairToken), minOut, address(this), false, block.timestamp
            );
        IERC20(l.standardExchange).forceApprove(l.standardExchange, 0);
    }

    function _unwrapExactPairOut(uint256 pairOut) internal returns (uint256 seIn) {
        _requireNonZero(pairOut);
        Repo.Layout storage l = Repo._layout();
        if (l.pairToken == l.standardExchange) return pairOut;
        uint256 cap = _spendableSeShares();
        if (cap == 0) {
            if (Repo._layout().ownerOnlyLiquidity) return 0;
            revert InsufficientTokenOut();
        }
        seIn = IStandardExchangeOut(l.standardExchange)
            .previewExchangeOut(IERC20(l.standardExchange), IERC20(l.pairToken), pairOut);
        // Never unwrap the last MAX_DUST_WEI SE shares — both book legs stay live.
        if (seIn == 0 || seIn > cap) revert InsufficientTokenOut();
        IERC20(l.standardExchange).forceApprove(l.standardExchange, seIn);
        uint256 spent = IStandardExchangeOut(l.standardExchange)
            .exchangeOut(
                IERC20(l.standardExchange), seIn, IERC20(l.pairToken), pairOut, address(this), false, block.timestamp
            );
        IERC20(l.standardExchange).forceApprove(l.standardExchange, 0);
        require(spent == seIn, "unwrap exact-out");
    }

    function _unwrapPairLeavingDust(uint256 pairWant) internal returns (uint256) {
        return ClaimLib.takeExactPair(pairWant);
    }


    /* ---------------------------------------------------------------------- */
    /*                              swap core                                 */
    /* ---------------------------------------------------------------------- */

    function _zeroForOneIsRawIn() internal view returns (bool) {
        return Repo._layout().currency0 == Repo._layout().rawToken;
    }

    function _quoteExactIn(bool zeroForOne, uint256 amountIn) internal view returns (uint256 amountOut) {
        return _singleSwapQuote(zeroForOne, amountIn, true);
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

    struct JoinUnbalancedAcc {
        uint256 raw;
        uint256 pair;
        uint256 seShare;
        bool sawPair;
        bool sawSe;
    }

    function _accumulateJoin(address[] calldata tokensIn, uint256[] calldata amounts)
        internal
        view
        returns (JoinUnbalancedAcc memory acc)
    {
        if (tokensIn.length != amounts.length) revert InvalidRoute();
        Repo.Layout storage l = Repo._layout();
        for (uint256 i; i < tokensIn.length; ++i) {
            if (amounts[i] == 0) continue;
            UniswapV4SeBufferHookLegLib.LegKind kind = UniswapV4SeBufferHookLegLib.classify(l.legs, tokensIn[i]);
            if (kind == UniswapV4SeBufferHookLegLib.LegKind.Unknown) revert InvalidRoute();
            if (kind == UniswapV4SeBufferHookLegLib.LegKind.Detf) {
                acc.raw += amounts[i];
            } else if (kind == UniswapV4SeBufferHookLegLib.LegKind.Pair) {
                if (acc.sawSe) revert PairAndShareSameLeg();
                acc.sawPair = true;
                acc.pair += amounts[i];
            } else {
                if (acc.sawPair) revert PairAndShareSameLeg();
                acc.sawSe = true;
                acc.seShare += amounts[i];
            }
        }
    }

    function _requireFirstJoinFullBook(JoinUnbalancedAcc memory acc) internal view {
        if (ERC20Repo._totalSupply() != 0) return;
        if (acc.raw == 0 || (acc.pair == 0 && acc.seShare == 0)) {
            revert FirstJoinMustBeFullBook();
        }
    }

    /// @dev Account for a two-currency deposit after its input tokens have been pulled.
    function _deposit(uint256 amount0, uint256 amount1, address to, uint256 minLpAmount, uint256 deadline)
        internal returns (uint256 lpAmount, uint256 used0, uint256 used1)
    {
        _requireDeadline(deadline);
        if (ERC20Repo._totalSupply() == 0) {
            _requireNonZero(amount0);
            _requireNonZero(amount1);
        }
        Repo.Layout storage l = Repo._layout();
        bool rawFirst = l.currency0 == l.rawToken;
        uint256 usedRaw;
        uint256 usedPair;
        (lpAmount, usedRaw, usedPair) = ClaimLib.joinComponents(
            rawFirst ? amount0 : amount1, rawFirst ? amount1 : amount0, false, to, minLpAmount
        );
        (used0, used1) = rawFirst ? (usedRaw, usedPair) : (usedPair, usedRaw);
        _syncReserves();
        emit Deposit(msg.sender, to, amount0, amount1, used0, used1, lpAmount);
    }

    /// @dev After dual pull of (amount0, amount1), reconstruct pre-pull effective reserves.
    function _reservesBeforeDualPull(uint256 amount0, uint256 amount1) internal view returns (uint256 x, uint256 y) {
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
        view
        returns (uint256 used0, uint256 used1)
    {
        return _singleClamp(x, y, amount0, amount1);
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
        return _singleClamp(reserveCurrency0(), reserveCurrency1(), amount0, amount1);
    }

    /// @dev D59: LP for a later join is the smaller raw-balance growth ratio (raw token, SE shares) measured
    ///      against the raw book in pool order before the intake; the provider rate plays no part in issuance.
    function _mintFromDeltas(uint256 rawXBefore, uint256 rawYBefore, address to) internal returns (uint256 lpAmount) {
        uint256 x = _rawReserveCurrency0();
        uint256 y = _rawReserveCurrency1();
        lpAmount = Math.mintSharesLater(x - rawXBefore, y - rawYBefore, rawXBefore, rawYBefore, ERC20Repo._totalSupply());
        if (lpAmount == 0) revert ZeroAmount();
        _mintLp(to, lpAmount);
    }

    /// @dev B6 proportional deposit: raw face + SE shares; book uses claim of SE shares (anti-skew).
    function _depositWithSeShares(uint256 amountRaw, uint256 amountSe, address to, uint256 minLpAmount, uint256 deadline)
        internal returns (uint256 lpAmount, uint256 usedRaw, uint256 usedSe)
    {
        _requireDeadline(deadline);
        if (ERC20Repo._totalSupply() == 0) {
            _requireNonZero(amountRaw);
            _requireNonZero(amountSe);
        }
        (lpAmount, usedRaw, usedSe) = ClaimLib.joinComponents(amountRaw, amountSe, true, to, minLpAmount);
        _syncReserves();
        emit DepositSeShares(msg.sender, to, amountRaw, amountSe, usedRaw, usedSe, lpAmount);
    }

    function _firstMintSeShares(address to) internal returns (uint256 lpAmount) {
        // Inventory already on hook (pulled SE + raw); no buffer.
        Repo.Layout storage l = Repo._layout();
        uint256 geometric = Math.mintSharesFirst(
            Math.toWad(reserveCurrency0(), l.decimalsCurrency0), Math.toWad(reserveCurrency1(), l.decimalsCurrency1)
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
        (uint256 rawBefore, uint256 seClaimBefore, uint256 claimOffered) = _seDepositPrePullBook(amountRaw, amountSe);
        if (rawBefore == 0 || seClaimBefore == 0) revert NotLive();
        if (claimOffered == 0) revert ZeroAmount();
        uint256 seBefore = _rawSeBalance() - amountSe; // D59: pre-pull share balance

        uint256 usedClaim;
        (usedRaw, usedClaim) = _clampToReserveRatioFrom(rawBefore, seClaimBefore, amountRaw, claimOffered);
        // Linear in SE unwrap claim for ERC-4626-style SE (claim of subset of shares).
        usedSe = (amountSe * usedClaim) / claimOffered;
        if (usedSe == 0 || usedRaw == 0) revert ZeroAmount();

        _refundSeDepositExcess(amountRaw, amountSe, usedRaw, usedSe);
        lpAmount = _mintFromDeltas(_poolOrderX(rawBefore, seBefore), _poolOrderY(rawBefore, seBefore), to);
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

    function _refundSeDepositExcess(uint256 amountRaw, uint256 amountSe, uint256 usedRaw, uint256 usedSe) internal {
        Repo.Layout storage l = Repo._layout();
        if (amountRaw > usedRaw) {
            IERC20(l.rawToken).safeTransfer(msg.sender, amountRaw - usedRaw);
        }
        if (amountSe > usedSe) {
            IERC20(l.standardExchange).safeTransfer(msg.sender, amountSe - usedSe);
        }
    }

    function _poolOrderX(uint256 rawAmt, uint256 seClaimAmt) internal view returns (uint256) {
        return _singleOrderX(rawAmt, seClaimAmt);
    }

    function _poolOrderY(uint256 rawAmt, uint256 seClaimAmt) internal view returns (uint256) {
        return _singleOrderY(rawAmt, seClaimAmt);
    }

    /// @dev D60: rated valuation of `seBal` shares (pair units).
    function _previewSeClaimOfBal(uint256 seBal) internal view returns (uint256) {
        return ClaimLib.ratedOf(seBal);
    }

    /* ---------------------------------------------------------------------- */
    /*                       D59 raw liquidity book                           */
    /* ---------------------------------------------------------------------- */

    /// @dev D59: LP issuance is proportional in raw balances. The raw book in pool order is the raw-token
    ///      balance and the SE share balance (an identity leg's pair balance); the provider rate never enters it.
    function _rawSeBalance() internal view returns (uint256) {
        return IERC20(Repo._layout().standardExchange).balanceOf(address(this));
    }

    function _rawReserveCurrency0() internal view returns (uint256) {
        return _singleRawReserve(Repo._layout().currency0);
    }

    function _rawReserveCurrency1() internal view returns (uint256) {
        return _singleRawReserve(Repo._layout().currency1);
    }

    /// @dev Raw units a leg gains from `used` tokens: the raw token itself, or the SE shares a pair buffer mints
    ///      (the SE's own preview, which equals execution, D73).
    function _previewRawDelta(bool forC0, uint256 used0, uint256 used1) internal view returns (uint256) {
        return _singleRawDelta(forC0, used0, used1);
    }

    /// @dev Raw book before a pull of (amount0, amount1): the raw leg backs out its pull; an identity pair leg
    ///      backs out the pulled pair (it already sits in the share balance); a buffered pair leg's pull sits as
    ///      free pair, outside the share balance.
    function _rawReservesBeforeDualPull(uint256 amount0, uint256 amount1)
        internal view returns (uint256 x, uint256 y)
    {
        Repo.Layout storage l = Repo._layout();
        bool identity = l.pairToken == l.standardExchange;
        uint256 seBal = _rawSeBalance();
        uint256 rawBal = IERC20(l.rawToken).balanceOf(address(this));
        if (l.currency0 == l.rawToken) {
            x = rawBal - amount0;
            y = identity && seBal >= amount1 ? seBal - amount1 : seBal;
        } else {
            x = identity && seBal >= amount0 ? seBal - amount0 : seBal;
            y = rawBal - amount1;
        }
    }

    function _depositSingle(address tokenIn, uint256 amountIn, address to, uint256 minLpAmount, uint256 deadline)
        internal returns (uint256 lpAmount)
    {
        _requireDeadline(deadline);
        _requireNonZero(amountIn);
        Repo.Layout storage l = Repo._layout();
        if (tokenIn != l.rawToken && tokenIn != l.pairToken) revert InvalidToken();
        uint256 supply = ERC20Repo._totalSupply();
        if (supply < Repo.MINIMUM_LIQUIDITY
            || (supply == Repo.MINIMUM_LIQUIDITY && msg.sender != MultiStepOwnableRepo._owner())) {
            revert NotZapEligible();
        }
        lpAmount = ClaimLib.singleComponentJoin(tokenIn, amountIn, to, minLpAmount, 0);
        _syncReserves();
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
            uint256 rawBefore = l.bookedRaw;
            uint256 rInN = Math.toWad(rawBefore, _decimalsOf(l.rawToken));
            saleAmt = Math.fromWadFloor(
                Math.swapDepositSaleAmt(Math.toWad(amountIn, _decimalsOf(l.rawToken)), rInN), _decimalsOf(l.rawToken)
            );
        } else {
            uint256 claimInFull = _previewBufferClaimIn(amountIn);
            uint256 rInN = Math.toWad(_seClaim(), _decimalsOf(l.pairToken));
            uint256 saleClaimN = Math.swapDepositSaleAmt(Math.toWad(claimInFull, _decimalsOf(l.pairToken)), rInN);
            if (claimInFull == 0) {
                saleAmt = amountIn / 2;
            } else {
                saleAmt = (amountIn * Math.fromWadFloor(saleClaimN, _decimalsOf(l.pairToken))) / claimInFull;
            }
        }
        if (saleAmt > amountIn) saleAmt = amountIn;
        // Never sell 100% of tokenIn: keptIn==0 makes _clampToReserveRatioFrom ZeroAmount
        // on close/mint rejoin into a keep-10 remainder pool.
        if (saleAmt == 0 || saleAmt >= amountIn) saleAmt = amountIn / 2;

        // Quote on pre-buffer book with pulled inventory (raw-in includes amountIn for face quote).
        ClaimLib.ExactInOutput memory output = _quoteExactInZapPlan(zfo, saleAmt, tokenIn, amountIn);
        amountOtherOut = output.amountOut;

        if (tokenIn == l.pairToken) {
            _bufferPair(saleAmt);
            l.bookedRaw -= amountOtherOut;
        } else {
            l.bookedRaw += saleAmt;
            amountOtherOut = ClaimLib.unwrapQuoted(output);
        }
        // An unmintable zap must roll back its pull and intermediate swap.
        if (amountOtherOut == 0) revert ZeroAmount();
        emit ZapSwap(msg.sender, tokenIn, tokenOut, saleAmt, amountOtherOut);
    }

    /// @dev Zap exact-in quote treating just-pulled tokenIn inventory carefully.
    function _quoteExactInZap(bool zeroForOne, uint256 amountIn, address tokenIn, uint256 pulledIn)
        internal
        view
        returns (uint256 amountOut)
    {
        return _quoteExactInZapPlan(zeroForOne, amountIn, tokenIn, pulledIn).amountOut;
    }

    function _quoteExactInZapPlan(bool zeroForOne, uint256 amountIn, address, uint256)
        internal view returns (ClaimLib.ExactInOutput memory output)
    {
        Repo.Layout storage l = Repo._layout();
        bool rawIn = zeroForOne == _zeroForOneIsRawIn();
        uint256 rawBal = l.bookedRaw;
        uint256 seClaim = _seClaim();
        if (rawIn) {
            uint256 rInN = Math.toWad(rawBal, _decimalsOf(l.rawToken));
            uint256 rOutN = Math.toWad(seClaim, _decimalsOf(l.pairToken));
            uint256 aInN = Math.toWad(amountIn, _decimalsOf(l.rawToken));
            uint256 budget = Math.fromWadFloor(Math.saleQuote(aInN, rInN, rOutN), _decimalsOf(l.pairToken));
            if (budget != 0) output = ClaimLib.previewBudget(budget);
        } else {
            uint256 claimIn = _previewBufferClaimIn(amountIn);
            uint256 rInN = Math.toWad(seClaim, _decimalsOf(l.pairToken));
            uint256 rOutN = Math.toWad(rawBal, _decimalsOf(l.rawToken));
            uint256 cInN = Math.toWad(claimIn, _decimalsOf(l.pairToken));
            output.amountOut = Math.fromWadFloor(Math.saleQuote(cInN, rInN, rOutN), _decimalsOf(l.rawToken));
        }
    }

    function _proportionalAddAfterZap(address tokenIn, address, uint256 keptIn, uint256 amountOtherOut, address to)
        internal returns (uint256 lpAmount)
    {
        bool rawIn = tokenIn == Repo._layout().rawToken;
        (lpAmount,,) = ClaimLib.joinComponents(rawIn ? keptIn : amountOtherOut,
            rawIn ? amountOtherOut : keptIn, false, to, 0);
    }

    /// @dev Rated book after the zap swap with the free adds backed out (an identity pair leg's pulled pair
    ///      already sits in the rated balance), then the reserve-ratio clamp. add0/add1 are in currency order.
    function _clampAfterZap(uint256 add0, uint256 add1) internal view returns (uint256 used0, uint256 used1) {
        Repo.Layout storage l = Repo._layout();
        bool identity = l.pairToken == l.standardExchange;
        uint256 seClaim = _seClaim();
        uint256 xBefore;
        uint256 yBefore;
        if (l.currency0 == l.rawToken) {
            xBefore = IERC20(l.rawToken).balanceOf(address(this)) - add0;
            yBefore = identity && seClaim >= add1 ? seClaim - add1 : seClaim;
        } else {
            xBefore = identity && seClaim >= add0 ? seClaim - add0 : seClaim;
            yBefore = IERC20(l.rawToken).balanceOf(address(this)) - add1;
        }
        (used0, used1) = _clampToReserveRatioFrom(xBefore, yBefore, add0, add1);
    }

    /*                              protocol fee                              */
    /* ---------------------------------------------------------------------- */



    function _supplyAfterProtocolMint() internal view returns (uint256 supplyAdj) {
        return _singleSupply();
    }

    function _supplyAfterProtocolMintForPairClaim(uint256 pairClaim) internal view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        if (pairClaim == 0 && IERC20(l.standardExchange).balanceOf(address(this)) > 0) pairClaim = 1;
        uint256 product = Math.toWad(IERC20(l.rawToken).balanceOf(address(this)), _decimalsOf(l.rawToken))
            * Math.toWad(pairClaim, _decimalsOf(l.pairToken));
        return _supplyAfterProtocolMintForProduct(product);
    }

    function _supplyAfterProtocolMintForProduct(uint256 product) private view returns (uint256 supplyAdj) {
        return _singleSupplyForProduct(product);
    }

    /* ---------------------------------------------------------------------- */

    function _previewReserveAfterIntake(bool forC0, uint256 used0, uint256 used1) internal view returns (uint256) {
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

    /// @dev Quote initial LP issuance for raw and buffered SE-share capital.
    function _previewFirstMintSeShares(uint256 usedRaw, uint256 claimOffered) internal view returns (uint256 lpAmount) {
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

        // D59: the clamp sized `usedSe` on the rated book; issuance follows the raw book (raw token, SE shares).
        lpAmount = Math.mintSharesLater(
            _poolOrderX(usedRaw, usedSe), _poolOrderY(usedRaw, usedSe),
            _rawReserveCurrency0(), _rawReserveCurrency1(), _supplyAfterProtocolMint()
        );
    }

    function _previewZapSplit(address tokenIn, uint256 amountIn)
        internal
        view
        returns (uint256 saleAmt, uint256 amountOtherOut, uint256 keptIn)
    {
        return _singleZapSplit(tokenIn, amountIn);
    }
}
