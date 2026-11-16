// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {IStakedDETF, IDETFFundedRewards} from "contracts/interfaces/IStakedDETF.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {DETFFundedStakingMath} from "contracts/vaults/detf/common/core/DETFFundedStakingMath.sol";
import {DETFSeigniorageShareLib} from "contracts/vaults/detf/common/core/DETFSeigniorageShareLib.sol";
import {DETFFundedStakingRepo as Repo} from "contracts/vaults/detf/common/claimToken/DETFFundedStakingRepo.sol";
import {
    DETF_FEE_TO_BOND_NFT_ID,
    DETF_CREATOR_BOND_NFT_ID
} from "contracts/vaults/detf/common/core/DETFBondNftIds.sol";

/// @title StakedDETFTarget
/// @notice Held-DETF staking, with SE principal routes and narrowly authorized reward funding.
/// @dev Composed payment-token routes live on DETF/SY and call these same direct staking routes.
contract StakedDETFTarget is IStakedDETF, ReentrancyLockModifiers {
    using BetterSafeERC20 for IERC20;

    error Unauthorized(address caller);
    error RewardSynchronizationInProgress();
    error InvalidStakingRoute(address tokenIn, address tokenOut);
    error ZeroAmount();
    error DeadlineExpired(uint256 deadline);
    error MinimumOutputNotMet(uint256 minimum, uint256 actual);
    error MaximumInputExceeded(uint256 maximum, uint256 required);

    /// @dev Synchronization precedes the local lock so authorized expansion funding may callback.
    modifier synchronized() {
        _synchronize();
        _;
    }

    /// @inheritdoc IStakedDETF
    function detf() external view returns (address) {
        return address(Repo._layoutStruct().detf);
    }

    /// @inheritdoc IStakedDETF
    function gonsOf(address account_) external view returns (uint256) {
        return Repo._layoutStruct().gonsOf[account_];
    }

    /// @inheritdoc IStakedDETF
    function stakingState() public view returns (StakingState memory state_) {
        Repo.Storage storage s_ = Repo._layoutStruct();
        state_ = StakingState(
            s_.totalGons, s_.gonsPerUnit, s_.accountedBacking, s_.allocationDust,
            s_.stakingDust, s_.feeWeight, s_.creatorWeight
        );
    }

    /// @inheritdoc IStakedDETF
    function previewDistributions(uint256[] calldata rewards_) external view returns (StakingState memory state_) {
        state_ = stakingState();
        Repo.Storage storage s_ = Repo._layoutStruct();
        (, uint256 fee_, uint256 creator_) = s_.feeOracle.seigniorageSplitOfVault(address(s_.detf));
        for (uint256 i; i < rewards_.length; ++i) {
            uint256 amount_ = rewards_[i];
            if (amount_ == 0) continue;
            state_.accountedBacking += amount_;
            DETFFundedStakingMath.RewardAllocation memory allocation_ = DETFFundedStakingMath._allocate(
                amount_ + state_.allocationDust, state_.totalGons, state_.feeWeight, state_.creatorWeight
            );
            state_.allocationDust = allocation_.dust;
            (state_.gonsPerUnit,, state_.stakingDust) = DETFFundedStakingMath._rebase(
                state_.totalGons, state_.gonsPerUnit, allocation_.staking + state_.stakingDust
            );
            state_.totalGons += DETFFundedStakingMath._toGons(
                allocation_.fee + allocation_.creator, state_.gonsPerUnit
            );
            (uint256 feeDelta_, uint256 creatorDelta_) = DETFSeigniorageShareLib._topUpDeltas(
                state_.totalGons, state_.feeWeight, state_.creatorWeight, fee_, creator_
            );
            state_.feeWeight += feeDelta_;
            state_.creatorWeight += creatorDelta_;
        }
    }

    /// @notice Staking receipts retain the configured DETF-derived name.
    function name() external view returns (string memory) { return ERC20Repo._name(); }

    /// @notice Staking receipts retain the configured symbol.
    function symbol() external view returns (string memory) { return ERC20Repo._symbol(); }

    /// @notice Native staking and backing token amounts have the same nine-decimal unit.
    function decimals() external pure returns (uint8) { return 9; }

    /// @notice Aggregate funded redemption liability, excluding virtual reward weights.
    function totalSupply() external view returns (uint256) { return Repo._totalSupply(); }

    /// @notice Funded balance changes only with gons transfers or funded index growth.
    function balanceOf(address owner_) external view returns (uint256) { return Repo._balanceOf(owner_); }

    /// @notice ERC-20 allowance in native sDETF units.
    function allowance(address owner_, address spender_) external view returns (uint256) {
        return ERC20Repo._allowance(owner_, spender_);
    }

    /// @notice Approve native units; the shared ERC-20 Repo emits the approval event once.
    function approve(address spender_, uint256 amount_) external returns (bool) {
        ERC20Repo._approve(msg.sender, spender_, amount_);
        return true;
    }

    /// @notice Settle due expansion before transferring the funded position.
    function transfer(address to_, uint256 amount_) external synchronized nonReentrant returns (bool) {
        Repo._transfer(msg.sender, to_, amount_);
        return true;
    }

    /// @notice Transfer using the shared permit-compatible native-unit allowance ledger.
    function transferFrom(address from_, address to_, uint256 amount_)
        external synchronized nonReentrant returns (bool)
    {
        ERC20Repo._spendAllowance(from_, msg.sender, amount_);
        Repo._transfer(from_, to_, amount_);
        return true;
    }

    /// @notice Direct funded staking and unstaking quote one raw unit for one raw unit.
    function previewExchangeIn(IERC20 tokenIn_, uint256 amountIn_, IERC20 tokenOut_)
        external view returns (uint256)
    {
        _isStake(tokenIn_, tokenOut_);
        return amountIn_;
    }

    /// @notice Direct exact-output staking and unstaking require equal raw input.
    function previewExchangeOut(IERC20 tokenIn_, IERC20 tokenOut_, uint256 amountOut_)
        external view returns (uint256)
    {
        _isStake(tokenIn_, tokenOut_);
        return amountOut_;
    }

    /// @notice Exchange actual DETF for equal sDETF, or burn sDETF for held DETF.
    function exchangeIn(
        IERC20 tokenIn_, uint256 amountIn_, IERC20 tokenOut_, uint256 minAmountOut_,
        address recipient_, bool pretransferred_, uint256 deadline_
    ) external synchronized nonReentrant returns (uint256 amountOut_) {
        if (amountIn_ < minAmountOut_) revert MinimumOutputNotMet(minAmountOut_, amountIn_);
        _exchange(tokenIn_, tokenOut_, amountIn_, recipient_, pretransferred_, deadline_);
        return amountIn_;
    }

    /// @notice Exact-output direct staking pulls or burns only the required native input.
    function exchangeOut(
        IERC20 tokenIn_, uint256 maxAmountIn_, IERC20 tokenOut_, uint256 amountOut_,
        address recipient_, bool pretransferred_, uint256 deadline_
    ) external synchronized nonReentrant returns (uint256 amountIn_) {
        if (amountOut_ > maxAmountIn_) revert MaximumInputExceeded(maxAmountIn_, amountOut_);
        _exchange(tokenIn_, tokenOut_, amountOut_, recipient_, pretransferred_, deadline_);
        return amountOut_;
    }

    /// @inheritdoc IStakedDETF
    function fundRewards(uint256 amount_)
        external nonReentrant returns (uint256 stakingGrowth_, uint256 feeReceipt_, uint256 creatorReceipt_)
    {
        Repo.Storage storage s_ = Repo._layoutStruct();
        if (msg.sender != address(s_.detf)) revert Unauthorized(msg.sender);
        if (amount_ == 0) revert ZeroAmount();
        _pullDetf(s_, amount_);
        address feeRecipient_ = IERC721(s_.bondNftVault).ownerOf(DETF_FEE_TO_BOND_NFT_ID);
        address creatorRecipient_ = IERC721(s_.bondNftVault).ownerOf(DETF_CREATOR_BOND_NFT_ID);
        DETFFundedStakingMath.RewardAllocation memory allocation_;
        (allocation_, stakingGrowth_) = Repo._distribute(s_, amount_, feeRecipient_, creatorRecipient_);
        _topUpWeights(s_);
        emit RewardsFunded(amount_, stakingGrowth_, allocation_.fee, allocation_.creator, s_.gonsPerUnit);
        return (stakingGrowth_, allocation_.fee, allocation_.creator);
    }

    /// @inheritdoc IStakedDETF
    function retireEscrowDust(uint256 gons_) external synchronized nonReentrant {
        Repo.Storage storage s_ = Repo._layoutStruct();
        if (msg.sender != s_.bondNftVault) revert Unauthorized(msg.sender);
        Repo._retireFraction(s_, msg.sender, gons_);
        _topUpWeights(s_);
    }

    function _exchange(
        IERC20 tokenIn_, IERC20 tokenOut_, uint256 amount_, address recipient_, bool pretransferred_, uint256 deadline_
    ) internal {
        if (block.timestamp > deadline_) revert DeadlineExpired(deadline_);
        if (amount_ == 0) revert ZeroAmount();
        // Preserve the secure claim-route rule: prior idle balances do not authenticate input.
        if (pretransferred_) revert ISecurePullErrors.TransferDeltaInsufficient(amount_, 0);
        bool stake_ = _isStake(tokenIn_, tokenOut_);
        if (recipient_ == address(0)) recipient_ = msg.sender;
        Repo.Storage storage s_ = Repo._layoutStruct();
        if (stake_) {
            _pullDetf(s_, amount_);
            uint256 gons_ = Repo._creditPrincipal(s_, recipient_, amount_);
            emit Staked(msg.sender, recipient_, amount_, gons_);
        } else {
            uint256 gons_ = Repo._debitPrincipal(s_, msg.sender, amount_);
            s_.detf.safeTransfer(recipient_, amount_);
            Repo._requireBacking(s_);
            emit Unstaked(msg.sender, recipient_, amount_, gons_);
        }
        _topUpWeights(s_);
    }

    function _isStake(IERC20 tokenIn_, IERC20 tokenOut_) internal view returns (bool) {
        address backing_ = address(Repo._layoutStruct().detf);
        if (address(tokenIn_) == backing_ && address(tokenOut_) == address(this)) return true;
        if (address(tokenIn_) == address(this) && address(tokenOut_) == backing_) return false;
        revert InvalidStakingRoute(address(tokenIn_), address(tokenOut_));
    }

    function _pullDetf(Repo.Storage storage s_, uint256 amount_) internal {
        uint256 before_ = s_.detf.balanceOf(address(this));
        s_.detf.safeTransferFrom(msg.sender, address(this), amount_);
        uint256 after_ = s_.detf.balanceOf(address(this));
        uint256 received_ = after_ >= before_ ? after_ - before_ : 0;
        if (received_ != amount_) revert ISecurePullErrors.TransferDeltaInsufficient(amount_, received_);
    }

    function _topUpWeights(Repo.Storage storage s_) internal {
        (, uint256 fee_, uint256 creator_) = s_.feeOracle.seigniorageSplitOfVault(address(s_.detf));
        Repo._topUpWeights(s_, fee_, creator_);
    }

    function _synchronize() internal {
        Repo.Storage storage s_ = Repo._layoutStruct();
        if (s_.synchronizing) revert RewardSynchronizationInProgress();
        s_.synchronizing = true;
        IDETFFundedRewards(address(s_.detf)).synchronizeRewards();
        s_.synchronizing = false;
    }
}
