// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

/* -------------------------------------------------------------------------- */
/*                                    Crane                                   */
/* -------------------------------------------------------------------------- */

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC4626} from "@crane/contracts/interfaces/IERC4626.sol";
import {IPermit2} from "@crane/contracts/interfaces/protocols/utils/permit2/IPermit2.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {MultiStepOwnableModifiers} from "@crane/contracts/access/ERC8023/MultiStepOwnableModifiers.sol";
import {Permit2AwareRepo} from "@crane/contracts/protocols/utils/permit2/aware/Permit2AwareRepo.sol";

/* -------------------------------------------------------------------------- */
/*                                  Indexedex                                 */
/* -------------------------------------------------------------------------- */

import {IDetfClaimPurchase} from "contracts/interfaces/IDetfClaimPurchase.sol";
import {IDETFFundedRewards} from "contracts/interfaces/IStakedDETF.sol";
import {ITokenStaking} from "contracts/interfaces/ITokenStaking.sol";
import {TokenStakingRepo} from "contracts/protocols/staking/token/TokenStakingRepo.sol";
import {IRebasingAwareERC4626DFPkg} from
    "contracts/protocols/staking/rebasingVault/IRebasingAwareERC4626DFPkg.sol";

/**
 * @title TokenStakingTarget
 * @notice Synthetix-style same-token staking, then chunked mint + buyClaim wrap.
 * @dev Remaining unclaimed streaming rewards are socialized into the migrate pool
 *      on the first `migrateToClaimVault`. Users should `getReward` before that
 *      if they want T in wallet rather than a pro-rata claim share.
 */
