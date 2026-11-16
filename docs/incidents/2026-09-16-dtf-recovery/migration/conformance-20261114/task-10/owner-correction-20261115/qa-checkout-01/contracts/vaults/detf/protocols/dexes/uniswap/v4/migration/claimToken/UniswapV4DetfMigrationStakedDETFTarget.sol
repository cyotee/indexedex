// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC721} from "@crane/contracts/interfaces/IERC721.sol";
import {IERC20Errors} from "@crane/contracts/interfaces/IERC20Errors.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {IStakedDETF} from "contracts/interfaces/IStakedDETF.sol";
import {ISecurePullErrors} from "contracts/interfaces/ISecurePullErrors.sol";
import {LocalCreditLib} from "contracts/utils/LocalCreditLib.sol";
import {StakedDETFTarget} from "contracts/vaults/detf/common/claimToken/StakedDETFTarget.sol";
import {DETFFundedStakingRepo as FundedRepo} from
    "contracts/vaults/detf/common/claimToken/DETFFundedStakingRepo.sol";
import {DETFFundedStakingMath as StakingMath} from
    "contracts/vaults/detf/common/core/DETFFundedStakingMath.sol";
import {DETF_FEE_TO_BOND_NFT_ID, DETF_CREATOR_BOND_NFT_ID} from
    "contracts/vaults/detf/common/core/DETFBondNftIds.sol";
import {IUniswapV4DetfMigration, IUniswapV4DetfMigrationAccounting} from
    "../interfaces/IUniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationBondNFTVault} from "../bondNft/IUniswapV4DetfMigrationBondNFTVault.sol";
import {IUniswapV4DetfMigrationSY} from "../sy/IUniswapV4DetfMigrationSY.sol";
import {IUniswapV4DetfMigrationRewardToken} from "../sy/rewards/IUniswapV4DetfMigrationRewardToken.sol";
import {UniswapV4DetfMigrationRewardTokenRepo as RewardTokenRepo} from
    "../sy/rewards/UniswapV4DetfMigrationRewardTokenRepo.sol";
import {IUniswapV4DetfMigrationStakedDETF} from "./IUniswapV4DetfMigrationStakedDETF.sol";
import {UniswapV4DetfMigrationStakedDETFRepo as Repo} from "./UniswapV4DetfMigrationStakedDETFRepo.sol";

