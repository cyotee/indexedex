// SPDX-License-Identifier: BSL-1.1
pragma solidity ^0.8.0;

import {IMultiVaultWeightedDetfBonding} from "contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/IMultiVaultWeightedDetfBonding.sol";
import {IERC20} from "@crane/contracts/interfaces/IERC20.sol";
import {BetterSafeERC20} from "@crane/contracts/tokens/ERC20/utils/BetterSafeERC20.sol";
import {IDetfBondNFT} from "contracts/interfaces/IDetfBondNFT.sol";
import {IDetfNftReserveDonation} from "contracts/vaults/detf/common/bondNft/IDetfReserveDonation.sol";
import {MintSplit} from "contracts/vaults/detf/common/core/DETFMintSplit.sol";
import {MultiVaultWeightedDetfCommon} from "./MultiVaultWeightedDetfCommon.sol";
import {MultiVaultWeightedDetfRepo as Repo} from "./MultiVaultWeightedDetfRepo.sol";



/// @notice Bond principal is funded in staking escrow; every acquired reserve LP belongs to the DETF.
abstract contract MultiVaultWeightedDetfBondingTarget is MultiVaultWeightedDetfCommon {
    using BetterSafeERC20 for IERC20;

    function initializeReserve(uint256[] calldata amounts_, uint256 duration_, address to_, uint256 deadline_)
        public virtual nonReentrant returns (uint256 id_, uint256 lp_)
    {
        _requireNotDisabled();
        _requireActive(deadline_, 1);
        _requireBootstrapAmounts(amounts_);
        if (to_ == address(0)) to_ = msg.sender;
        uint256 lock_ = _effectiveLockDuration(duration_);
        Repo.Storage storage s_ = Repo._layoutStruct();
        uint256[] memory received_ = new uint256[](s_.vaultCount);
        for (uint256 i; i < s_.vaultCount; ++i) received_[i] = _pullToken(s_.vaultShares[i], amounts_[i], false);
        uint256 liquidity_ = _quoteBondJoinDetfAllLegs(received_);
        MintSplit memory split_ = _splitBondDetf(_quoteFirstBondPurchaseAllLegs(received_, lock_), liquidity_);
        _mintDetf(address(this), liquidity_);
        lp_ = _initializeReserve(liquidity_, received_);
        id_ = _completePurchase(split_, lock_, to_, lp_);
        _syncAllExpectedHoldReserves();
    }

    function _requireBootstrapAmounts(uint256[] calldata amounts_) internal view {
        Repo.Storage storage s_ = Repo._layoutStruct();
        if (s_.isReserveLive || IERC20(s_.reservePool).totalSupply() != 0) revert Repo.AlreadyLive();
        if (amounts_.length != s_.vaultCount) revert Repo.InvalidVaultCount(amounts_.length);
        for (uint256 i; i < amounts_.length; ++i) if (amounts_[i] == 0) revert Repo.ZeroAmount();
    }

    function bond(IERC20 in_, uint256 amount_, uint256 duration_, address to_, bool prepaid_, uint256 deadline_)
        public virtual nonReentrant returns (uint256 id_, uint256 lp_)
    {
        _requireNotDisabled();
        _requireActive(deadline_, amount_);
        Repo.Storage storage s_ = Repo._layoutStruct();
        if (!s_.isReserveLive) {
            _rejectPretransferredFirstBond(prepaid_, amount_);
            if (s_.vaultCount != 1) revert Repo.InvalidVaultCount(s_.vaultCount);
        }
        if (to_ == address(0)) to_ = msg.sender;
        _updateExpansionMintOnRewards();
        uint256 lock_ = _effectiveLockDuration(duration_);
        (bool found_, uint256 leg_) = Repo._findVaultShareIndex(in_);
        if (!found_) revert Repo.InvalidRoute(address(in_), address(this));
        uint256 shares_ = _pullToken(in_, amount_, prepaid_);
        uint256 liquidity_ = _quoteBondJoinDetf(leg_, shares_);
        MintSplit memory split_ = _splitBondDetf(_quoteBondPurchase(leg_, shares_, lock_), liquidity_);
        _mintDetf(address(this), liquidity_);
        lp_ = _joinReserveBothDetfAndShare(leg_, liquidity_, shares_);
        id_ = _completePurchase(split_, lock_, to_, lp_);
        _syncAllExpectedHoldReserves();
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

    function previewInitializeReserve(uint256[] calldata amounts_, uint256 duration_)
        external view returns (uint256 principal_, uint256 liquidity_, uint256 pot_)
    {
        _requireBootstrapAmounts(amounts_);
        liquidity_ = _quoteBondJoinDetfAllLegs(amounts_);
        MintSplit memory split_ = _splitBondDetf(
            _quoteFirstBondPurchaseAllLegs(amounts_, _effectiveLockDuration(duration_)), liquidity_
        );
        return (split_.userDetf, liquidity_, split_.inventoryDetf);
    }

    function previewBond(IERC20 in_, uint256 amount_, uint256 duration_)
        external view returns (uint256 principal_, uint256 liquidity_, uint256 pot_)
    {
        Repo.Storage storage s_ = Repo._layoutStruct();
        if (!s_.isReserveLive && s_.vaultCount != 1) revert Repo.InvalidVaultCount(s_.vaultCount);
        (bool found_, uint256 leg_) = Repo._findVaultShareIndex(in_);
        if (!found_) revert Repo.InvalidRoute(address(in_), address(this));
        liquidity_ = _quoteBondJoinDetf(leg_, amount_);
        MintSplit memory split_ = _splitBondDetf(
            _quoteBondPurchase(leg_, amount_, _effectiveLockDuration(duration_)), liquidity_
        );
        return (split_.userDetf, liquidity_, split_.inventoryDetf);
    }

    function acceptedBondTokens() external view returns (address[] memory tokens_) {
        Repo.Storage storage s_ = Repo._layoutStruct();
        tokens_ = new address[](s_.vaultCount);
        for (uint256 i; i < tokens_.length; ++i) tokens_[i] = address(s_.vaultShares[i]);
    }

    function joinDonatedCapital(IERC20 token_, uint256 amount_, uint256 deadline_)
        external nonReentrant returns (uint256 lp_)
    {
        _requireBondNft();
        _requireNotDisabled();
        _requireReserveLive();
        _requireActive(deadline_, amount_);
        if (address(token_) == address(this)) lp_ = _joinReserveDetfOnly(_pullToken(token_, amount_, false));
        else {
            (bool found_, uint256 leg_) = Repo._findVaultShareIndex(token_);
            if (!found_) revert Repo.InvalidRoute(address(token_), address(this));
            lp_ = _joinReserveVaultShareOnly(leg_, _pullToken(token_, amount_, false));
        }
        _sendJoinBptToNft(lp_);
        _syncAllExpectedHoldReserves();
    }

    function notifyReserveDonated() external { _requireBondNft(); }
    function donate(IERC20 token_, uint256 amount_, bool prepaid_) external {
        _requireNotDisabled();
        IDetfNftReserveDonation(address(Repo._layoutStruct().bondNftVault)).donate(
            msg.sender, token_, amount_, 0, prepaid_, block.timestamp
        );
    }
}