contract TokenStakingTarget is ITokenStaking, ReentrancyLockModifiers, MultiStepOwnableModifiers {
    using BetterSafeERC20 for IERC20;
    using TokenStakingRepo for TokenStakingRepo.Storage;

    uint256 internal constant WAD = 1e18;

    function stakingToken() public view returns (IERC20) {
        return TokenStakingRepo._layoutStruct().stakingToken;
    }

    function rewardsDuration() public view returns (uint256) {
        return TokenStakingRepo._layoutStruct().rewardsDuration;
    }

    function periodFinish() public view returns (uint256) {
        return TokenStakingRepo._layoutStruct().periodFinish;
    }

    function rewardRate() public view returns (uint256) {
        return TokenStakingRepo._layoutStruct().rewardRate;
    }

    function lastUpdateTime() public view returns (uint256) {
        return TokenStakingRepo._layoutStruct().lastUpdateTime;
    }

    function rewardPerTokenStored() public view returns (uint256) {
        return TokenStakingRepo._layoutStruct().rewardPerTokenStored;
    }

    function userRewardPerTokenPaid(address account) public view returns (uint256) {
        return TokenStakingRepo._layoutStruct().userRewardPerTokenPaid[account];
    }

    function rewards(address account) public view returns (uint256) {
        return TokenStakingRepo._layoutStruct().rewards[account];
    }

    function totalSupply() public view returns (uint256) {
        return TokenStakingRepo._layoutStruct().totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return TokenStakingRepo._layoutStruct().balanceOf[account];
    }

    function phase() public view returns (Phase) {
        return TokenStakingRepo._layoutStruct().phase;
    }

    function targetDetf() public view returns (IDetfClaimPurchase) {
        return TokenStakingRepo._layoutStruct().targetDetf;
    }

    function reserveRemaining() public view returns (uint256) {
        return TokenStakingRepo._layoutStruct().stakingToken.balanceOf(address(this));
    }

    function rewardReserve() public view returns (uint256) {
        TokenStakingRepo.Storage storage layoutStruct = TokenStakingRepo._layoutStruct();
        uint256 bal = layoutStruct.stakingToken.balanceOf(address(this));
        uint256 principal = layoutStruct.totalSupply;
        return bal > principal ? bal - principal : 0;
    }

    function permit2() public view returns (address) {
        return address(Permit2AwareRepo._permit2());
    }

    function claimVault() public view returns (IERC4626) {
        return TokenStakingRepo._layoutStruct().claimVault;
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        TokenStakingRepo.Storage storage layoutStruct = TokenStakingRepo._layoutStruct();
        uint256 finish = layoutStruct.periodFinish;
        return block.timestamp < finish ? block.timestamp : finish;
    }

    function rewardPerToken() public view returns (uint256) {
        TokenStakingRepo.Storage storage layoutStruct = TokenStakingRepo._layoutStruct();
        if (layoutStruct.totalSupply == 0) {
            return layoutStruct.rewardPerTokenStored;
        }
        return layoutStruct.rewardPerTokenStored
            + ((lastTimeRewardApplicable() - layoutStruct.lastUpdateTime) * layoutStruct.rewardRate * WAD)
                / layoutStruct.totalSupply;
    }

    function earned(address account) public view returns (uint256) {
        TokenStakingRepo.Storage storage layoutStruct = TokenStakingRepo._layoutStruct();
        return (
            layoutStruct.balanceOf[account] * (rewardPerToken() - layoutStruct.userRewardPerTokenPaid[account])
        ) / WAD + layoutStruct.rewards[account];
    }

    function previewClaim(address account, uint256 stakeAmount) public view returns (uint256 claimOut) {
        TokenStakingRepo.Storage storage layoutStruct = TokenStakingRepo._layoutStruct();
        if (layoutStruct.phase != Phase.Wrapped) {
            return 0;
        }
        uint256 supply = layoutStruct.totalSupply;
        uint256 userBal = layoutStruct.balanceOf[account];
        if (stakeAmount == 0 || supply == 0 || stakeAmount > userBal) {
            return 0;
        }
        IERC4626 vault = layoutStruct.claimVault;
        uint256 vaultShares = IERC20(address(vault)).balanceOf(address(this));
        uint256 redeemShares = stakeAmount == supply ? vaultShares : (stakeAmount * vaultShares) / supply;
        return vault.previewRedeem(redeemShares);
    }

    function stake(uint256 amount) external nonReentrant {
        TokenStakingRepo.Storage storage layoutStruct = TokenStakingRepo._layoutStruct();
        _onlyPhase(layoutStruct, Phase.Staking);
        if (amount == 0) {
            revert AmountZero();
        }
        _updateReward(layoutStruct, msg.sender);
        layoutStruct.totalSupply += amount;
        layoutStruct.balanceOf[msg.sender] += amount;
        _pullStakingToken(layoutStruct.stakingToken, amount);
        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) public nonReentrant {
        TokenStakingRepo.Storage storage layoutStruct = TokenStakingRepo._layoutStruct();
        _onlyPhase(layoutStruct, Phase.Staking);
        _withdraw(layoutStruct, amount);
    }

    function getReward() public nonReentrant {
        TokenStakingRepo.Storage storage layoutStruct = TokenStakingRepo._layoutStruct();
        _onlyPhase(layoutStruct, Phase.Staking);
        _getReward(layoutStruct);
    }

    function exit() external nonReentrant {
        TokenStakingRepo.Storage storage layoutStruct = TokenStakingRepo._layoutStruct();
        _onlyPhase(layoutStruct, Phase.Staking);
        uint256 bal = layoutStruct.balanceOf[msg.sender];
        if (bal != 0) {
            _withdraw(layoutStruct, bal);
        }
        _getReward(layoutStruct);
    }

    function reassign(address to, uint256 amount) external nonReentrant {
        if (to == address(0)) {
            revert InvalidAddress();
        }
        if (to == msg.sender) {
            revert SelfReassign();
        }
        if (amount == 0) {
            revert AmountZero();
        }
        TokenStakingRepo.Storage storage layoutStruct = TokenStakingRepo._layoutStruct();
        _updateReward(layoutStruct, msg.sender);
        _updateReward(layoutStruct, to);
        uint256 fromBal = layoutStruct.balanceOf[msg.sender];
        if (amount > fromBal) {
            revert InsufficientStake(msg.sender, amount, fromBal);
        }
        uint256 rewardsMoved = (layoutStruct.rewards[msg.sender] * amount) / fromBal;
        layoutStruct.rewards[msg.sender] -= rewardsMoved;
        layoutStruct.rewards[to] += rewardsMoved;
        layoutStruct.balanceOf[msg.sender] = fromBal - amount;
        layoutStruct.balanceOf[to] += amount;
        emit StakeReassigned(msg.sender, to, amount, rewardsMoved);
    }

    function notifyRewardAmount(uint256 reward) external onlyOwner nonReentrant {
        TokenStakingRepo.Storage storage layoutStruct = TokenStakingRepo._layoutStruct();
        _onlyPhase(layoutStruct, Phase.Staking);
        if (reward == 0) {
            revert AmountZero();
        }
        _updateReward(layoutStruct, address(0));
        _pullStakingToken(layoutStruct.stakingToken, reward);
        if (block.timestamp >= layoutStruct.periodFinish) {
            layoutStruct.rewardRate = reward / layoutStruct.rewardsDuration;
        } else {
            uint256 remaining = layoutStruct.periodFinish - block.timestamp;
            uint256 leftover = remaining * layoutStruct.rewardRate;
            layoutStruct.rewardRate = (reward + leftover) / layoutStruct.rewardsDuration;
        }
        layoutStruct.lastUpdateTime = block.timestamp;
        layoutStruct.periodFinish = block.timestamp + layoutStruct.rewardsDuration;
        emit RewardAdded(reward);
    }

    function setRewardsDuration(uint256 newDuration) external onlyOwner {
        TokenStakingRepo.Storage storage layoutStruct = TokenStakingRepo._layoutStruct();
        _onlyPhase(layoutStruct, Phase.Staking);
        if (newDuration == 0) {
            revert AmountZero();
        }
        if (block.timestamp <= layoutStruct.periodFinish) {
            revert RewardsPeriodNotFinished();
        }
        layoutStruct.rewardsDuration = newDuration;
        emit RewardsDurationUpdated(newDuration);
    }

    function setTargetDetf(IDetfClaimPurchase detf) external onlyOwner {
        if (address(detf) == address(0)) {
            revert InvalidAddress();
        }
        TokenStakingRepo.Storage storage layoutStruct = TokenStakingRepo._layoutStruct();
        _onlyPhase(layoutStruct, Phase.Staking);
        layoutStruct.targetDetf = detf;
        emit TargetDetfSet(detf);
    }

    function migrateToClaimVault(uint256 amount, uint256 minClaimOut, uint256 deadline)
        external
        onlyOwner
        nonReentrant
        returns (uint256 claimMinted, uint256 vaultShares)
    {
        TokenStakingRepo.Storage storage layoutStruct = TokenStakingRepo._layoutStruct();
        if (layoutStruct.phase != Phase.Staking && layoutStruct.phase != Phase.Migrating) {
            revert InvalidPhase(layoutStruct.phase, Phase.Migrating);
        }
        IDetfClaimPurchase detf = layoutStruct.targetDetf;
        if (address(detf) == address(0)) {
            revert TargetDetfUnset();
        }
        IERC20 token = layoutStruct.stakingToken;
        if (amount == 0) {
            revert AmountZero();
        }
        uint256 available = token.balanceOf(address(this));
        if (amount > available) {
            revert AmountExceedsReserve(amount, available);
        }
        if (layoutStruct.phase == Phase.Staking) {
            _beginMigration(layoutStruct);
        }

        uint256 detfMinted = _mintDetf(detf, token, amount, deadline);
        claimMinted = _buyClaim(detf, detfMinted, minClaimOut, deadline);
        vaultShares = _wrapClaim(layoutStruct, detf);

        uint256 remaining = token.balanceOf(address(this));
        if (remaining == 0) {
            layoutStruct.phase = Phase.Wrapped;
        }
        emit MigratedToClaimVault(detf, amount, detfMinted, claimMinted, vaultShares, remaining);
    }

    function withdrawClaim(uint256 stakeAmount) external nonReentrant returns (uint256 claimOut) {
        TokenStakingRepo.Storage storage layoutStruct = TokenStakingRepo._layoutStruct();
        _onlyPhase(layoutStruct, Phase.Wrapped);
        if (stakeAmount == 0) {
            revert AmountZero();
        }
        uint256 userBal = layoutStruct.balanceOf[msg.sender];
        if (stakeAmount > userBal) {
            revert InsufficientStake(msg.sender, stakeAmount, userBal);
        }
        uint256 supply = layoutStruct.totalSupply;
        IERC4626 vault = layoutStruct.claimVault;
        uint256 vaultShares = IERC20(address(vault)).balanceOf(address(this));
        uint256 redeemShares = stakeAmount == supply ? vaultShares : (stakeAmount * vaultShares) / supply;
        layoutStruct.balanceOf[msg.sender] = userBal - stakeAmount;
        layoutStruct.totalSupply = supply - stakeAmount;
        claimOut = vault.redeem(redeemShares, msg.sender, address(this));
        emit ClaimWithdrawn(msg.sender, stakeAmount, claimOut);
    }

    function recoverERC20(IERC20 token, uint256 amount) external onlyOwner {
        TokenStakingRepo.Storage storage layoutStruct = TokenStakingRepo._layoutStruct();
        if (address(token) == address(layoutStruct.stakingToken)) {
            revert CannotRecoverReservedToken(token);
        }
        address vault = address(layoutStruct.claimVault);
        if (vault != address(0)
            && (address(token) == vault || address(token) == layoutStruct.claimVault.asset()))
        {
            revert CannotRecoverReservedToken(token);
        }
        token.safeTransfer(msg.sender, amount);
    }

    function rescueRewardReserve(uint256 amount) external onlyOwner nonReentrant {
        TokenStakingRepo.Storage storage layoutStruct = TokenStakingRepo._layoutStruct();
        if (amount == 0) {
            revert AmountZero();
        }
        uint256 available = rewardReserve();
        if (amount > available) {
            revert AmountExceedsReserve(amount, available);
        }
        _updateReward(layoutStruct, address(0));
        layoutStruct.rewardRate = 0;
        layoutStruct.periodFinish = block.timestamp;
        layoutStruct.lastUpdateTime = block.timestamp;
        layoutStruct.stakingToken.safeTransfer(msg.sender, amount);
        emit RewardReserveRescued(msg.sender, amount, available - amount);
    }

    function completeWrap(address dustTo) external onlyOwner nonReentrant {
        if (dustTo == address(0)) {
            revert InvalidAddress();
        }
        TokenStakingRepo.Storage storage layoutStruct = TokenStakingRepo._layoutStruct();
        _onlyPhase(layoutStruct, Phase.Migrating);
        IERC20 token = layoutStruct.stakingToken;
        uint256 dust = token.balanceOf(address(this));
        if (dust != 0) {
            token.safeTransfer(dustTo, dust);
        }
        layoutStruct.phase = Phase.Wrapped;
        emit MigrationCompleted(dustTo, dust);
    }

    function _pullStakingToken(IERC20 token, uint256 amount) internal {
        if (token.allowance(msg.sender, address(this)) >= amount) {
            token.safeTransferFrom(msg.sender, address(this), amount);
            return;
        }
        if (amount > type(uint160).max) {
            revert AmountExceedsReserve(amount, type(uint160).max);
        }
        IPermit2 p2 = Permit2AwareRepo._permit2();
        p2.transferFrom(msg.sender, address(this), uint160(amount), address(token));
    }

    function _withdraw(TokenStakingRepo.Storage storage layoutStruct, uint256 amount) internal {
        if (amount == 0) {
            revert AmountZero();
        }
        _updateReward(layoutStruct, msg.sender);
        uint256 userBal = layoutStruct.balanceOf[msg.sender];
        if (amount > userBal) {
            revert InsufficientStake(msg.sender, amount, userBal);
        }
        layoutStruct.totalSupply -= amount;
        layoutStruct.balanceOf[msg.sender] = userBal - amount;
        layoutStruct.stakingToken.safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    function _getReward(TokenStakingRepo.Storage storage layoutStruct) internal {
        _updateReward(layoutStruct, msg.sender);
        uint256 reward = layoutStruct.rewards[msg.sender];
        if (reward == 0) {
            return;
        }
        layoutStruct.rewards[msg.sender] = 0;
        layoutStruct.stakingToken.safeTransfer(msg.sender, reward);
        emit RewardPaid(msg.sender, reward);
    }

    function _updateReward(TokenStakingRepo.Storage storage layoutStruct, address account) internal {
        layoutStruct.rewardPerTokenStored = rewardPerToken();
        layoutStruct.lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            layoutStruct.rewards[account] = earned(account);
            layoutStruct.userRewardPerTokenPaid[account] = layoutStruct.rewardPerTokenStored;
        }
    }

    function _onlyPhase(TokenStakingRepo.Storage storage layoutStruct, Phase expected) internal view {
        if (layoutStruct.phase != expected) {
            revert InvalidPhase(layoutStruct.phase, expected);
        }
    }

    function _beginMigration(TokenStakingRepo.Storage storage layoutStruct) internal {
        if (layoutStruct.totalSupply == 0) {
            revert AmountZero();
        }
        _updateReward(layoutStruct, address(0));
        layoutStruct.rewardRate = 0;
        layoutStruct.periodFinish = block.timestamp;
        layoutStruct.lastUpdateTime = block.timestamp;
        layoutStruct.phase = Phase.Migrating;
    }

    function _mintDetf(IDetfClaimPurchase detf, IERC20 token, uint256 amount, uint256 deadline)
        internal
        returns (uint256 detfMinted)
    {
        token.safeApprove(address(detf), amount);
        detfMinted = detf.exchangeIn(token, amount, IERC20(address(detf)), 0, address(this), false, deadline);
        token.safeApprove(address(detf), 0);
    }

    function _buyClaim(IDetfClaimPurchase detf, uint256 detfMinted, uint256 minClaimOut, uint256 deadline)
        internal
        returns (uint256 claimMinted)
    {
        IERC20 detfToken = IERC20(address(detf));
        IERC20 claimToken = IERC20(detf.rebasingClaimToken());
        detfToken.safeApprove(address(claimToken), detfMinted);
        claimMinted = IStandardExchangeIn(address(claimToken)).exchangeIn(
            detfToken, detfMinted, claimToken, minClaimOut, address(this), false, deadline
        );
        detfToken.safeApprove(address(claimToken), 0);
    }

    function _wrapClaim(TokenStakingRepo.Storage storage layoutStruct, IDetfClaimPurchase detf)
        internal
        returns (uint256 vaultShares)
    {
        IERC20 claimToken = IERC20(detf.rebasingClaimToken());
        IERC4626 vault = layoutStruct.claimVault;
        if (address(vault) == address(0)) {
            vault = IRebasingAwareERC4626DFPkg(address(layoutStruct.claimVaultPkg)).deployVault(
                IERC20Metadata(address(claimToken))
            );
            layoutStruct.claimVault = vault;
        }
        try IDETFFundedRewards(address(claimToken)).synchronizeRewards() {} catch {}
        uint256 claimBal = claimToken.balanceOf(address(this));
        claimToken.safeApprove(address(vault), claimBal);
        vaultShares = vault.deposit(claimBal, address(this));
        claimToken.safeApprove(address(vault), 0);
        emit ClaimVaultWrapped(vault, claimToken, claimBal, vaultShares);
    }
}
