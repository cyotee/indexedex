// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {IDETFFundedRewards} from "contracts/interfaces/IStakedDETF.sol";
import {ExchangeInAmount} from "contracts/utils/ExchangeInAmount.sol";
import {DETFSYTarget} from "contracts/vaults/detf/common/sy/DETFSYTarget.sol";
import {DETFSYRepo as SYRepo} from "contracts/vaults/detf/common/sy/DETFSYRepo.sol";
import {DETFFundedStakingMath as StakingMath} from "contracts/vaults/detf/common/core/DETFFundedStakingMath.sol";
import {
    IUniswapV4DetfMigration,
    IUniswapV4DetfMigrationAccounting
} from "../interfaces/IUniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationStakedDETF} from "../claimToken/IUniswapV4DetfMigrationStakedDETF.sol";
import {UniswapV4DetfMigrationSYRepo as Repo} from "./UniswapV4DetfMigrationSYRepo.sol";

/// @notice Raw-backed SY or principal-denominated staking SY with old-holder reward custody.
/// @dev Uses the common registered package in both modes. The inherited metadata, route lists,
/// approvals and vault queries still read the canonical common repos; no second share ledger exists.
contract UniswapV4DetfMigrationSYTarget is DETFSYTarget, IUniswapV4DetfMigrationAccounting {
    using BetterSafeERC20 for IERC20;

    uint256 internal constant REWARD_QUANTUM = 1e18;

    error InvalidPrincipalGons(uint256 gons, uint256 k);
    error MigrationAcquisitionClosed();

    /// @dev Announce synchronization before the parent call, then take the local lock at the entry.
    /// Parent admission checks the actual fixed child and this phase, not the origin of a token hook.
    modifier migrationSynchronized(AccountingPhase phase_) {
        Repo.Storage storage m_ = Repo._layoutStruct();
        if (m_.phase != AccountingPhase.Idle) {
            revert MigrationAccountingBusy(address(this), uint8(m_.phase));
        }
        m_.phase = AccountingPhase.Synchronizing;
        IDETFFundedRewards(address(SYRepo._layoutStruct().detf)).synchronizeRewards();
        m_.phase = phase_;
        _;
        m_.phase = AccountingPhase.Idle;
    }

    /// @inheritdoc IUniswapV4DetfMigrationAccounting
    function migrationAccountingPhase() external view returns (uint8) {
        return uint8(Repo._layoutStruct().phase);
    }

    /// @notice Receipt-side custody debits read the actual post-effects common attribution.
    function attributedSyGons() external view returns (uint256) {
        SYRepo.Storage storage s_ = SYRepo._layoutStruct();
        return s_.isStaking ? s_.backingGons : 0;
    }

    /// @notice Settle both distinct old holders before moving principal shares.
    function transfer(address to_, uint256 amount_)
        external override migrationSynchronized(AccountingPhase.Accounting) nonReentrant returns (bool)
    {
        _checkpointTransfer(msg.sender, to_);
        ERC20Repo._transfer(msg.sender, to_, amount_);
        _requireBacking(SYRepo._layoutStruct());
        return true;
    }

    /// @notice Spend the canonical allowance, including max and owner-as-spender allowances.
    function transferFrom(address from_, address to_, uint256 amount_)
        external override migrationSynchronized(AccountingPhase.Accounting) nonReentrant returns (bool)
    {
        _checkpointTransfer(from_, to_);
        ERC20Repo._transferFrom(from_, to_, amount_);
        _requireBacking(SYRepo._layoutStruct());
        return true;
    }

    /// @notice Only the input actually pulled by this call can create new principal shares.
    function deposit(address receiver_, address tokenIn_, uint256 amount_, uint256 minimum_)
        external payable override migrationSynchronized(AccountingPhase.Acquiring) nonReentrant
        returns (uint256 shares_)
    {
        if (msg.value != 0) revert UnexpectedNativeValue();
        if (amount_ == 0) revert ZeroAmount();
        if (receiver_ == address(0)) revert InvalidReceiver(receiver_);
        if (!isValidTokenIn(tokenIn_)) revert InvalidToken(tokenIn_);
        SYRepo.Storage storage s_ = SYRepo._layoutStruct();
        if (s_.isStaking) {
            // Acquisition may fund an active issuance distribution. Pin k only after it finishes.
            uint256 receivedGons_ = _acquireStakingGons(s_, IERC20(tokenIn_), amount_);
            uint256 k_ = s_.staking.stakingState().gonsPerUnit;
            if (receivedGons_ % k_ != 0) revert InvalidPrincipalGons(receivedGons_, k_);
            shares_ = receivedGons_ / k_;
            Repo._layoutStruct().phase = AccountingPhase.Accounting;
            // Book the measured in-flight packet before a custody callback reads post-debit A.
            // The mint below represents this addition; it must not add the same gons again.
            s_.backingGons += receivedGons_;
            _checkpoint(s_, receiver_, k_);
        } else {
            shares_ = _acquireDetf(s_, IERC20(tokenIn_), amount_);
            Repo._layoutStruct().phase = AccountingPhase.Accounting;
            s_.rawBacking += shares_;
        }
        if (shares_ == 0) revert ZeroShares();
        if (shares_ < minimum_) revert MinimumOutputNotMet(minimum_, shares_);
        ERC20Repo._mint(receiver_, shares_);
        _requireBacking(s_);
        emit Deposit(msg.sender, receiver_, tokenIn_, amount_, shares_);
    }

    /// @notice Preserve the standard bearer branch: true burns issued shares actually held at SY.
    function redeem(address receiver_, uint256 shares_, address tokenOut_, uint256 minimum_, bool internalBalance_)
        external override migrationSynchronized(AccountingPhase.Accounting) nonReentrant
        returns (uint256 amountOut_)
    {
        if (shares_ == 0) revert ZeroAmount();
        if (receiver_ == address(0)) revert InvalidReceiver(receiver_);
        if (!isValidTokenOut(tokenOut_)) revert InvalidToken(tokenOut_);
        SYRepo.Storage storage s_ = SYRepo._layoutStruct();
        address source_ = internalBalance_ ? address(this) : msg.sender;
        if (s_.isStaking) {
            uint256 k_ = s_.staking.stakingState().gonsPerUnit;
            _checkpoint(s_, source_, k_);
            ERC20Repo._burn(source_, shares_);
            s_.backingGons -= StakingMath._toGons(shares_, k_);
            IUniswapV4DetfMigrationStakedDETF receipt_ = _receipt(s_);
            if (tokenOut_ == address(s_.staking)) {
                receipt_.transferSyPrincipal(receiver_, shares_, k_);
                amountOut_ = shares_;
            } else {
                // No pooled full-account unstake or fractional retirement is admitted here.
                uint256 before_ = s_.detf.balanceOf(address(this));
                receipt_.withdrawSyPrincipal(address(this), shares_, k_);
                uint256 received_ = s_.detf.balanceOf(address(this)) - before_;
                if (received_ != shares_) revert UnexpectedTransferAmount(shares_, received_);
                Repo._layoutStruct().phase = AccountingPhase.Paying;
                amountOut_ = _payPrincipal(s_, shares_, IERC20(tokenOut_), receiver_);
            }
        } else {
            ERC20Repo._burn(source_, shares_);
            s_.rawBacking -= shares_;
            Repo._layoutStruct().phase = AccountingPhase.Paying;
            amountOut_ = _payPrincipal(s_, shares_, IERC20(tokenOut_), receiver_);
        }
        if (amountOut_ < minimum_) revert MinimumOutputNotMet(minimum_, amountOut_);
        _requireBacking(s_);
        emit Redeem(msg.sender, receiver_, tokenOut_, shares_, amountOut_);
    }

    /// @notice Both modes quote principal only. Staking rewards have a separate RT-valued API.
    function exchangeRate() public pure override returns (uint256) { return 1e18; }

    function previewDeposit(address tokenIn_, uint256 amount_) external view override returns (uint256) {
        if (!isValidTokenIn(tokenIn_)) return 0;
        SYRepo.Storage storage s_ = SYRepo._layoutStruct();
        if (tokenIn_ == address(s_.detf) || (s_.isStaking && tokenIn_ == address(s_.staking))) return amount_;
        // A declared raw-SY receipt input is an existing-principal exit, not ordinary acquisition.
        if (tokenIn_ != address(s_.staking) && !_parent(s_).migrationActivated()) return 0;
        return ExchangeInAmount.previewOut(IStandardExchangeIn(address(s_.detf)), IERC20(tokenIn_), amount_, s_.detf);
    }

    function previewRedeem(address tokenOut_, uint256 shares_) external view override returns (uint256) {
        if (!isValidTokenOut(tokenOut_)) return 0;
        SYRepo.Storage storage s_ = SYRepo._layoutStruct();
        if (tokenOut_ == address(s_.detf) || (s_.isStaking && tokenOut_ == address(s_.staking))) return shares_;
        return ExchangeInAmount.previewOut(IStandardExchangeIn(address(s_.detf)), s_.detf, shares_, IERC20(tokenOut_));
    }

    /// @notice Native RT quantities use one token unit per 1e18 exact receipt gons.
    function getRewardTokens() external view override returns (address[] memory) {
        return _rewardTokens(SYRepo._layoutStruct());
    }

    function accruedRewards(address user_) external view override returns (uint256[] memory amounts_) {
        SYRepo.Storage storage s_ = SYRepo._layoutStruct();
        amounts_ = new uint256[](s_.isStaking ? 1 : 0);
        if (!s_.isStaking || user_ == address(this)) return amounts_;
        uint256 k_ = s_.staking.stakingState().gonsPerUnit;
        uint256 gons_ = _receipt(s_).deferredRewardGons(
            uint8(IUniswapV4DetfMigrationStakedDETF.RewardDomain.SY), user_
        );
        gons_ += _latentGons(user_, k_);
        amounts_[0] = gons_ / REWARD_QUANTUM;
    }

    function rewardIndexesCurrent()
        external override migrationSynchronized(AccountingPhase.Accounting) nonReentrant
        returns (uint256[] memory)
    {
        return _rewardIndexes(SYRepo._layoutStruct());
    }

    function rewardIndexesStored() external view override returns (uint256[] memory) {
        return _rewardIndexes(SYRepo._layoutStruct());
    }

    /// @notice Anyone may trigger a fixed-beneficiary claim; even a zero claim requires activation.
    function claimRewards(address user_)
        external override migrationSynchronized(AccountingPhase.Accounting) nonReentrant
        returns (uint256[] memory amounts_)
    {
        SYRepo.Storage storage s_ = SYRepo._layoutStruct();
        _requireActivated(s_);
        amounts_ = new uint256[](s_.isStaking ? 1 : 0);
        if (s_.isStaking) {
            uint256 k_ = s_.staking.stakingState().gonsPerUnit;
            _checkpoint(s_, user_, k_);
            // The receipt credits self-held earnings to U; they have no public beneficiary.
            if (user_ != address(this)) amounts_[0] = _receipt(s_).issueSyRewardTokens(user_, k_);
        }
        _requireBacking(s_);
        emit ClaimRewards(user_, _rewardTokens(s_), amounts_);
    }

    /// @notice Owner-only native-sDETF payment from R2 modulo q, never from its whole-RT portion.
    function claimRewardRemainder()
        external migrationSynchronized(AccountingPhase.Accounting) nonReentrant returns (uint256 nativeSDETF_)
    {
        SYRepo.Storage storage s_ = SYRepo._layoutStruct();
        _requireActivated(s_);
        if (s_.isStaking) {
            uint256 k_ = s_.staking.stakingState().gonsPerUnit;
            _checkpoint(s_, msg.sender, k_);
            nativeSDETF_ = _receipt(s_).paySyRewardRemainder(msg.sender, k_);
        }
        _requireBacking(s_);
    }

    function _checkpointTransfer(address from_, address to_) private {
        SYRepo.Storage storage s_ = SYRepo._layoutStruct();
        if (!s_.isStaking) return;
        uint256 k_ = s_.staking.stakingState().gonsPerUnit;
        _checkpoint(s_, from_, k_);
        if (to_ != from_) _checkpoint(s_, to_, k_);
    }

    function _checkpoint(SYRepo.Storage storage s_, address account_, uint256 k_) private {
        uint256 gons_ = _latentGons(account_, k_);
        Repo._layoutStruct().lastK[account_] = k_;
        if (gons_ == 0) return;
        // Receipt verifies coverage against this already-debited authoritative attribution.
        s_.backingGons -= gons_;
        _receipt(s_).deferSyRewards(account_, gons_, k_);
    }

    function _latentGons(address account_, uint256 k_) private view returns (uint256) {
        uint256 lastK_ = Repo._layoutStruct().lastK[account_];
        uint256 shares_ = ERC20Repo._balanceOf(account_);
        if (lastK_ == 0 && shares_ == 0) return 0;
        if (lastK_ < k_) revert UnexpectedGonsPerUnit(lastK_, k_);
        if (lastK_ == k_) return 0;
        return StakingMath._toGons(shares_, lastK_ - k_);
    }

    /// @dev Actual parent output/refund receipt, never pre-existing input or output inventory.
    function _acquireDetf(SYRepo.Storage storage s_, IERC20 tokenIn_, uint256 amount_)
        internal override returns (uint256)
    {
        if (address(tokenIn_) != address(s_.detf) && address(tokenIn_) != address(s_.staking)) {
            if (!_parent(s_).migrationActivated()) revert MigrationAcquisitionClosed();
        }
        if (address(tokenIn_) == address(s_.staking)) {
            // Raw SY is an ordinary receipt wallet. Remove its old latent growth before measuring
            // a new receipt packet; staking SY takes its protected direct-input branch instead.
            _receipt(s_).checkpointRewards();
        }
        uint256 received_ = _pull(tokenIn_, amount_);
        if (address(tokenIn_) == address(s_.detf)) return received_;
        ExchangeInAmount.Result memory result_ = _exchangeParent(s_, tokenIn_, received_, s_.detf);
        if (result_.amountRefunded != 0) tokenIn_.safeTransfer(msg.sender, result_.amountRefunded);
        return result_.amountOut;
    }

    function _payPrincipal(SYRepo.Storage storage s_, uint256 amount_, IERC20 tokenOut_, address receiver_)
        private returns (uint256)
    {
        if (address(tokenOut_) == address(s_.detf)) {
            s_.detf.safeTransfer(receiver_, amount_);
            return amount_;
        }
        if (address(tokenOut_) == address(s_.staking)) _receipt(s_).checkpointRewards();
        ExchangeInAmount.Result memory result_ = _exchangeParent(s_, s_.detf, amount_, tokenOut_);
        tokenOut_.safeTransfer(receiver_, result_.amountOut);
        if (result_.amountRefunded != 0) s_.detf.safeTransfer(receiver_, result_.amountRefunded);
        return result_.amountOut;
    }

    function _exchangeParent(SYRepo.Storage storage s_, IERC20 tokenIn_, uint256 amount_, IERC20 tokenOut_)
        private returns (ExchangeInAmount.Result memory result_)
    {
        uint256 inputBefore_ = tokenIn_.balanceOf(address(this));
        uint256 outputBefore_ = tokenOut_.balanceOf(address(this));
        tokenIn_.forceApprove(address(s_.detf), amount_);
        result_ = ExchangeInAmount.exchangeResult(
            IStandardExchangeIn(address(s_.detf)), tokenIn_, amount_, tokenOut_, 0,
            address(this), false, block.timestamp
        );
        tokenIn_.forceApprove(address(s_.detf), 0);
        ExchangeInAmount.requireReceipt(
            amount_, result_, inputBefore_, tokenIn_.balanceOf(address(this)),
            outputBefore_, tokenOut_.balanceOf(address(this))
        );
    }

    function _rewardTokens(SYRepo.Storage storage s_) private view returns (address[] memory tokens_) {
        tokens_ = new address[](s_.isStaking ? 1 : 0);
        if (s_.isStaking) tokens_[0] = _parent(s_).migrationSyRewardToken();
    }

    function _rewardIndexes(SYRepo.Storage storage s_) private view returns (uint256[] memory indexes_) {
        indexes_ = new uint256[](s_.isStaking ? 1 : 0);
        if (s_.isStaking) {
            indexes_[0] = 1 + StakingMath.INITIAL_GONS_PER_UNIT - s_.staking.stakingState().gonsPerUnit;
        }
    }

    function _requireActivated(SYRepo.Storage storage s_) private view {
        if (!_parent(s_).migrationActivated()) revert MigrationRewardsClosed();
    }

    function _parent(SYRepo.Storage storage s_) private view returns (IUniswapV4DetfMigration) {
        return IUniswapV4DetfMigration(address(s_.detf));
    }

    function _receipt(SYRepo.Storage storage s_) private view returns (IUniswapV4DetfMigrationStakedDETF) {
        return IUniswapV4DetfMigrationStakedDETF(address(s_.staking));
    }
}
