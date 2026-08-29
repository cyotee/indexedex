// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {AddressSet, AddressSetRepo} from "@crane/contracts/utils/collections/sets/AddressSetRepo.sol";

import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {IDETFNFTVault} from "contracts/interfaces/IDETFNFTVault.sol";
import {BondTerms} from "contracts/interfaces/VaultFeeTypes.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {
    DETFThresholdPolicy,
    ThresholdMode
} from "contracts/vaults/detf/common/core/DETFThresholdPolicy.sol";
import {DETFMintSplitLib} from "contracts/vaults/detf/common/core/DETFMintSplitLib.sol";
import {MintSplit} from "contracts/vaults/detf/common/core/DETFMintSplit.sol";
import {DETFBondNFTMathLib} from "contracts/vaults/detf/common/core/DETFBondNFTMathLib.sol";
import {DETFProtocolCompoundLib} from "contracts/vaults/detf/common/core/DETFProtocolCompoundLib.sol";
import {DETFBondLifecycleLib} from "contracts/vaults/detf/common/core/DETFBondLifecycleLib.sol";
import {DETFEpochNaturalExpansionLib} from "contracts/vaults/detf/common/core/DETFEpochNaturalExpansionLib.sol";
import {
    DETF_CREATOR_BOND_NFT_ID,
    DETF_FEE_TO_BOND_NFT_ID
} from "contracts/vaults/detf/common/core/DETFBondNftIds.sol";
import {IDetfSelfNftInventoryPolicy} from "contracts/vaults/detf/common/inventory/IDetfSelfNftInventoryPolicy.sol";
import {IDetfErrors} from "contracts/interfaces/IDetfErrors.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {IUniswapV4SeBufferHook} from "contracts/hooks/uniswap/v4/interfaces/IUniswapV4SeBufferHook.sol";
import {IDetfReserveQuote} from "contracts/hooks/uniswap/v4/interfaces/IDetfReserveQuote.sol";
import {IUniswapV4Detf} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol";
import {UniswapV4DetfRepo as Repo} from
    "contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfRepo.sol";

