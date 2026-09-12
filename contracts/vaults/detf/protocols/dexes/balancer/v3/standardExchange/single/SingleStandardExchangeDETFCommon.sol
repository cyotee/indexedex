// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {DETFBalancerLiquidityQuoteLib} from "contracts/vaults/detf/protocols/dexes/balancer/v3/common/DETFBalancerLiquidityQuoteLib.sol";

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeErrors} from "@crane/contracts/interfaces/IStandardExchangeErrors.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {TokenInfo} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";
import {BalancerV3VaultAwareRepo} from "@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3VaultAwareRepo.sol";
import {BalancerV3WeightedPoolQuote} from "@crane/contracts/protocols/dexes/balancer/v3/utils/BalancerV3WeightedPoolQuote.sol";
import {FixedPoint} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/FixedPoint.sol";
import {ScalingHelpers} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/helpers/ScalingHelpers.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {ReentrancyLockRepo} from "@crane/contracts/access/reentrancy/ReentrancyLockRepo.sol";
import {IBalancerV3StandardExchangeRouterProxy} from "contracts/interfaces/proxies/IBalancerV3StandardExchangeRouterProxy.sol";
import {BalancerV3StandardExchangeRouterAwareRepo} from "contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterAwareRepo.sol";
import {DETFBalancerReserveSwapTarget} from "contracts/vaults/detf/protocols/dexes/balancer/v3/common/DETFBalancerReserveSwapTarget.sol";
import {DETFMintSplitLib} from "contracts/vaults/detf/common/core/DETFMintSplitLib.sol";
import {MintSplit} from "contracts/vaults/detf/common/core/DETFMintSplit.sol";
import {DETFBondNFTMathLib} from "contracts/vaults/detf/common/core/DETFBondNFTMathLib.sol";
import {DETFNaturalExpansionLib} from "contracts/vaults/detf/common/core/DETFNaturalExpansionLib.sol";
import {BondTerms} from "contracts/interfaces/VaultFeeTypes.sol";
import {IBasicVault} from "contracts/interfaces/IBasicVault.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {SingleStandardExchangeDETFRepo as Repo} from "./SingleStandardExchangeDETFRepo.sol";

