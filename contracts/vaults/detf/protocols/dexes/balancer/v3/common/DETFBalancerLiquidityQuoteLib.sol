// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IVault} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IVault.sol";
import {IBasePool} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/IBasePool.sol";
import {PoolData, Rounding, TokenType} from "@crane/contracts/external/balancer/v3/interfaces/contracts/vault/VaultTypes.sol";
import {BasePoolMath} from "@crane/contracts/external/balancer/v3/vault/contracts/BasePoolMath.sol";
import {PoolDataLib} from "@crane/contracts/external/balancer/v3/vault/contracts/lib/PoolDataLib.sol";
import {PoolConfigLib} from "@crane/contracts/external/balancer/v3/vault/contracts/lib/PoolConfigLib.sol";
import {ScalingHelpers} from "@crane/contracts/external/balancer/v3/solidity-utils/contracts/helpers/ScalingHelpers.sol";

/// @notice The Vault's unbalanced join quote, including native decimals, rates and fees.
/// @dev A single-token join is not a proportional amount/supply conversion. Use the actual
/// pool invariant after the Vault's yield-fee settlement and round incoming assets down.
library DETFBalancerLiquidityQuoteLib {
    function _singleAssetJoin(address vault_, address pool_, uint256 index_, uint256 rawIn_)
        internal view returns (uint256 lpOut_)
    {
        uint256 supply_ = IERC20(pool_).totalSupply();
        if (rawIn_ == 0 || supply_ == 0) return 0;
        PoolData memory d_ = IVault(vault_).getPoolData(pool_);
        (,,uint256[] memory raw_,uint256[] memory lastLive_) = IVault(vault_).getPoolTokenInfo(pool_);
        uint256 yieldFee_ = PoolConfigLib.getAggregateYieldFeePercentage(d_.poolConfigBits);
        bool chargeYield_ = yieldFee_ != 0 && !PoolConfigLib.isPoolInRecoveryMode(d_.poolConfigBits);
        for (uint256 i_; i_ < raw_.length; ++i_) {
            PoolDataLib.updateRawAndLiveBalance(d_, i_, raw_[i_], Rounding.ROUND_UP);
            if (chargeYield_ && d_.tokenInfo[i_].paysYieldFees && d_.tokenInfo[i_].tokenType == TokenType.WITH_RATE) {
                uint256 due_ = PoolDataLib._computeYieldFeesDue(d_, lastLive_[i_], i_, yieldFee_);
                if (due_ != 0) PoolDataLib.updateRawAndLiveBalance(d_, i_, raw_[i_] - due_, Rounding.ROUND_UP);
            }
        }
        uint256[] memory amounts_ = new uint256[](raw_.length);
        amounts_[index_] = ScalingHelpers.toScaled18ApplyRateRoundDown(rawIn_, d_.decimalScalingFactors[index_], d_.tokenRates[index_]);
        (lpOut_,) = BasePoolMath.computeAddLiquidityUnbalanced(d_.balancesLiveScaled18, amounts_, supply_,
            PoolConfigLib.getStaticSwapFeePercentage(d_.poolConfigBits), IBasePool(pool_));
    }
}
