// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {IUniswapV4DetfMigrationAccounting} from "../interfaces/IUniswapV4DetfMigration.sol";

/// @notice Both standard nine-decimal wrappers, with R3 principal-denominated staking SY.
/// @dev Keep the inherited four-argument deposit and five-argument redeem ABI. Internal redemption
/// burns actual SY-held issued shares; it is bearer principal, not an owner ticket or underlying
/// donation. Checkpoint old holders before share changes. Self-held earnings belong to protocol U.
/// Staking rate=1e18, assetInfo=(TOKEN,parent,9), yieldToken=receipt; raw yieldToken=parent.
/// Staking reward tokens=[RT], index=[1+1e36-k], accrued/claim/event amounts are native RT.
/// claimRewards requires activation even for zero. Self accrued/claim returns [0] when callable.
/// Raw SY retains rawBacking=shares and empty reward arrays, without automatic receipt routes.
interface IUniswapV4DetfMigrationSY is IStandardizedYield, IUniswapV4DetfMigrationAccounting {
    /// @notice Activated owner-only native-sDETF payout from the caller's R2 modulo 1e18 gons.
    /// @dev Checkpoint first, pay floor((R2%1e18)/k), debit only paid*k; never spend whole RT backing.
    /// This is not the standard claimRewards RT return. Raw mode has no R2 and pays zero when active.
    function claimRewardRemainder() external returns (uint256 nativeSDETF);

    /// @notice Canonical backingGons, not a duplicate share ledger; raw mode returns zero.
    /// @dev Receipt reads actual post-effects attribution before permitting a staking-SY custody debit.
    function attributedSyGons() external view returns (uint256);
}
