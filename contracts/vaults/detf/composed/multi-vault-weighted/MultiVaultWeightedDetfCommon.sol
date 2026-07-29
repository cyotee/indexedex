// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IVault} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IVault.sol";
import {IRateProvider} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/IRateProvider.sol";
import {
    ScalingHelpers
} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/helpers/ScalingHelpers.sol";
import {FixedPoint} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/math/FixedPoint.sol";
import {TokenInfo} from "@crane/contracts/interfaces/protocols/dexes/balancer/v3/VaultTypes.sol";
import {
    BalancerV3VaultAwareRepo
} from "@crane/contracts/protocols/dexes/balancer/v3/vault/BalancerV3VaultAwareRepo.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {
    IBalancerV3StandardExchangeRouterProxy
} from "contracts/interfaces/proxies/IBalancerV3StandardExchangeRouterProxy.sol";
import {
    BalancerV3StandardExchangeRouterAwareRepo
} from "contracts/protocols/dexes/balancer/v3/routers/BalancerV3StandardExchangeRouterAwareRepo.sol";
import {
    BalancerV3WeightedPoolQuote
} from "@crane/contracts/protocols/dexes/balancer/v3/utils/BalancerV3WeightedPoolQuote.sol";
import {DETFThresholdPolicy} from "contracts/vaults/detf/core/DETFThresholdPolicy.sol";
import {DETFUsageFeeLib} from "contracts/vaults/detf/core/DETFUsageFeeLib.sol";
import {DETFBondNFTMathLib} from "contracts/vaults/detf/core/DETFBondNFTMathLib.sol";
import {BondTerms} from "contracts/interfaces/VaultFeeTypes.sol";
import {
    MultiVaultWeightedDetfRepo
} from "contracts/vaults/detf/composed/multi-vault-weighted/MultiVaultWeightedDetfRepo.sol";

