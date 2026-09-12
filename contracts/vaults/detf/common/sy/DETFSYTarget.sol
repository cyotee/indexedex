// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IStandardizedYield} from "@crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol";
import {IStandardExchangeIn} from "@crane/contracts/interfaces/IStandardExchangeIn.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {AddressSet, AddressSetRepo} from "@crane/contracts/utils/collections/sets/AddressSetRepo.sol";
import {ReentrancyLockModifiers} from "@crane/contracts/access/reentrancy/ReentrancyLockModifiers.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {IDETFFundedRewards} from "contracts/interfaces/IStakedDETF.sol";
import {IDETFStakingPreview} from "contracts/interfaces/IDETFStandardizedYield.sol";
import {IStandardVault} from "contracts/interfaces/IStandardVault.sol";
import {StandardVaultRepo} from "contracts/vaults/standard/StandardVaultRepo.sol";
import {DETFSYRepo as Repo} from "contracts/vaults/detf/common/sy/DETFSYRepo.sol";
import {DETFFundedStakingMath as StakingMath} from "contracts/vaults/detf/common/core/DETFFundedStakingMath.sol";

/// @title DETFSYTarget
/// @notice Pendle SY for raw DETF or static funded staking gons, on distinct wrapper addresses.
contract DETFSYTarget is IStandardizedYield, ReentrancyLockModifiers {
    using BetterSafeERC20 for IERC20;
    using AddressSetRepo for AddressSet;

    error InvalidToken(address token);
    error InvalidReceiver(address receiver);
    error ZeroAmount();
    error UnexpectedNativeValue();
    error ZeroShares();
    error MinimumOutputNotMet(uint256 minimum, uint256 actual);
    error InsufficientBacking(uint256 held, uint256 required);
    error UnexpectedTransferAmount(uint256 requested, uint256 received);

    modifier synchronized() {
        IDETFFundedRewards(address(Repo._layoutStruct().detf)).synchronizeRewards();
        _;
    }

    /// @notice Static share metadata is configured by the registered package.
    function name() external view returns (string memory) { return ERC20Repo._name(); }
    function symbol() external view returns (string memory) { return ERC20Repo._symbol(); }
    function decimals() external pure returns (uint8) { return 9; }
    function totalSupply() external view returns (uint256) { return ERC20Repo._totalSupply(); }
    function balanceOf(address account_) external view returns (uint256) { return ERC20Repo._balanceOf(account_); }
    function allowance(address owner_, address spender_) external view returns (uint256) {
        return ERC20Repo._allowance(owner_, spender_);
    }

    function approve(address spender_, uint256 amount_) external returns (bool) {
        ERC20Repo._approve(msg.sender, spender_, amount_);
        return true;
    }

    /// @notice Settle due expansion before transferring static ownership units.
    function transfer(address to_, uint256 amount_) external synchronized nonReentrant returns (bool) {
        ERC20Repo._transfer(msg.sender, to_, amount_);
        return true;
    }

    function transferFrom(address from_, address to_, uint256 amount_)
        external synchronized nonReentrant returns (bool)
    {
        ERC20Repo._transferFrom(from_, to_, amount_);
        return true;
    }

    /// @inheritdoc IStandardizedYield
    function deposit(address receiver_, address tokenIn_, uint256 amount_, uint256 minimum_)
        external payable synchronized nonReentrant returns (uint256 shares_)
    {
        if (msg.value != 0) revert UnexpectedNativeValue();
        if (amount_ == 0) revert ZeroAmount();
        if (receiver_ == address(0)) revert InvalidReceiver(receiver_);
        if (!isValidTokenIn(tokenIn_)) revert InvalidToken(tokenIn_);
        Repo.Storage storage s_ = Repo._layoutStruct();
        if (s_.isStaking) {
            uint256 receivedGons_ = _acquireStakingGons(s_, IERC20(tokenIn_), amount_);
            shares_ = receivedGons_ / StakingMath.INITIAL_GONS_PER_UNIT;
            uint256 represented_ = StakingMath._toGons(shares_, StakingMath.INITIAL_GONS_PER_UNIT);
            s_.backingGons += represented_;
            s_.conversionDustGons += receivedGons_ - represented_;
        } else {
            shares_ = _acquireDetf(s_, IERC20(tokenIn_), amount_);
            s_.rawBacking += shares_;
        }
        if (shares_ == 0) revert ZeroShares();
        if (shares_ < minimum_) revert MinimumOutputNotMet(minimum_, shares_);
        ERC20Repo._mint(receiver_, shares_);
        _requireBacking(s_);
        emit Deposit(msg.sender, receiver_, tokenIn_, amount_, shares_);
    }

    /// @inheritdoc IStandardizedYield
    function redeem(address receiver_, uint256 shares_, address tokenOut_, uint256 minimum_, bool internalBalance_)
        external synchronized nonReentrant returns (uint256 amountOut_)
    {
        if (shares_ == 0) revert ZeroAmount();
        if (receiver_ == address(0)) revert InvalidReceiver(receiver_);
        if (!isValidTokenOut(tokenOut_)) revert InvalidToken(tokenOut_);
        Repo.Storage storage s_ = Repo._layoutStruct();
        ERC20Repo._burn(internalBalance_ ? address(this) : msg.sender, shares_);
        if (s_.isStaking) {
            uint256 slice_ = StakingMath._toGons(shares_, StakingMath.INITIAL_GONS_PER_UNIT);
            s_.backingGons -= slice_;
            uint256 k_ = s_.staking.stakingState().gonsPerUnit;
            uint256 native_ = Math.mulDiv(shares_, StakingMath._syExchangeRate(k_), 1e18);
            s_.conversionDustGons += slice_ - StakingMath._toGons(native_, k_);
            amountOut_ = _redeemStaking(s_, native_, IERC20(tokenOut_), receiver_);
            // Full-account unstaking retires the wrapper's last fractional gons.
            // Such dust has moved to the staking reserve and cannot remain booked here.
            uint256 held_ = s_.staking.gonsOf(address(this));
            if (held_ < s_.backingGons) revert InsufficientBacking(held_, s_.backingGons);
            uint256 surplus_ = held_ - s_.backingGons;
            if (s_.conversionDustGons > surplus_) s_.conversionDustGons = surplus_;
        } else {
            s_.rawBacking -= shares_;
            amountOut_ = _payDetf(s_, shares_, IERC20(tokenOut_), receiver_);
        }
        if (amountOut_ < minimum_) revert MinimumOutputNotMet(minimum_, amountOut_);
        _requireBacking(s_);
        emit Redeem(msg.sender, receiver_, tokenOut_, shares_, amountOut_);
    }

    /// @inheritdoc IStandardizedYield
    function exchangeRate() public view returns (uint256) {
        Repo.Storage storage s_ = Repo._layoutStruct();
        return s_.isStaking ? StakingMath._syExchangeRate(s_.staking.stakingState().gonsPerUnit) : 1e18;
    }

    /// @inheritdoc IStandardizedYield
    function yieldToken() external view returns (address) {
        Repo.Storage storage s_ = Repo._layoutStruct();
        return s_.isStaking ? address(s_.staking) : address(s_.detf);
    }

    /// @inheritdoc IStandardizedYield
    function assetInfo() external view returns (AssetType, address, uint8) {
        return (AssetType.TOKEN, address(Repo._layoutStruct().detf), 9);
    }

    function getTokensIn() external view returns (address[] memory) { return Repo._layoutStruct().tokensIn._values(); }
    function getTokensOut() external view returns (address[] memory) { return Repo._layoutStruct().tokensOut._values(); }
    function isValidTokenIn(address token_) public view returns (bool) { return Repo._layoutStruct().tokensIn._contains(token_); }
    function isValidTokenOut(address token_) public view returns (bool) { return Repo._layoutStruct().tokensOut._contains(token_); }

    /// @inheritdoc IStandardizedYield
    function previewDeposit(address tokenIn_, uint256 amount_) external view returns (uint256) {
        if (!isValidTokenIn(tokenIn_)) revert InvalidToken(tokenIn_);
        Repo.Storage storage s_ = Repo._layoutStruct();
        uint256 detfAmount_ = amount_;
        if (tokenIn_ != address(s_.detf) && !(s_.isStaking && tokenIn_ == address(s_.staking))) {
            detfAmount_ = IStandardExchangeIn(address(s_.detf)).previewExchangeIn(
                IERC20(tokenIn_), amount_, s_.detf
            );
        }
        if (!s_.isStaking) return detfAmount_;
        uint256 k_ = IDETFStakingPreview(address(s_.detf)).previewStakingGonsPerUnit(IERC20(tokenIn_), amount_);
        return Math.mulDiv(detfAmount_, k_, StakingMath.INITIAL_GONS_PER_UNIT);
    }

    /// @inheritdoc IStandardizedYield
    function previewRedeem(address tokenOut_, uint256 shares_) external view returns (uint256) {
        if (!isValidTokenOut(tokenOut_)) revert InvalidToken(tokenOut_);
        Repo.Storage storage s_ = Repo._layoutStruct();
        uint256 detfAmount_ = shares_;
        if (s_.isStaking) {
            uint256 k_ = IDETFStakingPreview(address(s_.detf)).previewStakingGonsPerUnit(s_.detf, 0);
            detfAmount_ = Math.mulDiv(shares_, StakingMath._syExchangeRate(k_), 1e18);
            if (tokenOut_ == address(s_.staking)) return detfAmount_;
        }
        if (tokenOut_ == address(s_.detf)) return detfAmount_;
        return IStandardExchangeIn(address(s_.detf)).previewExchangeIn(s_.detf, detfAmount_, IERC20(tokenOut_));
    }

    /// @notice DETF yield is already funded into the backing index; it cannot be claimed twice.
    function getRewardTokens() external pure returns (address[] memory) { return new address[](0); }
    function accruedRewards(address) external pure returns (uint256[] memory) { return new uint256[](0); }
    function rewardIndexesCurrent() external pure returns (uint256[] memory) { return new uint256[](0); }
    function rewardIndexesStored() external pure returns (uint256[] memory) { return new uint256[](0); }
    function claimRewards(address user_) external returns (uint256[] memory amounts_) {
        amounts_ = new uint256[](0);
        emit ClaimRewards(user_, new address[](0), amounts_);
    }

    /// @notice Registry metadata describes the actual DETF accounting asset.
    function vaultFeeTypeIds() external view returns (bytes32) { return StandardVaultRepo._vaultFeeTypeIds(); }
    function contentsId() external view returns (bytes32) { return StandardVaultRepo._contentsId(); }
    function vaultTypes() external view returns (bytes4[] memory) { return StandardVaultRepo._vaultTypes(); }
    function vaultConfig() external view returns (IStandardVault.VaultConfig memory) {
        address[] memory tokens_ = new address[](1);
        tokens_[0] = address(Repo._layoutStruct().detf);
        return IStandardVault.VaultConfig({
            vaultFeeTypeIds: StandardVaultRepo._vaultFeeTypeIds(), contentsId: StandardVaultRepo._contentsId(),
            vaultTypes: StandardVaultRepo._vaultTypes(), tokens: tokens_
        });
    }

    function _acquireStakingGons(Repo.Storage storage s_, IERC20 tokenIn_, uint256 amount_) internal returns (uint256) {
        if (address(tokenIn_) == address(s_.staking)) {
            uint256 heldBefore_ = s_.staking.gonsOf(address(this));
            _pull(tokenIn_, amount_);
            return s_.staking.gonsOf(address(this)) - heldBefore_;
        }
        // Ordinary mint's seigniorage settles before measuring the new principal's staking receipt.
        uint256 detfAmount_ = _acquireDetf(s_, tokenIn_, amount_);
        uint256 before_ = s_.staking.gonsOf(address(this));
        s_.detf.forceApprove(address(s_.staking), detfAmount_);
        s_.staking.exchangeIn(s_.detf, detfAmount_, IERC20(address(s_.staking)), detfAmount_, address(this), false, block.timestamp);
        s_.detf.forceApprove(address(s_.staking), 0);
        return s_.staking.gonsOf(address(this)) - before_;
    }

    function _acquireDetf(Repo.Storage storage s_, IERC20 tokenIn_, uint256 amount_) internal returns (uint256) {
        uint256 received_ = _pull(tokenIn_, amount_);
        if (address(tokenIn_) == address(s_.detf)) return received_;
        uint256 before_ = s_.detf.balanceOf(address(this));
        tokenIn_.forceApprove(address(s_.detf), received_);
        IStandardExchangeIn(address(s_.detf)).exchangeIn(
            tokenIn_, received_, s_.detf, 0, address(this), false, block.timestamp
        );
        tokenIn_.forceApprove(address(s_.detf), 0);
        return s_.detf.balanceOf(address(this)) - before_;
    }

    function _redeemStaking(Repo.Storage storage s_, uint256 native_, IERC20 tokenOut_, address receiver_)
        internal returns (uint256)
    {
        if (native_ == 0) return 0;
        if (address(tokenOut_) == address(s_.staking)) {
            IERC20(address(s_.staking)).safeTransfer(receiver_, native_);
            return native_;
        }
        s_.staking.exchangeIn(
            IERC20(address(s_.staking)), native_, s_.detf, native_, address(this), false, block.timestamp
        );
        return _payDetf(s_, native_, tokenOut_, receiver_);
    }

    function _payDetf(Repo.Storage storage s_, uint256 amount_, IERC20 tokenOut_, address receiver_)
        internal returns (uint256 out_)
    {
        if (amount_ == 0) return 0;
        if (address(tokenOut_) == address(s_.detf)) {
            s_.detf.safeTransfer(receiver_, amount_);
            return amount_;
        }
        s_.detf.forceApprove(address(s_.detf), amount_);
        out_ = IStandardExchangeIn(address(s_.detf)).exchangeIn(
            s_.detf, amount_, tokenOut_, 0, receiver_, false, block.timestamp
        );
        s_.detf.forceApprove(address(s_.detf), 0);
    }

    function _pull(IERC20 token_, uint256 amount_) internal returns (uint256) {
        uint256 before_ = token_.balanceOf(address(this));
        token_.safeTransferFrom(msg.sender, address(this), amount_);
        uint256 received_ = token_.balanceOf(address(this)) - before_;
        if (received_ != amount_) revert UnexpectedTransferAmount(amount_, received_);
        return received_;
    }

    function _requireBacking(Repo.Storage storage s_) internal view {
        uint256 held_ = s_.isStaking ? s_.staking.gonsOf(address(this)) : s_.detf.balanceOf(address(this));
        uint256 required_ = s_.isStaking ? s_.backingGons + s_.conversionDustGons : s_.rawBacking;
        if (held_ < required_) revert InsufficientBacking(held_, required_);
    }
}