/// @notice R3 principal packets and exact retained rewards over the canonical funded receipt ledger.
/// @dev No second backing pool or index. Protected custodians use only fixed typed post-debit calls.
contract UniswapV4DetfMigrationStakedDETFTarget is StakedDETFTarget, IUniswapV4DetfMigrationStakedDETF {
    using BetterSafeERC20 for IERC20;

    modifier accounting() {
        _requireIdle();
        Repo._layoutStruct().phase = uint8(AccountingPhase.Accounting);
        _;
        _requireEscrow();
        Repo._layoutStruct().phase = uint8(AccountingPhase.Idle);
    }

    /// @inheritdoc IUniswapV4DetfMigrationAccounting
    function migrationAccountingPhase() external view returns (uint8) {
        return Repo._layoutStruct().phase;
    }

    /// @inheritdoc IUniswapV4DetfMigrationStakedDETF
    function egressState(address account_) external view returns (
        uint256 physicalGons, uint256 liquidBasis, uint256 latentGons,
        uint256 walletGons, uint256 roleGons, uint256 syGons, uint256 maxUnstake
    ) {
        FundedRepo.Storage storage s_ = FundedRepo._layoutStruct();
        Repo.Storage storage m_ = Repo._layoutStruct();
        physicalGons = s_.gonsOf[account_];
        walletGons = m_.deferred[0][account_];
        roleGons = m_.deferred[1][account_];
        syGons = m_.deferred[2][account_];
        if (!_protected(account_)) {
            liquidBasis = m_.liquidBasis[account_];
            uint256 required_ = StakingMath._toGons(liquidBasis, s_.gonsPerUnit);
            _requireCoverage(account_, physicalGons, required_);
            latentGons = physicalGons - required_;
            maxUnstake = _parent().migrationActivated() ? physicalGons / s_.gonsPerUnit : liquidBasis;
        }
    }

    /// @inheritdoc IUniswapV4DetfMigrationStakedDETF
    function deferredRewardGons(uint8 domain_, address beneficiary_) external view returns (uint256) {
        if (domain_ > 2) revert InvalidRewardDomain(domain_);
        return Repo._layoutStruct().deferred[domain_][beneficiary_];
    }

    /// @inheritdoc IUniswapV4DetfMigrationStakedDETF
    function tokenizedSyRewardGons() external view returns (uint256) {
        return Repo._layoutStruct().tokenizedSyGons;
    }

    /// @inheritdoc IUniswapV4DetfMigrationStakedDETF
    function checkpointRewards() external synchronized nonReentrant accounting returns (uint256 movedGons) {
        _requireNormal(msg.sender);
        return _checkpoint(msg.sender);
    }

    /// @inheritdoc IERC20
    function transfer(address to_, uint256 amount_)
        external override(StakedDETFTarget, IERC20) synchronized nonReentrant accounting returns (bool)
    {
        _transferPrincipal(msg.sender, to_, amount_, false);
        return true;
    }

    /// @inheritdoc IERC20
    function transferFrom(address from_, address to_, uint256 amount_)
        external override(StakedDETFTarget, IERC20) synchronized nonReentrant accounting returns (bool)
    {
        // Canonical semantics deliberately spend even max allowance and owner-as-spender approval.
        ERC20Repo._spendAllowance(from_, msg.sender, amount_);
        _transferPrincipal(from_, to_, amount_, true);
        return true;
    }

    /// @inheritdoc IStakedDETF
    function fundRewards(uint256 amount_)
        external override(StakedDETFTarget, IStakedDETF) nonReentrant
        returns (uint256 stakingGrowth_, uint256 feeReceipt_, uint256 creatorReceipt_)
    {
        FundedRepo.Storage storage s_ = FundedRepo._layoutStruct();
        if (msg.sender != address(s_.detf)) revert Unauthorized(msg.sender);
        Repo.Storage storage m_ = Repo._layoutStruct();
        uint8 savedPhase_ = m_.phase;
        if (savedPhase_ != uint8(AccountingPhase.Idle) && savedPhase_ != uint8(AccountingPhase.Synchronizing)) {
            revert MigrationAccountingBusy(address(this), savedPhase_);
        }
        m_.phase = uint8(AccountingPhase.Accounting);
        if (amount_ == 0) revert ZeroAmount();
        _pullDetf(s_, amount_);
        address feeRecipient_ = IERC721(s_.bondNftVault).ownerOf(DETF_FEE_TO_BOND_NFT_ID);
        address creatorRecipient_ = IERC721(s_.bondNftVault).ownerOf(DETF_CREATOR_BOND_NFT_ID);
        StakingMath.RewardAllocation memory allocation_;
        (allocation_, stakingGrowth_) = _distributeRewards(s_, amount_, feeRecipient_, creatorRecipient_);
        _topUpWeights(s_);
        _requireEscrow();
        // Funding inside an outer synchronization must not expose an Idle callback window.
        m_.phase = savedPhase_;
        emit RewardsFunded(amount_, stakingGrowth_, allocation_.fee, allocation_.creator, s_.gonsPerUnit);
        return (stakingGrowth_, allocation_.fee, allocation_.creator);
    }

    /// @inheritdoc IStakedDETF
    function retireEscrowDust(uint256 gons_)
        external override(StakedDETFTarget, IStakedDETF) nonReentrant accounting
    {
        FundedRepo.Storage storage s_ = FundedRepo._layoutStruct();
        _requireCaller(s_.bondNftVault, AccountingPhase.Accounting);
        _requirePostDebit(msg.sender, gons_, IUniswapV4DetfMigrationBondNFTVault(msg.sender).attributedBondGons());
        uint256 dustBefore_ = s_.stakingDust;
        FundedRepo._retireFraction(s_, msg.sender, gons_);
        _topUpWeights(s_);
        emit MigrationGonsRetired(msg.sender, gons_, s_.stakingDust - dustBefore_, s_.gonsPerUnit);
    }

    /// @inheritdoc IUniswapV4DetfMigrationStakedDETF
    function claimDeferredRewards(uint8 domain_)
        external synchronized nonReentrant accounting returns (uint256 nativePaid)
    {
        if (domain_ > 1) revert InvalidRewardDomain(domain_);
        return _release(domain_, msg.sender);
    }

    /// @inheritdoc IUniswapV4DetfMigrationStakedDETF
    function claimDeferredRoleRewards(address beneficiary_)
        external synchronized nonReentrant accounting returns (uint256 nativePaid)
    {
        return _release(1, beneficiary_);
    }

    /// @inheritdoc IUniswapV4DetfMigrationStakedDETF
    function transferDeferredRewardRights(uint8 domain_, address to_, uint256 gons_)
        external synchronized nonReentrant accounting
    {
        if (domain_ != 0 && domain_ != 2) revert InvalidRewardDomain(domain_);
        _requireNormal(msg.sender);
        _requireNormal(to_);
        _debitDeferred(domain_, msg.sender, gons_);
        Repo.Storage storage m_ = Repo._layoutStruct();
        m_.deferred[domain_][to_] += gons_;
        m_.deferredGons += gons_;
        emit DeferredRewardRightsTransferred(msg.sender, to_, domain_, gons_);
    }

    /// @inheritdoc IUniswapV4DetfMigrationStakedDETF
    function deliverBondClaim(address recipient_, uint256 principal_, uint256 reward_, uint256 expectedK_)
        external nonReentrant accounting
    {
        _requireCaller(FundedRepo._layoutStruct().bondNftVault, AccountingPhase.Accounting);
        _requireK(expectedK_);
        if (reward_ != 0) _requireActive();
        uint256 amount_ = principal_ + reward_;
        uint256 gons_ = StakingMath._toGons(amount_, expectedK_);
        _requirePostDebit(msg.sender, gons_, IUniswapV4DetfMigrationBondNFTVault(msg.sender).attributedBondGons());
        _deliverNative(msg.sender, recipient_, amount_);
    }

    /// @inheritdoc IUniswapV4DetfMigrationStakedDETF
    function deferSyRewards(address beneficiary_, uint256 gons_, uint256 expectedK_)
        external nonReentrant accounting
    {
        _requireCaller(_parent().stakingSY(), AccountingPhase.Accounting);
        _requireK(expectedK_);
        if (beneficiary_ == address(0)) revert InvalidRewardBeneficiary(beneficiary_);
        _requirePostDebit(msg.sender, gons_, IUniswapV4DetfMigrationSY(msg.sender).attributedSyGons());
        _moveGons(msg.sender, address(this), gons_);
        if (beneficiary_ == msg.sender) {
            Repo._layoutStruct().selfHeldSyGons += gons_;
            emit SelfHeldSyRewardsDeferred(msg.sender, gons_, expectedK_);
        } else {
            _creditDeferred(2, beneficiary_, gons_, msg.sender);
        }
    }

    /// @inheritdoc IUniswapV4DetfMigrationStakedDETF
    function transferSyPrincipal(address recipient_, uint256 principal_, uint256 expectedK_)
        external nonReentrant accounting
    {
        _requireCaller(_parent().stakingSY(), AccountingPhase.Accounting);
        _requireK(expectedK_);
        _requirePostDebit(
            msg.sender, StakingMath._toGons(principal_, expectedK_),
            IUniswapV4DetfMigrationSY(msg.sender).attributedSyGons()
        );
        _deliverNative(msg.sender, recipient_, principal_);
    }

    /// @inheritdoc IUniswapV4DetfMigrationStakedDETF
    function withdrawSyPrincipal(address recipient_, uint256 principal_, uint256 expectedK_)
        external nonReentrant accounting
    {
        _requireCaller(_parent().stakingSY(), AccountingPhase.Accounting);
        _requireK(expectedK_);
        if (recipient_ == address(0)) revert IERC20Errors.ERC20InvalidReceiver(recipient_);
        uint256 gons_ = StakingMath._toGons(principal_, expectedK_);
        _requirePostDebit(msg.sender, gons_, IUniswapV4DetfMigrationSY(msg.sender).attributedSyGons());
        FundedRepo.Storage storage s_ = FundedRepo._layoutStruct();
        // Never use full-account withdrawal/retirement on pooled SY inventory.
        s_.gonsOf[msg.sender] -= gons_;
        s_.totalGons -= gons_;
        s_.accountedBacking -= principal_;
        emit Transfer(msg.sender, address(0), principal_);
        Repo._layoutStruct().phase = uint8(AccountingPhase.Paying);
        s_.detf.safeTransfer(recipient_, principal_);
        FundedRepo._requireBacking(s_);
        _topUpWeights(s_);
        emit Unstaked(msg.sender, recipient_, principal_, gons_);
    }

    /// @inheritdoc IUniswapV4DetfMigrationStakedDETF
    function issueSyRewardTokens(address beneficiary_, uint256 expectedK_)
        external nonReentrant accounting returns (uint256 nativeRT)
    {
        _requireCaller(_parent().stakingSY(), AccountingPhase.Accounting);
        _requireK(expectedK_);
        _requireActive();
        _requireNormal(beneficiary_);
        IUniswapV4DetfMigrationRewardToken token_ = _rewardToken();
        _requireTokenizedSupply(token_);
        nativeRT = Repo._layoutStruct().deferred[2][beneficiary_] / RewardTokenRepo.GONS_PER_UNIT;
        uint256 gons_ = StakingMath._toGons(nativeRT, RewardTokenRepo.GONS_PER_UNIT);
        _debitDeferred(2, beneficiary_, gons_);
        Repo._layoutStruct().tokenizedSyGons += gons_;
        token_.mintByReceipt(beneficiary_, nativeRT);
        _requireTokenizedSupply(token_);
        emit SyRewardsTokenized(beneficiary_, nativeRT, gons_, expectedK_);
    }

    /// @inheritdoc IUniswapV4DetfMigrationStakedDETF
    function paySyRewardRemainder(address beneficiary_, uint256 expectedK_)
        external nonReentrant accounting returns (uint256 nativeSDETF)
    {
        _requireCaller(_parent().stakingSY(), AccountingPhase.Accounting);
        _requireK(expectedK_);
        _requireActive();
        _requireNormal(beneficiary_);
        uint256 remainder_ = Repo._layoutStruct().deferred[2][beneficiary_] % RewardTokenRepo.GONS_PER_UNIT;
        nativeSDETF = remainder_ / expectedK_;
        uint256 gons_ = StakingMath._toGons(nativeSDETF, expectedK_);
        _debitDeferred(2, beneficiary_, gons_);
        _deliverNative(address(this), beneficiary_, nativeSDETF);
        emit SyRewardRemainderPaid(beneficiary_, nativeSDETF, gons_, expectedK_);
    }

    /// @inheritdoc IUniswapV4DetfMigrationStakedDETF
    function redeemSyRewardTokens(address owner_, address receiver_, uint256 nativeRT_, uint256 minNative_)
        external synchronized nonReentrant accounting returns (uint256 nativeSDETF, uint256 retainedGons)
    {
        IUniswapV4DetfMigrationRewardToken token_ = _rewardToken();
        _requireCaller(address(token_), AccountingPhase.Accounting);
        _requireActive();
        _requireNormal(owner_);
        _requireNormal(receiver_);
        _requireTokenizedSupply(token_);
        uint256 balance_ = token_.balanceOf(owner_);
        if (nativeRT_ > balance_) revert IERC20Errors.ERC20InsufficientBalance(owner_, balance_, nativeRT_);
        uint256 k_ = FundedRepo._layoutStruct().gonsPerUnit;
        uint256 gons_ = StakingMath._toGons(nativeRT_, RewardTokenRepo.GONS_PER_UNIT);
        nativeSDETF = gons_ / k_;
        retainedGons = gons_ % k_;
        if (nativeSDETF < minNative_) revert MinimumOutputNotMet(minNative_, nativeSDETF);
        Repo._layoutStruct().tokenizedSyGons -= gons_;
        token_.burnByReceipt(owner_, nativeRT_);
        _requireTokenizedSupply(token_);
        _creditDeferred(0, owner_, retainedGons, address(this));
        _deliverNative(address(this), receiver_, nativeSDETF);
    }

    /// @dev Both inherited SE exact-in and exact-out dispatch here after synchronization and lock.
    function _exchange(
        IERC20 tokenIn_, IERC20 tokenOut_, uint256 amount_, address recipient_, bool pretransferred_, uint256 deadline_
    ) internal override accounting {
        if (block.timestamp > deadline_) revert DeadlineExpired(deadline_);
        if (amount_ == 0) revert ZeroAmount();
        if (pretransferred_) {
            LocalCreditLib.requirePretransferCaller(msg.sender);
            revert ISecurePullErrors.TransferDeltaInsufficient(amount_, 0);
        }
        bool stake_ = _isStake(tokenIn_, tokenOut_);
        if (recipient_ == address(0)) recipient_ = msg.sender;
        FundedRepo.Storage storage s_ = FundedRepo._layoutStruct();
        if (stake_) {
            if (_protected(recipient_)) {
                if (recipient_ == s_.bondNftVault) {
                    _requireCaller(recipient_, AccountingPhase.Accounting);
                    _requireCoverage(
                        recipient_, s_.gonsOf[recipient_],
                        IUniswapV4DetfMigrationBondNFTVault(recipient_).attributedBondGons()
                    );
                } else if (recipient_ == _parent().stakingSY()) {
                    _requireCaller(recipient_, AccountingPhase.Acquiring);
                    _requireCoverage(
                        recipient_, s_.gonsOf[recipient_], IUniswapV4DetfMigrationSY(recipient_).attributedSyGons()
                    );
                } else {
                    revert InvalidRewardBeneficiary(recipient_);
                }
            } else {
                _requireNormal(recipient_);
                _checkpoint(recipient_);
                Repo._layoutStruct().liquidBasis[recipient_] += amount_;
            }
            _pullDetf(s_, amount_);
            uint256 gons_ = FundedRepo._creditPrincipal(s_, recipient_, amount_);
            emit Staked(msg.sender, recipient_, amount_, gons_);
        } else {
            _requireNormal(msg.sender);
            if (!_parent().migrationActivated()) {
                _checkpoint(msg.sender);
                _requirePrincipal(msg.sender, amount_);
            }
            _debitBasis(msg.sender, amount_);
            uint256 dustBefore_ = s_.stakingDust;
            uint256 gons_ = FundedRepo._debitPrincipal(s_, msg.sender, amount_);
            uint256 retired_ = gons_ - StakingMath._toGons(amount_, s_.gonsPerUnit);
            if (retired_ != 0) {
                emit MigrationGonsRetired(msg.sender, retired_, s_.stakingDust - dustBefore_, s_.gonsPerUnit);
            }
            Repo._layoutStruct().phase = uint8(AccountingPhase.Paying);
            s_.detf.safeTransfer(recipient_, amount_);
            FundedRepo._requireBacking(s_);
            emit Unstaked(msg.sender, recipient_, amount_, gons_);
        }
        _topUpWeights(s_);
    }

    /// @dev Canonical two-floor allocation/rebase issues into escrow before any recipient delivery.
    function _distributeRewards(
        FundedRepo.Storage storage s_, uint256 amount_, address feeRecipient_, address creatorRecipient_
    ) internal override returns (StakingMath.RewardAllocation memory allocation_, uint256 stakingGrowth_) {
        (allocation_, stakingGrowth_) = FundedRepo._distribute(s_, amount_, address(this), address(this));
        bool active_ = _parent().migrationActivated();
        _allocateRole(feeRecipient_, allocation_.fee, active_);
        _allocateRole(creatorRecipient_, allocation_.creator, active_);
    }

    function _allocateRole(address beneficiary_, uint256 amount_, bool active_) internal {
        if (beneficiary_ == address(0)) revert InvalidRewardBeneficiary(beneficiary_);
        if (amount_ == 0) return;
        if (!active_ || _protected(beneficiary_)) {
            _creditDeferred(
                1, beneficiary_, StakingMath._toGons(amount_, FundedRepo._layoutStruct().gonsPerUnit), address(0)
            );
        } else {
            _deliverNative(address(this), beneficiary_, amount_);
        }
    }

    function _transferPrincipal(address from_, address to_, uint256 amount_, bool allowancePull_) internal {
        _requireNormal(from_);
        bool syIngress_ = to_ != address(0) && to_ == _parent().stakingSY();
        if (syIngress_) {
            if (!allowancePull_) revert InvalidRewardBeneficiary(to_);
            _requireCaller(to_, AccountingPhase.Acquiring);
            // Receipt deposits convey principal, leaving old wallet rewards with their owner.
            _checkpoint(from_);
            _requirePrincipal(from_, amount_);
        } else {
            _requireNormal(to_);
            if (!_parent().migrationActivated()) {
                _checkpoint(from_);
                _requirePrincipal(from_, amount_);
                if (from_ != to_) _checkpoint(to_);
            }
        }
        FundedRepo._transfer(from_, to_, amount_);
        if (from_ != to_) {
            _debitBasis(from_, amount_);
            if (!syIngress_) Repo._layoutStruct().liquidBasis[to_] += amount_;
        }
    }

    function _checkpoint(address account_) internal returns (uint256 gons_) {
        FundedRepo.Storage storage s_ = FundedRepo._layoutStruct();
        uint256 principalGons_ = StakingMath._toGons(Repo._layoutStruct().liquidBasis[account_], s_.gonsPerUnit);
        _requireCoverage(account_, s_.gonsOf[account_], principalGons_);
        gons_ = s_.gonsOf[account_] - principalGons_;
        if (gons_ != 0) {
            _moveGons(account_, address(this), gons_);
            _creditDeferred(0, account_, gons_, account_);
        }
    }

    function _release(uint8 domain_, address beneficiary_) internal returns (uint256 nativePaid_) {
        _requireActive();
        _requireNormal(beneficiary_);
        // Only the owner's wallet claim crystallizes fresh wallet growth here. A permissionless
        // role release must not turn a contract beneficiary's active receipt balance into R0.
        if (domain_ == 0) _checkpoint(beneficiary_);
        uint256 k_ = FundedRepo._layoutStruct().gonsPerUnit;
        nativePaid_ = Repo._layoutStruct().deferred[domain_][beneficiary_] / k_;
        uint256 gons_ = StakingMath._toGons(nativePaid_, k_);
        _debitDeferred(domain_, beneficiary_, gons_);
        _deliverNative(address(this), beneficiary_, nativePaid_);
        emit DeferredRewardsPaid(beneficiary_, domain_, nativePaid_, gons_, k_);
    }

    function _deliverNative(address source_, address recipient_, uint256 amount_) internal {
        _requireNormal(recipient_);
        if (!_parent().migrationActivated()) _checkpoint(recipient_);
        Repo._layoutStruct().liquidBasis[recipient_] += amount_;
        FundedRepo._transfer(source_, recipient_, amount_);
    }

    function _moveGons(address from_, address to_, uint256 gons_) internal {
        FundedRepo.Storage storage s_ = FundedRepo._layoutStruct();
        _requireCoverage(from_, s_.gonsOf[from_], gons_);
        s_.gonsOf[from_] -= gons_;
        s_.gonsOf[to_] += gons_;
        emit Transfer(from_, to_, gons_ / s_.gonsPerUnit);
    }

    function _creditDeferred(uint8 domain_, address beneficiary_, uint256 gons_, address source_) internal {
        Repo.Storage storage m_ = Repo._layoutStruct();
        m_.deferred[domain_][beneficiary_] += gons_;
        m_.deferredGons += gons_;
        emit RewardGonsDeferred(source_, beneficiary_, domain_, gons_, FundedRepo._layoutStruct().gonsPerUnit);
    }

    function _debitDeferred(uint8 domain_, address beneficiary_, uint256 gons_) internal {
        Repo.Storage storage m_ = Repo._layoutStruct();
        uint256 available_ = m_.deferred[domain_][beneficiary_];
        if (gons_ > available_) revert InsufficientDeferredRewardGons(gons_, available_);
        m_.deferred[domain_][beneficiary_] = available_ - gons_;
        m_.deferredGons -= gons_;
    }

    function _debitBasis(address account_, uint256 amount_) internal {
        Repo.Storage storage m_ = Repo._layoutStruct();
        uint256 basis_ = m_.liquidBasis[account_];
        m_.liquidBasis[account_] = amount_ >= basis_ ? 0 : basis_ - amount_;
    }

    function _requirePrincipal(address account_, uint256 amount_) internal view {
        uint256 available_ = Repo._layoutStruct().liquidBasis[account_];
        if (amount_ > available_) revert InsufficientLiquidPrincipal(amount_, available_);
    }

    function _requirePostDebit(address custodian_, uint256 debit_, uint256 attributed_) internal view {
        uint256 held_ = FundedRepo._layoutStruct().gonsOf[custodian_];
        _requireCoverage(custodian_, held_, debit_);
        _requireCoverage(custodian_, held_ - debit_, attributed_);
    }

    function _requireCoverage(address custodian_, uint256 held_, uint256 required_) internal pure {
        if (held_ < required_) revert MigrationCustodyUnderfunded(custodian_, held_, required_);
    }

    function _requireEscrow() internal view {
        Repo.Storage storage m_ = Repo._layoutStruct();
        uint256 required_ = m_.deferredGons + m_.tokenizedSyGons + m_.selfHeldSyGons;
        uint256 held_ = FundedRepo._layoutStruct().gonsOf[address(this)];
        if (held_ != required_) revert MigrationCustodyUnderfunded(address(this), held_, required_);
    }

    function _requireTokenizedSupply(IUniswapV4DetfMigrationRewardToken token_) internal view {
        uint256 required_ = StakingMath._toGons(token_.totalSupply(), RewardTokenRepo.GONS_PER_UNIT);
        uint256 booked_ = Repo._layoutStruct().tokenizedSyGons;
        if (booked_ != required_) revert MigrationCustodyUnderfunded(address(token_), booked_, required_);
    }

    function _requireK(uint256 expected_) internal view {
        uint256 actual_ = FundedRepo._layoutStruct().gonsPerUnit;
        if (expected_ != actual_) revert UnexpectedGonsPerUnit(expected_, actual_);
    }

    function _requireCaller(address caller_, AccountingPhase phase_) internal view {
        if (caller_ == address(0) || msg.sender != caller_) revert Unauthorized(msg.sender);
        uint8 actual_ = IUniswapV4DetfMigrationAccounting(caller_).migrationAccountingPhase();
        if (actual_ != uint8(phase_)) revert MigrationAccountingBusy(caller_, actual_);
    }

    function _protected(address account_) internal view returns (bool) {
        return account_ == address(this) || account_ == FundedRepo._layoutStruct().bondNftVault
            || (account_ != address(0)
                && (account_ == _parent().stakingSY() || account_ == _parent().migrationSyRewardToken()));
    }

    function _requireNormal(address account_) internal view {
        if (account_ == address(0) || _protected(account_)) revert InvalidRewardBeneficiary(account_);
    }

    function _requireActive() internal view {
        if (!_parent().migrationActivated()) revert MigrationRewardsClosed();
    }

    function _requireIdle() internal view {
        uint8 phase_ = Repo._layoutStruct().phase;
        if (phase_ != uint8(AccountingPhase.Idle)) revert MigrationAccountingBusy(address(this), phase_);
    }

    function _parent() internal view returns (IUniswapV4DetfMigration) {
        return IUniswapV4DetfMigration(address(FundedRepo._layoutStruct().detf));
    }

    function _rewardToken() internal view returns (IUniswapV4DetfMigrationRewardToken token_) {
        address tokenAddress_ = _parent().migrationSyRewardToken();
        if (tokenAddress_ == address(0)) revert InvalidRewardBeneficiary(tokenAddress_);
        token_ = IUniswapV4DetfMigrationRewardToken(tokenAddress_);
        if (token_.receipt() != address(this) || token_.parent() != address(_parent())) {
            revert InvalidRewardBeneficiary(tokenAddress_);
        }
    }

    /// @dev Only genuine parent funding may reenter this receipt while it announces Synchronizing.
    function _synchronize() internal override {
        _requireIdle();
        Repo._layoutStruct().phase = uint8(AccountingPhase.Synchronizing);
        super._synchronize();
        Repo._layoutStruct().phase = uint8(AccountingPhase.Idle);
    }
}
