// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

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
import {IRateProvider} from
    "@crane/contracts/protocols/dexes/balancer/common/interfaces/IRateProvider.sol";
import {IAllowanceTransfer} from
    "@crane/contracts/interfaces/protocols/utils/permit2/IAllowanceTransfer.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
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
 * @dev No BaseHook / DeltaResolver inheritance. LP via ERC20Repo; inventory = face | live SE shares.
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

    modifier onlyLiquidityOwner() {
        UniswapV4HookOwnerOnlyLiquidityLib.enforce(Repo._layout().ownerOnlyLiquidity);
        _;
    }

    /* ---------------------------------------------------------------------- */
    /*                              binding views                             */
    /* ---------------------------------------------------------------------- */

    function poolManager() public view returns (IPoolManager) {
        return IPoolManager(Repo._layout().poolManager);
    }

    function feeOracle() public view returns (IVaultFeeOracleQuery) {
        return IVaultFeeOracleQuery(Repo._layout().feeOracle);
    }

    function permit2() public pure returns (address) {
        return PERMIT2;
    }

    function numTokens() public view returns (uint8) {
        return Repo._layout().numTokens;
    }

    function tokens() public view returns (address[] memory) {
        return Repo._layout().tokens;
    }

    function token(uint256 index) public view returns (address) {
        return Repo._layout().tokens[index];
    }

    function getNormalizedWeights() public view returns (uint256[] memory) {
        return Repo._layout().weights;
    }

    function weight(uint256 index) public view returns (uint256) {
        return Repo._layout().weights[index];
    }

    function standardExchange(uint256 index) public view returns (address) {
        return Repo._layout().standardExchanges[index];
    }

    function rateProvider(uint256 index) public view returns (address) {
        return Repo._layout().rateProviders[index];
    }

    function isBuffered(uint256 index) public view returns (bool) {
        return Repo._layout().standardExchanges[index] != address(0);
    }

    function invScale(uint256 index) public view returns (uint256) {
        return Repo._layout().invScales[index];
    }

    function ratedScale(uint256 index) public view returns (uint256) {
        return Repo._layout().ratedScales[index];
    }

    function nativeReserve(uint256 index) public view returns (uint256) {
        return _nativeAt(uint8(index));
    }

    function nativeReserves() public view returns (uint256[] memory out) {
        Repo.Layout storage l = Repo._layout();
        out = new uint256[](l.numTokens);
        for (uint8 i; i < l.numTokens; ++i) {
            out[i] = _nativeAt(i);
        }
    }

    function seBalance(uint256 index) public view returns (uint256) {
        address se = Repo._layout().standardExchanges[index];
        if (se == address(0)) return 0;
        return IERC20(se).balanceOf(address(this));
    }

    function seClaim(uint256 index) public view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        address se = l.standardExchanges[index];
        if (se == address(0)) return 0;
        uint256 bal = IERC20(se).balanceOf(address(this));
        if (bal == 0) return 0;
        return IStandardExchangeIn(se).previewExchangeIn(IERC20(se), bal, IERC20(l.tokens[index]));
    }

    function ratedBalance(uint256 index) public view returns (uint256) {
        return _ratedPairUnits(uint8(index));
    }

    function ratedBalances() public view returns (uint256[] memory out) {
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

    function kLast() public view returns (uint256) {
        return Repo._layout().kLast;
    }

    function kLastMode() public view returns (IUniswapV4StandardExchangeWeightedBufferHook.KLastMode) {
        return IUniswapV4StandardExchangeWeightedBufferHook.KLastMode(Repo._layout().kLastMode);
    }

    function isFullBook() public view returns (bool) {
        return Math.isFullBookReserves(_nativeAll());
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

    function ensurePairPools() external returns (uint256 doorsEnsured) {
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
        return IERC20(se).balanceOf(address(this));
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
        Repo.Layout storage l = Repo._layout();
        address se = l.standardExchanges[i];
        if (se == address(0)) {
            return l.rawReserves[i];
        }
        uint256 seBal = IERC20(se).balanceOf(address(this));
        if (seBal == 0) return 0;
        address rp = l.rateProviders[i];
        if (rp != address(0)) {
            uint256 rate = _getRateFailClosed(rp);
            return (seBal * rate) / Math.RATE_PRECISION;
        }
        return IStandardExchangeIn(se).previewExchangeIn(IERC20(se), seBal, IERC20(l.tokens[i]));
    }

    function _getRateFailClosed(address provider) internal view returns (uint256 rate) {
        (bool ok, bytes memory ret) =
            provider.staticcall(abi.encodeWithSelector(IRateProvider.getRate.selector));
        if (!ok || ret.length != 32) revert RateProviderFailed();
        rate = abi.decode(ret, (uint256));
        if (rate == 0) revert RateProviderFailed();
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

    function _isLive() internal view returns (bool) {
        return _totalSupply() > 0 && Math.isFullBookReserves(_nativeAll());
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

    function _feeOnAndShare()
        internal
        view
        returns (bool feeOn, address feeTo_, uint256 ownerFeeShare, uint256 usageFeeWad)
    {
        IVaultFeeOracleQuery fo = _feeOracle();
        feeTo_ = address(fo.feeTo());
        usageFeeWad = fo.usageFeeOfVault(address(this));
        ownerFeeShare = (usageFeeWad * Repo.FEE_DENOMINATOR) / Math.WAD;
        feeOn = feeTo_ != address(0) && usageFeeWad != 0 && usageFeeWad < Math.WAD
            && ownerFeeShare != 0;
    }

    function _measureK() internal view returns (uint8 mode, uint256 k, uint256 rootK) {
        uint256[] memory inv = _invWadAll();
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

    function _maybeMintProtocolFee() internal returns (uint256 protocolLp) {
        (bool feeOn, address feeTo_, uint256 ownerFeeShare,) = _feeOnAndShare();
        Repo.Layout storage l = Repo._layout();
        if (!feeOn || l.kLast == 0) return 0;
        (uint8 mode,, uint256 rootK) = _measureK();
        if (mode != l.kLastMode) return 0;
        protocolLp = Math.protocolLpShares(_totalSupply(), rootK, l.kLast, ownerFeeShare);
        if (protocolLp > 0) {
            _mintLp(feeTo_, protocolLp);
            emit IUniswapV4StandardExchangeWeightedBufferHook.ProtocolFeeMinted(feeTo_, protocolLp);
        }
    }

    function _snapshotKLastIfFeeOn() internal {
        (bool feeOn,,,) = _feeOnAndShare();
        Repo.Layout storage l = Repo._layout();
        if (!feeOn) {
            l.kLast = 0;
            return;
        }
        (uint8 mode, uint256 k,) = _measureK();
        l.kLast = k;
        l.kLastMode = mode;
    }

    function _syncVaultReserves() internal {
        Repo.Layout storage l = Repo._layout();
        for (uint8 i; i < l.numTokens; ++i) {
            MultiAssetBasicVaultRepo._updateReserve(IERC20(l.tokens[i]), _nativeAt(i));
        }
    }

    /// @dev Reserve-delta pull (L-DETF-HOST-UPGRADE). Pull delta only on false;
    ///      pretransfer credits claimed iff claimed <= U (face surplus; virtual R > B → U = face).
    function _securePull(IERC20 tokenIn, uint256 claimed, bool pretransferred)
        internal
        returns (uint256 observedDelta)
    {
        uint256 B0 = tokenIn.balanceOf(address(this));
        if (!pretransferred) {
            _pull(address(tokenIn), claimed);
            return tokenIn.balanceOf(address(this)) - B0;
        }
        uint256 R = MultiAssetBasicVaultRepo._reserveOfToken(address(tokenIn));
        uint256 U = B0 >= R ? B0 - R : B0;
        if (claimed > U) {
            revert ISecurePullErrors.TransferDeltaInsufficient(claimed, U);
        }
        return claimed;
    }

    function _pull(address token_, uint256 amount) internal {
        if (amount == 0) return;
        uint256 allowance = IERC20(token_).allowance(msg.sender, address(this));
        if (allowance >= amount) {
            IERC20(token_).safeTransferFrom(msg.sender, address(this), amount);
        } else {
            IAllowanceTransfer(PERMIT2).transferFrom(
                msg.sender, address(this), uint160(amount), token_
            );
        }
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

    function _bufferToken(uint8 i, uint256 amount) internal returns (uint256 seOut) {
        if (amount == 0) return 0;
        Repo.Layout storage l = Repo._layout();
        address se = l.standardExchanges[i];
        address t = l.tokens[i];
        if (se == address(0)) {
            l.rawReserves[i] += amount;
            return 0;
        }
        uint256 minOut = IStandardExchangeIn(se).previewExchangeIn(IERC20(t), amount, IERC20(se));
        if (minOut == 0) revert BufferFailed();
        IERC20(t).forceApprove(se, amount);
        seOut = IStandardExchangeIn(se).exchangeIn(
            IERC20(t), amount, IERC20(se), minOut, address(this), false, block.timestamp
        );
        if (seOut < minOut) revert BufferFailed();
    }

    function _unwrapSeShares(uint8 i, uint256 seIn, address to) internal returns (uint256 pairOut) {
        if (seIn == 0) return 0;
        Repo.Layout storage l = Repo._layout();
        address se = l.standardExchanges[i];
        address t = l.tokens[i];
        uint256 minOut = IStandardExchangeIn(se).previewExchangeIn(IERC20(se), seIn, IERC20(t));
        if (minOut == 0) revert UnwrapFailed();
        IERC20(se).forceApprove(se, seIn);
        pairOut = IStandardExchangeIn(se).exchangeIn(
            IERC20(se), seIn, IERC20(t), minOut, to, false, block.timestamp
        );
        if (pairOut < minOut) revert UnwrapFailed();
    }

    function _unwrapExactTokenOut(uint8 i, uint256 amountOut, address to)
        internal
        returns (uint256 seIn)
    {
        if (amountOut == 0) return 0;
        Repo.Layout storage l = Repo._layout();
        address se = l.standardExchanges[i];
        address t = l.tokens[i];
        seIn = IStandardExchangeOut(se).previewExchangeOut(IERC20(se), IERC20(t), amountOut);
        IERC20(se).forceApprove(se, seIn);
        uint256 got = IStandardExchangeOut(se).exchangeOut(
            IERC20(se), seIn, IERC20(t), amountOut, to, false, block.timestamp
        );
        if (got < amountOut) revert UnwrapFailed();
    }

    /// @dev Buffer-last: binding-index order for used pair-token amounts > 0.
    function _bufferLast(uint256[] memory pairAmounts) internal {
        Repo.Layout storage l = Repo._layout();
        for (uint8 i; i < l.numTokens; ++i) {
            if (pairAmounts[i] > 0) _bufferToken(i, pairAmounts[i]);
        }
    }

    function _refundBufferedDust() internal {
        Repo.Layout storage l = Repo._layout();
        address to = msg.sender;
        for (uint8 i; i < l.numTokens; ++i) {
            address se = l.standardExchanges[i];
            if (se == address(0)) continue;
            IERC20 pair_ = IERC20(l.tokens[i]);
            uint256 bal = pair_.balanceOf(address(this));
            if (bal <= Repo.MAX_DUST_WEI) continue;
            uint256 excess = bal - Repo.MAX_DUST_WEI;
            uint256 preview = IStandardExchangeIn(se).previewExchangeIn(pair_, excess, IERC20(se));
            if (preview > 0) {
                _bufferToken(i, excess);
                bal = pair_.balanceOf(address(this));
                if (bal <= Repo.MAX_DUST_WEI) continue;
                excess = bal - Repo.MAX_DUST_WEI;
            }
            if (to == address(0) || to == address(this)) continue;
            pair_.safeTransfer(to, excess);
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
            if (se == address(0)) {
                invDeltas[i] = pairAmounts[i];
            } else {
                invDeltas[i] = IStandardExchangeIn(se).previewExchangeIn(
                    IERC20(l.tokens[i]), pairAmounts[i], IERC20(se)
                );
            }
        }
    }

    }