/// @notice Single-SE reserve adapter with funded staking and mandatory primary/swap routing.
abstract contract SingleStandardExchangeDETFCommon is ReentrancyLockModifiers, DETFBalancerReserveSwapTarget {
    using BetterSafeERC20 for IERC20;
    using FixedPoint for uint256;
    uint256 internal constant ONE_WAD = 1e18;
    event NaturalSupplyExpanded(uint256 mintAmount, uint256 syntheticPrice, uint256 timestamp);
    function _requireReserveLive() internal view {
        if (!Repo._layoutStruct().isReserveLive) {
            revert Repo.ReservePoolNotInitialized();
        }
    }

    function _requireActive(uint256 deadline_, uint256 amount_) internal view {
        if (amount_ == 0) revert Repo.ZeroAmount();
        if (block.timestamp > deadline_) {
            revert Repo.DeadlineExpired(deadline_);
        }
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

    function _previewUnbalancedBpt(uint256 tokenIndex_, uint256 amountIn_) internal view returns (uint256) {
        return DETFBalancerLiquidityQuoteLib._singleAssetJoin(address(_reserveVault()), Repo._layoutStruct().reservePool, tokenIndex_, amountIn_);
    }

    function _previewJoinDonatedCapital(IERC20 token_, uint256 amount_)
        internal
        view
        returns (uint256 lpOut_)
    {
        if (amount_ == 0) return 0;
        Repo.Storage storage s = Repo._layoutStruct();
        if (!s.isReserveLive) return 0;
        if (address(token_) == s.reservePool) return 0;
        if (address(token_) == address(this)) return _previewUnbalancedBpt(s.detfIndex, amount_);
        if (address(token_) == address(s.rebasingClaimToken)) return 0;
        uint256 vaultShares_ = amount_;
        if (address(token_) != address(s.standardExchangeVaultShare)) {
            if (!_isAllowlistedTokenIn(token_)) return 0;
            try IStandardExchangeIn(address(s.standardExchangeVault)).previewExchangeIn(
                token_, amount_, s.standardExchangeVaultShare
            ) returns (uint256 sh_) {
                vaultShares_ = sh_;
            } catch {
                return 0;
            }
        }
        return _previewUnbalancedBpt(s.vaultShareIndex, vaultShares_);
    }

    function _sendJoinBptToNft(uint256 bptOut_) internal {
        Repo.Storage storage s = Repo._layoutStruct();
        if (bptOut_ == 0) revert Repo.ZeroAmount();
        IERC20(s.reservePool).safeTransfer(address(s.bondNftVault), bptOut_);
    }

    function _custodyBptOnNft(uint256 bptAmount_) internal {
        if (bptAmount_ == 0) return;
        Repo.Storage storage s = Repo._layoutStruct();
        IERC20(s.reservePool).safeTransfer(address(s.bondNftVault), bptAmount_);
    }

    function _pullBptFromNft(uint256 bptAmount_) internal {
        if (bptAmount_ == 0) return;
        Repo.Storage storage s = Repo._layoutStruct();
        IERC20 bpt_ = IERC20(s.reservePool);
        uint256 have_ = bpt_.balanceOf(address(this));
        if (have_ >= bptAmount_) return;
        uint256 need_ = bptAmount_ - have_;
        s.bondNftVault.transferHeldToken(bpt_, address(this), need_);
    }

    function _isAllowlistedTokenIn(IERC20 token_) internal view returns (bool) {
        Repo.Storage storage s = Repo._layoutStruct();
        if (address(token_) == address(s.standardExchangeVaultShare)) return true;
        if (address(token_) == address(this)) return false;

        address[] memory tokens_ = IBasicVault(address(s.standardExchangeVault)).vaultTokens();
        for (uint256 i; i < tokens_.length; ++i) {
            if (tokens_[i] == address(token_)) return true;
        }
        return false;
    }

    function _effectiveLockDuration(uint256 lockDuration_) internal view returns (uint256 effective_) {
        BondTerms memory terms_ = DETFBondNFTMathLib._bondTerms(address(this));
        if (lockDuration_ < terms_.minLockDuration) {
            revert Repo.LockDurationTooShort(lockDuration_, terms_.minLockDuration);
        }
        effective_ = lockDuration_ > terms_.maxLockDuration ? terms_.maxLockDuration : lockDuration_;
    }

    function _bonusMultiplier(uint256 effectiveLockDuration_) internal view returns (uint256) {
        return DETFBondNFTMathLib._bonusMultiplierOfVault(address(this), effectiveLockDuration_);
    }

    function _seigniorageIncentiveWad() internal view returns (uint256) {
        Repo.Storage storage s = Repo._layoutStruct();
        if (address(s.feeOracle) == address(0)) return 0;
        return s.feeOracle.seigniorageIncentivePercentageOfVault(address(this));
    }

    function _usageFeeWad() internal view returns (uint256) {
        Repo.Storage storage s = Repo._layoutStruct();
        if (address(s.feeOracle) == address(0)) return 0;
        return s.feeOracle.usageFeeOfVault(address(this));
    }

    function _splitMintedDetf(uint256 gross_) internal view returns (MintSplit memory split_) {
        split_.grossDetf = gross_;
        if (gross_ == 0) return split_;
        (uint256 user_, uint256 pot_) = DETFMintSplitLib._splitLiveGross(gross_, _seigniorageIncentiveWad());
        split_.userDetf = user_;
        split_.inventoryDetf = pot_;
        split_.feeToDetf = 0;
    }

    function _reserveRouter() internal view returns (IBalancerV3StandardExchangeRouterProxy) {
        return BalancerV3StandardExchangeRouterAwareRepo._balancerV3StandardExchangeRouter();
    }

    function _reserveVault() internal view returns (IVault) {
        return BalancerV3VaultAwareRepo._balancerV3Vault();
    }

    function _joinReserveBothLegs(uint256 detfAmount_, uint256 vaultShares_) internal returns (uint256 bptOut_) {
        Repo.Storage storage s = Repo._layoutStruct();
        IVault bal_ = _reserveVault();
        address pool_ = s.reservePool;

        if (detfAmount_ > 0) {
            IERC20(address(this)).safeTransfer(address(bal_), detfAmount_);
        }
        if (vaultShares_ > 0) {
            s.standardExchangeVaultShare.safeTransfer(address(bal_), vaultShares_);
        }

        if (IERC20(pool_).totalSupply() == 0) {
            IERC20[] memory tokens_ = new IERC20[](2);
            uint256[] memory exactAmountsIn_ = new uint256[](2);
            if (address(this) < address(s.standardExchangeVaultShare)) {
                tokens_[0] = IERC20(address(this));
                tokens_[1] = s.standardExchangeVaultShare;
                exactAmountsIn_[0] = detfAmount_;
                exactAmountsIn_[1] = vaultShares_;
            } else {
                tokens_[0] = s.standardExchangeVaultShare;
                tokens_[1] = IERC20(address(this));
                exactAmountsIn_[0] = vaultShares_;
                exactAmountsIn_[1] = detfAmount_;
            }
            bptOut_ = _reserveRouter().prepayInitialize(pool_, tokens_, exactAmountsIn_, 0, "");
        } else {
            uint256 n_ = bal_.getCurrentLiveBalances(pool_).length;
            uint256[] memory amountsIn_ = new uint256[](n_);
            amountsIn_[s.detfIndex] = detfAmount_;
            amountsIn_[s.vaultShareIndex] = vaultShares_;
            bptOut_ = _reserveRouter().prepayAddLiquidityUnbalanced(pool_, amountsIn_, 0, "");
        }
    }

    function _joinReserveVaultSharesOnly(uint256 vaultShares_) internal returns (uint256 bptOut_) {
        Repo.Storage storage s = Repo._layoutStruct();
        IVault bal_ = _reserveVault();
        uint256 n_ = bal_.getCurrentLiveBalances(s.reservePool).length;
        uint256[] memory amountsIn_ = new uint256[](n_);
        amountsIn_[s.vaultShareIndex] = vaultShares_;
        s.standardExchangeVaultShare.safeTransfer(address(bal_), vaultShares_);
        bptOut_ = _reserveRouter().prepayAddLiquidityUnbalanced(s.reservePool, amountsIn_, 0, "");
    }

    function _joinReserveDetfOnly(uint256 detfAmount_) internal returns (uint256 bptOut_) {
        Repo.Storage storage s = Repo._layoutStruct();
        uint256 n_ = _reserveVault().getCurrentLiveBalances(s.reservePool).length;
        uint256[] memory amountsIn_ = new uint256[](n_);
        amountsIn_[s.detfIndex] = detfAmount_;
        IERC20(address(this)).safeTransfer(address(_reserveVault()), detfAmount_);
        bptOut_ = _reserveRouter().prepayAddLiquidityUnbalanced(s.reservePool, amountsIn_, 0, "");
    }

    function _exitReserveProportional(uint256 bptIn_)
        internal
        returns (uint256 detfOut_, uint256 vaultSharesOut_)
    {
        Repo.Storage storage s = Repo._layoutStruct();
        _pullBptFromNft(bptIn_);
        uint256 n_ = _reserveVault().getCurrentLiveBalances(s.reservePool).length;
        uint256[] memory minOut_ = new uint256[](n_);
        IERC20(s.reservePool).forceApprove(address(_reserveRouter()), bptIn_); // BetterSafeERC20
        uint256[] memory raw_ =
            _reserveRouter().prepayRemoveLiquidityProportional(s.reservePool, bptIn_, minOut_, "");
        detfOut_ = raw_[s.detfIndex];
        vaultSharesOut_ = raw_[s.vaultShareIndex];
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
        uint256 minOut_,
        address recipient_,
        uint256 deadline_
    ) internal returns (uint256 amountOut_) {
        if (amountIn_ == 0) return 0;
        tokenIn_.safeTransfer(address(host_), amountIn_);
        amountOut_ = host_.exchangeIn(
            tokenIn_, amountIn_, tokenOut_, minOut_, recipient_, true, deadline_
        );
    }

    function _mintDetf(address to_, uint256 amount_) internal {
        if (amount_ > 0) ERC20Repo._mint(to_, amount_);
    }

    function _burnDetf(address from_, uint256 amount_) internal {
        ERC20Repo._burn(from_, amount_);
    }

    function _protocolLp() internal view returns (uint256) {
        Repo.Storage storage s_ = Repo._layoutStruct();
        IERC20 lp_ = IERC20(s_.reservePool);
        return lp_.balanceOf(address(this)) + lp_.balanceOf(address(s_.bondNftVault));
    }

    /// @dev Normalize both pool legs before applying the retained synthetic-price equation.
    function _syntheticPriceForSupply(uint256 supply_) internal view returns (uint256) {
        if (supply_ == 0) return ONE_WAD;
        Repo.Storage storage s_ = Repo._layoutStruct();
        uint256 lpSupply_ = IERC20(s_.reservePool).totalSupply();
        uint256 owned_ = _protocolLp();
        if (lpSupply_ == 0 || owned_ == 0) return ONE_WAD;
        (, TokenInfo[] memory info_, uint256[] memory raw_,) = _reserveVault().getPoolTokenInfo(s_.reservePool);
        uint256 detf_ = Math.mulDiv(raw_[s_.detfIndex], owned_, lpSupply_);
        uint256 shares_ = Math.mulDiv(raw_[s_.vaultShareIndex], owned_, lpSupply_);
        uint256 value_ = detf_ * 1e9 + _shareScaled18(shares_).mulDown(_tokenRate(info_[s_.vaultShareIndex]));
        return Math.mulDiv(value_, 1e9, supply_);
    }

    function _syntheticPrice() internal view returns (uint256) {
        return _syntheticPriceForSupply(ERC20Repo._totalSupply());
    }

    function _isMintingAllowed() internal view returns (bool) {
        Repo.Storage storage s_ = Repo._layoutStruct();
        return s_.isReserveLive && _syntheticPrice() > s_.mintThreshold;
    }

    function _isBurningAllowed() internal view returns (bool) {
        Repo.Storage storage s_ = Repo._layoutStruct();
        return s_.isReserveLive && _syntheticPrice() < s_.burnThreshold;
    }

    function _previewPrimaryMint() internal view returns (bool) {
        Repo.Storage storage s_ = Repo._layoutStruct();
        return s_.isReserveLive
            && _syntheticPriceForSupply(ERC20Repo._totalSupply() + _pendingExpansionDetf()) > s_.mintThreshold;
    }

    function _previewPrimaryBurn() internal view returns (bool) {
        Repo.Storage storage s_ = Repo._layoutStruct();
        return s_.isReserveLive
            && _syntheticPriceForSupply(ERC20Repo._totalSupply() + _pendingExpansionDetf()) < s_.burnThreshold;
    }

    function _shareScaled18(uint256 raw_) internal view returns (uint256) {
        uint8 decimals_ = IERC20Metadata(address(Repo._layoutStruct().standardExchangeVaultShare)).decimals();
        return Math.mulDiv(raw_, 10 ** (18 - decimals_), 1);
    }

    function _tokenRate(TokenInfo memory info_) internal view returns (uint256) {
        return address(info_.rateProvider) == address(0) ? ONE_WAD : info_.rateProvider.getRate();
    }

    /// @dev Preserve the family's weight-derived opening price, in nine-decimal DETF units.
    function _quoteDetfBootstrap(uint256 shares_) internal view returns (uint256) {
        Repo.Storage storage s_ = Repo._layoutStruct();
        uint256 rate_ = address(s_.vaultRateProvider) == address(0) ? ONE_WAD : s_.vaultRateProvider.getRate();
        return Math.mulDiv(_shareScaled18(shares_).mulDown(rate_), s_.detfWeight, s_.vaultShareWeight) / 1e9;
    }

    /// @dev Live reserve quote without issuance uplift. Both directions use the same pool fee/math.
    function _quoteReserveSwap(bool detfIn_, uint256 rawIn_) internal view returns (uint256) {
        Repo.Storage storage s_ = Repo._layoutStruct();
        (, TokenInfo[] memory info_, uint256[] memory raw_,) = _reserveVault().getPoolTokenInfo(s_.reservePool);
        uint256 rate_ = _tokenRate(info_[s_.vaultShareIndex]);
        uint256 detfBalance_ = raw_[s_.detfIndex] * 1e9;
        uint256 shareBalance_ = _shareScaled18(raw_[s_.vaultShareIndex]).mulDown(rate_);
        uint256 input_ = detfIn_ ? rawIn_ * 1e9 : _shareScaled18(rawIn_).mulDown(rate_);
        uint256 output_ = BalancerV3WeightedPoolQuote.computeOutGivenExactInAfterFee(
            detfIn_ ? detfBalance_ : shareBalance_, detfIn_ ? s_.detfWeight : s_.vaultShareWeight,
            detfIn_ ? shareBalance_ : detfBalance_, detfIn_ ? s_.vaultShareWeight : s_.detfWeight,
            input_, _reserveVault().getStaticSwapFeePercentage(s_.reservePool)
        );
        if (!detfIn_) return output_ / 1e9;
        uint256 scale_ = 10 ** (18 - IERC20Metadata(address(s_.standardExchangeVaultShare)).decimals());
        // Balancer rounds a non-integral output-token rate up before undoing scaling.
        return ScalingHelpers.toRawUndoRateRoundDown(output_, scale_, ScalingHelpers.computeRateRoundUp(rate_));
    }

    function _quoteDetfOutForVaultShares(uint256 shares_) internal view returns (uint256) {
        return _quoteReserveSwap(false, shares_ + Math.mulDiv(shares_, _seigniorageIncentiveWad(), ONE_WAD));
    }

    function _quoteBondJoinDetf(uint256 shares_) internal view returns (uint256) {
        Repo.Storage storage s_ = Repo._layoutStruct();
        if (!s_.isReserveLive) {
            // Retain the original weight-only liquidity seed. The purchased quote has its
            // own opening rate; it must not change the separately matched reserve leg.
            return Math.mulDiv(_shareScaled18(shares_), s_.detfWeight, s_.vaultShareWeight) / 1e9;
        }
        (,, uint256[] memory raw_,) = _reserveVault().getPoolTokenInfo(s_.reservePool);
        return Math.mulDiv(shares_, raw_[s_.detfIndex], raw_[s_.vaultShareIndex]);
    }

    function _quoteBondPurchase(uint256 shares_, uint256 duration_) internal view returns (uint256) {
        uint256 boosted_ = Math.mulDiv(shares_, _bonusMultiplier(duration_), ONE_WAD);
        return Repo._layoutStruct().isReserveLive ? _quoteReserveSwap(false, boosted_) : _quoteDetfBootstrap(boosted_);
    }

    function _splitBondDetf(uint256 gross_, uint256 liquidity_) internal view returns (MintSplit memory split_) {
        split_.grossDetf = gross_;
        (split_.userDetf, split_.inventoryDetf,) = DETFMintSplitLib._splitBond(gross_, liquidity_, _seigniorageIncentiveWad());
    }

    function _bptForDetfShares(uint256 amount_, bool preview_) internal view returns (uint256) {
        uint256 supply_ = ERC20Repo._totalSupply();
        if (preview_) supply_ += _pendingExpansionDetf();
        return supply_ == 0 ? 0 : Math.mulDiv(amount_, _protocolLp(), supply_);
    }

    function _previewBptUnwind(uint256 lp_) internal view returns (uint256) {
        Repo.Storage storage s_ = Repo._layoutStruct();
        uint256 supply_ = IERC20(s_.reservePool).totalSupply();
        if (lp_ == 0 || supply_ == 0) return 0;
        (,, uint256[] memory raw_,) = _reserveVault().getPoolTokenInfo(s_.reservePool);
        return Math.mulDiv(raw_[s_.vaultShareIndex], lp_, supply_);
    }

    function _expansionQuote() internal view returns (uint256 amount_, uint256 boundary_, uint256 price_) {
        Repo.Storage storage s_ = Repo._layoutStruct();
        price_ = _syntheticPrice();
        (amount_, boundary_) = DETFNaturalExpansionLib.computeEpochExpansion(DETFNaturalExpansionLib.EpochInput({
            isLive: s_.isReserveLive, isMintAllowed: price_ > s_.mintThreshold,
            syntheticPrice: price_, totalDetfSupply: ERC20Repo._totalSupply(),
            lastSettledBoundary: s_.lastExpansionTimestamp, nowTimestamp: block.timestamp,
            closureRatePerSecond: s_.expansionClosureRatePerSecond
        }));
    }

    function _pendingExpansionDetf() internal view returns (uint256 pending_) { (pending_,,) = _expansionQuote(); }

    function _updateExpansionMintOnRewards() internal returns (uint256 amount_) {
        uint256 boundary_;
        uint256 price_;
        (amount_, boundary_, price_) = _expansionQuote();
        Repo._layoutStruct().lastExpansionTimestamp = boundary_;
        if (amount_ != 0) {
            _fundStakingRewards(amount_);
            emit NaturalSupplyExpanded(amount_, price_, boundary_);
        }
    }

    function _fundStakingRewards(uint256 amount_) internal {
        if (amount_ == 0) return;
        address staking_ = address(Repo._layoutStruct().rebasingClaimToken);
        _mintDetf(address(this), amount_);
        IERC20(address(this)).forceApprove(staking_, amount_);
        IStakedDETF(staking_).fundRewards(amount_);
        IERC20(address(this)).forceApprove(staking_, 0);
    }

    function _pullToken(IERC20 token_, uint256 amount_, bool pretransferred_) internal returns (uint256) {
        uint256 before_ = token_.balanceOf(address(this));
        if (!pretransferred_) {
            token_.safeTransferFrom(msg.sender, address(this), amount_);
            uint256 received_ = token_.balanceOf(address(this)) - before_;
            if (received_ != amount_) revert ISecurePullErrors.TransferDeltaInsufficient(amount_, received_);
        } else {
            uint256 reserved_ = MultiAssetBasicVaultRepo._reserveOfToken(address(token_));
            uint256 available_ = before_ > reserved_ ? before_ - reserved_ : 0;
            if (amount_ > available_) revert ISecurePullErrors.TransferDeltaInsufficient(amount_, available_);
        }
        return amount_;
    }

    function _receiveVaultShares(IERC20 token_, uint256 amount_, bool prepaid_, uint256 deadline_)
        internal returns (uint256)
    {
        Repo.Storage storage s_ = Repo._layoutStruct();
        if (!_isAllowlistedTokenIn(token_)) revert Repo.UnsupportedRoute(token_, IERC20(address(this)));
        uint256 received_ = _pullToken(token_, amount_, prepaid_);
        if (address(token_) == address(s_.standardExchangeVaultShare)) return received_;
        return _nestedExchangeInPush(s_.standardExchangeVault, token_, received_, s_.standardExchangeVaultShare, 0, address(this), deadline_);
    }

    function _sendVaultShares(uint256 shares_, IERC20 out_, uint256 min_, address to_, uint256 deadline_)
        internal returns (uint256 received_)
    {
        Repo.Storage storage s_ = Repo._layoutStruct();
        if (!_isAllowlistedTokenIn(out_)) revert Repo.UnsupportedRoute(IERC20(address(this)), out_);
        if (address(out_) == address(s_.standardExchangeVaultShare)) {
            received_ = shares_;
            out_.safeTransfer(to_, received_);
        } else {
            received_ = _nestedExchangeInPush(s_.standardExchangeVault, s_.standardExchangeVaultShare, shares_, out_, min_, to_, deadline_);
        }
        if (received_ < min_) revert IStandardExchangeErrors.MinAmountNotMet(min_, received_);
    }

    function _previewVaultSharesIn(IERC20 token_, uint256 amount_) internal view returns (uint256) {
        Repo.Storage storage s_ = Repo._layoutStruct();
        if (!_isAllowlistedTokenIn(token_)) revert Repo.UnsupportedRoute(token_, IERC20(address(this)));
        if (address(token_) == address(s_.standardExchangeVaultShare)) return amount_;
        return s_.standardExchangeVault.previewExchangeIn(token_, amount_, s_.standardExchangeVaultShare);
    }

    function _previewVaultSharesOut(uint256 shares_, IERC20 token_) internal view returns (uint256) {
        Repo.Storage storage s_ = Repo._layoutStruct();
        if (!_isAllowlistedTokenIn(token_)) revert Repo.UnsupportedRoute(IERC20(address(this)), token_);
        if (address(token_) == address(s_.standardExchangeVaultShare)) return shares_;
        return s_.standardExchangeVault.previewExchangeIn(s_.standardExchangeVaultShare, shares_, token_);
    }
}
