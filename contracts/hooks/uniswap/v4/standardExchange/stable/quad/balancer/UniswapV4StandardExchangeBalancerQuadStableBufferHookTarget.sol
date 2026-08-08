// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {BetterSafeERC20 as SafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {Currency} from "@crane/contracts/protocols/dexes/uniswap/v4/types/Currency.sol";
import {IPoolManager} from "@crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";
import {IRateProvider} from
    "@crane/contracts/protocols/dexes/balancer/common/interfaces/IRateProvider.sol";
import {IAllowanceTransfer} from
    "@crane/contracts/interfaces/protocols/utils/permit2/IAllowanceTransfer.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
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
 * @notice Shared book/guards/buffer helpers for 4-asset Balancer StableMath SE buffer facets.
 * @dev No BaseHook inheritance. Fixed N=4; no weights; no partial-book KLast modes.
 *      LP via ERC20Repo; inventory = face | live SE shares; kLast = geoMean4(invWad).
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

    function numTokens() public pure returns (uint8) {
        return uint8(Repo.N_TOKENS);
    }

    function tokens() public view returns (address[] memory out) {
        Repo.Layout storage l = Repo._layout();
        out = new address[](Repo.N_TOKENS);
        out[0] = l.tokens[0];
        out[1] = l.tokens[1];
        out[2] = l.tokens[2];
        out[3] = l.tokens[3];
    }

    function token(uint256 index) public view returns (address) {
        if (index >= Repo.N_TOKENS) revert InvalidN();
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
        if (index >= Repo.N_TOKENS) revert InvalidN();
        return Repo._layout().standardExchanges[index];
    }

    function rateProvider(uint256 index) public view returns (address) {
        if (index >= Repo.N_TOKENS) revert InvalidN();
        return Repo._layout().rateProviders[index];
    }

    function isBuffered(uint256 index) public view returns (bool) {
        if (index >= Repo.N_TOKENS) revert InvalidN();
        return Repo._layout().standardExchanges[index] != address(0);
    }

    function invScale(uint256 index) public view returns (uint256) {
        if (index >= Repo.N_TOKENS) revert InvalidN();
        return Repo._layout().invScales[index];
    }

    function ratedScale(uint256 index) public view returns (uint256) {
        if (index >= Repo.N_TOKENS) revert InvalidN();
        return Repo._layout().ratedScales[index];
    }

    function nativeReserve(uint256 index) public view returns (uint256) {
        if (index >= Repo.N_TOKENS) revert InvalidN();
        return _nativeAt(uint8(index));
    }

    function nativeReserves() public view returns (uint256[] memory out) {
        uint256[4] memory n = _nativeAll();
        out = Math.toDynamic(n);
    }

    function seBalance(uint256 index) public view returns (uint256) {
        if (index >= Repo.N_TOKENS) revert InvalidN();
        address se = Repo._layout().standardExchanges[index];
        if (se == address(0)) return 0;
        return IERC20(se).balanceOf(address(this));
    }

    function seClaim(uint256 index) public view returns (uint256) {
        if (index >= Repo.N_TOKENS) revert InvalidN();
        Repo.Layout storage l = Repo._layout();
        address se = l.standardExchanges[index];
        if (se == address(0)) return 0;
        uint256 bal = IERC20(se).balanceOf(address(this));
        if (bal == 0) return 0;
        return IStandardExchangeIn(se).previewExchangeIn(IERC20(se), bal, IERC20(l.tokens[index]));
    }

    function ratedBalance(uint256 index) public view returns (uint256) {
        if (index >= Repo.N_TOKENS) revert InvalidN();
        return _ratedPairUnits(uint8(index));
    }

    function ratedBalances() public view returns (uint256[] memory out) {
        uint256[4] memory r;
        for (uint8 i; i < Repo.N_TOKENS; ++i) {
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

    function pairDoorCount() public pure returns (uint256) {
        return PairPoolLib.pairDoorCount();
    }

    function ensurePairPools() external returns (uint256 doorsEnsured) {
        Repo.Layout storage l = Repo._layout();
        doorsEnsured = PairPoolLib.ensureAllPairPools(
            IPoolManager(l.poolManager), address(this), l.tokens, 0
        );
        emit IUniswapV4StandardExchangeBalancerQuadStableBufferHook.PairPoolsEnsured(address(this), doorsEnsured);
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
        for (uint8 i; i < Repo.N_TOKENS; ++i) {
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

    /// @notice Free pool-token balance eligible for pretransfer funding (orbital/weighted peer).
    /// @dev SE legs: full face balance is free (pair never book). Raw legs: bal − intentional
    ///      `rawReserves` only — inventory cannot fund pretransfer (prevents book drain).
    function _freeTokenBalance(address token_) internal view returns (uint256 free) {
        uint8 i = _tokenIndex(token_);
        Repo.Layout storage l = Repo._layout();
        uint256 bal = IERC20(token_).balanceOf(address(this));
        if (l.standardExchanges[i] != address(0)) {
            return bal;
        }
        uint256 book = l.rawReserves[i];
        return bal > book ? bal - book : 0;
    }

    function _requirePretransferred(address token_, uint256 amount) internal view {
        if (_freeTokenBalance(token_) < amount) revert InsufficientPretransfer();
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

    function _nativeAll() internal view returns (uint256[4] memory out) {
        for (uint8 i; i < Repo.N_TOKENS; ++i) {
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
        return IStandardExchangeIn(se).previewExchangeIn(IERC20(se), seBal, IERC20(l.tokens[i]));
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

    /// @dev I1: kLast domain = geometricMean4(invWad). Full book only for growth.
    function _rootKNow() internal view returns (uint256) {
        uint256[4] memory inv = _invWadAll();
        if (!Math.isFullBookReserves(inv)) return 0;
        return Math.rootK(inv);
    }

    function _maybeMintProtocolFee() internal returns (uint256 protocolLp) {
        (bool feeOn, address feeTo_, uint256 ownerFeeShare,) = _feeOnAndShare();
        Repo.Layout storage l = Repo._layout();
        if (!feeOn || l.kLast == 0) return 0;
        uint256 rootKNow = _rootKNow();
        if (rootKNow == 0) return 0;
        protocolLp = Math.protocolLpShares(_totalSupply(), rootKNow, l.kLast, ownerFeeShare);
        if (protocolLp > 0) {
            _mintLp(feeTo_, protocolLp);
            emit IUniswapV4StandardExchangeBalancerQuadStableBufferHook.ProtocolFeeMinted(feeTo_, protocolLp);
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
        uint256 protocolLp = Math.protocolLpShares(supply, rootKNow, l.kLast, ownerFeeShare);
        return supply + protocolLp;
    }

    function _snapshotKLastIfFeeOn() internal {
        (bool feeOn,,,) = _feeOnAndShare();
        Repo.Layout storage l = Repo._layout();
        if (!feeOn) {
            l.kLast = 0;
            return;
        }
        l.kLast = _rootKNow();
    }

    function _syncVaultReserves() internal {
        Repo.Layout storage l = Repo._layout();
        for (uint8 i; i < Repo.N_TOKENS; ++i) {
            MultiAssetBasicVaultRepo._updateReserve(IERC20(l.tokens[i]), _nativeAt(i));
        }
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
        address se = l.standardExchanges[i];
        address t = l.tokens[i];
        if (se == address(0)) {
            // Intentional raw intake; live LP book still balanceOf (D21).
            _creditRawIntentional(i, amount);
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
    function _bufferLast(uint256[4] memory pairAmounts) internal {
        for (uint8 i; i < Repo.N_TOKENS; ++i) {
            if (pairAmounts[i] > 0) _bufferToken(i, pairAmounts[i]);
        }
    }

    function _refundBufferedDust() internal {
        Repo.Layout storage l = Repo._layout();
        for (uint8 i; i < Repo.N_TOKENS; ++i) {
            if (l.standardExchanges[i] == address(0)) continue;
            uint256 bal = IERC20(l.tokens[i]).balanceOf(address(this));
            if (bal > 0 && bal <= Repo.MAX_DUST_WEI) {
                // leave tiny dust
            } else if (bal > Repo.MAX_DUST_WEI) {
                IERC20(l.tokens[i]).safeTransfer(msg.sender, bal);
            }
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
            if (se == address(0)) {
                invDeltas[i] = pairAmounts[i];
            } else {
                invDeltas[i] = IStandardExchangeIn(se).previewExchangeIn(
                    IERC20(l.tokens[i]), pairAmounts[i], IERC20(se)
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
            if (se == address(0)) {
                pairOut[i] = invOut[i];
            } else {
                pairOut[i] = IStandardExchangeIn(se).previewExchangeIn(
                    IERC20(se), invOut[i], IERC20(l.tokens[i])
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
