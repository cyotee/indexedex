// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {IDetfNftReserveDonation} from "contracts/vaults/detf/common/bondNft/IDetfReserveDonation.sol";
import {MintSplit} from "contracts/vaults/detf/common/core/DETFMintSplit.sol";
import {MixedBufferMultiVaultStableDetfCommon} from "./MixedBufferMultiVaultStableDetfCommon.sol";
import {MixedBufferMultiVaultStableDetfRepo as Repo} from "./MixedBufferMultiVaultStableDetfRepo.sol";

interface IMixedBufferMultiVaultStableDetfBonding {
    function bond(IERC20 tokenIn, uint256 amountIn, uint256 duration, address recipient, bool prepaid, uint256 deadline)
        external returns (uint256 tokenId, uint256 protocolLpAdded);
    function bootstrapFirstBond(uint256 buffer, uint256[] calldata amounts, uint256 duration, address recipient, uint256 deadline)
        external returns (uint256 tokenId, uint256 protocolLpAdded, uint256 purchasedPrincipal);
    function previewBond(IERC20 tokenIn, uint256 amountIn, uint256 duration)
        external view returns (uint256 principal, uint256 liquidityDetf, uint256 rewardPot);
    function previewBootstrapFirstBond(uint256 buffer, uint256[] calldata amounts, uint256 duration)
        external view returns (uint256 principal, uint256 liquidityDetf, uint256 rewardPot);
    function acceptedBondTokens() external view returns (address[] memory);
    function joinDonatedCapital(IERC20 token, uint256 amount, uint256 deadline) external returns (uint256);
    function previewJoinDonatedCapital(IERC20 token, uint256 amount) external view returns (uint256);
    function notifyReserveDonated() external;
    function donate(IERC20 token, uint256 amount, bool prepaid) external;
}

