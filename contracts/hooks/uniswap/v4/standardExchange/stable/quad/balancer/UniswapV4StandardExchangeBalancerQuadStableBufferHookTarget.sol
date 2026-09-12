// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

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
 *      LP via ERC20Repo; inventory = face | live SE shares; pricing uses the SE-valued StableMath invariant.
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
        return uint8(Repo._numTokens());
    }

    function tokens() public view returns (address[] memory) {
        return Repo._layout().tokens;
    }

    function token(uint256 index) public view returns (address) {
        if (index >= Repo._numTokens()) revert InvalidN();
        return Repo._layout().tokens[index];
    }

    function baseAmp() public view returns (uint256) {
        return Repo._layout().baseAmp;
    }

    /// @notice Scaled amplification A' = baseAmp * AMP_PRECISION (1e3).
    function getCurrentAmp() public view returns (uint256) {
        return Repo._layout().baseAmp * Repo.AMP_PRECISION;
    }

    function standardExchange(uint256 index) public view returns (address) {
        if (index >= Repo._numTokens()) revert InvalidN();
        return Repo._layout().standardExchanges[index];
    }

    function rateProvider(uint256 index) public view returns (address) {
        if (index >= Repo._numTokens()) revert InvalidN();
        return Repo._layout().rateProviders[index];
    }

    function isBuffered(uint256 index) public view returns (bool) {
        if (index >= Repo._numTokens()) revert InvalidN();
        return Repo._layout().standardExchanges[index] != address(0);
    }

    function invScale(uint256 index) public view returns (uint256) {
        if (index >= Repo._numTokens()) revert InvalidN();
        return Repo._layout().invScales[index];
    }

    function ratedScale(uint256 index) public view returns (uint256) {
        if (index >= Repo._numTokens()) revert InvalidN();
        return Repo._layout().ratedScales[index];
    }

    function nativeReserve(uint256 index) public view returns (uint256) {
        if (index >= Repo._numTokens()) revert InvalidN();
        return _nativeAt(uint8(index));
    }

    function nativeReserves() public view returns (uint256[] memory out) {
        uint256[] memory n = _nativeAll();
        out = Math.toDynamic(n);
    }

    function seBalance(uint256 index) public view returns (uint256) {
        if (index >= Repo._numTokens()) revert InvalidN();
        address se = Repo._layout().standardExchanges[index];
        if (se == address(0)) return 0;
        return IERC20(se).balanceOf(address(this));
    }

    function seClaim(uint256 index) public view returns (uint256) {
        if (index >= Repo._numTokens()) revert InvalidN();
        Repo.Layout storage l = Repo._layout();
        address se = l.standardExchanges[index];
        if (se == address(0)) return 0;
        uint256 bal = IERC20(se).balanceOf(address(this));
        if (bal == 0) return 0;
        if (se == l.tokens[index]) return bal;
        return IStandardExchangeIn(se).previewExchangeIn(IERC20(se), bal, IERC20(l.tokens[index]));
    }

    function ratedBalance(uint256 index) public view returns (uint256) {
        if (index >= Repo._numTokens()) revert InvalidN();
        return _ratedPairUnits(uint8(index));
    }

    function ratedBalances() public view returns (uint256[] memory out) {
        uint256[] memory r = new uint256[](Repo._numTokens());
        for (uint8 i; i < Repo._numTokens(); ++i) {
            r[i] = _ratedPairUnits(i);
        }
        out = Math.toDynamic(r);
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

    function isFullBook() public view returns (bool) {
        return Math.isFullBookReserves(_nativeAll());
    }

    function pairDoorCount() public view returns (uint256) {
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

    /// @dev Live inventory (D21): raw = face `balanceOf(hook)` (donations dilute);
    ///      buffered = live SE share `balanceOf(hook)`. Free pair on SE legs is not book.
    function _nativeAt(uint8 i) internal view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        address se = l.standardExchanges[i];
        if (se == address(0)) return IERC20(l.tokens[i]).balanceOf(address(this));
        return IERC20(se).balanceOf(address(this));
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
            return tokenIn.balanceOf(address(this)) - B0;
        }
        uint256 U = _freeTokenBalance(address(tokenIn));
        if (claimed > U) {
            revert ISecurePullErrors.TransferDeltaInsufficient(claimed, U);
        }
        return claimed;
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
        if (amount == 0) return;
        Repo.Layout storage l = Repo._layout();
        if (l.standardExchanges[i] != address(0)) return;
        uint256 book = l.rawReserves[i];
        l.rawReserves[i] = book > amount ? book - amount : 0;
    }

    function _nativeAll() internal view returns (uint256[] memory out) {
        out = new uint256[](Repo._numTokens());
        for (uint8 i; i < Repo._numTokens(); ++i) {
            out[i] = _nativeAt(i);
        }
    }

    /// @dev Pair-token units for swap rating (pre WAD scale). Raw = live face; SE = seBal×rate or claim.
    function _ratedPairUnits(uint8 i) internal view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        address se = l.standardExchanges[i];
        if (se == address(0)) {
            return IERC20(l.tokens[i]).balanceOf(address(this));
        }
        uint256 seBal = IERC20(se).balanceOf(address(this));
        if (seBal == 0) return 0;
        address rp = l.rateProviders[i];
        if (rp != address(0)) {
            uint256 rate = _getRateFailClosed(rp);
            return (seBal * rate) / Math.RATE_PRECISION;
        }
        if (se == l.tokens[i]) return seBal;
        return IStandardExchangeIn(se).previewExchangeIn(IERC20(se), seBal, IERC20(l.tokens[i]));
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
    function _liquidityValue(uint8 i, uint256 inventory, bool roundUp) internal view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        if (inventory == 0) return 0;
        if (l.standardExchanges[i] == address(0)) {
            return roundUp ? Math.scaleToUp(inventory, l.ratedScales[i]) : Math.scaleTo(inventory, l.ratedScales[i]);
        }
        uint256 native = _nativeAt(i);
        uint256 value = Math.scaleTo(_ratedPairUnits(i), l.ratedScales[i]);
        if (native == 0 || value == 0) revert NotFullBook();
        return roundUp ? FixedPointMathLib.fullMulDivUp(inventory, value, native)
            : FixedPointMathLib.fullMulDiv(inventory, value, native);
    }

    function _liquidityInventory(uint8 i, uint256 value, bool roundUp) internal view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        if (value == 0) return 0;
        if (l.standardExchanges[i] == address(0)) {
            return roundUp ? Math.descaleUp(value, l.ratedScales[i]) : Math.descale(value, l.ratedScales[i]);
        }
        uint256 native = _nativeAt(i);
        uint256 balanceValue = Math.scaleTo(_ratedPairUnits(i), l.ratedScales[i]);
        if (native == 0 || balanceValue == 0) revert NotFullBook();
        return roundUp ? FixedPointMathLib.fullMulDivUp(value, native, balanceValue)
            : FixedPointMathLib.fullMulDiv(value, native, balanceValue);
    }

    function _liquidityAmounts(uint256[] memory inventory) internal view returns (uint256[] memory values) {
        values = new uint256[](inventory.length);
        for (uint8 i; i < inventory.length; ++i) values[i] = _liquidityValue(i, inventory[i], false);
    }

    /// @dev Initial denomination is D(pair inputs)/n. Share inputs are valued by the SE's public redemption quote.
    function _initialLiquidityValues(uint256[] memory amounts, bool[] memory sharesIn)
        internal view returns (uint256[] memory values)
    {
        Repo.Layout storage l = Repo._layout();
        values = new uint256[](amounts.length);
        for (uint8 i; i < amounts.length; ++i) {
            uint256 pairAmount = amounts[i];
            if (sharesIn[i] && pairAmount != 0) {
                pairAmount = IStandardExchangeIn(l.standardExchanges[i]).previewExchangeIn(
                    IERC20(l.standardExchanges[i]), pairAmount, IERC20(l.tokens[i])
                );
            }
            values[i] = Math.scaleTo(pairAmount, l.ratedScales[i]);
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
    function _rootKCheckpoint() internal view returns (uint256) {
        Repo.Layout storage l = Repo._layout();
        if (l.feeReserves.length != l.tokens.length) return 0;
        return Math.rootK(_liquidityAmounts(l.feeReserves), _amp());
    }

    function _maybeMintProtocolFee() internal returns (uint256 protocolLp) {
        (bool feeOn, address feeTo_, uint256 ownerFeeShare,) = _feeOnAndShare();
        Repo.Layout storage l = Repo._layout();
        if (feeOn && l.kLast != 0) {
            uint256 rootKNow = _rootKNow();
            protocolLp = Math.protocolLpShares(_totalSupply(), rootKNow, _rootKCheckpoint(), ownerFeeShare);
            l.kLast = rootKNow;
            if (protocolLp > 0) {
                _mintLp(feeTo_, protocolLp);
                emit IUniswapV4StandardExchangeBalancerQuadStableBufferHook.ProtocolFeeMinted(feeTo_, protocolLp);
            }
        }
        l.liquiditySupplyBefore = _totalSupply();
        l.feeReserves = _nativeAll();
        if (l.liquiditySupplyBefore != 0) {
            l.liquidityValuesBefore = _ratedWadAll();
            l.liquidityValueBefore = Math.getD(l.liquidityValuesBefore, _amp());
        }
    }

    /// @dev Supply after simulating protocol growth mint (for LP previews under fee-on).
    function _previewSupplyAfterProtocolMint() internal view returns (uint256 supply) {
        supply = _totalSupply();
        (bool feeOn,, uint256 ownerFeeShare,) = _feeOnAndShare();
        Repo.Layout storage l = Repo._layout();
        if (!feeOn || l.kLast == 0) return supply;
        uint256 rootKNow = _rootKNow();
        if (rootKNow == 0) return supply;
        uint256 protocolLp = Math.protocolLpShares(supply, rootKNow, _rootKCheckpoint(), ownerFeeShare);
        return supply + protocolLp;
    }

    function _snapshotKLastIfFeeOn() internal {
        (bool feeOn,,,) = _feeOnAndShare();
        Repo.Layout storage l = Repo._layout();
        if (l.liquiditySupplyBefore != 0) {
            // Use the same rates as the quote. Downstream SE fees/rate changes are shared by SE owners;
            // they must not change the hook's in-flight inventory-to-LP exchange rate.
            uint256[] memory valuesAfter = l.liquidityValuesBefore;
            uint256 supplyAfter = _totalSupply();
            bool proportionalBackingPreserved = true;
            for (uint8 i; i < valuesAfter.length; ++i) {
                uint256 nativeAfter = _nativeAt(i);
                if (nativeAfter < FixedPointMathLib.fullMulDivUp(l.feeReserves[i], supplyAfter, l.liquiditySupplyBefore)) {
                    proportionalBackingPreserved = false;
                }
                valuesAfter[i] = FixedPointMathLib.fullMulDiv(nativeAfter, valuesAfter[i], l.feeReserves[i]);
            }
            // Component-wise backing proves proportional operations directly, without integer D homogeneity error.
            if (!proportionalBackingPreserved) {
                uint256 valueAfter = Math.getD(valuesAfter, _amp());
                if (valueAfter < FixedPointMathLib.fullMulDiv(l.liquidityValueBefore, supplyAfter, l.liquiditySupplyBefore)) {
                    revert LiquidityValueLoss();
                }
            }
        }
        l.liquiditySupplyBefore = 0;
        l.liquidityValueBefore = 0;
        delete l.liquidityValuesBefore;
        if (!feeOn) {
            l.kLast = 0;
            return;
        }
        l.kLast = _rootKNow();
        l.feeReserves = _nativeAll();
    }

    function _syncVaultReserves() internal {
        Repo.Layout storage l = Repo._layout();
        for (uint8 i; i < Repo._numTokens(); ++i) {
            uint256 inventory = _nativeAt(i);
            MultiAssetBasicVaultRepo._updateReserve(IERC20(l.tokens[i]), inventory);
            l.rawReserves[i] = IERC20(l.tokens[i]).balanceOf(address(this));
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
        address se = l.standardExchanges[i];
        address t = l.tokens[i];
        if (se == address(0)) {
            // Intentional raw intake; live LP book still balanceOf (D21).
            _creditRawIntentional(i, amount);
            return 0;
        }
        if (se == t) return amount;
        uint256 minOut = IStandardExchangeIn(se).previewExchangeIn(IERC20(t), amount, IERC20(se));
        if (minOut == 0) revert BufferFailed();
        IERC20(t).forceApprove(se, amount);
        uint256 beforeShares = IERC20(se).balanceOf(address(this));
        seOut = IStandardExchangeIn(se).exchangeIn(
            IERC20(t), amount, IERC20(se), minOut, address(this), false, block.timestamp
        );
        IERC20(t).forceApprove(se, 0);
        if (seOut < minOut || IERC20(se).balanceOf(address(this)) - beforeShares != seOut) revert BufferFailed();
    }

    function _unwrapSeShares(uint8 i, uint256 seIn, address to) internal returns (uint256 pairOut) {
        if (seIn == 0) return 0;
        Repo.Layout storage l = Repo._layout();
        address se = l.standardExchanges[i];
        address t = l.tokens[i];
        if (se == t) {
            if (to != address(this)) IERC20(se).safeTransfer(to, seIn);
            return seIn;
        }
        uint256 minOut = IStandardExchangeIn(se).previewExchangeIn(IERC20(se), seIn, IERC20(t));
        if (minOut == 0) return 0;
        IERC20(se).forceApprove(se, seIn);
        uint256 beforeBalance = IERC20(t).balanceOf(to);
        pairOut = IStandardExchangeIn(se).exchangeIn(
            IERC20(se), seIn, IERC20(t), minOut, to, false, block.timestamp
        );
        IERC20(se).forceApprove(se, 0);
        if (pairOut < minOut || IERC20(t).balanceOf(to) - beforeBalance != pairOut) revert UnwrapFailed();
    }

    function _unwrapExactTokenOut(uint8 i, uint256 amountOut, address to)
        internal
        returns (uint256 seIn)
    {
        if (amountOut == 0) return 0;
        Repo.Layout storage l = Repo._layout();
        address se = l.standardExchanges[i];
        address t = l.tokens[i];
        if (se == t) {
            if (to != address(this)) IERC20(t).safeTransfer(to, amountOut);
            return amountOut;
        }
        seIn = IStandardExchangeOut(se).previewExchangeOut(IERC20(se), IERC20(t), amountOut);
        uint256 beforeBalance = IERC20(t).balanceOf(address(this));
        IERC20(se).forceApprove(se, seIn);
        uint256 spent = IStandardExchangeOut(se).exchangeOut(
            IERC20(se), seIn, IERC20(t), amountOut, address(this), false, block.timestamp
        );
        IERC20(se).forceApprove(se, 0);
        uint256 received = IERC20(t).balanceOf(address(this)) - beforeBalance;
        if (spent > seIn || received < amountOut) revert UnwrapFailed();
        if (to != address(this)) IERC20(t).safeTransfer(to, amountOut);
        // SE exits can round up or include execution surplus. Retain that value
        // in the shared reserve while settling exactly the hook's quoted output.
        uint256 surplus = received - amountOut;
        if (surplus != 0 && IStandardExchangeIn(se).previewExchangeIn(IERC20(t), surplus, IERC20(se)) != 0) {
            _bufferToken(i, surplus);
        }
        return spent;
    }

    /// @dev Buffer-last: binding-index order for used pair-token amounts > 0.
    function _bufferLast(uint256[] memory pairAmounts) internal {
        for (uint8 i; i < Repo._numTokens(); ++i) {
            if (pairAmounts[i] > 0) _bufferToken(i, pairAmounts[i]);
        }
    }

    function _refundBufferedDust() internal {
        Repo.Layout storage l = Repo._layout();
        for (uint8 i; i < Repo._numTokens(); ++i) {
            address se = l.standardExchanges[i];
            if (se == address(0) || se == l.tokens[i]) continue;
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
            // Unconvertible native dust stays with the reserve until it can be buffered.
        }
    }

    /// @dev Map pair-token edge amounts → intended inventory deltas (shares for SE, face for raw).
    function _pairToInvPreview(uint256[] memory pairAmounts)
        internal
        view
        returns (uint256[] memory invDeltas)
    {
        invDeltas = new uint256[](Repo._numTokens());
        Repo.Layout storage l = Repo._layout();
        for (uint8 i; i < Repo._numTokens(); ++i) {
            if (pairAmounts[i] == 0) continue;
            address se = l.standardExchanges[i];
            if (se == address(0) || se == l.tokens[i]) {
                invDeltas[i] = pairAmounts[i];
            } else {
                invDeltas[i] = IStandardExchangeIn(se).previewExchangeIn(
                    IERC20(l.tokens[i]), pairAmounts[i], IERC20(se)
                );
            }
        }
    }

    function _invToPairOutPreview(uint256[] memory invOut)
        internal
        view
        returns (uint256[] memory pairOut)
    {
        pairOut = new uint256[](Repo._numTokens());
        Repo.Layout storage l = Repo._layout();
        for (uint8 i; i < Repo._numTokens(); ++i) {
            if (invOut[i] == 0) continue;
            address se = l.standardExchanges[i];
            if (se == address(0) || se == l.tokens[i]) {
                pairOut[i] = invOut[i];
            } else {
                pairOut[i] = IStandardExchangeIn(se).previewExchangeIn(
                    IERC20(se), invOut[i], IERC20(l.tokens[i])
                );
            }
        }
    }

    function _requireAmountsLength(uint256[] memory amounts) internal view {
        if (amounts.length != Repo._numTokens()) revert InvalidN();
    }

    function _checkedAmounts(uint256[] memory a) internal view returns (uint256[] memory) {
        _requireAmountsLength(a);
        return Math.toDynamic(a);
    }
}
