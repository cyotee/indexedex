// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {ExchangeInAmount} from "contracts/utils/ExchangeInAmount.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
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
import {LPFeeLibrary} from "@crane/contracts/protocols/dexes/uniswap/v4/libraries/LPFeeLibrary.sol";
import {ModifyLiquidityParams, SwapParams} from
    "@crane/contracts/protocols/dexes/uniswap/v4/types/PoolOperation.sol";
import {BalanceDelta} from "@crane/contracts/protocols/dexes/uniswap/v4/types/BalanceDelta.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {UniswapV4StandardExchangeWeightedBufferHookClaimLib as ClaimLib} from
    "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookClaimLib.sol";
import {UniswapV4StandardExchangeWeightedBufferHookPullLib as PullLib} from
    "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookPullLib.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {LocalCreditLib} from "contracts/utils/LocalCreditLib.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {
    UniswapV4HookOwnerOnlyLiquidityLib
} from "contracts/hooks/uniswap/v4/libs/UniswapV4HookOwnerOnlyLiquidityLib.sol";
import {
    IUniswapV4StandardExchangeWeightedBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/interfaces/IUniswapV4StandardExchangeWeightedBufferHook.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHookRepo as Repo
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookRepo.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHookMath as Math
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookMath.sol";
import {
    UniswapV4StandardExchangeWeightedBufferHookPairPoolLib as PairPoolLib
} from "contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookPairPoolLib.sol";

/**
 * @title UniswapV4StandardExchangeWeightedBufferHookTarget
 * @notice Product logic: dual-scale weighted book, SE buffer-last LP, rated V4/SE swaps, MultiAssetLiquidity.
 * @dev No BaseHook / DeltaResolver inheritance. LP via ERC20Repo; inventory is explicitly booked shares and local pair tokens.
 */
/**
 * @title UniswapV4StandardExchangeWeightedBufferHookTarget
 * @notice Shared book/guards/buffer helpers for weighted SE buffer facets.
 */
abstract contract UniswapV4StandardExchangeWeightedBufferHookTarget {

    using SafeERC20 for IERC20;
    using LPFeeLibrary for uint24;

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
    error InvalidN();
    error InsufficientLP();
    error InsufficientPretransfer();
    error BufferFailed();
    error UnwrapFailed();
    error MaxInRatio();
    error MaxOutRatio();
    /// @notice B6: SE-share flag set on a raw (unbuffered) leg.
    error SeShareNotBuffered();
    error ArrayLengthMismatch();
    error PairAndShareSameLeg();
    error FirstJoinMustBeFullBook();
    error NotLive();

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
    function ownerOnlyLiquidity() external view returns (bool) {
        return Repo._layout().ownerOnlyLiquidity;
    }

    function _bindingPoolManager() internal view returns (IPoolManager) {
        return IPoolManager(Repo._layout().poolManager);
    }

    function feeOracle() public view returns (IVaultFeeOracleQuery) {
        return IVaultFeeOracleQuery(Repo._layout().feeOracle);
    }

    function _bindingPermit2() internal pure returns (address) {
        return PERMIT2;
    }

    function _bindingNumTokens() internal view returns (uint8) {
        return Repo._layout().numTokens;
    }

    function tokens() public view returns (address[] memory) {
        return Repo._layout().tokens;
    }

    function _bindingToken(uint256 index) internal view returns (address) {
        return Repo._layout().tokens[index];
    }

    function _bindingWeights() internal view returns (uint256[] memory) {
        return Repo._layout().weights;
    }

    function _bindingWeight(uint256 index) internal view returns (uint256) {
        return Repo._layout().weights[index];
    }

    function _bindingStandardExchange(uint256 index) internal view returns (address) {
        return Repo._layout().standardExchanges[index];
    }

    function _bindingRateProvider(uint256 index) internal view returns (address) {
        return Repo._layout().rateProviders[index];
    }

    function _bindingIsBuffered(uint256 index) internal view returns (bool) {
        return Repo._layout().standardExchanges[index] != address(0);
    }

    function _bindingInvScale(uint256 index) internal view returns (uint256) {
        return Repo._layout().invScales[index];
    }

    function _bindingRatedScale(uint256 index) internal view returns (uint256) {
        return Repo._layout().ratedScales[index];
    }

    function _bindingNativeReserve(uint256 index) internal view returns (uint256) {
        return _nativeAt(uint8(index));
    }

    function _bindingNativeReserves() internal view returns (uint256[] memory out) {
        Repo.Layout storage l = Repo._layout();
        out = new uint256[](l.numTokens);
        for (uint8 i; i < l.numTokens; ++i) {
            out[i] = _nativeAt(i);
        }
    }

    function _bindingSeBalance(uint256 index) internal view returns (uint256) {
        address se = Repo._layout().standardExchanges[index];
        if (se == address(0)) return 0;
        return Repo._layout().seReserves[index];
    }

    function _bindingSeClaim(uint256 index) internal view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        address se = l.standardExchanges[index];
        if (se == address(0)) return 0;
        uint256 bal = l.seReserves[index];
        if (bal == 0) return 0;
        if (se == l.tokens[index]) return bal;(uint256 quotedAmountOut,) = IStandardExchangeIn(se).previewExchangeIn(IERC20(se), bal, IERC20(l.tokens[index]));
        return quotedAmountOut;
    }

    function _bindingRatedBalance(uint256 index) internal view returns (uint256) {
        return _ratedPairUnits(uint8(index));
    }

    function _bindingRatedBalances() internal view returns (uint256[] memory out) {
        Repo.Layout storage l = Repo._layout();
        out = new uint256[](l.numTokens);
        for (uint8 i; i < l.numTokens; ++i) {
            out[i] = _ratedPairUnits(i);
        }
    }

    function dexSwapFee() public view returns (uint256) {
        return feeOracle().dexSwapFeeOfVault(address(this));
    }

    function usageFee() public view returns (uint256) {
        return feeOracle().usageFeeOfVault(address(this));
    }

    function feeTo() public view returns (address) {
        return address(feeOracle().feeTo());
    }

    function _bindingKLast() internal view returns (uint256) {
        return Repo._layout().kLast;
    }

    function kLastMode() public view returns (IUniswapV4StandardExchangeWeightedBufferHook.KLastMode) {
        return IUniswapV4StandardExchangeWeightedBufferHook.KLastMode(Repo._layout().kLastMode);
    }

    function isFullBook() public view returns (bool) {
        Repo.Layout storage l = Repo._layout();
        for (uint8 i; i < l.numTokens; ++i) if (l.rawReserves[i] == 0 && l.seReserves[i] == 0) return false;
        return true;
    }

    function isLive() public view returns (bool) {
        return _isLive();
    }

    function firstJoinMustBeFullBook() public pure returns (bool) {
        return true;
    }

    function requiredFirstBondTokens() public view returns (address[] memory) {
        return tokens();
    }

    function standardExchangeOf(address query) public view returns (address) {
        return Repo._layout().legs.standardExchangeOf[query];
    }

    function syntheticNumeraires() public view returns (address[] memory n) {
        Repo.Layout storage l = Repo._layout();
        address detf_ = l.legs.detfToken;
        uint8 m = l.numTokens;
        uint256 count;
        for (uint8 i; i < m; ++i) {
            if (l.tokens[i] != detf_) ++count;
        }
        n = new address[](count);
        uint256 k;
        for (uint8 i; i < m; ++i) {
            if (l.tokens[i] != detf_) n[k++] = l.tokens[i];
        }
    }

    function tradingFeeWad() public view returns (uint256) {
        return dexSwapFee();
    }

    function pairDoorCount() public view returns (uint256) {
        return PairPoolLib.pairDoorCount(Repo._layout().numTokens);
    }

    function _ensurePairPools() internal returns (uint256 doorsEnsured) {
        Repo.Layout storage l = Repo._layout();
        doorsEnsured = PairPoolLib.ensureAllPairPools(
            IPoolManager(l.poolManager), address(this), l.tokens, 0
        );
        emit IUniswapV4StandardExchangeWeightedBufferHook.PairPoolsEnsured(address(this), doorsEnsured);
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

    function _nativeAt(uint8 i) internal view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        address se = l.standardExchanges[i];
        if (se == address(0)) return l.rawReserves[i];
        return l.seReserves[i];
    }

    function _nativeAll() internal view returns (uint256[] memory out) {
        Repo.Layout storage l = Repo._layout();
        out = new uint256[](l.numTokens);
        for (uint8 i; i < l.numTokens; ++i) {
            out[i] = _nativeAt(i);
        }
    }

    /// @dev Pair-token units for swap rating (pre WAD scale).
    function _ratedPairUnits(uint8 i) internal view returns (uint256) {
        return ClaimLib.ratedPairUnits(i);
    }

    function _getRateFailClosed(address provider) internal view returns (uint256 rate) {
        return ClaimLib.getRateFailClosed(provider);
    }

    function _invWadAll() internal view returns (uint256[] memory scaled) {
        Repo.Layout storage l = Repo._layout();
        scaled = new uint256[](l.numTokens);
        for (uint8 i; i < l.numTokens; ++i) {
            scaled[i] = Math.scaleTo(_nativeAt(i), l.invScales[i]);
        }
    }

    function _ratedWadAll() internal view returns (uint256[] memory scaled) {
        Repo.Layout storage l = Repo._layout();
        scaled = new uint256[](l.numTokens);
        for (uint8 i; i < l.numTokens; ++i) {
            scaled[i] = Math.scaleTo(_ratedPairUnits(i), l.ratedScales[i]);
        }
    }

    function _scaleInvAmounts(uint256[] memory invAmounts) internal view returns (uint256[] memory scaled) {
        Repo.Layout storage l = Repo._layout();
        scaled = new uint256[](l.numTokens);
        for (uint8 i; i < l.numTokens; ++i) {
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

    function _isLive() internal view returns (bool) { return _totalSupply() > 0 && isFullBook(); }

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



    function _measureK() internal view returns (uint8 mode, uint256 k, uint256 rootK) {
        return _measureK(_invWadAll());
    }

    function _measureK(uint256[] memory inv) internal view returns (uint8 mode, uint256 k, uint256 rootK) {
        if (Math.isFullBookReserves(inv)) {
            mode = 0;
            k = Math.computeV(Repo._layout().weights, inv);
            rootK = k;
        } else {
            mode = 1;
            k = Math.computeInterimK(Repo._layout().weights, inv);
            rootK = k;
        }
    }





    function _syncVaultReserves() internal {
        Repo.Layout storage l = Repo._layout();
        for (uint8 i; i < l.numTokens; ++i) {
            MultiAssetBasicVaultRepo._updateReserve(IERC20(l.tokens[i]), _nativeAt(i));
        }
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
        uint8 i = _tokenIndex(address(token));
        uint256 R = l.standardExchanges[i] == address(0)
            ? MultiAssetBasicVaultRepo._reserveOfToken(address(token)) : l.rawReserves[i];
        return LocalCreditLib.available(token.balanceOf(address(this)), R);
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

    function _pull(address token_, uint256 amount) internal {
        PullLib.pull(token_, msg.sender, amount);
    }

    function _pullAmounts(uint256[] memory amounts) internal {
        Repo.Layout storage l = Repo._layout();
        for (uint8 i; i < l.numTokens; ++i) {
            if (amounts[i] > 0) _pull(l.tokens[i], amounts[i]);
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                         buffer / unwrap (D29)                          */
    /* ---------------------------------------------------------------------- */

    function _bufferToken(uint8 i, uint256 amount) internal returns (uint256) {
        return ClaimLib.bufferPool(i, amount);
    }

    function _unwrapSeShares(uint8 i, uint256 seIn, address to) internal returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        l.seReserves[i] -= seIn;
        return ClaimLib.unwrap(l.standardExchanges[i], l.tokens[i], seIn, to);
    }

    function _unwrapExactTokenOut(uint8 i, uint256 amountOut, address to) internal returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        return ClaimLib.unwrapExactTokenOut(l.standardExchanges[i], l.tokens[i], amountOut, to);
    }

    /// @dev Buffer-last: binding-index order for used pair-token amounts > 0.
    function _bufferLast(uint256[] memory pairAmounts) internal {
        Repo.Layout storage l = Repo._layout();
        for (uint8 i; i < l.numTokens; ++i) {
            if (pairAmounts[i] > 0) _bufferToken(i, pairAmounts[i]);
        }
    }

    /// @dev Map pair-token edge amounts → intended inventory deltas (shares for SE, face for raw).
    function _pairToInvPreview(uint256[] memory pairAmounts)
        internal
        view
        returns (uint256[] memory invDeltas)
    {
        Repo.Layout storage l = Repo._layout();
        invDeltas = new uint256[](l.numTokens);
        for (uint8 i; i < l.numTokens; ++i) {
            if (pairAmounts[i] == 0) continue;
            address se = l.standardExchanges[i];
            if (se == address(0) || se == l.tokens[i]) {
                invDeltas[i] = pairAmounts[i];
            } else {invDeltas[i] = ExchangeInAmount.previewOut(IStandardExchangeIn(address(IStandardExchangeIn(se))), IERC20(l.tokens[i]), pairAmounts[i], IERC20(se)
                );
            }
        }
    }

    }
