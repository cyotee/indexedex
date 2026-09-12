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
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";
import {IVaultRegistryDisableQuery} from "contracts/interfaces/IVaultRegistryDisableQuery.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {MultiAssetBasicVaultRepo} from "contracts/vaults/basic/MultiAssetBasicVaultRepo.sol";
import {MixedBufferMultiVaultStableDetfRepo as Repo} from "./MixedBufferMultiVaultStableDetfRepo.sol";

import {StableMath} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/StableMath.sol";
import {IStandardExchange} from "contracts/interfaces/IStandardExchange.sol";
import {IMixedBufferMultiVaultStablePool} from "contracts/protocols/dexes/balancer/v3/pools/stable/mixedBufferMultiVault/IMixedBufferMultiVaultStablePool.sol";

/// @notice Mixed Buffer reserve accounting with funded staking and mandatory price gates.
abstract contract MixedBufferMultiVaultStableDetfCommon is ReentrancyLockModifiers, DETFBalancerReserveSwapTarget {
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

    function _syncAllExpectedHoldReserves() internal {
        address[] memory tokens = MultiAssetBasicVaultRepo._vaultTokens();
        for (uint256 i; i < tokens.length; ++i) {
            IERC20 t = IERC20(tokens[i]);
            MultiAssetBasicVaultRepo._updateReserve(t, t.balanceOf(address(this)));
        }
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

    function _tokenRate(TokenInfo memory info_) internal view returns (uint256) {
        return address(info_.rateProvider) == address(0) ? ONE_WAD : info_.rateProvider.getRate();
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

    function _amp() internal view returns (uint256 amp_) {
        Repo.Storage storage s = Repo._layoutStruct();
        (amp_,,) = IMixedBufferMultiVaultStablePool(s.reservePool).getAmplificationParameter();
        if (amp_ == 0) {
            // Fallback: raw amp * AMP_PRECISION if pool view not yet ready.
            amp_ = s.amplificationParameter * StableMath.AMP_PRECISION;
        }
    }

    function _mathBalancesLive() internal view returns (uint256[] memory balances_) {
        Repo.Storage storage s = Repo._layoutStruct();
        IMixedBufferMultiVaultStablePool pool_ = IMixedBufferMultiVaultStablePool(s.reservePool);
        uint256[] memory live_ = _reserveVault().getCurrentLiveBalances(s.reservePool);
        uint256 n_ = live_.length;
        balances_ = new uint256[](n_);
        for (uint256 i; i < n_; ++i) {
            balances_[i] = live_[i];
        }
        balances_[s.bufferIndex] = pool_.virtualBuffer();
        for (uint256 i; i < s.vaultCount; ++i) {
            balances_[s.shareIndexes[i]] = pool_.derivedShareDepth(i);
        }
    }

    function _initializeReserve(
        uint256 detfAmount_,
        uint256 bufferAmount_,
        uint256[] memory vaultShareAmounts_
    ) internal returns (uint256 bptOut_) {
        Repo.Storage storage s = Repo._layoutStruct();
        uint256 n_ = uint256(s.vaultCount) + 2; // DETF + buffer + N shares
        IERC20[] memory tokens_ = new IERC20[](n_);
        uint256[] memory amounts_ = new uint256[](n_);

        tokens_[s.detfIndex] = IERC20(address(this));
        amounts_[s.detfIndex] = detfAmount_;
        if (detfAmount_ > 0) {
            IERC20(address(this)).safeTransfer(address(_reserveVault()), detfAmount_);
        }

        tokens_[s.bufferIndex] = s.bufferToken;
        amounts_[s.bufferIndex] = bufferAmount_;
        if (bufferAmount_ > 0) {
            s.bufferToken.safeTransfer(address(_reserveVault()), bufferAmount_);
        }

        for (uint256 i; i < s.vaultCount; ++i) {
            uint256 idx_ = s.shareIndexes[i];
            tokens_[idx_] = s.vaultShares[i];
            amounts_[idx_] = vaultShareAmounts_[i];
            if (vaultShareAmounts_[i] > 0) {
                s.vaultShares[i].safeTransfer(address(_reserveVault()), vaultShareAmounts_[i]);
            }
        }

        // Sort by address for Balancer initialize order.
        for (uint256 i; i < n_; ++i) {
            for (uint256 j = i + 1; j < n_; ++j) {
                if (address(tokens_[j]) < address(tokens_[i])) {
                    (tokens_[i], tokens_[j]) = (tokens_[j], tokens_[i]);
                    (amounts_[i], amounts_[j]) = (amounts_[j], amounts_[i]);
                }
            }
        }

        bptOut_ = _reserveRouter().prepayInitialize(s.reservePool, tokens_, amounts_, 0, "");
    }

    function _joinReserveUnbalanced(uint256[] memory amountsIn_) internal returns (uint256 bptOut_) {
        Repo.Storage storage s = Repo._layoutStruct();
        bptOut_ = _reserveRouter().prepayAddLiquidityUnbalanced(s.reservePool, amountsIn_, 0, "");
    }

    function _joinReserveBufferAndDetf(uint256 bufferAmount_, uint256 detfAmount_)
        internal
        returns (uint256 bptOut_)
    {
        Repo.Storage storage s = Repo._layoutStruct();
        uint256 n_ = _reserveVault().getCurrentLiveBalances(s.reservePool).length;
        uint256[] memory amountsIn_ = new uint256[](n_);
        amountsIn_[s.bufferIndex] = bufferAmount_;
        amountsIn_[s.detfIndex] = detfAmount_;
        if (detfAmount_ > 0) IERC20(address(this)).safeTransfer(address(_reserveVault()), detfAmount_);
        if (bufferAmount_ > 0) s.bufferToken.safeTransfer(address(_reserveVault()), bufferAmount_);
        bptOut_ = _joinReserveUnbalanced(amountsIn_);
    }

    function _joinReserveShareAndDetf(uint256 legIndex_, uint256 vaultShares_, uint256 detfAmount_)
        internal
        returns (uint256 bptOut_)
    {
        Repo.Storage storage s = Repo._layoutStruct();
        uint256 n_ = _reserveVault().getCurrentLiveBalances(s.reservePool).length;
        uint256[] memory amountsIn_ = new uint256[](n_);
        amountsIn_[s.shareIndexes[legIndex_]] = vaultShares_;
        amountsIn_[s.detfIndex] = detfAmount_;
        if (detfAmount_ > 0) IERC20(address(this)).safeTransfer(address(_reserveVault()), detfAmount_);
        if (vaultShares_ > 0) s.vaultShares[legIndex_].safeTransfer(address(_reserveVault()), vaultShares_);
        bptOut_ = _joinReserveUnbalanced(amountsIn_);
    }

    function _joinReserveVaultShareOnly(uint256 legIndex_, uint256 vaultShares_)
        internal
        returns (uint256 bptOut_)
    {
        Repo.Storage storage s = Repo._layoutStruct();
        uint256 n_ = _reserveVault().getCurrentLiveBalances(s.reservePool).length;
        uint256[] memory amountsIn_ = new uint256[](n_);
        amountsIn_[s.shareIndexes[legIndex_]] = vaultShares_;
        s.vaultShares[legIndex_].safeTransfer(address(_reserveVault()), vaultShares_);
        bptOut_ = _joinReserveUnbalanced(amountsIn_);
    }

    function _joinReserveLegs(uint256 detfAmount_, uint256 bufferAmount_, uint256[] memory vaultShareAmounts_)
        internal
        returns (uint256 bptOut_)
    {
        Repo.Storage storage s = Repo._layoutStruct();
        uint256 n_ = _reserveVault().getCurrentLiveBalances(s.reservePool).length;
        uint256[] memory amountsIn_ = new uint256[](n_);
        amountsIn_[s.detfIndex] = detfAmount_;
        amountsIn_[s.bufferIndex] = bufferAmount_;
        if (detfAmount_ > 0) IERC20(address(this)).safeTransfer(address(_reserveVault()), detfAmount_);
        if (bufferAmount_ > 0) s.bufferToken.safeTransfer(address(_reserveVault()), bufferAmount_);
        for (uint256 i; i < s.vaultCount; ++i) {
            uint256 amt_ = i < vaultShareAmounts_.length ? vaultShareAmounts_[i] : 0;
            amountsIn_[s.shareIndexes[i]] = amt_;
            if (amt_ > 0) s.vaultShares[i].safeTransfer(address(_reserveVault()), amt_);
        }
        bptOut_ = _joinReserveUnbalanced(amountsIn_);
    }

    function _exitReserveProportional(uint256 bptIn_)
        internal
        returns (uint256 detfOut_, uint256 bufferOut_, uint256[] memory vaultSharesOut_)
    {
        Repo.Storage storage s = Repo._layoutStruct();
        _pullBptFromNft(bptIn_);
        uint256 n_ = _reserveVault().getCurrentLiveBalances(s.reservePool).length;
        uint256[] memory minOut_ = new uint256[](n_);
        IERC20(s.reservePool).forceApprove(address(_reserveRouter()), bptIn_);
        uint256[] memory raw_ =
            _reserveRouter().prepayRemoveLiquidityProportional(s.reservePool, bptIn_, minOut_, "");
        detfOut_ = raw_[s.detfIndex];
        bufferOut_ = raw_[s.bufferIndex];
        vaultSharesOut_ = new uint256[](s.vaultCount);
        for (uint256 i; i < s.vaultCount; ++i) {
            vaultSharesOut_[i] = raw_[s.shareIndexes[i]];
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

    /// @dev Native reserve index for a configured payment or redemption token.
    function _paymentIndex(IERC20 token_) internal view returns (uint256) {
        Repo.Storage storage s_ = Repo._layoutStruct();
        if (address(token_) == address(s_.bufferToken)) return s_.bufferIndex;
        (bool found_, uint256 leg_) = Repo._findVaultShareIndex(token_);
        if (!found_) revert Repo.InvalidRoute(address(token_), address(this));
        return s_.shareIndexes[leg_];
    }

    function _toLive(uint256 index_, uint256 raw_) internal view returns (uint256) {
        (uint256[] memory scale_, uint256[] memory rates_) = _reserveVault().getPoolTokenRates(Repo._layoutStruct().reservePool);
        return Math.mulDiv(raw_, scale_[index_] * rates_[index_], ONE_WAD);
    }

    function _toRaw(uint256 index_, uint256 live_) internal view returns (uint256) {
        (uint256[] memory scale_, uint256[] memory rates_) = _reserveVault().getPoolTokenRates(Repo._layoutStruct().reservePool);
        return ScalingHelpers.toRawUndoRateRoundDown(live_, scale_[index_], ScalingHelpers.computeRateRoundUp(rates_[index_]));
    }

    /// @dev Preserve the family peg seed: average the normalized non-DETF legs.
    function _pegSeedDetfAmount(uint256 buffer_, uint256[] memory shares_) internal view returns (uint256) {
        Repo.Storage storage s_ = Repo._layoutStruct();
        if (shares_.length != s_.vaultCount) revert Repo.InvalidBootstrapAmounts();
        uint256 value_ = _toLive(s_.bufferIndex, buffer_);
        for (uint256 i; i < s_.vaultCount; ++i) value_ += _toLive(s_.shareIndexes[i], shares_[i]);
        uint256 seed_ = value_ / (uint256(s_.vaultCount) + 1) / 1e9;
        if (seed_ == 0) revert Repo.InvalidBootstrapAmounts();
        return seed_;
    }

    /// @dev First bond uses the existing linear peg seed with the full duration multiplier once.
    function _firstBondPurchase(uint256 buffer_, uint256[] memory shares_, uint256 duration_) internal view returns (uint256) {
        uint256 multiplier_ = _bonusMultiplier(duration_);
        uint256[] memory boosted_ = new uint256[](shares_.length);
        for (uint256 i; i < shares_.length; ++i) boosted_[i] = Math.mulDiv(shares_[i], multiplier_, ONE_WAD);
        return _pegSeedDetfAmount(Math.mulDiv(buffer_, multiplier_, ONE_WAD), boosted_);
    }

    function _quoteBondJoinDetf(uint256 index_, uint256 amount_) internal view returns (uint256) {
        Repo.Storage storage s_ = Repo._layoutStruct();
        (,, uint256[] memory raw_,) = _reserveVault().getPoolTokenInfo(s_.reservePool);
        if (raw_[index_] == 0) return _toLive(index_, amount_) / 1e9;
        return Math.mulDiv(amount_, raw_[s_.detfIndex], raw_[index_]);
    }

    function _quoteSwap(uint256 indexIn_, uint256 indexOut_, uint256 amount_) internal view returns (uint256) {
        if (amount_ == 0) return 0;
        uint256[] memory balances_ = _mathBalancesLive();
        uint256 amp_ = _amp();
        uint256 invariant_ = StableMath.computeInvariant(amp_, balances_);
        uint256 input_ = _toLive(indexIn_, amount_);
        input_ -= Math.mulDiv(input_, _reserveVault().getStaticSwapFeePercentage(Repo._layoutStruct().reservePool), ONE_WAD, Math.Rounding.Ceil);
        uint256 live_ = StableMath.computeOutGivenExactIn(amp_, balances_, indexIn_, indexOut_, input_, invariant_);
        return _toRaw(indexOut_, live_);
    }

    function _quoteOrdinaryDetf(IERC20 token_, uint256 amount_) internal view returns (uint256) {
        uint256 boosted_ = amount_ + Math.mulDiv(amount_, _seigniorageIncentiveWad(), ONE_WAD);
        return _quoteSwap(_paymentIndex(token_), Repo._layoutStruct().detfIndex, boosted_);
    }

    function _quoteBondPurchase(IERC20 token_, uint256 amount_, uint256 duration_) internal view returns (uint256) {
        uint256 boosted_ = Math.mulDiv(amount_, _bonusMultiplier(duration_), ONE_WAD);
        return _quoteSwap(_paymentIndex(token_), Repo._layoutStruct().detfIndex, boosted_);
    }

    function _syntheticPriceForSupply(uint256 supply_) internal view returns (uint256) {
        if (supply_ == 0) return ONE_WAD;
        uint256 owned_ = _protocolLp();
        uint256 total_ = IERC20(Repo._layoutStruct().reservePool).totalSupply();
        if (owned_ == 0 || total_ == 0) return ONE_WAD;
        uint256[] memory balances_ = _mathBalancesLive();
        uint256 value_;
        for (uint256 i; i < balances_.length; ++i) value_ += Math.mulDiv(balances_[i], owned_, total_);
        return Math.mulDiv(value_, 1e9, supply_);
    }

    function _previewBurnToken(IERC20 out_, uint256 amount_) internal view returns (uint256) {
        uint256 index_ = _paymentIndex(out_);
        Repo.Storage storage s_ = Repo._layoutStruct();
        if (!_previewPrimaryBurn()) return _quoteSwap(s_.detfIndex, index_, amount_);
        uint256 lp_ = _bptForDetfShares(amount_, true);
        uint256 total_ = IERC20(s_.reservePool).totalSupply();
        if (lp_ == 0 || total_ == 0) return 0;
        (,, uint256[] memory raw_,) = _reserveVault().getPoolTokenInfo(s_.reservePool);
        return Math.mulDiv(raw_[index_], lp_, total_);
    }

    /// @dev Preserve buffer input through its existing SE conversion before the non-DETF join.
    function _joinPayment(IERC20 token_, uint256 amount_) internal returns (uint256) {
        Repo.Storage storage s_ = Repo._layoutStruct();
        if (address(token_) == address(s_.bufferToken)) {
            uint256 shares_ = _nestedExchangeInPush(s_.underlyingVaults[0], token_, amount_, s_.vaultShares[0], 0, address(this), block.timestamp);
            return _joinReserveVaultShareOnly(0, shares_);
        }
        (bool found_, uint256 leg_) = Repo._findVaultShareIndex(token_);
        if (!found_) revert Repo.InvalidRoute(address(token_), address(this));
        return _joinReserveVaultShareOnly(leg_, amount_);
    }

    function _previewJoinDonatedCapital(IERC20 token_, uint256 amount_) internal view returns (uint256) {
        Repo.Storage storage s_ = Repo._layoutStruct();
        if (!s_.isReserveLive || amount_ == 0) return 0;
        if (address(token_) == address(this)) return _previewUnbalancedBpt(s_.detfIndex, amount_);
        if (address(token_) == address(s_.bufferToken)) {
            uint256 shares_ = s_.underlyingVaults[0].previewExchangeIn(token_, amount_, s_.vaultShares[0]);
            return _previewUnbalancedBpt(s_.shareIndexes[0], shares_);
        }
        (bool found_, uint256 leg_) = Repo._findVaultShareIndex(token_);
        return found_ ? _previewUnbalancedBpt(s_.shareIndexes[leg_], amount_) : 0;
    }
}
