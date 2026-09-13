// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IStandardExchangeOut} from "@crane/contracts/interfaces/IStandardExchangeOut.sol";

/// @notice DETF callback used to settle completed expansion epochs before stake changes.
interface IDETFFundedRewards {
    function synchronizeRewards() external returns (uint256 expansionMinted_);
}

/// @title IStakedDETF
/// @notice Nine-decimal funded staking receipts. Public principal routes use Standard Exchange.
interface IStakedDETF is IERC20, IERC20Metadata, IStandardExchangeIn, IStandardExchangeOut {
    struct StakingState {
        uint256 totalGons;
        uint256 gonsPerUnit;
        uint256 accountedBacking;
        uint256 allocationDust;
        uint256 stakingDust;
        uint256 feeWeight;
        uint256 creatorWeight;
    }

    /// @notice Actual DETF backing token; one raw sDETF redeems for one raw DETF.
    function detf() external view returns (address);

    /// @notice Fixed internal ownership units, used by bond escrow and the static SY.
    function gonsOf(address account_) external view returns (uint256);

    /// @notice Current funded accounting, excluding pending unminted expansion.
    function stakingState() external view returns (StakingState memory);

    /// @notice Simulate ordered reward funding for transaction previews, without changing actual backing.
    /// @dev Zero entries are ignored, matching DETF's zero-funding path. Public balances and rates
    ///      continue to use stakingState(), never this hypothetical state.
    function previewDistributions(uint256[] calldata rewards_) external view returns (StakingState memory);

    /// @notice DETF-only settlement hook; pulls and distributes actually funded DETF once.
    function fundRewards(uint256 amount_)
        external
        returns (uint256 stakingGrowth_, uint256 feeReceipt_, uint256 creatorReceipt_);

    /// @notice Bond-vault-only retirement of a closed position's sub-native gons remainder.
    function retireEscrowDust(uint256 gons_) external;

    event Staked(address indexed payer, address indexed recipient, uint256 detfAmount, uint256 gons);
    event Unstaked(address indexed owner, address indexed recipient, uint256 detfAmount, uint256 gons);
    event RewardsFunded(
        uint256 detfAmount,
        uint256 stakingGrowth,
        uint256 feeReceipt,
        uint256 creatorReceipt,
        uint256 gonsPerUnit
    );
}