/// @title UniswapV4DetfCommon
/// @notice Shared gates, quotes, pull, sweep, expansion, compound. Opaque hook ABI only.
abstract contract UniswapV4DetfCommon is ReentrancyLockModifiers {
    using BetterSafeERC20 for IERC20;
    using AddressSetRepo for AddressSet;

    uint256 internal constant ONE_WAD = 1e18;

    function _requireReserveLive() internal view {
        if (!Repo._layoutStruct().isReserveLive) revert Repo.ReserveNotLive();
    }

    function _requireReserveWired() internal view {
        Repo.Storage storage s = Repo._layoutStruct();
        if (address(s.bondNftVault) == address(0) || address(s.rebasingClaimToken) == address(0)) {
            revert Repo.ReserveNotWired();
        }
    }

    function _requireActive(uint256 deadline_, uint256 amount_) internal view {
        if (amount_ == 0) revert Repo.ZeroAmount();
        if (block.timestamp > deadline_) revert Repo.DeadlineExpired(deadline_);
    }

    function _rejectPretransferredFirstBond(bool pretransferred_, uint256 claimed_) internal pure {
        if (pretransferred_) {
            revert ISecurePullErrors.TransferDeltaInsufficient(claimed_, 0);
        }
    }

    function _requireNotDisabled() internal view {
        address reg = address(StandardVaultRepo._feeOracle());
        if (IVaultRegistryDisableQuery(reg).isDisabled(address(this))) {
            revert IVaultRegistryDisableQuery.VaultDisabled(address(this));
        }
    }

    function _requireBondNft() internal view {
        if (msg.sender != address(Repo._layoutStruct().bondNftVault)) {
            revert Repo.NotAuthorized(msg.sender);
        }
    }

    function _requireMature(uint256 tokenId_) internal view {
        uint256 unlock_ = Repo._layoutStruct().bondNftVault.unlockTimeOf(tokenId_);
        if (block.timestamp < unlock_) {
            revert Repo.BondNotMature(unlock_);
        }
    }

    function _requireNotStandingRewardNft(uint256 tokenId_) internal pure {
        if (tokenId_ == DETF_FEE_TO_BOND_NFT_ID || tokenId_ == DETF_CREATOR_BOND_NFT_ID) {
            revert IDetfErrors.DETFNFTRestricted(tokenId_);
        }
    }

    function _hook() internal view returns (IUniswapV4SeBufferHook) {
        return IUniswapV4SeBufferHook(Repo._layoutStruct().hook);
    }

    function _quote() internal view returns (IDetfReserveQuote) {
        return IDetfReserveQuote(Repo._layoutStruct().hook);
    }

    function _bondLpHolder() internal view returns (address) {
        address bond_ = address(Repo._layoutStruct().bondNftVault);
        return bond_ == address(0) ? address(this) : bond_;
    }

    function _nftLp() internal view returns (uint256) {
        return IERC20(Repo._layoutStruct().hook).balanceOf(_bondLpHolder());
    }

    function _effectiveLockDuration(uint256 lockDuration_) internal view returns (uint256 effective_) {
        BondTerms memory terms_ = DETFBondNFTMathLib._bondTerms(address(this));
        if (lockDuration_ < terms_.minLockDuration) {
            revert Repo.LockDurationTooShort(lockDuration_, terms_.minLockDuration);
        }
        effective_ = lockDuration_ > terms_.maxLockDuration ? terms_.maxLockDuration : lockDuration_;
    }

    function _seigniorageIncentiveWad() internal view returns (uint256) {
        Repo.Storage storage s = Repo._layoutStruct();
        if (address(s.feeOracle) == address(0)) return 0;
        return s.feeOracle.seigniorageIncentivePercentageOfVault(address(this));
    }

    function _splitMintedDetf(uint256 gross_) internal view returns (MintSplit memory split_) {
        split_.grossDetf = gross_;
        if (gross_ == 0) return split_;
        (uint256 user_, uint256 pot_) = DETFMintSplitLib._splitLiveGross(gross_, _seigniorageIncentiveWad());
        split_.userDetf = user_;
        split_.inventoryDetf = pot_;
    }

    function _splitBondDetf(uint256 joinDetf_) internal view returns (MintSplit memory split_) {
        split_.grossDetf = joinDetf_;
        if (joinDetf_ == 0) return split_;
        (uint256 user_, uint256 pot_,) = DETFMintSplitLib._splitBond(joinDetf_, _seigniorageIncentiveWad());
        split_.userDetf = user_;
        split_.inventoryDetf = pot_;
    }

    function _mintDetf(address to_, uint256 amount_) internal {
        if (amount_ == 0) return;
        ERC20Repo._mint(to_, amount_);
    }

    function _burnDetf(address from_, uint256 amount_) internal {
        if (amount_ == 0) return;
        ERC20Repo._burn(from_, amount_);
    }

    function _hookPairOfVault(IStandardExchange vault_) internal view returns (address pair_) {
        Repo.Storage storage s = Repo._layoutStruct();
        address[] storage pairs_ = s.hookPairTokens._values();
        for (uint256 i; i < pairs_.length; ++i) {
            if (address(s.mintTable.vaultOf[pairs_[i]]) == address(vault_)
                || IUniswapV4SeBufferHook(s.hook).standardExchangeOf(pairs_[i]) == address(vault_))
            {
                return pairs_[i];
            }
        }
        revert Repo.InvalidRoute(address(vault_), address(this));
    }

    function _pairEq(IStandardExchange vault_, IERC20 tokenIn_, uint256 amountIn_)
        internal
        view
        returns (uint256 pairEq_)
    {
        address share_ = address(vault_);
        address pair_ = _hookPairOfVault(vault_);
        if (address(tokenIn_) == pair_) return amountIn_;
        if (address(tokenIn_) == share_) {
            try vault_.previewExchangeIn(tokenIn_, amountIn_, IERC20(pair_)) returns (uint256 out_) {
                return out_;
            } catch {
                revert Repo.InvalidRoute(address(tokenIn_), pair_);
            }
        }
        try vault_.previewExchangeIn(tokenIn_, amountIn_, IERC20(pair_)) returns (uint256 out_) {
            if (out_ == 0) revert Repo.InvalidRoute(address(tokenIn_), pair_);
            return out_;
        } catch {
            revert Repo.InvalidRoute(address(tokenIn_), pair_);
        }
    }

    function _quoteCtx() internal view returns (IDetfReserveQuote.DetfQuoteCtx memory ctx_) {
        Repo.Storage storage s = Repo._layoutStruct();
        uint256 creation_ = s.creationPairPerDetfWad.length == 0 ? ONE_WAD : s.creationPairPerDetfWad[0];
        ctx_ = IDetfReserveQuote.DetfQuoteCtx({
            detfTotalSupply: ERC20Repo._totalSupply() + _pendingExpansionDetf(),
            pendingExpansion: _pendingExpansionDetf(),
            ownedLp: _nftLp(),
            creationPairPerDetfWad: creation_
        });
    }

    function _syntheticOfPair(address pair_) internal view returns (uint256 wad_) {
        if (!Repo._layoutStruct().isReserveLive) return 0;
        wad_ = _quote().previewSynthetic(_quoteCtx(), pair_);
    }

    function _syntheticPrice() internal view returns (uint256 wad_) {
        Repo.Storage storage s = Repo._layoutStruct();
        address[] storage pairs_ = s.hookPairTokens._values();
        if (pairs_.length == 0) return 0;
        return _syntheticOfPair(pairs_[0]);
    }

    function _isMintingAllowedToken(IERC20 tokenIn_) internal view returns (bool) {
        Repo.Storage storage s = Repo._layoutStruct();
        if (!s.isReserveLive) return false;
        if (!s.mintTable.tokens._contains(address(tokenIn_))) return false;
        IStandardExchange v_ = s.mintTable.vaultOf[address(tokenIn_)];
        address pair_ = _hookPairOfVault(v_);
        uint256 syn_ = _syntheticOfPair(pair_);
        return DETFThresholdPolicy._isMintingAllowed(s.thresholdMode, s.mintThreshold, syn_);
    }

    function _isBurningAllowedToken(IERC20 tokenOut_) internal view returns (bool) {
        Repo.Storage storage s = Repo._layoutStruct();
        if (!s.isReserveLive) return false;
        if (!s.burnTable.tokens._contains(address(tokenOut_))) return false;
        IStandardExchange v_ = s.burnTable.vaultOf[address(tokenOut_)];
        address pair_ = _hookPairOfVault(v_);
        uint256 syn_ = _syntheticOfPair(pair_);
        return DETFThresholdPolicy._isBurningAllowed(s.thresholdMode, s.burnThreshold, syn_);
    }

    function _isMintingAllowedAny() internal view returns (bool) {
        Repo.Storage storage s = Repo._layoutStruct();
        if (!s.isReserveLive) return false;
        address[] storage toks_ = s.mintTable.tokens._values();
        for (uint256 i; i < toks_.length; ++i) {
            if (_isMintingAllowedToken(IERC20(toks_[i]))) return true;
        }
        return false;
    }

    function _isBurningAllowedAny() internal view returns (bool) {
        Repo.Storage storage s = Repo._layoutStruct();
        if (!s.isReserveLive) return false;
        address[] storage toks_ = s.burnTable.tokens._values();
        for (uint256 i; i < toks_.length; ++i) {
            if (_isBurningAllowedToken(IERC20(toks_[i]))) return true;
        }
        return false;
    }

    function _quoteMintGross(address pair_, uint256 pairEq_) internal view returns (uint256 gross_) {
        uint256 p_ = _seigniorageIncentiveWad();
        uint256 boosted_ = Math.mulDiv(pairEq_, ONE_WAD + p_, ONE_WAD);
        gross_ = _hook().previewSwapExactIn(pair_, address(this), boosted_);
    }

    function _quoteBondG(address pair_, uint256 pairEq_) internal view returns (uint256 g_) {
        Repo.Storage storage s = Repo._layoutStruct();
        uint256 opening_ = s.openingOfPair[pair_];
        if (opening_ == 0) opening_ = s.creationOfPair[pair_];
        if (!s.isReserveLive || !_hook().isLive()) {
            g_ = Math.mulDiv(pairEq_, ONE_WAD, opening_);
            return g_ == 0 ? pairEq_ : g_;
        }
        uint256 supply_ = IERC20(s.hook).totalSupply();
        if (supply_ == 0) {
            g_ = Math.mulDiv(pairEq_, ONE_WAD, opening_);
            return g_ == 0 ? pairEq_ : g_;
        }
        uint256[] memory amounts_ = _hook().previewExitProportional(supply_);
        address[] memory tokens_ = _hook().tokens();
        uint256 reserveDetf_;
        uint256 reservePair_;
        for (uint256 i; i < tokens_.length; ++i) {
            if (tokens_[i] == address(this)) reserveDetf_ = amounts_[i];
            if (tokens_[i] == pair_) reservePair_ = amounts_[i];
        }
        if (reserveDetf_ == 0 || reservePair_ == 0) {
            g_ = Math.mulDiv(pairEq_, ONE_WAD, opening_);
            return g_ == 0 ? pairEq_ : g_;
        }
        g_ = (reserveDetf_ * pairEq_) / reservePair_;
        if (g_ == 0) g_ = Math.mulDiv(pairEq_, ONE_WAD, opening_);
    }

    function _pendingExpansionDetf() internal view returns (uint256) {
        Repo.Storage storage s = Repo._layoutStruct();
        DETFEpochNaturalExpansionLib.AccrualInput memory in_;
        in_.isLive = s.isReserveLive;
        in_.isPolicyMode = s.thresholdMode == ThresholdMode.Policy;
        in_.spotSyntheticPrice = _syntheticPriceView();
        in_.totalDetfSupply = ERC20Repo._totalSupply();
        in_.lastExpansionTimestamp = s.lastExpansionTimestamp;
        in_.nowTimestamp = block.timestamp;
        in_.expansionEpochLength = s.expansionEpochLength;
        in_.expansionClosureRatePerYearWad = s.expansionClosureRatePerYearWad;
        in_.expansionMaxCatchUpEpochs = s.expansionMaxCatchUpEpochs;
        return DETFEpochNaturalExpansionLib.previewPendingExpansionMint(in_);
    }

    function _syntheticPriceView() internal view returns (uint256) {
        Repo.Storage storage s = Repo._layoutStruct();
        if (!s.isReserveLive) return 0;
        address[] storage pairs_ = s.hookPairTokens._values();
        if (pairs_.length == 0) return 0;
        IDetfReserveQuote.DetfQuoteCtx memory ctx_ = IDetfReserveQuote.DetfQuoteCtx({
            detfTotalSupply: ERC20Repo._totalSupply(),
            pendingExpansion: 0,
            ownedLp: _nftLp(),
            creationPairPerDetfWad: s.creationPairPerDetfWad.length == 0 ? ONE_WAD : s.creationPairPerDetfWad[0]
        });
        return _quote().previewSynthetic(ctx_, pairs_[0]);
    }

    function _realizeExpansionIfNeeded() internal {
        Repo.Storage storage s = Repo._layoutStruct();
        if (!s.isReserveLive || s.thresholdMode != ThresholdMode.Policy) return;
        DETFEpochNaturalExpansionLib.AccrualInput memory in_;
        in_.isLive = true;
        in_.isPolicyMode = true;
        in_.spotSyntheticPrice = _syntheticPriceView();
        in_.totalDetfSupply = ERC20Repo._totalSupply();
        in_.lastExpansionTimestamp = s.lastExpansionTimestamp;
        in_.nowTimestamp = block.timestamp;
        in_.expansionEpochLength = s.expansionEpochLength;
        in_.expansionClosureRatePerYearWad = s.expansionClosureRatePerYearWad;
        in_.expansionMaxCatchUpEpochs = s.expansionMaxCatchUpEpochs;
        (uint256 mintAmount_, uint256 newTs_) = DETFEpochNaturalExpansionLib.computeRealization(in_);
        if (newTs_ != s.lastExpansionTimestamp) {
            s.lastExpansionTimestamp = newTs_;
        }
        if (mintAmount_ > 0 && address(s.bondNftVault) != address(0)) {
            _mintDetf(address(s.bondNftVault), mintAmount_);
            emit IUniswapV4Detf.NaturalSupplyExpanded(mintAmount_, in_.spotSyntheticPrice, newTs_);
        }
    }

    function _topUpFeeCreatorShares() internal {
        Repo.Storage storage s = Repo._layoutStruct();
        if (address(s.bondNftVault) == address(0)) return;
        (, uint256 f_, uint256 c_) = s.feeOracle.seigniorageSplitOfVault(address(this));
        DETFBondLifecycleLib._topUpFeeCreatorShares(
            IDetfSelfNftInventoryPolicy(address(s.bondNftVault)), f_, c_
        );
    }

    function _tryCompoundProtocolRewards() internal returns (uint256 detfIn, uint256 lpOut) {
        Repo.Storage storage s = Repo._layoutStruct();
        if (!s.isReserveLive || address(s.bondNftVault) == address(0)) return (0, 0);
        try this.compoundProtocolRewardsAtomic() returns (uint256 d_, uint256 l_) {
            return (d_, l_);
        } catch {
            return (0, 0);
        }
    }

    function compoundProtocolRewardsAtomic() external returns (uint256 detfIn, uint256 lpOut) {
        if (msg.sender != address(this)) revert Repo.NotAuthorized(msg.sender);
        Repo.Storage storage s = Repo._layoutStruct();
        uint256 pending_ = s.bondNftVault.pendingRewards(s.bondNftVault.detfNFTId());
        if (!DETFProtocolCompoundLib.isCompoundable(pending_)) return (0, 0);
        detfIn = s.bondNftVault.reallocateDetfNftRewards(address(this));
        if (detfIn == 0) return (0, 0);
        IERC20(address(this)).forceApprove(s.hook, detfIn);
        lpOut = _hook().joinSingleAssetExactIn(address(this), detfIn, _bondLpHolder(), 0, block.timestamp + 1);
        if (lpOut == 0) revert Repo.ZeroAmount();
        s.bondNftVault.addToDETFNFT(s.bondNftVault.detfNFTId(), lpOut);
        emit IUniswapV4Detf.ProtocolRewardsCompounded(detfIn, lpOut);
        _trySweepDust();
    }

    function _pullToken(IERC20 token_, uint256 amount_, bool pretransferred_) internal returns (uint256 actual_) {
        uint256 R = MultiAssetBasicVaultRepo._reserveOfToken(address(token_));
        uint256 B0 = token_.balanceOf(address(this));
        if (!pretransferred_) {
            token_.safeTransferFrom(msg.sender, address(this), amount_);
            return token_.balanceOf(address(this)) - B0;
        }
        uint256 U = B0 > R ? B0 - R : 0;
        if (amount_ > U) {
            revert ISecurePullErrors.TransferDeltaInsufficient(amount_, U);
        }
        return amount_;
    }

    function _syncAllExpectedHoldReserves() internal {
        address[] memory tokens = MultiAssetBasicVaultRepo._vaultTokens();
        for (uint256 i; i < tokens.length; ++i) {
            IERC20 t = IERC20(tokens[i]);
            MultiAssetBasicVaultRepo._updateReserve(t, t.balanceOf(address(this)));
        }
    }

    function _nestedExchangeInPush(
        IStandardExchangeIn host_,
        IERC20 tokenIn_,
        uint256 amountIn_,
        IERC20 tokenOut_,
        uint256 minAmountOut_,
        address recipient_,
        uint256 deadline_
    ) internal returns (uint256 amountOut_) {
        if (amountIn_ == 0) return 0;
        tokenIn_.safeTransfer(address(host_), amountIn_);
        amountOut_ = host_.exchangeIn(
            tokenIn_, amountIn_, tokenOut_, minAmountOut_, recipient_, true, deadline_
        );
    }

    function _toShare(IStandardExchange vault_, IERC20 tokenIn_, uint256 amountIn_, uint256 deadline_)
        internal
        returns (uint256 shareOut_)
    {
        address share_ = address(vault_);
        if (address(tokenIn_) == share_) return amountIn_;
        shareOut_ = _nestedExchangeInPush(
            IStandardExchangeIn(share_),
            tokenIn_,
            amountIn_,
            IERC20(share_),
            0,
            address(this),
            deadline_
        );
        if (shareOut_ == 0) revert Repo.InvalidRoute(address(tokenIn_), share_);
    }

    function _joinShare(uint256 shareAmount_, address shareToken_) internal returns (uint256 lpOut_) {
        if (shareAmount_ == 0) return 0;
        IERC20(shareToken_).forceApprove(Repo._layoutStruct().hook, shareAmount_);
        lpOut_ = _hook().joinSingleAssetExactIn(
            shareToken_, shareAmount_, _bondLpHolder(), 0, block.timestamp + 1
        );
        IERC20(shareToken_).forceApprove(Repo._layoutStruct().hook, 0);
    }

    function _joinUnbalanced(address[] memory tokens_, uint256[] memory amounts_)
        internal
        returns (uint256 lpOut_)
    {
        address hook_ = Repo._layoutStruct().hook;
        for (uint256 i; i < tokens_.length; ++i) {
            if (amounts_[i] > 0) {
                IERC20(tokens_[i]).forceApprove(hook_, amounts_[i]);
            }
        }
        lpOut_ = IUniswapV4SeBufferHook(hook_).joinUnbalanced(
            tokens_, amounts_, _bondLpHolder(), 0, block.timestamp + 1
        );
        for (uint256 j; j < tokens_.length; ++j) {
            IERC20(tokens_[j]).forceApprove(hook_, 0);
        }
    }

    function _pullNftLp(uint256 lpAmount_) internal {
        if (lpAmount_ == 0) return;
        Repo.Storage storage s = Repo._layoutStruct();
        IERC20 lp_ = IERC20(s.hook);
        uint256 have_ = lp_.balanceOf(address(this));
        if (have_ >= lpAmount_) return;
        uint256 need_ = lpAmount_ - have_;
        s.bondNftVault.transferHeldToken(lp_, address(this), need_);
    }

    /// @dev Join DETF as protocol id-0 LP. Caps to diamond balance.
    function _rejoinDetfAsProtocolLp(uint256 detfAmt_) internal {
        if (detfAmt_ == 0) return;
        Repo.Storage storage s = Repo._layoutStruct();
        uint256 have_ = IERC20(address(this)).balanceOf(address(this));
        if (detfAmt_ > have_) detfAmt_ = have_;
        if (detfAmt_ == 0) return;
        IERC20(address(this)).forceApprove(s.hook, detfAmt_);
        uint256 lpOut_ = _hook().joinSingleAssetExactIn(
            address(this), detfAmt_, _bondLpHolder(), 0, block.timestamp + 1
        );
        IERC20(address(this)).forceApprove(s.hook, 0);
        if (lpOut_ > 0) {
            s.bondNftVault.addToDETFNFT(s.bondNftVault.detfNFTId(), lpOut_);
            _topUpFeeCreatorShares();
        }
    }

    /// @dev Swap this-call withdrawn non-DETF legs to DETF. Snapshot DETF-buying power once;
    ///      dump largest leftover first (D15-5). Uses exit amounts, not booked inventory.
    function _dumpWithdrawnToDetf(address[] memory tokens_, uint256[] memory withdrawn_, uint256 deadline_)
        internal
    {
        (uint256[] memory order_, uint256[] memory amt_, uint256 m_) = _dumpPlan(tokens_, withdrawn_);
        _executeDumpPlan(tokens_, order_, amt_, m_, deadline_);
    }

    function _dumpPlan(address[] memory tokens_, uint256[] memory withdrawn_)
        private
        view
        returns (uint256[] memory order_, uint256[] memory amt_, uint256 m_)
    {
        uint256 n_ = tokens_.length < withdrawn_.length ? tokens_.length : withdrawn_.length;
        amt_ = new uint256[](n_);
        uint256[] memory pow_ = new uint256[](n_);
        order_ = new uint256[](n_);
        for (uint256 i; i < n_; ++i) {
            if (tokens_[i] == address(this) || withdrawn_[i] == 0) continue;
            uint256 a_ = _dumpAmt(tokens_[i], withdrawn_[i]);
            if (a_ == 0) continue;
            amt_[m_] = a_;
            uint256 q_ = _dumpQuote(tokens_[i], a_);
            pow_[m_] = q_ == 0 ? a_ : q_;
            order_[m_] = i;
            unchecked {
                ++m_;
            }
        }
        _sortDumpDesc(order_, pow_, amt_, m_);
    }

    function _dumpAmt(address token_, uint256 withdrawn_) private view returns (uint256 a_) {
        uint256 have_ = IERC20(token_).balanceOf(address(this));
        a_ = withdrawn_ < have_ ? withdrawn_ : have_;
    }

    function _dumpQuote(address token_, uint256 amt_) private view returns (uint256 q_) {
        try _hook().previewSwapExactIn(token_, address(this), amt_) returns (uint256 d_) {
            q_ = d_;
        } catch {}
    }

    function _sortDumpDesc(
        uint256[] memory order_,
        uint256[] memory pow_,
        uint256[] memory amt_,
        uint256 m_
    ) private pure {
        for (uint256 a = 1; a < m_; ++a) {
            uint256 idx_ = order_[a];
            uint256 p_ = pow_[a];
            uint256 w_ = amt_[a];
            uint256 b_ = a;
            while (b_ > 0 && pow_[b_ - 1] < p_) {
                order_[b_] = order_[b_ - 1];
                pow_[b_] = pow_[b_ - 1];
                amt_[b_] = amt_[b_ - 1];
                unchecked {
                    --b_;
                }
            }
            order_[b_] = idx_;
            pow_[b_] = p_;
            amt_[b_] = w_;
        }
    }

    function _executeDumpPlan(
        address[] memory tokens_,
        uint256[] memory order_,
        uint256[] memory amt_,
        uint256 m_,
        uint256 deadline_
    ) private {
        for (uint256 k; k < m_; ++k) {
            _swapDumpLeg(tokens_[order_[k]], amt_[k], deadline_);
        }
    }

    function _swapDumpLeg(address t_, uint256 dump_, uint256 deadline_) private {
        uint256 have_ = IERC20(t_).balanceOf(address(this));
        if (dump_ > have_) dump_ = have_;
        if (dump_ == 0) return;
        address hook_ = Repo._layoutStruct().hook;
        IERC20(t_).forceApprove(hook_, dump_);
        try IUniswapV4SeBufferHook(hook_).ownerSwapExactIn(t_, address(this), dump_, 0, deadline_) {} catch {}
        IERC20(t_).forceApprove(hook_, 0);
    }

    /// @dev Physical unwind of hook LP to DETF. Does not spend booked diamond inventory.
    function _exitLpToDetf(uint256 lpAmount_, uint256 deadline_) internal returns (uint256 detfFromLp_) {
        if (lpAmount_ == 0) return 0;
        Repo.Storage storage s = Repo._layoutStruct();
        uint256 detfBefore_ = IERC20(address(this)).balanceOf(address(this));
        _pullNftLp(lpAmount_);
        address[] memory tokens_ = _hook().tokens();
        IERC20(s.hook).forceApprove(s.hook, lpAmount_);
        uint256[] memory withdrawn_ =
            _hook().exitProportional(lpAmount_, address(this), new uint256[](tokens_.length), deadline_);
        IERC20(s.hook).forceApprove(s.hook, 0);
        _dumpWithdrawnToDetf(tokens_, withdrawn_, deadline_);
        uint256 detfAfter_ = IERC20(address(this)).balanceOf(address(this));
        detfFromLp_ = detfAfter_ > detfBefore_ ? detfAfter_ - detfBefore_ : 0;
    }

    /// @dev Claim-token D15: convertToAssets-scale the originalShares slice so previewRedeem matches.
    function _claimUnwindLp(uint256 lpAmount_) internal view returns (uint256 unwindLp_) {
        unwindLp_ = lpAmount_;
        Repo.Storage storage s = Repo._layoutStruct();
        if (address(s.bondNftVault) == address(0) || lpAmount_ == 0) return unwindLp_;
        uint256 orig_ = s.bondNftVault.originalSharesOf(s.bondNftVault.detfNFTId());
        if (orig_ == 0) return unwindLp_;
        uint256 assets_ = orig_;
        try s.bondNftVault.convertToAssets(orig_) returns (uint256 a_) {
            if (a_ > 0) assets_ = a_;
        } catch {}
        unwindLp_ = Math.mulDiv(lpAmount_, assets_, orig_);
        if (unwindLp_ == 0) unwindLp_ = lpAmount_;
        uint256 nftLp_ = IERC20(s.hook).balanceOf(address(s.bondNftVault));
        uint256 diamondLp_ = IERC20(s.hook).balanceOf(address(this));
        uint256 cap_ = nftLp_ + diamondLp_;
        if (unwindLp_ > cap_) unwindLp_ = cap_;
    }

    /// @dev Owed DETF for claim-token redeem. Two-step identity of `previewRedeem` (R-22).
    ///      `totalShares` is post-burn here; reconstruct pre-burn shares from `lpAmount`.
    function _claimOwedDetf(uint256 lpAmount_)
        internal
        view
        returns (uint256 owed_, uint256 unwindLp_, uint256 floorOwed_)
    {
        unwindLp_ = _claimUnwindLp(lpAmount_);
        Repo.Storage storage s = Repo._layoutStruct();
        if (address(s.bondNftVault) == address(0) || lpAmount_ == 0) {
            owed_ = _previewClaimLiquidity(unwindLp_);
            floorOwed_ = owed_;
            return (owed_, unwindLp_, floorOwed_);
        }
        uint256 orig_ = s.bondNftVault.originalSharesOf(s.bondNftVault.detfNFTId());
        if (orig_ == 0) {
            owed_ = _previewClaimLiquidity(unwindLp_);
            floorOwed_ = owed_;
            return (owed_, unwindLp_, floorOwed_);
        }
        uint256 assets_ = orig_;
        try s.bondNftVault.convertToAssets(orig_) returns (uint256 a_) {
            if (a_ > 0) assets_ = a_;
        } catch {}
        uint256 zapout_ = _previewClaimLiquidity(assets_);
        uint256 sPost_;
        if (address(s.rebasingClaimToken) != address(0)) {
            sPost_ = s.rebasingClaimToken.totalShares();
        }
        if (sPost_ == 0 || lpAmount_ >= orig_) {
            owed_ = zapout_;
            floorOwed_ = zapout_;
            return (owed_, unwindLp_, floorOwed_);
        }
        uint256 extShares_ = Math.mulDiv(lpAmount_, sPost_, orig_ - lpAmount_, Math.Rounding.Ceil);
        uint256 sPre_ = sPost_ + extShares_;
        if (sPre_ == 0 || zapout_ == 0 || extShares_ == 0) {
            owed_ = Math.mulDiv(zapout_, lpAmount_, orig_);
            floorOwed_ = owed_;
            return (owed_, unwindLp_, floorOwed_);
        }
        uint256 internalTotal_ = sPre_ * 1e9;
        uint256 rate_ = Math.mulDiv(zapout_, 1e18 * 1e9, internalTotal_);
        if (rate_ == 0) {
            owed_ = Math.mulDiv(zapout_, lpAmount_, orig_);
            floorOwed_ = owed_;
            return (owed_, unwindLp_, floorOwed_);
        }
        uint256 amount_ = Math.mulDiv(extShares_ * 1e9, rate_, 1e18 * 1e9);
        uint256 shares2_ = Math.mulDiv(amount_, 1e18 * 1e9, rate_);
        floorOwed_ = Math.mulDiv(shares2_, rate_, 1e18 * 1e9);
        owed_ = Math.mulDiv(shares2_, rate_, 1e18 * 1e9, Math.Rounding.Ceil);
    }

    function _previewClaimLiquidity(uint256 lpAmount_) internal view returns (uint256 detfOut_) {
        if (lpAmount_ == 0) return 0;
        address[] memory tokens_ = _hook().tokens();
        uint256[] memory withdrawn_ = _hook().previewExitProportional(lpAmount_);
        uint256 n_ = tokens_.length < withdrawn_.length ? tokens_.length : withdrawn_.length;
        for (uint256 i; i < n_; ++i) {
            if (tokens_[i] == address(this)) {
                detfOut_ += withdrawn_[i];
                continue;
            }
            if (withdrawn_[i] == 0) continue;
            try _hook().previewSwapExactIn(tokens_[i], address(this), withdrawn_[i]) returns (uint256 d_) {
                detfOut_ += d_;
            } catch {}
        }
    }

    /// @dev Same-tx `previewRedeem` quote stored on the claim token (R-22).
    function _claimHint() internal view returns (uint256 hinted_) {
        address claim_ = address(Repo._layoutStruct().rebasingClaimToken);
        if (claim_ == address(0)) return 0;
        (bool ok_, bytes memory data_) =
            claim_.staticcall(abi.encodeWithSelector(bytes4(keccak256("pendingRedeemDetfOut()"))));
        if (ok_ && data_.length >= 32) hinted_ = abi.decode(data_, (uint256));
    }

    /// @dev Dump any leftover hook pair sitting on the diamond after proportional exit.
    function _dumpSittingPairToDetf() internal {
        address[] memory tokens_ = _hook().tokens();
        uint256 n_ = tokens_.length;
        uint256[] memory amt_ = new uint256[](n_);
        for (uint256 i; i < n_; ++i) {
            if (tokens_[i] == address(this)) continue;
            amt_[i] = IERC20(tokens_[i]).balanceOf(address(this));
        }
        _dumpWithdrawnToDetf(tokens_, amt_, block.timestamp + 1);
    }

    /// @dev Claim-token pay: never above `previewRedeem` hint (`owed_`). Surplus rejoins as protocol LP.
    ///      Sequential leftover dump can be 1–3 wei short of the independent zapout quote; mint that dust.
    function _claimPayAmount(uint256 owed_, uint256 produced_)
        internal
        returns (uint256 detfOut_)
    {
        detfOut_ = (owed_ > 0 && produced_ > owed_) ? owed_ : produced_;
        if (owed_ > detfOut_ && owed_ - detfOut_ <= 3) {
            uint256 have_ = IERC20(address(this)).balanceOf(address(this));
            if (have_ < owed_) _mintDetf(address(this), owed_ - have_);
            detfOut_ = owed_;
        }
    }

    /// @dev D15 pending-first: if harvest covers two-step owed, pay and skip LP unwind.
    function _claimPayFromPending(uint256 owed_, uint256 harvested_, address recipient_)
        internal
        returns (bool paid_)
    {
        if (owed_ == 0 || harvested_ < owed_) return false;
        IERC20(address(this)).safeTransfer(recipient_, owed_);
        uint256 leftoverHarv_ = harvested_ - owed_;
        if (leftoverHarv_ > 0) _rejoinDetfAsProtocolLp(leftoverHarv_);
        _trySweepDust();
        _syncAllExpectedHoldReserves();
        return true;
    }

    function _claimRemoveOrigShares(uint256 lpAmount_) internal {
        Repo.Storage storage s = Repo._layoutStruct();
        if (address(s.bondNftVault) == address(0)) return;
        uint256 id0_ = s.bondNftVault.originalSharesOf(s.bondNftVault.detfNFTId());
        uint256 remove_ = lpAmount_ < id0_ ? lpAmount_ : id0_;
        if (remove_ > 0) {
            s.bondNftVault.removeFromDETFNFT(s.bondNftVault.detfNFTId(), remove_);
        }
    }

    function _returnLeftoverLp() internal {
        Repo.Storage storage s = Repo._layoutStruct();
        IERC20 lp_ = IERC20(s.hook);
        uint256 bal_ = lp_.balanceOf(address(this));
        if (bal_ == 0 || address(s.bondNftVault) == address(0)) return;
        lp_.safeTransfer(address(s.bondNftVault), bal_);
    }

    function _bookUnassignedLp(uint256 lpOut_) internal {
        if (lpOut_ == 0) return;
        Repo.Storage storage s = Repo._layoutStruct();
        if (address(s.bondNftVault) == address(0)) return;
        if (s.bondNftVault.totalOriginalShares() == 0) {
            s.bondNftVault.addToDETFNFT(s.bondNftVault.detfNFTId(), lpOut_);
        }
    }

    function _trySweepDust() internal {
        try this.sweepDustAtomic() {} catch {}
    }

    function sweepDustAtomic() external {
        if (msg.sender != address(this)) revert Repo.NotAuthorized(msg.sender);
        _sweepDustBody();
    }

    function _sweepDustBody() internal {
        Repo.Storage storage s = Repo._layoutStruct();
        address hookAddr_ = s.hook;
        if (hookAddr_ == address(0)) return;
        IERC20 lp_ = IERC20(hookAddr_);
        uint256 lpBal_ = lp_.balanceOf(address(this));
        if (lpBal_ > 0 && address(s.bondNftVault) != address(0)) {
            lp_.safeTransfer(address(s.bondNftVault), lpBal_);
            _bookUnassignedLp(lpBal_);
        }
        if (!s.isReserveLive) return;
        address[] memory tokens_ = IUniswapV4SeBufferHook(hookAddr_).tokens();
        address[] storage ses_ = s.hookStandardExchanges._values();
        // Later residual joins can refund an earlier-cleared pair via conservation.
        // Repeat until diamond leftovers are dust or the round makes no progress.
        for (uint256 round_; round_ < 8; ++round_) {
            uint256 dirty_;
            for (uint256 i; i < tokens_.length; ++i) {
                uint256 before_ = IERC20(tokens_[i]).balanceOf(address(this));
                _tryJoinResidual(tokens_[i]);
                if (IERC20(tokens_[i]).balanceOf(address(this)) > 10) dirty_ = 1;
                if (IERC20(tokens_[i]).balanceOf(address(this)) + 10 < before_) dirty_ = 1;
            }
            for (uint256 j; j < ses_.length; ++j) {
                uint256 beforeSe_ = IERC20(ses_[j]).balanceOf(address(this));
                _tryJoinResidual(ses_[j]);
                if (IERC20(ses_[j]).balanceOf(address(this)) > 10) dirty_ = 1;
                if (IERC20(ses_[j]).balanceOf(address(this)) + 10 < beforeSe_) dirty_ = 1;
            }
            if (dirty_ == 0) break;
        }
    }

    function _tryJoinResidual(address token_) internal {
        uint256 bal_ = IERC20(token_).balanceOf(address(this));
        if (bal_ == 0) return;

        Repo.Storage storage s = Repo._layoutStruct();
        bool isSe_ = s.hookStandardExchanges._contains(token_);
        // Leftover DETF/SE: partial-add. Zap of leftover DETF sells inventory;
        // leftover SE unwraps back to pair after the pair loop.
        if (!isSe_ && token_ != address(this)) {
            _joinResidualCapped(token_, bal_);
        }
        uint256 leftover_ = IERC20(token_).balanceOf(address(this));
        if (leftover_ > 10) _joinResidualUnbalanced(token_, leftover_);

        if (token_ == address(this)) {
            return;
        }
        leftover_ = IERC20(token_).balanceOf(address(this));
        if (leftover_ <= 10) return;
        // Last-resort only: tiny unjoinable remainder. Do not park large SE
        // (donates book without LP and can fail later burns).
        if (s.hookPairTokens._contains(token_)) {
            _wrapAndParkPair(token_);
        } else if (isSe_) {
            _parkResidualOnHook(token_);
        }
    }

    /// @dev Orbital leftover can MathDomain on a 3-leg zap of the full residual.
    ///      Halve and retry so R19 still clears.
    function _joinResidualCapped(address token_, uint256 amount_) internal {
        if (amount_ == 0) return;
        address hook_ = Repo._layoutStruct().hook;
        uint256 amt_ = amount_;
        for (uint256 i; i < 24 && amt_ > 10; ++i) {
            uint256 before_ = IERC20(token_).balanceOf(address(this));
            if (amt_ > before_) amt_ = before_;
            if (amt_ <= 10) break;
            IERC20(token_).forceApprove(hook_, amt_);
            try _hook().joinSingleAssetExactIn(
                token_, amt_, _bondLpHolder(), 0, block.timestamp + 1
            ) returns (uint256 lpOut_) {
                IERC20(token_).forceApprove(hook_, 0);
                _bookUnassignedLp(lpOut_);
                uint256 after_ = IERC20(token_).balanceOf(address(this));
                if (lpOut_ == 0 || after_ + 10 >= before_) {
                    amt_ = amt_ / 2;
                } else {
                    amt_ = after_;
                }
            } catch {
                IERC20(token_).forceApprove(hook_, 0);
                amt_ = amt_ / 2;
            }
        }
        IERC20(token_).forceApprove(hook_, 0);
    }

    function _joinResidualUnbalanced(address token_, uint256 amount_) internal {
        if (amount_ <= 10) return;
        address hook_ = Repo._layoutStruct().hook;
        address[] memory tokensIn_ = new address[](1);
        uint256[] memory amounts_ = new uint256[](1);
        tokensIn_[0] = token_;
        uint256 amt_ = amount_;
        for (uint256 i; i < 24 && amt_ > 10; ++i) {
            uint256 before_ = IERC20(token_).balanceOf(address(this));
            if (amt_ > before_) amt_ = before_;
            if (amt_ <= 10) break;
            amounts_[0] = amt_;
            IERC20(token_).forceApprove(hook_, amt_);
            try _hook().joinUnbalanced(
                tokensIn_, amounts_, _bondLpHolder(), 0, block.timestamp + 1
            ) returns (uint256 lpOut_) {
                IERC20(token_).forceApprove(hook_, 0);
                _bookUnassignedLp(lpOut_);
                uint256 after_ = IERC20(token_).balanceOf(address(this));
                if (lpOut_ == 0 || after_ + 10 >= before_) {
                    amt_ = amt_ / 2;
                } else {
                    amt_ = after_;
                }
            } catch {
                IERC20(token_).forceApprove(hook_, 0);
                amt_ = amt_ / 2;
            }
        }
        IERC20(token_).forceApprove(hook_, 0);
    }

    function _parkResidualOnHook(address token_) internal {
        uint256 left_ = IERC20(token_).balanceOf(address(this));
        if (left_ <= 10) return;
        IERC20(token_).safeTransfer(Repo._layoutStruct().hook, left_ - 10);
    }

    function _wrapAndParkPair(address pair_) internal {
        Repo.Storage storage s = Repo._layoutStruct();
        address se_ = IUniswapV4SeBufferHook(s.hook).standardExchangeOf(pair_);
        if (se_ == address(0)) return;
        uint256 amt_ = IERC20(pair_).balanceOf(address(this));
        if (amt_ > 10) amt_ -= 10;
        for (uint256 i; i < 16 && amt_ > 0; ++i) {
            uint256 before_ = IERC20(pair_).balanceOf(address(this));
            if (amt_ + 10 > before_) amt_ = before_ > 10 ? before_ - 10 : 0;
            if (amt_ == 0) break;
            try this.sweepPairToShare(se_, pair_, amt_) returns (uint256) {
                uint256 seBal_ = IERC20(se_).balanceOf(address(this));
                if (seBal_ > 10) IERC20(se_).safeTransfer(s.hook, seBal_ - 10);
                uint256 after_ = IERC20(pair_).balanceOf(address(this));
                if (after_ + 10 >= before_) amt_ = amt_ / 2;
                else amt_ = after_ > 10 ? after_ - 10 : 0;
            } catch {
                amt_ = amt_ / 2;
            }
        }
        _parkResidualOnHook(se_);
    }

    function sweepPairToShare(address se_, address pair_, uint256 amount_)
        external
        returns (uint256 shares_)
    {
        if (msg.sender != address(this)) revert Repo.NotAuthorized(msg.sender);
        IERC20(pair_).forceApprove(se_, amount_);
        shares_ = IStandardExchangeIn(se_).exchangeIn(
            IERC20(pair_), amount_, IERC20(se_), 0, address(this), false, block.timestamp + 1
        );
        IERC20(pair_).forceApprove(se_, 0);
    }
}
