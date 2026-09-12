// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IDetfClaimPurchase} from "contracts/interfaces/IDetfClaimPurchase.sol";

/**
 * @title ITokenStaking
 * @notice Same-token Synthetix-style staking with a later DETF claim wrap.
 * @dev Phase `Staking`: stake / withdraw / getReward / reassign / notifyRewardAmount.
 *      Owner may set `targetDetf` before that DETF is deployed.
 *      Owner `migrateToClaimVault(amount, ...)` calls unified Uni V4
 *      `mint(stakingToken)` then `exchangeIn(detfToken → rebasingClaimToken)`
 *      (D18). DETF must already be live via a first bond elsewhere. Amount is
 *      caller-chosen so a DETF size cap cannot stall the whole reserve. First
 *      migrate freezes T rewards and user T exits.
 *      Remaining T = 0 flips to `Wrapped`. Users `withdrawClaim` from staking
 *      weights against the ERC-4626 (deployed on first migrate).
 *      If leftover T cannot mint, owner `completeWrap` sends that T to `dustTo`
 *      and flips `Wrapped`. Unmigrated T is owner-trusted; stakers share only
 *      claim already in the vault.
 */
interface ITokenStaking {
    enum Phase {
        Staking,
        Migrating,
        Wrapped
    }

    error AmountZero();
    error InvalidAddress();
    error InvalidPhase(Phase actual, Phase expected);
    error InsufficientStake(address account, uint256 requested, uint256 available);
    error TargetDetfUnset();
    error AmountExceedsReserve(uint256 requested, uint256 available);
    error RewardsPeriodNotFinished();
    error CannotRecoverReservedToken(IERC20 token);
    error SelfReassign();

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardsDurationUpdated(uint256 newDuration);
    event StakeReassigned(address indexed from, address indexed to, uint256 amount, uint256 rewardsMoved);
    event TargetDetfSet(IDetfClaimPurchase indexed detf);
    event MigratedToClaimVault(
        IDetfClaimPurchase indexed detf,
        uint256 rateAssetIn,
        uint256 detfMinted,
        uint256 claimMinted,
        uint256 vaultShares,
        uint256 reserveRemaining
    );
    event ClaimVaultWrapped(IERC4626 indexed vault, IERC20 indexed rebasingClaimToken, uint256 assets, uint256 shares);
    event ClaimWithdrawn(address indexed user, uint256 stakeAmount, uint256 claimOut);
    event RewardReserveRescued(address indexed to, uint256 amount, uint256 remaining);
    event MigrationCompleted(address indexed dustTo, uint256 dustAmount);

    function stakingToken() external view returns (IERC20);
    function rewardsDuration() external view returns (uint256);
    function periodFinish() external view returns (uint256);
    function rewardRate() external view returns (uint256);
    function lastUpdateTime() external view returns (uint256);
    function rewardPerTokenStored() external view returns (uint256);
    function userRewardPerTokenPaid(address account) external view returns (uint256);
    function rewards(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function lastTimeRewardApplicable() external view returns (uint256);
    function rewardPerToken() external view returns (uint256);
    function earned(address account) external view returns (uint256);
    function phase() external view returns (Phase);
    function targetDetf() external view returns (IDetfClaimPurchase);
    function reserveRemaining() external view returns (uint256);
    function rewardReserve() external view returns (uint256);
    function permit2() external view returns (address);
    function claimVault() external view returns (IERC4626);
    function previewClaim(address account, uint256 stakeAmount) external view returns (uint256 claimOut);

    function stake(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function getReward() external;
    function exit() external;
    function reassign(address to, uint256 amount) external;

    function notifyRewardAmount(uint256 reward) external;
    function setRewardsDuration(uint256 newDuration) external;
    function setTargetDetf(IDetfClaimPurchase detf) external;
    function migrateToClaimVault(uint256 amount, uint256 minClaimOut, uint256 deadline)
        external
        returns (uint256 claimMinted, uint256 vaultShares);
    function withdrawClaim(uint256 stakeAmount) external returns (uint256 claimOut);
    function recoverERC20(IERC20 token, uint256 amount) external;
    /// @notice Owner pulls excess staking-token above `totalSupply` (principal). Stops the time stream.
    function rescueRewardReserve(uint256 amount) external;
    /// @notice Owner sends leftover staking-token to `dustTo` and flips `Wrapped`.
    /// @dev Only `Migrating`. Unmigrated T is owner-trusted. Stakers share claim already wrapped.
    function completeWrap(address dustTo) external;
}
