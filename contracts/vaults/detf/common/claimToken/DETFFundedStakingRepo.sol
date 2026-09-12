// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {IERC20Errors} from "@crane/contracts/interfaces/IERC20Errors.sol";
import {IERC20Events} from "@crane/contracts/interfaces/IERC20Events.sol";
import {IVaultFeeOracleQuery} from "contracts/interfaces/IVaultFeeOracleQuery.sol";
import {DETFFundedStakingMath as StakingMath} from "contracts/vaults/detf/common/core/DETFFundedStakingMath.sol";
import {DETFSeigniorageShareLib} from "contracts/vaults/detf/common/core/DETFSeigniorageShareLib.sol";

/// @title DETFFundedStakingRepo
/// @notice Funded DETF liabilities and nonredeemable standing reward weights.
/// @dev Target callers must authenticate funding and measure actual inbound DETF before credit.
library DETFFundedStakingRepo {
    bytes32 internal constant DEFAULT_SLOT =
        bytes32(uint256(keccak256(abi.encode("indexedex.detf.funded.staking"))) - 1);

    error AlreadyInitialized();
    error InvalidBackingToken();
    error InsufficientBacking(uint256 held, uint256 required);
    error InvalidEscrowRemainder(uint256 gons);

    struct Storage {
        IERC20 detf;
        address bondNftVault;
        IVaultFeeOracleQuery feeOracle;
        bool synchronizing;
        uint256 gonsPerUnit;
        uint256 totalGons;
        uint256 accountedBacking;
        uint256 allocationDust;
        uint256 stakingDust;
        uint256 feeWeight;
        uint256 creatorWeight;
        mapping(address account => uint256 gons) gonsOf;
    }

    /// @notice Resolve a namespaced ledger, including isolated test instances.
    function _layoutStruct(bytes32 slot_) internal pure returns (Storage storage layoutStruct_) {
        assembly {
            layoutStruct_.slot := slot_
        }
    }

    /// @notice Resolve the canonical funded staking ledger.
    function _layoutStruct() internal pure returns (Storage storage) {
        return _layoutStruct(DEFAULT_SLOT);
    }

    /// @notice Initialize once; the index is never reset after the final unstake.
    function _initialize(
        Storage storage layoutStruct_, IERC20 detf_, address bondNftVault_, IVaultFeeOracleQuery feeOracle_
    ) internal {
        if (address(layoutStruct_.detf) != address(0)) revert AlreadyInitialized();
        if (address(detf_) == address(0) || bondNftVault_ == address(0) || address(feeOracle_) == address(0)) {
            revert InvalidBackingToken();
        }
        if (IERC20Metadata(address(detf_)).decimals() != 9) revert InvalidBackingToken();
        layoutStruct_.detf = detf_;
        layoutStruct_.bondNftVault = bondNftVault_;
        layoutStruct_.feeOracle = feeOracle_;
        layoutStruct_.gonsPerUnit = StakingMath.INITIAL_GONS_PER_UNIT;
    }

    /// @notice Initialize the canonical ledger.
    function _initialize(IERC20 detf_, address bondNftVault_, IVaultFeeOracleQuery feeOracle_) internal {
        _initialize(_layoutStruct(), detf_, bondNftVault_, feeOracle_);
    }

    /// @notice Aggregate outstanding native-unit redemption liability.
    function _totalSupply(Storage storage layoutStruct_) internal view returns (uint256) {
        return StakingMath._toAmount(layoutStruct_.totalGons, layoutStruct_.gonsPerUnit);
    }

    /// @notice Aggregate liability in the canonical ledger.
    function _totalSupply() internal view returns (uint256) {
        return _totalSupply(_layoutStruct());
    }

    /// @notice Current native-unit balance backed by an account's gons.
    function _balanceOf(Storage storage layoutStruct_, address account_) internal view returns (uint256) {
        return StakingMath._toAmount(layoutStruct_.gonsOf[account_], layoutStruct_.gonsPerUnit);
    }

    /// @notice Current balance in the canonical ledger.
    function _balanceOf(address account_) internal view returns (uint256) {
        return _balanceOf(_layoutStruct(), account_);
    }

    /// @notice Credit actually received principal, without treating it as reward income.
    /// @dev Inbound transfer authentication belongs to the calling Target, not balance surplus.
    function _creditPrincipal(Storage storage layoutStruct_, address recipient_, uint256 amount_)
        internal
        returns (uint256 gons_)
    {
        layoutStruct_.accountedBacking += amount_;
        _requireBacking(layoutStruct_);
        gons_ = _issueAllocatedPrincipal(layoutStruct_, recipient_, amount_);
    }

    /// @notice Credit principal in the canonical ledger.
    function _creditPrincipal(address recipient_, uint256 amount_) internal returns (uint256) {
        return _creditPrincipal(_layoutStruct(), recipient_, amount_);
    }

    /// @notice Debit a funded withdrawal before the Target transfers equal native DETF units.
    /// @dev Full exits retire only this account's sub-native remainder, retaining its backing as dust.
    function _debitPrincipal(Storage storage layoutStruct_, address owner_, uint256 amount_)
        internal
        returns (uint256 gons_)
    {
        uint256 balance_ = _balanceOf(layoutStruct_, owner_);
        if (amount_ > balance_) revert IERC20Errors.ERC20InsufficientBalance(owner_, balance_, amount_);
        uint256 oldLiability_ = _totalSupply(layoutStruct_);
        gons_ = amount_ == balance_
            ? layoutStruct_.gonsOf[owner_]
            : StakingMath._toGons(amount_, layoutStruct_.gonsPerUnit);
        layoutStruct_.gonsOf[owner_] -= gons_;
        layoutStruct_.totalGons -= gons_;
        layoutStruct_.accountedBacking -= amount_;
        layoutStruct_.stakingDust += oldLiability_ - _totalSupply(layoutStruct_) - amount_;
        emit IERC20Events.Transfer(owner_, address(0), amount_);
    }

    /// @notice Debit principal in the canonical ledger.
    function _debitPrincipal(address owner_, uint256 amount_) internal returns (uint256) {
        return _debitPrincipal(_layoutStruct(), owner_, amount_);
    }

    /// @notice Retire only a final position fraction; all released backing remains ordinary dust.
    function _retireFraction(Storage storage layoutStruct_, address owner_, uint256 gons_) internal {
        if (gons_ >= layoutStruct_.gonsPerUnit || gons_ > layoutStruct_.gonsOf[owner_]) {
            revert InvalidEscrowRemainder(gons_);
        }
        uint256 before_ = _totalSupply(layoutStruct_);
        layoutStruct_.gonsOf[owner_] -= gons_;
        layoutStruct_.totalGons -= gons_;
        layoutStruct_.stakingDust += before_ - _totalSupply(layoutStruct_);
    }

    /// @notice Retire a final fraction in the canonical ledger.
    function _retireFraction(address owner_, uint256 gons_) internal {
        _retireFraction(_layoutStruct(), owner_, gons_);
    }

    /// @notice Transfer equal native balances without changing aggregate or standing weights.
    function _transfer(Storage storage layoutStruct_, address from_, address to_, uint256 amount_) internal {
        if (from_ == address(0)) revert IERC20Errors.ERC20InvalidSender(from_);
        if (to_ == address(0)) revert IERC20Errors.ERC20InvalidReceiver(to_);
        uint256 balance_ = _balanceOf(layoutStruct_, from_);
        if (amount_ > balance_) revert IERC20Errors.ERC20InsufficientBalance(from_, balance_, amount_);
        uint256 gons_ = StakingMath._toGons(amount_, layoutStruct_.gonsPerUnit);
        layoutStruct_.gonsOf[from_] -= gons_;
        layoutStruct_.gonsOf[to_] += gons_;
        emit IERC20Events.Transfer(from_, to_, amount_);
    }

    /// @notice Transfer in the canonical ledger.
    function _transfer(address from_, address to_, uint256 amount_) internal {
        _transfer(_layoutStruct(), from_, to_, amount_);
    }

    /// @notice Apply the retained top-up-only fee formula after funded gons change.
    function _topUpWeights(Storage storage layoutStruct_, uint256 feeFraction_, uint256 creatorFraction_) internal {
        (uint256 fee_, uint256 creator_) = DETFSeigniorageShareLib._topUpDeltas(
            layoutStruct_.totalGons,
            layoutStruct_.feeWeight,
            layoutStruct_.creatorWeight,
            feeFraction_,
            creatorFraction_
        );
        layoutStruct_.feeWeight += fee_;
        layoutStruct_.creatorWeight += creator_;
    }

    /// @notice Apply weight top-ups in the canonical ledger.
    function _topUpWeights(uint256 feeFraction_, uint256 creatorFraction_) internal {
        _topUpWeights(_layoutStruct(), feeFraction_, creatorFraction_);
    }

    /// @notice Allocate new funded rewards, rebase existing gons, then issue backed role receipts.
    /// @dev The caller tops up future weights afterward. Existing allocation and staking dust
    ///      enter their respective stages exactly once; receipt minting adds no new backing.
    function _distribute(
        Storage storage layoutStruct_, uint256 amount_, address feeRecipient_, address creatorRecipient_
    ) internal returns (StakingMath.RewardAllocation memory allocation_, uint256 growth_) {
        layoutStruct_.accountedBacking += amount_;
        _requireBacking(layoutStruct_);
        allocation_ = StakingMath._allocate(
            amount_ + layoutStruct_.allocationDust,
            layoutStruct_.totalGons,
            layoutStruct_.feeWeight,
            layoutStruct_.creatorWeight
        );
        layoutStruct_.allocationDust = allocation_.dust;
        (layoutStruct_.gonsPerUnit, growth_, layoutStruct_.stakingDust) = StakingMath._rebase(
            layoutStruct_.totalGons, layoutStruct_.gonsPerUnit, allocation_.staking + layoutStruct_.stakingDust
        );
        if (allocation_.fee != 0) _issueAllocatedPrincipal(layoutStruct_, feeRecipient_, allocation_.fee);
        if (allocation_.creator != 0) _issueAllocatedPrincipal(layoutStruct_, creatorRecipient_, allocation_.creator);
    }

    /// @notice Distribute funded rewards in the canonical ledger.
    function _distribute(uint256 amount_, address feeRecipient_, address creatorRecipient_)
        internal
        returns (StakingMath.RewardAllocation memory, uint256)
    {
        return _distribute(_layoutStruct(), amount_, feeRecipient_, creatorRecipient_);
    }

    /// @notice Assert backing without treating unsolicited balances as new rewards.
    function _requireBacking(Storage storage layoutStruct_) internal view {
        uint256 held_ = layoutStruct_.detf.balanceOf(address(this));
        if (held_ < layoutStruct_.accountedBacking) {
            revert InsufficientBacking(held_, layoutStruct_.accountedBacking);
        }
    }

    /// @notice Assert backing for the canonical ledger.
    function _requireBacking() internal view {
        _requireBacking(_layoutStruct());
    }

    /// @dev Only an already funded principal allocation may call this issuance helper.
    function _issueAllocatedPrincipal(Storage storage layoutStruct_, address recipient_, uint256 amount_)
        private
        returns (uint256 gons_)
    {
        if (recipient_ == address(0)) revert IERC20Errors.ERC20InvalidReceiver(recipient_);
        gons_ = StakingMath._toGons(amount_, layoutStruct_.gonsPerUnit);
        layoutStruct_.totalGons += gons_;
        layoutStruct_.gonsOf[recipient_] += gons_;
        emit IERC20Events.Transfer(address(0), recipient_, amount_);
    }
}