/// @notice Bond principal is funded in staking escrow; every acquired reserve LP belongs to the DETF.
abstract contract MixedBufferMultiVaultStableDetfBondingTarget is MixedBufferMultiVaultStableDetfCommon, IMixedBufferMultiVaultStableDetfBonding {
    using BetterSafeERC20 for IERC20;

    function bootstrapFirstBond(uint256 buffer_, uint256[] calldata amounts_, uint256 duration_, address to_, uint256 deadline_)
        public virtual nonReentrant returns (uint256 id_, uint256 lp_, uint256 principal_)
    {
        _requireNotDisabled();
        _requireActive(deadline_, buffer_);
        _requireBootstrapAmounts(buffer_, amounts_);
        if (to_ == address(0)) to_ = msg.sender;
        uint256 lock_ = _effectiveLockDuration(duration_);
        Repo.Storage storage s_ = Repo._layoutStruct();
        _pullToken(s_.bufferToken, buffer_, false);
        uint256[] memory received_ = new uint256[](s_.vaultCount);
        for (uint256 i; i < s_.vaultCount; ++i) received_[i] = _pullToken(s_.vaultShares[i], amounts_[i], false);
        uint256 liquidity_ = _pegSeedDetfAmount(buffer_, received_);
        MintSplit memory split_ = _splitBondDetf(_firstBondPurchase(buffer_, received_, lock_), liquidity_);
        _mintDetf(address(this), liquidity_);
        lp_ = _initializeReserve(liquidity_, buffer_, received_);
        id_ = _completePurchase(split_, lock_, to_, lp_);
        principal_ = split_.userDetf;
        _syncAllExpectedHoldReserves();
    }

    function _requireBootstrapAmounts(uint256 buffer_, uint256[] calldata amounts_) internal view {
        Repo.Storage storage s_ = Repo._layoutStruct();
        if (s_.isReserveLive || IERC20(s_.reservePool).totalSupply() != 0) revert Repo.AlreadyLive();
        if (buffer_ == 0 || amounts_.length != s_.vaultCount) revert Repo.InvalidBootstrapAmounts();
        for (uint256 i; i < amounts_.length; ++i) if (amounts_[i] == 0) revert Repo.InvalidBootstrapAmounts();
    }

    function bond(IERC20 in_, uint256 amount_, uint256 duration_, address to_, bool prepaid_, uint256 deadline_)
        public virtual nonReentrant returns (uint256 id_, uint256 lp_)
    {
        _requireNotDisabled();
        _requireActive(deadline_, amount_);
        _requireReserveLive();
        if (to_ == address(0)) to_ = msg.sender;
        _updateExpansionMintOnRewards();
        uint256 lock_ = _effectiveLockDuration(duration_);
        uint256 index_ = _paymentIndex(in_);
        uint256 actual_ = _pullToken(in_, amount_, prepaid_);
        uint256 liquidity_ = _quoteBondJoinDetf(index_, actual_);
        MintSplit memory split_ = _splitBondDetf(_quoteBondPurchase(in_, actual_, lock_), liquidity_);
        _mintDetf(address(this), liquidity_);
        lp_ = _joinBondPayment(in_, actual_, liquidity_);
        id_ = _completePurchase(split_, lock_, to_, lp_);
        _syncAllExpectedHoldReserves();
    }

    function _joinBondPayment(IERC20 in_, uint256 amount_, uint256 liquidity_) internal returns (uint256) {
        if (Repo._isBufferToken(in_)) return _joinReserveBufferAndDetf(amount_, liquidity_);
        (bool found_, uint256 leg_) = Repo._findVaultShareIndex(in_);
        if (!found_) revert Repo.InvalidRoute(address(in_), address(this));
        return _joinReserveShareAndDetf(leg_, amount_, liquidity_);
    }

    function _completePurchase(MintSplit memory split_, uint256 duration_, address to_, uint256 lp_)
        internal returns (uint256 id_)
    {
        if (lp_ == 0 || split_.userDetf == 0) revert Repo.ZeroAmount();
        Repo.Storage storage s_ = Repo._layoutStruct();
        _custodyBptOnNft(lp_);
        if (!s_.isReserveLive) Repo._setReserveLive();
        _mintDetf(address(this), split_.userDetf);
        IERC20(address(this)).forceApprove(address(s_.bondNftVault), split_.userDetf);
        id_ = IDetfBondNFT(address(s_.bondNftVault)).createFundedPosition(split_.userDetf, duration_, to_);
        IERC20(address(this)).forceApprove(address(s_.bondNftVault), 0);
        _fundStakingRewards(split_.inventoryDetf);
    }

    function previewBootstrapFirstBond(uint256 buffer_, uint256[] calldata amounts_, uint256 duration_)
        external view returns (uint256 principal_, uint256 liquidity_, uint256 pot_)
    {
        _requireBootstrapAmounts(buffer_, amounts_);
        liquidity_ = _pegSeedDetfAmount(buffer_, amounts_);
        MintSplit memory split_ = _splitBondDetf(_firstBondPurchase(buffer_, amounts_, _effectiveLockDuration(duration_)), liquidity_);
        return (split_.userDetf, liquidity_, split_.inventoryDetf);
    }

    function previewBond(IERC20 in_, uint256 amount_, uint256 duration_)
        external view returns (uint256 principal_, uint256 liquidity_, uint256 pot_)
    {
        _requireReserveLive();
        liquidity_ = _quoteBondJoinDetf(_paymentIndex(in_), amount_);
        MintSplit memory split_ = _splitBondDetf(_quoteBondPurchase(in_, amount_, _effectiveLockDuration(duration_)), liquidity_);
        return (split_.userDetf, liquidity_, split_.inventoryDetf);
    }

    function acceptedBondTokens() external view returns (address[] memory tokens_) {
        Repo.Storage storage s_ = Repo._layoutStruct();
        tokens_ = new address[](uint256(s_.vaultCount) + 1);
        tokens_[0] = address(s_.bufferToken);
        for (uint256 i; i < s_.vaultCount; ++i) tokens_[i + 1] = address(s_.vaultShares[i]);
    }

    function joinDonatedCapital(IERC20 token_, uint256 amount_, uint256 deadline_)
        external nonReentrant returns (uint256 lp_)
    {
        _requireBondNft();
        _requireNotDisabled();
        _requireReserveLive();
        _requireActive(deadline_, amount_);
        lp_ = address(token_) == address(this)
            ? _joinReserveBufferAndDetf(0, _pullToken(token_, amount_, false))
            : _joinPayment(token_, _pullToken(token_, amount_, false));
        if (lp_ == 0) revert Repo.ZeroAmount();
        _custodyBptOnNft(lp_);
        _syncAllExpectedHoldReserves();
    }

    function previewJoinDonatedCapital(IERC20 token_, uint256 amount_) external view returns (uint256) {
        return _previewJoinDonatedCapital(token_, amount_);
    }
    function notifyReserveDonated() external { _requireBondNft(); }
    function donate(IERC20 token_, uint256 amount_, bool prepaid_) external {
        _requireNotDisabled();
        IDetfNftReserveDonation(address(Repo._layoutStruct().bondNftVault)).donate(
            msg.sender, token_, amount_, 0, prepaid_, block.timestamp
        );
    }
}
