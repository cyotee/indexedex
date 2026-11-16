// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {Math} from "@crane/contracts/utils/Math.sol";

library DETFMintSplitLib {
    uint256 internal constant ONE_WAD = 1e18;

    function _splitHalfSeigniorage(uint256 grossAmount_, uint256 seignioragePercentage_)
        internal
        pure
        returns (uint256 userAmount_, uint256 inventoryAmount_)
    {
        inventoryAmount_ = Math.mulDiv(grossAmount_, seignioragePercentage_, 2 * ONE_WAD);
        userAmount_ = grossAmount_ - inventoryAmount_;
    }

    /// @notice Live mint D27/D3: `U = Gross`. User `(1-p)*Gross`, pot `p*Gross`. Floor each `mulDiv`.
    function _splitLiveGross(uint256 gross_, uint256 p_)
        internal
        pure
        returns (uint256 userDetf_, uint256 potDetf_)
    {
        userDetf_ = Math.mulDiv(gross_, ONE_WAD - p_, ONE_WAD);
        potDetf_ = Math.mulDiv(gross_, p_, ONE_WAD);
    }

    /// @notice Bond L1 + D3 + D4: join `G` unboosted; user `(1-p)*G`; pot `p*G` (D3) + `p*G` (D4).
    function _splitBond(uint256 joinDetf_, uint256 p_)
        internal
        pure
        returns (uint256 userDetf_, uint256 potDetf_, uint256 join_)
    {
        return _splitBond(joinDetf_, joinDetf_, p_);
    }

    /// @notice Split independently quoted purchased DETF and the unboosted liquidity self-leg.
    /// @dev D36/D49: principal is (1-p)*U; the reward pot is floor(p*U)+floor(p*G).
    /// @param purchasedGross_ Gross DETF quoted from the duration-adjusted payment.
    /// @param joinDetf_ DETF quoted from the actual payment for the reserve liquidity join.
    /// @param p_ Existing WAD seigniorage fraction.
    /// @return userDetf_ Fixed net DETF principal to fund into the bond's staking position.
    /// @return potDetf_ DETF reward pot distributed immediately after funding principal.
    /// @return join_ Separately minted liquidity self-leg, unaffected by the purchase bonus.
    function _splitBond(uint256 purchasedGross_, uint256 joinDetf_, uint256 p_)
        internal
        pure
        returns (uint256 userDetf_, uint256 potDetf_, uint256 join_)
    {
        join_ = joinDetf_;
        userDetf_ = Math.mulDiv(purchasedGross_, ONE_WAD - p_, ONE_WAD);
        potDetf_ = Math.mulDiv(purchasedGross_, p_, ONE_WAD) + Math.mulDiv(joinDetf_, p_, ONE_WAD);
    }
}
