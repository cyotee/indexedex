// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {UniswapV4BufferHookLiquidityRouteLib as Components} from "contracts/hooks/uniswap/v4/libs/UniswapV4BufferHookLiquidityRouteLib.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {ExchangeInAmount} from "contracts/utils/ExchangeInAmount.sol";

import {UniswapV4StandardExchangeBalancerQuadStableBufferHookClaimLib as ClaimLib} from "./UniswapV4StandardExchangeBalancerQuadStableBufferHookClaimLib.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {FixedPointMathLib} from "@crane/contracts/utils/FixedPointMathLib.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IRateProvider} from
    "@crane/contracts/protocols/dexes/balancer/common/interfaces/IRateProvider.sol";
import {IAllowanceTransfer} from
    "@crane/contracts/interfaces/protocols/utils/permit2/IAllowanceTransfer.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {LocalCreditLib} from "contracts/utils/LocalCreditLib.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {
    IUniswapV4StandardExchangeBalancerQuadStableBufferHook
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/interfaces/IUniswapV4StandardExchangeBalancerQuadStableBufferHook.sol";
import {
    UniswapV4StandardExchangeBalancerQuadStableBufferHookRepo as Repo
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookRepo.sol";
import {
    UniswapV4StandardExchangeBalancerQuadStableBufferHookMath as Math
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookMath.sol";
import {
    UniswapV4StandardExchangeBalancerQuadStableBufferHookPairPoolLib as PairPoolLib
} from "contracts/hooks/uniswap/v4/standardExchange/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookPairPoolLib.sol";

/**
 * @title UniswapV4StandardExchangeBalancerQuadStableBufferHookTarget
 * @notice Shared book/guards/buffer helpers for 2–5 asset Balancer StableMath SE buffer facets.
 * @dev No BaseHook inheritance. Immutable active token count; no weights; no partial-book KLast modes.
 *      LP via ERC20Repo; ownership uses booked native components; swaps use local plus rated shares.
 */
abstract contract UniswapV4StandardExchangeBalancerQuadStableBufferHookTarget {
    using SafeERC20 for IERC20;

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
    error InvalidTransferAmount();
    error LiquidityValueLoss();

    modifier nonReentrant() {
        Repo.Layout storage l = Repo._layout();
        if (l.reentrancyStatus == Repo.ENTERED) revert Reentrancy();
        l.reentrancyStatus = Repo.ENTERED;
        _;
        l.reentrancyStatus = Repo.NOT_ENTERED;
    }

    /* ---------------------------------------------------------------------- */
    /*                              binding views                             */
    /* ---------------------------------------------------------------------- */

    function _bindingPoolManager() internal view returns (IPoolManager) {
        return IPoolManager(Repo._layout().poolManager);
    }

    function _bindingFeeOracle() internal view returns (IVaultFeeOracleQuery) {
        return IVaultFeeOracleQuery(Repo._layout().feeOracle);
    }

    function _bindingPermit2() internal pure returns (address) {
        return PERMIT2;
    }

    function _bindingNumTokens() internal view returns (uint8) {
        return uint8(Repo._numTokens());
    }

    function _bindingTokens() internal view returns (address[] memory) {
        return Repo._layout().tokens;
    }

    function _bindingToken(uint256 index) internal view returns (address) {
        if (index >= Repo._numTokens()) revert InvalidN();
        return Repo._layout().tokens[index];
    }

    function _bindingBaseAmp() internal view returns (uint256) {
        return Repo._layout().baseAmp;
    }

    /// @notice Scaled amplification A' = baseAmp * AMP_PRECISION (1e3).
    function _bindingCurrentAmp() internal view returns (uint256) {
        return Repo._layout().baseAmp * Repo.AMP_PRECISION;
    }

    function _bindingStandardExchange(uint256 index) internal view returns (address) {
        if (index >= Repo._numTokens()) revert InvalidN();
        return Repo._layout().standardExchanges[index];
    }

    function _bindingRateProvider(uint256 index) internal view returns (address) {
        if (index >= Repo._numTokens()) revert InvalidN();
        return Repo._layout().rateProviders[index];
    }

    function _bindingIsBuffered(uint256 index) internal view returns (bool) {
        if (index >= Repo._numTokens()) revert InvalidN();
        return Repo._layout().standardExchanges[index] != address(0);
    }

    function _bindingInvScale(uint256 index) internal view returns (uint256) {
        if (index >= Repo._numTokens()) revert InvalidN();
        return Repo._layout().invScales[index];
    }

    function _bindingRatedScale(uint256 index) internal view returns (uint256) {
        if (index >= Repo._numTokens()) revert InvalidN();
        return Repo._layout().ratedScales[index];
    }

    function _bindingNativeReserve(uint256 index) internal view returns (uint256) {
        if (index >= Repo._numTokens()) revert InvalidN();
        return _nativeAt(uint8(index));
    }

    function _bindingNativeReserves() internal view returns (uint256[] memory out) {
        uint256[] memory n = _nativeAll();
        out = Math.toDynamic(n);
    }

    function _bindingSeBalance(uint256 index) internal view returns (uint256) {
        if (index >= Repo._numTokens()) revert InvalidN();
        address se = Repo._layout().standardExchanges[index];
        if (se == address(0)) return 0;
        return Repo._layout().seReserves[index];
    }

    function _bindingSeClaim(uint256 index) internal view returns (uint256) {
        if (index >= Repo._numTokens()) revert InvalidN();
        Repo.Layout storage l = Repo._layout();
        address se = l.standardExchanges[index];
        if (se == address(0)) return 0;
        uint256 bal = l.seReserves[index];
        if (bal == 0) return 0;
        if (se == l.tokens[index]) return bal;(uint256 quotedAmountOut,) = IStandardExchangeIn(se).previewExchangeIn(IERC20(se), bal, IERC20(l.tokens[index]));
        return quotedAmountOut;
    }

    function _bindingRatedBalance(uint256 index) internal view returns (uint256) {
        if (index >= Repo._numTokens()) revert InvalidN();
        return _ratedPairUnits(uint8(index));
    }

    function _bindingRatedBalances() internal view returns (uint256[] memory out) {
        uint256[] memory r = new uint256[](Repo._numTokens());
        for (uint8 i; i < Repo._numTokens(); ++i) {
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

    function _bindingKLast() internal pure returns (uint256) { return 0; }

    function _bindingIsFullBook() internal view returns (bool) {
        Repo.Layout storage l = Repo._layout();
        for (uint256 i; i < l.tokens.length; ++i) {
            if (l.rawReserves[i] == 0 && l.seReserves[i] == 0) return false;
        }
        return true;
    }

    function _bindingPairDoorCount() internal view returns (uint256) {
        return PairPoolLib.pairDoorCount(Repo._numTokens());
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

    /// @notice B6: resolve pair token **or** its SE vault share for a buffered leg.
    /// @return idx Book index
    /// @return seUnit True when `t` is the SE share (inventory unit); false for pair face.
    function _indexOfPairOrSe(address t) internal view returns (uint8 idx, bool seUnit) {
        Repo.Layout storage l = Repo._layout();
        for (uint8 i; i < Repo._numTokens(); ++i) {
            if (l.tokens[i] == t) return (i, false);
            if (l.standardExchanges[i] != address(0) && l.standardExchanges[i] == t) {
                return (i, true);
            }
        }
        revert("token");
    }

    function _amp() internal view returns (uint256) {
        return Repo._layout().baseAmp * Repo.AMP_PRECISION;
    }

    /// @dev Native booked inventory, excluding pending caller funds and ambient custody.
    function _nativeAt(uint8 i) internal view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        return l.standardExchanges[i] == address(0) ? l.rawReserves[i] : l.seReserves[i];
    }

    /// @notice Pair-token funding above the recorded native balance, excluding retained SE-leg dust.
    function _freeTokenBalance(address token_) internal view returns (uint256 free) {
        uint8 i = _tokenIndex(token_);
        Repo.Layout storage l = Repo._layout();
        uint256 bal = IERC20(token_).balanceOf(address(this));
        uint256 book = l.rawReserves[i];
        return bal > book ? bal - book : 0;
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
        uint256 U = _freeTokenBalance(address(tokenIn));
        if (claimed > U) {
            revert ISecurePullErrors.TransferDeltaInsufficient(claimed, U);
        }
        return claimed;
    }

    /// @dev Exact-out input (D15): false-flag pulls `used` and refunds nothing. True-flag credits
    ///      `budget(available, maxAmountIn)` and refunds `credit - used` to `msg.sender` only.
    function _pullExactOutInput(IERC20 token, uint256 used, uint256 maxAmountIn, bool pretransferred)
        internal
    {
        _securePull(token, used, pretransferred);
        if (!pretransferred) return;
        uint256 credit = LocalCreditLib.budget(_freeTokenBalance(address(token)), maxAmountIn);
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

    function _nativeAll() internal view returns (uint256[] memory out) {
        out = new uint256[](Repo._numTokens());
        for (uint8 i; i < Repo._numTokens(); ++i) {
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

    function _ratedWadAll() internal view returns (uint256[] memory scaled) {
        scaled = new uint256[](Repo._numTokens());
        Repo.Layout storage l = Repo._layout();
        for (uint8 i; i < Repo._numTokens(); ++i) {
            scaled[i] = Math.scaleTo(_ratedPairUnits(i), l.ratedScales[i]);
        }
    }

    /// @dev Liquidity and swaps use the same SE-valued book. Physical ownership remains in native inventory units.






    /// @dev Rate-free D(retained native inventory)/n with the existing inventory normalization.
    function _initialLiquidityValues(uint256[] memory inventory, bool[] memory)
        internal view returns (uint256[] memory values)
    {
        Repo.Layout storage l = Repo._layout();
        values = new uint256[](inventory.length);
        for (uint8 i; i < inventory.length; ++i) values[i] = Math.scaleTo(inventory[i], l.invScales[i]);
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

    /// @dev StableMath D of the SE-valued book, normalized by active token count.
    function _rootKNow() internal view returns (uint256) {
        uint256[] memory inv = _ratedWadAll();
        if (!Math.isFullBookReserves(inv)) return 0;
        return Math.rootK(inv, _amp());
    }

    /// @dev Revalue both checkpoint and current inventory at the same SE rates; passive yield alone is not fee growth.




    /// @dev Supply after simulating protocol growth mint (for LP previews under fee-on).




    function _syncVaultReserves() internal {
        Repo.Layout storage l = Repo._layout();
        for (uint8 i; i < l.tokens.length; ++i) {
            MultiAssetBasicVaultRepo._updateReserve(IERC20(l.tokens[i]), _ratedPairUnits(i));
        }
    }

    function _pull(address token_, uint256 amount) internal {
        if (amount == 0) return;
        uint256 beforeBalance = IERC20(token_).balanceOf(address(this));
        uint256 allowance = IERC20(token_).allowance(msg.sender, address(this));
        if (allowance >= amount) {
            IERC20(token_).safeTransferFrom(msg.sender, address(this), amount);
        } else {
            if (amount > type(uint160).max) revert InvalidTransferAmount();
            IAllowanceTransfer(PERMIT2).transferFrom(msg.sender, address(this), uint160(amount), token_);
        }
        if (IERC20(token_).balanceOf(address(this)) - beforeBalance != amount) revert InvalidTransferAmount();
    }

    function _pullAmounts(uint256[] memory amounts) internal {
        Repo.Layout storage l = Repo._layout();
        for (uint8 i; i < Repo._numTokens(); ++i) {
            if (amounts[i] > 0) _pull(l.tokens[i], amounts[i]);
        }
    }

    /* ---------------------------------------------------------------------- */
    /*                         buffer / unwrap (buffer-last)                  */
    /* ---------------------------------------------------------------------- */

    function _bufferToken(uint8 i, uint256 amount) internal returns (uint256 seOut) {
        if (amount == 0) return 0;
        Repo.Layout storage l = Repo._layout();
        if (l.standardExchanges[i] == address(0) || _disabled(i)) {
            l.rawReserves[i] += amount;
            return 0;
        }
        ExchangeInAmount.Result memory receipt = _convert(i, false, amount);
        l.seReserves[i] += receipt.amountOut;
        l.rawReserves[i] += receipt.amountRefunded;
        return receipt.amountOut;
    }

    function _unwrapSeShares(uint8 i, uint256 seIn, address to) internal returns (uint256 pairOut) {
        if (seIn == 0) return 0;
        Repo.Layout storage l = Repo._layout();
        l.seReserves[i] -= seIn;
        ExchangeInAmount.Result memory receipt = _convert(i, true, seIn);
        if (receipt.amountRefunded != 0 || receipt.amountOut == 0) revert UnwrapFailed();
        pairOut = receipt.amountOut;
        if (to != address(this)) IERC20(l.tokens[i]).safeTransfer(to, pairOut);
    }

    function _unwrapExactTokenOut(uint8 i, uint256 amountOut, address to) internal returns (uint256 seIn) {
        Repo.Layout storage l = Repo._layout();
        uint256 local = amountOut < l.rawReserves[i] ? amountOut : l.rawReserves[i];
        l.rawReserves[i] -= local;
        uint256 deficit = amountOut - local;
        if (deficit != 0) {
            address se = l.standardExchanges[i];
            IERC20 pair = IERC20(l.tokens[i]);
            seIn = IStandardExchangeOut(se).previewExchangeOut(IERC20(se), pair, deficit);
            if (seIn == 0) revert IStandardExchangeOut.ExchangeOutNotAvailable();
            if (seIn > l.seReserves[i]) revert WouldZeroReserve();
            uint256 beforeShares = IERC20(se).balanceOf(address(this));
            uint256 beforePair = pair.balanceOf(address(this));
            IERC20(se).forceApprove(se, seIn);
            uint256 spent = IStandardExchangeOut(se).exchangeOut(IERC20(se), seIn, pair, deficit, address(this), false, block.timestamp);
            IERC20(se).forceApprove(se, 0);
            uint256 received = pair.balanceOf(address(this)) - beforePair;
            if (spent > seIn || beforeShares - IERC20(se).balanceOf(address(this)) != spent || received < deficit) revert UnwrapFailed();
            l.seReserves[i] -= spent;
            l.rawReserves[i] += received - deficit;
            seIn = spent;
        }
        if (to != address(this)) IERC20(l.tokens[i]).safeTransfer(to, amountOut);
    }

    function _disabled(uint8 i) internal view returns (bool) { return ClaimLib.disabled(i); }

    /// @dev Only the explicitly attributed amount is converted. No book is changed here.
    function _convert(uint8 i, bool redeem, uint256 amount) internal returns (ExchangeInAmount.Result memory receipt) {
        return ClaimLib.convert(i, redeem, amount);
    }

    function _previewMint(uint256 gross) internal view returns (uint256 net, uint256 fee) {
        (bool active, address recipient,, uint256 percentage) = _feeOnAndShare();
        return Components.splitMintFee(gross, percentage, recipient, active);
    }

    function _grossForNet(uint256 net) internal view returns (uint256) {
        (bool active, address recipient,, uint256 percentage) = _feeOnAndShare();
        return Components.grossForNet(net, percentage, recipient, active);
    }

    function _mintBacked(address to, uint256 gross) internal returns (uint256 net, uint256 fee) {
        (net, fee) = _previewMint(gross);
        if (fee != 0) {
            address recipient = _bindingFeeTo();
            _mintLp(recipient, fee);
            emit IUniswapV4StandardExchangeBalancerQuadStableBufferHook.ProtocolFeeMinted(recipient, fee);
        }
        _mintLp(to, net);
    }

    /// @dev Buffer-last: binding-index order for used pair-token amounts > 0.




    /// @dev Map pair-token edge amounts → intended inventory deltas (shares for SE, face for raw).




    function _requireAmountsLength(uint256[] memory amounts) internal view {
        if (amounts.length != Repo._numTokens()) revert InvalidN();
    }

    function _checkedAmounts(uint256[] memory a) internal view returns (uint256[] memory) {
        _requireAmountsLength(a);
        return Math.toDynamic(a);
    }
}
