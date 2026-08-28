// SPDX-License-Identifier: BSL-1.1
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
    UniswapV4HookOwnerOnlyLiquidityLib
} from "contracts/hooks/uniswap/v4/libs/UniswapV4HookOwnerOnlyLiquidityLib.sol";
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
 * @title UniswapV4SingleStandardExchangeBufferConstantProductHookWithdrawTarget
 * @notice Product logic only: CP hooks, liquidity, SE In/Out, product views.
 * @dev LP ERC-20, IBasicVault, IStandardVault are cut as shared facets on the diamond.
 *      LP supply/balances use ERC20Repo; vaultTokens/reserves use MultiAssetBasicVaultRepo
 *      (pair reserve accounting = virtual SE claim; raw = face inventory).
 */
abstract contract UniswapV4SingleStandardExchangeBufferConstantProductHookWithdrawTarget {
    using SafeERC20 for IERC20;

    event Deposit(address indexed sender, address indexed to, uint256 amount0, uint256 amount1, uint256 used0, uint256 used1, uint256 lpAmount);
    event DepositSingle(address indexed sender, address indexed to, address tokenIn, uint256 amountIn, uint256 lpAmount);
    event Withdraw(address indexed sender, address indexed to, uint256 lpAmount, uint256 amount0, uint256 amount1);
    event WithdrawSingle(address indexed sender, address indexed to, uint256 lpAmount, address tokenOut, uint256 amountOut);
    event WithdrawSeShares(
        address indexed sender, address indexed to, uint256 lpAmount, uint256 amountRaw, uint256 amountSe
    );
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

    modifier onlyLiquidityOwner() {
        UniswapV4HookOwnerOnlyLiquidityLib.enforce(Repo._layout().ownerOnlyLiquidity);
        _;
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
        uint256 claim = IStandardExchangeIn(l.standardExchange).previewExchangeIn(
            IERC20(l.standardExchange), seBal, IERC20(l.pairToken)
        );
        return claim == 0 ? 1 : claim;
    }

    function _reserveOfCurrency(address c) internal view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        if (c == l.rawToken) return IERC20(l.rawToken).balanceOf(address(this));
        if (c == l.pairToken) return _seClaim();
        return 0;
    }

    function _isLive() internal view returns (bool) {
        if (reserveCurrency0() > 0 && reserveCurrency1() > 0) return true;
        Repo.Layout storage l = Repo._layout();
        return IERC20(l.rawToken).balanceOf(address(this)) > 0
            && IERC20(l.standardExchange).balanceOf(address(this)) > 0;
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

    function _decimalsOf(address token) internal view returns (uint8 d) {
        Repo.Layout storage l = Repo._layout();
        if (token == l.currency0) d = l.decimalsCurrency0;
        else if (token == l.currency1) d = l.decimalsCurrency1;
        else revert InvalidToken();
        // CREATE3 DETF may not exist at hook bind, so stored decimals can be 0.
        if (d == 0) d = 18;
    }

    function _wadProduct() internal view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        return Math.toWad(reserveCurrency0(), _decimalsOf(l.currency0))
            * Math.toWad(reserveCurrency1(), _decimalsOf(l.currency1));
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

    function _spendableSeShares() internal view returns (uint256) {
        uint256 seBal = IERC20(Repo._layout().standardExchange).balanceOf(address(this));
        // Leave 1 wei so `_isLive` stays true. Proportional exit already retains MAX_DUST_WEI.
        return seBal > 1 ? seBal - 1 : 0;
    }

    function _spendableRaw() internal view returns (uint256) {
        uint256 rawBal = IERC20(Repo._layout().rawToken).balanceOf(address(this));
        return rawBal > 1 ? rawBal - 1 : 0;
    }

    function _unwrapSeShares(uint256 seIn) internal returns (uint256 pairOut) {
        uint256 cap = _spendableSeShares();
        if (seIn > cap) seIn = cap;
        if (seIn == 0) return 0;
        Repo.Layout storage l = Repo._layout();
        uint256 minOut;
        try IStandardExchangeIn(l.standardExchange).previewExchangeIn(
            IERC20(l.standardExchange), seIn, IERC20(l.pairToken)
        ) returns (uint256 m) {
            minOut = m;
        } catch {
            minOut = 0;
        }
        // Uni V3/V4 SE pulls shares via transferFrom when pretransferred=false.
        IERC20(l.standardExchange).forceApprove(l.standardExchange, seIn);
        pairOut = IStandardExchangeIn(l.standardExchange).exchangeIn(
            IERC20(l.standardExchange),
            seIn,
            IERC20(l.pairToken),
            minOut,
            address(this),
            false,
            block.timestamp
        );
        IERC20(l.standardExchange).forceApprove(l.standardExchange, 0);
    }

    function _unwrapExactPairOut(uint256 pairOut) internal returns (uint256 seIn) {
        _requireNonZero(pairOut);
        Repo.Layout storage l = Repo._layout();
        uint256 cap = _spendableSeShares();
        if (cap == 0) revert InsufficientTokenOut();
        try IStandardExchangeOut(l.standardExchange).previewExchangeOut(
            IERC20(l.standardExchange), IERC20(l.pairToken), pairOut
        ) returns (uint256 need) {
            seIn = need;
        } catch {
            seIn = type(uint256).max;
        }
        // Never unwrap the last MAX_DUST_WEI SE shares — both book legs stay live.
        if (seIn > cap) {
            uint256 pairGot = _unwrapSeShares(cap);
            if (pairGot == 0) revert InsufficientTokenOut();
            return cap;
        }
        IERC20(l.standardExchange).forceApprove(l.standardExchange, seIn);
        uint256 spent = IStandardExchangeOut(l.standardExchange).exchangeOut(
            IERC20(l.standardExchange),
            seIn,
            IERC20(l.pairToken),
            pairOut,
            address(this),
            false,
            block.timestamp
        );
        IERC20(l.standardExchange).forceApprove(l.standardExchange, 0);
        require(spent == seIn, "unwrap exact-out");
    }

    function _unwrapPairLeavingDust(uint256 pairWant) internal returns (uint256 pairGot) {
        uint256 pairBefore = IERC20(Repo._layout().pairToken).balanceOf(address(this));
        _unwrapExactPairOut(pairWant);
        pairGot = IERC20(Repo._layout().pairToken).balanceOf(address(this)) - pairBefore;
        if (pairGot == 0) revert InsufficientTokenOut();
    }

    function _refundPairDust(address to) internal {
        to;
        Repo.Layout storage l = Repo._layout();
        for (uint256 i; i < 3; ++i) {
            uint256 bal = IERC20(l.pairToken).balanceOf(address(this));
            if (bal <= Repo.MAX_DUST_WEI) return;
            uint256 excess = bal - Repo.MAX_DUST_WEI;
            uint256 preview = IStandardExchangeIn(l.standardExchange).previewExchangeIn(
                IERC20(l.pairToken), excess, IERC20(l.standardExchange)
            );
            if (preview == 0) return;
            _bufferPair(excess);
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

    function exitProportional(
        uint256 shares,
        address to,
        uint256[] calldata amountsMin,
        uint256 deadline
    ) external onlyLiquidityOwner nonReentrant returns (uint256[] memory amounts) {
        uint256 min0 = amountsMin.length > 0 ? amountsMin[0] : 0;
        uint256 min1 = amountsMin.length > 1 ? amountsMin[1] : 0;
        (uint256 a0, uint256 a1) = _withdraw(shares, to, min0, min1, deadline);
        amounts = new uint256[](2);
        Repo.Layout storage l = Repo._layout();
        amounts[0] = l.currency0 == l.rawToken ? a0 : a1;
        amounts[1] = l.currency0 == l.rawToken ? a1 : a0;
    }

    function previewExitProportional(uint256 shares) external view returns (uint256[] memory amounts) {
        (uint256 a0, uint256 a1) = this.previewWithdraw(shares);
        amounts = new uint256[](2);
        Repo.Layout storage l = Repo._layout();
        amounts[0] = l.currency0 == l.rawToken ? a0 : a1;
        amounts[1] = l.currency0 == l.rawToken ? a1 : a0;
    }

    function exitSingleAssetExactBptIn(
        address tokenOut,
        uint256 sharesIn,
        address to,
        uint256 amountOutMin,
        uint256 deadline
    ) external onlyLiquidityOwner nonReentrant returns (uint256 amountOut) {
        return _withdrawSingle(sharesIn, tokenOut, to, amountOutMin, deadline);
    }

    function previewExitSingleAssetExactBptIn(address tokenOut, uint256 sharesIn)
        external
        view
        returns (uint256 amountOut)
    {
        if (sharesIn == 0 || ERC20Repo._totalSupply() == 0) return 0;
        return this.previewWithdrawSingle(sharesIn, tokenOut);
    }

    function exitSingleAssetExactTokenOut(
        address tokenOut,
        uint256 amountOut,
        address to,
        uint256 sharesInMax,
        uint256 deadline
    ) external onlyLiquidityOwner nonReentrant returns (uint256 sharesIn) {
        uint256 previewOut = this.previewWithdrawSingle(sharesInMax, tokenOut);
        if (previewOut < amountOut) revert InsufficientTokenOut();
        uint256 got = _withdrawSingle(sharesInMax, tokenOut, to, amountOut, deadline);
        got;
        return sharesInMax;
    }

    function previewExitSingleAssetExactTokenOut(address tokenOut, uint256 amountOut)
        external
        view
        returns (uint256 sharesIn)
    {
        tokenOut;
        amountOut;
        return 0;
    }

    function previewBurnToToken(uint256 lpAmount, address tokenOut) external view returns (uint256 amountOut) {
        if (lpAmount == 0 || ERC20Repo._totalSupply() == 0) return 0;
        Repo.Layout storage l = Repo._layout();
        if (tokenOut == l.standardExchange) {
            tokenOut = l.pairToken;
        }
        if (tokenOut != l.pairToken && tokenOut != l.rawToken) return 0;
        return this.previewWithdrawSingle(lpAmount, tokenOut);
    }

    function withdraw(uint256 lpAmount, address to, uint256 minAmount0, uint256 minAmount1, uint256 deadline)
        external
        onlyLiquidityOwner
        nonReentrant
        returns (uint256 amount0, uint256 amount1)
    {
        return _withdraw(lpAmount, to, minAmount0, minAmount1, deadline);
    }

    function withdrawSingle(
        uint256 lpAmount,
        address tokenOut,
        address to,
        uint256 minAmountOut,
        uint256 deadline
    ) external onlyLiquidityOwner nonReentrant returns (uint256 amountOut) {
        return _withdrawSingle(lpAmount, tokenOut, to, minAmountOut, deadline);
    }

    /// @notice B6: proportional withdraw paying rawToken + SE vault shares (no unwrap).
    function withdrawSeShares(
        uint256 lpAmount,
        address to,
        uint256 minAmountRaw,
        uint256 minAmountSe,
        uint256 deadline
    ) external onlyLiquidityOwner nonReentrant returns (uint256 amountRaw, uint256 amountSe) {
        return _withdrawSeShares(lpAmount, to, minAmountRaw, minAmountSe, deadline);
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
        _mintProtocolFeeIfNeeded();

        Repo.Layout storage l = Repo._layout();
        if (lpAmount > ERC20Repo._balanceOf(msg.sender)) revert InsufficientLpOut();

        (uint256 rawOut, uint256 seOut) = _proRataRawAndSe(lpAmount);
        _burnLp(msg.sender, lpAmount);
        uint256 pairOut = seOut > 0 ? _unwrapSeShares(seOut) : 0;

        if (rawOut > 0) {
            uint256 cap = _spendableRaw();
            if (rawOut > cap) rawOut = cap;
            if (rawOut > 0) IERC20(l.rawToken).safeTransfer(to, rawOut);
        }
        if (pairOut > 0) IERC20(l.pairToken).safeTransfer(to, pairOut);
        (amount0, amount1) = _orderAmounts(rawOut, pairOut);

        if (amount0 < minAmount0 || amount1 < minAmount1) revert InsufficientTokenOut();
        _syncReserves();
        _setKLastPostOp();
        _refundPairDust(msg.sender);
        emit Withdraw(msg.sender, to, lpAmount, amount0, amount1);
    }

    function _proRataRawAndSe(uint256 lpAmount) internal view returns (uint256 rawOut, uint256 seOut) {
        Repo.Layout storage l = Repo._layout();
        uint256 supply = ERC20Repo._totalSupply();
        uint256 rawBal = IERC20(l.rawToken).balanceOf(address(this));
        uint256 seBal = IERC20(l.standardExchange).balanceOf(address(this));
        rawOut = (rawBal * lpAmount) / supply;
        seOut = (seBal * lpAmount) / supply;
        uint256 dust = Repo.MAX_DUST_WEI;
        // Keep 10 wei of each book leg on every proportional exit, including lpAmount == supply.
        if (rawBal <= dust) {
            rawOut = 0;
        } else if (rawOut > rawBal - dust) {
            rawOut = rawBal - dust;
        }
        if (seBal <= dust) {
            seOut = 0;
        } else if (seOut > seBal - dust) {
            seOut = seBal - dust;
        }
    }

    function _withdrawSeShares(
        uint256 lpAmount,
        address to,
        uint256 minAmountRaw,
        uint256 minAmountSe,
        uint256 deadline
    ) internal returns (uint256 amountRaw, uint256 amountSe) {
        _requireDeadline(deadline);
        _requireNonZero(lpAmount);
        _mintProtocolFeeIfNeeded();

        Repo.Layout storage l = Repo._layout();
        if (lpAmount > ERC20Repo._balanceOf(msg.sender)) revert InsufficientLpOut();

        (amountRaw, amountSe) = _proRataRawAndSe(lpAmount);
        _burnLp(msg.sender, lpAmount);

        if (amountRaw > 0) {
            uint256 capRaw = _spendableRaw();
            if (amountRaw > capRaw) amountRaw = capRaw;
            if (amountRaw > 0) IERC20(l.rawToken).safeTransfer(to, amountRaw);
        }
        if (amountSe > 0) {
            uint256 capSe = _spendableSeShares();
            if (amountSe > capSe) amountSe = capSe;
            if (amountSe > 0) IERC20(l.standardExchange).safeTransfer(to, amountSe);
        }

        if (amountRaw < minAmountRaw || amountSe < minAmountSe) revert InsufficientTokenOut();
        _syncReserves();
        _setKLastPostOp();
        _refundPairDust(msg.sender);
        emit WithdrawSeShares(msg.sender, to, lpAmount, amountRaw, amountSe);
    }

    function _orderAmounts(uint256 rawAmt, uint256 pairAmt)
        internal
        view
        returns (uint256 amount0, uint256 amount1)
    {
        if (Repo._layout().currency0 == Repo._layout().rawToken) {
            amount0 = rawAmt;
            amount1 = pairAmt;
        } else {
            amount0 = pairAmt;
            amount1 = rawAmt;
        }
    }

    function _withdrawSingle(
        uint256 lpAmount,
        address tokenOut,
        address to,
        uint256 minAmountOut,
        uint256 deadline
    ) internal returns (uint256 amountOut) {
        _requireDeadline(deadline);
        _requireNonZero(lpAmount);
        Repo.Layout storage l = Repo._layout();
        if (tokenOut != l.rawToken && tokenOut != l.pairToken) revert InvalidToken();
        _requireZapEligible();
        _mintProtocolFeeIfNeeded();

        if (lpAmount > ERC20Repo._balanceOf(msg.sender)) revert InsufficientLpOut();

        // O13: quote residual sell once on pre-buffer / pre-unwrap book (same as previewWithdrawSingle).
        amountOut = _previewWithdrawSingleAfterFeeMint(lpAmount, tokenOut);
        if (amountOut < minAmountOut) revert InsufficientTokenOut();

        (uint256 rawUser, uint256 seUser) = _proRataRawAndSe(lpAmount);
        _burnLp(msg.sender, lpAmount);

        uint256 pairUser = seUser > 0 ? _unwrapSeShares(seUser) : 0;
        if (tokenOut == l.pairToken) {
            // Realize residual raw → pair using closed-form amount already quoted.
            uint256 residual = amountOut > pairUser ? amountOut - pairUser : 0;
            if (residual > 0) {
                uint256 got = _unwrapPairLeavingDust(residual);
                emit ZapSwap(msg.sender, l.rawToken, l.pairToken, rawUser, got);
                amountOut = pairUser + got;
            }
            if (amountOut > 0) IERC20(l.pairToken).safeTransfer(to, amountOut);
        } else {
            // Realize residual pair → raw: buffer pair last after quote (O13).
            uint256 residual = amountOut > rawUser ? amountOut - rawUser : 0;
            if (pairUser > 0) {
                _bufferPair(pairUser);
                emit ZapSwap(msg.sender, l.pairToken, l.rawToken, pairUser, residual);
            }
            uint256 capRaw = _spendableRaw();
            if (amountOut > capRaw) amountOut = capRaw;
            if (amountOut > 0) IERC20(l.rawToken).safeTransfer(to, amountOut);
        }

        _syncReserves();
        _setKLastPostOp();
        _refundPairDust(msg.sender);
        emit WithdrawSingle(msg.sender, to, lpAmount, tokenOut, amountOut);
    }

    /// @dev Shared preview/exec quote for zap-out after protocol mint (if any).
    function _previewWithdrawSingleAfterFeeMint(uint256 lpAmount, address tokenOut)
        internal
        view
        returns (uint256 amountOut)
    {
        Repo.Layout storage l = Repo._layout();
        uint256 supply = ERC20Repo._totalSupply();
        if (lpAmount == 0 || supply == 0) return 0;
        uint256 rawBal = IERC20(l.rawToken).balanceOf(address(this));
        uint256 seBal = IERC20(l.standardExchange).balanceOf(address(this));
        uint256 rawUser = (rawBal * lpAmount) / supply;
        uint256 seUser = (seBal * lpAmount) / supply;
        uint256 pairUser = seUser == 0 ? 0 : _previewUnwrapSe(seUser);
        uint256 rawRemain = rawBal - rawUser;
        uint256 seClaimRem = _previewSeClaimOf(seBal - seUser);

        if (tokenOut == l.pairToken) {
            return pairUser + _saleQuoteRawToPair(rawUser, rawRemain, seClaimRem);
        }
        if (tokenOut == l.rawToken) {
            return rawUser + _saleQuotePairToRaw(pairUser, seClaimRem, rawRemain);
        }
        revert InvalidToken();
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
    function previewWithdraw(uint256 lpAmount)
        external
        view
        returns (uint256 amount0, uint256 amount1)
    {
        uint256 supply = _supplyAfterProtocolMint();
        if (lpAmount == 0 || supply == 0) return (0, 0);
        // Preview uses post-protocol-mint supply; inventory split uses current balances.
        if (ERC20Repo._totalSupply() == 0) return (0, 0);
        uint256 rawBal = IERC20(Repo._layout().rawToken).balanceOf(address(this));
        uint256 seBal = IERC20(Repo._layout().standardExchange).balanceOf(address(this));
        uint256 rawOut = (rawBal * lpAmount) / supply;
        uint256 seOut = (seBal * lpAmount) / supply;
        uint256 dust = Repo.MAX_DUST_WEI;
        if (rawBal <= dust) rawOut = 0;
        else if (rawOut > rawBal - dust) rawOut = rawBal - dust;
        if (seBal <= dust) seOut = 0;
        else if (seOut > seBal - dust) seOut = seBal - dust;
        return _orderAmounts(rawOut, seOut == 0 ? 0 : _previewUnwrapSe(seOut));
    }

    /// @notice B6 preview: pro-rata raw + SE shares (no unwrap).
    function previewWithdrawSeShares(uint256 lpAmount)
        external
        view
        returns (uint256 amountRaw, uint256 amountSe)
    {
        uint256 supply = _supplyAfterProtocolMint();
        if (lpAmount == 0 || supply == 0) return (0, 0);
        if (ERC20Repo._totalSupply() == 0) return (0, 0);
        uint256 rawBal = IERC20(Repo._layout().rawToken).balanceOf(address(this));
        uint256 seBal = IERC20(Repo._layout().standardExchange).balanceOf(address(this));
        amountRaw = (rawBal * lpAmount) / supply;
        amountSe = (seBal * lpAmount) / supply;
        uint256 dust = Repo.MAX_DUST_WEI;
        if (rawBal <= dust) amountRaw = 0;
        else if (amountRaw > rawBal - dust) amountRaw = rawBal - dust;
        if (seBal <= dust) amountSe = 0;
        else if (amountSe > seBal - dust) amountSe = seBal - dust;
    }

    function previewWithdrawSingle(uint256 lpAmount, address tokenOut)
        external
        view
        returns (uint256 amountOut)
    {
        // Mirror exec: use post-protocol-mint supply for pro-rata weights when fee-on would mint.
        uint256 supplyNow = ERC20Repo._totalSupply();
        if (lpAmount == 0 || supplyNow == 0) return 0;
        // Temporarily view-simulate protocol mint by using adjusted supply only in pro-rata.
        // Exec mints first then divides by post-mint supply — same as _supplyAfterProtocolMint.
        // Inventory amounts still taken from current balances (protocol mint is LP-only).
        uint256 supply = _supplyAfterProtocolMint();
        Repo.Layout storage l = Repo._layout();
        uint256 rawBal = IERC20(l.rawToken).balanceOf(address(this));
        uint256 seBal = IERC20(l.standardExchange).balanceOf(address(this));
        uint256 rawUser = (rawBal * lpAmount) / supply;
        uint256 seUser = (seBal * lpAmount) / supply;
        uint256 pairUser = seUser == 0 ? 0 : _previewUnwrapSe(seUser);
        uint256 rawRemain = rawBal - rawUser;
        uint256 seClaimRem = _previewSeClaimOf(seBal - seUser);

        if (tokenOut == l.pairToken) {
            return pairUser + _saleQuoteRawToPair(rawUser, rawRemain, seClaimRem);
        }
        if (tokenOut == l.rawToken) {
            return rawUser + _saleQuotePairToRaw(pairUser, seClaimRem, rawRemain);
        }
        revert InvalidToken();
    }

    function _previewUnwrapSe(uint256 seAmount) internal view returns (uint256) {
        if (seAmount == 0) return 0;
        Repo.Layout storage l = Repo._layout();
        return IStandardExchangeIn(l.standardExchange).previewExchangeIn(
            IERC20(l.standardExchange), seAmount, IERC20(l.pairToken)
        );
    }

    function _previewSeClaimOf(uint256 seBal) internal view returns (uint256) {
        if (seBal == 0) return 0;
        return _previewUnwrapSe(seBal);
    }

    function _saleQuoteRawToPair(uint256 rawIn, uint256 rawRes, uint256 pairRes)
        internal
        view
        returns (uint256)
    {
        if (rawIn == 0 || rawRes == 0 || pairRes == 0) return 0;
        uint8 dRaw = _decimalsOf(Repo._layout().rawToken);
        uint8 dPair = _decimalsOf(Repo._layout().pairToken);
        return Math.fromWadFloor(
            Math.saleQuote(Math.toWad(rawIn, dRaw), Math.toWad(rawRes, dRaw), Math.toWad(pairRes, dPair)),
            dPair
        );
    }

    function _saleQuotePairToRaw(uint256 pairIn, uint256 pairRes, uint256 rawRes)
        internal
        view
        returns (uint256)
    {
        if (pairIn == 0 || pairRes == 0 || rawRes == 0) return 0;
        uint256 claimIn = _previewBufferClaimIn(pairIn);
        uint8 dRaw = _decimalsOf(Repo._layout().rawToken);
        uint8 dPair = _decimalsOf(Repo._layout().pairToken);
        return Math.fromWadFloor(
            Math.saleQuote(Math.toWad(claimIn, dPair), Math.toWad(pairRes, dPair), Math.toWad(rawRes, dRaw)),
            dRaw
        );
    }

    // LP ERC-20, IBasicVault, IStandardVault: shared diamond facets only.
}
