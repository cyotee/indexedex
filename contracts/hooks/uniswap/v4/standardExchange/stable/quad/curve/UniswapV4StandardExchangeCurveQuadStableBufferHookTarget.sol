// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV4BufferHookLiquidityRouteLib as Components} from "contracts/hooks/uniswap/v4/libs/UniswapV4BufferHookLiquidityRouteLib.sol";
import {ExchangeInAmount} from "contracts/utils/ExchangeInAmount.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {UniswapV4StandardExchangeCurveQuadStableBufferHookClaimLib as ClaimLib} from "./UniswapV4StandardExchangeCurveQuadStableBufferHookClaimLib.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IHooks} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IHooks.sol";
import {PoolKey} from "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol";
import {TickMath} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/TickMath.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IRateProvider} from
    "@crane/contracts/protocols/dexes/balancer/common/interfaces/IRateProvider.sol";
import {UniswapV4StandardExchangeCurveQuadStableBufferHookPullLib as PullLib} from "./UniswapV4StandardExchangeCurveQuadStableBufferHookPullLib.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {LocalCreditLib} from "contracts/utils/LocalCreditLib.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {
    UniswapV4HookOwnerOnlyLiquidityLib
} from "contracts/hooks/uniswap/v4/libs/UniswapV4HookOwnerOnlyLiquidityLib.sol";
import {
    IUniswapV4StandardExchangeCurveQuadStableBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/interfaces/IUniswapV4StandardExchangeCurveQuadStableBufferHook.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableBufferHookRepo as Repo
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookRepo.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableBufferHookMath as Math
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookMath.sol";
import {
    UniswapV4StandardExchangeCurveQuadStableBufferHookPairPoolLib as PairPoolLib
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookPairPoolLib.sol";
import {AddressSet, AddressSetRepo} from "@crane/contracts/utils/collections/sets/AddressSetRepo.sol";
import {
    UniswapV4SeBufferHookLegLib
} from "contracts/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib.sol";

/**
 * @title UniswapV4StandardExchangeCurveQuadStableBufferHookTarget
 * @notice Shared book/guards/buffer helpers for 4-asset StableSwap SE buffer facets.
 * @dev No BaseHook inheritance. Fixed N=4; no weights; no partial-book KLast modes.
 *      LP via ERC20Repo; inventory = face | live SE shares; kLast = geoMean4(invWad).
 */
abstract contract UniswapV4StandardExchangeCurveQuadStableBufferHookTarget {
    using SafeERC20 for IERC20;
    using AddressSetRepo for AddressSet;

    function _exitSingleAssetFrom(address holder, address tokenOut, uint256 sharesIn, bool receiveSeShare, address to, uint256 amountOutMin)
        internal returns (uint256 amountOut)
    {
        if (to == address(0)) revert ZeroAddress();
        if (sharesIn == 0) revert ZeroAmount();
        if (!_isLive()) revert NotFullBook();
        uint8 idx = _tokenIndex(tokenOut);
        if (receiveSeShare && Repo._layout().standardExchanges[idx] == address(0)) revert SeShareNotBuffered();
        uint256 supply = _totalSupply();
        _burnLp(holder, sharesIn);
        amountOut = ClaimLib.paySingleExit(idx, sharesIn, supply, receiveSeShare, to);
        if (amountOut < amountOutMin) revert Slippage();
        _syncVaultReserves();
        emit IUniswapV4StandardExchangeCurveQuadStableBufferHook.WithdrawSingleFlexible(
            msg.sender, to, tokenOut, amountOut, receiveSeShare, sharesIn, 0
        );
    }

    address internal constant PERMIT2 = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    error ZeroAddress();
    error ZeroAmount();
    error NotPoolManager();
    error DeadlineExpired();
    error Slippage();
    error NotFullBook();
    error WouldZeroReserve();
    error SwapNotLive();
    error InvalidFeeWad();
    error RateProviderFailed();
    error InvalidPair();
    error InvalidPoolKey();
    error LiquidityNotAllowed();
    error DonateNotAllowed();
    error HookNotImplemented();
    error Reentrancy();
    error InsufficientPretransfer();
    error BufferFailed();
    error UnwrapFailed();
    error InvalidN();
    /// @notice B6: SE-share flag set on a raw (unbuffered) leg.
    error SeShareNotBuffered();
    error ArrayLengthMismatch();
    error PairAndShareSameLeg();
    error FirstJoinMustBeFullBook();
    error NotLive();

    struct JoinUnbalancedAcc {
        uint256[4] edge;
        bool[4] isSeShare;
        bool[4] filled;
        bool anySe;
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
    /*                              binding views                             */
    /* ---------------------------------------------------------------------- */

    /// @notice Fixed direct-liquidity policy selected at deployment.
    function _bindingOwnerOnlyLiquidity() internal view returns (bool) {
        return Repo._layout().ownerOnlyLiquidity;
    }

    function _bindingPoolManager() internal view returns (IPoolManager) {
        return IPoolManager(Repo._layout().poolManager);
    }

    function _bindingFeeOracle() internal view returns (IVaultFeeOracleQuery) {
        return IVaultFeeOracleQuery(Repo._layout().feeOracle);
    }

    function _bindingPermit2() internal pure returns (address) {
        return PERMIT2;
    }

    function _bindingNumTokens() internal pure returns (uint8) {
        return uint8(Repo.N_TOKENS);
    }

    function _bindingTokens() internal view returns (address[] memory out) {
        Repo.Layout storage l = Repo._layout();
        out = new address[](Repo.N_TOKENS);
        out[0] = l.tokens[0];
        out[1] = l.tokens[1];
        out[2] = l.tokens[2];
        out[3] = l.tokens[3];
    }

    function _bindingToken(uint256 index) internal view returns (address) {
        if (index >= Repo.N_TOKENS) revert InvalidN();
        return Repo._layout().tokens[index];
    }

    function _bindingBaseAmp() internal view returns (uint256) {
        return Repo._layout().baseAmp;
    }

    /// @notice Scaled amplification A' = baseAmp * AMP_PRECISION (100).
    function _bindingCurrentAmp() internal view returns (uint256) {
        return Repo._layout().baseAmp * Repo.AMP_PRECISION;
    }

    function _bindingStandardExchange(uint256 index) internal view returns (address) {
        if (index >= Repo.N_TOKENS) revert InvalidN();
        return Repo._layout().standardExchanges[index];
    }

    function _bindingRateProvider(uint256 index) internal view returns (address) {
        if (index >= Repo.N_TOKENS) revert InvalidN();
        return Repo._layout().rateProviders[index];
    }

    function _bindingIsBuffered(uint256 index) internal view returns (bool) {
        if (index >= Repo.N_TOKENS) revert InvalidN();
        return Repo._layout().standardExchanges[index] != address(0);
    }

    function _bindingInvScale(uint256 index) internal view returns (uint256) {
        if (index >= Repo.N_TOKENS) revert InvalidN();
        return Repo._layout().invScales[index];
    }

    function _bindingRatedScale(uint256 index) internal view returns (uint256) {
        if (index >= Repo.N_TOKENS) revert InvalidN();
        return Repo._layout().ratedScales[index];
    }

    function _bindingNativeReserve(uint256 index) internal view returns (uint256) {
        if (index >= Repo.N_TOKENS) revert InvalidN();
        return _nativeAt(uint8(index));
    }

    function _bindingNativeReserves() internal view returns (uint256[] memory out) {
        uint256[4] memory n = _nativeAll();
        out = Math.toDynamic(n);
    }

    function _bindingSeBalance(uint256 index) internal view returns (uint256) {
        if (index >= Repo.N_TOKENS) revert InvalidN();
        return Repo._layout().seReserves[index];
    }

    function _bindingSeClaim(uint256 index) internal view returns (uint256) {
        if (index >= Repo.N_TOKENS) revert InvalidN();
        Repo.Layout storage l = Repo._layout();
        address se = l.standardExchanges[index];
        if (se == address(0)) return 0;
        uint256 bal = l.seReserves[index];
        if (bal == 0) return 0;
        if (se == l.tokens[index]) return bal;(uint256 quotedAmountOut,) = IStandardExchangeIn(se).previewExchangeIn(IERC20(se), bal, IERC20(l.tokens[index]));
        return quotedAmountOut;
    }

    function _bindingRatedBalance(uint256 index) internal view returns (uint256) {
        if (index >= Repo.N_TOKENS) revert InvalidN();
        return _ratedPairUnits(uint8(index));
    }

    function _bindingRatedBalances() internal view returns (uint256[] memory out) {
        uint256[4] memory r;
        for (uint8 i; i < Repo.N_TOKENS; ++i) {
            r[i] = _ratedPairUnits(i);
        }
        out = Math.toDynamic(r);
    }

    function _bindingDexSwapFee() internal view returns (uint256) {
        return _bindingFeeOracle().dexSwapFeeOfVault(address(this));
    }

    function _bindingUsageFee() internal view returns (uint256) {
        return _bindingFeeOracle().usageFeeOfVault(address(this));
    }

    function _bindingFeeTo() internal view returns (address) {
        return address(_bindingFeeOracle().feeTo());
    }

    function _bindingKLast() internal view returns (uint256) {
        return Repo._layout().kLast;
    }

    function _bindingIsFullBook() internal view returns (bool) { return _isLive(); }

    function _bindingIsLive() internal view returns (bool) {
        return _isLive();
    }

    function _bindingFirstJoinMustBeFullBook() internal pure returns (bool) {
        return true;
    }

    function _bindingRequiredFirstBondTokens() internal view returns (address[] memory inputs) {
        Repo.Layout storage l = Repo._layout();
        inputs = new address[](4);
        for (uint8 i; i < 4; ++i) inputs[i] = l.standardExchanges[i] == address(0) ? l.tokens[i] : l.standardExchanges[i];
    }

    function _bindingStandardExchangeOf(address token_) internal view returns (address) {
        return Repo._layout().legs.standardExchangeOf[token_];
    }

    function _bindingSyntheticNumeraires() internal view returns (address[] memory) {
        return Repo._layout().legs.pairTokens._asArray();
    }

    function _bindingTradingFeeWad() internal view returns (uint256) {
        return _bindingDexSwapFee();
    }

    function _bindingPairDoorCount() internal pure returns (uint256) {
        return PairPoolLib.pairDoorCount();
    }

    function _ensurePairPools() internal returns (uint256 doorsEnsured) {
        Repo.Layout storage l = Repo._layout();
        IPoolManager pm = IPoolManager(l.poolManager);
        uint160 price = TickMath.getSqrtPriceAtTick(0);
        IHooks h = IHooks(address(this));
        for (uint256 i; i < Repo.N_TOKENS; ++i) {
            for (uint256 j = i + 1; j < Repo.N_TOKENS; ++j) {
                PoolKey memory key =
                    PairPoolLib.pairKey(l.tokens[i], l.tokens[j], Repo.TICK_SPACING, h);
                if (PairPoolLib.initIfNeeded(pm, key, price)) {
                    unchecked {
                        ++doorsEnsured;
                    }
                }
            }
        }
        emit IUniswapV4StandardExchangeCurveQuadStableBufferHook.PairPoolsEnsured(
            address(this), doorsEnsured
        );
    }

    /* ---------------------------------------------------------------------- */
    /*                              internal book                             */
    /* ---------------------------------------------------------------------- */

    function _poolManager() internal view returns (IPoolManager) {
        return IPoolManager(Repo._layout().poolManager);
    }

    function _feeOracle() internal view returns (IVaultFeeOracleQuery) {
        return IVaultFeeOracleQuery(Repo._layout().feeOracle);
    }

    function _onlyPoolManager() internal view {
        if (msg.sender != Repo._layout().poolManager) revert NotPoolManager();
    }

    function _requireDeadline(uint256 deadline) internal view {
        if (block.timestamp > deadline) revert DeadlineExpired();
    }

    function _tokenIndex(address t) internal view returns (uint8) {
        return Repo._indexOf(Repo._layout(), t);
    }

    function _isLive() internal view returns (bool) {
        Repo.Layout storage l = Repo._layout();
        for (uint8 i; i < 4; ++i) if (l.rawReserves[i] == 0 && l.seReserves[i] == 0) return false;
        return _totalSupply() != 0;
    }

    function _accumulateJoin(address[] memory tokensIn, uint256[] memory amounts)
        internal
        view
        returns (JoinUnbalancedAcc memory acc)
    {
        if (tokensIn.length != amounts.length || tokensIn.length == 0) {
            revert IUniswapV4StandardExchangeCurveQuadStableBufferHook.InvalidRoute();
        }
        Repo.Layout storage l = Repo._layout();
        for (uint256 i; i < tokensIn.length; ++i) {
            if (amounts[i] == 0) revert ZeroAmount();
            UniswapV4SeBufferHookLegLib.LegKind kind =
                UniswapV4SeBufferHookLegLib.classify(l.legs, tokensIn[i]);
            if (kind == UniswapV4SeBufferHookLegLib.LegKind.Unknown) {
                revert IUniswapV4StandardExchangeCurveQuadStableBufferHook.InvalidRoute();
            }
            uint8 idx;
            bool isSe;
            if (kind == UniswapV4SeBufferHookLegLib.LegKind.StandardExchange) {
                idx = _tokenIndex(l.legs.pairOfStandardExchange[tokensIn[i]]);
                isSe = true;
            } else {
                idx = _tokenIndex(tokensIn[i]);
            }
            if (acc.filled[idx]) revert PairAndShareSameLeg();
            acc.filled[idx] = true;
            acc.edge[idx] = amounts[i];
            acc.isSeShare[idx] = isSe;
            if (isSe) acc.anySe = true;
        }
    }

    function _requireFirstJoinFullBook(JoinUnbalancedAcc memory acc) internal view {
        if (_isLive()) return;
        for (uint8 i; i < Repo.N_TOKENS; ++i) {
            if (!acc.filled[i]) revert FirstJoinMustBeFullBook();
        }
    }

    function _tryResolveJoinToken(address tokenIn)
        internal
        view
        returns (bool ok, uint8 idx, bool isSeShare)
    {
        UniswapV4SeBufferHookLegLib.LegKind kind =
            UniswapV4SeBufferHookLegLib.classify(Repo._layout().legs, tokenIn);
        if (kind == UniswapV4SeBufferHookLegLib.LegKind.Unknown) {
            return (false, 0, false);
        }
        if (kind == UniswapV4SeBufferHookLegLib.LegKind.StandardExchange) {
            idx = _tokenIndex(Repo._layout().legs.pairOfStandardExchange[tokenIn]);
            return (true, idx, true);
        }
        return (true, _tokenIndex(tokenIn), false);
    }

    function _resolveJoinToken(address tokenIn) internal view returns (uint8 idx, bool isSeShare) {
        bool ok;
        (ok, idx, isSeShare) = _tryResolveJoinToken(tokenIn);
        if (!ok) revert IUniswapV4StandardExchangeCurveQuadStableBufferHook.InvalidRoute();
    }

    function _seFlags(JoinUnbalancedAcc memory acc) internal pure returns (bool[] memory flags) {
        flags = new bool[](Repo.N_TOKENS);
        for (uint8 i; i < Repo.N_TOKENS; ++i) {
            flags[i] = acc.isSeShare[i];
        }
    }

    function _tokensAmountsFromOrdered(uint256[] memory amounts)
        internal
        view
        returns (address[] memory ts, uint256[] memory am)
    {
        _requireAmountsLen4(amounts);
        address[] memory toks = _bindingTokens();
        uint256 n;
        for (uint256 i; i < Repo.N_TOKENS; ++i) {
            if (amounts[i] > 0) {
                unchecked {
                    ++n;
                }
            }
        }
        ts = new address[](n);
        am = new uint256[](n);
        uint256 w;
        for (uint256 i; i < Repo.N_TOKENS; ++i) {
            if (amounts[i] == 0) continue;
            ts[w] = toks[i];
            am[w] = amounts[i];
            unchecked {
                ++w;
            }
        }
    }

    function _amp() internal view returns (uint256) {
        return Repo._layout().baseAmp * Repo.AMP_PRECISION;
    }

    /// @dev Booked native inventory: raw tokens or SE shares, excluding ambient custody.
    function _nativeAt(uint8 i) internal view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        return l.standardExchanges[i] == address(0) ? l.rawReserves[i] : l.seReserves[i];
    }

    /// @notice Pair-token funding above the recorded native balance, excluding retained SE-leg dust.
    function _freeTokenBalance(address token_) internal view returns (uint256) {
        return _unbookedBalance(IERC20(token_));
    }

    /// @dev Reserve-delta pull (L-DETF-HOST-UPGRADE). Pull delta only on false;
    ///      pretransfer credits only pair-native funding above its recorded balance.
    function _securePull(IERC20 tokenIn, uint256 claimed, bool pretransferred)
        internal
        returns (uint256 observedDelta)
    {
        uint256 B0 = tokenIn.balanceOf(address(this));
        if (!pretransferred) {
            _pull(address(tokenIn), claimed);
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

    /// @dev Unbooked face balance available as pretransfer credit (D2/D28): raw legs book
    ///      `reserveOfToken`, buffered legs book `rawReserves[i]`.
    function _unbookedBalance(IERC20 token) internal view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        _tokenIndex(address(token));
        uint256 booked;
        for (uint8 i; i < 4; ++i) {
            if (l.tokens[i] == address(token)) booked += l.rawReserves[i];
            if (l.standardExchanges[i] == address(token)) booked += l.seReserves[i];
        }
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

    /// @dev Credit intentional raw book after funded intake (join/swap/pretransfer consume free).
    function _creditRawIntentional(uint8 i, uint256 amount) internal {
        if (amount == 0) return;
        Repo.Layout storage l = Repo._layout();
        if (l.standardExchanges[i] == address(0)) {
            l.rawReserves[i] += amount;
        }
    }

    /// @dev Debit intentional raw book on raw out (floors against live face via _nativeAt).
    function _debitRawIntentional(uint8 i, uint256 amount) internal {
        Repo._layout().rawReserves[i] -= amount;
    }

    function _nativeAll() internal view returns (uint256[4] memory out) {
        for (uint8 i; i < Repo.N_TOKENS; ++i) {
            out[i] = _nativeAt(i);
        }
    }

    /// @dev Pair-token units for swap rating (pre WAD scale). Raw = live face; SE = seBal×rate or claim.
    function _ratedPairUnits(uint8 i) internal view returns (uint256) {
        return ClaimLib.ratedPairUnits(i);
    }

    function _getRateFailClosed(address provider) internal view returns (uint256 rate) {
        (bool ok, bytes memory ret) =
            provider.staticcall(abi.encodeWithSelector(IRateProvider.getRate.selector));
        if (!ok || ret.length != 32) revert RateProviderFailed();
        rate = abi.decode(ret, (uint256));
        if (rate == 0) revert RateProviderFailed();
    }

    function _invWadAll() internal view returns (uint256[4] memory scaled) {
        Repo.Layout storage l = Repo._layout();
        for (uint8 i; i < Repo.N_TOKENS; ++i) {
            scaled[i] = Math.scaleTo(_nativeAt(i), l.invScales[i]);
        }
    }

    function _ratedWadAll() internal view returns (uint256[4] memory scaled) {
        Repo.Layout storage l = Repo._layout();
        for (uint8 i; i < Repo.N_TOKENS; ++i) {
            scaled[i] = Math.scaleTo(_ratedPairUnits(i), l.ratedScales[i]);
        }
    }

    function _scaleInv(uint256[4] memory invAmounts) internal view returns (uint256[4] memory scaled) {
        Repo.Layout storage l = Repo._layout();
        for (uint8 i; i < Repo.N_TOKENS; ++i) {
            scaled[i] = Math.scaleTo(invAmounts[i], l.invScales[i]);
        }
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

    function _feeOnAndShare() internal view returns (bool feeOn, address feeTo_, uint256 ownerFeeShare, uint256 usageFeeWad) {
        IVaultFeeOracleQuery fo = _feeOracle();
        feeTo_ = address(fo.feeTo());
        usageFeeWad = fo.usageFeeOfVault(address(this));
        feeOn = feeTo_ != address(0) && usageFeeWad != 0;
        ownerFeeShare = 0;
    }

    /// @dev Compatibility denomination for the native SY exchange-rate view, not LP issuance.
    function _rootKNow() internal view returns (uint256) {
        uint256[4] memory inv = _invWadAll();
        return Math.rootK(inv);
    }

    function _splitMintFee(uint256 gross) internal view returns (uint256 net, uint256 fee) {
        (bool active, address recipient,, uint256 percentage) = _feeOnAndShare();
        return Components.splitMintFee(gross, percentage, recipient, active);
    }

    function _mintBackedLp(address to, uint256 gross) internal returns (uint256 net, uint256 fee) {
        (net, fee) = _splitMintFee(gross);
        if (fee != 0) {
            address recipient = _bindingFeeTo();
            _mintLp(recipient, fee);
            emit IUniswapV4StandardExchangeCurveQuadStableBufferHook.ProtocolFeeMinted(recipient, fee);
        }
        _mintLp(to, net);
    }

    function _syncVaultReserves() internal {
        Repo.Layout storage l = Repo._layout();
        // Native inventory metadata is not a swap valuation and never invokes a rate provider.
        for (uint8 i; i < 4; ++i) MultiAssetBasicVaultRepo._updateReserve(IERC20(l.tokens[i]), _nativeAt(i));
    }

    function _pull(address token_, uint256 amount) internal {
        PullLib.pull(token_, msg.sender, amount);
    }

    function _pullAmounts(uint256[4] memory amounts) internal {
        Repo.Layout storage l = Repo._layout();
        for (uint8 i; i < Repo.N_TOKENS; ++i) {
            if (amounts[i] > 0) _pull(l.tokens[i], amounts[i]);
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                         buffer / unwrap (buffer-last)                  */
    /* ---------------------------------------------------------------------- */

    function _bufferToken(uint8 i, uint256 amount) internal returns (uint256 seOut) {
        if (amount == 0) return 0;
        Repo.Layout storage l = Repo._layout();
        if (l.standardExchanges[i] == address(0) || ClaimLib.disabled(i)) {
            l.rawReserves[i] += amount;
            return 0;
        }
        ExchangeInAmount.Result memory result = ClaimLib.convert(i, amount, false);
        l.seReserves[i] += result.amountOut;
        l.rawReserves[i] += result.amountRefunded;
        return result.amountOut;
    }

    function _spendableSeSharesAt(uint8 i) internal view returns (uint256) {
        return Repo._layout().seReserves[i];
    }

    function _unwrapSeShares(uint8 i, uint256 seIn, address to) internal returns (uint256 pairOut) {
        if (seIn == 0) return 0;
        Repo.Layout storage l = Repo._layout();
        l.seReserves[i] -= seIn;
        ExchangeInAmount.Result memory result = ClaimLib.convert(i, seIn, true);
        if (result.amountRefunded != 0 || result.amountOut == 0) revert UnwrapFailed();
        pairOut = result.amountOut;
        if (to != address(this)) IERC20(l.tokens[i]).safeTransfer(to, pairOut);
    }

    function _unwrapExactTokenOut(uint8 i, uint256 amountOut, address to) internal returns (uint256 seIn) {
        if (amountOut == 0) return 0;
        Repo.Layout storage l = Repo._layout();
        uint256 local = amountOut < l.rawReserves[i] ? amountOut : l.rawReserves[i];
        l.rawReserves[i] -= local;
        uint256 deficit = amountOut - local;
        if (deficit != 0) {
            address se = l.standardExchanges[i];
            seIn = IStandardExchangeOut(se).previewExchangeOut(IERC20(se), IERC20(l.tokens[i]), deficit);
            if (seIn == 0) revert IStandardExchangeOut.ExchangeOutNotAvailable();
            if (seIn > l.seReserves[i]) revert UnwrapFailed();
            uint256 received = _unwrapSeShares(i, seIn, address(this));
            if (received < deficit) revert UnwrapFailed();
            l.rawReserves[i] += received - deficit;
        }
        if (to != address(this)) IERC20(l.tokens[i]).safeTransfer(to, amountOut);
    }

    /// @dev Buffer-last: binding-index order for used pair-token amounts > 0.
    function _bufferLast(uint256[4] memory pairAmounts) internal {
        for (uint8 i; i < Repo.N_TOKENS; ++i) {
            if (pairAmounts[i] > 0) _bufferToken(i, pairAmounts[i]);
        }
    }

    /// @dev Map pair-token edge amounts → intended inventory deltas (shares for SE, face for raw).
    function _pairToInvPreview(uint256[4] memory pairAmounts)
        internal
        view
        returns (uint256[4] memory invDeltas)
    {
        Repo.Layout storage l = Repo._layout();
        for (uint8 i; i < Repo.N_TOKENS; ++i) {
            if (pairAmounts[i] == 0) continue;
            address se = l.standardExchanges[i];
            if (se == address(0) || se == l.tokens[i]) {
                invDeltas[i] = pairAmounts[i];
            } else {invDeltas[i] = ExchangeInAmount.previewOut(IStandardExchangeIn(address(IStandardExchangeIn(se))), IERC20(l.tokens[i]), pairAmounts[i], IERC20(se)
                );
            }
        }
    }

    function _invToPairOutPreview(uint256[4] memory invOut)
        internal
        view
        returns (uint256[4] memory pairOut)
    {
        Repo.Layout storage l = Repo._layout();
        for (uint8 i; i < Repo.N_TOKENS; ++i) {
            if (invOut[i] == 0) continue;
            address se = l.standardExchanges[i];
            if (se == address(0) || se == l.tokens[i]) {
                pairOut[i] = invOut[i];
            } else {pairOut[i] = ExchangeInAmount.previewOut(IStandardExchangeIn(address(IStandardExchangeIn(se))), IERC20(se), invOut[i], IERC20(l.tokens[i])
                );
            }
        }
    }

    function _requireAmountsLen4(uint256[] memory amounts) internal pure {
        if (amounts.length != Repo.N_TOKENS) revert InvalidN();
    }

    function _toFixed4(uint256[] memory a) internal pure returns (uint256[4] memory f) {
        _requireAmountsLen4(a);
        f[0] = a[0];
        f[1] = a[1];
        f[2] = a[2];
        f[3] = a[3];
    }
}