/// @title MultiVaultWeightedDetfCommon
/// @notice Shared helpers: pricing, thresholds, multi-leg reserve join/exit, bond lock clamp.
abstract contract MultiVaultWeightedDetfCommon is ReentrancyLockModifiers {
    using BetterSafeERC20 for IERC20;
    using FixedPoint for uint256;
    using ScalingHelpers for uint256;

    uint256 internal constant ONE_WAD = 1e18;

    struct MintSplit {
        uint256 grossDetf;
        uint256 userDetf;
        uint256 feeToDetf;
        uint256 protocolDetf;
    }

    function _requireReserveLive() internal view {
        if (!MultiVaultWeightedDetfRepo._layoutStruct().isReserveLive) {
            revert MultiVaultWeightedDetfRepo.ReservePoolNotInitialized();
        }
    }

    function _requireActive(uint256 deadline_, uint256 amount_) internal view {
        if (amount_ == 0) revert MultiVaultWeightedDetfRepo.ZeroAmount();
        if (block.timestamp > deadline_) {
            revert MultiVaultWeightedDetfRepo.DeadlineExpired(deadline_);
        }
    }

    function _effectiveLockDuration(uint256 lockDuration_) internal view returns (uint256 effective_) {
        BondTerms memory terms_ = DETFBondNFTMathLib._bondTerms(address(this));
        if (lockDuration_ < terms_.minLockDuration) {
            revert MultiVaultWeightedDetfRepo.LockDurationTooShort(lockDuration_, terms_.minLockDuration);
        }
        effective_ = lockDuration_ > terms_.maxLockDuration ? terms_.maxLockDuration : lockDuration_;
    }

    function _syntheticPrice() internal view returns (uint256 syntheticPrice_) {
        MultiVaultWeightedDetfRepo.Storage storage s = MultiVaultWeightedDetfRepo._layoutStruct();
        uint256 totalSupply_ = ERC20Repo._totalSupply();
        if (totalSupply_ == 0) return ONE_WAD;

        IVault balVault_ = BalancerV3VaultAwareRepo._balancerV3Vault();
        uint256 bptSupply_ = IERC20(s.reservePool).totalSupply();
        uint256 ownedBpt_ = IERC20(s.reservePool).balanceOf(address(this));
        if (address(s.bondNftVault) != address(0)) {
            ownedBpt_ += IERC20(s.reservePool).balanceOf(address(s.bondNftVault));
        }
        if (bptSupply_ == 0 || ownedBpt_ == 0) return ONE_WAD;

        TokenInfo[] memory info_;
        uint256[] memory balancesRaw_;
        (, info_, balancesRaw_,) = balVault_.getPoolTokenInfo(s.reservePool);

        uint256 totalValue_ = balancesRaw_[s.detfIndex] * ownedBpt_ / bptSupply_;
        for (uint256 i; i < s.vaultCount; ++i) {
            uint256 idx_ = s.vaultShareIndexes[i];
            uint256 ownedShares_ = balancesRaw_[idx_] * ownedBpt_ / bptSupply_;
            uint256 rate_ = ONE_WAD;
            if (address(info_[idx_].rateProvider) != address(0)) {
                rate_ = info_[idx_].rateProvider.getRate();
            }
            totalValue_ += ownedShares_.mulDown(rate_);
        }
        syntheticPrice_ = totalValue_.divDown(totalSupply_);
    }

    /// @dev Live-coupled: inert ⇒ false. Live + Open ⇒ true. Live + Policy ⇒ strict synthetic deadband.
    function _isMintingAllowed() internal view returns (bool) {
        MultiVaultWeightedDetfRepo.Storage storage s = MultiVaultWeightedDetfRepo._layoutStruct();
        if (!s.isReserveLive) return false;
        return DETFThresholdPolicy._isMintingAllowed(s.thresholdMode, s.mintThreshold, _syntheticPrice());
    }

    /// @dev Live-coupled: inert ⇒ false. Live + Open ⇒ true. Live + Policy ⇒ strict synthetic deadband.
    function _isBurningAllowed() internal view returns (bool) {
        MultiVaultWeightedDetfRepo.Storage storage s = MultiVaultWeightedDetfRepo._layoutStruct();
        if (!s.isReserveLive) return false;
        return DETFThresholdPolicy._isBurningAllowed(s.thresholdMode, s.burnThreshold, _syntheticPrice());
    }

    function _seigniorageIncentiveWad() internal view returns (uint256) {
        MultiVaultWeightedDetfRepo.Storage storage s = MultiVaultWeightedDetfRepo._layoutStruct();
        if (address(s.feeOracle) == address(0)) return 0;
        return s.feeOracle.seigniorageIncentivePercentageOfVault(address(this));
    }

    function _usageFeeWad() internal view returns (uint256) {
        MultiVaultWeightedDetfRepo.Storage storage s = MultiVaultWeightedDetfRepo._layoutStruct();
        if (address(s.feeOracle) == address(0)) return 0;
        return s.feeOracle.usageFeeOfVault(address(this));
    }

    /// @dev Gross DETF from vault-share input on leg `legIndex_`.
    function _quoteDetfOutForVaultShares(uint256 legIndex_, uint256 vaultShares_)
        internal
        view
        returns (uint256 detfOut_)
    {
        MultiVaultWeightedDetfRepo.Storage storage s = MultiVaultWeightedDetfRepo._layoutStruct();
        if (IERC20(s.reservePool).totalSupply() == 0 || !s.isReserveLive) {
            return _quoteDetfBootstrap(s, legIndex_, vaultShares_);
        }
        return _quoteDetfLive(s, legIndex_, vaultShares_);
    }

    function _quoteDetfBootstrap(
        MultiVaultWeightedDetfRepo.Storage storage s,
        uint256 legIndex_,
        uint256 vaultShares_
    ) private view returns (uint256 detfOut_) {
        uint256 rate_ = address(s.rateProviders[legIndex_]) != address(0)
            ? s.rateProviders[legIndex_].getRate()
            : ONE_WAD;
        detfOut_ = vaultShares_.mulDown(rate_).mulDivUp(s.weightDetf, s.vaultWeights[legIndex_]);
        if (detfOut_ == 0) detfOut_ = vaultShares_;
    }

    function _quoteDetfLive(
        MultiVaultWeightedDetfRepo.Storage storage s,
        uint256 legIndex_,
        uint256 vaultShares_
    ) private view returns (uint256 detfOut_) {
        (uint256 balIn_, uint256 balOut_, uint256 rateOut_, uint256 fee_) = _loadCurveInputs(s, legIndex_);
        uint256 rateIn_ = address(s.rateProviders[legIndex_]) != address(0)
            ? s.rateProviders[legIndex_].getRate()
            : ONE_WAD;
        uint256 amountInLive_ =
            (vaultShares_ + vaultShares_.mulDown(_seigniorageIncentiveWad())).mulDown(rateIn_);
        uint256 outLive_ = BalancerV3WeightedPoolQuote.computeOutGivenExactInAfterFee(
            balIn_, s.vaultWeights[legIndex_], balOut_, s.weightDetf, amountInLive_, fee_
        );
        detfOut_ = outLive_.divDown(rateOut_);
        if (detfOut_ == 0) detfOut_ = vaultShares_;
    }

    function _loadCurveInputs(MultiVaultWeightedDetfRepo.Storage storage s, uint256 legIndex_)
        private
        view
        returns (uint256 balInLive_, uint256 balOutLive_, uint256 rateOut_, uint256 fee_)
    {
        IVault bal_ = BalancerV3VaultAwareRepo._balancerV3Vault();
        fee_ = bal_.getStaticSwapFeePercentage(s.reservePool);
        TokenInfo[] memory tokenInfo_;
        uint256[] memory balancesRaw_;
        (, tokenInfo_, balancesRaw_,) = bal_.getPoolTokenInfo(s.reservePool);
        uint256 shareIdx_ = s.vaultShareIndexes[legIndex_];
        balInLive_ = _toLiveScaled18(balancesRaw_[shareIdx_], tokenInfo_[shareIdx_]);
        balOutLive_ = _toLiveScaled18(balancesRaw_[s.detfIndex], tokenInfo_[s.detfIndex]);
        rateOut_ = _tokenRate(tokenInfo_[s.detfIndex]);
    }

    function _splitMintedDetf(uint256 gross_) internal view returns (MintSplit memory split_) {
        split_.grossDetf = gross_;
        if (gross_ == 0) return split_;
        (uint256 afterFee_, uint256 feeTo_) = DETFUsageFeeLib._splitUsageFee(gross_, _usageFeeWad());
        split_.feeToDetf = feeTo_;
        uint256 halfInc_ = _seigniorageIncentiveWad() / 2;
        split_.protocolDetf = afterFee_.mulDown(halfInc_);
        split_.userDetf = afterFee_ - split_.protocolDetf;
    }

    function _toLiveScaled18(uint256 raw_, TokenInfo memory info_) internal view returns (uint256) {
        return raw_.mulDown(_tokenRate(info_));
    }

    function _tokenRate(TokenInfo memory info_) internal view returns (uint256) {
        if (address(info_.rateProvider) == address(0)) return ONE_WAD;
        return info_.rateProvider.getRate();
    }

    function _reserveRouter() internal view returns (IBalancerV3StandardExchangeRouterProxy) {
        return BalancerV3StandardExchangeRouterAwareRepo._balancerV3StandardExchangeRouter();
    }

    function _reserveVault() internal view returns (IVault) {
        return BalancerV3VaultAwareRepo._balancerV3Vault();
    }

    /// @dev Initialize pool with DETF + all vault legs. `vaultShareAmounts_[i]` for each leg.
    function _initializeReserve(uint256 detfAmount_, uint256[] memory vaultShareAmounts_)
        internal
        returns (uint256 bptOut_)
    {
        MultiVaultWeightedDetfRepo.Storage storage s = MultiVaultWeightedDetfRepo._layoutStruct();
        uint256 n_ = uint256(s.vaultCount) + 1;
        IERC20[] memory tokens_ = new IERC20[](n_);
        uint256[] memory exactAmountsIn_ = new uint256[](n_);

        // Build unsorted then place by pool index.
        tokens_[s.detfIndex] = IERC20(address(this));
        exactAmountsIn_[s.detfIndex] = detfAmount_;
        if (detfAmount_ > 0) {
            IERC20(address(this)).safeTransfer(address(_reserveVault()), detfAmount_);
        }

        for (uint256 i; i < s.vaultCount; ++i) {
            uint256 idx_ = s.vaultShareIndexes[i];
            tokens_[idx_] = s.vaultShares[i];
            exactAmountsIn_[idx_] = vaultShareAmounts_[i];
            if (vaultShareAmounts_[i] > 0) {
                s.vaultShares[i].safeTransfer(address(_reserveVault()), vaultShareAmounts_[i]);
            }
        }

        // Tokens array must be sorted by address for Balancer initialize.
        IERC20[] memory sortedTokens_ = new IERC20[](n_);
        uint256[] memory sortedAmounts_ = new uint256[](n_);
        for (uint256 i; i < n_; ++i) {
            sortedTokens_[i] = tokens_[i];
            sortedAmounts_[i] = exactAmountsIn_[i];
        }
        // Pool was registered with sorted tokens; amounts already in pool-index order if indexes match sort.
        // Re-sort by token address to match factory registration order.
        for (uint256 i; i < n_; ++i) {
            for (uint256 j = i + 1; j < n_; ++j) {
                if (address(sortedTokens_[j]) < address(sortedTokens_[i])) {
                    (sortedTokens_[i], sortedTokens_[j]) = (sortedTokens_[j], sortedTokens_[i]);
                    (sortedAmounts_[i], sortedAmounts_[j]) = (sortedAmounts_[j], sortedAmounts_[i]);
                }
            }
        }

        bptOut_ = _reserveRouter().prepayInitialize(s.reservePool, sortedTokens_, sortedAmounts_, 0, "");
    }

    function _joinReserveVaultShareOnly(uint256 legIndex_, uint256 vaultShares_)
        internal
        returns (uint256 bptOut_)
    {
        MultiVaultWeightedDetfRepo.Storage storage s = MultiVaultWeightedDetfRepo._layoutStruct();
        uint256 n_ = _reserveVault().getCurrentLiveBalances(s.reservePool).length;
        uint256[] memory amountsIn_ = new uint256[](n_);
        amountsIn_[s.vaultShareIndexes[legIndex_]] = vaultShares_;
        s.vaultShares[legIndex_].safeTransfer(address(_reserveVault()), vaultShares_);
        bptOut_ = _reserveRouter().prepayAddLiquidityUnbalanced(s.reservePool, amountsIn_, 0, "");
    }

    function _joinReserveDetfOnly(uint256 detfAmount_) internal returns (uint256 bptOut_) {
        MultiVaultWeightedDetfRepo.Storage storage s = MultiVaultWeightedDetfRepo._layoutStruct();
        uint256 n_ = _reserveVault().getCurrentLiveBalances(s.reservePool).length;
        uint256[] memory amountsIn_ = new uint256[](n_);
        amountsIn_[s.detfIndex] = detfAmount_;
        IERC20(address(this)).safeTransfer(address(_reserveVault()), detfAmount_);
        bptOut_ = _reserveRouter().prepayAddLiquidityUnbalanced(s.reservePool, amountsIn_, 0, "");
    }

    function _joinReserveBothDetfAndShare(uint256 legIndex_, uint256 detfAmount_, uint256 vaultShares_)
        internal
        returns (uint256 bptOut_)
    {
        MultiVaultWeightedDetfRepo.Storage storage s = MultiVaultWeightedDetfRepo._layoutStruct();
        if (IERC20(s.reservePool).totalSupply() == 0) {
            uint256[] memory amounts_ = new uint256[](s.vaultCount);
            // Weight-matched other legs: only primary leg funded; other legs zero fails initialize.
            // Caller must use initializeReserve for multi-leg empty pool.
            amounts_[legIndex_] = vaultShares_;
            return _initializeReserve(detfAmount_, amounts_);
        }
        uint256 n_ = _reserveVault().getCurrentLiveBalances(s.reservePool).length;
        uint256[] memory amountsIn_ = new uint256[](n_);
        amountsIn_[s.detfIndex] = detfAmount_;
        amountsIn_[s.vaultShareIndexes[legIndex_]] = vaultShares_;
        if (detfAmount_ > 0) IERC20(address(this)).safeTransfer(address(_reserveVault()), detfAmount_);
        if (vaultShares_ > 0) s.vaultShares[legIndex_].safeTransfer(address(_reserveVault()), vaultShares_);
        bptOut_ = _reserveRouter().prepayAddLiquidityUnbalanced(s.reservePool, amountsIn_, 0, "");
    }

    function _exitReserveProportional(uint256 bptIn_)
        internal
        returns (uint256 detfOut_, uint256[] memory vaultSharesOut_)
    {
        MultiVaultWeightedDetfRepo.Storage storage s = MultiVaultWeightedDetfRepo._layoutStruct();
        uint256 n_ = _reserveVault().getCurrentLiveBalances(s.reservePool).length;
        uint256[] memory minOut_ = new uint256[](n_);
        IERC20(s.reservePool).forceApprove(address(_reserveRouter()), bptIn_);
        uint256[] memory raw_ =
            _reserveRouter().prepayRemoveLiquidityProportional(s.reservePool, bptIn_, minOut_, "");
        detfOut_ = raw_[s.detfIndex];
        vaultSharesOut_ = new uint256[](s.vaultCount);
        for (uint256 i; i < s.vaultCount; ++i) {
            vaultSharesOut_[i] = raw_[s.vaultShareIndexes[i]];
        }
    }

    function _bptForDetfShares(uint256 detfShares_) internal view returns (uint256 bptOut_) {
        MultiVaultWeightedDetfRepo.Storage storage s = MultiVaultWeightedDetfRepo._layoutStruct();
        uint256 supply_ = ERC20Repo._totalSupply();
        uint256 bptBal_ = IERC20(s.reservePool).balanceOf(address(this));
        if (supply_ == 0 || bptBal_ == 0) return 0;
        bptOut_ = detfShares_ * bptBal_ / supply_;
    }

    function _pullToken(IERC20 token_, uint256 amount_, bool pretransferred_) internal returns (uint256 actual_) {
        if (pretransferred_) return amount_;
        uint256 before_ = token_.balanceOf(address(this));
        token_.safeTransferFrom(msg.sender, address(this), amount_);
        actual_ = token_.balanceOf(address(this)) - before_;
    }

    function _feeTo() internal view returns (address) {
        MultiVaultWeightedDetfRepo.Storage storage s = MultiVaultWeightedDetfRepo._layoutStruct();
        return address(s.feeOracle.feeTo());
    }

    function _mintDetf(address to_, uint256 amount_) internal {
        if (amount_ > 0) ERC20Repo._mint(to_, amount_);
    }

    function _burnDetf(address from_, uint256 amount_) internal {
        ERC20Repo._burn(from_, amount_);
    }

    function _legWeightSumExcept(uint256 legIndex_) internal view returns (uint256 sum_) {
        MultiVaultWeightedDetfRepo.Storage storage s = MultiVaultWeightedDetfRepo._layoutStruct();
        sum_ = s.weightDetf;
        for (uint256 i; i < s.vaultCount; ++i) {
            if (i != legIndex_) sum_ += s.vaultWeights[i];
        }
    }
}
