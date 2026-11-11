// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {IERC20Metadata} from "@crane/contracts/interfaces/IERC20Metadata.sol";
import {ERC20Repo} from "@crane/contracts/tokens/ERC20/ERC20Repo.sol";
import {Math} from "@crane/contracts/utils/Math.sol";
import {IUniswapV4DetfMigration, IUniswapV4DetfMigrationAccounting} from
    "../../interfaces/IUniswapV4DetfMigration.sol";
import {IUniswapV4DetfMigrationStakedDETF} from "../../claimToken/IUniswapV4DetfMigrationStakedDETF.sol";
import {IUniswapV4DetfMigrationRewardToken} from "./IUniswapV4DetfMigrationRewardToken.sol";
import {UniswapV4DetfMigrationRewardTokenRepo as Repo} from "./UniswapV4DetfMigrationRewardTokenRepo.sol";

/// @notice Transferable fixed-gon RT. Mint and burn are receipt callbacks, never independent funding.
contract UniswapV4DetfMigrationRewardTokenTarget is IUniswapV4DetfMigrationRewardToken {
    error TokenizedRewardSupplyMismatch(uint256 expectedGons, uint256 bookedGons);

    modifier idleAccounting() {
        _requirePhase(address(this), uint8(AccountingPhase.Idle));
        Repo._layoutStruct().phase = uint8(AccountingPhase.Accounting);
        _;
        Repo._layoutStruct().phase = uint8(AccountingPhase.Idle);
    }

    /// @inheritdoc IERC20Metadata
    function name() external view returns (string memory) { return ERC20Repo._name(); }

    /// @inheritdoc IERC20Metadata
    function symbol() external view returns (string memory) { return ERC20Repo._symbol(); }

    /// @inheritdoc IERC20Metadata
    function decimals() external pure returns (uint8) { return 27; }

    /// @inheritdoc IERC20
    function totalSupply() external view returns (uint256) { return ERC20Repo._totalSupply(); }

    /// @inheritdoc IERC20
    function balanceOf(address account_) external view returns (uint256) { return ERC20Repo._balanceOf(account_); }

    /// @inheritdoc IERC20
    function allowance(address owner_, address spender_) external view returns (uint256) {
        return ERC20Repo._allowance(owner_, spender_);
    }

    /// @inheritdoc IERC20
    function approve(address spender_, uint256 amount_) external idleAccounting returns (bool) {
        ERC20Repo._approve(msg.sender, spender_, amount_);
        return true;
    }

    /// @inheritdoc IERC20
    function transfer(address recipient_, uint256 amount_) external idleAccounting returns (bool) {
        ERC20Repo._transfer(msg.sender, recipient_, amount_);
        return true;
    }

    /// @inheritdoc IERC20
    function transferFrom(address owner_, address recipient_, uint256 amount_)
        external idleAccounting returns (bool)
    {
        ERC20Repo._transferFrom(owner_, recipient_, amount_);
        return true;
    }

    /// @inheritdoc IUniswapV4DetfMigrationAccounting
    function migrationAccountingPhase() external view returns (uint8) { return Repo._layoutStruct().phase; }

    /// @inheritdoc IUniswapV4DetfMigrationRewardToken
    function receipt() external view returns (address) { return Repo._layoutStruct().receipt; }

    /// @inheritdoc IUniswapV4DetfMigrationRewardToken
    function parent() external view returns (address) { return Repo._layoutStruct().parent; }

    /// @inheritdoc IUniswapV4DetfMigrationRewardToken
    function mintByReceipt(address beneficiary_, uint256 amount_) external idleAccounting {
        _requireReceipt();
        if (beneficiary_ == address(0)) revert InvalidMigrationRewardReceiver(beneficiary_);
        ERC20Repo._mint(beneficiary_, amount_);
        _requireSupply();
    }

    /// @inheritdoc IUniswapV4DetfMigrationRewardToken
    function burnByReceipt(address owner_, uint256 amount_) external {
        _requireReceipt();
        // Only the synchronous receipt callback of this token's own redemption is admitted.
        _requirePhase(address(this), uint8(AccountingPhase.Accounting));
        if (owner_ == address(0)) revert InvalidMigrationRewardReceiver(owner_);
        ERC20Repo._burn(owner_, amount_);
        _requireSupply();
    }

    /// @inheritdoc IUniswapV4DetfMigrationRewardToken
    function redeem(uint256 amount_, address receiver_, uint256 minimum_)
        external idleAccounting returns (uint256 nativeSDETF, uint256 retainedGons)
    {
        if (receiver_ == address(0)) revert InvalidMigrationRewardReceiver(receiver_);
        // Receipt performs real parent synchronization before pinning k and checking activation.
        (nativeSDETF, retainedGons) = IUniswapV4DetfMigrationStakedDETF(Repo._layoutStruct().receipt)
            .redeemSyRewardTokens(msg.sender, receiver_, amount_, minimum_);
        emit SyRewardTokenRedeemed(msg.sender, receiver_, amount_, nativeSDETF, retainedGons);
    }

    /// @inheritdoc IUniswapV4DetfMigrationRewardToken
    function previewRedeem(uint256 amount_) external view returns (uint256 nativeSDETF) {
        uint256 k_ = IUniswapV4DetfMigrationStakedDETF(Repo._layoutStruct().receipt).stakingState().gonsPerUnit;
        return Math.mulDiv(amount_, Repo.GONS_PER_UNIT, k_);
    }

    function _requireReceipt() internal view {
        Repo.Storage storage s_ = Repo._layoutStruct();
        if (s_.receipt == address(0) || msg.sender != s_.receipt) revert NotMigrationReceipt(msg.sender);
        IUniswapV4DetfMigration parent_ = IUniswapV4DetfMigration(s_.parent);
        if (parent_.migrationSyRewardToken() != address(this)) revert NotMigrationReceipt(msg.sender);
        if (!parent_.migrationActivated()) revert MigrationRewardsClosed();
        _requirePhase(s_.receipt, uint8(AccountingPhase.Accounting));
    }

    function _requirePhase(address component_, uint8 expected_) internal view {
        uint8 actual_ = component_ == address(this)
            ? Repo._layoutStruct().phase
            : IUniswapV4DetfMigrationAccounting(component_).migrationAccountingPhase();
        if (actual_ != expected_) revert MigrationAccountingBusy(component_, actual_);
    }

    function _requireSupply() internal view {
        uint256 expected_ = Math.mulDiv(ERC20Repo._totalSupply(), Repo.GONS_PER_UNIT, 1);
        uint256 booked_ =
            IUniswapV4DetfMigrationStakedDETF(Repo._layoutStruct().receipt).tokenizedSyRewardGons();
        if (expected_ != booked_) revert TokenizedRewardSupplyMismatch(expected_, booked_);
    }
}
